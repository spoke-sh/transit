//! Compose actual finite capture with watch acquisition. In-memory transaction
//! scheduling proves the handoff; disk and gateway loss have separate peers.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const s = root.station;
const p = root.protocol;
const Store = q.testing.Store;
const support = @import("table_watch_test_support.zig");
const Source = struct {
    store: *Store,
    pub fn open(self: @This(), resource: u64) !s.Turn {
        if (resource != self.store.resource or self.store.denied) return error.AccessDenied;
        return self.store.capture();
    }
};
const WatchReader = support.Reader;
fn upload(store: *Store, bundle: q.Bundle) !s.PublicationReference {
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&bytes);
    const reference = try bundle.reference(store.resource, 1);
    for (0..100) |_| {
        var turn = try store.capture();
        if (try s.PublicationUpload.step(&turn, .{ .domain = .query_request, .namespace = reference.namespace, .identity_key = q.UnifiedRecords.key('u', 1, 0), .identity = try reference.encode(), .limits = .{ .record_bytes = q.Bundle.max_bytes, .staging_bytes = q.Bundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = reference.spec, .bytes = body }} })) return reference;
        try store.commit(turn);
    }
    return error.UploadIncomplete;
}
test "a data commit during actual finite capture escapes its basis while capture bookkeeping never self-invalidates" {
    var store: Store = .{};
    defer store.deinit();
    var requests: Store = .{ .resource = 8, .pid = 9 };
    defer requests.deinit();
    const declaration = try support.create(&store, "CREATE TABLE items (id INT64 PRIMARY KEY, \"count\" INT64)");
    for (0..12) |index| {
        var sql: [128]u8 = undefined;
        try support.mutate(&store, try std.fmt.bufPrint(&sql, "INSERT INTO items VALUES ({d}, {d})", .{ index, index }));
    }
    var reader = try WatchReader.open(&store);
    const initial = try root.TableWatch.snapshot(t.allocator, &reader, support.principal, declaration);
    var table_source = try support.declaration(&store);
    defer table_source.deinit();
    const definition: q.SourceDefinition = .{ .resource = store.resource, .source = .{ .table = table_source.source } };
    const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const bundle = try q.testing.Store.signQuery(try q.Bundle.fromSql(arena.allocator(), definition, "items", "SELECT * FROM items", limits), support.principal, store.pid, requests.pid, requests.resource);
    const reference = try upload(&requests, bundle);
    try support.delegate(&store, requests.pid, requests.resource, limits);
    var turn: s.Turn = undefined;
    turn = try store.capture();
    turn.delivery.input.origin = .{ .process = .{ .pid = requests.pid, .turn = 1, .output = 0 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 77, .payload = try reference.encode() }).encode();
    const job = try q.UnifiedCapture.start(&turn, reference, Source{ .store = &requests }, arena.allocator());
    try store.commit(turn);
    reader = try WatchReader.open(&store);
    const admitted = try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expectEqual(initial.observation.data_revision, admitted.data_revision);
    const captured = try (try q.UnifiedCapture.checkpoint(&reader, job.id)).basis(bundle.source);
    try t.expect(root.TableWatch.covered(admitted, captured));
    // The retained source is already captured; this data change is newer and
    // must remain observable while later query steps read the older version.
    try support.mutate(&store, "INSERT INTO items VALUES (12, 12)");
    reader = try WatchReader.open(&store);
    const changed = try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration);
    try t.expect(!root.TableWatch.covered(changed, captured));
    const workspace = try t.allocator.alloc(u8, q.fuze.LogicalArrow.working_bytes);
    defer t.allocator.free(workspace);
    var execution_arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer execution_arena.deinit();
    const cancellation = q.fuze.execution.Cancellation.init(false);
    for (0..1000) |_| {
        turn = try store.capture();
        const current = try q.UnifiedCapture.job(&turn, job.id);
        const continuation: q.UnifiedRecords.Continuation = .{ .job = job.id, .input = current.continuation };
        turn.delivery.input.origin = .{ .process = .{ .pid = store.pid, .turn = 1, .output = 0 } };
        turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try continuation.encode() }).encode();
        _ = execution_arena.reset(.retain_capacity);
        const step = try q.UnifiedCapture.advance(&turn, continuation, Source{ .store = &requests }, execution_arena.allocator(), workspace, &cancellation);
        try store.commit(turn);
        reader = try WatchReader.open(&store);
        try t.expectEqual(changed.data_revision, (try root.TableWatch.observe(t.allocator, &reader, support.principal, declaration)).data_revision);
        if (step == .complete) break;
    } else return error.CaptureIncomplete;
    const done = try q.UnifiedCapture.job(&reader, job.id);
    try t.expectEqual(.complete, done.phase);
    const checkpoint = try q.UnifiedCapture.checkpoint(&reader, job.id);
    try t.expectEqual(@as(u64, 12), checkpoint.progress.rows);
    try t.expectEqualDeep(captured, try checkpoint.basis(bundle.source));
    try t.expect(store.versions.get(job.source).?.view.released_at != null);
    try t.expect(!root.TableWatch.covered(changed, try checkpoint.basis(bundle.source)));
    try t.expect(root.TableWatch.covered(changed, (try root.TableWatch.snapshot(t.allocator, &reader, support.principal, declaration)).observation.basis));
}
