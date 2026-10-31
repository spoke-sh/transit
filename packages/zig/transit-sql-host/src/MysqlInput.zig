const std = @import("std");
const mysql = @import("transit_mysql");
pub const Owned = struct {
    allocator: std.mem.Allocator,
    sequence: u8,
    payload: []u8,
    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.payload);
        self.* = undefined;
    }
};
pub fn read(allocator: std.mem.Allocator, transport: anytype, expected: u8, maximum: u32) !Owned {
    var prefix: [4]u8 = undefined;
    try transport.readExact(&prefix);
    const n = try mysql.Frame.frameSize(&prefix, expected, maximum);
    const payload = try allocator.alloc(u8, n - 4);
    errdefer allocator.free(payload);
    try transport.readExact(payload);
    return .{ .allocator = allocator, .sequence = expected, .payload = payload };
}
