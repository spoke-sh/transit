//! Paged directory for one sorted, time-bucketed run of bounded `.tseg` chunks.
//! Roots are private until an owning Queue decision retains and publishes them.
const std = @import("std");
const p = @import("transit_protocol");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const Run = @import("QueueTimeRun.zig");
const Self = @This();

pub const Root = struct {
    directory: ?pages.Reference,
    rows: u64,
    chunks: u64,
    first: ?Run.Event,
    last: ?Run.Event,
    pub const empty: Root = .{ .directory = null, .rows = 0, .chunks = 0, .first = null, .last = null };
    pub fn validate(self: Root) !void {
        if ((self.rows == 0) != (self.directory == null) or (self.rows == 0) != (self.chunks == 0) or
            (self.rows == 0) != (self.first == null) or (self.first == null) != (self.last == null)) return error.InvalidQueueTimeDirectory;
        if (self.rows == 0) return;
        if (self.chunks > self.rows or (self.rows - 1) / Run.max_rows >= self.chunks or
            (self.rows == 1 and !std.meta.eql(self.first, self.last)) or
            (self.rows > 1 and !Run.Event.less(self.first.?, self.last.?))) return error.InvalidQueueTimeDirectory;
    }
};
pub const Entry = struct {
    first_row: u64,
    chunk: Run.Descriptor,
    pub fn encode(self: Entry) !pages.Value {
        const chunk = try self.chunk.encode();
        var bytes: [248]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.first_row, .big);
        @memcpy(bytes[8..], chunk.slice());
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Entry {
        if (value.len != 248) return error.InvalidQueueTimeDirectory;
        return .{ .first_row = std.mem.readInt(u64, value.data[0..8], .big), .chunk = try Run.Descriptor.decode(try pages.Value.init(value.data[8..248])) };
    }
};
pub const Audit = struct {
    basis: Root,
    after: ?Run.Event = null,
    rows: u64 = 0,
    chunks: u64 = 0,
    complete: bool = false,
};

store: *Store,
seed: p.StreamQueue.Partition,
kind: Run.Kind,
bucket: u64,

pub fn eventKey(event: Run.Event) !pages.Key {
    var bytes: [24]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], event.at_ms, .big);
    std.mem.writeInt(u64, bytes[8..16], event.offset, .big);
    std.mem.writeInt(u64, bytes[16..24], event.epoch, .big);
    return pages.Key.init(&bytes);
}
fn requireRoot(self: Self, root: Root) !void {
    try self.seed.validate();
    try root.validate();
    if (self.seed.interpretation.revision != 1 or self.bucket > std.math.maxInt(u64) >> Run.bucket_bits) return error.InvalidQueueTimeDirectory;
    if (root.first) |first| {
        try first.validate(self.kind);
        try root.last.?.validate(self.kind);
        if (first.bucket() != self.bucket or root.last.?.bucket() != self.bucket) return error.InvalidQueueTimeDirectory;
    }
}
fn requireChunk(self: Self, chunk: Run.Descriptor) !void {
    try chunk.validate();
    if (!std.meta.eql(self.seed, chunk.seed) or self.kind != chunk.kind or self.bucket != chunk.bucket) return error.InvalidQueueTimeDirectory;
}
fn tree(self: Self) pages.Tree(Store) {
    return .{ .store = self.store };
}

/// Append one already staged chunk to a private run. Only chunk boundaries
/// enter this B-tree; row count does not allocate a resident directory array.
pub fn append(self: Self, before: Root, chunk: Run.Descriptor) !Root {
    try self.requireRoot(before);
    try self.requireChunk(chunk);
    if (before.last) |last| if (!Run.Event.less(last, chunk.first)) return error.QueueTimeRunOverlap;
    const rows = std.math.add(u64, before.rows, chunk.rows) catch return error.QueueTimeRunCardinalityOverflow;
    const chunks = std.math.add(u64, before.chunks, 1) catch return error.QueueTimeRunCardinalityOverflow;
    const directory = try self.tree().put(before.directory, try eventKey(chunk.last), try (Entry{ .first_row = before.rows, .chunk = chunk }).encode());
    const next: Root = .{ .directory = directory, .rows = rows, .chunks = chunks, .first = before.first orelse chunk.first, .last = chunk.last };
    try next.validate();
    return next;
}

/// Locate the first chunk whose upper key exceeds the exclusive cursor. This
/// does not validate earlier chunks or establish coverage of the whole run.
pub fn find(self: Self, root: Root, after: ?Run.Event) !?Entry {
    try self.requireRoot(root);
    const page = try self.tree().scan(root.directory, if (after) |event| try eventKey(event) else null);
    const entry = page.entries[0] orelse {
        if (root.last) |last| if (after == null or Run.Event.less(after.?, last)) return error.InvalidQueueTimeDirectory;
        return null;
    };
    const value = try Entry.decode(entry.value);
    try self.requireChunk(value.chunk);
    if (root.rows == 0 or !std.meta.eql(entry.key, try eventKey(value.chunk.last)) or
        value.first_row >= root.rows or value.chunk.rows > root.rows - value.first_row or
        Run.Event.less(value.chunk.first, root.first.?) or Run.Event.less(root.last.?, value.chunk.last) or
        (value.first_row == 0 and !std.meta.eql(value.chunk.first, root.first.?)) or
        (value.first_row + value.chunk.rows == root.rows and !std.meta.eql(value.chunk.last, root.last.?)) or
        (after == null and value.first_row != 0)) return error.InvalidQueueTimeDirectory;
    return value;
}

/// One directory entry per step, with exact row/chunk continuity and an actual
/// exhausted-directory check. Errors leave the caller's audit cursor unchanged.
pub fn audit(self: Self, cursor: *Audit) !?Entry {
    try self.requireRoot(cursor.basis);
    if (cursor.rows > cursor.basis.rows or cursor.chunks > cursor.basis.chunks or
        (cursor.chunks == 0) != (cursor.after == null)) return error.InvalidQueueTimeDirectory;
    if (cursor.complete) {
        if (cursor.rows != cursor.basis.rows or cursor.chunks != cursor.basis.chunks or !std.meta.eql(cursor.after, cursor.basis.last)) return error.InvalidQueueTimeDirectory;
        return null;
    }
    const value = try self.find(cursor.basis, cursor.after) orelse {
        if (cursor.rows != cursor.basis.rows or cursor.chunks != cursor.basis.chunks or !std.meta.eql(cursor.after, cursor.basis.last)) return error.InvalidQueueTimeDirectory;
        cursor.complete = true;
        return null;
    };
    if (value.first_row != cursor.rows or cursor.chunks == cursor.basis.chunks or
        (cursor.after != null and !Run.Event.less(cursor.after.?, value.chunk.first))) return error.InvalidQueueTimeDirectory;
    cursor.rows += value.chunk.rows;
    cursor.chunks += 1;
    cursor.after = value.chunk.last;
    return value;
}
