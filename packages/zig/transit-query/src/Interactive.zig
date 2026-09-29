//! Volatile finite execution over a fresh leased source cut. No durable query
//! upload, progress, result publication or principal sequence is created here.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const Self = @This();
bundle: q.Bundle,
source: q.wire.SnapshotReader,
progress: m.Stream.Progress,
cursor: q.UnifiedSource.Cursor = .{},
bytes: u64 = 0,
cache: [64]?Cached = @splat(null),
cache_slot: usize = 0,

pub fn open(client: *q.UnifiedClient, bundle: q.Bundle, nonce: [16]u8) !Self {
    try bundle.validate();
    const description = try client.describe(bundle.source);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    var source = try q.wire.SnapshotReader.open(client.resources(), bundle.source.resource, nonce);
    errdefer source.close() catch {};
    if (source.snapshot.resource.writer != client.connection.source) return error.QuerySourceUnavailable;
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(try q.UnifiedSource.basis(bundle.source, source.view.revision), try bundle.source.schema(&columns));
    return .{ .bundle = bundle, .source = source, .progress = .start(bound) };
}
pub fn close(self: *Self) !void {
    try self.source.close();
}
pub fn complete(self: *const Self) bool {
    return self.progress.finished != null;
}
pub fn schema(self: *const Self, columns: *[m.max_columns]m.Column) !m.Schema {
    if (self.bundle.plan.aggregate != .rows) {
        columns[0] = .{ .name = try .init(@tagName(self.bundle.plan.aggregate)), .type = if (self.bundle.plan.aggregate == .count) .uint64 else .int64 };
        return .{ .columns = columns[0..1] };
    }
    var source_columns: [m.max_columns]m.Column = undefined;
    const source = try self.bundle.source.schema(&source_columns);
    for (self.bundle.plan.projection, 0..) |index, i| columns[i] = source.columns[index];
    return .{ .columns = columns[0..self.bundle.plan.projection.len] };
}
/// Returned bytes borrow output; decoded source memory belongs to this page's
/// allocator. The caller must discard that arena before requesting another page.
pub fn next(self: *Self, client: *q.UnifiedClient, allocator: std.mem.Allocator, workspace: []u8, output: []u8, cancellation: *const q.fuze.execution.Cancellation) !?m.Stream.Segment {
    if (self.complete()) return error.QueryComplete;
    if (self.progress.pages >= self.bundle.limits.pages) return error.QueryBudgetExceeded;
    if (cancellation.load(.acquire)) return error.Cancelled;
    self.source.cancellation = cancellation;
    var current = try client.resources().open(self.bundle.source.resource);
    var batch: q.UnifiedSource.Batch = undefined;
    var data: CachedReader = .{ .session = self, .view = self.source.view };
    if (self.bundle.plan.limit == 0) {
        batch = .{ .basis = self.progress.basis, .ordinal = self.cursor.ordinal, .next = .{ .done = true } };
    } else try q.UnifiedSource.page(self.bundle.source, self.progress.basis, self.cursor, &data, &current, allocator, &batch);
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try self.bundle.plan.bind(self.progress.basis, try self.bundle.source.schema(&columns));
    const candidate = try m.Stream.step(bound, self.progress, batch.engine(), workspace, output, cancellation);
    const bytes = try std.math.add(u64, self.bytes, if (candidate.segment) |segment| segment.bytes.len else 0);
    if (candidate.progress.segments > self.bundle.limits.segments or bytes > self.bundle.limits.result_bytes) return error.QueryBudgetExceeded;
    // A previously authorized snapshot is not a current source policy. This
    // check precedes every disclosure, including a terminal zero-row result.
    // Even an entirely cached page must renew/check its lease and current native
    // permission. The one-byte key is an ordinary bounded point probe; its value
    // is discarded. It is not a reserved key or a separate authority operation.
    _ = try self.source.entry(try q.protocol.Value.init("\x00"));
    const current_policy = try client.describe(self.bundle.source);
    if (!current_policy.limits.permits(self.bundle.limits)) return error.QueryBudgetExceeded;
    if (cancellation.load(.acquire)) return error.Cancelled;
    self.progress = candidate.progress;
    self.cursor = batch.next;
    self.bytes = bytes;
    return candidate.segment;
}

const Cached = struct { key: q.protocol.Value, entry: ?q.protocol.Growth.Entry };
const CachedReader = struct {
    session: *Self,
    view: @FieldType(q.wire.SnapshotReader, "view"),
    pub fn read(self: *@This(), key: q.protocol.Value) !?q.protocol.Value {
        return if (try self.entry(key)) |value| value.value else null;
    }
    pub fn entry(self: *@This(), key: q.protocol.Value) !?q.protocol.Growth.Entry {
        if (self.session.source.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
        for (self.session.cache) |slot| if (slot) |cached| {
            if (cached.key.eql(key)) return cached.entry;
        };
        const result = try self.session.source.entry(key);
        self.session.cache[self.session.cache_slot] = .{ .key = key, .entry = result };
        self.session.cache_slot = (self.session.cache_slot + 1) % self.session.cache.len;
        return result;
    }
    pub fn page(self: *@This(), after: ?q.protocol.Value) !q.protocol.Growth.Batch(q.protocol.Growth.Entry, q.protocol.Value) {
        return self.session.source.page(after);
    }
};
