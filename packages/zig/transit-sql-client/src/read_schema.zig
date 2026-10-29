const std = @import("std");
const s = @import("transit_sql_client");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var json: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try json.beginObject();
    try json.objectField("$id");
    try json.write("urn:transit:sql-read:v1");
    try json.objectField("definition");
    try json.write(s.protocol.native.current_definition);
    try json.objectField("$defs");
    try json.beginObject();
    inline for (.{ "ReadRequest", "ReadResponse" }, .{ s.ReadWorkspace.Request, s.ReadWorkspace.Response }) |name, T| {
        try json.objectField(name);
        try s.results.protocol.Schema.writeRecursiveAt(T, &json, .{ .output = true, .safe_integers = true, .sequence_max_length = 256, .text_max_length = 262144 }, "/$defs/" ++ name);
    }
    try json.endObject();
    try json.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
