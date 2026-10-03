//! Bounded, pure Boolean composition over the existing typed predicate atoms.
//! Instructions and literal bytes borrow caller storage and must stay immutable
//! during use. Owned stores instructions inline; literal bytes remain borrowed.
const m = @import("Unified.zig");
const Self = @This();
const machine = @import("PredicateMachine.zig");

/// Limits expression work, never retained source or result cardinality.
pub const max_instructions = machine.max_instructions;
pub const Instruction = machine.Instruction(m.Plan.Atom);
instructions: []const Instruction,

/// Copyable instruction ownership for allocator-free saved-plan decoding.
/// No slice points into this value until view() borrows its final address.
/// Scalar text/binary storage still belongs to the caller or encoded plan.
pub const Owned = struct {
    instructions: [max_instructions]Instruction = @splat(.negate),
    count: u8 = 0,

    pub fn init(instructions: []const Instruction) !Owned {
        try (Self{ .instructions = instructions }).validateShape();
        var result: Owned = .{ .count = @intCast(instructions.len) };
        @memcpy(result.instructions[0..instructions.len], instructions);
        return result;
    }
    pub fn view(self: *const Owned) !Self {
        if (self.count == 0) return error.InvalidPredicateProgram;
        if (self.count > max_instructions) return error.PredicateTooLarge;
        return .{ .instructions = self.instructions[0..self.count] };
    }
};

/// A postfix program must consume all its instructions into exactly one value.
/// No references, jumps, recursion or shared subexpressions can amplify work.
pub fn validateShape(self: Self) !void {
    try machine.validateShape(self.instructions);
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
    return machine.truth(self.instructions, row);
}
pub fn truthDiagnostic(self: Self, row: m.Row, instruction: ?*?u8) !m.Truth {
    return machine.truthDiagnostic(self.instructions, row, instruction);
}

pub fn matches(self: Self, row: m.Row) !bool {
    return (try self.truth(row)).selects();
}

test {
    _ = @import("predicate_program_test.zig");
}
