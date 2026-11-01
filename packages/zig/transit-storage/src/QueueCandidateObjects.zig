//! Select the immutable dependencies of one proposed Queue root. This only
//! avoids staging unreachable private derivations; it never deletes an object
//! or supplies authority to publish a root. Existing provider objects are leaves.
const std = @import("std");
const Candidates = @import("CandidateObjects.zig");
const Store = @import("TreeStore.zig");
const Bitmap = @import("BitmapDirectory.zig");
const Tack = @import("Tack.zig");
const Keys = @import("OrderedKeyIndex.zig");
const Schedule = @import("QueueSchedule.zig");
const Directory = @import("QueueTimeDirectory.zig");
const Records = @import("LogPartitionRecord.zig");
const Domain = enum(u3) { plain, sidecars, bitmap, keys, levels, blob };
const Self = @This();

candidates: *Candidates,
store: *Store,
scratch: *std.heap.ArenaAllocator,
buffers: Schedule.Buffers,

pub fn persist(candidates: *Candidates, store: *Store, scratch: *std.heap.ArenaAllocator, root: Records.Root) !void {
    try root.validate();
    const queue = root.queue orelse return error.InvalidQueueRoot;
    var self: Self = .{ .candidates = candidates, .store = store, .scratch = scratch, .buffers = try Schedule.Buffers.init(queue.eligible, queue.deadlines) };
    candidates.beginSelection();
    // Queue roots cannot contain Stream compaction, hidden offsets or group pins.
    // Every other top-level index stores opaque values, not child directories.
    for ([_]?Store.pages.Reference{ root.batches, root.segments, root.receipts, root.producers, root.producer_receipts, root.transaction_pins, root.archive.directory, queue.items, queue.read_releases }) |reference|
        try self.tree(reference, .plain);
    try self.tree(queue.keys, .keys);
    try self.tree(queue.sidecars, .sidecars);
    try self.schedule(queue.eligible);
    try self.schedule(queue.deadlines);
    // At most one visit per private object and interpretation domain. The work
    // list lives in CandidateObjects' resident quota; no backlog-sized stack or
    // per-page allocation is needed, even for long ordered keys.
    while (candidates.nextSelected()) |selected| {
        const domain: Domain = @fromBackingInt(@intCast(selected.domain));
        if (domain == .blob) continue;
        const page = try store.load(.{ .digest = selected.expected, .location = selected.digest });
        switch (page.body) {
            .branch => |children| for (children) |child| {
                if (child) |value| try self.tree(value.reference, domain);
            },
            .leaf => |entries| for (entries) |entry| {
                if (entry) |value| try self.leaf(value, domain);
            },
        }
    }
    try candidates.persistSelected(&self);
}

fn tree(self: *Self, reference: ?Store.pages.Reference, domain: Domain) !void {
    const value = reference orelse return;
    var name: [96]u8 = undefined;
    try self.candidates.select(try Store.key(value.location, &name), @backingInt(domain), value.digest);
}
fn schedule(self: *Self, root: Schedule.Root) !void {
    try root.validate();
    try self.tree(root.pending, .plain);
    try self.tree(root.levels, .levels);
    if (root.work) |work| {
        try self.tree(work.merge.basis.items, .plain);
        try self.tree(work.merge.basis.sidecars, .sidecars);
        for (work.merge.sources ++ [_]Directory.Root{work.merge.output}) |run| try self.tree(run.directory, .plain);
    }
}
fn leaf(self: *Self, entry: Store.pages.Entry, domain: Domain) !void {
    switch (domain) {
        .plain => {},
        .sidecars => {
            const manifest = try Tack.decode(entry.value.slice());
            for (manifest.states) |state| try self.tree(state.containers, .bitmap);
        },
        .bitmap => {
            const reference = try Bitmap.Reference.decode(entry.value);
            var name: [96]u8 = undefined;
            try self.candidates.select(try Bitmap.objectKey(reference, &name), @backingInt(Domain.blob), reference.digest);
        },
        // Chunk-depth validation belongs to OrderedKeyIndex. This traversal
        // follows every child of an already constructed private tree, including
        // identical subtrees shared by keys of different lengths.
        .keys => try self.tree(try Keys.childIndex(entry, 0), .keys),
        .levels => {
            defer _ = self.scratch.reset(.retain_capacity);
            const run = try Records.valueDecode(Directory.Root, self.scratch.allocator(), entry.value);
            try run.validate();
            try self.tree(run.directory, .plain);
        },
        .blob => unreachable,
    }
}
pub fn keep(self: *Self, name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "data-index/") or std.mem.startsWith(u8, name, "bitmap-containers/")) return self.candidates.isSelected(name);
    return self.buffers.keep(name);
}
