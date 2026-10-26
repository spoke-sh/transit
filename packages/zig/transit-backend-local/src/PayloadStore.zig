//! Physical standalone payload operations under an accepted native declaration.
//! Recovery verifies the original attempt; it never recreates uncertain bytes.
const std = @import("std");
const core = @import("transit_core");
const g = core.protocol.Growth;
const Backend = @import("Backend.zig");
const Files = @import("LocalFiles.zig");
const Self = @This();
pub const Engine = core.growing.Engine(@import("Store.zig"), @import("PageStore.zig"));
const marker_bytes = 136;
engine: *Engine,
observe: @import("Diagnostics.zig") = .{},

fn backend(self: *Self) *Backend {
    return self.engine.journal.backend;
}
fn acquire(self: *Self, expected: g.Payload) !void {
    const owner = self.backend();
    if (self.engine.page_store.backend != owner) return error.InvalidPayloadOwner;
    try owner.authority.lockShared(owner.io);
    errdefer owner.authority.unlockShared(owner.io);
    try self.engine.refresh();
    var state = try self.engine.state();
    const current = (try state.get(g.Payload, core.growing.address(.payload, expected.id))) orelse return error.UnknownPayload;
    if (!std.meta.eql(current, expected)) return error.PayloadIdentityMismatch;
}
fn release(self: *Self) void {
    self.backend().authority.unlockShared(self.backend().io);
}
fn key(value: g.Payload, output: *[64]u8) []const u8 {
    return std.fmt.bufPrint(output, "native/u/{x:0>16}", .{value.id}) catch unreachable;
}
fn markerName(value: g.Payload, output: *[64]u8) []const u8 {
    return std.fmt.bufPrint(output, ".payload-{x:0>16}", .{value.id}) catch unreachable;
}
fn marker(value: g.Payload) ![marker_bytes]u8 {
    if (value.id == 0 or value.pid == 0 or value.bytes == 0 or value.bytes > core.protocol.max_payload_bytes) return error.InvalidPayload;
    var bytes: [marker_bytes]u8 = @splat(0);
    bytes[0..8].* = "TPAY1\x00\x00\x00".*;
    bytes[8..40].* = g.definition_bytes;
    std.mem.writeInt(u64, bytes[40..48], value.id, .little);
    std.mem.writeInt(u64, bytes[48..56], value.pid, .little);
    std.mem.writeInt(u64, bytes[56..64], value.publisher, .little);
    std.mem.writeInt(u32, bytes[64..68], value.bytes, .little);
    bytes[68] = @intFromBool(value.allow_delete);
    bytes[72..104].* = value.sha256;
    std.crypto.hash.sha2.Sha256.hash(bytes[0..104], bytes[104..136], .{});
    return bytes;
}
fn requireMarker(self: *Self, value: g.Payload, confirm: bool) !void {
    var name: [64]u8 = undefined;
    var bytes: [marker_bytes]u8 = undefined;
    const expected = try marker(value);
    const stored = (try Files.read(self.backend().io, self.backend().directory, markerName(value, &name), &bytes)) orelse return error.PayloadUnavailable;
    if (!std.mem.eql(u8, stored, &expected)) return error.PayloadIntegrity;
    if (confirm) {
        const owner = self.backend();
        const file = try owner.directory.openFile(owner.io, markerName(value, &name), .{ .follow_symlinks = false });
        defer file.close(owner.io);
        try file.sync(owner.io);
        try Files.sync(owner.io, owner.directory);
    }
}
fn validate(value: g.Payload, bytes: []const u8) !void {
    if (value.bytes == 0 or value.bytes > core.protocol.max_payload_bytes or bytes.len != value.bytes) return error.InvalidPayload;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &value.sha256)) return error.PayloadIntegrity;
}

/// The trusted publisher calls once for its freshly accepted declaration.
/// After any uncertain result, only verifyPayload may resolve the attempt.
pub fn createPayloadOnce(self: *Self, value: g.Payload, bytes: []const u8) !void {
    return self.observe.run(self.backend().io, "payload.create", create, .{ self, value, bytes });
}
fn create(self: *Self, value: g.Payload, bytes: []const u8) !void {
    if (value.phase != .creating) return error.PayloadPhase;
    try validate(value, bytes);
    const intent = try marker(value);
    try self.acquire(value);
    defer self.release();
    const owner = self.backend();
    try owner.mutex.lock(owner.io);
    defer owner.mutex.unlock(owner.io);
    var name: [64]u8 = undefined;
    var existing: [marker_bytes]u8 = undefined;
    if (try Files.read(owner.io, owner.directory, markerName(value, &name), &existing)) |stored| {
        if (!std.mem.eql(u8, stored, &intent)) return error.PayloadIntegrity;
        return error.PayloadCreationAttempted;
    }
    const chunks = std.math.divCeil(usize, bytes.len, 64 * 1024) catch unreachable;
    try owner.reserve(marker_bytes + bytes.len + chunks * 32 + 1024, false);
    try Files.save(owner.io, owner.directory, markerName(value, &name), &intent, false);
    self.observe.metrics.request_payload_bytes +|= bytes.len;
    _ = try owner.objects.objectStore().putImmutable(key(value, &name), bytes, value.sha256);
}

/// Verify the original bytes and establish their durability, without a new PUT.
/// Missing content is uncertainty/unavailability, never empty content or deletion.
pub fn verifyPayload(self: *Self, value: g.Payload) !void {
    return self.observe.run(self.backend().io, "payload.verify", verify, .{ self, value });
}
fn verify(self: *Self, value: g.Payload) !void {
    if (value.phase != .creating and value.phase != .ready) return error.PayloadUnavailable;
    try self.acquire(value);
    defer self.release();
    try self.requireMarker(value, true);
    var name: [64]u8 = undefined;
    var bytes: [core.protocol.max_payload_bytes]u8 = undefined;
    const body = self.backend().read(key(value, &name), &bytes) catch |err| switch (err) {
        error.MissingStorageObject => return error.PayloadUnavailable,
        else => return err,
    };
    try validate(value, body);
    self.observe.metrics.response_bytes +|= body.len;
    const owner = self.backend();
    try owner.mutex.lock(owner.io);
    defer owner.mutex.unlock(owner.io);
    try owner.objects.confirmImmutableObject(key(value, &name), .{ .size = value.bytes, .sha256 = value.sha256 });
}

/// Physical retirement requires the current accepted native intent. The attempt
/// marker remains permanently; payload_deleted is a separate native publication.
pub fn reclaimPayload(self: *Self, value: g.Payload) !void {
    return self.observe.run(self.backend().io, "payload.delete", reclaim, .{ self, value });
}
fn reclaim(self: *Self, value: g.Payload) !void {
    if (value.phase != .retiring or !value.allow_delete or value.retired_at == null) return error.PayloadPhase;
    try self.acquire(value);
    defer self.release();
    try self.requireMarker(value, false);
    const owner = self.backend();
    try owner.mutex.lock(owner.io);
    defer owner.mutex.unlock(owner.io);
    var name: [64]u8 = undefined;
    const removed = try owner.objects.reclaimImmutableObject(key(value, &name), .{ .size = value.bytes, .sha256 = value.sha256 });
    owner.allocated -= @min(owner.allocated, removed);
}
