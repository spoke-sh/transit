//! Bounded hot Table snapshot cache with database-owned recovery slots. A warm
//! SELECT borrows a pin without writing a local file or a new durable operation.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const w = c.DirectTableProtocol;
const Self = @This();
pub const Gateway = struct { realm: u64, account: [32]u8 };
pub const StreamPin = struct {
    request: p.StreamRead.Request,
    release_operation: u64,
    receipt: ?p.StreamRead.Receipt = null,

    pub fn releaseOwner(self: StreamPin) p.DataLifecycle.Operation {
        return .{ .scope = self.request.operation.scope, .principal = self.request.operation.principal, .operation = self.release_operation };
    }
    pub fn validate(self: StreamPin) !void {
        try self.request.validate();
        try self.releaseOwner().validate();
        if (self.request.group != null or self.release_operation == self.request.operation.operation) return error.InvalidSqlReadRecovery;
        if (self.receipt) |receipt| {
            try receipt.requireRequest(self.request);
        }
    }
};
pub const Record = struct {
    definition: p.Growth.Definition,
    gateway: Gateway,
    generation: u64,
    table: c.DirectTableBinding,
    operation: u64,
    changed_lsn: u64,
    expected: p.DataLifecycle.Position,
    handle: ?c.storage.TablePartition.SnapshotHandle,
    stream: ?StreamPin = null,
    state: enum { active, closing },
    pub fn owner(self: Record) p.DataLifecycle.Operation {
        return .{ .scope = self.table.connection.scope, .principal = self.table.connection.principal, .operation = self.operation };
    }
    pub fn snapshot(self: Record) !w.Snapshot {
        return .{ .object = self.table.interpretation.interpretation.object, .handle = self.handle orelse return error.TableSnapshotNotPinned };
    }
    pub fn streamReceipt(self: Record) !p.StreamRead.Receipt {
        const pin = self.stream orelse return error.StreamSliceNotPinned;
        return pin.receipt orelse error.StreamSliceNotPinned;
    }
    pub fn validate(self: Record) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.table.validate();
        try self.owner().validate();
        try self.expected.validate();
        if (self.generation == 0 or self.gateway.realm != self.table.connection.scope.realm or
            std.mem.allEqual(u8, &self.gateway.account, 0) or self.expected.next_lsn == 0) return error.InvalidSqlReadRecovery;
        if (self.stream) |stream| {
            if (self.handle != null or !std.meta.eql(stream.request.operation, self.owner()) or
                !std.meta.eql(stream.request.target.interpretation, self.table.interpretation.interpretation)) return error.InvalidSqlReadRecovery;
            try stream.validate();
        } else if (self.handle) |handle| {
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
known_slots: ?struct { connection: w.Connection, mask: u64 } = null,
cleanup_slot: usize = 0,
dirty: std.atomic.Value(bool) = .init(true),
wake: ?*g.RecoveryWork = null,
pub const capacity = 64;
const format: u32 = c.DirectRecord.read_cache_format;
const Slot = struct { generation: u64, record: ?Record };
const Entry = struct { record: Record, state: c.DirectClientToken.Progress, users: u32 };
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
fn open(self: *Self, client: c.DirectTableClient, index: usize) !?c.DirectClientToken.Progress {
    return c.DirectClientToken.inspect(client, try self.key(client, index));
}
fn bindInitial(self: *Self, client: c.DirectTableClient, index: usize, value: Record) !c.DirectClientToken.Progress {
    const selected = try self.key(client, index);
    const bytes = try p.Json.valueAlloc(self.allocator, Slot{ .generation = self.generation, .record = value });
    defer self.allocator.free(bytes);
    const reference = try c.DirectRecord.stage(client, selected.account, format, bytes);
    const receipt = c.DirectClientToken.bind(client, .{ .key = selected, .fingerprint = reference.content.sha256, .intent = .{ .external = .{ .connection = client.connection, .namespace = 1, .operation = value.operation, .record = reference } } }) catch |err| {
        if (err == error.Conflict) {
            const rejection = client.service.last_rejection;
            if (try c.DirectClientToken.inspect(client, selected)) |current| _ = try self.read(client, current);
            client.service.last_rejection = rejection;
        }
        return err;
    };
    if (self.known_slots) |*known| if (std.meta.eql(known.connection, client.connection)) {
        known.mask |= @as(u64, 1) << @intCast(index);
    };
    return c.DirectClientToken.Progress.initial(receipt);
}
fn read(self: *Self, client: c.DirectTableClient, state: c.DirectClientToken.Progress) !Slot {
    const reference = state.record orelse if (state.receipt.binding.intent == .external) state.receipt.binding.intent.external.record else return error.InvalidSqlReadRecovery;
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
    return c.DirectClientToken.update(client, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = true, .cancel = false, .record = reference }) catch |err| {
        if (err == error.Conflict) {
            const rejection = client.service.last_rejection;
            if (try c.DirectClientToken.inspect(client, state.receipt.binding.key)) |current| _ = try self.read(client, current);
            // Successful reconciliation clears transport diagnostics. Preserve
            // the failed update's cause only when returning that original error;
            // a reconciliation denial or invalid record keeps its own failure.
            client.service.last_rejection = rejection;
        }
        return err;
    };
}
fn releaseStream(client: c.DirectTableClient, stream: StreamPin) !void {
    const receipt: p.StreamRead.Receipt = if (stream.receipt) |known| known else blk: {
        const cancelled = try client.call(.{ .stream = .{ .cancel = .{ .consume = stream.request } } });
        defer cancelled.deinit();
        if (cancelled.value.result != .stream or cancelled.value.result.stream != .operation) return error.InvalidStreamResponse;
        const operation = cancelled.value.result.stream.operation orelse return error.InvalidStreamResponse;
        break :blk switch (operation) {
            .closed => return,
            .consume => |accepted| accepted,
            else => return error.InvalidStreamResponse,
        };
    };
    const released = try client.call(.{ .stream = .{ .mutate = .{ .work = .{ .release = .{
        .target = stream.request.target,
        .operation = stream.releaseOwner(),
        .read = receipt.handle(),
    } }, .payload = null } } });
    defer released.deinit();
    if (released.value.result != .stream or released.value.result.stream != .operation) return error.InvalidStreamResponse;
    const operation = released.value.result.stream.operation orelse return error.InvalidStreamResponse;
    switch (operation) {
        .release => {},
        .closed => |closed| if (closed.reason != .refused or closed.reason.refused != .read_released) return error.InvalidStreamResponse,
        else => return error.InvalidStreamResponse,
    }
}
fn release(client: c.DirectTableClient, record: Record) !void {
    if (record.stream) |stream| return releaseStream(client, stream);
    try client.closeOriginalCapture(record.table.interpretation.interpretation, record.owner(), record.expected, record.handle);
}
/// Observe a durable recovery slot without creating it or acquiring a pin.
pub fn inspect(self: *Self, client: c.DirectTableClient, index: usize) !?Record {
    if (index >= capacity) return error.InvalidSqlReadRecovery;
    const state = (try self.open(client, index)) orelse return null;
    return (try self.read(client, state)).record;
}
/// Current definition and logical change frontier qualify a cached exact cut.
/// Current authority is checked by lookup and again on every buffered disclosure.
pub fn acquireCurrent(self: *Self, client: c.DirectTableClient, table: c.DirectTableBinding) !Record {
    return self.acquireCurrentWithMetadata(client, table, null);
}
pub fn acquireCurrentWithMetadata(self: *Self, client: c.DirectTableClient, table: c.DirectTableBinding, known_metadata: ?w.Definition) !Record {
    if (table.catalog != null) return error.HistoricalRetentionOwned;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (!std.meta.eql(client.connection, table.connection)) return error.CatalogIdentityConflict;
    const metadata = if (known_metadata) |known| blk: {
        try table.check(client.connection, known);
        break :blk known;
    } else blk: {
        const response = try client.call(.{ .lookup = .{ .namespace = table.namespace, .name = table.name.slice() } });
        defer response.deinit();
        const found = response.value.result.lookup orelse return error.TableDefinitionChanged;
        try table.check(client.connection, found);
        break :blk found;
    };
    for (&self.entries) |*slot| if (slot.*) |*entry| {
        if (entry.record.stream == null and std.meta.eql(entry.record.table, table) and entry.record.changed_lsn == metadata.changed_lsn) {
            entry.users = try std.math.add(u32, entry.users, 1);
            return entry.record;
        }
    };
    const index = for (self.entries, 0..) |slot, i| {
        if (slot) |entry| {
            if (entry.users == 0 and entry.record.stream == null and std.meta.eql(entry.record.table.connection, client.connection) and
                std.meta.eql(entry.record.table.interpretation.interpretation.object, table.interpretation.interpretation.object)) break i;
        }
    } else for (self.entries, 0..) |slot, i| {
        if (slot == null) break i;
    } else for (self.entries, 0..) |slot, i| {
        if (slot.?.users == 0 and std.meta.eql(slot.?.record.table.connection, client.connection)) break i;
    } else return error.SqlReadLeaseCapacity;
    errdefer self.requireCleanup();
    // Eviction has selected an unborrowed entry. Stop advertising it before
    // releasing the durable pin: a lost release reply must not leave a warm hit
    // pointing at a pin that the owner may already have closed.
    const cached = self.entries[index];
    self.entries[index] = null;
    var state: ?c.DirectClientToken.Progress = null;
    var previous_record: ?Record = null;
    if (cached) |entry| {
        state = entry.state;
        previous_record = entry.record;
    } else if (try self.open(client, index)) |existing| {
        state = existing;
        previous_record = (try self.read(client, existing)).record;
    }
    const selected = metadata;
    if (previous_record) |prior| {
        var to_release = prior;
        if (cached != null and to_release.stream == null) {
            const released = try client.call(.{ .release = try to_release.snapshot() });
            released.deinit();
        } else {
            if (to_release.state != .closing) {
                to_release.state = .closing;
                state = try self.write(client, state.?, to_release);
            }
            try release(client, to_release);
        }
    }
    var random: [8]u8 = undefined;
    try self.io.randomSecure(&random);
    const operation = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    var record: Record = .{ .definition = p.Growth.current_definition, .gateway = self.gateway, .generation = self.generation, .table = table, .operation = operation, .changed_lsn = selected.changed_lsn, .expected = selected.position, .handle = null, .state = .active };
    const next_state = if (state) |existing|
        try self.write(client, existing, record)
    else
        try self.bindInitial(client, index, record);
    const pinned = try client.call(.{ .pin = .{
        .object = table.interpretation.interpretation.object,
        .owner = record.owner(),
        .expected = record.expected,
        .selection = .current,
        .interpretation = table.interpretation.interpretation,
    } });
    defer pinned.deinit();
    record.handle = pinned.value.result.pin;
    self.entries[index] = .{ .record = record, .state = next_state, .users = 1 };
    return record;
}
pub fn acquireStreamSlice(self: *Self, client: c.DirectTableClient, table: c.DirectTableBinding, stream: g.direct.DirectRelationalCompilation.StreamSource) !Record {
    if (table.catalog != null) return error.HistoricalRetentionOwned;
    try self.mutex.lock(self.io);
    defer self.mutex.unlock(self.io);
    if (!std.meta.eql(client.connection, table.connection)) return error.CatalogIdentityConflict;
    const lookup = try client.call(.{ .log_lookup = .{ .namespace = table.namespace, .name = table.name.slice() } });
    defer lookup.deinit();
    const found = lookup.value.result.log_lookup orelse return error.CatalogDefinitionChanged;
    if (found.declaration.kind() != .stream or found.declaration.stored.retired or
        !std.meta.eql(found.declaration.stored.declaration.interpretation, stream.definition.stored.declaration.interpretation))
    {
        return error.CatalogDefinitionChanged;
    }
    const target: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = found.declaration.stored.declaration.interpretation,
        .partition = stream.slice.partition,
    };
    const observed = try client.call(.{ .stream = .{ .observe = target } });
    defer observed.deinit();
    if (observed.value.result != .stream or observed.value.result.stream != .cut) return error.InvalidStreamResponse;
    const cut = observed.value.result.stream.cut;
    const from = if (stream.slice.from_offset) |explicit_from| blk: {
        if (explicit_from < cut.retained_from) return error.StreamOffsetTrimmed;
        if (explicit_from > cut.next) return error.LogOffsetBeyondCut;
        break :blk explicit_from;
    } else cut.retained_from;
    if (stream.slice.until_offset) |explicit_until| {
        if (explicit_until < from) return error.InvalidStreamSliceBounds;
        if (explicit_until > cut.next) return error.LogOffsetBeyondCut;
    }
    const index = for (self.entries, 0..) |slot, i| {
        if (slot == null) break i;
    } else for (self.entries, 0..) |slot, i| {
        if (slot.?.users == 0 and std.meta.eql(slot.?.record.table.connection, client.connection)) break i;
    } else return error.SqlReadLeaseCapacity;
    errdefer self.requireCleanup();
    const cached = self.entries[index];
    self.entries[index] = null;
    var state: ?c.DirectClientToken.Progress = null;
    var previous_record: ?Record = null;
    if (cached) |entry| {
        state = entry.state;
        previous_record = entry.record;
    } else if (try self.open(client, index)) |existing| {
        state = existing;
        previous_record = (try self.read(client, existing)).record;
    }
    if (previous_record) |prior| {
        var to_release = prior;
        if (cached != null and to_release.stream == null) {
            const released = try client.call(.{ .release = try to_release.snapshot() });
            released.deinit();
        } else {
            if (to_release.state != .closing) {
                to_release.state = .closing;
                state = try self.write(client, state.?, to_release);
            }
            try release(client, to_release);
        }
    }
    var random: [16]u8 = undefined;
    try self.io.randomSecure(&random);
    const operation = (std.mem.readInt(u64, random[0..8], .little) % p.max_counter) + 1;
    var release_operation = (std.mem.readInt(u64, random[8..16], .little) % p.max_counter) + 1;
    if (release_operation == operation) release_operation = (operation % p.max_counter) + 1;
    const owner: p.DataLifecycle.Operation = .{ .scope = table.connection.scope, .principal = table.connection.principal, .operation = operation };
    const request: p.StreamRead.Request = .{
        .target = target,
        .operation = owner,
        .group = null,
        .from = from,
        .until = stream.slice.until_offset,
        .timestamp = stream.slice.timestamp,
    };
    var record: Record = .{
        .definition = p.Growth.current_definition,
        .gateway = self.gateway,
        .generation = self.generation,
        .table = table,
        .operation = operation,
        .changed_lsn = cut.accepted.next_lsn,
        .expected = cut.accepted,
        .handle = null,
        .stream = .{ .request = request, .release_operation = release_operation, .receipt = null },
        .state = .active,
    };
    const next_state = if (state) |existing|
        try self.write(client, existing, record)
    else
        try self.bindInitial(client, index, record);
    const pinned = try client.call(.{ .stream = .{ .mutate = .{ .work = .{ .consume = request }, .payload = null } } });
    defer pinned.deinit();
    if (pinned.value.result != .stream or pinned.value.result.stream != .operation) return error.InvalidStreamResponse;
    const operation_receipt = pinned.value.result.stream.operation orelse return error.InvalidStreamResponse;
    const receipt = switch (operation_receipt) {
        .consume => |accepted| accepted,
        else => return error.InvalidStreamResponse,
    };
    record.stream.?.receipt = receipt;
    self.entries[index] = .{ .record = record, .state = next_state, .users = 1 };
    return record;
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
        if (entry.record.stream != null and entry.users == 0) {
            var closing = entry.*;
            slot.* = null;
            closing.record.state = .closing;
            const state = try self.write(client, closing.state, closing.record);
            try release(client, closing.record);
            _ = try self.write(client, state, null);
        }
        return;
    };
    return error.InvalidSqlReadRecovery;
}
/// Explicit shutdown of one connection after its readers and recovery worker
/// have joined. Use ordinary durable reconciliation to release cached pins;
/// an interrupted drain leaves the original recovery records intact.
pub fn drain(self: *Self, client: c.DirectTableClient) !void {
    {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        for (self.entries) |slot| if (slot) |entry| {
            if (std.meta.eql(entry.record.table.connection, client.connection) and entry.users != 0) return error.SqlReadCacheInUse;
        };
        for (&self.entries) |*slot| if (slot.*) |entry| {
            if (std.meta.eql(entry.record.table.connection, client.connection)) slot.* = null;
        };
        self.known_slots = null;
    }
    for (0..capacity) |_| _ = try self.tick(client);
}
/// Inspect one fixed recovery slot. Slots bound cache capacity, never durable
/// collection cardinality; each overwrite preserves the previous WAL evidence.
pub fn tick(self: *Self, client: c.DirectTableClient) !bool {
    if (!self.mutex.tryLock()) return false;
    defer self.mutex.unlock(self.io);
    const index = self.cleanup_slot;
    self.cleanup_slot = (index + 1) % capacity;
    if (index == 0) self.known_slots = null;
    errdefer self.known_slots = null;
    if (self.entries[index] != null) return false;
    if (self.known_slots == null or !std.meta.eql(self.known_slots.?.connection, client.connection)) {
        const account = (try self.key(client, 0)).account;
        var mask: u64 = 0;
        var after: ?u64 = null;
        while (true) {
            const page = try c.DirectClientToken.list(client, account, after, false);
            for (page.entries) |entry| if (entry) |progress| {
                const token = progress.receipt.binding.key.token;
                const slot_index = std.mem.readInt(u64, token[0..8], .little);
                if (slot_index < capacity and std.mem.allEqual(u8, token[8..16], 0)) {
                    mask |= @as(u64, 1) << @intCast(slot_index);
                }
            };
            after = page.next orelse break;
        }
        self.known_slots = .{ .connection = client.connection, .mask = mask };
    }
    if ((self.known_slots.?.mask & (@as(u64, 1) << @intCast(index))) == 0) return false;
    var state = (try self.open(client, index)) orelse return false;
    const slot = try self.read(client, state);
    var record = slot.record orelse return false;
    if (record.state != .closing) {
        record.state = .closing;
        state = try self.write(client, state, record);
    }
    try release(client, record);
    _ = try self.write(client, state, null);
    return true;
}

test "read cache reconciliation preserves the original conflict but never masks a new refusal" {
    const t = std.testing;
    const Peer = struct {
        state: c.DirectClientToken.Progress,
        bytes: []const u8,
        signing_key: [32]u8,
        denial: enum { none, inspect, read } = .none,
        stages: usize = 0,
        updates: usize = 0,
        inspections: usize = 0,
        reads: usize = 0,
        fn invoke(raw: *anyopaque, invocation: *g.wire.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const request = try invocation.request(w.Request);
            try request.validate(invocation.allocator);
            try request.proof.verify(self.signing_key);
            const result: w.Result = switch (request.action) {
                .record => |record| switch (record) {
                    .stage => |stage| blk: {
                        self.stages += 1;
                        const bytes = try stage.bytes.decode(invocation.allocator, c.DirectRecord.max_bytes);
                        break :blk .{ .record = .{ .reference = try c.DirectRecord.reference(stage.scope, stage.format, bytes), .bytes = null } };
                    },
                    .read => |reference| blk: {
                        self.reads += 1;
                        try self.state.record.?.requireSame(reference);
                        if (self.denial == .read) return invocation.client.reject(.forbidden, .AccessDenied);
                        break :blk .{ .record = .{ .reference = reference, .bytes = try w.Binary.encode(invocation.allocator, self.bytes) } };
                    },
                    else => return error.TestUnexpectedRequest,
                },
                .client_progress => |progress| switch (progress) {
                    .update => |update| {
                        self.updates += 1;
                        try self.state.receipt.binding.key.requireSame(update.key);
                        try t.expectEqualDeep(self.state.revision, update.expected);
                        return invocation.client.reject(.conflict, .Conflict);
                    },
                    .inspect => |selected| blk: {
                        self.inspections += 1;
                        try self.state.receipt.binding.key.requireSame(selected);
                        if (self.denial == .inspect) return invocation.client.reject(.forbidden, .AccessDenied);
                        break :blk .{ .client_progress = .{ .state = self.state } };
                    },
                    else => return error.TestUnexpectedRequest,
                },
                else => return error.TestUnexpectedRequest,
            };
            const claim = request.proof.claim;
            const response: w.Response = .{ .definition = p.Growth.current_definition, .context = claim.context, .policy_revision = 1, .subject = .{ .principal = claim.principal, .login_role = 1, .role = 1, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context }, .result = result };
            try invocation.respond(try g.wire.LocalEndpoint.clone(invocation.allocator, response));
        }
    };
    const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const selected: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(6), .token = @splat(7) };
    const bytes = try p.Json.valueAlloc(t.allocator, Slot{ .generation = 1, .record = null });
    defer t.allocator.free(bytes);
    const reference = try c.DirectRecord.reference(selected.scope(), format, bytes);
    var state = c.DirectClientToken.Progress.initial(.{
        .binding = .{ .key = selected, .fingerprint = reference.content.sha256, .intent = .{ .external = .{ .connection = connection, .namespace = 1, .operation = 8, .record = reference } } },
        .position = .{ .partition = 9, .next_lsn = 10 },
        .coordination = null,
    });
    state.record = reference;
    try state.validate();
    const signing = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
    var peer: Peer = .{ .state = state, .bytes = bytes, .signing_key = signing.public_key.toBytes() };
    var transport = g.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &peer, .invoke = Peer.invoke };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = signing, .credential_epoch = 1 };
    var cache = try Self.init(t.allocator, t.io, std.Io.Dir.cwd(), .{ .realm = 1, .account = selected.account }, 1);
    defer cache.deinit();
    try t.expectError(error.Conflict, cache.write(caller, state, null));
    try t.expectEqual(@as(?p.ErrorCode, .Conflict), transport.last_rejection);
    peer.denial = .inspect;
    try t.expectError(error.AccessDenied, cache.write(caller, state, null));
    try t.expectEqual(@as(?p.ErrorCode, .AccessDenied), transport.last_rejection);
    peer.denial = .read;
    try t.expectError(error.AccessDenied, cache.write(caller, state, null));
    try t.expectEqual(@as(?p.ErrorCode, .AccessDenied), transport.last_rejection);
    try t.expectEqual(3, peer.stages);
    try t.expectEqual(3, peer.updates);
    try t.expectEqual(3, peer.inspections);
    try t.expectEqual(2, peer.reads);
}

test "stream slice pins validate cut bounds, release on close, and reconcile uncertain consume tokens" {
    const t = std.testing;
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null };
    const stream_cols = [_]g.fuze.TableSchema.Column{
        .{ .id = 1, .name = "k", .type = .utf8, .nullable = false, .collation = .utf8_binary },
    };
    const stream_schema: g.fuze.TableSchema.Schema = .{ .object = 21, .revision = 1, .next_column = 2, .columns = &stream_cols, .primary_key = &.{} };
    const stream_props: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 11, .name = try .init("events") };
    var props_buf: [4096]u8 = undefined;
    var stream_decl = try c.storage.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = scope, .branch = 1, .object = 21 },
        .revision = 1,
        .schema = stream_schema,
        .properties = try stream_props.encode(&props_buf),
        .configuration = .{
            .partitioning = .{ .count = 1, .key_column = 1, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = .{ .stream = .{ .compact_key_column = 1, .timestamp_column = null } },
        },
        .limits = .{ .append_rows = 8, .append_bytes = 8192, .claim_rows = 1, .read_rows = 8, .read_bytes = 8192, .active_leases = 1, .waiters = 1, .timer_steps = 1 },
    });
    defer stream_decl.deinit();
    const stream_stored = try stream_decl.stored();
    const stream_def: c.DirectLog.Definition = .{
        .stored = stream_stored,
        .seed = stream_stored,
        .properties = stream_props,
        .initialization = .{ .scope = scope, .principal = 5, .operation = 1 },
        .first_partition = 13,
    };
    var schema_buf: [g.fuze.TableSchema.max_bytes]u8 = undefined;
    const bin_stream_schema = try w.Binary.encode(t.allocator, try stream_schema.encode(&schema_buf));
    defer t.allocator.free(bin_stream_schema.base64);
    const definition: c.DirectLogProtocol.Definition = .{
        .declaration = stream_def,
        .schema = bin_stream_schema,
    };
    const Peer = struct {
        signing_key: [32]u8,
        log_def: c.DirectLogProtocol.Definition,
        slot_state: ?c.DirectClientToken.Progress = null,
        slot_bytes: ?[]u8 = null,
        allocator: std.mem.Allocator,
        fail_consume: bool = false,
        cancel_returns_accepted: bool = true,
        consumes: usize = 0,
        cancels: usize = 0,
        releases: usize = 0,

        fn deinit(self: *@This()) void {
            if (self.slot_bytes) |b| self.allocator.free(b);
        }

        fn invoke(raw: *anyopaque, invocation: *g.wire.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const request = try invocation.request(w.Request);
            try request.validate(invocation.allocator);
            try request.proof.verify(self.signing_key);
            const result: w.Result = switch (request.action) {
                .log_lookup => .{ .log_lookup = self.log_def },
                .stream => |stream_req| switch (stream_req) {
                    .observe => |target| .{ .stream = .{ .cut = .{
                        .target = target,
                        .accepted = .{ .partition = 13, .next_lsn = 9 },
                        .retained_from = 2,
                        .next = 6,
                    } } },
                    .mutate => |mutate| switch (mutate.work) {
                        .consume => |consume_req| blk: {
                            self.consumes += 1;
                            if (self.fail_consume) return error.AuthorityTimeout;
                            break :blk .{ .stream = .{ .operation = .{ .consume = .{
                                .request = consume_req,
                                .cut = .{
                                    .target = consume_req.target,
                                    .accepted = .{ .partition = 13, .next_lsn = 9 },
                                    .retained_from = 2,
                                    .next = 6,
                                },
                                .until = consume_req.until orelse 6,
                                .source = .{ .bytes = 16, .sha256 = @splat(0x33) },
                                .accepted = .{ .partition = 13, .next_lsn = 10 },
                            } } } };
                        },
                        .release => |release_req| blk: {
                            self.releases += 1;
                            break :blk .{ .stream = .{ .operation = .{ .release = .{
                                .release = release_req,
                                .accepted = .{ .partition = 13, .next_lsn = 11 },
                            } } } };
                        },
                        else => return error.TestUnexpectedRequest,
                    },
                    .cancel => |cancel_req| switch (cancel_req) {
                        .consume => |consume_req| blk: {
                            self.cancels += 1;
                            if (self.cancel_returns_accepted) {
                                break :blk .{ .stream = .{ .operation = .{ .consume = .{
                                    .request = consume_req,
                                    .cut = .{
                                        .target = consume_req.target,
                                        .accepted = .{ .partition = 13, .next_lsn = 9 },
                                        .retained_from = 2,
                                        .next = 6,
                                    },
                                    .until = consume_req.until orelse 6,
                                    .source = .{ .bytes = 16, .sha256 = @splat(0x33) },
                                    .accepted = .{ .partition = 13, .next_lsn = 10 },
                                } } } };
                            }
                            break :blk .{ .stream = .{ .operation = .{ .closed = .{
                                .binding = .{ .stream = try cancel_req.binding(invocation.allocator) },
                                .recorded = .{ .partition = 13, .next_lsn = 10 },
                                .reason = .cancelled,
                            } } } };
                        },
                        else => return error.TestUnexpectedRequest,
                    },
                    else => return error.TestUnexpectedRequest,
                },
                .record => |record| switch (record) {
                    .stage => |stage| blk: {
                        const decoded = try stage.bytes.decode(invocation.allocator, c.DirectRecord.max_bytes);
                        if (self.slot_bytes) |old| self.allocator.free(old);
                        self.slot_bytes = try self.allocator.dupe(u8, decoded);
                        break :blk .{ .record = .{ .reference = try c.DirectRecord.reference(stage.scope, stage.format, decoded), .bytes = null } };
                    },
                    .read => |reference| .{ .record = .{ .reference = reference, .bytes = try w.Binary.encode(invocation.allocator, self.slot_bytes.?) } },
                    else => return error.TestUnexpectedRequest,
                },
                .client_token => |token_req| switch (token_req) {
                    .bind => |bind_req| blk: {
                        const receipt: c.DirectClientToken.Receipt = .{
                            .binding = bind_req,
                            .position = .{ .partition = 1, .next_lsn = 2 },
                            .coordination = null,
                        };
                        var initial = c.DirectClientToken.Progress.initial(receipt);
                        initial.record = bind_req.intent.external.record;
                        self.slot_state = initial;
                        break :blk .{ .client_token = receipt };
                    },
                    else => return error.TestUnexpectedRequest,
                },
                .client_progress => |progress| switch (progress) {
                    .update => |update| blk: {
                        var current = self.slot_state.?;
                        current.revision.next_lsn += 1;
                        current.record = update.record;
                        self.slot_state = current;
                        break :blk .{ .client_progress = .{ .state = current } };
                    },
                    .inspect => .{ .client_progress = .{ .state = self.slot_state } },
                    .list => blk: {
                        var entries: [8]?c.DirectClientToken.Progress = @splat(null);
                        if (self.slot_state) |s| entries[0] = s;
                        break :blk .{ .client_progress = .{ .page = .{
                            .entries = entries,
                            .next = null,
                        } } };
                    },
                    else => return error.TestUnexpectedRequest,
                },
                else => return error.TestUnexpectedRequest,
            };
            const claim = request.proof.claim;
            const response: w.Response = .{ .definition = p.Growth.current_definition, .context = claim.context, .policy_revision = 1, .subject = .{ .principal = claim.principal, .login_role = 1, .role = 1, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context }, .result = result };
            try invocation.respond(try g.wire.LocalEndpoint.clone(invocation.allocator, response));
        }
    };
    const signing = try p.Ed25519.KeyPair.generateDeterministic(@splat(19));
    var peer: Peer = .{ .signing_key = signing.public_key.toBytes(), .log_def = definition, .allocator = t.allocator };
    defer peer.deinit();
    var transport = g.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &peer, .invoke = Peer.invoke };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = signing, .credential_epoch = 1 };
    const binding: c.DirectTableBinding = .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .namespace = stream_props.namespace,
        .name = stream_props.name,
        .interpretation = .{
            .kind = .table,
            .interpretation = stream_stored.declaration.interpretation,
            .content = stream_stored.content,
            .schema_fingerprint = try stream_schema.fingerprint(),
            .retired = stream_stored.retired,
        },
    };
    try binding.validate();
    var cache = try Self.init(t.allocator, t.io, std.Io.Dir.cwd(), .{ .realm = 1, .account = @splat(6) }, 1);
    defer cache.deinit();

    // 1. Cut bound rejections before allocating a pin.
    try t.expectError(error.StreamOffsetTrimmed, cache.acquireStreamSlice(caller, binding, .{
        .definition = definition.declaration,
        .slice = .{ .partition = 0, .from_offset = 1, .until_offset = 4 },
    }));
    try t.expectError(error.LogOffsetBeyondCut, cache.acquireStreamSlice(caller, binding, .{
        .definition = definition.declaration,
        .slice = .{ .partition = 0, .from_offset = 2, .until_offset = 7 },
    }));
    try t.expectError(error.InvalidStreamSliceBounds, cache.acquireStreamSlice(caller, binding, .{
        .definition = definition.declaration,
        .slice = .{ .partition = 0, .from_offset = 5, .until_offset = 3 },
    }));
    try t.expectEqual(@as(usize, 0), peer.consumes);

    // 2. Normal acquire + deterministic release on close.
    const pinned = try cache.acquireStreamSlice(caller, binding, .{
        .definition = definition.declaration,
        .slice = .{ .partition = 0, .from_offset = null, .until_offset = 6 },
    });
    try t.expectEqual(@as(u64, 2), (try pinned.streamReceipt()).request.from);
    try t.expectEqual(@as(u64, 6), (try pinned.streamReceipt()).until);
    try t.expectEqual(@as(usize, 1), peer.consumes);
    try cache.close(caller, pinned);
    try t.expectEqual(@as(usize, 1), peer.releases);
    try t.expectEqual(@as(?Record, null), try cache.inspect(caller, 0));

    // 3. Uncertain consume failure reconciled by tick via cancel + release.
    peer.fail_consume = true;
    try t.expectError(error.AuthorityTimeout, cache.acquireStreamSlice(caller, binding, .{
        .definition = definition.declaration,
        .slice = .{ .partition = 0, .from_offset = 2, .until_offset = 5 },
    }));
    try t.expect((try cache.inspect(caller, 0)) != null);
    peer.fail_consume = false;
    peer.cancel_returns_accepted = true;
    try t.expect(try cache.tick(caller));
    try t.expectEqual(@as(usize, 1), peer.cancels);
    try t.expectEqual(@as(usize, 2), peer.releases);
    try t.expectEqual(@as(?Record, null), try cache.inspect(caller, 0));
}
