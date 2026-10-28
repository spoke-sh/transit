const std = @import("std");
const tls = @import("transit_tls_server");
const memory = @import("transit_memory");
const bounded_io = @import("transit_io");
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 5 and args.len != 6) return error.Usage;
    const connections = if (args.len == 6) try std.fmt.parseInt(u32, args[5], 10) else 1;
    if (connections == 0 or connections > 1000) return error.Usage;
    var probe: memory.AllocationProbe = .{ .parent = init.gpa };
    const reserve = try tls.Memory.create(probe.allocator(), 16 * 1024 * 1024);
    defer reserve.destroy();
    const runtime = try bounded_io.Threaded.create(probe.allocator(), .{ .workers = 4, .task_bytes = 256 * 1024, .worker_cleanup = tls.Memory.stopThread });
    defer runtime.destroy();
    const io = runtime.io();
    probe.begin(true);
    var context = try tls.Context.init(args[1], args[2]);
    defer context.deinit();
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", try std.fmt.parseInt(u16, args[3], 10))).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    for (0..connections) |_| {
        var future = try io.concurrent(exchange, .{ io, &context, &listener, args[4] });
        try future.await(io);
    }
    try probe.verify();
    const report = try std.json.Stringify.valueAlloc(allocator, .{ .connections = connections, .reserved_bytes = reserve.reservedBytes(), .io_reserved_bytes = runtime.reservedBytes(), .backing = probe.counts, .peak_occupied_bytes = reserve.reserve.peak_occupied_bytes }, .{});
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn exchange(io: std.Io, context: *tls.Context, listener: *std.Io.net.Server, protocol: []const u8) !void {
    const stream = try listener.accept(io);
    defer stream.close(io);
    var transport: tls.Transport = .{ .io = io, .stream = stream, .deadline = .none };
    try transport.resetDeadline(3000);
    if (std.mem.eql(u8, protocol, "postgres")) {
        var request: [8]u8 = undefined;
        try transport.readExact(&request);
        if (!std.mem.eql(u8, &request, &.{ 0, 0, 0, 8, 4, 210, 22, 47 })) return error.InvalidSslRequest;
        try transport.writeAll("S");
    } else if (std.mem.eql(u8, protocol, "mysql")) {
        // Protocol 4.1 SSLRequest is exactly 32 payload bytes, sequence 1.
        // The independent peer supplies the greeting for the upgrade probe.
        var request: [36]u8 = undefined;
        try transport.readExact(&request);
        if (!std.mem.eql(u8, request[0..4], &.{ 32, 0, 0, 1 }) or std.mem.readInt(u32, request[4..8], .little) & 0x800 == 0) return error.InvalidSslRequest;
    } else return error.Usage;
    var session = try tls.Session.accept(context, &transport);
    defer session.deinit();
    var message: [16]u8 = undefined;
    try session.readExact(&message);
    try session.writeAll(&message);
    try session.finish();
}
