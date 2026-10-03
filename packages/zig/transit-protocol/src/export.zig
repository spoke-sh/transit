//! Export the same public types used by the Zig client/server as JSON Schema.
//! Declaration order and defaults are included for canonical signing in bindings.
const std = @import("std");
const p = @import("transit_protocol");
const field = p.Schema.field;
pub fn main(init: std.process.Init) !void {
    const g = p.Growth;
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--diagnostic")) {
        try p.Schema.write(p.Diagnostic, &out, .{ .safe_integers = true, .output = true });
        try writer.interface.writeByte('\n');
        return writer.interface.flush();
    }
    try out.beginObject();
    try field(&out, "$schema", "https://json-schema.org/draft/2020-12/schema");
    try field(&out, "title", "Transit native protocol v1");
    try field(&out, "x-transit", .{
        .version = g.version,
        .definition = g.current_definition,
        .request_domain = g.request_domain,
        .query_domain = g.query_domain,
        .identity_maximum = p.max_counter,
        .canonical = "UTF-8 compact JSON; declared field order; include defaults and nulls; decimal integers; single-key tagged unions; reject unknown and duplicate fields",
        .signing = "Ed25519(SHA256(domain || canonical-json))",
        .limits = .{ .record_bytes = p.max_entry_bytes, .key_bytes = g.key_bytes, .page_entries = g.page_size, .turn_mutations = g.turn_mutations, .turn_views = g.turn_views, .turn_outputs = g.turn_outputs },
        .routes = .{
            .{ .path = "/v1/command", .method = "POST", .request = "SignedRequest", .response = "Receipt", .failure = "ErrorResponse" },
            .{ .path = "/v1/query", .method = "POST", .request = "SignedQuery", .response = "Response", .failure = "ErrorResponse" },
        },
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
