//! Selected protocol metadata from an authorized current source. Message bodies,
//! method routing and credential references are never disclosed by this lens.
const std = @import("std");
const rpc = @import("root.zig");
const x = rpc.exchange;
pub const Policy = struct {
    endpoint_revision: u64,
    tls: bool,
    trust_digest: ?[32]u8,
    timeout_ms: u32,
    limits: rpc.transport.Limits,
    shape: rpc.Shape,
    descriptor_digest: [32]u8,
    retry: ?rpc.Policy.Reference,
};
pub fn Record(comptime T: type) type {
    return struct { member: x.Member, value: T };
}
pub const Terminal = struct {
    timing: Record(rpc.Capture.Timing),
    omission: Record(rpc.Capture.Omission),
    completion: Record(rpc.Capture.Completion),
};
pub const Summary = struct {
    descriptor: x.Descriptor,
    failure: ?x.Failure = null,
    policy: ?Record(Policy) = null,
    half_close: ?Record(rpc.Capture.HalfClose) = null,
    response_message_records: u32 = 0,
    response_body_bytes: u64 = 0,
    terminal: ?Terminal = null,
};
pub fn policy(gpa: std.mem.Allocator, bytes: []const u8) !Policy {
    var owned = try rpc.Policy.parse(gpa, bytes);
    defer owned.deinit();
    const v = owned.policy;
    return .{ .endpoint_revision = v.endpoint_revision, .tls = v.tls, .trust_digest = v.trust_digest, .timeout_ms = v.timeout_ms, .limits = v.limits, .shape = v.shape, .descriptor_digest = v.descriptor_digest, .retry = if (v.retry_policy) |r| .{ .id = r.id, .revision = r.revision } else null };
}
fn load(ex: x.Exchange, source: anytype, member: x.Member, buffer: []u8) ![]const u8 {
    if (member.length > buffer.len) return error.GrpcInspectionCapacity;
    var cursor = try ex.publication().open(source, @as(u64, member.ordinal) + 1);
    if (!std.meta.eql(cursor.spec, member.spec())) return error.InvalidExchangeCoverage;
    var count: usize = 0;
    while (true) {
        const part = try ex.publication().read(source, cursor);
        @memcpy(buffer[count..][0..part.bytes.len], part.bytes.slice());
        count += part.bytes.len;
        cursor = part.next orelse break;
    }
    return buffer[0..count];
}
fn record(comptime T: type, ex: x.Exchange, source: anytype, member: x.Member) !Record(T) {
    var buffer: [256]u8 = undefined;
    return .{ .member = member, .value = try x.codec.decode(T, try x.p.Value.init(try load(ex, source, member, &buffer))) };
}
/// Client.Reader supplies current policy and resource-revision checks on every
/// access. Verify all member commitments and selected metadata bytes only;
/// neither a complete descriptor nor this projection proves remote computation
/// or substitutes for full message/body replay. Partial message headers remain
/// indexed records, not a claim of complete application messages.
pub fn read(gpa: std.mem.Allocator, ex: x.Exchange, source: anytype) !Summary {
    const d = try ex.inspect(source);
    if (d.protocol != rpc.protocol_format) return error.WrongExchangeProtocol;
    if (d.phase == .retired) return error.ExchangeUnavailable;
    if (d.segments > 256) return error.GrpcInspectionCapacity;
    var result: Summary = .{ .descriptor = d, .failure = try ex.failure(source) };
    var chain = x.Coverage.initial;
    var timing: ?Record(rpc.Capture.Timing) = null;
    var omission: ?Record(rpc.Capture.Omission) = null;
    var completion: ?Record(rpc.Capture.Completion) = null;
    for (0..d.segments) |ordinal| {
        const member = try ex.member(source, @intCast(ordinal));
        if (member.format != rpc.protocol_format or member.ordinal != ordinal) return error.InvalidGrpcCapture;
        chain = x.Coverage.next(chain, member.ordinal, member.kind, member.spec());
        if (!std.mem.eql(u8, &chain, &member.chain)) return error.InvalidExchangeCoverage;
        const kind = std.enums.fromInt(rpc.Kind, member.kind) orelse return error.InvalidGrpcCapture;
        switch (kind) {
            .endpoint_policy => {
                if (result.policy != null) return error.InvalidGrpcCapture;
                var bytes: [8192]u8 = undefined;
                result.policy = .{ .member = member, .value = try policy(gpa, try load(ex, source, member, &bytes)) };
            },
            .half_close => {
                if (result.half_close != null) return error.InvalidGrpcCapture;
                result.half_close = try record(rpc.Capture.HalfClose, ex, source, member);
            },
            .response_message => result.response_message_records += 1,
            .response_body => result.response_body_bytes += member.length,
            .timing => {
                if (timing != null) return error.InvalidGrpcCapture;
                timing = try record(rpc.Capture.Timing, ex, source, member);
            },
            .omission => {
                if (omission != null) return error.InvalidGrpcCapture;
                omission = try record(rpc.Capture.Omission, ex, source, member);
            },
            .completion => {
                if (completion != null) return error.InvalidGrpcCapture;
                completion = try record(rpc.Capture.Completion, ex, source, member);
            },
            else => {},
        }
    }
    if (!std.mem.eql(u8, &chain, &d.chain)) return error.InvalidExchangeCoverage;
    if (d.phase == .complete) {
        const time = timing orelse return error.GrpcReplayGap;
        const omitted = omission orelse return error.GrpcReplayGap;
        const done = completion orelse return error.GrpcReplayGap;
        if (result.policy == null or time.member.ordinal + 1 != omitted.member.ordinal or omitted.member.ordinal + 1 != done.member.ordinal or done.member.ordinal + 1 != d.segments or try done.value.terminalCode() != d.terminal_code) return error.InvalidGrpcCapture;
        if ((done.value.half_closed == .yes) != (result.half_close != null) or done.value.received_messages != result.response_message_records or done.value.received_bytes != result.response_body_bytes + result.response_message_records * 5) return error.InvalidGrpcCapture;
        if (result.half_close) |closed| if (closed.value.messages != done.value.sent_messages or closed.value.wire_bytes != done.value.sent_bytes) return error.InvalidGrpcCapture;
        result.terminal = .{ .timing = time, .omission = omitted, .completion = done };
    }
    return result;
}

test "inspection preserves policy identity without route, metadata or credential disclosure" {
    const t = std.testing;
    const prepared: rpc.Policy.Prepared = .{ .endpoint_revision = std.math.maxInt(u64), .host = "private.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .limits = .{}, .trust_digest = @splat(1), .method = "/private.Service/Method", .shape = .bidi, .descriptor_digest = @splat(2), .metadata_digest = @splat(3), .batch_digest = @splat(4), .credentials = &.{.{ .binding = "private-binding", .version = 7, .metadata = "authorization" }}, .retry_policy = .{ .id = std.math.maxInt(u64), .revision = 7, .key_metadata = "private-key" } };
    var buffer: [8192]u8 = undefined;
    const selected = try policy(t.allocator, try prepared.encode(&buffer));
    try t.expectEqual(std.math.maxInt(u64), selected.endpoint_revision);
    try t.expectEqual(std.math.maxInt(u64), selected.retry.?.id);
    try t.expectEqual(.bidi, selected.shape);
    const json = try std.json.Stringify.valueAlloc(t.allocator, selected, .{});
    defer t.allocator.free(json);
    try t.expect(std.mem.indexOf(u8, json, "private") == null);
    var invalid = prepared;
    invalid.version = 2;
    const bad = try std.json.Stringify.valueAlloc(t.allocator, invalid, .{});
    defer t.allocator.free(bad);
    try t.expectError(error.InvalidGrpcPolicy, policy(t.allocator, bad));
}
