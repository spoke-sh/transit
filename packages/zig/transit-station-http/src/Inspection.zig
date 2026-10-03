//! Bounded, allowlisted metadata over an authorized current resource source.
//! Reads four known members at most; never reads request/response body members.
const std = @import("std");
const http = @import("root.zig");
const x = http.exchange;
pub const Policy = struct {
    endpoint_revision: u64,
    tls: bool,
    trust_digest: ?[32]u8,
    timeout_ms: u32,
    request_bytes: u64,
    response_bytes: u64,
    method: std.http.Method,
    retry: ?http.Policy.Reference,
    redirect: ?http.Policy.Reference,
    reconcile: ?http.Policy.Reference,
    cancel: ?http.Policy.Reference,
};
pub fn Record(comptime T: type) type {
    return struct { member: x.Member, value: T };
}
pub const Terminal = struct {
    timing: Record(http.Timing),
    omission: Record(http.Omission),
    completion: Record(http.Completion),
};
pub const Summary = struct {
    descriptor: x.Descriptor,
    failure: ?x.Failure = null,
    policy: ?Record(Policy) = null,
    terminal: ?Terminal = null,
};

pub fn policy(gpa: std.mem.Allocator, bytes: []const u8) !Policy {
    if (bytes.len > 8192) return error.HttpInspectionCapacity;
    const parsed = try std.json.parseFromSlice(http.Policy.Prepared, gpa, bytes, .{});
    defer parsed.deinit();
    const prepared = parsed.value;
    if (prepared.version != 1 or prepared.endpoint_revision == 0 or prepared.timeout_ms == 0 or prepared.tls != (prepared.trust_digest != null)) return error.InvalidHttpCapture;
    var head: [http.Request.maximum_head_bytes]u8 = undefined;
    _ = try prepared.request.render(prepared.host, prepared.port, &head, null, false);
    const result: Policy = .{
        .endpoint_revision = prepared.endpoint_revision,
        .tls = prepared.tls,
        .trust_digest = prepared.trust_digest,
        .timeout_ms = prepared.timeout_ms,
        .request_bytes = prepared.request_bytes,
        .response_bytes = prepared.response_bytes,
        .method = prepared.request.method,
        .retry = if (prepared.retry_policy) |v| .{ .id = v.id, .revision = v.revision } else null,
        .redirect = prepared.redirect_policy,
        .reconcile = if (prepared.reconcile_policy) |v| .{ .id = v.id, .revision = v.revision } else null,
        .cancel = if (prepared.cancel_policy) |v| .{ .id = v.id, .revision = v.revision } else null,
    };
    inline for (.{ "retry", "redirect", "reconcile", "cancel" }) |field| if (@field(result, field)) |ref| try ref.validate();
    return result;
}

fn load(ex: x.Exchange, source: anytype, ordinal: u32, kind: http.Kind, buffer: []u8) !struct { member: x.Member, bytes: []const u8 } {
    const member = try ex.member(source, ordinal);
    if (member.kind != @backingInt(kind) or member.format != http.protocol_format) return error.HttpReplayGap;
    if (member.length > buffer.len) return error.HttpInspectionCapacity;
    var cursor = try ex.publication().open(source, @as(u64, ordinal) + 1);
    if (!std.meta.eql(cursor.spec, member.spec())) return error.InvalidExchangeCoverage;
    var count: usize = 0;
    while (true) {
        const part = try ex.publication().read(source, cursor);
        @memcpy(buffer[count..][0..part.bytes.len], part.bytes.slice());
        count += part.bytes.len;
        cursor = part.next orelse break;
    }
    return .{ .member = member, .bytes = buffer[0..count] };
}
fn terminalRecord(comptime T: type, ex: x.Exchange, source: anytype, ordinal: u32, kind: http.Kind) !Record(T) {
    var buffer: [256]u8 = undefined;
    const record = try load(ex, source, ordinal, kind, &buffer);
    return .{ .member = record.member, .value = try x.codec.decode(T, try x.p.Value.init(record.bytes)) };
}

/// The caller owns the source's current-policy and revision checks. Public
/// Client.Reader performs those on every read; no old execution view is used.
/// Selected member digests are verified. This does not replay the entire body
/// or independently verify the exchange's complete HTTP transcript.
pub fn read(gpa: std.mem.Allocator, ex: x.Exchange, source: anytype) !Summary {
    const d = try ex.inspect(source);
    if (d.protocol != http.protocol_format) return error.WrongExchangeProtocol;
    if (d.phase == .retired) return error.ExchangeUnavailable;
    var result: Summary = .{ .descriptor = d, .failure = try ex.failure(source) };
    if (d.segments > 0) {
        var buffer: [8192]u8 = undefined;
        const record = try load(ex, source, 0, .request_template, &buffer);
        result.policy = .{ .member = record.member, .value = try policy(gpa, record.bytes) };
    }
    if (d.phase == .complete) {
        if (d.segments < 8) return error.HttpReplayGap;
        const terminal: Terminal = .{
            .timing = try terminalRecord(http.Timing, ex, source, d.segments - 3, .timing),
            .omission = try terminalRecord(http.Omission, ex, source, d.segments - 2, .omission),
            .completion = try terminalRecord(http.Completion, ex, source, d.segments - 1, .completion),
        };
        if (terminal.completion.value.status != d.terminal_code or !std.mem.eql(u8, &terminal.completion.member.chain, &d.chain)) return error.InvalidExchangeCoverage;
        if (!std.mem.eql(u8, &x.Coverage.next(terminal.timing.member.chain, terminal.omission.member.ordinal, @backingInt(http.Kind.omission), terminal.omission.member.spec()), &terminal.omission.member.chain) or !std.mem.eql(u8, &x.Coverage.next(terminal.omission.member.chain, terminal.completion.member.ordinal, @backingInt(http.Kind.completion), terminal.completion.member.spec()), &terminal.completion.member.chain)) return error.InvalidExchangeCoverage;
        result.terminal = terminal;
    }
    return result;
}

test "inspection policy retains full identities while excluding routing and credential values" {
    const t = std.testing;
    const prepared: http.Policy.Prepared = .{ .endpoint_revision = std.math.maxInt(u64), .host = "private.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .request_bytes = 64, .response_bytes = 8192, .response_headers = &.{"content-length"}, .trust_digest = @splat(1), .retry_policy = .{ .id = std.math.maxInt(u64), .revision = 7, .key_header = "private-key" }, .request = .{ .method = .GET, .target = &.{.{ .literal = "/private-target" }}, .headers = &.{.{ .name = "Authorization", .value = &.{.{ .secret = .{ .binding = "private-binding", .version = 7 } }} }} } };
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, prepared, .{});
    defer t.allocator.free(bytes);
    const projected = try policy(t.allocator, bytes);
    try t.expectEqual(std.math.maxInt(u64), projected.endpoint_revision);
    try t.expectEqual(std.math.maxInt(u64), projected.retry.?.id);
    const json = try std.json.Stringify.valueAlloc(t.allocator, projected, .{});
    defer t.allocator.free(json);
    try t.expect(std.mem.indexOf(u8, json, "private") == null);
    try t.expectEqual(.GET, projected.method);
    var invalid = prepared;
    invalid.version = 2;
    const bad = try std.json.Stringify.valueAlloc(t.allocator, invalid, .{});
    defer t.allocator.free(bad);
    try t.expectError(error.InvalidHttpCapture, policy(t.allocator, bad));
}
