const std = @import("std");
const t = std.testing;
const m = @import("LogicalChange.zig");
const Bytes = @import("Bytes.zig").Bytes;
const Index = struct {
    pub const Key = Bytes(128);
    pub const Value = Bytes(256);
    const Entry = struct { key: Key, value: Value };
    const Store = struct { records: []Entry, used: usize = 0 };
    count: usize = 0,
    pub fn get(self: Index, store: *Store, key: Key) !?Value {
        var i = self.count;
        while (i != 0) {
            i -= 1;
            if (Key.eql(store.records[i].key, key)) return store.records[i].value;
        }
        return null;
    }
    pub fn put(self: Index, store: *Store, key: Key, value: Value) !Index {
        if (self.count != store.used or store.used == store.records.len) return error.TestStoreFull;
        store.records[store.used] = .{ .key = key, .value = value };
        store.used += 1;
        return .{ .count = store.used };
    }
};
const Tree = @import("CausalTree.zig").CausalTree(Index);
fn dot(replica: u8, sequence: u64, ordinal: u16) m.Dot {
    var id: [16]u8 = @splat(0);
    id[15] = replica;
    return .{ .replica = id, .sequence = sequence, .ordinal = ordinal };
}
test "logical canonical changes borrow wide fields and reject every truncated prefix" {
    const name: [257]u8 = @splat('n');
    const value: [4097]u8 = @splat('x');
    const header: m.Header = .{ .definition = @splat(3), .document = @splat(1), .replica = @splat(2), .epoch = 1, .sequence = 1, .preceding_sequence = 0, .operations = 1 };
    var buffer: [8192]u8 = undefined;
    const bytes = try m.encode(header, &.{.{ .field = &name, .value = .{ .kind = .string, .bytes = &value } }}, &buffer);
    try t.expectEqualStrings("DCHANGE1", bytes[0..8]);
    try t.expectEqualSlices(u8, &.{ 1, 0, 0, 0, 0, 0, 0, 0 }, bytes[56..64]);
    for (0..bytes.len) |end| {
        var decoder = m.Decoder.init(bytes[0..end]) catch continue;
        _ = decoder.next() catch continue;
        return error.AcceptedTruncatedChange;
    }
    var decoder = try m.Decoder.init(bytes);
    const op = (try decoder.next()).?;
    try t.expectEqualSlices(u8, &name, op.field);
    try t.expectEqualSlices(u8, &value, op.value.?.bytes);
    try t.expect(op.value.?.bytes.ptr == bytes[bytes.len - value.len ..].ptr);
    try t.expect((try decoder.next()) == null);
    buffer[bytes.len] = 0;
    decoder = try m.Decoder.init(buffer[0 .. bytes.len + 1]);
    _ = try decoder.next();
    try t.expectError(error.InvalidDocumentEncoding, decoder.next());
    var observed: [52]u8 = undefined;
    observed[0..26].* = dot(2, 1, 0).bytes();
    observed[26..52].* = dot(1, 1, 0).bytes();
    try t.expectError(error.InvalidLogicalOperation, (m.Operation{ .field = "x", .observed = &observed, .value = null }).validate());
}
test "logical observed-remove permutations converge and replacement detaches old descendants" {
    const records = try t.allocator.alloc(Index.Entry, 1024);
    defer t.allocator.free(records);
    var store: Index.Store = .{ .records = records };
    for ([_]bool{ false, true }) |reverse| {
        store.used = 0;
        var tree: Tree = .{ .limits = .{ .depth = 16, .conflicts = 8, .steps = 4096 } };
        const first = dot(if (reverse) 2 else 1, 1, 0);
        const second = dot(if (reverse) 1 else 2, 1, 0);
        try tree.applyOperation(&store, first, .{ .field = "x", .value = .{ .kind = .string, .bytes = if (reverse) "B" else "A" } });
        try tree.applyOperation(&store, second, .{ .field = "x", .value = .{ .kind = .string, .bytes = if (reverse) "A" else "B" } });
        const conflict = try tree.lookup(&store, &.{"x"});
        try t.expectEqual(.conflict, conflict.status);
        try t.expectEqual(@as(u16, 1), tree.summary.conflicts);
        try t.expectEqualDeep(dot(1, 1, 0), (try tree.assignmentAt(&store, conflict.slot.?, 0)).dot);
        try t.expectEqualDeep(dot(2, 1, 0), (try tree.assignmentAt(&store, conflict.slot.?, 1)).dot);
        // An observed remove of A retains concurrent B, independently of order.
        try tree.applyOperation(&store, dot(3, 1, 0), .{ .field = "x", .observed = &dot(1, 1, 0).bytes(), .value = null });
        const visible = try tree.lookup(&store, &.{"x"});
        try t.expectEqual(.value, visible.status);
        const selected = try tree.assignmentAt(&store, visible.slot.?, 0);
        try t.expectEqualStrings("B", (try tree.valueChunk(&store, selected.dot, 0)).slice());
        try t.expectEqual(@as(u16, 0), tree.summary.conflicts);
        const parent = dot(4, 1, 0);
        try tree.applyOperation(&store, parent, .{ .field = "parent", .value = .{ .kind = .map } });
        try tree.applyOperation(&store, dot(4, 1, 1), .{ .object = parent, .field = "child", .value = .{ .kind = .null_value } });
        const snapshot = tree;
        try tree.applyOperation(&store, dot(4, 2, 0), .{ .field = "parent", .observed = &parent.bytes(), .value = .{ .kind = .map } });
        try t.expectEqual(.missing, (try tree.lookup(&store, &.{ "parent", "child" })).status);
        var retained = snapshot;
        try t.expectEqual(.null_value, (try retained.lookup(&store, &.{ "parent", "child" })).status);
        var refused = tree;
        refused.limits.conflicts = 0;
        try t.expectError(error.DocumentConflictCapacity, refused.applyOperation(&store, dot(5, 1, 0), .{ .field = "x", .value = .{ .kind = .boolean, .bytes = &.{1} } }));
        try t.expectEqual(.value, (try tree.lookup(&store, &.{"x"})).status);
    }
}
