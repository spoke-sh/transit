//! Export the same public types used by the Zig client/server as JSON Schema.
//! Declaration order and defaults are included for canonical signing in bindings.
const std = @import("std");
const p = @import("transit_protocol");
fn field(out: *std.json.Stringify, name: []const u8, value: anytype) !void {
    try out.objectField(name);
    try out.write(value);
}
fn schema(comptime T: type, out: *std.json.Stringify) std.Io.Writer.Error!void {
    @setEvalBranchQuota(100000);
    try out.beginObject();
    if (T == p.Value) {
        try field(out, "type", "string");
        try field(out, "pattern", "^(?:[0-9a-f]{2})*$");
        try field(out, "maxLength", p.Value.max_bytes * 2);
        try field(out, "x-transit-encoding", "lowercase-hex");
    } else switch (@typeInfo(T)) {
        .int => |info| {
            try field(out, "type", "integer");
            try field(out, "minimum", std.math.minInt(T));
            try field(out, "maximum", std.math.maxInt(T));
            try field(out, "x-transit-bits", info.bits);
            try field(out, "x-transit-signed", info.signedness == .signed);
        },
        .bool => try field(out, "type", "boolean"),
        .void => {
            try field(out, "type", "object");
            try field(out, "maxProperties", 0);
        },
        .optional => |info| {
            try out.objectField("anyOf");
            try out.beginArray();
            try schema(info.child, out);
            try out.write(.{ .type = "null" });
            try out.endArray();
        },
        .array => |info| {
            try field(out, "type", "array");
            try field(out, "minItems", info.len);
            try field(out, "maxItems", info.len);
            try out.objectField("items");
            try schema(info.child, out);
        },
        .@"enum" => |info| {
            try field(out, "type", "string");
            try field(out, "enum", info.field_names);
        },
        .@"struct" => |info| {
            try field(out, "type", "object");
            try field(out, "additionalProperties", false);
            try field(out, "x-transit-field-order", info.field_names);
            try out.objectField("properties");
            try out.beginObject();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.objectField(name);
                try schema(F, out);
            }
            try out.endObject();
            try out.objectField("required");
            try out.beginArray();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| {
                if (comptime attrs.defaultValue(F) == null) try out.write(name);
            }
            try out.endArray();
            try out.objectField("x-transit-defaults");
            try out.beginObject();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| {
                if (comptime attrs.defaultValue(F)) |value| try field(out, name, value);
            }
            try out.endObject();
        },
        .@"union" => |info| {
            try out.objectField("oneOf");
            try out.beginArray();
            inline for (info.field_names, info.field_types) |name, F| {
                try out.beginObject();
                try field(out, "type", "object");
                try field(out, "additionalProperties", false);
                try field(out, "required", &[_][]const u8{name});
                try out.objectField("properties");
                try out.beginObject();
                try out.objectField(name);
                try schema(F, out);
                try out.endObject();
                try out.endObject();
            }
            try out.endArray();
        },
        else => @compileError("Public contract contains an unsupported wire type: " ++ @typeName(T)),
    }
    try out.endObject();
}
pub fn main(init: std.process.Init) !void {
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
            .{ .path = "/v2/inspect", .method = "POST", .request = "SignedInspectionQuery", .response = "InspectionPage", .failure = "ErrorResponse" },
            .{ .path = "/v2/command", .method = "POST", .request = "SignedRequest", .response = "Receipt", .failure = "ErrorResponse" },
            .{ .path = "/v2/view", .method = "POST", .request = "SignedRequest", .response = "View", .failure = "ErrorResponse" },
        },
        .inspection_signing_domain_hex = "7265792e7472616e7369742e696e7370656374696f6e2e763100",
        .permissions = .{ .admin = p.permission(.admin), .spawn = p.permission(.spawn), .send = p.permission(.send), .execute = p.permission(.execute), .inspect = p.permission(.inspect), .effect = p.permission(.effect), .publish = p.permission(.publish) },
    });
    try out.objectField("$defs");
    try out.beginObject();
    inline for (.{ "Request", "SignedRequest", "View", "Receipt", "ErrorResponse", "InspectionQuery", "SignedInspectionQuery", "InspectionPage" }, .{ p.Request, p.SignedRequest, p.View, p.Receipt, p.ErrorResponse, p.Inspection.Query, p.Inspection.SignedQuery, p.Inspection.Page }) |name, T| {
        try out.objectField(name);
        try schema(T, &out);
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
