//! Tier 0 MVCC Memtable + Direct Data-Plane `TWAL1` `.row_delta` ingestion +
//! Read-Your-Writes snapshot reader (merging Memtable with `.tseg`/`.tdel` segments) +
//! `.tseg`/`.tdel` segment flush and crash recovery.
const std = @import("std");
const TransitLog = @import("TransitLog.zig");
const TransitObjectStore = @import("TransitObjectStore.zig");
const TableManifest = @import("TableManifest.zig");
const PartitionLease = @import("PartitionLease.zig");
const NvmeCache = @import("NvmeCache.zig");
const fuze = @import("transit_fuze");
const TableSchema = fuze.TableSchema;
const TableRow = fuze.TableRow;
const Collation = fuze.Collation;
const TSeg = fuze.TSeg;
const TDel = fuze.TDel;
const Values = fuze.Types.Values;
const Cell = Values.Cell;

pub const DeltaOp = enum(u8) {
    upsert = 1,
    delete = 2,
};

pub const VersionedEntry = struct {
    lsn: u64,
    op: DeltaOp,
    pk_sort_key: []u8,
    encoded_row: []u8, // `FTR1` encoded `TableRow.Row` when `op == .upsert`
};

pub const DecodedDelta = struct {
    arena: std.heap.ArenaAllocator,
    object_id: u64,
    schema_revision: u64,
    op: DeltaOp,
    pk_sort_key: []const u8,
    encoded_row: []const u8,

    pub fn deinit(self: *DecodedDelta) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn encodeRowDeltaPayload(
    out: []u8,
    object_id: u64,
    schema_revision: u64,
    op: DeltaOp,
    pk_sort_key: []const u8,
    encoded_row: []const u8,
) ![]const u8 {
    var writer: std.Io.Writer = .fixed(out);
    try writer.writeAll("TRDL");
    try writer.writeByte(1); // v1
    try writer.writeInt(u64, object_id, .little);
    try writer.writeInt(u64, schema_revision, .little);
    try writer.writeByte(@backingInt(op));
    try writer.writeInt(u16, @intCast(pk_sort_key.len), .little);
    try writer.writeAll(pk_sort_key);
    try writer.writeInt(u32, @intCast(encoded_row.len), .little);
    try writer.writeAll(encoded_row);
    return writer.buffered();
}

pub fn decodeRowDeltaPayload(allocator: std.mem.Allocator, payload: []const u8) !DecodedDelta {
    if (payload.len < 4 + 1 + 8 + 8 + 1 + 2 + 4) return error.InvalidRowDelta;
    if (!std.mem.eql(u8, payload[0..4], "TRDL") or payload[4] != 1) return error.InvalidRowDelta;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();

    var reader: std.Io.Reader = .fixed(payload[5..]);
    const object_id = try reader.takeInt(u64, .little);
    const schema_revision = try reader.takeInt(u64, .little);
    const op = std.enums.fromInt(DeltaOp, try reader.takeByte()) orelse return error.InvalidRowDelta;
    const pk_len = try reader.takeInt(u16, .little);
    const pk_sort_key = try a.dupe(u8, try reader.take(pk_len));
    const row_len = try reader.takeInt(u32, .little);
    const encoded_row = try a.dupe(u8, try reader.take(row_len));
    if (reader.bufferedLen() != 0) return error.InvalidRowDelta;

    return .{
        .arena = arena,
        .object_id = object_id,
        .schema_revision = schema_revision,
        .op = op,
        .pk_sort_key = pk_sort_key,
        .encoded_row = encoded_row,
    };
}

pub const TableMemtable = struct {
    allocator: std.mem.Allocator,
    catalog_id: u64,
    object_id: u64,
    partition_id: u64,
    schema: TableSchema.Schema,
    layout_fingerprint: [32]u8,
    lease: PartitionLease.PartitionLease,
    log: TransitLog.Log,
    store: TransitObjectStore.ObjectStore,
    cache: ?*NvmeCache.NvmeCache = null,
    next_segment_id: u64 = 1,
    active_manifest_owned: ?TableManifest.OwnedManifest = null,
    entries: std.ArrayListUnmanaged(VersionedEntry) = .empty,

    pub fn init(
        allocator: std.mem.Allocator,
        catalog_id: u64,
        object_id: u64,
        partition_id: u64,
        schema: TableSchema.Schema,
        lease: PartitionLease.PartitionLease,
        log: TransitLog.Log,
        store: TransitObjectStore.ObjectStore,
        cache: ?*NvmeCache.NvmeCache,
    ) !TableMemtable {
        try schema.validate();
        const fp = try schema.layoutFingerprint();
        return .{
            .allocator = allocator,
            .catalog_id = catalog_id,
            .object_id = object_id,
            .partition_id = partition_id,
            .schema = schema,
            .layout_fingerprint = fp,
            .lease = lease,
            .log = log,
            .store = store,
            .cache = cache,
        };
    }

    pub fn deinit(self: *TableMemtable) void {
        self.clearEntries();
        self.entries.deinit(self.allocator);
        if (self.active_manifest_owned) |*owned| owned.deinit();
        self.* = undefined;
    }

    fn clearEntries(self: *TableMemtable) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.pk_sort_key);
            self.allocator.free(entry.encoded_row);
        }
        self.entries.clearRetainingCapacity();
    }

    pub fn upsertRow(self: *TableMemtable, row: TableRow.Row, now_ms: i64) !u64 {
        try self.lease.validateDataPartition(now_ms);
        try row.identity.validate();
        try self.schema.validateRow(row.cells);

        var pk_buf: [Collation.max_sort_key_bytes]u8 = undefined;
        const pk_sort_key = try Collation.encodePrimaryKeySortKey(self.schema, row.cells, true, &pk_buf);

        const row_buf = try self.allocator.alloc(u8, TableRow.max_bytes);
        defer self.allocator.free(row_buf);
        const encoded_row = try row.encode(self.schema, row_buf);

        const receipt = try self.appendWalDelta(.upsert, pk_sort_key, encoded_row);
        try self.applyInMemoryDelta(receipt.lsn, .upsert, pk_sort_key, encoded_row);
        return receipt.lsn;
    }

    pub fn deleteByPrimaryKey(self: *TableMemtable, key_cells: []const Cell, now_ms: i64) !u64 {
        try self.lease.validateDataPartition(now_ms);
        var pk_buf: [Collation.max_sort_key_bytes]u8 = undefined;
        const pk_sort_key = try Collation.encodePrimaryKeySortKey(self.schema, key_cells, false, &pk_buf);

        const receipt = try self.appendWalDelta(.delete, pk_sort_key, &.{});
        try self.applyInMemoryDelta(receipt.lsn, .delete, pk_sort_key, &.{});
        return receipt.lsn;
    }

    /// Read-Your-Writes snapshot point lookup by Primary Key at `snapshot_lsn`.
    /// Consults the Tier 0 MVCC Memtable first, then committed `.tseg`/`.tdel` segments
    /// in the active `TableManifest`.
    pub fn getByPrimaryKey(
        self: *TableMemtable,
        allocator: std.mem.Allocator,
        key_cells: []const Cell,
        snapshot_lsn: u64,
    ) !?TSeg.OwnedRow {
        var pk_buf: [Collation.max_sort_key_bytes]u8 = undefined;
        const pk_sort_key = try Collation.encodePrimaryKeySortKey(self.schema, key_cells, false, &pk_buf);

        // 1. Check Tier 0 MVCC Memtable from newest to oldest `<= snapshot_lsn`
        var idx = self.entries.items.len;
        while (idx > 0) {
            idx -= 1;
            const entry = self.entries.items[idx];
            if (entry.lsn > snapshot_lsn) continue;
            if (std.mem.eql(u8, entry.pk_sort_key, pk_sort_key)) {
                return switch (entry.op) {
                    .delete => null,
                    .upsert => try self.decodeOwnedRow(allocator, entry.encoded_row),
                };
            }
        }

        // 2. Probe committed `.tseg` segments from newest to oldest in `active_manifest`
        const manifest = if (self.active_manifest_owned) |m| m.manifest else return null;
        var seg_idx = manifest.segments.len;
        while (seg_idx > 0) {
            seg_idx -= 1;
            const seg = manifest.segments[seg_idx];
            if (!seg.mayContainPk(pk_sort_key)) continue;

            const tseg_bytes = try allocator.alloc(u8, seg.tseg_bytes);
            defer allocator.free(tseg_bytes);
            _ = try self.readObjectBytes(seg.tseg_key, seg.tseg_bytes, .metadata_or_index, tseg_bytes);

            var footer = try TSeg.readFooter(allocator, tseg_bytes);
            defer footer.deinit();

            var maybe_del: ?TDel.DeletionVector = null;
            defer if (maybe_del) |*d| d.deinit();
            if (seg.tdel_key) |dk| {
                const tdel_bytes = try allocator.alloc(u8, seg.tdel_bytes);
                defer allocator.free(tdel_bytes);
                _ = try self.readObjectBytes(dk, seg.tdel_bytes, .metadata_or_index, tdel_bytes);
                maybe_del = try TDel.DeletionVector.decode(allocator, tdel_bytes);
            }

            if (try TSeg.lookupPrimaryKey(
                allocator,
                self.schema,
                &footer,
                tseg_bytes,
                if (maybe_del) |*d| d else null,
                key_cells,
            )) |found| {
                return found;
            }
        }

        return null;
    }

    /// Flushes all active Tier 0 Memtable entries into a new immutable `.tseg` segment,
    /// writes `.tdel` deletion vectors for any prior segments whose keys were overwritten
    /// or deleted, and publishes `manifest/<object_id>/v{N+1}.tman` via conditional CAS.
    pub fn flushToSegment(self: *TableMemtable, now_ms: i64) !?TableManifest.Manifest {
        try self.lease.validateDataPartition(now_ms);
        if (self.entries.items.len == 0) {
            return if (self.active_manifest_owned) |m| m.manifest else null;
        }

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const a = arena.allocator();

        var latest_by_pk: std.StringArrayHashMapUnmanaged(VersionedEntry) = .empty;
        var max_flushed_lsn: u64 = if (self.active_manifest_owned) |m| m.manifest.flushed_lsn else 0;
        for (self.entries.items) |entry| {
            max_flushed_lsn = @max(max_flushed_lsn, entry.lsn);
            try latest_by_pk.put(a, entry.pk_sort_key, entry);
        }

        const prior_segments = if (self.active_manifest_owned) |m| m.manifest.segments else &[_]TableManifest.SegmentDescriptor{};
        const next_version: u64 = if (self.active_manifest_owned) |m| m.manifest.manifest_version + 1 else 1;

        var updated_segments: std.ArrayListUnmanaged(TableManifest.SegmentDescriptor) = .empty;
        for (prior_segments) |seg| {
            var updated_seg = seg;
            var seg_touches = false;
            var it = latest_by_pk.iterator();
            while (it.next()) |kv| {
                if (seg.mayContainPk(kv.key_ptr.*)) {
                    seg_touches = true;
                    break;
                }
            }
            if (seg_touches) {
                const tseg_bytes = try a.alloc(u8, seg.tseg_bytes);
                _ = try self.readObjectBytes(seg.tseg_key, seg.tseg_bytes, .metadata_or_index, tseg_bytes);
                var footer = try TSeg.readFooter(a, tseg_bytes);
                defer footer.deinit();

                var del_vec = if (seg.tdel_key) |dk| blk: {
                    const tdel_bytes = try a.alloc(u8, seg.tdel_bytes);
                    _ = try self.readObjectBytes(dk, seg.tdel_bytes, .metadata_or_index, tdel_bytes);
                    break :blk try TDel.DeletionVector.decode(a, tdel_bytes);
                } else try TDel.DeletionVector.init(a, seg.segment_id, seg.row_count);

                var newly_deleted: u32 = 0;
                var pk_it = latest_by_pk.iterator();
                while (pk_it.next()) |kv| {
                    if (footer.findPrimaryKeySortKey(kv.key_ptr.*)) |entry| {
                        if (try del_vec.markDeleted(entry.global_row_offset)) {
                            newly_deleted += 1;
                        }
                    }
                }

                if (newly_deleted > 0) {
                    const tdel_buf = try a.alloc(u8, 64 + seg.row_count * 4);
                    const encoded_tdel = try del_vec.encode(tdel_buf);
                    var tdel_sha: [32]u8 = undefined;
                    std.crypto.hash.sha2.Sha256.hash(encoded_tdel, &tdel_sha, .{});

                    var dk_buf: [64]u8 = undefined;
                    const dk = try a.dupe(u8, try TableManifest.deletionKey(self.object_id, seg.segment_id, next_version, &dk_buf));
                    _ = try self.store.putImmutable(dk, encoded_tdel, tdel_sha);

                    updated_seg.tdel_key = dk;
                    updated_seg.tdel_sha256 = tdel_sha;
                    updated_seg.tdel_bytes = @intCast(encoded_tdel.len);
                    updated_seg.deleted_count = del_vec.deleted_count;
                }
            }
            try updated_segments.append(a, updated_seg);
        }

        // Collect all live `.upsert` rows
        var live_rows: std.ArrayListUnmanaged(TableRow.Row) = .empty;
        var it = latest_by_pk.iterator();
        while (it.next()) |kv| {
            if (kv.value_ptr.op == .upsert) {
                const decoded = try TableRow.decode(a, self.schema, kv.value_ptr.encoded_row);
                try live_rows.append(a, decoded.row());
            }
        }

        if (live_rows.items.len > 0) {
            const seg_id = self.next_segment_id;
            self.next_segment_id += 1;

            const tseg_buf = try a.alloc(u8, TSeg.max_segment_bytes);
            const encoded_tseg = try TSeg.writeSegment(
                a,
                self.schema,
                live_rows.items,
                .{ .segment_id = seg_id },
                tseg_buf,
            );
            var tseg_sha: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(encoded_tseg, &tseg_sha, .{});

            var sk_buf: [64]u8 = undefined;
            const sk = try a.dupe(u8, try TableManifest.segmentKey(self.object_id, seg_id, &sk_buf));
            _ = try self.store.putImmutable(sk, encoded_tseg, tseg_sha);

            var footer = try TSeg.readFooter(a, encoded_tseg);
            defer footer.deinit();

            try updated_segments.append(a, .{
                .segment_id = seg_id,
                .tseg_key = sk,
                .tseg_sha256 = tseg_sha,
                .tseg_bytes = @intCast(encoded_tseg.len),
                .row_count = @intCast(live_rows.items.len),
                .deleted_count = 0,
                .min_pk_sort_key = try a.dupe(u8, footer.min_pk_sort_key),
                .max_pk_sort_key = try a.dupe(u8, footer.max_pk_sort_key),
            });
        }

        var total_live: u64 = 0;
        for (updated_segments.items) |seg| total_live += seg.liveRows();

        const next_manifest: TableManifest.Manifest = .{
            .catalog_id = self.catalog_id,
            .object_id = self.object_id,
            .manifest_version = next_version,
            .schema_revision = self.schema.revision,
            .layout_fingerprint = self.layout_fingerprint,
            .writer_epoch = self.lease.writer_epoch,
            .policy_epoch = self.lease.policy_epoch,
            .flushed_lsn = max_flushed_lsn,
            .live_row_count = total_live,
            .segments = updated_segments.items,
        };

        const man_buf = try a.alloc(u8, TableManifest.max_encoded_bytes);
        const encoded_man = try next_manifest.encode(man_buf);

        var mk_buf: [64]u8 = undefined;
        const mk = try TableManifest.manifestKey(self.object_id, next_version, &mk_buf);
        if (!try self.store.putConditional(mk, .if_none_match, encoded_man)) {
            return error.ManifestCasConflict;
        }

        const decoded_owned = try TableManifest.decode(self.allocator, encoded_man);
        if (self.active_manifest_owned) |*prev| prev.deinit();
        self.active_manifest_owned = decoded_owned;
        self.clearEntries();
        return self.active_manifest_owned.?.manifest;
    }

    /// Recovers the latest committed `TableManifest` from `TransitObjectStore` and replays
    /// any uncommitted `.row_delta` frames from `TransitLog` after the manifest checkpoint.
    pub fn recoverFromWal(self: *TableMemtable) !u64 {
        self.clearEntries();
        if (self.active_manifest_owned) |*prev| {
            prev.deinit();
            self.active_manifest_owned = null;
        }

        var version: u64 = 1;
        while (true) : (version += 1) {
            var mk_buf: [64]u8 = undefined;
            const mk = try TableManifest.manifestKey(self.object_id, version, &mk_buf);
            const meta = (try self.store.head(mk)) orelse break;
            const bytes = try self.allocator.alloc(u8, @intCast(meta.size));
            defer self.allocator.free(bytes);
            _ = try self.store.getRange(mk, 0, @intCast(meta.size), bytes);
            const owned = try TableManifest.decode(self.allocator, bytes);
            if (self.active_manifest_owned) |*prev| prev.deinit();
            self.active_manifest_owned = owned;
        }

        var start_lsn: u64 = 0;
        if (self.active_manifest_owned) |m| {
            start_lsn = m.manifest.flushed_lsn + 1;
            var max_seg_id: u64 = 0;
            for (m.manifest.segments) |seg| max_seg_id = @max(max_seg_id, seg.segment_id);
            self.next_segment_id = max_seg_id + 1;
        }

        var replayed: u64 = 0;
        var batch = try self.log.read(self.allocator, self.partition_id, start_lsn, 4096);
        defer batch.deinit();

        for (batch.frames) |frame| {
            if (frame.header.kind != .row_delta) continue;
            var delta = try decodeRowDeltaPayload(self.allocator, frame.payload);
            defer delta.deinit();
            if (delta.object_id != self.object_id) continue;

            try self.applyInMemoryDelta(
                frame.header.lsn,
                delta.op,
                delta.pk_sort_key,
                delta.encoded_row,
            );
            replayed += 1;
        }
        return replayed;
    }

    fn readObjectBytes(
        self: *TableMemtable,
        key: []const u8,
        len: u32,
        category: NvmeCache.CacheCategory,
        out: []u8,
    ) ![]const u8 {
        if (self.cache) |c| {
            return c.getRangeVerified(key, 0, len, category, out);
        }
        return self.store.getRange(key, 0, len, out);
    }

    fn appendWalDelta(
        self: *TableMemtable,
        op: DeltaOp,
        pk_sort_key: []const u8,
        encoded_row: []const u8,
    ) !TransitLog.AppendReceipt {
        const payload_buf = try self.allocator.alloc(u8, 64 + pk_sort_key.len + encoded_row.len);
        defer self.allocator.free(payload_buf);
        const payload = try encodeRowDeltaPayload(
            payload_buf,
            self.object_id,
            self.schema.revision,
            op,
            pk_sort_key,
            encoded_row,
        );
        return self.log.append(
            self.partition_id,
            null,
            self.lease.writer_epoch,
            self.lease.policy_epoch,
            .row_delta,
            payload,
        );
    }

    fn applyInMemoryDelta(
        self: *TableMemtable,
        lsn: u64,
        op: DeltaOp,
        pk_sort_key: []const u8,
        encoded_row: []const u8,
    ) !void {
        const pk_copy = try self.allocator.dupe(u8, pk_sort_key);
        errdefer self.allocator.free(pk_copy);
        const row_copy = try self.allocator.dupe(u8, encoded_row);
        errdefer self.allocator.free(row_copy);

        try self.entries.append(self.allocator, .{
            .lsn = lsn,
            .op = op,
            .pk_sort_key = pk_copy,
            .encoded_row = row_copy,
        });
    }

    fn decodeOwnedRow(self: *const TableMemtable, allocator: std.mem.Allocator, encoded_row: []const u8) !TSeg.OwnedRow {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        const decoded = try TableRow.decode(a, self.schema, encoded_row);
        const r = decoded.row();
        return .{
            .arena = arena,
            .identity = r.identity,
            .cells = r.cells,
        };
    }
};
