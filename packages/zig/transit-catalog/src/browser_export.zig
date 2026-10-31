const std = @import("std");
const c = @import("transit_catalog");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try c.protocol.Schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try c.protocol.Schema.field(&out, "$id", "urn:transit:browser:v1");
    try c.protocol.Schema.field(&out, "x-transit-definition", c.BrowserDeclarations.definition);
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "Response" }) |name| {
        try out.objectField("Admin" ++ name);
        try c.protocol.Schema.writeRecursiveAt(@field(c.BrowserAdministration, name), &out, .{ .text_max_length = 65536, .sequence_max_length = 128, .output = comptime std.mem.eql(u8, name, "Response") }, "/$defs/Admin" ++ name);
    }
    inline for (.{ "ProviderDiscovery", "Session", "LoggedOut", "Failure", "Snapshot" }) |name| {
        try out.objectField(name);
        try c.protocol.Schema.writeRecursiveAt(@field(c.BrowserContract, name), &out, .{ .text_max_length = 4 * 1024 * 1024, .sequence_max_length = 128, .output = true }, "/$defs/" ++ name);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
