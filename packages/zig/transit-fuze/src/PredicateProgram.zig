//! Bounded, pure Boolean composition over the existing typed predicate atoms.
//! Instructions and literal bytes borrow caller storage and must stay immutable
//! during use. This component does not yet extend SQL or the FZP1 plan codec.
const m = @import("Unified.zig");
const Self = @This();

/// Limits expression work, never retained source or result cardinality.
pub const max_instructions = 64;
pub const Instruction = union(enum) {
    atom: m.Plan.Predicate,
    negate,
    conjunction,
    disjunction,
};
instructions: []const Instruction,

/// A postfix program must consume all its instructions into exactly one value.
/// No references, jumps, recursion or shared subexpressions can amplify work.
pub fn validateShape(self: Self) !void {
    if (self.instructions.len == 0) return error.InvalidPredicateProgram;
    if (self.instructions.len > max_instructions) return error.PredicateTooLarge;
    var depth: usize = 0;
    for (self.instructions) |instruction| switch (instruction) {
        .atom => depth += 1,
        .negate => if (depth == 0) return error.InvalidPredicateProgram,
        .conjunction, .disjunction => {
            if (depth < 2) return error.InvalidPredicateProgram;
            depth -= 1;
        },
    };
    if (depth != 1) return error.InvalidPredicateProgram;
}

/// Validate every atom before reading source rows, including those combined
/// with a truth value that would determine the result without the other side.
pub fn validate(self: Self, schema: m.Schema) !void {
    try schema.validate();
    try self.validateShape();
    for (self.instructions) |instruction| switch (instruction) {
        .atom => |atom| try atom.validate(schema),
        else => {},
    };
}

/// Evaluate atoms eagerly in instruction order and return the first error.
/// Boolean identities never skip a comparison or hide an evaluated error.
/// The caller validates against its schema before processing source rows.
pub fn truth(self: Self, row: m.Row) !m.Truth {
    try self.validateShape();
    var stack: [max_instructions]m.Truth = undefined;
    var depth: usize = 0;
    for (self.instructions) |instruction| switch (instruction) {
        .atom => |atom| {
            stack[depth] = try atom.truth(row);
            depth += 1;
        },
        .negate => stack[depth - 1] = stack[depth - 1].negate(),
        .conjunction, .disjunction => {
            const right = stack[depth - 1];
            depth -= 1;
            stack[depth - 1] = if (instruction == .conjunction)
                stack[depth - 1].conjunction(right)
            else
                stack[depth - 1].disjunction(right);
        },
    };
    return stack[0];
}

pub fn matches(self: Self, row: m.Row) !bool {
    return (try self.truth(row)).selects();
}

test {
    _ = @import("predicate_program_test.zig");
}
