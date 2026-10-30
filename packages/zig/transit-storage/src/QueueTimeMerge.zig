//! Bounded, resumable merge of two immutable scheduling runs. Every returned
//! state and output root is private until the Queue owner accepts its decision.
const std = @import("std");
const p = @import("transit_protocol");
const Store = @import("TreeStore.zig");
const Run = @import("QueueTimeRun.zig");
const Directory = @import("QueueTimeDirectory.zig");
const Self = @This();

/// A filter must examine this frozen Queue state, never a moving current root.
/// Retaining these roots is the publishing owner's responsibility.
pub const Basis = struct {
    items: ?Store.pages.Reference,
    sidecars: ?Store.pages.Reference,
    next_offset: u64,
    pub fn validate(self: Basis) !void {
        if ((self.next_offset == 0) != (self.items == null) or (self.items == null) != (self.sidecars == null)) return error.InvalidQueueTimeMerge;
    }
};
pub const Position = struct {
    rows: u64,
    chunks: u64,
    after: ?Run.Event,
    complete: bool,
    pub const initial: Position = .{ .rows = 0, .chunks = 0, .after = null, .complete = false };
    fn validate(self: Position, root: Directory.Root) !void {
        if (self.rows > root.rows or self.chunks > root.chunks or self.chunks > self.rows or
            (self.rows == 0) != (self.after == null)) return error.InvalidQueueTimeMerge;
        if (self.after) |after| {
            if (Run.Event.less(after, root.first.?) or Run.Event.less(root.last.?, after) or
                (self.rows == root.rows and !std.meta.eql(after, root.last.?))) return error.InvalidQueueTimeMerge;
        }
        if (self.rows == root.rows and self.chunks != root.chunks) return error.InvalidQueueTimeMerge;
        if (self.complete and self.rows != root.rows) return error.InvalidQueueTimeMerge;
    }
};
pub const State = struct {
    seed: p.StreamQueue.Partition,
    kind: Run.Kind,
    bucket: u64,
    basis: Basis,
    sources: [2]Directory.Root,
    positions: [2]Position,
    output: Directory.Root,
    discarded: u64,
    last: ?Run.Event,
    complete: bool,

    pub fn init(seed: p.StreamQueue.Partition, kind: Run.Kind, bucket: u64, basis: Basis, sources: [2]Directory.Root) !State {
        const result: State = .{ .seed = seed, .kind = kind, .bucket = bucket, .basis = basis, .sources = sources, .positions = @splat(.initial), .output = .empty, .discarded = 0, .last = null, .complete = false };
        try result.validate();
        return result;
    }
    pub fn validate(self: State) !void {
        try self.seed.validate();
        try self.basis.validate();
        if (self.seed.interpretation.revision != 1 or self.bucket > std.math.maxInt(u64) >> Run.bucket_bits) return error.InvalidQueueTimeMerge;
        _ = std.math.add(u64, self.sources[0].rows, self.sources[1].rows) catch return error.InvalidQueueTimeMerge;
        for (self.sources ++ [_]Directory.Root{self.output}) |root| {
            try root.validate();
            if (root.first) |first| {
                try first.validate(self.kind);
                try root.last.?.validate(self.kind);
                if (first.bucket() != self.bucket or root.last.?.bucket() != self.bucket) return error.InvalidQueueTimeMerge;
            }
        }
        var last: ?Run.Event = null;
        for (self.positions, self.sources) |position, root| {
            try position.validate(root);
            if (position.after) |after| if (last == null or Run.Event.less(last.?, after)) {
                last = after;
            };
        }
        const consumed = self.positions[0].rows + self.positions[1].rows;
        if (self.discarded > consumed or self.output.rows != consumed - self.discarded or
            !std.meta.eql(last, self.last) or self.complete != (self.positions[0].complete and self.positions[1].complete)) return error.InvalidQueueTimeMerge;
        if (self.output.last) |output_last| if (self.last == null or Run.Event.less(self.last.?, output_last)) return error.InvalidQueueTimeMerge;
    }
};

/// Preallocate with the owning maintenance workspace, independently of backlog.
pub const Workspace = struct {
    inputs: [2][Run.max_rows]Run.Event,
    output: [Run.max_rows]Run.Event,
    encoded: [Run.max_bytes]u8,
};
store: *Store,
scratch: *std.heap.ArenaAllocator,
workspace: *Workspace,

const Reader = struct {
    directory: Directory,
    root: Directory.Root,
    position: Position,
    scratch: *std.heap.ArenaAllocator,
    events: []Run.Event,
    loaded: ?Directory.Entry = null,

    fn finish(self: *Reader) !void {
        if (self.position.complete) return;
        if (self.position.rows != self.root.rows) return;
        if (try self.directory.find(self.root, self.position.after) != null or
            self.position.chunks != self.root.chunks or !std.meta.eql(self.position.after, self.root.last)) return error.InvalidQueueTimeMerge;
        self.position.complete = true;
    }
    fn peek(self: *Reader) !?Run.Event {
        try self.finish();
        if (self.position.complete) return null;
        const need_load = if (self.loaded) |entry| self.position.rows >= entry.first_row + entry.chunk.rows else true;
        if (need_load) {
            const entry = try self.directory.find(self.root, self.position.after) orelse return error.InvalidQueueTimeMerge;
            if (entry.first_row > self.position.rows or self.position.rows >= entry.first_row + entry.chunk.rows or
                self.position.chunks == self.root.chunks) return error.InvalidQueueTimeMerge;
            if (self.loaded != null and entry.first_row != self.position.rows) return error.InvalidQueueTimeMerge;
            defer _ = self.scratch.reset(.retain_capacity);
            _ = try Run.load(self.scratch.allocator(), self.directory.store.store, entry.chunk, self.events);
            const index: usize = @intCast(self.position.rows - entry.first_row);
            if (index == 0) {
                if (self.position.after) |after| if (!Run.Event.less(after, self.events[0])) return error.InvalidQueueTimeMerge;
            } else if (!std.meta.eql(self.position.after, @as(?Run.Event, self.events[index - 1]))) return error.InvalidQueueTimeMerge;
            self.loaded = entry;
        }
        const entry = self.loaded.?;
        return self.events[@intCast(self.position.rows - entry.first_row)];
    }
    fn take(self: *Reader) !Run.Event {
        const event = try self.peek() orelse return error.InvalidQueueTimeMerge;
        self.position.rows += 1;
        self.position.after = event;
        if (self.position.rows == self.loaded.?.first_row + self.loaded.?.chunk.rows) self.position.chunks += 1;
        return event;
    }
};

/// Consumes at most `budget` input rows, including duplicates and filtered rows,
/// and stages at most one bounded output chunk. `filter.keep(basis, kind, event)`
/// must be deterministic over the frozen basis; errors preserve the input State.
/// A budget boundary is progress, never evidence of exhausted source coverage.
pub fn step(self: Self, before: State, serial: u64, budget: u16, filter: anytype) !State {
    try before.validate();
    if (serial == 0 or budget == 0 or budget > Run.max_rows) return error.InvalidQueueTimerBudget;
    if (before.complete) return before;
    const directory: Directory = .{ .store = self.store, .seed = before.seed, .kind = before.kind, .bucket = before.bucket };
    var readers: [2]Reader = undefined;
    for (&readers, before.sources, before.positions, &self.workspace.inputs) |*reader, root, position, *events| reader.* = .{ .directory = directory, .root = root, .position = position, .scratch = self.scratch, .events = events };
    var next = before;
    var count: usize = 0;
    for (0..budget) |_| {
        const left = try readers[0].peek();
        const right = try readers[1].peek();
        const selected: usize = if (left == null) (if (right == null) break else 1) else if (right != null and Run.Event.less(right.?, left.?)) 1 else 0;
        const event = try readers[selected].take();
        if (next.last) |last| if (Run.Event.less(event, last)) return error.InvalidQueueTimeMerge;
        const duplicate = std.meta.eql(next.last, @as(?Run.Event, event));
        if (!duplicate and try filter.keep(before.basis, before.kind, event)) {
            self.workspace.output[count] = event;
            count += 1;
        } else next.discarded += 1;
        next.last = event;
    }
    // Exhaustion requires a real directory check, but does not load an extra
    // payload chunk just to speculate about the next step.
    for (&readers, &next.positions) |*reader, *position| {
        try reader.finish();
        position.* = reader.position;
    }
    if (count != 0) {
        defer _ = self.scratch.reset(.retain_capacity);
        const chunk = try Run.stage(self.scratch.allocator(), self.store.store, before.seed, before.kind, serial, self.workspace.output[0..count], &self.workspace.encoded);
        next.output = try directory.append(before.output, chunk);
    }
    next.complete = next.positions[0].complete and next.positions[1].complete;
    try next.validate();
    return next;
}
