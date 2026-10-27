//! Server-managed captured queries reuse the Query owner's upload, execution,
//! cancellation and result contracts. Native ledger publication freezes every
//! compiled bundle and signed command before dispatch; token lookup never compiles.
const std = @import("std");
const g = @import("root.zig");
const q = g.query;
const f = g.fuze;
const api = g.session_protocol;
const ops = g.SessionOperations;
const ledger = g.CapturedLedger;
const saved = q.SavedSubmission;

pub fn load(host: *g.Session, id: u64) !ops.External {
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.ledger, &reader, id);
    if (item.kind != .captured or !std.meta.eql(item.binding(), try host.account.database(host.database))) return error.SqlOperationBindingChanged;
    const source = host.source orelse return error.UnknownSqlSource;
    if (!std.mem.eql(u8, &item.source, &source.fingerprint)) return error.SqlOperationBindingChanged;
    try source.current();
    return item;
}
pub fn select(host: *g.Session, id: u64) !void {
    var reader = try host.observer.source();
    const item = try ops.external(host.runtime.ledger, &reader, id);
    if (item.kind != .captured) return error.InvalidSqlOperationReference;
    for (host.account.sources) |*source| {
        if (!std.mem.eql(u8, source.database, host.database)) continue;
        const key = try q.wire.readKey(host.allocator, host.io, source.key_file);
        const fingerprint = try g.SourceSession.bindingFingerprint(host.allocator, source, key.public_key.toBytes());
        if (std.mem.eql(u8, &fingerprint, &item.source)) return host.selectSource(source.name);
    }
    try host.selectSource(null);
    return error.SqlOperationBindingChanged;
}
pub fn namespace(item: ops.External) !u64 {
    const id = std.mem.readInt(u64, item.original[0..8], .little);
    if (id == 0 or id > q.protocol.max_counter or !std.mem.allEqual(u8, item.original[8..], 0)) return error.InvalidQueryIdentity;
    return id;
}
fn state(host: *g.Session, id: u64) !ledger.State {
    var reader = try host.observer.source();
    return ledger.state(host.runtime.ledger, &reader, id);
}
fn bytes(host: *g.Session, id: u64, record: u64, maximum: usize) ![]u8 {
    var reader = try host.observer.source();
    return g.Upload.read(host.allocator, host.runtime.ledger.publication(id), &reader, record, maximum);
}
fn command(host: *g.Session, value: ledger.Command) !void {
    try host.current();
    try host.runtime.control(.{ .captured = value }, host.deadline);
}
fn publish(host: *g.Session, id: u64, record: u64, format: u32, content: []const u8) !void {
    const target: g.Control.Record = .{ .operation = id, .generation = host.account.generation, .record = record };
    try command(host, .{ .begin = .{ .target = target, .spec = try g.station.Publication.Digest.of(format, content) } });
    var offset: usize = 0;
    while (offset < content.len) {
        const count = @min(g.Upload.part_bytes, content.len - offset);
        try command(host, .{ .part = .{ .target = target, .part = try g.Control.Part.init(@intCast(offset), content[offset..][0..count]) } });
        offset += count;
    }
    try command(host, .{ .publish = target });
}
pub fn admit(host: *g.Session, prepared: *g.SourceSession.Prepared, values: []const ?f.Types.Values.Atom, token: api.Token, fingerprint: [32]u8) !api.Operation {
    try host.runtime.capture_mutex.lock(host.io);
    defer host.runtime.capture_mutex.unlock(host.io);
    if (try host.fresh(g.ConfigurationOperations.find, .{ host, token, @as(?[32]u8, fingerprint) })) |ref| return status(host, ref.id);
    const source = host.source orelse return error.UnknownSqlSource;
    var bound = try source.bind(prepared, values);
    defer bound.deinit();
    var original: [16]u8 = @splat(0);
    for (0..8) |_| {
        try host.io.randomSecure(original[0..8]);
        const id = std.mem.readInt(u64, original[0..8], .little) & q.protocol.max_counter;
        std.mem.writeInt(u64, original[0..8], id, .little);
        if (id != 0 and try host.fresh(q.UnifiedClient.status, .{ &source.client, id }) == null) break;
    } else return error.QueryUploadIdentityConflict;
    // Freeze the explicit Table cut and pin operation before publishing the
    // bundle. Authorization prepares a delegation; the source owns acquisition.
    // Recovery below reads these exact bytes and never captures current data.
    bound.bundle = if (bound.bundle.source.source == .table)
        try source.client.authorizeCurrent(bound.bundle, source.configuration.workspace.executor orelse return error.QuerySourceUnavailable, std.mem.readInt(u64, original[0..8], .little))
    else
        try source.client.authorizeBundle(bound.bundle);
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const compiled = try bound.bundle.encode(&buffer);
    try host.runtime.control(.{ .external_begin = .{ .nonce = token, .fingerprint = fingerprint, .kind = .captured, .binding = try host.account.database(host.database), .original = original, .source = source.fingerprint, .expected_generation = host.account.generation, .reservation = 1024 * 1024 } }, host.deadline);
    const reference = (try host.fresh(g.ConfigurationOperations.find, .{ host, token, @as(?[32]u8, fingerprint) })) orelse return error.MissingGatewayOperation;
    const item = try host.fresh(load, .{ host, reference.id });
    if (!std.mem.eql(u8, &item.original, &original)) return status(host, item.id);
    try publish(host, item.id, 1, q.Bundle.format, compiled);
    return status(host, item.id);
}
fn terminal(phase: q.UnifiedRequest.Phase) bool {
    return switch (phase) {
        .complete, .cancelled, .denied, .rejected, .retired => true,
        else => false,
    };
}
pub fn status(host: *g.Session, id: u64) !api.Operation {
    const item = try host.fresh(load, .{ host, id });
    const local = try host.fresh(state, .{ host, id });
    const current = try host.fresh(q.UnifiedClient.status, .{ &host.source.?.client, try namespace(item) });
    const cancelled_before_admission = local.cancel == 1 and local.pending == 0 and local.staging == 0 and current == null;
    const complete = cancelled_before_admission or local.rejected == 1 or (current != null and terminal(current.?.phase));
    const outcome: @FieldType(api.Operation, "outcome") = if (cancelled_before_admission) .cancelled else if (local.rejected == 1) .rejected else if (complete) switch (current.?.phase) {
        .complete => .applied,
        .cancelled, .retired => .cancelled,
        else => .rejected,
    } else null;
    if (item.phase == .terminal and !complete) return error.MissingCapturedQueryOutcome;
    return .{ .command = .capture, .identity = .{ .account = host.account.ledger.account, .id = id, .kind = .captured }, .token = item.nonce, .phase = if (complete) .terminal else if (item.phase == .reserved) .reserved else if (current) |value| switch (value.phase) {
        .uploading => .uploading,
        .sealed => .ready,
        else => .active,
    } else .ready, .blocked = item.phase == .reserved and outcome == null, .outcome = outcome, .cancellation_requested = local.cancel == 1, .owner_operation = item.original, .diagnostic = if (current) |value| if (value.failure) |failure| try failure.diagnostic(try namespace(item), value.phase) else null else null };
}
fn settle(host: *g.Session, id: u64, local: ledger.State) !void {
    const target: g.Control.Record = .{ .operation = id, .generation = host.account.generation, .record = local.pending };
    var input = local.input;
    if (input == 0) {
        const content = try host.fresh(bytes, .{ host, id, local.pending, @as(usize, saved.max_bytes) });
        defer host.allocator.free(content);
        const pending = try saved.decode(content);
        const source = host.source.?;
        try source.client.validate(pending);
        try q.protocol.Ed25519.Signature.fromBytes(pending.signed.signature).verify(&try q.protocol.Growth.digest(pending.signed.request), source.client.key.public_key);
        try host.current();
        input = (try source.client.submit(pending)).position;
        try command(host, .{ .receipt = .{ .target = target, .input = input } });
    }
    switch (try host.source.?.client.observe(input)) {
        .pending => {},
        .committed => try command(host, .{ .processed = .{ .target = target, .rejected = 0 } }),
        .rejected => try command(host, .{ .processed = .{ .target = target, .rejected = 1 } }),
    }
}
/// A pass performs at most one native step. No result wait occupies the shared
/// account lane, and bounded indexed recovery proceeds without an HTTP client.
pub fn resumeOperation(host: *g.Session, id: u64) !api.Operation {
    try host.runtime.capture_mutex.lock(host.io);
    defer host.runtime.capture_mutex.unlock(host.io);
    const item = try host.fresh(load, .{ host, id });
    if (item.phase == .terminal) return status(host, id);
    const local = try host.fresh(state, .{ host, id });
    if (local.pending != 0) {
        try settle(host, id, local);
        return status(host, id);
    }
    const observed = try status(host, id);
    if (observed.phase == .terminal) {
        try host.runtime.control(.{ .external_complete = .{ .operation = id, .generation = host.account.generation, .summary = switch (observed.outcome.?) {
            .applied => .applied,
            .cancelled => .cancelled,
            else => .rejected,
        } } }, host.deadline);
        return observed;
    }
    if (item.phase == .reserved) return observed;
    if (local.staging != 0) {
        try command(host, .{ .abandon = .{ .operation = id, .generation = host.account.generation, .record = local.staging } });
        return status(host, id);
    }
    var reader = try host.observer.source();
    if (try ledger.lane(&reader, item.source)) |owner| if (owner != id) return observed;
    const source = host.source.?;
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    defer arena.deinit();
    const content = try host.fresh(bytes, .{ host, id, @as(u64, 1), @as(usize, q.Bundle.max_bytes) });
    defer host.allocator.free(content);
    const bundle = try q.Bundle.decode(arena.allocator(), content);
    if (!std.mem.eql(u8, &try bundle.source.fingerprint(), &try source.definition.fingerprint())) return error.SqlOperationBindingChanged;
    // Cancellation first settles any published command. Once requested it
    // never resumes the upload or submits a new query execution.
    const pending = if (local.cancel == 1) try source.client.prepare(.{ .cancel = try namespace(item) }) else (try source.client.prepareNext(try namespace(item), bundle)) orelse return observed;
    var storage: [saved.max_bytes]u8 = undefined;
    try publish(host, id, local.records + 1, saved.format, try saved.encode(pending, &storage));
    try settle(host, id, try host.fresh(state, .{ host, id }));
    return status(host, id);
}
pub fn cancel(host: *g.Session, id: u64) !api.Operation {
    _ = try host.fresh(load, .{ host, id });
    try command(host, .{ .cancel = .{ .operation = id, .generation = host.account.generation } });
    return status(host, id);
}

pub const Prepared = struct {
    id: u64,
    namespace: u64,
    arena: std.heap.ArenaAllocator,
    bundle: q.Bundle,
    output: f.Types.Decoded,
    pub fn deinit(self: *Prepared) void {
        self.output.deinit();
        self.arena.deinit();
    }
};
pub fn prepareResult(host: *g.Session, id: u64) !Prepared {
    const item = try host.fresh(load, .{ host, id });
    const observed = try status(host, id);
    if (observed.phase != .terminal or observed.outcome != .applied) return error.IncompleteResult;
    const content = try host.fresh(bytes, .{ host, id, @as(u64, 1), @as(usize, q.Bundle.max_bytes) });
    defer host.allocator.free(content);
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const bundle = try q.Bundle.decode(arena.allocator(), content);
    var fields: [q.SourceDefinition.max_columns]f.Types.Field = undefined;
    return .{ .id = id, .namespace = try namespace(item), .arena = arena, .bundle = bundle, .output = try (try bundle.plan.outputSchema(&fields)).clone(host.allocator) };
}
pub fn validateResult(host: *g.Session, prepared: *Prepared) !void {
    _ = try host.fresh(load, .{ host, prepared.id });
    _ = try host.fresh(q.UnifiedClient.authorize, .{ &host.source.?.client, prepared.bundle.source });
    const observed = try status(host, prepared.id);
    if (observed.phase != .terminal or observed.outcome != .applied) return error.IncompleteResult;
}
pub const Read = struct {
    host: *g.Session,
    prepared: *Prepared,
    arena: std.heap.ArenaAllocator,
    page_arena: std.heap.ArenaAllocator,
    workspace: []u8,
    arrow: []u8,
    decoded: ?f.LogicalInspect.Batch = null,
    index: usize = 0,
    cursor: ?q.UnifiedResult.Cursor = null,
    complete: bool = false,
    basis: ?q.Basis = null,
    pub fn init(host: *g.Session, prepared: *Prepared) !Read {
        try validateResult(host, prepared);
        var arena: std.heap.ArenaAllocator = .init(host.allocator);
        errdefer arena.deinit();
        const workspace = try arena.allocator().alloc(u8, f.LogicalArrow.working_bytes);
        const arrow = try arena.allocator().alloc(u8, f.LogicalArrow.segment_bytes);
        return .{ .host = host, .prepared = prepared, .arena = arena, .page_arena = .init(host.allocator), .workspace = workspace, .arrow = arrow };
    }
    pub fn deinit(self: *Read) void {
        if (self.decoded) |*decoded| decoded.deinit();
        self.page_arena.deinit();
        self.arena.deinit();
    }
    fn page(self: *Read) !q.UnifiedResult.Page {
        // A retained page is addressed by the original manifest and cursor.
        // Repeating its reads cannot execute SQL or advance that cursor. Drop
        // all failed-attempt allocations before retrying current authorization
        // and the same immutable page; publish progress only after validation.
        _ = self.page_arena.reset(.free_all);
        self.decoded = @as(f.LogicalInspect.Batch, undefined);
        return self.host.source.?.client.page(self.prepared.namespace, self.cursor, self.page_arena.allocator(), self.workspace, self.arrow, &self.decoded.?) catch |err| {
            // page owns error cleanup; only a successful decode is live.
            self.decoded = null;
            return err;
        };
    }
    pub fn next(self: *Read, maximum: u8) !g.ReadBatch {
        try validateResult(self.host, self.prepared);
        var result: g.ReadBatch = .{};
        while (self.decoded == null or self.index == self.decoded.?.rows.len) {
            if (self.decoded) |*decoded| decoded.deinit();
            self.decoded = null;
            self.index = 0;
            _ = self.page_arena.reset(.free_all);
            if (self.complete) {
                result.complete = true;
                return result;
            }
            const acquired = try self.host.fresh(page, .{self});
            self.cursor = acquired.next;
            self.basis = acquired.basis;
            self.complete = acquired.next == null;
        }
        const count = @min(maximum, self.decoded.?.rows.len - self.index);
        for (result.rows[0..count], self.decoded.?.rows[self.index..][0..count]) |*to, row| to.* = row.cells;
        self.index += count;
        result.len = @intCast(count);
        result.complete = self.complete and self.index == self.decoded.?.rows.len;
        return result;
    }
};
