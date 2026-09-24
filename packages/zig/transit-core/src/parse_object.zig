//! Bounded checkpoint parsing directly into caller-owned storage. Large arrays
//! must not travel through by-value generic JSON frames on worker threads.
const std = @import("std");
pub fn Owned(comptime T: type) type {
    return struct {
        value: *T,
        pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!@This() {
            const value = try allocator.create(T);
            errdefer allocator.destroy(value);
            try into(T, value, allocator, source, options);
            return .{ .value = value };
        }
    };
}
pub fn parse(comptime T: type, allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!T {
    const result = try allocator.create(T);
    defer allocator.destroy(result);
    try into(T, result, allocator, source, options);
    return result.*;
}
fn into(comptime T: type, result: *T, allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!void {
    // Small/custom wire values retain the standard parser's exact semantics.
    if (@sizeOf(T) <= 4096) {
        result.* = try std.json.innerParse(T, allocator, source, options);
        return;
    }
    switch (@typeInfo(T)) {
        .optional => |info| {
            if (try source.peekNextTokenType() == .null) {
                _ = try source.next();
                result.* = null;
            } else {
                result.* = @as(info.child, undefined);
                try into(info.child, &result.*.?, allocator, source, options);
            }
        },
        .array => |info| {
            if (try source.next() != .array_begin) return error.UnexpectedToken;
            for (result) |*slot| try into(info.child, slot, allocator, source, options);
            if (try source.next() != .array_end) return error.UnexpectedToken;
        },
        .@"struct" => |info| {
            var seen: [info.field_names.len]bool = @splat(false);
            if (try source.next() != .object_begin) return error.UnexpectedToken;
            while (try source.peekNextTokenType() != .object_end) {
                const name = try std.json.innerParse([]const u8, allocator, source, options);
                var found = false;
                inline for (info.field_names, info.field_types, 0..) |field, F, i| {
                    if (std.mem.eql(u8, name, field)) {
                        if (seen[i]) return error.DuplicateField;
                        try into(F, &@field(result, field), allocator, source, options);
                        seen[i] = true;
                        found = true;
                        break;
                    }
                }
                if (!found) return error.UnknownField;
            }
            _ = try source.next();
            inline for (info.field_names, info.field_types, info.field_attrs, 0..) |field, F, attrs, i| {
                if (!seen[i]) @field(result, field) = attrs.defaultValue(F) orelse return error.MissingField;
            }
        },
        else => @compileError("Large checkpoint field needs a bounded parser"),
    }
}
