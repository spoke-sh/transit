//! Bounded recovery-root enumeration at an accepted log cut. Only a completed
//! walk establishes its hash-linked coverage; emitted roots grant no deletion
//! authority and must remain retained by the enclosing collection owner.
const std = @import("std");
const r = @import("LogPartitionRecord.zig");
const I = @import("LogInitialization.zig");
const Recovery = @import("LogRecovery.zig");
const History = @import("LogHistory.zig");
const Evidence = @import("LogEvidence.zig");
const Store = @import("TreeStore.zig");
const Log = @import("TransitLog.zig");
const Self = @This();
pub const Step = union(enum) {
    current: r.Root,
    checkpoint: struct { reference: Recovery.Reference, basis: Recovery.Basis },
    initialization: I.Evidence,
    frame: r.Record,
    complete,
};
cut: Recovery.Basis,
phase: enum { current, baseline, frames, complete } = .current,
next_lsn: u64 = 1,
previous: [32]u8 = @splat(0),
baseline: ?Recovery.Basis = null,

pub fn init(cut: Recovery.Basis) !Self {
    try cut.validate();
    return .{ .cut = cut };
}
pub fn next(self: *Self, allocator: std.mem.Allocator, index: *Store, log: Log.Log) !Step {
    const before = self.*;
    errdefer self.* = before;
    const cut = self.cut.root;
    switch (self.phase) {
        .current => {
            self.phase = .baseline;
            return .{ .current = cut };
        },
        .baseline => {
            self.phase = .frames;
            if (cut.recovery) |reference| {
                const basis = try Recovery.load(allocator, index.store, reference, cut.next_lsn, cut.initialization);
                if (basis.root.next_offset > cut.next_offset or basis.root.retained_from > cut.retained_from) return error.InvalidLogStorageGraph;
                self.baseline = basis;
                self.next_lsn = reference.next_lsn;
                self.previous = basis.commitment;
                return .{ .checkpoint = .{ .reference = reference, .basis = basis } };
            }
            var batch = try log.read(allocator, cut.initialization.partition, 0, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.LogInitializationMissing;
            const initialized = try I.decode(allocator, batch.frames[0]);
            try cut.initialization.requireSame(initialized.request);
            self.previous = initialized.record.sha256;
            if (cut.next_lsn == 1) {
                if (!std.meta.eql(cut, try r.Root.initial(initialized.request)) or !std.mem.eql(u8, &self.previous, &self.cut.commitment)) return error.InvalidLogStorageGraph;
                self.phase = .complete;
            }
            return .{ .initialization = initialized };
        },
        .frames => {
            if (self.next_lsn == 0 or self.next_lsn >= cut.next_lsn) return error.InvalidLogStorageGraph;
            var batch = if (self.next_lsn < cut.archive.through)
                try History.read(allocator, index, cut.archive, cut.initialization.partition, self.next_lsn)
            else
                try log.read(allocator, cut.initialization.partition, self.next_lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.LogHistoryUnavailable;
            const frame = batch.frames[0];
            const record = (try r.decode(allocator, frame, cut.initialization.partition, self.next_lsn)).record;
            try cut.initialization.requireSame(record.root.initialization);
            if (!std.mem.eql(u8, &self.previous, &record.previous) or record.root.next_offset > cut.next_offset or record.root.retained_from > cut.retained_from or !std.meta.eql(record.root.recovery, cut.recovery)) return error.InvalidLogStorageGraph;
            if (self.baseline) |basis| if (self.next_lsn == basis.root.next_lsn) try Recovery.requirePublication(basis, cut.recovery.?, record);
            const commitment = Evidence.hash(frame.payload);
            if (record.root.next_lsn == cut.next_lsn) {
                if (!std.meta.eql(record.root, cut) or !std.mem.eql(u8, &commitment, &self.cut.commitment)) return error.InvalidLogStorageGraph;
                self.phase = .complete;
            }
            self.previous = commitment;
            self.next_lsn = record.root.next_lsn;
            return .{ .frame = record };
        },
        .complete => return .complete,
    }
}
