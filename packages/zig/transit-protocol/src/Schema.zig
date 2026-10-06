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
pub const Options = struct {
    /// An owner may factor the shared diagnostic into its own definitions.
    diagnostic_reference: ?[]const u8 = null,
    output: bool = false,
    safe_integers: bool = false,
    text_max_length: usize = 256,
    /// Opt-in host collection bound. Kernel wire contracts keep fixed arrays;
    /// domain validation can impose a stricter per-field limit on host slices.
    sequence_max_length: ?usize = null,
    /// Override only the next slice dimension, preserving child collection bounds.
    sequence_outer_max_length: ?usize = null,
};
/// A public owner can narrow or extend one sequence field without changing
/// neighboring collections or the caller's other schema options.
pub fn fieldOptions(comptime T: type, comptime name: []const u8, comptime options: Options) Options {
    var result = options;
    if (comptime @hasDecl(T, "json_schema_sequence_bounds") and @hasField(@TypeOf(T.json_schema_sequence_bounds), name)) {
        result.sequence_max_length = @field(T.json_schema_sequence_bounds, name);
    }
    if (comptime @hasDecl(T, "json_schema_outer_sequence_bounds") and @hasField(@TypeOf(T.json_schema_outer_sequence_bounds), name)) {
        result.sequence_outer_max_length = @field(T.json_schema_outer_sequence_bounds, name);
    }
    if (comptime @hasDecl(T, "json_schema_text_bounds") and @hasField(@TypeOf(T.json_schema_text_bounds), name)) {
        result.text_max_length = @field(T.json_schema_text_bounds, name);
    }
    return result;
}
pub fn sequenceItems(comptime options: Options) Options {
    var result = options;
    result.sequence_outer_max_length = null;
    return result;
}
/// Reflect recursive host values with local references. The selected options
/// and each owner's field bounds remain part of the referenced type identity.
pub fn writeRecursive(comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
    return @import("RecursiveSchema.zig").write(T, out, options);
}
/// Embed a recursive schema at a known JSON pointer in a larger contract.
pub fn writeRecursiveAt(comptime T: type, out: *std.json.Stringify, comptime options: Options, comptime base: []const u8) std.Io.Writer.Error!void {
    return @import("RecursiveSchema.zig").writeAt(T, out, options, base);
}
test {
    _ = @import("RecursiveSchema.zig");
}
pub fn write(comptime T: type, out: *std.json.Stringify, comptime options: Options) std.Io.Writer.Error!void {
    @setEvalBranchQuota(100000);
    if (T == p.Diagnostic) {
        if (options.diagnostic_reference) |name| return out.write(.{ .@"$ref" = name });
    }
    if (comptime @typeInfo(T) == .@"struct") {
        if (comptime @hasDecl(T, "jsonSchema")) return T.jsonSchema(out);
    }
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
            if (info.size != .slice) @compileError("Public wire pointers must be slices");
            if (info.child == u8) {
                try field(out, "type", "string");
                try field(out, "maxLength", options.text_max_length);
            } else {
                const bound = options.sequence_outer_max_length orelse (options.sequence_max_length orelse @compileError("Public sequences require an explicit finite profile bound"));
                try field(out, "type", "array");
                try field(out, "maxItems", bound);
                try out.objectField("items");
                try write(info.child, out, sequenceItems(options));
            }
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
                if (comptime @hasDecl(T, "json_schema_fields") and @hasField(@TypeOf(T.json_schema_fields), name)) {
                    try out.write(@field(T.json_schema_fields, name));
                } else try write(F, out, fieldOptions(T, name, options));
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
                try write(F, out, fieldOptions(T, name, options));
                try out.endObject();
                try out.endObject();
            }
            try out.endArray();
        },
        else => @compileError("Public contract contains an unsupported wire type: " ++ @typeName(T)),
    }
    try out.endObject();
}

test "public owned scalar schema follows its JSON codec hook" {
    const Scalar = struct {
        pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
            try out.write(.{ .type = "string", .pattern = "^[0-9]+$" });
        }
    };
    var bytes: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    var out: std.json.Stringify = .{ .writer = &writer };
    try write(Scalar, &out, .{});
    try std.testing.expectEqualStrings("{\"type\":\"string\",\"pattern\":\"^[0-9]+$\"}", writer.buffered());
}

test "sequence field bounds preserve neighboring collections and schema options" {
    const Example = struct {
        pub const json_schema_sequence_bounds = .{ .instructions = 64 };
        columns: []const bool,
        instructions: []const u32,
    };
    const Selection = union(enum) {
        pub const json_schema_sequence_bounds = .{ .instructions = 64 };
        columns: []const bool,
        instructions: []const u32,
    };
    const t = std.testing;
    inline for (.{ Example, Selection }) |T| {
        var bytes: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var out: std.json.Stringify = .{ .writer = &writer };
        try write(T, &out, .{ .output = true, .sequence_max_length = 8 });
        const decoded = try std.json.parseFromSlice(std.json.Value, t.allocator, writer.buffered(), .{});
        defer decoded.deinit();
        const columns = if (T == Example) decoded.value.object.get("properties").?.object.get("columns").? else decoded.value.object.get("oneOf").?.array.items[0].object.get("properties").?.object.get("columns").?;
        const instructions = if (T == Example) decoded.value.object.get("properties").?.object.get("instructions").? else decoded.value.object.get("oneOf").?.array.items[1].object.get("properties").?.object.get("instructions").?;
        try t.expectEqual(@as(i64, 8), columns.object.get("maxItems").?.integer);
        try t.expectEqual(@as(i64, 64), instructions.object.get("maxItems").?.integer);
        try t.expectEqualStrings("integer", instructions.object.get("items").?.object.get("type").?.string);
    }
}
