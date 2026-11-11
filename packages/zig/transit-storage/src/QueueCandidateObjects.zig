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
const Run = @import("QueueTimeRun.zig");
const Evidence = @import("LogEvidence.zig");
const Selection = @import("QueueSelection.zig");
const ReadRelease = @import("QueueReadRelease.zig");
const Records = @import("LogPartitionRecord.zig");
const Domain = enum(u3) { plain, receipts, sidecars, bitmap, keys, levels, run_chunks, blob };
const Self = @This();

candidates: *Candidates,
store: *Store,
scratch: *std.heap.ArenaAllocator,
root: Records.Root,
selection_buffer: []u8,
buffers: Schedule.Buffers,

fn selectReachable(candidates: *Candidates, store: *Store, scratch: *std.heap.ArenaAllocator, root: Records.Root, selection_buffer: []u8) !Self {
    try root.validate();
    const queue = root.queue orelse return error.InvalidQueueRoot;
    var self: Self = .{ .candidates = candidates, .store = store, .scratch = scratch, .root = root, .selection_buffer = selection_buffer, .buffers = try Schedule.Buffers.init(queue.eligible, queue.deadlines) };
    candidates.beginSelection();
    // Queue roots cannot contain Stream compaction, hidden offsets or group pins.
    // Every other top-level index stores opaque values, not child directories.
    for ([_]?Store.pages.Reference{ root.batches, root.segments, root.producers, root.producer_receipts, root.transaction_pins, root.archive.directory, queue.items, queue.read_releases }) |reference|
        try self.tree(reference, .plain);
    try self.tree(root.receipts, .receipts);
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
    return self;
}

pub fn persist(candidates: *Candidates, store: *Store, scratch: *std.heap.ArenaAllocator, root: Records.Root, selection_buffer: []u8) !void {
    const self = try selectReachable(candidates, store, scratch, root, selection_buffer);
    try candidates.persistSelected(&self);
    for (candidates.entries[0..candidates.count], 0..) |entry, index| {
        const name = candidates.keyAt(index);
        if (self.keep(name) and std.mem.startsWith(u8, name, "data-index/")) store.markVerified(entry.digest);
    }
}

pub fn compact(candidates: *Candidates, store: *Store, scratch: *std.heap.ArenaAllocator, root: Records.Root, selection_buffer: []u8) !void {
    const self = try selectReachable(candidates, store, scratch, root, selection_buffer);
    candidates.compactSelected(&self);
    store.clearDerived();
}

fn tree(self: *Self, reference: ?Store.pages.Reference, domain: Domain) !void {
    const value = reference orelse return;
    var name: [96]u8 = undefined;
    try self.candidates.select(try Store.key(value.location, &name), @backingInt(domain), value.digest);
}
fn schedule(self: *Self, root: Schedule.Root) !void {
    try root.validate();
    try self.tree(root.pending, .run_chunks);
    try self.tree(root.levels, .levels);
    if (root.work) |work| {
        try self.tree(work.merge.basis.items, .plain);
        try self.tree(work.merge.basis.sidecars, .sidecars);
        for (work.merge.sources ++ [_]Directory.Root{work.merge.output}) |run| try self.tree(run.directory, .run_chunks);
    }
}
fn leaf(self: *Self, entry: Store.pages.Entry, domain: Domain) !void {
    switch (domain) {
        .plain => {},
        .receipts => {
            const content = try Evidence.decodeReference(entry.value);
            var name: [96]u8 = undefined;
            const evidence_key = try Evidence.key(content, &name);
            try self.candidates.select(evidence_key, @backingInt(Domain.blob), content.sha256);
            if (self.candidates.contains(evidence_key)) {
                defer _ = self.scratch.reset(.retain_capacity);
                const record = try Evidence.load(self.scratch.allocator(), self.candidates.objectStore(), entry.value);
                if (record.outcome == .claim) if (record.outcome.claim.receipt.leases) |leases| {
                    var selection_name: [96]u8 = undefined;
                    const selection_key = try Selection.objectKey(leases, &selection_name);
                    try self.candidates.select(selection_key, @backingInt(Domain.blob), leases.sha256);
                    if ((try ReadRelease.find(self.scratch.allocator(), self.store, self.root.queue.?.read_releases, record.outcome.claim.receipt, self.root.position())) == null) {
                        const selection = try Selection.load(self.scratch.allocator(), self.candidates.objectStore(), leases, self.selection_buffer);
                        try self.tree(selection.metadata.source.batches, .plain);
                        try self.tree(selection.metadata.source.segments, .plain);
                    }
                };
            }
        },
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
            try self.tree(run.directory, .run_chunks);
        },
        .run_chunks => {
            const chunk = if (entry.value.len == 240)
                try Run.Descriptor.decode(entry.value)
            else
                (try Directory.Entry.decode(entry.value)).chunk;
            var name: [96]u8 = undefined;
            try self.candidates.select(try Run.key(chunk.content, &name), @backingInt(Domain.blob), chunk.content.sha256);
        },
        .blob => unreachable,
    }
}
pub fn keep(self: *const Self, name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "data-index/") or
        std.mem.startsWith(u8, name, "bitmap-containers/") or
        std.mem.startsWith(u8, name, "queue-time-runs/") or
        std.mem.startsWith(u8, name, "log-evidence/") or
        std.mem.startsWith(u8, name, "queue-selections/")) return self.candidates.isSelected(name);
    return self.buffers.keep(name);
}
