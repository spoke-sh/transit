//! Independent Arrow consumers read these actual Fuze-produced IPC fixtures.
const std = @import("std");
const fuze = @import("transit_fuze");
const a = fuze.arrow;
pub const std_options: std.Options = .{ .log_level = .info };

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.Usage;
    const empty = std.mem.eql(u8, args[1], "empty");
    const types = [_]a.DataType{ .{ .int64 = {} }, .{ .string = {} } };
    const fields = [_]a.Field{
        .{ .name = "id", .data_type = &types[0], .nullable = false },
        .{ .name = "label", .data_type = &types[1], .nullable = true },
    };
    var ids = try a.Int64Builder.init(allocator, 3);
    defer ids.deinit();
    var labels = try a.StringBuilder.init(allocator, 3, 32);
    defer labels.deinit();
    if (!empty) {
        try ids.append(1);
        try ids.append(9007199254740993);
        try ids.append(std.math.maxInt(i64));
        try labels.append("ready");
        try labels.appendNull();
        try labels.append("東京");
    }
    var id_column = try ids.finish();
    defer id_column.release();
    var label_column = try labels.finish();
    defer label_column.release();
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{ id_column, label_column });
    defer batch.deinit();
    var buffer: [4096]u8 = undefined;
    const encoded = try fuze.encode(allocator, batch, &buffer);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[2], .data = encoded });
}
