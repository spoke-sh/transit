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

fn witness(value: ?rpc.Service.Rejection, path: []const u8, cause: anyerror) !rpc.Service.Rejection {
    const detail = value orelse return error.MissingDiagnosticEvidence;
    try detail.validate();
    try t.expectEqualStrings(path, detail.field[0..detail.field_len]);
    try t.expectEqualStrings(@errorName(cause), detail.cause[0..detail.cause_len]);
    _ = try detail.diagnostic();
    return detail;
}
test "transport metadata and batch checks retain later indices and distinct budgets" {
    var detail: ?rpc.Service.Rejection = null;
    const req: rpc.Request = .{ .method = "/test.Service/Method", .shape = .bidi, .descriptor_digest = @splat(1), .metadata = &.{ .{ .name = "x-good", .value = .{ .literal = "safe" } }, .{ .name = "x-bad", .value = .{ .literal = "private\r\n" } } } };
    try t.expectError(error.InvalidGrpcMetadata, req.validateDiagnostic(&detail));
    const metadata = try witness(detail, "request.metadata[1].value", error.InvalidGrpcMetadata);
    try t.expectEqual(.redacted, metadata.actual_kind);
    var bytes: [100]u8 = undefined;
    const batch = try rpc.Batch.encode(&.{ "a", "longer" }, .bidi, .{}, &bytes);
    detail = null;
    try t.expectError(error.GrpcBudgetExceeded, rpc.Batch.decodeDiagnostic(batch, .bidi, .{ .message_bytes = 5 }, &detail));
    const message = try witness(detail, "request.messages[1].bytes", error.GrpcBudgetExceeded);
    try t.expectEqual(@as(u64, 5), message.expected_number);
    try t.expectEqual(@as(u64, 6), message.actual_number);
    detail = null;
    try t.expectError(error.GrpcBudgetExceeded, rpc.Batch.decodeDiagnostic(batch, .bidi, .{ .request_bytes = 16 }, &detail));
    const framed = try witness(detail, "request.framed_bytes", error.GrpcBudgetExceeded);
    try t.expectEqual(@as(u64, 17), framed.actual_number);
    detail = null;
    try t.expectError(error.InvalidGrpcBatch, rpc.Batch.decodeDiagnostic(batch[0 .. batch.len - 1], .bidi, .{}, &detail));
    const truncated = try witness(detail, "request.batch[1].bytes", error.InvalidGrpcBatch);
    try t.expectEqual(@as(u64, 6), truncated.expected_number);
    try t.expectEqual(@as(u64, 5), truncated.actual_number);
    const original = detail;
    try t.expectError(error.InvalidGrpcMetadata, req.validateDiagnostic(&detail));
    try t.expectEqualDeep(original, detail);
}
test "prepared policy witnesses separate original fields and withhold credential contents" {
    const good: rpc.Policy.Prepared = .{ .endpoint_revision = 1, .host = "private.example", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .limits = .{}, .trust_digest = @splat(1), .method = "/test.Service/Method", .shape = .bidi, .descriptor_digest = @splat(2), .metadata_digest = @splat(3), .batch_digest = @splat(4) };
    try good.validate();
    const cases = [_]struct { field: []const u8, cause: anyerror }{
        .{ .field = "policy.version", .cause = error.InvalidGrpcPolicy },
        .{ .field = "policy.endpoint_revision", .cause = error.InvalidGrpcPolicy },
        .{ .field = "policy.trust_digest", .cause = error.InvalidGrpcPolicy },
        .{ .field = "limits.response_bytes", .cause = error.InvalidGrpcLimits },
        .{ .field = "endpoint.port", .cause = error.InvalidGrpcEndpoint },
        .{ .field = "endpoint.timeout_ms", .cause = error.InvalidGrpcEndpoint },
        .{ .field = "policy.credentials[1].version", .cause = error.InvalidGrpcSecret },
        .{ .field = "policy.credentials[1]", .cause = error.DuplicateGrpcCredential },
        .{ .field = "policy.response_metadata[1]", .cause = error.GrpcCredentialCaptureForbidden },
        .{ .field = "policy.response_metadata[1]", .cause = error.InvalidGrpcMetadata },
        .{ .field = "policy.retry.revision", .cause = error.GrpcFollowupNotGranted },
        .{ .field = "policy.retry.key_metadata", .cause = error.InvalidGrpcIdempotencyKey },
    };
    for (cases, 0..) |case, index| {
        var changed = good;
        switch (index) {
            0 => changed.version = 2,
            1 => changed.endpoint_revision = 0,
            2 => changed.trust_digest = null,
            3 => changed.limits.response_bytes = 262145,
            4 => changed.port = 0,
            5 => changed.timeout_ms = 300001,
            6 => changed.credentials = &.{ .{ .binding = "first", .version = 1, .metadata = "authorization" }, .{ .binding = "private-binding", .version = 0, .metadata = "x-secret" } },
            7 => changed.credentials = &.{ .{ .binding = "private-binding", .version = 1, .metadata = "authorization" }, .{ .binding = "private-binding", .version = 2, .metadata = "x-secret" } },
            8 => changed.response_metadata = &.{ "x-good", "authorization" },
            9 => changed.response_metadata = &.{ "x-good", "X-Bad" },
            10 => changed.retry_policy = .{ .id = 1, .revision = 0, .key_metadata = "x-key" },
            11 => changed.retry_policy = .{ .id = 1, .revision = 1, .key_metadata = "authorization" },
            else => unreachable,
        }
        var detail: ?rpc.Service.Rejection = null;
        try t.expectError(case.cause, changed.validateDiagnostic(&detail));
        try t.expectError(case.cause, changed.validate());
        const original = try witness(detail, case.field, case.cause);
        const envelope = try original.diagnostic();
        const json = try std.json.Stringify.valueAlloc(t.allocator, envelope, .{});
        defer t.allocator.free(json);
        try t.expect(std.mem.indexOf(u8, json, "private") == null);
    }
}
test "provenance decoding identifies original version hex and canonical failures without classifying allocation" {
    const request: rpc.Request = .{ .method = "/test.Service/Method", .shape = .bidi, .descriptor_digest = @splat(1), .metadata = &.{.{ .name = "x-test", .value = .{ .literal = "value" } }} };
    var bytes: [8192]u8 = undefined;
    const encoded = try request.provenance(&bytes);
    var detail: ?rpc.Service.Rejection = null;
    var failing: std.testing.FailingAllocator = .init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutOfMemory, rpc.Request.parseDiagnostic(failing.allocator(), encoded, &detail));
    try t.expectEqual(null, detail);
    const version = std.mem.indexOf(u8, encoded, "\"version\":1").? + 10;
    bytes[version] = '2';
    try t.expectError(error.InvalidGrpcRequest, rpc.Request.parseDiagnostic(t.allocator, encoded, &detail));
    _ = try witness(detail, "request.version", error.InvalidGrpcRequest);
    bytes[version] = '1';
    const literal = std.mem.indexOf(u8, encoded, "\"literal_hex\":\"").? + 15;
    bytes[literal] = 'z';
    detail = null;
    try t.expectError(error.InvalidCharacter, rpc.Request.parseDiagnostic(t.allocator, encoded, &detail));
    const hex = try witness(detail, "request.metadata[0].literal_hex", error.InvalidCharacter);
    try t.expectEqual(.redacted, hex.actual_kind);
}

test "request reference checks retain the actual mismatching commitment and first field" {
    const request: rpc.Request = .{ .method = "/test.Service/Method", .shape = .bidi, .descriptor_digest = @splat(1) };
    var metadata: [8192]u8 = undefined;
    var batch: [100]u8 = undefined;
    const good = try rpc.RequestRecord.prepare(3, std.math.maxInt(u64), request, &.{"body"}, 1, 1000, 1, &metadata, &batch);
    const cases = [_][]const u8{ "request.resource", "request.namespace", "request.metadata.bytes", "request.batch.bytes", "request.endpoint_revision", "request.reconcile_before_ms", "request.max_attempts", "request.metadata.digest", "request.batch.digest", "request.shape", "request.descriptor_digest" };
    for (cases, 0..) |path, index| {
        var changed = good.reference;
        switch (index) {
            0 => changed.resource = 0,
            1 => changed.namespace = 0,
            2 => changed.metadata_bytes += 1,
            3 => changed.batch_bytes += 1,
            4 => changed.endpoint_revision = 0,
            5 => changed.reconcile_before_ms = 0,
            6 => changed.max_attempts = 0,
            7 => changed.metadata_digest[0] ^= 1,
            8 => changed.batch_digest[0] ^= 1,
            9 => changed.shape = .unary,
            10 => changed.descriptor_digest[0] ^= 1,
            else => unreachable,
        }
        var detail: ?rpc.Service.Rejection = null;
        try t.expectError(error.InvalidGrpcRequestReference, rpc.RequestRecord.validateContentDiagnostic(t.allocator, changed, good.metadata, good.batch, &detail));
        const original = try witness(detail, path, error.InvalidGrpcRequestReference);
        if (index == 7) {
            try t.expectEqualSlices(u8, &changed.metadata_digest, &original.expected_text);
            try t.expectEqualSlices(u8, &good.reference.metadata_digest, &original.actual_text);
        }
        if (index == 8) {
            try t.expectEqualSlices(u8, &changed.batch_digest, &original.expected_text);
            try t.expectEqualSlices(u8, &good.reference.batch_digest, &original.actual_text);
        }
    }
}
