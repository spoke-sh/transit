//! Identical driver for the current and origin/main specialized six-type path.
const std = @import("std");
const f = @import("transit_fuze");
const m = f.Unified;
pub fn main(init: std.process.Init) !void {
    const columns = [_]m.Column{
        .{ .name = try m.Name.init("i"), .type = .int64 },
        .{ .name = try m.Name.init("u"), .type = .uint64 },
        .{ .name = try m.Name.init("f"), .type = .float64 },
        .{ .name = try m.Name.init("b"), .type = .boolean },
        .{ .name = try m.Name.init("s"), .type = .utf8 },
        .{ .name = try m.Name.init("x"), .type = .binary },
    };
    const source: m.Sql.Source = .{ .name = try m.Name.init("items"), .schema = .{ .columns = &columns } };
    const workspace = try init.gpa.alloc(u8, m.Arrow.working_bytes);
    defer init.gpa.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var cells: [m.max_rows][6]m.Cell = undefined;
    var rows: [m.max_rows]m.Row = undefined;
    for (&rows, &cells, 0..) |*row, *values, i| {
        values.* = .{ .{ .value = .{ .int64 = @intCast(i) } }, .{ .value = .{ .uint64 = std.math.maxInt(u64) } }, .{ .value = .{ .float64 = -0.0 } }, .{ .value = .{ .boolean = true } }, .{ .value = .{ .utf8 = "λ exact" } }, .{ .value = .{ .binary = "\x00\xff" } } };
        row.* = .{ .cells = values };
    }
    const statements = [_][]const u8{
        "SELECT * FROM items",
        "SELECT count(*) FROM items WHERE i >= 4",
        "SELECT count(*) FROM items WHERE u = '18446744073709551615'::uint64",
        "SELECT count(*) FROM items WHERE f = '-0.0'::float64",
        "SELECT count(*) FROM items WHERE b = TRUE",
        "SELECT count(*) FROM items WHERE s = 'λ exact'",
        "SELECT count(*) FROM items WHERE x = '\\x00ff'::bytea",
        "SELECT sum(i) FROM items",
    };
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const cancelled = f.execution.Cancellation.init(false);
    for (statements, 0..) |sql, index| {
        var arena: std.heap.ArenaAllocator = .init(init.gpa);
        defer arena.deinit();
        const plan = try m.Sql.plan(arena.allocator(), sql, source);
        const bound = try plan.bind(.{ .kind = .table, .resource = 1, .revision = 1, .contract = @splat(1), .schema = try source.schema.fingerprint() }, source.schema);
        const iterations = 64;
        const pages = 128;
        const start = std.Io.Clock.awake.now(init.io);
        var bytes: u64 = 0;
        for (0..iterations) |_| {
            var progress: m.Stream.Progress = .start(bound);
            for (0..pages) |page| {
                const result = try m.Stream.step(bound, progress, .{ .basis = bound.basis, .ordinal = page, .rows = &rows, .end = page == pages - 1 }, workspace, &output, &cancelled);
                progress = result.progress;
                if (result.segment) |segment| {
                    bytes += segment.bytes.len;
                    std.mem.doNotOptimizeAway(segment.bytes);
                }
            }
            if (progress.scanned != pages * m.max_rows or progress.rows != (if (index == 0) @as(u64, pages * m.max_rows) else 1) or progress.finished != .source_end) return error.IncorrectResult;
            if (progress.selected != pages * (if (index == 1) @as(u64, 4) else m.max_rows)) return error.IncorrectSelection;
            if (index == 7 and progress.sum != 28 * pages) return error.IncorrectSum;
        }
        const ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .sql = sql, .iterations = iterations, .pages = pages, .rows_per_page = m.max_rows, .selected_per_iteration = pages * (if (index == 1) @as(u64, 4) else m.max_rows), .elapsed_ns = ns, .export_bytes = bytes, .build_mode = @tagName(@import("builtin").mode) }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
