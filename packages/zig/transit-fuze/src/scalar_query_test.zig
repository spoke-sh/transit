const std = @import("std");
const f = @import("root.zig");
const t = std.testing;
const Cell = f.Types.Values.Cell;
fn decimal(value: i128) Cell {
    return .{ .value = .{ .atom = .{ .decimal = value } } };
}
fn boolean(value: bool) Cell {
    return .{ .value = .{ .atom = .{ .boolean = value } } };
}
const schema: f.Types.Type = .{ .structure = &.{
    .{ .name = "a", .type = .{ .decimal = .{ .precision = 8, .scale = 2 } }, .nullable = true },
    .{ .name = "b", .type = .{ .decimal = .{ .precision = 8, .scale = 2 } } },
    .{ .name = "keep", .type = .boolean },
} };
const Rows = struct {
    allocator: std.mem.Allocator,
    rows: []const [3]Cell,
    index: usize = 0,
    complete: bool = false,
    pub fn deinit(_: *Rows) void {}
    pub fn next(self: *Rows) !?f.LogicalQuery.Row {
        if (self.index == self.rows.len) {
            self.complete = true;
            return null;
        }
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const cells = try arena.allocator().dupe(Cell, &self.rows[self.index]);
        self.index += 1;
        return .{ .arena = arena, .cells = cells };
    }
};

test "scalar SQL executes after filters in pull and bounded batches with owned results" {
    var query = try f.TableSelect.compile(t.allocator, "SELECT DECIMAL_DIVIDE(a,b,8,2,HALF_EVEN) AS quotient FROM items WHERE keep = TRUE", "items", schema, @splat(7), null);
    defer query.deinit();
    const rows = [_][3]Cell{ .{ decimal(100), decimal(600), boolean(true) }, .{ .{ .type_error = .decimal }, decimal(0), boolean(false) }, .{ .null, decimal(600), boolean(true) } };
    inline for (.{ f.LogicalQuery.Execution(Rows, .full_source), f.BatchExecution.Execution(Rows, .full_source) }) |Execution| {
        var execution = try Execution.init(.{ .allocator = t.allocator, .rows = &rows }, query.plan);
        var result = (try execution.next()).?;
        defer result.deinit();
        var second = (try execution.next()).?;
        defer second.deinit();
        try t.expect((try execution.next()) == null);
        try t.expectEqual(@as(u64, 3), execution.scanned);
        execution.deinit();
        try t.expectEqualDeep(decimal(17), result.cells[0]);
        try t.expect(second.cells[0] == .null);
    }
    var fields: [128]f.Types.Field = undefined;
    const output = try query.plan.outputSchema(&fields);
    try t.expectEqualStrings("quotient", output.structure[0].name);
    try t.expectEqualDeep(schema.structure[0].type, output.structure[0].type);
    const traits = try f.OperatorTraits.forLogicalPlan(query.plan);
    try t.expect(traits.fallible and traits.deterministic);
    try t.expectEqual(.checked_scalar, traits.five_state_rule);
    try t.expect(!f.OperatorTraits.Summary.forExplain(traits).doesWork());
}

test "scalar plan codec owns nested instructions and rejects old definitions and forward references" {
    var query = try f.TableSelect.compile(t.allocator, "SELECT DECIMAL_RESCALE(DECIMAL_ADD(a,b,9,2,REJECT),8,1,HALF_EVEN) AS amount FROM items", "items", schema, @splat(7), null);
    defer query.deinit();
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const encoded = try f.LogicalPlanCodec.encode(query.plan, &bytes);
    var restored = try f.LogicalPlanCodec.decode(t.allocator, schema, @splat(7), encoded);
    defer restored.deinit();
    try t.expectEqual(try query.plan.fingerprint(), try restored.plan.fingerprint());
    const previous = std.crypto.hash.sha2.Sha256.hash;
    var old: [32]u8 = undefined;
    previous("transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters:collations", &old, .{});
    @memcpy(bytes[4..36], &old);
    try t.expectError(error.UnsupportedPlanDefinition, f.LogicalPlanCodec.decode(t.allocator, schema, @splat(7), encoded));
    @memset(&bytes, 0xaa);
    var work: f.ScalarProgram.Workspace = .{};
    try restored.plan.scalars.prepare(schema.structure, &work);
    const result = try restored.plan.materialize(&.{ decimal(125), decimal(100), boolean(true) }, &work);
    try t.expectEqualDeep(decimal(22), result[restored.plan.projection[0]]);
    var invalid = restored.plan;
    invalid.scalars.instructions = &.{.{ .decimal_rescale = .{ .value = 1, .result = .{ .precision = 8, .scale = 2 }, .rounding = .reject } }};
    try t.expectError(error.InvalidScalarReference, invalid.validate());
}

test "scalar SQL retains exact timezone metadata and refuses missing or mismatched rules" {
    const time_schema: f.Types.Type = .{ .structure = &.{.{ .name = "ts", .type = .{ .timestamp = .utc } }} };
    const rules = try f.PinnedTimezone.Descriptor.init("iana-2025b", "Etc/UTC", @embedFile("timezone-fixtures/utc.tzif"));
    const text = "SELECT ts AT TIME ZONE 'Etc/UTC' AS local, TIME_BUCKET(ts,1000000,'Etc/UTC') AS bucket, LOCAL_TO_UTC(ts AT TIME ZONE 'Etc/UTC','Etc/UTC',REJECT) AS original, TIME_BUCKET(LOCAL_TO_UTC(ts AT TIME ZONE 'Etc/UTC','Etc/UTC',REJECT),1000000,'Etc/UTC') AS nested_bucket FROM events";
    try t.expectError(error.MissingColumnSemantics, f.TableSelect.compile(t.allocator, text, "events", time_schema, @splat(8), null));
    var query = try f.TableSelect.compileSemantics(t.allocator, text, "events", time_schema, @splat(8), null, null, &.{.{ .timezone = rules }});
    defer query.deinit();
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var restored = try f.LogicalPlanCodec.decode(t.allocator, time_schema, @splat(8), try f.LogicalPlanCodec.encode(query.plan, &bytes));
    defer restored.deinit();
    var work: f.ScalarProgram.Workspace = .{};
    try restored.plan.scalars.prepare(time_schema.structure, &work);
    @memset(&bytes, 0);
    const result = try restored.plan.materialize(&.{.{ .value = .{ .atom = .{ .timestamp = -1 } } }}, &work);
    try t.expectEqual(@as(i64, -1), result[query.plan.projection[0]].value.atom.timestamp);
    try t.expectEqual(@as(i64, -1000000), result[query.plan.projection[1]].value.atom.timestamp);
    try t.expectEqual(@as(i64, -1), result[query.plan.projection[2]].value.atom.timestamp);
    try t.expectEqual(@as(i64, -1000000), result[query.plan.projection[3]].value.atom.timestamp);
    try t.expectError(error.TimezoneDefinitionMismatch, f.TableSelect.compileSemantics(t.allocator, "SELECT ts AT TIME ZONE 'America/New_York' FROM events", "events", time_schema, @splat(8), null, null, &.{.{ .timezone = rules }}));
}

test "scalar projection pruning remaps dependencies and preserves output and failures" {
    const table: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 5, .primary_key = &.{1}, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "unused", .type = .binary },
        .{ .id = 3, .name = "a", .type = schema.structure[0].type },
        .{ .id = 4, .name = "b", .type = schema.structure[1].type },
    } };
    var fields: [128]f.Types.Field = undefined;
    var query = try f.TableSelect.compile(t.allocator, "SELECT DECIMAL_DIVIDE(a,b,8,2,REJECT) AS q FROM items", "items", try table.rowType(&fields), @splat(9), null);
    defer query.deinit();
    const projection = try f.TableProjection.fromPlan(table, query.plan);
    try t.expectEqualSlices(u8, &.{ 0, 2, 3 }, projection.columns());
    var workspace: f.TableProjection.Workspace = .{};
    const remapped = try projection.remap(table, query.plan, &workspace);
    var output: [128]f.Types.Field = undefined;
    try t.expectEqual(try (try query.plan.outputSchema(&fields)).fingerprint(), try (try remapped.outputSchema(&output)).fingerprint());
    var work: f.ScalarProgram.Workspace = .{};
    try remapped.scalars.prepare(remapped.schema.structure, &work);
    const row = [_]Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, decimal(100), decimal(0) };
    try t.expectError(error.DivisionByZero, remapped.materialize(&row, &work));
    try t.expectEqual(@as(?u8, 2), work.failed);
}

test "scalar decimal SUM retains 38 digit precision and resumes exact source ordered progress" {
    var query = try f.TableSelect.compile(t.allocator, "SELECT SUM(DECIMAL_DIVIDE(a,b,8,2,HALF_EVEN)) AS total FROM items", "items", schema, @splat(7), null);
    defer query.deinit();
    const rows = [_][3]Cell{ .{ decimal(100), decimal(600), boolean(true) }, .{ .null, decimal(600), boolean(true) }, .{ decimal(100), decimal(600), boolean(true) } };
    inline for (.{ f.LogicalQuery.Execution(Rows, .full_source), f.BatchExecution.Execution(Rows, .full_source) }) |Execution| {
        var execution = try Execution.init(.{ .allocator = t.allocator, .rows = &rows }, query.plan);
        defer execution.deinit();
        var result = (try execution.next()).?;
        defer result.deinit();
        try t.expectEqualDeep(decimal(34), result.cells[0]);
        try t.expect((try execution.next()) == null);
    }
    var fields: [128]f.Types.Field = undefined;
    const output_type = try query.plan.outputSchema(&fields);
    try t.expectEqualDeep(f.Types.Type{ .decimal = .{ .precision = 38, .scale = 2 } }, output_type.structure[0].type);
    const stream = f.LogicalStream;
    const workspace = try t.allocator.alloc(u8, 256 * 1024);
    defer t.allocator.free(workspace);
    var output: [f.LogicalArrow.segment_bytes]u8 = undefined;
    var cancel = std.atomic.Value(bool).init(false);
    const start = try stream.Progress.start(query.plan);
    const first = try stream.step(query.plan, start, .{ .binding = query.plan.source_basis, .ordinal = 0, .end = false, .rows = &.{ .{ .cells = &rows[0] }, .{ .cells = &rows[1] } } }, workspace, &output, &cancel, null);
    try t.expect(first.segment == null);
    const saved = try first.progress.encode(query.plan);
    try t.expectEqual(@as(usize, 134), saved.len);
    const resumed = try stream.Progress.decode(query.plan, &saved);
    const last = try stream.step(query.plan, resumed, .{ .binding = query.plan.source_basis, .ordinal = 1, .end = true, .rows = &.{.{ .cells = &rows[2] }} }, workspace, &output, &cancel, null);
    var decoded = try f.LogicalInspect.decode(t.allocator, output_type, last.segment.?.bytes, 1, workspace);
    defer decoded.deinit();
    @memset(&output, 0);
    try t.expectEqualDeep(decimal(34), decoded.rows[0].cells[0]);
    var old: [126]u8 = @splat(0);
    @memcpy(old[0..4], "FQS1");
    try t.expectError(error.InvalidQueryProgress, stream.Progress.decode(query.plan, &old));
    const maximum: i128 = 99999999999999999999999999999999999999;
    try t.expectError(error.DecimalOverflow, f.LogicalQuery.Counters.addSum(maximum, output_type.structure[0].type, decimal(1)));
    try t.expectEqual(@as(?i128, maximum), try f.LogicalQuery.Counters.addSum(maximum, output_type.structure[0].type, .null));
}

test "scalar range ordering and vector metrics bind exact logical operands" {
    const range = f.Types.Type{ .range = &.int64 };
    const vector: f.Types.Type = .{ .vector = .{ .dimensions = 2, .element = .float32 } };
    const input: f.Types.Type = .{ .structure = &.{
        .{ .name = "a", .type = range },  .{ .name = "b", .type = range },
        .{ .name = "x", .type = vector }, .{ .name = "y", .type = vector },
    } };
    const text = "SELECT RANGE_ADJACENT(a,b) AS adjacent, RANGE_CONTAINS(a,b) AS contains, RANGE_OVERLAPS(a,b) AS overlaps, RANGE_COMPARE(a,b) AS ordering, VECTOR_DISTANCE(x,y) AS distance FROM items";
    var query = try f.TableSelect.compileSemantics(t.allocator, text, "items", input, @splat(9), null, null, &.{ .{}, .{}, .{ .metric = .l2_squared }, .{ .metric = .l2_squared } });
    defer query.deinit();
    var x: [8]u8 align(64) = .{ 0, 0, 0x80, 0x3f, 0, 0, 0, 0x40 }; // 1, 2
    var y: [8]u8 align(64) = .{ 0, 0, 0x80, 0x40, 0, 0, 0xc0, 0x40 }; // 4, 6
    const lower: @import("RangeValue.zig").Value = .{ .lower = .{ .value = .{ .signed = 1 }, .inclusive = true }, .upper = .{ .value = .{ .signed = 3 }, .inclusive = false } };
    const upper: @import("RangeValue.zig").Value = .{ .lower = .{ .value = .{ .signed = 3 }, .inclusive = true }, .upper = null };
    var work: f.ScalarProgram.Workspace = .{};
    try query.plan.scalars.prepare(input.structure, &work);
    const result = try query.plan.materialize(&.{ .{ .value = .{ .range = lower } }, .{ .value = .{ .range = upper } }, .{ .value = .{ .vector = &x } }, .{ .value = .{ .vector = &y } } }, &work);
    try t.expect(result[query.plan.projection[0]].value.atom.boolean);
    try t.expect(!result[query.plan.projection[1]].value.atom.boolean);
    try t.expect(!result[query.plan.projection[2]].value.atom.boolean);
    try t.expectEqual(@as(i128, -1), result[query.plan.projection[3]].value.atom.signed);
    try t.expectEqual(@as(f64, 25), result[query.plan.projection[4]].value.atom.float);
    try t.expectError(error.IncompatibleVectorMetric, f.TableSelect.compile(t.allocator, "SELECT VECTOR_DISTANCE(x,y,HAMMING) FROM items", "items", input, @splat(9), null));
}

test "scalar SQL corresponds to independent decimal and instruction byte oracles" {
    const Case = struct { sql: []const u8, a_precision: u8, a_scale: u8, b_precision: u8, b_scale: u8, a: []const u8, b: []const u8, expected: ?[]const u8, failure: ?[]const u8, program_hex: []const u8 };
    const Fixture = struct { oracle: []const u8, cases: []const Case };
    const fixtures = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/scalar-programs.json"), .{});
    defer fixtures.deinit();
    for (fixtures.value.cases) |case| {
        const input: f.Types.Type = .{ .structure = &.{
            .{ .name = "a", .type = .{ .decimal = .{ .precision = case.a_precision, .scale = case.a_scale } } },
            .{ .name = "b", .type = .{ .decimal = .{ .precision = case.b_precision, .scale = case.b_scale } } },
            .{ .name = "keep", .type = .boolean },
        } };
        var query = try f.TableSelect.compile(t.allocator, case.sql, "items", input, @splat(47), null);
        defer query.deinit();
        var bytes: [128]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try query.plan.scalars.write(&writer);
        var expected_bytes: [128]u8 = undefined;
        try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected_bytes, case.program_hex), writer.buffered());
        const rows = [_][3]Cell{.{ decimal(try std.fmt.parseInt(i128, case.a, 10)), decimal(try std.fmt.parseInt(i128, case.b, 10)), boolean(true) }};
        inline for (.{ f.LogicalQuery.Execution(Rows, .full_source), f.BatchExecution.Execution(Rows, .full_source) }) |Execution| {
            var execution = try Execution.init(.{ .allocator = t.allocator, .rows = &rows }, query.plan);
            defer execution.deinit();
            if (case.failure) |expected_error| {
                if (execution.next()) |unexpected| {
                    if (unexpected) |value| {
                        var row = value;
                        row.deinit();
                    }
                    return error.ExpectedScalarFailure;
                } else |err| try t.expectEqualStrings(expected_error, @errorName(err));
                try t.expectEqual(.projection, execution.failure.?.operation);
                try t.expectError(error.FailedQuery, execution.next());
            } else {
                var row = (try execution.next()).?;
                defer row.deinit();
                try t.expectEqualDeep(decimal(try std.fmt.parseInt(i128, case.expected.?, 10)), row.cells[0]);
                try t.expect((try execution.next()) == null);
            }
        }
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        const foreign = try f.QueryValues.Plan.fromNative(arena.allocator(), query.plan);
        const restored = try foreign.native(arena.allocator(), input, query.plan.source_basis);
        try t.expectEqual(try query.plan.fingerprint(), try restored.fingerprint());
    }
}

test "prepared scalar timezone plans own artifacts after preparation and binding close" {
    var artifacts: [@embedFile("timezone-fixtures/utc.tzif").len]u8 = @embedFile("timezone-fixtures/utc.tzif").*;
    const input: f.Types.Type = .{ .structure = &.{.{ .name = "ts", .type = .{ .timestamp = .utc } }} };
    const rules = try f.PinnedTimezone.Descriptor.init("iana-2025b", "Etc/UTC", &artifacts);
    var prepared = try f.LogicalPrepared.initSemantics(t.allocator, "SELECT TIME_BUCKET(ts,1000000,'Etc/UTC') AS bucket FROM events", "events", input, @splat(19), null, .transit, &.{.{ .timezone = rules }});
    var bound = blk: {
        defer prepared.deinit();
        @memset(&artifacts, 0);
        break :blk try prepared.instantiate(t.allocator, "events", input, @splat(19), @splat(21), &.{}, null);
    };
    defer bound.deinit();
    var work: f.ScalarProgram.Workspace = .{};
    try bound.plan.scalars.prepare(input.structure, &work);
    const cells = try bound.plan.materialize(&.{.{ .value = .{ .atom = .{ .timestamp = -1 } } }}, &work);
    try t.expectEqual(@as(i64, -1000000), cells[bound.plan.projection[0]].value.atom.timestamp);
    try t.expectEqual(@as([32]u8, @splat(21)), bound.plan.source_basis);
}
