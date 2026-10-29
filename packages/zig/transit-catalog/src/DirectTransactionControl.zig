//! Catalog-owned original commit attempt and bounded cleanup progress.
const std = @import("std");
const c = @import("root.zig");
const x = c.protocol.Transaction;
const W = c.DirectTransactionWorkspace;
pub const format: u32 = 0x54585031;
pub const Command = enum { commit, abort };
pub const State = struct {
    definition: c.protocol.Growth.Definition,
    revision: c.protocol.DataLifecycle.Position,
    binding: c.storage.TransactionDecisionLog.Binding,
    abort_requested: bool,
    workspace: ?W.Head,
    preparations: ?x.Directory,
    prepared_after: ?u64,
    preparation_complete: bool,
    decision: ?x.Decision,
    cleanup_after: ?u64,
    cleanup_complete: bool,

    pub fn validate(self: State, progress: c.DirectClientToken.Progress) !void {
        try self.binding.validate();
        if (progress.receipt.binding.intent != .transaction or !std.meta.eql(self.revision, progress.revision) or
            progress.cancel or progress.pending == self.cleanup_complete or (self.cleanup_complete and self.decision == null)) return error.InvalidTransactionControl;
        try self.binding.begin.requireSame(progress.receipt.binding.intent.transaction.begin);
        if (self.workspace) |head| {
            var original = progress;
            original.pending = true;
            original.revision = head.revision;
            try head.validate(original);
            if (head.last_statement != self.binding.attempt.last_statement) return error.InvalidTransactionControl;
        } else if (self.binding.attempt.last_statement != 0 or self.binding.attempt.writes != 0) return error.InvalidTransactionControl;
        if (self.decision) |decision| {
            try decision.requireAttempt(self.binding.attempt);
            if (decision.position.partition != progress.receipt.coordination.?) return error.InvalidTransactionControl;
            if (decision.outcome == .committed and (self.workspace == null or !self.preparation_complete)) return error.InvalidTransactionControl;
        }
        if (self.preparations) |directory| try directory.validate();
    }
};

pub const Status = struct {
    revision: c.protocol.DataLifecycle.Position,
    begin: x.Begin,
    acquired: bool,
    last_statement: u64,
    pending_statement: bool,
    last_control: u64,
    pending_control: bool,
    savepoints: u64,
    attempt: ?x.Attempt,
    observation: x.Observation,
    cleanup_complete: bool,
};

pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !State {
    const state = try W.load(State, allocator, objects, progress.record orelse return error.InvalidTransactionControl, progress.receipt.binding.key.scope(), format);
    try state.validate(progress);
    return state;
}
