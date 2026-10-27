//! Transport-independent row consumption. A source owns its buffers; this owner
//! validates semantic progress and never interprets a cursor or a wire message.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
pub const Chunk = struct { values: r.Batch, completion: ?r.Completion };
pub const Source = struct {
    context: *anyopaque,
    next: *const fn (*anyopaque) anyerror!Chunk,
    close: *const fn (*anyopaque) anyerror!void,
    deinit: *const fn (*anyopaque) void,
    failure: ?*const fn (*anyopaque) ?r.Failure = null,
};
schema: r.Types.Type,
observation: r.Observation.Value,
progress: r.Progress,
source: Source,
chunk: r.Batch = .{},
row_scratch: [(r.Types.Limits{}).nodes]r.Types.Values.Cell = undefined,
index: usize = 0,
closed: bool = false,

/// Schema/observation and source context remain owned by source until deinit.
pub fn init(schema: r.Types.Type, observation: r.Observation.Value, identity: r.Identity, source: Source) !Self {
    try schema.validate(.{});
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
    self.chunk = .{};
    self.index = 0;
    self.progress.release();
    try self.source.close(self.source.context);
}
pub fn completion(self: Self) ?r.Completion {
    return self.progress.completion();
}
pub fn failure(self: Self) ?r.Failure {
    return if (self.source.failure) |read| read(self.source.context) else null;
}
/// Accept a source-owned initial or subsequent chunk atomically. Native adapters
/// expose already received terminal evidence before the first delivery.
pub fn receive(self: *Self, chunk: Chunk) !void {
    if (self.closed or self.index != self.chunk.len) return error.InvalidResultTransition;
    if (chunk.values.len == 0 and chunk.completion == null) return error.InvalidResultChunk;
    try chunk.values.validate(self.schema.structure);
    var state = self.progress;
    if (chunk.values.len != 0) try state.receive(state.identity, chunk.values.len);
    if (chunk.completion) |terminal| try state.finish(state.identity, terminal);
    self.progress = state;
    self.chunk = chunk.values;
    self.index = 0;
}
/// The returned row is borrowed until the next advance or closure. Merely
/// peeking does not deliver it; bounded windows can leave a non-fitting row here.
fn ensureAvailable(self: *Self) !bool {
    if (self.closed) return if (self.progress.consumption == .exhausted) false else error.ResultClosed;
    if (self.progress.consumption == .stopped) return error.ResultIncomplete;
    errdefer {
        self.progress.fail(false);
        self.close() catch {};
    }
    if (self.index < self.chunk.len) return true;
    if (self.progress.consumption == .exhausted) {
        try self.close();
        return false;
    }
    const chunk = self.source.next(self.source.context) catch |err| {
        self.progress.fail(err == error.Canceled or err == error.ResultCancelled);
        return err;
    };
    try self.receive(chunk);
    if (chunk.values.len == 0) {
        try self.close();
        return false;
    }
    return true;
}
pub fn peekRow(self: *Self) !?r.Row {
    if (!try self.ensureAvailable()) return null;
    return try self.chunk.rowInto(self.index, &self.row_scratch);
}
pub fn nextRow(self: *Self) !?r.Row {
    const row = try self.peekRow() orelse return null;
    try self.progress.deliver(1);
    self.index += 1;
    return row;
}
/// Logical chunks are borrowed efficiency units; they carry no fetch ordinal,
/// schema repetition or end-of-stream sentinel for the consumer to interpret.
pub fn nextBatch(self: *Self) !?r.Batch {
    if (!try self.ensureAvailable()) return null;
    const batch = try self.chunk.slice(self.index, self.chunk.len - self.index);
    try self.progress.deliver(batch.len);
    self.index = self.chunk.len;
    return batch;
}
