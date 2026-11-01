//! Bounded attempt counters for the co-hosted service. No query, principal,
//! credential or payload labels. A count is transport work, not durable success.
const std = @import("std");
const Endpoint = @import("root.zig").LocalEndpoint;
const Self = @This();
base: Endpoint,
counts: [4]std.atomic.Value(u64) = @splat(.init(0)),
pub const Snapshot = struct { table: u64 = 0, native: u64 = 0, blocks: u64 = 0, payload: u64 = 0 };
pub fn endpoint(self: *Self) Endpoint {
    return .{ .context = self, .invoke = invoke, .changes = self.base.changes };
}
pub fn snapshot(self: *const Self) Snapshot {
    return .{ .table = self.counts[0].load(.monotonic), .native = self.counts[1].load(.monotonic), .blocks = self.counts[2].load(.monotonic), .payload = self.counts[3].load(.monotonic) };
}
fn invoke(raw: *anyopaque, call: *Endpoint.Invocation) !void {
    const self: *Self = @ptrCast(@alignCast(raw));
    const index: ?usize = if (std.mem.eql(u8, call.path, "/table/v1")) 0 else if (std.mem.eql(u8, call.path, "/v1/query") or std.mem.eql(u8, call.path, "/v1/command")) 1 else if (std.mem.eql(u8, call.path, "/v1/blocks")) 2 else if (std.mem.eql(u8, call.path, "/v1/payload")) 3 else null;
    if (index) |i| _ = self.counts[i].fetchAdd(1, .monotonic);
    return self.base.invoke(self.base.context, call);
}
