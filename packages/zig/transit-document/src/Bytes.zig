//! Owned bounded bytes for the current canonical Document change profile.
const std = @import("std");
pub fn Bytes(comptime capacity: usize) type {
    return struct {
        const B = @This();
        len: u16 = 0,
        data: [capacity]u8 = @splat(0),
        pub fn init(bytes: []const u8) !B {
            if (bytes.len > capacity) return error.IndexValueTooLarge;
            var result: B = .{ .len = @intCast(bytes.len) };
            @memcpy(result.data[0..bytes.len], bytes);
            return result;
        }
        pub fn slice(self: *const B) []const u8 {
            return self.data[0..self.len];
        }
        pub fn validate(self: B, nonempty: bool) !void {
            if (self.len > capacity or (nonempty and self.len == 0)) return error.InvalidIndexValue;
        }
        pub fn eql(a: B, b: B) bool {
            return a.len == b.len and std.mem.eql(u8, a.slice(), b.slice());
        }
    };
}
