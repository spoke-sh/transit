//! Transit-authored component probes, not complete TPC workloads or durable I/O.
const std = @import("std");
const s = @import("transit_station");
const f = s.fuze;
const m = f.Unified;
const p = s.protocol;
const builtin = @import("builtin");
const Case = struct { id: []const u8, kind: enum { select, declaration, mutation }, source: []const u8, sql: []const u8 };
const Probe = struct { id: []const u8, kind: enum { select, declaration, table_schema, mutation }, sql: []const u8 };
const Config = struct {
    rows: usize,
    page_rows: usize,
    seed: u32,
    iterations: usize,
    compile_iterations: usize,
    verify_dir: ?[]const u8 = null,
    cases: []const Case,
    probes: []const Probe,
};
const Store = struct {
    table: s.Table,
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (key.eql(s.Table.descriptorKey(1))) return try s.Table.encodeSchema(self.table.schema);
        if (key.eql(s.Table.rowKey(1, 1))) return try self.table.encodeCell(.{ .int64 = 50 });
        if (key.eql(s.Table.rowKey(1, 2))) return try self.table.encodeCell(.null);
        return null;
    }
    fn turn(self: *Store) !s.Turn {
        return s.Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = 5, .revision = 0, .input = .{ .position = 4, .ordinal = 1, .value = .{}, .origin = .{ .external = .{ .principal = 9, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = 6, .pid = 2, .principal = 65536, .generation = 3, .input = 4, .process_revision = 0, .resource = 7, .revision = 0, .deadline_ms = 100 }, .{ .context = self, .read = read });
    }
};
fn emit(out: *std.Io.Writer, value: anytype) !void {
    try std.json.Stringify.value(value, .{}, out);
    try out.writeByte('\n');
}
fn elapsed(io: std.Io, start: std.Io.Timestamp) i96 {
    return start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
}
fn execute(io: std.Io, c: Config, index: usize, bound: m.Plan.Bound, workspace: []u8, output: []u8, verify: bool) !m.Stream.Progress {
    var progress: m.Stream.Progress = .start(bound);
    var offset: usize = 0;
    const cancelled = f.execution.Cancellation.init(false);
    while (progress.finished == null) {
        var cells: [m.max_rows][2]m.Cell = undefined;
        var rows: [m.max_rows]m.Row = undefined;
        const count = @min(c.page_rows, c.rows - offset);
        for (0..count) |i| {
            const n = offset + i;
            cells[i] = .{ .{ .value = .{ .int64 = @intCast(n) } }, if (n % 13 == 0) .null else .{ .value = .{ .int64 = @intCast((n * 17 + c.seed) % 101) } } };
            rows[i] = .{ .cells = &cells[i] };
        }
        const next = try m.Stream.step(bound, progress, .{ .basis = bound.basis, .ordinal = progress.pages, .rows = rows[0..count], .end = offset + count == c.rows }, workspace, output, &cancelled);
        if (next.segment) |segment| {
            std.mem.doNotOptimizeAway(segment.bytes);
            if (verify) {
                var path: [4096]u8 = undefined;
                const name = try std.fmt.bufPrint(&path, "{s}/{d}-{d}.arrow", .{ c.verify_dir.?, index, progress.segments });
                try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = name, .data = segment.bytes });
            }
        }
        progress = next.progress;
        offset += count;
    }
    return progress;
}
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 2) return error.Usage;
    const parsed = try std.json.parseFromSlice(Config, a, try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], a, .limited(1024 * 1024)), .{});
    const c = parsed.value;
    if (c.rows > 1000000 or c.page_rows == 0 or c.page_rows > m.max_rows or c.iterations == 0 or c.iterations > 1000 or c.compile_iterations == 0 or c.compile_iterations > 1000000 or c.cases.len > 128 or c.probes.len > 128) return error.InvalidBudget;
    var buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const out = &stdout.interface;
    try emit(out, .{ .kind = "metadata", .optimization = @tagName(builtin.mode), .compiler = builtin.zig_version_string, .workspace_bytes = m.Arrow.working_bytes, .segment_bytes = m.Arrow.segment_bytes });
    const columns = [_]m.Column{ .{ .name = try m.Name.init("id"), .type = .int64 }, .{ .name = try m.Name.init("quantity"), .type = .int64 } };
    const workspace = try a.alloc(u8, m.Arrow.working_bytes);
    const output = try a.alloc(u8, m.Arrow.segment_bytes);
    var memory: [16384]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&memory);
    for (c.cases, 0..) |case, index| {
        const source: m.Sql.Source = .{ .name = try m.Name.init(case.source), .schema = .{ .columns = &columns } };
        const schema: f.model.Schema = .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("quantity") }, .value_type = .int64 };
        const target: f.TableMutation.Target = .{ .name = try f.model.Name.init(case.source), .schema = schema };
        const start = std.Io.Clock.awake.now(init.io);
        for (0..c.compile_iterations) |_| {
            allocator.reset();
            switch (case.kind) {
                .select => std.mem.doNotOptimizeAway(try m.Sql.plan(allocator.allocator(), case.sql, source)),
                .declaration => std.mem.doNotOptimizeAway(try f.Declaration.compile(case.sql)),
                .mutation => std.mem.doNotOptimizeAway(try f.TableMutation.compile(case.sql, target)),
            }
        }
        try emit(out, .{ .id = case.id, .phase = "compile", .iterations = c.compile_iterations, .elapsed_ns = elapsed(init.io, start) });
        switch (case.kind) {
            .select => {
                allocator.reset();
                const plan = try m.Sql.plan(allocator.allocator(), case.sql, source);
                var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
                const restored = try m.Codec.decode(try m.Codec.encode(plan, &bytes));
                const bound = try restored.bind(.{ .kind = .table, .resource = 7, .revision = 1, .contract = @splat(1), .schema = try source.schema.fingerprint() }, source.schema);
                const verified = try execute(init.io, c, index, bound, workspace, output, c.verify_dir != null);
                const begin = std.Io.Clock.awake.now(init.io);
                for (0..c.iterations) |_| {
                    const result = try execute(init.io, c, index, bound, workspace, output, false);
                    if (!std.meta.eql(result, verified)) return error.UnstableResult;
                }
                try emit(out, .{ .id = case.id, .phase = "execute", .iterations = c.iterations, .elapsed_ns = elapsed(init.io, begin), .scanned = verified.scanned, .selected = verified.selected, .rows = verified.rows, .segments = verified.segments, .sum = verified.sum, .finished = verified.finished });
            },
            .declaration => {
                const definition = try f.Declaration.compile(case.sql);
                if (!std.meta.eql(schema, try definition.tableSchema())) return error.IncorrectSchema;
                var formatted: [4096]u8 = undefined;
                try emit(out, .{ .id = case.id, .phase = "verify_declaration", .formatted = try definition.format(&formatted) });
            },
            .mutation => {
                const plan = try f.TableMutation.compile(case.sql, target);
                var store: Store = .{ .table = .{ .id = 1, .resource = 7, .schema = schema } };
                var turn = try store.turn();
                const verified = try s.TableMutation.apply(&turn, store.table, plan);
                try emit(out, .{ .id = case.id, .phase = "verify_mutation", .affected = verified.affected_rows, .mutations = turn.decision.mutations });
                const begin = std.Io.Clock.awake.now(init.io);
                for (0..c.compile_iterations) |_| {
                    var next = try store.turn();
                    const result = try s.TableMutation.apply(&next, store.table, plan);
                    if (!std.meta.eql(next.decision, turn.decision) or result.affected_rows != verified.affected_rows) return error.UnstableMutation;
                    std.mem.doNotOptimizeAway(next.decision);
                }
                try emit(out, .{ .id = case.id, .phase = "propose_mutation", .iterations = c.compile_iterations, .elapsed_ns = elapsed(init.io, begin) });
            },
        }
    }
    const source: m.Sql.Source = .{ .name = try m.Name.init("stock"), .schema = .{ .columns = &columns } };
    const target: f.TableMutation.Target = .{ .name = try f.model.Name.init("stock"), .schema = .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("quantity") }, .value_type = .int64 } };
    for (c.probes) |probe| {
        allocator.reset();
        const rejection: ?anyerror = blk: {
            switch (probe.kind) {
                .select => _ = m.Sql.plan(allocator.allocator(), probe.sql, source) catch |err| break :blk err,
                .declaration => _ = f.Declaration.compile(probe.sql) catch |err| break :blk err,
                .table_schema => {
                    const definition = try f.Declaration.compile(probe.sql);
                    _ = definition.tableSchema() catch |err| break :blk err;
                },
                .mutation => _ = f.TableMutation.compile(probe.sql, target) catch |err| break :blk err,
            }
            break :blk null;
        };
        if (rejection) |err| {
            try emit(out, .{ .id = probe.id, .phase = "blocker_probe", .err = @errorName(err) });
        } else return error.CoverageNeedsReview;
    }
    try out.flush();
}
