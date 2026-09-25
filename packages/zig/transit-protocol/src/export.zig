//! Export the same public types used by the Zig client/server as JSON Schema.
//! Declaration order and defaults are included for canonical signing in bindings.
const std = @import("std");
const p = @import("transit_protocol");
const field = p.Schema.field;
const schema = p.Schema.schema;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "growth")) return growth(init);
    if (args.len != 1) return error.InvalidArguments;
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try field(&out, "title", "Transit public protocol v2");
    try field(&out, "x-transit", .{
        .version = p.version,
        .signing_domain_hex = "7265792e7472616e7369742e726571756573742e763200",
        .signing = "Ed25519(SHA256(domain || canonical-request-json))",
        .canonical = "UTF-8 compact JSON; declared field order; include defaults and nulls; decimal integers; single-key tagged unions; reject unknown and duplicate fields",
        .application_bytes = "lowercase hexadecimal, at most 256 decoded bytes per value",
        .limits = .{ .body_bytes = p.max_body, .record_bytes = p.max_entry_bytes, .turn_outputs = p.max_turn_outputs, .counter_maximum = p.max_counter },
        .routes = .{
            .{ .path = "/v2/delivery", .method = "POST", .request = "SignedDeliveryQuery", .response = "DeliveryStatus", .failure = "ErrorResponse" },
            .{ .path = "/v2/state", .method = "POST", .request = "SignedStateQuery", .response = "StatePage", .failure = "ErrorResponse" },
            .{ .path = "/v2/inspect", .method = "POST", .request = "SignedInspectionQuery", .response = "InspectionPage", .failure = "ErrorResponse" },
            .{ .path = "/v2/command", .method = "POST", .request = "SignedRequest", .response = "Receipt", .failure = "ErrorResponse" },
            .{ .path = "/v2/view", .method = "POST", .request = "SignedRequest", .response = "View", .failure = "ErrorResponse" },
        },
        .state_signing_domain_hex = "7265792e7472616e7369742e73746174652e763100",
        .state_version = p.State.version,
        .inspection_signing_domain_hex = "7265792e7472616e7369742e696e7370656374696f6e2e763100",
        .permissions = .{ .admin = p.permission(.admin), .spawn = p.permission(.spawn), .send = p.permission(.send), .execute = p.permission(.execute), .inspect = p.permission(.inspect), .effect = p.permission(.effect), .publish = p.permission(.publish), .delivery = p.permission(.delivery) },
    });
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "SignedRequest", "View", "Receipt", "ErrorResponse", "InspectionQuery", "SignedInspectionQuery", "InspectionPage", "StateCommand", "StateQuery", "SignedStateQuery", "StatePage", "DeliveryQuery", "SignedDeliveryQuery", "DeliveryStatus" }, .{ p.Request, p.SignedRequest, p.View, p.Receipt, p.ErrorResponse, p.Inspection.Query, p.Inspection.SignedQuery, p.Inspection.Page, p.State.Command, p.State.Query, p.State.SignedQuery, p.State.Page, p.Delivery.Query, p.Delivery.SignedQuery, p.Delivery.Status }) |name, T| {
        try out.objectField(name);
        try schema(T, &out);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}

fn growth(init: std.process.Init) !void {
    const g = p.Growth;
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try field(&out, "title", "Transit growing profile v3 (development)");
    try field(&out, "x-transit", .{
        .version = g.version,
        .status = "contract candidate; service integration in progress",
        .request_domain = g.request_domain,
        .query_domain = g.query_domain,
        .identity_maximum = p.max_counter,
        .canonical = "UTF-8 compact JSON; declared field order; include defaults and nulls; decimal integers; single-key tagged unions; reject unknown and duplicate fields",
        .signing = "Ed25519(SHA256(domain || canonical-json))",
        .limits = .{ .record_bytes = p.max_entry_bytes, .key_bytes = g.key_bytes, .page_entries = g.page_size, .turn_mutations = g.turn_mutations, .turn_views = g.turn_views, .turn_outputs = g.turn_outputs },
    });
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "SignedRequest", "Query", "SignedQuery", "Response", "Receipt", "ErrorResponse" }, .{ g.Request, g.SignedRequest, g.Query, g.SignedQuery, g.Response, p.Receipt, p.ErrorResponse }) |name, T| {
        try out.objectField(name);
        try p.Schema.write(T, &out, .{ .safe_integers = true });
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
