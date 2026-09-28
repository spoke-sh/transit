const std = @import("std");
const api = @import("transit_serving").Api;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedDescriptionFormat;
    const format = std.meta.stringToEnum(api.Format, args[1]) orelse return error.ExpectedDescriptionFormat;
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try api.write(format, &writer.interface);
    try writer.interface.flush();
}
