//! Serialized Queue payload and scheduling-state owner. The catalog adapter
//! binds current declarations, authorization and the global operation namespace.
//! Stream consumption and retention controls are deliberately not Queue APIs.
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
pub const ArchiveProgress = Owner.ArchiveProgress;

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
pub fn enqueue(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Append, payload: []const u8, guard: Guard) !p.StreamQueue.AppendReceipt {
    return self.owner.append(declared, request, payload, guard);
}
pub fn operation(self: *Self, identity: p.DataLifecycle.Operation, guard: Guard) !?@import("LogEvidence.zig").Record {
    return self.owner.operation(identity, guard);
}
pub fn claim(self: *Self, declared: Declaration.Stored, request: p.StreamQueue.Claim, guard: Guard) !p.StreamQueue.ClaimReceipt {
    return self.owner.claim(declared, request, guard);
}
pub fn flush(self: *Self, cut: p.DataLifecycle.Position, guard: Guard) !FlushProgress {
    return self.owner.flush(cut, guard);
}
pub fn archive(self: *Self, cut: p.DataLifecycle.Position, limits: @import("LogHistory.zig").Limits, guard: Guard) !ArchiveProgress {
    return self.owner.archive(cut, limits, guard);
}
pub fn checkpoint(self: *Self, cut: p.DataLifecycle.Position, guard: Guard) !@import("LogRecovery.zig").Reference {
    return self.owner.checkpoint(cut, guard);
}
pub fn trimArchived(self: *Self, guard: Guard) !u64 {
    return self.owner.trimArchived(guard);
}
