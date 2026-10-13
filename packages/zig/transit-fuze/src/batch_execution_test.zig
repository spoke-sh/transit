const std = @import("std");
const logical = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const Cell = types.Values.Cell;
const Execution = @import("BatchExecution.zig").Execution;

const Fixture = struct {
    allocator: std.mem.Allocator,
    rows: []const [2]Cell,
    index: usize = 0,
    complete: bool = false,
    fail_at: ?usize = null,
    pub fn deinit(_: *Fixture) void {}
    pub fn next(self: *Fixture) !?logical.Row {
        if (self.fail_at == self.index) return error.SourceFault;
        if (self.index == self.rows.len) {
            self.complete = true;
            return null;
        }
        var arena: std.heap.ArenaAllocator = .init(self.allocator);
        errdefer arena.deinit();
        const cells = try arena.allocator().dupe(Cell, &self.rows[self.index]);
        for (cells) |*cell| cell.* = try types.Values.cloneValidated(arena.allocator(), cell.*);
        self.index += 1;
        return .{ .arena = arena, .cells = cells };
    }
};
const fixture_schema: types.Type = .{ .structure = &.{ .{ .name = "key", .type = .int64, .nullable = true, .optional = true }, .{ .name = "value", .type = .int64, .nullable = true, .optional = true } } };

test "valid oversized rows retain the source owner without increasing the physical cap" {
    const text: [8192]u8 = @splat('x');
    const rows = [_][2]Cell{
        .{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .bytes = &text } } } },
        .{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .{ .value = .{ .atom = .{ .bytes = "small" } } } },
        .{ .{ .value = .{ .atom = .{ .signed = 3 } } }, .{ .value = .{ .atom = .{ .bytes = &text } } } },
    };
    const plan: logical.Plan = .{ .schema = .{ .structure = &.{ .{ .name = "key", .type = .int64 }, .{ .name = "value", .type = .utf8 } } }, .source_basis = @splat(71), .projection = &.{1} };
    var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = std.testing.allocator, .rows = &rows }, plan, .{ .rows = 64, .bytes = 4096 });
    defer execution.deinit();
    for ([_][]const u8{ &text, "small", &text }) |expected| {
        var row = (try execution.next()).?;
        defer row.deinit();
        try std.testing.expectEqualStrings(expected, row.cells[0].value.atom.bytes);
        try std.testing.expectEqual(@as(usize, 4096), execution.physical.residentBytes());
    }
    try std.testing.expect(try execution.next() == null);
    try std.testing.expect(execution.complete);
    try std.testing.expectEqual(@as(u64, 3), execution.scanned);
}

test "checked SUM prefix wins over later predicate failure across every batch size" {
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = .sum, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    const yes: Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const rows = [_][2]Cell{
        .{ yes, .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i64) } } } },
        .{ yes, yes },
        .{ .{ .type_error = .utf8 }, .{ .value = .{ .atom = .{ .signed = -1 } } } },
    };
    for ([_]usize{ 1, 2, 3, 64, 256, 1024 }) |size| {
        var execution = try Execution(Fixture, .selected_prefix).initBudget(.{ .allocator = std.testing.allocator, .rows = &rows }, plan, .{ .rows = size });
        defer execution.deinit();
        try std.testing.expectError(error.Overflow, execution.next());
        try std.testing.expectEqual(@as(u64, 2), execution.failure.?.row);
        try std.testing.expectEqual(.sum, execution.failure.?.operation);
        try std.testing.expectEqualStrings("value", execution.failure.?.column[0..execution.failure.?.column_len]);
    }
}
fn integer(value: i64) Cell {
    return .{ .value = .{ .atom = .{ .signed = value } } };
}

test "batch coordinator preserves earlier COUNT failure over later predicate and read failure" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(1), .{ .type_error = .utf8 } }, .{ .{ .type_error = .boolean }, integer(3) } };
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = .count_values, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    for ([_]usize{ 1, 64, 256, 1024 }) |target| {
        var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = t.allocator, .rows = &rows, .fail_at = 2 }, plan, .{ .rows = target });
        defer execution.deinit();
        try t.expectError(error.QueryTypeError, execution.next());
        try t.expectEqual(@as(u64, 1), execution.failure.?.row);
        try t.expectEqual(.count, execution.failure.?.operation);
        try t.expectEqualStrings("value", execution.failure.?.columnName());
        try t.expectError(error.FailedQuery, execution.next());
        try t.expect(!execution.complete);
    }
}
test "LIMIT retains complete-source verification and selected-prefix boundary" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(1), integer(7) }, .{ .{ .type_error = .utf8 }, integer(8) } };
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .limit = 1, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    inline for (.{ .full_source, .selected_prefix }) |verification| {
        var execution = try Execution(Fixture, verification).init(.{ .allocator = t.allocator, .rows = &rows, .fail_at = 2 }, plan);
        defer execution.deinit();
        var row = (try execution.next()).?;
        defer row.deinit();
        try t.expectEqual(@as(i128, 7), row.cells[0].value.atom.signed);
        if (verification == .full_source) {
            try t.expectError(error.SourceFault, execution.next());
            try t.expect(!execution.complete);
        } else {
            try t.expect((try execution.next()) == null);
            try t.expect(execution.complete);
            try t.expectEqual(@as(usize, 1), execution.scan.index);
        }
    }
}
test "rebatching preserves independent rows, count and value-count answers" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(-1), integer(1) }, .{ .null, integer(2) }, .{ integer(2), .null }, .{ integer(3), integer(9) }, .{ .missing, integer(4) } };
    for ([_]usize{ 1, 2, 3, 64, 256, 1024 }) |target| {
        inline for (.{ .rows, .count, .count_values }) |aggregate| {
            const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = aggregate, .predicate = .{ .compare = .{ .column = 0, .op = .gt, .value = .{ .signed = 0 } } } };
            var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = t.allocator, .rows = &rows }, plan, .{ .rows = target });
            defer execution.deinit();
            var first = (try execution.next()).?;
            defer first.deinit();
            if (aggregate == .rows) {
                try t.expect(first.cells[0] == .null);
                var second = (try execution.next()).?;
                defer second.deinit();
                try t.expectEqual(@as(i128, 9), second.cells[0].value.atom.signed);
            } else try t.expectEqual(@as(u128, if (aggregate == .count) 2 else 1), first.cells[0].value.atom.unsigned);
            try t.expect((try execution.next()) == null);
            try t.expect(execution.complete);
            try t.expectEqual(@as(u64, 5), execution.scanned);
        }
    }
}
test "allocation failures release batch and source-owned rows" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(a: std.mem.Allocator) !void {
            const rows = [_][2]Cell{.{ integer(1), integer(7) }};
            const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1} };
            var execution = try Execution(Fixture, .full_source).init(.{ .allocator = a, .rows = &rows }, plan);
            defer execution.deinit();
            while (try execution.next()) |input| {
                var row = input;
                row.deinit();
            }
        }
    }.run, .{});
}
