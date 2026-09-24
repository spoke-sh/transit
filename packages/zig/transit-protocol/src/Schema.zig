//! Shared JSON Schema writer for typed public wire contracts.
const std = @import("std");
const p = @import("root.zig");
pub fn field(out: *std.json.Stringify, name: []const u8, value: anytype) !void {
    try out.objectField(name);
    try out.write(value);
}
pub fn schema(comptime T: type, out: *std.json.Stringify) std.Io.Writer.Error!void {
    return write(T, out, .{});
}
pub const Options = struct { output: bool = false, safe_integers: bool = false };
pub fn write(comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
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
            try field(out, "minimum", if (options.safe_integers) @max(std.math.minInt(T), -p.max_counter) else std.math.minInt(T));
            try field(out, "maximum", if (options.safe_integers) @min(std.math.maxInt(T), p.max_counter) else std.math.maxInt(T));
            try field(out, "x-transit-bits", info.bits);
            try field(out, "x-transit-signed", info.signedness == .signed);
        },
        .pointer => |info| {
            if (info.size != .slice or info.child != u8) @compileError("Only text slices are public wire pointers");
            try field(out, "type", "string");
            try field(out, "maxLength", 256);
        },
        .bool => try field(out, "type", "boolean"),
        .void => {
            try field(out, "type", "object");
            try field(out, "maxProperties", 0);
        },
        .optional => |info| {
            try out.objectField("anyOf");
            try out.beginArray();
            try write(info.child, out, options);
            try out.write(.{ .type = "null" });
            try out.endArray();
        },
        .array => |info| {
            try field(out, "type", "array");
            try field(out, "minItems", info.len);
            try field(out, "maxItems", info.len);
            try out.objectField("items");
            try write(info.child, out, options);
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
                try write(F, out, options);
            }
            try out.endObject();
            try out.objectField("required");
            try out.beginArray();
            inline for (info.field_names, info.field_types, info.field_attrs) |name, F, attrs| {
                // Runtime bindings omit absent upgrade evidence to preserve
                // checkpoint serialization from before the upgrade extension.
                if (comptime T == p.Runtime.Binding and std.mem.eql(u8, name, "upgrade_from")) continue;
                if (comptime options.output or attrs.defaultValue(F) == null) try out.write(name);
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
                try write(F, out, options);
                try out.endObject();
                try out.endObject();
            }
            try out.endArray();
        },
        else => @compileError("Public contract contains an unsupported wire type: " ++ @typeName(T)),
    }
    try out.endObject();
}
