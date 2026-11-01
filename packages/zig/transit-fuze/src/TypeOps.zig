//! Structural typed equality/hash and partial lexicographic ordering. These are
//! logical value traits, separate from SQL's missing/null predicate semantics.
const std = @import("std");
const t = @import("Types.zig");
const v = t.Values;
const Hash = std.crypto.hash.sha2.Sha256;
pub const Trait = enum { equality, ordering };
pub fn supports(descriptor: t.Type, trait: Trait) !bool {
    try descriptor.validate(.{});
    return supported(descriptor, trait);
}
fn supported(descriptor: t.Type, trait: Trait) bool {
    return switch (descriptor) {
        .json => false,
        .interval => trait == .equality,
        .map => |map| trait == .equality and supported(map.key.*, trait) and supported(map.value.type.*, trait),
        .structure, .tagged_union => |fields| blk: {
            for (fields) |field| if (!supported(field.type, trait)) break :blk false;
            break :blk true;
        },
        .list => |element| supported(element.type.*, trait),
        .array => |array| supported(array.element.type.*, trait),
        else => true,
    };
}
fn inspect(cell: v.Cell, trait: Trait) anyerror!void {
    switch (cell) {
        .type_error => return error.QueryTypeError,
        .conflict => return error.QueryConflict,
        .missing, .null => if (trait == .ordering) return error.UnorderedCell,
        .value => |value| switch (value) {
            .structure, .list, .array => |cells| for (cells) |child| try inspect(child, trait),
            .map => |entries| for (entries) |entry| try inspect(entry.value, trait),
            .tagged_union => |union_value| try inspect(union_value.value.*, trait),
            else => {},
        },
    }
}
fn validate(field: t.Field, cell: v.Cell, trait: Trait) !void {
    try cell.validate(field, .{});
    if (!supported(field.type, trait)) return error.UnsupportedTypeTrait;
    // Inspect every active child before comparison; a short-circuit inequality
    // cannot conceal an error/conflict or make a non-comparable value ordered.
    try inspect(cell, trait);
}
pub fn eql(field: t.Field, left: v.Cell, right: v.Cell) !bool {
    try validate(field, left, .equality);
    try validate(field, right, .equality);
    return equalCell(field.type, left, right);
}
pub fn order(field: t.Field, left: v.Cell, right: v.Cell) !std.math.Order {
    try validate(field, left, .ordering);
    try validate(field, right, .ordering);
    return ordered(field.type, left.value, right.value);
}
fn equalCell(descriptor: t.Type, left: v.Cell, right: v.Cell) anyerror!bool {
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
    return switch (left) {
        .missing, .null => true,
        .value => |value| switch (value) {
            .atom => |atom| if (descriptor == .interval) std.meta.eql(atom.interval, right.value.atom.interval) else try v.atomOrder(atom, right.value.atom, descriptor) == .eq,
            .range, .multirange, .vector => try ordered(descriptor, value, right.value) == .eq,
            .structure => |cells| blk: {
                for (cells, right.value.structure, descriptor.structure) |a, b, field| if (!try equalCell(field.type, a, b)) break :blk false;
                break :blk true;
            },
            .list, .array => |cells| blk: {
                const other = if (value == .list) right.value.list else right.value.array;
                if (cells.len != other.len) break :blk false;
                const child = if (descriptor == .list) descriptor.list.type else descriptor.array.element.type;
                for (cells, other) |a, b| if (!try equalCell(child.*, a, b)) break :blk false;
                break :blk true;
            },
            .map => |entries| blk: {
                if (entries.len != right.value.map.len) break :blk false;
                for (entries, right.value.map) |a, b| {
                    if (try v.atomOrder(a.key, b.key, descriptor.map.key.*) != .eq or !try equalCell(descriptor.map.value.type.*, a.value, b.value)) break :blk false;
                }
                break :blk true;
            },
            .tagged_union => |tagged| tagged.index == right.value.tagged_union.index and try equalCell(descriptor.tagged_union[tagged.index].type, tagged.value.*, right.value.tagged_union.value.*),
            .json => unreachable,
        },
        .type_error, .conflict => unreachable,
    };
}
fn ordered(descriptor: t.Type, left: v.Value, right: v.Value) anyerror!std.math.Order {
    return switch (left) {
        .atom => |atom| v.atomOrder(atom, right.atom, descriptor),
        .range => |range| t.Ranges.order(descriptor.range.*, range, right.range),
        .multirange => |ranges| blk: {
            const count = @min(ranges.len, right.multirange.len);
            for (ranges[0..count], right.multirange[0..count]) |a, b| {
                const comparison = try t.Ranges.order(descriptor.multirange.*, a, b);
                if (comparison != .eq) break :blk comparison;
            }
            break :blk std.math.order(ranges.len, right.multirange.len);
        },
        .vector => |bytes| t.Vectors.order(descriptor.vector, bytes, right.vector),
        .structure => |cells| blk: {
            for (cells, right.structure, descriptor.structure) |a, b, field| {
                const comparison = try ordered(field.type, a.value, b.value);
                if (comparison != .eq) break :blk comparison;
            }
            break :blk .eq;
        },
        .list, .array => |cells| blk: {
            const other = if (left == .list) right.list else right.array;
            const child = if (descriptor == .list) descriptor.list.type else descriptor.array.element.type;
            const count = @min(cells.len, other.len);
            for (cells[0..count], other[0..count]) |a, b| {
                const comparison = try ordered(child.*, a.value, b.value);
                if (comparison != .eq) break :blk comparison;
            }
            break :blk std.math.order(cells.len, other.len);
        },
        .tagged_union => |tagged| if (tagged.index != right.tagged_union.index) std.math.order(tagged.index, right.tagged_union.index) else ordered(descriptor.tagged_union[tagged.index].type, tagged.value.value, right.tagged_union.value.value),
        .json, .map => unreachable,
    };
}
/// Hashes logical meaning, including type/field flags and structural cell state.
/// Signed zero normalizes for equality; the exact value codecs still preserve it.
pub fn hash(field: t.Field, cell: v.Cell) ![32]u8 {
    try validate(field, cell, .equality);
    var hasher = Hash.init(.{});
    hasher.update("transit.fuze.structural-hash.v1\x00");
    hasher.update(&try field.type.fingerprint());
    hasher.update(&.{ @intFromBool(field.nullable), @intFromBool(field.optional) });
    hashCell(&hasher, field.type, cell);
    return hasher.finalResult();
}
fn number(hasher: *Hash, value: anytype) void {
    var bytes: [@sizeOf(@TypeOf(value))]u8 = undefined;
    std.mem.writeInt(@TypeOf(value), &bytes, value, .little);
    hasher.update(&bytes);
}
fn bytesHash(hasher: *Hash, bytes: []const u8) void {
    number(hasher, @as(u64, @intCast(bytes.len)));
    hasher.update(bytes);
}
fn hashAtom(hasher: *Hash, atom: t.Semantics.Atom) void {
    switch (atom) {
        .signed => |value| number(hasher, value),
        .unsigned => |value| number(hasher, value),
        .decimal => |value| number(hasher, value),
        .float => |value| number(hasher, @as(u64, @bitCast(if (value == 0) @as(f64, 0) else value))),
        .boolean => |value| hasher.update(&.{@intFromBool(value)}),
        .bytes => |value| bytesHash(hasher, value),
        .date => |value| number(hasher, value),
        .time => |value| number(hasher, value),
        .timestamp => |value| number(hasher, value),
        .interval => |value| {
            number(hasher, value.months);
            number(hasher, value.days);
            number(hasher, value.nanos);
        },
        .uuid => |value| hasher.update(&value),
    }
}
fn hashRange(hasher: *Hash, range: t.Ranges.Value) void {
    hasher.update(&.{@intFromBool(range.is_empty)});
    for ([_]?t.Ranges.Bound{ range.lower, range.upper }) |bound| {
        hasher.update(&.{@intFromBool(bound != null)});
        if (bound) |value| {
            hasher.update(&.{@intFromBool(value.inclusive)});
            hashAtom(hasher, value.value);
        }
    }
}
fn hashCell(hasher: *Hash, descriptor: t.Type, cell: v.Cell) void {
    hasher.update(&.{@backingInt(std.meta.activeTag(cell))});
    switch (cell) {
        .value => |value| switch (value) {
            .atom => |atom| hashAtom(hasher, atom),
            .range => |range| hashRange(hasher, range),
            .multirange => |ranges| {
                number(hasher, @as(u64, @intCast(ranges.len)));
                for (ranges) |range| hashRange(hasher, range);
            },
            .vector => |bytes| t.Vectors.hashValidated(hasher, descriptor.vector, bytes),
            .structure => |cells| {
                number(hasher, @as(u64, @intCast(cells.len)));
                for (cells, descriptor.structure) |child, field| hashCell(hasher, field.type, child);
            },
            .list, .array => |cells| {
                number(hasher, @as(u64, @intCast(cells.len)));
                const child_type = if (descriptor == .list) descriptor.list.type else descriptor.array.element.type;
                for (cells) |child| hashCell(hasher, child_type.*, child);
            },
            .map => |entries| {
                number(hasher, @as(u64, @intCast(entries.len)));
                for (entries) |entry| {
                    hashAtom(hasher, entry.key);
                    hashCell(hasher, descriptor.map.value.type.*, entry.value);
                }
            },
            .tagged_union => |tagged| {
                hasher.update(&.{tagged.index});
                hashCell(hasher, descriptor.tagged_union[tagged.index].type, tagged.value.*);
            },
            .json => unreachable,
        },
        .missing, .null => {},
        .type_error, .conflict => unreachable,
    }
}
test "structural traits preserve states and normalize only equal floating zeros" {
    const test_alloc = std.testing;
    const field: t.Field = .{ .name = "value", .type = .{ .structure = &.{ .{ .name = "float", .type = .float32 }, .{ .name = "x", .type = .int128, .nullable = true, .optional = true } } } };
    const first: v.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .float = -0.0 } } }, .missing } } };
    const second: v.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .float = 0.0 } } }, .missing } } };
    const third: v.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .float = 0.0 } } }, .null } } };
    try test_alloc.expect(try eql(field, first, second));
    try test_alloc.expectEqual(try hash(field, first), try hash(field, second));
    try test_alloc.expect(!try eql(field, first, third));
    try test_alloc.expect(!std.mem.eql(u8, &try hash(field, first), &try hash(field, third)));
    try test_alloc.expectError(error.UnorderedCell, order(field, first, second));
    try test_alloc.expect(!try supports(.json, .equality));
    try test_alloc.expect(!try supports(.interval, .ordering));
    const error_value: v.Cell = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .float = 9 } } }, .{ .type_error = .utf8 } } } };
    try test_alloc.expectError(error.QueryTypeError, eql(field, first, error_value));
    try test_alloc.expectError(error.QueryTypeError, hash(field, error_value));
    const conflict: v.Cell = .{ .conflict = &.{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .atom = .{ .signed = 1 } } } },
        .{ .counter = 2, .replica = 1, .value = .null },
    } };
    const scalar: t.Field = .{ .name = "x", .type = .int64, .nullable = true };
    try test_alloc.expectError(error.QueryConflict, eql(scalar, .null, conflict));
    try test_alloc.expectError(error.QueryConflict, hash(scalar, conflict));
}
test "recursive ordering and map equality use exact typed keys" {
    const testing = std.testing;
    const field: t.Field = .{ .name = "values", .type = .{ .list = .{ .type = &.uint128 } } };
    const first: v.Cell = .{ .value = .{ .list = &.{.{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) - 1 } } }} } };
    const second: v.Cell = .{ .value = .{ .list = &.{.{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u128) } } }} } };
    try testing.expectEqual(.lt, try order(field, first, second));
    const map_field: t.Field = .{ .name = "map", .type = .{ .map = .{ .key = &.int64, .value = .{ .type = &.utf8, .nullable = true } } } };
    const map: v.Cell = .{ .value = .{ .map = &.{.{ .key = .{ .signed = -1 }, .value = .null }} } };
    try testing.expect(try eql(map_field, map, map));
    try testing.expectError(error.UnsupportedTypeTrait, order(map_field, map, map));
    _ = try hash(map_field, map);
}
