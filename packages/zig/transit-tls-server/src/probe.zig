const std = @import("std");
const tls = @import("transit_tls_server");
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 5) return error.Usage;
    var context = try tls.Context.init(args[1], args[2]);
    defer context.deinit();
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", try std.fmt.parseInt(u16, args[3], 10))).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    const stream = try listener.accept(init.io);
    defer stream.close(init.io);
    var transport: tls.Transport = .{ .io = init.io, .stream = stream, .deadline = .none };
    try transport.resetDeadline(3000);
    if (std.mem.eql(u8, args[4], "postgres")) {
        var request: [8]u8 = undefined;
        try transport.readExact(&request);
        if (!std.mem.eql(u8, &request, &.{ 0, 0, 0, 8, 4, 210, 22, 47 })) return error.InvalidSslRequest;
        try transport.writeAll("S");
    } else if (std.mem.eql(u8, args[4], "mysql")) {
        // Protocol 4.1 SSLRequest is exactly 32 payload bytes, sequence 1.
        // The independent peer supplies the greeting for the upgrade probe.
        var request: [36]u8 = undefined;
        try transport.readExact(&request);
        if (!std.mem.eql(u8, request[0..4], &.{ 32, 0, 0, 1 }) or std.mem.readInt(u32, request[4..8], .little) & 0x800 == 0) return error.InvalidSslRequest;
    } else return error.Usage;
    var session = try tls.Session.accept(&context, &transport);
    defer session.deinit();
    var message: [16]u8 = undefined;
    try session.readExact(&message);
    try session.writeAll(&message);
    try session.finish();
}
