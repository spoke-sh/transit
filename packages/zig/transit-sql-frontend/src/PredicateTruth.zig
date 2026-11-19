//! Truth values for predicate composition. Null/missing comparisons stay
//! unknown until the final filter decision. No allocation, I/O or cell coercion.
const std = @import("std");

pub const Truth = enum(u8) {
    true_value,
    false_value,
    unknown,

    pub fn fromBool(value: bool) Truth {
        return if (value) .true_value else .false_value;
    }
    pub fn selects(self: Truth) bool {
        return self == .true_value;
    }
    pub fn negate(self: Truth) Truth {
        return switch (self) {
            .true_value => .false_value,
            .false_value => .true_value,
            .unknown => .unknown,
        };
    }
    // These combine already evaluated operands. They do not choose evaluation
    // order, suppress errors, or authorize an expression rewrite.
    pub fn conjunction(self: Truth, other: Truth) Truth {
        if (self == .false_value or other == .false_value) return .false_value;
        if (self == .unknown or other == .unknown) return .unknown;
        return .true_value;
    }
    pub fn disjunction(self: Truth, other: Truth) Truth {
        if (self == .true_value or other == .true_value) return .true_value;
        if (self == .unknown or other == .unknown) return .unknown;
        return .false_value;
    }
};

test "predicate truth preserves unknown under negation and combines all truth pairs" {
    // Explicit tables follow PostgreSQL 18 logical operators. Transit also
    // maps a missing comparison operand to unknown; errors are separate.
    // https://www.postgresql.org/docs/18/functions-logical.html
    const t = std.testing;
    const yes = Truth.true_value;
    const no = Truth.false_value;
    const unknown = Truth.unknown;
    const values = [_]Truth{ yes, no, unknown };
    const negative = [_]Truth{ no, yes, unknown };
    const conjunction = [_][3]Truth{
        .{ yes, no, unknown },
        .{ no, no, no },
        .{ unknown, no, unknown },
    };
    const disjunction = [_][3]Truth{
        .{ yes, yes, yes },
        .{ yes, no, unknown },
        .{ yes, unknown, unknown },
    };
    for (values, 0..) |left, i| {
        try t.expectEqual(negative[i], left.negate());
        try t.expectEqual(i == 0, left.selects());
        for (values, 0..) |right, j| {
            try t.expectEqual(conjunction[i][j], left.conjunction(right));
            try t.expectEqual(disjunction[i][j], left.disjunction(right));
        }
    }
}
