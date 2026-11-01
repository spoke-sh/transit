//! Neutral local transaction identities and decision evidence. Shape validation
//! does not acquire a consistent cut, authorize work or prove durable acceptance.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const q = p.StreamQueue;

pub const StateKind = enum { table, kv, document };
pub const LogKind = enum { stream, queue };

/// Stable physical-owner selection. A logical log partition ordinal is never a
/// WAL partition ID. State objects have one selected owner and no ordinal.
pub const Target = struct {
    object: d.Object,
    kind: enum { table, kv, document, stream, queue },
    partition: ?u32,

    pub fn validate(self: Target) !void {
        try self.object.validate();
        if ((self.kind == .stream or self.kind == .queue) != (self.partition != null))
            return error.InvalidTransactionTarget;
    }

    pub fn order(self: Target, other: Target) std.math.Order {
        const object = std.math.order(self.object.object, other.object.object);
        if (object != .eq) return object;
        if (self.partition == null) return if (other.partition == null) .eq else .lt;
        if (other.partition == null) return .gt;
        return std.math.order(self.partition.?, other.partition.?);
    }
};

/// Owner-issued retention evidence. The descriptor alone does not establish a
/// live pin; its owner verifies the referenced record and exact guarded basis.
pub const Pin = struct { owner: d.Operation, content: d.Content };

pub const Identity = struct {
    begin: d.Operation,
    branch: u64,

    pub fn validate(self: Identity) !void {
        try self.begin.validate();
        if (self.branch != 1) return error.UnsupportedTransactionDomain;
    }

    pub fn requireObject(self: Identity, object: d.Object) !void {
        try self.validate();
        try object.validate();
        if (!std.meta.eql(self.begin.scope, object.scope) or self.branch != object.branch)
            return error.TransactionIdentityConflict;
    }
};

/// An immutable, paged directory commitment. Count is durable cardinality, not
/// an array capacity. Even an empty directory has an encoded header and digest.
pub const Directory = struct {
    content: d.Content,
    count: u64,

    pub fn validate(self: Directory) !void {
        try self.content.validate();
    }
};

/// Definitive refusal of a frozen caller command before native work admission.
pub const CallRefusal = enum { stale_workspace, statement_conflict, control_conflict, transaction_closed, unsupported_scope, identity_conflict };

pub const Mode = enum { serializable, read_only };
pub const Selection = enum { explicit_objects, authorized_catalog_tables };

/// Per-transaction admission limits, distinct from result/disclosure reserves.
/// Expiry is a request to settle/close, never evidence of an abort decision.
pub const Limits = struct {
    resident_bytes: u64,
    workspace_bytes: u64,
    participants: u64,
    statements: u64,
    savepoints: u32,

    pub fn validate(self: Limits) !void {
        if (self.resident_bytes == 0 or self.workspace_bytes == 0 or
            self.participants == 0 or self.statements == 0 or self.savepoints == 0)
            return error.InvalidTransactionLimits;
    }
};

pub const Begin = struct {
    definition: p.Growth.Definition,
    identity: Identity,
    mode: Mode,
    selection: Selection,
    /// Exact selected identities and interpretations, frozen before pinning.
    objects: Directory,
    /// Name/definition directory observation; never a data commit position.
    catalog: d.Position,
    limits: Limits,

    pub fn validate(self: Begin) !void {
        try self.identity.validate();
        try self.objects.validate();
        try self.catalog.validate();
        try self.limits.validate();
        if (self.catalog.next_lsn == 0 or self.objects.count > self.limits.participants)
            return error.InvalidTransactionBegin;
    }

    pub fn requireSame(self: Begin, other: Begin) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.TransactionIdentityConflict;
    }
};

/// Publication follows complete acquisition under all selected guards. A value
/// supplied by a caller is not evidence that those guards or pins existed.
pub const Cut = struct {
    begin: Begin,
    sources: Directory,
    acquired: d.Position,

    pub fn validate(self: Cut) !void {
        try self.begin.validate();
        try self.sources.validate();
        try self.acquired.validate();
        if (self.sources.count != self.begin.objects.count or self.acquired.next_lsn == 0)
            return error.IncompleteTransactionCut;
    }
};

/// Explicit recovery material for a temporary caller attachment. It grants no
/// authority and never substitutes a new transaction for the original token.
pub const Handle = struct {
    definition: p.Growth.Definition,
    identity: Identity,
    account: [32]u8,
    token: [16]u8,
    audience: u64,
    role: ?u64,
    pub fn validate(self: Handle) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        if (std.mem.allEqual(u8, &self.account, 0) or self.audience == 0 or self.audience > p.max_counter) return error.InvalidTransactionHandle;
        if (self.role) |role| if (role > p.max_counter) return error.InvalidTransactionHandle;
    }
};

/// An exact private read over the original common cut. Base Table positions
/// remain public acceptance positions; private bytes never acquire a commit LSN.
/// The owner validates membership, live original pins and the current revision.
pub const ReadView = struct {
    cut: Cut,
    revision: d.Position,
    last_statement: u64,
    source: StateGuard,
    /// Virtual evaluator position used by private DML guards. This is not an
    /// accepted public WAL position; only the common decision publishes data.
    private_position: d.Position,
    private: d.Content,

    pub fn validate(self: ReadView) !void {
        try self.cut.validate();
        try self.revision.validate();
        try self.source.validate();
        try self.private_position.validate();
        if (self.private_position.partition != self.source.source.accepted.partition or self.private_position.next_lsn < self.source.source.accepted.next_lsn) return error.InvalidTransactionRead;
        try self.private.validate();
        try self.cut.begin.identity.requireObject(self.source.source.interpretation.object);
        if (self.cut.acquired.partition != self.cut.begin.catalog.partition or self.cut.acquired.next_lsn <= self.cut.begin.catalog.next_lsn or
            self.revision.partition != self.cut.acquired.partition or
            self.revision.next_lsn < self.cut.acquired.next_lsn or
            self.last_statement > self.cut.begin.limits.statements)
            return error.InvalidTransactionRead;
    }
};

/// One selected Table's immutable basis and logical conflict frontier. The pin
/// receipt and physical accepted frontier may advance without a logical change.
pub const StateGuard = struct {
    /// A logical comparison basis, not a claim of contiguous WAL/history
    /// coverage. The source directory separately carries its exact live pin.
    source: struct {
        interpretation: d.Definition,
        accepted: d.Position,

        pub fn validate(self: @This()) !void {
            try self.interpretation.validate();
            try self.accepted.validate();
        }
    },
    changed_lsn: u64,

    pub fn validate(self: StateGuard) !void {
        try self.source.validate();
        if (self.changed_lsn > self.source.accepted.next_lsn)
            return error.InvalidTransactionGuard;
    }

    pub fn requireUnchanged(self: StateGuard, current: StateGuard) !void {
        try self.validate();
        try current.validate();
        if (!std.meta.eql(self.source.interpretation, current.source.interpretation) or
            !self.source.accepted.unchangedAt(current.source.accepted, current.changed_lsn) or
            self.changed_lsn != current.changed_lsn)
            return error.TransactionConflict;
    }
};

/// The logical frontier includes append, group progress, claim and settlement
/// changes. Flush/checkpoint bookkeeping may advance acceptance independently.
pub const LogGuard = struct {
    kind: LogKind,
    source: q.Cut,
    changed_lsn: u64,

    pub fn validate(self: LogGuard) !void {
        try self.source.validate();
        if (self.changed_lsn > self.source.accepted.next_lsn) return error.InvalidTransactionGuard;
    }

    pub fn requireUnchanged(self: LogGuard, current: LogGuard) !void {
        try self.validate();
        try current.validate();
        if (self.kind != current.kind or !std.meta.eql(self.source.target, current.source.target) or
            self.source.retained_from != current.source.retained_from or self.source.next != current.source.next or
            !self.source.accepted.unchangedAt(current.source.accepted, current.changed_lsn) or
            self.changed_lsn != current.changed_lsn) return error.TransactionConflict;
    }
};

pub const Guard = union(enum) {
    state: struct { kind: StateKind, basis: StateGuard },
    log: LogGuard,

    pub fn validate(self: Guard) !void {
        switch (self) {
            .state => |state| try state.basis.validate(),
            .log => |log| try log.validate(),
        }
    }

    pub fn target(self: Guard) Target {
        return switch (self) {
            .state => |state| .{ .object = state.basis.source.interpretation.object, .kind = switch (state.kind) {
                .table => .table,
                .kv => .kv,
                .document => .document,
            }, .partition = null },
            .log => |log| .{ .object = log.source.target.interpretation.object, .kind = if (log.kind == .stream) .stream else .queue, .partition = log.source.target.partition },
        };
    }

    pub fn accepted(self: Guard) d.Position {
        return switch (self) {
            .state => |state| state.basis.source.accepted,
            .log => |log| log.source.accepted,
        };
    }

    pub fn requireTable(self: Guard) !StateGuard {
        try self.validate();
        if (self != .state or self.state.kind != .table) return error.UnsupportedTransactionParticipant;
        return self.state.basis;
    }

    pub fn requirePagedState(self: Guard) !StateGuard {
        try self.validate();
        if (self != .state or self.state.kind == .document) return error.UnsupportedTransactionParticipant;
        return self.state.basis;
    }
};

/// One preparation per owner. Appends and settlements on the same log partition
/// share an ordered action directory and one successor. They cannot overwrite
/// each other's prepared roots. Null actions are a read-only dependency.
/// Shapes reserve no offsets and do not enable an unimplemented owner.
pub const Participant = union(enum) {
    state: struct {
        kind: StateKind,
        guard: StateGuard,
        access: enum { read, write },
    },
    log: struct { guard: LogGuard, actions: ?Directory },

    pub fn guard(self: Participant) Guard {
        return switch (self) {
            .state => |state| .{ .state = .{ .kind = state.kind, .basis = state.guard } },
            .log => |log| .{ .log = log.guard },
        };
    }

    pub fn writes(self: Participant) bool {
        return switch (self) {
            .state => |state| state.access == .write,
            .log => |log| log.actions != null,
        };
    }

    pub fn validate(self: Participant, identity: Identity) !void {
        switch (self) {
            .state => |state| {
                try state.guard.validate();
                try identity.requireObject(state.guard.source.interpretation.object);
            },
            .log => |log| {
                try log.guard.validate();
                try identity.requireObject(log.guard.source.target.interpretation.object);
                if (log.actions) |actions| {
                    try actions.validate();
                    if (actions.count == 0) return error.InvalidTransactionParticipant;
                }
            },
        }
    }

    pub fn requireLocalTable(self: Participant, begin: Begin) !void {
        try begin.validate();
        try self.validate(begin.identity);
        switch (self) {
            .state => |state| {
                if (state.kind != .table) return error.UnsupportedTransactionParticipant;
                if (begin.mode == .read_only and state.access == .write) return error.ReadOnlyTransaction;
            },
            else => return error.UnsupportedTransactionParticipant,
        }
    }

    /// The shared paged state owner implements Table and KV preparations.
    /// Document and log owners must supply their own qualified preparation.
    pub fn requireLocalState(self: Participant, begin: Begin) !void {
        try begin.validate();
        try self.validate(begin.identity);
        if (self != .state or self.state.kind == .document) return error.UnsupportedTransactionParticipant;
        if (begin.mode == .read_only and self.writes()) return error.ReadOnlyTransaction;
    }
};

/// Statement identity remains unique after savepoint rollback. Returning rows
/// or counts establishes provisional statement completion, never commit.
pub const Statement = struct {
    transaction: Identity,
    sequence: u64,
    intent: [32]u8,

    pub fn validate(self: Statement) !void {
        try self.transaction.validate();
        if (self.sequence == 0) return error.InvalidTransactionStatement;
    }
};

/// Source terminal disposition is conditional on the exact destination append
/// appearing in the same decision. Its payload must be the source item's
/// verified encoding under the recorded destination definition. A full/denied
/// destination leaves the source nonterminal. This type grants no authority.
pub const TerminalTransfer = struct {
    operation: d.Operation,
    source: union(enum) {
        nack: q.Lease,
        exhausted: struct {
            target: q.Partition,
            offset: u64,
            lease_epoch: u64,
            attempt: u64,
            /// Accepted visibility/expiry deadline. Maintenance must prove
            /// exhaustion and trusted time at/after this bound under its guard.
            not_before_ms: u64,
        },
    },
    destination: q.Append,

    pub fn target(self: TerminalTransfer) q.Partition {
        return switch (self.source) {
            .nack => |lease| lease.target,
            .exhausted => |item| item.target,
        };
    }

    pub fn validate(self: TerminalTransfer) !void {
        try self.target().requireOperation(self.operation);
        try self.destination.validate();
        if (self.destination.kind != .queue or self.destination.rows != 1 or
            !std.meta.eql(self.operation.scope, self.destination.operation.scope) or
            self.operation.principal != self.destination.operation.principal or
            self.operation.operation == self.destination.operation.operation or
            std.meta.eql(self.target().interpretation.object, self.destination.target.interpretation.object)) return error.InvalidTransactionTransfer;
        switch (self.source) {
            .nack => |lease| {
                try lease.validate();
                if (lease.claim.principal != self.operation.principal or lease.claim.operation == self.operation.operation)
                    return error.InvalidTransactionTransfer;
            },
            .exhausted => |item| if (item.offset == std.math.maxInt(u64) or item.lease_epoch == 0 or item.attempt == 0 or item.not_before_ms == 0)
                return error.InvalidTransactionTransfer,
        }
    }
};

/// Entries of one owner's immutable action directory, ordered by
/// (statement.sequence, ordinal). Ordinals start at one within each statement;
/// the owner verifies uniqueness, completeness and the statement commitment.
/// Reusing a statement after savepoint rollback is forbidden. No offset is
/// reserved by constructing or staging this value.
pub const LogAction = struct {
    statement: Statement,
    ordinal: u32,
    action: union(enum) {
        append: q.Append,
        stream_offset: q.OffsetCommit,
        queue_ack: q.Settlement,
        queue_terminal: TerminalTransfer,
    },

    pub fn validate(self: LogAction, guard_value: LogGuard) !void {
        try self.statement.validate();
        try guard_value.validate();
        if (self.ordinal == 0) return error.InvalidTransactionStatement;
        const operation: d.Operation, const target: q.Partition = switch (self.action) {
            .append => |append| blk: {
                try append.validate();
                if ((append.kind == .stream) != (guard_value.kind == .stream)) return error.TransactionIdentityConflict;
                break :blk .{ append.operation, append.target };
            },
            .stream_offset => |commit| blk: {
                try commit.validate();
                if (guard_value.kind != .stream) return error.TransactionIdentityConflict;
                if (commit.coverage.cut.accepted.partition != guard_value.source.accepted.partition or
                    commit.coverage.cut.accepted.next_lsn > guard_value.source.accepted.next_lsn or
                    commit.coverage.until > guard_value.source.next) return error.InvalidTransactionGuard;
                break :blk .{ commit.operation, commit.coverage.cut.target };
            },
            .queue_ack => |ack| blk: {
                try ack.validate();
                if (guard_value.kind != .queue or ack.action != .ack) return error.InvalidTransactionSettlement;
                try guard_value.source.requireOffset(ack.lease.offset);
                if (ack.lease.offset == guard_value.source.next) return error.InvalidTransactionSettlement;
                break :blk .{ ack.operation, ack.lease.target };
            },
            .queue_terminal => |transfer| blk: {
                try transfer.validate();
                if (guard_value.kind != .queue) return error.InvalidTransactionTransfer;
                const offset = switch (transfer.source) {
                    .nack => |lease| lease.offset,
                    .exhausted => |item| item.offset,
                };
                try guard_value.source.requireOffset(offset);
                if (offset == guard_value.source.next) return error.InvalidTransactionTransfer;
                break :blk .{ transfer.operation, transfer.target() };
            },
        };
        try target.requireSame(guard_value.source.target);
        try self.statement.transaction.requireObject(target.interpretation.object);
        if (operation.principal != self.statement.transaction.begin.principal or
            operation.operation == self.statement.transaction.begin.operation) return error.TransactionIdentityConflict;
    }
};

pub const Attempt = struct {
    definition: p.Growth.Definition,
    transaction: Identity,
    /// Original commit operation; retries cannot allocate a new identity.
    operation: d.Operation,
    cut: d.Content,
    workspace: d.Content,
    participants: Directory,
    writes: u64,
    last_statement: u64,

    pub fn validate(self: Attempt) !void {
        try self.transaction.validate();
        try self.operation.validate();
        try self.cut.validate();
        try self.workspace.validate();
        try self.participants.validate();
        if (!std.meta.eql(self.operation.scope, self.transaction.begin.scope) or
            self.operation.principal != self.transaction.begin.principal or
            self.operation.operation == self.transaction.begin.operation or
            self.writes > self.participants.count) return error.InvalidTransactionAttempt;
    }

    pub fn requireSame(self: Attempt, other: Attempt) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.TransactionIdentityConflict;
    }
};

pub const Prepared = struct {
    attempt: Attempt,
    target: Target,
    predecessor: Guard,
    /// Participant WAL acceptance, distinct from catalog admission/decision.
    position: d.Position,
    successor: d.Content,

    pub fn validate(self: Prepared) !void {
        try self.attempt.validate();
        try self.target.validate();
        try self.attempt.transaction.requireObject(self.target.object);
        try self.predecessor.validate();
        try self.position.validate();
        try self.successor.validate();
        if (!std.meta.eql(self.target, self.predecessor.target()) or
            self.position.partition != self.predecessor.accepted().partition or
            self.position.next_lsn <= self.predecessor.accepted().next_lsn or
            self.attempt.writes == 0) return error.InvalidTransactionPreparation;
    }
};

pub const Decision = struct {
    attempt: Attempt,
    outcome: enum { committed, aborted },
    /// Complete prepared directory for commit; an abort can cover a prefix.
    prepared: Directory,
    /// Coordination log only. Never substitute a participant/catalog position.
    position: d.Position,
    coordinator_epoch: u64,
    policy_epoch: u64,

    pub fn validate(self: Decision) !void {
        try self.attempt.validate();
        try self.prepared.validate();
        try self.position.validate();
        if (self.coordinator_epoch == 0 or self.policy_epoch == 0 or self.position.next_lsn == 0 or
            self.prepared.count > self.attempt.writes or
            (self.outcome == .committed and self.prepared.count != self.attempt.writes))
            return error.InvalidTransactionDecision;
    }

    pub fn requireAttempt(self: Decision, attempt: Attempt) !void {
        try self.validate();
        try self.attempt.requireSame(attempt);
    }
};

/// Uncertainty is caller knowledge, never an additional durable decision.
pub const Observation = union(enum) {
    unavailable,
    denied,
    not_observed,
    preparing: Attempt,
    decided: Decision,

    pub fn validate(self: Observation) !void {
        switch (self) {
            .unavailable, .denied, .not_observed => {},
            .preparing => |attempt| try attempt.validate(),
            .decided => |decision| try decision.validate(),
        }
    }
};

pub const SchemaTypes = struct {
    begin: Begin,
    cut: Cut,
    participant: Participant,
    statement: Statement,
    prepared: Prepared,
    observation: Observation,
    log_action: LogAction,
};

test {
    _ = @import("transaction_test.zig");
}
