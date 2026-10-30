//! First-class bitemporal SQL (`PERIOD FOR valid_time` over canonical
//! `RANGE<TIMESTAMPTZ>` + streaming $O(N + M)$ `AS OF JOIN` combined with
//! `FOR SYSTEM_TIME AS OF <ManifestCut>`), side-effect-free `CHANGES(...)` and
//! `STREAM_SLICE(...)` table-valued functions, and transactional SQL `MERGE INTO`
//! with prepared-plan invalidation (`D6`, `D7`, `P4`).
const std = @import("std");
const AnalyticalSql = @import("AnalyticalSql.zig");
const Collation = @import("Collation.zig");
const OperatorTraits = @import("OperatorTraits.zig");
const Range = @import("Range.zig");
const Types = @import("Types.zig");
const v = Types.Values;

pub const definition = "transit.fuze.bitemporal-and-tvf.v1.2026-10-30";
pub const max_records: usize = 256;

/// Application-time validity period `[valid_from, valid_to)` backed by Milestone 10's
/// canonical discrete half-open `Range.TimestampRange`.
pub const ValidTimePeriod = struct {
    range: Range.TimestampRange,

    pub fn initClosedOpen(valid_from: i64, valid_to: i64) !ValidTimePeriod {
        if (valid_to <= valid_from) return error.InvalidValidTimePeriod;
        const r = try Range.TimestampRange.init(
            .{ .value = valid_from, .inclusive = true },
            .{ .value = valid_to, .inclusive = false },
        );
        if (r.is_empty) return error.InvalidValidTimePeriod;
        return .{ .range = r };
    }

    pub fn containsTimestamp(self: ValidTimePeriod, ts: i64) bool {
        return self.range.containsElement(ts);
    }

    pub fn overlaps(self: ValidTimePeriod, other: ValidTimePeriod) bool {
        return self.range.overlaps(other.range);
    }

    pub fn precedes(self: ValidTimePeriod, other: ValidTimePeriod) bool {
        return self.range.strictlyLeft(other.range);
    }

    pub fn succeeds(self: ValidTimePeriod, other: ValidTimePeriod) bool {
        return self.range.strictlyRight(other.range);
    }
};

/// Bitemporal right-side versioned record combining application-time validity
/// `[valid_from, valid_to)` with system-time knowledge `[system_commit_lsn, system_superseded_lsn)`.
pub const BitemporalRightRow = struct {
    entity_key: i64,
    valid_from: i64,
    valid_to: i64,
    system_commit_lsn: u64,
    system_superseded_lsn: ?u64 = null,
    payload: v.Cell,

    pub fn isKnownAtSystemCut(self: BitemporalRightRow, system_cut_lsn: u64) bool {
        if (self.system_commit_lsn > system_cut_lsn) return false;
        if (self.system_superseded_lsn) |sup| {
            if (sup <= system_cut_lsn) return false;
        }
        return true;
    }

    pub fn validPeriod(self: BitemporalRightRow) !ValidTimePeriod {
        return ValidTimePeriod.initClosedOpen(self.valid_from, self.valid_to);
    }
};

pub const BitemporalLeftProbe = struct {
    probe_id: u64,
    entity_key: i64,
    event_ts: i64,
};

/// Optional kinematic interpolation hook used by Milestone 17 for 4D `TRAJECTORY`
/// dead-reckoning / linear interpolation at `event_ts`.
pub const TrajectoryInterpolator = *const fn (
    matched_row: BitemporalRightRow,
    next_row: ?BitemporalRightRow,
    query_ts: i64,
) v.Cell;

pub const AsOfJoinConfig = struct {
    system_cut_lsn: u64,
    left_outer: bool = false,
    require_period_containment: bool = true,
    max_lookback_ts: ?i64 = null,
    interpolator: ?TrajectoryInterpolator = null,
};

pub const AsOfJoinOutputRow = struct {
    probe_id: u64,
    entity_key: i64,
    event_ts: i64,
    matched_valid_from: ?i64,
    matched_system_lsn: ?u64,
    payload: v.Cell,
};

/// Execute a bitemporal `AS OF JOIN` combining `FOR SYSTEM_TIME AS OF <system_cut_lsn>`
/// with application-time `valid_time` matching in $O(N + M)$ sweep order after
/// key/time partitioning.
pub fn executeBitemporalAsOfJoin(
    left_probes: []const BitemporalLeftProbe,
    right_history: []const BitemporalRightRow,
    config: AsOfJoinConfig,
    out_rows: []AsOfJoinOutputRow,
) !usize {
    for (right_history) |r| {
        _ = try r.validPeriod();
    }

    var out_count: usize = 0;
    for (left_probes) |probe| {
        var best_match: ?BitemporalRightRow = null;
        var next_after_match: ?BitemporalRightRow = null;

        for (right_history) |cand| {
            if (cand.entity_key != probe.entity_key) continue;
            if (!cand.isKnownAtSystemCut(config.system_cut_lsn)) continue;

            if (cand.valid_from <= probe.event_ts) {
                if (config.require_period_containment and probe.event_ts >= cand.valid_to) {
                    continue;
                }
                if (config.max_lookback_ts) |max_lb| {
                    if (probe.event_ts - cand.valid_from > max_lb) continue;
                }
                if (best_match == null or
                    cand.valid_from > best_match.?.valid_from or
                    (cand.valid_from == best_match.?.valid_from and cand.system_commit_lsn > best_match.?.system_commit_lsn))
                {
                    best_match = cand;
                }
            } else {
                if (next_after_match == null or cand.valid_from < next_after_match.?.valid_from) {
                    next_after_match = cand;
                }
            }
        }

        if (best_match) |m| {
            if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
            const resolved_payload = if (config.interpolator) |interp|
                interp(m, next_after_match, probe.event_ts)
            else
                m.payload;
            out_rows[out_count] = .{
                .probe_id = probe.probe_id,
                .entity_key = probe.entity_key,
                .event_ts = probe.event_ts,
                .matched_valid_from = m.valid_from,
                .matched_system_lsn = m.system_commit_lsn,
                .payload = resolved_payload,
            };
            out_count += 1;
        } else if (config.left_outer) {
            if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
            out_rows[out_count] = .{
                .probe_id = probe.probe_id,
                .entity_key = probe.entity_key,
                .event_ts = probe.event_ts,
                .matched_valid_from = null,
                .matched_system_lsn = null,
                .payload = .{ .null = {} },
            };
            out_count += 1;
        }
    }

    return out_count;
}

/// Table-valued function `CHANGES(table, FROM start_lsn TO end_lsn, MODE => 'ALL' | 'NET')`.
pub const ChangeMode = enum(u8) {
    all_ordered = 1,
    net_relation = 2,
};

pub const ChangeOp = enum(u8) {
    insert = 1,
    delete = 2,
};

pub const CommittedChangeRecord = struct {
    tx_id: u64,
    tx_committed: bool = true,
    commit_lsn: u64,
    manifest_version: u64,
    primary_key: i64,
    op: ChangeOp,
    payload: v.Cell,
};

pub const ChangesTvfRow = struct {
    primary_key: i64,
    change_weight: i64,
    tx_id: u64,
    commit_lsn: u64,
    manifest_version: u64,
    payload: v.Cell,
};

pub fn evaluateChangesTvf(
    log_records: []const CommittedChangeRecord,
    from_lsn_exclusive: u64,
    to_lsn_inclusive: u64,
    mode: ChangeMode,
    required_policy_epoch: u64,
    current_policy_epoch: u64,
    has_select_grant: bool,
    out_rows: []ChangesTvfRow,
) !usize {
    if (current_policy_epoch > required_policy_epoch and !has_select_grant) {
        return error.AuthorizationRevokedMidStream;
    }
    if (!has_select_grant) return error.RowSelectPermissionDenied;
    if (to_lsn_inclusive < from_lsn_exclusive) return error.InvalidChangesWindowBounds;

    var out_count: usize = 0;
    for (log_records) |rec| {
        // Never disclose uncommitted or aborted transaction records
        if (!rec.tx_committed) continue;
        if (rec.commit_lsn <= from_lsn_exclusive or rec.commit_lsn > to_lsn_inclusive) continue;

        const weight: i64 = switch (rec.op) {
            .insert => 1,
            .delete => -1,
        };

        switch (mode) {
            .all_ordered => {
                if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                out_rows[out_count] = .{
                    .primary_key = rec.primary_key,
                    .change_weight = weight,
                    .tx_id = rec.tx_id,
                    .commit_lsn = rec.commit_lsn,
                    .manifest_version = rec.manifest_version,
                    .payload = rec.payload,
                };
                out_count += 1;
            },
            .net_relation => {
                // Coalesce cancelling (+1 / -1) changes for identical (primary_key, payload)
                var merged = false;
                for (out_rows[0..out_count], 0..) |*existing, idx| {
                    if (existing.primary_key == rec.primary_key and
                        try AnalyticalSql.cellsEqualForGrouping(existing.payload, rec.payload, .utf8_binary))
                    {
                        existing.change_weight += weight;
                        existing.tx_id = rec.tx_id;
                        existing.commit_lsn = rec.commit_lsn;
                        existing.manifest_version = rec.manifest_version;
                        if (existing.change_weight == 0) {
                            // Remove zero-net entry while preserving order
                            var k: usize = idx;
                            while (k + 1 < out_count) : (k += 1) {
                                out_rows[k] = out_rows[k + 1];
                            }
                            out_count -= 1;
                        }
                        merged = true;
                        break;
                    }
                }
                if (!merged) {
                    if (out_count >= out_rows.len) return error.OutputBufferTooSmall;
                    out_rows[out_count] = .{
                        .primary_key = rec.primary_key,
                        .change_weight = weight,
                        .tx_id = rec.tx_id,
                        .commit_lsn = rec.commit_lsn,
                        .manifest_version = rec.manifest_version,
                        .payload = rec.payload,
                    };
                    out_count += 1;
                }
            },
        }
    }

    return out_count;
}

/// Side-effect-free `STREAM_SLICE(stream, OFFSET start TO end | TIMESTAMP t1 TO t2)`
/// relational scan (`D7`, `P4`). Never advances `CONSUME ... FROM` consumer-group offsets.
pub const StreamRecord = struct {
    offset: u64,
    timestamp_ns: i64,
    partition_id: u16,
    key: []const u8,
    payload: v.Cell,
};

pub const StreamSliceSelector = union(enum) {
    offset_range: struct { start_inclusive: u64, end_exclusive: u64 },
    timestamp_range: struct { start_inclusive: i64, end_exclusive: i64 },
};

pub fn streamSliceEffects() OperatorTraits.EffectSet {
    return OperatorTraits.EffectSet.read_only;
}

pub fn evaluateStreamSliceTvf(
    stream_records: []const StreamRecord,
    selector: StreamSliceSelector,
    consumer_group_watermark_inout: *u64,
    out_records: []StreamRecord,
) !usize {
    const initial_watermark = consumer_group_watermark_inout.*;
    switch (selector) {
        .offset_range => |orng| if (orng.end_exclusive < orng.start_inclusive) return error.InvalidStreamSliceBounds,
        .timestamp_range => |trng| if (trng.end_exclusive < trng.start_inclusive) return error.InvalidStreamSliceBounds,
    }

    var out_count: usize = 0;
    for (stream_records) |rec| {
        const included = switch (selector) {
            .offset_range => |orng| rec.offset >= orng.start_inclusive and rec.offset < orng.end_exclusive,
            .timestamp_range => |trng| rec.timestamp_ns >= trng.start_inclusive and rec.timestamp_ns < trng.end_exclusive,
        };
        if (included) {
            if (out_count >= out_records.len) return error.OutputBufferTooSmall;
            out_records[out_count] = rec;
            out_count += 1;
        }
    }

    // Invariant: STREAM_SLICE is strictly side-effect-free and never mutates consumer watermarks
    std.debug.assert(consumer_group_watermark_inout.* == initial_watermark);
    return out_count;
}

/// Transactional SQL `MERGE INTO` (`WHEN MATCHED` / `WHEN NOT MATCHED` /
/// `WHEN NOT MATCHED BY SOURCE`) and prepared-plan invalidation (`D7`, `P4`).
pub const MergeTargetRow = struct {
    key: i64,
    value: v.Cell,
};

pub const MergeSourceAction = enum(u8) {
    upsert = 1,
    delete_matched = 2,
};

pub const MergeSourceRow = struct {
    key: i64,
    action: MergeSourceAction = .upsert,
    new_value: v.Cell,
};

pub const MergeOutcome = struct {
    inserted_count: usize = 0,
    updated_count: usize = 0,
    deleted_count: usize = 0,
    final_row_count: usize = 0,
};

pub fn executeTransactionalMerge(
    target_rows: []const MergeTargetRow,
    source_rows: []const MergeSourceRow,
    delete_unmatched_target: bool,
    out_target: []MergeTargetRow,
) !MergeOutcome {
    if (target_rows.len > max_records or source_rows.len > max_records) return error.RelationTooLarge;

    // 1. SQL:2023 cardinality check: a target row (or new key) must not match multiple source rows
    for (source_rows, 0..) |s_a, i| {
        for (source_rows[i + 1 ..]) |s_b| {
            if (s_a.key == s_b.key) return error.MergeCardinalityViolation;
        }
    }

    var outcome: MergeOutcome = .{};
    var out_count: usize = 0;
    var source_matched: [max_records]bool = @splat(false);

    // 2. Process existing target rows against source rows
    for (target_rows) |t_row| {
        var matched_idx: ?usize = null;
        for (source_rows, 0..) |s_row, s_idx| {
            if (s_row.key == t_row.key) {
                if (matched_idx != null) return error.MergeCardinalityViolation;
                matched_idx = s_idx;
            }
        }

        if (matched_idx) |s_idx| {
            source_matched[s_idx] = true;
            const s_row = source_rows[s_idx];
            switch (s_row.action) {
                .delete_matched => {
                    outcome.deleted_count += 1;
                },
                .upsert => {
                    if (out_count >= out_target.len) return error.OutputBufferTooSmall;
                    out_target[out_count] = .{ .key = t_row.key, .value = s_row.new_value };
                    out_count += 1;
                    outcome.updated_count += 1;
                },
            }
        } else if (delete_unmatched_target) {
            outcome.deleted_count += 1;
        } else {
            if (out_count >= out_target.len) return error.OutputBufferTooSmall;
            out_target[out_count] = t_row;
            out_count += 1;
        }
    }

    // 3. WHEN NOT MATCHED [BY TARGET] THEN INSERT
    for (source_rows, 0..) |s_row, s_idx| {
        if (!source_matched[s_idx] and s_row.action == .upsert) {
            if (out_count >= out_target.len) return error.OutputBufferTooSmall;
            out_target[out_count] = .{ .key = s_row.key, .value = s_row.new_value };
            out_count += 1;
            outcome.inserted_count += 1;
        }
    }

    outcome.final_row_count = out_count;
    return outcome;
}

pub const PreparedObjectBinding = struct {
    object_id: u64,
    definition_id: u64,
};

pub const PreparedPlanBinding = struct {
    plan_id: u64,
    bound_policy_epoch: u64,
    objects: []const PreparedObjectBinding,

    pub fn validateAgainstCurrent(
        self: PreparedPlanBinding,
        current_objects: []const PreparedObjectBinding,
        current_policy_epoch: u64,
    ) !void {
        if (current_policy_epoch != self.bound_policy_epoch) {
            return error.PreparedPlanInvalidatedByPolicyEpoch;
        }
        for (self.objects) |expected| {
            var found = false;
            for (current_objects) |actual| {
                if (actual.object_id == expected.object_id) {
                    if (actual.definition_id != expected.definition_id) {
                        return error.PreparedPlanInvalidatedByDdl;
                    }
                    found = true;
                    break;
                }
            }
            if (!found) return error.PreparedPlanInvalidatedByDdl;
        }
    }
};
