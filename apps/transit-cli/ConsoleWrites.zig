//! General catalog writes with immutable saved intent and exact native recovery.
const std = @import("std");
const Timing = @import("Timing.zig");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Recovery = @import("TableRecovery.zig");
const Self = @This();
pub const Config = struct { recovery_file: []const u8 };
io: std.Io,
allocator: std.mem.Allocator,
catalog: c.TableClient,
storage: Recovery,
read_deadline: ?i64 = null,

pub fn validateConfig(config: Config) !void {
    if (config.recovery_file.len == 0) return error.InvalidWriteConfiguration;
}
pub fn open(init: std.process.Init, path: []const u8, client: *c.TableClient) !Self {
    return .{ .io = init.io, .allocator = init.gpa, .catalog = client.*, .storage = try Recovery.open(init.io, init.gpa, path, client) };
}
pub fn close(self: *Self) void {
    self.storage.close();
    std.crypto.secureZero(u8, std.mem.asBytes(&self.catalog.key));
}
pub fn unresolved(self: *const Self) bool {
    return self.storage.unresolved();
}
fn save(self: *Self, timing: ?*Timing) !void {
    const previous = if (timing) |clock| clock.phase else null;
    if (timing) |clock| clock.enter(.persist);
    defer if (timing) |clock| clock.enter(previous.?);
    try self.storage.save(&self.catalog);
}
fn identity(io: std.Io) !u64 {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    return @max(1, std.mem.readInt(u64, &bytes, .little));
}
pub fn describe(self: *Self, console: *Console) !void {
    return @import("ConsoleCatalog.zig").inspect(console, &self.catalog, null);
}
pub fn start(self: *Self, console: *Console, text: []const u8, route: q.fuze.SqlDiagnostic.Route) !void {
    if (self.unresolved() or console.session.pending != null or console.session.input != null or (console.session.namespace != null and !console.session.complete)) return error.UnresolvedSubmission;
    console.write_preparing = true;
    var timing = Timing.start(console.init, console.preferences.timing);
    defer console.finishTiming(&timing);
    self.read_deadline = std.Io.Clock.boot.now(self.io).toMilliseconds() + 300000;
    defer self.read_deadline = null;
    timing.enter(.compile);
    var arena: std.heap.ArenaAllocator = .init(self.allocator);
    defer arena.deinit();
    var location: q.fuze.Sql.Location = .{};
    const ddl = if (route == .declaration) q.fuze.TableDdl.target(arena.allocator(), text) catch |err| {
        console.diagnostic.sql = q.fuze.SqlDiagnostic.tableDdl(text, err, location);
        return err;
    } else null;
    const ids: c.TableClient.CompileIdentity = .{ .operation = try identity(self.io), .namespace = try identity(self.io), .create_object = if (ddl != null and ddl.?.kind == .create) try identity(self.io) else null };
    var intent = self.readOnly(c.TableClient.compile, .{ &self.catalog, self.allocator, text, ids, &location }) catch |err| {
        console.diagnostic.sql = if (route == .declaration) q.fuze.SqlDiagnostic.tableDdl(text, err, location) else q.fuze.SqlDiagnostic.tableDml(text, err, location);
        return err;
    };
    defer intent.deinit();
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    timing.enter(.prepare);
    // A preparation denial has no transport uncertainty and must not install
    // active recovery work. Persist the first exact command before dispatch.
    const first = try self.readOnly(c.TableClient.next, .{ &self.catalog, &intent });
    timing.enter(.persist);
    try self.storage.install(&self.catalog, &intent);
    if (first == .send) {
        self.storage.record.pending = first.send;
        try self.save(&timing);
    }
    console.write_preparing = false;
    try self.advance(console, &timing, false);
}
fn check(self: *Self, deadline: i64) !void {
    if (self.storage.failed) return error.ConsoleRecoveryWriteFailed;
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    if (std.Io.Clock.boot.now(self.io).toMilliseconds() >= deadline) return error.WriteWaitTimedOut;
}
// Only current reads/local preparation belong here. Captured query scans,
// native sends, persistence and rendering must never enter this retry loop.
fn readOnly(self: *Self, comptime read: anytype, args: std.meta.ArgsTuple(@TypeOf(read))) anyerror!@typeInfo(@typeInfo(@TypeOf(read)).@"fn".return_type.?).error_union.payload {
    while (true) {
        if (self.read_deadline) |deadline| try self.check(deadline);
        return @call(.auto, read, args) catch |err| {
            const stale = (err == error.Rejected or err == error.Conflict) and self.catalog.transport.last_rejection == .StaleStateResource;
            if (self.read_deadline == null or (!q.wire.Client.unavailable(err) and !stale)) return err;
            try self.io.sleep(.fromMilliseconds(if (stale) 1 else 50), .awake);
            continue;
        };
    }
}
pub fn recover(self: *Self, console: *Console) !void {
    var timing = Timing.start(console.init, console.preferences.timing);
    defer console.finishTiming(&timing);
    if (self.storage.record.complete) {
        _ = try self.statusTimed(console, &timing);
        return;
    }
    try self.advance(console, &timing, true);
}
fn advance(self: *Self, console: *Console, timing: *Timing, resuming: bool) !void {
    const work = if (self.storage.intent) |*value| value else return error.NoSavedWrite;
    const record = &self.storage.record;
    const deadline = self.read_deadline orelse std.Io.Clock.boot.now(self.io).toMilliseconds() + 300000;
    self.read_deadline = deadline;
    defer self.read_deadline = null;
    var resume_once = resuming;
    while (true) {
        try self.check(deadline);
        if (record.pending) |pending| {
            if (record.input == null) {
                timing.enter(.submit);
                record.input = (try self.catalog.submit(pending)).position;
                try self.save(timing);
            }
            timing.enter(.wait);
            const progress = try self.readOnly(c.TableClient.waitProgress, .{ &self.catalog, work, pending, record.input.? });
            if (progress == .pending) continue;
            const current = progress.processed;
            if (current.outcome) |result| if (result.terminal()) return self.finish(console, timing, result, current.disposition);
            if (current.upload) |upload| if (upload.phase == .cancelled and current.outcome == null) {
                record.complete = true;
                try self.save(timing);
                _ = try self.statusTimed(console, timing);
                return;
            };
            if (current.disposition) |disposition| {
                // Rejecting one continuation never closes an accepted operation.
                record.complete = current.outcome == null and current.upload == null;
                try self.save(timing);
                if (!resume_once or record.complete) {
                    console.diagnostic.write = try @import("WriteDiagnostic.zig").tableInput(disposition, !record.complete);
                    if (console.session.format == .json) _ = try self.statusTimed(console, timing);
                    return error.MutationInputRejected;
                }
            }
            record.pending = null;
            record.input = null;
            try self.save(timing);
        }
        timing.enter(.prepare);
        if (record.cancelling) {
            const current = try self.readOnly(c.TableClient.inspectIntent, .{ &self.catalog, work });
            if (current.outcome) |result| if (result.terminal()) return self.finish(console, timing, result, null);
            if (current.outcome == null and current.upload == null) {
                // All saved sends were reconciled above. This current cut has
                // no admitted SQL/upload, so only private intent is withdrawn.
                record.complete = true;
                try self.save(timing);
                try self.emit(console, current, null);
                return;
            }
            if (current.upload) |upload| if (upload.phase == .cancelled and current.outcome == null) {
                record.complete = true;
                try self.save(timing);
                _ = try self.statusTimed(console, timing);
                return;
            };
            const control: c.TableControl.Command = if (current.upload != null) .{ .cancel_upload = work.upload() } else switch (work.identity) {
                .ddl => |ref| .{ .cancel_ddl = ref },
                .dml => |ref| .{ .cancel_dml = .{ .scope = work.header.scope, .reference = ref.reference } },
            };
            record.pending = try self.readOnly(c.TableClient.prepareControl, .{ &self.catalog, control });
        } else switch (try self.readOnly(c.TableClient.next, .{ &self.catalog, work })) {
            .send => |pending| record.pending = pending,
            .terminal => |result| return self.finish(console, timing, result, null),
            .upload_cancelled => {
                record.complete = true;
                try self.save(timing);
                _ = try self.statusTimed(console, timing);
                return;
            },
            .running => {
                if (resume_once) {
                    record.pending = try self.readOnly(c.TableClient.prepareResume, .{ &self.catalog, work });
                    resume_once = false;
                } else {
                    timing.enter(.wait);
                    try self.readOnly(c.TableClient.waitForChange, .{ &self.catalog, work });
                    continue;
                }
            },
        }
        record.input = null;
        try self.save(timing);
    }
}
fn finish(self: *Self, console: *Console, timing: *Timing, outcome: c.TableClient.Outcome, disposition: ?c.TableControl.Disposition) !void {
    if (!outcome.terminal()) return error.InvalidConsoleRecovery;
    self.storage.record.complete = true;
    try self.save(timing);
    timing.enter(.render);
    const detail = try @import("WriteDiagnostic.zig").tableOutcome(self.allocator, &self.storage.intent.?, outcome);
    if (disposition) |value| {
        console.diagnostic.write = try @import("WriteDiagnostic.zig").tableInput(value, false);
    } else console.diagnostic.write = detail;
    if (console.session.format == .json or console.diagnostic.write == null) try self.emit(console, .{ .outcome = outcome, .upload = null }, disposition);
    if (disposition != null) return error.MutationInputRejected;
    if (detail != null) return error.MutationRejected;
}
pub fn cancel(self: *Self, console: *Console) !void {
    if (self.storage.intent == null) return error.NoSavedWrite;
    if (self.storage.record.complete) {
        _ = try self.status(console);
        return;
    }
    self.storage.record.cancelling = true;
    try self.save(null);
    try self.recover(console);
}
pub fn clearComplete(self: *Self) !void {
    try self.storage.clearComplete(&self.catalog);
}
pub fn status(self: *Self, console: *Console) !bool {
    return self.statusTimed(console, null);
}
fn statusTimed(self: *Self, console: *Console, timing: ?*Timing) !bool {
    const intent = if (self.storage.intent) |*value| value else return false;
    if (timing) |clock| clock.enter(.fetch);
    // No preparation or submission. Status alone cannot settle an uncertain
    // transport step, even when an original terminal SQL outcome is visible.
    const current = try self.readOnly(c.TableClient.inspectIntent, .{ &self.catalog, intent });
    const disposition = if (self.storage.record.input) |input| try self.readOnly(c.TableClient.inputDisposition, .{ &self.catalog, self.storage.record.pending.?, input }) else null;
    if (timing) |clock| clock.enter(.render);
    try self.emit(console, current, disposition);
    return true;
}
fn emit(self: *Self, console: *Console, current: c.TableClient.State, disposition: ?c.TableControl.Disposition) !void {
    const intent = &self.storage.intent.?;
    const uncertain = self.storage.record.pending != null and self.storage.record.input == null;
    const current_phase = if (current.outcome == null and current.upload == null and self.storage.record.complete and self.storage.record.cancelling and self.storage.record.pending == null) "withdrawn_before_admission" else phase(current);
    var buffer: [32768]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    if (console.session.format == .json) {
        var id: [20]u8 = undefined;
        var object: [20]u8 = undefined;
        var matched: [20]u8 = undefined;
        var changed: [20]u8 = undefined;
        const counts = if (current.outcome) |value| if (value == .dml and value.dml.state == .applied) .{ .matched = try std.fmt.bufPrint(&matched, "{d}", .{value.dml.matched}), .changed = try std.fmt.bufPrint(&changed, "{d}", .{value.dml.changed}) } else null else null;
        try std.json.Stringify.value(.{ .table_operation = .{ .id = try std.fmt.bufPrint(&id, "{d}", .{intent.header.operation}), .object = try std.fmt.bufPrint(&object, "{d}", .{intent.header.object}), .kind = @tagName(intent.header.kind), .phase = current_phase, .counts = counts, .diagnostic = if (current.outcome) |value| try c.TableDiagnostic.status(intent, value) else null, .input_disposition = if (disposition) |value| @tagName(value.outcome) else null, .input_diagnostic = if (disposition) |value| try c.TableDiagnostic.input(value) else null, .uncertain = uncertain } }, .{}, &out);
        try out.writeByte('\n');
    } else {
        if (disposition) |value| try (try @import("WriteDiagnostic.zig").tableInput(value, current.outcome != null and !current.outcome.?.terminal())).render(&out, console.diagnostic.style);
        if (current.outcome) |value| {
            if (try @import("WriteDiagnostic.zig").tableOutcome(self.allocator, intent, value)) |detail| {
                try detail.render(&out, console.diagnostic.style);
            } else if (value == .dml and value.dml.state == .applied) {
                try out.print("{d} {s} affected", .{ value.dml.changed, if (value.dml.changed == 1) "row" else "rows" });
                if (value.dml.matched != value.dml.changed) try out.print(" ({d} matched)", .{value.dml.matched});
                try out.writeByte('\n');
            } else try out.print("{s}: {s}\n", .{ @tagName(intent.header.kind), phase(current) });
        } else try out.print("{s}: {s}; uncertain send: {s}\n", .{ @tagName(intent.header.kind), current_phase, if (uncertain) "yes" else "no" });
        if (uncertain and current.outcome != null) try out.writeAll("The saved transport command still needs exact reconciliation. Use .resume.\n");
    }
    try @import("Output.zig").write(console.init, console.out, out.buffered());
}
fn phase(current: c.TableClient.State) []const u8 {
    if (current.outcome) |value| return switch (value) {
        .ddl => |ddl| if (ddl.table) |table| @tagName(table.state) else @tagName(ddl.operation.state),
        .dml => |dml| @tagName(dml.state),
    };
    return if (current.upload) |upload| @tagName(upload.phase) else "unconfirmed";
}
pub fn unresolvedDiagnostic(self: Self, cause: anyerror) !q.protocol.Diagnostic {
    if (!self.unresolved()) return error.NoSavedWrite;
    const intent = &self.storage.intent.?;
    const d = q.protocol.Diagnostic;
    var value = try d.init("write.saved_work_unresolved", .lifecycle, .reconcile, .unknown, .saved_intent, "The saved Table operation needs reconciliation. Preserve its recovery files; do not repeat the SQL or replace its operation identity.");
    value.cause = try d.Code.init(@errorName(cause));
    value.identity = .{ .domain = if (intent.identity == .ddl) .catalog else .mutation, .id = .init(intent.header.operation), .realm = .init(intent.header.scope.realm), .resource = .init(intent.header.scope.resource) };
    if (self.catalog.transport.last_rejection) |native| try value.text(.native_cause, .authority, @tagName(native));
    try value.action(.inspect_status);
    try value.action(.resume_exact);
    try value.action(.cancel_mutation);
    try value.validate();
    return value;
}
