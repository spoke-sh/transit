const std = @import("std");
const pg = @import("transit_postgres");
pub const Owned = struct {
    allocator: std.mem.Allocator,
    code: u32,
    payload: []u8,
    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.payload);
        self.* = undefined;
    }
};
pub fn read(allocator: std.mem.Allocator, transport: anytype) !Owned {
    var header: [8]u8 = undefined;
    try transport.readExact(&header);
    const length = try pg.Startup.frameSize(&header);
    const code = std.mem.readInt(u32, header[4..8], .big);
    const payload = try allocator.alloc(u8, length - 8);
    errdefer allocator.free(payload);
    try transport.readExact(payload);
    return .{ .allocator = allocator, .code = code, .payload = payload };
}
