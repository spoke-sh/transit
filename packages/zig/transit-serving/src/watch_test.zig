const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const p = root.protocol;
const r = root.ReactiveModel;
const watch = root.TableWatch;
const Store = struct {
    revision: u64 = 2,
    data_revision: u64 = 2,
    reads: usize = 0,
    mutate_at: ?usize = null,
    denied: bool = false,
    empty: bool = false,
    schema: root.station.fuze.model.Schema,
    fn open(self: *Store) Reader {
        return .{ .store = self, .view = .{ .resource = 8, .revision = self.revision } };
    }
    const Reader = struct {
        store: *Store,
        view: struct { id: u64 = 0, resource: u64, revision: u64 },
        fn check(self: *@This()) !void {
            self.store.reads += 1;
            if (self.store.mutate_at == self.store.reads) {
                self.store.revision += 1;
                self.store.data_revision = self.store.revision;
            }
            if (self.store.denied) return error.AccessDenied;
            if (self.store.revision != self.view.revision) return error.StaleStateResource;
        }
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            try self.check();
            if (key.eql(root.station.Table.descriptorKey(1))) return try root.station.Table.encodeSchema(self.store.schema);
            return null;
        }
        pub fn entry(self: *@This(), key: p.Value) !?p.Growth.Entry {
            try self.check();
            return .{ .key = key, .value = p.Value.integer(0), .revision = self.store.data_revision };
        }
        pub fn page(self: *@This(), _: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
            try self.check();
            var batch: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
            if (!self.store.empty) batch.entries[0] = .{ .key = root.station.Table.rowKey(1, 7), .value = try p.Value.init(&.{ 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 }), .revision = self.store.data_revision };
            return batch;
        }
    };
};
fn source(store: Store) !r.Source {
    return .{ .revision = 1, .target = 88, .resource = 8, .table = 1, .progress_key = try p.Value.init("data-progress"), .schema = try store.schema.fingerprint() };
}
test "snapshot acquisition cannot mix concurrent cuts; bookkeeping and empty pages do not advance data" {
    var store: Store = .{ .schema = .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 } };
    const declaration = try source(store);
    var reader = store.open();
    const initial = try watch.snapshot(&reader, declaration);
    try t.expectEqual(@as(i64, 1), initial.rows[0].?.value.?.value);
    try t.expectEqual(@as(u64, 2), initial.observation.data_revision);
    const acquisitions = store.reads;
    for (1..acquisitions + 1) |step| {
        store.reads = 0;
        store.mutate_at = step;
        reader = store.open();
        try t.expectError(error.StaleStateResource, watch.snapshot(&reader, declaration));
        store.mutate_at = null;
        reader = store.open();
        const retried = try watch.snapshot(&reader, declaration);
        try t.expectEqual(store.data_revision, retried.observation.data_revision);
    }
    const last_data = store.data_revision;
    for (0..64) |_| {
        store.revision += 1; // query/retention/status bookkeeping only
        reader = store.open();
        const observed = try watch.observe(&reader, declaration);
        try t.expectEqual(last_data, observed.data_revision);
    }
    store.empty = true;
    reader = store.open();
    const empty = try watch.snapshot(&reader, declaration);
    try t.expectEqual(last_data, empty.observation.data_revision);
    for (empty.rows) |row| try t.expect(row == null);
    try t.expect(!empty.more);
    store.schema.names[1] = try .init("new_column");
    try t.expectError(error.ReactiveResetRequired, watch.snapshot(&reader, declaration));
    store.denied = true;
    try t.expectError(error.AccessDenied, watch.snapshot(&reader, declaration));
}
test "query coverage and resume compare exact contracts rather than unrelated numeric revisions" {
    var store: Store = .{ .schema = .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 } };
    const declaration = try source(store);
    var reader = store.open();
    const initial = try watch.observe(&reader, declaration);
    try t.expect(watch.covered(initial, initial.basis));
    var captured = initial.basis;
    captured.resource += 1;
    captured.revision = 999;
    try t.expect(!watch.covered(initial, captured));
    captured = initial.basis;
    captured.contract[0] ^= 1;
    try t.expect(!watch.covered(initial, captured));
    captured = initial.basis;
    captured.schema[0] ^= 1;
    try t.expect(!watch.covered(initial, captured));
    store.revision += 1;
    store.data_revision = store.revision;
    reader = store.open();
    const newer = try watch.observe(&reader, declaration);
    try t.expect(!watch.covered(newer, initial.basis));
    const scope: r.Scope = .{ .realm = 49, .principal = 65536, .service = 1, .ingress = 9, .session = 7, .generation = 10, .subscription = 3, .subscription_generation = 12 };
    var position: r.Position = .{ .scope = scope, .watch_revision = 1, .resource = 8, .schema = declaration.schema, .data_revision = initial.data_revision };
    try watch.validateResume(position, scope, declaration, newer, 0);
    position.data_revision = newer.data_revision + 1;
    try t.expectError(error.InvalidReactiveCursor, watch.validateResume(position, scope, declaration, newer, 0));
    position.data_revision = 1;
    position.scope.session += 1;
    try t.expectError(error.InvalidReactiveCursor, watch.validateResume(position, scope, declaration, newer, 0));
    position.scope = scope;
    position.watch_revision += 1;
    try t.expectError(error.ReactiveResetRequired, watch.validateResume(position, scope, declaration, newer, 0));
}
