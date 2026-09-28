const std = @import("std");
const http = @import("transit_http_server");
const Context = struct {
    active: std.atomic.Value(usize) = .init(0),
    errors: std.atomic.Value(usize) = .init(0),
    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
        _ = self.active.fetchAdd(1, .monotonic);
        defer _ = self.active.fetchSub(1, .monotonic);
        if (std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .ok, "{\"ready\":true}");
        if (std.mem.eql(u8, request.head.target, "/large")) {
            const bytes = try allocator.alloc(u8, 8 * 1024 * 1024);
            defer allocator.free(bytes);
            @memset(bytes, 'x');
            return http.respond(request, .ok, bytes);
        }
        if (std.mem.eql(u8, request.head.target, "/slow")) try io.sleep(.fromMilliseconds(1000), .awake);
        var body: [64]u8 = undefined;
        const bytes = request.readerExpectNone(&.{}).readSliceShort(&body) catch return http.respond(request, .bad_request, "{}");
        if (bytes >= body.len) return http.respond(request, .payload_too_large, "{}");
        try http.respond(request, .ok, body[0..bytes]);
    }
    pub fn connectionError(self: *@This(), _: anyerror, _: bool) void {
        _ = self.errors.fetchAdd(1, .monotonic);
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", try std.fmt.parseInt(u16, args[1], 10))).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var context: Context = .{};
    const options: http.Options = .{ .connections = 8, .requests = 2, .control_requests = 1, .header_timeout_ms = 200, .request_timeout_ms = 700 };
    const Task = struct {
        fn run(io: std.Io, allocator: std.mem.Allocator, server: *std.Io.net.Server, limits: http.Options, ctx: *Context) anyerror!void {
            try http.serve(io, allocator, server, limits, ctx);
        }
    };
    http.deadline(init.io, try std.fmt.parseInt(u32, args[2], 10), Task.run, .{ init.io, init.gpa, &listener, options, &context }) catch |err| {
        if (err != error.HttpDeadline) return err;
    };
    if (context.active.load(.monotonic) != 0) return error.UnjoinedHandler;
    var buffer: [128]u8 = undefined;
    var writer = std.Io.File.stdout().writer(init.io, &buffer);
    try writer.interface.print("{{\"joined\":true,\"errors\":{d}}}\n", .{context.errors.load(.monotonic)});
    try writer.interface.flush();
}
