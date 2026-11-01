//! Executable endpoint for an independent Python oracle. No expected comparisons
//! are computed here: report real Batch and production physical decoder outputs.
const std = @import("std");
const f = @import("transit_fuze");
const Case = struct {
    id: usize,
    collation: f.TableSchema.Collation,
    encoding: f.TableSchema.Encoding,
    op: enum { eq, ne, lt, le, gt, ge },
    literal: []const u8,
    rows: []const struct { state: f.Types.State, value: []const u8 = "" },
};
const Cell = f.Types.Values.Cell;
const Outcome = f.ColumnPredicate.Outcome;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(4 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const cases = try std.json.parseFromSlice([]const Case, init.gpa, bytes, .{});
    defer cases.deinit();
    var output_buffer: [8192]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (cases.value) |case| {
        if (case.rows.len > 32) return error.FixtureTooLarge;
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const schema: f.Types.Type = .{ .structure = &.{.{ .name = "text", .type = .utf8, .nullable = true, .optional = true }} };
        var plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(14), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = case.literal } } } };
        plan.predicate.compare.op = std.meta.stringToEnum(@TypeOf(plan.predicate.compare.op), @tagName(case.op)).?;
        plan.collations.columns[0] = case.collation;
        var batch = try f.Batch.init(a, plan, .{ .rows = 32, .bytes = 256 * 1024 });
        defer batch.deinit();
        const alternatives = [_]f.Types.Values.Alternative{
            .{ .counter = 1, .replica = 1, .value = .null },
            .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .bytes = "Conflict Spelling" } } } },
        };
        var cells: [32]Cell = undefined;
        for (case.rows, 0..) |row, i| {
            cells[i] = switch (row.state) {
                .value => .{ .value = .{ .atom = .{ .bytes = row.value } } },
                .null => .null,
                .missing => .missing,
                .type_error => .{ .type_error = .utf8 },
                .conflict => .{ .conflict = &alternatives },
            };
            try batch.append(cells[i..][0..1], .{ .row = i + 1, .boundary = 1 });
        }
        batch.evaluate();
        var outcomes: [32]Outcome = undefined;
        var raw: [32]?[]const u8 = undefined;
        var selected: [32]u32 = undefined;
        var count: usize = 0;
        for (batch.outcomes[0..batch.len], 0..) |outcome, i| {
            outcomes[i] = switch (outcome) {
                .type_error => .type_error,
                .conflict => .conflict,
                .truth => |truth| switch (truth) {
                    .true_value => .yes,
                    .false_value => .no,
                    .unknown => .unknown,
                },
            };
            const cell = batch.columns[0].view(batch.len).cell(i);
            raw[i] = if (cell == .value) cell.value.atom.bytes else null;
            if (outcomes[i] == .yes) {
                selected[count] = @intCast(i);
                count += 1;
            }
        }
        const column: f.TableSchema.Column = .{ .id = 1, .name = "text", .type = .utf8, .encoding = case.encoding, .collation = case.collation };
        const page_buffer = try a.alloc(u8, 256 * 1024);
        const page = try f.PhysicalCodecs.encodeColumnPage(a, column, cells[0..batch.len], page_buffer);
        const predicate: f.ColumnPredicate.Predicate = .{ .compare = .{ .op = plan.predicate.compare.op, .value = plan.predicate.compare.value } };
        const physical = try f.PhysicalCodecs.evaluateColumnPage(a, a, column, page, predicate);
        const materialized = try f.PhysicalCodecs.decodeColumnPageSelected(a, a, column, page, selected[0..count]);
        var selected_raw: [32][]const u8 = undefined;
        for (materialized.cells, 0..) |cell, i| selected_raw[i] = cell.value.atom.bytes;
        try std.json.Stringify.value(.{ .id = case.id, .batch = outcomes[0..batch.len], .physical = physical.outcomes, .raw = raw[0..batch.len], .selected = selected_raw[0..count], .streamed = physical.streamed_strings, .materialized = physical.materialized_strings }, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
