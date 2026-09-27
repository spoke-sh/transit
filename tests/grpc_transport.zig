const std = @import("std");
const grpc = @import("transit_grpc");
const Payload = struct {
    text: []const u8 = "",
    blob: []const u8 = "",
    sequence: u64 = 0,
    pub const pb_fields = .{
        .text = grpc.protobuf.Field{ .number = 1, .kind = .string },
        .blob = grpc.protobuf.Field{ .number = 2, .kind = .bytes },
        .sequence = grpc.protobuf.Field{ .number = 3, .kind = .uint64 },
    };
};
const Collector = struct {
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    messages: usize = 0,
    initial: usize = 0,
    trailers: usize = 0,
    duplicate_metadata: usize = 0,
    binary_metadata: usize = 0,
    half_close: bool = false,
    fn capture(raw: *anyopaque, event: grpc.Event) !void {
        const self: *Collector = @ptrCast(@alignCast(raw));
        switch (event) {
            .message => |bytes| {
                self.hash.update(bytes);
                self.bytes += bytes.len;
                self.messages += 1;
            },
            .half_close => self.half_close = true,
            .initial_metadata, .trailers => |fields| {
                if (event == .initial_metadata) self.initial += 1 else self.trailers += 1;
                for (fields) |field| {
                    if (std.mem.eql(u8, field.name, "x-repeat")) self.duplicate_metadata += 1;
                    if (std.mem.eql(u8, field.name, "x-blob-bin")) {
                        if (!std.mem.eql(u8, field.value, "AP8") and !std.mem.eql(u8, field.value, "AP8=")) return error.InvalidBinaryMetadata;
                        self.binary_metadata += 1;
                    }
                }
            },
        }
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 5) return error.ExpectedPortMethodShapeCA;
    const shape: grpc.Shape = @fromBackingInt(try std.fmt.parseInt(u8, args[3], 10));
    const request_count: usize = if (shape == .unary or shape == .server_streaming) 1 else 4;
    var message: [8192]u8 = @splat(0x5a);
    message[0..8].* = .{ 0, 255, 0xc3, 0xa9, 0xf0, 0x9f, 0x8c, 0x90 };
    const encoded = try grpc.protobuf.encodeAlloc(init.gpa, Payload{ .text = "café 🌐", .blob = &message, .sequence = 18446744073709551615 }, .{});
    defer init.gpa.free(encoded);
    const messages = [_][]const u8{ encoded, encoded, encoded, encoded };
    var endpoint: grpc.Endpoint = .{ .host = "localhost", .address = "127.0.0.1", .port = try std.fmt.parseInt(u16, args[1], 10), .ca_file = args[4], .timeout_ms = 1500 };
    if (std.mem.eql(u8, args[2], "/test.Peer/Flow")) endpoint.timeout_ms = 10000;
    if (std.mem.eql(u8, args[2], "/test.Peer/Limited")) endpoint.limits.response_bytes = 100;
    var collector: Collector = .{};
    const result = grpc.execute(init.gpa, init.io, endpoint, .{
        .method = args[2],
        .shape = shape,
        .messages = messages[0..request_count],
        .metadata = &.{ .{ .name = "x-repeat", .value = "first" }, .{ .name = "x-repeat", .value = "second" }, .{ .name = "x-blob-bin", .value = "\x00\xff" } },
    }, .{ .context = &collector, .emit = Collector.capture });
    var buffer: [2048]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (result) |value| {
        try output.interface.print("{{\"status\":{d},\"sent\":{d},\"received\":{d},\"bytes\":{d},\"sha256\":\"{x}\",\"half_closed\":{},\"initial\":{d},\"trailers\":{d},\"duplicates\":{d},\"binary\":{d}}}\n", .{ value.status, value.sent_messages, value.received_messages, collector.bytes, collector.hash.finalResult(), value.half_closed, collector.initial, collector.trailers, collector.duplicate_metadata, collector.binary_metadata });
    } else |err| try output.interface.print("{{\"error\":\"{s}\",\"received\":{d}}}\n", .{ @errorName(err), collector.messages });
    try output.interface.flush();
}
