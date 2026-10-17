//! Build-time registry export; this is not a Transit CLI command.
const std = @import("std");
const q = @import("transit_query");
const settings = @import("server/SettingsSchema.zig").registry;
pub fn main(init: std.process.Init) !void {
    var bytes: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &bytes);
    try std.json.Stringify.value(.{ .definition = q.protocol.Growth.current_definition, .settings = settings.descriptors, .schema = try settings.schema(init.arena.allocator()) }, .{ .whitespace = .indent_2 }, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
