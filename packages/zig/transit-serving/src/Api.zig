//! Owning operation metadata and reflected descriptions. No hand-maintained
//! parallel schema copies; native signatures remain the authority boundary.
const std = @import("std");
const root = @import("root.zig");
const schema = root.protocol.Schema;
const field = schema.field;
const r = root.ReactiveModel;
const w = root.ReactiveWire;
pub const description_bytes = 256 * 1024;
pub const Discovery = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u8 = 1,
    service: u64,
    ingress: u64,
    resource: u64,
    binding_revision: u64,
    watch_revision: u64,
    sse: bool = true,
    websocket: bool = true,
    subprotocol: []const u8 = r.subprotocol,
    openapi_sha256: [32]u8,
    asyncapi_sha256: [32]u8,
};
pub const Error = struct { err: enum { ServingRequestFailed, HttpCapacity, InvalidHttpRequest }, reason: ?root.ServingDiagnostic.Reason = null, diagnostic: ?root.protocol.Diagnostic = null };
pub const definitions = .{
    .{ "SubjectProof", root.protocol.Authorization.Proof },
    .{ "Diagnostic", root.protocol.Diagnostic },
    .{ "SignedCommand", r.SignedSend },
    .{ "ServingRead", root.Model.SignedRead },
    .{ "ServingResponse", root.Adapter.ReadResult },
    .{ "Receipt", root.Adapter.Receipt },
    .{ "ReactiveRead", r.SignedRead },
    .{ "ReactiveResponse", root.ReactiveAdapter.Response },
    .{ "Bootstrap", w.Bootstrap },
    .{ "ClientMessage", w.ClientMessage },
    .{ "ServerMessage", w.ServerMessage },
    .{ "Discovery", Discovery },
    .{ "Error", Error },
    .{ "SseItem", w.SseItem },
};
pub const operations = .{
    .{ "command", "/serving/v1/command", "SignedCommand", "Receipt", "202" },
    .{ "servingRead", "/serving/v1/read", "ServingRead", "ServingResponse", "200" },
    .{ "control", "/reactive/v1/control", "SignedCommand", "Receipt", "202" },
    .{ "read", "/reactive/v1/read", "ReactiveRead", "ReactiveResponse", "200" },
    .{ "challenge", "/reactive/v1/challenge", "ReactiveRead", "ServerMessage", "200" },
    .{ "events", "/reactive/v1/events", "Bootstrap", "ServerMessage", "200" },
    .{ "discovery", "/reactive/v1/discovery", "ServingRead", "Discovery", "200" },
};
fn reference(out: *std.json.Stringify, name: []const u8) !void {
    var bytes: [128]u8 = undefined;
    try out.write(.{ .@"$ref" = try std.fmt.bufPrint(&bytes, "#/components/schemas/{s}", .{name}) });
}
fn schemas(out: *std.json.Stringify) !void {
    try out.objectField("schemas");
    try out.beginObject();
    inline for (definitions) |definition| {
        try out.objectField(definition[0]);
        try schema.write(definition[1], out, .{ .safe_integers = true, .sequence_max_length = 8, .output = definition[1] == root.protocol.Diagnostic, .authorization_proof_reference = if (definition[1] == root.protocol.Authorization.Proof) null else "#/components/schemas/SubjectProof", .diagnostic_reference = if (definition[1] == root.protocol.Diagnostic) null else "#/components/schemas/Diagnostic" });
    }
    try out.endObject();
}
pub const Format = enum { openapi, asyncapi };
pub fn write(format: Format, writer: *std.Io.Writer) !void {
    var out: std.json.Stringify = .{ .writer = writer, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    if (format == .openapi) try openapi(&out) else try asyncapi(&out);
    try out.endObject();
    try writer.writeByte('\n');
}
fn openapi(out: *std.json.Stringify) !void {
    try field(out, "openapi", "3.2.1");
    try field(out, "jsonSchemaDialect", "https://spec.openapis.org/oas/3.2/dialect/2026-02-26");
    try field(out, "info", .{ .title = "Transit serving and reactive API", .version = "1.0.0", .description = "Provisioned native Ed25519 proofs in JSON bodies; exact HTTPS Host/Origin. Current service policy, native grants, source declarations, session generations and leases are runtime requirements. Ingress receipts are distinct from committed application outcomes. No bearer credential is accepted in URLs." });
    try field(out, "x-transit-authentication", .{ .type = "signed-json-body", .algorithm = "Ed25519", .current_native_grants = true, .current_service_policy = true });
    try out.objectField("paths");
    try out.beginObject();
    inline for (operations) |operation| {
        const events = comptime std.mem.eql(u8, operation[0], "events");
        try out.objectField(operation[1]);
        try out.beginObject();
        try out.objectField("post");
        try out.beginObject();
        try field(out, "operationId", operation[0]);
        try field(out, "description", if (events) "Fetch-streaming SSE after consuming one authenticated challenge and observing the signed attachment commit. Each SSE item has event/data and an optional id; data is a JSON-encoded ServerMessage. The challenge and streaming POST must use the same gateway. Event IDs are the lowercase-hex canonical signed cursor. Resume must match Last-Event-ID and the signed read cursor. A terminal event or interruption ends streaming; it does not cancel accepted commands." else if (comptime std.mem.eql(u8, operation[0], "control")) "Reserved capacity for signed renew, unsubscribe, close and trusted observer controls only. Native acceptance does not prove the lifecycle transition committed." else "A signed native scope plus current authorization is required. Retain uncertain command bytes and recover the same durable operation.");
        if (events) try field(out, "parameters", .{.{ .name = "Last-Event-ID", .in = "header", .required = false, .schema = .{ .type = "string", .pattern = "^(?:[0-9a-f]{2})+$", .maxLength = 512 } }});
        try out.objectField("requestBody");
        try out.beginObject();
        try field(out, "required", true);
        try out.objectField("content");
        try out.beginObject();
        try out.objectField("application/json");
        try out.beginObject();
        try out.objectField("schema");
        try reference(out, operation[2]);
        try out.endObject();
        try out.endObject();
        try out.endObject();
        try out.objectField("responses");
        try out.beginObject();
        try out.objectField(operation[4]);
        try out.beginObject();
        try field(out, "description", if (events) "Authorized bounded event stream" else "Bounded observation or ingress-stage receipt");
        try out.objectField("content");
        try out.beginObject();
        try out.objectField(if (events) "text/event-stream" else "application/json");
        try out.beginObject();
        try out.objectField(if (events) "itemSchema" else "schema");
        try reference(out, if (events) "SseItem" else operation[3]);
        try out.endObject();
        try out.endObject();
        try out.endObject();
        try out.objectField("default");
        try out.write(.{ .description = "400 invalid envelope, 403 current denial, 404 absent identity, 409 conflict/fence/reset, 410 closed/expired session or unavailable resource, 413 byte limit, 429 caller capacity, 502 invalid evidence, 503 unavailable/capacity, 504 upstream timeout. Errors never prove an uncertain command was unaccepted.", .content = .{ .@"application/json" = .{ .schema = .{ .@"$ref" = "#/components/schemas/Error" } } } });
        try out.endObject();
        try out.endObject();
        try out.endObject();
    }
    try out.endObject();
    try out.objectField("components");
    try out.beginObject();
    try schemas(out);
    try out.endObject();
    try field(out, "x-transit-budgets", .{ .body_bytes = r.max_message_bytes, .sessions = r.max_sessions, .sessions_per_caller = r.max_caller_sessions, .subscriptions_per_session = 1, .lease_ms = r.max_lease_ms });
}
fn asyncapi(out: *std.json.Stringify) !void {
    try field(out, "asyncapi", "3.0.0");
    try field(out, "info", .{ .title = "Transit reactive WebSocket", .version = "1.0.0", .description = "RFC 6455 HTTP/1.1, transit.reactive.v1, JSON text, provisioned Ed25519 challenge bootstrap in the first client message. No URL credentials, arbitrary browser handshake headers, compression, binary messages or HTTP/2 CONNECT. Native exact command recovery is shared with HTTP." });
    try field(out, "defaultContentType", "application/json");
    try field(out, "servers", .{ .configured = .{ .host = "{host}", .protocol = "wss", .variables = .{ .host = .{ .default = "serving.example.test", .description = "Must equal the deployment's exact configured public HTTPS host." } } } });
    try field(out, "channels", .{ .reactive = .{ .address = "/reactive/v1/websocket", .servers = .{.{ .@"$ref" = "#/servers/configured" }}, .messages = .{ .client = .{ .@"$ref" = "#/components/messages/client" }, .server = .{ .@"$ref" = "#/components/messages/server" } }, .bindings = .{ .ws = .{ .method = "GET", .bindingVersion = "0.1.0", .headers = .{ .type = "object", .properties = .{ .Origin = .{ .type = "string" }, .@"Sec-WebSocket-Protocol" = .{ .type = "string", .@"const" = r.subprotocol } }, .required = .{ "Origin", "Sec-WebSocket-Protocol" } } } } } });
    try field(out, "operations", .{
        .receiveClient = .{ .action = "receive", .channel = .{ .@"$ref" = "#/channels/reactive" }, .messages = .{.{ .@"$ref" = "#/channels/reactive/messages/client" }} },
        .sendServer = .{ .action = "send", .channel = .{ .@"$ref" = "#/channels/reactive" }, .messages = .{.{ .@"$ref" = "#/channels/reactive/messages/server" }} },
    });
    try out.objectField("components");
    try out.beginObject();
    try field(out, "messages", .{
        .client = .{ .name = "ClientMessage", .contentType = "application/json", .payload = .{ .@"$ref" = "#/components/schemas/ClientMessage" } },
        .server = .{ .name = "ServerMessage", .contentType = "application/json", .payload = .{ .@"$ref" = "#/components/schemas/ServerMessage" } },
    });
    try schemas(out);
    try out.endObject();
    try field(out, "x-transit-budgets", .{ .message_bytes = r.max_message_bytes, .fragments = r.max_fragments, .control_bytes = 125, .bootstrap_ms = 2000, .write_ms = 1000, .revalidate_ms = 500 });
}
pub fn digest(format: Format, allocator: std.mem.Allocator) ![32]u8 {
    const bytes = try allocator.alloc(u8, description_bytes);
    defer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    try write(format, &writer);
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &result, .{});
    return result;
}

test "shared diagnostic references keep both API descriptions within the existing bound" {
    var bytes: [description_bytes]u8 = undefined;
    for (std.enums.values(Format)) |format| {
        var writer: std.Io.Writer = .fixed(&bytes);
        try write(format, &writer);
        try std.testing.expect(writer.buffered().len < description_bytes);
        try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "#/components/schemas/Diagnostic") != null);
    }
}
