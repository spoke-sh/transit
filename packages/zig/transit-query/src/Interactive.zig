//! Volatile finite execution over a fresh leased source cut. No durable query
//! upload, progress, result publication or principal sequence is created here.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const g = q.protocol.Growth;
const Self = @This();
bundle: q.Bundle,
source: q.wire.SnapshotReader,
progress: f.LogicalStream.Progress,
basis: q.Basis,
cursor: q.UnifiedSource.Cursor = .{},
bytes: u64 = 0,
cache: [64]?Cached = @splat(null),
cache_slot: usize = 0,
table_nodes: q.station.ImmutableIndex.Cache = .{},
current: ?q.wire.ResourceReader.Batch = null,
range: ?g.SnapshotRead.Range = null,
range_entries: [g.SnapshotRead.range_entries]?g.Entry = @splat(null),
range_next: ?q.protocol.Value = null,
range_index: usize = 0,
range_available: bool = false,
diagnostic: ?q.protocol.Diagnostic = null,

pub fn open(client: *q.UnifiedClient, bundle: q.Bundle, nonce: [16]u8, allocator: std.mem.Allocator) !Self {
    try bundle.validate();
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
    var data: CachedReader = .{ .session = &result, .view = result.source.view };
    const grant = (try q.UnifiedCapture.policy(&result.current.?, client.connection.requester)) orelse return error.QueryDenied;
    // The opening snapshot is the admission cut. Current policy is checked
    // independently before any schema or row is disclosed.
    // Table admission resolves the complete live schema at the authorization
    // batch's exact revision; that bounded batch alone is not a schema reader.
    result.basis = if (bundle.source.source == .table) table: {
        var cached = (try client.batchSupport()).cached(result.current.?);
        const authority = try tableAuthority(client, bundle.source);
        var current = authority.wrapAcquisition(&cached);
        var retained = authority.wrapAcquisition(&data);
        const basis = try (try bundle.source.source.table.capture(allocator, &retained, &current, try grant.tablePrincipal(bundle.source.source.table))).record();
        try retained.finish();
        try current.finish();
        break :table basis;
    } else try q.UnifiedSource.capture(bundle.source, &data, &result.current.?, try grant.principal(bundle.source), allocator);
    result.progress = try f.LogicalStream.Progress.start(try bundle.bind(try result.basis.fingerprint()));
    const metadata = try client.interactiveMetadata(bundle.source);
    const refreshed = try result.source.batch(.{ .snapshot = .{ .existing = result.source.snapshot.id }, .current = metadata });
    _ = try client.interactiveDescription(bundle.source, metadata, refreshed);
    // Carry the newly checked live observation into page reads. The retained
    // reader and basis still name the opening cut, including across writes.
    result.current = q.UnifiedClient.interactiveBatch(metadata[0].?, refreshed.current[0].?);
    return result;
}
pub fn close(self: *Self) !void {
    try self.source.close();
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
    if (self.complete()) return error.QueryComplete;
    if (self.progress.pages >= self.bundle.limits.pages) {
        if (self.diagnosticAllowed(client)) self.diagnostic = q.ExecutionDiagnostic.budget(.pages, self.bundle.limits.pages, std.math.add(u64, self.progress.pages, 1) catch return error.Overflow) catch null;
        return error.QueryBudgetExceeded;
    }
    if (cancellation.load(.acquire)) return error.Cancelled;
    self.source.cancellation = cancellation;
    var batch: q.UnifiedSource.Batch = undefined;
    var batch_initialized = false;
    defer if (batch_initialized) batch.deinit();
    var data: CachedReader = .{ .session = self, .view = self.source.view };
    const bound = try self.bundle.bind(try self.basis.fingerprint());
    const grant = (try q.UnifiedCapture.policy(&self.current.?, client.connection.requester)) orelse return error.QueryDenied;
    const principal = try grant.principal(self.bundle.source);
    if (self.bundle.source.source == .table) {
        var cached = (try client.batchSupport()).cached(self.current.?);
        const authority = try tableAuthority(client, self.bundle.source);
        var current = authority.wrapAcquisition(&cached);
        var retained = authority.wrapAcquisition(&data);
        if (self.bundle.plan.limit == 0) {
            _ = try self.bundle.source.source.table.checkCurrent(&current, principal orelse return error.QueryDenied);
            batch = .{ .basis = self.basis, .binding = bound.source_basis, .ordinal = self.cursor.ordinal, .next = .{ .ordinal = self.cursor.ordinal + 1, .done = true } };
            batch_initialized = true;
        } else {
            try q.UnifiedSource.tablePage(self.bundle.source, bound, self.basis, self.cursor, &retained, &current, principal orelse return error.QueryDenied, allocator, &batch);
            batch_initialized = true;
            try retained.finish();
        }
        try current.finish();
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
    const current_policy = policy: {
        const metadata = try client.interactiveMetadata(self.bundle.source);
        const validated = try self.source.batch(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = metadata, .finish = candidate.progress.finished != null });
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

fn tableAuthority(client: *q.UnifiedClient, definition: q.SourceDefinition) !q.catalog.TableAuthority.Context {
    const authorization = client.authorizationClient();
    return .{ .client = authorization, .subject = try authorization.proof(client.connection.source, try definition.fingerprint()) };
}

fn diagnosticAllowed(self: *Self, client: *q.UnifiedClient) bool {
    const metadata = client.interactiveMetadata(self.bundle.source) catch return false;
    const validated = self.source.batch(.{ .snapshot = .{ .existing = self.source.snapshot.id }, .current = metadata }) catch return false;
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
        .table => |table| {
            request.points[0] = q.catalog.Records.key(table.scope.catalog, 'c', 0, 0);
            request.points[1] = q.station.TableHead.key(table.object);
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
    pub fn tableIndexCache(self: *@This()) *q.station.ImmutableIndex.Cache {
        return &self.session.table_nodes;
    }
    pub fn read(self: *@This(), key: q.protocol.Value) !?q.protocol.Value {
        return if (try self.entry(key)) |value| value.value else null;
    }
    pub fn entry(self: *@This(), key: q.protocol.Value) !?q.protocol.Growth.Entry {
        if (self.session.source.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
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
        const result = try self.session.source.batch(.{ .snapshot = .{ .existing = self.session.source.snapshot.id }, .points = missing });
        for (missing[0..count], result.points[0..count]) |key, value| self.session.remember(key.?, value);
    }
    pub fn page(self: *@This(), after: ?q.protocol.Value) !q.protocol.Growth.Batch(q.protocol.Growth.Entry, q.protocol.Value) {
        const session = self.session;
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
