//! Scalar work targets accepted with the Table root. They select physical work;
//! they grant neither retention changes nor permission to collect an object.
const Self = @This();

pub const Action = union(enum) {
    begin_archive,
    complete_archive,
    begin_compaction,
    skip_compaction: u64,
    complete_compaction,
};
pub const Archive = struct {
    through_lsn: u64,
    source_lsn: u64,
    /// First accepted archive publication covering this fixed target.
    checkpoint_lsn: ?u64,
};
pub const Compaction = struct {
    before_segment: u64,
    source_lsn: u64,
    /// Last segment deliberately retained by this pass. Relocated rows sort
    /// beyond before_segment; neither kind of progress needs a resident queue.
    after_segment: u64,
};

archive_source_lsn: u64,
archived_source_lsn: u64,
archive_target: ?Archive,
compaction_source_lsn: u64,
compacted_source_lsn: u64,
compaction_target: ?Compaction,

pub const empty: Self = .{
    .archive_source_lsn = 0,
    .archived_source_lsn = 0,
    .archive_target = null,
    .compaction_source_lsn = 0,
    .compacted_source_lsn = 0,
    .compaction_target = null,
};

pub fn validate(self: Self, root: anytype) !void {
    if (self.archive_source_lsn > root.next_lsn or self.archived_source_lsn > self.archive_source_lsn or
        self.compaction_source_lsn > self.archive_source_lsn or self.compacted_source_lsn > self.compaction_source_lsn)
        return error.InvalidTableMaintenance;
    if (self.archive_target) |target| {
        if (target.through_lsn == 0 or target.through_lsn >= root.next_lsn or
            target.source_lsn <= self.archived_source_lsn or target.source_lsn > self.archive_source_lsn or
            target.source_lsn > target.through_lsn) return error.InvalidTableMaintenance;
        if (target.checkpoint_lsn) |at| {
            if (at <= target.through_lsn or at > root.next_lsn or root.archive.through < target.through_lsn)
                return error.InvalidTableMaintenance;
        } else if (root.archive.through >= target.through_lsn) return error.InvalidTableMaintenance;
    }
    if (self.compaction_target) |target| {
        if (target.before_segment <= 1 or target.before_segment > root.next_segment or target.after_segment >= target.before_segment or
            target.source_lsn <= self.compacted_source_lsn or target.source_lsn > self.compaction_source_lsn)
            return error.InvalidTableMaintenance;
    }
}

/// Derive bookkeeping from the actual accepted action. Recovery checks this
/// same transition; an unrelated append cannot invent progress or a new target.
pub fn transition(before: anytype, after: anytype, action: anytype) !Self {
    var next = before.maintenance;
    switch (action) {
        .maintenance => |work| switch (work) {
            .begin_archive => {
                if (next.archive_target != null or next.archive_source_lsn <= next.archived_source_lsn)
                    return error.InvalidTableMaintenance;
                next.archive_target = .{ .through_lsn = before.next_lsn, .source_lsn = next.archive_source_lsn, .checkpoint_lsn = null };
            },
            .complete_archive => {
                const target = next.archive_target orelse return error.InvalidTableMaintenance;
                const at = target.checkpoint_lsn orelse return error.InvalidTableMaintenance;
                const recovery = before.recovery orelse return error.InvalidTableMaintenance;
                if (before.archive.through < target.through_lsn or recovery.next_lsn < at)
                    return error.InvalidTableMaintenance;
                next.archived_source_lsn = target.source_lsn;
                next.archive_target = null;
            },
            .begin_compaction => {
                if (before.retired or before.next_segment <= 1 or next.compaction_target != null or
                    next.compaction_source_lsn <= next.compacted_source_lsn) return error.InvalidTableMaintenance;
                next.compaction_target = .{ .before_segment = before.next_segment, .source_lsn = next.compaction_source_lsn, .after_segment = 0 };
            },
            .skip_compaction => |segment| {
                var target = next.compaction_target orelse return error.InvalidTableMaintenance;
                if (before.retired or segment <= target.after_segment or segment >= target.before_segment)
                    return error.InvalidTableMaintenance;
                // Publication/recovery additionally require the exact next
                // live segment. A record cannot jump over unexamined inputs.
                target.after_segment = segment;
                next.compaction_target = target;
            },
            .complete_compaction => {
                const target = next.compaction_target orelse return error.InvalidTableMaintenance;
                next.compacted_source_lsn = target.source_lsn;
                next.compaction_target = null;
            },
        },
        .archive => {
            if (next.archive_target) |*target| {
                if (target.checkpoint_lsn == null and after.archive.through >= target.through_lsn)
                    target.checkpoint_lsn = after.next_lsn;
            }
        },
        .recovery => {},
        else => {
            // Receipts, admitted work, pins and relocation all need recovery
            // coverage. Archive/checkpoint bookkeeping cannot trigger itself.
            next.archive_source_lsn = after.next_lsn;
            // Compaction outputs cannot retrigger compaction. Logical changes,
            // bulk writes, schema rewrites and flush output can select new work.
            if (action != .compaction and (after.changed_lsn != before.changed_lsn or after.next_segment != before.next_segment))
                next.compaction_source_lsn = after.next_lsn;
        },
    }
    return next;
}
