//! Canonical RANGE<T> and MULTIRANGE<T> intervals and Allen's interval algebra
//! over INT64, DECIMAL128, DATE32, TIMESTAMP, and TIMESTAMPTZ.
//! Discrete domains (INT64, DATE32) canonicalize closed/open bounds to [lower, upper).
const std = @import("std");

pub const Subtype = enum(u8) {
    int64 = 1,
    decimal128 = 2,
    date32 = 3,
    timestamp = 4,
    timestamptz = 5,

    pub fn isDiscrete(self: Subtype) bool {
        return switch (self) {
            .int64, .date32 => true,
            .decimal128, .timestamp, .timestamptz => false,
        };
    }
};

/// Generic canonical Range<T> for ordered scalar domains.
/// When `discrete` is true, non-empty finite bounds canonicalize to half-open `[lower, upper)`.
pub fn Range(comptime T: type, comptime discrete: bool) type {
    return struct {
        const Self = @This();

        pub const Bound = struct {
            value: T,
            inclusive: bool,
        };

        is_empty: bool = false,
        lower: ?Bound = null,
        upper: ?Bound = null,

        pub const empty: Self = .{ .is_empty = true, .lower = null, .upper = null };
        pub const unbounded: Self = .{ .is_empty = false, .lower = null, .upper = null };

        /// Construct and canonicalize a range from optional lower/upper bounds.
        pub fn init(lower: ?Bound, upper: ?Bound) !Self {
            var norm_lower = lower;
            var norm_upper = upper;

            if (discrete) {
                if (norm_lower) |lb| {
                    if (!lb.inclusive) {
                        const next = std.math.add(T, lb.value, 1) catch return error.RangeBoundOverflow;
                        norm_lower = .{ .value = next, .inclusive = true };
                    }
                }
                if (norm_upper) |ub| {
                    if (ub.inclusive) {
                        const next = std.math.add(T, ub.value, 1) catch return error.RangeBoundOverflow;
                        norm_upper = .{ .value = next, .inclusive = false };
                    }
                }
            }

            if (norm_lower) |lb| {
                if (norm_upper) |ub| {
                    const ord = std.math.order(lb.value, ub.value);
                    if (ord == .gt) return Self.empty;
                    if (ord == .eq and (!lb.inclusive or !ub.inclusive)) return Self.empty;
                }
            }

            return .{
                .is_empty = false,
                .lower = norm_lower,
                .upper = norm_upper,
            };
        }

        pub fn closed(lower_val: T, upper_val: T) !Self {
            return init(.{ .value = lower_val, .inclusive = true }, .{ .value = upper_val, .inclusive = true });
        }

        pub fn halfOpen(lower_val: T, upper_val: T) !Self {
            return init(.{ .value = lower_val, .inclusive = true }, .{ .value = upper_val, .inclusive = false });
        }

        pub fn eql(a: Self, b: Self) bool {
            if (a.is_empty and b.is_empty) return true;
            if (a.is_empty != b.is_empty) return false;
            return std.meta.eql(a.lower, b.lower) and std.meta.eql(a.upper, b.upper);
        }

        /// Compare two lower bounds in domain order (`-inf` < `[v` < `(v`).
        pub fn compareLower(a: ?Bound, b: ?Bound) std.math.Order {
            const la = a orelse return if (b == null) .eq else .lt;
            const lb = b orelse return .gt;
            const ord = std.math.order(la.value, lb.value);
            if (ord != .eq) return ord;
            if (la.inclusive == lb.inclusive) return .eq;
            return if (la.inclusive) .lt else .gt;
        }

        /// Compare two upper bounds in domain order (`v)` < `v]` < `+inf`).
        pub fn compareUpper(a: ?Bound, b: ?Bound) std.math.Order {
            const ua = a orelse return if (b == null) .eq else .gt;
            const ub = b orelse return .lt;
            const ord = std.math.order(ua.value, ub.value);
            if (ord != .eq) return ord;
            if (ua.inclusive == ub.inclusive) return .eq;
            return if (ua.inclusive) .gt else .lt;
        }

        /// Total order over canonical ranges (`empty` first, then lower bound, then upper bound).
        pub fn compare(a: Self, b: Self) std.math.Order {
            if (a.is_empty and b.is_empty) return .eq;
            if (a.is_empty) return .lt;
            if (b.is_empty) return .gt;
            const low_ord = compareLower(a.lower, b.lower);
            if (low_ord != .eq) return low_ord;
            return compareUpper(a.upper, b.upper);
        }

        /// True when `a`'s upper bound lies strictly to the left of `b`'s lower bound (`a << b`).
        pub fn strictlyLeft(a: Self, b: Self) bool {
            if (a.is_empty or b.is_empty) return false;
            const ua = a.upper orelse return false;
            const lb = b.lower orelse return false;
            const ord = std.math.order(ua.value, lb.value);
            if (ord == .lt) return true;
            if (ord == .gt) return false;
            return !ua.inclusive or !lb.inclusive;
        }

        /// True when `a`'s lower bound lies strictly to the right of `b`'s upper bound (`a >> b`).
        pub fn strictlyRight(a: Self, b: Self) bool {
            return strictlyLeft(b, a);
        }

        /// Allen's overlap predicate (`a && b`).
        pub fn overlaps(a: Self, b: Self) bool {
            if (a.is_empty or b.is_empty) return false;
            return !strictlyLeft(a, b) and !strictlyRight(a, b);
        }

        /// Point membership (`a @> elem`).
        pub fn containsElement(self: Self, elem: T) bool {
            if (self.is_empty) return false;
            if (self.lower) |lb| {
                const ord = std.math.order(elem, lb.value);
                if (ord == .lt or (ord == .eq and !lb.inclusive)) return false;
            }
            if (self.upper) |ub| {
                const ord = std.math.order(elem, ub.value);
                if (ord == .gt or (ord == .eq and !ub.inclusive)) return false;
            }
            return true;
        }

        /// Range containment (`self @> other`). Every range contains the empty range.
        pub fn containsRange(self: Self, other: Self) bool {
            if (other.is_empty) return true;
            if (self.is_empty) return false;
            return compareLower(self.lower, other.lower) != .gt and
                compareUpper(self.upper, other.upper) != .lt;
        }

        /// Inverse range containment (`self <@ container`).
        pub fn containedBy(self: Self, container: Self) bool {
            return container.containsRange(self);
        }

        /// Allen's adjacency / meets predicate (`a -|- b`): disjoint ranges with no element between them.
        pub fn adjacent(a: Self, b: Self) bool {
            if (a.is_empty or b.is_empty) return false;
            return meetsOrdered(a, b) or meetsOrdered(b, a);
        }

        fn meetsOrdered(left: Self, right: Self) bool {
            const ua = left.upper orelse return false;
            const lb = right.lower orelse return false;
            if (discrete) {
                // In canonical discrete [lower, upper) form, ua.inclusive == false and lb.inclusive == true.
                return !ua.inclusive and lb.inclusive and ua.value == lb.value;
            } else {
                return ua.value == lb.value and (ua.inclusive != lb.inclusive);
            }
        }

        /// Intersection (`a * b`).
        pub fn intersection(a: Self, b: Self) Self {
            if (!overlaps(a, b)) return Self.empty;
            const max_lower = if (compareLower(a.lower, b.lower) == .gt) a.lower else b.lower;
            const min_upper = if (compareUpper(a.upper, b.upper) == .lt) a.upper else b.upper;
            return .{
                .is_empty = false,
                .lower = max_lower,
                .upper = min_upper,
            };
        }

        /// Coalesce two overlapping or adjacent ranges into a single span (`a + b`).
        pub fn coalesce(a: Self, b: Self) ?Self {
            if (a.is_empty) return b;
            if (b.is_empty) return a;
            if (!overlaps(a, b) and !adjacent(a, b)) return null;
            const min_lower = if (compareLower(a.lower, b.lower) == .lt) a.lower else b.lower;
            const max_upper = if (compareUpper(a.upper, b.upper) == .gt) a.upper else b.upper;
            return .{
                .is_empty = false,
                .lower = min_lower,
                .upper = max_upper,
            };
        }
    };
}

pub const Int64Range = Range(i64, true);
pub const Date32Range = Range(i32, true);
pub const Decimal128Range = Range(i128, false);
pub const TimestampRange = Range(i64, false);

/// Generic canonical MultiRange over a Range type `R`: sorted, non-empty, disjoint, non-adjacent intervals.
pub fn MultiRange(comptime R: type) type {
    return struct {
        const Self = @This();
        pub const ElementRange = R;

        runs: []const R = &.{},

        /// Normalize an arbitrary slice of ranges into `out` buffer and return the canonical MultiRange.
        pub fn normalizeInto(inputs: []const R, scratch: []R) !Self {
            if (scratch.len < inputs.len) return error.MultiRangeBufferTooSmall;
            var count: usize = 0;
            for (inputs) |r| {
                if (!r.is_empty) {
                    scratch[count] = r;
                    count += 1;
                }
            }
            if (count == 0) return .{ .runs = &.{} };

            std.mem.sort(R, scratch[0..count], {}, struct {
                fn lessThan(_: void, a: R, b: R) bool {
                    return R.compare(a, b) == .lt;
                }
            }.lessThan);

            var write_idx: usize = 0;
            for (scratch[1..count]) |next_r| {
                if (R.coalesce(scratch[write_idx], next_r)) |merged| {
                    scratch[write_idx] = merged;
                } else {
                    write_idx += 1;
                    scratch[write_idx] = next_r;
                }
            }
            return .{ .runs = scratch[0 .. write_idx + 1] };
        }

        pub fn isEmpty(self: Self) bool {
            return self.runs.len == 0;
        }

        pub fn containsElement(self: Self, elem: @FieldType(R.Bound, "value")) bool {
            for (self.runs) |r| {
                if (r.containsElement(elem)) return true;
            }
            return false;
        }

        pub fn containsRange(self: Self, target: R) bool {
            if (target.is_empty) return true;
            for (self.runs) |r| {
                if (r.containsRange(target)) return true;
            }
            return false;
        }

        pub fn overlapsRange(self: Self, target: R) bool {
            if (target.is_empty) return false;
            for (self.runs) |r| {
                if (r.overlaps(target)) return true;
            }
            return false;
        }

        pub fn overlapsMultiRange(self: Self, other: Self) bool {
            var i: usize = 0;
            var j: usize = 0;
            while (i < self.runs.len and j < other.runs.len) {
                const a = self.runs[i];
                const b = other.runs[j];
                if (a.overlaps(b)) return true;
                if (R.strictlyLeft(a, b)) {
                    i += 1;
                } else {
                    j += 1;
                }
            }
            return false;
        }

        pub fn eql(a: Self, b: Self) bool {
            if (a.runs.len != b.runs.len) return false;
            for (a.runs, b.runs) |ra, rb| {
                if (!ra.eql(rb)) return false;
            }
            return true;
        }
    };
}

pub const Int64MultiRange = MultiRange(Int64Range);
pub const Date32MultiRange = MultiRange(Date32Range);
pub const Decimal128MultiRange = MultiRange(Decimal128Range);
pub const TimestampMultiRange = MultiRange(TimestampRange);
