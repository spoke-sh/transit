//! Bounded deterministic selection against one accepted Queue root. Selection
//! does not publish leases; the log owner stages and accepts its exact result.
const std = @import("std");
const p = @import("transit_protocol");
const q = p.StreamQueue;
const Index = @import("QueueIndex.zig");
const Selection = @import("QueueSelection.zig");
const Root = @import("LogPartitionRecord.zig").Root;
const Declaration = @import("LogDeclaration.zig");
const Time = @import("LogTime.zig");
const pages = @import("TreeStore.zig").pages;

pub fn select(index: Index, root: Root, declared: Declaration.Stored, claim: q.Claim, observed: Time.Sample, work: []q.Lease) ![]q.Lease {
    try claim.validate();
    try observed.validate();
    try root.requireDeclaration(declared);
    try claim.target.requireSame((try root.cut(declared)).target);
    if (declared.declaration.configuration.policy != .queue) return error.LogPartitionConflict;
    if (claim.maximum > declared.declaration.limits.claim_rows or claim.maximum > work.len or claim.maximum > Selection.max_rows) return error.QueueClaimLimitExceeded;
    const policy = declared.declaration.configuration.policy.queue;
    _ = try policy.deadline(observed.latest_ms, claim.lease_ms);
    const before = root.queue orelse return error.InvalidQueueRoot;
    const capacity = declared.declaration.limits.active_leases -| before.active;
    const limit = @min(claim.maximum, capacity);
    var count: usize = 0;
    var after: ?pages.Key = null;
    while (count < claim.maximum) {
        const item = try index.eligibleAfter(before, after, observed.earliest_ms) orelse break;
        if (count == limit) {
            if (count == 0) return error.QueueLeaseCapacityExceeded;
            break;
        }
        work[count] = (try item.acquire(try index.state(before, item), claim, policy, observed)).lease.?;
        count += 1;
        after = try Index.timedKey(item.visible_ms, item.offset);
    }
    const leases = work[0..count];
    std.mem.sort(q.Lease, leases, {}, struct {
        fn less(_: void, a: q.Lease, b: q.Lease) bool {
            return a.offset < b.offset;
        }
    }.less);
    return leases;
}

pub fn metadata(root: Root, declared: Declaration.Stored, claim: q.Claim, observed: Time.Sample, rows: u32) !Selection.Metadata {
    return .{
        .definition = p.Growth.current_definition,
        .declared = declared,
        .claim = claim,
        .accepted = .{ .partition = root.initialization.partition, .next_lsn = try std.math.add(u64, root.next_lsn, 1) },
        .observed = observed,
        .expires_ms = try declared.declaration.configuration.policy.queue.deadline(observed.latest_ms, claim.lease_ms),
        .rows = rows,
        .source = .{ .accepted = root.position(), .next_offset = root.next_offset, .batches = root.batches, .segments = root.segments },
    };
}

pub fn receipt(meta: Selection.Metadata, leases: []const q.Lease, buffer: []u8) !q.ClaimReceipt {
    if (leases.len != meta.rows) return error.InvalidQueueSelection;
    if (leases.len != 0) return meta.receipt(@import("LogBatch.zig").content(try Selection.encode(meta, leases, buffer)));
    const result: q.ClaimReceipt = .{ .claim = meta.claim, .accepted = meta.accepted, .observed_ms = meta.observed.latest_ms, .expires_ms = meta.expires_ms, .rows = 0, .leases = null };
    try result.validate();
    return result;
}
