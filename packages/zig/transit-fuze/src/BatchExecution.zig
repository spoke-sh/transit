//! Bounded typed pull execution. Source acquisition stays serial; read
//! failures are held behind the already acquired prefix's operator frontier.
const std = @import("std");
const batch = @import("Batch.zig");
const logical = @import("LogicalQuery.zig");
const types = @import("Types.zig");
const Cell = types.Values.Cell;
const RowAllocator = @import("RowAllocator.zig");

pub fn Execution(comptime Scan: type, comptime verification: logical.Verification) type {
    return struct {
        const Self = @This();
        scan: Scan,
        row_allocator: ?*RowAllocator = null,
        physical: batch,
        fingerprint: [32]u8,
        /// Optional public borrowed-plan contract; the physical program owns its copy.
        borrowed_plan: ?logical.Plan = null,
        runner: ?batch.Runner = null,
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
        pending_provenance: batch.Provenance = .{ .row = 1, .boundary = 1 },
        oversized: bool = false,
        read_error: ?anyerror = null,
        read_rejection: if (@hasField(Scan, "rejection")) @FieldType(Scan, "rejection") else void = if (@hasField(Scan, "rejection")) null else {},

        /// Takes ownership of scan only on success. Decoder/source and returned
        /// row budgets remain with their existing owners; limits bound compute.
        pub fn init(scan: Scan, plan: logical.Plan) !Self {
            return initBudget(scan, plan, .{});
        }
        pub fn initBudget(scan: Scan, plan: logical.Plan, limits: batch.Limits) !Self {
            var physical = try batch.init(scan.allocator, plan, limits);
            errdefer physical.deinit();
            const row_allocator = if (@hasDecl(Scan, "nextAllocated")) try RowAllocator.init(scan.allocator) else null;
            return .{ .scan = scan, .row_allocator = row_allocator, .physical = physical, .fingerprint = physical.fingerprint };
        }
        pub fn deinit(self: *Self) void {
            if (self.pending) |*row| row.deinit();
            self.physical.deinit();
            self.scan.deinit();
            if (self.row_allocator) |allocator| allocator.deinit();
            self.* = undefined;
        }
        fn atLimit(self: *const Self) bool {
            return if (self.physical.plan.limit) |limit| self.selected == limit else false;
        }
        fn acquire(self: *Self) !?logical.Row {
            if (@hasDecl(Scan, "nextAllocated")) return self.scan.nextAllocated(self.row_allocator.?.allocator());
            return self.scan.next();
        }
        fn fill(self: *Self) !void {
            self.physical.reset();
            self.index = 0;
            if (self.read_error != null) return;
            // Do not delay the first row behind a target-sized source read.
            var target = if (self.emitted < self.startup_rows and self.physical.plan.aggregate == .rows) 1 else self.physical.capacity;
            if (verification == .selected_prefix) if (self.physical.plan.limit) |limit| {
                target = @min(target, limit - self.selected);
            };
            while (self.physical.len < target) {
                const had_pending = self.pending != null;
                const acquired = if (self.pending) |row| held: {
                    self.pending = null;
                    break :held row;
                } else self.acquire() catch |err| {
                    self.read_error = err;
                    if (@hasField(Scan, "rejection")) {
                        self.read_rejection = self.scan.rejection;
                        self.scan.rejection = null;
                    }
                    break;
                };
                var row = acquired orelse break;
                const ordinal = std.math.add(u64, self.scanned, self.physical.len + 1) catch |err| {
                    row.deinit();
                    self.read_error = err;
                    break;
                };
                const provenance: batch.Provenance = if (had_pending) self.pending_provenance else .{ .row = ordinal, .boundary = ordinal, .identity = if (@hasDecl(Scan, "batchIdentity")) self.scan.batchIdentity() else null, .location = if (@hasDecl(Scan, "batchPosition")) self.scan.batchPosition() else null };
                self.physical.appendValidated(row.cells, provenance) catch |err| {
                    if (err == error.BatchFull) {
                        self.pending = row;
                        self.pending_provenance = provenance;
                        self.oversized = self.physical.len == 0;
                    } else {
                        row.deinit();
                        self.read_error = err;
                    }
                    break;
                };
                row.deinit();
            }
            if (self.runner) |runner| try runner.evaluate(runner.context, &self.physical, runner.cancellation) else self.physical.evaluate();
        }
        pub fn next(self: *Self) !?logical.Row {
            if (self.failed) return error.FailedQuery;
            if (self.complete) return null;
            errdefer self.failed = true;
            if (self.borrowed_plan) |borrowed| if (!std.mem.eql(u8, &try borrowed.fingerprint(), &self.fingerprint)) return error.SourceChanged;
            try self.disclose();
            const plan = self.physical.plan;
            while (true) {
                if (verification == .selected_prefix and self.atLimit()) break;
                if (self.index == self.physical.len) {
                    // Full-file verification still runs all conversions and EOF
                    // checks beyond LIMIT, without evaluating discarded operators.
                    if (verification == .full_source and self.atLimit() and self.pending == null and self.read_error == null) {
                        while (try self.acquire()) |input| {
                            var row = input;
                            defer row.deinit();
                            self.scanned = try std.math.add(u64, self.scanned, 1);
                        }
                        break;
                    }
                    try self.fill();
                    if (self.oversized) {
                        if (try self.consumeOversized()) |row| return row;
                        continue;
                    }
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
        /// A valid decoded row may exceed the physical payload reservation.
        /// Evaluate that one existing owner directly; never narrow admission or
        /// allocate a larger compute buffer to accommodate a pathological row.
        fn consumeOversized(self: *Self) !?logical.Row {
            var row = self.pending.?;
            self.pending = null;
            self.oversized = false;
            var returned = false;
            defer if (!returned) row.deinit();
            const plan = self.physical.plan;
            var counters: logical.Counters = .{ .scanned = self.scanned, .selected = self.selected, .value_count = self.value_count, .sum = self.sum };
            defer {
                self.scanned = counters.scanned;
                self.selected = counters.selected;
                self.value_count = counters.value_count;
                self.sum = counters.sum;
            }
            var site: ?logical.Counters.FailureSite = null;
            const selected = counters.observe(plan, row.cells, &site) catch |err| {
                self.scanned = counters.scanned;
                if (site) |failure| {
                    self.captureState(failure.operation, failure.column, std.meta.activeTag(row.cells[failure.column]), failure.instruction);
                    if (@hasDecl(Scan, "restoreBatchPosition")) if (self.pending_provenance.location) |position| self.scan.restoreBatchPosition(position);
                }
                return err;
            };
            if (!selected or plan.aggregate != .rows) return null;
            if (self.row_allocator != null) {
                var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
                errdefer arena.deinit();
                const projected = try arena.allocator().alloc(Cell, plan.projection.len);
                for (plan.projection, projected) |column, *cell| cell.* = try types.Values.cloneValidated(arena.allocator(), row.cells[column]);
                try self.disclose();
                self.emitted = try std.math.add(u64, self.emitted, 1);
                return .{ .arena = arena, .cells = projected };
            }
            const projected = try row.arena.allocator().alloc(Cell, plan.projection.len);
            for (plan.projection, projected) |column, *cell| cell.* = row.cells[column];
            row.cells = projected;
            try self.disclose();
            self.emitted = try std.math.add(u64, self.emitted, 1);
            returned = true;
            return row;
        }

        fn capture(self: *Self, operation: @FieldType(logical.Failure, "operation"), column: u8, row: usize, instruction: ?u8) void {
            self.captureState(operation, column, self.physical.columns[column].states[row], instruction);
            if (@hasDecl(Scan, "restoreBatchPosition")) if (self.physical.provenance[row].location) |position| self.scan.restoreBatchPosition(position);
        }
        fn captureState(self: *Self, operation: @FieldType(logical.Failure, "operation"), column: u8, state: types.State, instruction: ?u8) void {
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
                .state = state,
                .instruction = instruction,
                .binding = plan.source_basis,
                .plan = self.physical.fingerprint,
            };
            @memcpy(detail.column[0..detail.column_len], field.name[0..detail.column_len]);
            self.failure = detail;
        }
    };
}

test {
    _ = @import("batch_execution_test.zig");
}
