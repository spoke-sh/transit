//! Bounded original-invocation recovery. Discovery owns no payload cache; each
//! step reopens the frozen declaration and progress through public read owners.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const I = q.ApplicationInvocation;
const M = q.ManagedApplication;
const T = c.DirectClientToken;
pub const Host = q.ApplicationExecution.Host;
pub const Result = enum {
    complete,
    /// A native phase advanced. Another fair sweep can run immediately.
    progressed,
    /// The original acquisition or native recovery has not advanced. Retain
    /// bounded retry debt; never create a replacement identity to hide it.
    waiting,
};

pub fn step(manager: M, token: T.Key, host: Host) !Result {
    var progress = try T.inspect(manager.client, token) orelse return error.ClientOperationMissing;
    if (!std.mem.eql(u8, &token.account, &M.workAccount())) return error.DataflowIdentityConflict;
    const original = progress.original orelse return error.InvalidDirectRecord;
    if (original.phase == .closed) return .complete;
    if (original.phase == .reserved) return error.OwnedRecordPending;
    const owner: I = .{ .manager = manager };
    const loaded = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
    defer loaded.deinit();
    const declared = try manager.load(loaded.value.declaration);
    defer declared.deinit();
    try loaded.value.validate(declared.value, manager.client.allocator);
    // An unavailable host parks original acquisitions/evaluations. Settlement
    // and cleanup remain executable without it, including after cancellation.
    if (!progress.cancel and !loaded.value.execution.cancelled and loaded.value.execution.phase == .evaluate)
        try host.ready(host.context, manager.client.allocator, declared.value);
    if (original.phase != .attached) {
        progress = try owner.resumeAttachment(declared.value, progress, loaded.value) orelse return .complete;
    }
    const execution: q.ApplicationExecution = .{ .owner = owner, .native = host };
    const next = try execution.tick(declared.value, progress, loaded.value);
    if (next.original == null) return error.InvalidDirectRecord;
    if (next.original.?.phase == .closed) return .complete;
    return if (std.meta.eql(next.revision, progress.revision)) .waiting else .progressed;
}
