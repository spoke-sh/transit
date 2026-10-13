//! Experimental int64 pull execution. Source acquisition stays serial; read
//! failures are held behind the already acquired prefix's operator frontier.
const std = @import("std");
const batch = @import("Batch.zig");
const logical = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const Cell = types.Values.Cell;

pub fn Execution(comptime Scan: type, comptime verification: logical.Verification) type {
    return struct {
        const Self = @This();
        scan: Scan,
        physical: batch,
        scanned: u64 = 0,
        selected: u64 = 0,
        value_count: u64 = 0,
        sum: ?i64 = null,
        emitted: u64 = 0,
        /// Host output boundary to serve with single-row acquisition first.
        startup_rows: u16 = 1,
        complete: bool = false,
        failed: bool = false,
        failure: ?logical.Failure = null,
        index: usize = 0,
        pending: ?logical.Row = null,
        read_error: ?anyerror = null,
        read_rejection: if (@hasField(Scan, "rejection")) @FieldType(Scan, "rejection") else void = if (@hasField(Scan, "rejection")) null else {},

        /// Takes ownership of scan only on success. Decoder/source and returned
        /// row budgets remain with their existing owners; limits bound compute.
        pub fn init(scan: Scan, plan: logical.Plan) !Self {
            return initBudget(scan, plan, .{});
        }
        pub fn initBudget(scan: Scan, plan: logical.Plan, limits: batch.Limits) !Self {
            return .{ .scan = scan, .physical = try batch.init(scan.allocator, plan, limits) };
        }
        pub fn deinit(self: *Self) void {
            if (self.pending) |*row| row.deinit();
            self.physical.deinit();
            self.scan.deinit();
            self.* = undefined;
        }
        fn atLimit(self: *const Self) bool {
            return if (self.physical.plan.limit) |limit| self.selected == limit else false;
        }
        fn fill(self: *Self) void {
            self.physical.reset();
            self.index = 0;
            if (self.read_error != null) return;
            // Do not delay the first row behind a target-sized source read.
            var target = if (self.emitted < self.startup_rows and self.physical.plan.aggregate == .rows) 1 else self.physical.capacity;
            if (verification == .selected_prefix) if (self.physical.plan.limit) |limit| {
                target = @min(target, limit - self.selected);
            };
            while (self.physical.len < target) {
                const acquired = if (self.pending) |row| held: {
                    self.pending = null;
                    break :held row;
                } else self.scan.next() catch |err| {
                    self.read_error = err;
                    if (@hasField(Scan, "rejection")) self.read_rejection = self.scan.rejection;
                    break;
                };
                var row = acquired orelse break;
                const ordinal = std.math.add(u64, self.scanned, self.physical.len + 1) catch |err| {
                    row.deinit();
                    self.read_error = err;
                    break;
                };
                const provenance: batch.Provenance = .{ .row = ordinal, .boundary = ordinal, .identity = if (@hasDecl(Scan, "batchIdentity")) self.scan.batchIdentity() else null };
                self.physical.appendValidated(row.cells, provenance) catch |err| {
                    if (err == error.BatchFull and self.physical.len != 0) {
                        self.pending = row;
                    } else {
                        row.deinit();
                        self.read_error = if (err == error.BatchFull) error.BatchBudgetExceeded else err;
                    }
                    break;
                };
                row.deinit();
            }
            self.physical.evaluate();
        }
        pub fn next(self: *Self) !?logical.Row {
            if (self.failed) return error.FailedQuery;
            if (self.complete) return null;
            errdefer self.failed = true;
            try self.disclose();
            const plan = self.physical.plan;
            while (true) {
                if (verification == .selected_prefix and self.atLimit()) break;
                if (self.index == self.physical.len) {
                    // Full-file verification still runs all conversions and EOF
                    // checks beyond LIMIT, without evaluating discarded operators.
                    if (verification == .full_source and self.atLimit() and self.pending == null and self.read_error == null) {
                        while (try self.scan.next()) |input| {
                            var row = input;
                            defer row.deinit();
                            self.scanned = try std.math.add(u64, self.scanned, 1);
                        }
                        break;
                    }
                    self.fill();
                    if (self.physical.len == 0) {
                        if (self.read_error) |err| {
                            if (@hasField(Scan, "rejection")) self.scan.rejection = self.read_rejection;
                            return err;
                        }
                        break;
                    }
                }
                const i = self.index;
                self.index += 1;
                self.scanned = try std.math.add(u64, self.scanned, 1);
                if (self.atLimit()) continue;
                switch (self.physical.outcomes[i]) {
                    .type_error, .conflict => |_, tag| {
                        const site = self.physical.predicateFailure(i);
                        self.capture(.predicate, site.column, i, site.instruction);
                        return if (tag == .type_error) error.QueryTypeError else error.QueryConflict;
                    },
                    .truth => |truth| if (!truth.selects()) continue,
                }
                self.selected = try std.math.add(u64, self.selected, 1);
                self.physical.selection[self.physical.selected] = i;
                self.physical.selected += 1;
                if (plan.aggregate == .count_values) {
                    self.value_count = @import("Finite.zig").countState(self.value_count, self.physical.columns[plan.projection[0]].states[i]) catch |err| {
                        self.capture(.count, plan.projection[0], i, null);
                        return err;
                    };
                }
                if (plan.aggregate == .sum) {
                    self.sum = @import("Finite.zig").sum(self.sum, self.physical.columns[plan.projection[0]].view(self.physical.len).cell(i), struct {
                        fn integer(value: types.Values.Value) !i64 {
                            return @intCast(value.atom.signed);
                        }
                    }.integer) catch |err| {
                        self.capture(.sum, plan.projection[0], i, null);
                        return err;
                    };
                }
                if (plan.aggregate == .rows) {
                    var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
                    errdefer arena.deinit();
                    const cells = try arena.allocator().alloc(Cell, plan.projection.len);
                    for (plan.projection, cells) |column, *cell| {
                        cell.* = try types.Values.cloneValidated(arena.allocator(), self.physical.columns[column].view(self.physical.len).cell(i));
                    }
                    try self.disclose();
                    self.emitted = try std.math.add(u64, self.emitted, 1);
                    return .{ .arena = arena, .cells = cells };
                }
            }
            if (!self.scan.complete and !(verification == .selected_prefix and self.atLimit())) return error.IncompleteSource;
            if (plan.aggregate != .rows) {
                var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
                errdefer arena.deinit();
                const cells = try arena.allocator().alloc(Cell, 1);
                cells[0] = try (logical.Counters{ .selected = self.selected, .value_count = self.value_count, .sum = self.sum }).result(plan.aggregate);
                try self.disclose();
                self.complete = true;
                self.emitted = 1;
                return .{ .arena = arena, .cells = cells };
            }
            try self.disclose();
            self.complete = true;
            return null;
        }
        fn disclose(self: *Self) !void {
            if (@hasDecl(Scan, "validateBatchDisclosure")) try self.scan.validateBatchDisclosure();
        }
        fn capture(self: *Self, operation: @FieldType(logical.Failure, "operation"), column: u8, row: usize, instruction: ?u8) void {
            const plan = self.physical.plan;
            const field = plan.schema.structure[column];
            const typed = @import("FileValueDiagnostic.zig").init(.{}, field.type, null);
            var detail: logical.Failure = .{
                .operation = operation,
                .row = self.scanned,
                .column_len = @intCast(@min(field.name.len, 128)),
                .column_truncated = field.name.len > 128,
                .expected = typed.expected,
                .expected_len = typed.expected_len,
                .state = self.physical.columns[column].states[row],
                .instruction = instruction,
                .binding = plan.source_basis,
                .plan = self.physical.fingerprint,
            };
            @memcpy(detail.column[0..detail.column_len], field.name[0..detail.column_len]);
            self.failure = detail;
        }
    };
}

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
        self.index += 1;
        return .{ .arena = arena, .cells = cells };
    }
};
const fixture_schema: types.Type = .{ .structure = &.{ .{ .name = "key", .type = .int64, .nullable = true, .optional = true }, .{ .name = "value", .type = .int64, .nullable = true, .optional = true } } };

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
