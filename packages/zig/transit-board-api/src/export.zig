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
    if (pid) try out.write(.{ .name = if (std.mem.indexOf(u8, path, "{resource}") != null) "resource" else "pid", .in = "path", .required = true, .schema = .{ .type = "integer", .minimum = 1, .maximum = api.protocol.max_counter } });
    if (std.mem.indexOf(u8, path, "{exchange}") != null) try out.write(.{ .name = "exchange", .in = "path", .required = true, .schema = .{ .type = "string", .pattern = "^[1-9][0-9]{0,19}$" }, .description = "Canonical nonzero uint64 decimal identity, at most 18446744073709551615." });
    if (std.mem.indexOf(u8, path, "{document}") != null) {
        try out.write(.{ .name = "document", .in = "path", .required = true, .schema = .{ .type = "string", .pattern = "^[1-9][0-9]{0,19}$" }, .description = "Canonical nonzero uint64 Document identity." });
        try out.write(.{ .name = "revision", .in = "query", .required = false, .schema = .{ .type = "integer", .minimum = 0, .maximum = api.protocol.max_counter }, .description = "Original resource revision; refresh explicitly after 409." });
        try out.write(.{ .name = "after", .in = "query", .required = false, .schema = .{ .type = "string", .pattern = "^([0-9a-f]{2}){1,128}$" }, .description = "Opaque exclusive register cursor. Requires its original resource revision. Counts cover one bounded page, including detached history." });
    }
    if (paged) for ([_][]const u8{ "after", "position", "policy_revision", "retained_from" }) |param| try out.write(.{ .name = param, .in = "query", .required = false, .schema = .{ .type = "integer", .minimum = 0, .maximum = api.protocol.max_counter }, .description = "Continuation: supply all cut fields together; restart explicitly after 409" });
    if (std.mem.eql(u8, path, "/api/v1/atlas")) for ([_][]const u8{ "position", "process_after", "resource_after" }) |param| try out.write(.{ .name = param, .in = "query", .required = false, .schema = .{ .type = "integer", .minimum = 0, .maximum = api.protocol.max_counter }, .description = "Growing profile only. An after cursor requires its original position; refresh explicitly after 409." });
    if (std.mem.eql(u8, path, "/api/v1/resources/{resource}/records")) {
        try out.write(.{ .name = "revision", .in = "query", .required = false, .schema = .{ .type = "integer", .minimum = 0, .maximum = api.protocol.max_counter }, .description = "Growing resource revision. Refresh explicitly after 409." });
        try out.write(.{ .name = "after", .in = "query", .required = false, .schema = .{ .type = "string", .pattern = "^([0-9a-f]{2}){1,32}$" }, .description = "Exclusive key cursor; supply its original resource revision." });
    }
    if (std.mem.eql(u8, method, "post")) try out.write(.{ .name = "Origin", .in = "header", .required = true, .schema = .{ .type = "string" }, .description = "Must exactly match the configured public_origin. Query capability must be explicitly configured." });
    try out.endArray();
    if (std.mem.eql(u8, method, "post")) {
        try out.objectField("requestBody");
        try out.write(.{ .required = true, .content = .{ .@"application/json" = .{ .schema = .{ .@"$ref" = if (std.mem.eql(u8, path, "/api/v1/query-v2")) "#/components/schemas/UnifiedQueryRequest" else "#/components/schemas/QueryRequest" } } } });
    }
    try out.objectField("responses");
    try out.beginObject();
    try response(out, "200", name);
    for ([_][]const u8{ "400", "403", "404", "409", "410", "429", "503" }) |status| try response(out, status, "Error");
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
    try field(&out, "info", .{ .title = "Transit Board inspection and optional query API", .version = "1.0.0", .description = "Private deployment: no Board keys or sessions. Every reachable viewer shares one read-only Transit principal; current permission is checked on every data read. A separately configured query identity enables the Table query endpoint; inspection remains read-only." });
    try field(&out, "jsonSchemaDialect", "https://json-schema.org/draft/2020-12/schema");
    try field(&out, "security", [0][]const u8{});
    try out.objectField("paths");
    try out.beginObject();
    try route(&out, "/api/v1/resources/{resource}/participation", "get", "ParticipationResponse", true, false);
    try route(&out, "/api/v1/atlas", "get", "AtlasResponse", false, false);
    try route(&out, "/api/v1/query", "post", "QueryResponse", false, false);
    try route(&out, "/api/v1/query-v2", "post", "UnifiedQueryResponse", false, false);
    try route(&out, "/api/v1/capabilities", "get", "Capabilities", false, false);
    try route(&out, "/api/v1/processes", "get", "Response", false, true);
    try route(&out, "/api/v1/processes/{pid}", "get", "Response", true, true);
    try route(&out, "/api/v1/processes/{pid}/associations", "get", "StateResponse", true, true);
    try route(&out, "/api/v1/resources", "get", "StateResponse", false, true);
    try route(&out, "/api/v1/resources/{resource}", "get", "StateResponse", true, true);
    try route(&out, "/api/v1/resources/{resource}/entries", "get", "StateResponse", true, true);
    try route(&out, "/api/v1/resources/{resource}/records", "get", "RecordsResponse", true, false);
    try route(&out, "/api/v1/resources/{resource}/http/{exchange}", "get", "HttpResponse", true, false);
    try route(&out, "/api/v1/resources/{resource}/grpc/{exchange}", "get", "GrpcResponse", true, false);
    try route(&out, "/api/v1/resources/{resource}/documents/{document}", "get", "DocumentResponse", true, false);
    for ([_][]const u8{ "mailbox", "outbox", "effects", "payloads", "history", "journey" }) |resource| {
        var path: [128]u8 = undefined;
        try route(&out, try std.fmt.bufPrint(&path, "/api/v1/processes/{{pid}}/{s}", .{resource}), "get", "Response", true, true);
    }
    try out.endObject();
    try out.objectField("components");
    try out.beginObject();
    try out.objectField("schemas");
    try out.beginObject();
    inline for (.{ "Response", "StateResponse", "Capabilities", "Error", "AtlasResponse", "ParticipationResponse", "QueryRequest", "QueryResponse", "RecordsResponse", "HttpResponse", "GrpcResponse", "DocumentResponse", "UnifiedQueryRequest", "UnifiedQueryResponse" }, .{ api.Response, api.StateResponse, api.Capabilities, api.Error, api.AtlasResponse, api.ParticipationResponse, api.QueryRequest, api.QueryResponse, api.RecordsResponse, api.HttpResponse, api.GrpcResponse, api.DocumentResponse, api.UnifiedQueryRequest, api.UnifiedQueryResponse }) |name, T| {
        try out.objectField(name);
        try s.write(T, &out, .{ .output = true, .safe_integers = true, .sequence_max_length = if (T == api.UnifiedQueryRequest or T == api.UnifiedQueryResponse) 8 else null, .text_max_length = if (T == api.UnifiedQueryRequest or T == api.UnifiedQueryResponse) 131072 else if (T == api.QueryRequest or T == api.QueryResponse) 16384 else 256 });
    }
    try out.endObject();
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
