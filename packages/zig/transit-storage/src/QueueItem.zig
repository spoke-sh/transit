//! Deterministic per-offset Queue metadata. `.tack` owns the state partition;
//! the WAL owner must publish these successors with its bitmap and indexes.
//! Neither a candidate nor a timer wakeup establishes a live lease.
const std = @import("std");
const p = @import("transit_protocol");
const q = p.StreamQueue;
const Policy = p.StreamQueueDeclaration.Queue;
const Time = @import("LogTime.zig");
const State = @import("Tack.zig").State;
const Self = @This();

offset: u64,
batch_next: u64,
next_key: ?u64,
visible_ms: u64,
epoch: u64,
attempts: u64,
lease: ?q.Lease,
blocked: enum { none, exhausted, dead_letter },

pub fn initial(offset: u64, batch_next: u64, visible_ms: u64) !Self {
    const result: Self = .{ .offset = offset, .batch_next = batch_next, .next_key = null, .visible_ms = visible_ms, .epoch = 0, .attempts = 0, .lease = null, .blocked = .none };
    try result.validate();
    return result;
}
pub fn validate(self: Self) !void {
    if (self.offset >= self.batch_next or (self.epoch == 0) != (self.attempts == 0)) return error.InvalidQueueItem;
    if (self.next_key) |next| if (next <= self.offset or next == std.math.maxInt(u64)) return error.InvalidQueueItem;
    if (self.lease) |lease| {
        try lease.validate();
        if (lease.offset != self.offset or lease.epoch != self.epoch or lease.attempt != self.attempts or self.blocked != .none) return error.InvalidQueueItem;
    }
    if (self.blocked != .none and self.attempts == 0) return error.InvalidQueueItem;
}
pub fn requireState(self: Self, state: State) !void {
    try self.validate();
    if ((state == .acquired) != (self.lease != null) or (state != .available and self.blocked != .none)) return error.QueueStateConflict;
}

/// The upper bound creates a conservative deadline; the lower bound proves
/// visibility. The owner rechecks both under its publication guard.
pub fn acquire(self: Self, state: State, claim: q.Claim, policy: Policy, now: Time.Sample) !Self {
    try self.requireState(state);
    try claim.validate();
    try policy.validate();
    try now.validate();
    if (state != .available) return error.QueueStateConflict;
    if (self.blocked != .none or self.attempts >= policy.maximum_attempts) return error.QueueRetryExhausted;
    if (now.earliest_ms < self.visible_ms) return error.QueueNotVisible;
    var next = self;
    next.epoch = std.math.add(u64, self.epoch, 1) catch return error.QueueLeaseEpochExhausted;
    next.attempts = std.math.add(u64, self.attempts, 1) catch return error.QueueAttemptExhausted;
    next.lease = .{ .target = claim.target, .claim = claim.operation, .offset = self.offset, .epoch = next.epoch, .attempt = next.attempts, .expires_ms = try policy.deadline(now.latest_ms, claim.lease_ms) };
    try next.requireState(.acquired);
    return next;
}

/// An interval spanning expiry proves neither liveness nor expiry. In that
/// case both settlement and reassignment wait for authoritative time.
fn requireLive(lease: q.Lease, current: q.Lease, now: Time.Sample) !void {
    try now.validate();
    try lease.requireLive(current, now.earliest_ms);
    if (now.latest_ms >= lease.expires_ms) return error.QueueTimeUnavailable;
}

pub const Transition = struct { item: Self, state: State };

/// Exhaustion keeps the source available but blocked. Only a later common
/// transaction may make a DLQ destination durable and terminalize its source.
fn retry(self: Self, policy: Policy, anchor_ms: u64, requested_ms: u64) !Self {
    var next = self;
    next.lease = null;
    if (next.attempts >= policy.maximum_attempts) {
        next.blocked = if (policy.dead_letter == null) .exhausted else .dead_letter;
    } else {
        const delay = try policy.backoff.delay(@intCast(next.attempts));
        const backoff_until = std.math.add(u64, anchor_ms, delay) catch return error.QueueRetryDeadlineOverflow;
        next.visible_ms = @max(requested_ms, backoff_until);
    }
    try next.requireState(.available);
    return next;
}

pub fn settle(self: Self, state: State, request: q.Settlement, policy: Policy, now: Time.Sample) !Transition {
    try self.requireState(state);
    try request.validate();
    try policy.validate();
    if (state != .acquired) return error.QueueLeaseFenced;
    try requireLive(request.lease, self.lease.?, now);
    var next = self;
    switch (request.action) {
        .ack => {
            next.lease = null;
            try next.requireState(.acked);
            return .{ .item = next, .state = .acked };
        },
        .nack => |nack| return .{ .item = try self.retry(policy, now.latest_ms, nack.visible_ms), .state = .available },
        .extend => |extend| {
            const maximum = try policy.deadline(now.latest_ms, policy.maximum_lease_ms);
            if (extend.expires_ms > maximum) return error.InvalidQueueLeaseDuration;
            next.lease.?.expires_ms = extend.expires_ms;
            try next.requireState(.acquired);
            return .{ .item = next, .state = .acquired };
        },
    }
}

/// Delay after expiry is measured from the accepted deadline, so downtime and
/// delayed cleanup do not restart the backoff interval. The accepted clock floor
/// and the exact receipt are still checked by the enclosing WAL owner.
pub fn expire(self: Self, state: State, policy: Policy, now: Time.Sample) !Self {
    try self.requireState(state);
    try policy.validate();
    try now.validate();
    if (state != .acquired) return error.QueueLeaseFenced;
    if (now.earliest_ms < self.lease.?.expires_ms) return error.QueueTimeUnavailable;
    return self.retry(policy, self.lease.?.expires_ms, 0);
}
