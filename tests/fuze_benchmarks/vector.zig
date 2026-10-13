//! Decoded operators and owned-row pipeline, independently checked by vector.py.
const std = @import("std");
const f = @import("transit_fuze");
const Tracker = @import("Allocator.zig");
const Cell = f.Types.Values.Cell;
const schema: f.Types.Type = .{ .structure = &.{
    .{ .name = "key", .type = .int64, .nullable = true, .optional = true },
    .{ .name = "payload", .type = .int64 },
} };
fn cells(i: usize) [2]Cell {
    return .{
        if (i % 13 == 0) .null else if (i % 17 == 0) .missing else .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(i % 101)) - 50 } } },
        .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(i)) * 3 - 7 } } },
    };
}
const Scan = struct {
    allocator: std.mem.Allocator,
    rows: usize,
    index: usize = 0,
    complete: bool = false,
    pub fn deinit(_: *Scan) void {}
    pub fn next(self: *Scan) !?f.LogicalQuery.Row {
        if (self.index == self.rows) {
            self.complete = true;
            return null;
        }
        var arena: std.heap.ArenaAllocator = .init(self.allocator);
        errdefer arena.deinit();
        const data = cells(self.index);
        const owned = try arena.allocator().dupe(Cell, &data);
        self.index += 1;
        return .{ .arena = arena, .cells = owned };
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.InvalidArguments;
    const batched = std.mem.eql(u8, args[1], "batch");
    if (!batched and !std.mem.eql(u8, args[1], "scalar")) return error.InvalidArguments;
    const kernel = std.mem.eql(u8, args[2], "kernel");
    if (!kernel and !std.mem.eql(u8, args[2], "pipeline")) return error.InvalidArguments;
    const rows = try std.fmt.parseInt(usize, args[3], 10);
    const repetitions = try std.fmt.parseInt(usize, args[4], 10);
    if (rows == 0 or rows > 1048576 or repetitions == 0 or repetitions > 10000) return error.InvalidArguments;
    const plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(71), .projection = &.{1}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    var tracker: Tracker = .{ .backing = init.gpa };
    const a = tracker.allocator();
    const decoded = try init.gpa.alloc([2]Cell, rows);
    defer init.gpa.free(decoded);
    for (decoded, 0..) |*row, i| row.* = cells(i);
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
        value.* = if (row[0] == .value) @intCast(row[0].value.atom.signed) else 0;
    }
    var count: u64 = 0;
    var checksum: i64 = 0;
    var first_ns: ?i96 = null;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..repetitions) |_| {
        if (kernel and batched) {
            // This measures already decoded columns. Packing is excluded here
            // and included in the separate complete owned-row pipeline below.
            f.Batch.compare(.{ .flat = .{ .values = integers, .states = states, .details = details } }, 0, .ge, outcomes);
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
            var execution = try Engine.init(.{ .allocator = a, .rows = rows }, plan);
            defer execution.deinit();
            while (try execution.next()) |item| {
                var row = item;
                defer row.deinit();
                count += 1;
                checksum += @intCast(row.cells[0].value.atom.signed);
                if (first_ns == null) first_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            }
            if (!execution.complete or execution.scanned != rows) return error.IncompleteSource;
        }
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{ .engine = args[1], .phase = args[2], .rows = rows, .repetitions = repetitions, .count = count, .checksum = checksum, .elapsed_ns = elapsed, .first_ns = first_ns, .allocations = tracker.allocations, .allocated_bytes = tracker.allocated_bytes, .peak_live_bytes = tracker.peak_bytes, .end_live_bytes = tracker.live_bytes, .build_mode = @tagName(@import("builtin").mode) }, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
