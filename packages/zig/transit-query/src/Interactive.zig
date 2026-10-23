//! Volatile finite execution over a fresh leased source cut. No durable query
//! upload, progress, result publication or principal sequence is created here.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const g = q.protocol.Growth;
const Self = @This();
bundle: q.Bundle,
source: ?q.wire.SnapshotReader = null,
table: ?q.catalog.DirectTableReader.Basis = null,
closed: bool = false,
progress: f.LogicalStream.Progress,
basis: q.Basis,
cursor: q.UnifiedSource.Cursor = .{},
bytes: u64 = 0,
cache: [64]?Cached = @splat(null),
cache_slot: usize = 0,
table_nodes: q.station.TablePages.Cache = .{},
block_cache: ?q.wire.BlockBatch = null,
current: ?q.wire.ResourceReader.Batch = null,
range: ?g.SnapshotRead.Range = null,
range_entries: [g.SnapshotRead.range_entries]?g.Entry = @splat(null),
range_next: ?q.protocol.Value = null,
range_index: usize = 0,
range_available: bool = false,
diagnostic: ?q.protocol.Diagnostic = null,

pub fn open(client: *q.UnifiedClient, bundle: q.Bundle, nonce: [16]u8, allocator: std.mem.Allocator) !Self {
    _ = allocator;
    try bundle.validate();
    if (bundle.source.source == .table) return error.QueryTableSnapshotRequired;
    if (client.snapshot_support == null) _ = try client.batchSupport();
    const support = client.snapshot_support orelse return error.InteractiveQueriesUnavailable;
    const request = try opening(client, bundle, nonce);
    var acquired = try support.acquire(request);
    errdefer acquired.reader.close() catch {};
    if (acquired.reader.snapshot.resource.writer != client.connection.source) return error.QuerySourceUnavailable;
    const description = try client.interactiveDescription(bundle.source, request.current, acquired.result);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    var result: Self = .{ .bundle = bundle, .source = acquired.reader, .progress = undefined, .basis = undefined, .range = request.range };
    result.current = q.UnifiedClient.interactiveBatch(request.current[0].?, acquired.result.current[0].?);
    for (request.points, acquired.result.points) |key, value| if (key) |requested| result.remember(requested, value);
    if (request.range != null) result.acceptRange(acquired.result);
    const data: CachedReader = .{ .session = &result, .view = result.source.?.view };
    const grant = (try q.UnifiedCapture.policy(&result.current.?, client.connection.requester)) orelse return error.QueryDenied;
    try q.UnifiedSource.checkCurrent(bundle.source, &result.current.?, try grant.principal(bundle.source));
    if (data.view.resource != bundle.source.resource) return error.SourceChanged;
    result.basis = try q.UnifiedSource.basis(bundle.source, data.view.revision);
    result.progress = try f.LogicalStream.Progress.start(try bundle.bind(try result.basis.fingerprint()));
    const metadata = try client.interactiveMetadata(bundle.source);
    const refreshed = try result.source.?.batch(.{ .snapshot = .{ .existing = result.source.?.snapshot.id }, .current = metadata });
    _ = try client.interactiveDescription(bundle.source, metadata, refreshed);
    // Carry the newly checked live observation into page reads. The retained
    // reader and basis still name the opening cut, including across writes.
    result.current = q.UnifiedClient.interactiveBatch(metadata[0].?, refreshed.current[0].?);
    return result;
}
pub fn close(self: *Self) !void {
    if (self.source) |*source| try source.close();
    self.closed = true;
}
pub fn complete(self: *const Self) bool {
    return self.progress.finished != null;
}
pub fn schema(self: *const Self, columns: *[q.SourceDefinition.max_columns]f.Types.Field) !f.Types.Type {
    return self.bundle.plan.outputSchema(columns);
}
/// Returned bytes borrow output; decoded source memory belongs to this page's
/// allocator. The caller must discard that arena before requesting another page.
pub fn next(self: *Self, client: *q.UnifiedClient, allocator: std.mem.Allocator, workspace: []u8, output: []u8, cancellation: *const q.fuze.execution.Cancellation) !?f.LogicalStream.Segment {
    self.diagnostic = null;
    if (self.closed) return error.QueryClosed;
    if (self.complete()) return error.QueryComplete;
    if (self.progress.pages >= self.bundle.limits.pages) {
        if (self.diagnosticAllowed(client)) self.diagnostic = q.ExecutionDiagnostic.budget(.pages, self.bundle.limits.pages, std.math.add(u64, self.progress.pages, 1) catch return error.Overflow) catch null;
        return error.QueryBudgetExceeded;
    }
    if (cancellation.load(.acquire)) return error.Cancelled;
    if (self.source) |*source| source.cancellation = cancellation;
    var batch: q.UnifiedSource.Batch = undefined;
    var batch_initialized = false;
    defer if (batch_initialized) batch.deinit();
    var data: CachedReader = .{ .session = self, .view = if (self.source) |source| source.view else .{ .resource = self.bundle.source.resource, .revision = 0 } };
    const bound = try self.bundle.bind(try self.basis.fingerprint());
    const principal = if (self.table != null) client.connection.principal else try ((try q.UnifiedCapture.policy(&self.current.?, client.connection.requester)) orelse return error.QueryDenied).principal(self.bundle.source);
    if (self.bundle.source.source == .table) {
        const direct = client.tables orelse return error.QuerySourceUnavailable;
        const retained = self.table orelse return error.QueryTableSnapshotRequired;
        if (self.bundle.plan.limit == 0) {
            try self.checkTable(client);
            batch = .{ .basis = self.basis, .binding = bound.source_basis, .ordinal = self.cursor.ordinal, .next = .{ .ordinal = self.cursor.ordinal + 1, .done = true } };
        } else try q.UnifiedSource.tablePage(self.bundle.source, bound, self.basis, retained, self.cursor, direct, allocator, &batch);
        batch_initialized = true;
    } else if (self.bundle.plan.limit == 0) {
        try q.UnifiedSource.checkCurrent(self.bundle.source, &self.current.?, principal);
        batch = .{ .basis = self.basis, .binding = bound.source_basis, .ordinal = self.cursor.ordinal, .next = .{ .ordinal = self.cursor.ordinal + 1, .done = true } };
        batch_initialized = true;
    } else {
        try q.UnifiedSource.page(self.bundle.source, bound, self.basis, self.cursor, &data, &self.current.?, principal, allocator, &batch);
        batch_initialized = true;
    }
    var failure: ?f.LogicalStream.Failure = null;
    const candidate = f.LogicalStream.step(bound, self.progress, batch.engine(), workspace, output, cancellation, &failure) catch |err| {
        if (failure) |evidence| {
            // A failed computation still needs fresh authorization before keys
            // or the retained execution basis can enter a diagnostic.
            if (self.diagnosticAllowed(client)) self.diagnostic = q.ExecutionDiagnostic.local(err, bound, &batch, evidence) catch null;
        }
        return err;
    };
    const bytes = try std.math.add(u64, self.bytes, if (candidate.segment) |segment| segment.bytes.len else 0);
    if (candidate.progress.segments > self.bundle.limits.segments) {
        if (self.diagnosticAllowed(client)) self.diagnostic = q.ExecutionDiagnostic.budget(.segments, self.bundle.limits.segments, candidate.progress.segments) catch null;
        return error.QueryBudgetExceeded;
    }
    if (bytes > self.bundle.limits.result_bytes) {
        if (self.diagnosticAllowed(client)) self.diagnostic = q.ExecutionDiagnostic.budget(.result_bytes, self.bundle.limits.result_bytes, bytes) catch null;
        return error.QueryBudgetExceeded;
    }
    // Final live validation also covers entirely cached computation and empty
    // output. The terminal validation releases the pin in the same native call.
    const current_policy = if (self.table != null) policy: {
        try self.checkTable(client);
        break :policy try client.authorize(self.bundle.source);
    } else policy: {
        const metadata = try client.interactiveMetadata(self.bundle.source);
        const validated = try self.source.?.batch(.{ .snapshot = .{ .existing = self.source.?.snapshot.id }, .current = metadata, .finish = candidate.progress.finished != null });
        const description = try client.interactiveDescription(self.bundle.source, metadata, validated);
        self.current = q.UnifiedClient.interactiveBatch(metadata[0].?, validated.current[0].?);
        break :policy description;
    };
    if (!current_policy.limits.permits(self.bundle.limits)) return error.QueryBudgetExceeded;
    if (cancellation.load(.acquire)) return error.Cancelled;
    self.progress = candidate.progress;
    self.cursor = batch.next;
    self.bytes = bytes;
    return candidate.segment;
}

/// The caller owns this durable direct pin, including uncertain acquisition
/// and eventual release. Closing the local evaluator does not release it.
pub fn openTable(client: *q.UnifiedClient, bundle: q.Bundle, snapshot: q.catalog.DirectTableProtocol.Snapshot, allocator: std.mem.Allocator) !Self {
    try bundle.validate();
    if (bundle.source.source != .table) return error.InvalidQuerySource;
    const description = try client.authorize(bundle.source);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    const retained = try bundle.source.source.table.capture(allocator, client.tables orelse return error.QuerySourceUnavailable, snapshot);
    const basis = try retained.record();
    return .{ .bundle = bundle, .table = retained.retained, .basis = basis, .progress = try f.LogicalStream.Progress.start(try bundle.bind(try basis.fingerprint())) };
}
fn checkTable(self: *Self, client: *q.UnifiedClient) !void {
    const retained = self.table orelse return error.QueryTableSnapshotRequired;
    const direct = client.tables orelse return error.QuerySourceUnavailable;
    try self.bundle.source.source.table.requireConnection(direct);
    const response = try direct.call(.{ .snapshot = retained.snapshot });
    defer response.deinit();
    const source = response.value.result.snapshot;
    const actual: q.catalog.DirectTableReader.Basis = .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.row_count, .authority = source.authority };
    if (!std.meta.eql(actual, retained)) return error.SourceChanged;
}

fn diagnosticAllowed(self: *Self, client: *q.UnifiedClient) bool {
    if (self.table != null) {
        self.checkTable(client) catch return false;
        const permitted = client.authorize(self.bundle.source) catch return false;
        return permitted.limits.permits(self.bundle.limits);
    }
    const metadata = client.interactiveMetadata(self.bundle.source) catch return false;
    const validated = self.source.?.batch(.{ .snapshot = .{ .existing = self.source.?.snapshot.id }, .current = metadata }) catch return false;
    const permitted = client.interactiveDescription(self.bundle.source, metadata, validated) catch return false;
    return permitted.limits.permits(self.bundle.limits);
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
        .table => return error.QueryTableSnapshotRequired,
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
    pub fn tableIndexCache(self: *@This()) *q.station.TablePages.Cache {
        return &self.session.table_nodes;
    }
    pub fn read(self: *@This(), key: q.protocol.Value) !?q.protocol.Value {
        return if (try self.entry(key)) |value| value.value else null;
    }
    pub fn readBlock(self: *@This(), key: q.protocol.Value, output: []u8) !?[]const u8 {
        try self.prefetchBlocks(&.{key});
        return self.session.block_cache.?.read(key, output);
    }
    pub fn prefetchBlocks(self: *@This(), keys: []const q.protocol.Value) !void {
        if (self.session.source.?.failed) |err| return err;
        if (self.session.source.?.closed) return error.QueryClosed;
        if (self.session.source.?.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
        if (keys.len == 0) return;
        if (keys.len > g.page_size) return error.InvalidResourceRead;
        if (self.session.block_cache) |*cache| {
            const all = for (keys) |key| {
                if (!cache.contains(key)) break false;
            } else true;
            if (all) return;
        }
        var request: g.SnapshotRead.Query = .{ .snapshot = .{ .existing = self.session.source.?.snapshot.id } };
        for (keys, 0..) |key, i| request.blocks[i] = key;
        var body: q.protocol.Blocks.Body = .{};
        const result = try self.session.source.?.blockBatch(request, &body);
        self.session.block_cache = try q.wire.BlockBatch.init(request.blocks, result.blocks, body);
    }
    pub fn entry(self: *@This(), key: q.protocol.Value) !?q.protocol.Growth.Entry {
        if (self.session.source.?.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
        for (self.session.cache) |slot| if (slot) |cached| {
            if (cached.key.eql(key)) return cached.entry;
        };
        try self.prefetch(&.{key});
        for (self.session.cache) |slot| if (slot) |cached| {
            if (cached.key.eql(key)) return cached.entry;
        };
        return error.InvalidResourceRead;
    }
    /// Publication adapters can acquire known immutable chunks together. The
    /// normal decoder still verifies every descriptor, chunk and commitment.
    pub fn prefetch(self: *@This(), keys: []const q.protocol.Value) !void {
        if (keys.len > g.page_size) return error.InvalidResourceRead;
        var missing: g.SnapshotRead.Keys = @splat(null);
        var count: usize = 0;
        outer: for (keys) |key| {
            for (self.session.cache) |slot| if (slot) |cached| {
                if (cached.key.eql(key)) continue :outer;
            };
            for (missing[0..count]) |slot| if (slot.?.eql(key)) continue :outer;
            missing[count] = key;
            count += 1;
        }
        if (count == 0) return;
        const result = try self.session.source.?.batch(.{ .snapshot = .{ .existing = self.session.source.?.snapshot.id }, .points = missing });
        for (missing[0..count], result.points[0..count]) |key, value| self.session.remember(key.?, value);
    }
    pub fn page(self: *@This(), after: ?q.protocol.Value) !q.protocol.Growth.Batch(q.protocol.Growth.Entry, q.protocol.Value) {
        const session = self.session;
        if (!session.range_available) {
            var range = session.range orelse g.SnapshotRead.Range{};
            range.after = after;
            session.acceptRange(try session.source.?.batch(.{ .snapshot = .{ .existing = session.source.?.snapshot.id }, .range = range }));
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
