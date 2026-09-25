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
    inline for (.{ "Config", "Action", "Result", "Event", "ArrowCell", "HostConfig", "HostRequest" }, .{ abi.Config, abi.actions.Action, abi.actions.Result, abi.Event, abi.actions.ArrowCell, abi.host.Config, abi.host.Request }) |name, T| {
        try out.objectField(name);
        try s.protocol.Schema.write(T, &out, .{ .safe_integers = true });
    }
    try out.endObject();
    try out.endObject();
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
