//! Independent clients consume bytes produced by the real metadata builder.
const std = @import("std");
const flight = @import("transit_flight");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.ExpectedCommandInputOutput;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], init.gpa, .limited(1024));
    defer init.gpa.free(input);
    const workspace = try init.gpa.alloc(u8, flight.Metadata.working_bytes);
    defer init.gpa.free(workspace);
    var output: [16384]u8 = undefined;
    const type_url = try std.fmt.allocPrint(init.gpa, "{s}{s}", .{ flight.command_prefix, args[1] });
    defer init.gpa.free(type_url);
    const bytes = try flight.Metadata.encode(.{ .type_url = type_url, .value = input }, "counter", .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 }, &output, workspace);
    _ = try flight.Ipc.parts(bytes, workspace);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = bytes });
}
