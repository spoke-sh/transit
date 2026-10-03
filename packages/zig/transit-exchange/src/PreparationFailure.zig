//! Original validation evidence for an accepted exchange that never acquired an
//! intent. This is a capture closure, not an admission rejection or native result.
const std = @import("std");
const x = @import("root.zig");
const a = x.AdmissionRejection;
const Self = @This();
pub const magic = "EXP1";
resource: u64,
exchange: u64,
input: u64,
reason: a.Reason,
check: a.Check,
field_len: u8,
field_truncated: u8,
field: [32]u8,
cause_len: u8,
cause_truncated: u8,
cause: [64]u8,
expected_kind: a.Availability,
expected_number: u64,
expected_len: u8,
expected_truncated: u8,
expected_text: [32]u8,
actual_kind: a.Availability,
actual_number: u64,
actual_len: u8,
actual_truncated: u8,
actual_text: [32]u8,

pub fn from(resource: u64, exchange: u64, input: u64, detail: anytype) Self {
    var result: Self = undefined;
    inline for (comptime std.meta.fieldNames(Self)) |name| {
        if (comptime std.mem.eql(u8, name, "resource")) result.resource = resource else if (comptime std.mem.eql(u8, name, "exchange")) result.exchange = exchange else if (comptime std.mem.eql(u8, name, "input")) result.input = input else @field(result, name) = @field(detail, name);
    }
    return result;
}
fn evidence(self: Self) a.For("EXA1", .http) {
    var value: a.For("EXA1", .http) = .{ .reason = self.reason };
    inline for (comptime std.meta.fieldNames(Self)) |name| {
        if (comptime !std.mem.eql(u8, name, "resource") and !std.mem.eql(u8, name, "exchange") and !std.mem.eql(u8, name, "input")) @field(value, name) = @field(self, name);
    }
    return value;
}
pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > x.p.max_counter or self.exchange == 0 or self.input == 0 or self.input > x.p.max_counter or self.reason == .busy or self.check == .unrecorded or self.cause_len == 0) return error.InvalidPreparationFailure;
    try self.evidence().validate();
}
pub fn encode(self: Self) !x.p.Value {
    return x.codec.encode(self);
}
pub fn decode(value: x.p.Value) !Self {
    return x.codec.decode(Self, value);
}
pub fn failure(self: Self) !x.Failure {
    try self.validate();
    var result: x.Failure = .{ .resource = self.resource, .exchange = self.exchange, .reason = .preparation_failure, .origin_input = self.input, .cause_len = self.cause_len, .cause_truncated = self.cause_truncated };
    @memcpy(result.cause_bytes[0..self.cause_len], self.cause[0..self.cause_len]);
    return result;
}
pub fn explain(self: Self, value: *x.p.Diagnostic) !void {
    try self.validate();
    try x.OutcomeDiagnostic.validationFacts(value, self.evidence());
    try value.validate();
}

test "preparation evidence owns original fields without becoming input rejection" {
    const t = std.testing;
    const Rejection = a.For("HTF1", .http);
    var field = [_]u8{'x'};
    const detail = Rejection.detail(.invalid_request, .maximum, &field, .{ .unsigned = 16 }, .{ .unsigned = 17 }, error.HttpRequestTooLarge);
    const original = from(7, std.math.maxInt(u64), 12, detail);
    field[0] = 'y';
    try t.expectEqual(@as(usize, 216), x.codec.size(Self));
    const encoded = try original.encode();
    try t.expect(encoded.len <= x.station.Frame.max_payload);
    const owned = try decode(encoded);
    try t.expectEqualDeep(original, owned);
    try t.expectEqualStrings("x", owned.field[0..owned.field_len]);
    var failure_value = try owned.failure();
    failure_value.owner = 3;
    failure_value.principal = 9;
    failure_value.input = 20;
    var diagnostic = try failure_value.diagnostic(1);
    try owned.explain(&diagnostic);
    try t.expectEqualStrings("exchange.preparation_failed", diagnostic.code.slice());
    try t.expectEqual(.not_applicable, diagnostic.outcome);
    try t.expectEqual(.prepare, diagnostic.stage);
    try t.expectEqualStrings("HttpRequestTooLarge", diagnostic.cause.?.slice());
    for (0..encoded.len) |length| try t.expectError(error.InvalidExchangeRecord, decode(try x.p.Value.init(encoded.data[0..length])));
    var invalid = original;
    invalid.input = 0;
    try t.expectError(error.InvalidPreparationFailure, invalid.validate());
    invalid = original;
    invalid.cause_len = 0;
    try t.expectError(error.InvalidPreparationFailure, invalid.validate());
}

test "independent EXP1 bytes bind the original input and scalar evidence" {
    const t = std.testing;
    const parsed = try std.json.parseFromSlice(struct { record: x.p.Value }, t.allocator, @embedFile("preparation-failure-fixtures.json"), .{});
    defer parsed.deinit();
    const record = try decode(parsed.value.record);
    try t.expect((try record.encode()).eql(parsed.value.record));
    try t.expectEqual(std.math.maxInt(u64), record.exchange);
    try t.expectEqual(@as(u64, 12), record.input);
    try t.expectEqualStrings("request.body_bytes", record.field[0..record.field_len]);
    try t.expectEqual(@as(u64, 65536), record.expected_number);
    try t.expectEqual(@as(u64, 65537), record.actual_number);
    var invalid = parsed.value.record;
    invalid.data[29] = 255;
    try t.expectError(error.InvalidExchangeRecord, decode(invalid));
    invalid = parsed.value.record;
    invalid.data[32 + record.field_len] = 1;
    try t.expectError(error.InvalidAdmissionRejection, decode(invalid));
}
