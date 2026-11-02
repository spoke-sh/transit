//! One bounded immutable Table directory walk. The maintenance owner selects
//! accepted roots and retains them for the walk's lifetime; emitted references
//! confer neither access nor deletion authority. Child key directories are
//! separate work items, so resident depth never grows with retained cardinality.
const std = @import("std");
const d = @import("transit_protocol").DataLifecycle;
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const r = @import("TablePartitionRecord.zig");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Ordered = @import("OrderedKeyIndex.zig");
const Evidence = @import("TableEvidence.zig");
const Archive = @import("TableArchive.zig");
const Snapshot = @import("TableSnapshot.zig");
const Interpretations = @import("TableInterpretations.zig");
const Declaration = @import("TableDeclaration.zig");
const Self = @This();
const key_chunk_bytes = @sizeOf(@FieldType(pages.Key, "data"));

pub const Context = struct {
    object: d.Object,
    partition: u64,
    next_lsn: u64,
    next_segment: u64,

    pub fn fromRoot(root: r.Root) !Context {
        try root.validate();
        return .{ .object = root.interpretation.object, .partition = root.partition, .next_lsn = root.next_lsn, .next_segment = root.next_segment };
    }
};

pub const Kind = enum { pages_only, rows, scan_rows, ordered_rows, physical_schemas, column_origins, definitions, receipts, operations, pins, archive };
pub const Root = struct {
    reference: pages.Reference,
    kind: Kind,
    /// Bytes already consumed by ancestor ordered-key chunk directories.
    prefix_bytes: u16 = 0,
};
pub const Edge = union(enum) {
    /// This page has been loaded and integrity checked before disclosure.
    page: Root,
    /// An ordered-key child is separate work. Queue it durably and walk it with
    /// the same Context; do not accumulate all emitted children in RAM.
    index: Root,
    /// Object/frame edges require their owner's content and semantic validation.
    segment: d.Content,
    wal: d.Position,
    snapshot: Snapshot.Handle,
    evidence: struct { owner: d.Operation, content: d.Content, kind: enum { receipt, operation } },
    archive: struct { position: d.Position, content: d.Content },
    declaration: Declaration.Stored,
    definition: Interpretations.Accepted,
};
const Frame = struct { reference: pages.Reference, height: ?u8 = null, child: u8 = 0, disclosed: bool = false };
pub const max_depth = pages.max_height + 1;
context: Context,
root: Root,
stack: [max_depth]?Frame = @splat(null),
depth: u8 = 0,

pub fn init(context: Context, root: Root) !Self {
    try context.object.validate();
    if (context.partition == 0 or context.next_lsn == 0 or context.next_segment == 0 or
        (root.kind != .ordered_rows and root.prefix_bytes != 0) or
        root.prefix_bytes >= Ordered.max_key_bytes or root.prefix_bytes % key_chunk_bytes != 0) return error.InvalidTableStorageGraph;
    var result: Self = .{ .context = context, .root = root };
    result.stack[0] = .{ .reference = root.reference };
    result.depth = 1;
    return result;
}

fn owner(self: *const Self, key: pages.Key) !d.Operation {
    if (key.len != 16) return error.InvalidTableStorageGraph;
    const result: d.Operation = .{ .scope = self.context.object.scope, .principal = std.mem.readInt(u64, key.data[0..8], .big), .operation = std.mem.readInt(u64, key.data[8..16], .big) };
    try result.validate();
    return result;
}

fn locator(self: *const Self, value: pages.Value) !Edge {
    const row = try r.Locator.decode(value);
    if (row.length == 0) return error.InvalidTableStorageGraph;
    return switch (row.kind) {
        .wal => blk: {
            if (row.lsn >= self.context.next_lsn or @as(u64, row.offset) + row.length > Log.max_payload_bytes) return error.InvalidTableStorageGraph;
            // Position identifies the required exclusive frame frontier, not a
            // new acceptance or a license to read another partition.
            break :blk .{ .wal = .{ .partition = self.context.partition, .next_lsn = row.lsn + 1 } };
        },
        .segment => blk: {
            if (row.lsn == 0 or row.lsn >= self.context.next_segment or row.length > Objects.max_object_bytes) return error.InvalidTableStorageGraph;
            break :blk .{ .segment = .{ .bytes = row.length, .sha256 = row.digest } };
        },
    };
}

fn owned(self: *const Self, entry: pages.Entry) !?Edge {
    switch (self.root.kind) {
        .pages_only => return null,
        .rows => {
            if (entry.key.len != 32) return error.InvalidTableStorageGraph;
            return try self.locator(entry.value);
        },
        .scan_rows => {
            if (entry.value.len != r.Locator.scan_bytes) return error.InvalidTableStorageGraph;
            const value = try pages.Value.init(entry.value.data[32..r.Locator.scan_bytes]);
            if (!std.meta.eql(entry.key, try (try r.Locator.decode(value)).scanKey())) return error.InvalidTableStorageGraph;
            return try self.locator(value);
        },
        .ordered_rows => {
            const child = try Ordered.childIndex(entry, self.root.prefix_bytes) orelse return null;
            return .{ .index = .{ .reference = child, .kind = .ordered_rows, .prefix_bytes = self.root.prefix_bytes + entry.key.len } };
        },
        .physical_schemas, .column_origins => {
            _ = try Interpretations.identity(entry.key);
            const stored = if (self.root.kind == .physical_schemas) (try Interpretations.Physical.decode(entry.value)).declaration else try Interpretations.decode(entry.value);
            if (!std.meta.eql(stored.interpretation.object, self.context.object)) return error.InvalidTableStorageGraph;
            return .{ .declaration = stored };
        },
        .definitions => {
            const accepted = try Interpretations.Accepted.decode(entry.value);
            if (try Interpretations.identity(entry.key) != accepted.declaration.interpretation.revision or
                !std.meta.eql(accepted.declaration.interpretation.object, self.context.object) or
                accepted.next_lsn > self.context.next_lsn) return error.InvalidTableStorageGraph;
            return .{ .definition = accepted };
        },
        .receipts, .operations => return .{ .evidence = .{
            .owner = try self.owner(entry.key),
            .content = try Evidence.decodeReference(entry.value),
            .kind = if (self.root.kind == .receipts) .receipt else .operation,
        } },
        .pins => {
            const identity = try self.owner(entry.key);
            const pin = try Snapshot.Pin.decode(entry.value);
            if (pin.released) return null;
            return .{ .snapshot = .{ .owner = identity, .content = pin.content } };
        },
        .archive => {
            if (entry.key.len != 8) return error.InvalidTableStorageGraph;
            const lsn = std.mem.readInt(u64, entry.key.data[0..8], .big);
            if (lsn >= self.context.next_lsn) return error.InvalidTableStorageGraph;
            return .{ .archive = .{ .position = .{ .partition = self.context.partition, .next_lsn = lsn + 1 }, .content = try Archive.decodeReference(entry.value) } };
        },
    }
}

/// Each call loads at most max_depth + 1 pages and emits one edge. Failed reads
/// or shape validation restore the complete cursor, so retry cannot skip work.
pub fn next(self: *Self, store: anytype) !?Edge {
    const before = self.*;
    errdefer self.* = before;
    if (self.depth > self.stack.len) return error.InvalidTableStorageGraph;
    for (self.stack[self.depth..]) |slot| if (slot != null) return error.InvalidTableStorageGraph;
    while (self.depth != 0) {
        const frame = if (self.stack[self.depth - 1]) |*value| value else return error.InvalidTableStorageGraph;
        const page = try store.load(frame.reference);
        try frame.reference.verify(&page);
        if (frame.height) |height| if (page.height != height) return error.InvalidTableStorageGraph;
        if (frame.child > page.count) return error.InvalidTableStorageGraph;
        if (!frame.disclosed) {
            if (frame.child != 0) return error.InvalidTableStorageGraph;
            frame.disclosed = true;
            var root = self.root;
            root.reference = frame.reference;
            return .{ .page = root };
        }
        switch (page.body) {
            .branch => |children| if (frame.child < page.count) {
                const child = children[frame.child].?;
                frame.child += 1;
                if (self.depth == self.stack.len) return error.InvalidTableStorageGraph;
                self.stack[self.depth] = .{ .reference = child.reference, .height = page.height - 1 };
                self.depth += 1;
                continue;
            },
            .leaf => |entries| while (frame.child < page.count) {
                const entry = entries[frame.child].?;
                frame.child += 1;
                if (try self.owned(entry)) |edge| return edge;
            },
        }
        self.stack[self.depth - 1] = null;
        self.depth -= 1;
    }
    return null;
}

/// Skip only the page most recently emitted, after an independently retained
/// mark has established that its complete typed subtree was already visited
/// under this same context, directory kind and ordered-key prefix depth.
pub fn skip(self: *Self) !void {
    if (self.depth == 0 or self.depth > self.stack.len) return error.InvalidTableStorageGraph;
    const frame = self.stack[self.depth - 1] orelse return error.InvalidTableStorageGraph;
    if (!frame.disclosed or frame.child != 0) return error.InvalidTableStorageGraph;
    self.stack[self.depth - 1] = null;
    self.depth -= 1;
}
