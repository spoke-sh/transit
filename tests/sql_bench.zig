//! Pure SQL costs, isolated from source I/O and authority. No timing assertions.
const std = @import("std");
const f = @import("transit_fuze");
const m = f.Unified;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--count-values")) return countValues(init);
    if (args.len != 1) return error.Usage;
    const columns = [_]m.Column{
        .{ .name = try m.Name.init("id"), .type = .int64 },
        .{ .name = try m.Name.init("value"), .type = .int64 },
    };
    const source: m.Sql.Source = .{ .name = try m.Name.init("items"), .schema = .{ .columns = &columns } };
    const statements = [_][]const u8{
        "SELECT * FROM items",
        "SELECT value, id FROM items WHERE id >= -4 LIMIT 1024",
        "SELECT count(*) FROM items",
        "SELECT sum(chosen.value) FROM (SELECT value FROM items WHERE id > -8 LIMIT 1024) AS chosen",
    };
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var memory: [16384]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&memory);
    const iterations = 10000;
    for (statements, 0..) |sql, case| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            allocator.reset();
            const plan = try m.Sql.plan(allocator.allocator(), sql, source);
            std.mem.doNotOptimizeAway(plan);
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "compile", .case = case, .iterations = iterations, .elapsed_ns = elapsed }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    const mutation_target: f.TableMutation.Target = .{ .name = try f.model.Name.init("items"), .schema = .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("value") }, .value_type = .int64 } };
    for ([_][]const u8{
        "INSERT INTO items (id,value) VALUES(1,2),(2,NULL),(3,-9223372036854775808)",
        "UPDATE items SET value=12 WHERE id=9223372036854775807",
        "DELETE FROM items WHERE id=7",
    }, 0..) |sql, case| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const plan = try f.TableMutation.compile(sql, mutation_target);
            std.mem.doNotOptimizeAway(plan);
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "compile_mutation", .case = case, .iterations = iterations, .elapsed_ns = elapsed }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    for ([_][]const u8{
        "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
        "CREATE KV settings (UTF8)",
        "CREATE DOCUMENT notebook",
        "CREATE TABLE wide (a INT64,b BOOL,c UTF8,d BINARY,e INT64,f BOOL,g UTF8,h BINARY)",
    }, 0..) |sql, case| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const definition = try f.Declaration.compile(sql);
            std.mem.doNotOptimizeAway(definition);
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "compile_declaration", .case = case, .iterations = iterations, .elapsed_ns = elapsed }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    const workspace = try init.arena.allocator().alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var cells: [m.max_rows][2]m.Cell = undefined;
    var rows: [m.max_rows]m.Row = undefined;
    for (&rows, &cells, 0..) |*row, *values, i| {
        values.* = .{ .{ .value = .{ .int64 = @intCast(i) } }, .{ .value = .{ .int64 = 1 } } };
        row.* = .{ .cells = values };
    }
    const cancelled = f.execution.Cancellation.init(false);
    for ([_][]const u8{ "SELECT count(*) FROM items", "SELECT sum(value) FROM items" }, 0..) |sql, case| {
        allocator.reset();
        const plan = try m.Sql.plan(allocator.allocator(), sql, source);
        const bound = try plan.bind(.{ .kind = .table, .resource = 1, .revision = 1, .contract = @splat(1), .schema = try source.schema.fingerprint() }, source.schema);
        const start = std.Io.Clock.awake.now(init.io);
        for (0..100) |_| {
            var progress: m.Stream.Progress = .start(bound);
            for (0..1024) |page| {
                const result = try m.Stream.step(bound, progress, .{ .basis = bound.basis, .ordinal = page, .rows = &rows, .end = page == 1023 }, workspace, &output, &cancelled);
                progress = result.progress;
                if (result.segment) |segment| std.mem.doNotOptimizeAway(segment.bytes);
            }
            if (progress.scanned != 8192 or progress.rows != 1 or progress.finished != .source_end) return error.IncorrectResult;
            if (case == 1 and progress.sum != 8192) return error.IncorrectResult;
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "aggregate", .case = case, .iterations = 100, .rows_per_iteration = 8192, .elapsed_ns = elapsed }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}

/// New-capability costs are separate from the unchanged baseline workload.
/// A nullable fixture has two value cells, one null and one missing per four
/// inputs; both COUNT forms consume exactly the same bounded pages.
fn countValues(init: std.process.Init) !void {
    const values = [_]m.Scalar{ .{ .int64 = -1 }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = false }, .{ .utf8 = "" }, .{ .binary = "\x00\xff" } };
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var memory: [16384]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&memory);
    const workspace = try init.arena.allocator().alloc(u8, m.Arrow.working_bytes);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancelled = f.execution.Cancellation.init(false);
    for (values) |value| {
        const columns = [_]m.Column{.{ .name = try .init("value"), .type = std.meta.activeTag(value) }};
        const source: m.Sql.Source = .{ .name = try .init("items"), .schema = .{ .columns = &columns } };
        for ([_]bool{ false, true }) |mixed| {
            var cells: [m.max_rows][1]m.Cell = undefined;
            var rows: [m.max_rows]m.Row = undefined;
            for (&rows, &cells, 0..) |*row, *cell, i| {
                cell[0] = if (mixed and i % 4 < 2) (if (i % 4 == 0) .null else .missing) else .{ .value = value };
                row.* = .{ .cells = cell };
            }
            for ([_][]const u8{ "SELECT COUNT(*) FROM items", "SELECT COUNT(value) FROM items" }, 0..) |sql, kind| {
                const label = try std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}/{s}", .{ @tagName(value), if (mixed) "nullable" else "values", if (kind == 0) "rows" else "values" });
                const compile_iterations = 10000;
                const compile_start = std.Io.Clock.awake.now(init.io);
                for (0..compile_iterations) |_| {
                    allocator.reset();
                    std.mem.doNotOptimizeAway(try m.Sql.plan(allocator.allocator(), sql, source));
                }
                const compile_elapsed = compile_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
                try std.json.Stringify.value(.{ .phase = "compile", .case = label, .iterations = compile_iterations, .elapsed_ns = compile_elapsed }, .{}, &stdout.interface);
                try stdout.interface.writeByte('\n');
                allocator.reset();
                const plan = try m.Sql.plan(allocator.allocator(), sql, source);
                const bound = try plan.bind(.{ .kind = .table, .resource = 1, .revision = 1, .contract = @splat(1), .schema = try source.schema.fingerprint() }, source.schema);
                const expected: u64 = if (kind == 1 and mixed) 4096 else 8192;
                var final_bytes: []const u8 = &.{};
                const start = std.Io.Clock.awake.now(init.io);
                for (0..100) |_| {
                    var progress = m.Stream.Progress.start(bound);
                    for (0..1024) |page| {
                        const result = try m.Stream.step(bound, progress, .{ .basis = bound.basis, .ordinal = page, .rows = &rows, .end = page == 1023 }, workspace, &output, &cancelled);
                        progress = try m.Stream.Progress.decode(&try result.progress.encode());
                        if (result.segment) |segment| {
                            if (page != 1023) return error.IncorrectResult;
                            final_bytes = segment.bytes;
                            std.mem.doNotOptimizeAway(final_bytes);
                        }
                    }
                    if (progress.scanned != 8192 or progress.selected != 8192 or progress.rows != 1 or progress.finished != .source_end or progress.sum != null) return error.IncorrectResult;
                    if (progress.value_count != (if (kind == 1) expected else 0)) return error.IncorrectResult;
                }
                const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
                var output_columns: [m.max_columns]m.Column = undefined;
                const schema = try plan.outputSchema(source.schema, &output_columns);
                var decoded: m.Inspect.Batch = undefined;
                try m.Inspect.decode(schema, final_bytes, 1, workspace, init.arena.allocator(), &decoded);
                if ((try decoded.row(0)).cells[0].value.uint64 != expected) return error.IncorrectResult;
                try std.json.Stringify.value(.{ .phase = "aggregate_checkpoint", .case = label, .iterations = 100, .rows_per_iteration = 8192, .expected = expected, .elapsed_ns = elapsed }, .{}, &stdout.interface);
                try stdout.interface.writeByte('\n');
            }
        }
    }
    try stdout.interface.flush();
}
