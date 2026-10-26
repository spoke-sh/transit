const std = @import("std");
const grpc = @import("transit_grpc");
const rpc = @import("transit_station_grpc");
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
    adapter: ?*rpc.Capture = null,
    validator: rpc.Replay.Validator = .{ .terminal_code = 0 },
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    bytes: usize = 0,
    messages: usize = 0,
    initial: usize = 0,
    trailers: usize = 0,
    duplicate_metadata: usize = 0,
    binary_metadata: usize = 0,
    half_close: bool = false,
    fn append(raw: *anyopaque, kind: rpc.Capture.Kind, bytes: []const u8) !void {
        const self: *Collector = @ptrCast(@alignCast(raw));
        var offset: usize = 0;
        while (offset < bytes.len) {
            const len = @min(256, bytes.len - offset);
            try self.validator.push(kind, bytes[offset..][0..len], offset + len == bytes.len);
            offset += len;
        }
        if (bytes.len == 0) try self.validator.push(kind, "", true);
    }

    fn capture(raw: *anyopaque, event: grpc.Event) !void {
        const self: *Collector = @ptrCast(@alignCast(raw));
        if (self.adapter) |adapter| try rpc.Capture.emit(adapter, event);
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
    const descriptor = @embedFile("grpc_descriptor");
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(descriptor, &digest, .{});
    var schema = try grpc.Descriptor.parse(init.gpa, descriptor);
    defer schema.deinit();
    const selected = schema.method(args[2]) catch |err| if (err == error.GrpcDescriptorMethodMissing) null else return err;
    if (selected) |method| {
        try std.testing.expectEqual(shape, method.shape);
        try std.testing.expectEqualStrings(".test.Payload", method.input_type);
        try std.testing.expectEqualStrings(".test.Payload", method.output_type);
        try std.testing.expectEqualSlices(u8, &digest, &method.descriptor_digest);
    }
    const request: rpc.Request = .{ .method = args[2], .shape = shape, .descriptor_digest = digest, .metadata = &.{
        .{ .name = "x-repeat", .value = .{ .literal = "first" } },
        .{ .name = "x-repeat", .value = .{ .literal = "second" } },
        .{ .name = "x-blob-bin", .value = .{ .literal = "\x00\xff" } },
    } };
    var metadata_buffer: [8192]u8 = undefined;
    const metadata_bytes = try request.provenance(&metadata_buffer);
    try Collector.append(&collector, .request_metadata, metadata_bytes);
    var batch_buffer: [rpc.Batch.maximum_bytes]u8 = undefined;
    const batch_bytes = try rpc.Batch.encode(messages[0..request_count], shape, endpoint.limits, &batch_buffer);
    var offset: usize = 0;
    while (offset < batch_bytes.len) {
        const len = @min(4096, batch_bytes.len - offset);
        try Collector.append(&collector, .request_batch, batch_bytes[offset..][0..len]);
        offset += len;
    }
    const ca = try std.Io.Dir.cwd().readFileAlloc(init.io, args[4], init.gpa, .limited(1048576));
    defer init.gpa.free(ca);
    var trust: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(ca, &trust, .{});
    const policy: rpc.Policy.Prepared = .{ .endpoint_revision = 1, .host = endpoint.host, .address = endpoint.address, .port = endpoint.port, .tls = endpoint.tls, .timeout_ms = endpoint.timeout_ms, .limits = endpoint.limits, .response_metadata = &.{ "x-repeat", "x-blob-bin" }, .trust_digest = trust, .method = request.method, .shape = shape, .descriptor_digest = digest, .metadata_digest = (try rpc.exchange.Publication.Digest.of(2, metadata_bytes)).digest, .batch_digest = (try rpc.exchange.Publication.Digest.of(2, batch_bytes)).digest };
    var policy_buffer: [8192]u8 = undefined;
    try Collector.append(&collector, .endpoint_policy, try policy.encode(&policy_buffer));
    const batch = try rpc.Batch.decode(batch_bytes, shape, endpoint.limits);
    var adapter: rpc.Capture = .{ .sink = .{ .context = &collector, .append = Collector.append }, .planned = .{ .messages = @intCast(batch.count), .wire_bytes = batch.wire_bytes }, .allowlist = &.{ "x-repeat", "x-blob-bin" } };
    collector.adapter = &adapter;
    const result = grpc.execute(init.gpa, init.io, endpoint, .{
        .method = args[2],
        .shape = shape,
        .messages = messages[0..request_count],
        .metadata = &.{ .{ .name = "x-repeat", .value = "first" }, .{ .name = "x-repeat", .value = "second" }, .{ .name = "x-blob-bin", .value = "\x00\xff" } },
    }, .{ .context = &collector, .emit = Collector.capture });
    var buffer: [2048]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (result) |value| {
        collector.validator.terminal_code = value.status + 1;
        const captured = try adapter.finish(value, .{ .started_ms = 1, .elapsed_ns = 1 });
        const replayed = try collector.validator.finish();
        if (!std.meta.eql(captured, replayed)) return error.CaptureReplayMismatch;
        try output.interface.print("{{\"capture_complete\":true,\"status\":{d},\"sent\":{d},\"received\":{d},\"bytes\":{d},\"sha256\":\"{x}\",\"half_closed\":{},\"initial\":{d},\"trailers\":{d},\"duplicates\":{d},\"binary\":{d}}}\n", .{ value.status, value.sent_messages, value.received_messages, collector.bytes, collector.hash.finalResult(), value.half_closed, collector.initial, collector.trailers, collector.duplicate_metadata, collector.binary_metadata });
    } else |err| try output.interface.print("{{\"error\":\"{s}\",\"received\":{d}}}\n", .{ @errorName(err), collector.messages });
    try output.interface.flush();
}
