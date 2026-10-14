//! Finite gateway records over paged Station publication. Each 128-byte ingress
//! part fits a native message. Incomplete records never become dispatch evidence.
const std = @import("std");
const c = @import("root.zig").catalog;
const s = @import("root.zig").station;
const p = c.protocol;
const Pub = s.Publication;
pub const part_bytes = 128;
fn halfKey(publication: Pub, id: u64) p.Value {
    return Pub.key(publication.domain, publication.namespace, 'h', id, 0);
}
fn check(publication: Pub) !void {
    if (publication.domain != .sql_gateway) return error.InvalidGatewayPublication;
}
pub fn append(publication: Pub, turn: *s.Turn, id: u64, offset: u32, bytes: []const u8) !u32 {
    const before = turn.decision;
    errdefer turn.decision = before;
    try check(publication);
    const record = try publication.inspect(turn, id);
    if (record.spec.length > c.TableIntent.max_bytes) return error.GatewayRecordTooLarge;
    if (record.state != .staging) return error.GatewayUploadClosed;
    if (offset >= record.spec.length or offset % part_bytes != 0 or bytes.len != @min(part_bytes, record.spec.length - offset)) return error.InvalidGatewayPart;
    const half_key = halfKey(publication, id);
    const half = try turn.read(half_key);
    if (half) |value| if (value.len != part_bytes or record.written >= record.spec.chunks()) return error.InvalidGatewayUpload;
    const received = @min(record.written * Pub.chunk_bytes, record.spec.length) + @as(u32, if (half != null) part_bytes else 0);
    const index = offset / Pub.chunk_bytes;
    if (offset < received) {
        const stored = if (index < record.written) (try turn.read(Pub.key(publication.domain, publication.namespace, 'c', id, index))) orelse return error.InvalidGatewayUpload else half orelse return error.InvalidGatewayUpload;
        const start: usize = if (index < record.written) offset % Pub.chunk_bytes else 0;
        if (start > stored.len or bytes.len > stored.len - start or !std.mem.eql(u8, bytes, stored.slice()[start..][0..bytes.len])) return error.GatewayUploadConflict;
        return received;
    }
    if (offset != received or index != record.written) return error.GatewayUploadGap;
    const size = try record.spec.size(index);
    if (offset % Pub.chunk_bytes == 0) {
        if (half != null) return error.InvalidGatewayUpload;
        if (size <= part_bytes) _ = try publication.append(turn, id, index, bytes) else try turn.write(half_key, try p.Value.init(bytes));
    } else {
        const first = half orelse return error.InvalidGatewayUpload;
        if (first.len + bytes.len != size) return error.InvalidGatewayPart;
        var chunk: [Pub.chunk_bytes]u8 = undefined;
        @memcpy(chunk[0..part_bytes], first.slice());
        @memcpy(chunk[part_bytes..][0..bytes.len], bytes);
        _ = try publication.append(turn, id, index, chunk[0..size]);
        try turn.write(half_key, null);
    }
    return received + @as(u32, @intCast(bytes.len));
}
pub fn seal(publication: Pub, turn: *s.Turn, id: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try check(publication);
    if (try turn.read(halfKey(publication, id)) != null) return error.IncompletePublication;
    _ = try publication.publish(turn, id);
}
/// Read one bounded finite record, never the inventory. Source must be a
/// committed public read view. Allocation is returned to the caller.
pub fn read(allocator: std.mem.Allocator, publication: Pub, source: anytype, id: u64, maximum: usize) ![]u8 {
    try check(publication);
    var cursor = try publication.open(source, id);
    if (cursor.spec.length > maximum) return error.GatewayRecordTooLarge;
    const bytes = try allocator.alloc(u8, cursor.spec.length);
    errdefer allocator.free(bytes);
    var offset: usize = 0;
    while (true) {
        const part = try publication.read(source, cursor);
        if (part.bytes.len > bytes.len - offset) return error.InvalidGatewayUpload;
        @memcpy(bytes[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (offset != bytes.len or !std.meta.eql(try Pub.Digest.of(cursor.spec.format, bytes), cursor.spec)) return error.InvalidGatewayUpload;
    return bytes;
}

/// Equality against an already validated immutable publication at one committed
/// cut. This is a bounded range read, not a replacement full-chain validator.
/// The ledger creates its binding only after read() verifies the entire intent.
pub fn Matcher(comptime Source: type) type {
    return struct {
        source: Source,
        publication: Pub,
        spec: Pub.Spec,
        body_offset: u32,
        body_length: u32,
        pub fn matchBytes(self: @This(), offset: u32, bytes: []const u8) !bool {
            if (bytes.len > s.Frame.max_payload or offset > self.body_length or bytes.len > self.body_length - offset) return false;
            const record = try self.publication.inspect(self.source, 1);
            if (record.state != .published or !std.meta.eql(record.spec, self.spec) or @as(u64, self.body_offset) + self.body_length != self.spec.length) return error.InvalidGatewayIntent;
            var absolute: usize = @as(usize, self.body_offset) + offset;
            var compared: usize = 0;
            while (compared < bytes.len) {
                const index: u32 = @intCast(absolute / Pub.chunk_bytes);
                const chunk = (try self.source.read(Pub.key(self.publication.domain, self.publication.namespace, 'c', 1, index))) orelse return error.MissingPublicationChunk;
                if (chunk.len != try self.spec.size(index)) return error.InvalidPublicationChunk;
                const begin = absolute % Pub.chunk_bytes;
                const count = @min(bytes.len - compared, chunk.len - begin);
                if (!std.mem.eql(u8, bytes[compared..][0..count], chunk.slice()[begin..][0..count])) return false;
                absolute += count;
                compared += count;
            }
            return true;
        }
    };
}

/// Validate a fully staged finite record before its atomic publication. Its
/// committed source excludes private appends; the caller still owns the seal.
pub fn readStaged(allocator: std.mem.Allocator, publication: Pub, source: anytype, id: u64, maximum: usize) ![]u8 {
    try check(publication);
    const record = try publication.inspect(source, id);
    if (record.state != .staging or record.written != record.spec.chunks() or try source.read(halfKey(publication, id)) != null) return error.IncompletePublication;
    if (record.spec.length > maximum) return error.GatewayRecordTooLarge;
    const bytes = try allocator.alloc(u8, record.spec.length);
    errdefer allocator.free(bytes);
    var offset: usize = 0;
    for (0..record.spec.chunks()) |index| {
        const chunk = (try source.read(Pub.key(publication.domain, publication.namespace, 'c', id, @intCast(index)))) orelse return error.MissingPublicationChunk;
        if (chunk.len != try record.spec.size(@intCast(index))) return error.InvalidPublicationChunk;
        @memcpy(bytes[offset..][0..chunk.len], chunk.slice());
        offset += chunk.len;
    }
    if (!std.mem.eql(u8, &record.chain, &record.spec.digest) or !std.meta.eql(try Pub.Digest.of(record.spec.format, bytes), record.spec)) return error.InvalidPublicationDigest;
    return bytes;
}

/// Discard only an explicitly abandoned, never-published bounded step attempt.
/// Its permanent descriptor/identity remains; accepted intents are excluded.
pub fn collectAbandonedStep(publication: Pub, turn: *s.Turn, id: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try check(publication);
    const record = try publication.inspect(turn, id);
    if (id <= 1 or record.state != .abandoned or record.spec.format != @import("SavedStep.zig").format or record.spec.length > @import("SavedStep.zig").max_bytes) return error.InvalidGatewayCleanup;
    const half = halfKey(publication, id);
    const retained_half = try turn.read(half);
    if (retained_half) |value| if (value.len != part_bytes or record.written > 1) return error.InvalidGatewayUpload;
    if (!try publication.collect(turn, id)) return error.InvalidGatewayCleanup;
    if (retained_half != null) try turn.write(half, null);
}
