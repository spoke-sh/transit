//! Immutable logical records over native bulk blocks. One-block records stage
//! atomically. Larger records retain Publication's quota, identity and closure
//! state machine, with complete 64 KiB blocks instead of 256-byte KV writes.
const std = @import("std");
const p = @import("transit_client").protocol;
const Pub = @import("Publication.zig");
const Turn = @import("Turn.zig");
const Self = @This();
publication: Pub,
const header_bytes = 44;
pub const block_bytes = (p.Blocks.max_block_bytes - header_bytes) / Pub.chunk_bytes * Pub.chunk_bytes;
const units = block_bytes / Pub.chunk_bytes;

fn encode(spec: Pub.Spec, bytes: []const u8, buffer: *[p.Blocks.max_block_bytes]u8) ![]const u8 {
    if (bytes.len > block_bytes) return error.InvalidPublicationChunk;
    buffer[0..4].* = "SBR1".*;
    std.mem.writeInt(u32, buffer[4..8], spec.format, .little);
    std.mem.writeInt(u32, buffer[8..12], spec.length, .little);
    buffer[12..44].* = spec.digest;
    @memcpy(buffer[header_bytes..][0..bytes.len], bytes);
    return buffer[0 .. header_bytes + bytes.len];
}
pub fn specification(bytes: []const u8) !Pub.Spec {
    if (bytes.len < header_bytes or bytes.len > header_bytes + block_bytes or !std.mem.eql(u8, bytes[0..4], "SBR1")) return error.InvalidPublicationChunk;
    const spec: Pub.Spec = .{ .format = std.mem.readInt(u32, bytes[4..8], .little), .length = std.mem.readInt(u32, bytes[8..12], .little), .digest = bytes[12..44].* };
    try spec.validate();
    return spec;
}
pub fn encodedSize(length: usize) usize {
    return length + header_bytes * @max(1, std.math.divCeil(usize, length, block_bytes) catch unreachable);
}

pub fn key(self: Self, id: u64, index: u32) p.Value {
    return Pub.key(self.publication.domain, self.publication.namespace, 'c', id, index);
}
fn descriptorKey(self: Self, id: u64) p.Value {
    return Pub.key(self.publication.domain, self.publication.namespace, 'r', id, 0);
}
fn check(self: Self, source: anytype, id: u64) !Pub.Budget {
    if (id == 0) return error.InvalidPublicationIdentity;
    return self.publication.budget(source);
}
pub fn stage(self: Self, turn: *Turn, id: u64, spec: Pub.Spec, bytes: []const u8) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const budget = try self.check(turn, id);
    if (spec.length > budget.limits.record_bytes) return error.PublicationTooLarge;
    if (!std.meta.eql(try Pub.Digest.of(spec.format, bytes), spec)) return error.InvalidPublicationDigest;
    if (bytes.len <= block_bytes) {
        var buffer: [p.Blocks.max_block_bytes]u8 = undefined;
        if (try turn.readBlock(self.key(id, 0), &buffer)) |found| {
            if (!std.meta.eql(try specification(found), spec) or !std.mem.eql(u8, found[header_bytes..], bytes)) return error.PublicationIdentityConflict;
        } else try turn.writeBlock(self.key(id, 0), try encode(spec, bytes, &buffer));
        return true;
    }
    _ = try self.publication.begin(turn, id, spec);
    var record = try self.publication.inspect(turn, id);
    if (record.state == .published) return true;
    var progressed = false;
    while (record.written < spec.chunks()) {
        if (record.written % units != 0) return error.InvalidPublicationDescriptor;
        const offset = @as(usize, record.written) * Pub.chunk_bytes;
        const part = bytes[offset..][0..@min(block_bytes, bytes.len - offset)];
        var buffer: [p.Blocks.max_block_bytes]u8 = undefined;
        if (try turn.readBlock(self.key(id, record.written / units), &buffer) != null) return error.InvalidPublicationDescriptor;
        turn.writeBlock(self.key(id, record.written / units), try encode(spec, part, &buffer)) catch |err| {
            if (err != error.MutationBudgetExceeded or !progressed) return err;
            return false;
        };
        const end = @min(record.written + units, spec.chunks());
        while (record.written < end) : (record.written += 1) {
            const start = @as(usize, record.written) * Pub.chunk_bytes;
            record.chain = try Pub.Digest.next(record.chain, record.written, bytes[start..][0..try spec.size(record.written)]);
        }
        try turn.write(self.descriptorKey(id), try record.encode());
        progressed = true;
    }
    _ = self.publication.publish(turn, id) catch |err| {
        if (err != error.MutationBudgetExceeded or !progressed) return err;
        return false;
    };
    return true;
}
pub fn read(self: Self, source: anytype, id: u64, spec: Pub.Spec, output: []u8) ![]const u8 {
    const budget = try self.check(source, id);
    if (spec.length > budget.limits.record_bytes or spec.length > output.len) return error.PublicationTooLarge;
    if (spec.length > block_bytes) {
        const record = try self.publication.inspect(source, id);
        if (record.state != .published) return error.PublicationNotPublished;
        if (!std.meta.eql(record.spec, spec)) return error.InvalidPublicationDescriptor;
    }
    var offset: usize = 0;
    var index: u32 = 0;
    while (offset < spec.length or index == 0) : (index += 1) {
        if (spec.length > block_bytes and index % 2 == 0) {
            const remaining = std.math.divCeil(usize, spec.length - offset, block_bytes) catch unreachable;
            var keys: [2]p.Value = undefined;
            const count = @min(remaining, keys.len);
            for (keys[0..count], 0..) |*address, i| address.* = self.key(id, index + @as(u32, @intCast(i)));
            if (comptime @hasDecl(@typeInfo(@TypeOf(source)).pointer.child, "prefetchBlocks")) try source.prefetchBlocks(keys[0..count]);
        }
        const size = @min(block_bytes, spec.length - offset);
        var buffer: [p.Blocks.max_block_bytes]u8 = undefined;
        const bytes = (try source.readBlock(self.key(id, index), &buffer)) orelse return error.MissingPublicationChunk;
        if (!std.meta.eql(try specification(bytes), spec) or bytes.len != header_bytes + size) return error.InvalidPublicationChunk;
        @memcpy(output[offset..][0..size], bytes[header_bytes..]);
        offset += size;
    }
    const bytes = output[0..offset];
    if (!std.meta.eql(try Pub.Digest.of(spec.format, bytes), spec)) return error.InvalidPublicationDigest;
    return bytes;
}
/// Only the owner of a closed, unpublished reservation may call this. Current
/// block edges disappear; protected older native roots continue owning bytes.
pub fn collect(self: Self, turn: *Turn, id: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    _ = try self.check(turn, id);
    var record = self.publication.inspect(turn, id) catch |err| {
        if (err != error.PublicationNotFound) return err;
        try turn.writeBlock(self.key(id, 0), null);
        return true;
    };
    if (record.spec.length <= block_bytes) return error.InvalidPublicationDescriptor;
    switch (record.state) {
        .staging => record.state = .abandoned,
        .published => record.state = .retired,
        .abandoned, .retired => {},
    }
    var removed: usize = 0;
    while (record.collected < record.written and removed < 2) : (removed += 1) {
        if (record.collected % units != 0) return error.InvalidPublicationDescriptor;
        try turn.writeBlock(self.key(id, record.collected / units), null);
        record.collected = @min(record.collected + units, record.written);
    }
    if (record.collected == record.written and record.reserved) {
        var quota = try self.publication.budget(turn);
        if (quota.records == 0 or quota.bytes < record.spec.length) return error.InvalidPublicationBudget;
        quota.records -= 1;
        quota.bytes -= record.spec.length;
        record.reserved = false;
        try turn.write(Pub.key(self.publication.domain, self.publication.namespace, 'b', 0, 0), try quota.encode());
    }
    try turn.write(self.descriptorKey(id), try record.encode());
    return record.collected == record.written;
}
