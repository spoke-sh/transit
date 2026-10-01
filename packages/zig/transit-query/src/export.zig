//! Browser host declarations reflect the query owner, independently of Board.
const std = @import("std");
const q = @import("transit_query");
pub fn main(init: std.process.Init) !void {
    var bytes: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &bytes);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try q.protocol.Schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try q.protocol.Schema.field(&out, "$id", "urn:transit:query-workspace:v1");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "Response", "Draft" }) |name| {
        try out.objectField(name);
        try q.protocol.Schema.write(@field(q.Workspace, name), &out, if (comptime std.mem.eql(u8, name, "Request")) q.Workspace.request_schema_options else q.Workspace.schema_options);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
