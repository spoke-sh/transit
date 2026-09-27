const std = @import("std");
const abi = @import("station_abi");
const s = @import("transit_station");
fn cType(comptime T: type) []const u8 {
    if (T == void) return "void";
    if (T == u32 or T == abi.Status) return "uint32_t";
    if (T == u64) return "uint64_t";
    if (T == usize) return "size_t";
    if (T == [*]const u8 or T == *const [32]u8) return "const uint8_t *";
    if (T == *abi.Server or T == ?*abi.Server) return "station_server *";
    if (T == *?*abi.Server) return "station_server **";
    if (T == *abi.growing.Server or T == ?*abi.growing.Server) return "station_growing_server *";
    if (T == *?*abi.growing.Server) return "station_growing_server **";
    if (T == *abi.query_client.Client or T == ?*abi.query_client.Client) return "station_query_client *";
    if (T == *?*abi.query_client.Client) return "station_query_client **";
    if (T == *const abi.Buffer) return "const station_buffer *";
    if (T == ?*abi.Buffer) return "station_buffer *";
    if (T == *?*abi.Buffer) return "station_buffer **";
    @compileError("Unsupported Station ABI type: " ++ @typeName(T));
}
pub fn main(init: std.process.Init) !void {
    var bytes: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &bytes);
    var out: std.json.Stringify = .{ .writer = &writer.interface, .options = .{ .whitespace = .indent_2 } };
    try out.beginObject();
    try s.protocol.Schema.field(&out, "version", abi.version);
    try s.protocol.Schema.field(&out, "minimum_stack_bytes", abi.minimum_stack_bytes);
    try out.objectField("statuses");
    try out.beginObject();
    inline for (@typeInfo(abi.Status).@"enum".field_names, @typeInfo(abi.Status).@"enum".field_values) |name, value| try s.protocol.Schema.field(&out, name, value);
    try out.endObject();
    try out.objectField("functions");
    try out.beginArray();
    inline for (@typeInfo(abi.Api).@"struct".decl_names) |name| {
        const function = @typeInfo(@TypeOf(@field(abi.Api, name))).@"fn";
        try out.beginObject();
        try s.protocol.Schema.field(&out, "name", name);
        try s.protocol.Schema.field(&out, "result", cType(function.return_type.?));
        try out.objectField("parameters");
        try out.beginArray();
        inline for (function.param_types) |T| try out.write(cType(T.?));
        try out.endArray();
        try out.endObject();
    }
    try out.endArray();
    try out.objectField("schemas");
    try out.beginObject();
    inline for (.{ "Config", "Action", "Result", "Event", "ArrowCell", "HostConfig", "HostRequest", "GrowingConfig", "GrowingAction", "GrowingResult", "GrowingEvent", "GrowingCapabilities", "HttpCodecAction", "HttpCodecResult", "HttpReadAction", "HttpReadResult", "GrpcCodecAction", "GrpcCodecResult", "GrpcReadAction", "GrpcReadResult", "DocumentCodecAction", "DocumentCodecResult", "DocumentReadAction", "DocumentReadResult", "UnifiedQueryCodecAction", "UnifiedQueryCodecResult", "UnifiedQueryConfig", "UnifiedQueryAction", "UnifiedQueryResult" }, .{ abi.Config, abi.actions.Action, abi.actions.Result, abi.Event, abi.actions.ArrowCell, abi.host.Config, abi.host.Request, abi.growing.Config, abi.growing.actions.Action, abi.growing.actions.Result, abi.growing.Event, abi.growing.Capabilities, abi.http.Action, abi.http.Result, abi.http.ReadAction, abi.http.ReadResult, abi.grpc.Action, abi.grpc.Result, abi.grpc.ReadAction, abi.grpc.ReadResult, abi.document.Action, abi.document.Result, abi.document_bridge.ReadAction, abi.document_bridge.ReadResult, abi.unified_query.Action, abi.unified_query.Result, abi.query_client.Config, abi.query_client.bridge.Action, abi.query_client.bridge.Result }) |name, T| {
        try out.objectField(name);
        // Foreign text includes whole frozen requests and IPC encoded as hex.
        // It is not the kernel's 256-byte opaque Value. Domain helpers impose
        // their narrower field budgets, and the host bounds the complete line.
        try s.protocol.Schema.write(T, &out, .{ .safe_integers = true, .text_max_length = s.protocol.max_body * 2, .sequence_max_length = abi.http.http.Request.maximum_pieces, .output = T == abi.Event or T == abi.actions.Result or T == abi.actions.ArrowCell or T == abi.growing.Event or T == abi.growing.actions.Result or T == abi.growing.Capabilities or T == abi.http.Result or T == abi.http.ReadResult or T == abi.grpc.Result or T == abi.grpc.ReadResult or T == abi.document.Result or T == abi.document_bridge.ReadResult or T == abi.unified_query.Result or T == abi.query_client.bridge.Result });
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
