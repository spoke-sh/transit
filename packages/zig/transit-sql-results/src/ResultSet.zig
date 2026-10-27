//! Transport-independent row consumption. A source owns its buffers; this owner
//! validates semantic progress and never interprets a cursor or a wire message.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
pub const Chunk = struct { rows: []const r.Row, completion: ?r.Completion };
pub const Source = struct {
    context: *anyopaque,
    next: *const fn (*anyopaque) anyerror!Chunk,
    close: *const fn (*anyopaque) anyerror!void,
    deinit: *const fn (*anyopaque) void,
};
schema: r.Types.Type,
observation: r.Observation.Value,
progress: r.Progress,
source: Source,
chunk: []const r.Row = &.{},
index: usize = 0,
closed: bool = false,

/// Schema/observation and source context remain owned by source until deinit.
pub fn init(schema: r.Types.Type, observation: r.Observation.Value, identity: r.Identity, source: Source) !Self {
    if (schema != .structure or !std.mem.eql(u8, &try schema.fingerprint(), &identity.schema)) return error.InvalidResultSchema;
    return .{ .schema = schema, .observation = observation, .progress = .{ .identity = identity }, .source = source };
}
pub fn deinit(self: *Self) void {
    self.close() catch {};
    self.source.deinit(self.source.context);
    self.* = undefined;
}
pub fn close(self: *Self) !void {
    if (self.closed) return;
    self.closed = true;
    self.chunk = &.{};
    self.index = 0;
    self.progress.release();
    try self.source.close(self.source.context);
}
pub fn completion(self: Self) ?r.Completion {
    return self.progress.completion();
}
/// The returned row is borrowed until the next advance or closure. Merely
/// peeking does not deliver it; bounded windows can leave a non-fitting row here.
pub fn peekRow(self: *Self) !?r.Row {
    if (self.closed) return if (self.progress.consumption == .exhausted) null else error.ResultClosed;
    if (self.progress.consumption == .stopped) return error.ResultIncomplete;
    errdefer {
        self.progress.fail(false);
        self.close() catch {};
    }
    if (self.index < self.chunk.len) return self.chunk[self.index];
    if (self.progress.consumption == .exhausted) {
        try self.close();
        return null;
    }
    const chunk = self.source.next(self.source.context) catch |err| {
        self.progress.fail(err == error.Canceled or err == error.ResultCancelled);
        return err;
    };
    if (chunk.rows.len == 0 and chunk.completion == null) return error.InvalidResultChunk;
    for (chunk.rows) |row| {
        if (row.len != self.schema.structure.len) return error.InvalidResultRow;
        for (row, self.schema.structure) |cell, field| try cell.validate(field, .{});
    }
    if (chunk.rows.len != 0) try self.progress.receive(self.progress.identity, chunk.rows.len);
    if (chunk.completion) |terminal| try self.progress.finish(self.progress.identity, terminal);
    self.chunk = chunk.rows;
    self.index = 0;
    if (chunk.rows.len == 0) {
        try self.close();
        return null;
    }
    return chunk.rows[0];
}
pub fn nextRow(self: *Self) !?r.Row {
    const row = try self.peekRow() orelse return null;
    try self.progress.deliver(1);
    self.index += 1;
    return row;
}
/// Logical chunks are borrowed efficiency units; they carry no fetch ordinal,
/// schema repetition or end-of-stream sentinel for the consumer to interpret.
pub fn nextChunk(self: *Self) !?[]const r.Row {
    _ = try self.peekRow() orelse return null;
    const rows = self.chunk[self.index..];
    try self.progress.deliver(rows.len);
    self.index = self.chunk.len;
    return rows;
}
