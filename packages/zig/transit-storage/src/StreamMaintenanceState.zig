//! Accepted physical-work frontiers. Archive and checkpoint bookkeeping cannot
//! schedule itself forever; a finite workload eventually leaves no work due.
//! These fields grant neither expiry nor physical collection authority.
const Self = @This();
pub const Action = enum { begin_archive, complete_archive, begin_rewrite, skip_expired_rewrite, complete_rewrite, cancel_rewrite };
pub const Rewrite = struct {
    source_lsn: u64,
    through_offset: u64,
    after_offset: u64,
};
pub const Archive = struct {
    through_lsn: u64,
    source_lsn: u64,
    checkpoint_lsn: ?u64,
};

archive_source_lsn: u64,
archived_source_lsn: u64,
archive_target: ?Archive,
compaction_source_lsn: u64,
compacted_through_lsn: u64,
rewrite_source_lsn: u64,
rewritten_source_lsn: u64,
rewrite_target: ?Rewrite,

pub const empty: Self = .{
    .archive_source_lsn = 0,
    .archived_source_lsn = 0,
    .archive_target = null,
    .compaction_source_lsn = 0,
    .compacted_through_lsn = 0,
    .rewrite_source_lsn = 0,
    .rewritten_source_lsn = 0,
    .rewrite_target = null,
};

pub fn validate(self: Self, root: anytype) !void {
    if (self.archive_source_lsn > root.next_lsn or self.archived_source_lsn > self.archive_source_lsn or
        self.compaction_source_lsn > self.archive_source_lsn or self.compacted_through_lsn >= root.next_lsn)
        return error.InvalidStreamMaintenance;
    if (self.compacted_through_lsn != (if (root.compacted) |cut| cut.next_lsn else 0))
        return error.InvalidStreamMaintenance;
    if (self.rewrite_source_lsn > self.archive_source_lsn or self.rewritten_source_lsn > self.rewrite_source_lsn) return error.InvalidStreamMaintenance;
    if (self.rewrite_target) |target| {
        if (target.source_lsn == 0 or target.source_lsn > self.rewrite_source_lsn or target.source_lsn <= self.rewritten_source_lsn or
            target.after_offset > target.through_offset or target.through_offset > root.sealed_through) return error.InvalidStreamMaintenance;
    }
    if (self.archive_target) |target| {
        if (target.through_lsn == 0 or target.through_lsn >= root.next_lsn or
            target.source_lsn <= self.archived_source_lsn or target.source_lsn > self.archive_source_lsn or
            target.source_lsn > target.through_lsn) return error.InvalidStreamMaintenance;
        if (target.checkpoint_lsn) |at| {
            if (at <= target.through_lsn or at > root.next_lsn or root.archive.through < target.through_lsn)
                return error.InvalidStreamMaintenance;
        } else if (root.archive.through >= target.through_lsn) return error.InvalidStreamMaintenance;
    }
}

/// Publication and recovery derive the same exact successor from the accepted
/// action. A record cannot invent a completed target or skip an unarchived cut.
pub fn transition(before: anytype, after: anytype, action: anytype) !Self {
    var next = before.maintenance;
    switch (action) {
        .maintenance => |work| switch (work) {
            .begin_archive => {
                if (next.archive_target != null or next.archive_source_lsn <= next.archived_source_lsn)
                    return error.InvalidStreamMaintenance;
                next.archive_target = .{ .through_lsn = before.next_lsn, .source_lsn = next.archive_source_lsn, .checkpoint_lsn = null };
            },
            .begin_rewrite => {
                if (next.rewrite_target != null or next.rewrite_source_lsn <= next.rewritten_source_lsn) return error.InvalidStreamMaintenance;
                next.rewrite_target = .{ .source_lsn = next.rewrite_source_lsn, .after_offset = before.retained_from, .through_offset = before.sealed_through };
                next.archive_source_lsn = after.next_lsn;
            },
            .skip_expired_rewrite => {
                const target = if (next.rewrite_target) |*value| value else return error.InvalidStreamMaintenance;
                if (target.after_offset >= @min(before.retained_from, target.through_offset)) return error.InvalidStreamMaintenance;
                target.after_offset = @min(before.retained_from, target.through_offset);
                next.archive_source_lsn = after.next_lsn;
            },
            .complete_rewrite => {
                const target = next.rewrite_target orelse return error.InvalidStreamMaintenance;
                if (target.after_offset != target.through_offset) return error.InvalidStreamMaintenance;
                next.rewritten_source_lsn = target.source_lsn;
                next.rewrite_target = null;
                next.archive_source_lsn = after.next_lsn;
            },
            .cancel_rewrite => {
                if (next.rewrite_target == null) return error.InvalidStreamMaintenance;
                next.rewrite_target = null;
                next.archive_source_lsn = after.next_lsn;
            },
            .complete_archive => {
                const target = next.archive_target orelse return error.InvalidStreamMaintenance;
                const at = target.checkpoint_lsn orelse return error.InvalidStreamMaintenance;
                const recovery = before.recovery orelse return error.InvalidStreamMaintenance;
                if (before.archive.through < target.through_lsn or recovery.next_lsn < at)
                    return error.InvalidStreamMaintenance;
                next.archived_source_lsn = target.source_lsn;
                next.archive_target = null;
            },
        },
        .archive => {
            if (next.archive_target) |*target| {
                if (target.checkpoint_lsn == null and after.archive.through >= target.through_lsn)
                    target.checkpoint_lsn = after.next_lsn;
            }
        },
        .checkpoint => {},
        else => {
            next.archive_source_lsn = after.next_lsn;
            switch (action) {
                .operation => |record| switch (record.outcome) {
                    .append, .assignment, .offset => if (after.declared.declaration.configuration.policy == .stream) {
                        next.compaction_source_lsn = after.next_lsn;
                    },
                    .read, .release, .claim => {},
                },
                .flush, .expire => if (after.declared.declaration.configuration.policy == .stream) {
                    next.compaction_source_lsn = after.next_lsn;
                },
                .compaction_publish => |cut| {
                    next.compacted_through_lsn = cut.next_lsn;
                    next.rewrite_source_lsn = after.next_lsn;
                },
                .rewrite => |value| {
                    const target = if (next.rewrite_target) |*work| work else return error.InvalidStreamMaintenance;
                    if (target.after_offset != value.receipt.first or value.receipt.next > target.through_offset) return error.InvalidStreamMaintenance;
                    target.after_offset = value.receipt.next;
                },
                else => {},
            }
        },
    }
    return next;
}
