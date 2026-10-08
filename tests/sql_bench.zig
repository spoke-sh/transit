//! Pure SQL costs, isolated from source I/O and authority. No timing assertions.
const std = @import("std");
const f = @import("transit_fuze");
const q = @import("transit_query");
const m = f.Unified;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--count-values")) return countValues(init);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--parameters")) return parameters(init);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--parameter-callers")) return parameterCallers(init);
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
    const mutation_schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "value", .type = .int64 },
    }, .primary_key = &.{1} };
    for ([_][]const u8{
        "INSERT INTO items (id,value) VALUES(1,2),(2,NULL),(3,-9223372036854775808)",
        "UPDATE items SET value=12 WHERE id=9223372036854775807",
        "DELETE FROM items WHERE id=7",
    }, 0..) |sql, case| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            allocator.reset();
            var compiled = try f.TableDml.compile(allocator.allocator(), sql, "items", mutation_schema, null);
            defer compiled.deinit();
            std.mem.doNotOptimizeAway(compiled.plan);
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "compile_mutation", .contract = "general-table-ddl-dml", .case = case, .iterations = iterations, .elapsed_ns = elapsed }, .{}, &stdout.interface);
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
            allocator.reset();
            if (std.mem.startsWith(u8, sql, "CREATE TABLE")) {
                var definition = try f.TableDdl.compile(allocator.allocator(), sql, null, null);
                defer definition.deinit();
                std.mem.doNotOptimizeAway(definition.statement);
            } else {
                std.mem.doNotOptimizeAway(try f.Declaration.compile(sql));
            }
        }
        const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        try std.json.Stringify.value(.{ .phase = "compile_declaration", .contract = "general-table-ddl-dml", .case = case, .iterations = iterations, .elapsed_ns = elapsed }, .{}, &stdout.interface);
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

/// Measure preparation and repeated binding separately from ordinary literal
/// compilation. Every equivalent plan's bytes are checked before timing.
fn parameters(init: std.process.Init) !void {
    const values = [_]m.Scalar{ .{ .int64 = -1 }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = true }, .{ .utf8 = "it's 東京" }, .{ .binary = "\x00\xff" } };
    const literals = [_][]const u8{ "-1", "'18446744073709551615'::uint64", "'-0.0'::float64", "TRUE", "'it''s 東京'", "'\\x00ff'::bytea" };
    const sql = "SELECT value AS chosen FROM items WHERE value >= $1 LIMIT $2";
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var memory: [16384]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&memory);
    const iterations = 10000;
    for (values, literals) |value, literal| {
        const columns = [_]m.Column{.{ .name = try .init("value"), .type = std.meta.activeTag(value) }};
        const source: m.Sql.Source = .{ .name = try .init("items"), .schema = .{ .columns = &columns } };
        const ordinary = try std.fmt.allocPrint(init.arena.allocator(), "SELECT value AS chosen FROM items WHERE value >= {s} LIMIT 1024", .{literal});
        var prepared = try f.Prepared.init(init.gpa, sql, source);
        defer prepared.deinit();
        var bound = try prepared.bind(init.gpa, source, &.{ value, .{ .uint64 = 1024 } });
        defer bound.deinit();
        allocator.reset();
        const expected = try m.Sql.plan(allocator.allocator(), ordinary, source);
        var expected_bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        var actual_bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        const canonical = try m.Codec.encode(expected, &expected_bytes);
        if (!std.mem.eql(u8, canonical, try m.Codec.encode(bound.plan, &actual_bytes))) return error.IncorrectParameterPlan;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(canonical, &digest, .{});
        inline for (.{ "literal_compile", "template_prepare", "template_bind" }) |phase| {
            const start = std.Io.Clock.awake.now(init.io);
            for (0..iterations) |_| {
                allocator.reset();
                if (comptime std.mem.eql(u8, phase, "literal_compile")) {
                    std.mem.doNotOptimizeAway(try m.Sql.plan(allocator.allocator(), ordinary, source));
                } else if (comptime std.mem.eql(u8, phase, "template_prepare")) {
                    var template = try f.Prepared.init(allocator.allocator(), sql, source);
                    std.mem.doNotOptimizeAway(template.prototype);
                    template.deinit();
                } else {
                    var binding = try prepared.bind(allocator.allocator(), source, &.{ value, .{ .uint64 = 1024 } });
                    std.mem.doNotOptimizeAway(binding.plan);
                    binding.deinit();
                }
            }
            const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            try std.json.Stringify.value(.{ .phase = phase, .case = @tagName(value), .iterations = iterations, .elapsed_ns = elapsed, .plan_sha256 = digest }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
        }
    }
    try stdout.interface.flush();
}

const CompilationClient = struct {
    reads: usize = 0,
    pub fn describe(self: *@This(), definition: q.SourceDefinition) !q.UnifiedClient.Description {
        self.reads += 1;
        return .{ .definition = definition, .resource_revision = 1, .policy_revision = 1, .limits = .{ .pages = 100, .segments = 100, .result_bytes = 1048576 }, .active = null };
    }
};

/// Source/parameter conversion, complete source binding and owned neutral
/// results, including two stub description checks. No signing/network latency.
fn parameterCallers(init: std.process.Init) !void {
    const values = [_]m.Scalar{ .{ .int64 = -1 }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = true }, .{ .utf8 = "it's 東京" }, .{ .binary = "\x00\xff" } };
    const literals = [_][]const u8{ "-1", "18446744073709551615", "-0.0", "TRUE", "'it''s 東京'", "X'00ff'" };
    var output: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &output);
    var memory: [65536]u8 = undefined;
    var arena = std.heap.FixedBufferAllocator.init(&memory);
    const iterations = 10000;
    const foreign_values = [_]q.Values.Scalar{ .{ .signed = "-1" }, .{ .unsigned = "18446744073709551615" }, .{ .float_bits = "0000000000000080" }, .{ .boolean = true }, .{ .utf8 = "it's 東京" }, .{ .binary = "00ff" } };
    for (values, literals, foreign_values) |value, literal, foreign_value| {
        const ordinary = try std.fmt.allocPrint(init.arena.allocator(), "SELECT value AS chosen FROM items WHERE value >= {s} LIMIT 1024", .{literal});
        const parameters_wire = [_]q.Values.Scalar{ foreign_value, .{ .unsigned = "1024" } };
        const scope: q.SqlInspection.Scope = .{ .name = "items", .source = .{ .resource = 7, .source = .{ .kv = .{ .prefix = "646174612f", .key = .{ .type = .int64 }, .value = .{ .type = std.meta.activeTag(value) } } } }, .limits = .{ .pages = "100", .segments = "100", .result_bytes = "1048576" } };
        const literal_request: q.SqlCompilation.Request = .{ .scope = scope, .sql = ordinary };
        const parameter_request: q.SqlCompilation.Request = .{ .scope = scope, .sql = "SELECT value AS chosen FROM items WHERE value >= $1 LIMIT $2", .parameters = &parameters_wire };
        var checked: CompilationClient = .{};
        const expected = try q.SqlCompilation.apply(init.arena.allocator(), &checked, literal_request);
        const bound = try q.SqlCompilation.apply(init.arena.allocator(), &checked, parameter_request);
        if (!std.mem.eql(u8, expected.bundle, bound.bundle) or checked.reads != 4) return error.IncorrectParameterBundle;
        const canonical = try q.Values.unhex(init.arena.allocator(), bound.bundle, q.Bundle.max_bytes);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(canonical, &digest, .{});
        inline for (.{ "literal_neutral", "parameter_neutral" }) |phase| {
            var client: CompilationClient = .{};
            const request = if (comptime std.mem.eql(u8, phase, "literal_neutral")) literal_request else parameter_request;
            const start = std.Io.Clock.awake.now(init.io);
            for (0..iterations) |_| {
                arena.reset();
                const result = try q.SqlCompilation.apply(arena.allocator(), &client, request);
                std.mem.doNotOptimizeAway(result);
            }
            const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            if (client.reads != iterations * 2) return error.IncorrectDescriptionCount;
            try std.json.Stringify.value(.{ .phase = phase, .case = @tagName(value), .iterations = iterations, .elapsed_ns = elapsed, .bundle_sha256 = digest, .description_reads_per_iteration = 2 }, .{}, &stdout.interface);
            try stdout.interface.writeByte('\n');
        }
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
