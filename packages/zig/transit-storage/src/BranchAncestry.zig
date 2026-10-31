//! Bounded, private merge-base preparation over exact immutable manifests.
//! All ancestry must be read before a result is complete. No catalog head,
//! retention pin, read authorization or merge decision is published here.
const std = @import("std");
const p = @import("transit_protocol");
const b = p.Branch;
const d = p.DataLifecycle;
const TreeStore = @import("TreeStore.zig");
const Snapshot = @import("BranchSnapshot.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = TreeStore.pages;
const Self = @This();

pub const Limits = struct {
    visits: u64,
    staged_bytes: u64,
    step_bytes: usize,
    resident_pages: usize,
};
pub const Resolution = union(enum) { unrelated, unique: b.Reference, ambiguous };
const Walk = struct { pending: ?pages.Reference = null, seen: ?pages.Reference = null };
const Phase = enum { source, target, select, complete };
const State = struct {
    source: Walk = .{},
    target: Walk = .{},
    common: ?pages.Reference = null,
    dominated: ?pages.Reference = null,
    after: ?pages.Key = null,
    phase: Phase = .source,
    result: Resolution = .unrelated,
};

index: TreeStore,
scope: d.Scope,
limits: Limits,
state: State = .{},
visits: u64 = 0,

pub fn init(allocator: std.mem.Allocator, objects: Objects.ObjectStore, source: b.Reference, target: b.Reference, limits: Limits) !Self {
    try source.validate();
    try target.validate();
    try source.identity.requireScope(target.identity.scope);
    if (limits.visits == 0 or limits.staged_bytes == 0 or limits.step_bytes == 0) return error.InvalidBranchLimits;
    var self: Self = .{ .index = try TreeStore.init(allocator, objects, limits.resident_pages), .scope = source.identity.scope, .limits = limits };
    errdefer self.index.deinit();
    try self.begin();
    {
        defer self.index.end();
        try self.enqueue(&self.state.source, source);
        try self.enqueue(&self.state.target, target);
    }
    return self;
}

pub fn deinit(self: *Self) void {
    self.index.deinit();
    self.* = undefined;
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}

fn begin(self: *Self) !void {
    if (self.index.staged_bytes >= self.limits.staged_bytes) return error.BranchAncestryStagingLimit;
    try self.index.begin(@intCast(@min(self.limits.step_bytes, self.limits.staged_bytes - self.index.staged_bytes)));
}

fn key(ref: b.Reference) !pages.Key {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], ref.identity.branch, .big);
    std.mem.writeInt(u64, bytes[8..16], ref.version, .big);
    return pages.Key.init(&bytes);
}

fn value(ref: b.Reference) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], ref.content.bytes, .little);
    bytes[8..40].* = ref.content.sha256;
    return pages.Value.init(&bytes);
}

fn reference(self: *Self, entry: pages.Entry) !b.Reference {
    if (entry.key.len != 16 or entry.value.len != 40) return error.InvalidBranchAncestry;
    const ref: b.Reference = .{
        .identity = .{ .scope = self.scope, .branch = std.mem.readInt(u64, entry.key.data[0..8], .big) },
        .version = std.mem.readInt(u64, entry.key.data[8..16], .big),
        .content = .{ .bytes = std.mem.readInt(u64, entry.value.data[0..8], .little), .sha256 = entry.value.data[8..40].* },
    };
    try ref.validate();
    return ref;
}

fn contains(self: *Self, root: ?pages.Reference, ref: b.Reference) !bool {
    const known = try self.tree().get(root, try key(ref)) orelse return false;
    if (!std.meta.eql(known, try value(ref))) return error.BranchIdentityConflict;
    return true;
}

fn insert(self: *Self, root: *?pages.Reference, ref: b.Reference) !void {
    try ref.identity.requireScope(self.scope);
    if (!try self.contains(root.*, ref)) root.* = try self.tree().put(root.*, try key(ref), try value(ref));
}

fn enqueue(self: *Self, walk: *Walk, ref: b.Reference) !void {
    if (try self.contains(walk.seen, ref)) return;
    try self.insert(&walk.seen, ref);
    try self.insert(&walk.pending, ref);
}

/// Visit at most one manifest or one fixed index page. Failure never advances
/// private roots; attempted reads/writes still consume the finite work budget.
pub fn step(self: *Self) !bool {
    if (self.state.phase == .complete) return true;
    var next = self.state;
    if (next.phase == .select) {
        const batch = try self.tree().scan(next.common, next.after);
        for (batch.entries) |slot| if (slot) |entry| {
            const ref = try self.reference(entry);
            if (!try self.contains(next.dominated, ref)) next.result = switch (next.result) {
                .unrelated => .{ .unique = ref },
                .unique, .ambiguous => .ambiguous,
            };
        };
        next.after = batch.next;
        if (batch.next == null) next.phase = .complete;
    } else {
        const walk = if (next.phase == .source) &next.source else &next.target;
        const batch = try self.tree().scan(walk.pending, null);
        if (batch.entries[0]) |entry| {
            if (self.visits == self.limits.visits) return error.BranchAncestryWorkLimit;
            self.visits += 1;
            const ref = try self.reference(entry);
            const manifest = try Snapshot.loadManifest(self.index.store, ref);
            try self.begin();
            defer self.index.end();
            walk.pending = try self.tree().remove(walk.pending, entry.key);
            // Restore provenance is not an ancestry edge. Only accepted parent
            // and merge-parent history participates in common-base selection.
            inline for (.{ manifest.parent, manifest.merge_parent }) |parent| if (parent) |ancestor| try self.enqueue(walk, ancestor);
            if (next.phase == .target and try self.contains(next.source.seen, ref)) {
                try self.insert(&next.common, ref);
                // Every parent of a common node is common. Marking direct
                // parents after exhaustive traversal excludes all nonmaximal
                // common nodes without comparing unrelated branch clocks.
                inline for (.{ manifest.parent, manifest.merge_parent }) |parent| if (parent) |ancestor| {
                    if (!try self.contains(next.source.seen, ancestor)) return error.InvalidBranchAncestry;
                    try self.insert(&next.dominated, ancestor);
                };
            }
        } else next.phase = if (next.phase == .source) .target else .select;
    }
    self.state = next;
    return next.phase == .complete;
}

pub fn result(self: *const Self) !Resolution {
    if (self.state.phase != .complete) return error.IncompleteBranchAncestry;
    return self.state.result;
}

test {
    _ = @import("branch_ancestry_test.zig");
}
