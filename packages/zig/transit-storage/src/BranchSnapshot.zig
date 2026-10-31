//! Private immutable branch manifests and paged Table source directories.
//! Staging acquires no pins and publishes no branch. The catalog owner must
//! verify retained dependencies and accept the complete cut before exposure.
const std = @import("std");
const p = @import("transit_protocol");
const b = p.Branch;
const d = p.DataLifecycle;
const TreeStore = @import("TreeStore.zig");
const Objects = @import("TransitObjectStore.zig");
const Snapshot = @import("TableSnapshot.zig");
const pages = TreeStore.pages;
const Self = @This();
pub const max_object_bytes = 16 * 1024;
const header_bytes = 40;
const Artifact = enum { directory, entry, manifest };

pub const Entry = struct {
    source: d.SourceCut,
    pin: Snapshot.Handle,

    pub fn validate(self: Entry, identity: b.Identity, owner: d.Operation) !void {
        try self.source.validate();
        try self.pin.owner.validate();
        try self.pin.content.validate();
        try identity.requireScope(self.source.interpretation.object.scope);
        if (!std.meta.eql(self.pin.owner, owner)) return error.BranchIdentityConflict;
    }
};

pub const Root = struct {
    definition: p.Growth.Definition,
    identity: b.Identity,
    retention_owner: d.Operation,
    entries: ?pages.Reference,
    count: u64,

    pub fn validate(self: Root) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        try self.retention_owner.validate();
        try self.identity.requireScope(self.retention_owner.scope);
        if ((self.entries == null) != (self.count == 0)) return error.InvalidBranchDirectory;
    }
};

/// Exact-root progress; callers cannot splice pages from a different selection.
/// This internal cursor is not an authorization capability or signed wire token.
pub const Cursor = struct {
    directory: b.Directory,
    after: ?u64 = null,
    seen: u64 = 0,
    complete: bool = false,
};
pub const Page = struct {
    entries: [pages.page_entries]?Entry = @splat(null),
    cursor: Cursor,
};

objects: Objects.ObjectStore,
index: TreeStore,
root: Root,
object_limit: u64,
index_work_bytes: usize,

pub fn init(allocator: std.mem.Allocator, objects: Objects.ObjectStore, identity: b.Identity, owner: d.Operation, object_limit: u64, resident_pages: usize, index_work_bytes: usize) !Self {
    const root: Root = .{ .definition = p.Growth.current_definition, .identity = identity, .retention_owner = owner, .entries = null, .count = 0 };
    try root.validate();
    if (object_limit == 0 or index_work_bytes == 0) return error.InvalidBranchLimits;
    return .{ .objects = objects, .index = try TreeStore.init(allocator, objects, resident_pages), .root = root, .object_limit = object_limit, .index_work_bytes = index_work_bytes };
}

pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}

fn entryKey(object: u64) !pages.Key {
    if (object == 0) return error.InvalidBranchDirectory;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, object, .big);
    return pages.Key.init(&bytes);
}

fn magic(comptime kind: Artifact) *const [8]u8 {
    return switch (kind) {
        .directory => "TBRDIR01",
        .entry => "TBRENT01",
        .manifest => "TBRMAN01",
    };
}

pub fn objectKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_object_bytes) return error.InvalidBranchArtifact;
    return std.fmt.bufPrint(output, "branch-snapshots/{x}.data", .{&content.sha256});
}

fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

fn encode(comptime kind: Artifact, value: anytype, output: *[max_object_bytes]u8) ![]const u8 {
    output[0..8].* = magic(kind).*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. header_bytes + writer.end];
}

fn stage(objects: Objects.ObjectStore, comptime kind: Artifact, value: anytype) !d.Content {
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try encode(kind, value, &bytes);
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try objectKey(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidBranchArtifact;
    return content;
}

fn load(objects: Objects.ObjectStore, comptime kind: Artifact, comptime T: type, content: d.Content) !T {
    var name: [96]u8 = undefined;
    const key = try objectKey(content, &name);
    const metadata = try objects.head(key) orelse return error.BranchArtifactMissing;
    if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidBranchArtifact;
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try objects.getRange(key, 0, @intCast(content.bytes), &bytes);
    if (encoded.len != content.bytes or !std.mem.eql(u8, &hash(encoded), &content.sha256) or
        !std.mem.eql(u8, encoded[0..8], magic(kind))) return error.InvalidBranchArtifact;
    if (!std.mem.eql(u8, encoded[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_object_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const parsed = std.json.parseFromSliceLeaky(T, fixed.allocator(), encoded[header_bytes..], .{}) catch |err|
        return if (err == error.OutOfMemory) error.BranchDecodeLimit else err;
    var canonical: [max_object_bytes]u8 = undefined;
    if (!std.mem.eql(u8, encoded, try encode(kind, parsed, &canonical))) return error.InvalidBranchArtifact;
    // Root, Entry and Manifest have no borrowed slices; parsing storage never escapes.
    return parsed;
}

fn reference(content: d.Content) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], content.bytes, .little);
    bytes[8..40].* = content.sha256;
    return pages.Value.init(&bytes);
}

pub fn contentOf(value: pages.Value) !d.Content {
    if (value.len != 40) return error.InvalidBranchDirectory;
    const content: d.Content = .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .sha256 = value.data[8..40].* };
    var name: [96]u8 = undefined;
    _ = try objectKey(content, &name);
    return content;
}

fn loadEntry(self: *Self, key: pages.Key, value: pages.Value) !Entry {
    const entry = try load(self.objects, .entry, Entry, try contentOf(value));
    try entry.validate(self.root.identity, self.root.retention_owner);
    if (!std.meta.eql(key, try entryKey(entry.source.interpretation.object.object))) return error.InvalidBranchDirectory;
    return entry;
}

pub fn get(self: *Self, object: u64) !?Entry {
    const key = try entryKey(object);
    return try self.loadEntry(key, try self.tree().get(self.root.entries, key) orelse return null);
}

/// Immutable exact retry. A failed put leaves the private root unchanged;
/// already staged objects remain unreferenced until the owner cleans them up.
pub fn put(self: *Self, entry: Entry) !void {
    try entry.validate(self.root.identity, self.root.retention_owner);
    const object = entry.source.interpretation.object.object;
    if (try self.get(object)) |known| {
        if (!std.meta.eql(entry, known)) return error.BranchIdentityConflict;
        return;
    }
    if (self.root.count >= self.object_limit) return error.BranchObjectLimit;
    const content = try stage(self.objects, .entry, entry);
    try self.index.begin(self.index_work_bytes);
    defer self.index.end();
    const next = try self.tree().put(self.root.entries, try entryKey(object), try reference(content));
    self.root.entries = next;
    self.root.count += 1;
}

pub fn commitment(self: *const Self) !b.Directory {
    try self.root.validate();
    var bytes: [max_object_bytes]u8 = undefined;
    const encoded = try encode(.directory, self.root, &bytes);
    return .{ .content = .{ .bytes = encoded.len, .sha256 = hash(encoded) }, .objects = self.root.count };
}

pub fn seal(self: *Self) !b.Directory {
    try self.root.validate();
    return .{ .content = try stage(self.objects, .directory, self.root), .objects = self.root.count };
}

/// Reopen a selected private root. No latest-name fallback or pin acquisition.
pub fn restore(self: *Self, directory: b.Directory) !void {
    try directory.validate();
    const next = try load(self.objects, .directory, Root, directory.content);
    try next.validate();
    if (!std.meta.eql(next.identity, self.root.identity) or !std.meta.eql(next.retention_owner, self.root.retention_owner) or next.count != directory.objects) return error.BranchIdentityConflict;
    if (next.count > self.object_limit) return error.BranchObjectLimit;
    if (next.entries) |root| _ = try self.index.load(root);
    self.root = next;
}

pub fn cursor(self: *const Self) !Cursor {
    return .{ .directory = try self.commitment() };
}

/// One fixed page; failure leaves the supplied cursor unchanged. Complete only
/// follows verified exhaustion at the directory's declared object count.
pub fn page(self: *Self, progress: Cursor) !Page {
    if (!std.meta.eql(progress.directory, try self.commitment())) return error.BranchIdentityConflict;
    if (progress.seen > self.root.count or (progress.after == null) != (progress.seen == 0) or
        (progress.complete and progress.seen != self.root.count)) return error.InvalidBranchCursor;
    var result: Page = .{ .cursor = progress };
    if (progress.complete) return result;
    const batch = try self.tree().scan(self.root.entries, if (progress.after) |after| try entryKey(after) else null);
    for (batch.entries, &result.entries) |slot, *out| if (slot) |entry| {
        const value = try self.loadEntry(entry.key, entry.value);
        const object = value.source.interpretation.object.object;
        if (result.cursor.after) |after| if (object <= after) return error.InvalidBranchDirectory;
        if (result.cursor.seen == self.root.count) return error.InvalidBranchDirectory;
        out.* = value;
        result.cursor.after = object;
        result.cursor.seen += 1;
    };
    if (batch.next == null) {
        if (result.cursor.seen != self.root.count) return error.IncompleteBranchDirectory;
        result.cursor.complete = true;
    } else if (result.cursor.seen == progress.seen) return error.IncompleteBranchDirectory;
    return result;
}

/// Verify stored source attribution, including the accepted unflushed frontier.
/// The caller separately verifies that the owning Table accepted a live pin and
/// retains it through branch publication; staged pin bytes alone are insufficient.
pub fn verifyEntry(self: *Self, allocator: std.mem.Allocator, entry: Entry) !void {
    try entry.validate(self.root.identity, self.root.retention_owner);
    var snapshot = try Snapshot.load(allocator, self.objects, entry.pin);
    defer snapshot.deinit();
    if (!std.meta.eql(snapshot.root.interpretation, entry.source.interpretation) or
        !std.meta.eql(snapshot.position(), entry.source.accepted)) return error.BranchIdentityConflict;
}

pub fn stageManifest(self: *Self, value: b.Manifest) !b.Reference {
    try value.validate();
    if (!std.meta.eql(value.identity, self.root.identity) or !std.meta.eql(value.retention_owner, self.root.retention_owner) or
        !std.meta.eql(value.objects, try self.commitment())) return error.BranchIdentityConflict;
    _ = try self.seal();
    return .{ .identity = value.identity, .version = value.version, .content = try stage(self.objects, .manifest, value) };
}

pub fn loadManifest(objects: Objects.ObjectStore, expected: b.Reference) !b.Manifest {
    try expected.validate();
    const value = try load(objects, .manifest, b.Manifest, expected.content);
    try value.validate();
    if (!std.meta.eql(value.identity, expected.identity) or value.version != expected.version) return error.BranchIdentityConflict;
    return value;
}

test {
    _ = @import("branch_snapshot_test.zig");
}
