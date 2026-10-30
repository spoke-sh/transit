const std = @import("std");
const t = std.testing;
const r = @import("LogPartitionRecord.zig");

// Conservative schema bound for the ordinary reflected JSON writer. Refuse
// variable-length or custom representations rather than guessing their size.
fn maximum(comptime T: type) usize {
    return switch (@typeInfo(T)) {
        .void => 2,
        .bool => 5,
        .int => |info| blk: {
            var magnitude: u128 = if (info.signedness == .signed) @as(u128, 1) << (info.bits - 1) else std.math.maxInt(T);
            var size: usize = @as(usize, 1) + @intFromBool(info.signedness == .signed);
            while (magnitude >= 10) : (magnitude /= 10) size += 1;
            break :blk size;
        },
        .optional => |info| @max(4, maximum(info.child)),
        .array => |info| 2 + info.len * maximum(info.child) + info.len - @intFromBool(info.len != 0),
        .@"enum" => |info| blk: {
            var size: usize = 0;
            for (info.field_names) |name| size = @max(size, quoted(name));
            break :blk size;
        },
        .@"struct" => |info| blk: {
            if (@hasDecl(T, "jsonStringify") or info.is_tuple) @compileError("explicit JSON bound required for " ++ @typeName(T));
            var size: usize = 2;
            for (info.field_names, info.field_types, 0..) |name, Field, i| size += quoted(name) + 1 + maximum(Field) + @intFromBool(i != 0);
            break :blk size;
        },
        .@"union" => |info| blk: {
            var size: usize = 0;
            for (info.field_names, info.field_types) |name, Field| size = @max(size, 2 + quoted(name) + 1 + maximum(Field));
            break :blk size;
        },
        else => @compileError("unbounded JSON metadata field: " ++ @typeName(T)),
    };
}
fn quoted(comptime name: []const u8) usize {
    for (name) |byte| if (byte < 32 or byte > 126 or byte == '"' or byte == '\\') @compileError("escaped field/tag name needs an explicit bound");
    return name.len + 2;
}

test "queue record full width fields and two complete merge states fit the metadata limit" {
    const bytes = comptime blk: {
        @setEvalBranchQuota(100000);
        var root: usize = 2;
        const info = @typeInfo(r.Root).@"struct";
        for (info.field_names, info.field_types, 0..) |name, Field, i| {
            // Queue Root.validate forbids Stream-only compaction/read state.
            const stream_only = std.mem.eql(u8, name, "compaction") or std.mem.eql(u8, name, "compacted") or
                std.mem.eql(u8, name, "groups") or std.mem.eql(u8, name, "group_offsets") or std.mem.eql(u8, name, "pins");
            root += quoted(name) + 1 + (if (stream_only) 4 else maximum(Field)) + @intFromBool(i != 0);
        }
        var record: usize = 2;
        const fields = @typeInfo(r.Record).@"struct";
        for (fields.field_names, fields.field_types, 0..) |name, Field, i| record += quoted(name) + 1 +
            (if (std.mem.eql(u8, name, "root")) root else maximum(Field)) + @intFromBool(i != 0);
        break :blk record;
    };
    try t.expect(bytes <= r.max_metadata_bytes);
    std.debug.print("Queue WAL metadata: conservative full-width bound {d}/{d} bytes.\n", .{ bytes, r.max_metadata_bytes });
}
