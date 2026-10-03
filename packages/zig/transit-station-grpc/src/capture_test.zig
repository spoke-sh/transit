const std = @import("std");
const t = std.testing;
const rpc = @import("root.zig");
const c = rpc.Capture;
const x = rpc.exchange;
const Log = struct {
    const Segment = struct { kind: c.Kind, bytes: []u8 };
    segments: std.ArrayList(Segment) = .empty,
    fail_at: ?usize = null,
    fn deinit(self: *Log) void {
        for (self.segments.items) |segment| t.allocator.free(segment.bytes);
        self.segments.deinit(t.allocator);
    }
    fn append(raw: *anyopaque, kind: c.Kind, bytes: []const u8) !void {
        const self: *Log = @ptrCast(@alignCast(raw));
        if (self.fail_at == self.segments.items.len) return error.Unavailable;
        const copy = try t.allocator.dupe(u8, bytes);
        errdefer t.allocator.free(copy);
        try self.segments.append(t.allocator, .{ .kind = kind, .bytes = copy });
    }
    fn replay(self: *const Log, validator: *rpc.Replay.Validator) !c.Completion {
        for (self.segments.items) |segment| {
            var offset: usize = 0;
            while (offset < segment.bytes.len) {
                const len = @min(17, segment.bytes.len - offset);
                try validator.push(segment.kind, segment.bytes[offset..][0..len], offset + len == segment.bytes.len);
                offset += len;
            }
            if (segment.bytes.len == 0) try validator.push(segment.kind, "", true);
        }
        return validator.finish();
    }
};
const initial = [_]rpc.transport.Field{
    .{ .name = ":status", .value = "200" },
    .{ .name = "content-type", .value = "application/grpc" },
    .{ .name = "x-duplicate", .value = "one" },
    .{ .name = "x-duplicate", .value = "two" },
    .{ .name = "x-binary-bin", .value = "AP+A" },
    .{ .name = "set-cookie", .value = "private-response-value" },
};
const trailers = [_]rpc.transport.Field{.{ .name = "grpc-status", .value = "0" }};
fn prepare(log: *Log, shape: rpc.Shape, secret: bool) !c.HalfClose {
    const request: rpc.Request = .{ .method = "/fixture.Service/Call", .shape = shape, .descriptor_digest = @splat(7), .metadata = if (secret) &.{.{ .name = "authorization", .value = .{ .secret = .{ .binding = "token", .version = 1 } } }} else &.{} };
    var metadata: [8192]u8 = undefined;
    const metadata_bytes = try request.provenance(&metadata);
    try Log.append(log, .request_metadata, metadata_bytes);
    var bytes: [rpc.Batch.maximum_bytes]u8 = undefined;
    const messages: []const []const u8 = if (shape == .unary or shape == .server_streaming) &.{"\x0a\x02hi"} else &.{ "", "\x0a\x02hi", "\x12\x02\x00\xff" };
    const encoded = try rpc.Batch.encode(messages, shape, .{}, &bytes);
    try Log.append(log, .request_batch, encoded);
    const policy: rpc.Policy.Prepared = .{ .endpoint_revision = 1, .host = "peer.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .limits = .{}, .response_metadata = &.{ "x-duplicate", "x-binary-bin" }, .trust_digest = @splat(1), .method = request.method, .shape = request.shape, .descriptor_digest = request.descriptor_digest, .metadata_digest = (try x.Publication.Digest.of(2, metadata_bytes)).digest, .batch_digest = (try x.Publication.Digest.of(2, encoded)).digest, .credentials = if (secret) &.{.{ .binding = "token", .version = 1, .metadata = "authorization" }} else &.{} };
    var policy_buffer: [8192]u8 = undefined;
    try policy.validateRequest(request);
    try Log.append(log, .endpoint_policy, try policy.encode(&policy_buffer));
    const batch = try rpc.Batch.decode(encoded, shape, .{});
    return .{ .messages = @intCast(batch.count), .wire_bytes = batch.wire_bytes };
}
fn complete(log: *Log, shape: rpc.Shape, secret: bool) !void {
    const planned = try prepare(log, shape, secret);
    var capture: c = .{ .sink = .{ .context = log, .append = Log.append }, .allowlist = &.{ "x-duplicate", "x-binary-bin" }, .planned = planned, .request_secrets = @intFromBool(secret) };
    // Incoming progress may precede the local request half-close. A finite
    // callback order records observation, not causality between directions.
    try c.emit(&capture, .{ .initial_metadata = &initial });
    const bytes: [9000]u8 = @splat(0xf3);
    try c.emit(&capture, .{ .message = &bytes });
    try c.emit(&capture, .half_close);
    const stream = shape == .server_streaming or shape == .bidi;
    if (stream) try c.emit(&capture, .{ .message = "" });
    try c.emit(&capture, .{ .trailers = &trailers });
    const result = try capture.finish(.{ .status = 0, .sent_messages = planned.messages, .sent_bytes = planned.wire_bytes, .received_messages = if (stream) 2 else 1, .received_bytes = if (stream) 9010 else 9005, .half_closed = true }, .{ .started_ms = 1, .elapsed_ns = 2 });
    try t.expectEqual(@as(u32, 1), try result.terminalCode());
    try t.expectError(error.GrpcCaptureClosed, c.emit(&capture, .half_close));
    for (log.segments.items) |segment| try t.expect(std.mem.indexOf(u8, segment.bytes, "private-response-value") == null);
}
test "all shapes verify bounded message parts and directional completion without effects or sockets" {
    inline for (std.meta.tags(rpc.Shape)) |shape| {
        var log: Log = .{};
        defer log.deinit();
        try complete(&log, shape, false);
        var validator: rpc.Replay.Validator = .{ .terminal_code = 1 };
        const result = try log.replay(&validator);
        try t.expectEqual(@as(u32, 0), result.status);
        try t.expectEqual(.yes, result.half_closed);
        var exact: rpc.Replay.Validator = .{ .terminal_code = 1, .policy = .require_unredacted };
        try t.expectError(error.GrpcReplayGap, log.replay(&exact));
        var wrong: rpc.Replay.Validator = .{ .terminal_code = 2 };
        try t.expectError(error.GrpcReplayGap, log.replay(&wrong));
    }
}
test "missing altered duplicated or interleaved message evidence cannot become complete success" {
    var log: Log = .{};
    defer log.deinit();
    try complete(&log, .bidi, true);
    var validator: rpc.Replay.Validator = .{ .terminal_code = 1 };
    _ = try log.replay(&validator);
    const index = for (log.segments.items, 0..) |part, i| {
        if (part.kind == .response_body) break i;
    } else unreachable;
    log.segments.items[index].bytes[0] ^= 1;
    validator = .{ .terminal_code = 1 };
    try t.expectError(error.GrpcReplayGap, log.replay(&validator));
    try t.expectError(error.GrpcReplayFailed, validator.finish());
    log.segments.items[index].bytes[0] ^= 1;
    const saved = log.segments.items[index];
    log.segments.items[index].kind = .half_close;
    validator = .{ .terminal_code = 1 };
    try t.expectError(error.GrpcReplayGap, log.replay(&validator));
    log.segments.items[index] = saved;
    const last = log.segments.pop().?;
    defer t.allocator.free(last.bytes);
    validator = .{ .terminal_code = 1 };
    try t.expectError(error.GrpcReplayGap, log.replay(&validator));
}
test "sink failure preserves prefix and makes the active capture unusable" {
    var log: Log = .{};
    defer log.deinit();
    const planned = try prepare(&log, .bidi, false);
    var capture: c = .{ .sink = .{ .context = &log, .append = Log.append }, .planned = planned };
    try c.emit(&capture, .{ .initial_metadata = &initial });
    log.fail_at = log.segments.items.len + 2; // header + first body part accepted
    const bytes: [9000]u8 = @splat(0x80);
    try t.expectError(error.Unavailable, c.emit(&capture, .{ .message = &bytes }));
    try t.expectEqual(@as(u32, 0), capture.received);
    try t.expectEqual(c.Kind.response_body, log.segments.items[log.segments.items.len - 1].kind);
    try t.expectError(error.GrpcCaptureClosed, c.emit(&capture, .{ .message = &bytes }));
    var validator: rpc.Replay.Validator = .{ .terminal_code = 1 };
    try t.expectError(error.GrpcReplayGap, log.replay(&validator));
}
test "trailers-only non-OK may precede sending and half-close without inventing sent counts" {
    var log: Log = .{};
    defer log.deinit();
    const planned = try prepare(&log, .client_streaming, false);
    var capture: c = .{ .sink = .{ .context = &log, .append = Log.append }, .planned = planned };
    const refused = [_]rpc.transport.Field{ .{ .name = ":status", .value = "200" }, .{ .name = "content-type", .value = "application/grpc" }, .{ .name = "grpc-status", .value = "7" } };
    try c.emit(&capture, .{ .initial_metadata = &refused });
    _ = try capture.finish(.{ .status = 7, .sent_messages = 0, .sent_bytes = 3, .received_messages = 0, .received_bytes = 0, .half_closed = false }, .{ .started_ms = 5, .elapsed_ns = 7 });
    var validator: rpc.Replay.Validator = .{ .terminal_code = 8, .policy = .require_unredacted };
    const result = try log.replay(&validator);
    try t.expectEqual(@as(u32, 3), result.sent_bytes);
    try t.expectEqual(.no, result.half_closed);
    const terminal = &log.segments.items[log.segments.items.len - 1];
    var bad = try x.codec.decode(c.Completion, try x.p.Value.init(terminal.bytes));
    bad.sent_bytes = planned.wire_bytes;
    const encoded = try x.codec.encode(bad);
    @memcpy(terminal.bytes, encoded.slice());
    validator = .{ .terminal_code = 8 };
    try t.expectError(error.GrpcReplayGap, log.replay(&validator));
}
test "metadata preserves duplicate binary wire values but rejects invalid omitted fields" {
    var buffer: [8192]u8 = undefined;
    const captured = try rpc.Metadata.capture(&initial, &.{ "x-duplicate", "x-binary-bin" }, false, &buffer);
    try t.expectEqual(@as(u32, 1), captured.omitted);
    const block = try rpc.Metadata.decode(captured.bytes, false);
    try t.expectEqualStrings("one", block.entries()[2].value);
    try t.expectEqualStrings("two", block.entries()[3].value);
    try t.expectEqualStrings("AP+A", block.entries()[4].value);
    var fields = initial;
    fields[5].value = "bad\n";
    try t.expectError(error.InvalidGrpcMetadata, rpc.Metadata.capture(&fields, &.{}, false, &buffer));
    fields = initial;
    fields[4].value = "%%%";
    try t.expectError(error.InvalidGrpcMetadata, rpc.Metadata.capture(&fields, &.{}, false, &buffer));
    fields = initial;
    fields[4].value = "AP+A, /w==";
    _ = try rpc.Metadata.capture(&fields, &.{"x-binary-bin"}, false, &buffer);
    fields[4].value = "/w===";
    try t.expectError(error.InvalidGrpcMetadata, rpc.Metadata.capture(&fields, &.{}, false, &buffer));
    try t.expectError(error.InvalidGrpcMetadata, rpc.Metadata.capture(&.{ .{ .name = "grpc-status", .value = "0" }, .{ .name = "grpc-status", .value = "7" } }, &.{}, true, &buffer));
}

test "explicit retry freezes routing schema credentials and exact batch without acquiring authority" {
    const request: rpc.Request = .{ .method = "/service.Remote/Apply", .shape = .unary, .descriptor_digest = @splat(9), .metadata = &.{ .{ .name = "idempotency-key", .value = .{ .literal = "fixed-operation" } }, .{ .name = "authorization", .value = .{ .secret = .{ .binding = "token", .version = 3 } } } } };
    var buffer: [8192]u8 = undefined;
    const spec = try x.Publication.Digest.of(2, try request.provenance(&buffer));
    const parent: rpc.Policy.Prepared = .{ .endpoint_revision = 1, .host = "peer.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .limits = .{}, .trust_digest = @splat(1), .method = request.method, .shape = request.shape, .descriptor_digest = request.descriptor_digest, .metadata_digest = spec.digest, .batch_digest = @splat(7), .credentials = &.{.{ .binding = "token", .version = 3, .metadata = "authorization" }}, .retry_policy = .{ .id = 1, .revision = std.math.maxInt(u64), .key_metadata = "idempotency-key" } };
    const decision = try rpc.Policy.followup(.retry, parent, parent, request);
    try t.expectEqual(std.math.maxInt(u64), decision.revision);
    try t.expectError(error.GrpcFollowupNotGranted, rpc.Policy.followup(.redirect, parent, parent, request));
    var next = parent;
    next.address = "169.254.169.254";
    try t.expectError(error.GrpcFollowupChanged, rpc.Policy.followup(.retry, parent, next, request));
    next = parent;
    next.batch_digest[0] ^= 1;
    try t.expectError(error.GrpcFollowupChanged, rpc.Policy.followup(.retry, parent, next, request));
    next = parent;
    next.descriptor_digest[0] ^= 1;
    try t.expectError(error.GrpcRequestNotGranted, rpc.Policy.followup(.retry, parent, next, request));
    next = parent;
    next.credentials = &.{.{ .binding = "token", .version = 4, .metadata = "authorization" }};
    try t.expectError(error.GrpcCredentialNotGranted, next.validateRequest(request));
    next = parent;
    next.response_metadata = &.{"authorization"};
    try t.expectError(error.GrpcCredentialCaptureForbidden, next.validate());
    next = parent;
    next.tls = false;
    next.trust_digest = null;
    try t.expectError(error.GrpcCredentialRequiresTls, next.validate());
    var literal = request;
    literal.metadata = &.{.{ .name = "authorization", .value = .{ .literal = "private-credential" } }};
    try t.expectError(error.GrpcCredentialReferenceRequired, literal.provenance(&buffer));
}

test "independent RPC capture layouts preserve binary metadata and full-width timing" {
    const Fixture = struct { initial_hex: []const u8, trailers_hex: []const u8, message_hex: []const u8, half_close_hex: []const u8, timing_hex: []const u8, omission_hex: []const u8, completion_hex: []const u8, body_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/capture.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    var buffer: [8192]u8 = undefined;
    const initial_block = try rpc.Metadata.decode(try std.fmt.hexToBytes(&buffer, fixture.initial_hex), false);
    try t.expectEqualStrings("AP8=", initial_block.entries()[4].value);
    const terminal = try rpc.Metadata.decode(try std.fmt.hexToBytes(&buffer, fixture.trailers_hex), true);
    try t.expectEqual(@as(u32, 0), terminal.status.?);
    inline for (.{ .{ c.Message, "message_hex" }, .{ c.HalfClose, "half_close_hex" }, .{ c.Timing, "timing_hex" }, .{ c.Omission, "omission_hex" }, .{ c.Completion, "completion_hex" } }) |item| {
        const bytes = try std.fmt.hexToBytes(&buffer, @field(fixture, item[1]));
        const record = try x.codec.decode(item[0], try x.p.Value.init(bytes));
        try t.expectEqualSlices(u8, bytes, (try x.codec.encode(record)).slice());
        for (0..bytes.len) |len| try t.expectError(error.InvalidExchangeRecord, x.codec.decode(item[0], try x.p.Value.init(bytes[0..len])));
    }
    const timing = try x.codec.decode(c.Timing, try x.p.Value.init(try std.fmt.hexToBytes(&buffer, fixture.timing_hex)));
    try t.expectEqual(std.math.maxInt(u64), timing.started_ms);
    const header = try x.codec.decode(c.Message, try x.p.Value.init(try std.fmt.hexToBytes(&buffer, fixture.message_hex)));
    const body = try std.fmt.hexToBytes(&buffer, fixture.body_hex);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &digest, .{});
    try t.expectEqualSlices(u8, &digest, &header.digest);
    try t.expectEqual(body.len, header.length);
}

test "grpc policy witnesses distinguish route, shape, schema, credential and frozen batch" {
    const request: rpc.Request = .{ .method = "/service.Remote/Apply", .shape = .unary, .descriptor_digest = @splat(9), .metadata = &.{ .{ .name = "idempotency-key", .value = .{ .literal = "fixed-operation" } }, .{ .name = "authorization", .value = .{ .secret = .{ .binding = "token", .version = 3 } } } } };
    var buffer: [8192]u8 = undefined;
    const spec = try x.Publication.Digest.of(2, try request.provenance(&buffer));
    const parent: rpc.Policy.Prepared = .{ .endpoint_revision = 1, .host = "peer.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .limits = .{}, .trust_digest = @splat(1), .method = request.method, .shape = request.shape, .descriptor_digest = request.descriptor_digest, .metadata_digest = spec.digest, .batch_digest = @splat(7), .credentials = &.{.{ .binding = "token", .version = 3, .metadata = "authorization" }}, .retry_policy = .{ .id = 1, .revision = std.math.maxInt(u64), .key_metadata = "idempotency-key" } };
    var context: ?rpc.Service.Rejection = null;
    var next = parent;
    next.method = "/service.Remote/Other";
    context = null;
    try t.expectError(error.GrpcRequestNotGranted, rpc.Policy.followupDiagnostic(.retry, parent, next, request, &context));
    try t.expectEqualStrings("request.method", context.?.field[0..context.?.field_len]);
    next = parent;
    next.shape = .server_streaming;
    context = null;
    try t.expectError(error.GrpcRequestNotGranted, rpc.Policy.followupDiagnostic(.retry, parent, next, request, &context));
    try t.expectEqualStrings("request.shape", context.?.field[0..context.?.field_len]);
    next = parent;
    next.descriptor_digest[0] ^= 1;
    context = null;
    try t.expectError(error.GrpcRequestNotGranted, rpc.Policy.followupDiagnostic(.retry, parent, next, request, &context));
    try t.expectEqualStrings("request.descriptor_digest", context.?.field[0..context.?.field_len]);
    try t.expectEqualSlices(u8, &next.descriptor_digest, &context.?.expected_text);
    next = parent;
    next.credentials = &.{.{ .binding = "token", .version = 4, .metadata = "authorization" }};
    context = null;
    try t.expectError(error.GrpcCredentialNotGranted, next.validateRequestDiagnostic(request, &context));
    try t.expectEqualStrings("request.metadata[1]", context.?.field[0..context.?.field_len]);
    try t.expectEqual(.redacted, context.?.expected_kind);
    try t.expectEqual(.redacted, context.?.actual_kind);
    next = parent;
    next.batch_digest[0] ^= 1;
    context = null;
    try t.expectError(error.GrpcFollowupChanged, rpc.Policy.followupDiagnostic(.retry, parent, next, request, &context));
    try t.expectEqualStrings("policy.batch_digest", context.?.field[0..context.?.field_len]);
    try t.expectEqualSlices(u8, &parent.batch_digest, &context.?.expected_text);
    try t.expectEqualSlices(u8, &next.batch_digest, &context.?.actual_text);
    context = null;
    try t.expectError(error.GrpcFollowupNotGranted, rpc.Policy.followupDiagnostic(.redirect, parent, parent, request, &context));
    try t.expectEqualStrings("followup.reason", context.?.field[0..context.?.field_len]);
    var literal = request;
    literal.metadata = &.{.{ .name = "authorization", .value = .{ .literal = "private-credential" } }};
    context = null;
    try t.expectError(error.GrpcCredentialReferenceRequired, parent.validateRequestDiagnostic(literal, &context));
    try t.expectEqualStrings("metadata[0].value", context.?.field[0..context.?.field_len]);
    try t.expectEqual(.redacted, context.?.actual_kind);
    const encoded = try x.codec.encode(context.?);
    try t.expectEqual(null, std.mem.indexOf(u8, encoded.slice(), "private-credential"));
    try t.expectEqualDeep(context.?, try x.codec.decode(rpc.Service.Rejection, encoded));
}
