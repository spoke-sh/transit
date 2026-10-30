//! Accepted physical-work frontiers. Archive and checkpoint bookkeeping cannot
//! schedule itself forever; a finite workload eventually leaves no work due.
//! These fields grant neither expiry nor physical collection authority.
const Self = @This();
pub const Action = enum { begin_archive, complete_archive };
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

pub const empty: Self = .{
    .archive_source_lsn = 0,
    .archived_source_lsn = 0,
    .archive_target = null,
    .compaction_source_lsn = 0,
    .compacted_through_lsn = 0,
};

pub fn validate(self: Self, root: anytype) !void {
    if (self.archive_source_lsn > root.next_lsn or self.archived_source_lsn > self.archive_source_lsn or
        self.compaction_source_lsn > self.archive_source_lsn or self.compacted_through_lsn >= root.next_lsn)
        return error.InvalidStreamMaintenance;
    if (self.compacted_through_lsn != (if (root.compacted) |cut| cut.next_lsn else 0))
        return error.InvalidStreamMaintenance;
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
                    .append, .assignment, .offset => next.compaction_source_lsn = after.next_lsn,
                    .read, .release => {},
                },
                .flush, .expire => next.compaction_source_lsn = after.next_lsn,
                .compaction_publish => |cut| next.compacted_through_lsn = cut.next_lsn,
                else => {},
            }
        },
    }
    return next;
}
