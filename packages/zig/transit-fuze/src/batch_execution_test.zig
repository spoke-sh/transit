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
    rejection: ?enum { fixture_denied } = null,
    pub fn deinit(_: *Fixture) void {}
    pub fn next(self: *Fixture) !?logical.Row {
        return self.nextAllocated(self.allocator);
    }
    pub fn nextAllocated(self: *Fixture, row_allocator: std.mem.Allocator) !?logical.Row {
        if (self.fail_at == self.index) {
            self.rejection = .fixture_denied;
            return error.SourceFault;
        }
        if (self.index == self.rows.len) {
            self.complete = true;
            return null;
        }
        var arena: std.heap.ArenaAllocator = .init(row_allocator);
        errdefer arena.deinit();
        const cells = try arena.allocator().dupe(Cell, &self.rows[self.index]);
        for (cells) |*cell| cell.* = try types.Values.cloneValidated(arena.allocator(), cell.*);
        self.index += 1;
        return .{ .arena = arena, .cells = cells };
    }
};
const fixture_schema: types.Type = .{ .structure = &.{ .{ .name = "key", .type = .int64, .nullable = true, .optional = true }, .{ .name = "value", .type = .int64, .nullable = true, .optional = true } } };

test "seeded rebatching preserves independent projection COUNT and ordered SUM across dispatch choices" {
    const Batch = @import("Batch.zig");
    var prng = std.Random.DefaultPrng.init(71);
    const random = prng.random();
    for (0..32) |_| {
        var rows: [129][2]Cell = undefined;
        var selected: [129]Cell = undefined;
        var count: usize = 0;
        var sum: ?i64 = null;
        const limit = random.uintLessThan(usize, 130);
        for (&rows) |*row| {
            const key = @as(i64, @intCast(random.uintLessThan(u32, 201))) - 100;
            row[0] = switch (random.uintLessThan(u8, 8)) {
                0 => .null,
                1 => .missing,
                else => integer(key),
            };
            const value = @as(i64, @intCast(random.uintLessThan(u32, 2049))) - 1024;
            row[1] = if (random.boolean()) .null else integer(value);
            if (row[0] == .value and key >= 0 and count < limit) {
                selected[count] = row[1];
                count += 1;
                if (row[1] == .value) sum = (sum orelse 0) + value;
            }
        }
        const size = 1 + random.uintLessThan(usize, 1024);
        for ([_]Batch.kernels.cpu.Implementation{ .portable, .avx2 }) |implementation| {
            if (implementation == .avx2 and !Batch.kernels.cpu.hasAvx2()) continue;
            inline for (.{ .rows, .count, .sum }) |aggregate| {
                const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = aggregate, .limit = limit, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
                var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = std.testing.allocator, .rows = &rows }, plan, .{ .rows = size, .implementation = implementation });
                defer execution.deinit();
                var emitted: usize = 0;
                while (try execution.next()) |input| {
                    var row = input;
                    defer row.deinit();
                    const expected: Cell = switch (aggregate) {
                        .rows => selected[emitted],
                        .count => .{ .value = .{ .atom = .{ .unsigned = count } } },
                        .sum => if (sum) |value| integer(value) else .null,
                        else => unreachable,
                    };
                    try std.testing.expectEqualDeep(expected, row.cells[0]);
                    emitted += 1;
                }
                try std.testing.expectEqual(if (aggregate == .rows) count else 1, emitted);
                try std.testing.expectEqual(rows.len, execution.scanned);
                try std.testing.expect(execution.complete);
            }
        }
    }
}

test "valid oversized rows preserve values without increasing the physical cap" {
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

test "cached and oversized projected rows outlive the execution and later acquisitions" {
    const text: [8192]u8 = @splat('x');
    const rows = [_][2]Cell{
        .{ integer(1), .{ .value = .{ .atom = .{ .bytes = "first" } } } },
        .{ integer(2), .{ .value = .{ .atom = .{ .bytes = &text } } } },
        .{ integer(3), .{ .value = .{ .atom = .{ .bytes = "last" } } } },
    };
    const plan: logical.Plan = .{ .schema = .{ .structure = &.{ .{ .name = "key", .type = .int64 }, .{ .name = "value", .type = .utf8 } } }, .source_basis = @splat(71), .projection = &.{1} };
    var output: [3]logical.Row = undefined;
    var count: usize = 0;
    defer for (output[0..count]) |*row| row.deinit();
    {
        var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = std.testing.allocator, .rows = &rows }, plan, .{ .rows = 64, .bytes = 4096 });
        defer execution.deinit();
        for (&output) |*row| {
            row.* = (try execution.next()).?;
            count += 1;
        }
        try std.testing.expect(try execution.next() == null);
    }
    for (output, [_][]const u8{ "first", &text, "last" }) |row, expected| try std.testing.expectEqualStrings(expected, row.cells[0].value.atom.bytes);
}

test "allocation failures release oversized cached-source projections" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(a: std.mem.Allocator) !void {
            const text: [8192]u8 = @splat('x');
            const rows = [_][2]Cell{.{ integer(1), .{ .value = .{ .atom = .{ .bytes = &text } } } }};
            const plan: logical.Plan = .{ .schema = .{ .structure = &.{ .{ .name = "key", .type = .int64 }, .{ .name = "value", .type = .utf8 } } }, .source_basis = @splat(71), .projection = &.{1} };
            var execution = try Execution(Fixture, .full_source).initBudget(.{ .allocator = a, .rows = &rows }, plan, .{ .bytes = 4096 });
            defer execution.deinit();
            var row = (try execution.next()).?;
            defer row.deinit();
            try std.testing.expectEqualStrings(&text, row.cells[0].value.atom.bytes);
        }
    }.run, .{});
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
        try t.expect(execution.scan.rejection == null);
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

test "deferred source rejection is restored only at its own failure frontier" {
    const rows = [_][2]Cell{ .{ integer(1), integer(7) }, .{ integer(2), integer(8) } };
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1} };
    var execution = try Execution(Fixture, .full_source).init(.{ .allocator = std.testing.allocator, .rows = &rows, .fail_at = 2 }, plan);
    defer execution.deinit();
    execution.startup_rows = 0;
    for ([_]i64{ 7, 8 }) |expected| {
        var row = (try execution.next()).?;
        defer row.deinit();
        try std.testing.expectEqual(@as(i128, expected), row.cells[0].value.atom.signed);
        try std.testing.expect(execution.scan.rejection == null);
    }
    try std.testing.expectError(error.SourceFault, execution.next());
    try std.testing.expectEqual(.fixture_denied, execution.scan.rejection.?);
}

const SparseFixture = struct {
    allocator: std.mem.Allocator,
    rows: []const [2]Cell,
    ordinals: []const u64,
    coverage: u64,
    index: usize = 0,
    complete: bool = false,
    failure: ?logical.Failure = null,
    pub fn deinit(_: *SparseFixture) void {}
    pub fn next(self: *SparseFixture) !?logical.Row {
        if (self.index == self.rows.len) {
            if (self.failure != null) return error.QueryTypeError;
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
    pub fn batchOrdinal(self: *const SparseFixture) u64 {
        return self.ordinals[self.index - 1];
    }
    pub fn batchCoverage(self: *const SparseFixture) u64 {
        return self.coverage;
    }
    pub fn batchFailure(self: *const SparseFixture) ?logical.Failure {
        return self.failure;
    }
};
fn deferredPredicate(plan: logical.Plan) !logical.Failure {
    var result: logical.Failure = .{ .operation = .predicate, .row = 25, .column_len = 3, .column_truncated = false, .expected = @splat(0), .expected_len = 5, .state = .type_error, .instruction = 0, .binding = plan.source_basis, .plan = try plan.fingerprint() };
    @memcpy(result.column[0..3], "key");
    @memcpy(result.expected[0..5], "int64");
    return result;
}

test "filtered batch sources preserve original failure ordinals and deferred source arbitration" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(1), integer(std.math.maxInt(i64)) }, .{ integer(1), integer(1) } };
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = .sum };
    for ([_]usize{ 1, 2, 8, 256 }) |target| {
        var execution = try Execution(SparseFixture, .selected_prefix).initBudget(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &.{ 4, 19 }, .coverage = 25, .failure = try deferredPredicate(plan) }, plan, .{ .rows = target });
        defer execution.deinit();
        try t.expectError(error.Overflow, execution.next());
        try t.expectEqual(@as(u64, 19), execution.failure.?.row);
        try t.expectEqual(.sum, execution.failure.?.operation);
        try t.expectEqual(@as(u64, 19), execution.scanned);
    }
    const small = [_][2]Cell{.{ integer(1), integer(7) }};
    var deferred = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &small, .ordinals = &.{4}, .coverage = 25, .failure = try deferredPredicate(plan) }, plan);
    defer deferred.deinit();
    try t.expectError(error.QueryTypeError, deferred.next());
    try t.expectEqual(@as(u64, 25), deferred.scanned);
    try t.expectEqualDeep(try deferredPredicate(plan), deferred.failure.?);
    try t.expect(!deferred.complete);
}

test "filtered batch coverage counts skipped tails while LIMIT retains its selected prefix" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(1), integer(7) }, .{ integer(1), integer(11) } };
    var plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = .count };
    var full = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &.{ 4, 19 }, .coverage = 23 }, plan);
    defer full.deinit();
    var count = (try full.next()).?;
    defer count.deinit();
    try t.expectEqual(@as(u128, 2), count.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(u64, 23), full.scanned);
    try t.expect(full.complete);
    plan.limit = 1;
    var prefix = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &.{ 4, 19 }, .coverage = 23, .failure = try deferredPredicate(plan) }, plan);
    defer prefix.deinit();
    var limited = (try prefix.next()).?;
    defer limited.deinit();
    try t.expectEqual(@as(u128, 1), limited.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(u64, 4), prefix.scanned);
    try t.expectEqual(@as(usize, 1), prefix.scan.index);
    try t.expect(prefix.complete);
    // An empty filtered result still requires complete original source coverage.
    plan.limit = null;
    var empty = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &.{}, .ordinals = &.{}, .coverage = 23 }, plan);
    defer empty.deinit();
    var zero = (try empty.next()).?;
    defer zero.deinit();
    try t.expectEqual(@as(u128, 0), zero.cells[0].value.atom.unsigned);
    try t.expectEqual(@as(u64, 23), empty.scanned);
}

test "filtered batch sources reject regressing ordinals coverage and foreign failure attribution" {
    const t = std.testing;
    const rows = [_][2]Cell{ .{ integer(1), integer(7) }, .{ integer(1), integer(11) } };
    const plan: logical.Plan = .{ .schema = fixture_schema, .source_basis = @splat(71), .projection = &.{1}, .aggregate = .count };
    for ([_]struct { ordinals: [2]u64, coverage: u64 }{ .{ .ordinals = .{ 0, 19 }, .coverage = 23 }, .{ .ordinals = .{ 4, 4 }, .coverage = 23 }, .{ .ordinals = .{ 4, 19 }, .coverage = 18 } }) |case| {
        var execution = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &case.ordinals, .coverage = case.coverage }, plan);
        defer execution.deinit();
        try t.expectError(error.SourceChanged, execution.next());
        try t.expect(!execution.complete);
    }
    var failure = try deferredPredicate(plan);
    failure.plan[0] ^= 1;
    var foreign = try Execution(SparseFixture, .selected_prefix).init(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &.{ 4, 19 }, .coverage = 25, .failure = failure }, plan);
    defer foreign.deinit();
    try t.expectError(error.SourceChanged, foreign.next());
    try t.expect(foreign.failure == null);
}

test "filtered oversized rows retain original provenance across a held batch suffix" {
    const t = std.testing;
    const text: [8192]u8 = @splat('x');
    const rows = [_][2]Cell{ .{ integer(1), .{ .value = .{ .atom = .{ .bytes = "small" } } } }, .{ integer(2), .{ .value = .{ .atom = .{ .bytes = &text } } } }, .{ .{ .type_error = .utf8 }, .{ .value = .{ .atom = .{ .bytes = "last" } } } } };
    const plan: logical.Plan = .{ .schema = .{ .structure = &.{ .{ .name = "key", .type = .int64 }, .{ .name = "value", .type = .utf8 } } }, .source_basis = @splat(71), .projection = &.{1}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    var execution = try Execution(SparseFixture, .selected_prefix).initBudget(.{ .allocator = t.allocator, .rows = &rows, .ordinals = &.{ 4, 19, 23 }, .coverage = 23 }, plan, .{ .bytes = 4096 });
    defer execution.deinit();
    execution.startup_rows = 0;
    for ([_][]const u8{ "small", &text }, [_]u64{ 4, 19 }) |expected, ordinal| {
        var row = (try execution.next()).?;
        defer row.deinit();
        try t.expectEqualStrings(expected, row.cells[0].value.atom.bytes);
        try t.expectEqual(ordinal, execution.scanned);
    }
    try t.expectError(error.QueryTypeError, execution.next());
    try t.expectEqual(@as(u64, 23), execution.failure.?.row);
    try t.expectEqual(.predicate, execution.failure.?.operation);
    try t.expectEqual(@as(usize, 4096), execution.physical.residentBytes());
}
