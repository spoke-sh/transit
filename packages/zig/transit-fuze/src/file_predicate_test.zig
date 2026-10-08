const std = @import("std");
const t = std.testing;
const f = @import("FileQuery.zig");
const types = @import("Types.zig");
const Truth = @import("Finite.zig").Truth;
const Program = f.Program;
const Instruction = Program.Instruction;
const schema: types.Type = .{ .structure = &.{
    .{ .name = "a", .type = .boolean, .nullable = true, .optional = true },
    .{ .name = "b", .type = .boolean, .nullable = true, .optional = true },
} };
fn atom(column: u8) Instruction {
    return .{ .atom = .{ .compare = .{ .column = column, .op = .eq, .value = .{ .boolean = true } } } };
}

test "file Boolean programs preserve unknown and eager first error through logical cells" {
    const yes = Truth.true_value;
    const no = Truth.false_value;
    const unknown = Truth.unknown;
    const both = [4][4]Truth{
        .{ yes, no, unknown, unknown },     .{ no, no, no, no },
        .{ unknown, no, unknown, unknown }, .{ unknown, no, unknown, unknown },
    };
    const either = [4][4]Truth{
        .{ yes, yes, yes, yes },             .{ yes, no, unknown, unknown },
        .{ yes, unknown, unknown, unknown }, .{ yes, unknown, unknown, unknown },
    };
    const cells = [_]types.Values.Cell{
        .{ .value = .{ .atom = .{ .boolean = true } } },
        .{ .value = .{ .atom = .{ .boolean = false } } },
        .null,
        .missing,
    };
    const and_program: Program = .{ .instructions = &.{ atom(0), atom(1), .conjunction } };
    const or_program: Program = .{ .instructions = &.{ atom(0), atom(1), .disjunction } };
    const negated: Program = .{ .instructions = &.{ atom(0), .negate } };
    const negative = [_]Truth{ no, yes, unknown, unknown };
    for (cells, 0..) |left, i| {
        try t.expectEqual(negative[i], try negated.truth(schema, &.{left}));
        for (cells, 0..) |right, j| {
            try t.expectEqual(both[i][j], try and_program.truth(schema, &.{ left, right }));
            try t.expectEqual(either[i][j], try or_program.truth(schema, &.{ left, right }));
        }
    }
    const conflict: types.Values.Cell = .{ .conflict = &.{
        .{ .counter = 1, .replica = 1, .value = .null },
        .{ .counter = 1, .replica = 2, .value = .{ .value = .{ .atom = .{ .boolean = true } } } },
    } };
    const type_error: types.Values.Cell = .{ .type_error = .boolean };
    try conflict.validate(schema.structure[0], .{});
    for ([_]Program{ and_program, or_program }) |program| {
        try program.validate(schema);
        try t.expectError(error.QueryTypeError, program.truth(schema, &.{ type_error, conflict }));
        try t.expectError(error.QueryConflict, program.truth(schema, &.{ conflict, type_error }));
    }
    try t.expectError(error.QueryConflict, and_program.truth(schema, &.{ cells[1], conflict }));
    try t.expectError(error.QueryTypeError, or_program.truth(schema, &.{ cells[0], type_error }));
    const inspect: Program = .{ .instructions = &.{
        .{ .atom = .{ .state = .{ .column = 0, .value = .type_error } } },
        .{ .atom = .{ .state = .{ .column = 1, .value = .conflict } } },
        .conjunction,
    } };
    try t.expectEqual(yes, try inspect.truth(schema, &.{ type_error, conflict }));
}

test "file Boolean plans reject invalid stacks bounds and every atom before scanning" {
    for ([_][]const Instruction{ &.{}, &.{.negate}, &.{ atom(0), .disjunction }, &.{ atom(0), atom(1) } }) |instructions| {
        const program: Program = .{ .instructions = instructions };
        try t.expectError(error.InvalidPredicateProgram, program.validate(schema));
        try t.expectError(error.InvalidPredicateProgram, program.truth(schema, &.{}));
    }
    var instructions: [Program.max_instructions + 1]Instruction = @splat(.negate);
    instructions[0] = atom(0);
    const at_limit: Program = .{ .instructions = instructions[0..Program.max_instructions] };
    try at_limit.validate(schema);
    try t.expectEqual(Truth.false_value, try at_limit.truth(schema, &.{.{ .value = .{ .atom = .{ .boolean = true } } }}));
    const too_large: Program = .{ .instructions = &instructions };
    try t.expectError(error.PredicateTooLarge, too_large.validate(schema));
    try t.expectError(error.PredicateTooLarge, too_large.truth(schema, &.{}));
    var invalid = [_]Instruction{ .{ .atom = .all }, atom(2), .disjunction };
    const program: Program = .{ .instructions = &invalid };
    try t.expectError(error.UnknownColumn, program.validate(schema));
    invalid[1] = .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 1 } } } };
    try t.expectError(error.TypeMismatch, program.validate(schema));
    invalid[1] = atom(0);
    try t.expectError(error.UnknownColumn, program.truth(schema, &.{}));
}

test "file fingerprints bind program order opcodes and literal bytes within the existing budget" {
    var literal = "hello".*;
    var instructions = [_]Instruction{
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = &literal } } } },
        .{ .atom = .{ .state = .{ .column = 0, .value = .null } } },
        .disjunction,
    };
    const plan: f.Plan = .{
        .schema = .{ .structure = &.{.{ .name = "label", .type = .utf8 }} },
        .source_basis = @splat(1),
        .projection = &.{0},
        .predicate = .{ .program = .{ .instructions = &instructions } },
    };
    const original = try plan.fingerprint();
    literal[0] = 'H';
    try t.expect(!std.mem.eql(u8, &original, &try plan.fingerprint()));
    literal[0] = 'h';
    std.mem.swap(Instruction, &instructions[0], &instructions[1]);
    try t.expect(!std.mem.eql(u8, &original, &try plan.fingerprint()));
    std.mem.swap(Instruction, &instructions[0], &instructions[1]);
    instructions[2] = .conjunction;
    try t.expect(!std.mem.eql(u8, &original, &try plan.fingerprint()));
    instructions[2] = .disjunction;
    try t.expectEqualSlices(u8, &original, &try plan.fingerprint());
    const large_literal: [types.Query.max_cell_bytes]u8 = @splat('x');
    var large: [5]Instruction = undefined;
    large[0] = .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = &large_literal } } } };
    large[1] = large[0];
    large[2] = .conjunction;
    large[3] = large[0];
    large[4] = .conjunction;
    var oversized = plan;
    oversized.predicate = .{ .program = .{ .instructions = &large } };
    try oversized.validate();
    try t.expectError(error.PlanTooLarge, oversized.fingerprint());
}
