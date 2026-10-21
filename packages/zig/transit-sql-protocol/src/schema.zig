const std = @import("std");
const api = @import("transit_sql_protocol");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var json: std.json.Stringify = .{ .writer = &output.interface, .options = .{ .whitespace = .indent_2 } };
    try json.beginObject();
    try json.objectField("version");
    try json.write(1);
    try json.objectField("definition");
    try json.write(api.native.current_definition);
    try json.objectField("routes");
    try json.write(.{ .method = "POST", .data = api.data_path, .control = api.control_path });
    try json.objectField("encoding");
    try json.write(api.encoding);
    try json.objectField("request");
    try api.fuze.LogicalSchema.write(api.Request, &json);
    try json.objectField("response");
    try api.fuze.LogicalSchema.write(api.Response, &json);
    try json.endObject();
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
