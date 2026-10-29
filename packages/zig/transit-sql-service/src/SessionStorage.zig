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
pub const node_fields = [_]f.Types.Field{
    .{ .name = "backend", .type = .utf8 },
    .{ .name = "root", .type = .utf8, .nullable = true },
    .{ .name = "allocated_bytes", .type = .uint64, .nullable = true },
    .{ .name = "storage_limit_bytes", .type = .uint64, .nullable = true },
    .{ .name = "storage_control_bytes", .type = .uint64, .nullable = true },
    .{ .name = "request_limit_bytes", .type = .uint64, .nullable = true },
    .{ .name = "data_limit_bytes", .type = .uint64, .nullable = true },
    .{ .name = "data_used_bytes", .type = .uint64, .nullable = true },
    .{ .name = "data_peak_bytes", .type = .uint64, .nullable = true },
    .{ .name = "control_limit_bytes", .type = .uint64, .nullable = true },
    .{ .name = "control_used_bytes", .type = .uint64, .nullable = true },
    .{ .name = "control_peak_bytes", .type = .uint64, .nullable = true },
    .{ .name = "maintenance_state", .type = .utf8, .nullable = true },
    .{ .name = "maintenance_completed_steps", .type = .uint64, .nullable = true },
    .{ .name = "maintenance_failed_steps", .type = .uint64, .nullable = true },
    .{ .name = "maintenance_last_failure", .type = .utf8, .nullable = true },
    .{ .name = "maintenance_interval_ms", .type = .uint64, .nullable = true },
    .{ .name = "maintenance_timeout_ms", .type = .uint64, .nullable = true },
    .{ .name = "maintenance_limit_bytes", .type = .uint64, .nullable = true },
};
fn text(value: []const u8) Cell {
    return .{ .value = .{ .atom = .{ .bytes = value } } };
}
/// The returned root slice borrows the read owner's observation, not a temporary
/// native client response or an arena reset by the next row.
pub fn nodeRow(observed: *const g.query.protocol.Storage.Observation) [node_fields.len]Cell {
    const data = observed.data_requests;
    const control = observed.control_requests;
    const work = observed.maintenance;
    return .{
        text(@tagName(observed.backend)),
        if (observed.root) |*path| text(path.slice()) else .null,
        optional(observed.allocated_bytes),
        optional(if (observed.limits) |v| v.bytes else null),
        optional(if (observed.limits) |v| v.control_bytes else null),
        optional(observed.request_limit_bytes),
        optional(if (data) |v| v.limit else null),
        optional(if (data) |v| v.used else null),
        optional(if (data) |v| v.peak else null),
        optional(if (control) |v| v.limit else null),
        optional(if (control) |v| v.used else null),
        optional(if (control) |v| v.peak else null),
        if (work) |v| text(@tagName(v.state)) else .null,
        optional(if (work) |v| v.completed_steps else null),
        optional(if (work) |v| v.failed_steps else null),
        if (work) |v| if (v.last_failure) |failure| text(@tagName(failure)) else .null else .null,
        optional(if (work) |v| v.interval_ms else null),
        optional(if (work) |v| v.operation_timeout_ms else null),
        optional(if (observed.settings) |v| v.resident_bytes else null),
    };
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
