//! Bounded, restartable evaluation over one exact v1 source. Adapter cursors
//! persist beside this checkpoint; source permissions never live in progress.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
pub const progress_bytes = 175;
pub const Finish = enum(u8) { source_end = 1, limit = 2 };
pub const Progress = struct {
    basis: m.Basis,
    plan: [32]u8,
    pages: u64 = 0,
    scanned: u64 = 0,
    selected: u64 = 0,
    value_count: u64 = 0,
    segments: u64 = 0,
    rows: u64 = 0,
    sum: ?i64 = null,
    finished: ?Finish = null,
    pub fn start(bound: m.Plan.Bound) Progress {
        return .{ .basis = bound.basis, .plan = bound.fingerprint };
    }
    pub fn validate(self: Progress, bound: m.Plan.Bound) !void {
        if (!std.meta.eql(self.basis, bound.basis) or !std.mem.eql(u8, &self.plan, &bound.fingerprint)) return error.SourceChanged;
        if (self.selected > self.scanned or self.scanned / m.max_rows + @intFromBool(self.scanned % m.max_rows != 0) > self.pages or self.segments > self.pages) return error.InvalidQueryProgress;
        if (self.value_count > self.selected or (bound.plan.aggregate != .count_values and self.value_count != 0)) return error.InvalidQueryProgress;
        if (self.pages == 0 and (self.sum != null or self.finished != null)) return error.InvalidQueryProgress;
        if (bound.plan.limit) |limit| {
            if (self.selected > limit or (self.finished == .limit and self.selected != limit)) return error.InvalidQueryProgress;
            if (self.pages > 0 and self.selected == limit and self.finished != .limit) return error.InvalidQueryProgress;
        } else if (self.finished == .limit) return error.InvalidQueryProgress;
        switch (bound.plan.aggregate) {
            .rows => {
                if (self.sum != null or self.rows != self.selected) return error.InvalidQueryProgress;
                if (self.selected == 0) {
                    if (self.segments != @intFromBool(self.finished != null)) return error.InvalidQueryProgress;
                } else if (self.segments == 0 or self.segments > self.selected or self.rows / m.max_rows + @intFromBool(self.rows % m.max_rows != 0) > self.segments) return error.InvalidQueryProgress;
            },
            .count, .sum, .count_values => {
                if (self.rows != @intFromBool(self.finished != null) or self.segments != self.rows) return error.InvalidQueryProgress;
                if ((bound.plan.aggregate != .sum or self.selected == 0) and self.sum != null) return error.InvalidQueryProgress;
            },
        }
    }
    pub fn encode(self: Progress) ![progress_bytes]u8 {
        var output: [progress_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&output);
        try writer.writeAll("FZS1");
        try writer.writeByte(@backingInt(self.basis.kind));
        try writer.writeInt(u64, self.basis.resource, .little);
        try writer.writeInt(u64, self.basis.revision, .little);
        try writer.writeAll(&self.basis.contract);
        try writer.writeAll(&self.basis.schema);
        try writer.writeAll(&self.plan);
        inline for (.{ "pages", "scanned", "selected", "value_count", "segments", "rows" }) |name| try writer.writeInt(u64, @field(self, name), .little);
        try writer.writeByte(@intFromBool(self.sum != null));
        try writer.writeInt(i64, self.sum orelse 0, .little);
        try writer.writeByte(if (self.finished) |finish| @backingInt(finish) else 0);
        std.debug.assert(writer.end == progress_bytes);
        return output;
    }
    pub fn decode(bytes: []const u8) !Progress {
        if (bytes.len != progress_bytes) return error.InvalidQueryProgress;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "FZS1")) return error.InvalidQueryProgress;
        var result: Progress = .{
            .basis = .{
                .kind = std.enums.fromInt(m.SourceKind, try reader.takeByte()) orelse return error.InvalidQueryProgress,
                .resource = try reader.takeInt(u64, .little),
                .revision = try reader.takeInt(u64, .little),
                .contract = (try reader.takeArray(32)).*,
                .schema = (try reader.takeArray(32)).*,
            },
            .plan = (try reader.takeArray(32)).*,
        };
        inline for (.{ "pages", "scanned", "selected", "value_count", "segments", "rows" }) |name| @field(result, name) = try reader.takeInt(u64, .little);
        const present = try reader.takeByte();
        const sum = try reader.takeInt(i64, .little);
        if (present > 1 or (present == 0 and sum != 0)) return error.InvalidQueryProgress;
        result.sum = if (present == 1) sum else null;
        const finish = try reader.takeByte();
        result.finished = if (finish == 0) null else std.enums.fromInt(Finish, finish) orelse return error.InvalidQueryProgress;
        return result;
    }
};
pub const Segment = struct { bytes: []const u8, rows: u8, digest: [32]u8 };
pub const Step = struct { progress: Progress, segment: ?Segment };
pub const Failure = struct {
    pub const Operation = enum { validate, predicate, count, sum };
    operation: Operation,
    /// One-based ordinal in the actual adapter scan, not a stable row identity.
    row: u64,
    page_row: u8,
    column: u8,
    /// Zero-based postfix instruction; only present for predicate evaluation.
    instruction: ?u8 = null,
};
/// No candidate may be published after an error. Filter and checked sum run in
/// source order; even an overflow that later values could offset is an error.
pub fn step(bound: m.Plan.Bound, previous: Progress, page: m.Page, workspace: []u8, output: []u8, cancellation: *const f.execution.Cancellation) !Step {
    return stepDiagnostic(bound, previous, page, workspace, output, cancellation, null);
}
pub fn stepDiagnostic(bound: m.Plan.Bound, previous: Progress, page: m.Page, workspace: []u8, output: []u8, cancellation: *const f.execution.Cancellation, diagnostic: ?*?Failure) !Step {
    if (diagnostic) |detail| detail.* = null;
    try bound.validate();
    try previous.validate(bound);
    if (previous.finished != null) return error.QueryComplete;
    if (page.ordinal != previous.pages) return error.InvalidQueryOrdinal;
    var invalid: ?m.Page.Failure = null;
    page.validateDiagnostic(bound.schema, &invalid) catch |err| {
        if (diagnostic) |detail| if (invalid) |cell| {
            detail.* = .{ .operation = .validate, .row = std.math.add(u64, previous.scanned, @as(u64, cell.row) + 1) catch return err, .page_row = cell.row, .column = cell.column };
        };
        return err;
    };
    if (!std.meta.eql(page.basis, bound.basis)) return error.SourceChanged;
    if (cancellation.load(.acquire)) return error.Cancelled;
    var next = previous;
    next.pages = try std.math.add(u64, next.pages, 1);
    var cells: [m.max_rows][m.max_columns]m.Cell = undefined;
    var selected: [m.max_rows]m.Row = undefined;
    var count: usize = 0;
    const kernels = @import("VectorPage.zig");
    var outcomes: [m.max_rows]kernels.Outcome = undefined;
    var sites: [m.max_rows]u8 = undefined;
    kernels.unifiedPage(&bound, page.rows, outcomes[0..page.rows.len], sites[0..page.rows.len]);
    for (page.rows, 0..) |row, row_index| {
        if (cancellation.load(.acquire)) return error.Cancelled;
        if (bound.plan.limit) |limit| if (next.selected == limit) break;
        next.scanned = try std.math.add(u64, next.scanned, 1);
        switch (outcomes[row_index]) {
            .truth => |truth| if (!truth.selects()) continue,
            .type_error, .conflict => |_, tag| {
                const site = kernels.nativeSite(&bound.plan, sites[row_index]);
                if (diagnostic) |detail| detail.* = .{ .operation = .predicate, .row = next.scanned, .page_row = @intCast(row_index), .column = site.column, .instruction = site.instruction };
                return if (tag == .type_error) error.QueryTypeError else error.QueryConflict;
            },
        }
        next.selected = try std.math.add(u64, next.selected, 1);
        if (bound.plan.aggregate == .count_values) next.value_count = @import("Finite.zig").countValue(next.value_count, row.cells[bound.plan.projection[0]]) catch |err| {
            if (diagnostic) |detail| detail.* = .{ .operation = .count, .row = next.scanned, .page_row = @intCast(row_index), .column = bound.plan.projection[0] };
            return err;
        };
        if (bound.plan.aggregate == .sum) next.sum = @import("Finite.zig").sum(next.sum, row.cells[bound.plan.projection[0]], struct {
            fn integer(value: m.Scalar) !i64 {
                return value.int64;
            }
        }.integer) catch |err| {
            if (diagnostic) |detail| detail.* = .{ .operation = .sum, .row = next.scanned, .page_row = @intCast(row_index), .column = bound.plan.projection[0] };
            return err;
        };
        if (bound.plan.aggregate == .rows) {
            for (bound.plan.projection, 0..) |column, index| cells[count][index] = row.cells[column];
            selected[count] = .{ .cells = cells[count][0..bound.plan.projection.len] };
            count += 1;
        }
    }
    next.finished = if (bound.plan.limit != null and next.selected == bound.plan.limit.?) .limit else if (page.end) .source_end else null;
    var columns: [m.max_columns]m.Column = undefined;
    var segment: ?Segment = null;
    if (bound.plan.aggregate == .rows) {
        if (count > 0 or (next.finished != null and previous.segments == 0)) {
            segment = try encode(try bound.plan.outputSchema(bound.schema, &columns), selected[0..count], workspace, output);
        }
    } else if (next.finished != null) {
        const value: m.Cell = switch (bound.plan.aggregate) {
            .count => .{ .value = .{ .uint64 = next.selected } },
            .count_values => .{ .value = .{ .uint64 = next.value_count } },
            .sum => if (next.sum) |sum| .{ .value = .{ .int64 = sum } } else .null,
            .rows => unreachable,
        };
        segment = try encode(try bound.plan.outputSchema(bound.schema, &columns), &.{.{ .cells = &.{value} }}, workspace, output);
    }
    if (cancellation.load(.acquire)) return error.Cancelled;
    if (segment) |part| {
        next.segments = try std.math.add(u64, next.segments, 1);
        next.rows = try std.math.add(u64, next.rows, part.rows);
    }
    try next.validate(bound);
    return .{ .progress = next, .segment = segment };
}
fn encode(schema: m.Schema, rows: []const m.Row, workspace: []u8, output: []u8) !Segment {
    const bytes = try m.Arrow.encode(schema, rows, workspace, output);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = bytes, .rows = @intCast(rows.len), .digest = digest };
}

test "runtime witnesses retain eager atom order, later-page rows and checked sum position" {
    const t = std.testing;
    const schema: m.Schema = .{ .columns = &.{ .{ .name = try m.Name.init("id"), .type = .int64 }, .{ .name = try m.Name.init("amount"), .type = .int64 } } };
    const basis: m.Basis = .{ .kind = .table, .resource = 3, .revision = 7, .schema = try schema.fingerprint(), .contract = @splat(1) };
    const predicate: m.Plan = .{ .projection = &.{1}, .predicate = .{ .program = try m.PredicateProgram.Owned.init(&.{
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .int64 = 999 } } } },
        .{ .atom = .{ .compare = .{ .column = 1, .op = .eq, .value = .{ .int64 = 0 } } } },
        .conjunction,
    }) } };
    const bound = try predicate.bind(basis, schema);
    var previous = Progress.start(bound);
    previous.pages = 1;
    previous.scanned = 8;
    const page: m.Page = .{ .basis = basis, .ordinal = 1, .end = true, .rows = &.{.{ .cells = &.{ .{ .value = .{ .int64 = 1 } }, .{ .type_error = .utf8 } } }} };
    var cancelled: f.execution.Cancellation = .init(false);
    var detail: ?Failure = null;
    try t.expectError(error.QueryTypeError, stepDiagnostic(bound, previous, page, &.{}, &.{}, &cancelled, &detail));
    try t.expectEqualDeep(Failure{ .operation = .predicate, .row = 9, .page_row = 0, .column = 1, .instruction = 1 }, detail.?);
    try t.expectEqual(@as(u64, 8), previous.scanned);
    try t.expectError(error.QueryTypeError, step(bound, previous, page, &.{}, &.{}, &cancelled));
    cancelled.store(true, .release);
    try t.expectError(error.Cancelled, stepDiagnostic(bound, previous, page, &.{}, &.{}, &cancelled, &detail));
    try t.expect(detail == null);
    cancelled.store(false, .release);

    const sum = try (m.Plan{ .projection = &.{1}, .aggregate = .sum }).bind(basis, schema);
    const overflowing: m.Page = .{ .basis = basis, .ordinal = 0, .end = true, .rows = &.{
        .{ .cells = &.{ .{ .value = .{ .int64 = -1 } }, .{ .value = .{ .int64 = std.math.maxInt(i64) } } } },
        .{ .cells = &.{ .{ .value = .{ .int64 = 2 } }, .{ .value = .{ .int64 = 1 } } } },
        .{ .cells = &.{ .{ .value = .{ .int64 = 3 } }, .{ .value = .{ .int64 = -1 } } } },
    } };
    try t.expectError(error.Overflow, stepDiagnostic(sum, .start(sum), overflowing, &.{}, &.{}, &cancelled, &detail));
    try t.expectEqualDeep(Failure{ .operation = .sum, .row = 2, .page_row = 1, .column = 1 }, detail.?);
}
