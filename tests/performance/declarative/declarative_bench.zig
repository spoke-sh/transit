//! Transit-authored component probes, not complete TPC workloads or durable I/O.
const std = @import("std");
const s = @import("transit_station");
const f = s.fuze;
const m = f.Unified;
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
const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "quantity", .type = .int64 },
}, .primary_key = &.{1} };
const Store = struct {
    allocator: std.mem.Allocator,
    records: std.ArrayList([]u8) = .empty,
    fn deinit(self: *Store) void {
        for (self.records.items) |bytes| self.allocator.free(bytes);
        self.records.deinit(self.allocator);
    }
    pub fn save(self: *Store, spec: s.Publication.Spec, bytes: []const u8) !u64 {
        if (!std.meta.eql(spec, try s.Publication.Digest.of(spec.format, bytes))) return error.InvalidCommitment;
        const owned = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(owned);
        try self.records.append(self.allocator, owned);
        return self.records.items.len;
    }
    pub fn saveBlob(self: *Store, spec: s.Publication.Spec, bytes: []const u8) !u64 {
        return self.save(spec, bytes);
    }
    pub fn load(self: *Store, ref: s.ImmutableIndex.Reference, output: []u8) ![]const u8 {
        return self.loadBlob(.{ .id = ref.id, .spec = ref.spec }, output);
    }
    pub fn loadBlob(self: *Store, ref: s.TableData.Blob, output: []u8) ![]const u8 {
        if (ref.id == 0 or ref.id > self.records.items.len) return error.MissingRecord;
        const bytes = self.records.items[@intCast(ref.id - 1)];
        if (bytes.len > output.len) return error.BufferTooSmall;
        @memcpy(output[0..bytes.len], bytes);
        return output[0..bytes.len];
    }
    fn seed(self: *Store) !s.TableData {
        var data: s.TableData = .{ .schema = schema };
        for ([_]?i64{ 50, null }, 1..) |value, id| {
            const cells: [2]f.Types.Values.Cell = .{ .{ .value = .{ .atom = .{ .signed = id } } }, if (value) |number| .{ .value = .{ .atom = .{ .signed = number } } } else .null };
            data = (try data.insert(self.allocator, self, .{ .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(id) }, .cells = &cells })).data;
        }
        return data;
    }
};
const CandidateResult = struct { matched: u64 = 0, changed: u64 = 0, rows: [5]?[2]?i64 = @splat(null) };
/// Pure candidate construction and decoded result verification, not publication
/// or a captured/native turn. The fixture has two source rows and three inserts.
fn candidate(allocator: std.mem.Allocator, store: *Store, original: s.TableData, plan: f.TableDml.Plan) !CandidateResult {
    const first = store.records.items.len + 1;
    var overlay = try s.TableCandidate.Overlay(*Store).init(allocator, store, first, first + s.TableCandidate.max_records);
    defer overlay.deinit();
    var data = original;
    var result: CandidateResult = .{};
    switch (plan.action) {
        .insert => |input| for (input, 0..) |cells, ordinal| {
            const next = try data.insert(allocator, &overlay, .{ .identity = .{ .origin = 1, .operation = 2, .ordinal = @intCast(ordinal) }, .cells = cells });
            data = next.data;
            result.matched += next.matched;
            result.changed += next.changed;
        },
        .update, .delete => {
            var cursor: ?f.TableRow.Identity = null;
            while (try original.next(allocator, store, cursor)) |owned| {
                var source_row = owned;
                defer source_row.deinit();
                const row = source_row.row();
                cursor = row.identity;
                if (!try plan.matches(row.cells)) continue;
                var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
                const next = switch (plan.action) {
                    .update => |assignments| try data.update(allocator, &overlay, .{ .identity = row.identity, .cells = try schema.update(row.cells, assignments, &cells) }),
                    .delete => try data.delete(allocator, &overlay, row.identity),
                    else => unreachable,
                };
                data = next.data;
                result.matched += next.matched;
                result.changed += next.changed;
            }
        },
    }
    _ = try overlay.finish(data.index);
    var cursor: ?f.TableRow.Identity = null;
    var count: usize = 0;
    while (try data.next(allocator, &overlay, cursor)) |owned| {
        var output = owned;
        defer output.deinit();
        if (count == result.rows.len) return error.BenchmarkRowsExceeded;
        const row = output.row();
        cursor = row.identity;
        result.rows[count] = .{ @intCast(row.cells[0].value.atom.signed), if (row.cells[1] == .null) null else @intCast(row.cells[1].value.atom.signed) };
        count += 1;
    }
    return result;
}
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
        const start = std.Io.Clock.awake.now(init.io);
        for (0..c.compile_iterations) |_| {
            allocator.reset();
            switch (case.kind) {
                .select => std.mem.doNotOptimizeAway(try m.Sql.plan(allocator.allocator(), case.sql, source)),
                .declaration => {
                    var definition = try f.TableDdl.compile(allocator.allocator(), case.sql, null, null);
                    defer definition.deinit();
                    std.mem.doNotOptimizeAway(definition.statement);
                },
                .mutation => {
                    var compiled = try f.TableDml.compile(allocator.allocator(), case.sql, case.source, schema, null);
                    defer compiled.deinit();
                    std.mem.doNotOptimizeAway(compiled.plan);
                },
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
                var definition = try f.TableDdl.compile(init.gpa, case.sql, null, null);
                defer definition.deinit();
                const actual_schema = try definition.statement.create.bind(1);
                if (!std.mem.eql(u8, &try schema.fingerprint(), &try actual_schema.fingerprint())) return error.IncorrectSchema;
                var arena: std.heap.ArenaAllocator = .init(init.gpa);
                defer arena.deinit();
                try emit(out, .{ .id = case.id, .phase = "verify_declaration", .schema = try f.TableSchemaJson.foreign(&arena, actual_schema) });
            },
            .mutation => {
                var compiled = try f.TableDml.compile(init.gpa, case.sql, case.source, schema, null);
                defer compiled.deinit();
                var store: Store = .{ .allocator = init.gpa };
                defer store.deinit();
                const original = try store.seed();
                const verified = try candidate(init.gpa, &store, original, compiled.plan);
                try emit(out, .{ .id = case.id, .phase = "verify_mutation", .candidate = verified });
                const begin = std.Io.Clock.awake.now(init.io);
                for (0..c.compile_iterations) |_| {
                    const result = try candidate(init.gpa, &store, original, compiled.plan);
                    if (!std.meta.eql(result, verified)) return error.UnstableMutation;
                    std.mem.doNotOptimizeAway(result);
                }
                try emit(out, .{ .id = case.id, .phase = "build_candidate", .iterations = c.compile_iterations, .elapsed_ns = elapsed(init.io, begin) });
            },
        }
    }
    const source: m.Sql.Source = .{ .name = try m.Name.init("stock"), .schema = .{ .columns = &columns } };
    for (c.probes) |probe| {
        allocator.reset();
        const rejection: ?anyerror = blk: {
            switch (probe.kind) {
                .select => _ = m.Sql.plan(allocator.allocator(), probe.sql, source) catch |err| break :blk err,
                .declaration, .table_schema => {
                    var definition = f.TableDdl.compile(allocator.allocator(), probe.sql, null, null) catch |err| break :blk err;
                    defer definition.deinit();
                    _ = definition.statement.create.bind(1) catch |err| break :blk err;
                },
                .mutation => {
                    var compiled = f.TableDml.compile(allocator.allocator(), probe.sql, "stock", schema, null) catch |err| break :blk err;
                    defer compiled.deinit();
                },
            }
            break :blk null;
        };
        try emit(out, .{ .id = probe.id, .phase = "capability_probe", .err = if (rejection) |err| @errorName(err) else null });
    }
    try out.flush();
}
