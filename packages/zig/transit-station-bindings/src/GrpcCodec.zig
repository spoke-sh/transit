//! Host values only; shared RPC owns descriptor, request and outcome semantics.
const std = @import("std");
pub const grpc = @import("transit_station_grpc");
const a = @import("Actions.zig");
const base = @import("Abi.zig");
const p = grpc.exchange.p;
pub const Metadata = struct { name: []const u8, value: union(enum) { literal: []const u8, secret: struct { binding: []const u8, version: []const u8 } } };
pub const Method = struct { path: []const u8, shape: grpc.Shape, descriptor_digest: []const u8 };
pub const Request = struct {
    method: Method,
    metadata: []const Metadata = &.{},
    fn native(self: Request, alloc: std.mem.Allocator) !grpc.Request {
        if (self.metadata.len > 64) return error.InvalidGrpcMetadata;
        const entries = try alloc.alloc(grpc.Request.Entry, self.metadata.len);
        for (entries, self.metadata) |*out, entry| out.* = .{ .name = entry.name, .value = switch (entry.value) {
            .literal => |hex| .{ .literal = try unhex(alloc, hex, grpc.Request.maximum_bytes) },
            .secret => |secret| .{ .secret = .{ .binding = secret.binding, .version = try unsigned(secret.version) } },
        } };
        if (self.method.descriptor_digest.len != 64) return error.InvalidGrpcDescriptor;
        var digest: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&digest, self.method.descriptor_digest);
        return .{ .method = self.method.path, .shape = self.method.shape, .descriptor_digest = digest, .metadata = entries };
    }
};
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidGrpcInteger;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidGrpcInteger;
    return std.fmt.parseInt(u64, text, 10);
}
fn unhex(alloc: std.mem.Allocator, text: []const u8, maximum: usize) ![]const u8 {
    if (text.len % 2 != 0 or text.len / 2 > maximum) return error.GrpcRequestTooLarge;
    const bytes = try alloc.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(bytes, text);
}
pub const Identity = struct {
    resource: u64,
    exchange: []const u8,
    pub fn native(self: Identity) !grpc.Service.Release {
        const result: grpc.Service.Release = .{ .resource = self.resource, .exchange = try unsigned(self.exchange) };
        try result.validate();
        return result;
    }
};
pub const Followup = struct {
    resource: u64,
    parent: []const u8,
    reference: p.Value,
    pub fn native(self: Followup) !grpc.Service.Followup {
        const ref = try grpc.RequestRecord.Reference.decode(self.reference);
        const wire = try ref.encode();
        const value: grpc.Service.Followup = .{ .resource = self.resource, .parent = try unsigned(self.parent), .reason = .retry, .request = wire.data[0..grpc.exchange.codec.size(grpc.RequestRecord.Reference)].* };
        try value.validate();
        return value;
    }
};
pub const Action = union(enum) {
    descriptor: struct { bytes: []const u8, method: []const u8 },
    prepare: struct { resource: u64, namespace: []const u8, request: Request, messages: []const []const u8, endpoint_revision: []const u8, reconcile_before_ms: u64, max_attempts: u32 = 1 },
    outcome: p.Value,
    release: Identity,
    released: p.Value,
    followup: Followup,
};
pub const Outcome = struct {
    phase: @FieldType(grpc.Service.Outcome, "phase"),
    resource: u64,
    exchange: []const u8,
    effect: u64,
    attempt: u64,
    status: ?u32,
    reference: ?p.Value,
    diagnostic: p.Diagnostic,
};
pub const Result = union(enum) {
    descriptor: struct { method: Method, input_type: []const u8, output_type: []const u8 },
    prepared: struct { reference: p.Value, metadata: []const u8, batch: []const u8, metadata_spec: grpc.exchange.Publication.Spec, batch_spec: grpc.exchange.Publication.Spec },
    outcome: Outcome,
    rejected: struct { reason: @FieldType(grpc.Service.Rejection, "reason"), diagnostic: p.Diagnostic },
    release: p.Value,
    released: Identity,
    followup: p.Value,
};
pub const ReadAction = union(enum) {
    open: struct { reference: p.Value, policy: grpc.Replay.Policy = .captured },
    next: u64,
    close: u64,
};
pub const ReadResult = union(enum) { opened: u64, part: ?grpc.Replay.Part, closed: bool };
pub fn apply(alloc: std.mem.Allocator, action: Action) !Result {
    switch (action) {
        .descriptor => |input| {
            var schema = try grpc.transport.Descriptor.parse(alloc, try unhex(alloc, input.bytes, grpc.transport.Descriptor.maximum_bytes));
            defer schema.deinit();
            const method = try schema.method(input.method);
            return .{ .descriptor = .{ .method = .{ .path = input.method, .shape = method.shape, .descriptor_digest = try a.hex(alloc, &method.descriptor_digest) }, .input_type = try alloc.dupe(u8, method.input_type), .output_type = try alloc.dupe(u8, method.output_type) } };
        },
        .prepare => |input| {
            if (input.messages.len > 64) return error.GrpcRequestTooLarge;
            const messages = try alloc.alloc([]const u8, input.messages.len);
            for (messages, input.messages) |*out, hex| out.* = try unhex(alloc, hex, (grpc.transport.Limits{}).message_bytes);
            var metadata: [grpc.Request.maximum_bytes]u8 = undefined;
            var batch: [grpc.Batch.maximum_bytes]u8 = undefined;
            const prepared = try grpc.RequestRecord.prepare(input.resource, try unsigned(input.namespace), try input.request.native(alloc), messages, try unsigned(input.endpoint_revision), input.reconcile_before_ms, input.max_attempts, &metadata, &batch);
            return .{ .prepared = .{ .reference = try prepared.reference.encode(), .metadata = try a.hex(alloc, prepared.metadata), .batch = try a.hex(alloc, prepared.batch), .metadata_spec = prepared.reference.metadataSpec(), .batch_spec = prepared.reference.batchSpec() } };
        },
        .outcome => |wire| {
            if (std.mem.startsWith(u8, wire.slice(), grpc.Service.Rejection.magic)) {
                const value = try grpc.exchange.codec.decode(grpc.Service.Rejection, wire);
                return .{ .rejected = .{ .reason = value.reason, .diagnostic = try value.diagnostic() } };
            }
            if (std.mem.startsWith(u8, wire.slice(), grpc.Service.Released.magic)) return apply(alloc, .{ .released = wire });
            const value = try grpc.Service.Outcome.decode(wire);
            return .{ .outcome = .{ .phase = value.phase, .resource = value.resource, .exchange = try a.decimal(alloc, value.exchange), .effect = value.effect, .attempt = value.attempt, .status = if (value.phase == .observed) value.status else null, .reference = if (value.phase == .observed) try (try value.reference()).encode() else null, .diagnostic = try value.diagnostic(null) } };
        },
        .release => |input| return .{ .release = try (try input.native()).encode() },
        .released => |wire| {
            const value = try grpc.Service.Released.decode(wire);
            return .{ .released = .{ .resource = value.resource, .exchange = try a.decimal(alloc, value.exchange) } };
        },
        .followup => |input| return .{ .followup = try (try input.native()).encode() },
    }
}
pub fn codec(json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > p.max_body) return .invalid_argument;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = std.json.parseFromSlice(Action, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    const result = apply(alloc, action.value) catch |err| return base.failure(err, out);
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}
test "RPC native values preserve original bytes full-width identities and unknown versus OK" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const result = (try apply(alloc, .{ .prepare = .{ .resource = 8, .namespace = "18446744073709551615", .request = .{ .method = .{ .path = "/test.Peer/Call", .shape = .bidi, .descriptor_digest = &@as([64]u8, @splat('a')) }, .metadata = &.{.{ .name = "data-bin", .value = .{ .literal = "00ff01" } }} }, .messages = &.{ "", "00ff01" }, .endpoint_revision = "7", .reconcile_before_ms = 9000 } })).prepared;
    const ref = try grpc.RequestRecord.Reference.decode(result.reference);
    try t.expectEqual(std.math.maxInt(u64), ref.namespace);
    const batch = try grpc.Batch.decode(try unhex(alloc, result.batch, grpc.Batch.maximum_bytes), .bidi, .{});
    try t.expectEqual(@as(usize, 2), batch.count);
    try t.expectError(error.InvalidGrpcInteger, unsigned("01"));
    try t.expectError(error.InvalidGrpcInteger, unsigned("-1"));
    var outcome: grpc.Service.Outcome = .{ .phase = .closed_unknown, .resource = 7, .exchange = std.math.maxInt(u64), .effect = 19, .attempt = 20, .status = 0, .chain = @splat(0) };
    const unknown = (try apply(alloc, .{ .outcome = try outcome.encode() })).outcome;
    try t.expectEqualStrings("18446744073709551615", unknown.exchange);
    try t.expectEqual(null, unknown.status);
    try t.expectEqual(null, unknown.reference);
    outcome.phase = .observed;
    const ok = (try apply(alloc, .{ .outcome = try outcome.encode() })).outcome;
    try t.expectEqual(@as(?u32, 0), ok.status);
    try t.expect(ok.reference != null);
}

test "Grpc reply diagnostics retain every status and distinguish capture completion from retry authority" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var value: grpc.Service.Outcome = .{ .phase = .observed, .resource = 7, .exchange = std.math.maxInt(u64), .effect = 19, .attempt = 20, .status = 0, .chain = @splat(1) };
    for (0..17) |status| {
        value.status = @intCast(status);
        const detail = (try apply(alloc, .{ .outcome = try value.encode() })).outcome.diagnostic;
        try t.expectEqual(.completed, detail.outcome);
        try t.expectEqual(.domain_status, detail.evidence);
        try t.expectEqual(.exchange, detail.identity.?.domain);
        try t.expectEqual(std.math.maxInt(u64), try detail.identity.?.id.value());
        try t.expectEqual(@as(u64, 7), try detail.identity.?.resource.?.value());
        try t.expectEqual(@as(u64, status), try detail.facts[3].?.value.?.unsigned.value());
        try t.expectEqual(.inspect_status, detail.actions[0].?.kind);
        try t.expectEqual(null, detail.actions[1]);
    }
    inline for (.{ .closed_unknown, .not_dispatched }) |phase| {
        value.phase = phase;
        value.status = 0;
        value.chain = @splat(0);
        value.attempt = if (phase == .closed_unknown) 20 else 0;
        const decoded = (try apply(alloc, .{ .outcome = try value.encode() })).outcome;
        try t.expectEqual(null, decoded.status);
        try t.expectEqual(null, decoded.reference);
        try t.expectEqual(if (phase == .closed_unknown) .closed_unknown else .not_dispatched, decoded.diagnostic.outcome);
        try t.expectEqual(null, decoded.diagnostic.cause);
        var wire: [8192]u8 = undefined;
        _ = try decoded.diagnostic.encode(&wire);
    }
    inline for (.{ .denied, .invalid_request, .busy }) |reason| {
        const rejected: grpc.Service.Rejection = .{ .reason = reason };
        const decoded = (try apply(alloc, .{ .outcome = try grpc.exchange.codec.encode(rejected) })).rejected;
        try t.expectEqual(reason, decoded.reason);
        try t.expectEqual(.input_rejected, decoded.diagnostic.outcome);
        try t.expectEqual(null, decoded.diagnostic.identity);
        try t.expectEqual(null, decoded.diagnostic.cause);
        var detail = decoded.diagnostic;
        try t.expectError(error.InvalidDiagnostic, detail.action(.correct_input));
    }
}
