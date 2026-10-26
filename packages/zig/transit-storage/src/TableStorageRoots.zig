//! Bounded history/recovery root enumeration at a caller-retained accepted cut.
//! A complete hash-linked traversal is required before its marks can support
//! collection. Live pins and their history anchors are separate graph edges;
//! this component neither selects all owners nor grants deletion authority.
const std = @import("std");
const r = @import("TablePartitionRecord.zig");
const Recovery = @import("TableRecovery.zig");
const Archive = @import("TableArchive.zig");
const Store = @import("TreeStore.zig");
const Log = @import("TransitLog.zig");
const Self = @This();

pub const Role = enum {
    /// Current control/data directories and live pins own their dependencies.
    current,
    /// Replay can inspect control directories and pin/release metadata.
    recovery,
    /// Historical reads own data/definition roots, not old pin/control graphs.
    history,
};
pub const Step = union(enum) {
    current: r.Root,
    checkpoint: struct { reference: Recovery.Reference, basis: Recovery.Basis },
    frame: struct { record: r.Record, role: Role },
    progress,
    complete,
};
cut: Recovery.Basis,
phase: enum { current, checkpoint, frames, complete } = .current,
next_lsn: u64,
previous: ?[32]u8 = null,
baseline: ?Recovery.Basis = null,

/// The caller obtains this cut from a recovered accepted Table owner and keeps
/// its storage available. A fabricated root or staged capsule is not authority.
pub fn init(cut: Recovery.Basis) !Self {
    try cut.root.validate();
    if (cut.root.next_lsn == 0 or (cut.root.history_floor != 0 and
        (cut.root.recovery == null or cut.root.history_floor > cut.root.recovery.?.next_lsn))) return error.InvalidTableStorageGraph;
    return .{ .cut = cut, .next_lsn = cut.root.history_floor };
}

/// One bounded capsule or frame is loaded per step. No returned value borrows
/// the read buffer. A failed step leaves every cursor field unchanged.
pub fn next(self: *Self, allocator: std.mem.Allocator, index: *Store, log: Log.Log) !Step {
    const before = self.*;
    errdefer self.* = before;
    const cut = self.cut.root;
    switch (self.phase) {
        .current => {
            self.phase = .checkpoint;
            return .{ .current = cut };
        },
        .checkpoint => {
            if (cut.recovery) |reference| {
                const basis = try Recovery.load(allocator, index.store, reference, cut.next_lsn, cut.partition, cut.interpretation.object);
                if (basis.root.history_floor > cut.history_floor or basis.root.next_segment > cut.next_segment or
                    basis.root.changed_lsn > cut.changed_lsn) return error.InvalidTableStorageGraph;
                self.baseline = basis;
                if (self.next_lsn == basis.root.next_lsn) self.previous = basis.chain;
                self.phase = .frames;
                // Its superseded recovery reference is structural history,
                // never another capsule to recursively open.
                return .{ .checkpoint = .{ .reference = reference, .basis = basis } };
            }
            self.phase = .frames;
            return .progress;
        },
        .frames => {
            if (self.next_lsn < cut.history_floor or self.next_lsn >= cut.next_lsn) return error.InvalidTableStorageGraph;
            var batch = if (self.next_lsn < cut.archive.through)
                try Archive.read(allocator, index, cut.archive, cut.partition, self.next_lsn)
            else
                try log.read(allocator, cut.partition, self.next_lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.TableHistoryMissing;
            const frame = batch.frames[0];
            const decoded = try r.decodeFrame(allocator, frame, cut.partition, self.next_lsn);
            const record = decoded.record;
            const digest = r.hash(frame.payload);
            if (!std.meta.eql(record.root.interpretation.object, cut.interpretation.object) or
                record.root.next_segment > cut.next_segment or record.root.changed_lsn > cut.changed_lsn or
                record.root.history_floor > cut.history_floor) return error.InvalidTableStorageGraph;
            if (self.previous) |previous| if (!std.mem.eql(u8, &previous, &record.previous)) return error.InvalidTableHistory;
            if (self.next_lsn == 0 and !std.mem.allEqual(u8, &record.previous, 0)) return error.InvalidTableHistory;
            if (self.baseline) |baseline| {
                if (record.root.next_lsn == baseline.root.next_lsn and
                    (!std.meta.eql(record.root, baseline.root) or !std.mem.eql(u8, &digest, &baseline.chain))) return error.InvalidTableRecovery;
                if (self.next_lsn >= baseline.root.next_lsn and
                    (!std.meta.eql(record.root.recovery, cut.recovery) or
                        (self.next_lsn == baseline.root.next_lsn and record.action != .recovery))) return error.InvalidTableRecovery;
            }
            if (record.root.next_lsn == cut.next_lsn) {
                if (!std.meta.eql(record.root, cut) or !std.mem.eql(u8, &digest, &self.cut.chain)) return error.InvalidTableHistory;
                self.phase = .complete;
            }
            self.previous = digest;
            self.next_lsn = record.root.next_lsn;
            return .{ .frame = .{ .record = record, .role = if (self.baseline == null or frame.header.lsn >= self.baseline.?.root.next_lsn) .recovery else .history } };
        },
        .complete => return .complete,
    }
}
