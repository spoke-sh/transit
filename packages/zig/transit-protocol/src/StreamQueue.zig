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

/// Persistent producer fencing survives detailed receipt expiry. This value is
/// a private candidate until accepted with the append and its original receipt.
pub const ProducerState = struct {
    target: Partition,
    principal: u64,
    producer: Producer,
    discarded_through: u64,

    pub fn validate(self: ProducerState) !void {
        try self.target.validate();
        try self.producer.validate();
        if (self.principal > p.max_counter or self.discarded_through > self.producer.sequence) return error.InvalidLogProducerState;
    }

    pub fn initial(append: Append) !ProducerState {
        try append.validate();
        const producer = append.producer orelse return error.LogProducerRequired;
        if (producer.sequence != 1) return error.LogProducerSequenceGap;
        return .{ .target = append.target, .principal = append.operation.principal, .producer = producer, .discarded_through = 0 };
    }

    /// Original operation lookup precedes this check. A retry classification
    /// still requires the exact accepted receipt; it never admits new payload.
    pub fn check(self: ProducerState, append: Append) !enum { append, advance_epoch, retry } {
        try self.validate();
        try append.validate();
        if (self.target.partition != append.target.partition or !std.meta.eql(self.target.interpretation.object, append.target.interpretation.object)) return error.LogPartitionConflict;
        const producer = append.producer orelse return error.LogProducerRequired;
        if (!std.mem.eql(u8, &self.producer.id, &producer.id) or self.principal != append.operation.principal) return error.LogProducerConflict;
        if (producer.epoch < self.producer.epoch) return error.LogProducerFenced;
        if (producer.epoch > self.producer.epoch) {
            if (producer.sequence != 1) return error.LogProducerSequenceGap;
            return .advance_epoch;
        }
        if (producer.sequence <= self.discarded_through) return error.LogProducerReceiptExpired;
        if (producer.sequence <= self.producer.sequence) return .retry;
        if (producer.sequence - self.producer.sequence != 1) return error.LogProducerSequenceGap;
        return .append;
    }

    pub fn forgetThrough(self: ProducerState, sequence: u64) !ProducerState {
        try self.validate();
        if (sequence < self.discarded_through or sequence > self.producer.sequence) return error.InvalidLogProducerFloor;
        var result = self;
        result.discarded_through = sequence;
        return result;
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

/// Durable assignment and exclusive checkpoint for one object/partition/group.
/// Its definition attributes the last accepted transition, not an implicit grant.
pub const GroupProgress = struct {
    target: Partition,
    group: Group,
    next: u64,

    pub fn validate(self: GroupProgress) !void {
        try self.target.validate();
        try self.group.validate();
    }

    /// The owner must additionally verify its own issued coverage and current
    /// authority. A definition edit preserves the logical group identity.
    pub fn advance(self: GroupProgress, commit: OffsetCommit) !GroupProgress {
        try self.validate();
        try commit.requireCurrent(self.group, self.next);
        const target = commit.coverage.cut.target;
        if (target.partition != self.target.partition or !std.meta.eql(target.interpretation.object, self.target.interpretation.object)) return error.LogPartitionConflict;
        return .{ .target = target, .group = self.group, .next = commit.next };
    }
};

/// Explicit local assignment: an object administrator selects one principal for
/// one group/partition. There is no inferred membership or automatic rebalance.
pub const GroupAssignment = struct {
    operation: d.Operation,
    cut: Cut,
    expected: ?GroupProgress,
    group: Group,
    next: u64,

    pub fn validate(self: GroupAssignment) !void {
        try self.cut.target.requireOperation(self.operation);
        try self.cut.requireOffset(self.next);
        try self.group.validate();
        if (self.cut.accepted.next_lsn == 0) return error.InvalidLogGroupAssignment;
        if (self.expected) |previous| {
            try previous.validate();
            if (previous.target.partition != self.cut.target.partition or
                !std.meta.eql(previous.target.interpretation.object, self.cut.target.interpretation.object)) return error.LogPartitionConflict;
            const generation = std.math.add(u64, previous.group.generation, 1) catch return error.LogGroupGenerationExhausted;
            if (self.group.id != previous.group.id or self.group.generation != generation or self.next != previous.next) return error.InvalidLogGroupAssignment;
        } else if (self.group.generation != 1) return error.InvalidLogGroupAssignment;
    }

    /// Original receipt lookup precedes this fresh-publication check. The owner
    /// supplies its current assignment and verified current cut under one guard.
    /// Appends may extend the observed cut; reclamation may not skip its checkpoint.
    pub fn requireCurrent(self: GroupAssignment, current: ?GroupProgress, cut: Cut) !void {
        try self.validate();
        try self.cut.target.requireSame(cut.target);
        try cut.requireOffset(self.next);
        if (cut.accepted.partition != self.cut.accepted.partition or cut.accepted.next_lsn < self.cut.accepted.next_lsn or cut.next < self.cut.next) return error.LogPartitionConflict;
        if (current) |value| try value.validate();
        if (!std.meta.eql(self.expected, current)) return error.LogGroupAssignmentConflict;
    }

    pub fn resulting(self: GroupAssignment) !GroupProgress {
        try self.validate();
        return .{ .target = self.cut.target, .group = self.group, .next = self.next };
    }
    pub fn requireSame(self: GroupAssignment, other: GroupAssignment) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.LogGroupAssignmentConflict;
    }
};

pub const GroupAssignmentReceipt = struct {
    assignment: GroupAssignment,
    accepted: d.Position,
    pub fn validate(self: GroupAssignmentReceipt) !void {
        try self.assignment.validate();
        try self.accepted.validate();
        if (self.accepted.partition != self.assignment.cut.accepted.partition or self.accepted.next_lsn <= self.assignment.cut.accepted.next_lsn) return error.InvalidLogGroupAssignment;
    }
    pub fn requireAssignment(self: GroupAssignmentReceipt, assignment: GroupAssignment) !void {
        try self.validate();
        try self.assignment.requireSame(assignment);
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

/// The original result remains recoverable after further progress/reassignment.
pub const OffsetReceipt = struct {
    commit: OffsetCommit,
    accepted: d.Position,
    pub fn validate(self: OffsetReceipt) !void {
        try self.commit.validate();
        try self.accepted.validate();
        if (self.accepted.partition != self.commit.coverage.cut.accepted.partition or self.accepted.next_lsn <= self.commit.coverage.cut.accepted.next_lsn) return error.InvalidOffsetReceipt;
    }
    pub fn requireCommit(self: OffsetReceipt, commit: OffsetCommit) !void {
        try self.validate();
        try commit.validate();
        if (!std.meta.eql(self.commit, commit)) return error.LogOffsetConflict;
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

/// Trusted time is supplied by the owner under its decision guard. Persist the
/// accepted floor with outcomes; restart must not reset it to a caller clock.
pub const QueueClock = struct {
    floor_ms: u64,
    pub fn observe(self: QueueClock, trusted_now_ms: ?u64) !u64 {
        const now = trusted_now_ms orelse return error.QueueTimeUnavailable;
        if (now < self.floor_ms) return error.QueueTimeRegression;
        return now;
    }
};

/// A claim has its own frozen identity. An accepted empty selection remains
/// empty on retry; another selection needs another operation, never a restart.
pub const Claim = struct {
    target: Partition,
    operation: d.Operation,
    maximum: u32,
    lease_ms: u64,
    pub fn validate(self: Claim) !void {
        try self.target.requireOperation(self.operation);
        if (self.maximum == 0 or self.lease_ms == 0) return error.InvalidQueueClaim;
    }
    pub fn requireSame(self: Claim, other: Claim) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.QueueClaimConflict;
    }
};

pub const ClaimReceipt = struct {
    claim: Claim,
    accepted: d.Position,
    observed_ms: u64,
    expires_ms: u64,
    rows: u32,
    /// Immutable exact selection and per-message lease epochs/attempts. The
    /// owner verifies every lease against the claim and retains payload access.
    leases: ?d.Content,
    pub fn validate(self: ClaimReceipt) !void {
        try self.claim.validate();
        try self.accepted.validate();
        const expires = std.math.add(u64, self.observed_ms, self.claim.lease_ms) catch return error.QueueLeaseDeadlineOverflow;
        if (self.accepted.next_lsn == 0 or self.rows > self.claim.maximum or (self.rows == 0) != (self.leases == null) or self.expires_ms != expires) return error.InvalidQueueClaimReceipt;
        if (self.leases) |leases| try leases.validate();
    }
    pub fn requireClaim(self: ClaimReceipt, claim: Claim) !void {
        try self.validate();
        try self.claim.requireSame(claim);
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
    declaration: p.StreamQueueDeclaration.Declaration,
    append: AppendReceipt,
    producer: ProducerState,
    offset_commit: OffsetCommit,
    group_progress: GroupProgress,
    group_assignment: GroupAssignmentReceipt,
    offset_receipt: OffsetReceipt,
    claim: ClaimReceipt,
    clock: QueueClock,
    settlement: SettlementReceipt,
};

test {
    _ = @import("stream_queue_test.zig");
}
