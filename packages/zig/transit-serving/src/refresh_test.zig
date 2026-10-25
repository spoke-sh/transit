//! Scheduler transitions over real direct Table observations and native upload
//! records. Source execution, signature checks and verified manifests are
//! injected at the Reader boundary; this is not a complete Follow proof.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const s = root.station;
const p = root.protocol;
const r = root.ReactiveModel;
const m = root.RefreshModel;
const support = @import("table_watch_test_support.zig");
const Store = q.testing.Store;
const principal = 65536;
const configuration: root.Model.Configuration = .{ .service = 10, .administrator = 11, .observer = 12 };
const owner: root.Refresh = .{ .principal = principal, .source = 3 };
const Results = std.AutoHashMapUnmanaged(u64, q.TablePosition);
const Reader = struct {
    source: *support.Store,
    requests: *Store,
    results: *Results,
    denied: bool = false,
    unavailable: bool = false,
    diagnostic: ?*root.ServingFailure.Context = null,
    pub fn withDiagnostic(self: @This(), context: ?*root.ServingFailure.Context) @This() {
        var scoped_reader = self;
        scoped_reader.diagnostic = context;
        return scoped_reader;
    }
    pub fn authorize(self: @This(), turn: *s.Turn, caller: u64, source: r.Source, credentials: m.Proof) !void {
        if (self.unavailable) return error.AuthorityUnavailable;
        if (self.denied or self.source.denied or caller != principal or source.resource != support.scope.resource or source.audience != support.connection.audience or credentials.principal != caller or credentials.pid != turn.delivery.pid or credentials.input == 0) return error.ServingDenied;
    }
    pub fn observe(self: @This(), caller: u64, source: r.Source, credentials: m.Proof) !root.TableWatch.Observation {
        if (self.unavailable) return error.AuthorityUnavailable;
        if (credentials.principal != caller) return error.ServingDenied;
        var watch = try support.Reader.open(self.source);
        return root.TableWatch.observeDiagnostic(t.allocator, &watch, caller, source, self.diagnostic);
    }
    pub fn templates(self: @This(), turn: *s.Turn, input: m.Follow, source: r.Source, credentials: m.Proof) !void {
        try self.authorize(turn, principal, source, credentials);
        try m.validateCaptures(input.captures, input.limit, input.template);
        for (input.captures[0..input.limit]) |namespace| {
            const status = (try q.UnifiedUpload.status(turn, namespace.value)) orelse return error.InvalidRefreshTemplate;
            if (status.phase != .prepared) return error.InvalidRefreshTemplate;
        }
    }
    pub fn result(self: @This(), turn: *s.Turn, namespace: u64, source: r.Source, credentials: m.Proof) !q.TablePosition {
        try self.authorize(turn, principal, source, credentials);
        const status = (try q.UnifiedUpload.status(turn, namespace)) orelse return error.InvalidRefreshTemplate;
        if (status.phase != .complete) return error.InvalidRefreshTemplate;
        return self.results.get(namespace) orelse error.InvalidRefreshTemplate;
    }
};
const Rig = struct {
    source: support.Store = .{},
    results: Results = .empty,
    next_namespace: u64 = 100,
    requests: Store = .{ .resource = 8, .pid = 9 },
    declaration: r.Source = undefined,
    fn deinit(self: *@This()) void {
        self.results.deinit(t.allocator);
        self.source.deinit();
        self.requests.deinit();
    }
    fn reader(self: *@This()) Reader {
        return .{ .source = &self.source, .requests = &self.requests, .results = &self.results };
    }
    fn command(self: *@This(), caller: u64, input: root.Model.Command) !void {
        var turn = try self.requests.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = caller, .policy_revision = 1 } };
        try (root.Service{ .configuration = configuration }).apply(&turn, input, caller);
        if (input == .reactive) switch (input.reactive) {
            .close => |identity| try root.Refresh.sessionStopped(&turn, caller, identity),
            .expire => |request| try root.Refresh.sessionStopped(&turn, request.principal, request.identity),
            else => {},
        };
        try self.requests.commit(turn);
    }
    fn mutate(self: *@This()) !void {
        var buffer: [128]u8 = undefined;
        try support.mutate(&self.source, try std.fmt.bufPrint(&buffer, "UPDATE items SET \"count\" = {d} WHERE id = 1", .{self.source.operation}));
    }
    fn init(self: *@This()) !void {
        self.declaration = try support.create(&self.source, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
        try support.mutate(&self.source, "INSERT INTO items VALUES (1, 0)");
        var turn: s.Turn = undefined;
        turn = try self.requests.capture();
        var service: root.Service = .{ .configuration = configuration };
        const handler = service.interface();
        try handler.initialize.?(handler.context, &turn);
        try self.requests.commit(turn);
        try self.command(11, .{ .publish = .{ .expected = 0, .binding = .{ .revision = 1, .target = 3, .codec = 1, .active_limit = 2, .wait_before_ms = 30000 } } });
        try self.command(11, .{ .policy = .{ .principal = principal, .expected = 0, .policy = .{ .revision = 1, .reads = true, .commands = true, .active_limit = 2 } } });
        try self.command(11, .{ .reactive = .{ .publish = .{ .expected = 0, .source = self.declaration } } });
        try self.clock(1000);
        try self.upload(1, false);
        turn = try self.requests.capture();
        _ = try q.UnifiedUpload.submit(&turn, 1, 3);
        try self.requests.commit(turn);
        try self.finish(1, false);
    }
    fn upload(self: *@This(), namespace: u64, prepared: bool) !void {
        var declaration = try support.declaration(&self.source);
        defer declaration.deinit();
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const source: q.SourceDefinition = .{ .resource = support.scope.resource, .source = .{ .table = declaration.source } };
        const bundle = try q.Bundle.fromSql(arena.allocator(), source, "items", "SELECT * FROM items", .{ .pages = 100, .segments = 100, .result_bytes = 1048576 });
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const body = try bundle.encode(&bytes);
        const ref = try bundle.reference(self.requests.resource, namespace);
        var turn = try self.requests.capture();
        try q.UnifiedUpload.begin(&turn, ref);
        try self.requests.commit(turn);
        for (0..ref.spec.chunks()) |ordinal| {
            const chunk = body[ordinal * s.Publication.chunk_bytes ..][0..try ref.spec.size(@intCast(ordinal))];
            var offset: usize = 0;
            while (offset < chunk.len) : (offset += q.UnifiedRequest.part_bytes) {
                turn = try self.requests.capture();
                try q.UnifiedUpload.part(&turn, .{ .namespace = namespace, .ordinal = @intCast(ordinal), .second = offset != 0, .bytes = chunk[offset..@min(offset + q.UnifiedRequest.part_bytes, chunk.len)] });
                try self.requests.commit(turn);
            }
        }
        turn = try self.requests.capture();
        try q.UnifiedUpload.seal(&turn, namespace);
        try self.requests.commit(turn);
        if (prepared) {
            turn = try self.requests.capture();
            try q.UnifiedUpload.prepare(&turn, namespace);
            try self.requests.commit(turn);
        }
    }
    fn clock(self: *@This(), now: u64) !void {
        try self.command(12, .{ .reactive = .{ .observe_clock = now } });
    }
    fn session(self: *@This(), id: u64) !r.SessionIdentity {
        try self.command(principal, .{ .reactive = .{ .open = .{ .session = id, .source_revision = 1, .lease_before_ms = 29000 } } });
        var turn = try self.requests.capture();
        return .{ .session = id, .generation = (try root.ReactiveService.session(&turn, principal, id)).?.generation };
    }
    fn apply(self: *@This(), input: m.Command) !void {
        var turn = try self.requests.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } };
        try owner.apply(&turn, principal, input, self.reader(), 1000);
        try self.requests.commit(turn);
    }
    fn follow(self: *@This(), identity: r.SessionIdentity, expected: u64, limit: u8) !m.Selection {
        var captures: m.Captures = @splat(.{ .value = 0 });
        for (captures[0..limit]) |*namespace| {
            namespace.* = .{ .value = self.next_namespace };
            self.next_namespace += 1;
            try self.upload(namespace.value, true);
        }
        try self.apply(.{ .follow = .{ .view = .{ .session = identity, .expected = expected, .template = .{ .value = 1 }, .captures = captures, .limit = limit } } });
        var turn = try self.requests.capture();
        return .{ .session = identity, .generation = try root.Refresh.head(&turn, principal, identity.session) };
    }
    fn view(self: *@This(), selection: m.Selection) !m.View {
        var turn = try self.requests.capture();
        return (try root.Refresh.view(&turn, principal, selection.generation)).?;
    }
    fn drive(self: *@This()) !bool {
        var turn = try self.requests.capture();
        const again = try owner.drive(&turn, self.reader(), 1000);
        try self.requests.commit(turn);
        // Reconstruct requester-local state at every scheduling/activation boundary.
        const restored = try self.requests.clone();
        self.requests.deinit();
        self.requests = restored;
        return again;
    }
    fn drain(self: *@This()) !void {
        for (0..100) |_| {
            if (!try self.drive()) return;
        }
        return error.UnboundedRefreshWake;
    }
    fn finish(self: *@This(), namespace: u64, change_during_capture: bool) !void {
        var turn = try self.requests.capture();
        const status = (try q.UnifiedUpload.status(&turn, namespace)).?;
        try t.expectEqual(.admitted, status.phase);
        // A retained direct source cut feeds the injected completed-result
        // observation. This does not execute Fuze or verify a result manifest.
        const observed = try self.reader().observe(principal, self.declaration, .{ .pid = self.requests.pid, .input = 1, .principal = principal });
        const object = self.declaration.interpretation().object;
        const pin = try self.source.catalog.pinRows(object, .{ .scope = support.scope, .principal = principal, .operation = self.source.next() }, .{ .partition = observed.basis.partition.value, .next_lsn = observed.basis.accepted.value }, self.source.policy());
        defer self.source.catalog.releaseRows(object, pin, self.source.policy()) catch unreachable;
        if (change_during_capture) try self.mutate();
        try self.results.put(t.allocator, namespace, observed.basis);
        const reference: s.PublicationReference = .{ .domain = .query_result, .resource = 17, .namespace = namespace, .record = q.UnifiedRecords.manifest_record, .spec = try s.Publication.Digest.of(q.UnifiedRecords.manifest_format, "injected scheduler result") };
        const reply: s.Frame = .{ .kind = .reply, .correlation = status.correlation, .payload = try reference.encode() };
        turn.delivery.input.value = try reply.encode();
        turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
        try t.expect(try turn.acceptReply() == .accepted);
        try q.UnifiedUpload.reply(&turn, reply, 3);
        try self.requests.commit(turn);
    }
};

test "simulation: refresh source cuts survive replacement, interruption and in-flight mutation" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    for (0..4) |round| {
        var rig: Rig = .{};
        defer rig.deinit();
        try rig.init();
        const identity = try rig.session(1);
        const selected = try rig.follow(identity, 0, 2);
        try rig.mutate();
        try rig.apply(.{ .invalidate = selected });
        try t.expect(try rig.drive());
        const interrupted = random.random().uintLessThan(u8, 4);
        for (0..interrupted) |_| {
            var turn = try rig.requests.capture();
            const before = turn.decision;
            var reader = rig.reader();
            reader.unavailable = true;
            try t.expectError(error.AuthorityUnavailable, owner.drive(&turn, reader, 1000));
            try t.expectEqualDeep(before, turn.decision);
        }
        const replace = random.random().boolean();
        const current = if (replace) try rig.follow(identity, selected.generation, 1) else selected;
        if (replace) try rig.apply(.{ .pause = current });
        try rig.drain();
        const admitted = try rig.view(selected);
        try t.expectEqual(.admitted, admitted.phase);
        const changed = random.random().boolean();
        try rig.finish(admitted.namespace.value, changed);
        try rig.drain();
        try t.expectEqual(.ready, (try rig.view(selected)).phase);
        var turn = try rig.requests.capture();
        const status = (try q.UnifiedUpload.status(&turn, admitted.namespace.value)).?;
        try t.expectEqual(.complete, status.phase);
        const basis = try rig.reader().result(&turn, admitted.namespace.value, rig.declaration, .{ .pid = turn.delivery.pid, .input = admitted.generation, .principal = principal });
        try t.expectEqual(support.scope.resource, basis.resource);
        if (replace) {
            try t.expectError(error.RefreshGenerationConflict, rig.apply(.{ .acknowledged = .{ .selection = selected, .namespace = admitted.namespace } }));
            try t.expectEqual(.paused, (try rig.view(current)).phase);
        } else {
            try rig.apply(.{ .acknowledged = .{ .selection = selected, .namespace = admitted.namespace } });
            const view = try rig.view(selected);
            if (changed) try t.expect(view.dirty.value > view.covered.value) else try t.expect(view.covered.value >= view.dirty.value);
        }
        rig.source.denied = true;
        try t.expectError(error.ServingDenied, rig.reader().result(&turn, admitted.namespace.value, rig.declaration, .{ .pid = turn.delivery.pid, .input = admitted.generation, .principal = principal }));
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"refresh\",\"round\":{d},\"interruptions\":{d},\"replaced\":{},\"mutated\":{}}}\n", .{ round, interrupted, replace, changed });
    }
}

test "fair requester refresh recovers each cut and converges after a mutation following the selected source cut" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const first = try rig.follow(try rig.session(1), 0, 2);
    const second = try rig.follow(try rig.session(2), 0, 2);
    try t.expect(!try rig.drive()); // Capture bookkeeping is not relevant data.
    try rig.mutate();
    try rig.apply(.{ .invalidate = first });
    try rig.apply(.{ .invalidate = second });
    try rig.drain();
    const a = try rig.view(first);
    try t.expectEqual(.admitted, a.phase);
    try t.expectEqual(.idle, (try rig.view(second)).phase);
    try rig.finish(a.namespace.value, true);
    try rig.drain();
    try t.expectEqual(.ready, (try rig.view(first)).phase);
    const b = try rig.view(second);
    try t.expectEqual(.admitted, b.phase); // Round-robin grants the other tab.
    try rig.apply(.{ .acknowledged = .{ .selection = first, .namespace = a.namespace } });
    try t.expect((try rig.view(first)).dirty.value > (try rig.view(first)).covered.value);
    try rig.finish(b.namespace.value, false);
    try rig.drain();
    try rig.apply(.{ .acknowledged = .{ .selection = second, .namespace = b.namespace } });
    try t.expect(!try rig.drive()); // Minimum start interval still enforced.
    try rig.clock(2000);
    try rig.drain();
    const successor = try rig.view(first);
    try t.expectEqual(.admitted, successor.phase);
    try t.expect(successor.namespace.value != a.namespace.value);
    try rig.finish(successor.namespace.value, false);
    try rig.drain();
    try rig.apply(.{ .acknowledged = .{ .selection = first, .namespace = successor.namespace } });
    try t.expectEqual(.exhausted, (try rig.view(first)).phase);
    try t.expect((try rig.view(first)).covered.value >= (try rig.view(first)).dirty.value);
    for (0..8) |_| try t.expect(!try rig.drive());
    var turn = try rig.requests.capture();
    for ([_]u64{ 1, a.namespace.value, b.namespace.value, successor.namespace.value }) |namespace| try t.expectEqual(.complete, (try q.UnifiedUpload.status(&turn, namespace)).?.phase);
}

test "pause and generation replacement do not cancel selected work or accept stale acknowledgments" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const identity = try rig.session(1);
    const old = try rig.follow(identity, 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = old });
    try t.expect(try rig.drive()); // Selection is durable before activation.
    try rig.apply(.{ .pause = old });
    const next = try rig.follow(identity, old.generation, 1);
    try rig.drain();
    const prior = try rig.view(old);
    try t.expectEqual(.admitted, prior.phase);
    try rig.finish(prior.namespace.value, false);
    try t.expect(try rig.drive());
    try t.expectError(error.RefreshGenerationConflict, rig.apply(.{ .acknowledged = .{ .selection = old, .namespace = prior.namespace } }));
    try rig.apply(.{ .pause = next });
    try rig.drain();
    try t.expectEqual(.ready, (try rig.view(old)).phase);
    try t.expectEqual(.paused, (try rig.view(next)).phase);
}

test "manual admission blocks wakeups; current denial, outage and wall-clock expiry are distinct" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const selection = try rig.follow(try rig.session(1), 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selection });
    try t.expect(try rig.drive());
    var turn = try rig.requests.capture();
    var manual = (try q.UnifiedUpload.status(&turn, 1)).?.reference;
    manual.namespace = 2;
    try q.UnifiedUpload.begin(&turn, manual);
    try rig.requests.commit(turn);
    turn = try rig.requests.capture();
    try t.expect(!try owner.drive(&turn, rig.reader(), 1000));
    try t.expect(turn.decision.mutations[0] == null);
    try q.UnifiedUpload.cancel(&turn, 2);
    try rig.requests.commit(turn);
    for (0..100) |_| {
        turn = try rig.requests.capture();
        const done = try q.UnifiedUpload.collect(&turn, 2);
        try rig.requests.commit(turn);
        if (done) break;
    } else return error.CleanupIncomplete;
    var unavailable = rig.reader();
    unavailable.unavailable = true;
    turn = try rig.requests.capture();
    try t.expectError(error.AuthorityUnavailable, owner.drive(&turn, unavailable, 1000));
    try t.expect(turn.decision.mutations[0] == null);
    try t.expect(try rig.drive()); // Activates the selected prepared upload.
    var revoked = rig.reader();
    revoked.denied = true;
    turn = try rig.requests.capture();
    try t.expect(try owner.drive(&turn, revoked, 1000));
    try rig.requests.commit(turn);
    try rig.drain();
    try t.expectEqual(.denied, (try rig.view(selection)).phase);
    const replacement = try rig.follow(selection.session, selection.generation, 1);
    turn = try rig.requests.capture();
    try t.expect(try owner.drive(&turn, rig.reader(), 29000)); // No observer clock update required.
    try rig.requests.commit(turn);
    try t.expectEqual(.paused, (try rig.view(replacement)).phase);
}

test "explicit admission of the selected prepared request preserves its original call" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const selection = try rig.follow(try rig.session(1), 0, 1);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selection });
    try t.expect(try rig.drive());
    const namespace = (try rig.view(selection)).namespace.value;
    var turn = try rig.requests.capture();
    try q.UnifiedUpload.activate(&turn, namespace);
    try rig.requests.commit(turn);
    turn = try rig.requests.capture();
    const correlation = try q.UnifiedUpload.submit(&turn, namespace, 3);
    try rig.requests.commit(turn);
    try t.expect(!try rig.drive());
    try t.expectEqual(.admitted, (try rig.view(selection)).phase);
    turn = try rig.requests.capture();
    try t.expectEqual(correlation, (try q.UnifiedUpload.status(&turn, namespace)).?.correlation);
    for (turn.decision.outputs) |output| try t.expect(output == null);
    try rig.finish(namespace, false);
    try rig.drain();
    try t.expectEqual(.ready, (try rig.view(selection)).phase);
}

test "composed live owner initializes within four writes and fences internal controls before dispatch" {
    var store: Store = .{ .resource = 8, .pid = 9 };
    defer store.deinit();
    var live: root.LiveService = .{ .configuration = .{ .service = configuration, .query_principal = principal, .source = 3 }, .resources = undefined, .scratch = &.{}, .upper_ms = 1000 };
    const handler = live.interface();
    const guard = live.guard();
    var turn = try store.capture();
    try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
    try handler.initialize.?(handler.context, &turn);
    turn.delivery.input.origin = .{ .external = .{ .principal = 11, .policy_revision = 1 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try root.Model.Command.encode(.initialize) }).encode();
    try t.expect(!try guard.reject(guard.context, &turn));
    try handler.handle(handler.context, &turn, try s.Frame.decode(turn.delivery.input.value));
    try store.commit(turn);
    try t.expect(turn.decision.outputs[0] == null);
    for ([_]p.Value{ root.RefreshModel.wake, try q.UnifiedRequest.Command.encode(.{ .collect = 1 }), try q.UnifiedRequest.Command.encode(.initialize) }) |payload| {
        turn = try store.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = 999, .policy_revision = 1 } };
        turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = payload }).encode();
        try t.expect(try guard.reject(guard.context, &turn));
        if (std.mem.startsWith(u8, payload.slice(), "UQ")) try t.expect(try turn.read(q.UnifiedRecords.key('e', turn.delivery.input.position, 0)) != null);
        try store.commit(turn);
    }
    turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode();
    try t.expect(!try guard.reject(guard.context, &turn));
    try handler.handle(handler.context, &turn, try s.Frame.decode(turn.delivery.input.value));
    try store.commit(turn);
}

test "occupied refresh namespace fails one view and preserves ingress progress" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const selection = try rig.follow(try rig.session(1), 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selection });
    var turn = try rig.requests.capture();
    const captures = try root.Codec.decode(m.Captures, 'K', (try turn.read(m.capturesKey(principal, selection.generation))).?);
    const namespace = captures[0].value;
    try q.UnifiedUpload.cancel(&turn, namespace);
    try rig.requests.commit(turn);
    const original = (try q.UnifiedUpload.status(&turn, namespace)).?;
    turn = try rig.requests.capture();
    try t.expect(try owner.drive(&turn, rig.reader(), 1000));
    try rig.requests.commit(turn);
    const value = try rig.view(selection);
    try t.expectEqual(.failed, value.phase);
    try t.expect(!value.enabled);
    try t.expectEqual(@as(u8, 0), value.starts);
    turn = try rig.requests.capture();
    try t.expectEqualDeep(original, (try q.UnifiedUpload.status(&turn, namespace)).?);
    try t.expect(!try rig.drive());
}

test "Follow reports an explicitly closed session independently of lease expiry" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const identity = try rig.session(1);
    const selection = try rig.follow(identity, 0, 2);
    try rig.command(principal, .{ .reactive = .{ .close = identity } });
    try t.expectError(error.ReactiveSessionClosed, rig.apply(.{ .invalidate = selection }));
    try t.expectError(error.ReactiveSessionClosed, rig.follow(identity, selection.generation, 2));
    try rig.apply(.{ .pause = selection });
    try t.expectEqual(.paused, (try rig.view(selection)).phase);
}

test "closure retains original stop and does not cancel selected work" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const identity = try rig.session(1);
    const selected = try rig.follow(identity, 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selected });
    try t.expect(try rig.drive());
    try rig.command(principal, .{ .reactive = .{ .close = identity } });
    const stopped = try rig.view(selected);
    try t.expect(!stopped.enabled);
    try t.expectEqual(.preparing, stopped.phase);
    try t.expectEqual(.session_closed, stopped.failure.stopped.reason);
    try t.expectEqual(.closed, stopped.failure.stopped.witness.session.phase);
    try rig.command(principal, .{ .reactive = .{ .close = identity } });
    try rig.apply(.{ .pause = selected });
    try t.expectEqualDeep(stopped.failure, (try rig.view(selected)).failure);
    try rig.drain();
    const admitted = try rig.view(selected);
    try t.expectEqual(.admitted, admitted.phase);
    try rig.finish(admitted.namespace.value, false);
    try rig.drain();
    const ready = try rig.view(selected);
    try t.expectEqual(.ready, ready.phase);
    try t.expectEqualDeep(stopped.failure, ready.failure);
}

test "original service policy denial survives restored rights and owner reconstruction" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const selected = try rig.follow(try rig.session(1), 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selected });
    try rig.command(11, .{ .policy = .{ .principal = principal, .expected = 1, .policy = .{ .revision = 2, .reads = false, .commands = true, .active_limit = 2 } } });
    try rig.drain();
    const stopped = try rig.view(selected);
    try t.expectEqual(.denied, stopped.phase);
    try t.expectEqual(.service_denied, stopped.failure.stopped.reason);
    try t.expectEqual(@as(u64, 2), stopped.failure.stopped.witness.policy.revision);
    try t.expect(!stopped.failure.stopped.witness.policy.reads);
    try rig.command(11, .{ .policy = .{ .principal = principal, .expected = 2, .policy = .{ .revision = 3, .reads = true, .commands = true, .active_limit = 2 } } });
    try rig.drain();
    try t.expectEqualDeep(stopped, try rig.view(selected));
}

test "cancelled selected upload stops Follow before bounded collection" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    const selected = try rig.follow(try rig.session(1), 0, 2);
    try rig.mutate();
    try rig.apply(.{ .invalidate = selected });
    try t.expect(try rig.drive());
    try t.expect(try rig.drive()); // Activates the selected prepared upload.
    const preparing = try rig.view(selected);
    var turn = try rig.requests.capture();
    try q.UnifiedUpload.cancel(&turn, preparing.namespace.value);
    try rig.requests.commit(turn);
    try rig.drain();
    const stopped = try rig.view(selected);
    try t.expectEqual(.paused, stopped.phase);
    try t.expect(!stopped.enabled);
    try t.expectEqual(.query_cancelled, stopped.failure.stopped.reason);
    turn = try rig.requests.capture();
    const work = (try q.UnifiedUpload.status(&turn, preparing.namespace.value)).?;
    try t.expectEqual(.cancelled, work.phase);
    try t.expect(work.collected);
    try t.expectEqual(@as(u64, 0), (try root.Refresh.scheduler(&turn)).generation);
}

test "watch detects changed direct interpretations under current rights" {
    var rig: Rig = .{};
    defer rig.deinit();
    try rig.init();
    var declaration = rig.declaration;
    declaration.interpretation_digest = @splat(255);
    try t.expectError(error.ReactiveResetRequired, rig.reader().observe(principal, declaration, .{ .pid = rig.requests.pid, .input = 1, .principal = principal }));
    rig.source.denied = true;
    try t.expectError(error.CatalogDenied, rig.reader().observe(principal, declaration, .{ .pid = rig.requests.pid, .input = 1, .principal = principal }));
}

test "selected query failure stays independent of earlier stop and classifies only permission denial as denied" {
    for ([_]q.QueryFailure.Code{ .resource_unavailable, .policy_denied, .arithmetic_overflow }) |code| {
        var rig: Rig = .{};
        defer rig.deinit();
        try rig.init();
        const selected = try rig.follow(try rig.session(1), 0, 2);
        try rig.mutate();
        try rig.apply(.{ .invalidate = selected });
        try rig.drain();
        const admitted = try rig.view(selected);
        try t.expectEqual(.admitted, admitted.phase);
        if (code == .arithmetic_overflow) try rig.apply(.{ .pause = selected });
        const prior = try rig.view(selected);
        var turn = try rig.requests.capture();
        const work = (try q.UnifiedUpload.status(&turn, admitted.namespace.value)).?;
        const failure: q.QueryFailure = .{ .code = code, .stage = .execution };
        const reply: s.Frame = .{ .kind = .reply, .correlation = work.correlation, .payload = try failure.encode() };
        turn.delivery.input.value = try reply.encode();
        turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
        try t.expect(try turn.acceptReply() == .accepted);
        try q.UnifiedUpload.reply(&turn, reply, 3);
        try rig.requests.commit(turn);
        try rig.drain();
        const stopped = try rig.view(selected);
        try t.expectEqual(if (code == .policy_denied) m.Phase.denied else m.Phase.failed, stopped.phase);
        if (code == .arithmetic_overflow) try t.expectEqualDeep(prior.failure, stopped.failure) else try t.expectEqual(.query_rejected, stopped.failure.stopped.reason);
        turn = try rig.requests.capture();
        const outcome = (try q.UnifiedUpload.status(&turn, admitted.namespace.value)).?;
        try t.expectEqual(code, outcome.failure.?.code);
        const diagnostic = (try q.Bridge.statusDiagnostic(outcome)).?;
        try t.expectEqual(.rejected, diagnostic.outcome);
    }
}
