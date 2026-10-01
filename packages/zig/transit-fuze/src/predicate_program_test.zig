const std = @import("std");
const t = std.testing;
const m = @import("Unified.zig");
const Program = m.PredicateProgram;
const Instruction = Program.Instruction;
const columns = [_]m.Column{
    .{ .name = m.Name.init("a") catch unreachable, .type = .boolean },
    .{ .name = m.Name.init("b") catch unreachable, .type = .boolean },
    .{ .name = m.Name.init("c") catch unreachable, .type = .boolean },
};
const schema: m.Schema = .{ .columns = &columns };
const cells = [_]m.Cell{ .{ .value = .{ .boolean = true } }, .{ .value = .{ .boolean = false } }, .null, .missing };

fn atom(column: u8) Instruction {
    return .{ .atom = .{ .compare = .{ .column = column, .op = .eq, .value = .{ .boolean = true } } } };
}

test "bounded Boolean programs preserve null and missing through nested composition" {
    const yes = m.Truth.true_value;
    const no = m.Truth.false_value;
    const unknown = m.Truth.unknown;
    // Independent four-cell tables; null and missing each exercise unknown.
    const both = [4][4]m.Truth{
        .{ yes, no, unknown, unknown },
        .{ no, no, no, no },
        .{ unknown, no, unknown, unknown },
        .{ unknown, no, unknown, unknown },
    };
    const either = [4][4]m.Truth{
        .{ yes, yes, yes, yes },
        .{ yes, no, unknown, unknown },
        .{ yes, unknown, unknown, unknown },
        .{ yes, unknown, unknown, unknown },
    };
    const and_program: Program = .{ .instructions = &.{ atom(0), atom(1), .conjunction } };
    const or_program: Program = .{ .instructions = &.{ atom(0), atom(1), .disjunction } };
    // (a OR b) AND NOT c. Expected values use only the literal tables above.
    const nested: Program = .{ .instructions = &.{ atom(0), atom(1), .disjunction, atom(2), .negate, .conjunction } };
    for ([_]Program{ and_program, or_program, nested }) |program| try program.validate(schema);
    for (cells, 0..) |a, i| for (cells, 0..) |b, j| {
        const pair: m.Row = .{ .cells = &.{ a, b, .null } };
        try t.expectEqual(both[i][j], try and_program.truth(pair));
        try t.expectEqual(either[i][j], try or_program.truth(pair));
        for (cells, 0..) |c, k| {
            const row: m.Row = .{ .cells = &.{ a, b, c } };
            const left: usize = switch (either[i][j]) {
                .true_value => 0,
                .false_value => 1,
                .unknown => 2,
            };
            const negated = [_]usize{ 1, 0, 2, 3 };
            const expected = both[left][negated[k]];
            try t.expectEqual(expected, try nested.truth(row));
            try t.expectEqual(expected == yes, try nested.matches(row));
        }
    };
}

test "Boolean program shape rejects underflow trailing roots and work beyond its bound" {
    const malformed = [_][]const Instruction{
        &.{},
        &.{.negate},
        &.{.conjunction},
        &.{ atom(0), .disjunction },
        &.{ atom(0), atom(1) },
        &.{ atom(0), atom(1), .conjunction, .conjunction },
    };
    for (malformed) |instructions| {
        const program: Program = .{ .instructions = instructions };
        try t.expectError(error.InvalidPredicateProgram, program.validate(schema));
        try t.expectError(error.InvalidPredicateProgram, program.truth(.{ .cells = &.{.{ .type_error = .map }} }));
    }
    var instructions: [Program.max_instructions + 1]Instruction = @splat(.negate);
    instructions[0] = atom(0);
    const at_limit: Program = .{ .instructions = instructions[0..Program.max_instructions] };
    try at_limit.validate(schema);
    try t.expectEqual(m.Truth.false_value, try at_limit.truth(.{ .cells = &.{cells[0]} }));
    const too_large: Program = .{ .instructions = &instructions };
    try t.expectError(error.PredicateTooLarge, too_large.validate(schema));
    try t.expectError(error.PredicateTooLarge, too_large.truth(.{ .cells = &.{cells[0]} }));

    // A broad tree exercises retained intermediate values as well as deep NOT.
    for (instructions[0..32]) |*instruction| instruction.* = atom(0);
    @memset(instructions[32..63], .conjunction);
    instructions[63] = .negate;
    try at_limit.validate(schema);
    try t.expectEqual(m.Truth.false_value, try at_limit.truth(.{ .cells = &.{cells[0]} }));
}

test "Boolean validation checks every atom even beside a determining truth value" {
    var instructions = [_]Instruction{ .{ .atom = .all }, atom(3), .disjunction };
    const program: Program = .{ .instructions = &instructions };
    try t.expectError(error.UnknownColumn, program.validate(schema));
    instructions[1] = .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = 1 } } } };
    try t.expectError(error.TypeMismatch, program.validate(schema));
    instructions[1] = atom(0);
    try program.validate(schema);
    try t.expectError(error.InvalidColumnCount, program.validate(.{ .columns = &.{} }));
    try t.expectError(error.UnknownColumn, program.truth(.{ .cells = &.{} }));
}

test "Boolean evaluation is eager and preserves the first evaluated error" {
    const alternatives = [_]m.Alternative{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .boolean = true } } },
        .{ .counter = 1, .replica = 2, .value = .null },
    };
    const conflict: m.Cell = .{ .conflict = &alternatives };
    const type_error: m.Cell = .{ .type_error = .map };
    const and_program: Program = .{ .instructions = &.{ atom(0), atom(1), .conjunction } };
    const or_program: Program = .{ .instructions = &.{ atom(0), atom(1), .disjunction } };
    for ([_]Program{ and_program, or_program }) |program| {
        try program.validate(schema);
        try t.expectError(error.QueryTypeError, program.truth(.{ .cells = &.{ type_error, conflict } }));
        try t.expectError(error.QueryConflict, program.truth(.{ .cells = &.{ conflict, type_error } }));
    }
    try t.expectError(error.QueryConflict, and_program.truth(.{ .cells = &.{ cells[1], conflict } }));
    try t.expectError(error.QueryTypeError, or_program.truth(.{ .cells = &.{ cells[0], type_error } }));
    // A state test can inspect the error state without comparing its value.
    const inspect: Program = .{ .instructions = &.{
        .{ .atom = .{ .state = .{ .column = 0, .value = .type_error } } },
        .{ .atom = .{ .state = .{ .column = 1, .value = .conflict } } },
        .conjunction,
    } };
    try inspect.validate(schema);
    try t.expect(try inspect.matches(.{ .cells = &.{ type_error, conflict } }));
}
