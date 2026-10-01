//! Test bridge: one neutral typed cell to one bounded Arrow batch.
const std = @import("std");
const f = @import("transit_fuze");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.InvalidInvocation;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(f.LogicalJson.max_input_bytes));
    defer init.gpa.free(bytes);
    var value = try f.LogicalJson.decode(init.gpa, bytes);
    defer value.deinit();
    const workspace = try init.gpa.alloc(u8, f.LogicalArrow.working_bytes);
    defer init.gpa.free(workspace);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    const encoded = try f.LogicalArrow.encode(.{ .structure = &.{value.field} }, &.{.{ .cells = &.{value.cell} }}, workspace, &output);
    try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
}
