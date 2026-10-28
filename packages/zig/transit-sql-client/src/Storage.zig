//! Stable client storage. Statement owners and transport connections draw from
//! separate fixed reserves; independent response leases never overwrite peers.
const std = @import("std");
const memory = @import("transit_memory");
const Response = @import("Response.zig");
const api = @import("root.zig").protocol;
const Self = @This();
pub const data_bytes = 16 * 1024 * 1024;
pub const transport_bytes = 4 * 1024 * 1024;
pub const response_slots = 4;
parent: std.mem.Allocator,
references: usize = 1,
data: memory.Slab,
transport: memory.Slab,
responses: [response_slots]Response.Slot = @splat(.{}),
urls: [2][]const u8 = @splat(&.{}),
targets: [2]std.Uri = undefined,

pub fn create(parent: std.mem.Allocator, endpoint: []const u8) !*Self {
    const self = try parent.create(Self);
    errdefer parent.destroy(self);
    self.* = .{ .parent = parent, .data = try .init(parent, data_bytes), .transport = undefined };
    errdefer self.data.deinit();
    self.transport = try .init(parent, transport_bytes);
    errdefer self.transport.deinit();
    const a = self.data.allocator();
    errdefer for (self.urls) |url| a.free(url);
    if (!std.mem.startsWith(u8, endpoint, "unix:")) {
        const base = std.mem.trimEnd(u8, endpoint, "/");
        for ([_][]const u8{ api.data_path, api.control_path }, &self.urls, &self.targets) |path, *url, *target| {
            url.* = try std.fmt.allocPrint(a, "{s}{s}", .{ base, path });
            target.* = try std.Uri.parse(url.*);
        }
    }
    return self;
}
pub fn acquireResponse(self: *Self, allocator: std.mem.Allocator) !Response.Lease {
    for (&self.responses) |*slot| if (!slot.active) return slot.acquire(allocator);
    return error.SqlResponseCapacity;
}
pub fn reservedBytes(_: *const Self) usize {
    return @sizeOf(Self) + data_bytes + transport_bytes;
}
/// Settlement can authenticate one new observation session over the same
/// reserve. Callers serialize admission and join it before releasing the owner.
pub fn retain(self: *Self) !*Self {
    self.references = try std.math.add(usize, self.references, 1);
    return self;
}
pub fn destroy(self: *Self) void {
    std.debug.assert(self.references != 0);
    self.references -= 1;
    if (self.references != 0) return;
    for (self.responses) |slot| std.debug.assert(!slot.active);
    for (self.urls) |url| self.data.allocator().free(url);
    self.transport.deinit();
    self.data.deinit();
    const parent = self.parent;
    std.crypto.secureZero(u8, std.mem.asBytes(self));
    parent.destroy(self);
}

fn failures(allocator: std.mem.Allocator) !void {
    const self = try create(allocator, "http://127.0.0.1:1");
    defer self.destroy();
}
test "client reserve initialization rolls back every backing failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, failures, .{});
}
test "client reserve accounts idle capacity and refuses retained response slot exhaustion" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const self = try create(probe.allocator(), "http://127.0.0.1:1/");
    defer self.destroy();
    try t.expectEqual(self.reservedBytes(), probe.live_bytes);
    probe.begin(true);
    var leases: [response_slots]Response.Lease = undefined;
    for (&leases) |*lease| lease.* = try self.acquireResponse(self.data.allocator());
    try t.expectError(error.SqlResponseCapacity, self.acquireResponse(self.data.allocator()));
    for (leases) |lease| try lease.release();
    try probe.verify();
}
