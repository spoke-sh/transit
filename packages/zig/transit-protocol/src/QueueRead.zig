//! Original claim traversal and observed lease state. These shapes establish
//! neither an accepted claim nor present execution authority.
const std = @import("std");
const p = @import("root.zig");
const q = p.StreamQueue;

pub const TimeBounds = struct {
    earliest_ms: u64,
    latest_ms: u64,
    pub fn validate(self: TimeBounds) !void {
        if (self.earliest_ms > self.latest_ms) return error.LogTimeUnavailable;
    }
    pub fn exact(now: u64) TimeBounds {
        return .{ .earliest_ms = now, .latest_ms = now };
    }
};
pub const State = enum(u2) { available, acquired, acked, archived };
pub const Blocked = union(enum) {
    none,
    exhausted,
    dead_letter: p.DataLifecycle.Definition,
    pub fn validate(self: Blocked) !void {
        if (self == .dead_letter) try self.dead_letter.validate();
    }
};
pub const Liveness = enum { live, expired, unavailable, fenced };

/// Ordinals address the immutable original selection. This cursor is not a
/// consumption proof or an authorization token; the owner resolves its receipt.
pub const Cursor = struct {
    receipt: q.ClaimReceipt,
    next: u32,
    pub fn validate(self: Cursor) !void {
        try self.receipt.validate();
        if (self.next > self.receipt.rows) return error.InvalidQueueCursor;
    }
    pub fn requireReceipt(self: Cursor, original: q.ClaimReceipt) !void {
        try self.validate();
        try original.validate();
        if (!std.meta.eql(self.receipt, original)) return error.QueueClaimConflict;
    }
    pub fn complete(self: Cursor) bool {
        return self.next == self.receipt.rows;
    }
};

/// Explicit closure of an original claim's payload read dependency. This is
/// separate from closing a transient result buffer, and never settles leases.
/// The owner must resolve the exact accepted claim under current authority.
pub const Release = struct {
    operation: p.DataLifecycle.Operation,
    claim: q.ClaimReceipt,

    pub fn validate(self: Release) !void {
        try self.claim.validate();
        try self.claim.claim.target.requireOperation(self.operation);
        if (self.operation.principal != self.claim.claim.operation.principal or
            std.meta.eql(self.operation, self.claim.claim.operation)) return error.InvalidQueueReadRelease;
    }
};

pub const ReleaseReceipt = struct {
    release: Release,
    accepted: p.DataLifecycle.Position,

    pub fn validate(self: ReleaseReceipt) !void {
        try self.release.validate();
        try self.accepted.validate();
        if (self.accepted.partition != self.release.claim.accepted.partition or
            self.accepted.next_lsn <= self.release.claim.accepted.next_lsn) return error.InvalidQueueReadRelease;
    }
    pub fn requireRelease(self: ReleaseReceipt, release: Release) !void {
        try self.validate();
        try release.validate();
        if (!std.meta.eql(self.release, release)) return error.QueueReadReleaseConflict;
    }
};

/// Current metadata and trusted time are observations, separate from the
/// original selection's immutable payload basis.
pub const Basis = struct {
    cut: q.Cut,
    time: ?TimeBounds,
    pub fn validate(self: Basis) !void {
        try self.cut.validate();
        if (self.time) |time| try time.validate();
    }
    pub fn requireReceipt(self: Basis, original: q.ClaimReceipt) !void {
        try self.validate();
        try original.validate();
        const old = original.claim.target;
        const current = self.cut.target;
        if (current.partition != old.partition or !std.meta.eql(current.interpretation.object, old.interpretation.object) or
            current.interpretation.revision < old.interpretation.revision or
            (current.interpretation.revision == old.interpretation.revision and !std.meta.eql(current, old)) or
            self.cut.accepted.partition != original.accepted.partition or self.cut.accepted.next_lsn < original.accepted.next_lsn) return error.InvalidQueueObservation;
    }
};

/// Current counters and deadline do not expose a different holder's claim
/// identity. Renewal or reassignment can fence the original lease even while
/// the current message remains acquired.
pub const LeaseObservation = struct {
    original: q.Lease,
    state: State,
    epoch: u64,
    attempt: u64,
    expires_ms: ?u64,
    blocked: Blocked,
    /// Accepted exhaustion time retained even if the retry policy changes.
    blocked_after_ms: ?u64,
    liveness: Liveness,

    pub fn validate(self: LeaseObservation) !void {
        try self.original.validate();
        try self.blocked.validate();
        if (self.epoch < self.original.epoch or self.attempt < self.original.attempt or
            (self.state == .acquired) != (self.expires_ms != null) or
            (self.blocked != .none and self.state != .available) or
            (self.blocked != .none) != (self.blocked_after_ms != null)) return error.InvalidQueueObservation;
        if (self.expires_ms) |expires| if (expires == 0) return error.InvalidQueueObservation;
        if (self.liveness != .fenced and (self.state != .acquired or self.epoch != self.original.epoch or
            self.attempt != self.original.attempt or self.expires_ms != self.original.expires_ms)) return error.InvalidQueueObservation;
        if (self.liveness == .fenced and self.state == .acquired and self.epoch == self.original.epoch and
            self.attempt == self.original.attempt and self.expires_ms == self.original.expires_ms) return error.InvalidQueueObservation;
    }
    pub fn requireBasis(self: LeaseObservation, basis: Basis, receipt: q.ClaimReceipt) !void {
        try self.validate();
        try basis.requireReceipt(receipt);
        if (!std.meta.eql(self.original.target, receipt.claim.target) or !std.meta.eql(self.original.claim, receipt.claim.operation) or
            self.original.expires_ms != receipt.expires_ms or self.original.offset >= basis.cut.next) return error.InvalidQueueObservation;
        switch (self.liveness) {
            .fenced => {},
            .unavailable => if (basis.time) |time| {
                if (time.earliest_ms >= self.original.expires_ms or time.latest_ms < self.original.expires_ms) return error.InvalidQueueObservation;
            },
            .live => {
                const time = basis.time orelse return error.InvalidQueueObservation;
                if (time.latest_ms >= self.original.expires_ms) return error.InvalidQueueObservation;
            },
            .expired => {
                const time = basis.time orelse return error.InvalidQueueObservation;
                if (time.earliest_ms < self.original.expires_ms) return error.InvalidQueueObservation;
            },
        }
    }
};
