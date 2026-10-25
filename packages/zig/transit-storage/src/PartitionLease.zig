//! Partitioned Control vs. Data Log separation, Epoch-Fenced `PartitionLease`
//! records, and optimistic manifest rebasing as separate storage components.
//! Conditional provider I/O may block; this is not the installed Table owner.
const std = @import("std");
const TransitLog = @import("TransitLog.zig");
const TransitObjectStore = @import("TransitObjectStore.zig");
const TableManifest = @import("TableManifest.zig");
const fuze = @import("transit_fuze");
const TSeg = fuze.TSeg;

/// This lease component reserves partition 0 for its control records and uses
/// partitions >= 1 for data. The installed native backend separately uses
/// partition 0 for its complete native history, including process/resource work.
pub const control_partition_id: u64 = 0;

pub const PartitionLease = struct {
    object_id: u64,
    partition_id: u64,
    holder_id: u64,
    writer_epoch: u64,
    policy_epoch: u64,
    lease_until_ms: i64,

    pub const encoded_bytes: usize = 48;

    pub fn validateDataPartition(self: PartitionLease, now_ms: i64) !void {
        if (self.object_id == 0 or self.partition_id == control_partition_id or
            self.holder_id == 0 or self.writer_epoch == 0 or self.policy_epoch == 0)
        {
            return error.InvalidPartitionLease;
        }
        if (now_ms > self.lease_until_ms) return error.LeaseExpired;
    }

    pub fn verifyEpochFence(
        self: PartitionLease,
        candidate_writer_epoch: u64,
        candidate_policy_epoch: u64,
        now_ms: i64,
    ) !void {
        try self.validateDataPartition(now_ms);
        if (candidate_writer_epoch < self.writer_epoch or candidate_policy_epoch < self.policy_epoch) {
            return error.StaleEpoch;
        }
    }

    pub fn encode(self: PartitionLease, out: *[encoded_bytes]u8) void {
        var writer: std.Io.Writer = .fixed(out);
        writer.writeInt(u64, self.object_id, .little) catch unreachable;
        writer.writeInt(u64, self.partition_id, .little) catch unreachable;
        writer.writeInt(u64, self.holder_id, .little) catch unreachable;
        writer.writeInt(u64, self.writer_epoch, .little) catch unreachable;
        writer.writeInt(u64, self.policy_epoch, .little) catch unreachable;
        writer.writeInt(i64, self.lease_until_ms, .little) catch unreachable;
    }

    pub fn decode(bytes: []const u8) !PartitionLease {
        if (bytes.len != encoded_bytes) return error.InvalidPartitionLease;
        var reader: std.Io.Reader = .fixed(bytes);
        return .{
            .object_id = try reader.takeInt(u64, .little),
            .partition_id = try reader.takeInt(u64, .little),
            .holder_id = try reader.takeInt(u64, .little),
            .writer_epoch = try reader.takeInt(u64, .little),
            .policy_epoch = try reader.takeInt(u64, .little),
            .lease_until_ms = try reader.takeInt(i64, .little),
        };
    }

    pub fn appendToControlLog(
        self: PartitionLease,
        control_log: TransitLog.Log,
        expected_lsn: ?u64,
        now_ms: i64,
    ) !TransitLog.AppendReceipt {
        try self.validateDataPartition(now_ms);
        var payload: [encoded_bytes]u8 = undefined;
        self.encode(&payload);
        return control_log.append(
            control_partition_id,
            expected_lsn,
            self.writer_epoch,
            self.policy_epoch,
            .policy_control,
            &payload,
        );
    }
};

pub const CommitOutcome = struct {
    committed_version: u64,
    rebased_attempts: u32,
};

pub const OccCoordinator = struct {
    pub const max_rebase_retries: u32 = 8;

    /// Commits `candidate_segment` on top of `base_manifest` (or `null` when creating `v1`).
    /// If another writer concurrently publishes `v{N+1}`, verifies whether the concurrent
    /// commit's added segments have disjoint primary keys (`min_pk_sort_key..max_pk_sort_key`
    /// plus exact embedded `.tseg` PK B-Tree probe when bounds overlap). Disjoint commits
    /// are automatically rebased onto `v{N+1}` without rewriting `.tseg` objects; overlapping
    /// primary keys fail closed with `error.WriteWriteConflict`.
    pub fn commitSegment(
        allocator: std.mem.Allocator,
        store: TransitObjectStore.ObjectStore,
        catalog_id: u64,
        object_id: u64,
        schema_revision: u64,
        layout_fingerprint: [32]u8,
        lease: PartitionLease,
        now_ms: i64,
        base_manifest: ?TableManifest.Manifest,
        candidate_segment: TableManifest.SegmentDescriptor,
        candidate_flushed_lsn: u64,
    ) !CommitOutcome {
        try lease.validateDataPartition(now_ms);

        var current_base_owned: ?TableManifest.OwnedManifest = null;
        defer if (current_base_owned) |*owned| owned.deinit();

        var current_base: ?TableManifest.Manifest = base_manifest;
        var rebased_attempts: u32 = 0;

        while (rebased_attempts <= max_rebase_retries) {
            const target_version: u64 = if (current_base) |b| b.manifest_version + 1 else 1;
            if (current_base) |b| {
                if (lease.writer_epoch < b.writer_epoch or lease.policy_epoch < b.policy_epoch) {
                    return error.StaleEpoch;
                }
            }

            const existing_len = if (current_base) |b| b.segments.len else 0;
            const merged = try allocator.alloc(TableManifest.SegmentDescriptor, existing_len + 1);
            defer allocator.free(merged);
            if (current_base) |b| {
                @memcpy(merged[0..existing_len], b.segments);
            }
            merged[existing_len] = candidate_segment;

            var total_live: u64 = 0;
            for (merged) |seg| total_live += seg.liveRows();

            const next_flushed_lsn = if (current_base) |b|
                @max(b.flushed_lsn, candidate_flushed_lsn)
            else
                candidate_flushed_lsn;

            const next_manifest: TableManifest.Manifest = .{
                .catalog_id = catalog_id,
                .object_id = object_id,
                .manifest_version = target_version,
                .schema_revision = schema_revision,
                .layout_fingerprint = layout_fingerprint,
                .writer_epoch = lease.writer_epoch,
                .policy_epoch = lease.policy_epoch,
                .flushed_lsn = next_flushed_lsn,
                .live_row_count = total_live,
                .segments = merged,
            };

            const encode_buf = try allocator.alloc(u8, TableManifest.max_encoded_bytes);
            defer allocator.free(encode_buf);
            const encoded = try next_manifest.encode(encode_buf);

            var key_buf: [64]u8 = undefined;
            const key = try TableManifest.manifestKey(object_id, target_version, &key_buf);

            if (try store.putConditional(key, .if_none_match, encoded)) {
                return .{
                    .committed_version = target_version,
                    .rebased_attempts = rebased_attempts,
                };
            }

            // Another writer won `target_version`. Load the winning manifest and check PK overlap.
            rebased_attempts += 1;
            if (rebased_attempts > max_rebase_retries) return error.WriteWriteConflict;

            const winning_meta = (try store.head(key)) orelse return error.WriteWriteConflict;
            const winning_bytes = try allocator.alloc(u8, @intCast(winning_meta.size));
            defer allocator.free(winning_bytes);
            _ = try store.getRange(key, 0, @intCast(winning_meta.size), winning_bytes);

            var winning_owned = try TableManifest.decode(allocator, winning_bytes);
            errdefer winning_owned.deinit();

            try verifyDisjointFromConcurrentCommit(
                allocator,
                store,
                current_base,
                winning_owned.manifest,
                candidate_segment,
            );

            if (current_base_owned) |*prev| prev.deinit();
            current_base_owned = winning_owned;
            current_base = current_base_owned.?.manifest;
        }
        return error.WriteWriteConflict;
    }

    fn verifyDisjointFromConcurrentCommit(
        allocator: std.mem.Allocator,
        store: TransitObjectStore.ObjectStore,
        prior_base: ?TableManifest.Manifest,
        winning: TableManifest.Manifest,
        candidate: TableManifest.SegmentDescriptor,
    ) !void {
        if (winning.schema_revision == 0) return error.InvalidTableManifest;
        if (prior_base) |b| {
            if (winning.schema_revision != b.schema_revision or
                !std.mem.eql(u8, &winning.layout_fingerprint, &b.layout_fingerprint))
            {
                return error.WriteWriteConflict;
            }
        }

        for (winning.segments) |win_seg| {
            var existed = false;
            if (prior_base) |b| {
                for (b.segments) |old_seg| {
                    if (old_seg.segment_id == win_seg.segment_id) {
                        existed = true;
                        break;
                    }
                }
            }
            if (existed) continue;
            if (!win_seg.overlapsPkRange(candidate)) continue;

            if (try segmentsShareAnyPrimaryKey(allocator, store, win_seg, candidate)) {
                return error.WriteWriteConflict;
            }
        }
    }

    fn segmentsShareAnyPrimaryKey(
        allocator: std.mem.Allocator,
        store: TransitObjectStore.ObjectStore,
        seg_a: TableManifest.SegmentDescriptor,
        seg_b: TableManifest.SegmentDescriptor,
    ) !bool {
        const bytes_a = try allocator.alloc(u8, seg_a.tseg_bytes);
        defer allocator.free(bytes_a);
        _ = try store.getRange(seg_a.tseg_key, 0, seg_a.tseg_bytes, bytes_a);

        const bytes_b = try allocator.alloc(u8, seg_b.tseg_bytes);
        defer allocator.free(bytes_b);
        _ = try store.getRange(seg_b.tseg_key, 0, seg_b.tseg_bytes, bytes_b);

        var footer_a = try TSeg.readFooter(allocator, bytes_a);
        defer footer_a.deinit();
        var footer_b = try TSeg.readFooter(allocator, bytes_b);
        defer footer_b.deinit();

        return footer_a.overlapsPrimaryKeys(&footer_b);
    }
};
