//! Schema-bound range values. Bounds are typed atoms, never recursive cells;
//! missing/null/error/conflict belong to the enclosing logical cell.
const std = @import("std");
const t = @import("Types.zig");
const intervals = @import("Range.zig");
pub const Bound = struct { value: t.Semantics.Atom, inclusive: bool };
pub const Value = struct {
    is_empty: bool = false,
    lower: ?Bound = null,
    upper: ?Bound = null,
};

pub fn validateSubtype(subtype: t.Type) !void {
    switch (subtype) {
        .int64, .decimal, .date, .timestamp => try subtype.validate(.{}),
        else => return error.UnsupportedRangeSubtype,
    }
}
fn discrete(subtype: t.Type) bool {
    return subtype == .int64 or subtype == .date;
}
fn coefficient(subtype: t.Type, atom: t.Semantics.Atom) !i128 {
    try t.Semantics.validate(atom, subtype);
    return switch (atom) {
        .signed, .decimal, .date, .timestamp => |value| value,
        else => return error.UnsupportedRangeSubtype,
    };
}
fn atomFromCoefficient(subtype: t.Type, number: i128) !t.Semantics.Atom {
    const atom: t.Semantics.Atom = switch (subtype) {
        .int64 => .{ .signed = std.math.cast(i64, number) orelse return error.RangeBoundOverflow },
        .date => .{ .date = std.math.cast(i32, number) orelse return error.RangeBoundOverflow },
        .decimal => .{ .decimal = number },
        .timestamp => .{ .timestamp = std.math.cast(i64, number) orelse return error.RangeBoundOverflow },
        else => return error.UnsupportedRangeSubtype,
    };
    try t.Semantics.validate(atom, subtype);
    return atom;
}
fn Native(comptime is_discrete: bool) type {
    return intervals.Range(i128, is_discrete);
}
fn native(comptime is_discrete: bool, subtype: t.Type, value: Value) !Native(is_discrete) {
    try validateSubtype(subtype);
    if (value.is_empty) {
        if (value.lower != null or value.upper != null) return error.InvalidRangeValue;
        return .empty;
    }
    return .{
        .lower = if (value.lower) |bound| .{ .value = try coefficient(subtype, bound.value), .inclusive = bound.inclusive } else null,
        .upper = if (value.upper) |bound| .{ .value = try coefficient(subtype, bound.value), .inclusive = bound.inclusive } else null,
    };
}
fn logical(subtype: t.Type, value: anytype) !Value {
    return .{
        .is_empty = value.is_empty,
        .lower = if (value.lower) |bound| .{ .value = try atomFromCoefficient(subtype, bound.value), .inclusive = bound.inclusive } else null,
        .upper = if (value.upper) |bound| .{ .value = try atomFromCoefficient(subtype, bound.value), .inclusive = bound.inclusive } else null,
    };
}
fn canonicalFor(comptime is_discrete: bool, subtype: t.Type, value: Value) !Value {
    const input = try native(is_discrete, subtype, value);
    if (input.is_empty) return .{ .is_empty = true };
    // Validate shifted discrete endpoints before empty-range reduction. An
    // unrepresentable successor must not silently become empty or unbounded.
    if (is_discrete) {
        if (input.lower) |bound| if (!bound.inclusive) {
            _ = try atomFromCoefficient(subtype, try std.math.add(i128, bound.value, 1));
        };
        if (input.upper) |bound| if (bound.inclusive) {
            _ = try atomFromCoefficient(subtype, try std.math.add(i128, bound.value, 1));
        };
    }
    return logical(subtype, try Native(is_discrete).init(input.lower, input.upper));
}
pub fn canonical(subtype: t.Type, value: Value) !Value {
    return if (discrete(subtype)) canonicalFor(true, subtype, value) else canonicalFor(false, subtype, value);
}
pub fn validate(subtype: t.Type, value: Value) !void {
    const normalized = try canonical(subtype, value);
    // Only fixed-width scalar atoms are admitted here; no borrowed bytes occur.
    if (!std.meta.eql(value, normalized)) return error.NonCanonicalRange;
}
pub fn order(subtype: t.Type, left: Value, right: Value) !std.math.Order {
    try validate(subtype, left);
    try validate(subtype, right);
    return Native(false).compare(try native(false, subtype, left), try native(false, subtype, right));
}
pub const Predicate = enum { overlaps, contains, adjacent };
pub fn evaluate(subtype: t.Type, predicate: Predicate, left: Value, right: Value) !bool {
    try validate(subtype, left);
    try validate(subtype, right);
    const a = try native(false, subtype, left);
    const b = try native(false, subtype, right);
    return switch (predicate) {
        .overlaps => Native(false).overlaps(a, b),
        .contains => a.containsRange(b),
        // Canonical discrete ranges have complementary endpoint inclusivity,
        // so the continuous adjacency rule is identical on their representation.
        .adjacent => Native(false).adjacent(a, b),
    };
}
pub fn validateMulti(subtype: t.Type, runs: []const Value) !void {
    try validateSubtype(subtype);
    if (runs.len > (t.Limits{}).children) return error.ValueBudgetExceeded;
    for (runs, 0..) |run, i| {
        try validate(subtype, run);
        if (run.is_empty) return error.NonCanonicalMultiRange;
        if (i != 0) {
            const before = try native(false, subtype, runs[i - 1]);
            const after = try native(false, subtype, run);
            if (Native(false).compare(before, after) != .lt or Native(false).coalesce(before, after) != null) return error.NonCanonicalMultiRange;
        }
    }
}
/// Normalize into caller-owned reusable scratch/output. No allocation occurs.
pub fn normalizeMulti(subtype: t.Type, inputs: []const Value, output: []Value) ![]const Value {
    try validateSubtype(subtype);
    if (inputs.len > (t.Limits{}).children) return error.ValueBudgetExceeded;
    if (output.len < inputs.len) return error.MultiRangeBufferTooSmall;
    var count: usize = 0;
    for (inputs) |input| {
        const run = try canonical(subtype, input);
        if (!run.is_empty) {
            output[count] = run;
            count += 1;
        }
    }
    std.mem.sort(Value, output[0..count], subtype, struct {
        fn lessThan(element: t.Type, left: Value, right: Value) bool {
            // All values were validated before sorting; no fallible conversion
            // or allocation is hidden inside the comparison hot path.
            return Native(false).compare(native(false, element, left) catch unreachable, native(false, element, right) catch unreachable) == .lt;
        }
    }.lessThan);
    if (count == 0) return output[0..0];
    var last: usize = 0;
    for (output[1..count]) |next| {
        if (Native(false).coalesce(try native(false, subtype, output[last]), try native(false, subtype, next))) |merged| {
            output[last] = try logical(subtype, merged);
        } else {
            last += 1;
            output[last] = next;
        }
    }
    return output[0 .. last + 1];
}

test "schema-bound ranges preserve continuous inclusivity and reject discrete overflow" {
    const testing = std.testing;
    const closed: Value = .{ .lower = .{ .value = .{ .signed = 1 }, .inclusive = true }, .upper = .{ .value = .{ .signed = 3 }, .inclusive = true } };
    const normalized = try canonical(.int64, closed);
    try testing.expectEqual(@as(i128, 4), normalized.upper.?.value.signed);
    try testing.expect(!normalized.upper.?.inclusive);
    try testing.expectError(error.NonCanonicalRange, validate(.int64, closed));
    try validate(.int64, normalized);
    try testing.expectError(error.RangeBoundOverflow, canonical(.int64, .{ .upper = .{ .value = .{ .signed = std.math.maxInt(i64) }, .inclusive = true } }));
    try testing.expectError(error.RangeBoundOverflow, canonical(.date, .{ .lower = .{ .value = .{ .date = std.math.maxInt(i32) }, .inclusive = false } }));
    const decimal: Value = .{ .lower = .{ .value = .{ .decimal = 123 }, .inclusive = false }, .upper = .{ .value = .{ .decimal = 234 }, .inclusive = true } };
    try testing.expectEqualDeep(decimal, try canonical(.{ .decimal = .{ .precision = 4, .scale = 2 } }, decimal));
    try testing.expectError(error.TypeMismatch, validate(.int64, decimal));
    const next: Value = .{ .lower = .{ .value = normalized.upper.?.value, .inclusive = true }, .upper = null };
    var output: [3]Value = undefined;
    const runs = try normalizeMulti(.int64, &.{ next, .{ .is_empty = true }, normalized }, &output);
    try testing.expectEqual(@as(usize, 1), runs.len);
    try testing.expect(runs[0].upper == null);
    try validateMulti(.int64, runs);
    try testing.expectError(error.NonCanonicalMultiRange, validateMulti(.int64, &.{ normalized, normalized }));
}
