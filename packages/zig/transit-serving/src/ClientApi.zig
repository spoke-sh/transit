//! Optional private host adapter. These schemas are distinct from the signed
//! M20 API: deployment admission selects one configured caller, never a user ID.
const std = @import("std");
const root = @import("root.zig");
pub fn write(writer: *std.Io.Writer) !void {
    var out: std.json.Stringify = .{ .writer = writer, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try out.objectField("HostRequest");
    try root.protocol.Schema.write(root.ReactiveClient.Request, &out, .{ .safe_integers = true, .sequence_max_length = 8 });
    try out.objectField("HostResponse");
    try root.protocol.Schema.write(root.ReactiveClient.Response, &out, .{ .safe_integers = true, .sequence_max_length = 8 });
    try out.endObject();
    try writer.writeByte('\n');
}
