//! No dispatch semantics: independent negotiation proof for the transport seam.
const std = @import("std");
const tls = @import("transit_tls");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedPortAndCA;
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", try std.fmt.parseInt(u16, args[1], 10));
    const socket = try address.connect(init.io, .{ .mode = .stream });
    defer socket.close(init.io);
    var buffers: [4][tls.Client.min_buffer_len]u8 = undefined;
    var reader = socket.reader(init.io, &buffers[0]);
    var writer = socket.writer(init.io, &buffers[1]);
    var bundle: std.crypto.Certificate.Bundle = .empty;
    defer bundle.deinit(init.gpa);
    const now = std.Io.Clock.real.now(init.io);
    try bundle.addCertsFromFilePath(init.gpa, init.io, now, std.Io.Dir.cwd(), args[2]);
    var lock: std.Io.RwLock = .init;
    var entropy: [tls.Client.Options.entropy_len]u8 = undefined;
    try init.io.randomSecure(&entropy);
    var secure = try tls.Client.init(&reader.interface, &writer.interface, .{
        .host = .{ .explicit = "localhost" },
        .ca = .{ .bundle = .{ .gpa = init.gpa, .io = init.io, .lock = &lock, .bundle = &bundle } },
        .read_buffer = &buffers[2],
        .write_buffer = &buffers[3],
        .entropy = &entropy,
        .realtime_now = now,
        .required_alpn = "h2",
    });
    defer std.crypto.secureZero(u8, std.mem.asBytes(&secure));
    try secure.writer.writeAll("negotiated-h2");
    try secure.writer.flush();
    try writer.interface.flush();
}
