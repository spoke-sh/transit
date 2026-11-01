//! Bounded human presentation of logical values. Neutral JSON owns lossless wire
//! representation; this formatter never changes stored values or type admission.
const std = @import("std");
const t = @import("Types.zig");
pub fn typeName(out: *std.Io.Writer, value: t.Type) anyerror!void {
    switch (value) {
        .decimal => |d| try out.print("decimal({d},{d})", .{ d.precision, d.scale }),
        .timestamp => |zone| try out.print("timestamp({s})", .{@tagName(zone)}),
        .range, .multirange => |subtype| {
            try out.print("{s}<", .{@tagName(value)});
            try typeName(out, subtype.*);
            try out.writeByte('>');
        },
        .vector => |shape| try out.print("vector({d},{s})", .{ shape.dimensions, @tagName(shape.element) }),
        .list => |element| {
            try out.writeAll("list<");
            try typeName(out, element.type.*);
            if (element.nullable) try out.writeByte('?');
            try out.writeByte('>');
        },
        .array => |array| {
            try out.print("array[{d}]<", .{array.length});
            try typeName(out, array.element.type.*);
            if (array.element.nullable) try out.writeByte('?');
            try out.writeByte('>');
        },
        .map => |map| {
            try out.writeAll("map<");
            try typeName(out, map.key.*);
            try out.writeByte(',');
            try typeName(out, map.value.type.*);
            if (map.value.nullable) try out.writeByte('?');
            try out.writeByte('>');
        },
        .structure, .tagged_union => |fields| {
            try out.print("{s}<", .{@tagName(value)});
            for (fields, 0..) |field, i| {
                if (i != 0) try out.writeByte(',');
                try std.json.Stringify.value(field.name, .{ .escape_unicode = true }, out);
                try out.writeByte(':');
                try typeName(out, field.type);
                if (field.nullable) try out.writeByte('?');
                if (field.optional) try out.writeByte('*');
            }
            try out.writeByte('>');
        },
        else => try out.writeAll(@tagName(value)),
    }
}
pub fn cell(out: *std.Io.Writer, value: t.Values.Cell, expected: t.Type) anyerror!void {
    switch (value) {
        .missing => try out.writeAll("MISSING"),
        .null => try out.writeAll("NULL"),
        .type_error => |kind| try out.print("TYPE_ERROR({s})", .{@tagName(kind)}),
        .conflict => |alternatives| {
            try out.writeAll("CONFLICT[");
            for (alternatives, 0..) |alternative, i| {
                if (i != 0) try out.writeAll(", ");
                try out.print("{d}@{d}: ", .{ alternative.counter, alternative.replica });
                try cell(out, switch (alternative.value) {
                    .null => .null,
                    .type_error => |kind| .{ .type_error = kind },
                    .value => |v| .{ .value = v },
                }, expected);
            }
            try out.writeByte(']');
        },
        .value => |v| switch (v) {
            .atom => |a| try atom(out, a, expected),
            .range => |r| try range(out, r, expected.range.*),
            .multirange => |ranges| {
                try out.writeByte('{');
                for (ranges, 0..) |r, i| {
                    if (i != 0) try out.writeByte(',');
                    try range(out, r, expected.multirange.*);
                }
                try out.writeByte('}');
            },
            .vector => |bytes| {
                if (expected.vector.element == .binary) {
                    try out.writeAll("0x");
                    for (bytes) |byte| try out.print("{x:0>2}", .{byte});
                } else {
                    try out.writeByte('[');
                    for (0..expected.vector.dimensions) |i| {
                        if (i != 0) try out.writeByte(',');
                        try out.print("{d}", .{t.Vectors.element(expected.vector.element, bytes, i)});
                    }
                    try out.writeByte(']');
                }
            },
            .json => |bytes| {
                try out.writeAll("JSON ");
                try std.json.Stringify.value(bytes, .{ .escape_unicode = true }, out);
            },
            .structure => |values| {
                try out.writeByte('{');
                for (values, expected.structure, 0..) |child, field, i| {
                    if (i != 0) try out.writeAll(", ");
                    try std.json.Stringify.value(field.name, .{ .escape_unicode = true }, out);
                    try out.writeAll(": ");
                    try cell(out, child, field.type);
                }
                try out.writeByte('}');
            },
            .list, .array => |values| {
                const element = if (expected == .list) expected.list.type.* else expected.array.element.type.*;
                try out.writeByte('[');
                for (values, 0..) |child, i| {
                    if (i != 0) try out.writeAll(", ");
                    try cell(out, child, element);
                }
                try out.writeByte(']');
            },
            .map => |entries| {
                try out.writeAll("MAP{");
                for (entries, 0..) |entry, i| {
                    if (i != 0) try out.writeAll(", ");
                    try atom(out, entry.key, expected.map.key.*);
                    try out.writeAll(": ");
                    try cell(out, entry.value, expected.map.value.type.*);
                }
                try out.writeByte('}');
            },
            .tagged_union => |tagged| {
                const variant = expected.tagged_union[tagged.index];
                try std.json.Stringify.value(variant.name, .{ .escape_unicode = true }, out);
                try out.writeByte('(');
                try cell(out, tagged.value.*, variant.type);
                try out.writeByte(')');
            },
        },
    }
}
fn range(out: *std.Io.Writer, value: t.Ranges.Value, subtype: t.Type) !void {
    if (value.is_empty) return out.writeAll("empty");
    try out.writeByte(if (value.lower != null and value.lower.?.inclusive) '[' else '(');
    if (value.lower) |bound| try atom(out, bound.value, subtype);
    try out.writeByte(',');
    if (value.upper) |bound| try atom(out, bound.value, subtype);
    try out.writeByte(if (value.upper != null and value.upper.?.inclusive) ']' else ')');
}
fn atom(out: *std.Io.Writer, value: t.Values.Atom, expected: t.Type) !void {
    switch (value) {
        inline .signed, .unsigned => |number| try out.print("{d}", .{number}),
        .float => |number| if (expected == .float32) try out.print("{d}", .{@as(f32, @floatCast(number))}) else try out.print("{d}", .{number}),
        .boolean => |boolean| try out.writeAll(if (boolean) "true" else "false"),
        .bytes => |bytes| if (expected == .binary) {
            try out.writeAll("0x");
            for (bytes) |byte| try out.print("{x:0>2}", .{byte});
        } else try std.json.Stringify.value(bytes, .{ .escape_unicode = true }, out),
        .decimal => |number| {
            var buffer: [40]u8 = undefined;
            const magnitude: u128 = @intCast(if (number < 0) -number else number);
            const digits = try std.fmt.bufPrint(&buffer, "{d}", .{magnitude});
            const scale = expected.decimal.scale;
            if (number < 0) try out.writeByte('-');
            if (scale == 0) return out.writeAll(digits);
            if (digits.len <= scale) {
                try out.writeAll("0.");
                try out.splatByteAll('0', scale - digits.len);
                try out.writeAll(digits);
            } else {
                try out.writeAll(digits[0 .. digits.len - scale]);
                try out.writeByte('.');
                try out.writeAll(digits[digits.len - scale ..]);
            }
        },
        .date => |days| try date(out, days),
        .time => |nanos| try time(out, nanos, 9),
        .timestamp => |micros| {
            try date(out, @divFloor(micros, 86400_000_000));
            try out.writeByte('T');
            try time(out, @as(u64, @intCast(@mod(micros, 86400_000_000))) * 1000, 6);
            if (expected.timestamp == .utc) try out.writeByte('Z');
        },
        .interval => |interval| try out.print("INTERVAL({d} months, {d} days, {d} ns)", .{ interval.months, interval.days, interval.nanos }),
        .uuid => |uuid| {
            const hex = std.fmt.bytesToHex(uuid, .lower);
            try out.print("{s}-{s}-{s}-{s}-{s}", .{ hex[0..8], hex[8..12], hex[12..16], hex[16..20], hex[20..32] });
        },
    }
}
fn date(out: *std.Io.Writer, days: i64) !void {
    const z = days + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const day = doy - @divFloor(153 * mp + 2, 5) + 1;
    const month = mp + @as(i64, if (mp < 10) 3 else -9);
    const year = yoe + era * 400 + @intFromBool(month <= 2);
    if (year < 0) try out.writeByte('-');
    try out.print("{d:0>4}-{d:0>2}-{d:0>2}", .{ @abs(year), @as(u64, @intCast(month)), @as(u64, @intCast(day)) });
}
fn time(out: *std.Io.Writer, nanos: u64, precision: u8) !void {
    const seconds = nanos / 1000_000_000;
    try out.print("{d:0>2}:{d:0>2}:{d:0>2}", .{ seconds / 3600, (seconds / 60) % 60, seconds % 60 });
    const fraction = nanos % 1000_000_000;
    if (fraction != 0) {
        var bytes: [9]u8 = undefined;
        _ = try std.fmt.bufPrint(&bytes, "{d:0>9}", .{fraction});
        try out.writeByte('.');
        try out.writeAll(bytes[0..precision]);
    }
}
pub fn preview(allocator: std.mem.Allocator, value: t.Values.Cell, expected: t.Type) ![]const u8 {
    var bytes: [256]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    cell(&out, value, expected) catch |err| {
        if (err != error.WriteFailed) return err;
        return std.fmt.allocPrint(allocator, "{s}... [truncated]", .{out.buffered()});
    };
    return allocator.dupe(u8, out.buffered());
}
test "logical display preserves exact decimals temporal values and terminal escaping" {
    const testing = std.testing;
    const cases = .{
        .{ "-0.0012", t.Type{ .decimal = .{ .precision = 10, .scale = 4 } }, t.Values.Atom{ .decimal = -12 } },
        .{ "2000-02-29", t.Type.date, t.Values.Atom{ .date = 11016 } },
        .{ "1969-12-31T23:59:59.999999Z", t.Type{ .timestamp = .utc }, t.Values.Atom{ .timestamp = -1 } },
        .{ "23:59:59.123456789", t.Type.time, t.Values.Atom{ .time = 86399_123456789 } },
        .{ "340282366920938463463374607431768211455", t.Type.uint128, t.Values.Atom{ .unsigned = std.math.maxInt(u128) } },
        .{ "\"\\u001b[31m\\n\"", t.Type.utf8, t.Values.Atom{ .bytes = "\x1b[31m\n" } },
    };
    inline for (cases) |example| {
        var bytes: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try atom(&out, example[2], example[1]);
        try testing.expectEqualStrings(example[0], out.buffered());
    }
}
