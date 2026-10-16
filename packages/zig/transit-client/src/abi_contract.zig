//! Reflect exported signatures; the generated header cannot diverge from Zig.
const std = @import("std");
const abi = @import("Abi.zig");
const p = @import("transit_client").protocol;
const authorization = @import("transit_client").AuthorizationBridge;

fn cType(comptime T: type) []const u8 {
    if (T == void) return "void";
    if (T == u32 or T == abi.Status) return "uint32_t";
    if (T == usize) return "size_t";
    if (T == [*]const u8 or T == *const [32]u8) return "const uint8_t *";
    if (T == *abi.Client or T == ?*abi.Client) return "transit_client *";
    if (T == *?*abi.Client) return "transit_client **";
    if (T == *const abi.Operation) return "const transit_operation *";
    if (T == ?*abi.Operation) return "transit_operation *";
    if (T == *?*abi.Operation) return "transit_operation **";
    if (T == *const abi.Buffer) return "const transit_buffer *";
    if (T == ?*abi.Buffer) return "transit_buffer *";
    if (T == *?*abi.Buffer) return "transit_buffer **";
    @compileError("Unsupported C ABI type: " ++ @typeName(T));
}

pub fn main(init: std.process.Init) !void {
    var scratch: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &scratch);
    var json: std.json.Stringify = .{ .writer = &output.interface, .options = .{ .whitespace = .indent_2 } };
    try json.beginObject();
    try json.objectField("version");
    try json.write(abi.version);
    try p.Schema.field(&json, "definition", p.Growth.current_definition);
    try p.Schema.field(&json, "minimum_stack_bytes", abi.minimum_stack_bytes);
    try p.Schema.field(&json, "limits", .{ .max_counter = p.max_counter, .value_bytes = p.Value.max_bytes, .max_body = p.max_body, .host_line_bytes = abi.host.max_line_bytes, .host_config_bytes = abi.host.max_config_bytes });
    inline for (.{ "statuses", "kinds" }, .{ abi.Status, abi.Kind }) |name, T| {
        try json.objectField(name);
        try json.beginObject();
        inline for (@typeInfo(T).@"enum".field_names, @typeInfo(T).@"enum".field_values) |field, value| {
            try json.objectField(field);
            try json.write(value);
        }
        try json.endObject();
    }
    try json.objectField("functions");
    try json.beginArray();
    inline for (@typeInfo(abi.Api).@"struct".decl_names) |name| {
        const function = @typeInfo(@TypeOf(@field(abi.Api, name))).@"fn";
        try json.beginObject();
        try json.objectField("name");
        try json.write(name);
        try json.objectField("result");
        try json.write(cType(function.return_type.?));
        try json.objectField("parameters");
        try json.beginArray();
        inline for (function.param_types) |T| try json.write(cType(T.?));
        try json.endArray();
        try json.endObject();
    }
    try json.endArray();
    try json.objectField("schemas");
    try json.beginObject();
    inline for (.{ "OperationMetadata", "ClientHostConfig", "ClientHostRequest", "ClientCapabilities", "Diagnostic", "AuthorizationConnection", "AuthorizationAction", "AuthorizationResult" }, .{ abi.Metadata, abi.host.Config, abi.host.Request, abi.host.Capabilities, p.Diagnostic, authorization.Connection, authorization.Action, authorization.Result }) |name, T| {
        try json.objectField(name);
        try p.Schema.write(T, &json, .{ .safe_integers = true, .text_max_length = p.max_body * 2, .output = T == abi.Metadata or T == abi.host.Capabilities or T == p.Diagnostic or T == authorization.Result });
    }
    try json.endObject();
    try json.endObject();
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
