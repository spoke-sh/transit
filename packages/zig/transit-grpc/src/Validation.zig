//! Pure preflight evidence. Field names are owned; payload and routing bytes are
//! never retained. This transport type has no Station or protocol dependency.
const std = @import("std");
const Self = @This();
pub const Check = enum { equal, maximum, different, decode, policy };
pub const Scalar = union(enum) { unsigned: u64, text: []const u8, redacted };
check: Check,
field: [64]u8 = @splat(0),
field_len: u8 = 0,
expected: Scalar,
actual: Scalar,

/// Text scalars are static rule descriptions; dynamic input uses unsigned
/// measurements or redacted. The generated field path is copied before return.
pub fn fail(context: ?*?Self, check: Check, field: []const u8, expected: Scalar, actual: Scalar, cause: anyerror) anyerror {
    if (context) |slot| if (slot.* == null) {
        std.debug.assert(field.len <= 64);
        var value: Self = .{ .check = check, .expected = expected, .actual = actual, .field_len = @intCast(field.len) };
        @memcpy(value.field[0..field.len], field);
        slot.* = value;
    };
    return cause;
}
pub fn path(self: *const Self) []const u8 {
    return self.field[0..self.field_len];
}
