//! Retained, bounded two-pass key compaction. A frozen source and private key
//! index determine supersession; only publication changes subsequent reads.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const Declaration = @import("LogDeclaration.zig");
const B = @import("BitmapDirectory.zig");
const pages = @import("TreeStore.zig").pages;
pub const max_rows = 64;

pub const Source = struct {
    declared: Declaration.Stored,
    cut: q.Cut,
    batches: ?pages.Reference,
    segments: ?pages.Reference,
    hidden: B.Root,
    sealed_through: u64,

    pub fn validate(self: Source) !void {
        try self.declared.validate();
        try self.cut.validate();
        try self.hidden.validate();
        if (self.declared.retired or self.declared.declaration.configuration.policy != .stream or
            self.declared.declaration.configuration.policy.stream.compact_key_column == null or
            !std.meta.eql(self.declared.declaration.interpretation, self.cut.target.interpretation) or
            self.cut.target.partition >= self.declared.declaration.configuration.partitioning.count or
            self.cut.accepted.next_lsn == 0 or self.sealed_through < self.cut.retained_from or self.sealed_through > self.cut.next or
            (self.batches != null) != (self.cut.next != self.cut.retained_from) or
            (self.segments != null) != (self.sealed_through != self.cut.retained_from) or self.hidden.cardinality > self.cut.next) return error.InvalidStreamCompaction;
    }
};

pub const Phase = enum { index, mark, ready };
pub const State = struct {
    source: Source,
    protected_next: u64,
    phase: Phase,
    next: u64,
    latest: ?pages.Reference,
    candidate: B.Root,

    pub fn init(source: Source, protected_next: u64) !State {
        const state: State = .{ .source = source, .protected_next = protected_next, .phase = .index, .next = source.cut.retained_from, .latest = null, .candidate = source.hidden };
        try state.validate();
        return state;
    }
    pub fn until(self: State) u64 {
        return if (self.phase == .index) self.source.cut.next else @min(self.protected_next, self.source.sealed_through);
    }
    pub fn validate(self: State) !void {
        try self.source.validate();
        try self.candidate.validate();
        if (self.source.cut.retained_from >= self.source.cut.next or
            self.protected_next < self.source.cut.retained_from or self.protected_next > self.source.cut.next or
            self.next < self.source.cut.retained_from or self.next > self.until() or
            self.candidate.cardinality < self.source.hidden.cardinality or self.candidate.cardinality > self.source.cut.next or
            (self.phase == .index and !std.meta.eql(self.candidate, self.source.hidden)) or
            (self.phase == .ready and self.next != self.until()) or
            ((self.phase != .index or self.next != self.source.cut.retained_from) and self.latest == null)) return error.InvalidStreamCompaction;
    }
    pub fn advance(self: *State, through: u64) !void {
        if (self.phase == .ready or through <= self.next or through > self.until() or through - self.next > max_rows) return error.InvalidStreamCompaction;
        self.next = through;
        if (through == self.until()) switch (self.phase) {
            .index => {
                self.phase = .mark;
                self.next = self.source.cut.retained_from;
                if (self.next == self.until()) self.phase = .ready;
            },
            .mark => self.phase = .ready,
            .ready => unreachable,
        };
        try self.validate();
    }
};

/// OrderedKeyIndex stores opaque 32-byte values. Padding has one canonical
/// shape; a key match, never an offset or digest alone, proves supersession.
pub fn encodeOffset(offset: u64) [32]u8 {
    var bytes: [32]u8 = @splat(0);
    std.mem.writeInt(u64, bytes[0..8], offset, .big);
    return bytes;
}
pub fn decodeOffset(bytes: [32]u8, from: u64, until: u64) !u64 {
    const offset = std.mem.readInt(u64, bytes[0..8], .big);
    if (!std.mem.allEqual(u8, bytes[8..], 0) or offset < from or offset >= until) return error.InvalidStreamCompaction;
    return offset;
}

pub const Progress = struct {
    cut: d.Position,
    position: d.Position,
    next: u64,
    examined: u32,
    hidden: u64,
    status: enum { progress, complete, consumer, unsealed },
};
