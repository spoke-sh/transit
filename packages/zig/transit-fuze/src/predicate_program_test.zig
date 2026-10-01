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

test "owned programs copy instructions and reject malformed lengths before borrowing" {
    var instructions = [_]Instruction{ atom(0), .negate };
    var original = try Program.Owned.init(&instructions);
    var copied = original;
    instructions[1] = .conjunction;
    original.instructions[1] = .disjunction;
    const view = try copied.view();
    try t.expectEqual(@intFromPtr(&copied.instructions), @intFromPtr(view.instructions.ptr));
    try view.validate(schema);
    try t.expectEqual(m.Truth.false_value, try view.truth(.{ .cells = &.{cells[0]} }));
    copied.count = 0;
    try t.expectError(error.InvalidPredicateProgram, copied.view());
    copied.count = 255;
    try t.expectError(error.PredicateTooLarge, copied.view());
}

test "canonical programs own decoded instructions and retain borrowed literal bytes" {
    const input: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("label"), .type = .utf8 }} };
    const plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .program = try .init(&.{
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .utf8 = "hello" } } } },
        .negate,
        .{ .atom = .{ .state = .{ .column = 0, .value = .null } } },
        .disjunction,
    }) } };
    var bytes: [m.Codec.max_plan_bytes + 1]u8 = undefined;
    const encoded = try m.Codec.encode(plan, &bytes);
    var decoded = try m.Codec.decode(encoded);
    const copied = decoded;
    decoded.predicate.program.instructions[1] = .conjunction;
    try copied.validate(input);
    try t.expect(try copied.matches(.{ .cells = &.{.null} }));
    try t.expect(!try copied.matches(.{ .cells = &.{.missing} }));
    try t.expect(!try copied.matches(.{ .cells = &.{.{ .value = .{ .utf8 = "hello" } }} }));
    try t.expect(try copied.matches(.{ .cells = &.{.{ .value = .{ .utf8 = "world" } }} }));
    const literal = copied.predicate.program.instructions[0].atom.compare.value.utf8;
    try t.expect(@intFromPtr(literal.ptr) >= @intFromPtr(encoded.ptr));
    try t.expect(@intFromPtr(literal.ptr) + literal.len <= @intFromPtr(encoded.ptr) + encoded.len);
    var repeated: [m.Codec.max_plan_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, encoded, try m.Codec.encode(copied, &repeated));
    for (0..encoded.len) |len| {
        if (m.Codec.decode(encoded[0..len])) |_| return error.AcceptedTruncatedProgram else |_| {}
    }
    bytes[encoded.len] = 0;
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(bytes[0 .. encoded.len + 1]));
    // A one-column unnamed plan has its predicate tag at byte 49.
    try t.expectEqual(@as(u8, 3), bytes[49]);
    bytes[50] = 65;
    try t.expectError(error.PredicateTooLarge, m.Codec.decode(encoded));
    bytes[50] = 0;
    try t.expectError(error.InvalidPredicateProgram, m.Codec.decode(encoded));
    bytes[50] = 4;
    bytes[51] = 255;
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(encoded));
    bytes[51] = 4;
    try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(encoded));
}

test "saved programs enforce scalar schema instruction and total encoding budgets" {
    var instructions: [Program.max_instructions]Instruction = @splat(.negate);
    instructions[0] = atom(0);
    var plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .program = try .init(&instructions) } };
    var bytes: [m.Codec.max_plan_bytes * 2]u8 = undefined;
    const encoded = try m.Codec.encode(plan, &bytes);
    const decoded = try m.Codec.decode(encoded);
    try decoded.validate(schema);
    try t.expect(!try decoded.matches(.{ .cells = &.{cells[0]} }));
    plan.predicate.program.instructions[0].atom.compare.column = 8;
    try t.expectError(error.UnknownColumn, m.Codec.encode(plan, &bytes));
    plan.predicate.program.instructions[0].atom.compare.column = 3;
    try t.expectError(error.UnknownColumn, plan.validate(schema));
    plan.predicate.program.instructions[0].atom.compare = .{ .column = 0, .op = .eq, .value = .{ .float64 = std.math.inf(f64) } };
    try t.expectError(error.NonFiniteValue, m.Codec.encode(plan, &bytes));
    const large: Instruction = .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .binary = &@as([m.max_cell_bytes]u8, @splat(255)) } } } };
    plan.predicate.program = try .init(&.{ large, large, .conjunction });
    try t.expectError(error.PlanTooLarge, m.Codec.encode(plan, &bytes));
}

test "compound plan identity fences continuation and survives page boundaries" {
    const f = @import("root.zig");
    const program = try Program.Owned.init(&.{ atom(0), .negate, atom(1), .disjunction });
    const plan: m.Plan = .{ .projection = &.{0}, .aggregate = .count, .limit = 2, .predicate = .{ .program = program } };
    const basis: m.Basis = .{ .kind = .kv, .resource = 7, .revision = 9, .contract = @splat(1), .schema = try schema.fingerprint() };
    const bound = try plan.bind(basis, schema);
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    const first = try m.Stream.step(bound, .start(bound), .{ .basis = basis, .ordinal = 0, .rows = &.{
        .{ .cells = &.{ .null, cells[1], .null } },
        .{ .cells = &.{ cells[1], .missing, .null } },
    }, .end = false }, workspace, &output, &cancellation);
    try t.expectEqual(@as(u64, 1), first.progress.selected);
    var encoded: [m.Codec.max_plan_bytes]u8 = undefined;
    const restored = try (try m.Codec.decode(try m.Codec.encode(plan, &encoded))).bind(basis, schema);
    const checkpoint = try first.progress.encode();
    const progress = try m.Stream.Progress.decode(&checkpoint);
    const page: m.Page = .{ .basis = basis, .ordinal = 1, .rows = &.{
        .{ .cells = &.{ cells[0], cells[0], .null } },
        .{ .cells = &.{ cells[0], cells[0], .null } },
    }, .end = true };
    const final = try m.Stream.step(restored, progress, page, workspace, &output, &cancellation);
    try t.expectEqual(@as(u64, 2), final.progress.selected);
    var changed = plan;
    changed.predicate.program.instructions[3] = .conjunction;
    const different = try changed.bind(basis, schema);
    try t.expectError(error.SourceChanged, m.Stream.step(different, progress, page, workspace, &output, &cancellation));
    var tampered = restored;
    tampered.plan = changed;
    try t.expectError(error.SourceChanged, m.Stream.step(tampered, progress, page, workspace, &output, &cancellation));
}

test "public and bound encoders reject invalid atoms before producing canonical bytes" {
    const input: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = .utf8 }} };
    const basis: m.Basis = .{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(1), .schema = try input.fingerprint() };
    const Case = struct { atom: m.Plan.Atom, failure: anyerror };
    for ([_]Case{
        .{ .atom = .{ .state = .{ .column = m.max_columns, .value = .missing } }, .failure = error.UnknownColumn },
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .utf8 = "\xff" } } }, .failure = error.InvalidUtf8 },
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .binary = &@as([m.max_cell_bytes + 1]u8, @splat(0)) } } }, .failure = error.CellTooLarge },
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .float64 = std.math.inf(f64) } } }, .failure = error.NonFiniteValue },
    }) |case| {
        var plan: m.Plan = .{ .projection = &.{0}, .predicate = switch (case.atom) {
            inline else => |value, tag| @unionInit(m.Plan.Predicate, @tagName(tag), value),
        } };
        var buffer: [m.Codec.max_plan_bytes]u8 = undefined;
        for (0..2) |_| {
            try t.expectError(case.failure, m.Codec.encode(plan, &buffer));
            try t.expectError(case.failure, plan.bind(basis, input));
            var owned: Program.Owned = .{ .count = 1 };
            owned.instructions[0] = .{ .atom = case.atom };
            plan.predicate = .{ .program = owned };
        }
    }
    const mismatch: m.Plan = .{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = 7 } } } };
    var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const decoded = try m.Codec.decode(try m.Codec.encode(mismatch, &bytes));
    try t.expectError(error.TypeMismatch, decoded.bind(basis, input));
}

test "independent Boolean plan fixtures preserve every scalar and canonical identity" {
    const Fixture = struct { version: u8, cases: []const struct { name: []const u8, type: u8, wire_hex: []const u8, digest: []const u8 } };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/boolean-plans-v1.json"), .{});
    defer fixture.deinit();
    try t.expectEqual(1, fixture.value.version);
    for (fixture.value.cases) |case| {
        var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        const encoded = try std.fmt.hexToBytes(&bytes, case.wire_hex);
        const plan = try m.Codec.decode(encoded);
        const input: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = @fromBackingInt(@intCast(case.type)) }} };
        const bound = try plan.bind(.{ .kind = .document, .resource = 7, .revision = 9, .contract = @splat(1), .schema = try input.fingerprint() }, input);
        var digest: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&digest, case.digest);
        try t.expectEqualSlices(u8, &digest, &bound.fingerprint);
        var repeated: [m.Codec.max_plan_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, encoded, try m.Codec.encode(plan, &repeated));
        try t.expect(try plan.matches(.{ .cells = &.{.null} }));
        try t.expect(!try plan.matches(.{ .cells = &.{.missing} }));
        const literal = plan.predicate.program.instructions[0].atom.compare.value;
        try t.expect(!try plan.matches(.{ .cells = &.{.{ .value = literal }} }));
        // The previous output-alias definition must fail before plan decoding.
        _ = try std.fmt.hexToBytes(bytes[4..36], "58ae72e1f9a4b589536e5a0d262d6e6aebcc2fab40698b4bfea6833281ad9f3c");
        try t.expectError(error.UnsupportedPlanDefinition, m.Codec.decode(encoded));
    }
}
