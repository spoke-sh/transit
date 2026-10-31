//! Transport driver for a pure framing continuation. Capacity grows only after
//! validated headers and is retained until this authenticated connection closes.
const std = @import("std");
pub fn Reader(comptime Decoder: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        bytes: []u8,
        decoder: Decoder,
        borrowed: bool = false,
        pub fn init(allocator: std.mem.Allocator, shape: Decoder.Shape) !Self {
            const bytes = try allocator.alloc(u8, @min(8192, try shape.capacity()));
            errdefer allocator.free(bytes);
            return .{ .allocator = allocator, .bytes = bytes, .decoder = try .init(bytes, shape) };
        }
        pub fn deinit(self: *Self) void {
            self.decoder.abort();
            std.crypto.secureZero(u8, self.bytes);
            self.allocator.free(self.bytes);
            self.* = undefined;
        }
        pub fn read(self: *Self, transport: anytype) ![]const u8 {
            if (self.borrowed) return error.FrameStillBorrowed;
            errdefer self.decoder.abort();
            while (true) switch (try self.decoder.next()) {
                .input => |bytes| {
                    try transport.readExact(bytes);
                    try self.decoder.advance(bytes.len);
                },
                .capacity => |needed| {
                    self.bytes = try self.allocator.realloc(self.bytes, needed);
                    try self.decoder.supply(self.bytes);
                },
                .frame => |bytes| {
                    self.borrowed = true;
                    return bytes;
                },
            };
        }
        pub fn release(self: *Self) void {
            std.debug.assert(self.borrowed);
            self.decoder.release() catch unreachable;
            self.borrowed = false;
        }
    };
}
