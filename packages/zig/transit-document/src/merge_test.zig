const std = @import("std");
const t = std.testing;
const lib = @import("root.zig");
const m = lib.Model;
const Index = @import("index_fixture.zig");
const Document = lib.Document(Index);
const Store = Index.Store;

fn name(bytes: []const u8) !m.Name {
    return m.Name.init(bytes);
}
fn dot(counter: u64, replica: u64) m.Dot {
    return .{ .counter = counter, .replica = replica };
}
fn change(replica: u64, previous: u64, first: u64, operations: []const m.Operation) m.Change {
    var out: m.Change = .{ .document = 17, .epoch = 1, .replica = replica, .previous = previous, .first = first, .len = @intCast(operations.len) };
    @memcpy(out.operations[0..operations.len], operations);
    return out;
}
fn accept(doc: *Document, store: *Store, c: m.Change) !void {
    const candidate = try doc.apply(store, c);
    try t.expect(!candidate.duplicate);
    doc.* = candidate.state;
}
fn field(doc: Document, store: *Store, path: []const u8) !Document.Register {
    return doc.field(store, .root, try name(path));
}
fn text(doc: Document, store: *Store, object: m.Dot, buffer: []u8) ![]const u8 {
    var cursor: Document.SequenceCursor = .{};
    var used: usize = 0;
    for (0..10000) |_| switch (try doc.sequenceStep(store, object, &cursor)) {
        .end => return buffer[0..used],
        .more => {},
        .item => |item| {
            try t.expectEqual(@as(u8, 1), item.values.len);
            const cp = item.values.assignments[0].value.character;
            used += try std.unicode.utf8Encode(@intCast(cp), buffer[used..]);
        },
    };
    return error.TraversalDidNotComplete;
}

test "simulation: Document accepted-set convergence through staging loss and reordered dependencies" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    for (0..12) |round| {
        var store: Store = .{};
        defer store.deinit();
        var doc: Document = .{ .document = 17 };
        var order = [_]u64{ 1, 2, 3, 4 };
        random.random().shuffle(u64, &order);
        var observed: [4]m.Dot = undefined;
        for (&observed, 0..) |*item, i| item.* = dot(1, i + 1);
        const resolution = change(5, 0, 2, &.{.{ .assign = .{ .field = try name("x"), .observed = try m.Observed.init(&observed), .value = .{ .unsigned = round } } }});
        try t.expectError(error.DocumentDependencyMissing, doc.apply(&store, resolution));
        for (order) |replica| {
            const edit = change(replica, 0, 1, &.{.{ .assign = .{ .field = try name("x"), .value = .{ .unsigned = replica } } }});
            const snapshot = doc;
            const fault = random.random().uintLessThan(usize, 3);
            store.fail_after = store.records.items.len + fault;
            try t.expectError(error.StorageUnavailable, doc.apply(&store, edit));
            try t.expectEqualDeep(snapshot, doc);
            store.fail_after = null;
            try accept(&doc, &store, edit);
            const duplicate = try doc.apply(&store, edit);
            try t.expect(duplicate.duplicate);
            try t.expectEqual(doc.revision, duplicate.accepted_revision);
            if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"document\",\"round\":{d},\"replica\":{d},\"fault_after\":{d},\"revision\":{d}}}\n", .{ round, replica, fault, doc.revision });
        }
        const snapshot = doc;
        const conflicts = try field(doc, &store, "x");
        try t.expectEqual(@as(u8, 4), conflicts.len);
        // This expected set is independent of application/iteration order.
        for (conflicts.assignments[0..conflicts.len], 1..) |assignment, replica| {
            try t.expectEqual(dot(1, replica), assignment.id);
            try t.expectEqual(replica, assignment.value.unsigned);
        }
        try accept(&doc, &store, resolution);
        try t.expectEqual(round, (try field(doc, &store, "x")).assignments[0].value.unsigned);
        try t.expectEqual(.conflict, (try field(snapshot, &store, "x")).status());
        store.denied = true;
        try t.expectError(error.AccessDenied, field(snapshot, &store, "x"));
    }
}

test "map conflicts, explicit resolution, null, missing, type errors and duplicate identity" {
    var store: Store = .{};
    defer store.deinit();
    var doc: Document = .{ .document = 17 };
    const a = change(1, 0, 1, &.{.{ .assign = .{ .field = try name("x"), .value = .{ .signed = std.math.minInt(i64) } } }});
    const b = change(2, 0, 1, &.{.{ .assign = .{ .field = try name("x"), .value = .null_value } }});
    try accept(&doc, &store, a);
    const old = doc;
    try accept(&doc, &store, b);
    try t.expectEqual(.conflict, (try field(doc, &store, "x")).status());
    try t.expectEqual(.scalar, (try field(old, &store, "x")).status());
    const resolution = change(3, 0, 2, &.{.{ .assign = .{ .field = try name("x"), .observed = (try field(doc, &store, "x")).observed(), .value = .null_value } }});
    try accept(&doc, &store, resolution);
    try t.expectEqual(.null_value, (try field(doc, &store, "x")).status());
    try t.expectEqual(.missing, (try field(doc, &store, "y")).status());
    const path = [_]m.Name{ try name("x"), try name("z") };
    try t.expectError(error.DocumentTypeError, doc.path(&store, &path));
    const record_count = store.records.items.len;
    const duplicate = try doc.apply(&store, a);
    try t.expect(duplicate.duplicate);
    try t.expectEqual(@as(u64, 1), duplicate.accepted_revision);
    try t.expectEqual(record_count, store.records.items.len);
    var conflict = a;
    conflict.operations[0].assign.value = .{ .signed = 99 };
    try t.expectError(error.DocumentIdentityConflict, doc.apply(&store, conflict));
    const missing = change(1, 9, 10, &.{.{ .assign = .{ .field = try name("x"), .value = .null_value } }});
    try t.expectError(error.DocumentDependencyMissing, doc.apply(&store, missing));
    const wrong = change(4, 0, 3, &.{.{ .remove = .{ .field = try name("y"), .observed = try m.Observed.init(&.{dot(2, 3)}) } }});
    try t.expectError(error.DocumentWrongDependency, doc.apply(&store, wrong));
    var stale = resolution;
    stale.epoch = 2;
    try t.expectError(error.DocumentResyncRequired, doc.apply(&store, stale));
}

test "nested delete edit races and text convergence across all concurrent permutations" {
    const boot = change(1, 0, 1, &.{
        .{ .assign = .{ .field = try name("nested"), .value = .map } },
        .{ .assign = .{ .object = dot(1, 1), .field = try name("x"), .value = .{ .signed = 1 } } },
        .{ .assign = .{ .field = try name("body"), .value = .text } },
        .{ .insert = .{ .object = dot(3, 1), .value = .{ .character = 'a' } } },
    });
    const concurrent = [_]m.Change{
        change(2, 0, 5, &.{ .{ .remove = .{ .field = try name("nested"), .observed = try m.Observed.init(&.{dot(1, 1)}) } }, .{ .delete_element = .{ .object = dot(3, 1), .element = dot(4, 1) } } }),
        change(3, 0, 5, &.{ .{ .assign = .{ .object = dot(1, 1), .field = try name("x"), .observed = try m.Observed.init(&.{dot(2, 1)}), .value = .{ .signed = 2 } } }, .{ .insert = .{ .object = dot(3, 1), .after = dot(4, 1), .value = .{ .character = 0x1f642 } } } }),
        change(4, 0, 5, &.{.{ .insert = .{ .object = dot(3, 1), .after = dot(4, 1), .value = .{ .character = 'b' } } }}),
        change(5, 0, 5, &.{.{ .assign = .{ .field = try name("title"), .value = .{ .string = try m.Bytes.init("e\xcc\x81") } } }}),
    };
    var schedules: usize = 0;
    for (0..4) |a| for (0..4) |b| for (0..4) |c| for (0..4) |d| {
        if (a == b or a == c or a == d or b == c or b == d or c == d) continue;
        var store: Store = .{};
        defer store.deinit();
        var doc: Document = .{ .document = 17 };
        try accept(&doc, &store, boot);
        const original = doc;
        for ([_]usize{ a, b, c, d }) |i| {
            try accept(&doc, &store, concurrent[i]);
            try t.expect((try doc.apply(&store, concurrent[i])).duplicate);
        }
        try t.expectEqual(.missing, (try field(doc, &store, "nested")).status());
        try t.expectEqual(.object, (try field(original, &store, "nested")).status());
        var bytes: [64]u8 = undefined;
        // Independent expected RGA order: higher Lamport dot comes first;
        // deleting anchor 'a' keeps both descendants and no parent resurrection.
        try t.expectEqualStrings("🙂b", try text(doc, &store, dot(3, 1), &bytes));
        try t.expectEqualStrings("a", try text(original, &store, dot(3, 1), &bytes));
        try t.expectEqualStrings("e\xcc\x81", (try field(doc, &store, "title")).assignments[0].value.string.slice());
        schedules += 1;
    };
    try t.expectEqual(@as(usize, 24), schedules);
}

test "list element updates conflict and deletion wins without hiding later insertion" {
    var store: Store = .{};
    defer store.deinit();
    var doc: Document = .{ .document = 17 };
    const boot = change(1, 0, 1, &.{ .{ .assign = .{ .field = try name("items"), .value = .list } }, .{ .insert = .{ .object = dot(1, 1), .value = .{ .unsigned = std.math.maxInt(u64) } } } });
    try accept(&doc, &store, boot);
    const old = doc;
    try accept(&doc, &store, change(2, 0, 3, &.{.{ .set_element = .{ .object = dot(1, 1), .element = dot(2, 1), .observed = try m.Observed.init(&.{dot(2, 1)}), .value = .null_value } }}));
    try accept(&doc, &store, change(3, 0, 3, &.{.{ .set_element = .{ .object = dot(1, 1), .element = dot(2, 1), .observed = try m.Observed.init(&.{dot(2, 1)}), .value = .map } }}));
    var cursor: Document.SequenceCursor = .{};
    try t.expectEqual(.conflict, (try doc.sequenceStep(&store, dot(1, 1), &cursor)).item.values.status());
    try accept(&doc, &store, change(4, 0, 3, &.{ .{ .delete_element = .{ .object = dot(1, 1), .element = dot(2, 1) } }, .{ .insert = .{ .object = dot(1, 1), .after = dot(2, 1), .value = .{ .binary = try m.Bytes.init(&.{ 0, 255 }) } } } }));
    cursor = .{};
    try t.expectEqual(.more, try doc.sequenceStep(&store, dot(1, 1), &cursor));
    const result = (try doc.sequenceStep(&store, dot(1, 1), &cursor)).item;
    try t.expectEqualSlices(u8, &.{ 0, 255 }, result.values.assignments[0].value.binary.slice());
    cursor = .{};
    try t.expectEqual(std.math.maxInt(u64), (try old.sequenceStep(&store, dot(1, 1), &cursor)).item.values.assignments[0].value.unsigned);
}

test "rejected changes and storage failure leave old snapshots intact; capacity is not expiry" {
    var store: Store = .{};
    defer store.deinit();
    var doc: Document = .{ .document = 17 };
    for (1..9) |replica| try accept(&doc, &store, change(replica, 0, 1, &.{.{ .assign = .{ .field = try name("x"), .value = .null_value } }}));
    const accepted = doc;
    try t.expectError(error.DocumentConflictCapacity, doc.apply(&store, change(9, 0, 1, &.{.{ .assign = .{ .field = try name("x"), .value = .null_value } }})));
    const partial = change(9, 0, 1, &.{ .{ .assign = .{ .field = try name("y"), .value = .map } }, .{ .insert = .{ .object = dot(1, 9), .value = .null_value } } });
    try t.expectError(error.DocumentTypeError, doc.apply(&store, partial));
    try t.expectEqual(.missing, (try field(doc, &store, "y")).status());
    const next = change(9, 0, 2, &.{.{ .assign = .{ .field = try name("z"), .value = .null_value } }});
    store.fail_after = store.records.items.len + 1;
    try t.expectError(error.StorageUnavailable, doc.apply(&store, next));
    try t.expectEqualDeep(accepted, doc);
    store.fail_after = null;
    try accept(&doc, &store, next);
    store.denied = true;
    try t.expectError(error.AccessDenied, field(doc, &store, "x"));
    try t.expectError(error.AccessDenied, doc.apply(&store, next));
}

test "text grows beyond one change and paged traversal advances through long deleted runs" {
    var store: Store = .{};
    defer store.deinit();
    var doc: Document = .{ .document = 17 };
    try accept(&doc, &store, change(1, 0, 1, &.{.{ .assign = .{ .field = try name("text"), .value = .text } }}));
    var previous: u64 = 1;
    var anchor: m.Dot = .root;
    for (0..80) |_| {
        var edits: [8]m.Operation = undefined;
        for (&edits, 0..) |*edit, i| {
            edit.* = .{ .insert = .{ .object = dot(1, 1), .after = anchor, .value = .{ .character = 'x' } } };
            anchor = dot(previous + 1 + i, 1);
        }
        try accept(&doc, &store, change(1, previous, previous + 1, &edits));
        previous += 8;
    }
    try t.expect(doc.index.root.?.entries > 2048);
    var cursor: Document.SequenceCursor = .{};
    var count: usize = 0;
    var transitions: usize = 0;
    while (true) {
        transitions += 1;
        switch (try doc.sequenceStep(&store, dot(1, 1), &cursor)) {
            .end => break,
            .more => {},
            .item => count += 1,
        }
    }
    try t.expectEqual(@as(usize, 640), count);
    try t.expect(transitions > count); // Backtracking has explicit bounded continuations.
    const deletion = change(2, 0, 642, &.{.{ .delete_element = .{ .object = dot(1, 1), .element = dot(2, 1) } }});
    try accept(&doc, &store, deletion);
    cursor = .{};
    try t.expectEqual(.more, try doc.sequenceStep(&store, dot(1, 1), &cursor));
    try t.expectEqual(dot(3, 1), (try doc.sequenceStep(&store, dot(1, 1), &cursor)).item.id);
}
