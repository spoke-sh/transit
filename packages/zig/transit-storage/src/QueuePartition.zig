//! Serialized Queue payload and scheduling-state owner. The catalog adapter
//! binds current declarations, authorization and the global operation namespace.
//! Stream consumption is not a Queue API; payload expiry requires terminal state.
const std = @import("std");
const p = @import("transit_protocol");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Initialization = @import("LogInitialization.zig");
const Declaration = @import("LogDeclaration.zig");
const Guard = @import("PublicationGuard.zig");
const Owner = @import("LogPartition.zig").Owner(.queue);
const Self = @This();

pub const Options = Owner.Options;
pub const Root = Owner.Root;
pub const Recovery = Owner.Recovery;
pub const RecoveryState = Owner.RecoveryState;
pub const FlushProgress = Owner.FlushProgress;
pub const ExpirationStatus = Owner.ExpirationStatus;
pub const ExpirationProgress = Owner.ExpirationProgress;
pub const ArchiveProgress = Owner.ArchiveProgress;
pub const ClaimReadLimits = Owner.ClaimReadLimits;
pub const ClaimReadRow = Owner.ClaimReadRow;
pub const ClaimReadPage = Owner.ClaimReadPage;
pub const ClaimReadiness = Owner.ClaimReadiness;

owner: Owner,

pub fn open(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Initialization.Request, guard: Guard, options: Options) !Self {
    return .{ .owner = try Owner.open(allocator, log, objects, request, guard, options) };
}
pub fn deinit(self: *Self) !void {
    try self.owner.deinit();
    self.* = undefined;
}
pub fn recoverStep(self: *Self, guard: Guard, budget: u16) !Recovery {
    return self.owner.recoverStep(guard, budget);
}
pub fn recoverStepSince(self: *Self, guard: Guard, budget: u16, prior: ?RecoveryState) !Recovery {
    return self.owner.recoverStepSince(guard, budget, prior);
}
pub fn recoveryState(self: *Self) !RecoveryState {
    return self.owner.recoveryState();
}
pub fn observe(self: *Self, declared: Declaration.Stored, guard: Guard) !p.StreamQueue.Cut {
    return self.owner.observe(declared, guard);
}
pub fn transactionPinState(self: *Self, owner: p.DataLifecycle.Operation, guard: Guard) !@import("LogTransaction.zig").PinState {
    return self.owner.transactionPinState(owner, guard);
}
pub fn pinTransactionSource(self: *Self, declared: Declaration.Stored, identity: p.Transaction.Identity, expected: p.DataLifecycle.Position, guard: Guard) !p.Transaction.Pin {
    return self.owner.pinTransactionSource(declared, identity, expected, guard);
}
pub fn inspectTransactionSource(self: *Self, handle: p.Transaction.Pin, guard: Guard) !@import("LogTransaction.zig").Source {
    return self.owner.inspectTransactionSource(handle, guard);
}
pub fn releaseTransactionSource(self: *Self, handle: p.Transaction.Pin, guard: Guard) !void {
    return self.owner.releaseTransactionSource(handle, guard);
}
pub fn prepareTransaction(self: *Self, binding: @import("TransactionDecisionLog.zig").Binding, coordination: u64, basis: p.Transaction.LogGuard, pin: p.Transaction.Pin, directory: p.Transaction.Directory, limits: @import("LogTransaction.zig").EvaluationLimits, guard: Guard) !p.Transaction.Prepared {
    return self.owner.prepareTransaction(binding, coordination, basis, pin, directory, limits, null, guard);
}
pub fn verifyPrepared(self: *Self, expected: p.Transaction.Prepared) !@import("LogTransaction.zig").DecisionTime {
    return self.owner.verifyPrepared(expected);
}
pub fn verifyDecisionTime(self: *Self, check: @import("LogTransaction.zig").DecisionTime) !void {
    return self.owner.verifyDecisionTime(check);
}
pub fn resolveTransaction(self: *Self, guard: Guard) !?p.Transaction.Decision {
    return self.owner.resolveTransaction(guard);
}
pub fn enqueue(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Append, payload: []const u8, guard: Guard) !p.StreamQueue.AppendReceipt {
    return self.owner.append(declared, request, payload, guard);
}
pub fn operation(self: *Self, identity: p.DataLifecycle.Operation, guard: Guard) !?@import("LogEvidence.zig").Record {
    return self.owner.operation(identity, guard);
}
pub fn claim(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Claim, guard: Guard) !p.StreamQueue.ClaimReceipt {
    return self.owner.claim(declared, request, guard);
}
pub fn claimReadiness(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Claim, guard: Guard) !ClaimReadiness {
    return self.owner.claimReadiness(declared, request, guard);
}
pub fn claimNonempty(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Claim, guard: Guard) !p.StreamQueue.ClaimReceipt {
    return self.owner.claimNonempty(declared, request, guard);
}
pub fn readClaimPage(self: *Self, declared: Declaration.Stored, cursor: p.QueueRead.Cursor, limits: ClaimReadLimits, output: std.mem.Allocator, guard: Guard) !ClaimReadPage {
    return self.owner.readClaimPage(declared, cursor, limits, output, guard);
}
pub fn releaseClaimRead(self: *Self, declared: Declaration.Stored, request: p.QueueRead.Release, guard: Guard) !p.QueueRead.ReleaseReceipt {
    return self.owner.releaseClaimRead(declared, request, guard);
}
pub fn settle(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Settlement, guard: Guard) !p.StreamQueue.SettlementReceipt {
    return self.owner.settle(declared, request, guard);
}
pub fn expireOne(self: *Self, declared: Declaration.Stored, guard: Guard) !bool {
    return self.owner.expireQueueOne(declared, guard);
}
/// Retire at most one sealed, fully terminal payload batch from the retained
/// prefix under explicit age policy. Open claim reads retain their frozen roots.
pub fn expireTerminalHistory(self: *Self, declared: Declaration.Stored, cut: p.DataLifecycle.Position, guard: Guard) !ExpirationProgress {
    return self.owner.expireHistory(declared, cut, guard);
}
pub fn scheduleMaintenanceUnit(self: *Self, declared: Declaration.Stored, maximum: u16, guard: Guard) !bool {
    return self.owner.scheduleQueueUnit(declared, maximum, guard);
}
pub fn flush(self: *Self, cut: p.DataLifecycle.Position, guard: Guard) !FlushProgress {
    return self.owner.flush(cut, guard);
}
pub fn archive(self: *Self, cut: p.DataLifecycle.Position, limits: @import("LogHistory.zig").Limits, guard: Guard) !ArchiveProgress {
    return self.owner.archive(cut, limits, guard);
}
pub fn archiveMaintenanceUnit(self: *Self, limits: @import("LogHistory.zig").Limits, guard: Guard) !bool {
    return self.owner.archiveMaintenanceUnit(limits, guard);
}
pub fn checkpoint(self: *Self, cut: p.DataLifecycle.Position, guard: Guard) !@import("LogRecovery.zig").Reference {
    return self.owner.checkpoint(cut, guard);
}
pub fn trimArchived(self: *Self, guard: Guard) !u64 {
    return self.owner.trimArchived(guard);
}
