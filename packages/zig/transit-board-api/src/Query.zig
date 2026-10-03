//! Interpret framework query records; never decode SQL, Arrow rows or tickets.
const std = @import("std");
const api = @import("root.zig");
const p = api.protocol;
const q = @import("transit_station").Query;
const current = @import("transit_query");
pub const Detail = union(enum) {
    execution: struct {
        result: u64,
        destination: u64,
        correlation: u64,
        source: p.Growth.ReadVersionId,
        request_resource: u64,
        request_namespace: []const u8,
        phase: current.UnifiedRecords.Phase,
        failure: ?current.Bridge.Failure,
        policy_revision: u64,
    },
    request: struct {
        namespace: []const u8,
        correlation: u64,
        phase: current.UnifiedRequest.Phase,
        failure: ?current.Bridge.Failure,
        collected: bool,
        result_resource: ?u64,
        result_namespace: ?[]const u8,
        result_digest: ?[32]u8,
    },
    capture: struct {
        result: u64,
        destination: u64,
        correlation: []const u8,
        table: u32,
        source: p.Growth.ReadVersionId,
        policy_revision: []const u8,
        phase: q.records.Phase,
        bytes: []const u8,
        send_segment: []const u8,
        send_offset: u16,
        chain: [32]u8,
    },
    manifest: struct {
        result: u64,
        destination: u64,
        correlation: []const u8,
        table: u32,
        policy_revision: []const u8,
        basis: @FieldType(q.Manifest, "basis"),
        plan: [32]u8,
        segments: []const u8,
        bytes: []const u8,
        rows: []const u8,
        chain: [32]u8,
        schema: [32]u8,
    },
};
pub const Lens = struct { version: u8 = 1, source: @FieldType(api.Lens, "source"), declaration: Detail };
fn decimal(allocator: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub fn decode(allocator: std.mem.Allocator, writer: u64, resource: u64, key: p.Value, value: p.Value) !?Detail {
    p.State.key(key) catch return null;
    value.validate() catch return null;
    if (key.len == 19 and std.mem.eql(u8, key.slice()[0..2], "\x00U")) {
        const identity = std.mem.readInt(u64, key.data[3..11], .big);
        if (!key.eql(current.UnifiedRecords.key(key.data[2], identity, 0))) return null;
        switch (key.data[2]) {
            'j' => {
                const job = current.UnifiedRecords.Job.decode(value) catch return null;
                if (job.id != identity or job.source.pid != writer) return null;
                return .{ .execution = .{ .result = job.id, .destination = job.destination, .correlation = job.correlation, .source = job.source, .request_resource = job.request.resource, .request_namespace = try decimal(allocator, job.request.namespace), .phase = job.phase, .failure = if (job.failure) |failure| try current.Bridge.Failure.fromNative(allocator, failure) else null, .policy_revision = job.policy_revision } };
            },
            'u' => {
                const status = current.UnifiedRequest.Status.decode(value) catch return null;
                if (status.reference.namespace != identity or status.reference.resource != resource) return null;
                return .{ .request = .{ .namespace = try decimal(allocator, identity), .correlation = status.correlation, .phase = status.phase, .failure = if (status.failure) |failure| try current.Bridge.Failure.fromNative(allocator, failure) else null, .collected = status.collected, .result_resource = if (status.manifest) |ref| ref.resource else null, .result_namespace = if (status.manifest) |ref| try decimal(allocator, ref.namespace) else null, .result_digest = if (status.manifest) |ref| ref.spec.digest else null } };
            },
            else => return null,
        }
    }
    if (key.len != 21 or !std.mem.eql(u8, key.slice()[0..2], &.{ 0, 'Q' })) return null;
    const identity = std.mem.readInt(u64, key.data[3..11], .big);
    if (!key.eql(q.records.key(key.data[2], identity, 0, 0))) return null;
    switch (key.data[2]) {
        'j' => {
            const job = q.Job.decode(value) catch return null;
            if (job.result != identity or job.source.pid != writer) return null;
            return .{ .capture = .{ .result = job.result, .destination = job.destination, .correlation = try decimal(allocator, job.correlation), .table = job.table, .source = job.source, .policy_revision = try decimal(allocator, job.policy_revision), .phase = job.phase, .bytes = try decimal(allocator, job.bytes), .send_segment = try decimal(allocator, job.send_segment), .send_offset = job.send_offset, .chain = job.chain } };
        },
        'c', 'z' => {
            const manifest = q.Manifest.decode(value) catch return null;
            if (manifest.basis.revision > p.max_counter) return null;
            if (key.data[2] == 'c') {
                if (manifest.correlation != identity or manifest.destination != writer) return null;
            } else if (manifest.result != identity or manifest.basis.resource != resource) return null;
            return .{ .manifest = .{ .result = manifest.result, .destination = manifest.destination, .correlation = try decimal(allocator, manifest.correlation), .table = manifest.table, .policy_revision = try decimal(allocator, manifest.policy_revision), .basis = manifest.basis, .plan = manifest.plan, .segments = try decimal(allocator, manifest.segments), .bytes = try decimal(allocator, manifest.bytes), .rows = try decimal(allocator, manifest.rows), .chain = manifest.chain, .schema = manifest.schema } };
        },
        else => return null,
    }
}
test "query lens requires canonical records and preserves full-width counters" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const job: q.Job = .{ .result = 5, .destination = 8, .correlation = std.math.maxInt(u64), .table = 1, .source = .{ .pid = 2, .input = 5, .index = 0 }, .policy_revision = 1, .phase = .denied, .bytes = std.math.maxInt(u64) };
    const key = q.records.key('j', 5, 0, 0);
    const detail = (try decode(allocator, 2, 7, key, try job.encode())).?.capture;
    try t.expectEqual(job.phase, detail.phase);
    try t.expectEqualStrings("18446744073709551615", detail.correlation);
    try t.expectEqualStrings("18446744073709551615", detail.bytes);
    try t.expect(try decode(allocator, 3, 7, key, try job.encode()) == null);
    try t.expect(try decode(allocator, 2, 7, q.records.key('j', 6, 0, 0), try job.encode()) == null);
    try t.expect(try decode(allocator, 2, 7, q.records.key('d', 5, 0, 0), try job.encode()) == null);
    try t.expect(try decode(allocator, 2, 7, key, try p.Value.init("GQJ3 private data")) == null);
    var manifest: q.Manifest = .{ .result = 5, .destination = 8, .correlation = job.correlation, .table = 1, .policy_revision = 1, .basis = .{ .kind = .table, .resource = 7, .revision = 9, .contract = @splat(5), .schema = @splat(1) }, .plan = @splat(2), .segments = std.math.maxInt(u64), .bytes = std.math.maxInt(u64), .rows = std.math.maxInt(u64), .chain = @splat(3), .schema = @splat(4) };
    const received = q.records.key('c', manifest.correlation, 0, 0);
    const projected = (try decode(allocator, 8, 10, received, try manifest.encode())).?.manifest;
    try t.expectEqualStrings("18446744073709551615", projected.rows);
    const json = try p.Json.valueAlloc(allocator, projected);
    try t.expect(std.mem.indexOf(u8, json, "\"rows\":\"18446744073709551615\"") != null);
    try t.expect(try decode(allocator, 9, 10, received, try manifest.encode()) == null);
    try t.expect(try decode(allocator, 2, 7, q.records.key('z', 5, 1, 0), try manifest.encode()) == null);
    try t.expect(try decode(allocator, 2, 7, q.records.key('z', 5, 0, 0), try manifest.encode()) != null);
    manifest.basis.revision = std.math.maxInt(u64);
    try t.expect(try decode(allocator, 8, 10, received, try manifest.encode()) == null);
}

test "current query evidence requires exact key and resource identity without exposing bundles" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const reference: current.station.PublicationReference = .{ .domain = .query_request, .resource = 7, .namespace = 9, .record = 1, .spec = .{ .format = current.Bundle.format, .length = 64, .digest = @splat(1) } };
    const job: current.UnifiedRecords.Job = .{ .id = 5, .source = .{ .pid = 2, .input = 5, .index = 0 }, .destination = 8, .correlation = 9, .policy_revision = 1, .request = reference, .continuation = 1 };
    const key = current.UnifiedRecords.key('j', 5, 0);
    const evidence = (try decode(alloc, 2, 6, key, try job.encode())).?.execution;
    try t.expectEqual(job.phase, evidence.phase);
    try t.expectEqualStrings("9", evidence.request_namespace);
    var failed = job;
    failed.phase = .failed;
    failed.failure = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .pages, .limit = 1, .observed = 2 };
    const failure_evidence = (try decode(alloc, 2, 6, key, try failed.encode())).?.execution;
    try t.expectEqual(.budget_exceeded, failure_evidence.failure.?.code);
    try t.expectEqualStrings("2", failure_evidence.failure.?.observed);
    try t.expect(try decode(alloc, 3, 6, key, try job.encode()) == null);
    try t.expect(try decode(alloc, 2, 6, current.UnifiedRecords.key('j', 6, 0), try job.encode()) == null);
    const status: current.UnifiedRequest.Status = .{ .reference = reference };
    const status_key = current.UnifiedRecords.key('u', 9, 0);
    const pending = (try decode(alloc, 8, 7, status_key, try status.encode())).?.request;
    try t.expect(pending.result_resource == null);
    try t.expect(try decode(alloc, 8, 6, status_key, try status.encode()) == null);
    try t.expect(try decode(alloc, 8, 7, current.UnifiedRecords.key('u', 9, 1), try status.encode()) == null);
}
