//! Bounded, restartable evaluation over one exact v2 source. Adapter cursors
//! persist beside this checkpoint; source permissions never live in progress.
const std = @import("std");
const f = @import("root.zig");
const m = f.Unified;
pub const progress_bytes = 167;
pub const Finish = enum(u8) { source_end = 1, limit = 2 };
pub const Progress = struct {
    basis: m.Basis,
    plan: [32]u8,
    pages: u64 = 0,
    scanned: u64 = 0,
    selected: u64 = 0,
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
            .count, .sum => {
                if (self.rows != @intFromBool(self.finished != null) or self.segments != self.rows) return error.InvalidQueryProgress;
                if ((bound.plan.aggregate == .count or self.selected == 0) and self.sum != null) return error.InvalidQueryProgress;
            },
        }
    }
    pub fn encode(self: Progress) ![progress_bytes]u8 {
        var output: [progress_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&output);
        try writer.writeAll("FZS2");
        try writer.writeByte(@backingInt(self.basis.kind));
        try writer.writeInt(u64, self.basis.resource, .little);
        try writer.writeInt(u64, self.basis.revision, .little);
        try writer.writeAll(&self.basis.contract);
        try writer.writeAll(&self.basis.schema);
        try writer.writeAll(&self.plan);
        inline for (.{ "pages", "scanned", "selected", "segments", "rows" }) |name| try writer.writeInt(u64, @field(self, name), .little);
        try writer.writeByte(@intFromBool(self.sum != null));
        try writer.writeInt(i64, self.sum orelse 0, .little);
        try writer.writeByte(if (self.finished) |finish| @backingInt(finish) else 0);
        std.debug.assert(writer.end == progress_bytes);
        return output;
    }
    pub fn decode(bytes: []const u8) !Progress {
        if (bytes.len != progress_bytes) return error.InvalidQueryProgress;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "FZS2")) return error.InvalidQueryProgress;
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
        inline for (.{ "pages", "scanned", "selected", "segments", "rows" }) |name| @field(result, name) = try reader.takeInt(u64, .little);
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
/// No candidate may be published after an error. Filter and checked sum run in
/// source order; even an overflow that later values could offset is an error.
pub fn step(bound: m.Plan.Bound, previous: Progress, page: m.Page, workspace: []u8, output: []u8, cancellation: *const f.execution.Cancellation) !Step {
    const verified = try bound.plan.bind(bound.basis, bound.schema);
    if (!std.mem.eql(u8, &verified.fingerprint, &bound.fingerprint)) return error.SourceChanged;
    try previous.validate(bound);
    if (previous.finished != null) return error.QueryComplete;
    if (page.ordinal != previous.pages) return error.InvalidQueryOrdinal;
    try page.validate(bound.schema);
    if (!std.meta.eql(page.basis, bound.basis)) return error.SourceChanged;
    if (cancellation.load(.acquire)) return error.Cancelled;
    var next = previous;
    next.pages = try std.math.add(u64, next.pages, 1);
    var cells: [m.max_rows][m.max_columns]m.Cell = undefined;
    var selected: [m.max_rows]m.Row = undefined;
    var count: usize = 0;
    for (page.rows) |row| {
        if (cancellation.load(.acquire)) return error.Cancelled;
        if (bound.plan.limit) |limit| if (next.selected == limit) break;
        next.scanned = try std.math.add(u64, next.scanned, 1);
        if (!try bound.plan.matches(row)) continue;
        next.selected = try std.math.add(u64, next.selected, 1);
        if (bound.plan.aggregate == .sum) switch (row.cells[bound.plan.projection[0]]) {
            .missing, .null => {},
            .type_error => return error.QueryTypeError,
            .conflict => return error.QueryConflict,
            .value => |value| next.sum = try std.math.add(i64, next.sum orelse 0, value.int64),
        };
        for (bound.plan.projection, 0..) |column, index| cells[count][index] = row.cells[column];
        selected[count] = .{ .cells = cells[count][0..bound.plan.projection.len] };
        count += 1;
    }
    next.finished = if (bound.plan.limit != null and next.selected == bound.plan.limit.?) .limit else if (page.end) .source_end else null;
    var columns: [m.max_columns]m.Column = undefined;
    var segment: ?Segment = null;
    if (bound.plan.aggregate == .rows) {
        if (count > 0 or (next.finished != null and previous.segments == 0)) {
            for (bound.plan.projection, 0..) |column, index| columns[index] = bound.schema.columns[column];
            segment = try encode(.{ .columns = columns[0..bound.plan.projection.len] }, selected[0..count], workspace, output);
        }
    } else if (next.finished != null) {
        columns[0] = .{ .name = try m.Name.init(@tagName(bound.plan.aggregate)), .type = if (bound.plan.aggregate == .count) .uint64 else .int64 };
        const value: m.Cell = if (bound.plan.aggregate == .count) .{ .value = .{ .uint64 = next.selected } } else if (next.sum) |sum| .{ .value = .{ .int64 = sum } } else .null;
        segment = try encode(.{ .columns = columns[0..1] }, &.{.{ .cells = &.{value} }}, workspace, output);
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
