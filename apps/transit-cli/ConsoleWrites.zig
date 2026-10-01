//! Console composition of the existing signed write clients. Persist before
//! sending; admission, processed input and terminal outcome remain distinct.
const std = @import("std");
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
fn identity(io: std.Io) !u64 {
    var bytes: [8]u8 = undefined;
    try io.randomSecure(&bytes);
    return @max(1, std.mem.readInt(u64, &bytes, .little));
}
pub fn start(self: *Self, console: *Console, text: []const u8, route: q.fuze.SqlDiagnostic.Route) !void {
    if (self.unresolved() or console.session.pending != null or console.session.input != null or (console.session.namespace != null and !console.session.complete)) return error.UnresolvedSubmission;
    var timing = @import("Timing.zig").start(console.init, console.preferences.timing);
    defer timing.report();
    timing.enter(.compile);
    const operation: Operation = switch (route) {
        .mutation => mutation: {
            const writer = if (self.mutation) |*client| client else return error.ConsoleWriterRequired;
            const request = writer.compileSql(self.record.name.?, text) catch |err| return console.sqlFailure(text, err);
            const namespace = try identity(self.io);
            // A collision is a conflict, never adoption of somebody else's work.
            if (try writer.status(try request.reference(namespace)) != null) return error.MutationIdentityConflict;
            const pending = (try writer.prepareNext(namespace, request)) orelse return error.MutationIdentityConflict;
            break :mutation .{ .mutation = .{ .namespace = namespace, .request = request, .pending = pending, .input = null } };
        },
        .declaration => creation: {
            const catalog = if (self.catalog) |*client| client else return error.ConsoleCatalogRequired;
            const request = c.Model.CreateTable.compile(catalog.connection.scope, try identity(self.io), try identity(self.io), @intCast((try identity(self.io) % std.math.maxInt(u32)) + 1), text) catch |err| return console.sqlFailure(text, err);
            const pending = try catalog.prepareCreate(request);
            break :creation .{ .creation = .{ .request = request, .pending = pending, .input = null } };
        },
        else => unreachable,
    };
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    self.record.operation = operation;
    self.record.complete = false;
    self.record.cancelling = false;
    timing.enter(.persist);
    try self.save();
    timing.enter(.submit);
    try self.advance(console);
}
fn check(self: *Self, deadline: i64) !void {
    if (self.failed) return error.ConsoleRecoveryWriteFailed;
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    if (std.Io.Clock.boot.now(self.io).toMilliseconds() >= deadline) return error.WriteWaitTimedOut;
}
pub fn recover(self: *Self, console: *Console) !void {
    var timing = @import("Timing.zig").start(console.init, console.preferences.timing);
    defer timing.report();
    timing.enter(.submit);
    try self.advance(console);
}
fn advance(self: *Self, console: *Console) !void {
    const deadline = std.Io.Clock.boot.now(self.io).toMilliseconds() + 300000;
    if (self.record.operation == null) return error.NoSavedWrite;
    while (true) {
        try self.check(deadline);
        switch (self.record.operation.?) {
            .mutation => |*value| {
                const writer = &self.mutation.?;
                if (value.pending) |pending| {
                    if (value.input == null) {
                        value.input = (try writer.submit(pending)).position;
                        try self.save();
                    }
                    if (try writer.observe(pending, value.input.?) == .pending) {
                        try self.io.sleep(.fromMilliseconds(50), .awake);
                        continue;
                    }
                    if (try writer.rejection(pending, value.input.?)) |_| {
                        // Keep the frozen command and input for current-authorized
                        // inspection of the rejection on subsequent .status.
                        const current = try writer.status(try value.request.reference(value.namespace));
                        // An input rejection is not a terminal mutation. Keep an
                        // active upload recoverable, including explicit cancel.
                        if (current == null or current.?.terminal() or !self.record.cancelling) {
                            self.record.complete = current == null or current.?.terminal();
                            try self.save();
                            _ = try self.status(console);
                            return error.MutationInputRejected;
                        }
                    }
                    value.pending = null;
                    value.input = null;
                    try self.save();
                }
                const reference = try value.request.reference(value.namespace);
                if (try writer.status(reference)) |outcome| if (outcome.terminal()) {
                    self.record.complete = true;
                    try self.save();
                    _ = try self.status(console);
                    if (outcome.phase == .rejected) return error.MutationRejected;
                    return;
                };
                value.pending = if (self.record.cancelling) try writer.prepare(.{ .cancel = reference }) else (try writer.prepareNext(value.namespace, value.request)) orelse continue;
                try self.save();
            },
            .creation => |*value| {
                const catalog = &self.catalog.?;
                if (value.input == null) {
                    value.input = (try catalog.submit(value.pending)).position;
                    try self.save();
                }
                if (try catalog.observe(value.pending, value.input.?) == .pending) {
                    try self.io.sleep(.fromMilliseconds(50), .awake);
                    continue;
                }
                const disposition = try catalog.inputDisposition(value.pending, value.input.?);
                const receipt = if (disposition == null) try catalog.status(value.request) else null;
                if (receipt == null and disposition == null) return error.CatalogOutcomeMissing;
                self.record.complete = true;
                try self.save();
                _ = try self.status(console);
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
    var buffer: [4096]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    const destination = console.out;
    console.out = &out;
    defer console.out = destination;
    const found = try self.statusInto(console);
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
            const status_value = try writer.status(try value.request.reference(value.namespace));
            const rejection = if (value.input != null and value.pending != null) try writer.rejection(value.pending.?, value.input.?) else null;
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
            const disposition = if (value.input) |input| try catalog.inputDisposition(value.pending, input) else null;
            const receipt = if (disposition == null) try catalog.status(value.request) else null;
            const phase = if (disposition) |d| @tagName(d.outcome) else if (receipt) |r| @tagName(r.outcome) else "unconfirmed";
            if (console.session.format == .json) {
                var id: [20]u8 = undefined;
                try console.json(.{ .creation = .{ .id = try std.fmt.bufPrint(&id, "{d}", .{value.request.operation}), .name = value.request.name.slice(), .phase = phase, .uncertain = value.input == null } });
            } else try console.out.print("CREATE TABLE {s}: {s}\n", .{ value.request.name.slice(), phase });
        },
    }
    return true;
}
