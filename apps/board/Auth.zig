//! Ephemeral, bounded sessions. Rotation is observed by rereading the credential
//! file for every API request; no upstream response or allow decision is cached.
const std = @import("std");
const Auth = @This();
pub const capacity = 32;
const Session = struct { token: [32]u8, credential: [32]u8, expires_ms: i64 };
sessions: [capacity]?Session = @splat(null),

pub fn credential(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![32]u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128));
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    return decode(std.mem.trim(u8, bytes, " \t\r\n")) orelse error.InvalidCredential;
}
pub fn decode(hex: []const u8) ?[32]u8 {
    if (hex.len != 64) return null;
    var value: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&value, hex) catch return null;
    return value;
}
pub fn equal(a: [32]u8, b: [32]u8) bool {
    return std.crypto.timing_safe.eql([32]u8, a, b);
}
pub fn bearer(header: ?[]const u8, expected: [32]u8) bool {
    const value = header orelse return false;
    if (!std.mem.startsWith(u8, value, "Bearer ")) return false;
    return equal(decode(value[7..]) orelse return false, expected);
}
pub fn cookie(header: ?[]const u8) ?[32]u8 {
    var fields = std.mem.splitScalar(u8, header orelse return null, ';');
    var result: ?[32]u8 = null;
    while (fields.next()) |raw| {
        const value = std.mem.trim(u8, raw, " ");
        if (std.mem.startsWith(u8, value, "board_session=")) {
            if (result != null) return null;
            result = decode(value[14..]) orelse return null;
        }
    }
    return result;
}
pub fn authorized(self: *Auth, token: ?[32]u8, current: [32]u8, now: i64) bool {
    var accepted = false;
    for (&self.sessions) |*slot| if (slot.*) |session| {
        if (session.expires_ms <= now or !equal(session.credential, current)) {
            slot.* = null;
        } else if (token) |value| {
            if (equal(session.token, value)) accepted = true;
        }
    };
    return accepted;
}
pub fn issue(self: *Auth, io: std.Io, current: [32]u8, now: i64, lifetime_s: u32) ![32]u8 {
    _ = self.authorized(null, current, now);
    for (&self.sessions) |*slot| if (slot.* == null) {
        var token: [32]u8 = undefined;
        try io.randomSecure(&token);
        slot.* = .{ .token = token, .credential = current, .expires_ms = now + @as(i64, lifetime_s) * 1000 };
        return token;
    };
    return error.SessionCapacity;
}
pub fn logout(self: *Auth, token: ?[32]u8) void {
    if (token) |value| for (&self.sessions) |*slot| {
        if (slot.*) |session| if (equal(session.token, value)) {
            slot.* = null;
        };
    };
}

test "session expiry, rotation and logout invalidate cached authorization" {
    var auth: Auth = .{};
    auth.sessions[0] = .{ .token = @splat(7), .credential = @splat(9), .expires_ms = 100 };
    try std.testing.expect(auth.authorized(@as([32]u8, @splat(7)), @splat(9), 99));
    try std.testing.expect(!auth.authorized(@as([32]u8, @splat(7)), @splat(9), 100));
    auth.sessions[0] = .{ .token = @splat(7), .credential = @splat(9), .expires_ms = 100 };
    try std.testing.expect(!auth.authorized(@as([32]u8, @splat(7)), @splat(8), 99));
    auth.sessions[0] = .{ .token = @splat(7), .credential = @splat(9), .expires_ms = 100 };
    auth.logout(@as([32]u8, @splat(7)));
    try std.testing.expect(!auth.authorized(@as([32]u8, @splat(7)), @splat(9), 99));
}
