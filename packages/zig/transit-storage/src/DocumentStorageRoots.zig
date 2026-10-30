//! Bounded enumeration of retained Document storage roots for a fixed partition cut.
//! Mirrors `LogStorageRoots` so `DirectStorageGraph` can walk Document partitions
//! without unbounded recursion or unverified checkpoints.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Initialization = @import("DocumentInitialization.zig");
const Records = @import("DocumentPartitionRecord.zig");
const Recovery = @import("DocumentRecovery.zig");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");

pub const Step = union(enum) {
    empty: Initialization.Request,
    root: Records.Root,
    complete: void,
};

pub const Cursor = struct {
    initialization: Initialization.Request,
    end: u64,
    next_lsn: u64 = 1,
    expected_commitment: [32]u8 = @splat(0),
    latest: ?Records.Decoded = null,
    phase: enum { init, baseline, replay, done } = .init,

    pub fn init(initialization: Initialization.Request, end: u64) !Cursor {
        try initialization.validate();
        if (end == 0) return error.DocumentInitializationMissing;
        return .{ .initialization = initialization, .end = end };
    }

    pub fn step(
        self: *Cursor,
        allocator: std.mem.Allocator,
        log: Log.Log,
        objects: Objects.ObjectStore,
    ) !Step {
        switch (self.phase) {
            .done => return .complete,
            .init => {
                if (self.end == 1) {
                    const genesis = try Initialization.readStored(allocator, log, objects, self.initialization);
                    self.expected_commitment = genesis.record.sha256;
                    self.phase = .done;
                    return .{ .empty = self.initialization };
                }
                const latest = try decodeAt(allocator, log, self.initialization.partition, self.end - 1);
                try self.initialization.requireSame(latest.record.root.initialization);
                self.latest = latest;
                if (latest.record.root.recovery != null) {
                    self.phase = .baseline;
                    return .{ .root = latest.record.root };
                }
                const genesis = try Initialization.readStored(allocator, log, objects, self.initialization);
                self.expected_commitment = genesis.record.sha256;
                self.next_lsn = 1;
                self.phase = .replay;
                return .{ .root = latest.record.root };
            },
            .baseline => {
                const reference = self.latest.?.record.root.recovery.?;
                const basis = try Recovery.load(allocator, objects, reference, self.end, self.initialization);
                const publication = try decodeAt(allocator, log, self.initialization.partition, reference.next_lsn);
                try Recovery.requirePublication(basis, reference, publication.record);
                self.expected_commitment = publication.commitment;
                self.next_lsn = reference.next_lsn + 1;
                self.phase = .replay;
                return .{ .root = basis.root };
            },
            .replay => {
                if (self.next_lsn >= self.end) {
                    const latest = self.latest orelse return error.InvalidDocumentPartitionRecord;
                    if (!std.mem.eql(u8, &self.expected_commitment, &latest.commitment)) {
                        return error.InvalidDocumentPartitionRecord;
                    }
                    self.phase = .done;
                    return .complete;
                }
                const decoded = try decodeAt(allocator, log, self.initialization.partition, self.next_lsn);
                try self.initialization.requireSame(decoded.record.root.initialization);
                if (!std.mem.eql(u8, &decoded.record.previous_commitment, &self.expected_commitment)) {
                    return error.InvalidDocumentPartitionRecord;
                }
                self.expected_commitment = decoded.commitment;
                self.next_lsn += 1;
                return .{ .root = decoded.record.root };
            },
        }
    }

    fn decodeAt(allocator: std.mem.Allocator, log: Log.Log, partition: u64, lsn: u64) !Records.Decoded {
        var batch = try log.read(allocator, partition, lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.InvalidDocumentPartitionRecord;
        return Records.decode(allocator, batch.frames[0], partition, lsn);
    }
};
