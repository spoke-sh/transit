//! Pull execution over the shared SQL frontend plan.
const std = @import("std");
const sql = @import("transit_sql_frontend");
const types = sql.Types;
const values = types.Values;
pub const Row = sql.LogicalQuery.Row;
pub const Program = sql.LogicalQuery.Program;
pub const Plan = sql.LogicalQuery.Plan;
pub const Scalar = sql.LogicalQuery.Scalar;
pub const Failure = sql.LogicalQuery.Failure;
pub const Counters = sql.LogicalQuery.Counters;
pub const Verification = sql.LogicalQuery.Verification;
pub fn Execution(comptime Scan: type, comptime verification: Verification) type {
    return struct {
        const Self = @This();
        scan: Scan,
        plan: Plan,
        fingerprint: [32]u8,
        scanned: u64 = 0,
        selected: u64 = 0,
        value_count: u64 = 0,
        emitted: u64 = 0,
        sum: ?i128 = null,
        complete: bool = false,
        failed: bool = false,
        failure: ?Failure = null,
        scalar_work: Scalar.Workspace = .{},
        /// Takes ownership of scan only on success. The source owner must establish
        /// the schema and source-basis binding before entering this executor.
        pub fn init(scan: Scan, plan: Plan) !Self {
            var result: Self = .{ .scan = scan, .plan = plan, .fingerprint = try plan.fingerprint() };
            try plan.scalars.prepare(plan.schema.structure, &result.scalar_work);
            return result;
        }
        pub fn deinit(self: *Self) void {
            self.scan.deinit();
            self.* = undefined;
        }
        pub fn next(self: *Self) !?Row {
            if (self.failed) return error.FailedQuery;
            if (self.complete) return null;
            errdefer self.failed = true;
            if (!std.mem.eql(u8, &try self.plan.fingerprint(), &self.fingerprint)) return error.SourceChanged;
            while (if (verification == .selected_prefix and self.atLimit()) null else try self.scan.next()) |owned| {
                var row = owned;
                errdefer row.deinit();
                if (!try self.observe(row.cells)) {
                    row.deinit();
                    continue;
                }
                if (self.plan.aggregate == .rows) {
                    const projected = try row.arena.allocator().alloc(values.Cell, self.plan.projection.len);
                    for (self.plan.projection, projected) |index, *cell| cell.* = self.plan.evaluated(row.cells, &self.scalar_work)[index];
                    row.cells = projected;
                    self.emitted = try std.math.add(u64, self.emitted, 1);
                    return row;
                }
                row.deinit();
            }
            if (!self.scan.complete and !(verification == .selected_prefix and self.atLimit())) return error.IncompleteSource;
            if (self.plan.aggregate != .rows) {
                var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
                errdefer arena.deinit();
                const cells = try arena.allocator().alloc(values.Cell, 1);
                cells[0] = try self.counters().result(self.plan);
                self.complete = true;
                self.emitted = 1;
                return .{ .arena = arena, .cells = cells };
            }
            self.complete = true;
            return null;
        }
        fn atLimit(self: *const Self) bool {
            return if (self.plan.limit) |limit| self.selected == limit else false;
        }
        fn counters(self: *const Self) Counters {
            return .{ .scanned = self.scanned, .selected = self.selected, .value_count = self.value_count, .sum = self.sum };
        }
        fn observe(self: *Self, cells: []const values.Cell) !bool {
            var progress = self.counters();
            defer {
                self.scanned = progress.scanned;
                self.selected = progress.selected;
                self.value_count = progress.value_count;
                self.sum = progress.sum;
            }
            var failure: ?Counters.FailureSite = null;
            return progress.observePrepared(self.plan, cells, &self.scalar_work, &failure) catch |err| {
                // Capture the same one-based row before the deferred copy.
                self.scanned = progress.scanned;
                if (failure) |site| self.capture(site.operation, cells, site.column, site.instruction);
                return err;
            };
        }
        fn capture(self: *Self, operation: @FieldType(Failure, "operation"), cells: []const values.Cell, column: u8, instruction: ?u8) void {
            if (self.failure != null) return;
            const field = self.plan.inputField(column) catch return;
            const state = if (column < cells.len) std.meta.activeTag(cells[column]) else .value;
            self.failure = Failure.init(operation, self.scanned, field, state, instruction, self.plan.source_basis, self.fingerprint);
        }
    };
}
