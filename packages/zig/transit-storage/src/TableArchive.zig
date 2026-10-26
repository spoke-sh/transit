//! Immutable copies of complete accepted TWAL frames. Only a Table acceptance
//! record publishes Coverage; orphan objects never establish recovery authority.
const std = @import("std");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const TreeStore = @import("TreeStore.zig");
const pages = TreeStore.pages;
pub const max_frame_bytes = Log.header_bytes + Log.max_payload_bytes;
pub const max_frames = pages.mutation_batch;

pub const Coverage = struct {
    through: u64,
    directory: ?pages.Reference,

    pub const empty: Coverage = .{ .through = 0, .directory = null };

    pub fn validate(self: Coverage, next_lsn: u64) !void {
        if ((self.through == 0) != (self.directory == null) or
            (self.through != 0 and self.through >= next_lsn)) return error.InvalidTableArchive;
    }
};

pub const Limits = struct {
    frames: u8 = max_frames,
    encoded_bytes: usize = max_frame_bytes,

    pub fn validate(self: Limits) !void {
        if (self.frames == 0 or self.frames > max_frames or self.encoded_bytes < max_frame_bytes or
            self.encoded_bytes > max_frame_bytes * max_frames) return error.InvalidTableArchiveBudget;
    }
};

fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

pub fn key(lsn: u64) !pages.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, lsn, .big);
    return pages.Key.init(&bytes);
}

pub fn objectKey(digest: [32]u8, output: *[96]u8) ![]const u8 {
    return std.fmt.bufPrint(output, "table-history/{x}.twal", .{&digest});
}

/// The caller bounds resident input and output separately. One frame is encoded
/// and staged at a time; no retained-history-sized array is built.
pub fn stage(allocator: std.mem.Allocator, objects: Objects.ObjectStore, frame: Log.Frame) !pages.Value {
    if (frame.payload.len > Log.max_payload_bytes or frame.header.payload_len != frame.payload.len or frame.header.partition_id == 0) return error.InvalidTableArchive;
    const bytes = try allocator.alloc(u8, Log.alignedFrameSize(frame.payload.len));
    defer allocator.free(bytes);
    const h = frame.header;
    const encoded = try Log.encodeFrame(h.partition_id, h.writer_epoch, h.policy_epoch, h.lsn, h.timestamp_ms, h.kind, frame.payload, bytes);
    const digest = hash(encoded);
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try objectKey(digest, &name), encoded, digest);
    if (accepted.size != encoded.len or !std.mem.eql(u8, &accepted.sha256, &digest)) return error.InvalidTableArchive;
    var value: [36]u8 = undefined;
    std.mem.writeInt(u32, value[0..4], @intCast(encoded.len), .little);
    value[4..36].* = digest;
    return pages.Value.init(&value);
}

/// Reads use the latest accepted physical directory, even for an older retained
/// logical root. Missing archive bytes never fall back to a different history.
pub fn read(allocator: std.mem.Allocator, index: *TreeStore, coverage: Coverage, partition: u64, lsn: u64) !Log.Log.OwnedBatch {
    if (lsn >= coverage.through) return error.InvalidTableArchive;
    const tree: pages.Tree(TreeStore) = .{ .store = index };
    const value = try tree.get(coverage.directory, try key(lsn)) orelse return error.TableHistoryMissing;
    if (value.len != 36) return error.InvalidTableArchive;
    const size = std.mem.readInt(u32, value.data[0..4], .little);
    const digest = value.data[4..36].*;
    if (size < Log.header_bytes or size > max_frame_bytes or size % Log.frame_alignment != 0) return error.InvalidTableArchive;
    var name: [96]u8 = undefined;
    const object_key = try objectKey(digest, &name);
    const metadata = try index.store.head(object_key) orelse return error.TableHistoryMissing;
    if (metadata.size != size or !std.mem.eql(u8, &metadata.sha256, &digest)) return error.InvalidTableArchive;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const bytes = try arena.allocator().alloc(u8, size);
    const encoded = try index.store.getRange(object_key, 0, size, bytes);
    if (encoded.len != size or !std.mem.eql(u8, &hash(encoded), &digest)) return error.InvalidTableArchive;
    // A provider may return borrowed storage. The returned frame owns its bytes.
    if (encoded.ptr != bytes.ptr) @memcpy(bytes, encoded);
    const decoded = try Log.decodeFrame(bytes);
    if (decoded.consumed_bytes != size or decoded.frame.header.partition_id != partition or
        decoded.frame.header.lsn != lsn) return error.InvalidTableArchive;
    const frames = try arena.allocator().alloc(Log.Frame, 1);
    frames[0] = decoded.frame;
    return .{ .arena = arena, .frames = frames };
}
