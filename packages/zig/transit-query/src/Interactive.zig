//! Volatile finite execution over a fresh leased source cut. No durable query
//! upload, progress, result publication or principal sequence is created here.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const g = q.protocol.Growth;
const Self = @This();
bundle: q.Bundle,
source: q.wire.SnapshotReader,
progress: m.Stream.Progress,
columns: [m.max_columns]m.Column,
column_count: usize,
cursor: q.UnifiedSource.Cursor = .{},
bytes: u64 = 0,
cache: [64]?Cached = @splat(null),
cache_slot: usize = 0,
batched: bool = false,
current: ?q.wire.ResourceReader.Batch = null,
range: ?g.SnapshotRead.Range = null,
range_entries: [g.SnapshotRead.range_entries]?g.Entry = @splat(null),
range_next: ?q.protocol.Value = null,
range_index: usize = 0,
range_available: bool = false,

pub fn open(client: *q.UnifiedClient, bundle: q.Bundle, nonce: [16]u8) !Self {
    try bundle.validate();
    if (client.snapshot_support == null) client.snapshot_support = try q.wire.SnapshotReader.support(client.resources());
    const support = client.snapshot_support.?;
    if (support.batched) {
        const request = try opening(client, bundle, nonce);
        var acquired = try support.acquire(request);
        errdefer acquired.reader.close() catch {};
        if (acquired.reader.snapshot.resource.writer != client.connection.source) return error.QuerySourceUnavailable;
        const description = try client.interactiveDescription(bundle.source, acquired.result);
        if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
        var columns: [m.max_columns]m.Column = undefined;
        const bound = try bundle.plan.bind(try q.UnifiedSource.basis(bundle.source, acquired.reader.view.revision), try bundle.source.schema(&columns));
        var result: Self = .{ .bundle = bundle, .source = acquired.reader, .progress = .start(bound), .columns = columns, .column_count = bound.schema.columns.len, .batched = true, .range = request.range };
        result.current = q.UnifiedClient.interactiveBatch(request.current[0].?, acquired.result.current[0].?);
        for (request.points, acquired.result.points) |key, value| if (key) |requested| result.remember(requested, value);
        if (request.range != null) result.acceptRange(acquired.result);
        return result;
    }
    const description = try client.describe(bundle.source);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    var source = try support.open(bundle.source.resource, nonce);
    errdefer source.close() catch {};
    if (source.snapshot.resource.writer != client.connection.source) return error.QuerySourceUnavailable;
    var columns: [m.max_columns]m.Column = undefined;
    const bound = try bundle.plan.bind(try q.UnifiedSource.basis(bundle.source, source.view.revision), try bundle.source.schema(&columns));
    return .{ .bundle = bundle, .source = source, .progress = .start(bound), .columns = columns, .column_count = bound.schema.columns.len };
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
    // Only Document reads live lifecycle records through this adapter. Keep the
    // unused reader fail-closed so a future adapter cannot silently use it.
    var current: q.wire.ResourceReader.Reader = if (!self.batched and self.bundle.source.source == .document)
        try client.resources().open(self.bundle.source.resource)
    else
        .{ .client = client.resources(), .view = .{ .resource = self.bundle.source.resource, .revision = 0 }, .failed = error.InvalidResourceRead };
    var batch: q.UnifiedSource.Batch = undefined;
    var data: CachedReader = .{ .session = self, .view = self.source.view };
    if (self.bundle.plan.limit == 0) {
        batch = .{ .basis = self.progress.basis, .ordinal = self.cursor.ordinal, .next = .{ .done = true } };
    } else if (self.batched) {
        try q.UnifiedSource.pagePlanned(self.bundle.source, self.bundle.plan, self.progress.basis, self.cursor, &data, &self.current.?, allocator, &batch);
    } else try q.UnifiedSource.pagePlanned(self.bundle.source, self.bundle.plan, self.progress.basis, self.cursor, &data, &current, allocator, &batch);
    const bound: m.Plan.Bound = .{ .plan = self.bundle.plan, .basis = self.progress.basis, .schema = .{ .columns = self.columns[0..self.column_count] }, .fingerprint = self.progress.plan };
    const candidate = try m.Stream.step(bound, self.progress, batch.engine(), workspace, output, cancellation);
    const bytes = try std.math.add(u64, self.bytes, if (candidate.segment) |segment| segment.bytes.len else 0);
    if (candidate.progress.segments > self.bundle.limits.segments or bytes > self.bundle.limits.result_bytes) return error.QueryBudgetExceeded;
    // Final live validation also covers entirely cached computation and empty
    // output. The terminal validation releases the pin in the same native call.
    const current_policy = if (self.batched) policy: {
        const metadata = try client.interactiveMetadata(self.bundle.source);
        const validated = try self.source.batch(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = metadata, .finish = candidate.progress.finished != null });
        const description = try client.interactiveDescription(self.bundle.source, validated);
        self.current = q.UnifiedClient.interactiveBatch(metadata[0].?, validated.current[0].?);
        break :policy description;
    } else policy: {
        _ = try self.source.entry(try q.protocol.Value.init("\x00"));
        break :policy try client.describe(self.bundle.source);
    };
    if (!current_policy.limits.permits(self.bundle.limits)) return error.QueryBudgetExceeded;
    if (cancellation.load(.acquire)) return error.Cancelled;
    self.progress = candidate.progress;
    self.cursor = batch.next;
    self.bytes = bytes;
    return candidate.segment;
}

fn remember(self: *Self, key: q.protocol.Value, value: ?g.Entry) void {
    self.cache[self.cache_slot] = .{ .key = key, .entry = value };
    self.cache_slot = (self.cache_slot + 1) % self.cache.len;
}
fn acceptRange(self: *Self, result: g.SnapshotRead.Result) void {
    self.range_entries = result.entries;
    self.range_next = result.next;
    self.range_index = 0;
    self.range_available = true;
}
fn opening(client: *q.UnifiedClient, bundle: q.Bundle, nonce: [16]u8) !g.SnapshotRead.Query {
    var request: g.SnapshotRead.Query = .{ .snapshot = .{ .open = .{ .resource = bundle.source.resource, .nonce = nonce } }, .current = try client.interactiveMetadata(bundle.source) };
    if (bundle.plan.limit == 0) return request;
    switch (bundle.source.source) {
        .kv => |kv| request.range = .{ .prefix = if (kv.prefix.len == 0) null else kv.prefix },
        .document => |document| request.points[0] = (try document.reference.identity().service()).key('v', document.reference.revision),
        .table => |table| {
            request.points[0] = q.station.Table.descriptorKey(table.id);
            const prefix = try q.protocol.Value.init(q.station.Table.rowKey(table.id, 0).data[0..6]);
            request.range = .{ .prefix = prefix, .after = prefix };
            if (bundle.plan.predicate == .compare) {
                const comparison = bundle.plan.predicate.compare;
                if (comparison.column == 0 and comparison.value == .int64) switch (comparison.op) {
                    .eq => {
                        request.points[1] = q.station.Table.rowKey(table.id, comparison.value.int64);
                        request.range = null;
                    },
                    .gt => request.range.?.after = q.station.Table.rowKey(table.id, comparison.value.int64),
                    .ge => if (comparison.value.int64 != std.math.minInt(i64)) {
                        request.range.?.after = q.station.Table.rowKey(table.id, comparison.value.int64 - 1);
                    },
                    else => {},
                };
            }
        },
    }
    if (request.range != null and bundle.plan.predicate == .all) if (bundle.plan.limit) |limit| {
        request.range.?.limit = @intCast(@min(limit, g.SnapshotRead.range_entries));
    };
    return request;
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
        self.session.remember(key, result);
        return result;
    }
    pub fn page(self: *@This(), after: ?q.protocol.Value) !q.protocol.Growth.Batch(q.protocol.Growth.Entry, q.protocol.Value) {
        const session = self.session;
        if (!session.batched) return session.source.page(after);
        if (!session.range_available) {
            var range = session.range orelse g.SnapshotRead.Range{};
            range.after = after;
            session.acceptRange(try session.source.batch(.{ .snapshot = .{ .existing = session.source.snapshot.id }, .range = range }));
        }
        var result: g.Batch(g.Entry, q.protocol.Value) = .{};
        var count: usize = 0;
        while (session.range_index < session.range_entries.len and count < g.page_size) {
            const item = session.range_entries[session.range_index] orelse break;
            // The buffer belongs to this monotonically advancing source cursor.
            if (after) |key| if (std.mem.order(u8, item.key.slice(), key.slice()) != .gt) return error.InvalidResourceRead;
            result.entries[count] = item;
            count += 1;
            session.range_index += 1;
        }
        const buffered = session.range_index < session.range_entries.len and session.range_entries[session.range_index] != null;
        if (buffered or session.range_next != null) {
            if (count == 0) return error.InvalidResourceRead;
            result.next = result.entries[count - 1].?.key;
        }
        if (!buffered) session.range_available = false;
        return result;
    }
};
