const std = @import("std");
const t = std.testing;
const serving = @import("transit_serving");
const q = serving.query;
const s = serving.station;
const c = q.catalog;
const p = s.protocol;
const Counter = @import("Counter.zig");
const Data = Counter.Data;
const NativeStore = q.testing.Store;
const w = c.DirectTableProtocol;
const binding: Data.Binding = .{ .definition = p.Growth.current_definition, .scope = .{ .realm = 1, .resource = 7, .catalog = 1 }, .branch = 1, .audience = 3, .namespace = 1, .object = Counter.object, .role = null };
const ingress = 42;
/// Actual direct catalog/storage with an injected policy, alongside an
/// independent native private-turn reference store. This is not a disk proof.
const Store = struct {
    native: NativeStore = .{},
    wal: c.storage.LocalWal.LocalWal = .initMemory(t.allocator),
    objects: c.storage.LocalSegmentStore.LocalSegmentStore = .initMemory(t.allocator),
    catalog: ?c.DirectCatalog = null,
    dispatches: usize = 0,
    lose_accepted_reply: bool = false,
    fn deinit(self: *@This()) void {
        if (self.catalog) |*catalog| catalog.deinit();
        self.objects.deinit();
        self.wal.deinit();
        self.native.deinit();
    }
    fn capture(self: *@This()) !s.Turn {
        return self.native.capture();
    }
    fn commit(self: *@This(), turn: s.Turn) !void {
        return self.native.commit(turn);
    }
    fn client(self: *@This()) Data.Client {
        return .{ .context = self, .connection = binding.connection(2) catch unreachable, .exchange = exchange };
    }
    fn policy(self: *@This()) c.DirectCatalog.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = self.native.input, .principal = 2 } }, .make_guard = makeGuard, .registered = registered };
    }
    const Guard = struct { store: *Store, primary: p.Authorization.Guard };
    fn makeGuard(raw: *anyopaque, allocator: std.mem.Allocator, primary: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !c.storage.TablePartition.Guard {
        try t.expectEqual(null, prerequisite);
        const guard = try allocator.create(Guard);
        guard.* = .{ .store = @ptrCast(@alignCast(raw)), .primary = primary };
        return .{ .context = guard, .acquire = acquire, .release = release };
    }
    fn acquire(raw: *anyopaque) !c.storage.TablePartition.Guard.Fence {
        const guard: *Guard = @ptrCast(@alignCast(raw));
        _ = (try c.testing.Authority.authorize(&guard.store.native.authority, guard.primary)) orelse return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(raw: *anyopaque, kind: c.TableAuthority.Kind, id: u64) !?p.Authorization.Object {
        const self: *Store = @ptrCast(@alignCast(raw));
        self.native.authority.last_subject = 2;
        return c.testing.Authority.binding(&self.native.authority, c.testing.Authority.profile.domain(kind), try c.TableAuthority.binding(binding.scope, kind, id));
    }
    fn executeDdl(_: *anyopaque, catalog: *c.DirectCatalog, identity: p.DataLifecycle.Binding, policy_value: c.DirectCatalog.Policy, _: u16) !c.DirectCatalog.Observation {
        const result = try catalog.perform(identity, policy_value);
        return if (result == .committed) catalog.settle(identity, policy_value) else result;
    }
    fn executeNamespace(_: *anyopaque, _: *c.DirectCatalog, _: c.DirectNamespace.Binding, _: c.DirectCatalog.Policy, _: u16) !c.DirectNamespace.Observation {
        return error.UnexpectedNamespaceMutation;
    }
    fn exchange(raw: *anyopaque, connection: w.Connection, action: w.Action) !std.json.Parsed(w.Response) {
        const self: *Store = @ptrCast(@alignCast(raw));
        try t.expectEqualDeep(try binding.connection(2), connection);
        const arena = try t.allocator.create(std.heap.ArenaAllocator);
        arena.* = .init(t.allocator);
        errdefer {
            arena.deinit();
            t.allocator.destroy(arena);
        }
        if (action == .admit_saved or (action == .operation and action.operation.command == .execute)) self.dispatches += 1;
        const result = try c.DirectTableDispatch.apply(arena.allocator(), &self.catalog.?, self.policy(), action, null, .{ .context = self, .ddl = executeDdl, .namespace = executeNamespace });
        if (self.lose_accepted_reply and result == .rows and result.rows == .committed and action == .operation and action.operation.command == .execute) {
            self.lose_accepted_reply = false;
            return error.LostAcknowledgement;
        }
        return .{ .arena = arena, .value = .{ .definition = p.Growth.current_definition, .context = @splat(0), .policy_revision = 0, .subject = .{ .principal = 2, .login_role = 2, .role = 2, .credential_epoch = 1, .audience = 3, .context = @splat(0) }, .result = result } };
    }
};
fn setup(store: *Store) !void {
    try store.native.authority.setRights(.{ .principal = 2 });
    store.catalog = try c.DirectCatalog.init(t.allocator, .{ .scope = binding.scope, .branch = 1, .partition = 1, .audience = binding.audience, .authority = c.testing.Authority.profile, .database_name = try .init("counter"), .initial_schema_name = try .init("public") }, store.wal.log(), store.objects.objectStore(), store.wal.log(), store.objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    try store.catalog.?.recover();
    try store.catalog.?.initialize(store.policy());
    var bytes: [q.fuze.TableSchema.max_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(t.allocator, try Counter.schema.encode(&bytes));
    defer t.allocator.free(encoded.base64);
    var work: w.Ddl = .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = binding.scope, .principal = 2, .operation = 900000 }, .target = binding.target(), .action = .create, .expected_definition = null, .expected_data = null, .prerequisite = null, .intent = @splat(0) }, .namespace = 1, .name = "counter", .action = .{ .create = .{ .owner = 2, .schema = encoded } } };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    work.binding.intent = try work.digest(arena.allocator());
    var intent = try c.DirectTableIntent.create(t.allocator, store.client().connection, .{ .ddl = work });
    defer intent.deinit();
    const reference = try Data.stage(store.client(), &intent, 1);
    const admitted = try store.client().call(.{ .admit_saved = reference });
    defer admitted.deinit();
    const applied = try store.client().call(.{ .operation = .{ .binding = reference.binding, .command = .execute, .steps = 32 } });
    defer applied.deinit();
    try t.expect(applied.value.result.ddl == .committed);
    var turn = try store.capture();
    try binding.bind(&turn, true);
    try store.commit(turn);
    store.dispatches = 0;
}
fn enqueue(store: *Store, correlation: u64, key: i64, delta: i64) !void {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(i64, bytes[0..8], key, .little);
    std.mem.writeInt(i64, bytes[8..16], delta, .little);
    const frame: s.Frame = .{ .kind = .call, .correlation = correlation, .payload = try serving.Codec.encode('i', serving.Model.Invocation{ .service = 1, .principal = 65536, .operation = correlation, .binding = 1, .codec = 1, .payload = try p.Value.init(&bytes) }) };
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress, .turn = correlation, .output = 0 } };
    turn.delivery.input.value = try frame.encode();
    try Counter.enqueue(&turn, ingress, frame);
    try store.commit(turn);
}
fn selfTurn(store: *Store) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = store.native.pid, .turn = store.native.input - 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = Counter.continuation }).encode();
    return turn;
}
fn value(store: *Store, key: i64) !?i64 {
    var metadata = try Data.definition(store.client(), binding, Counter.schema);
    defer metadata.deinit();
    return if (try Data.get(t.allocator, store.client(), metadata.value, Counter.schema, key)) |row| row.value else null;
}
test "queued counters publish exact deltas, progress and original replies despite lost turns" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    // More accepted work than a resident native page; no in-memory work list.
    for (0..19) |i| try enqueue(&store, i + 1, 7, 1);
    var replies: usize = 0;
    for (0..4000) |_| {
        const before = try value(&store, 7);
        var lost = try selfTurn(&store);
        try Counter.drive(t.allocator, &lost, store.client(), binding);
        const accepted = try value(&store, 7);
        try t.expect(accepted == before or accepted == @as(i64, @intCast(replies + 1)));
        var turn = try selfTurn(&store);
        try Counter.drive(t.allocator, &turn, store.client(), binding);
        // An unsent native proposal cannot undo separate data acceptance.
        // When a reply was already proposed, recovering that receipt is exact.
        for (lost.decision.outputs) |slot| if (slot) |output| {
            if ((try s.Frame.decode(output.value)).kind == .reply) try t.expectEqualDeep(lost.decision, turn.decision);
        };
        var returned: ?s.Frame = null;
        for (turn.decision.outputs) |slot| if (slot) |output| {
            const frame = try s.Frame.decode(output.value);
            if (frame.kind == .reply) {
                try t.expectEqual(ingress, output.pid);
                try t.expectEqual(replies + 1, frame.correlation);
                try t.expectEqual(@as(i64, @intCast(replies + 1)), std.mem.readInt(i64, frame.payload.data[0..8], .little));
                returned = frame;
            }
        };
        try store.commit(turn);
        if (returned != null) replies += 1;
        try t.expectEqual(if (replies == 0) @as(?i64, null) else @as(i64, @intCast(replies)), try value(&store, 7));
        var observed = try store.capture();
        const progress = if (try observed.read(Counter.progress_key)) |v| try v.asInteger() else 0;
        try t.expectEqual(@as(i64, @intCast(replies)), progress);
        if (replies == 19) break;
    } else return error.UnfinishedCounterWork;
    var idle = try selfTurn(&store);
    try Counter.drive(t.allocator, &idle, store.client(), binding);
    for (idle.decision.mutations) |entry| try t.expectEqual(null, entry);
    for (idle.decision.outputs) |entry| try t.expectEqual(null, entry);
}

fn complete(store: *Store) !p.Value {
    for (0..4000) |_| {
        // Output exhaustion rolls back native progress/replies. A separately
        // accepted row remains recoverable through its original dispatch.
        var blocked = try selfTurn(store);
        for (&blocked.decision.outputs) |*output| output.* = .{ .pid = ingress, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("busy") }).encode() };
        const before = blocked.decision;
        try t.expectError(error.OutputBudgetExceeded, Counter.drive(t.allocator, &blocked, store.client(), binding));
        try t.expectEqualDeep(before, blocked.decision);
        var turn = try selfTurn(store);
        try Counter.drive(t.allocator, &turn, store.client(), binding);
        var reply: ?p.Value = null;
        for (turn.decision.outputs) |output| if (output) |entry| {
            const frame = try s.Frame.decode(entry.value);
            if (frame.kind == .reply) reply = frame.payload;
        };
        try store.commit(turn);
        if (reply) |result| return result;
    }
    return error.UnfinishedCounterWork;
}
test "counter overflow, no-op and output exhaustion preserve the exact saved delta" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, std.math.maxInt(i64));
    try t.expectEqual(std.math.maxInt(i64), std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
    try enqueue(&store, 2, 7, 1);
    try t.expect((try complete(&store)).eql(try p.Value.init("CounterOverflow")));
    var turn = try store.capture();
    try t.expectEqual(1, try (try turn.read(Counter.progress_key)).?.asInteger());
    try t.expectEqual(std.math.maxInt(i64), (try value(&store, 7)).?);
    try enqueue(&store, 3, 7, 0);
    try t.expectEqual(std.math.maxInt(i64), std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
    turn = try store.capture();
    try t.expectEqual(2, try (try turn.read(Counter.progress_key)).?.asInteger());
    try t.expectEqual(std.math.maxInt(i64), (try value(&store, 7)).?);
}
test "counter continuation requires its owner and invocations require the configured ingress" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, 1);
    var turn = try selfTurn(&store);
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress, .turn = 1, .output = 0 } };
    const before = turn.decision;
    try t.expectError(error.AccessDenied, Counter.drive(t.allocator, &turn, store.client(), binding));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(null, try value(&store, 7));
    turn.delivery.input.origin = .{ .process = .{ .pid = ingress + 1, .turn = 1, .output = 0 } };
    try t.expectError(error.UnexpectedServingIngress, Counter.enqueue(&turn, ingress, .{ .kind = .call, .correlation = 1, .payload = try p.Value.init("foreign") }));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
}

test "counter direct point lookups and durable queue grow beyond resident pages" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    // Distinct rows force the immutable index beyond an inline record and a
    // resident native page. A single repeatedly updated key misses this case.
    for (0..19) |i| try enqueue(&store, i + 1, @intCast(i + 1), 1);
    for (0..19) |i| {
        try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
        for (0..i + 1) |row| try t.expectEqual(1, (try value(&store, @intCast(row + 1))).?);
    }
    var turn = try store.capture();
    var metadata = try Data.definition(store.client(), binding, Counter.schema);
    defer metadata.deinit();
    try t.expectEqual(19, metadata.value.row_count);
    try t.expectEqual(19, try (try turn.read(Counter.progress_key)).?.asInteger());
}

test "uncommitted counter preparation cannot admit its data operation" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    const input = store.native.input;
    try enqueue(&store, 1, 7, 1);
    var lost = try selfTurn(&store);
    try Counter.drive(t.allocator, &lost, store.client(), binding);
    const prepared = (try Data.inspect(t.allocator, &lost, store.native.pid, input)).?;
    try t.expectEqual(0, store.dispatches);
    try t.expectEqual(null, try value(&store, 7));
    try t.expectError(error.CounterDispatchNotCommitted, Data.advance(t.allocator, &lost, store.client(), input, prepared.invocation));
    var recovered = try selfTurn(&store);
    try Counter.drive(t.allocator, &recovered, store.client(), binding);
    try t.expectEqualDeep(lost.decision, recovered.decision);
    try store.commit(recovered);
    try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
}

test "lost Table acceptance reply recovers the original counter receipt before native progress" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, 1);
    var prepared = try selfTurn(&store);
    try Counter.drive(t.allocator, &prepared, store.client(), binding);
    try store.commit(prepared);
    store.lose_accepted_reply = true;
    for (0..32) |_| {
        var turn = try selfTurn(&store);
        const before = turn.decision;
        Counter.drive(t.allocator, &turn, store.client(), binding) catch |err| {
            try t.expectEqual(error.LostAcknowledgement, err);
            try t.expectEqualDeep(before, turn.decision);
            break;
        };
        try store.commit(turn);
    } else return error.AcceptanceFaultNotReached;
    try t.expectEqual(1, (try value(&store, 7)).?);
    var observed = try store.capture();
    try t.expectEqual(null, try observed.read(Counter.progress_key));
    const dispatches = store.dispatches;
    try t.expectEqual(1, std.mem.readInt(i64, (try complete(&store)).data[0..8], .little));
    try t.expectEqual(dispatches, store.dispatches);
    observed = try store.capture();
    try t.expectEqual(1, try (try observed.read(Counter.progress_key)).?.asInteger());
    try t.expectEqual(1, (try value(&store, 7)).?);
}

test "counter binding rejects a changed Table or namespace after initialization" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    var turn = try store.capture();
    var changed = binding;
    changed.object += 1;
    try t.expectError(error.CounterDataBindingChanged, changed.bind(&turn, false));
    changed = binding;
    changed.namespace += 1;
    try t.expectError(error.CounterDataBindingChanged, changed.bind(&turn, false));
    try binding.bind(&turn, false);
    for (turn.decision.mutations) |entry| try t.expectEqual(null, entry);
}

test "competing Table writes reject the saved counter increment without recomputing it" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    try enqueue(&store, 1, 7, 1);
    var prepared = try selfTurn(&store);
    try Counter.drive(t.allocator, &prepared, store.client(), binding);
    try store.commit(prepared);
    var metadata = try Data.definition(store.client(), binding, Counter.schema);
    defer metadata.deinit();
    const operation = 123456;
    const identity = try w.Rows.insertIdentity(.{ .scope = binding.scope, .principal = 2, .operation = operation }, 0);
    var competing = try Data.mutation(t.allocator, store.client(), metadata.value, Counter.schema, operation, .{ .identity = identity, .key = 7, .value = 41 }, true);
    defer competing.deinit();
    const reference = try Data.stage(store.client(), &competing, binding.namespace);
    const admitted = try store.client().call(.{ .admit_saved = reference });
    defer admitted.deinit();
    const committed = try store.client().call(.{ .operation = .{ .binding = reference.binding, .command = .execute, .steps = 32 } });
    defer committed.deinit();
    try t.expect(committed.value.result.rows == .committed);
    try t.expect((try complete(&store)).eql(try p.Value.init("CounterMutationRejected")));
    try t.expectEqual(41, (try value(&store, 7)).?);
    var observed = try store.capture();
    try t.expectEqual(null, try observed.read(Counter.progress_key));
}
