const std = @import("std");
const t = std.testing;
const m = @import("Unified.zig");
const columns = [_]m.Column{
    .{ .name = m.Name.init("key") catch unreachable, .type = .uint64 },
    .{ .name = m.Name.init("value") catch unreachable, .type = .utf8 },
};
const schema: m.Schema = .{ .columns = &columns };
fn basis(kind: m.SourceKind) !m.Basis {
    return .{ .kind = kind, .resource = 17, .revision = 29, .contract = @splat(7), .schema = try schema.fingerprint() };
}
test "unified model keeps absent null type-error value and conflict distinct" {
    const alternatives = [_]m.Alternative{
        .{ .counter = 5, .replica = 1, .value = .{ .value = .{ .utf8 = "left🙂" } } },
        .{ .counter = 5, .replica = 2, .value = .null },
        .{ .counter = 6, .replica = 1, .value = .{ .type_error = .list } },
    };
    const cells = [_]m.Cell{ .missing, .null, .{ .type_error = .map }, .{ .value = .{ .utf8 = "" } }, .{ .conflict = &alternatives } };
    for (cells, 0..) |cell, index| {
        try cell.validate(.utf8);
        const plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .state = .{ .column = 0, .value = @fromBackingInt(@intCast(index)) } } };
        for (cells, 0..) |candidate, other| {
            const row: m.Row = .{ .cells = &.{candidate} };
            try t.expectEqual(index == other, try plan.matches(row));
            try t.expectEqual(if (index == other) m.Truth.true_value else m.Truth.false_value, try plan.predicateTruth(row));
        }
    }
    const comparison: m.Plan = .{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .utf8 = "" } } } };
    try t.expect(!try comparison.matches(.{ .cells = &.{.missing} }));
    try t.expect(!try comparison.matches(.{ .cells = &.{.null} }));
    for ([_]m.Cell{ .missing, .null }) |cell| {
        const truth = try comparison.predicateTruth(.{ .cells = &.{cell} });
        try t.expectEqual(m.Truth.unknown, truth);
        // A negated comparison must not accidentally select absent values.
        try t.expect(!truth.negate().selects());
    }
    try t.expectError(error.QueryTypeError, comparison.matches(.{ .cells = &.{cells[2]} }));
    try t.expectError(error.QueryConflict, comparison.matches(.{ .cells = &.{cells[4]} }));
    try t.expectError(error.QueryTypeError, comparison.predicateTruth(.{ .cells = &.{cells[2]} }));
    try t.expectError(error.QueryConflict, comparison.predicateTruth(.{ .cells = &.{cells[4]} }));
    try t.expectError(error.InvalidConflict, (m.Cell{ .conflict = alternatives[0..1] }).validate(.utf8));
    const reversed = [_]m.Alternative{ alternatives[1], alternatives[0] };
    try t.expectError(error.InvalidConflict, (m.Cell{ .conflict = &reversed }).validate(.utf8));
}
test "predicate truth preserves typed ordering and filter decisions for every comparison" {
    const pairs = [_][2]m.Scalar{
        .{ .{ .int64 = std.math.minInt(i64) }, .{ .int64 = std.math.maxInt(i64) } },
        .{ .{ .uint64 = 1 << 63 }, .{ .uint64 = std.math.maxInt(u64) } },
        .{ .{ .float64 = -1.5 }, .{ .float64 = 2.5 } },
        .{ .{ .boolean = false }, .{ .boolean = true } },
        .{ .{ .utf8 = "a" }, .{ .utf8 = "🙂" } },
        .{ .{ .binary = &.{0} }, .{ .binary = &.{ 0, 255 } } },
    };
    // Columns are less, equal and greater, respectively. Expected results are
    // literal comparison tables, independent of Scalar.order's implementation.
    const cases = [_]struct { op: m.Plan.Comparison, expected: [3]bool }{
        .{ .op = .eq, .expected = .{ false, true, false } },
        .{ .op = .ne, .expected = .{ true, false, true } },
        .{ .op = .lt, .expected = .{ true, false, false } },
        .{ .op = .le, .expected = .{ true, true, false } },
        .{ .op = .gt, .expected = .{ false, false, true } },
        .{ .op = .ge, .expected = .{ false, true, true } },
    };
    for (pairs) |pair| {
        const input: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = std.meta.activeTag(pair[0]) }} };
        const operands = [_][2]m.Scalar{ .{ pair[0], pair[1] }, .{ pair[0], pair[0] }, .{ pair[1], pair[0] } };
        for (cases) |case| for (operands, case.expected) |values, expected| {
            const plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = case.op, .value = values[1] } } };
            try plan.validate(input);
            const row: m.Row = .{ .cells = &.{.{ .value = values[0] }} };
            try t.expectEqual(if (expected) m.Truth.true_value else m.Truth.false_value, try plan.predicateTruth(row));
            try t.expectEqual(expected, try plan.matches(row));
        };
    }
}
test "predicate truth does not turn malformed inputs or evaluated errors into unknown" {
    const comparison: m.Plan = .{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = 1 } } } };
    const state: m.Plan = .{ .projection = &.{0}, .predicate = .{ .state = .{ .column = 0, .value = .missing } } };
    for ([_]m.Plan{ comparison, state }) |plan| {
        try t.expectError(error.UnknownColumn, plan.predicateTruth(.{ .cells = &.{} }));
        try t.expectError(error.UnknownColumn, plan.matches(.{ .cells = &.{} }));
    }
    const wrong: m.Row = .{ .cells = &.{.{ .value = .{ .uint64 = 1 } }} };
    try t.expectError(error.TypeMismatch, comparison.predicateTruth(wrong));
    try t.expectError(error.TypeMismatch, comparison.matches(wrong));
    const all: m.Plan = .{ .projection = &.{0} };
    for ([_]m.Cell{ .missing, .null, .{ .type_error = .map } }) |cell| {
        try t.expectEqual(m.Truth.true_value, try all.predicateTruth(.{ .cells = &.{cell} }));
    }
}
test "one typed plan binds all source kinds and exact contract and schema evidence" {
    const plan: m.Plan = .{ .projection = &.{ 1, 0 }, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .uint64 = std.math.maxInt(u64) } } } };
    for ([_]m.SourceKind{ .kv, .table, .document }) |kind| {
        const bound = try plan.bind(try basis(kind), schema);
        try t.expectEqual(kind, bound.basis.kind);
        const cells = [_]m.Cell{ .{ .value = .{ .uint64 = std.math.maxInt(u64) } }, .{ .value = .{ .utf8 = "🙂" } } };
        try (m.Page{ .basis = bound.basis, .ordinal = 0, .rows = &.{.{ .cells = &cells }}, .end = true }).validate(schema);
        try t.expect(try bound.plan.matches(.{ .cells = &cells }));
    }
    var invalid = try basis(.kv);
    invalid.schema[0] ^= 1;
    try t.expectError(error.SourceChanged, plan.bind(invalid, schema));
    try t.expectError(error.TypeMismatch, (m.Plan{ .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = -1 } } } }).bind(try basis(.kv), schema));
    try t.expectError(error.UnsupportedAggregate, (m.Plan{ .projection = &.{0}, .aggregate = .sum }).bind(try basis(.kv), schema));
    try t.expectError(error.DuplicateProjection, (m.Plan{ .projection = &.{ 0, 0 } }).bind(try basis(.kv), schema));
}
test "output schema is validated without a source cut and owns column names" {
    var output: [m.max_columns]m.Column = undefined;
    const projected = try (m.Plan{ .projection = &.{ 1, 0 } }).outputSchema(schema, &output);
    try t.expectEqualDeep(columns[1], projected.columns[0]);
    try t.expectEqualDeep(columns[0], projected.columns[1]);
    const count = try (m.Plan{ .projection = &.{0}, .aggregate = .count }).outputSchema(schema, &output);
    try t.expectEqualStrings("count", count.columns[0].name.slice());
    try t.expectEqual(m.Type.uint64, count.columns[0].type);
    try t.expectError(error.UnsupportedAggregate, (m.Plan{ .projection = &.{1}, .aggregate = .sum }).outputSchema(schema, &output));
    try t.expectError(error.DuplicateProjection, (m.Plan{ .projection = &.{ 0, 0 } }).outputSchema(schema, &output));
    try t.expectError(error.UnknownColumn, (m.Plan{ .projection = &.{2}, .aggregate = .count }).outputSchema(schema, &output));
}
test "canonical FZP1 preserves wide literals negative zero binary and larger plans" {
    const long: [512]u8 = @splat('x');
    const values = [_]m.Scalar{ .{ .int64 = std.math.minInt(i64) }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = false }, .{ .utf8 = "🙂" }, .{ .binary = &.{ 0, 255 } }, .{ .utf8 = &long } };
    for (values) |value| {
        const plan: m.Plan = .{ .projection = &.{ 0, 1 }, .limit = std.math.maxInt(u64), .predicate = .{ .compare = .{ .column = 1, .op = .ne, .value = value } } };
        var output: [m.Codec.max_plan_bytes]u8 = undefined;
        const encoded = try m.Codec.encode(plan, &output);
        const decoded = try m.Codec.decode(encoded);
        try t.expectEqual(plan.limit, decoded.limit);
        const scalar = decoded.predicate.compare.value;
        try t.expectEqual(std.math.Order.eq, try value.order(scalar));
        if (value == .float64) try t.expectEqual(@as(u64, 1 << 63), @as(u64, @bitCast(scalar.float64)));
        if (value == .utf8 and value.utf8.len == long.len) try t.expect(encoded.len > 207);
        for (0..encoded.len) |length| {
            if (m.Codec.decode(encoded[0..length])) |_| return error.AcceptedTruncatedPlan else |_| {}
        }
        output[encoded.len] = 0;
        try t.expectError(error.InvalidPlanEncoding, m.Codec.decode(output[0 .. encoded.len + 1]));
    }
    try t.expectError(error.NonFiniteValue, (m.Scalar{ .float64 = std.math.inf(f64) }).validate(.float64));
    try t.expectError(error.InvalidUtf8, (m.Scalar{ .utf8 = "\xff" }).validate(.utf8));
}

test "independent canonical query fixtures bind exact schema and plan digests" {
    const Fixture = struct { plans: []const struct { name: []const u8, type: u8, wire_hex: []const u8, digest: []const u8 }, schema: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/unified.json"), .{});
    defer fixture.deinit();
    var digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&digest, fixture.value.schema);
    try t.expectEqualSlices(u8, &digest, &try schema.fingerprint());
    for (fixture.value.plans) |item| {
        var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
        const encoded = try std.fmt.hexToBytes(&bytes, item.wire_hex);
        const plan = try m.Codec.decode(encoded);
        try t.expectEqual(item.type, @backingInt(std.meta.activeTag(plan.predicate.compare.value)));
        try t.expectEqual(@as(?u64, std.math.maxInt(u64)), plan.limit);
        var matching_columns = columns;
        matching_columns[1].type = @fromBackingInt(@intCast(item.type));
        const matching: m.Schema = .{ .columns = &matching_columns };
        var cut = try basis(.kv);
        cut.schema = try matching.fingerprint();
        const bound = try plan.bind(cut, matching);
        _ = try std.fmt.hexToBytes(&digest, item.digest);
        try t.expectEqualSlices(u8, &digest, &bound.fingerprint);
    }
}

test "independent output names survive canonical plans and preserve source identity" {
    const Fixture = struct {
        version: u8,
        definition: []const u8,
        cases: []const struct {
            name: []const u8,
            projection: []const u8,
            output_names: []const ?[]const u8,
            aggregate: m.Plan.Aggregate,
            encoded: []const u8,
            columns: []const []const u8,
        },
    };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/output-names-v1.json"), .{});
    defer fixture.deinit();
    try t.expectEqual(1, fixture.value.version);
    var definition: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&definition, fixture.value.definition);
    try t.expectEqualSlices(u8, &definition, &m.Codec.definition);
    const input: m.Schema = .{ .columns = &.{
        .{ .name = try m.Name.init("id"), .type = .int64 },
        .{ .name = try m.Name.init("value"), .type = .utf8 },
    } };
    const original = try input.fingerprint();
    for (fixture.value.cases) |case| {
        var plan: m.Plan = .{ .projection = case.projection, .aggregate = case.aggregate };
        for (case.output_names, 0..) |alias, index| if (alias) |name| {
            plan.output_names[index] = try m.Name.init(name);
        };
        var expected: [m.Codec.max_plan_bytes]u8 = undefined;
        var encoded: [m.Codec.max_plan_bytes]u8 = undefined;
        const wire = try std.fmt.hexToBytes(&expected, case.encoded);
        try t.expectEqualSlices(u8, wire, try m.Codec.encode(plan, &encoded));
        const restored = try m.Codec.decode(wire);
        try t.expectEqualDeep(plan.output_names, restored.output_names);
        var output: [m.max_columns]m.Column = undefined;
        const result = try restored.outputSchema(input, &output);
        try t.expectEqual(case.columns.len, result.columns.len);
        for (case.columns, result.columns) |name, column| try t.expectEqualStrings(name, column.name.slice());
        try t.expectEqualSlices(u8, &original, &try input.fingerprint());
        const cut: m.Basis = .{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(3), .schema = original };
        const bound = try restored.bind(cut, input);
        try t.expectEqualDeep(cut, bound.basis);
        if (case.output_names[0]) |name| {
            // Output names are owned even though projection/literal bytes borrow.
            expected[4 + definition.len + 2 + case.projection.len + 1] = 'z';
            try t.expectEqualStrings(name, restored.output_names[0].?.slice());
        }
        encoded[4] ^= 1;
        try t.expectError(error.UnsupportedPlanDefinition, m.Codec.decode(encoded[0..wire.len]));
    }
    try t.expectError(error.UnsupportedPlanDefinition, m.Codec.decode("FZP1\x00\x02\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"));
}

test "output names reject collisions hidden slots and malformed owned values" {
    var plan: m.Plan = .{ .projection = &.{ 0, 1 } };
    plan.output_names[0] = try m.Name.init("value");
    try t.expectError(error.DuplicateColumn, plan.validate(schema));
    plan.output_names[0] = try m.Name.init("renamed");
    plan.output_names[2] = try m.Name.init("hidden");
    try t.expectError(error.InvalidOutputNames, plan.validate(schema));
    plan.output_names[2] = null;
    plan.output_names[0].?.len = 33;
    try t.expectError(error.InvalidColumnName, plan.validate(schema));
    plan.output_names[0] = try m.Name.init("renamed");
    plan.output_names[0].?.bytes[31] = 'x';
    try t.expectError(error.InvalidColumnName, plan.validate(schema));
}

test "nested Arrow preserves typed states and releases fixed workspace" {
    const f = @import("root.zig");
    const alternatives = [_]m.Alternative{
        .{ .counter = 1, .replica = 1, .value = .{ .value = .{ .utf8 = "東京🙂" } } },
        .{ .counter = 1, .replica = 2, .value = .null },
    };
    const single: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("label"), .type = .utf8 }} };
    const rows = [_]m.Row{
        .{ .cells = &.{.missing} },
        .{ .cells = &.{.null} },
        .{ .cells = &.{.{ .type_error = .map }} },
        .{ .cells = &.{.{ .value = .{ .utf8 = "" } }} },
        .{ .cells = &.{.{ .conflict = &alternatives }} },
    };
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    @memset(workspace, 0xaa);
    const bytes = try m.Arrow.encode(single, &rows, workspace, &output);
    var repeated: [m.Arrow.segment_bytes]u8 = undefined;
    @memset(workspace, 0x55);
    try t.expectEqualSlices(u8, bytes, try m.Arrow.encode(single, &rows, workspace, &repeated));
    var owned = std.heap.ArenaAllocator.init(t.allocator);
    defer owned.deinit();
    var decoded: m.Inspect.Batch = undefined;
    try m.Inspect.decode(single, bytes, 5, workspace, owned.allocator(), &decoded);
    @memset(workspace, 0xcc);
    for (rows, 0..) |row, index| try t.expectEqualDeep(row, try decoded.row(index));
    try t.expectError(error.OutOfMemory, m.Inspect.decode(single, bytes, 5, workspace[0..1], owned.allocator(), &decoded));
    try t.expectError(error.InvalidArrowResult, m.Inspect.decode(single, bytes, 4, workspace, owned.allocator(), &decoded));
    const wrong: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("changed"), .type = .utf8 }} };
    try t.expectError(error.InvalidArrowResult, m.Inspect.decode(wrong, bytes, 5, workspace, owned.allocator(), &decoded));
    var input = std.Io.Reader.fixed(bytes);
    var reader = f.arrow.IpcStreamReader(*std.Io.Reader).init(t.allocator, &input);
    defer reader.deinit();
    const found = try reader.readSchema();
    try t.expectEqualStrings("label", found.fields[0].name);
    var batch = (try reader.nextRecordBatch()).?;
    defer batch.deinit();
    try t.expectEqual(@as(usize, 5), batch.numRows());
    try batch.column(0).data().validateFull();
    const states: f.arrow.UInt8Array = .{ .data = batch.column(0).data().children[0].data() };
    for (0..5) |index| try t.expectEqual(@as(u8, @intCast(index)), try states.value(index));
    try t.expect((try reader.nextRecordBatch()) == null);
    try t.expectError(error.WriteFailed, m.Arrow.encode(single, &rows, workspace, output[0..1]));
    try t.expectError(error.OutOfMemory, m.Arrow.encode(single, &rows, workspace[0..1], &output));
}

test "unified resumable limit and sum preserve source order across every page width" {
    const f = @import("root.zig");
    const s = m.Stream;
    const input_schema: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = .int64 }} };
    const cut: m.Basis = .{ .kind = .kv, .resource = 1, .revision = 99, .contract = @splat(6), .schema = try input_schema.fingerprint() };
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    var cells: [70][1]m.Cell = undefined;
    var rows: [70]m.Row = undefined;
    for (&cells, &rows, 0..) |*cell, *row, index| {
        cell[0] = if (index % 5 == 0) .null else .{ .value = .{ .int64 = @intCast(index) } };
        row.* = .{ .cells = cell };
    }
    for (1..m.max_rows + 1) |width| {
        for ([_]m.Plan.Aggregate{ .rows, .count, .sum }) |aggregate| {
            const bound = try (m.Plan{ .projection = &.{0}, .limit = 37, .aggregate = aggregate, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .int64 = 3 } } } }).bind(cut, input_schema);
            var progress = s.Progress.start(bound);
            var after: usize = 0;
            while (progress.finished == null) {
                const end = @min(rows.len, after + width);
                const step = try s.step(bound, progress, .{ .basis = cut, .ordinal = progress.pages, .rows = rows[after..end], .end = end == rows.len }, workspace, &output, &cancellation);
                progress = try s.Progress.decode(&try step.progress.encode());
                after = end;
            }
            try t.expectEqual(@as(u64, 37), progress.selected);
            try t.expectEqual(@as(u64, 49), progress.scanned);
            try t.expectEqual(s.Finish.limit, progress.finished.?);
            if (aggregate == .sum) try t.expectEqual(@as(?i64, 948), progress.sum);
            try t.expectEqual(@as(u64, if (aggregate == .rows) 37 else 1), progress.rows);
        }
    }
    const bound = try (m.Plan{ .projection = &.{0}, .aggregate = .sum }).bind(cut, input_schema);
    const first = try s.step(bound, s.Progress.start(bound), .{ .basis = cut, .ordinal = 0, .rows = &.{.{ .cells = &.{.{ .value = .{ .int64 = std.math.maxInt(i64) } }} }}, .end = false }, workspace, &output, &cancellation);
    try t.expectError(error.Overflow, s.step(bound, first.progress, .{ .basis = cut, .ordinal = 1, .rows = &.{ .{ .cells = &.{.{ .value = .{ .int64 = 1 } }} }, .{ .cells = &.{.{ .value = .{ .int64 = -1 } }} } }, .end = true }, workspace, &output, &cancellation));
}
test "unified capture rejects changed evidence cancellation and forged progress" {
    const f = @import("root.zig");
    const s = m.Stream;
    const bound = try (m.Plan{ .projection = &.{0}, .limit = 0 }).bind(try basis(.table), schema);
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    var cancellation = f.execution.Cancellation.init(true);
    const page: m.Page = .{ .basis = bound.basis, .ordinal = 0, .rows = &.{}, .end = false };
    const start = s.Progress.start(bound);
    try t.expectError(error.Cancelled, s.step(bound, start, page, workspace, &output, &cancellation));
    cancellation.store(false, .release);
    var changed = page;
    changed.basis.contract[0] ^= 1;
    try t.expectError(error.SourceChanged, s.step(bound, start, changed, workspace, &output, &cancellation));
    changed = page;
    changed.ordinal = 1;
    try t.expectError(error.InvalidQueryOrdinal, s.step(bound, start, changed, workspace, &output, &cancellation));
    var invalid = start;
    invalid.rows = 1;
    try t.expectError(error.InvalidQueryProgress, invalid.validate(bound));
    const empty = try s.step(bound, start, page, workspace, &output, &cancellation);
    try t.expectEqual(@as(u8, 0), empty.segment.?.rows);
    try t.expectEqual(@as(u64, 1), empty.progress.segments);
    try t.expectError(error.QueryComplete, s.step(bound, empty.progress, page, workspace, &output, &cancellation));
}

test "value counts resume across all source kinds page widths and pre-aggregate limits" {
    const f = @import("root.zig");
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    const values = [_]m.Scalar{ .{ .int64 = -1 }, .{ .uint64 = std.math.maxInt(u64) }, .{ .float64 = -0.0 }, .{ .boolean = false }, .{ .utf8 = "" }, .{ .binary = "" } };
    for (values) |value| {
        const input: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("value"), .type = std.meta.activeTag(value) }} };
        var cells: [19][1]m.Cell = undefined;
        var rows: [19]m.Row = undefined;
        for (&cells, &rows, 0..) |*cell, *row, i| {
            cell[0] = switch (i % 3) {
                0 => .null,
                1 => .missing,
                else => .{ .value = value },
            };
            row.* = .{ .cells = cell };
        }
        for ([_]m.SourceKind{ .kv, .table, .document }) |kind| {
            const cut: m.Basis = .{ .kind = kind, .resource = 17, .revision = 29, .contract = @splat(7), .schema = try input.fingerprint() };
            for ([_]?u64{ null, 0, 1, 2, 3, 7, 18 }) |limit| {
                const plan: m.Plan = .{ .projection = &.{0}, .aggregate = .count_values, .limit = limit };
                const bound = try plan.bind(cut, input);
                for (1..m.max_rows + 1) |width| {
                    var progress = m.Stream.Progress.start(bound);
                    var after: usize = 0;
                    while (progress.finished == null) {
                        const end = @min(rows.len, after + width);
                        const step = try m.Stream.step(bound, progress, .{ .basis = cut, .ordinal = progress.pages, .rows = rows[after..end], .end = end == rows.len }, workspace, &output, &cancellation);
                        progress = try m.Stream.Progress.decode(&try step.progress.encode());
                        try progress.validate(bound);
                        if (step.segment) |part| {
                            var columns_out: [m.max_columns]m.Column = undefined;
                            const output_schema = try plan.outputSchema(input, &columns_out);
                            try t.expectEqualStrings("count", output_schema.columns[0].name.slice());
                            var arena: std.heap.ArenaAllocator = .init(t.allocator);
                            defer arena.deinit();
                            var decoded: m.Inspect.Batch = undefined;
                            try m.Inspect.decode(output_schema, part.bytes, 1, workspace, arena.allocator(), &decoded);
                            try t.expectEqual(@as(u64, (limit orelse rows.len) / 3), (try decoded.row(0)).cells[0].value.uint64);
                        } else try t.expect(progress.finished == null);
                        after = end;
                    }
                    try t.expectEqual(limit orelse rows.len, progress.selected);
                    try t.expectEqual(@as(u64, (limit orelse rows.len) / 3), progress.value_count);
                    try t.expectEqual(@as(u64, 1), progress.rows);
                }
            }
        }
    }
}

test "value count rejects bad states and forged accumulators without publishing a candidate" {
    const f = @import("root.zig");
    const workspace = try t.allocator.alloc(u8, m.Arrow.working_bytes);
    defer t.allocator.free(workspace);
    var output: [m.Arrow.segment_bytes]u8 = undefined;
    const cancellation = f.execution.Cancellation.init(false);
    const bound = try (m.Plan{ .projection = &.{1}, .aggregate = .count_values }).bind(try basis(.kv), schema);
    const initial = m.Stream.Progress.start(bound);
    const conflicts = [_]m.Alternative{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 1, .replica = 2, .value = .null } };
    const bad_cells = [_]m.Cell{ .{ .type_error = .map }, .{ .conflict = &conflicts } };
    for (bad_cells) |cell| {
        const page: m.Page = .{ .basis = bound.basis, .ordinal = 0, .rows = &.{.{ .cells = &.{ .{ .value = .{ .uint64 = 1 } }, cell } }}, .end = true };
        try t.expectError(if (cell == .conflict) error.QueryConflict else error.QueryTypeError, m.Stream.step(bound, initial, page, workspace, &output, &cancellation));
        try t.expectEqual(@as(u64, 0), initial.pages);
        // COUNT(*) keeps counting rows even when a projected cell is an error.
        const count = try (m.Plan{ .projection = &.{1}, .aggregate = .count }).bind(bound.basis, schema);
        const step = try m.Stream.step(count, m.Stream.Progress.start(count), page, workspace, &output, &cancellation);
        try t.expectEqual(@as(u64, 1), step.progress.selected);
        try t.expectEqual(@as(u64, 0), step.progress.value_count);
    }
    var invalid = initial;
    invalid.value_count = 1;
    try t.expectError(error.InvalidQueryProgress, invalid.validate(bound));
    invalid = initial;
    invalid.sum = 0;
    invalid.pages = 1;
    try t.expectError(error.InvalidQueryProgress, invalid.validate(bound));
    const max = std.math.maxInt(u64);
    var full = initial;
    full.pages = max / m.max_rows + 1;
    full.scanned = max;
    full.selected = max;
    full.value_count = max;
    try full.validate(bound);
    const restored = try m.Stream.Progress.decode(&try full.encode());
    try t.expectEqual(max, restored.value_count);
    const old: [167]u8 = @splat(0);
    try t.expectError(error.InvalidQueryProgress, m.Stream.Progress.decode(&old));
    const count = try (m.Plan{ .projection = &.{1}, .aggregate = .count }).bind(bound.basis, schema);
    full.plan = count.fingerprint;
    try t.expectError(error.InvalidQueryProgress, full.validate(count));
}

test "combined plans reject earlier Boolean and value-count definitions" {
    var bytes: [m.Codec.max_plan_bytes]u8 = undefined;
    const encoded = try m.Codec.encode(.{ .projection = &.{0} }, &bytes);
    for ([_][]const u8{
        "fcfb9172e418c58d7d40f43b14cc121645cc8cedba70f18e69ed864188476b77",
        "661ed530f1b3654b456966cff2a22102ed32111e5ef7d9a218af6d88ba7c2bde",
    }) |previous| {
        _ = try std.fmt.hexToBytes(bytes[4..36], previous);
        try t.expectError(error.UnsupportedPlanDefinition, m.Codec.decode(encoded));
    }
}
