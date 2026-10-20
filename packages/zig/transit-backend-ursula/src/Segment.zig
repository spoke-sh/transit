//! Bounded private immutable frames and unreused physical segment identities.
//! No I/O or publication authority lives in this buffer. Its complete encoded
//! size is known before the backend reserves quota or creates provider storage.
const std = @import("std");
const Self = @This();
const max_frame_bytes = 4 + @import("transit_core").protocol.Blocks.max_block_bytes;
pub const max_frames = 1024;
pub const max_bytes = @import("transit_core").protocol.Storage.max_candidate_bytes;
pub const Location = [32]u8;
pub const Identity = struct {
    epoch: u64,
    nonce: [16]u8,
    pub fn validate(self: Identity) !void {
        if (self.epoch == 0 or self.epoch > @import("transit_core").protocol.max_counter or std.mem.allEqual(u8, &self.nonce, 0)) return error.InvalidStorageSegment;
    }
    pub fn locate(self: Identity, ordinal: u64) !Location {
        try self.validate();
        if (ordinal >= max_frames) return error.InvalidStorageLocation;
        var result: Location = undefined;
        std.mem.writeInt(u64, result[0..8], self.epoch, .big);
        result[8..24].* = self.nonce;
        std.mem.writeInt(u64, result[24..32], ordinal, .big);
        return result;
    }
    pub fn name(self: Identity, bucket: []const u8, journal: []const u8) ![45]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.immutable.segment.v1\x00");
        hash.update(bucket);
        hash.update("\x00");
        hash.update(journal);
        hash.update("\x00");
        const location = try self.locate(0);
        hash.update(location[0..24]);
        var result: [45]u8 = undefined;
        result[0..2].* = "s-".*;
        _ = std.base64.url_safe_no_pad.Encoder.encode(result[2..], &hash.finalResult());
        return result;
    }
};
pub const Address = struct {
    identity: Identity,
    ordinal: u64,
    pub fn decode(location: Location) !Address {
        const result: Address = .{ .identity = .{ .epoch = std.mem.readInt(u64, location[0..8], .big), .nonce = location[8..24].* }, .ordinal = std.mem.readInt(u64, location[24..32], .big) };
        _ = try result.identity.locate(result.ordinal);
        return result;
    }
};
const Frame = struct { offset: u32, bytes: u32 };
allocator: std.mem.Allocator,
identity: Identity,
body: []u8,
frames: [max_frames]Frame = undefined,
count: u16 = 0,
used: u32 = 0,

pub fn init(allocator: std.mem.Allocator, identity: Identity, bytes: u32) !Self {
    try identity.validate();
    if (bytes == 0 or bytes > max_bytes) return error.InvalidStorageBudget;
    return .{ .allocator = allocator, .identity = identity, .body = try allocator.alloc(u8, bytes) };
}
pub fn deinit(self: *Self) void {
    self.allocator.free(self.body);
    self.* = undefined;
}
/// Frames are canonical base64 JSON strings produced by the page/block codecs.
/// Reject delimiters here so one private frame can never create extra records.
pub fn append(self: *Self, record: []const u8) !Location {
    if (record.len < 2 or record[0] != '"' or record[record.len - 1] != '"') return error.InvalidStorageFrame;
    const encoded = record[1 .. record.len - 1];
    const size = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.InvalidStorageFrame;
    if (size == 0 or size > max_frame_bytes or encoded.len != std.base64.standard.Encoder.calcSize(size)) return error.InvalidStorageFrame;
    var decoded: [max_frame_bytes]u8 = undefined;
    std.base64.standard.Decoder.decode(decoded[0..size], encoded) catch return error.InvalidStorageFrame;
    var canonical: [std.base64.standard.Encoder.calcSize(max_frame_bytes)]u8 = undefined;
    if (!std.mem.eql(u8, encoded, std.base64.standard.Encoder.encode(&canonical, decoded[0..size]))) return error.InvalidStorageFrame;
    if (self.count == self.frames.len or record.len + 1 > self.body.len - self.used) return error.StorageCandidateBudget;
    const location = try self.identity.locate(self.count);
    @memcpy(self.body[self.used..][0..record.len], record);
    self.body[self.used + record.len] = '\n';
    self.frames[self.count] = .{ .offset = self.used, .bytes = @intCast(record.len) };
    self.used += @intCast(record.len + 1);
    self.count += 1;
    return location;
}
pub fn frame(self: *const Self, ordinal: u64) ![]const u8 {
    if (ordinal >= self.count) return error.InvalidStorageLocation;
    const part = self.frames[@intCast(ordinal)];
    return self.body[part.offset..][0..part.bytes];
}
pub fn residentBytes(self: *const Self) usize {
    return @sizeOf(Self) + self.body.len;
}

test "segment identities are scoped, framed, bounded and private" {
    const t = std.testing;
    const id: Identity = .{ .epoch = 7, .nonce = @splat(23) };
    try t.expect(!std.mem.eql(u8, &try id.name("a", "authority"), &try id.name("b", "authority")));
    try t.expect(!std.mem.eql(u8, &try id.name("a", "authority"), &try id.name("a", "other")));
    const address = try Address.decode(try id.locate(max_frames - 1));
    try t.expectEqualDeep(id, address.identity);
    try t.expectEqual(max_frames - 1, address.ordinal);
    try t.expectError(error.InvalidStorageLocation, id.locate(max_frames));
    try t.expectError(error.InvalidStorageSegment, Address.decode(@splat(0)));
    var buffer = try init(t.allocator, id, 14);
    defer buffer.deinit();
    var original = "\"YWJj\"".*;
    const first = try buffer.append(&original);
    original[1] = 'e';
    try t.expectEqualStrings("\"YWJj\"", try buffer.frame((try Address.decode(first)).ordinal));
    _ = try buffer.append("\"eHl6\"");
    try t.expectEqual(@as(u32, 14), buffer.used);
    try t.expectError(error.StorageCandidateBudget, buffer.append("\"eHl6\""));
    try t.expectEqual(@as(u16, 2), buffer.count);
    try t.expectError(error.InvalidStorageFrame, buffer.append("\"YQ==\"\n\"YQ==\""));
    try t.expectError(error.InvalidStorageFrame, buffer.append("\"YR==\""));
    try t.expectEqual(@sizeOf(Self) + 14, buffer.residentBytes());
}
