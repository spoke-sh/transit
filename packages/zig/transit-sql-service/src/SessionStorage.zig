//! Typed projection of the authorized direct Table storage observation. This
//! adapter owns no storage access, retention decision or maintenance operation.
const g = @import("root.zig");
const f = g.fuze;
const Cell = f.Types.Values.Cell;
pub const pending_limit = 1024;
pub const fields = [_]f.Types.Field{
    .{ .name = "object", .type = .uint64 },
    .{ .name = "schema_revision", .type = .uint64 },
    .{ .name = "partition", .type = .uint64 },
    .{ .name = "accepted_lsn", .type = .uint64 },
    .{ .name = "changed_lsn", .type = .uint64 },
    .{ .name = "live_rows", .type = .uint64 },
    .{ .name = "pending_rows", .type = .uint64 },
    .{ .name = "pending_bytes", .type = .uint64 },
    .{ .name = "pending_complete", .type = .boolean },
    .{ .name = "oldest_pending_lsn", .type = .uint64, .nullable = true },
    .{ .name = "archive_through", .type = .uint64 },
    .{ .name = "recovery_through", .type = .uint64, .nullable = true },
    .{ .name = "history_floor", .type = .uint64 },
    .{ .name = "next_segment", .type = .uint64 },
    .{ .name = "archive_source_lsn", .type = .uint64 },
    .{ .name = "archived_source_lsn", .type = .uint64 },
    .{ .name = "archive_target_source_lsn", .type = .uint64, .nullable = true },
    .{ .name = "archive_target_through_lsn", .type = .uint64, .nullable = true },
    .{ .name = "compaction_source_lsn", .type = .uint64 },
    .{ .name = "compacted_source_lsn", .type = .uint64 },
    .{ .name = "compaction_target_source_lsn", .type = .uint64, .nullable = true },
    .{ .name = "compaction_target_before_segment", .type = .uint64, .nullable = true },
    .{ .name = "compaction_target_after_segment", .type = .uint64, .nullable = true },
};
fn unsigned(value: u64) Cell {
    return .{ .value = .{ .atom = .{ .unsigned = value } } };
}
fn optional(value: ?u64) Cell {
    return if (value) |number| unsigned(number) else .null;
}
pub fn row(observed: g.catalog.DirectCatalog.StorageObservation) [fields.len]Cell {
    const work = observed.maintenance;
    const archive = work.archive_target;
    const compact = work.compaction_target;
    return .{
        unsigned(observed.interpretation.interpretation.object.object),
        unsigned(observed.interpretation.interpretation.revision),
        unsigned(observed.position.partition),
        unsigned(observed.position.next_lsn),
        unsigned(observed.changed_lsn),
        unsigned(observed.live_rows),
        unsigned(observed.pending.rows),
        unsigned(observed.pending.bytes),
        .{ .value = .{ .atom = .{ .boolean = observed.pending.complete } } },
        optional(observed.pending.oldest_lsn),
        unsigned(observed.archive_through),
        optional(observed.recovery_through),
        unsigned(observed.history_floor),
        unsigned(observed.next_segment),
        unsigned(work.archive_source_lsn),
        unsigned(work.archived_source_lsn),
        optional(if (archive) |target| target.source_lsn else null),
        optional(if (archive) |target| target.through_lsn else null),
        unsigned(work.compaction_source_lsn),
        unsigned(work.compacted_source_lsn),
        optional(if (compact) |target| target.source_lsn else null),
        optional(if (compact) |target| target.before_segment else null),
        optional(if (compact) |target| target.after_segment else null),
    };
}
