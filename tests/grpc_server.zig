const std = @import("std");
const server = @import("transit_grpc").Server;
const Context = struct {
    active: std.atomic.Value(u32) = .init(0),
    pub fn isControl(_: *@This(), request: server.Request) bool {
        return std.mem.eql(u8, request.method() catch return false, "/test.Peer/Health");
    }
    pub fn connectionError(_: *@This(), _: anyerror, _: bool) void {}
    pub fn handle(self: *@This(), io: std.Io, _: std.mem.Allocator, request: server.Request, response: *server.Response) !void {
        const method = try request.method();
        if (std.mem.eql(u8, method, "/test.Peer/Health")) {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, self.active.load(.acquire), .little);
            return response.send(&bytes);
        }
        _ = self.active.fetchAdd(1, .acquire);
        defer _ = self.active.fetchSub(1, .release);
        if (std.mem.eql(u8, method, "/test.Peer/Echo")) return response.send(request.message);
        if (std.mem.eql(u8, method, "/test.Peer/Wait")) {
            while (true) {
                try response.check();
                try io.sleep(.fromMilliseconds(20), .awake);
            }
        }
        if (std.mem.eql(u8, method, "/test.Peer/Stream")) {
            const bytes: [8192]u8 = @splat(42);
            for (0..24) |_| try response.send(&bytes);
            return;
        }
        return response.finish(12, "method unsupported");
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedPort;
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", try std.fmt.parseInt(u16, args[1], 10));
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var context: Context = .{};
    try server.serve(init.io, init.gpa, &listener, .{ .connections = 8, .requests = 2, .control_requests = 1, .header_timeout_ms = 1000, .write_timeout_ms = 1000, .request_timeout_ms = 5000, .connection_timeout_ms = 30000 }, &context);
}
