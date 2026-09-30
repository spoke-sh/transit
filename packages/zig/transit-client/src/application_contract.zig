const std = @import("std");
const client = @import("transit_client");
pub fn main(init: std.process.Init) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--fixture")) {
        const key = try client.protocol.Ed25519.KeyPair.generateDeterministic(@splat(7));
        const request: client.Application.Request = .{ .installation = @splat(1), .realm = 42, .principal = 9, .operation = "status-1", .command = .{ .status = .{ .application = "items" } } };
        const inspection: client.Application.Declaration = .{ .version = 1, .application = "items", .roles = &.{.{ .name = "data", .contract = "items-v1", .artifact = .{ .path = "/worker", .sha256 = @splat(1) }, .accesses = &.{} }}, .resources = &.{.{ .name = "data", .writer = "data" }}, .callers = &.{}, .inspection = &.{.{ .resource = "data", .permissions = 3 }} };
        try client.protocol.Json.write(.{ .inspection = inspection, .inspection_digest = try client.Application.digest(init.arena.allocator(), inspection), .signed = try client.Application.sign(init.arena.allocator(), request, key), .digest = try client.Application.digest(init.arena.allocator(), request) }, &out);
        try writer.interface.writeByte('\n');
        return writer.interface.flush();
    }
    if (args.len != 1) return error.InvalidInvocation;
    const schema = client.protocol.Schema;
    try out.beginObject();
    try schema.field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try schema.field(&out, "$id", "urn:transit:application-installation:v1");
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Declaration", "Request", "Signed", "Bootstrap", "Management", "Connection", "Status" }) |name| {
        try out.objectField(name);
        try schema.write(@field(client.Application, name), &out, .{ .safe_integers = true, .sequence_max_length = 16, .text_max_length = 8192 });
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
