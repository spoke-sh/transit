const std = @import("std");
const t = std.testing;
const rpc = @import("root.zig");
const x = rpc.exchange;
const Fixture = struct { metadata: []const u8, messages_hex: []const []const u8, batch_hex: []const u8, reference_hex: []const u8 };
test "independent GRQ1 GRB1 canonical metadata and original protobuf fixture" {
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/request.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    var batch_buffer: [rpc.Batch.maximum_bytes]u8 = undefined;
    const batch_bytes = try std.fmt.hexToBytes(&batch_buffer, fixture.batch_hex);
    const batch = try rpc.Batch.decode(batch_bytes, .bidi, .{});
    try t.expectEqual(@as(usize, 3), batch.count);
    for (batch.messages(), fixture.messages_hex) |message, hex| {
        var expected: [100]u8 = undefined;
        try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, hex), message);
    }
    var raw: [256]u8 = undefined;
    const reference = try rpc.RequestRecord.Reference.decode(try x.p.Value.init(try std.fmt.hexToBytes(&raw, fixture.reference_hex)));
    try t.expectEqual(std.math.maxInt(u64), reference.namespace);
    try t.expectEqual(std.math.maxInt(u64), reference.endpoint_revision);
    try t.expectEqual(std.math.maxInt(u32), reference.max_attempts);
    var owned = try rpc.RequestRecord.validateContent(t.allocator, reference, fixture.metadata, batch_bytes);
    defer owned.deinit();
    try t.expectEqual(std.math.maxInt(u64), owned.request.metadata[3].value.secret.version);
    try t.expectEqualSlices(u8, &.{ 0, 255, 128, 10 }, owned.request.metadata[2].value.literal);
    var metadata: [rpc.Request.maximum_bytes]u8 = undefined;
    var encoded_batch: [rpc.Batch.maximum_bytes]u8 = undefined;
    const prepared = try rpc.RequestRecord.prepare(reference.resource, reference.namespace, owned.request, batch.messages(), reference.endpoint_revision, reference.reconcile_before_ms, reference.max_attempts, &metadata, &encoded_batch);
    try t.expectEqualDeep(reference, prepared.reference);
    try t.expectEqualStrings(fixture.metadata, prepared.metadata);
    try t.expectEqualSlices(u8, batch_bytes, prepared.batch);
    var fields: [64]rpc.transport.Entry = undefined;
    try t.expectError(error.GrpcSecretUnresolved, owned.request.render(batch.messages(), &fields, null, .{}));
    var changed = reference;
    changed.shape = .client_streaming;
    try t.expectError(error.InvalidGrpcRequestReference, rpc.RequestRecord.validateContent(t.allocator, changed, fixture.metadata, batch_bytes));
    changed = reference;
    changed.descriptor_digest[0] ^= 1;
    try t.expectError(error.InvalidGrpcRequestReference, rpc.RequestRecord.validateContent(t.allocator, changed, fixture.metadata, batch_bytes));
    const encoded = try reference.encode();
    for (0..encoded.len) |len| try t.expectError(error.InvalidExchangeRecord, rpc.RequestRecord.Reference.decode(try x.p.Value.init(encoded.slice()[0..len])));
}
test "batch framing distinguishes empty from absent and rejects truncated excessive or trailing data" {
    var buffer: [rpc.Batch.maximum_bytes]u8 = undefined;
    const bytes = try rpc.Batch.encode(&.{ "", "\x00\xff", "caf\xc3\xa9\xf0\x9f\x8c\x90" }, .bidi, .{}, &buffer);
    for (0..bytes.len) |len| try t.expectError(error.InvalidGrpcBatch, rpc.Batch.decode(bytes[0..len], .bidi, .{}));
    buffer[bytes.len] = 0;
    try t.expectError(error.InvalidGrpcBatch, rpc.Batch.decode(buffer[0 .. bytes.len + 1], .bidi, .{}));
    try t.expectError(error.InvalidGrpcShape, rpc.Batch.decode(bytes, .unary, .{}));
    try t.expectError(error.GrpcBudgetExceeded, rpc.Batch.decode(bytes, .bidi, .{ .request_messages = 2 }));
    try t.expectError(error.GrpcBudgetExceeded, rpc.Batch.decode(bytes, .bidi, .{ .request_bytes = 16 }));
    const empty = try rpc.Batch.encode(&.{}, .bidi, .{}, &buffer);
    try t.expectEqual(@as(usize, 0), (try rpc.Batch.decode(empty, .bidi, .{})).count);
    const one = try rpc.Batch.encode(&.{""}, .unary, .{}, &buffer);
    const decoded = try rpc.Batch.decode(one, .unary, .{});
    try t.expectEqual(@as(usize, 1), decoded.count);
    try t.expectEqual(@as(u32, 5), decoded.wire_bytes);
    const oversized: [16385]u8 = @splat(0);
    try t.expectError(error.GrpcBudgetExceeded, rpc.Batch.encode(&.{&oversized}, .bidi, .{}, &buffer));
}
test "metadata rejects noncanonical input and field injection before interpolation" {
    const request: rpc.Request = .{ .method = "/test.Service/Method", .shape = .unary, .descriptor_digest = @splat(1), .metadata = &.{.{ .name = "x-text", .value = .{ .literal = "safe" } }} };
    var buffer: [8193]u8 = undefined;
    const bytes = try request.provenance(&buffer);
    buffer[bytes.len] = ' ';
    try t.expectError(error.NonCanonicalGrpcRequest, rpc.Request.parse(t.allocator, buffer[0 .. bytes.len + 1]));
    var bad = request;
    bad.metadata = &.{.{ .name = "x-inject", .value = .{ .literal = "bad\r\n" } }};
    try t.expectError(error.InvalidGrpcMetadata, bad.validate());
    bad.metadata = &.{.{ .name = "grpc-status", .value = .{ .literal = "0" } }};
    try t.expectError(error.InvalidGrpcMetadata, bad.validate());
    bad.metadata = &.{.{ .name = "x-secret", .value = .{ .secret = .{ .binding = "bad/name", .version = 1 } } }};
    try t.expectError(error.InvalidGrpcSecret, bad.validate());
    bad.method = "/test.Service/Method/extra";
    bad.metadata = &.{};
    try t.expectError(error.InvalidGrpcRequest, bad.validate());
}
