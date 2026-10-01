const std = @import("std");
const f = @import("transit_fuze");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var json: std.json.Stringify = .{ .writer = &output.interface, .options = .{ .whitespace = .indent_2 } };
    try json.beginObject();
    try json.objectField("type");
    try f.LogicalSchema.write(f.LogicalJson.TypeEnvelope, &json);
    try json.objectField("value");
    try f.LogicalSchema.write(f.LogicalJson.Envelope, &json);
    try json.endObject();
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
