//! Explicit v1 SQL session; resident state is one finite bundle, one frozen
//! command and one result cursor. Completed rows die with each command arena.
const std = @import("std");
const q = @import("transit_query");
const w = q.Workspace;
const m = q.fuze.Unified;
const Config = struct { url: []const u8, seed_file: []const u8, connection: q.UnifiedClient.Connection, workspace: w.Config, request_timeout_ms: u32 = 5000 };
pub const Session = struct {
    diagnostic: ?*@import("cli_support").Diagnostic = null,
    namespace: ?u64 = null,
    bundle: [q.Bundle.max_bytes]u8 = undefined,
    length: usize = 0,
    pending: ?q.UnifiedClient.Prepared = null,
    input: ?u64 = null,
    cursor: ?q.UnifiedResult.Cursor = null,
    complete: bool = false,
    format: enum { json, table } = .json,
    checkpoint_context: ?*anyopaque = null,
    checkpoint_fn: ?*const fn (*anyopaque, *const Session) anyerror!void = null,
    interrupted: ?*const fn () bool = null,
    pub fn clear(self: *Session) void {
        const format = self.format;
        const diagnostic = self.diagnostic;
        const context = self.checkpoint_context;
        const callback = self.checkpoint_fn;
        const interrupted = self.interrupted;
        std.crypto.secureZero(u8, &self.bundle);
        self.* = .{ .diagnostic = diagnostic, .format = format, .checkpoint_context = context, .checkpoint_fn = callback, .interrupted = interrupted };
    }
    pub fn checkpoint(self: *const Session) !void {
        if (self.checkpoint_fn) |callback| try callback(self.checkpoint_context.?, self);
    }
    fn checkInterrupt(self: *const Session) !void {
        if (self.interrupted) |interrupted| if (interrupted()) return error.ConsoleInterrupted;
    }
};
fn json(out: *std.Io.Writer, value: anytype) !void {
    try std.json.Stringify.value(value, .{ .escape_unicode = true }, out);
    try out.writeByte('\n');
}
pub fn run(init: std.process.Init, path: []const u8, diagnostic: *@import("cli_support").Diagnostic, structured: bool) !void {
    const config = try @import("cli_support").Settings.readTyped(Config, init, path, diagnostic);
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidConfiguration;
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    var client: q.UnifiedClient = .{ .wire = &wire, .connection = config.connection, .key = try q.wire.readKey(init.gpa, init.io, config.seed_file) };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    var session: Session = .{ .diagnostic = diagnostic };
    defer session.clear();
    var input_buffer: [65536]u8 = undefined;
    var input = std.Io.File.stdin().reader(init.io, &input_buffer);
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    try output.interface.flush();
    while (try input.interface.takeDelimiter('\n')) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (std.mem.eql(u8, line, ".quit")) break;
        if (line.len == 0) continue;
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        diagnostic.envelope = null;
        diagnostic.sql = null;
        diagnostic.file = null;
        command(init, &session, &client, config.workspace, line, arena.allocator(), &output.interface) catch |err| {
            // Read denial invalidates result access, not saved command identity.
            if (err == error.AccessDenied or err == error.QueryDenied or err == error.QuerySourceUnavailable or err == error.ResourceUnavailable or err == error.DocumentRetired or err == error.DocumentHistoryGap or err == error.DocumentResyncRequired) {
                session.cursor = null;
                session.complete = false;
            }
            if (structured) {
                if (diagnostic.sql == null) diagnostic.envelope = savedDiagnostic(session, err) catch null;
                @import("Diagnostic.zig").emit(diagnostic.*, init.io, err, true, null);
            } else try json(&output.interface, .{ .err = @errorName(err), .uncertain = session.pending != null });
        };
        try output.interface.flush();
    }
}
pub fn command(init: std.process.Init, session: *Session, client: *q.UnifiedClient, config: w.Config, line: []const u8, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    if (std.mem.eql(u8, line, ".sources") or std.mem.eql(u8, line, ".schema")) return json(out, try w.apply(allocator, client, config, .describe));
    if (std.mem.eql(u8, line, ".info")) {
        _ = try client.describe(try config.source.native(allocator));
        return json(out, .{ .connection = client.connection, .namespace = if (session.namespace) |id| try q.document.JsonValues.decimal(allocator, id) else null, .uncertain = session.pending != null, .input = session.input, .complete_coverage = session.complete });
    }
    if (std.mem.startsWith(u8, line, ".new ") or std.mem.startsWith(u8, line, ".resume ")) {
        if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
        const fresh = std.mem.startsWith(u8, line, ".new ");
        const id = try q.Values.unsigned(line[if (fresh) 5 else 8..]);
        if (id == 0) return error.InvalidQueryIdentity;
        _ = try client.describe(try config.source.native(allocator));
        const status = try client.status(id);
        if (fresh and status != null) return error.QueryUploadIdentityConflict;
        session.clear();
        session.namespace = id;
        return json(out, try w.apply(allocator, client, config, .{ .status = try q.document.JsonValues.decimal(allocator, id) }));
    }
    if (std.mem.eql(u8, line, ".pending")) return json(out, .{ .token = if (session.pending) |pending| try std.json.Stringify.valueAlloc(allocator, pending, .{}) else null });
    if (std.mem.eql(u8, line, ".bundle")) return json(out, .{ .bundle = if (session.length != 0) try q.document.JsonValues.hex(allocator, session.bundle[0..session.length]) else null });
    if (std.mem.startsWith(u8, line, ".restore-bundle ")) {
        if (session.pending != null or session.input != null or session.length != 0) return error.UnresolvedSubmission;
        const id = session.namespace orelse return error.NamespaceRequired;
        const encoded = line[16..];
        // Validate current policy, the configured source, limits and durable
        // upload identity before retaining bytes. Preparation never submits.
        _ = try w.apply(allocator, client, config, .{ .next = .{ .namespace = try q.document.JsonValues.decimal(allocator, id), .bundle = encoded } });
        const bytes = try q.Values.unhex(allocator, encoded, q.Bundle.max_bytes);
        @memcpy(session.bundle[0..bytes.len], bytes);
        session.length = bytes.len;
        return json(out, .{ .restored_bundle = true });
    }
    if (std.mem.startsWith(u8, line, ".restore ")) {
        if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
        const pending = try q.Bridge.prepared(allocator, line[9..]);
        try client.validate(pending);
        session.pending = pending;
        return json(out, .{ .restored = true });
    }
    if (std.mem.eql(u8, line, ".retry")) {
        const pending = session.pending orelse return error.NoPendingSubmission;
        const receipt = try submit(session, client, pending);
        try json(out, .{ .receipt = receipt });
        return advance(init, session, client, allocator, out);
    }
    if (std.mem.eql(u8, line, ".advance")) return advance(init, session, client, allocator, out);
    const id = session.namespace orelse return error.NamespaceRequired;
    const namespace = try q.document.JsonValues.decimal(allocator, id);
    if (std.mem.eql(u8, line, ".status")) return json(out, try w.apply(allocator, client, config, .{ .status = namespace }));
    if (std.mem.eql(u8, line, ".next")) {
        if (session.complete) return error.QueryComplete;
        const cursor = if (session.cursor) |value| try std.json.Stringify.valueAlloc(allocator, value, .{}) else null;
        const page = (try w.apply(allocator, client, config, .{ .page = .{ .namespace = namespace, .cursor = cursor } })).page;
        // JSON escaping preserves terminal boundaries and wide scalars. The
        // opaque cursor is copied only after the full verified page is written.
        if (session.format == .json) try json(out, .{ .manifest = page.evidence.manifest, .ordinal = page.evidence.ordinal, .columns = page.evidence.columns, .cells = page.cells, .complete_coverage = page.evidence.next == null }) else {
            try out.writeAll("Verified complete result; page evidence: ");
            try json(out, .{ .manifest = page.evidence.manifest, .ordinal = page.evidence.ordinal, .complete_coverage = page.evidence.next == null });
            for (page.evidence.columns) |column| {
                try std.json.Stringify.value(column.name, .{ .escape_unicode = true }, out);
                try out.writeByte('\t');
            }
            try out.writeByte('\n');
            for (page.cells) |row| {
                for (row) |cell| {
                    try std.json.Stringify.value(cell, .{ .escape_unicode = true }, out);
                    try out.writeByte('\t');
                }
                try out.writeByte('\n');
            }
        }
        session.cursor = if (page.evidence.next) |next| (try std.json.parseFromSlice(q.UnifiedResult.Cursor, allocator, next, .{})).value else null;
        session.complete = page.evidence.next == null;
        return;
    }
    if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
    if (std.mem.eql(u8, line, ".cancel") or std.mem.eql(u8, line, ".retire") or std.mem.eql(u8, line, ".collect")) {
        const operation = std.meta.stringToEnum(@FieldType(@FieldType(w.Request, "prepare_control"), "operation"), line[1..]).?;
        const prepared = (try w.apply(allocator, client, config, .{ .prepare_control = .{ .namespace = namespace, .operation = operation } })).prepared.?;
        session.pending = try q.Bridge.prepared(allocator, prepared.token);
        session.length = 0;
    } else {
        const Input = @import("cli_support").SqlInput;
        const request: Input.Request = if (try Input.commandPath(allocator, line)) |path|
            try Input.read(Input.Request, init, allocator, path)
        else ordinary: {
            if (line[0] == '.' or line[0] == '/') return error.UnknownCommand;
            break :ordinary .{ .sql = line };
        };
        return executeSql(init, session, client, config, request, allocator, out);
    }
    return submitAndAdvance(init, session, client, allocator, out);
}
/// Only new work reaches compilation. Recovery paths keep the saved bundle
/// and signed operation and never reopen a parameter file or rebind its values.
pub fn executeSql(init: std.process.Init, session: *Session, client: *q.UnifiedClient, config: w.Config, request: @import("cli_support").SqlInput.Request, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
    const id = session.namespace orelse return error.NamespaceRequired;
    if (session.length != 0 or try client.status(id) != null) return error.QueryUploadIdentityConflict;
    var binding: q.fuze.Sql.Binding = .{};
    const compiled = (w.applyDiagnostic(allocator, client, config, .{ .compile = request }, &binding) catch |err| {
        if (session.diagnostic) |diagnostic| diagnostic.sql = q.fuze.SqlDiagnostic.bound(request.sql, err, true, binding);
        return err;
    }).compiled;
    const bytes = try q.Values.unhex(allocator, compiled.bundle, q.Bundle.max_bytes);
    @memcpy(session.bundle[0..bytes.len], bytes);
    session.length = bytes.len;
    session.pending = try client.prepareNext(id, try q.Bundle.decode(allocator, session.bundle[0..session.length]));
    return submitAndAdvance(init, session, client, allocator, out);
}
fn submitAndAdvance(init: std.process.Init, session: *Session, client: *q.UnifiedClient, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    const receipt = try submit(session, client, session.pending orelse return error.NoPendingSubmission);
    try json(out, .{ .receipt = receipt });
    return advance(init, session, client, allocator, out);
}
fn submit(session: *Session, client: *q.UnifiedClient, pending: q.UnifiedClient.Prepared) !q.protocol.Receipt {
    try session.checkpoint(); // Persist the exact intent before any possible acceptance.
    try session.checkInterrupt();
    const receipt = try client.submit(pending);
    session.pending = null;
    session.input = receipt.position;
    try session.checkpoint();
    try session.checkInterrupt();
    return receipt;
}
/// Settle only the frozen operation; cancellation must not finish an upload.
pub fn settle(init: std.process.Init, session: *Session, client: *q.UnifiedClient) !void {
    if (session.pending) |pending| _ = try submit(session, client, pending);
    const deadline = std.Io.Clock.boot.now(init.io).toMilliseconds() + 30000;
    while (session.input) |input| {
        try session.checkInterrupt();
        switch (try client.observe(input)) {
            .pending => {
                if (std.Io.Clock.boot.now(init.io).toMilliseconds() >= deadline) return error.QueryWaitTimedOut;
                try init.io.sleep(.fromMilliseconds(20), .awake);
            },
            .committed => {
                session.input = null;
                try session.checkpoint();
            },
            .rejected => {
                session.input = null;
                try session.checkpoint();
                return error.QueryInputRejected;
            },
        }
    }
}
fn advance(init: std.process.Init, session: *Session, client: *q.UnifiedClient, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    if (session.pending != null) return error.UnresolvedSubmission;
    const deadline = std.Io.Clock.boot.now(init.io).toMilliseconds() + 30000;
    // Each finite upload has at most 128 parts, plus begin/seal/submit. Each
    // successful step is committed before another signed command is prepared.
    for (0..132) |_| {
        try session.checkInterrupt();
        while (session.input) |input| {
            try session.checkInterrupt();
            switch (try client.observe(input)) {
                .pending => {
                    if (std.Io.Clock.boot.now(init.io).toMilliseconds() >= deadline) return json(out, .{ .waiting_for_input = input });
                    try init.io.sleep(.fromMilliseconds(20), .awake);
                },
                .committed => {
                    session.input = null;
                    try session.checkpoint();
                },
                .rejected => |reason| {
                    session.input = null;
                    session.length = 0;
                    return json(out, .{ .rejected = reason });
                },
            }
        }
        const id = session.namespace orelse return json(out, .{ .committed = true });
        if (session.length == 0) break;
        var step_arena = std.heap.ArenaAllocator.init(allocator);
        defer step_arena.deinit();
        const bundle = try q.Bundle.decode(step_arena.allocator(), session.bundle[0..session.length]);
        session.pending = try client.prepareNext(id, bundle);
        if (session.pending == null) break;
        _ = try submit(session, client, session.pending.?);
    }
    const id = session.namespace orelse return;
    const status = try client.status(id);
    try json(out, .{ .status = if (status) |value| try q.Bridge.Status.fromNative(allocator, value) else null });
}

/// Saved local state supports reconciliation, but never proves query completion.
pub fn savedDiagnostic(session: Session, cause: anyerror) !q.protocol.Diagnostic {
    const d = q.protocol.Diagnostic;
    if (session.pending == null and session.input == null and (session.namespace == null or session.complete)) return q.ApiDiagnostic.attempt("console", .read, null, cause, .{}, false, null);
    const has_intent = session.pending != null or session.length != 0;
    var value = try d.init("query.saved_work_unresolved", .lifecycle, .reconcile, if (session.input != null) .pending else .unknown, if (session.input != null) .native_receipt else if (has_intent) .saved_intent else .none, "The selected query's current outcome is not established. Inspect its status before starting new work; retain any original bundle and signed command for exact reconciliation.");
    value.cause = try d.Code.init(@errorName(cause));
    if (session.namespace) |id| {
        value.identity = .{ .domain = .query, .id = .init(id) };
    } else if (session.pending) |pending| {
        value.identity = .{ .domain = .transport, .id = .init(pending.signed.request.sequence), .realm = .init(pending.signed.request.realm), .sequence = .init(pending.signed.request.sequence) };
    }
    if (session.input) |input| try value.fact(.native_input, .authority, .{ .unsigned = .init(input) });
    try value.action(.inspect_status);
    if (value.identity != null) try value.action(.resume_exact);
    if (session.namespace != null) try value.action(.cancel_wait);
    try value.validate();
    return value;
}
