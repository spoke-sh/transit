//! Accepted claim-read closure lookup shared by the Queue owner and retained
//! graph. A release at a later cut cannot close an older cut's dependencies.
const std = @import("std");
const p = @import("transit_protocol");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const Evidence = @import("LogEvidence.zig");

pub fn entry(allocator: std.mem.Allocator, store: *Store, key: pages.Key, encoded: pages.Value, frontier: p.DataLifecycle.Position) !p.QueueRead.ReleaseReceipt {
    try frontier.validate();
    const evidence = try Evidence.load(allocator, store.store, encoded);
    if (evidence.outcome != .queue_release) return error.InvalidQueueReadRelease;
    const receipt = evidence.outcome.queue_release;
    if (!std.meta.eql(key, try Evidence.operationKey(receipt.release.claim.claim.operation)) or
        receipt.accepted.partition != frontier.partition or receipt.accepted.next_lsn > frontier.next_lsn) return error.InvalidQueueReadRelease;
    return receipt;
}

pub fn find(allocator: std.mem.Allocator, store: *Store, root: ?pages.Reference, claim: p.StreamQueue.ClaimReceipt, frontier: p.DataLifecycle.Position) !?p.QueueRead.ReleaseReceipt {
    try claim.validate();
    const key = try Evidence.operationKey(claim.claim.operation);
    const tree: pages.Tree(Store) = .{ .store = store };
    const encoded = try tree.get(root, key) orelse return null;
    const receipt = try entry(allocator, store, key, encoded, frontier);
    if (!std.meta.eql(receipt.release.claim, claim)) return error.QueueClaimConflict;
    return receipt;
}
