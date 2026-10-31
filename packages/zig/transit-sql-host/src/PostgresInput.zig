const std = @import("std");
const pg = @import("transit_postgres");
pub const Owned = struct {
    allocator: std.mem.Allocator,
    tag: u8,
    payload: []u8,
    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.payload);
        self.* = undefined;
    }
};
pub fn read(allocator: std.mem.Allocator, transport: anytype, maximum: u32) !Owned {
    var prefix: [5]u8 = undefined;
    try transport.readExact(&prefix);
    const n = try pg.Frame.frameSize(&prefix, maximum);
    const payload = try allocator.alloc(u8, n - 5);
    errdefer allocator.free(payload);
    try transport.readExact(payload);
    return .{ .allocator = allocator, .tag = prefix[0], .payload = payload };
}
