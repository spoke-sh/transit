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
pub fn receivedBytes(publication: Pub, source: anytype, id: u64) !u32 {
    try check(publication);
    const record = try publication.inspect(source, id);
    const half = try source.read(halfKey(publication, id));
    if (half) |value| if (record.state != .staging or value.len != part_bytes or record.written >= record.spec.chunks() or record.spec.length - record.written * Pub.chunk_bytes <= part_bytes) return error.InvalidGatewayUpload;
    return @min(record.written * Pub.chunk_bytes, record.spec.length) + @as(u32, if (half != null) part_bytes else 0);
}
pub fn append(publication: Pub, turn: *s.Turn, id: u64, offset: u32, bytes: []const u8) !u32 {
    const before = turn.decision;
    errdefer turn.decision = before;
    try check(publication);
    const record = try publication.inspect(turn, id);
    if (record.spec.length > c.DirectTableIntent.max_bytes) return error.GatewayRecordTooLarge;
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
        try prefetch(publication, source, id, cursor.index, cursor.spec.chunks());
        const part = try publication.read(source, cursor);
        if (part.bytes.len > bytes.len - offset) return error.InvalidGatewayUpload;
        @memcpy(bytes[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (offset != bytes.len or !std.meta.eql(try Pub.Digest.of(cursor.spec.format, bytes), cursor.spec)) return error.InvalidGatewayUpload;
    return bytes;
}

fn prefetch(publication: Pub, source: anytype, id: u64, index: u32, chunks: u32) !void {
    if (comptime @hasDecl(@typeInfo(@TypeOf(source)).pointer.child, "prefetch")) {
        if (index % p.Growth.page_size != 0 or index == chunks) return;
        var keys: [p.Growth.page_size]p.Value = undefined;
        const count = @min(keys.len, chunks - index);
        for (keys[0..count], 0..) |*key, i| key.* = Pub.key(publication.domain, publication.namespace, 'c', id, index + @as(u32, @intCast(i)));
        try source.prefetch(keys[0..count]);
    }
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
        try prefetch(publication, source, id, @intCast(index), record.spec.chunks());
        const chunk = (try source.read(Pub.key(publication.domain, publication.namespace, 'c', id, @intCast(index)))) orelse return error.MissingPublicationChunk;
        if (chunk.len != try record.spec.size(@intCast(index))) return error.InvalidPublicationChunk;
        @memcpy(bytes[offset..][0..chunk.len], chunk.slice());
        offset += chunk.len;
    }
    if (!std.mem.eql(u8, &record.chain, &record.spec.digest) or !std.meta.eql(try Pub.Digest.of(record.spec.format, bytes), record.spec)) return error.InvalidPublicationDigest;
    return bytes;
}
