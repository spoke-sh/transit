//! Bounded caller-side steps with owned, restartable progress. Persistence,
//! source authorization and atomic result publication belong to Station.
const std = @import("std");
const f = @import("root.zig");
const m = f.model;
const a = f.arrow;
pub const progress_bytes = 143;
pub const PlanCodec = @import("StreamPlan.zig");
pub const Plan = struct {
    version: u8 = 1,
    predicate: f.Plan.Predicate = .all,
    projection: [2]?u8 = .{ 0, 1 },
    limit: ?u64 = null,
    aggregate: @FieldType(f.Plan, "aggregate") = .rows,
    fn finite(self: Plan) f.Plan {
        return .{ .predicate = self.predicate, .projection = self.projection, .aggregate = self.aggregate };
    }
    pub fn bind(self: Plan, basis: m.Basis, schema: m.Schema) !Bound {
        if (self.version != 1) return error.UnsupportedPlan;
        _ = try self.finite().bind(.{ .basis = basis, .schema = schema, .rows = &.{} });
        var bytes: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try std.json.Stringify.value(self, .{}, &writer);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.fuze.stream.plan.v1\x00");
        hash.update(writer.buffered());
        return .{ .logical = self, .basis = basis, .schema = schema, .fingerprint = hash.finalResult() };
    }
};
pub const Bound = struct {
    logical: Plan,
    basis: m.Basis,
    schema: m.Schema,
    fingerprint: [32]u8,
    pub fn start(self: Bound) Progress {
        return .{ .basis = self.basis, .plan = self.fingerprint };
    }
    pub fn explain(self: Bound) Explanation {
        return .{ .basis = self.basis, .filter = self.logical.predicate != .all, .projection = self.logical.projection, .limit = self.logical.limit, .aggregate = @tagName(self.logical.aggregate) };
    }
};
pub const Explanation = struct {
    version: u8 = 1,
    source: []const u8 = "ordered_batches",
    basis: m.Basis,
    filter: bool,
    projection: [2]?u8,
    limit: ?u64,
    aggregate: []const u8,
    batch_rows: u8 = m.max_rows,
    rewrites: [0]u8 = .{},
};
pub const Finish = enum(u8) { source_end = 1, limit = 2 };
pub const Progress = struct {
    version: u8 = 1,
    basis: m.Basis,
    plan: [32]u8,
    pages: u64 = 0,
    scanned: u64 = 0,
    selected: u64 = 0,
    segments: u64 = 0,
    rows: u64 = 0,
    last_key: ?i64 = null,
    sum: ?i64 = null,
    finished: ?Finish = null,

    pub fn validate(self: Progress, bound: Bound) !void {
        if (self.version != 1 or !std.meta.eql(self.basis, bound.basis) or !std.mem.eql(u8, &self.plan, &bound.fingerprint)) return error.SourceChanged;
        if (self.selected > self.scanned or self.segments > self.pages or
            self.scanned / m.max_rows + @intFromBool(self.scanned % m.max_rows != 0) > self.pages or
            (self.last_key == null) != (self.scanned == 0) or
            (self.pages == 0 and (self.scanned != 0 or self.sum != null or self.finished != null))) return error.InvalidQueryProgress;
        if (bound.logical.limit) |limit| if (self.selected > limit) return error.InvalidQueryProgress;
        if (self.finished == .limit and (bound.logical.limit == null or self.selected != bound.logical.limit.?)) return error.InvalidQueryProgress;
        if (self.pages > 0 and bound.logical.limit != null and self.selected == bound.logical.limit.? and self.finished != .limit) return error.InvalidQueryProgress;
        if (bound.logical.aggregate == .rows) {
            if (self.sum != null or self.rows != self.selected) return error.InvalidQueryProgress;
            if (self.selected == 0) {
                if (self.segments != @intFromBool(self.finished != null)) return error.InvalidQueryProgress;
            } else if (self.segments == 0 or self.segments > self.selected or
                self.rows / m.max_rows + @intFromBool(self.rows % m.max_rows != 0) > self.segments) return error.InvalidQueryProgress;
        } else {
            if (self.segments > 1 or self.rows != self.segments or
                (self.finished == null and self.segments != 0) or
                (self.finished != null and self.segments != 1)) return error.InvalidQueryProgress;
            if (bound.logical.aggregate == .count and self.sum != null) return error.InvalidQueryProgress;
            if (self.selected == 0 and self.sum != null) return error.InvalidQueryProgress;
        }
    }
    /// Compact owned checkpoint; it fits an ordinary state value but grants no
    /// authority. Caller publication must bind it to source and result evidence.
    pub fn encode(self: Progress) ![progress_bytes]u8 {
        if (self.version != 1) return error.InvalidQueryProgress;
        var bytes: [progress_bytes]u8 = @splat(0);
        bytes[0..4].* = "FTP1".*;
        std.mem.writeInt(u64, bytes[4..12], self.basis.resource, .little);
        std.mem.writeInt(u64, bytes[12..20], self.basis.revision, .little);
        bytes[20..52].* = self.basis.schema;
        bytes[52..84].* = self.plan;
        inline for (.{ "pages", "scanned", "selected", "segments", "rows" }, 0..) |name, i| std.mem.writeInt(u64, bytes[84 + 8 * i ..][0..8], @field(self, name), .little);
        if (self.last_key) |key| {
            bytes[124] = 1;
            std.mem.writeInt(i64, bytes[125..133], key, .little);
        }
        if (self.sum) |sum| {
            bytes[133] = 1;
            std.mem.writeInt(i64, bytes[134..142], sum, .little);
        }
        bytes[142] = if (self.finished) |finish| @backingInt(finish) else 0;
        return bytes;
    }
    pub fn decode(bytes: []const u8) !Progress {
        if (bytes.len != progress_bytes or !std.mem.eql(u8, bytes[0..4], "FTP1") or bytes[124] > 1 or bytes[133] > 1) return error.InvalidQueryProgress;
        var result: Progress = .{
            .basis = .{ .resource = std.mem.readInt(u64, bytes[4..12], .little), .revision = std.mem.readInt(u64, bytes[12..20], .little), .schema = bytes[20..52].* },
            .plan = bytes[52..84].*,
            .last_key = if (bytes[124] == 1) std.mem.readInt(i64, bytes[125..133], .little) else null,
            .sum = if (bytes[133] == 1) std.mem.readInt(i64, bytes[134..142], .little) else null,
            .finished = if (bytes[142] == 0) null else std.enums.fromInt(Finish, bytes[142]) orelse return error.InvalidQueryProgress,
        };
        inline for (.{ "pages", "scanned", "selected", "segments", "rows" }, 0..) |name, i| @field(result, name) = std.mem.readInt(u64, bytes[84 + 8 * i ..][0..8], .little);
        if (!std.mem.eql(u8, &try result.encode(), bytes)) return error.InvalidQueryProgress;
        return result;
    }
};
pub const Page = struct { ordinal: u64, source: m.Source, end: bool };
pub const Segment = struct { bytes: []const u8, rows: u8, digest: [32]u8 };
pub const Step = struct { progress: Progress, segment: ?Segment };

/// Pure candidate production. Neither progress nor a partial output buffer may
/// be published when this returns an error. No hidden retry or native worker.
pub fn step(bound: Bound, previous: Progress, page: Page, workspace: []u8, output: []u8, cancellation: *const f.execution.Cancellation) !Step {
    if (!std.meta.eql(bound, try bound.logical.bind(bound.basis, bound.schema))) return error.SourceChanged;
    try previous.validate(bound);
    if (previous.finished != null) return error.QueryComplete;
    if (page.ordinal != previous.pages) return error.InvalidQueryOrdinal;
    try page.source.validate();
    if (!std.meta.eql(bound.basis, page.source.basis) or !std.meta.eql(bound.schema, page.source.schema)) return error.SourceChanged;
    if (previous.last_key) |last| if (page.source.rows.len > 0 and page.source.rows[0].key <= last) return error.UnorderedSource;
    try cancelled(cancellation);
    var next = previous;
    next.pages = try std.math.add(u64, next.pages, 1);
    var selected: [m.max_rows]m.Row = undefined;
    var count: usize = 0;
    for (page.source.rows) |row| {
        try cancelled(cancellation);
        if (bound.logical.limit) |limit| if (next.selected == limit) break;
        next.scanned = try std.math.add(u64, next.scanned, 1);
        next.last_key = row.key;
        if (try bound.logical.finite().matches(row)) {
            selected[count] = row;
            count += 1;
            next.selected = try std.math.add(u64, next.selected, 1);
        }
    }
    if (bound.logical.aggregate == .sum and count > 0) next.sum = try sumRows(workspace, previous.sum, selected[0..count], bound.logical.projection[0].?);
    next.finished = if (bound.logical.limit != null and next.selected == bound.logical.limit.?) .limit else if (page.end) .source_end else null;
    try cancelled(cancellation);
    var segment: ?Segment = null;
    if (bound.logical.aggregate == .rows) {
        if (count > 0 or (next.finished != null and previous.segments == 0)) {
            const source: m.Source = .{ .basis = bound.basis, .schema = bound.schema, .rows = selected[0..count] };
            const logical: f.Plan = .{ .projection = bound.logical.projection, .limit = @intCast(count) };
            const encoded = try f.execution.run(try logical.bind(source), source, workspace, output, cancellation);
            segment = .{ .bytes = encoded.bytes, .rows = encoded.rows, .digest = encoded.digest };
        }
    } else if (next.finished != null) {
        const value = if (bound.logical.aggregate == .sum) next.sum else (std.math.cast(i64, next.selected) orelse return error.Overflow);
        const bytes = try scalar(workspace, output, @tagName(bound.logical.aggregate), value, bound.logical.aggregate == .sum);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        segment = .{ .bytes = bytes, .rows = 1, .digest = digest };
    }
    try cancelled(cancellation);
    if (segment) |result| {
        next.segments = try std.math.add(u64, next.segments, 1);
        next.rows = try std.math.add(u64, next.rows, result.rows);
    }
    try next.validate(bound);
    return .{ .progress = next, .segment = segment };
}
fn cancelled(flag: *const f.execution.Cancellation) !void {
    if (flag.load(.acquire)) return error.Cancelled;
}
fn sumRows(workspace: []u8, carry: ?i64, rows: []const m.Row, column: u8) !?i64 {
    var arena = std.heap.FixedBufferAllocator.init(workspace);
    const allocator = arena.allocator();
    var builder = try a.Int64Builder.init(allocator, rows.len + @intFromBool(carry != null));
    defer builder.deinit();
    // Prepending carry preserves overflow in global primary-key order. Adding
    // independently computed page totals would miss MAX + 1 followed by -1.
    if (carry) |value| try builder.append(value);
    for (rows) |row| {
        const cell = try row.cell(column);
        if (cell == .null) try builder.appendNull() else try builder.append(cell.int64);
    }
    var values = try builder.finish();
    defer values.release();
    var registry = a.compute.FunctionRegistry.init(allocator);
    defer registry.deinit();
    try f.compute.registerBaseKernels(&registry);
    var context = a.compute.ExecContext.init(allocator, &registry);
    var result = try context.invokeAggregate("sum", &.{.fromArray(values)}, .noneValue());
    defer result.release();
    return switch (result.scalar.value) {
        .null => null,
        .i64 => |value| value,
        else => error.InvalidComputeResult,
    };
}
fn scalar(workspace: []u8, output: []u8, name: []const u8, value: ?i64, nullable: bool) ![]const u8 {
    var arena = std.heap.FixedBufferAllocator.init(workspace);
    const allocator = arena.allocator();
    var builder = try a.Int64Builder.init(allocator, 1);
    defer builder.deinit();
    if (value) |number| try builder.append(number) else try builder.appendNull();
    var column = try builder.finish();
    defer column.release();
    const data_type: a.DataType = .{ .int64 = {} };
    const fields = [_]a.Field{.{ .name = name, .data_type = &data_type, .nullable = nullable }};
    var batch = try a.RecordBatch.initBorrowed(allocator, .{ .fields = &fields }, &.{column});
    defer batch.deinit();
    return f.encode(allocator, batch, output);
}
