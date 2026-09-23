//! Parse large internal checkpoints through a heap object. The pinned Debug
//! compiler otherwise reserves multi-megabyte frames for generic struct parsing.
const std = @import("std");
pub fn parse(comptime T: type, allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!T {
    const info = @typeInfo(T).@"struct";
    const result = try allocator.create(T);
    defer allocator.destroy(result);
    var seen: [info.field_names.len]bool = @splat(false);
    if (try source.next() != .object_begin) return error.UnexpectedToken;
    while (try source.peekNextTokenType() != .object_end) {
        const name = try std.json.innerParse([]const u8, allocator, source, options);
        var found = false;
        inline for (info.field_names, info.field_types, 0..) |field, F, i| {
            if (std.mem.eql(u8, name, field)) {
                if (seen[i]) return error.DuplicateField;
                @field(result, field) = try std.json.innerParse(F, allocator, source, options);
                seen[i] = true;
                found = true;
                break;
            }
        }
        if (!found) return error.UnknownField;
    }
    _ = try source.next();
    inline for (info.field_names, info.field_types, info.field_attrs, 0..) |field, F, attrs, i| {
        if (!seen[i]) {
            @field(result, field) = attrs.defaultValue(F) orelse return error.MissingField;
        }
    }
    return result.*;
}
