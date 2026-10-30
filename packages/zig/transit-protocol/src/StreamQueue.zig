//! Neutral Stream/Queue operation bindings. These types establish attribution,
//! not catalog membership, authorization, payload durability or executable APIs.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

/// A logical partition ordinal, independent of its physical WAL partition ID.
pub const Partition = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    partition: u32,

    pub fn validate(self: Partition) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1) return error.UnsupportedTransactionDomain;
    }

    pub fn requireSame(self: Partition, other: Partition) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.LogPartitionConflict;
    }

    pub fn requireOperation(self: Partition, operation: d.Operation) !void {
        try self.validate();
        try operation.validate();
        if (!std.meta.eql(self.interpretation.object.scope, operation.scope)) return error.LogPartitionConflict;
    }
};

/// Sequence identifies one batch, not one row. Producer fencing is independent
/// of worker activation and the operation token. The owner retains sequence
/// floors even after detailed duplicate receipts become eligible for expiry.
pub const Producer = struct {
    id: [16]u8,
    epoch: u64,
    sequence: u64,

    pub fn validate(self: Producer) !void {
        if (std.mem.allEqual(u8, &self.id, 0) or self.epoch == 0 or self.sequence == 0)
            return error.InvalidLogProducer;
    }
};

/// One partition's frozen append. Larger row collections live in immutable
/// content, never an in-memory array inside this operation binding.
pub const Append = struct {
    target: Partition,
    operation: d.Operation,
    kind: enum { stream, queue },
    producer: ?Producer,
    rows: u64,
    payload: d.Content,

    pub fn validate(self: Append) !void {
        try self.target.requireOperation(self.operation);
        try self.payload.validate();
        if (self.rows == 0) return error.InvalidLogAppend;
        if (self.producer) |producer| try producer.validate();
    }

    pub fn requireSame(self: Append, other: Append) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.LogAppendConflict;
    }
};

pub const AppendReceipt = struct {
    append: Append,
    /// Logical half-open offset range; never derived from physical WAL LSNs.
    first: u64,
    next: u64,
    accepted: d.Position,

    pub fn validate(self: AppendReceipt) !void {
        try self.append.validate();
        try self.accepted.validate();
        if (self.next <= self.first or self.next - self.first != self.append.rows or
            self.accepted.next_lsn == 0) return error.InvalidLogAppendReceipt;
    }

    pub fn requireAppend(self: AppendReceipt, append: Append) !void {
        try self.validate();
        try self.append.requireSame(append);
    }
};

/// Describes one retained range. Only its owner can prove a live retention pin.
/// Filtered/key-compacted records may leave holes within the logical range.
pub const Cut = struct {
    target: Partition,
    accepted: d.Position,
    retained_from: u64,
    next: u64,

    pub fn validate(self: Cut) !void {
        try self.target.validate();
        try self.accepted.validate();
        if (self.retained_from > self.next) return error.InvalidLogCut;
    }

    pub fn requireOffset(self: Cut, offset: u64) !void {
        try self.validate();
        if (offset < self.retained_from) return error.LogHistoryUnavailable;
        if (offset > self.next) return error.LogOffsetBeyondCut;
    }
};

/// Verified traversal coverage is distinct from filtered output cardinality.
/// Completion covers the requested finite range, not the live unbounded log.
pub const Coverage = struct {
    cut: Cut,
    from: u64,
    until: u64,
    through: u64,
    rows: u64,
    complete: bool,

    pub fn validate(self: Coverage) !void {
        try self.cut.requireOffset(self.from);
        try self.cut.requireOffset(self.until);
        if (self.from > self.through or self.through > self.until or
            self.rows > self.through - self.from or
            self.complete != (self.through == self.until)) return error.InvalidLogCoverage;
    }
};

/// Group identity is scoped to the target object. Generation fences assignment;
/// it cannot be replaced with the worker's local connection/session identity.
pub const Group = struct {
    id: u64,
    generation: u64,
    principal: u64,

    pub fn validate(self: Group) !void {
        if (self.id == 0 or self.generation == 0 or self.principal > p.max_counter)
            return error.InvalidLogGroup;
    }
};

pub const OffsetCommit = struct {
    operation: d.Operation,
    group: Group,
    coverage: Coverage,
    expected_next: u64,
    next: u64,

    pub fn validate(self: OffsetCommit) !void {
        try self.coverage.validate();
        try self.coverage.cut.target.requireOperation(self.operation);
        try self.group.validate();
        if (self.operation.principal != self.group.principal or
            !self.coverage.complete or self.coverage.from != self.expected_next or
            self.next != self.coverage.until) return error.InvalidOffsetCommit;
    }

    /// Called under the owner's publication guard after checking current rights
    /// and that coverage was issued by that owner. Exact accepted retry lookup
    /// precedes this fresh-publication check.
    pub fn requireCurrent(self: OffsetCommit, group: Group, next: u64) !void {
        try self.validate();
        try group.validate();
        if (!std.meta.eql(self.group, group)) return error.LogGroupFenced;
        if (self.expected_next != next) return error.LogOffsetConflict;
    }
};

/// Durable lease identity. This is the signed receipt's semantic body, not an
/// authenticated bearer credential or evidence that a claim was accepted.
pub const Lease = struct {
    target: Partition,
    claim: d.Operation,
    offset: u64,
    epoch: u64,
    attempt: u64,
    expires_ms: u64,

    pub fn validate(self: Lease) !void {
        try self.target.requireOperation(self.claim);
        if (self.offset == std.math.maxInt(u64) or self.epoch == 0 or
            self.attempt == 0 or self.expires_ms == 0) return error.InvalidQueueLease;
    }

    /// The owner supplies authoritative time under the same guard as the
    /// decision. Expired-but-not-reassigned leases fail too. Unknown time is not
    /// evidence that a lease remains live. Renewal replaces the exact receipt.
    pub fn requireLive(self: Lease, current: Lease, now_ms: ?u64) !void {
        try self.validate();
        try current.validate();
        if (!std.meta.eql(self, current)) return error.QueueLeaseFenced;
        const now = now_ms orelse return error.QueueTimeUnavailable;
        if (now >= self.expires_ms) return error.QueueLeaseExpired;
    }
};

pub const Settlement = struct {
    operation: d.Operation,
    lease: Lease,
    action: union(enum) {
        ack: void,
        nack: struct { visible_ms: u64 },
        extend: struct { expires_ms: u64 },
    },

    pub fn validate(self: Settlement) !void {
        try self.lease.validate();
        try self.lease.target.requireOperation(self.operation);
        if (self.operation.principal != self.lease.claim.principal or
            self.operation.operation == self.lease.claim.operation) return error.InvalidQueueSettlement;
        switch (self.action) {
            .ack, .nack => {},
            .extend => |extend| if (extend.expires_ms <= self.lease.expires_ms) return error.InvalidQueueSettlement,
        }
    }

    pub fn requireSame(self: Settlement, other: Settlement) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.QueueSettlementConflict;
    }

    pub fn requireLive(self: Settlement, current: Lease, now_ms: ?u64) !void {
        try self.validate();
        try self.lease.requireLive(current, now_ms);
    }
};

/// Publication evidence supports original retry even after the lease expires.
/// The owner separately authorizes disclosure and verifies this receipt's log.
pub const SettlementReceipt = struct {
    settlement: Settlement,
    accepted: d.Position,

    pub fn validate(self: SettlementReceipt) !void {
        try self.settlement.validate();
        try self.accepted.validate();
        if (self.accepted.next_lsn == 0) return error.InvalidQueueSettlementReceipt;
    }

    pub fn requireSettlement(self: SettlementReceipt, settlement: Settlement) !void {
        try self.validate();
        try self.settlement.requireSame(settlement);
    }
};

pub const SchemaTypes = struct {
    append: AppendReceipt,
    offset_commit: OffsetCommit,
    settlement: SettlementReceipt,
};

test {
    _ = @import("stream_queue_test.zig");
}
