//! Compose actual finite capture with watch acquisition. In-memory transaction
//! scheduling proves the handoff; disk and gateway loss have separate peers.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const s = root.station;
const p = root.protocol;
const Store = q.testing.Store;
const progress_key = p.Value.init("data-progress") catch unreachable;
const Source = struct {
    store: *Store,
    pub fn open(self: @This(), resource: u64) !s.GrowingTurn {
        if (resource != self.store.resource or self.store.denied) return error.AccessDenied;
        return self.store.capture();
    }
};
const WatchReader = struct {
    store: *Store,
    turn: s.GrowingTurn,
    view: p.Growth.View,
    fn open(store: *Store) !@This() {
        const turn = try store.capture();
        return .{ .store = store, .turn = turn, .view = turn.view };
    }
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        return self.turn.read(key);
    }
    pub fn page(self: *@This(), after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
        return self.turn.page(after);
    }
    pub fn entry(self: *@This(), key: p.Value) !?p.Growth.Entry {
        if (self.store.denied) return error.AccessDenied;
        if (self.store.revision != self.view.revision) return error.StaleStateResource;
        return if (self.store.state.get(key)) |value| .{ .key = key, .value = value, .revision = self.store.revisions.get(key).? } else null;
    }
};
fn upload(store: *Store, bundle: q.Bundle) !s.PublicationReference {
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    const reference = try bundle.reference(store.resource, 1);
    for (0..100) |_| {
        var turn = try store.capture();
        if (try s.PublicationUpload.step(&turn, .{ .namespace = reference.namespace, .identity_key = q.UnifiedRecords.key('u', 1, 0), .identity = try reference.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = reference.spec, .bytes = body }} })) return reference;
        try store.commit(turn);
    }
    return error.UploadIncomplete;
}
test "a data commit during actual finite capture escapes its basis while capture bookkeeping never self-invalidates" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    var turn = try store.capture();
    const table = try s.Table.create(&turn, 1, .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 });
    try turn.put(progress_key, p.Value.integer(0));
    try store.commit(turn);
    for (0..12) |index| {
        turn = try store.capture();
        try table.upsert(&turn, .{ .key = @intCast(index), .value = .{ .int64 = @intCast(index) } });
        try turn.put(progress_key, p.Value.integer(@intCast(index + 1)));
        try store.commit(turn);
    }
    const declaration: root.ReactiveModel.Source = .{ .revision = 1, .target = store.pid, .resource = store.resource, .table = table.id, .progress_key = progress_key, .schema = try table.schema.fingerprint() };
    var reader = try WatchReader.open(&store);
    const initial = try root.TableWatch.snapshot(&reader, declaration);
    const definition: q.SourceDefinition = .{ .resource = store.resource, .source = .{ .table = .{ .id = table.id, .schema = table.schema } } };
    const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
    const reference = try upload(&requests, .{ .source = definition, .plan = .{ .projection = &.{ 0, 1 } }, .limits = limits });
    turn = try store.capture();
    try q.UnifiedCapture.setPolicy(&turn, .{ .peer = requests.pid, .requests = requests.resource, .revision = 1, .allow = true, .limits = limits, .declaration = try q.Bundle.declaration(definition) });
    try store.commit(turn);
    turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = requests.pid, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 77, .payload = try reference.encode() }).encode();
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const job = try q.UnifiedCapture.start(&turn, reference, Source{ .store = &requests }, arena.allocator());
    try store.commit(turn);
    reader = try WatchReader.open(&store);
    const admitted = try root.TableWatch.observe(&reader, declaration);
    try t.expectEqual(initial.observation.data_revision, admitted.data_revision);
    const captured = (try q.UnifiedCapture.checkpoint(&reader, job.id)).progress.basis;
    try t.expect(root.TableWatch.covered(admitted, captured));
    // The retained source is already captured; this data change is newer and
    // must remain observable while later query steps read the older version.
    turn = try store.capture();
    try table.upsert(&turn, .{ .key = 12, .value = .{ .int64 = 12 } });
    try turn.put(progress_key, p.Value.integer(13));
    try store.commit(turn);
    reader = try WatchReader.open(&store);
    const changed = try root.TableWatch.observe(&reader, declaration);
    try t.expect(!root.TableWatch.covered(changed, captured));
    const workspace = try t.allocator.alloc(u8, q.fuze.Unified.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    const cancellation = q.fuze.execution.Cancellation.init(false);
    for (0..1000) |_| {
        turn = try store.capture();
        const current = try q.UnifiedCapture.job(&turn, job.id);
        const continuation: q.UnifiedRecords.Continuation = .{ .job = job.id, .input = current.continuation };
        turn.delivery.input.origin = .{ .process = .{ .pid = store.pid, .turn = 1, .output = 0 } };
        turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try continuation.encode() }).encode();
        _ = arena.reset(.retain_capacity);
        const step = try q.UnifiedCapture.advance(&turn, continuation, Source{ .store = &requests }, arena.allocator(), workspace, &cancellation);
        try store.commit(turn);
        reader = try WatchReader.open(&store);
        try t.expectEqual(changed.data_revision, (try root.TableWatch.observe(&reader, declaration)).data_revision);
        if (step == .complete) break;
    } else return error.CaptureIncomplete;
    const done = try q.UnifiedCapture.job(&reader, job.id);
    try t.expectEqual(.complete, done.phase);
    const checkpoint = try q.UnifiedCapture.checkpoint(&reader, job.id);
    try t.expectEqual(@as(u64, 12), checkpoint.progress.rows);
    try t.expectEqualDeep(captured, checkpoint.progress.basis);
    try t.expect(store.versions.get(job.source).?.view.released_at != null);
    try t.expect(!root.TableWatch.covered(changed, checkpoint.progress.basis));
    try t.expect(root.TableWatch.covered(changed, (try root.TableWatch.snapshot(&reader, declaration)).observation.basis));
}
