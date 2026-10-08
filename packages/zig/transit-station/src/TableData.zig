//! General Table candidate data over immutable, bounded pages. The caller owns
//! current authorization, staging reservations, source cuts and atomic head
//! publication. No result from this module constitutes an accepted mutation.
const std = @import("std");
const f = @import("transit_fuze");
const Index = @import("ImmutableIndex.zig");
const Pub = @import("Publication.zig");
const Row = f.TableRow;
const Cell = f.Types.Values.Cell;
const Self = @This();
pub const row_format: u32 = 0x54525701;
/// A bucket selector, never a commitment or proof of equality. Every matching
/// candidate is decoded and compared by its complete canonical typed key.
pub const key_digest_bytes = 16;
pub const primary_key_bytes = 1 + key_digest_bytes + Row.Identity.encoded_bytes;
schema: f.TableSchema.Schema,
index: Index = .{},

/// Identity/spec within the Table owner's immutable publication namespace.
pub const Blob = struct {
    id: u64,
    spec: Pub.Spec,
    pub fn validate(self: Blob) !void {
        if (self.id == 0 or self.spec.format != row_format or self.spec.length < Row.header_bytes or self.spec.length > Row.max_bytes) return error.InvalidTableBlob;
    }
    pub fn encode(self: Blob) !Index.Value {
        try self.validate();
        var bytes: [48]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.id, .little);
        std.mem.writeInt(u32, bytes[8..12], self.spec.format, .little);
        std.mem.writeInt(u32, bytes[12..16], self.spec.length, .little);
        bytes[16..48].* = self.spec.digest;
        return Index.Value.init(&bytes);
    }
    pub fn decode(value: Index.Value) !Blob {
        try value.validate(true);
        if (value.len != 48) return error.InvalidTableBlob;
        const result: Blob = .{ .id = std.mem.readInt(u64, value.data[0..8], .little), .spec = .{
            .format = std.mem.readInt(u32, value.data[8..12], .little),
            .length = std.mem.readInt(u32, value.data[12..16], .little),
            .digest = value.data[16..48].*,
        } };
        try result.validate();
        return result;
    }
};
pub const Candidate = struct {
    data: Self,
    matched: u64,
    /// Changed means different canonical stored row bytes (including JSON text
    /// and IEEE zero sign), not query equality for unsupported operator types.
    changed: u64,
};
pub fn validate(self: Self) !void {
    try self.schema.validate();
    if (self.index.root) |root| try root.validate();
}
fn rowKey(id: Row.Identity) !Index.Key {
    var bytes: [1 + Row.Identity.encoded_bytes]u8 = undefined;
    bytes[0] = 'R';
    bytes[1..].* = try id.encode();
    return Index.Key.init(&bytes);
}
fn identity(key: Index.Key) !Row.Identity {
    if (key.len != 21 or key.data[0] != 'R') return error.InvalidTableIndex;
    return Row.Identity.decode(key.data[1..21]);
}
fn primaryKey(digest: [32]u8, id: Row.Identity) !Index.Key {
    var bytes: [primary_key_bytes]u8 = undefined;
    bytes[0] = 'K';
    bytes[1..][0..key_digest_bytes].* = digest[0..key_digest_bytes].*;
    bytes[1 + key_digest_bytes ..].* = try id.encode();
    return Index.Key.init(&bytes);
}
fn digestValues(allocator: std.mem.Allocator, schema: f.TableSchema.Schema, values: []const Cell) ![32]u8 {
    // Small values avoid allocating the maximum envelope. Large inputs retain
    // the same encoding and explicit shared row budgets.
    var small: [4096]u8 = undefined;
    var large: ?[]u8 = null;
    defer if (large) |bytes| allocator.free(bytes);
    const encoded = Row.encodeKeyValues(schema, values, &small) catch |err| blk: {
        if (err != error.WriteFailed) return err;
        large = try allocator.alloc(u8, Row.max_key_bytes);
        break :blk try Row.encodeKeyValues(schema, values, large.?);
    };
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    return digest;
}
fn keyValues(self: Self, cells: []const Cell, output: *[f.TableSchema.max_columns]Cell) ![]const Cell {
    for (self.schema.primary_key, 0..) |id, i| output[i] = cells[try self.schema.index(id)];
    return output[0..self.schema.primary_key.len];
}
fn readRow(self: Self, allocator: std.mem.Allocator, source: anytype, id: Row.Identity, blob: Blob) !Row.Owned {
    try blob.validate();
    const buffer = try allocator.alloc(u8, blob.spec.length);
    defer allocator.free(buffer);
    const bytes = try source.loadBlob(blob, buffer);
    if (!std.meta.eql(blob.spec, try Pub.Digest.of(row_format, bytes))) return error.InvalidTableBlob;
    var result = try Row.decode(allocator, self.schema, bytes);
    errdefer result.deinit();
    if (!std.meta.eql(id, result.identity)) return error.InvalidTableIndex;
    return result;
}
pub fn get(self: Self, allocator: std.mem.Allocator, source: anytype, id: Row.Identity) !?Row.Owned {
    try self.validate();
    const value = try self.index.get(source, try rowKey(id)) orelse return null;
    return try self.readRow(allocator, source, id, try Blob.decode(value));
}
pub fn next(self: Self, allocator: std.mem.Allocator, source: anytype, after: ?Row.Identity) !?Row.Owned {
    try self.validate();
    const entry = try self.index.next(source, if (after) |id| try rowKey(id) else try Index.Key.init("R")) orelse return null;
    return try self.readRow(allocator, source, try identity(entry.key), try Blob.decode(entry.value));
}
/// One immutable row reference from this Table's verified index. Holding it
/// grants no source authority or retention; loading still verifies the complete
/// blob commitment, schema and row identity against the supplied source.
pub const RowReference = struct { identity: Row.Identity, blob: Blob };
pub fn loadReference(self: Self, allocator: std.mem.Allocator, source: anytype, ref: RowReference) !Row.Owned {
    return self.readRow(allocator, source, ref.identity, ref.blob);
}
/// Acquire at most eight references/headers together without decoding or owning
/// their row values. Pull executors can consume one row at a time and stop at a
/// selected LIMIT while reusing the bounded source cache.
pub fn references(self: Self, source: anytype, after: ?Row.Identity, output: []RowReference) !usize {
    if (output.len == 0 or output.len > Index.fanout) return error.InvalidTablePageSize;
    try self.validate();
    var blobs: [Index.fanout]Blob = undefined;
    var cursor = if (after) |id| try rowKey(id) else try Index.Key.init("R");
    var count: usize = 0;
    while (count < output.len) : (count += 1) {
        const entry = try self.index.next(source, cursor) orelse break;
        const id = try identity(entry.key);
        const blob = try Blob.decode(entry.value);
        output[count] = .{ .identity = id, .blob = blob };
        blobs[count] = blob;
        cursor = entry.key;
    }
    const Source = @typeInfo(@TypeOf(source)).pointer.child;
    if (comptime @hasDecl(Source, "prefetchBlobs")) if (count != 0) try source.prefetchBlobs(blobs[0..count]);
    return count;
}
/// Gather a bounded page of immutable references before acquiring row bodies.
/// Decoding still validates every commitment, schema and row identity. On error
/// no partially owned output escapes; callers retain their original cursor.
pub fn page(self: Self, allocator: std.mem.Allocator, source: anytype, after: ?Row.Identity, output: []?Row.Owned) !usize {
    if (output.len == 0 or output.len > Index.fanout) return error.InvalidTablePageSize;
    @memset(output, null);
    errdefer for (output) |*slot| {
        if (slot.*) |*row| row.deinit();
        slot.* = null;
    };
    var refs: [Index.fanout]RowReference = undefined;
    const count = try self.references(source, after, refs[0..output.len]);
    for (output[0..count], refs[0..count]) |*slot, ref| slot.* = try self.loadReference(allocator, source, ref);
    return count;
}
/// Collision-safe point lookup. Row identities break equal-digest index ties;
/// complete typed values determine equality. Each candidate is released before
/// continuing, independent of the number of retained rows/collision candidates.
pub fn findKey(self: Self, allocator: std.mem.Allocator, source: anytype, values: []const Cell) !?Row.Identity {
    try self.validate();
    return self.findDigest(allocator, source, values, try digestValues(allocator, self.schema, values), null);
}
fn findDigest(self: Self, allocator: std.mem.Allocator, source: anytype, values: []const Cell, digest: [32]u8, except: ?Row.Identity) !?Row.Identity {
    var prefix: [1 + key_digest_bytes]u8 = undefined;
    prefix[0] = 'K';
    prefix[1..].* = digest[0..key_digest_bytes].*;
    var after = try Index.Key.init(&prefix);
    while (try self.index.next(source, after)) |entry| {
        if (!std.mem.startsWith(u8, entry.key.slice(), &prefix)) break;
        if (entry.key.len != primary_key_bytes or entry.value.len != 0) return error.InvalidTableIndex;
        const id = try Row.Identity.decode(entry.key.data[1 + key_digest_bytes .. primary_key_bytes]);
        after = entry.key;
        if (except) |excluded| if (std.meta.eql(id, excluded)) continue;
        var row = try self.get(allocator, source, id) orelse return error.InvalidTableIndex;
        defer row.deinit();
        var same = true;
        for (self.schema.primary_key, values) |column, value| {
            const i = try self.schema.index(column);
            if (!try f.Types.Operations.eql(self.schema.columns[i].field(), row.row().cells[i], value)) same = false;
        }
        if (same) return id;
    }
    return null;
}
fn storeRow(self: Self, allocator: std.mem.Allocator, store: anytype, row: Row.Row) !Blob {
    var small: [4096]u8 = undefined;
    var large: ?[]u8 = null;
    defer if (large) |bytes| allocator.free(bytes);
    const encoded = row.encode(self.schema, &small) catch |err| blk: {
        if (err != error.WriteFailed) return err;
        large = try allocator.alloc(u8, Row.max_bytes);
        break :blk try row.encode(self.schema, large.?);
    };
    const spec = try Pub.Digest.of(row_format, encoded);
    return .{ .id = try store.saveBlob(spec, encoded), .spec = spec };
}
pub fn insert(self: Self, allocator: std.mem.Allocator, store: anytype, row: Row.Row) !Candidate {
    try self.validate();
    try self.schema.validateRow(row.cells);
    const address = try rowKey(row.identity);
    if (try self.index.get(store, address) != null) return error.RowIdentityExists;
    var key: [f.TableSchema.max_columns]Cell = undefined;
    const digest: ?[32]u8 = if (self.schema.primary_key.len != 0) try digestValues(allocator, self.schema, try self.keyValues(row.cells, &key)) else null;
    if (digest) |hash| if (try self.findDigest(allocator, store, key[0..self.schema.primary_key.len], hash, null) != null) return error.RowExists;
    const blob = try self.storeRow(allocator, store, row);
    var candidate = self;
    candidate.index = try candidate.index.put(store, address, try blob.encode());
    if (digest) |hash| candidate.index = try candidate.index.put(store, try primaryKey(hash, row.identity), try Index.Value.init(""));
    return .{ .data = candidate, .matched = 1, .changed = 1 };
}
pub fn update(self: Self, allocator: std.mem.Allocator, store: anytype, row: Row.Row) !Candidate {
    try self.validate();
    try self.schema.validateRow(row.cells);
    const address = try rowKey(row.identity);
    const old_value = try self.index.get(store, address) orelse return .{ .data = self, .matched = 0, .changed = 0 };
    const old_blob = try Blob.decode(old_value);
    var previous = try self.readRow(allocator, store, row.identity, old_blob);
    defer previous.deinit();
    var old_values: [f.TableSchema.max_columns]Cell = undefined;
    var new_values: [f.TableSchema.max_columns]Cell = undefined;
    const keyed = self.schema.primary_key.len != 0;
    const old_digest: ?[32]u8 = if (keyed) try digestValues(allocator, self.schema, try self.keyValues(previous.row().cells, &old_values)) else null;
    const new_digest: ?[32]u8 = if (keyed) try digestValues(allocator, self.schema, try self.keyValues(row.cells, &new_values)) else null;
    if (new_digest) |hash| if (try self.findDigest(allocator, store, new_values[0..self.schema.primary_key.len], hash, row.identity) != null) return error.RowExists;
    // Construct exact bytes before allocating a new immutable record; same-value
    // updates match but do not stage data or change the candidate root.
    var small: [4096]u8 = undefined;
    var large: ?[]u8 = null;
    defer if (large) |bytes| allocator.free(bytes);
    const encoded = row.encode(self.schema, &small) catch |err| blk: {
        if (err != error.WriteFailed) return err;
        large = try allocator.alloc(u8, Row.max_bytes);
        break :blk try row.encode(self.schema, large.?);
    };
    const spec = try Pub.Digest.of(row_format, encoded);
    if (std.meta.eql(spec, old_blob.spec)) return .{ .data = self, .matched = 1, .changed = 0 };
    const blob: Blob = .{ .id = try store.saveBlob(spec, encoded), .spec = spec };
    var candidate = self;
    candidate.index = try candidate.index.put(store, address, try blob.encode());
    if (old_digest) |hash| if (!std.mem.eql(u8, &hash, &new_digest.?)) {
        candidate.index = try candidate.index.remove(store, try primaryKey(hash, row.identity));
        candidate.index = try candidate.index.put(store, try primaryKey(new_digest.?, row.identity), try Index.Value.init(""));
    };
    return .{ .data = candidate, .matched = 1, .changed = 1 };
}
pub fn delete(self: Self, allocator: std.mem.Allocator, store: anytype, id: Row.Identity) !Candidate {
    var previous = try self.get(allocator, store, id) orelse return .{ .data = self, .matched = 0, .changed = 0 };
    defer previous.deinit();
    var candidate = self;
    candidate.index = try candidate.index.remove(store, try rowKey(id));
    if (self.schema.primary_key.len != 0) {
        var values: [f.TableSchema.max_columns]Cell = undefined;
        const digest = try digestValues(allocator, self.schema, try self.keyValues(previous.row().cells, &values));
        candidate.index = try candidate.index.remove(store, try primaryKey(digest, id));
    }
    return .{ .data = candidate, .matched = 1, .changed = 1 };
}

test {
    _ = @import("table_data_test.zig");
}
