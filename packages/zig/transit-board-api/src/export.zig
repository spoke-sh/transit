//! OpenAPI generated from the actual Board response types and Transit definitions.
const std = @import("std");
const api = @import("transit_board_api");
const s = api.protocol.Schema;
const field = s.field;
fn response(out: *std.json.Stringify, status: []const u8, name: []const u8) !void {
    try out.objectField(status);
    try out.beginObject();
    try field(out, "description", name);
    try out.objectField("content");
    try out.beginObject();
    try out.objectField("application/json");
    try out.beginObject();
    try out.objectField("schema");
    var buf: [128]u8 = undefined;
    try out.write(.{ .@"$ref" = try std.fmt.bufPrint(&buf, "#/components/schemas/{s}", .{name}) });
    try out.endObject();
    try out.endObject();
    try out.endObject();
}
fn route(out: *std.json.Stringify, path: []const u8, method: []const u8, name: []const u8, pid: bool, paged: bool) !void {
    try out.objectField(path);
    try out.beginObject();
    try out.objectField(method);
    try out.beginObject();
    try field(out, "summary", name);
    try out.objectField("parameters");
    try out.beginArray();
    if (pid) try out.write(.{ .name = "pid", .in = "path", .required = true, .schema = .{ .type = "integer", .minimum = 1, .maximum = api.protocol.max_counter } });
    if (paged) for ([_][]const u8{ "after", "position", "policy_revision", "retained_from" }) |param| try out.write(.{ .name = param, .in = "query", .required = false, .schema = .{ .type = "integer", .minimum = 0, .maximum = api.protocol.max_counter }, .description = "Continuation: supply all cut fields together; restart explicitly after 409" });
    try out.endArray();
    try out.objectField("responses");
    try out.beginObject();
    try response(out, "200", name);
    for ([_][]const u8{ "400", "403", "404", "409", "429", "503" }) |status| try response(out, status, "Error");
    try out.endObject();
    try out.endObject();
    try out.endObject();
}
pub fn main(init: std.process.Init) !void {
    var buf: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buf);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try field(&out, "openapi", "3.1.1");
    try field(&out, "info", .{ .title = "Transit Board inspection API", .version = "1.0.0", .description = "Private deployment: no Board keys or sessions. Every reachable viewer shares one read-only Transit principal; current permission is checked on every data read. No execution controls." });
    try field(&out, "jsonSchemaDialect", "https://json-schema.org/draft/2020-12/schema");
    try field(&out, "security", [0][]const u8{});
    try out.objectField("paths");
    try out.beginObject();
    try route(&out, "/api/v1/capabilities", "get", "Capabilities", false, false);
    try route(&out, "/api/v1/processes", "get", "Response", false, true);
    try route(&out, "/api/v1/processes/{pid}", "get", "Response", true, true);
    for ([_][]const u8{ "mailbox", "outbox", "effects", "payloads", "history", "journey" }) |resource| {
        var path: [128]u8 = undefined;
        try route(&out, try std.fmt.bufPrint(&path, "/api/v1/processes/{{pid}}/{s}", .{resource}), "get", "Response", true, true);
    }
    try out.endObject();
    try out.objectField("components");
    try out.beginObject();
    try out.objectField("schemas");
    try out.beginObject();
    inline for (.{ "Response", "Capabilities", "Error" }, .{ api.Response, api.Capabilities, api.Error }) |name, T| {
        try out.objectField(name);
        try s.write(T, &out, .{ .output = true, .safe_integers = true });
    }
    try out.endObject();
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
