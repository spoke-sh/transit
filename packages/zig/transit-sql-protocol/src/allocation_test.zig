//! Backing-allocation gates with independent typed values and changing shapes.
const std = @import("std");
const api = @import("root.zig");
const r = api.results;
const memory = @import("transit_memory");
const t = std.testing;

test "warmed binary codec preserves every logical kind and state across changing batches" {
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var budget: memory.Budget = .{ .parent = probe.allocator(), .limit = 16 * 1024 * 1024 };
    var encoded = try memory.Workspace.init(budget.allocator(), 4 * 1024 * 1024);
    defer encoded.deinit();
    var decoded = try memory.Workspace.init(budget.allocator(), 4 * 1024 * 1024);
    defer decoded.deinit();
    var frame_storage = try memory.Workspace.init(budget.allocator(), 4 * 1024 * 1024);
    defer frame_storage.deinit();
    var builder = try r.BatchBuilder.init(budget.allocator(), 2 * 1024 * 1024);
    defer builder.deinit();
    var encoding = try encoded.acquire();
    defer encoding.release(false) catch unreachable;
    var decoding = try decoded.acquire();
    defer decoding.release(false) catch unreachable;
    const tags = comptime std.meta.tags(r.Types.Tag);
    var fields: [tags.len]r.Types.Field = undefined;
    var values: [tags.len]r.Types.Values.Value = undefined;
    const child: r.Types.Field = .{ .name = "text", .type = .utf8, .nullable = true, .optional = true };
    const nested = [_]r.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = "snow ☃" } } }};
    const entries = [_]r.Types.Values.Entry{.{ .key = .{ .bytes = "key" }, .value = nested[0] }};
    const vector_bytes: [2]u8 align(64) = .{ 0xfe, 0x7f };
    inline for (tags, 0..) |tag, i| {
        fields[i] = .{ .name = @tagName(tag), .nullable = true, .optional = true, .type = switch (tag) {
            .decimal => .{ .decimal = .{ .precision = 38, .scale = 2 } },
            .timestamp => .{ .timestamp = .utc },
            .structure => .{ .structure = &.{child} },
            .list => .{ .list = .{ .type = &.utf8 } },
            .array => .{ .array = .{ .length = 1, .element = .{ .type = &.utf8 } } },
            .map => .{ .map = .{ .key = &.utf8, .value = .{ .type = &.utf8 } } },
            .tagged_union => .{ .tagged_union = &.{.{ .name = "text", .type = .utf8 }} },
            .range => .{ .range = &.int64 },
            .multirange => .{ .multirange = &.int64 },
            .vector => .{ .vector = .{ .dimensions = 2, .element = .int8 } },
            else => @unionInit(r.Types.Type, @tagName(tag), {}),
        } };
        values[i] = switch (tag) {
            .int8, .int16, .int32, .int64 => .{ .atom = .{ .signed = -37 } },
            .int128 => .{ .atom = .{ .signed = std.math.minInt(i128) } },
            .uint8, .uint16, .uint32, .uint64 => .{ .atom = .{ .unsigned = 197 } },
            .uint128 => .{ .atom = .{ .unsigned = std.math.maxInt(u128) } },
            .float32, .float64 => .{ .atom = .{ .float = -0.25 } },
            .boolean => .{ .atom = .{ .boolean = true } },
            .utf8 => .{ .atom = .{ .bytes = "text ☃ 列" } },
            .binary => .{ .atom = .{ .bytes = "\x00\xff\x80" } },
            .decimal => .{ .atom = .{ .decimal = -123456789012345678901234567890 } },
            .date => .{ .atom = .{ .date = -1 } },
            .time => .{ .atom = .{ .time = 1 } },
            .timestamp => .{ .atom = .{ .timestamp = -1 } },
            .interval => .{ .atom = .{ .interval = .{ .months = -2, .days = 3, .nanos = 7 } } },
            .uuid => .{ .atom = .{ .uuid = @splat(0xab) } },
            .structure => .{ .structure = &nested },
            .list => .{ .list = &nested },
            .array => .{ .array = &nested },
            .map => .{ .map = &entries },
            .tagged_union => .{ .tagged_union = .{ .index = 0, .value = &nested[0] } },
            .json => .{ .json = "{\"ok\":[1,true,null]}" },
            .range => .{ .range = .{ .lower = .{ .value = .{ .signed = -37 }, .inclusive = true }, .upper = .{ .value = .{ .signed = 197 }, .inclusive = false } } },
            .multirange => .{ .multirange = &.{
                .{ .lower = .{ .value = .{ .signed = -37 }, .inclusive = true }, .upper = .{ .value = .{ .signed = 0 }, .inclusive = false } },
                .{ .lower = .{ .value = .{ .signed = 197 }, .inclusive = true } },
            } },
            .vector => .{ .vector = &vector_bytes },
        };
    }
    var alternatives: [tags.len][2]r.Types.Values.Alternative = undefined;
    var cells: [5][tags.len]r.Types.Values.Cell = undefined;
    for (values, 0..) |value, i| {
        alternatives[i] = .{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 2, .replica = 1, .value = .{ .value = value } } };
        cells[0][i] = .{ .value = value };
        cells[1][i] = .null;
        cells[2][i] = .missing;
        cells[3][i] = .{ .type_error = .unknown };
        cells[4][i] = .{ .conflict = &alternatives[i] };
    }
    var directory: [api.ResultFrame.max_columns][]const u8 = undefined;
    probe.begin(true);
    for (0..200) |iteration| {
        try builder.reset(api.max_rows, api.max_batch_bytes);
        try encoding.reset();
        try decoding.reset();
        const width = if (iteration % 2 == 0) fields.len else 1 + iteration % fields.len;
        const count = ([_]usize{ 0, 1, 31, 32 })[(iteration / 2) % 4];
        for (0..count) |row| try t.expect(try builder.append(fields[0..width], cells[(row + iteration) % 5][0..width]));
        var rows: [api.max_rows]r.Row = undefined;
        for (rows[0..count], 0..) |*row, index| row.* = builder.rows[index].?;
        const ea = try encoding.allocator();
        const da = try decoding.allocator();
        const pages = try api.ResultColumns.encode(ea, ea, fields[0..width], .fromRows(rows[0..count]));
        const bytes = try api.ResultFrame.encodeInto(frame_storage.buffer, .{
            .instance = @splat(1),
            .cursor = @splat(2),
            .ordinal = 1,
            .rows = @intCast(count),
            .schema = @splat(3),
            .observation = @splat(4),
            .description = null,
            .columns = pages,
            .completion = .{ .rows = count },
        });
        const frame = try api.ResultFrame.parseInto(da, &directory, bytes);
        const batch = try api.ResultColumns.decode(da, da, fields[0..width], frame.columns, frame.rows);
        try batch.validate(fields[0..width]);
        for (0..count) |row| for (0..width) |column| try t.expectEqualDeep(cells[(row + iteration) % 5][column], batch.cell(row, column));
        try t.expectEqual(count, frame.completion.?.rows);
    }
    try probe.verify();
    try t.expectEqual(14 * 1024 * 1024, probe.live_bytes);
    try t.expectEqual(probe.live_bytes, budget.used);
}
