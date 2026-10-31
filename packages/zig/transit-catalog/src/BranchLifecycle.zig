//! Multi-commit realm-scoped branching (`refs/heads/<branch>`), $O(1)$ conditional
//! CAS head publication, pinned-tail `ManifestCut` preparation (including accepted
//! unflushed `TWAL1` rows), copy-on-write branch `.tseg`/`.tdel` isolation,
//! multi-branch GC reachability (`T6`), and branch-aware compaction policies.
const std = @import("std");
const c = @import("root.zig");
const fuze = c.fuze;
const s = fuze.TableSchema;
const t = fuze.Types;
const v = t.Values;
const H = c.HistoricalCatalog;

pub const max_branches: usize = 128;
pub const max_cuts: usize = 256;

pub const BranchMode = enum(u8) {
    full_data = 1,
    schema_only = 2,
};

pub const BranchMergePolicy = enum(u8) {
    allow_merge = 1,
    merge_disabled = 2,
    protected_head = 3,
};

pub const DataflowActivationState = enum(u8) {
    /// Copied view/dataflow definitions on a new branch always start inactive (`Published`).
    published_inactive = 1,
    active = 2,
    suspended = 3,
    completed = 4,
};

pub const OutboxDisposition = enum(u8) {
    executable_live = 1,
    /// Staged or historical outbox records never become executable through branch creation, merge, or restore.
    fenced_historical = 2,
};

pub const IndexReadiness = enum(u8) {
    ready_verified_coverage = 1,
    /// Copying an index definition without verified segment coverage cannot publish readiness.
    rebuild_required = 2,
};

pub const BranchPrivilege = enum(u8) {
    create_branch = 1,
    read_branch = 2,
    write_branch = 3,
    merge_branch = 4,
    restore_branch = 5,
};

/// Independent realm-scoped branch permissions evaluated at the current `policy_epoch`.
/// Branch creation never freezes source privileges or restores historical grants.
pub const BranchGrantSet = struct {
    policy_epoch: u64,
    principal: u64,
    privileges: []const BranchPrivilege = &.{},
    select_objects: []const u64 = &.{},
    write_objects: []const u64 = &.{},

    pub fn authorizePrivilege(self: BranchGrantSet, required: BranchPrivilege) !void {
        if (self.policy_epoch == 0 or self.principal == 0) return error.InvalidPolicyEpoch;
        if (std.mem.indexOfScalar(BranchPrivilege, self.privileges, required) == null) {
            return error.BranchPermissionDenied;
        }
    }

    pub fn authorizeSourceSelect(self: BranchGrantSet, tables: []const H.HistoricalTableBinding) !void {
        if (self.policy_epoch == 0 or self.principal == 0) return error.InvalidPolicyEpoch;
        for (tables) |tbl| {
            if (std.mem.indexOfScalar(u64, self.select_objects, tbl.object) == null) {
                return error.SourceTableSelectDenied;
            }
        }
    }

    pub fn authorizeObjectWrite(self: BranchGrantSet, object: u64) !void {
        if (self.policy_epoch == 0 or self.principal == 0) return error.InvalidPolicyEpoch;
        if (std.mem.indexOfScalar(u64, self.write_objects, object) == null) {
            return error.BranchTableWriteDenied;
        }
    }
};

/// Captures accepted unflushed `TransitLog` (`TWAL1`) rows at the exact branch source cut
/// (`pointing only at the latest flushed Table manifest is insufficient`).
pub const PinnedTailFrontier = struct {
    object: u64,
    wal_partition: u64,
    exclusive_next_lsn: u64,
    unflushed_rows: []const H.HistoricalRow = &.{},

    pub fn validate(self: PinnedTailFrontier, schema: s.Schema) !void {
        if (self.object == 0 or self.wal_partition == 0 or self.exclusive_next_lsn == 0) {
            return error.InvalidPinnedTailFrontier;
        }
        if (schema.object != self.object) return error.PinnedTailObjectMismatch;
        for (self.unflushed_rows) |row| {
            if (row.cells.len != schema.columns.len) return error.InvalidPinnedTailRowArity;
        }
    }
};

/// Descriptive counts in the bounded model. The helper performs no storage I/O
/// and supplies no latency measurements or durable pin-acquisition evidence.
pub const BranchPublicationMetrics = struct {
    pinned_segment_count: u32,
    pinned_unflushed_wal_rows: u32,
};

pub const BranchDescriptor = struct {
    branch_id: u64,
    branch_name: []const u8,
    parent_branch_id: ?u64,
    mode: BranchMode,
    merge_policy: BranchMergePolicy = .allow_merge,
    base_manifest_version: u64,
    base_manifest_digest: [32]u8,
    head_manifest_version: u64,
    head_manifest_digest: [32]u8,
    head_commit_lsn: u64,
    delta_wal_partition: u64,
    pinned_tails: []const PinnedTailFrontier = &.{},
    copied_dataflow_state: DataflowActivationState = .published_inactive,
    inherited_outbox_disposition: OutboxDisposition = .fenced_historical,
    index_readiness: IndexReadiness,
    live_process_pids_copied: u32 = 0,
    metrics: BranchPublicationMetrics,
};

pub const BranchRegistry = struct {
    branches: [max_branches]BranchDescriptor = undefined,
    branch_active: [max_branches]bool = @splat(false),
    branch_count: usize = 0,
    next_branch_id: u64 = 1,
    next_wal_partition: u64 = 1,
    cuts: [max_cuts]H.ManifestCut = undefined,
    cut_parent_versions: [max_cuts]?u64 = @splat(null),
    cut_merge_parent_versions: [max_cuts]?u64 = @splat(null),
    cut_restored_from_versions: [max_cuts]?u64 = @splat(null),
    cut_digests: [max_cuts][32]u8 = undefined,
    cut_count: usize = 0,

    pub fn initWithMain(initial_cut: H.ManifestCut, main_wal_partition: u64) !BranchRegistry {
        if (initial_cut.manifest_version != 1 or initial_cut.branch_id != 1 or
            !std.mem.eql(u8, initial_cut.branch_name, "main") or main_wal_partition == 0)
        {
            return error.InvalidMainBranchGenesis;
        }
        const digest = try initial_cut.digest();
        var reg: BranchRegistry = .{};
        reg.cuts[0] = initial_cut;
        reg.cut_digests[0] = digest;
        reg.cut_count = 1;

        var seg_count: u32 = 0;
        for (initial_cut.tables) |tbl| {
            seg_count += @intCast(tbl.segments.len);
        }

        reg.branches[0] = .{
            .branch_id = 1,
            .branch_name = "main",
            .parent_branch_id = null,
            .mode = .full_data,
            .merge_policy = .allow_merge,
            .base_manifest_version = 1,
            .base_manifest_digest = digest,
            .head_manifest_version = 1,
            .head_manifest_digest = digest,
            .head_commit_lsn = initial_cut.commit_lsn,
            .delta_wal_partition = main_wal_partition,
            .index_readiness = .ready_verified_coverage,
            .metrics = .{
                .pinned_segment_count = seg_count,
                .pinned_unflushed_wal_rows = 0,
            },
        };
        reg.branch_active[0] = true;
        reg.branch_count = 1;
        reg.next_branch_id = 2;
        reg.next_wal_partition = main_wal_partition + 1;
        return reg;
    }

    pub fn findBranchIndexByName(self: *const BranchRegistry, name: []const u8) ?usize {
        for (self.branches[0..self.branch_count], 0..) |b, i| {
            if (self.branch_active[i] and std.mem.eql(u8, b.branch_name, name)) return i;
        }
        return null;
    }

    pub fn findBranchById(self: *const BranchRegistry, branch_id: u64) ?BranchDescriptor {
        for (self.branches[0..self.branch_count], 0..) |b, i| {
            if (self.branch_active[i] and b.branch_id == branch_id) return b;
        }
        return null;
    }

    pub fn getCut(self: *const BranchRegistry, manifest_version: u64) !H.ManifestCut {
        if (manifest_version == 0 or manifest_version > self.cut_count) return error.UnknownManifestVersion;
        return self.cuts[manifest_version - 1];
    }

    /// Create a full-data or schema-only branch from an exact retained version via
    /// `If-None-Match` conditional CAS (`refs/heads/<branch> -> manifest/v{N}`) and
    /// allocate a dedicated branch `TransitLog` partition (`delta_wal_partition`).
    pub fn createBranchConditional(
        self: *BranchRegistry,
        new_branch_name: []const u8,
        source_branch_name: []const u8,
        source_manifest_version: ?u64,
        mode: BranchMode,
        merge_policy: BranchMergePolicy,
        pinned_tails: []const PinnedTailFrontier,
        schema_only_tables_storage: []H.HistoricalTableBinding,
        grants: BranchGrantSet,
    ) !BranchDescriptor {
        if (new_branch_name.len == 0 or new_branch_name.len > 63) return error.InvalidBranchName;
        // 1. Check current realm authority: CREATE BRANCH + source SELECT rights
        try grants.authorizePrivilege(.create_branch);
        try grants.authorizePrivilege(.read_branch);

        // 2. If-None-Match CAS check on `refs/heads/<new_branch_name>`
        if (self.findBranchIndexByName(new_branch_name) != null) {
            return error.BranchAlreadyExists;
        }
        if (self.branch_count >= max_branches or self.cut_count >= max_cuts) {
            return error.TooManyBranches;
        }

        const src_idx = self.findBranchIndexByName(source_branch_name) orelse return error.UnknownSourceBranch;
        const src_branch = self.branches[src_idx];
        const base_ver = source_manifest_version orelse src_branch.head_manifest_version;
        const base_cut = try self.getCut(base_ver);
        try grants.authorizeSourceSelect(base_cut.tables);

        // 3. Validate pinned-tail frontiers (including accepted unflushed TWAL1 rows)
        var unflushed_row_count: u32 = 0;
        for (pinned_tails) |tail| {
            const tbl = H.findTableByObject(base_cut.tables, tail.object) orelse return error.PinnedTailTableNotFound;
            try tail.validate(tbl.schema);
            unflushed_row_count += @intCast(tail.unflushed_rows.len);
        }

        var pinned_seg_count: u32 = 0;
        for (base_cut.tables) |tbl| {
            pinned_seg_count += @intCast(tbl.segments.len);
        }

        const assigned_branch_id = self.next_branch_id;
        self.next_branch_id += 1;
        const assigned_wal_partition = self.next_wal_partition;
        self.next_wal_partition += 1;

        var head_ver = base_ver;
        var head_digest = self.cut_digests[base_ver - 1];
        var head_lsn = base_cut.commit_lsn;

        if (mode == .schema_only) {
            if (schema_only_tables_storage.len < base_cut.tables.len) return error.SchemaOnlyBufferTooSmall;
            for (base_cut.tables, 0..) |tbl, i| {
                schema_only_tables_storage[i] = .{
                    .namespace = tbl.namespace,
                    .name = tbl.name,
                    .object = tbl.object,
                    .revision = tbl.revision,
                    .schema = tbl.schema,
                    .collation_profiles = tbl.collation_profiles,
                    .checks = tbl.checks,
                    .foreign_keys = tbl.foreign_keys,
                    .column_origins = tbl.column_origins,
                    .segments = &.{},
                };
            }
            const next_ver: u64 = @intCast(self.cut_count + 1);
            const highest_lsn = self.cuts[self.cut_count - 1].commit_lsn + 1;
            const schema_cut: H.ManifestCut = .{
                .manifest_version = next_ver,
                .commit_lsn = highest_lsn,
                .branch_id = assigned_branch_id,
                .branch_name = new_branch_name,
                .tzdb = base_cut.tzdb,
                .previous_manifest_digest = head_digest,
                .tables = schema_only_tables_storage[0..base_cut.tables.len],
                .views = base_cut.views,
                .property_graphs = base_cut.property_graphs,
                .foreign_tables = base_cut.foreign_tables,
            };
            head_digest = try schema_cut.digest();
            self.cuts[self.cut_count] = schema_cut;
            self.cut_parent_versions[self.cut_count] = base_ver;
            self.cut_digests[self.cut_count] = head_digest;
            self.cut_count += 1;
            head_ver = next_ver;
            head_lsn = highest_lsn;
            pinned_seg_count = 0;
        }

        const desc: BranchDescriptor = .{
            .branch_id = assigned_branch_id,
            .branch_name = new_branch_name,
            .parent_branch_id = src_branch.branch_id,
            .mode = mode,
            .merge_policy = merge_policy,
            .base_manifest_version = base_ver,
            .base_manifest_digest = self.cut_digests[base_ver - 1],
            .head_manifest_version = head_ver,
            .head_manifest_digest = head_digest,
            .head_commit_lsn = head_lsn,
            .delta_wal_partition = assigned_wal_partition,
            .pinned_tails = if (mode == .full_data) pinned_tails else &.{},
            .copied_dataflow_state = .published_inactive,
            .inherited_outbox_disposition = .fenced_historical,
            .index_readiness = if (mode == .full_data) .ready_verified_coverage else .rebuild_required,
            .live_process_pids_copied = 0,
            .metrics = .{
                .pinned_segment_count = pinned_seg_count,
                .pinned_unflushed_wal_rows = if (mode == .full_data) unflushed_row_count else 0,
            },
        };

        self.branches[self.branch_count] = desc;
        self.branch_active[self.branch_count] = true;
        self.branch_count += 1;
        return desc;
    }

    /// Advance a branch head (`refs/heads/<branch> -> manifest/v{N+1}`) via `If-Match`
    /// conditional CAS on `expected_head_manifest_version`.
    pub fn advanceBranchHeadConditional(
        self: *BranchRegistry,
        branch_name: []const u8,
        expected_head_manifest_version: u64,
        next_cut: H.ManifestCut,
        merge_parent_version: ?u64,
        restored_from_version: ?u64,
        is_direct_write: bool,
        grants: BranchGrantSet,
    ) !BranchDescriptor {
        const idx = self.findBranchIndexByName(branch_name) orelse return error.UnknownBranchName;
        var branch = &self.branches[idx];

        if (is_direct_write) {
            try grants.authorizePrivilege(.write_branch);
            if (branch.merge_policy == .protected_head) {
                return error.ProtectedBranchDirectWriteForbidden;
            }
        }
        if (branch.head_manifest_version != expected_head_manifest_version) {
            return error.ConditionalBranchHeadConflict;
        }
        if (next_cut.branch_id != branch.branch_id or !std.mem.eql(u8, next_cut.branch_name, branch.branch_name)) {
            return error.BranchCutIdentityMismatch;
        }
        if (next_cut.manifest_version != self.cut_count + 1) {
            return error.InvalidNextManifestVersion;
        }
        if (self.cut_count >= self.cuts.len) return error.BranchCutRegistryFull;
        const highest_lsn = self.cuts[self.cut_count - 1].commit_lsn;
        if (next_cut.commit_lsn <= highest_lsn) {
            return error.NonMonotonicManifestLsn;
        }
        if (!std.mem.eql(u8, &next_cut.previous_manifest_digest, &branch.head_manifest_digest)) {
            return error.BrokenManifestDigestChain;
        }

        const digest = try next_cut.digest();
        self.cuts[self.cut_count] = next_cut;
        self.cut_parent_versions[self.cut_count] = branch.head_manifest_version;
        self.cut_merge_parent_versions[self.cut_count] = merge_parent_version;
        self.cut_restored_from_versions[self.cut_count] = restored_from_version;
        self.cut_digests[self.cut_count] = digest;
        self.cut_count += 1;

        branch.head_manifest_version = next_cut.manifest_version;
        branch.head_manifest_digest = digest;
        branch.head_commit_lsn = next_cut.commit_lsn;
        return branch.*;
    }

    /// Delete a branch head (`refs/heads/<branch>`). Never deletes underlying `.tseg`,
    /// `.tdel`, or `TWAL1` objects still reachable from any remaining child/parent branch.
    pub fn dropBranch(self: *BranchRegistry, branch_name: []const u8, grants: BranchGrantSet) !void {
        try grants.authorizePrivilege(.write_branch);
        if (std.mem.eql(u8, branch_name, "main")) return error.CannotDropMainBranch;
        const idx = self.findBranchIndexByName(branch_name) orelse return error.UnknownBranchName;
        self.branch_active[idx] = false;
    }

    /// Resolve the lowest common ancestor (`LCA`) manifest version between two branches.
    pub fn findLowestCommonAncestor(self: *const BranchRegistry, branch_a: []const u8, branch_b: []const u8) !u64 {
        const idx_a = self.findBranchIndexByName(branch_a) orelse return error.UnknownBranchName;
        const idx_b = self.findBranchIndexByName(branch_b) orelse return error.UnknownBranchName;

        var ancestors_a: [max_cuts + 1]bool = @splat(false);
        var queue_a: [max_cuts]u64 = undefined;
        var q_head: usize = 0;
        var q_tail: usize = 0;

        queue_a[q_tail] = self.branches[idx_a].head_manifest_version;
        q_tail += 1;
        while (q_head < q_tail) {
            const ver = queue_a[q_head];
            q_head += 1;
            if (ver == 0 or ver > self.cut_count or ancestors_a[ver]) continue;
            ancestors_a[ver] = true;
            if (self.cut_parent_versions[ver - 1]) |p| {
                queue_a[q_tail] = p;
                q_tail += 1;
            }
            if (self.cut_merge_parent_versions[ver - 1]) |mp| {
                queue_a[q_tail] = mp;
                q_tail += 1;
            }
        }

        var best_lca: u64 = 0;
        var visited_b: [max_cuts + 1]bool = @splat(false);
        var queue_b: [max_cuts]u64 = undefined;
        q_head = 0;
        q_tail = 0;
        queue_b[q_tail] = self.branches[idx_b].head_manifest_version;
        q_tail += 1;
        while (q_head < q_tail) {
            const ver = queue_b[q_head];
            q_head += 1;
            if (ver == 0 or ver > self.cut_count or visited_b[ver]) continue;
            visited_b[ver] = true;
            if (ancestors_a[ver] and ver > best_lca) {
                best_lca = ver;
            }
            if (self.cut_parent_versions[ver - 1]) |p| {
                queue_b[q_tail] = p;
                q_tail += 1;
            }
            if (self.cut_merge_parent_versions[ver - 1]) |mp| {
                queue_b[q_tail] = mp;
                q_tail += 1;
            }
        }
        if (best_lca == 0) return error.NoCommonBranchAncestor;
        return best_lca;
    }
};

/// Branch-local `.tdel` Roaring deletion vector overlay over a shared ancestor `.tseg` segment.
/// Parent `.tseg` files are never mutated in place.
pub const SegmentDeletionOverlay = struct {
    branch_id: u64,
    segment_id: u64,
    tdel_generation: u64,
    deleted_row_indices: []const u32,
};

pub const BranchTableDelta = struct {
    branch_id: u64,
    table_object: u64,
    delta_wal_partition: u64,
    tdel_overlays: []const SegmentDeletionOverlay = &.{},
    branch_owned_segments: []const H.HistoricalSegment = &.{},
    unflushed_branch_wal_rows: []const H.HistoricalRow = &.{},

    pub fn isRowDeletedInSegment(self: BranchTableDelta, segment_id: u64, row_index: u32) bool {
        for (self.tdel_overlays) |ov| {
            if (ov.segment_id == segment_id) {
                if (std.mem.indexOfScalar(u32, ov.deleted_row_indices, row_index) != null) return true;
            }
        }
        return false;
    }
};

/// Materialize the visible rows of a table on a branch by combining:
/// 1. Shared ancestor `.tseg` segments masked by branch-local `.tdel` deletion overlays,
/// 2. Pinned ancestor unflushed `TWAL1` rows captured at branch creation (`PinnedTailFrontier`),
/// 3. Flushed branch-owned `.tseg` segments, and
/// 4. Unflushed branch `delta_wal_partition` rows.
pub fn materializeBranchTableRows(
    base_binding: H.HistoricalTableBinding,
    branch: BranchDescriptor,
    delta: BranchTableDelta,
    out_rows: []H.HistoricalRow,
) !usize {
    if (branch.mode == .schema_only) {
        var count: usize = 0;
        for (delta.branch_owned_segments) |seg| {
            for (seg.rows, 0..) |r, r_idx| {
                if (delta.isRowDeletedInSegment(seg.segment_id, @intCast(r_idx))) continue;
                if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
                out_rows[count] = r;
                count += 1;
            }
        }
        for (delta.unflushed_branch_wal_rows) |r| {
            if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
            out_rows[count] = r;
            count += 1;
        }
        return count;
    }

    var count: usize = 0;
    // 1. Inherited ancestor `.tseg` segments masked by branch-local `.tdel` overlays
    for (base_binding.segments) |seg| {
        for (seg.rows, 0..) |r, r_idx| {
            if (delta.isRowDeletedInSegment(seg.segment_id, @intCast(r_idx))) continue;
            if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
            out_rows[count] = r;
            count += 1;
        }
    }

    // 2. Pinned ancestor unflushed `TWAL1` tail rows at branch creation
    for (branch.pinned_tails) |tail| {
        if (tail.object == base_binding.object) {
            for (tail.unflushed_rows) |r| {
                if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
                out_rows[count] = r;
                count += 1;
            }
        }
    }

    // 3. Branch-owned flushed `.tseg` segments
    for (delta.branch_owned_segments) |seg| {
        for (seg.rows, 0..) |r, r_idx| {
            if (delta.isRowDeletedInSegment(seg.segment_id, @intCast(r_idx))) continue;
            if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
            out_rows[count] = r;
            count += 1;
        }
    }

    // 4. Branch-local unflushed `delta_wal_partition` rows
    for (delta.unflushed_branch_wal_rows) |r| {
        if (count >= out_rows.len) return error.MaterializeBufferTooSmall;
        out_rows[count] = r;
        count += 1;
    }

    return count;
}

/// Verify that the $O(1)$ copy-on-write branch representation matches an independent
/// full-copy oracle bit-for-bit (`use bounded independent copies as the correctness oracle`).
pub fn verifyAgainstIndependentCopyOracle(
    materialized_rows: []const H.HistoricalRow,
    oracle_rows: []const H.HistoricalRow,
) !void {
    if (materialized_rows.len != oracle_rows.len) return error.CopyOracleRowCountMismatch;
    for (materialized_rows, oracle_rows) |m_row, o_row| {
        if (m_row.cells.len != o_row.cells.len) return error.CopyOracleArityMismatch;
        for (m_row.cells, o_row.cells) |mc, oc| {
            if (!std.meta.eql(mc, oc)) return error.CopyOracleCellValueMismatch;
        }
    }
}

pub const ReachabilityReport = struct {
    reachable_segment_ids: [128]u64 = undefined,
    segment_branch_ref_counts: [128]u32 = @splat(0),
    reachable_segment_count: usize = 0,
    reachable_wal_partitions: [64]u64 = undefined,
    reachable_wal_count: usize = 0,

    pub fn addSegmentRef(self: *ReachabilityReport, segment_id: u64) !void {
        for (self.reachable_segment_ids[0..self.reachable_segment_count], 0..) |id, i| {
            if (id == segment_id) {
                self.segment_branch_ref_counts[i] += 1;
                return;
            }
        }
        if (self.reachable_segment_count >= self.reachable_segment_ids.len) return error.ReachabilityBufferFull;
        self.reachable_segment_ids[self.reachable_segment_count] = segment_id;
        self.segment_branch_ref_counts[self.reachable_segment_count] = 1;
        self.reachable_segment_count += 1;
    }

    pub fn addWalPartition(self: *ReachabilityReport, wal_partition: u64) !void {
        for (self.reachable_wal_partitions[0..self.reachable_wal_count]) |p| {
            if (p == wal_partition) return;
        }
        if (self.reachable_wal_count >= self.reachable_wal_partitions.len) return error.ReachabilityBufferFull;
        self.reachable_wal_partitions[self.reachable_wal_count] = wal_partition;
        self.reachable_wal_count += 1;
    }

    pub fn isSegmentReachable(self: *const ReachabilityReport, segment_id: u64) bool {
        for (self.reachable_segment_ids[0..self.reachable_segment_count]) |id| {
            if (id == segment_id) return true;
        }
        return false;
    }

    pub fn segmentRefCount(self: *const ReachabilityReport, segment_id: u64) u32 {
        for (self.reachable_segment_ids[0..self.reachable_segment_count], 0..) |id, i| {
            if (id == segment_id) return self.segment_branch_ref_counts[i];
        }
        return 0;
    }

    pub fn isWalPartitionReachable(self: *const ReachabilityReport, wal_partition: u64) bool {
        for (self.reachable_wal_partitions[0..self.reachable_wal_count]) |p| {
            if (p == wal_partition) return true;
        }
        return false;
    }
};

/// Compute multi-branch `.tseg` and `TransitLog` reachability across all active branches,
/// branch deltas, and pinned `ManifestCut` snapshots (`T6: SnapshotRetentionSafety.lean`).
pub fn computeMultiBranchReachability(
    registry: *const BranchRegistry,
    deltas: []const BranchTableDelta,
    pinned_manifest_versions: []const u64,
) !ReachabilityReport {
    var report: ReachabilityReport = .{};

    // 1. Walk every active branch head and its pinned ancestor tail
    for (registry.branches[0..registry.branch_count], 0..) |branch, i| {
        if (!registry.branch_active[i]) continue;
        try report.addWalPartition(branch.delta_wal_partition);
        for (branch.pinned_tails) |tail| {
            try report.addWalPartition(tail.wal_partition);
        }
        const head_cut = try registry.getCut(branch.head_manifest_version);
        for (head_cut.tables) |tbl| {
            for (tbl.segments) |seg| {
                try report.addSegmentRef(seg.segment_id);
            }
        }
        for (deltas) |d| {
            if (d.branch_id == branch.branch_id) {
                for (d.branch_owned_segments) |seg| {
                    try report.addSegmentRef(seg.segment_id);
                }
            }
        }
    }

    // 2. Walk explicitly pinned snapshot cuts (`TPINOBJ1` / active historical readers)
    for (pinned_manifest_versions) |ver| {
        const cut = try registry.getCut(ver);
        for (cut.tables) |tbl| {
            for (tbl.segments) |seg| {
                try report.addSegmentRef(seg.segment_id);
            }
        }
    }

    return report;
}

pub const CompactionAction = enum(u8) {
    skip_healthy = 1,
    compact_branch_local = 2,
    defer_shared_amplification_guard = 3,
    compact_shared_amortized = 4,
};

pub const CompactionCandidate = struct {
    segment_id: u64,
    branch_ref_count: u32,
    dead_row_ratio: f64,
    shared_tdel_intersection_ratio: f64,
};

/// Evaluate branch-aware compaction so compacting `main` neither breaks pinned
/// ancestor/branch manifests nor causes unmitigated $O(B)$ storage amplification
/// across $B$ active branches.
pub fn evaluateBranchAwareCompaction(candidate: CompactionCandidate) !CompactionAction {
    if (candidate.branch_ref_count == 0 or
        std.math.isNan(candidate.dead_row_ratio) or candidate.dead_row_ratio < 0.0 or candidate.dead_row_ratio > 1.0 or
        std.math.isNan(candidate.shared_tdel_intersection_ratio) or candidate.shared_tdel_intersection_ratio < 0.0 or candidate.shared_tdel_intersection_ratio > 1.0)
    {
        return error.InvalidCompactionCandidate;
    }

    if (candidate.branch_ref_count == 1) {
        if (candidate.dead_row_ratio >= 0.20) return .compact_branch_local;
        return .skip_healthy;
    }

    // Shared across k > 1 branches: require either common `.tdel` intersection >= 0.50
    // or dead-row ratio exceeding the branch-scaled amplification threshold min(0.80, 0.20 * k).
    if (candidate.shared_tdel_intersection_ratio >= 0.50) {
        return .compact_shared_amortized;
    }
    const scaled_threshold = @min(@as(f64, 0.80), 0.20 * @as(f64, @floatFromInt(candidate.branch_ref_count)));
    if (candidate.dead_row_ratio >= scaled_threshold) {
        return .compact_shared_amortized;
    }
    if (candidate.dead_row_ratio >= 0.20) {
        return .defer_shared_amplification_guard;
    }
    return .skip_healthy;
}
