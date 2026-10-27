const std = @import("std");
const r = @import("root.zig");
const t = std.testing;

test "column views borrow Arrow buffers and preserve five states across slices" {
    const f = r.fuze;
    const field: r.Types.Field = .{ .name = "n", .type = .uint64, .nullable = true, .optional = true };
    const alternatives = [_]r.Types.Values.Alternative{
        .{ .counter = 1, .replica = 1, .value = .null },
        .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .unsigned = 17 } } } },
    };
    const cells = [_]r.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } },
        .missing,
        .null,
        .{ .type_error = .utf8 },
        .{ .conflict = &alternatives },
        .{ .value = .{ .atom = .{ .unsigned = 17 } } },
    };
    const definition: f.TableSchema.Column = .{ .id = 1, .name = "n", .type = .uint64, .nullable = true };
    var page: [1024]u8 align(64) = undefined;
    const encoded = try f.PhysicalCodecs.encodeColumnPage(t.allocator, definition, &cells, &page);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const plain = try f.PhysicalCodecs.borrowPlainColumn(t.allocator, arena.allocator(), definition, encoded);
    const columns = [_]r.Batch.Column{.{ .plain = plain }};
    const batch = r.Batch.fromColumns(&columns, cells.len);
    try batch.validate(&.{field});
    var scratch: [1]r.Types.Values.Cell = undefined;
    for (cells, 0..) |expected, index| {
        try t.expectEqualDeep(expected, batch.cell(index, 0));
        try t.expectEqualDeep(expected, (try batch.rowInto(index, &scratch))[0]);
    }
    const suffix = try batch.slice(1, 5);
    const column = try suffix.columnAt(0);
    var buffers: [3]f.arrow.SharedBuffer = undefined;
    const arrow = try column.arrowValues(&buffers);
    const integers: f.arrow.PrimitiveArray(u64) = .{ .data = &arrow };
    try t.expectEqual(17, try integers.value(4));
    try t.expectEqual(1, arrow.offset);
    try t.expectEqual(5, arrow.length);
    try t.expectEqual(plain.buffers.values.ptr, arrow.buffers[1].data.ptr);
    // No detached row matrix or value allocation: all payloads still point into
    // the original admitted page. Non-value states are distinct outside Arrow's
    // nullable value child, which represents each of these lanes as null.
    for (0..4) |i| try t.expect(integers.isNull(i));
    try t.expectEqual(.missing, column.cell(0));
    try t.expectEqual(.type_error, std.meta.activeTag(column.cell(2)));
    try t.expectEqualDeep(&alternatives, column.cell(3).conflict);
    try t.expectError(error.InvalidResultChunk, batch.slice(5, 2));
}

test "column views reuse Fuze vectors without row materialization" {
    const words = [_]u64{ 0, 17, std.math.maxInt(u64) };
    const states = [_]r.Types.State{ .value, .value, .value };
    const details: [3]r.fuze.Batch.Detail = @splat(.none);
    const columns = [_]r.Batch.Column{.{ .vector = .{ .flat = .{ .type = .uint64, .data = .{ .words = &words }, .states = &states, .details = &details } } }};
    const batch = r.Batch.fromColumns(&columns, 3);
    try batch.validate(&.{.{ .name = "n", .type = .uint64 }});
    const slice = try batch.slice(1, 2);
    const view = try slice.columnAt(0);
    try t.expectEqual(17, view.cell(0).value.atom.unsigned);
    try t.expectEqual(std.math.maxInt(u64), view.cell(1).value.atom.unsigned);
    try t.expectEqual(&words, slice.layout.columns.values[0].vector.flat.data.words.ptr);
    try t.expectError(error.InvalidResultColumn, batch.validate(&.{.{ .name = "n", .type = .int64 }}));
    var broken = columns;
    broken[0].vector.flat.data = .states_only;
    try t.expectError(error.InvalidResultColumn, r.Batch.fromColumns(&broken, 3).validate(&.{.{ .name = "n", .type = .uint64 }}));
}
