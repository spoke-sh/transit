//! This consumer knows only the public result API, never messages or cursors.
const r = @import("root.zig").results;
pub const Observed = struct { values: [32]u128 = undefined, count: usize = 0, terminal: ?u64 = null };
pub fn consume(result: *r.ResultSet) !Observed {
    var output: Observed = .{};
    while (try result.nextRow()) |row| {
        if (output.count == output.values.len) return error.TestConsumerLimit;
        output.values[output.count] = row[0].value.atom.unsigned;
        output.count += 1;
    }
    output.terminal = if (result.completion()) |complete| complete.rows else null;
    return output;
}
pub fn consumeBatches(result: *r.ResultSet) !Observed {
    var output: Observed = .{};
    while (try result.nextBatch()) |batch| {
        for (0..batch.len) |i| {
            if (output.count == output.values.len) return error.TestConsumerLimit;
            output.values[output.count] = batch.cell(i, 0).value.atom.unsigned;
            output.count += 1;
        }
    }
    output.terminal = if (result.completion()) |complete| complete.rows else null;
    return output;
}
pub fn requireRelation(observed: Observed, length: usize) !void {
    // Independent oracle: the finite relation has occurrence i = i modulo 3.
    // No received/delivered counters or transport boundaries define this oracle.
    if (observed.count != length or observed.terminal != length) return error.OracleMismatch;
    for (observed.values[0..observed.count], 0..) |value, i| if (value != i % 3) return error.OracleMismatch;
}

const std = @import("std");
const Script = struct {
    length: usize,
    cuts: usize,
    empty_terminal: bool,
    position: usize = 0,
    columnar: bool = false,
    column_cells: [8]r.Types.Values.Cell = undefined,
    columns: [1]r.Batch.Column = undefined,
    closed: usize = 0,
    cells: [8][1]r.Types.Values.Cell = undefined,
    rows: [8]r.Row = undefined,
    fn next(context: *anyopaque) !r.ResultSet.Chunk {
        const self: *Script = @ptrCast(@alignCast(context));
        var count: usize = 0;
        while (self.position < self.length) {
            self.cells[count][0] = .{ .value = .{ .atom = .{ .unsigned = self.position % 3 } } };
            self.rows[count] = &self.cells[count];
            self.column_cells[count] = self.cells[count][0];
            self.position += 1;
            count += 1;
            if (self.cuts & (@as(usize, 1) << @intCast(self.position - 1)) != 0) break;
        }
        self.columns[0] = .{ .cells = self.column_cells[0..count] };
        return .{ .values = if (self.columnar) .fromColumns(&self.columns, count) else .fromRows(self.rows[0..count]), .completion = if (self.position == self.length and (!self.empty_terminal or count == 0)) .{ .rows = self.length } else null };
    }
    fn close(context: *anyopaque) !void {
        const self: *Script = @ptrCast(@alignCast(context));
        self.closed += 1;
        // A close is resource release, and supplies no evidence of exhaustion.
        @memset(std.mem.asBytes(&self.cells), 0);
    }
    fn deinit(_: *anyopaque) void {}
    fn open(self: *Script) !r.ResultSet {
        const schema: r.Types.Type = .{ .structure = &.{.{ .name = "n", .type = .uint128 }} };
        const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
        return r.ResultSet.init(schema, observation, .{ .result = @splat(6), .schema = try schema.fingerprint(), .observation = try r.Observation.fingerprint(std.testing.allocator, observation) }, .{ .context = self, .next = next, .close = close, .deinit = deinit });
    }
};
test "the same public consumer runs without a communication adapter for every partition" {
    for (0..9) |length| {
        for (0..@as(usize, 1) << @intCast(length)) |cuts| for ([_]bool{ false, true }) |empty_terminal| for ([_]bool{ false, true }) |columnar| inline for (.{ consume, consumeBatches }) |consumer| {
            var script: Script = .{ .length = length, .cuts = cuts, .empty_terminal = empty_terminal, .columnar = columnar };
            var result = try script.open();
            defer result.deinit();
            try requireRelation(try consumer(&result), length);
            try std.testing.expectEqual(1, script.closed);
        };
    }
}
test "independent oracle rejects fabricated completion on an early stop or EOF prefix" {
    // These deliberately broken projections can satisfy local row counters:
    // only the independent finite relation exposes the missing occurrences.
    for (0..7) |prefix| {
        var script: Script = .{ .length = 7, .cuts = 255, .empty_terminal = false };
        var result = try script.open();
        defer result.deinit();
        var observed: Observed = .{};
        for (0..prefix) |i| {
            observed.values[i] = (try result.nextRow()).?[0].value.atom.unsigned;
            observed.count += 1;
        }
        try result.close();
        try std.testing.expect(result.completion() == null);
        observed.terminal = observed.count; // mutant: close/EOF means success
        try std.testing.expectError(error.OracleMismatch, requireRelation(observed, 7));
    }
}
