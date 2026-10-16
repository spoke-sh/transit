//! Interpret framework query records; never decode SQL, Arrow rows or tickets.
const std = @import("std");
const api = @import("root.zig");
const p = api.protocol;
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
    return null;
}

test "current query evidence requires exact key and resource identity without exposing bundles" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const reference: current.station.PublicationReference = .{ .domain = .query_request, .resource = 7, .namespace = 9, .record = 1, .spec = .{ .format = current.Bundle.format, .length = current.Bundle.header_bytes, .digest = @splat(1) } };
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

test "query publication namespaces retain full-width identity and old layouts have no lens" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const reference: current.station.PublicationReference = .{ .domain = .query_request, .resource = 7, .namespace = std.math.maxInt(u64), .record = 1, .spec = .{ .format = current.Bundle.format, .length = current.Bundle.header_bytes, .digest = @splat(1) } };
    var status: current.UnifiedRequest.Status = .{ .reference = reference };
    const key = current.UnifiedRecords.key('u', reference.namespace, 0);
    const pending = (try decode(alloc, 8, 7, key, try status.encode())).?.request;
    try t.expectEqualStrings("18446744073709551615", pending.namespace);
    status.phase = .complete;
    status.correlation = 9;
    status.manifest = .{ .domain = .query_result, .resource = 6, .namespace = std.math.maxInt(u64), .record = current.UnifiedRecords.manifest_record, .spec = .{ .format = current.UnifiedRecords.manifest_format, .length = 300, .digest = @splat(2) } };
    const complete = (try decode(alloc, 8, 7, key, try status.encode())).?.request;
    try t.expectEqualStrings("18446744073709551615", complete.result_namespace.?);
    try t.expectEqual(@as(?u64, 6), complete.result_resource);
    const json = try p.Json.valueAlloc(alloc, complete);
    try t.expect(std.mem.indexOf(u8, json, "\"result_namespace\":\"18446744073709551615\"") != null);
    var previous_key: [21]u8 = @splat(0);
    previous_key[0..3].* = "\x00Qj".*;
    try t.expect(try decode(alloc, 8, 7, try p.Value.init(&previous_key), try status.encode()) == null);
}
