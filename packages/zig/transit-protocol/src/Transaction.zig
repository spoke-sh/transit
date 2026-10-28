//! Neutral local transaction identities and decision evidence. Shape validation
//! does not acquire a consistent cut, authorize work or prove durable acceptance.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

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

pub const Mode = enum { serializable, read_only };
pub const Selection = enum { explicit_tables, authorized_catalog_tables };

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
    tables: Directory,
    /// Name/definition directory observation; never a data commit position.
    catalog: d.Position,
    limits: Limits,

    pub fn validate(self: Begin) !void {
        try self.identity.validate();
        try self.tables.validate();
        try self.catalog.validate();
        try self.limits.validate();
        if (self.catalog.next_lsn == 0 or self.tables.count > self.limits.participants)
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
        if (self.sources.count != self.begin.tables.count or self.acquired.next_lsn == 0)
            return error.IncompleteTransactionCut;
    }
};

/// One selected Table's immutable basis and logical conflict frontier. The pin
/// receipt and physical accepted frontier may advance without a logical change.
pub const TableGuard = struct {
    source: d.SourceCut,
    changed_lsn: u64,

    pub fn validate(self: TableGuard) !void {
        try self.source.validate();
        if (self.changed_lsn > self.source.accepted.next_lsn)
            return error.InvalidTransactionGuard;
    }

    pub fn requireUnchanged(self: TableGuard, current: TableGuard) !void {
        try self.validate();
        try current.validate();
        if (!std.meta.eql(self.source.interpretation, current.source.interpretation) or
            !self.source.accepted.unchangedAt(current.source.accepted, current.changed_lsn) or
            self.changed_lsn != current.changed_lsn)
            return error.TransactionConflict;
    }
};

/// All three categories are reserved in the common envelope. Only Table state
/// guards/mutations execute in the selected local profile. A variant is not a
/// capability announcement for native resources, streams or queues.
pub const Participant = union(enum) {
    state: struct {
        kind: enum { table, kv, document },
        guard: TableGuard,
        access: enum { read, write },
    },
    append: struct { object: d.Object, kind: enum { stream, queue }, intent: d.Content },
    settlement: struct {
        object: d.Object,
        kind: enum { stream_offset, queue_ack },
        lease_epoch: u64,
        intent: d.Content,
    },

    pub fn validate(self: Participant, identity: Identity) !void {
        switch (self) {
            .state => |state| {
                try state.guard.validate();
                try identity.requireObject(state.guard.source.interpretation.object);
            },
            .append => |append| {
                try identity.requireObject(append.object);
                try append.intent.validate();
            },
            .settlement => |settlement| {
                try identity.requireObject(settlement.object);
                try settlement.intent.validate();
                if (settlement.lease_epoch == 0) return error.InvalidTransactionGuard;
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
    object: d.Object,
    predecessor: TableGuard,
    /// Participant WAL acceptance, distinct from catalog admission/decision.
    position: d.Position,
    successor: d.Content,

    pub fn validate(self: Prepared) !void {
        try self.attempt.validate();
        try self.attempt.transaction.requireObject(self.object);
        try self.predecessor.validate();
        try self.position.validate();
        try self.successor.validate();
        if (!std.meta.eql(self.object, self.predecessor.source.interpretation.object) or
            self.position.partition != self.predecessor.source.accepted.partition or
            self.position.next_lsn <= self.predecessor.source.accepted.next_lsn or
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
};

test {
    _ = @import("transaction_test.zig");
}
