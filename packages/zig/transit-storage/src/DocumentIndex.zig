//! Private Document candidates over bounded `.tseg` record batches and immutable
//! data indexes. Sealing makes a durable candidate, never an acceptance decision.
const std = @import("std");
const p = @import("transit_protocol");
const d = @import("transit_document");
const f = @import("transit_fuze");
const TreeStore = @import("TreeStore.zig");
const Ordered = @import("OrderedKeyIndex.zig");
const objects = @import("TransitObjectStore.zig");
const pages = TreeStore.pages;
const Tree = pages.Tree(TreeStore);
const Self = @This();

pub const Key = d.Bytes(128);
pub const Value = d.Bytes(256);
pub const Entry = struct { key: Key, value: Value };
pub const Identity = struct {
    document: u64,
    epoch: u64,
    type_revision: u32,
    pub fn validate(self: Identity) !void {
        if (self.document == 0 or self.epoch == 0 or self.type_revision == 0) return error.InvalidDocumentIdentity;
    }
};
/// All fields, including the definition, are mandatory when restoring a root.
/// A descriptor carries no authorization, revision acceptance or retention pin.
pub const Root = struct {
    definition: [32]u8,
    identity: Identity,
    records: pages.Reference,
    ordered: pages.Reference,
    entries: u64,
    pub fn validate(self: Root) !void {
        if (!std.mem.eql(u8, &self.definition, &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        try self.identity.validate();
        if (self.entries == 0) return error.InvalidDocumentRoot;
        for ([_]pages.Reference{ self.records, self.ordered }) |ref| {
            if (std.mem.allEqual(u8, &ref.digest, 0) or std.mem.allEqual(u8, &ref.location, 0)) return error.InvalidDocumentRoot;
        }
    }
};

root: ?Root = null,
generation: u64 = 0,
pending: usize = 0,
owner: ?*Store = null,

pub fn get(self: Self, store: *Store, key: Key) !?Value {
    try key.validate(true);
    try store.check(self);
    var i = self.pending;
    while (i != 0) {
        i -= 1;
        if (Key.eql(store.pending[i].key, key)) return store.pending[i].value;
    }
    return store.read(self.root, key);
}

pub fn next(self: Self, store: *Store, after: ?Key) !?Entry {
    if (after) |key| try key.validate(true);
    try store.check(self);
    const ordered: Ordered = .{ .store = &store.tree };
    var result: ?Entry = null;
    if (self.root) |root| {
        if (try ordered.seek(root.ordered, if (after) |*key| .{ .key = key.slice(), .inclusive = false } else null, null)) |found| {
            const key = try Key.init(found.key.slice());
            if (!std.mem.eql(u8, &found.value, &hash(key.slice()))) return error.InvalidDocumentIndex;
            result = .{ .key = key, .value = (try self.get(store, key)) orelse return error.InvalidDocumentIndex };
        }
    }
    // Reverse order ensures the newest pending value wins for equal keys.
    var i = self.pending;
    while (i != 0) {
        i -= 1;
        const entry = store.pending[i];
        if (after) |key| if (std.mem.order(u8, entry.key.slice(), key.slice()) != .gt) continue;
        if (result) |old| if (std.mem.order(u8, entry.key.slice(), old.key.slice()) != .lt) continue;
        result = entry;
    }
    return result;
}

pub fn put(self: Self, store: *Store, key: Key, value: Value) !Self {
    try store.check(self);
    try key.validate(true);
    try value.validate(false);
    // Candidate mutation is linear; copied prefixes can be read, not forked.
    if (self.generation == 0 or self.pending != store.used) return error.StaleDocumentCandidate;
    if (store.used == store.pending.len) return error.DocumentCandidateTooLarge;
    store.pending[store.used] = .{ .key = key, .value = value };
    store.used += 1;
    var result = self;
    result.pending = store.used;
    return result;
}

fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

pub const Locator = struct {
    segment: [32]u8,
    length: u32,
    row: u32,
    fn encode(self: Locator) !pages.Value {
        var bytes: [40]u8 = undefined;
        bytes[0..32].* = self.segment;
        std.mem.writeInt(u32, bytes[32..36], self.length, .big);
        std.mem.writeInt(u32, bytes[36..40], self.row, .big);
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Locator {
        if (value.len != 40) return error.InvalidDocumentLocator;
        return .{ .segment = value.data[0..32].*, .length = std.mem.readInt(u32, value.data[32..36], .big), .row = std.mem.readInt(u32, value.data[36..40], .big) };
    }
};

/// One owner, one active candidate; callers serialize access and supply current
/// authorization outside this component. No accepted head is stored here.
pub const Store = struct {
    pub const Options = struct {
        pending_records: usize = 128,
        segment_bytes: usize = 64 * 1024,
        scratch_bytes: usize = 1024 * 1024,
        resident_pages: usize = 8,
    };
    allocator: std.mem.Allocator,
    identity: Identity,
    tree: TreeStore,
    pending: []Entry,
    cached: []Entry,
    cached_segment: ?[32]u8 = null,
    cached_length: usize = 0,
    cached_rows: usize = 0,
    segment: []align(64) u8,
    scratch: []align(64) u8,
    used: usize = 0,
    generation: u64 = 0,
    active: bool = false,
    base: ?Root = null,

    pub fn init(allocator: std.mem.Allocator, object_store: objects.ObjectStore, identity: Identity, options: Options) !Store {
        try identity.validate();
        if (options.pending_records == 0 or options.pending_records > 4096 or options.segment_bytes < 128 or
            options.segment_bytes > f.TSeg.max_segment_bytes or options.scratch_bytes == 0) return error.InvalidDocumentStorageBudget;
        var tree = try TreeStore.init(allocator, object_store, options.resident_pages);
        errdefer tree.deinit();
        const pending = try allocator.alloc(Entry, options.pending_records);
        errdefer allocator.free(pending);
        const cached = try allocator.alloc(Entry, options.pending_records);
        errdefer allocator.free(cached);
        const segment = try allocator.alignedAlloc(u8, .fromByteUnits(64), options.segment_bytes);
        errdefer allocator.free(segment);
        const scratch = try allocator.alignedAlloc(u8, .fromByteUnits(64), options.scratch_bytes);
        return .{ .allocator = allocator, .identity = identity, .tree = tree, .pending = pending, .cached = cached, .segment = segment, .scratch = scratch };
    }

    pub fn deinit(self: *Store) void {
        self.tree.deinit();
        self.allocator.free(self.pending);
        self.allocator.free(self.cached);
        self.allocator.free(self.segment);
        self.allocator.free(self.scratch);
        self.* = undefined;
    }

    fn check(self: *Store, index: Self) !void {
        if (index.root) |root| {
            try root.validate();
            if (!std.meta.eql(root.identity, self.identity)) return error.DocumentIdentityMismatch;
        }
        if (index.generation != 0) {
            if (index.owner != self or !self.active or index.generation != self.generation or index.pending > self.used or
                !std.meta.eql(index.root, self.base)) return error.StaleDocumentCandidate;
        } else if (index.pending != 0 or index.owner != null) return error.StaleDocumentCandidate;
    }

    pub fn begin(self: *Store, base: Self, index_byte_limit: usize) !Self {
        if (self.active) return error.ActiveStorageCandidate;
        if (base.generation != 0) return error.StaleDocumentCandidate;
        try self.check(base);
        const generation = std.math.add(u64, self.generation, 1) catch return error.DocumentCandidateGenerationExhausted;
        try self.tree.begin(index_byte_limit);
        self.generation = generation;
        self.active = true;
        self.base = base.root;
        self.used = 0;
        return .{ .root = base.root, .generation = generation, .owner = self };
    }

    /// Invalidates all pending handles. Staged objects remain private orphans.
    pub fn abort(self: *Store) void {
        self.active = false;
        self.base = null;
        self.used = 0;
        self.tree.end();
    }

    /// Consumes the candidate on success or failure. The returned root still
    /// needs an owner's fenced WAL decision and retained-root lifecycle.
    pub fn seal(self: *Store, index: Self) !Self {
        try self.check(index);
        if (index.generation == 0 or index.pending != self.used) return error.StaleDocumentCandidate;
        defer self.abort();
        return self.sealInner(index);
    }

    fn schema(self: *const Store) f.TableSchema.Schema {
        return .{ .object = self.identity.document, .revision = self.identity.type_revision, .next_column = 3, .columns = &.{
            .{ .id = 1, .name = "key", .type = .binary, .nullable = false },
            .{ .id = 2, .name = "value", .type = .binary, .nullable = false },
        } };
    }

    fn buildSegment(self: *Store) ![]const u8 {
        var scratch = std.heap.FixedBufferAllocator.init(self.scratch);
        const allocator = scratch.allocator();
        const rows = try allocator.alloc(f.TableRow.Row, self.used);
        const cells = try allocator.alloc([2]f.Types.Values.Cell, self.used);
        // Preserve append order: keyless .tseg rows sort by this exact identity.
        for (self.pending[0..self.used], rows, cells, 0..) |*entry, *row, *pair, i| {
            pair.* = .{ binary(entry.key.slice()), binary(entry.value.slice()) };
            row.* = .{ .identity = .{ .origin = self.identity.document, .operation = self.identity.epoch, .ordinal = @intCast(i) }, .cells = pair };
        }
        return f.TSeg.writeSegment(allocator, self.schema(), rows, .{ .segment_id = self.identity.epoch, .rows_per_group = @intCast(self.used) }, self.segment);
    }

    fn sealInner(self: *Store, index: Self) !Self {
        if (self.used == 0) return .{ .root = index.root };
        const encoded = self.buildSegment() catch |err| switch (err) {
            error.OutOfMemory => return error.DocumentScratchBudget,
            error.WriteFailed, error.BufferTooSmall => return error.DocumentSegmentBudget,
            else => return err,
        };
        const digest = hash(encoded);
        var name: [96]u8 = undefined;
        const metadata = try self.tree.store.putImmutable(try segmentKey(digest, &name), encoded, digest);
        if (metadata.size != encoded.len or !std.mem.eql(u8, &metadata.sha256, &digest)) return error.InvalidDocumentSegment;
        var records: ?pages.Reference = if (index.root) |root| root.records else null;
        var ordered: ?pages.Reference = if (index.root) |root| root.ordered else null;
        var entries: u64 = if (index.root) |root| root.entries else 0;
        const tree: Tree = .{ .store = &self.tree };
        const directory: Ordered = .{ .store = &self.tree };
        for (self.pending[0..self.used], 0..) |entry, i| {
            // Only the final occurrence needs a directory update.
            var superseded = false;
            for (self.pending[i + 1 .. self.used]) |later| if (Key.eql(entry.key, later.key)) {
                superseded = true;
                break;
            };
            if (superseded) continue;
            const address = hash(entry.key.slice());
            const key = try pages.Key.init(&address);
            if (try tree.get(records, key)) |prior| {
                // A hash is an address, never evidence of full-key equality.
                const old = try self.load(try Locator.decode(prior));
                if (!Key.eql(old.key, entry.key)) return error.DocumentKeyCollision;
            } else entries = try std.math.add(u64, entries, 1);
            records = try tree.put(records, key, try (Locator{ .segment = digest, .length = @intCast(encoded.len), .row = @intCast(i) }).encode());
            ordered = try directory.put(ordered, entry.key.slice(), address);
        }
        return .{ .root = .{ .definition = p.Growth.definition_bytes, .identity = self.identity, .records = records.?, .ordered = ordered.?, .entries = entries } };
    }

    fn read(self: *Store, root: ?Root, key: Key) !?Value {
        const current = root orelse return null;
        const tree: Tree = .{ .store = &self.tree };
        const value = try tree.get(current.records, try pages.Key.init(&hash(key.slice()))) orelse return null;
        const entry = try self.load(try Locator.decode(value));
        if (!Key.eql(entry.key, key)) return error.DocumentKeyCollision;
        return entry.value;
    }

    fn load(self: *Store, locator: Locator) !Entry {
        if (self.cached_segment == null or !std.mem.eql(u8, &self.cached_segment.?, &locator.segment)) {
            self.cached_segment = null;
            try self.loadSegment(locator);
            self.cached_segment = locator.segment;
        }
        if (locator.length != self.cached_length or locator.row >= self.cached_rows) return error.InvalidDocumentLocator;
        return self.cached[locator.row];
    }

    fn loadSegment(self: *Store, locator: Locator) !void {
        if (locator.length > self.segment.len) return error.DocumentSegmentBudget;
        var name: [96]u8 = undefined;
        const key = try segmentKey(locator.segment, &name);
        const metadata = try self.tree.store.head(key) orelse return error.MissingDocumentSegment;
        if (metadata.size != locator.length or !std.mem.eql(u8, &metadata.sha256, &locator.segment)) return error.InvalidDocumentSegment;
        const bytes = try self.tree.store.getRange(key, 0, locator.length, self.segment);
        if (bytes.len != locator.length or !std.mem.eql(u8, &hash(bytes), &locator.segment)) return error.InvalidDocumentSegment;
        self.decodeSegment(bytes) catch |err| switch (err) {
            error.OutOfMemory => return error.DocumentScratchBudget,
            else => return err,
        };
        self.cached_length = bytes.len;
    }

    fn decodeSegment(self: *Store, bytes: []const u8) !void {
        var scratch = std.heap.FixedBufferAllocator.init(self.scratch);
        const allocator = scratch.allocator();
        var footer = try f.TSeg.readFooter(allocator, bytes);
        defer footer.deinit();
        if (footer.segment_id != self.identity.epoch or footer.row_groups.len != 1 or footer.total_rows == 0) return error.InvalidDocumentSegment;
        if (footer.total_rows > self.cached.len) return error.DocumentSegmentBudget;
        const keys = try f.TSeg.decodeRowGroupColumn(allocator, self.schema(), &footer, bytes, 0, 0);
        const values = try f.TSeg.decodeRowGroupColumn(allocator, self.schema(), &footer, bytes, 0, 1);
        if (keys.len != footer.total_rows or values.len != keys.len) return error.InvalidDocumentSegment;
        for (keys, values, self.cached[0..keys.len]) |key, value, *entry| {
            entry.* = .{ .key = try Key.init(try binaryBytes(key)), .value = try Value.init(try binaryBytes(value)) };
            try entry.key.validate(true);
        }
        self.cached_rows = keys.len;
    }
};

pub fn segmentKey(digest: [32]u8, out: *[96]u8) ![]const u8 {
    if (std.mem.allEqual(u8, &digest, 0)) return error.InvalidDocumentLocator;
    return std.fmt.bufPrint(out, "document-segment/{x}.tseg", .{&digest});
}
fn binary(bytes: []const u8) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .bytes = bytes } } };
}
fn binaryBytes(cell: f.Types.Values.Cell) ![]const u8 {
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidDocumentSegment;
    return cell.value.atom.bytes;
}
