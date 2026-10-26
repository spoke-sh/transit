const std = @import("std");
const t = std.testing;
const types = @import("Types.zig");
const q = @import("LogicalQuery.zig");
const Batch = @import("Batch.zig");
const Cell = types.Values.Cell;

test "hot typed columns preserve full width, signed zero and Boolean ordering" {
    const Case = struct { kind: types.Type, literal: types.Values.Atom, inputs: [3]types.Values.Atom };
    const cases = [_]Case{
        .{ .kind = .uint64, .literal = .{ .unsigned = std.math.maxInt(u64) - 1 }, .inputs = .{ .{ .unsigned = 0 }, .{ .unsigned = std.math.maxInt(u64) - 1 }, .{ .unsigned = std.math.maxInt(u64) } } },
        .{ .kind = .float64, .literal = .{ .float = 0.0 }, .inputs = .{ .{ .float = -1.25 }, .{ .float = -0.0 }, .{ .float = 1.25 } } },
        .{ .kind = .boolean, .literal = .{ .boolean = true }, .inputs = .{ .{ .boolean = false }, .{ .boolean = true }, .{ .boolean = true } } },
    };
    for (cases) |case| {
        const fields = [_]types.Field{.{ .name = "n", .type = case.kind }};
        const plan: q.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = case.literal } } };
        var physical = try Batch.init(t.allocator, plan, .{});
        defer physical.deinit();
        for (case.inputs, 0..) |atom, i| try physical.append(&.{.{ .value = .{ .atom = atom } }}, .{ .row = i + 1, .boundary = 1 });
        physical.evaluate();
        for (physical.outcomes[0..3], [_]bool{ false, true, true }, case.inputs, 0..) |out, expected, atom, i| {
            try t.expectEqual(expected, out.truth.selects());
            try t.expectEqualDeep(atom, physical.columns[0].view(3).cell(i).value.atom);
        }
    }
}

test "eager column programs keep the first failing instruction separately for each lane" {
    const fields = [_]types.Field{ .{ .name = "a", .type = .int64, .nullable = true }, .{ .name = "b", .type = .int64, .nullable = true } };
    const plan: q.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .program = .{ .instructions = &.{
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = 0 } } } },
        .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .signed = 0 } } } },
        .conjunction,
        .negate,
    } } } };
    var physical = try Batch.init(t.allocator, plan, .{});
    defer physical.deinit();
    const zero: Cell = .{ .value = .{ .atom = .{ .signed = 0 } } };
    const one: Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const bad: Cell = .{ .type_error = .utf8 };
    const input = [_][2]Cell{ .{ one, bad }, .{ bad, bad }, .{ zero, .null }, .{ one, .null }, .{ zero, zero } };
    for (input, 0..) |row, i| try physical.append(&row, .{ .row = i + 1, .boundary = 1 });
    physical.evaluate();
    try t.expectEqual(Batch.Outcome.type_error, physical.outcomes[0]);
    try t.expectEqual(Batch.Outcome.type_error, physical.outcomes[1]);
    try t.expectEqualDeep(q.Plan.PredicateFailure{ .column = 1, .instruction = 1 }, physical.predicateFailure(0));
    try t.expectEqualDeep(q.Plan.PredicateFailure{ .column = 0, .instruction = 0 }, physical.predicateFailure(1));
    try t.expectEqual(@import("Finite.zig").Truth.unknown, physical.outcomes[2].truth);
    try t.expect(physical.outcomes[3].truth.selects());
    try t.expect(!physical.outcomes[4].truth.selects());
}

fn richOwnership(a: std.mem.Allocator) !void {
    var text = [_]u8{'z'};
    var literal = [_]u8{'a'};
    const fields = [_]types.Field{ .{ .name = "s", .type = .utf8 }, .{ .name = "nested", .type = .{ .list = .{ .type = &.utf8, .nullable = true } } } };
    const plan: q.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(71), .projection = &.{1}, .predicate = .{ .compare = .{ .column = 0, .op = .gt, .value = .{ .bytes = &literal } } } };
    var physical = try Batch.init(a, plan, .{});
    defer physical.deinit();
    const children = [_]Cell{ .null, .{ .value = .{ .atom = .{ .bytes = &text } } } };
    try physical.append(&.{ .{ .value = .{ .atom = .{ .bytes = &text } } }, .{ .value = .{ .list = &children } } }, .{ .row = 1, .boundary = 1 });
    text[0] = 'b';
    literal[0] = 'z';
    physical.evaluate();
    try t.expect(physical.outcomes[0].truth.selects());
    const row = physical.columns[1].view(1).cell(0);
    try t.expectEqualStrings("z", row.value.list[1].value.atom.bytes);
    try t.expect(row.value.list[0] == .null);
}
test "generic nested values and variable literals own their bytes under allocation failure" {
    try richOwnership(t.allocator);
    try t.checkAllAllocationFailures(t.allocator, richOwnership, .{});
}

test "borrowed batch retains five states and recursive payloads without arena expansion" {
    const text: [8192]u8 = @splat('z');
    const children = [_]Cell{ .null, .{ .value = .{ .atom = .{ .bytes = &text } } } };
    const alternatives = [_]types.Values.Alternative{
        .{ .counter = 1, .replica = 1, .value = .null },
        .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .list = &children } } },
    };
    const fields = [_]types.Field{.{ .name = "nested", .type = .{ .list = .{ .type = &.utf8, .nullable = true } }, .nullable = true, .optional = true }};
    const plan: q.Plan = .{ .schema = .{ .structure = &fields }, .source_basis = @splat(71), .projection = &.{0} };
    var physical = try Batch.init(t.allocator, plan, .{ .rows = 8, .bytes = 8192 });
    defer physical.deinit();
    const cells = [_]Cell{ .null, .missing, .{ .type_error = .int64 }, .{ .conflict = &alternatives }, .{ .value = .{ .list = &children } } };
    const used = physical.memory.end_index;
    for (cells, 0..) |cell, i| {
        try cell.validate(fields[0], .{});
        try physical.appendBorrowedValidated(&.{cell}, .{ .row = i + 1, .boundary = 1 });
    }
    physical.evaluate();
    for (cells, 0..) |expected, i| {
        try t.expectEqualDeep(expected, physical.columns[0].view(cells.len).cell(i));
        try t.expect(physical.outcomes[i].truth.selects());
    }
    try t.expectEqual(used, physical.memory.end_index);
    try t.expectEqual(alternatives[0..].ptr, physical.columns[0].view(cells.len).cell(3).conflict.ptr);
    try t.expectEqual(children[0..].ptr, physical.columns[0].view(cells.len).cell(4).value.list.ptr);
    try t.expectError(error.InvalidProvenance, physical.appendBorrowedValidated(&.{.null}, .{ .row = 5, .boundary = 1 }));
    try t.expectEqual(cells.len, physical.len);
    physical.reset();
    try t.expectError(error.BatchFull, physical.appendValidated(&.{cells[4]}, .{ .row = 1, .boundary = 1 }));
    try t.expectEqual(@as(usize, 0), physical.len);
    try t.expectEqual(used, physical.memory.end_index);
}

test "portable and supported AVX2 agree on masks, every tail and five-state failures" {
    const finite = @import("Finite.zig");
    const alternatives = [_]types.Values.Alternative{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 2, .replica = 1, .value = .null } };
    for ([_]Batch.kernels.cpu.Implementation{ .portable, .avx2 }) |implementation| {
        if (implementation == .avx2 and !Batch.kernels.cpu.hasAvx2()) continue;
        for ([_]usize{ 0, 1, 3, 4, 7, 8, 15, 16, 17, 31, 32, 33, 63, 64, 65 }) |len| {
            for (std.enums.values(finite.Comparison)) |op| {
                const plan: q.Plan = .{ .schema = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true, .optional = true }} }, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = op, .value = .{ .signed = 0 } } } };
                var physical = try Batch.init(t.allocator, plan, .{ .implementation = implementation });
                defer physical.deinit();
                for (0..len) |i| {
                    const cell: Cell = switch (i % 11) {
                        0 => .null,
                        1 => .missing,
                        2 => .{ .type_error = .utf8 },
                        3 => .{ .conflict = &alternatives },
                        else => .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(i)) - 30 } } },
                    };
                    try physical.append(&.{cell}, .{ .row = i + 1, .boundary = i / 8 + 1 });
                }
                physical.evaluate();
                for (physical.outcomes[0..len], 0..) |actual, i| switch (i % 11) {
                    0, 1 => try t.expectEqual(finite.Truth.unknown, actual.truth),
                    2 => try t.expect(actual == .type_error),
                    3 => try t.expect(actual == .conflict),
                    else => {
                        const expected = switch (op) {
                            .eq => i == 30,
                            .ne => i != 30,
                            .lt => i < 30,
                            .le => i <= 30,
                            .gt => i > 30,
                            .ge => i >= 30,
                        };
                        try t.expectEqual(expected, actual.truth.selects());
                    },
                };
            }
        }
    }
}
