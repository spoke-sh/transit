const std = @import("std");
const e = std.testing;
const f = @import("root.zig");
const t = f.Types;
fn converted(allocator: std.mem.Allocator, input: t.Query.Cell) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const cell = try t.Values.fromQuery(arena.allocator(), .utf8, input);
    try cell.validate(.{ .name = "x", .type = .utf8, .nullable = true, .optional = true }, .{});
    try e.expectEqual(input.conflict.len, cell.conflict.len);
    try e.expectEqual(.unknown, cell.conflict[0].value.type_error);
    try e.expectEqual(.text, cell.conflict[1].value.type_error);
    try e.expectEqual(.character, cell.conflict[2].value.type_error);
    try e.expectEqualStrings("東京", cell.conflict[3].value.value.atom.bytes);
}
test "scalar adapters preserve source kinds conflicts and independent owned bytes" {
    inline for (std.enums.values(t.Query.Kind)) |kind| {
        var arena: std.heap.ArenaAllocator = .init(e.allocator);
        defer arena.deinit();
        const cell = try t.Values.fromQuery(arena.allocator(), .int64, .{ .type_error = kind });
        try e.expectEqualStrings(@tagName(kind), @tagName(cell.type_error));
    }
    var text = "東京".*;
    const input: t.Query.Cell = .{ .conflict = &.{
        .{ .counter = 1, .replica = std.math.maxInt(u64), .value = .{ .type_error = .unknown } },
        .{ .counter = 2, .replica = 1, .value = .{ .type_error = .text } },
        .{ .counter = 3, .replica = 1, .value = .{ .type_error = .character } },
        .{ .counter = std.math.maxInt(u64), .replica = 1, .value = .{ .value = .{ .utf8 = &text } } },
    } };
    try e.checkAllAllocationFailures(e.allocator, converted, .{input});
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const cell = try t.Values.fromQuery(arena.allocator(), .utf8, input);
    @memset(&text, 0);
    try e.expectEqualStrings("東京", cell.conflict[3].value.value.atom.bytes);
    try e.expectEqual(std.math.maxInt(u64), cell.conflict[3].counter);
    try e.expectError(error.TypeMismatch, t.Values.fromQuery(arena.allocator(), .boolean, .{ .value = .{ .int64 = 1 } }));
    try e.expectError(error.InvalidConflict, t.Values.fromQuery(arena.allocator(), .utf8, .{ .conflict = input.conflict[0..1] }));
}
test "source-only kinds roundtrip logical binary JSON and Arrow without becoming types" {
    const field: t.Field = .{ .name = "x", .type = .int64, .nullable = true, .optional = true };
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    inline for (.{ t.Kind.unknown, t.Kind.null_value, t.Kind.text, t.Kind.character }) |kind| {
        const cell: t.Values.Cell = .{ .type_error = kind };
        var binary: [1024]u8 = undefined;
        const bytes = try t.Codec.encode(cell, field, &binary);
        try e.expectEqualSlices(u8, &.{ 2, @backingInt(kind) }, bytes[bytes.len - 2 ..]);
        var decoded = try t.Codec.decode(e.allocator, bytes);
        defer decoded.deinit();
        try e.expectEqualDeep(cell, decoded.cell);
        const json = try f.LogicalJson.encode(e.allocator, cell, field);
        defer e.allocator.free(json);
        var restored = try f.LogicalJson.decode(e.allocator, json);
        defer restored.deinit();
        try e.expectEqualDeep(cell, restored.cell);
        var arrow: [f.LogicalArrow.segment_bytes]u8 = undefined;
        const schema: t.Type = .{ .structure = &.{field} };
        const ipc = try f.LogicalArrow.encode(schema, &.{.{ .cells = &.{cell} }}, workspace, &arrow);
        var batch = try f.LogicalInspect.decode(e.allocator, schema, ipc, 1, workspace);
        defer batch.deinit();
        try e.expectEqualDeep(cell, batch.rows[0].cells[0]);
        const invalid = "{\"definition\":\"" ++ t.definition ++ "\",\"type\":{\"" ++ @tagName(kind) ++ "\":{}}}";
        if (f.LogicalJson.decodeType(e.allocator, invalid)) |owner| {
            var unexpected = owner;
            unexpected.deinit();
            return error.SourceKindBecameDescriptor;
        } else |_| {}
    }
}
