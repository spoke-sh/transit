//! Test-only owned immutable bodies for in-memory schedule stores. This does
//! not model segment placement, physical reclamation or disk durability.
const std = @import("std");
const core = @import("transit_core");
const Self = @This();

values: std.AutoHashMapUnmanaged(core.blocks.Reference, []u8) = .empty,

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    var values = self.values.valueIterator();
    while (values.next()) |bytes| allocator.free(bytes.*);
    self.values.deinit(allocator);
}

pub fn stage(self: *Self, allocator: std.mem.Allocator, spec: core.protocol.Blocks.Spec, bytes: []const u8) !core.blocks.Reference {
    try spec.verify(bytes);
    const reference: core.blocks.Reference = .{ .value = spec, .location = spec.digest };
    if (!self.values.contains(reference)) {
        const owned = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned);
        try self.values.put(allocator, reference, owned);
    }
    return reference;
}

pub fn load(self: *Self, reference: core.blocks.Reference, output: []u8) ![]const u8 {
    const bytes = self.values.get(reference) orelse return error.BlockUnavailable;
    if (output.len < bytes.len) return error.BlockBufferTooSmall;
    try reference.value.verify(bytes);
    @memcpy(output[0..bytes.len], bytes);
    return output[0..bytes.len];
}
