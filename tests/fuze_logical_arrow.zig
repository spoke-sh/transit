//! Test bridge: one neutral typed cell to one bounded Arrow batch.
const std = @import("std");
const f = @import("transit_fuze");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 3 and std.mem.eql(u8, args[1], "--batch")) return batch(init, args[2]);
    if (args.len != 2) return error.InvalidInvocation;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(f.LogicalJson.max_input_bytes));
    defer init.gpa.free(bytes);
    var value = try f.LogicalJson.decode(init.gpa, bytes);
    defer value.deinit();
    const workspace = try init.gpa.alloc(u8, f.LogicalArrow.working_bytes);
    defer init.gpa.free(workspace);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    const encoded = try f.LogicalArrow.encode(.{ .structure = &.{value.field} }, &.{.{ .cells = &.{value.cell} }}, workspace, &output);
    var restored = try f.LogicalInspect.decode(init.gpa, .{ .structure = &.{value.field} }, encoded, 1, workspace);
    defer restored.deinit();
    const before = try f.LogicalJson.encode(init.gpa, value.cell, value.field);
    defer init.gpa.free(before);
    const after = try f.LogicalJson.encode(init.gpa, restored.rows[0].cells[0], restored.descriptor.type.structure[0]);
    defer init.gpa.free(after);
    if (!std.mem.eql(u8, before, after)) return error.LogicalArrowRoundTripMismatch;
    try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
}
fn batch(init: std.process.Init, path: []const u8) !void {
    const allocator = init.arena.allocator();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(f.LogicalJson.max_input_bytes));
    try f.Types.Json.preflight(bytes, .{ .bytes = f.LogicalJson.max_input_bytes, .depth = 96, .tokens = 65536 });
    const input = try std.json.parseFromSliceLeaky(struct { columns: []const f.Types.Field, rows: []const []const f.LogicalJson.Cell }, allocator, bytes, .{});
    const schema: f.Types.Type = .{ .structure = input.columns };
    try schema.validate(.{});
    if (input.columns.len > 128 or input.rows.len > f.LogicalArrow.max_rows) return error.InvalidShape;
    const rows = try allocator.alloc(f.LogicalArrow.Row, input.rows.len);
    for (input.rows, rows) |foreign, *row| {
        if (foreign.len != input.columns.len) return error.InvalidShape;
        const cells = try allocator.alloc(f.Types.Values.Cell, foreign.len);
        for (foreign, input.columns, cells) |value, field, *cell| cell.* = try f.LogicalJson.fromForeign(allocator, value, field);
        row.* = .{ .cells = cells };
    }
    const workspace = try allocator.alloc(u8, f.LogicalArrow.working_bytes);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    const encoded = try f.LogicalArrow.encode(schema, rows, workspace, &output);
    try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
}
