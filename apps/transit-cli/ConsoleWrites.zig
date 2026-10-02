//! Console composition of the existing signed write clients. Persist before
//! sending; admission, processed input and terminal outcome remain distinct.
const std = @import("std");
const Timing = @import("Timing.zig");
const q = @import("transit_query");
const c = @import("transit_catalog");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const g = q.protocol.Growth;
const Self = @This();
pub const Config = struct {
    recovery_file: []const u8,
    table: ?struct { name: []const u8, connection: q.TableMutationClient.Connection } = null,
    catalog: ?c.Client.Connection = null,
};
const Mutation = struct {
    namespace: u64,
    request: q.TableMutationRequest,
    pending: ?q.TableMutationClient.Prepared,
    input: ?u64,
};
const Creation = struct { request: c.Model.CreateTable, pending: c.Client.Prepared, input: ?u64 };
const Operation = union(enum) { mutation: Mutation, creation: Creation };
const Record = struct {
    version: u8,
    definition: g.Definition,
    key: [32]u8,
    table: ?q.TableMutationClient.Connection,
    name: ?q.fuze.model.Name,
    catalog: ?c.Client.Connection,
    operation: ?Operation,
    complete: bool,
    cancelling: bool,
};
io: std.Io,
allocator: std.mem.Allocator,
path: []const u8,
lock: std.Io.File,
record: Record,
mutation: ?q.TableMutationClient,
catalog: ?c.Client,
failed: bool = false,
read_deadline: ?i64 = null,

pub fn validateConfig(config: Config, connection: q.UnifiedClient.Connection) !void {
    if (config.recovery_file.len == 0 or (config.table == null and config.catalog == null)) return error.InvalidWriteConfiguration;
    if (config.table) |table| {
        _ = try q.fuze.model.Name.init(table.name);
        try table.connection.validate();
        if (table.connection.realm != connection.realm or table.connection.principal != connection.principal) return error.InvalidWriteConfiguration;
    }
    if (config.catalog) |catalog| {
        try catalog.validate();
        if (catalog.scope.realm != connection.realm or catalog.principal != connection.principal) return error.InvalidWriteConfiguration;
    }
}
pub fn open(init: std.process.Init, path: []const u8, config: Config, client: *q.UnifiedClient) !Self {
    const lock_path = try std.fmt.allocPrint(init.gpa, "{s}.lock", .{path});
    defer init.gpa.free(lock_path);
    const lock = try std.Io.Dir.cwd().createFile(init.io, lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(init.io);
    if (!try lock.tryLock(init.io, .exclusive)) return error.ConsoleRecoveryInUse;
    var self: Self = .{
        .io = init.io,
        .allocator = init.gpa,
        .path = path,
        .lock = lock,
        .mutation = if (config.table) |table| .{ .wire = client.wire, .connection = table.connection, .key = client.key } else null,
        .catalog = if (config.catalog) |catalog| .{ .transport = client.wire, .connection = catalog, .key = client.key } else null,
        .record = .{ .version = 1, .definition = g.current_definition, .key = client.key.public_key.toBytes(), .table = if (config.table) |table| table.connection else null, .name = if (config.table) |table| try q.fuze.model.Name.init(table.name) else null, .catalog = config.catalog, .operation = null, .complete = false, .cancelling = false },
    };
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(32768)) catch |err| {
        if (err == error.FileNotFound) return self;
        return err;
    };
    defer {
        std.crypto.secureZero(u8, bytes);
        init.gpa.free(bytes);
    }
    const parsed = try std.json.parseFromSlice(Record, init.gpa, bytes, .{});
    defer parsed.deinit();
    const record = parsed.value;
    if (record.version != 1 or !std.meta.eql(record.definition, g.current_definition) or !std.meta.eql(record.key, self.record.key) or !std.meta.eql(record.table, self.record.table) or !std.meta.eql(record.name, self.record.name) or !std.meta.eql(record.catalog, self.record.catalog)) return error.ConsoleRecoveryIdentityMismatch;
    if (record.operation) |operation| switch (operation) {
        .mutation => |value| {
            const writer = if (self.mutation) |*writer| writer else return error.InvalidConsoleRecovery;
            try value.request.validate();
            const target = writer.connection;
            if (value.request.realm != target.realm or value.request.writer != target.writer or value.request.resource != target.resource or value.request.table != target.table) return error.InvalidConsoleRecovery;
            const reference = try value.request.reference(value.namespace);
            if (value.input == 0 or (value.input != null and value.pending == null)) return error.InvalidConsoleRecovery;
            if (value.pending) |pending| {
                if (!std.meta.eql(pending.definition, g.current_definition)) return error.InvalidConsoleRecovery;
                try writer.validate(pending);
                const frame = try q.station.Frame.decode(pending.signed.request.command.send.value);
                const command = try q.TableMutationRecords.Command.decode(&frame.payload);
                const saved_reference = switch (command) {
                    .execute => |v| try v.request.reference(v.namespace),
                    .begin => |v| v.reference,
                    .part => |v| v.reference,
                    .seal, .apply, .cancel => |v| v,
                };
                if (!std.meta.eql(reference, saved_reference)) return error.InvalidConsoleRecovery;
            }
        },
        .creation => |value| {
            const catalog = if (self.catalog) |*catalog| catalog else return error.InvalidConsoleRecovery;
            if (value.input == 0 or record.cancelling or !std.meta.eql(value.pending.definition, g.current_definition)) return error.InvalidConsoleRecovery;
            try catalog.validate(value.pending);
            if (!std.meta.eql(try value.pending.request(), value.request)) return error.InvalidConsoleRecovery;
        },
    } else if (record.complete or record.cancelling) return error.InvalidConsoleRecovery;
    // Native types have convenience defaults. Saved recovery cannot use them:
    // require every nested compatibility field and the exact canonical shape.
    const canonical = try std.json.Stringify.valueAlloc(init.gpa, record, .{});
    defer {
        std.crypto.secureZero(u8, canonical);
        init.gpa.free(canonical);
    }
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidConsoleRecovery;
    self.record = record;
    return self;
}
pub fn close(self: *Self) void {
    self.lock.close(self.io);
    if (self.mutation) |*client| std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    if (self.catalog) |*client| std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    std.crypto.secureZero(u8, std.mem.asBytes(&self.record));
}
pub fn unresolved(self: *const Self) bool {
    return self.record.operation != null and !self.record.complete;
}
fn save(self: *Self) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    errdefer self.failed = true;
    const bytes = try std.json.Stringify.valueAlloc(self.allocator, self.record, .{});
    defer {
        std.crypto.secureZero(u8, bytes);
        self.allocator.free(bytes);
    }
    if (bytes.len > 32768) return error.ConsoleRecoveryTooLarge;
    const parent = try std.Io.Dir.cwd().openDir(self.io, std.fs.path.dirname(self.path) orelse ".", .{ .iterate = true });
    defer parent.close(self.io);
    var file = try parent.createFileAtomic(self.io, std.fs.path.basename(self.path), .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(self.io);
    try file.file.writeStreamingAll(self.io, bytes);
    try file.file.sync(self.io);
    try file.replace(self.io);
    if (std.c.fsync(parent.handle) != 0) return error.ConsoleRecoverySyncFailed;
}
fn saveTimed(self: *Self, timing: *Timing) !void {
    const previous = timing.phase;
    timing.enter(.persist);
    defer timing.enter(previous);
    try self.save();
}
fn identity(io: std.Io) !u64 {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    return @max(1, std.mem.readInt(u64, &bytes, .little));
}
pub fn start(self: *Self, console: *Console, text: []const u8, route: q.fuze.SqlDiagnostic.Route) !void {
    if (self.unresolved() or console.session.pending != null or console.session.input != null or (console.session.namespace != null and !console.session.complete)) return error.UnresolvedSubmission;
    var timing = @import("Timing.zig").start(console.init, console.preferences.timing);
    defer console.finishTiming(&timing);
    self.read_deadline = std.Io.Clock.boot.now(self.io).toMilliseconds() + 300000;
    defer self.read_deadline = null;
    timing.enter(.prepare);
    const operation: Operation = switch (route) {
        .mutation => mutation: {
            const writer = if (self.mutation) |*client| client else return error.ConsoleWriterRequired;
            const description = try self.readOnly(q.TableMutationClient.describe, .{writer});
            timing.enter(.compile);
            const request = q.TableMutationRequest.fromSql(writer.connection.realm, writer.connection.writer, description.table, self.record.name.?, text) catch |err| return console.sqlFailure(text, err);
            if (!description.policy.permits(request.plan.operation)) return error.MutationDenied;
            timing.enter(.prepare);
            const namespace = try identity(self.io);
            // A collision is a conflict, never adoption of somebody else's work.
            if (try self.readOnly(q.TableMutationClient.status, .{ writer, try request.reference(namespace) }) != null) return error.MutationIdentityConflict;
            const pending = (try self.readOnly(q.TableMutationClient.prepareNext, .{ writer, namespace, request })) orelse return error.MutationIdentityConflict;
            break :mutation .{ .mutation = .{ .namespace = namespace, .request = request, .pending = pending, .input = null } };
        },
        .declaration => creation: {
            const catalog = if (self.catalog) |*client| client else return error.ConsoleCatalogRequired;
            timing.enter(.compile);
            const request = c.Model.CreateTable.compile(catalog.connection.scope, try identity(self.io), try identity(self.io), @intCast((try identity(self.io) % std.math.maxInt(u32)) + 1), text) catch |err| return console.sqlFailure(text, err);
            timing.enter(.prepare);
            const pending = try self.readOnly(c.Client.prepareCreate, .{ catalog, request });
            break :creation .{ .creation = .{ .request = request, .pending = pending, .input = null } };
        },
        else => unreachable,
    };
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    self.record.operation = operation;
    self.record.complete = false;
    self.record.cancelling = false;
    try self.saveTimed(&timing);
    try self.advance(console, &timing);
}
fn check(self: *Self, deadline: i64) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    if (std.Io.Clock.boot.now(self.io).toMilliseconds() >= deadline) return error.WriteWaitTimedOut;
}
// Only current reads/local preparation belong here, never submit, persistence
// or rendering. An acknowledged input can be observed again without replaying it.
fn readOnly(self: *Self, comptime read: anytype, args: std.meta.ArgsTuple(@TypeOf(read))) anyerror!@typeInfo(@typeInfo(@TypeOf(read)).@"fn".return_type.?).error_union.payload {
    while (true) {
        if (self.read_deadline) |deadline| try self.check(deadline);
        return @call(.auto, read, args) catch |err| {
            if (self.read_deadline == null or !q.wire.Client.unavailable(err)) return err;
            try self.io.sleep(.fromMilliseconds(50), .awake);
            continue;
        };
    }
}
test "write observation retries only unavailable reads within its original deadline" {
    const Probe = struct {
        calls: usize = 0,
        failure: anyerror = error.AuthorityUnavailable,
        fn read(self: *@This()) anyerror!u8 {
            self.calls += 1;
            if (self.calls == 1) return self.failure;
            return 42;
        }
    };
    var self: Self = .{
        .io = std.testing.io,
        .allocator = std.testing.allocator,
        .path = "",
        .lock = undefined,
        .record = undefined,
        .mutation = null,
        .catalog = null,
        .read_deadline = std.math.maxInt(i64),
    };
    var probe: Probe = .{};
    try std.testing.expectEqual(@as(u8, 42), try self.readOnly(Probe.read, .{&probe}));
    try std.testing.expectEqual(@as(usize, 2), probe.calls);
    for ([_]anyerror{ error.AccessDenied, error.InvalidAuthorityResponse, error.Conflict }) |failure| {
        probe = .{ .failure = failure };
        try std.testing.expectError(failure, self.readOnly(Probe.read, .{&probe}));
        try std.testing.expectEqual(@as(usize, 1), probe.calls);
    }
    self.read_deadline = 0;
    probe = .{};
    try std.testing.expectError(error.WriteWaitTimedOut, self.readOnly(Probe.read, .{&probe}));
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    self.read_deadline = null;
    try std.testing.expectError(error.AuthorityUnavailable, self.readOnly(Probe.read, .{&probe}));
    try std.testing.expectEqual(@as(usize, 1), probe.calls);
}
pub fn recover(self: *Self, console: *Console) !void {
    var timing = @import("Timing.zig").start(console.init, console.preferences.timing);
    defer console.finishTiming(&timing);
    try self.advance(console, &timing);
}
fn advance(self: *Self, console: *Console, timing: *Timing) !void {
    const deadline = self.read_deadline orelse std.Io.Clock.boot.now(self.io).toMilliseconds() + 300000;
    if (self.record.operation == null) return error.NoSavedWrite;
    self.read_deadline = deadline;
    defer self.read_deadline = null;
    while (true) {
        try self.check(deadline);
        switch (self.record.operation.?) {
            .mutation => |*value| {
                const writer = &self.mutation.?;
                if (value.pending) |pending| {
                    if (value.input == null) {
                        timing.enter(.submit);
                        value.input = (try writer.submit(pending)).position;
                        try self.saveTimed(timing);
                    }
                    timing.enter(.wait);
                    if (try self.readOnly(q.TableMutationClient.observe, .{ writer, pending, value.input.? }) == .pending) {
                        try self.io.sleep(.fromMilliseconds(50), .awake);
                        continue;
                    }
                    timing.enter(.fetch);
                    if (try self.readOnly(q.TableMutationClient.rejection, .{ writer, pending, value.input.? })) |_| {
                        // Keep the frozen command and input for current-authorized
                        // inspection of the rejection on subsequent .status.
                        const current = try self.readOnly(q.TableMutationClient.status, .{ writer, try value.request.reference(value.namespace) });
                        // An input rejection is not a terminal mutation. Keep an
                        // active upload recoverable, including explicit cancel.
                        if (current == null or current.?.terminal() or !self.record.cancelling) {
                            self.record.complete = current == null or current.?.terminal();
                            try self.saveTimed(timing);
                            _ = try self.statusTimed(console, timing);
                            return error.MutationInputRejected;
                        }
                    }
                    value.pending = null;
                    value.input = null;
                    try self.saveTimed(timing);
                }
                const reference = try value.request.reference(value.namespace);
                timing.enter(.prepare);
                // prepareNext already batches the full terminal status with the
                // metadata needed for a successor. Avoid a separate status read
                // on every intermediate upload command.
                value.pending = if (self.record.cancelling) cancel: {
                    timing.enter(.fetch);
                    const outcome = try self.readOnly(q.TableMutationClient.status, .{ writer, reference });
                    timing.enter(.prepare);
                    break :cancel if (outcome != null and outcome.?.terminal()) null else try self.readOnly(q.TableMutationClient.prepare, .{ writer, .{ .cancel = reference } });
                } else try self.readOnly(q.TableMutationClient.prepareNext, .{ writer, value.namespace, value.request });
                if (value.pending == null) {
                    timing.enter(.fetch);
                    const outcome = (try self.readOnly(q.TableMutationClient.status, .{ writer, reference })) orelse return error.InvalidConsoleRecovery;
                    if (!outcome.terminal()) return error.InvalidConsoleRecovery;
                    self.record.complete = true;
                    try self.saveTimed(timing);
                    _ = try self.statusTimed(console, timing);
                    if (outcome.phase == .rejected) return error.MutationRejected;
                    return;
                }
                try self.saveTimed(timing);
            },
            .creation => |*value| {
                const catalog = &self.catalog.?;
                if (value.input == null) {
                    timing.enter(.submit);
                    value.input = (try catalog.submit(value.pending)).position;
                    try self.saveTimed(timing);
                }
                timing.enter(.wait);
                if (try self.readOnly(c.Client.observe, .{ catalog, value.pending, value.input.? }) == .pending) {
                    try self.io.sleep(.fromMilliseconds(50), .awake);
                    continue;
                }
                timing.enter(.fetch);
                const disposition = try self.readOnly(c.Client.inputDisposition, .{ catalog, value.pending, value.input.? });
                const receipt = if (disposition == null) try self.readOnly(c.Client.status, .{ catalog, value.request }) else null;
                if (receipt == null and disposition == null) return error.CatalogOutcomeMissing;
                self.record.complete = true;
                try self.saveTimed(timing);
                _ = try self.statusTimed(console, timing);
                if (disposition != null or receipt.?.outcome != .applied) return error.CatalogCreateRejected;
                return;
            },
        }
    }
}
pub fn cancel(self: *Self, console: *Console) !void {
    const operation = self.record.operation orelse return error.NoSavedWrite;
    if (operation == .creation) return error.CatalogCancellationUnsupported;
    self.record.cancelling = true;
    try self.save();
    try self.recover(console);
}
/// Observation only. Opening a console and .status never retry signed work.
pub fn status(self: *Self, console: *Console) !bool {
    return self.statusTimed(console, null);
}
fn statusTimed(self: *Self, console: *Console, timing: ?*Timing) !bool {
    if (timing) |clock| clock.enter(.fetch);
    var buffer: [4096]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    const destination = console.out;
    console.out = &out;
    defer console.out = destination;
    const found = try self.statusInto(console);
    if (timing) |clock| clock.enter(.render);
    try @import("Output.zig").write(console.init, destination, out.buffered());
    return found;
}
pub fn clearComplete(self: *Self) !void {
    if (self.unresolved()) return error.UnresolvedSubmission;
    self.record.operation = null;
    self.record.complete = false;
    self.record.cancelling = false;
    try self.save();
}
fn statusInto(self: *Self, console: *Console) !bool {
    const operation = self.record.operation orelse return false;
    switch (operation) {
        .mutation => |value| {
            const writer = &self.mutation.?;
            const status_value = try self.readOnly(q.TableMutationClient.status, .{ writer, try value.request.reference(value.namespace) });
            const rejection = if (value.input != null and value.pending != null) try self.readOnly(q.TableMutationClient.rejection, .{ writer, value.pending.?, value.input.? }) else null;
            const phase = if (rejection != null) "input_rejected" else if (status_value) |status_value_| @tagName(status_value_.phase) else "unconfirmed";
            const reason = if (rejection) |reason| @tagName(reason) else if (status_value) |s| @tagName(s.reason) else "none";
            const affected = if (rejection != null) null else if (status_value) |s| if (s.phase == .applied) @as(?u8, s.affected_rows) else null else null;
            const uncertain = value.pending != null and value.input == null;
            if (console.session.format == .json) {
                var id: [20]u8 = undefined;
                try console.json(.{ .mutation = .{ .id = try std.fmt.bufPrint(&id, "{d}", .{value.namespace}), .phase = phase, .reason = reason, .affected_rows = affected, .uncertain = uncertain } });
            } else if (affected) |count| try console.out.print("{d} {s} affected\n", .{ count, if (count == 1) "row" else "rows" }) else try console.out.print("Mutation: {s} ({s}); uncertain send: {s}\n", .{ phase, reason, if (uncertain) "yes" else "no" });
        },
        .creation => |value| {
            const catalog = &self.catalog.?;
            const disposition = if (value.input) |input| try self.readOnly(c.Client.inputDisposition, .{ catalog, value.pending, input }) else null;
            const receipt = if (disposition == null) try self.readOnly(c.Client.status, .{ catalog, value.request }) else null;
            const phase = if (disposition) |d| @tagName(d.outcome) else if (receipt) |r| @tagName(r.outcome) else "unconfirmed";
            if (console.session.format == .json) {
                var id: [20]u8 = undefined;
                try console.json(.{ .creation = .{ .id = try std.fmt.bufPrint(&id, "{d}", .{value.request.operation}), .name = value.request.name.slice(), .phase = phase, .uncertain = value.input == null } });
            } else try console.out.print("CREATE TABLE {s}: {s}\n", .{ value.request.name.slice(), phase });
        },
    }
    return true;
}
