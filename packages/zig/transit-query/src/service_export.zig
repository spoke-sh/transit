//! Public service envelopes reflected from their owning implementation.
const std = @import("std");
const q = @import("transit_query");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try q.protocol.Schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try q.protocol.Schema.field(&out, "$id", "urn:transit:table-service:v1");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "Response", "Limits" }) |name| {
        try out.objectField(name);
        try q.protocol.Schema.writeRecursiveAt(@field(q.TableService, name), &out, .{ .safe_integers = true, .text_max_length = q.catalog.TableBridge.max_input_bytes, .sequence_max_length = 65536, .output = comptime std.mem.eql(u8, name, "Response") }, "/$defs/" ++ name);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
