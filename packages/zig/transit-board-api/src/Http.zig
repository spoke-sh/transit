//! JSON-safe HTTP metadata with committed member references and no body preview.
const std = @import("std");
const api = @import("root.zig");
pub const adapter = @import("transit_station_http");
const x = adapter.exchange;
pub const Reference = struct { id: []const u8, revision: []const u8 };
pub const Member = struct { key: x.p.Value, ordinal: u32, kind: adapter.Kind, bytes: u32, digest: [32]u8, chain: [32]u8 };
pub const Policy = struct {
    member: Member,
    endpoint_revision: []const u8,
    tls: bool,
    trust_digest: ?[32]u8,
    timeout_ms: u32,
    request_bytes: []const u8,
    response_bytes: []const u8,
    method: std.http.Method,
    retry: ?Reference,
    redirect: ?Reference,
    reconcile: ?Reference,
    cancel: ?Reference,
};
pub const Terminal = struct {
    timing: struct { member: Member, started_ms: []const u8, elapsed_ns: []const u8 },
    omission: struct { member: Member, response_headers: u32, request_secrets: u32 },
    completion: struct { member: Member, status: u16, request_bytes: []const u8, response_bytes: []const u8, heads: u8, framing: @FieldType(adapter.Completion, "framing") },
};
pub const Response = struct {
    version: u8 = 1,
    source: @FieldType(api.ExchangeLens, "source"),
    exchange: []const u8,
    phase: x.Phase,
    coverage: [32]u8,
    failure: ?api.Exchange.Failure = null,
    policy: ?Policy,
    terminal: ?Terminal,
};
fn decimal(gpa: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(gpa, "{d}", .{value});
}
fn reference(gpa: std.mem.Allocator, value: ?adapter.Policy.Reference) !?Reference {
    const ref = value orelse return null;
    return .{ .id = try decimal(gpa, ref.id), .revision = try decimal(gpa, ref.revision) };
}
fn member(id: u64, value: x.Member) !Member {
    return .{ .key = x.Exchange.key(id, 'm', value.ordinal), .ordinal = value.ordinal, .kind = std.enums.fromInt(adapter.Kind, value.kind) orelse return error.InvalidHttpCapture, .bytes = value.length, .digest = value.digest, .chain = value.chain };
}
pub fn project(gpa: std.mem.Allocator, source: @FieldType(Response, "source"), id: u64, summary: adapter.Inspection.Summary) !Response {
    if (summary.descriptor.owner != source.pid or !source.key.eql(x.Exchange.key(id, 'd', 0))) return error.InvalidObservation;
    if (summary.failure) |failure| try failure.validateDescriptor(source.resource, id, summary.descriptor);
    return .{
        .failure = if (summary.failure) |failure| try api.Exchange.projectFailure(gpa, failure) else null,
        .source = source,
        .exchange = try decimal(gpa, id),
        .phase = summary.descriptor.phase,
        .coverage = summary.descriptor.chain,
        .policy = if (summary.policy) |record| .{
            .member = try member(id, record.member),
            .endpoint_revision = try decimal(gpa, record.value.endpoint_revision),
            .tls = record.value.tls,
            .trust_digest = record.value.trust_digest,
            .timeout_ms = record.value.timeout_ms,
            .request_bytes = try decimal(gpa, record.value.request_bytes),
            .response_bytes = try decimal(gpa, record.value.response_bytes),
            .method = record.value.method,
            .retry = try reference(gpa, record.value.retry),
            .redirect = try reference(gpa, record.value.redirect),
            .reconcile = try reference(gpa, record.value.reconcile),
            .cancel = try reference(gpa, record.value.cancel),
        } else null,
        .terminal = if (summary.terminal) |record| .{
            .timing = .{ .member = try member(id, record.timing.member), .started_ms = try decimal(gpa, record.timing.value.started_ms), .elapsed_ns = try decimal(gpa, record.timing.value.elapsed_ns) },
            .omission = .{ .member = try member(id, record.omission.member), .response_headers = record.omission.value.response_headers, .request_secrets = record.omission.value.request_secrets },
            .completion = .{ .member = try member(id, record.completion.member), .status = record.completion.value.status, .request_bytes = try decimal(gpa, record.completion.value.request_bytes), .response_bytes = try decimal(gpa, record.completion.value.response_bytes), .heads = record.completion.value.heads, .framing = record.completion.value.framing },
        } else null,
    };
}
