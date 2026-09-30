//! Immutable payload storage after an authenticated native intent.
const std = @import("std");
const core = @import("transit_core");
const g = core.protocol.Growth;
const adapter = @import("root.zig");
const observations = @import("transit_observability");
const Store = @This();
journal: *adapter.Journal,
fn payloadStream(self: *Store, id: u64, buffer: *[45]u8) adapter.ursula.Stream {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.payload.v1\x00");
    hash.update(self.journal.stream.bucket);
    hash.update("\x00");
    hash.update(self.journal.stream.name);
    hash.update("\x00");
    const bytes = std.mem.toBytes(std.mem.nativeToBig(u64, id));
    hash.update(&bytes);
    const sum = hash.finalResult();
    buffer[0..2].* = "p-".*;
    _ = std.base64.url_safe_no_pad.Encoder.encode(buffer[2..], &sum);
    return .{ .bucket = self.journal.stream.bucket, .name = buffer };
}

/// Only the trusted publisher which freshly committed the declaration may
/// call this once. Lost receipts/restart use verifyPayload, never repeat PUT.
/// The immutable body and closed flag are installed in a single storage call.
pub fn createPayloadOnce(self: *Store, value: g.Payload, body: []const u8) !void {
    var observation = observations.begin(self.journal.observer, .storage_operation, "createPayloadOnce", self.journal.parent_context);
    defer observation.finish();
    const parent = self.journal.parent_context;
    self.journal.parent_context = observation.span.context;
    defer self.journal.parent_context = parent;
    return self.createPayloadOnceImpl(value, body) catch |err| {
        observation.fail(err);
        return err;
    };
}

fn createPayloadOnceImpl(self: *Store, value: g.Payload, body: []const u8) !void {
    if (value.phase != .creating) return error.PayloadPhase;
    try validatePayload(value, body);
    var name: [45]u8 = undefined;
    var response = try self.journal.client.send(.{ .create_stream = .{
        .stream = self.payloadStream(value.id, &name),
        .options = .{ .body = body, .closed = true },
    } });
    defer response.deinit();
    try response.head.requireSuccess();
    try self.verifyPayload(value);
}

fn validatePayload(value: g.Payload, body: []const u8) !void {
    if (value.bytes == 0 or value.bytes > core.protocol.max_payload_bytes or body.len != value.bytes) return error.InvalidPayload;
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(body, &hash, .{});
    if (!std.mem.eql(u8, &value.sha256, &hash)) return error.PayloadIntegrity;
}

/// Read-only recovery of an uncertain single creation attempt. A missing stream
/// stays uncertain; it is never recreated, published as empty, or called deleted.
pub fn verifyPayload(self: *Store, value: g.Payload) !void {
    var observation = observations.begin(self.journal.observer, .storage_operation, "verifyPayload", self.journal.parent_context);
    defer observation.finish();
    const parent = self.journal.parent_context;
    self.journal.parent_context = observation.span.context;
    defer self.journal.parent_context = parent;
    return self.verifyPayloadImpl(value) catch |err| {
        observation.fail(err);
        return err;
    };
}

fn verifyPayloadImpl(self: *Store, value: g.Payload) !void {
    if (value.phase != .creating and value.phase != .ready) return error.PayloadUnavailable;
    var name: [45]u8 = undefined;
    const stream = self.payloadStream(value.id, &name);
    var head = try self.journal.client.send(.{ .head = .{ .stream = stream } });
    defer head.deinit();
    try head.head.requireSuccess();
    if (!((try head.head.metadata()).closed orelse false)) return error.PayloadNotClosed;
    var body = try self.journal.client.send(.{ .read = .{ .stream = stream, .options = .{ .max_bytes = core.protocol.max_payload_bytes + 1 } } });
    defer body.deinit();
    try body.head.requireSuccess();
    if (!((try body.head.metadata()).up_to_date orelse false)) return error.PayloadIntegrity;
    try validatePayload(value, body.body);
}

/// The caller must obtain this retirement intent from current authenticated
/// history. Its tombstone remains in the separate authority journal/checkpoint.
/// Missing is success only for this already-authorized deletion, not for reads.
pub fn reclaimPayload(self: *Store, value: g.Payload) !void {
    var observation = observations.begin(self.journal.observer, .storage_operation, "reclaimPayload", self.journal.parent_context);
    defer observation.finish();
    const parent = self.journal.parent_context;
    self.journal.parent_context = observation.span.context;
    defer self.journal.parent_context = parent;
    return self.reclaimPayloadImpl(value) catch |err| {
        observation.fail(err);
        return err;
    };
}

fn reclaimPayloadImpl(self: *Store, value: g.Payload) !void {
    if (value.phase != .retiring or !value.allow_delete or value.retired_at == null) return error.PayloadPhase;
    var name: [45]u8 = undefined;
    const stream = self.payloadStream(value.id, &name);
    var head = try self.journal.client.send(.{ .head = .{ .stream = stream } });
    defer head.deinit();
    if (head.head.status == .not_found) return;
    try head.head.requireSuccess();
    if (!((try head.head.metadata()).closed orelse false)) return error.PayloadNotClosed;
    var response = try self.journal.client.send(.{ .delete_stream = stream });
    defer response.deinit();
    if (response.head.status != .not_found) try response.head.requireSuccess();
    var verify = try self.journal.client.send(.{ .head = .{ .stream = stream } });
    defer verify.deinit();
    if (verify.head.status != .not_found) return error.DeletionUnconfirmed;
}
