const std = @import("std");
const c = @import("transit_catalog");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try c.protocol.Schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try c.protocol.Schema.field(&out, "$id", "urn:transit:direct-table:v1");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "Response" }) |name| {
        try out.objectField(name);
        try c.protocol.Schema.writeRecursiveAt(@field(c.DirectTableProtocol, name), &out, .{ .text_max_length = 256, .sequence_max_length = 128, .output = comptime std.mem.eql(u8, name, "Response") }, "/$defs/" ++ name);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
