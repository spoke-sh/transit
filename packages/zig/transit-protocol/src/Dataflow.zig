//! Managed computation identities, control fences and complete revision coverage.
//! These values do not grant authority, retain data or prove honest computation.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const Kind = enum { materialized_view, dataflow, subscription };
pub const Consumer = enum { finite_recomputation, net_relation_changes, complete_ordered_changes };
pub const Resume = enum { replay_history, recompute_snapshot };
pub const State = enum { published, authorized, active, suspended, retired };
pub const Command = enum { authorize, activate, suspend_computation, resume_computation, refresh, retire };
pub const Blocked = enum { none, authorization, source_changed, history_expired, storage_unavailable, budget, execution_failed, lease_fenced, unresolved_transaction };

/// Counts are durable cardinalities, never resident array capacities.
pub const Directory = p.Transaction.Directory;
pub const Limits = struct {
    resident_bytes: u64,
    spill_bytes: u64,
    result_bytes: u64,
    work_steps: u64,
    output_rows: u64,

    pub fn validate(self: Limits) !void {
        if (self.resident_bytes == 0 or self.result_bytes == 0 or self.work_steps == 0 or self.output_rows == 0)
            return error.InvalidDataflowLimits;
    }
};

/// Publication freezes the compiled plan and exact dependency directory. Names
/// are catalog bindings, not execution identities. The owner rejects cycles.
pub const Definition = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    owner: d.Operation,
    kind: Kind,
    consumer: Consumer,
    resume_policy: Resume,
    plan: d.Content,
    dependencies: Directory,
    limits: Limits,

    pub fn validate(self: Definition) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        try self.owner.validate();
        try self.plan.validate();
        try self.dependencies.validate();
        try self.limits.validate();
        if (!std.meta.eql(self.interpretation.object.scope, self.owner.scope) or self.dependencies.count == 0)
            return error.InvalidDataflowDefinition;
        if (self.consumer == .complete_ordered_changes and self.resume_policy != .replay_history)
            return error.InvalidDataflowConsumer;
    }
};

/// Authorization here is an observed lifecycle step, never a cached grant.
/// Every accepted control invalidates older worker fences, including refresh.
pub const Control = struct {
    state: State,
    epoch: u64,
    refresh: u64,

    pub fn initial() Control {
        return .{ .state = .published, .epoch = 1, .refresh = 0 };
    }
    pub fn validate(self: Control) !void {
        if (self.epoch == 0 or self.refresh >= self.epoch) return error.InvalidDataflowControl;
    }
    pub fn apply(self: Control, command: Command) !Control {
        try self.validate();
        if (self.state == .retired) return error.DataflowRetired;
        var next = self;
        next.state = switch (command) {
            .authorize => if (self.state == .published) .authorized else return error.InvalidDataflowTransition,
            .activate => if (self.state == .authorized) .active else return error.InvalidDataflowTransition,
            .suspend_computation => if (self.state == .active) .suspended else return error.InvalidDataflowTransition,
            .resume_computation => if (self.state == .suspended) .active else return error.InvalidDataflowTransition,
            .refresh => if (self.state == .active or self.state == .suspended) self.state else return error.InvalidDataflowTransition,
            .retire => .retired,
        };
        next.epoch = try std.math.add(u64, self.epoch, 1);
        if (command == .refresh) next.refresh = try std.math.add(u64, self.refresh, 1);
        return next;
    }
};

/// Save before dispatch. Retrying cannot resolve a new name or current revision.
pub const ControlAttempt = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    target: d.Definition,
    expected: Control,
    command: Command,

    pub fn validate(self: ControlAttempt) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.operation.validate();
        try self.target.validate();
        try self.expected.validate();
        if (!std.meta.eql(self.operation.scope, self.target.object.scope)) return error.DataflowIdentityConflict;
        _ = try self.expected.apply(self.command);
    }
    pub fn requireSame(self: ControlAttempt, other: ControlAttempt) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataflowIdentityConflict;
    }
};

/// A lease is execution ownership only. The accepting owner also checks current
/// source/output privileges and its own trusted clock/deadline under the fence.
pub const Lease = struct {
    target: d.Definition,
    control: Control,
    owner: d.Operation,
    epoch: u64,

    pub fn validate(self: Lease) !void {
        try self.target.validate();
        try self.control.validate();
        try self.owner.validate();
        if (self.epoch == 0 or self.control.state != .active or !std.meta.eql(self.target.object.scope, self.owner.scope))
            return error.InvalidDataflowLease;
    }
    pub fn requireCurrent(self: Lease, target: d.Definition, control: Control, epoch: u64) !void {
        try self.validate();
        try target.validate();
        try control.validate();
        if (!std.meta.eql(self.target, target) or !std.meta.eql(self.control, control) or self.epoch != epoch)
            return error.DataflowLeaseFenced;
    }
};

/// One source's exact handoff. The history lease must exist before backfill;
/// storing its identity is not evidence that the retention owner accepted it.
pub const Source = struct {
    interpretation: d.Definition,
    kind: enum { table, kv, document, stream, queue },
    position: d.Position,
    retention_owner: d.Operation,

    pub fn validate(self: Source) !void {
        try self.interpretation.validate();
        try self.position.validate();
        try self.retention_owner.validate();
        if (!std.meta.eql(self.interpretation.object.scope, self.retention_owner.scope)) return error.DataflowIdentityConflict;
    }
    pub fn requireSuccessor(self: Source, next: Source) !void {
        try self.validate();
        try next.validate();
        if (!std.meta.eql(self.interpretation, next.interpretation) or self.kind != next.kind or
            !std.meta.eql(self.retention_owner, next.retention_owner) or self.position.partition != next.position.partition)
            return error.DataflowSourceChanged;
        if (next.position.next_lsn < self.position.next_lsn) return error.DataflowCoverageGap;
    }
};

/// A complete bounded traversal of one source interval. Empty intervals are
/// valid; an empty page, timeout, budget stop or EOF does not set complete.
pub const Coverage = struct {
    from: Source,
    through: Source,
    complete: bool,

    pub fn validate(self: Coverage) !void {
        try self.from.requireSuccessor(self.through);
    }
    pub fn requireComplete(self: Coverage, previous: Source) !void {
        try self.validate();
        try previous.validate();
        if (!std.meta.eql(self.from, previous)) return error.DataflowCoverageGap;
        if (!self.complete) return error.IncompleteDataflowCoverage;
    }
};

/// A proposed complete successor. Prepared immutable roots remain private until
/// the state/output transaction decides. A candidate is never a result receipt.
pub const Candidate = struct {
    definition: p.Growth.Definition,
    lease: Lease,
    operation: d.Operation,
    previous_revision: u64,
    sources: Directory,
    result: d.Content,
    rows: u64,

    pub fn validate(self: Candidate) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.lease.validate();
        try self.operation.validate();
        try self.sources.validate();
        try self.result.validate();
        if (!std.meta.eql(self.operation.scope, self.lease.target.object.scope) or self.sources.count == 0 or self.previous_revision == std.math.maxInt(u64))
            return error.InvalidDataflowCandidate;
    }
};

/// Complete result and checkpoint attribution to the common transaction owner.
/// Validation checks binding only; the reader must verify the recorded decision.
pub const Completion = struct {
    candidate: Candidate,
    transaction: p.Transaction.Identity,
    decision: d.Position,

    pub fn validate(self: Completion) !void {
        try self.candidate.validate();
        try self.transaction.requireObject(self.candidate.lease.target.object);
        try self.decision.validate();
        if (self.decision.next_lsn == 0) return error.InvalidDataflowCompletion;
    }
    pub fn requireDecision(self: Completion, decision: p.Transaction.Decision) !void {
        try self.validate();
        try decision.validate();
        if (decision.outcome != .committed or !std.meta.eql(self.transaction, decision.attempt.transaction) or !std.meta.eql(self.decision, decision.position))
            return error.InvalidDataflowCompletion;
    }
};

pub const SchemaTypes = struct {
    declaration: Definition,
    control: ControlAttempt,
    source: Source,
    coverage: Coverage,
    candidate: Candidate,
    completion: Completion,
};

test {
    _ = @import("dataflow_test.zig");
}
