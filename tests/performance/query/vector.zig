//! Decoded operators and owned-row pipeline, independently checked by vector.py.
const std = @import("std");
const f = @import("transit_fuze");
const Pool = @import("transit_query").ComputePool;
const Tracker = @import("Allocator.zig");
const Cell = f.Types.Values.Cell;
const fixture = @import("pipeline_fixture.zig");
const Scan = struct {
    allocator: std.mem.Allocator,
    rows: usize,
    case: fixture.Case = .int64,
    index: usize = 0,
    complete: bool = false,
    pub fn deinit(_: *Scan) void {}
    pub fn next(self: *Scan) !?f.LogicalQuery.Row {
        return self.nextAllocated(self.allocator);
    }
    pub fn nextAllocated(self: *Scan, row_allocator: std.mem.Allocator) !?f.LogicalQuery.Row {
        if (self.index == self.rows) {
            self.complete = true;
            return null;
        }
        var arena: std.heap.ArenaAllocator = .init(row_allocator);
        errdefer arena.deinit();
        const data = fixture.cells(self.case, self.index);
        const owned = try arena.allocator().dupe(Cell, &data);
        self.index += 1;
        return .{ .arena = arena, .cells = owned };
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5 and args.len != 6) return error.InvalidArguments;
    const mode = std.meta.stringToEnum(enum { scalar, batch, automatic, simd, avx2, parallel1, parallel2, parallel4 }, args[1]) orelse return error.InvalidArguments;
    const batched = mode != .scalar;
    const implementation: f.Batch.kernels.cpu.Implementation = if (mode == .batch) .portable else if (mode == .simd or mode == .avx2) .avx2 else .automatic;
    const workers: u8 = switch (mode) {
        .parallel1 => 1,
        .parallel2 => 2,
        .parallel4 => 4,
        else => 0,
    };
    const pool = if (workers != 0) try Pool.init(init.gpa, init.io, .{ .workers = workers, .minimum_work = 0 }) else null;
    defer if (pool) |owner| owner.deinit();
    const kernel = std.mem.eql(u8, args[2], "kernel");
    if (!kernel and !std.mem.eql(u8, args[2], "pipeline")) return error.InvalidArguments;
    const rows = try std.fmt.parseInt(usize, args[3], 10);
    const repetitions = try std.fmt.parseInt(usize, args[4], 10);
    if (rows == 0 or rows > 1048576 or repetitions == 0 or repetitions > 10000) return error.InvalidArguments;
    const case = if (args.len == 6) std.meta.stringToEnum(fixture.Case, args[5]) orelse return error.InvalidArguments else fixture.Case.int64;
    if (kernel and case != .int64) return error.InvalidArguments;
    var fields: [2]f.Types.Field = undefined;
    const plan = fixture.plan(case, fixture.schema(case, &fields));
    var tracker: Tracker = .{ .backing = init.gpa };
    const a = tracker.allocator();
    const decoded = try init.gpa.alloc([2]Cell, rows);
    defer init.gpa.free(decoded);
    for (decoded, 0..) |*row, i| row.* = fixture.cells(case, i);
    const integers = try init.gpa.alloc(i64, rows);
    defer init.gpa.free(integers);
    const states = try init.gpa.alloc(f.Types.State, rows);
    defer init.gpa.free(states);
    const details = try init.gpa.alloc(f.Batch.Detail, rows);
    defer init.gpa.free(details);
    @memset(details, .none);
    const outcomes = try init.gpa.alloc(f.Batch.Outcome, rows);
    defer init.gpa.free(outcomes);
    for (decoded, integers, states) |row, *value, *state| {
        state.* = std.meta.activeTag(row[0]);
        value.* = if (case == .int64 and row[0] == .value) @intCast(row[0].value.atom.signed) else 0;
    }
    var kernel_atom = f.Batch.kernels.Atom.bindType(.{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } }, .int64);
    kernel_atom.implementation = try f.Batch.kernels.cpu.resolve(implementation);
    const kernel_column: f.Batch.View = .{ .flat = .{ .type = .int64, .data = .{ .words = std.mem.bytesAsSlice(u64, std.mem.sliceAsBytes(integers)) }, .states = states, .details = details } };
    var count: u64 = 0;
    var checksum: i64 = 0;
    var first_ns: ?i96 = null;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..repetitions) |_| {
        if (kernel and batched) {
            // This measures already decoded columns. Packing is excluded here
            // and included in the separate complete owned-row pipeline below.
            kernel_atom.run(kernel_atom, kernel_column, 0, outcomes);
            for (outcomes, decoded) |outcome, row| {
                if (outcome.truth.selects()) {
                    count += 1;
                    checksum += @intCast(row[1].value.atom.signed);
                    if (first_ns == null) first_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
                }
            }
        } else if (kernel) {
            var progress: f.LogicalQuery.Counters = .{};
            for (decoded) |row| {
                var failure: ?f.LogicalQuery.Counters.FailureSite = null;
                if (try progress.observe(plan, &row, &failure)) {
                    count += 1;
                    checksum += @intCast(row[1].value.atom.signed);
                    if (first_ns == null) first_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
                }
            }
        } else inline for (.{ false, true }) |use_batch| selected_engine: {
            if (use_batch != batched) break :selected_engine;
            const Engine = if (use_batch) f.BatchExecution.Execution(Scan, .full_source) else f.LogicalQuery.Execution(Scan, .full_source);
            var execution = if (use_batch) try Engine.initBudget(.{ .allocator = a, .rows = rows, .case = case }, plan, .{ .implementation = implementation }) else try Engine.init(.{ .allocator = a, .rows = rows, .case = case }, plan);
            if (use_batch) if (pool) |owner| {
                execution.runner = owner.runner(null);
            };
            defer execution.deinit();
            while (try execution.next()) |item| {
                var row = item;
                defer row.deinit();
                count += 1;
                checksum += if (row.cells[0] == .null) 0 else if (case == .nested) @intCast(row.cells[0].value.atom.unsigned) else @intCast(row.cells[0].value.atom.signed);
                if (first_ns == null) first_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            }
            if (!execution.complete or execution.scanned != rows) return error.IncompleteSource;
        }
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{ .case = @tagName(case), .engine = args[1], .implementation = if (mode == .scalar) "reference" else @tagName(kernel_atom.implementation), .workers = workers, .pool_reserved_bytes = if (workers != 0) Pool.reservedBytes(workers) else 0, .phase = args[2], .rows = rows, .repetitions = repetitions, .count = count, .checksum = checksum, .elapsed_ns = elapsed, .first_ns = first_ns, .allocations = tracker.allocations, .allocated_bytes = tracker.allocated_bytes, .peak_live_bytes = tracker.peak_bytes, .end_live_bytes = tracker.live_bytes, .build_mode = @tagName(@import("builtin").mode) }, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
