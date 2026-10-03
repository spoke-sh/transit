//! Owned first-failure evidence. The same bounded value is an authenticated
//! worker input (input/owner/principal zero) and its atomically retained record.
const std = @import("std");
const x = @import("root.zig");
const p = x.p;
const Self = @This();
pub const magic = "EXF1";
pub const Reason = enum(u8) { caller_closed = 1, controller_release = 2, recovered_incomplete = 3, transport_failure = 4, capture_failure = 5, preparation_failure = 6 };
pub const Operation = enum(u8) { none = 0, callback = 1, begin = 2, append = 3, seal = 4 };
resource: u64 = 0,
exchange: u64 = 0,
owner: u64 = 0,
principal: u64 = 0,
input: u64 = 0,
reason: Reason,
operation: Operation = .none,
origin_input: u64 = 0,
kind: u32 = 0,
member: u32 = 0,
chunk: u32 = 0,
requested_bytes: u32 = 0,
cause_len: u8 = 0,
cause_truncated: u8 = 0,
cause_bytes: [96]u8 = @splat(0),
phase: x.Phase = .preparing,
effect: u64 = 0,
attempt: u64 = 0,
segments: u32 = 0,
bytes: u64 = 0,

pub fn failed(reason: Reason, err: anyerror) Self {
    const name = @errorName(err);
    var value: Self = .{ .reason = reason };
    var length = @min(name.len, value.cause_bytes.len);
    while (!std.unicode.utf8ValidateSlice(name[0..length])) length -= 1;
    @memcpy(value.cause_bytes[0..length], name[0..length]);
    value.cause_len = @intCast(length);
    value.cause_truncated = @intFromBool(length < name.len);
    return value;
}
pub fn cause(self: *const Self) []const u8 {
    return self.cause_bytes[0..self.cause_len];
}
pub fn validate(self: Self) !void {
    if (self.cause_len > self.cause_bytes.len or self.cause_truncated > 1 or !std.unicode.utf8ValidateSlice(self.cause())) return error.InvalidExchangeFailure;
    for (self.cause_bytes[self.cause_len..]) |byte| if (byte != 0) return error.InvalidExchangeFailure;
    const has_cause = self.reason == .transport_failure or self.reason == .capture_failure or self.reason == .preparation_failure;
    if (has_cause != (self.cause_len != 0) or (!has_cause and self.cause_truncated != 0)) return error.InvalidExchangeFailure;
    if ((self.resource == 0) != (self.exchange == 0) or self.resource > p.max_counter or self.owner > p.max_counter or self.principal > p.max_counter or self.input > p.max_counter or self.origin_input > p.max_counter) return error.InvalidExchangeFailure;
    if (self.reason != .capture_failure and (self.operation != .none or (self.origin_input != 0 and self.reason != .preparation_failure) or self.kind != 0 or self.member != 0 or self.chunk != 0 or self.requested_bytes != 0)) return error.InvalidExchangeFailure;
    if (self.reason == .preparation_failure and (self.origin_input == 0 or self.phase != .preparing or self.effect != 0 or self.attempt != 0)) return error.InvalidExchangeFailure;
    if (self.operation != .append and self.chunk != 0) return error.InvalidExchangeFailure;
    // Mailbox input position is admission order, not the later turn commit.
    // A previously queued input can close an attempt authorized after admission.
    if (self.owner == 0) {
        if (self.input != 0 or self.principal != 0 or self.phase != .preparing or self.effect != 0 or self.attempt != 0 or self.segments != 0 or self.bytes != 0) return error.InvalidExchangeFailure;
    } else {
        if (self.resource == 0 or self.input == 0 or (self.effect == 0) != (self.attempt == 0) or
            self.effect > p.max_counter or self.attempt > p.max_counter or (self.phase == .capturing and self.effect == 0) or (self.phase == .preparing and self.effect != 0) or (self.phase != .preparing and self.phase != .ready and self.phase != .capturing)) return error.InvalidExchangeFailure;
    }
}
pub fn encodeRequest(self: Self) !p.Value {
    if (self.resource == 0 or self.owner != 0) return error.InvalidExchangeFailure;
    return x.codec.encode(self);
}
pub fn decodeRequest(value: p.Value) !Self {
    const result = try x.codec.decode(Self, value);
    if (result.resource == 0 or result.owner != 0) return error.InvalidExchangeFailure;
    return result;
}
pub fn encode(self: Self) !p.Value {
    if (self.owner == 0) return error.InvalidExchangeFailure;
    return x.codec.encode(self);
}
pub fn decode(value: p.Value) !Self {
    const result = try x.codec.decode(Self, value);
    if (result.owner == 0) return error.InvalidExchangeFailure;
    return result;
}

pub fn validateDescriptor(self: Self, resource: u64, id: u64, descriptor: x.Descriptor) !void {
    try self.validate();
    if (self.resource != resource or self.exchange != id or self.owner != descriptor.owner or
        self.segments != descriptor.segments or self.bytes != descriptor.bytes or
        (self.effect != 0 and (self.effect != descriptor.effect or self.attempt != descriptor.attempt)) or
        (descriptor.phase != .unknown and descriptor.phase != .retired) or descriptor.terminal_code != 0) return error.InvalidExchangeFailure;
}

pub fn diagnostic(self: Self, realm: u64) !p.Diagnostic {
    try self.validate();
    if (self.owner == 0) return error.InvalidExchangeFailure;
    const d = p.Diagnostic;
    const description: struct { []const u8, []const u8 } = switch (self.reason) {
        .preparation_failure => .{ "exchange.preparation_failed", "The accepted exchange failed validation during preparation, before any effect intent or dispatch. Its original field and validation evidence are retained. This closure does not settle any other exchange." },
        .transport_failure => .{ "exchange.transport_failed", "The connector transport failed and capture is incomplete. The remote operation may have run. Inspect the native effect and recorded connector policy before further work." },
        .capture_failure => .{ "exchange.capture_failed", "The connector could not retain a complete capture. The failure identifies the capture operation; remote execution may already have occurred. Capture failure does not settle the native effect." },
        .recovered_incomplete => .{ "exchange.recovered_incomplete", "A replacement activation found incomplete capture. The prior local cause was not recorded. Recovery closes capture without dispatching the remote request again." },
        .controller_release => .{ "exchange.preparation_released", "An explicit controller release closed incomplete preparation. This capture decision is separate from native effect settlement and remote cancellation." },
        .caller_closed => .{ "exchange.capture_closed", "The owner explicitly closed capture without a complete transcript. Inspect native effect settlement separately; capture closure does not establish a remote outcome." },
    };
    var value = try d.init(description[0], .lifecycle, if (self.reason == .preparation_failure) .prepare else if (self.reason == .capture_failure) .output else .execute, .not_applicable, .domain_status, description[1]);
    value.identity = .{ .domain = if (self.effect != 0) .effect else .exchange, .realm = .init(realm), .resource = .init(self.resource), .id = .init(if (self.effect != 0) self.effect else self.exchange) };
    if (self.cause_len != 0 and self.cause_truncated == 0) value.cause = try d.Code.init(self.cause());
    try value.fact(.object, .execution, .{ .unsigned = .init(self.exchange) });
    try value.fact(.actual_resource, .execution, .{ .unsigned = .init(self.resource) });
    try value.fact(.native_input, .execution, .{ .unsigned = .init(self.input) });
    try value.fact(.principal, .execution, .{ .unsigned = .init(self.principal) });
    try value.text(.source_basis, .execution, @tagName(self.phase));
    try value.fact(.emitted_segments, .execution, .{ .unsigned = .init(self.segments) });
    try value.fact(.actual_count, .execution, .{ .unsigned = .init(self.bytes) });
    try value.text(.unit, .owner, "captured bytes");
    try value.fact(.completion, .execution, .{ .boolean = false });
    if (self.attempt != 0) try value.fact(.attempt, .execution, .{ .unsigned = .init(self.attempt) });
    if (self.reason == .capture_failure) {
        try value.text(.operation, .execution, @tagName(self.operation));
        if (self.operation != .none and self.operation != .callback) try value.fact(.step, .execution, .{ .unsigned = .init(self.member) });
        if (self.operation == .append) try value.fact(.argument, .execution, .{ .unsigned = .init(self.chunk) });
        if (self.operation == .begin or self.operation == .append) try value.fact(.required, .caller, .{ .unsigned = .init(self.requested_bytes) });
        if (self.origin_input != 0) try value.fact(.first_occurrence, .execution, .{ .unsigned = .init(self.origin_input) });
    }
    if (self.reason == .preparation_failure) try value.fact(.first_occurrence, .execution, .{ .unsigned = .init(self.origin_input) });
    if (self.cause_truncated != 0) try value.text(.constraint, .owner, "The original local error name is truncated.");
    try value.action(.inspect_status);
    try value.validate();
    return value;
}

test "failure input owns the cause and fits one Station frame without becoming a stored record" {
    var request = failed(.transport_failure, error.ConnectionResetByPeer);
    request.resource = 1;
    request.exchange = std.math.maxInt(u64);
    const bytes = try request.encodeRequest();
    try std.testing.expect(bytes.len <= x.station.Frame.max_payload);
    const owned = try decodeRequest(bytes);
    try std.testing.expectEqualStrings("ConnectionResetByPeer", owned.cause());
    try std.testing.expectError(error.InvalidExchangeFailure, decode(bytes));
    var record = request;
    record.owner = 2;
    record.input = 6;
    record.phase = .capturing;
    record.effect = 4;
    record.attempt = 5;
    _ = try record.encode();
    try std.testing.expectError(error.InvalidExchangeFailure, decodeRequest(try record.encode()));
}

test "independent EXF1 bytes preserve full exchange identity and admission order" {
    const t = std.testing;
    const parsed = try std.json.parseFromSlice(struct { request: p.Value, record: p.Value }, t.allocator, @embedFile("failure-fixtures.json"), .{});
    defer parsed.deinit();
    const request = try decodeRequest(parsed.value.request);
    const record = try decode(parsed.value.record);
    try t.expect((try request.encodeRequest()).eql(parsed.value.request));
    try t.expect((try record.encode()).eql(parsed.value.record));
    try t.expectEqual(std.math.maxInt(u64), record.exchange);
    try t.expectEqualStrings("ConnectionResetByPeer", record.cause());
    try t.expectEqual(@as(u64, 12), record.input);
    try t.expectEqual(@as(u64, 20), record.attempt);
    var wrong = parsed.value.record;
    wrong.data[44] = 255;
    try t.expectError(error.InvalidExchangeRecord, decode(wrong));
    wrong = parsed.value.record;
    wrong.data[72 + record.cause_len] = 1;
    try t.expectError(error.InvalidExchangeFailure, decode(wrong));
    wrong = parsed.value.record;
    wrong.len -= 1;
    try t.expectError(error.InvalidExchangeRecord, decode(wrong));
}

test "capture inspection always targets original retained evidence without inferring dispatch" {
    const t = std.testing;
    var failure: Self = .{ .reason = .caller_closed, .resource = 7, .exchange = std.math.maxInt(u64), .owner = 2, .principal = 9, .input = 11 };
    const before = try failure.diagnostic(1);
    try t.expectEqual(.domain_status, before.evidence);
    try t.expectEqual(.not_applicable, before.outcome);
    try t.expectEqual(.exchange, before.identity.?.domain);
    try t.expectEqual(std.math.maxInt(u64), try before.identity.?.id.value());
    try t.expectEqualDeep(before.identity, before.actions[0].?.target);
    try t.expectEqual(.inspect_status, before.actions[0].?.kind);
    try t.expectEqual(null, before.actions[1]);
    failure.phase = .capturing;
    failure.effect = 4;
    failure.attempt = 5;
    const after = try failure.diagnostic(1);
    try t.expectEqual(.domain_status, after.evidence);
    try t.expectEqual(.not_applicable, after.outcome);
    try t.expectEqual(.effect, after.identity.?.domain);
    try t.expectEqual(@as(u64, 4), try after.identity.?.id.value());
    try t.expectEqualDeep(after.identity, after.actions[0].?.target);
    try t.expectEqual(null, after.actions[1]);
}
