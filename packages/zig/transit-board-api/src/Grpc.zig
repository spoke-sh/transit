//! Bounded RPC metadata with exact source/member evidence and no protobuf lens.
const std = @import("std");
const api = @import("root.zig");
pub const adapter = @import("transit_station_grpc");
const x = adapter.exchange;
pub const Member = struct { key: x.p.Value, ordinal: u32, kind: adapter.Kind, bytes: u32, digest: [32]u8, chain: [32]u8 };
pub const Policy = struct {
    member: Member,
    endpoint_revision: []const u8,
    tls: bool,
    trust_digest: ?[32]u8,
    timeout_ms: u32,
    limits: adapter.transport.Limits,
    shape: adapter.Shape,
    descriptor_digest: [32]u8,
    retry: ?struct { id: []const u8, revision: []const u8 },
};
pub const Terminal = struct {
    timing: struct { member: Member, started_ms: []const u8, elapsed_ns: []const u8 },
    omission: struct { member: Member, response_fields: u32, request_secrets: u32 },
    completion: struct { member: Member, status: u32, sent_messages: u32, received_messages: u32, sent_bytes: u32, received_bytes: u32, half_closed: bool },
};
pub const Response = struct {
    version: u8 = 1,
    source: @FieldType(api.ExchangeLens, "source"),
    exchange: []const u8,
    phase: x.Phase,
    coverage: [32]u8,
    failure: ?api.Exchange.Failure = null,
    policy: ?Policy,
    half_close: ?struct { member: Member, messages: u32, wire_bytes: u32 },
    response_message_records: u32,
    response_body_bytes: []const u8,
    terminal: ?Terminal,
};
fn decimal(gpa: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(gpa, "{d}", .{value});
}
fn member(id: u64, value: x.Member) !Member {
    return .{ .key = x.Exchange.key(id, 'm', value.ordinal), .ordinal = value.ordinal, .kind = std.enums.fromInt(adapter.Kind, value.kind) orelse return error.InvalidGrpcCapture, .bytes = value.length, .digest = value.digest, .chain = value.chain };
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
            .limits = record.value.limits,
            .shape = record.value.shape,
            .descriptor_digest = record.value.descriptor_digest,
            .retry = if (record.value.retry) |ref| .{ .id = try decimal(gpa, ref.id), .revision = try decimal(gpa, ref.revision) } else null,
        } else null,
        .half_close = if (summary.half_close) |record| .{ .member = try member(id, record.member), .messages = record.value.messages, .wire_bytes = record.value.wire_bytes } else null,
        .response_message_records = summary.response_message_records,
        .response_body_bytes = try decimal(gpa, summary.response_body_bytes),
        .terminal = if (summary.terminal) |record| .{
            .timing = .{ .member = try member(id, record.timing.member), .started_ms = try decimal(gpa, record.timing.value.started_ms), .elapsed_ns = try decimal(gpa, record.timing.value.elapsed_ns) },
            .omission = .{ .member = try member(id, record.omission.member), .response_fields = record.omission.value.response_fields, .request_secrets = record.omission.value.request_secrets },
            .completion = .{ .member = try member(id, record.completion.member), .status = record.completion.value.status, .sent_messages = record.completion.value.sent_messages, .received_messages = record.completion.value.received_messages, .sent_bytes = record.completion.value.sent_bytes, .received_bytes = record.completion.value.received_bytes, .half_closed = record.completion.value.half_closed == .yes },
        } else null,
    };
}
