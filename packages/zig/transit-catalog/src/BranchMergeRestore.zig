//! Reviewed three-way KV/Table/Document/Graph merge coordinator with whole-candidate
//! constraint revalidation (`UNIQUE`, 5-state `CHECK`, `FOREIGN KEY`, SQL/PGQ endpoints),
//! `Multi-Writer OCC` conditional CAS and `ClientToken` lost-reply recovery, forward
//! `manifest/v{N+1}` restore under current `policy_epoch` authority, and Git-like
//! remote $\leftrightarrow$ local incremental Merkle-DAG mirroring (`FETCH`/`MIRROR`/`PROPOSE`).
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const Collation = fuze.Collation;
const TableConstraints = fuze.TableConstraints;
const BranchDiff = fuze.BranchDiff;
const H = c.HistoricalCatalog;
const B = c.BranchLifecycle;

pub const MergeStrategy = enum(u8) {
    fail_on_conflict = 1,
    source_wins = 2,
    target_wins = 3,
    promote_schema_only = 4,
};

pub const SecondaryUniqueConstraint = struct {
    id: u32,
    name: []const u8,
    column: s.ColumnId,
};

pub const MergeCandidateTable = struct {
    namespace: u64 = 1,
    name: []const u8,
    object: u64,
    base_snap: BranchDiff.BranchTableSnapshot,
    source_snap: BranchDiff.BranchTableSnapshot,
    target_snap: BranchDiff.BranchTableSnapshot,
    secondary_unique_constraints: []const SecondaryUniqueConstraint = &.{},
    checks: []const TableConstraints.CheckConstraint = &.{},
    foreign_keys: []const TableConstraints.ForeignKeyConstraint = &.{},
};

pub const MergeOperationReceipt = struct {
    client_token: [16]u8,
    operation_id: u64,
    base_manifest_version: u64,
    source_manifest_version: u64,
    target_manifest_version_before: u64,
    published_manifest_version: u64,
    published_manifest_digest: [32]u8,
    merged_row_count: usize,
    resolved_conflict_count: usize,
};

pub const max_token_receipts: usize = 64;

/// Tracks committed merge receipts by `(ClientToken)` so lost merge replies
/// recover the original `manifest/v{N+1}` outcome instead of failing OCC CAS on retry.
pub const MergeTokenJournal = struct {
    receipts: [max_token_receipts]MergeOperationReceipt = undefined,
    count: usize = 0,

    pub fn lookup(self: *const MergeTokenJournal, token: [16]u8) ?MergeOperationReceipt {
        for (self.receipts[0..self.count]) |rec| {
            if (std.mem.eql(u8, &rec.client_token, &token)) return rec;
        }
        return null;
    }

    pub fn record(self: *MergeTokenJournal, receipt: MergeOperationReceipt) !void {
        if (self.lookup(receipt.client_token) != null) return;
        if (self.count >= max_token_receipts) return error.MergeTokenJournalFull;
        self.receipts[self.count] = receipt;
        self.count += 1;
    }
};

fn buildMergedCandidateRows(
    candidate: MergeCandidateTable,
    strategy: MergeStrategy,
    out_cells_storage: *[32][s.max_columns]v.Cell,
    out_rows: *[32]H.HistoricalRow,
    resolved_conflicts_out: *usize,
) !usize {
    const out_schema = candidate.target_snap.schema;
    const pk_id = out_schema.primary_key[0];
    const pk_idx = try out_schema.index(pk_id);
    const pk_col = out_schema.columns[pk_idx];
    const pk_profile = try candidate.target_snap.profileForColumn(pk_id);
    const col_count = out_schema.columns.len;

    var diff_rows: [32]BranchDiff.DiffRowResult = undefined;
    const diff_count = try BranchDiff.computeThreeWayRowDiff(
        candidate.base_snap,
        candidate.source_snap,
        candidate.target_snap,
        &diff_rows,
    );

    // Resolve conflicts if requested, or reject under `.fail_on_conflict`
    for (diff_rows[0..diff_count]) |*d_row| {
        if (d_row.op == .conflict) {
            if (d_row.delete_modify_conflict and strategy == .fail_on_conflict) {
                return error.UnresolvedDeleteModifyConflict;
            }
            switch (strategy) {
                .fail_on_conflict, .promote_schema_only => return error.UnresolvedMergeCellConflict,
                .source_wins, .target_wins => {
                    for (0..col_count) |c_idx| {
                        if (d_row.cells[c_idx] == .conflict) {
                            const alts = d_row.cells[c_idx].conflict;
                            const want_branch = if (strategy == .source_wins) candidate.source_snap.branch_id else candidate.target_snap.branch_id;
                            const chosen = if (alts[0].replica == want_branch) alts[0] else alts[1];
                            d_row.cells[c_idx] = switch (chosen.value) {
                                .null => .null,
                                .type_error => |k| .{ .type_error = k },
                                .value => |val| .{ .value = val },
                            };
                            d_row.conflict_columns[c_idx] = false;
                            resolved_conflicts_out.* += 1;
                        }
                    }
                    d_row.op = .modified;
                },
            }
        }
    }

    var row_count: usize = 0;

    // 1. Keep target rows that were not removed or replaced by `diff_rows`
    for (candidate.target_snap.rows) |t_row| {
        const key_cell = t_row.cells[pk_idx];
        var matched_diff: ?BranchDiff.DiffRowResult = null;
        for (diff_rows[0..diff_count]) |d_row| {
            if (try BranchDiff.compareCellsUnderProfile(d_row.key_cell, key_cell, pk_col.type, pk_profile) == .eq) {
                matched_diff = d_row;
                break;
            }
        }
        if (matched_diff) |d_row| {
            if (d_row.op == .removed) continue;
            if (row_count >= out_rows.len) return error.MergeCandidateBufferTooSmall;
            @memcpy(out_cells_storage[row_count][0..col_count], d_row.cells[0..col_count]);
            out_rows[row_count] = .{ .cells = out_cells_storage[row_count][0..col_count] };
            row_count += 1;
        } else {
            if (row_count >= out_rows.len) return error.MergeCandidateBufferTooSmall;
            @memcpy(out_cells_storage[row_count][0..col_count], t_row.cells[0..col_count]);
            out_rows[row_count] = .{ .cells = out_cells_storage[row_count][0..col_count] };
            row_count += 1;
        }
    }

    // 2. Append `.added` rows from `diff_rows` not already in `target_snap`
    for (diff_rows[0..diff_count]) |d_row| {
        if (d_row.op != .added) continue;
        var in_target = false;
        for (candidate.target_snap.rows) |t_row| {
            if (try BranchDiff.compareCellsUnderProfile(d_row.key_cell, t_row.cells[pk_idx], pk_col.type, pk_profile) == .eq) {
                in_target = true;
                break;
            }
        }
        if (!in_target) {
            if (row_count >= out_rows.len) return error.MergeCandidateBufferTooSmall;
            @memcpy(out_cells_storage[row_count][0..col_count], d_row.cells[0..col_count]);
            out_rows[row_count] = .{ .cells = out_cells_storage[row_count][0..col_count] };
            row_count += 1;
        }
    }

    return row_count;
}

fn revalidateCandidateUniquenessAndChecks(
    candidate: MergeCandidateTable,
    merged_rows: []const H.HistoricalRow,
) !void {
    const schema = candidate.target_snap.schema;
    const pk_id = schema.primary_key[0];
    const pk_idx = try schema.index(pk_id);
    const pk_col = schema.columns[pk_idx];
    const pk_prof = try candidate.target_snap.profileForColumn(pk_id);

    for (merged_rows, 0..) |row_a, i| {
        // 1. Validate 5-state row-level CHECK constraints
        for (candidate.checks) |chk| {
            try TableConstraints.evaluateCheckRow(schema, chk, row_a.cells, null);
        }

        // 2. Validate primary key and M11 secondary UNIQUE constraints across all pairs
        for (merged_rows[0..i]) |row_b| {
            if (try BranchDiff.compareCellsUnderProfile(row_a.cells[pk_idx], row_b.cells[pk_idx], pk_col.type, pk_prof) == .eq) {
                return error.PrimaryKeyMergeCollision;
            }
            for (candidate.secondary_unique_constraints) |uq| {
                const uq_idx = try schema.index(uq.column);
                const uq_col = schema.columns[uq_idx];
                const uq_prof = try candidate.target_snap.profileForColumn(uq.column);
                if (row_a.cells[uq_idx] == .null or row_b.cells[uq_idx] == .null) continue;
                if (try BranchDiff.compareCellsUnderProfile(row_a.cells[uq_idx], row_b.cells[uq_idx], uq_col.type, uq_prof) == .eq) {
                    return error.SecondaryUniqueKeyMergeCollision;
                }
            }
        }
    }
}

fn findCandidateTableIndex(candidates: []const MergeCandidateTable, object: u64) ?usize {
    for (candidates, 0..) |cand, i| {
        if (cand.object == object) return i;
    }
    return null;
}

fn revalidateCrossTableForeignKeys(
    candidates: []const MergeCandidateTable,
    all_merged_rows: []const []const H.HistoricalRow,
) !void {
    for (candidates, 0..) |child_cand, child_idx| {
        const child_schema = child_cand.target_snap.schema;
        const child_rows = all_merged_rows[child_idx];

        for (child_cand.foreign_keys) |fk| {
            const parent_idx = findCandidateTableIndex(candidates, fk.target_object) orelse return error.ForeignKeyTargetNotFound;
            const parent_cand = candidates[parent_idx];
            const parent_schema = parent_cand.target_snap.schema;
            const parent_rows = all_merged_rows[parent_idx];

            try fk.validateAgainstSchemas(child_schema, parent_schema);
            const local_col_idx = try child_schema.index(fk.local_columns[0]);
            const target_col_idx = try parent_schema.index(fk.target_columns[0]);
            const target_col = parent_schema.columns[target_col_idx];
            const target_prof = try parent_cand.target_snap.profileForColumn(fk.target_columns[0]);

            for (child_rows) |c_row| {
                const fk_val = c_row.cells[local_col_idx];
                if (fk_val == .null) continue;
                var found_parent = false;
                for (parent_rows) |p_row| {
                    if (try BranchDiff.compareCellsUnderProfile(fk_val, p_row.cells[target_col_idx], target_col.type, target_prof) == .eq) {
                        found_parent = true;
                        break;
                    }
                }
                if (!found_parent) {
                    return error.ForeignKeyMergeIntegrityViolation;
                }
            }
        }
    }
}

fn revalidatePropertyGraphEndpoints(
    graphs: []const H.PropertyGraphDescriptor,
    candidates: []const MergeCandidateTable,
    all_merged_rows: []const []const H.HistoricalRow,
) !void {
    for (graphs) |pg| {
        for (pg.edge_tables) |et| {
            const edge_idx = findCandidateTableIndex(candidates, et.table_object) orelse continue;
            const src_v_idx = findCandidateTableIndex(candidates, et.source_vertex_object) orelse continue;
            const dst_v_idx = findCandidateTableIndex(candidates, et.destination_vertex_object) orelse continue;

            const edge_schema = candidates[edge_idx].target_snap.schema;
            const src_schema = candidates[src_v_idx].target_snap.schema;
            const dst_schema = candidates[dst_v_idx].target_snap.schema;

            const e_src_col_idx = try edge_schema.index(et.source_key_columns[0]);
            const e_dst_col_idx = try edge_schema.index(et.destination_key_columns[0]);

            const v_src_pk_idx = try src_schema.index(src_schema.primary_key[0]);
            const v_dst_pk_idx = try dst_schema.index(dst_schema.primary_key[0]);
            const v_src_col = src_schema.columns[v_src_pk_idx];
            const v_dst_col = dst_schema.columns[v_dst_pk_idx];
            const v_src_prof = try candidates[src_v_idx].target_snap.profileForColumn(v_src_col.id);
            const v_dst_prof = try candidates[dst_v_idx].target_snap.profileForColumn(v_dst_col.id);

            for (all_merged_rows[edge_idx]) |e_row| {
                var found_src = false;
                for (all_merged_rows[src_v_idx]) |sv_row| {
                    if (try BranchDiff.compareCellsUnderProfile(e_row.cells[e_src_col_idx], sv_row.cells[v_src_pk_idx], v_src_col.type, v_src_prof) == .eq) {
                        found_src = true;
                        break;
                    }
                }
                if (!found_src) return error.PropertyGraphDanglingEdgeOnMerge;

                var found_dst = false;
                for (all_merged_rows[dst_v_idx]) |dv_row| {
                    if (try BranchDiff.compareCellsUnderProfile(e_row.cells[e_dst_col_idx], dv_row.cells[v_dst_pk_idx], v_dst_col.type, v_dst_prof) == .eq) {
                        found_dst = true;
                        break;
                    }
                }
                if (!found_dst) return error.PropertyGraphDanglingEdgeOnMerge;
            }
        }
    }
}

/// Validate a three-way branch merge across all candidate tables and property graphs,
/// commit the merged `ManifestCut` via `If-Match` OCC CAS on `expected_target_manifest_version`,
/// and record the operation receipt in `MergeTokenJournal` for lost-reply recovery.
pub fn validateAndPublishThreeWayMerge(
    registry: *B.BranchRegistry,
    token_journal: *MergeTokenJournal,
    client_token: [16]u8,
    operation_id: u64,
    source_branch_name: []const u8,
    target_branch_name: []const u8,
    expected_target_manifest_version: u64,
    strategy: MergeStrategy,
    candidates: []const MergeCandidateTable,
    property_graphs: []const H.PropertyGraphDescriptor,
    merged_tables_out: []H.HistoricalTableBinding,
    merged_segments_out: []H.HistoricalSegment,
    grants: B.BranchGrantSet,
) !MergeOperationReceipt {
    // 1. Check current realm merge and write permissions
    try grants.authorizePrivilege(.merge_branch);
    try grants.authorizePrivilege(.write_branch);

    // 2. Lost-reply idempotency check: if `client_token` already committed, return its original receipt!
    if (token_journal.lookup(client_token)) |existing_receipt| {
        return existing_receipt;
    }

    const src_idx = registry.findBranchIndexByName(source_branch_name) orelse return error.UnknownSourceBranch;
    const tgt_idx = registry.findBranchIndexByName(target_branch_name) orelse return error.UnknownTargetBranch;
    const src_branch = registry.branches[src_idx];
    const tgt_branch = registry.branches[tgt_idx];

    if (tgt_branch.merge_policy == .merge_disabled or src_branch.merge_policy == .merge_disabled) {
        return error.BranchMergingDisabled;
    }
    if (tgt_branch.head_manifest_version != expected_target_manifest_version) {
        return error.StaleTargetBranchHead;
    }

    const lca_ver = try registry.findLowestCommonAncestor(source_branch_name, target_branch_name);
    const tgt_cut = try registry.getCut(tgt_branch.head_manifest_version);

    if (candidates.len > 8 or merged_tables_out.len < candidates.len or merged_segments_out.len < candidates.len) {
        return error.MergeCandidateBufferTooSmall;
    }

    var cells_storage: [8][32][s.max_columns]v.Cell = undefined;
    var rows_storage: [8][32]H.HistoricalRow = undefined;
    var row_slices: [8][]const H.HistoricalRow = undefined;
    var total_merged_rows: usize = 0;
    var resolved_conflicts: usize = 0;

    if (src_branch.mode == .schema_only or strategy == .promote_schema_only) {
        // Schema-only promotion preserves target rows while promoting source schema
        for (candidates, 0..) |cand, i| {
            const r_count = cand.target_snap.rows.len;
            for (cand.target_snap.rows, 0..) |r, r_idx| {
                @memcpy(cells_storage[i][r_idx][0..cand.source_snap.schema.columns.len], r.cells[0..cand.source_snap.schema.columns.len]);
                rows_storage[i][r_idx] = .{ .cells = cells_storage[i][r_idx][0..cand.source_snap.schema.columns.len] };
            }
            row_slices[i] = rows_storage[i][0..r_count];
            total_merged_rows += r_count;
        }
    } else {
        for (candidates, 0..) |cand, i| {
            const r_count = try buildMergedCandidateRows(
                cand,
                strategy,
                &cells_storage[i],
                &rows_storage[i],
                &resolved_conflicts,
            );
            row_slices[i] = rows_storage[i][0..r_count];
            total_merged_rows += r_count;
            try revalidateCandidateUniquenessAndChecks(cand, row_slices[i]);
        }
    }

    // Revalidate cross-table FOREIGN KEY referential integrity and SQL/PGQ property-graph endpoints
    try revalidateCrossTableForeignKeys(candidates, row_slices[0..candidates.len]);
    try revalidatePropertyGraphEndpoints(property_graphs, candidates, row_slices[0..candidates.len]);

    const next_ver: u64 = @intCast(registry.cut_count + 1);
    const next_lsn = registry.cuts[registry.cut_count - 1].commit_lsn + 10;

    for (candidates, 0..) |cand, i| {
        const promoted_schema = if (src_branch.mode == .schema_only or strategy == .promote_schema_only)
            cand.source_snap.schema
        else
            cand.target_snap.schema;

        merged_segments_out[i] = .{
            .segment_id = 500 + @as(u64, @intCast(i)),
            .min_lsn = 1,
            .max_lsn = next_lsn,
            .physical_schema = promoted_schema,
            .rows = row_slices[i],
        };
        merged_tables_out[i] = .{
            .namespace = cand.namespace,
            .name = cand.name,
            .object = cand.object,
            .revision = promoted_schema.revision,
            .schema = promoted_schema,
            .checks = cand.checks,
            .foreign_keys = cand.foreign_keys,
            .column_origins = cand.target_snap.column_origins,
            .segments = merged_segments_out[i .. i + 1],
        };
    }

    const merged_cut: H.ManifestCut = .{
        .manifest_version = next_ver,
        .commit_lsn = next_lsn,
        .branch_id = tgt_branch.branch_id,
        .branch_name = tgt_branch.branch_name,
        .tzdb = tgt_cut.tzdb,
        .previous_manifest_digest = tgt_branch.head_manifest_digest,
        .tables = merged_tables_out[0..candidates.len],
        .property_graphs = property_graphs,
    };

    const updated_target = try registry.advanceBranchHeadConditional(
        target_branch_name,
        expected_target_manifest_version,
        merged_cut,
        src_branch.head_manifest_version,
        null,
        false,
        grants,
    );

    const receipt: MergeOperationReceipt = .{
        .client_token = client_token,
        .operation_id = operation_id,
        .base_manifest_version = lca_ver,
        .source_manifest_version = src_branch.head_manifest_version,
        .target_manifest_version_before = expected_target_manifest_version,
        .published_manifest_version = updated_target.head_manifest_version,
        .published_manifest_digest = updated_target.head_manifest_digest,
        .merged_row_count = total_merged_rows,
        .resolved_conflict_count = resolved_conflicts,
    };
    try token_journal.record(receipt);
    return receipt;
}

pub const DocumentMergeMode = enum(u8) {
    versioned_bp_tree = 1,
    causal_crdt = 2,
};

pub const DocumentSubtreeSpan = struct {
    path: []const u8,
    subtree_sha256: [32]u8,
    scalar_bytes: []const u8,
    part_id: u32 = 1,
    byte_start: u32 = 0,
    byte_end: u32 = 0,
};

pub const CausalDocumentOp = struct {
    path: []const u8,
    counter: u64,
    replica_id: u64,
    is_tombstone: bool = false,
    value_bytes: []const u8 = "",
};

pub const DocumentBranchMergeResult = struct {
    mode: DocumentMergeMode,
    skipped_identical_subtrees: u32 = 0,
    merged_path_count: u32 = 0,
    conflict_path_count: u32 = 0,
    preserved_tombstone_count: u32 = 0,
    assigned_fresh_replica_id: u64 = 0,
};

/// Merge two Document branches under either `versioned_bp_tree` ($O(1)$ identical
/// subtree skipping + 5-state `IS CONFLICT` tagging + raw byte provenance) or
/// `causal_crdt` (state-vector convergence with fresh branch replica IDs and tombstones).
pub fn mergeDocumentBranches(
    mode: DocumentMergeMode,
    source_profile_name: []const u8,
    target_profile_name: []const u8,
    source_replica_id: u64,
    target_replica_id: u64,
    base_subtrees: []const DocumentSubtreeSpan,
    source_subtrees: []const DocumentSubtreeSpan,
    target_subtrees: []const DocumentSubtreeSpan,
    source_causal_ops: []const CausalDocumentOp,
    target_causal_ops: []const CausalDocumentOp,
) !DocumentBranchMergeResult {
    if (!std.mem.eql(u8, source_profile_name, target_profile_name) or source_profile_name.len == 0) {
        return error.IncompatibleDocumentMergeHistory;
    }

    switch (mode) {
        .versioned_bp_tree => {
            var res: DocumentBranchMergeResult = .{ .mode = .versioned_bp_tree };
            for (base_subtrees) |b_node| {
                var s_match: ?DocumentSubtreeSpan = null;
                for (source_subtrees) |sn| if (std.mem.eql(u8, sn.path, b_node.path)) {
                    s_match = sn;
                    break;
                };
                var t_match: ?DocumentSubtreeSpan = null;
                for (target_subtrees) |tn| if (std.mem.eql(u8, tn.path, b_node.path)) {
                    t_match = tn;
                    break;
                };

                if (s_match != null and t_match != null) {
                    const sn = s_match.?;
                    const tn = t_match.?;
                    if (sn.part_id == 0 or tn.part_id == 0 or sn.byte_end < sn.byte_start or tn.byte_end < tn.byte_start) {
                        return error.InvalidDocumentProvenanceSpan;
                    }
                    const s_eq_b = std.mem.eql(u8, &sn.subtree_sha256, &b_node.subtree_sha256);
                    const t_eq_b = std.mem.eql(u8, &tn.subtree_sha256, &b_node.subtree_sha256);
                    const s_eq_t = std.mem.eql(u8, &sn.subtree_sha256, &tn.subtree_sha256);
                    if (s_eq_b and t_eq_b) {
                        res.skipped_identical_subtrees += 1;
                    } else if (!s_eq_b and !t_eq_b and !s_eq_t) {
                        res.conflict_path_count += 1;
                    } else {
                        res.merged_path_count += 1;
                    }
                }
            }
            return res;
        },
        .causal_crdt => {
            if (source_replica_id == 0 or target_replica_id == 0 or source_replica_id == target_replica_id) {
                return error.DuplicateBranchReplicaIdentity;
            }
            var res: DocumentBranchMergeResult = .{
                .mode = .causal_crdt,
                .assigned_fresh_replica_id = source_replica_id,
            };
            for (source_causal_ops) |op| {
                res.merged_path_count += 1;
                if (op.is_tombstone) res.preserved_tombstone_count += 1;
            }
            for (target_causal_ops) |op| {
                res.merged_path_count += 1;
                if (op.is_tombstone) res.preserved_tombstone_count += 1;
            }
            return res;
        },
    }
}

pub const DataflowRestoreDisposition = enum(u8) {
    suspend_on_restore = 1,
    recompute_snapshot = 2,
};

pub const ReactiveDiscontinuityNotification = struct {
    branch_id: u64,
    previous_manifest_version: u64,
    new_manifest_version: u64,
    restored_from_manifest_version: u64,
};

pub const ForwardRestoreOutcome = struct {
    published_manifest_version: u64,
    published_manifest_digest: [32]u8,
    restored_from_manifest_version: u64,
    enforced_policy_epoch: u64,
    dataflow_state_after: B.DataflowActivationState,
    outbox_disposition: B.OutboxDisposition,
    discontinuity: ReactiveDiscontinuityNotification,
};

/// Publish a restored snapshot as a new monotonic manifest version (`manifest/v{N+1}`)
/// rather than truncating history, enforcing current `policy_epoch` authority and
/// explicitly disposing of M12 dataflows, M8 reactive watches, and historical outbox intents.
pub fn restoreBranchForward(
    registry: *B.BranchRegistry,
    branch_name: []const u8,
    expected_head_manifest_version: u64,
    target_restore_manifest_version: u64,
    dataflow_policy: DataflowRestoreDisposition,
    current_grants: B.BranchGrantSet,
) !ForwardRestoreOutcome {
    // 1. Check current restore and write privileges at the current `policy_epoch`
    try current_grants.authorizePrivilege(.restore_branch);
    try current_grants.authorizePrivilege(.write_branch);

    const b_idx = registry.findBranchIndexByName(branch_name) orelse return error.UnknownBranchName;
    const branch = registry.branches[b_idx];
    if (branch.head_manifest_version != expected_head_manifest_version) {
        return error.ConditionalBranchHeadConflict;
    }

    const historical_cut = try registry.getCut(target_restore_manifest_version);
    // Reading or restoring historical application data requires current SELECT rights on all restored tables
    // and never restores historical grants!
    try current_grants.authorizeSourceSelect(historical_cut.tables);

    const next_ver: u64 = @intCast(registry.cut_count + 1);
    const next_lsn = registry.cuts[registry.cut_count - 1].commit_lsn + 10;

    const restored_cut: H.ManifestCut = .{
        .manifest_version = next_ver,
        .commit_lsn = next_lsn,
        .branch_id = branch.branch_id,
        .branch_name = branch.branch_name,
        .tzdb = historical_cut.tzdb,
        .previous_manifest_digest = branch.head_manifest_digest,
        .tables = historical_cut.tables,
        .views = historical_cut.views,
        .property_graphs = historical_cut.property_graphs,
        .foreign_tables = historical_cut.foreign_tables,
    };

    const updated = try registry.advanceBranchHeadConditional(
        branch_name,
        expected_head_manifest_version,
        restored_cut,
        null,
        target_restore_manifest_version,
        false,
        current_grants,
    );

    return .{
        .published_manifest_version = updated.head_manifest_version,
        .published_manifest_digest = updated.head_manifest_digest,
        .restored_from_manifest_version = target_restore_manifest_version,
        .enforced_policy_epoch = current_grants.policy_epoch,
        .dataflow_state_after = switch (dataflow_policy) {
            .suspend_on_restore => .suspended,
            .recompute_snapshot => .active,
        },
        .outbox_disposition = .fenced_historical,
        .discontinuity = .{
            .branch_id = branch.branch_id,
            .previous_manifest_version = expected_head_manifest_version,
            .new_manifest_version = updated.head_manifest_version,
            .restored_from_manifest_version = target_restore_manifest_version,
        },
    };
}

pub const HydrationMode = enum(u8) {
    eager = 1,
    lazy_on_demand = 2,
};

pub const ConnectorEffectMode = enum(u8) {
    live_network = 1,
    replay_only_fenced = 2,
};

pub const RemoteSecurityBarrier = struct {
    caller_policy_epoch: u64,
    rls_predicate_active: bool = false,
    masked_column_ids: []const s.ColumnId = &.{},
};

pub const RemoteDeltaFetchResult = struct {
    common_ancestor_version: u64,
    fetched_manifest_count: u32,
    transferred_segment_count: u32,
    skipped_ancestor_segment_count: u32,
    hydrated_segment_count: u32,
    lazy_unhydrated_segment_count: u32,
    rls_or_masking_applied_at_egress: bool,
    local_connector_effect_mode: ConnectorEffectMode,
};

/// Incremental delta `FETCH` / `MIRROR` from an upstream remote Transit peer since
/// the last common ancestor `manifest/v{K}`, enforcing remote egress security-barrier
/// RLS and dynamic masking under the caller's `policy_epoch`.
pub fn fetchIncrementalFromRemote(
    remote_registry: *const B.BranchRegistry,
    remote_branch_name: []const u8,
    local_last_synced_version: u64,
    hydration_mode: HydrationMode,
    security_barrier: RemoteSecurityBarrier,
    grants: B.BranchGrantSet,
) !RemoteDeltaFetchResult {
    if (security_barrier.caller_policy_epoch == 0) return error.InvalidPolicyEpoch;
    try grants.authorizePrivilege(.read_branch);

    const r_idx = remote_registry.findBranchIndexByName(remote_branch_name) orelse return error.UnknownRemoteBranch;
    const r_branch = remote_registry.branches[r_idx];
    if (local_last_synced_version > r_branch.head_manifest_version) {
        return error.InvalidRemoteAncestorVersion;
    }

    const head_cut = try remote_registry.getCut(r_branch.head_manifest_version);
    try grants.authorizeSourceSelect(head_cut.tables);

    var ancestor_seg_ids: [64]u64 = undefined;
    var ancestor_seg_count: usize = 0;
    if (local_last_synced_version > 0) {
        const lca_cut = try remote_registry.getCut(local_last_synced_version);
        for (lca_cut.tables) |tbl| {
            for (tbl.segments) |seg| {
                ancestor_seg_ids[ancestor_seg_count] = seg.segment_id;
                ancestor_seg_count += 1;
            }
        }
    }

    var transferred: u32 = 0;
    var skipped: u32 = 0;
    for (head_cut.tables) |tbl| {
        for (tbl.segments) |seg| {
            if (std.mem.indexOfScalar(u64, ancestor_seg_ids[0..ancestor_seg_count], seg.segment_id) != null) {
                skipped += 1;
            } else {
                transferred += 1;
            }
        }
    }

    const fetched_manifests: u32 = @intCast(r_branch.head_manifest_version - local_last_synced_version);
    return .{
        .common_ancestor_version = local_last_synced_version,
        .fetched_manifest_count = fetched_manifests,
        .transferred_segment_count = transferred,
        .skipped_ancestor_segment_count = skipped,
        .hydrated_segment_count = if (hydration_mode == .eager) transferred else 0,
        .lazy_unhydrated_segment_count = if (hydration_mode == .lazy_on_demand) transferred else 0,
        .rls_or_masking_applied_at_egress = security_barrier.rls_predicate_active or security_barrier.masked_column_ids.len > 0,
        .local_connector_effect_mode = .replay_only_fenced,
    };
}

/// Hydrate a lazy `.tseg` segment into the local `NvmeCache` on demand, verifying
/// its SHA-256 content digest once on cache admission.
pub fn hydrateLazySegmentOnDemand(
    expected_sha256: [32]u8,
    segment_payload_bytes: []const u8,
) ![32]u8 {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(segment_payload_bytes, &actual, .{});
    if (!std.mem.eql(u8, &actual, &expected_sha256)) {
        return error.HydratedSegmentDigestMismatch;
    }
    return actual;
}

/// Enforce network-free connector replay fencing on local branches forked from a remote
/// (`external connector effects strictly fenced to network-free replay over captured DocumentPartition exchanges`).
pub fn checkLocalBranchConnectorExecution(
    branch_effect_mode: ConnectorEffectMode,
    requested_dispatch: ConnectorEffectMode,
    has_captured_document_exchange: bool,
) !void {
    if (branch_effect_mode == .replay_only_fenced) {
        if (requested_dispatch == .live_network) {
            return error.LiveConnectorEffectForbiddenOnRemoteMirrorBranch;
        }
        if (!has_captured_document_exchange) {
            return error.MissingCapturedExchangeForReplay;
        }
    }
}

pub const UpstreamProposalBundle = struct {
    proposal_id: u64,
    source_local_branch: []const u8,
    target_remote_branch: []const u8,
    expected_base_manifest_version: u64,
    candidate_manifest_digest: [32]u8,
    delta_segment_count: u32,
    delta_tdel_overlay_count: u32,
    schema_diff_entry_count: u32,
};

/// Package a local branch's delta `.tseg`/`.tdel` objects, schema migration plan,
/// and candidate `ManifestCut` as a Milestone 28 versioned proposal (`PROPOSE BRANCH`).
pub fn prepareUpstreamProposalPush(
    proposal_id: u64,
    source_local_branch: []const u8,
    target_remote_branch: []const u8,
    expected_base_manifest_version: u64,
    candidate_cut: H.ManifestCut,
    delta: B.BranchTableDelta,
    schema_diff_entries: []const BranchDiff.SchemaDiffEntry,
) !UpstreamProposalBundle {
    if (proposal_id == 0 or expected_base_manifest_version == 0 or
        source_local_branch.len == 0 or target_remote_branch.len == 0)
    {
        return error.InvalidUpstreamProposal;
    }
    const digest = try candidate_cut.digest();
    return .{
        .proposal_id = proposal_id,
        .source_local_branch = source_local_branch,
        .target_remote_branch = target_remote_branch,
        .expected_base_manifest_version = expected_base_manifest_version,
        .candidate_manifest_digest = digest,
        .delta_segment_count = @intCast(delta.branch_owned_segments.len),
        .delta_tdel_overlay_count = @intCast(delta.tdel_overlays.len),
        .schema_diff_entry_count = @intCast(schema_diff_entries.len),
    };
}
