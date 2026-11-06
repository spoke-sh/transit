//! Immutable source chunks and a paged inventory. Catalog reservation and
//! publication own their lifetime; these helpers never accept a Document.
const std = @import("std");
const p = @import("transit_protocol");
const Objects = @import("TransitObjectStore.zig");
const TreeStore = @import("TreeStore.zig");
pub const pages = TreeStore.pages;
pub const chunk_bytes = 64 * 1024;
pub const step_bytes = 4 * 1024 * 1024;

pub const Chunk = struct {
    offset: u64,
    content: p.DataLifecycle.Content,

    pub fn validate(self: Chunk, source_bytes: u64) !void {
        try self.content.validate();
        if (self.offset % chunk_bytes != 0 or self.offset >= source_bytes or
            self.content.bytes != @min(chunk_bytes, source_bytes - self.offset))
            return error.InvalidDocumentSourceChunk;
    }
    pub fn indexKey(self: Chunk) !pages.Key {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, self.offset, .big);
        return pages.Key.init(&bytes);
    }
    pub fn value(self: Chunk) !pages.Value {
        var bytes: [40]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.content.bytes, .little);
        bytes[8..40].* = self.content.sha256;
        return pages.Value.init(&bytes);
    }
    pub fn fromEntry(key_value: pages.Key, value_bytes: pages.Value, source_bytes: u64) !Chunk {
        if (key_value.len != 8 or value_bytes.len != 40) return error.InvalidDocumentSourceChunk;
        const result: Chunk = .{
            .offset = std.mem.readInt(u64, key_value.data[0..8], .big),
            .content = .{ .bytes = std.mem.readInt(u64, value_bytes.data[0..8], .little), .sha256 = value_bytes.data[8..40].* },
        };
        try result.validate(source_bytes);
        return result;
    }
};

pub fn key(owner: [32]u8, chunk: Chunk, output: *[96]u8) ![]const u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.document.source.chunk.v1\x00");
    hash.update(&p.Growth.definition_bytes);
    hash.update(&owner);
    var numbers: [16]u8 = undefined;
    std.mem.writeInt(u64, numbers[0..8], chunk.offset, .big);
    std.mem.writeInt(u64, numbers[8..16], chunk.content.bytes, .big);
    hash.update(&numbers);
    hash.update(&chunk.content.sha256);
    const digest = hash.finalResult();
    return std.fmt.bufPrint(output, "document-sources/{x}.data", .{&digest});
}

pub fn put(objects: Objects.ObjectStore, owner: [32]u8, chunk: Chunk, bytes: []const u8) !void {
    if (bytes.len != chunk.content.bytes or bytes.len > chunk_bytes) return error.InvalidDocumentSourceChunk;
    var path: [96]u8 = undefined;
    const meta = try objects.putImmutable(try key(owner, chunk, &path), bytes, chunk.content.sha256);
    if (meta.size != chunk.content.bytes or !std.mem.eql(u8, &meta.sha256, &chunk.content.sha256)) return error.InvalidDocumentSourceChunk;
}

/// Caller owns output. Even a successful retry reads and verifies accepted
/// bytes; a missing object is never repaired by the read path.
pub fn read(objects: Objects.ObjectStore, owner: [32]u8, chunk: Chunk, output: []u8) ![]const u8 {
    if (chunk.content.bytes > chunk_bytes or output.len < chunk.content.bytes) return error.InvalidDocumentSourceChunk;
    var path: [96]u8 = undefined;
    const meta = try objects.getObject(try key(owner, chunk, &path), output[0..@intCast(chunk.content.bytes)]) orelse return error.DocumentSourceMissing;
    if (meta.size != chunk.content.bytes or !std.mem.eql(u8, &meta.sha256, &chunk.content.sha256)) return error.InvalidDocumentSourceChunk;
    const bytes = output[0..@intCast(meta.size)];
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &chunk.content.sha256)) return error.InvalidDocumentSourceChunk;
    return bytes;
}

pub fn lookup(index: *TreeStore, root: ?pages.Reference, offset: u64, source_bytes: u64) !Chunk {
    const request: Chunk = .{ .offset = offset, .content = undefined };
    var tree: pages.Tree(TreeStore) = .{ .store = index };
    const entry = try tree.get(root, try request.indexKey()) orelse return error.DocumentSourceMissing;
    return Chunk.fromEntry(try request.indexKey(), entry, source_bytes);
}
