//! Bounded hot Table snapshot cache with database-owned recovery slots. A warm
//! SELECT borrows a pin without writing a local file or a new durable operation.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
pub const Gateway = struct { realm: u64, account: [32]u8 };
pub const Record = struct {
    definition: p.Growth.Definition,
    gateway: Gateway,
    generation: u64,
    table: c.DirectTableBinding,
    operation: u64,
    changed_lsn: u64,
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
        if (self.generation == 0 or self.gateway.realm != self.table.connection.scope.realm or
            std.mem.allEqual(u8, &self.gateway.account, 0) or self.expected.next_lsn == 0) return error.InvalidSqlReadRecovery;
        if (self.handle) |handle| {
            try handle.content.validate();
            if (!std.meta.eql(handle.owner, self.owner())) return error.InvalidSqlReadRecovery;
        }
    }
};
allocator: std.mem.Allocator,
io: std.Io,
gateway: Gateway,
generation: u64,
mutex: std.Io.Mutex = .init,
entries: [capacity]?Entry = @splat(null),
cleanup_slot: usize = 0,
dirty: std.atomic.Value(bool) = .init(true),
wake: ?*g.RecoveryWork = null,
pub const capacity = 64;
const format: u32 = 0x53515231;
const Slot = struct { generation: u64, record: ?Record };
const Entry = struct { record: Record, users: u32 };
pub fn init(allocator: std.mem.Allocator, io: std.Io, parent: std.Io.Dir, gateway: Gateway, generation: u64) !Self {
    _ = parent;
    if (gateway.realm == 0 or generation == 0 or std.mem.allEqual(u8, &gateway.account, 0)) return error.InvalidSqlReadRecovery;
    return .{ .allocator = allocator, .io = io, .gateway = gateway, .generation = generation };
}
pub fn deinit(self: *Self) void {
    self.* = undefined;
}
fn requireCleanup(self: *Self) void {
    self.dirty.store(true, .release);
    if (self.wake) |work| work.notify(self.io);
}
fn key(self: *Self, client: c.DirectTableClient, index: usize) !c.DirectClientToken.Key {
    var token: [16]u8 = @splat(0);
    std.mem.writeInt(u64, token[0..8], index, .little);
    const scope: c.DirectRecord.Scope = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = self.gateway.account };
    const route = try c.DirectClientToken.accountPrefix(scope);
    return .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = g.AccountIdentity.internal(self.gateway.account, "read-cache", &route), .token = token };
}
fn open(self: *Self, client: c.DirectTableClient, index: usize, create: bool) !?c.DirectClientToken.Progress {
    const selected = try self.key(client, index);
    if (try c.DirectClientToken.inspect(client, selected)) |value| return value;
    if (!create) return null;
    const record = try c.DirectRecord.stage(client, selected.account, format, &selected.token);
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const operation = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    const receipt = try c.DirectClientToken.bind(client, .{ .key = selected, .fingerprint = record.content.sha256, .intent = .{ .external = .{ .connection = client.connection, .namespace = 1, .operation = operation, .record = record } } });
    return c.DirectClientToken.inspect(client, receipt.binding.key);
}
fn read(self: *Self, client: c.DirectTableClient, state: c.DirectClientToken.Progress) !Slot {
    const reference = state.record orelse return .{ .generation = 0, .record = null };
    if (reference.format != format) return error.InvalidSqlReadRecovery;
    const bytes = try c.DirectRecord.read(self.allocator, client, reference);
    defer self.allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Slot, self.allocator, bytes);
    defer parsed.deinit();
    const slot = parsed.value;
    if (slot.generation > self.generation) return error.StaleGatewayCoordinator;
    if (slot.record) |record| {
        try record.validate();
        if (!std.meta.eql(record.gateway, self.gateway) or record.generation > slot.generation or !std.meta.eql(record.table.connection, client.connection)) return error.InvalidSqlReadRecovery;
    }
    return slot;
}
fn write(self: *Self, client: c.DirectTableClient, state: c.DirectClientToken.Progress, value: ?Record) !c.DirectClientToken.Progress {
    const bytes = try p.Json.valueAlloc(self.allocator, Slot{ .generation = self.generation, .record = value });
    defer self.allocator.free(bytes);
    const reference = try c.DirectRecord.stage(client, state.receipt.binding.key.account, format, bytes);
    return c.DirectClientToken.update(client, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = true, .cancel = false, .record = reference });
}
fn release(client: c.DirectTableClient, record: Record) !void {
    try client.closeOriginalPin(record.table.interpretation.interpretation.object, record.owner(), record.expected, record.handle);
}
/// Observe a durable recovery slot without creating it or acquiring a pin.
pub fn inspect(self: *Self, client: c.DirectTableClient, index: usize) !?Record {
    if (index >= capacity) return error.InvalidSqlReadRecovery;
    const state = (try self.open(client, index, false)) orelse return null;
    return (try self.read(client, state)).record;
}
/// Current definition and logical change frontier qualify a cached exact cut.
/// Current authority is checked by lookup and again on every buffered disclosure.
pub fn acquireCurrent(self: *Self, client: c.DirectTableClient, table: c.DirectTableBinding) !Record {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (!std.meta.eql(client.connection, table.connection)) return error.CatalogIdentityConflict;
    const response = try client.call(.{ .lookup = .{ .namespace = table.namespace, .name = table.name.slice() } });
    defer response.deinit();
    const metadata = response.value.result.lookup orelse return error.TableDefinitionChanged;
    try table.check(client.connection, metadata);
    for (&self.entries) |*slot| if (slot.*) |*entry| {
        if (std.meta.eql(entry.record.table, table) and entry.record.changed_lsn == metadata.changed_lsn) {
            entry.users = try std.math.add(u32, entry.users, 1);
            return entry.record;
        }
    };
    const index = for (self.entries, 0..) |slot, i| {
        if (slot) |entry| {
            if (entry.users == 0 and std.meta.eql(entry.record.table.connection, client.connection) and
                std.meta.eql(entry.record.table.interpretation.interpretation.object, table.interpretation.interpretation.object)) break i;
        }
    } else for (self.entries, 0..) |slot, i| {
        if (slot == null) break i;
    } else for (self.entries, 0..) |slot, i| {
        if (slot.?.users == 0 and std.meta.eql(slot.?.record.table.connection, client.connection)) break i;
    } else return error.SqlReadLeaseCapacity;
    errdefer self.requireCleanup();
    var state = (try self.open(client, index, true)) orelse return error.InvalidSqlReadRecovery;
    const previous = try self.read(client, state);
    // Eviction has selected an unborrowed entry. Stop advertising it before
    // releasing the durable pin: a lost release reply must not leave a warm hit
    // pointing at a pin that the owner may already have closed.
    const cached = self.entries[index];
    self.entries[index] = null;
    var selected = metadata;
    if (previous.record) |prior| {
        var to_release = prior;
        to_release.state = .closing;
        state = try self.write(client, state, to_release);
        if (cached) |entry| {
            if (entry.record.operation == prior.operation and std.meta.eql(entry.record.table, prior.table)) {
                to_release.handle = entry.record.handle;
            }
        }
        try release(client, to_release);
        const refreshed = try client.call(.{ .lookup = .{ .namespace = table.namespace, .name = table.name.slice() } });
        defer refreshed.deinit();
        selected = refreshed.value.result.lookup orelse return error.TableDefinitionChanged;
        try table.check(client.connection, selected);
    }
    for (0..4) |attempt| {
        var random: [8]u8 = undefined;
        try self.io.randomSecure(&random);
        const operation = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
        var record: Record = .{ .definition = p.Growth.current_definition, .gateway = self.gateway, .generation = self.generation, .table = table, .operation = operation, .changed_lsn = selected.changed_lsn, .expected = selected.position, .handle = null, .state = .active };
        state = try self.write(client, state, record);
        const pinned = client.call(.{ .pin = .{ .object = table.interpretation.interpretation.object, .owner = record.owner(), .expected = record.expected } }) catch |err| {
            if (err != error.Conflict or attempt == 3) return err;
            // A Conflict alone proves nothing about acceptance. Only an absent
            // original pin at a strictly later monotone frontier proves this
            // exact acquisition cannot have succeeded or succeed in the future.
            // No iterator or result exists yet. Accepted/uncertain pins, other
            // failures and any already opened result retain their original cut.
            const observed = try client.call(.{ .pin_status = .{ .object = table.interpretation.interpretation.object, .owner = record.owner() } });
            defer observed.deinit();
            const current = observed.value.result.pin_state;
            if (current.handle != null or current.released or current.retired or
                current.position.partition != record.expected.partition or current.position.next_lsn <= record.expected.next_lsn) return err;
            record.state = .closing;
            state = try self.write(client, state, record);
            const refreshed = try client.call(.{ .lookup = .{ .namespace = table.namespace, .name = table.name.slice() } });
            defer refreshed.deinit();
            selected = refreshed.value.result.lookup orelse return error.TableDefinitionChanged;
            try table.check(client.connection, selected);
            continue;
        };
        defer pinned.deinit();
        record.handle = pinned.value.result.pin;
        self.entries[index] = .{ .record = record, .users = 1 };
        return record;
    }
    unreachable;
}
/// A connection releases only its in-memory borrow. Durable cache pins survive
/// between statements and are evicted under pressure or reconciled after restart.
pub fn close(self: *Self, client: c.DirectTableClient, record: Record) !void {
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    errdefer self.requireCleanup();
    if (!std.meta.eql(client.connection, record.table.connection)) return error.CatalogIdentityConflict;
    for (&self.entries) |*slot| if (slot.*) |*entry| {
        if (entry.record.operation != record.operation) continue;
        if (!std.meta.eql(entry.record, record) or entry.users == 0) return error.InvalidSqlReadRecovery;
        entry.users -= 1;
        return;
    };
    return error.InvalidSqlReadRecovery;
}
/// Inspect one fixed recovery slot. Slots bound cache capacity, never durable
/// collection cardinality; each overwrite preserves the previous WAL evidence.
pub fn tick(self: *Self, client: c.DirectTableClient) !bool {
    if (!self.mutex.tryLock()) return false;
    defer self.mutex.unlock(self.io);
    const index = self.cleanup_slot;
    self.cleanup_slot = (index + 1) % capacity;
    var state = (try self.open(client, index, false)) orelse return false;
    const slot = try self.read(client, state);
    var record = slot.record orelse return false;
    if (self.entries[index]) |entry| {
        if (entry.record.operation == record.operation and
            entry.record.generation == record.generation and
            std.meta.eql(entry.record.gateway, record.gateway) and
            std.meta.eql(entry.record.table, record.table) and
            std.meta.eql(entry.record.expected, record.expected)) return false;
    }
    record.state = .closing;
    state = try self.write(client, state, record);
    try release(client, record);
    _ = try self.write(client, state, null);
    return true;
}
