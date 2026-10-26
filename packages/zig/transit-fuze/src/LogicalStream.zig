//! Restartable finite logical evaluation. Progress and Arrow are provisional
//! until the source owner atomically publishes them with its adapter cursor.
const std = @import("std");
const q = @import("LogicalQuery.zig");
const t = @import("Types.zig");
const arrow = @import("LogicalArrow.zig");
const Cancellation = @import("execute.zig").Cancellation;
pub const max_rows = arrow.max_rows;
pub const progress_bytes = 126;
pub const Finish = enum(u8) { source_end = 1, limit = 2 };
pub const Progress = struct {
    binding: [32]u8,
    plan: [32]u8,
    pages: u64 = 0,
    counters: q.Counters = .{},
    segments: u64 = 0,
    rows: u64 = 0,
    finished: ?Finish = null,
    pub fn start(plan: q.Plan) !Progress {
        return .{ .binding = plan.source_basis, .plan = try plan.fingerprint() };
    }
    pub fn validate(self: Progress, plan: q.Plan) !void {
        try self.validateRecord();
        if (!std.mem.eql(u8, &self.binding, &plan.source_basis) or !std.mem.eql(u8, &self.plan, &try plan.fingerprint())) return error.SourceChanged;
        const count = self.counters;
        if (count.value_count > count.selected or (plan.aggregate != .count_values and count.value_count != 0)) return error.InvalidQueryProgress;
        if (plan.limit) |limit| {
            if (count.selected > limit or (self.finished == .limit and count.selected != limit)) return error.InvalidQueryProgress;
            if (self.pages > 0 and count.selected == limit and self.finished != .limit) return error.InvalidQueryProgress;
        } else if (self.finished == .limit) return error.InvalidQueryProgress;
        switch (plan.aggregate) {
            .rows => {
                if (count.sum != null or self.rows != count.selected) return error.InvalidQueryProgress;
                if (count.selected == 0) {
                    if (self.segments != @intFromBool(self.finished != null)) return error.InvalidQueryProgress;
                } else if (self.segments == 0 or self.segments > count.selected or pagesFor(self.rows) > self.segments) return error.InvalidQueryProgress;
            },
            .count, .sum, .count_values => {
                if (self.rows != @intFromBool(self.finished != null) or self.segments != self.rows) return error.InvalidQueryProgress;
                if ((plan.aggregate != .sum or count.selected == 0) and count.sum != null) return error.InvalidQueryProgress;
            },
        }
    }
    fn pagesFor(rows: u64) u64 {
        return rows / max_rows + @intFromBool(rows % max_rows != 0);
    }
    /// Structural validation for an enclosing durable record. Loading a record
    /// is not execution admission: validate(plan) is mandatory before using it.
    pub fn validateRecord(self: Progress) !void {
        const count = self.counters;
        if (count.selected > count.scanned or count.value_count > count.selected or pagesFor(count.scanned) > self.pages or self.segments > self.pages or pagesFor(self.rows) > self.segments) return error.InvalidQueryProgress;
        if (self.pages == 0 and (count.sum != null or self.finished != null)) return error.InvalidQueryProgress;
        if (self.finished != null and self.segments == 0) return error.InvalidQueryProgress;
    }
    pub fn encode(self: Progress, plan: q.Plan) ![progress_bytes]u8 {
        try self.validate(plan);
        return self.encodeRecord();
    }
    pub fn encodeRecord(self: Progress) ![progress_bytes]u8 {
        try self.validateRecord();
        var bytes: [progress_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("FQS1");
        try writer.writeAll(&self.binding);
        try writer.writeAll(&self.plan);
        try writer.writeInt(u64, self.pages, .little);
        inline for (.{ "scanned", "selected", "value_count" }) |field| try writer.writeInt(u64, @field(self.counters, field), .little);
        try writer.writeInt(u64, self.segments, .little);
        try writer.writeInt(u64, self.rows, .little);
        try writer.writeByte(@intFromBool(self.counters.sum != null));
        try writer.writeInt(i64, self.counters.sum orelse 0, .little);
        try writer.writeByte(if (self.finished) |finish| @backingInt(finish) else 0);
        std.debug.assert(writer.end == progress_bytes);
        return bytes;
    }
    pub fn decode(plan: q.Plan, bytes: []const u8) !Progress {
        const progress = try decodeRecord(bytes);
        try progress.validate(plan);
        return progress;
    }
    pub fn decodeRecord(bytes: []const u8) !Progress {
        if (bytes.len != progress_bytes) return error.InvalidQueryProgress;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "FQS1")) return error.InvalidQueryProgress;
        var progress: Progress = .{ .binding = (try reader.takeArray(32)).*, .plan = (try reader.takeArray(32)).*, .pages = try reader.takeInt(u64, .little) };
        inline for (.{ "scanned", "selected", "value_count" }) |field| @field(progress.counters, field) = try reader.takeInt(u64, .little);
        progress.segments = try reader.takeInt(u64, .little);
        progress.rows = try reader.takeInt(u64, .little);
        const present = try reader.takeByte();
        const sum = try reader.takeInt(i64, .little);
        if (present > 1 or (present == 0 and sum != 0)) return error.InvalidQueryProgress;
        progress.counters.sum = if (present == 1) sum else null;
        const finish = try reader.takeByte();
        progress.finished = if (finish == 0) null else std.enums.fromInt(Finish, finish) orelse return error.InvalidQueryProgress;
        try progress.validateRecord();
        return progress;
    }
};
pub const Page = struct { binding: [32]u8, ordinal: u64, end: bool, rows: []const arrow.Row };
pub const Segment = struct { bytes: []const u8, rows: u8, digest: [32]u8 };
pub const Step = struct { progress: Progress, segment: ?Segment };
pub const Failure = struct {
    operation: enum { validate, predicate, count, sum },
    row: u64,
    page_row: u8,
    column: ?u8 = null,
    instruction: ?u8 = null,
};
/// Source order, five states and checked arithmetic use the same row operators
/// as the pull executor. An error/cancellation returns no commit candidate.
pub fn step(plan: q.Plan, previous: Progress, page: Page, workspace: []u8, output: []u8, cancellation: *const Cancellation, diagnostic: ?*?Failure) !Step {
    if (diagnostic) |detail| detail.* = null;
    try previous.validate(plan);
    if (previous.finished != null) return error.QueryComplete;
    if (!std.mem.eql(u8, &page.binding, &plan.source_basis)) return error.SourceChanged;
    if (page.ordinal != previous.pages) return error.InvalidQueryOrdinal;
    if (page.rows.len > max_rows) return error.ArrowShapeTooLarge;
    if (cancellation.load(.acquire)) return error.Cancelled;
    for (page.rows, 0..) |row, row_index| {
        if (cancellation.load(.acquire)) return error.Cancelled;
        (t.Values.Cell{ .value = .{ .structure = row.cells } }).validate(.{ .name = "row", .type = plan.schema }, .{}) catch |err| {
            if (diagnostic) |detail| detail.* = .{ .operation = .validate, .row = std.math.add(u64, previous.counters.scanned, row_index + 1) catch return err, .page_row = @intCast(row_index) };
            return err;
        };
    }
    for (page.rows, 0..) |row, row_index| plan.collations.validateCells(row.cells) catch |err| {
        if (diagnostic) |detail| detail.* = .{ .operation = .validate, .row = std.math.add(u64, previous.counters.scanned, row_index + 1) catch return err, .page_row = @intCast(row_index) };
        return err;
    };
    var next = previous;
    next.pages = try std.math.add(u64, next.pages, 1);
    var cells: [max_rows][128]t.Values.Cell = undefined;
    var selected: [max_rows]arrow.Row = undefined;
    var count: usize = 0;
    const kernels = @import("VectorPage.zig");
    var outcomes: [max_rows]kernels.Outcome = undefined;
    var sites: [max_rows]u8 = undefined;
    kernels.logicalPage(plan, page.rows, outcomes[0..page.rows.len], sites[0..page.rows.len]);
    for (page.rows, 0..) |row, row_index| {
        if (cancellation.load(.acquire)) return error.Cancelled;
        if (plan.limit) |limit| if (next.counters.selected == limit) break;
        next.counters.scanned = try std.math.add(u64, next.counters.scanned, 1);
        switch (outcomes[row_index]) {
            .truth => |truth| if (!truth.selects()) continue,
            .type_error, .conflict => |_, tag| {
                const site = kernels.logicalSite(plan, sites[row_index]);
                if (diagnostic) |detail| detail.* = .{ .operation = .predicate, .row = next.counters.scanned, .page_row = @intCast(row_index), .column = site.column, .instruction = site.instruction };
                return if (tag == .type_error) error.QueryTypeError else error.QueryConflict;
            },
        }
        var failure: ?q.Counters.FailureSite = null;
        const matches = next.counters.contribute(plan, row.cells, &failure) catch |err| {
            if (diagnostic) |detail| if (failure) |site| {
                detail.* = .{ .operation = switch (site.operation) {
                    inline else => |tag| @field(@FieldType(Failure, "operation"), @tagName(tag)),
                }, .row = next.counters.scanned, .page_row = @intCast(row_index), .column = site.column, .instruction = site.instruction };
            };
            return err;
        };
        if (matches and plan.aggregate == .rows) {
            for (plan.projection, 0..) |column, index| cells[count][index] = row.cells[column];
            selected[count] = .{ .cells = cells[count][0..plan.projection.len] };
            count += 1;
        }
    }
    next.finished = if (plan.limit != null and next.counters.selected == plan.limit.?) .limit else if (page.end) .source_end else null;
    var fields: [128]t.Field = undefined;
    const schema = try plan.outputSchema(&fields);
    var segment: ?Segment = null;
    if (plan.aggregate == .rows) {
        if (count > 0 or (next.finished != null and previous.segments == 0)) segment = try encode(schema, selected[0..count], workspace, output);
    } else if (next.finished != null) {
        const value = try next.counters.result(plan.aggregate);
        segment = try encode(schema, &.{.{ .cells = &.{value} }}, workspace, output);
    }
    if (cancellation.load(.acquire)) return error.Cancelled;
    if (segment) |part| {
        next.segments = try std.math.add(u64, next.segments, 1);
        next.rows = try std.math.add(u64, next.rows, part.rows);
    }
    try next.validate(plan);
    return .{ .progress = next, .segment = segment };
}
fn encode(schema: t.Type, rows: []const arrow.Row, workspace: []u8, output: []u8) !Segment {
    const bytes = try arrow.encode(schema, rows, workspace, output);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = bytes, .rows = @intCast(rows.len), .digest = digest };
}
