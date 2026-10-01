//! Pure bounded postfix evaluation shared by native and logical file plans.
//! Atoms own type admission and row access; this machine owns shape, truth
//! composition and eager first-error order. No allocation, recursion or I/O.
const Truth = @import("PredicateTruth.zig").Truth;
pub const max_instructions = 64;

pub fn Instruction(comptime Atom: type) type {
    return union(enum) { atom: Atom, negate, conjunction, disjunction };
}

pub fn validateShape(instructions: anytype) !void {
    if (instructions.len == 0) return error.InvalidPredicateProgram;
    if (instructions.len > max_instructions) return error.PredicateTooLarge;
    var depth: usize = 0;
    for (instructions) |instruction| switch (instruction) {
        .atom => |atom| {
            try atom.validateShape();
            depth += 1;
        },
        .negate => if (depth == 0) return error.InvalidPredicateProgram,
        .conjunction, .disjunction => {
            if (depth < 2) return error.InvalidPredicateProgram;
            depth -= 1;
        },
    };
    if (depth != 1) return error.InvalidPredicateProgram;
}

/// Schema admission precedes row processing in each owning plan profile.
/// Recheck shape before stack access even for callers evaluating directly.
pub fn truth(instructions: anytype, row: anytype) !Truth {
    try validateShape(instructions);
    var stack: [max_instructions]Truth = undefined;
    var depth: usize = 0;
    for (instructions) |instruction| switch (instruction) {
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
