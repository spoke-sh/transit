//! Bounded original admission evidence. This record can travel in a single
//! correlated Station reply without borrowing request or policy memory.
const std = @import("std");
const x = @import("root.zig");
pub const Reason = enum(u8) { denied = 1, invalid_request = 2, busy = 3 };
pub const Check = enum(u8) { unrecorded, decode, equal, maximum, different, available, state, policy, occupied, mode, before };
pub const Availability = enum(u8) { unrecorded, redacted, inapplicable, unsigned, text, digest };
pub const Scalar = union(Availability) { unrecorded, redacted, inapplicable, unsigned: u64, text: []const u8, digest: [32]u8 };

pub fn For(comptime wire_magic: *const [4]u8, comptime protocol: x.OutcomeDiagnostic.Protocol) type {
    return struct {
        const Self = @This();
        pub const magic = wire_magic;
        reason: Reason,
        check: Check = .unrecorded,
        input: u64 = 0,
        request: [32]u8 = @splat(0),
        field_len: u8 = 0,
        field_truncated: u8 = 0,
        field: [32]u8 = @splat(0),
        cause_len: u8 = 0,
        cause_truncated: u8 = 0,
        cause: [64]u8 = @splat(0),
        expected_kind: Availability = .unrecorded,
        expected_number: u64 = 0,
        expected_len: u8 = 0,
        expected_truncated: u8 = 0,
        expected_text: [32]u8 = @splat(0),
        actual_kind: Availability = .unrecorded,
        actual_number: u64 = 0,
        actual_len: u8 = 0,
        actual_truncated: u8 = 0,
        actual_text: [32]u8 = @splat(0),

        pub fn detail(reason: Reason, check: Check, field: []const u8, expected: Scalar, actual: Scalar, cause: ?anyerror) Self {
            var result: Self = .{ .reason = reason, .check = check };
            store(field, &result.field, &result.field_len, &result.field_truncated);
            if (cause) |err| store(@errorName(err), &result.cause, &result.cause_len, &result.cause_truncated);
            result.scalar("expected", expected);
            result.scalar("actual", actual);
            return result;
        }
        fn scalar(self: *Self, comptime prefix: []const u8, value: Scalar) void {
            @field(self, prefix ++ "_kind") = std.meta.activeTag(value);
            switch (value) {
                .unsigned => |number| @field(self, prefix ++ "_number") = number,
                .digest => |digest| {
                    @field(self, prefix ++ "_text") = digest;
                    @field(self, prefix ++ "_len") = 32;
                },
                .text => |bytes| store(bytes, &@field(self, prefix ++ "_text"), &@field(self, prefix ++ "_len"), &@field(self, prefix ++ "_truncated")),
                else => {},
            }
        }
        pub fn original(self: Self, input: u64, payload: x.p.Value) Self {
            var result = self;
            result.input = input;
            std.crypto.hash.sha2.Sha256.hash(payload.slice(), &result.request, .{});
            return result;
        }
        pub fn causedBy(self: Self, cause: anyerror) Self {
            var result = self;
            if (result.cause_len == 0) store(@errorName(cause), &result.cause, &result.cause_len, &result.cause_truncated);
            return result;
        }
        pub fn validate(self: Self) !void {
            if (self.input > x.p.max_counter or (self.input == 0 and !std.mem.allEqual(u8, &self.request, 0))) return error.InvalidAdmissionRejection;
            try bounded(&self.field, self.field_len, self.field_truncated);
            try bounded(&self.cause, self.cause_len, self.cause_truncated);
            inline for (.{ "expected", "actual" }) |prefix| {
                const kind = @field(self, prefix ++ "_kind");
                const len = @field(self, prefix ++ "_len");
                const truncated = @field(self, prefix ++ "_truncated");
                const number = @field(self, prefix ++ "_number");
                if (kind == .digest) {
                    if (len != 32 or truncated != 0) return error.InvalidAdmissionRejection;
                } else try bounded(&@field(self, prefix ++ "_text"), len, truncated);
                if (kind != .unsigned and number != 0) return error.InvalidAdmissionRejection;
                if (kind != .text and kind != .digest and (len != 0 or truncated != 0)) return error.InvalidAdmissionRejection;
            }
            if (self.check == .unrecorded) {
                if (self.field_len != 0 or self.cause_len != 0 or self.expected_kind != .unrecorded or self.actual_kind != .unrecorded) return error.InvalidAdmissionRejection;
            } else if (self.field_len == 0) return error.InvalidAdmissionRejection;
        }
        pub fn diagnostic(self: Self) !x.p.Diagnostic {
            return x.OutcomeDiagnostic.rejection(protocol, self);
        }
    };
}
fn bounded(bytes: []const u8, len: u8, truncated: u8) !void {
    if (len > bytes.len or truncated > 1) return error.InvalidAdmissionRejection;
    if (!std.mem.allEqual(u8, bytes[len..], 0) or !std.unicode.utf8ValidateSlice(bytes[0..len])) return error.InvalidAdmissionRejection;
    if (truncated != 0 and len == 0) return error.InvalidAdmissionRejection;
}
fn store(bytes: []const u8, output: []u8, len: *u8, truncated: *u8) void {
    if (!std.unicode.utf8ValidateSlice(bytes)) {
        // A caller-owned byte string can still be explained without returning
        // malformed JSON or substituting replacement Unicode characters.
        var writer: std.Io.Writer = .fixed(output);
        writer.writeAll("bytes:") catch unreachable;
        var copied: usize = 0;
        for (bytes) |byte| {
            if (writer.buffer.len - writer.end < 4) break;
            writer.print("\\x{x:0>2}", .{byte}) catch unreachable;
            copied += 1;
        }
        len.* = @intCast(writer.end);
        truncated.* = @intFromBool(copied != bytes.len);
        return;
    }
    var count = @min(bytes.len, output.len);
    while (!std.unicode.utf8ValidateSlice(bytes[0..count])) count -= 1;
    @memcpy(output[0..count], bytes[0..count]);
    len.* = @intCast(count);
    truncated.* = @intFromBool(count != bytes.len);
}

test "admission witnesses fit one reply and own typed values through codec round trips" {
    const t = std.testing;
    const Rejection = For("HTF1", .http);
    try t.expectEqual(@as(usize, 232), x.codec.size(Rejection));
    var path = [_]u8{'x'};
    var record = Rejection.detail(.denied, .maximum, &path, .{ .unsigned = 3 }, .{ .unsigned = 4 }, error.HttpRequestTooLarge).original(17, try x.p.Value.init("original request"));
    path[0] = 'y';
    const encoded = try x.codec.encode(record);
    const decoded = try x.codec.decode(Rejection, encoded);
    try t.expectEqualDeep(record, decoded);
    try t.expectEqualStrings("x", decoded.field[0..decoded.field_len]);
    try t.expectEqualStrings("HttpRequestTooLarge", decoded.cause[0..decoded.cause_len]);
    for (0..encoded.len) |len| try t.expectError(error.InvalidExchangeRecord, x.codec.decode(Rejection, try x.p.Value.init(encoded.data[0..len])));
    try t.expectError(error.InvalidExchangeRecord, x.codec.decode(Rejection, try x.p.Value.init("HTF1\x01")));
    record.actual_kind = .redacted;
    try t.expectError(error.InvalidAdmissionRejection, record.validate());
}

test "admission strings truncate explicitly without splitting UTF-8 or exposing hidden values" {
    const t = std.testing;
    const Rejection = For("GRF1", .grpc);
    var bytes: [80]u8 = undefined;
    for (0..40) |i| @memcpy(bytes[2 * i ..][0..2], "λ");
    const record = Rejection.detail(.denied, .policy, "request", .redacted, .{ .text = &bytes }, null);
    try record.validate();
    try t.expectEqual(@as(u8, 1), record.actual_truncated);
    try t.expect(std.unicode.utf8ValidateSlice(record.actual_text[0..record.actual_len]));
    try t.expectEqual(Availability.redacted, record.expected_kind);
    try t.expect(std.mem.allEqual(u8, &record.expected_text, 0));
    const invalid = Rejection.detail(.invalid_request, .decode, "request", .unrecorded, .{ .text = "\xff\x00" }, error.InvalidUtf8);
    try invalid.validate();
    try t.expectEqualStrings("bytes:\\xff\\x00", invalid.actual_text[0..invalid.actual_len]);
}
