//! Immutable paged Roaring directory. Roots are private candidates until an
//! owning WAL publishes them. Cache and scratch sizes do not grow with the set.
const std = @import("std");
const p = @import("transit_protocol");
const b = @import("transit_bitmap");
const TreeStore = @import("TreeStore.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = TreeStore.pages;
const Self = @This();
pub const Container = b.Container;
pub const header_bytes = 48;
pub const max_container_bytes = header_bytes + b.max_encoded_bytes;
pub const Change = struct { offset: u16, present: bool };

pub const Root = struct {
    containers: ?pages.Reference,
    cardinality: u64,
    pub const empty: Root = .{ .containers = null, .cardinality = 0 };
    pub fn validate(self: Root) !void {
        if ((self.containers == null) != (self.cardinality == 0)) return error.InvalidBitmapRoot;
    }
};

/// The tree value contains enough evidence to verify one immutable container
/// without loading other directory pages or retaining a full directory in RAM.
pub const Reference = struct {
    digest: [32]u8,
    bytes: u32,
    cardinality: u32,

    pub fn validate(self: Reference) !void {
        if (self.bytes < header_bytes + b.header_bytes or self.bytes > max_container_bytes or
            self.cardinality == 0 or self.cardinality > b.values_per_container or
            std.mem.allEqual(u8, &self.digest, 0)) return error.InvalidBitmapReference;
    }
    pub fn encode(self: Reference) !pages.Value {
        try self.validate();
        var bytes: [40]u8 = undefined;
        bytes[0..32].* = self.digest;
        std.mem.writeInt(u32, bytes[32..36], self.bytes, .big);
        std.mem.writeInt(u32, bytes[36..40], self.cardinality, .big);
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Reference {
        try value.validate();
        if (value.len != 40) return error.InvalidBitmapReference;
        const result: Reference = .{ .digest = value.data[0..32].*, .bytes = std.mem.readInt(u32, value.data[32..36], .big), .cardinality = std.mem.readInt(u32, value.data[36..40], .big) };
        try result.validate();
        return result;
    }
};

store: *TreeStore,
objects: Objects.ObjectStore,
cached: ?struct { prefix: u64, reference: Reference } = null,
bytes: [max_container_bytes]u8 align(64) = undefined,

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = self.store };
}
pub fn key(prefix: u64) !pages.Key {
    if (prefix > std.math.maxInt(u48)) return error.InvalidBitmapPrefix;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, prefix, .big);
    return pages.Key.init(&bytes);
}
pub fn prefixOf(value: pages.Key) !u64 {
    try value.validate();
    if (value.len != 8) return error.InvalidBitmapPrefix;
    const result = std.mem.readInt(u64, value.data[0..8], .big);
    if (result > std.math.maxInt(u48)) return error.InvalidBitmapPrefix;
    return result;
}
pub fn objectKey(ref: Reference, output: *[96]u8) ![]const u8 {
    try ref.validate();
    return std.fmt.bufPrint(output, "bitmap-containers/{x}.data", .{&ref.digest});
}
pub fn reference(self: *Self, root: Root, prefix: u64) !?Reference {
    try root.validate();
    const value = try self.tree().get(root.containers, try key(prefix)) orelse return null;
    return try Reference.decode(value);
}

/// Borrow valid until the next cache miss on this owner. No source bytes or
/// permission outlive the enclosing operation unless the caller retains a pin.
pub fn read(self: *Self, prefix: u64, ref: Reference) !b.View {
    _ = try key(prefix);
    try ref.validate();
    if (self.cached) |cached| if (cached.prefix == prefix and std.meta.eql(cached.reference, ref))
        return .{ .bytes = self.bytes[header_bytes..ref.bytes], .kind = std.enums.fromInt(b.Kind, self.bytes[header_bytes + 4]).?, .cardinality = ref.cardinality };
    self.cached = null;
    var name: [96]u8 = undefined;
    const object_key = try objectKey(ref, &name);
    const metadata = (self.objects.getObject(object_key, &self.bytes) catch |err| switch (err) {
        error.BufferTooSmall, error.ObjectTooLarge, error.ObjectSizeMismatch => return error.InvalidBitmapContainer,
        else => return err,
    }) orelse return error.MissingBitmapContainer;
    if (metadata.size != ref.bytes or !std.mem.eql(u8, &metadata.sha256, &ref.digest)) return error.InvalidBitmapContainer;
    const bytes = self.bytes[0..ref.bytes];
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.mem.eql(u8, &digest, &ref.digest) or
        !std.mem.eql(u8, bytes[0..8], "TBMP0001") or
        std.mem.readInt(u64, bytes[40..48], .big) != prefix) return error.InvalidBitmapContainer;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const view = try b.View.parse(bytes[header_bytes..]);
    if (view.cardinality != ref.cardinality) return error.InvalidBitmapContainer;
    self.cached = .{ .prefix = prefix, .reference = ref };
    return view;
}
pub fn contains(self: *Self, root: Root, offset: u64) !bool {
    const prefix = offset >> 16;
    const ref = try self.reference(root, prefix) orelse return false;
    return (try self.read(prefix, ref)).contains(@truncate(offset));
}

/// One bounded container batch. The caller brackets all private tree work with
/// TreeStore.begin/end and supplies reusable mutation scratch. A staging failure
/// returns no root; it cannot replace the caller's previous accepted root.
pub fn edit(self: *Self, root: Root, prefix: u64, changes: []const Change, scratch: *Container) !Root {
    try root.validate();
    _ = try key(prefix);
    if (changes.len > b.values_per_container) return error.BitmapBatchTooLarge;
    if (self.store.candidate == null) return error.NoStorageCandidate;
    const previous = try self.reference(root, prefix);
    if (previous) |ref| {
        const view = try self.read(prefix, ref);
        try scratch.decode(view.bytes);
    } else scratch.clear();
    var changed = false;
    for (changes) |change|
        changed = (if (change.present) scratch.set(change.offset) else scratch.unset(change.offset)) or changed;
    if (!changed) return root;
    return self.stage(root, prefix, scratch, previous);
}

/// Replace one container using caller-owned reusable scratch. This stages only
/// private objects; the enclosing owner must publish the returned root durably.
pub fn replace(self: *Self, root: Root, prefix: u64, container: *const Container) !Root {
    try root.validate();
    _ = try key(prefix);
    if (self.store.candidate == null) return error.NoStorageCandidate;
    return self.stage(root, prefix, container, try self.reference(root, prefix));
}

fn stage(self: *Self, root: Root, prefix: u64, scratch: *const Container, previous: ?Reference) !Root {
    const old_count = if (previous) |ref| ref.cardinality else 0;
    if (root.cardinality < old_count) return error.InvalidBitmapRoot;
    const count = std.math.add(u64, root.cardinality - old_count, scratch.cardinality) catch return error.BitmapCardinalityOverflow;
    if (scratch.cardinality == 0) {
        if (!std.mem.allEqual(u64, &scratch.words, 0)) return error.InvalidBitmapCardinality;
        const result: Root = .{ .containers = try self.tree().remove(root.containers, try key(prefix)), .cardinality = count };
        try result.validate();
        return result;
    }
    var output: [max_container_bytes]u8 align(64) = undefined;
    output[0..8].* = "TBMP0001".*;
    output[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u64, output[40..48], prefix, .big);
    const body = try scratch.encode(output[header_bytes..]);
    const encoded = output[0 .. header_bytes + body.len];
    var ref: Reference = .{ .digest = undefined, .bytes = @intCast(encoded.len), .cardinality = scratch.cardinality };
    std.crypto.hash.sha2.Sha256.hash(encoded, &ref.digest, .{});
    // Charge the container as well as its directory pages to this candidate.
    const candidate = &self.store.candidate.?;
    if (encoded.len > candidate.limit - candidate.staged) return error.StorageCandidateTooLarge;
    candidate.staged += encoded.len;
    var name: [96]u8 = undefined;
    const accepted = try self.objects.putImmutable(try objectKey(ref, &name), encoded, ref.digest);
    if (accepted.size != ref.bytes or !std.mem.eql(u8, &accepted.sha256, &ref.digest)) return error.InvalidBitmapContainer;
    return .{ .containers = try self.tree().put(root.containers, try key(prefix), try ref.encode()), .cardinality = count };
}

/// Bounded directory traversal. Owning retention walkers follow these values
/// and all tree pages before reclaiming any container or historical root.
pub fn scan(self: *Self, root: Root, after: ?pages.Key) !pages.Slice {
    try root.validate();
    if (after) |value| _ = try prefixOf(value);
    return self.tree().scan(root.containers, after);
}
