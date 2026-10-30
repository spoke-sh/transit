const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const s = @import("root.zig");
const support = @import("log_test_support.zig");

test "log view preserves sparse original identities with bounded allocation-free buffers" {
    var declaration = try s.LogDeclaration.prepare(t.allocator, support.definition(.stream));
    defer declaration.deinit();
    const schema = declaration.definition.schema;
    const operation: p.DataLifecycle.Operation = .{ .scope = declaration.definition.object.scope, .principal = 2, .operation = 99 };
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .bytes = "a" } } }, .{ .value = .{ .atom = .{ .bytes = "payload" } } } };
    const rows: [7]s.LogBatch.Row = @splat(.{ .cells = &cells });
    var original: [8192]u8 = undefined;
    const bytes = try s.LogBatch.encode(schema, operation, .stream, &rows, &original);
    var output: [8192]u8 = undefined;
    var encoder = try s.LogView.Encoder.init(schema, 7, 3, &output);
    var input = try s.LogBatch.Iterator.init(bytes, schema, .stream, 7);
    while (try input.next()) |row| if (row.ordinal % 3 == 0) try encoder.append(row);
    const view = try encoder.finish();
    var iterator = try s.LogView.Iterator.init(view, schema, 7);
    var memory: [8192]u8 = undefined;
    var scratch = std.heap.FixedBufferAllocator.init(&memory);
    for ([_]u32{ 0, 3, 6 }) |ordinal| {
        const row = (try iterator.next()).?;
        try t.expectEqual(ordinal, row.ordinal);
        scratch.reset();
        const decoded = try row.decode(scratch.allocator(), schema, operation);
        try t.expectEqualStrings("payload", decoded.cells[1].value.atom.bytes);
    }
    try t.expectEqual(@as(?s.LogBatch.EncodedRow, null), try iterator.next());
    try t.expectError(error.InvalidLogSegment, s.LogView.Iterator.init(bytes, schema, 7));
    try t.expectError(error.InvalidLogBatch, s.LogBatch.Iterator.init(view, schema, .stream, 7));
    output[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, s.LogView.Iterator.init(view, schema, 7));
    output[8] ^= 1;
    iterator = try s.LogView.Iterator.init(view[0 .. view.len - 1], schema, 7);
    _ = try iterator.next();
    _ = try iterator.next();
    try t.expectError(error.InvalidLogSegment, iterator.next());
    iterator = try s.LogView.Iterator.init(view, schema, 7);
    _ = try iterator.next();
    std.mem.writeInt(u32, output[iterator.at..][0..4], 0, .big);
    try t.expectError(error.InvalidLogSegment, iterator.next());
    encoder = try s.LogView.Encoder.init(schema, 7, 0, &output);
    iterator = try s.LogView.Iterator.init(try encoder.finish(), schema, 7);
    try t.expectEqual(@as(?s.LogBatch.EncodedRow, null), try iterator.next());
    output[s.LogView.header_bytes] = 0;
    try t.expectError(error.InvalidLogSegment, s.LogView.Iterator.init(output[0 .. s.LogView.header_bytes + 1], schema, 7));
}
