//! One leased, non-resumable resource snapshot. Each fetch is authenticated
//! against current policy. Close is best effort only at the caller's boundary.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
const Self = @This();
client: root.ResourceReader,
snapshot: g.Snapshot,
view: struct { id: u64 = 0, resource: u64, revision: u64 },
failed: ?anyerror = null,
closed: bool = false,
cancellation: ?*const std.atomic.Value(bool) = null,

pub fn open(client: root.ResourceReader, resource: u64, nonce: [16]u8) !Self {
    return (try support(client)).open(resource, nonce);
}
/// Only immutable protocol support is reused. Every open authenticates afresh,
/// and a restarted authority can reject an unsupported operation normally.
pub fn support(client: root.ResourceReader) !Support {
    return Support.init(client, (try client.query(.capabilities)).body.capabilities);
}
pub const Support = struct {
    client: root.ResourceReader,
    /// A checked reply from this caller/connection can also negotiate other
    /// immutable protocol features. It grants no snapshot or resource access.
    pub fn init(client: root.ResourceReader, capabilities: g.Capabilities) !Support {
        if (!capabilities.leased_snapshots or !capabilities.snapshot_read) return error.InteractiveQueriesUnavailable;
        return .{ .client = client };
    }
    pub fn open(self: Support, resource: u64, nonce: [16]u8) !Self {
        const snapshot = (try self.client.query(.{ .open_snapshot = .{ .resource = resource, .nonce = nonce } })).body.open_snapshot;
        return .{ .client = self.client, .snapshot = snapshot, .view = .{ .resource = resource, .revision = snapshot.resource.revision } };
    }
    pub fn acquire(self: Support, request: g.SnapshotRead.Query) !struct { reader: Self, result: g.SnapshotRead.Result } {
        if (request.snapshot != .open) return error.InteractiveQueriesUnavailable;
        const result = (try self.client.query(.{ .snapshot_read = request })).body.snapshot_read;
        return .{ .reader = .{ .client = self.client, .snapshot = result.snapshot, .view = .{ .resource = result.snapshot.resource.id, .revision = result.snapshot.resource.revision } }, .result = result };
    }
};
pub fn batch(self: *Self, request: g.SnapshotRead.Query) !g.SnapshotRead.Result {
    if (self.closed) return error.QueryClosed;
    if (request.snapshot != .existing or !std.meta.eql(request.snapshot.existing, self.snapshot.id)) return error.InvalidResourceRead;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (self.failed) |err| return err;
    const result = (self.client.query(.{ .snapshot_read = request }) catch |err| {
        self.failed = err;
        return err;
    }).body.snapshot_read;
    if (!std.meta.eql(result.snapshot.resource, self.snapshot.resource) or result.snapshot.hard_deadline_ms != self.snapshot.hard_deadline_ms) {
        self.failed = error.InvalidResourceRead;
        return error.InvalidResourceRead;
    }
    self.snapshot = result.snapshot;
    self.closed = result.finished;
    return result;
}
pub fn close(self: *Self) !void {
    if (self.closed) return;
    _ = try self.client.query(.{ .close_snapshot = self.snapshot.id });
    self.closed = true;
}
/// Complete bulk bytes at this same leased cut. Validation/renewal and failure
/// poisoning match metadata reads; this never reacquires a different snapshot.
pub fn blockBatch(self: *Self, request: g.SnapshotRead.Query, body: *p.Blocks.Body) !g.SnapshotRead.Result {
    body.* = .{};
    errdefer body.* = .{};
    if (self.closed) return error.QueryClosed;
    if (request.snapshot != .existing or !std.meta.eql(request.snapshot.existing, self.snapshot.id)) return error.InvalidResourceRead;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (self.failed) |err| return err;
    const acquired = self.client.queryBlocks(.{ .snapshot_read = request }) catch |err| {
        self.failed = err;
        return err;
    };
    const result = acquired.response.body.snapshot_read;
    if (!std.meta.eql(result.snapshot.resource, self.snapshot.resource) or result.snapshot.hard_deadline_ms != self.snapshot.hard_deadline_ms) {
        self.failed = error.InvalidResourceRead;
        return error.InvalidResourceRead;
    }
    self.snapshot = result.snapshot;
    self.closed = result.finished;
    body.* = acquired.blocks;
    return result;
}
pub fn read(self: *Self, key: p.Value) !?p.Value {
    return if (try self.entry(key)) |value| value.value else null;
}
pub fn prefetchBlocks(_: *Self, _: []const p.Value) !void {}
pub fn readBlock(self: *Self, key: p.Value, output: []u8) !?[]const u8 {
    var request: g.SnapshotRead.Query = .{ .snapshot = .{ .existing = self.snapshot.id } };
    request.blocks[0] = key;
    var body: p.Blocks.Body = .{};
    const result = try self.blockBatch(request, &body);
    const batch_value = try root.BlockBatch.init(request.blocks, result.blocks, body);
    return batch_value.read(key, output);
}
pub fn entry(self: *Self, key: p.Value) !?g.Entry {
    return (try self.fetch(key, null)).entries[0];
}
pub fn page(self: *Self, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
    return self.fetch(null, after);
}
fn fetch(self: *Self, key: ?p.Value, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
    if (self.closed) return error.QueryClosed;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    if (self.failed) |err| return err;
    for (0..3) |_| {
        if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
        return self.fetchOnce(key, after) catch |err| {
            // Retry only an authority-tail race, at the same retained cut and
            // cursor. Expiry, denial and transport uncertainty never re-open.
            if (err == error.Conflict and self.client.wire.last_rejection == .Conflict) continue;
            self.failed = err;
            return err;
        };
    }
    self.failed = error.Conflict;
    return error.Conflict;
}
fn fetchOnce(self: *Self, key: ?p.Value, after: ?p.Value) !g.Batch(g.Entry, p.Value) {
    const result = (try self.client.query(.{ .snapshot_entries = .{ .id = self.snapshot.id, .key = key, .after = after } })).body.snapshot_entries;
    if (!std.meta.eql(result.snapshot.resource, self.snapshot.resource) or
        result.snapshot.hard_deadline_ms != self.snapshot.hard_deadline_ms) return error.InvalidResourceRead;
    self.snapshot = result.snapshot;
    return result.page;
}

test "sharing one capability reply preserves each required protocol flag" {
    var wire = root.Client.init(std.testing.allocator, std.testing.io, "http://127.0.0.1:1");
    defer wire.deinit();
    const reader: root.ResourceReader = .{
        .wire = &wire,
        .realm = 41,
        .principal = 42,
        .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)),
    };
    for (0..8) |flags| {
        const capabilities: g.Capabilities = .{
            .required_resources_per_process = 2,
            .dependency_validation_vertices = 3,
            .resource_read_batch = flags & 1 != 0,
            .leased_snapshots = flags & 2 != 0,
            .snapshot_read = flags & 4 != 0,
        };
        if (capabilities.resource_read_batch) {
            const batches = try root.ResourceReader.Batches.init(reader, capabilities);
            try std.testing.expectEqual(reader.principal, batches.client.principal);
            try std.testing.expect(batches.client.wire == &wire);
        } else try std.testing.expectError(error.ResourceReadBatchUnavailable, root.ResourceReader.Batches.init(reader, capabilities));
        if (capabilities.leased_snapshots and capabilities.snapshot_read) {
            const snapshots = try Support.init(reader, capabilities);
            try std.testing.expectEqual(reader.realm, snapshots.client.realm);
            try std.testing.expect(snapshots.client.wire == &wire);
        } else try std.testing.expectError(error.InteractiveQueriesUnavailable, Support.init(reader, capabilities));
        try std.testing.expect(wire.last_status == null);
    }
}
