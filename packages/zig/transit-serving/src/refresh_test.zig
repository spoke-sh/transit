//! Scheduling over real uploads, captures and result manifests. The reference
//! stores prove committed transitions; physical recovery is a separate proof.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const s = root.station;
const p = root.protocol;
const r = root.ReactiveModel;
const m = root.RefreshModel;
const Store = q.testing.Store;
const principal = 65536;
const configuration: root.Model.Configuration = .{ .service = 10, .administrator = 11, .observer = 12 };
const owner: root.Refresh = .{ .principal = principal, .source = 3 };
const proof: m.Proof = .{ .identity = @splat(1), .source = @splat(2), .requester = @splat(3) };
const Reader = struct {
    source: *Store,
    requests: *Store,
    denied: bool = false,
    unavailable: bool = false,
    pub fn open(self: @This(), resource: u64) !s.Turn {
        if (self.unavailable) return error.AuthorityUnavailable;
        const store = if (resource == self.source.resource) self.source else if (resource == self.requests.resource) self.requests else return error.AccessDenied;
        if (store.denied) return error.AccessDenied;
        return store.capture();
    }
    pub fn authorize(self: @This(), caller: u64, source: r.Source, credentials: m.Proof) !void {
        if (self.unavailable) return error.AuthorityUnavailable;
        if (self.denied or caller != principal or source.resource != self.source.resource or source.target != self.source.pid or !std.meta.eql(credentials, proof)) return error.ServingDenied;
    }
    const Watch = struct {
        turn: s.Turn,
        store: *Store,
        view: p.Growth.View,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            return self.turn.read(key);
        }
        pub fn entry(self: *@This(), key: p.Value) !?p.Growth.Entry {
            if (self.store.denied) return error.AccessDenied;
            return if (self.store.state.get(key)) |value| .{ .key = key, .value = value, .revision = self.store.revisions.get(key).? } else null;
        }
    };
    pub fn observe(self: @This(), source: r.Source) !root.TableWatch.Observation {
        const turn = try self.open(source.resource);
        var watch: Watch = .{ .turn = turn, .store = self.source, .view = turn.view };
        return root.TableWatch.observe(&watch, source);
    }
    pub fn result(self: @This(), turn: *s.Turn, namespace: u64, source: r.Source) !q.fuze.Unified.Basis {
        const status = (try q.UnifiedUpload.status(turn, namespace)) orelse return error.InvalidRefreshTemplate;
        if (status.phase != .complete) return error.InvalidRefreshTemplate;
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const opened = try q.UnifiedResult.open(status.manifest.?, .{ .resource = source.resource, .source = source.target, .requester = turn.delivery.pid, .correlation = status.correlation, .request = status.reference }, self, arena.allocator());
        return opened.manifest.checkpoint.progress.basis;
    }
};
const Rig = struct {
    source: Store = .{},
    requests: Store = .{ .resource = 8, .pid = 9 },
    declaration: r.Source = undefined,
    fn deinit(self: *@This()) void {
        self.source.deinit();
        self.requests.deinit();
    }
    fn reader(self: *@This()) Reader {
        return .{ .source = &self.source, .requests = &self.requests };
    }
    fn command(self: *@This(), caller: u64, input: root.Model.Command) !void {
        var turn = try self.requests.capture();
        turn.delivery.input.origin = .{ .external = .{ .principal = caller, .policy_revision = 1 } };
        try (root.Service{ .configuration = configuration }).apply(&turn, input, caller);
        try self.requests.commit(turn);
    }
    fn mutate(self: *@This()) !void {
        var turn = try self.source.capture();
        const table = try s.Table.open(&turn, 1);
        try table.upsert(&turn, .{ .key = 1, .value = .{ .int64 = @intCast(self.source.revision) } });
        try turn.put(self.declaration.progress_key, p.Value.integer(@intCast(self.source.revision)));
        try self.source.commit(turn);
    }
    fn init(self: *@This()) !void {
        var turn = try self.source.capture();
        const table = try s.Table.create(&turn, 1, .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 });
        self.declaration = .{ .revision = 1, .target = 3, .resource = 7, .table = 1, .progress_key = try p.Value.init("progress"), .schema = try table.schema.fingerprint() };
        try turn.put(self.declaration.progress_key, p.Value.integer(0));
        try self.source.commit(turn);
        try self.mutate();
        const bundle: q.Bundle = .{ .source = .{ .resource = 7, .source = .{ .table = .{ .id = 1, .schema = table.schema } } }, .plan = .{ .projection = &.{ 0, 1 } }, .limits = .{ .pages = 100, .segments = 100, .result_bytes = 1048576 } };
        turn = try self.source.capture();
        try q.UnifiedCapture.setPolicy(&turn, .{ .peer = 9, .requests = 8, .revision = 1, .allow = true, .limits = bundle.limits, .declaration = try q.Bundle.declaration(bundle.source) });
        try self.source.commit(turn);
        turn = try self.requests.capture();
        var service: root.Service = .{ .configuration = configuration };
        const handler = service.interface();
        try handler.initialize.?(handler.context, &turn);
        try self.requests.commit(turn);
        try self.command(11, .{ .publish = .{ .expected = 0, .binding = .{ .revision = 1, .target = 3, .codec = 1, .active_limit = 2, .wait_before_ms = 30000 } } });
        try self.command(11, .{ .policy = .{ .principal = principal, .expected = 0, .policy = .{ .revision = 1, .reads = true, .commands = true, .active_limit = 2 } } });
        try self.command(11, .{ .reactive = .{ .publish = .{ .expected = 0, .source = self.declaration } } });
        try self.clock(1000);
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const body = try bundle.encode(&bytes);
        const ref = try bundle.reference(8, 1);
        turn = try self.requests.capture();
        try q.UnifiedUpload.begin(&turn, ref);
        try self.requests.commit(turn);
        for (0..ref.spec.chunks()) |ordinal| {
            const chunk = body[ordinal * s.Publication.chunk_bytes ..][0..try ref.spec.size(@intCast(ordinal))];
            var offset: usize = 0;
            while (offset < chunk.len) : (offset += q.UnifiedRequest.part_bytes) {
                turn = try self.requests.capture();
                try q.UnifiedUpload.part(&turn, .{ .namespace = 1, .ordinal = @intCast(ordinal), .second = offset != 0, .bytes = chunk[offset..@min(offset + q.UnifiedRequest.part_bytes, chunk.len)] });
                try self.requests.commit(turn);
            }
        }
        turn = try self.requests.capture();
        try q.UnifiedUpload.seal(&turn, 1);
        try self.requests.commit(turn);
        turn = try self.requests.capture();
        _ = try q.UnifiedUpload.submit(&turn, 1, 3);
        try self.requests.commit(turn);
        try self.finish(1, false);
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
        try self.apply(.{ .follow = .{ .view = .{ .session = identity, .expected = expected, .template = .{ .value = 1 }, .limit = limit }, .proof = proof } });
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
        // Reconstruct requester-local state at every scheduling/copy boundary.
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
        var request_turn = try self.requests.capture();
        const status = (try q.UnifiedUpload.status(&request_turn, namespace)).?;
        try t.expectEqual(.admitted, status.phase);
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        var turn = try self.source.capture();
        turn.delivery.input.origin = .{ .process = .{ .pid = 9, .turn = 1, .output = 0 } };
        turn.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = status.correlation, .payload = try status.reference.encode() }).encode();
        const job = try q.UnifiedCapture.start(&turn, status.reference, self.reader(), arena.allocator());
        try self.source.commit(turn);
        if (change_during_capture) try self.mutate();
        const workspace = try t.allocator.alloc(u8, q.fuze.Unified.Arrow.working_bytes);
        defer t.allocator.free(workspace);
        const cancellation = q.fuze.execution.Cancellation.init(false);
        for (0..1000) |_| {
            turn = try self.source.capture();
            const current = try q.UnifiedCapture.job(&turn, job.id);
            const continuation: q.UnifiedRecords.Continuation = .{ .job = job.id, .input = current.continuation };
            turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
            turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try continuation.encode() }).encode();
            _ = arena.reset(.retain_capacity);
            const step = try q.UnifiedCapture.advance(&turn, continuation, self.reader(), arena.allocator(), workspace, &cancellation);
            try self.source.commit(turn);
            if (step != .complete) continue;
            for (turn.decision.outputs) |slot| if (slot) |output| {
                const frame = try s.Frame.decode(output.value);
                if (frame.kind != .reply) continue;
                request_turn = try self.requests.capture();
                request_turn.delivery.input.value = output.value;
                request_turn.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
                try t.expect(try request_turn.acceptReply() == .accepted);
                try q.UnifiedUpload.reply(&request_turn, frame, 3);
                try self.requests.commit(request_turn);
                return;
            };
            return error.MissingResultReply;
        }
        return error.CaptureIncomplete;
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
        const basis = try rig.reader().result(&turn, admitted.namespace.value, rig.declaration);
        try t.expectEqual(rig.source.resource, basis.resource);
        if (replace) {
            try t.expectError(error.RefreshGenerationConflict, rig.apply(.{ .acknowledged = .{ .selection = selected, .namespace = admitted.namespace } }));
            try t.expectEqual(.paused, (try rig.view(current)).phase);
        } else {
            try rig.apply(.{ .acknowledged = .{ .selection = selected, .namespace = admitted.namespace } });
            const view = try rig.view(selected);
            if (changed) try t.expect(view.dirty > view.covered) else try t.expect(view.covered >= view.dirty);
        }
        rig.source.denied = true;
        try t.expectError(error.AccessDenied, rig.reader().result(&turn, admitted.namespace.value, rig.declaration));
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"refresh\",\"round\":{d},\"interruptions\":{d},\"replaced\":{},\"mutated\":{}}}\n", .{ round, interrupted, replace, changed });
    }
}

test "fair requester refresh recovers each cut and converges after a mutation during real capture" {
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
    try t.expect((try rig.view(first)).dirty > (try rig.view(first)).covered);
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
    try t.expect((try rig.view(first)).covered >= (try rig.view(first)).dirty);
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
    try t.expect(try rig.drive()); // Intent is durable before copying starts.
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
    try t.expect(try rig.drive()); // Begins copied upload.
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
    const namespace = (@as(u64, 1) << 63) | turn.delivery.input.position;
    const key = s.Publication.key(.query_request, namespace, 'b', 0, 0);
    const original = try p.Value.init("occupied");
    try rig.requests.state.put(t.allocator, key, original);
    try rig.requests.revisions.put(t.allocator, key, rig.requests.revision);
    try t.expect(try owner.drive(&turn, rig.reader(), 1000));
    try rig.requests.commit(turn);
    const value = try rig.view(selection);
    try t.expectEqual(.failed, value.phase);
    try t.expect(!value.enabled);
    try t.expectEqual(@as(u8, 0), value.starts);
    try t.expectEqualDeep(original, rig.requests.state.get(key).?);
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
