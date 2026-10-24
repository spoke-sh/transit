//! Local recovery journal for SQL-owned direct Table pins. The Table owner is
//! authoritative; a file records the original request before its first attempt.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
pub const Gateway = struct { realm: u64, owner: u64, account: [32]u8 };
pub const Record = struct {
    definition: p.Growth.Definition,
    gateway: Gateway,
    generation: u64,
    table: c.DirectTableBinding,
    operation: u64,
    expected: p.DataLifecycle.Position,
    handle: ?c.storage.TablePartition.SnapshotHandle,
    state: enum { active, closing },
    pub fn owner(self: Record) p.DataLifecycle.Operation {
        return .{ .scope = self.table.connection.scope, .principal = self.table.connection.principal, .operation = self.operation };
    }
    pub fn snapshot(self: Record) !w.Snapshot {
        return .{ .object = self.table.interpretation.interpretation.object, .handle = self.handle orelse return error.TableSnapshotNotPinned };
    }
    pub fn validate(self: Record) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.table.validate();
        try self.owner().validate();
        try self.expected.validate();
        if (self.generation == 0 or self.gateway.owner == 0 or self.gateway.realm != self.table.connection.scope.realm or
            std.mem.allEqual(u8, &self.gateway.account, 0) or self.expected.next_lsn == 0) return error.InvalidSqlReadRecovery;
        if (self.handle) |handle| {
            try handle.content.validate();
            if (!std.meta.eql(handle.owner, self.owner())) return error.InvalidSqlReadRecovery;
        }
    }
};
allocator: std.mem.Allocator,
io: std.Io,
directory: std.Io.Dir,
gateway: Gateway,
generation: u64,
iterator: std.Io.Dir.Iterator,
mutex: std.Io.Mutex = .init,
pub const max_bytes = 8192;

pub fn init(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, gateway: Gateway, generation: u64) !Self {
    if (gateway.realm == 0 or gateway.owner == 0 or generation == 0 or std.mem.allEqual(u8, &gateway.account, 0)) return error.InvalidSqlReadRecovery;
    var buffer: [96]u8 = undefined;
    const folder = try std.fmt.bufPrint(&buffer, "read-pins-{s}", .{std.fmt.bytesToHex(gateway.account, .lower)});
    // A borrowed directory can be an O_PATH descriptor. Own a readable parent
    // descriptor so fsync establishes creation durability on Linux as well.
    const root = try parent.openDir(io, ".", .{ .iterate = true });
    defer root.close(io);
    try root.createDirPath(io, folder);
    const directory = try root.openDir(io, folder, .{ .iterate = true });
    errdefer directory.close(io);
    if (std.c.fsync(root.handle) != 0) return error.SqlReadRecoverySyncFailed;
    return .{ .allocator = allocator, .io = io, .directory = directory, .gateway = gateway, .generation = generation, .iterator = directory.iterate() };
}
pub fn deinit(self: *Self) void {
    self.directory.close(self.io);
    self.* = undefined;
}
fn name(operation: u64, buffer: *[32]u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "{d}.pin", .{operation});
}
fn read(self: *Self, operation: u64) !Record {
    var buffer: [32]u8 = undefined;
    const bytes = try self.directory.readFileAlloc(self.io, try name(operation, &buffer), self.allocator, .limited(max_bytes));
    defer self.allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Record, self.allocator, bytes);
    defer parsed.deinit();
    const record = parsed.value;
    try record.validate();
    if (record.operation != operation or !std.meta.eql(record.gateway, self.gateway)) return error.InvalidSqlReadRecovery;
    return record;
}
fn write(self: *Self, record: Record, replace: bool) !void {
    try record.validate();
    if (!std.meta.eql(record.gateway, self.gateway)) return error.InvalidSqlReadRecovery;
    const bytes = try p.Json.valueAlloc(self.allocator, record);
    defer self.allocator.free(bytes);
    if (bytes.len > max_bytes) return error.InvalidSqlReadRecovery;
    var buffer: [32]u8 = undefined;
    var file = try self.directory.createFileAtomic(self.io, try name(record.operation, &buffer), .{ .replace = replace, .permissions = .fromMode(0o600) });
    defer file.deinit(self.io);
    try file.file.writeStreamingAll(self.io, bytes);
    try file.file.sync(self.io);
    if (replace) try file.replace(self.io) else try file.link(self.io);
    if (std.c.fsync(self.directory.handle) != 0) return error.SqlReadRecoverySyncFailed;
}
fn remove(self: *Self, record: Record) !void {
    var buffer: [32]u8 = undefined;
    try self.directory.deleteFile(self.io, try name(record.operation, &buffer));
    if (std.c.fsync(self.directory.handle) != 0) return error.SqlReadRecoverySyncFailed;
}
/// The result owns the handle only after its recovery record reaches disk. On
/// any uncertain failure, preserve that record for closing or generation recovery.
pub fn acquire(self: *Self, client: c.DirectTableClient, table: c.DirectTableBinding, expected: p.DataLifecycle.Position) !Record {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (!std.meta.eql(client.connection, table.connection)) return error.CatalogIdentityConflict;
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const operation = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    var record: Record = .{ .definition = p.Growth.current_definition, .gateway = self.gateway, .generation = self.generation, .table = table, .operation = operation, .expected = expected, .handle = null, .state = .active };
    try self.write(record, false);
    errdefer {
        record.state = .closing;
        self.write(record, true) catch {};
    }
    const response = try client.call(.{ .pin = .{ .object = table.interpretation.interpretation.object, .owner = record.owner(), .expected = expected } });
    defer response.deinit();
    record.handle = response.value.result.pin;
    try self.write(record, true);
    return record;
}
/// Closing is durable before the remote release. A lost release reply leaves a
/// closing file; a later bounded pass observes the same original pin.
pub fn close(self: *Self, client: c.DirectTableClient, original: Record) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    var record = self.read(original.operation) catch |err| if (err == error.FileNotFound) return else return err;
    var expected = original;
    expected.state = record.state;
    if (!std.meta.eql(record, expected)) return error.InvalidSqlReadRecovery;
    if (!std.meta.eql(client.connection, record.table.connection)) return error.CatalogIdentityConflict;
    record.state = .closing;
    try self.write(record, true);
    try self.recover(client, record);
}
fn recover(self: *Self, client: c.DirectTableClient, record: Record) !void {
    // The journal owns the durable closure decision; the common client only
    // settles its original remote pin under current rights.
    try client.closeOriginalPin(record.table.interpretation.interpretation.object, record.owner(), record.expected, record.handle);
    try self.remove(record);
}
/// Visits at most eight directory entries and reconciles at most one orphan.
/// Failed cleanup retains the record and does not pin the directory cursor.
/// The caller checks the current native coordinator generation before entry.
pub fn tick(self: *Self, context: anytype, comptime resolve: anytype) !bool {
    if (!self.mutex.tryLock()) return false;
    defer self.mutex.unlock(self.io);
    for (0..8) |_| {
        const entry = (try self.iterator.next(self.io)) orelse {
            self.iterator = self.directory.iterate();
            return false;
        };
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".pin")) continue;
        const operation = std.fmt.parseInt(u64, entry.name[0 .. entry.name.len - 4], 10) catch return error.InvalidSqlReadRecovery;
        const record = self.read(operation) catch |err| if (err == error.FileNotFound) continue else return err;
        if (record.generation > self.generation) return error.StaleGatewayCoordinator;
        if (record.generation == self.generation and record.state == .active) continue;
        // The hosting account resolves only explicitly configured principals
        // and routes, using current credentials. A journal is never authority.
        const client = try resolve(context, record.table.connection);
        if (!std.meta.eql(client.connection, record.table.connection)) return error.InvalidSqlReadRecovery;
        try self.recover(client, record);
        return true;
    }
    return false;
}
