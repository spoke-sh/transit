//! Host values and buffers only. Shared HTTP owns request and outcome semantics.
const std = @import("std");
pub const http = @import("transit_station_http");
const a = @import("Actions.zig");
const base = @import("Abi.zig");
const p = http.exchange.p;
pub const Piece = union(enum) {
    literal: []const u8,
    variable: struct { name: []const u8, value: []const u8 },
    secret: struct { binding: []const u8, version: []const u8 },
};
pub const Header = struct { name: []const u8, value: []const Piece };
pub const Request = struct {
    method: std.http.Method,
    target: []const Piece,
    headers: []const Header = &.{},
    fn native(self: Request, alloc: std.mem.Allocator, body_bytes: usize) !http.Request {
        if (self.headers.len > http.Request.maximum_headers) return error.HttpRequestTooLarge;
        const headers = try alloc.alloc(http.Request.Header, self.headers.len);
        for (headers, self.headers) |*out, header| out.* = .{ .name = header.name, .value = try pieces(alloc, header.value) };
        return .{ .method = self.method, .target = try pieces(alloc, self.target), .headers = headers, .body_bytes = body_bytes };
    }
};
fn pieces(alloc: std.mem.Allocator, input: []const Piece) ![]const http.Request.Piece {
    if (input.len > http.Request.maximum_pieces) return error.HttpRequestTooLarge;
    const result = try alloc.alloc(http.Request.Piece, input.len);
    for (result, input) |*out, item| out.* = switch (item) {
        .literal => |v| .{ .literal = v },
        .variable => |v| .{ .variable = .{ .name = v.name, .value = v.value } },
        .secret => |v| .{ .secret = .{ .binding = v.binding, .version = try unsigned(v.version) } },
    };
    return result;
}
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidHttpInteger;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidHttpInteger;
    return std.fmt.parseInt(u64, text, 10);
}
pub const Action = union(enum) {
    prepare: struct { resource: u64, namespace: []const u8, request: Request, body: []const u8, endpoint_revision: []const u8, reconcile_before_ms: u64, max_attempts: u32 = 1 },
    outcome: p.Value,
};
pub const Outcome = struct {
    phase: @FieldType(http.Service.Outcome, "phase"),
    resource: u64,
    exchange: []const u8,
    effect: u64,
    attempt: u64,
    status: ?u16,
    reference: ?p.Value,
};
pub const Result = union(enum) {
    prepared: struct { reference: p.Value, metadata: []const u8, metadata_spec: http.exchange.Publication.Spec, body_spec: http.exchange.Publication.Spec },
    outcome: Outcome,
    rejected: @FieldType(http.Service.Rejection, "reason"),
};
pub const ReadAction = union(enum) {
    open: struct { reference: p.Value, policy: http.Replay.Policy = .captured },
    next: u64,
    close: u64,
};
pub const ReadResult = union(enum) {
    opened: u64,
    part: ?http.Replay.Part,
    closed: bool,
};
pub fn apply(alloc: std.mem.Allocator, action: Action) !Result {
    switch (action) {
        .prepare => |input| {
            if (input.body.len > http.RequestRecord.maximum_body_bytes * 2 or input.body.len % 2 != 0) return error.InvalidHttpBodyLength;
            const body = try alloc.alloc(u8, input.body.len / 2);
            _ = try std.fmt.hexToBytes(body, input.body);
            var buffer: [http.Request.maximum_head_bytes]u8 = undefined;
            const prepared = try http.RequestRecord.prepare(input.resource, try unsigned(input.namespace), try input.request.native(alloc, body.len), body, try unsigned(input.endpoint_revision), input.reconcile_before_ms, input.max_attempts, &buffer);
            return .{ .prepared = .{ .reference = try prepared.reference.encode(), .metadata = try a.hex(alloc, prepared.metadata), .metadata_spec = prepared.reference.metadataSpec(), .body_spec = prepared.reference.bodySpec() } };
        },
        .outcome => |wire| {
            if (std.mem.startsWith(u8, wire.slice(), http.Service.Rejection.magic)) return .{ .rejected = (try http.exchange.codec.decode(http.Service.Rejection, wire)).reason };
            const value = try http.Service.Outcome.decode(wire);
            return .{ .outcome = .{ .phase = value.phase, .resource = value.resource, .exchange = try a.decimal(alloc, value.exchange), .effect = value.effect, .attempt = value.attempt, .status = if (value.phase == .observed) value.status else null, .reference = if (value.phase == .observed) try (try value.reference()).encode() else null } };
        },
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
test "HTTP host conversion preserves unsigned identity and calls shared request validation" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const result = try apply(alloc, .{ .prepare = .{ .resource = 8, .namespace = "18446744073709551615", .request = .{ .method = .POST, .target = &.{.{ .literal = "/write" }} }, .body = "00ff01", .endpoint_revision = "7", .reconcile_before_ms = 9000, .max_attempts = 2 } });
    const ref = try http.RequestRecord.Reference.decode(result.prepared.reference);
    try t.expectEqual(std.math.maxInt(u64), ref.namespace);
    try t.expectEqual(@as(u32, 3), ref.body_bytes);
    try t.expectError(error.InvalidHttpInteger, unsigned("01"));
    try t.expectError(error.InvalidHttpInteger, unsigned("-1"));
    try t.expectError(error.Overflow, unsigned("18446744073709551616"));
    const unknown: http.Service.Outcome = .{ .phase = .closed_unknown, .resource = 7, .exchange = std.math.maxInt(u64), .effect = 19, .attempt = 20, .status = 0, .chain = @splat(0) };
    const decoded = (try apply(alloc, .{ .outcome = try unknown.encode() })).outcome;
    try t.expectEqualStrings("18446744073709551615", decoded.exchange);
    try t.expectEqual(null, decoded.reference);
    try t.expectEqual(null, decoded.status);
}
