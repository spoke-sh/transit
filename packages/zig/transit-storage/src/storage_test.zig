const std = @import("std");
const TransitLog = @import("TransitLog.zig");
const TransitObjectStore = @import("TransitObjectStore.zig");
const LocalWal = @import("LocalWal.zig");
const LocalSegmentStore = @import("LocalSegmentStore.zig");
const TableManifest = @import("TableManifest.zig");
const NvmeCache = @import("NvmeCache.zig");
const S3ObjectStore = @import("S3ObjectStore.zig");
const PartitionLease = @import("PartitionLease.zig");
const TableMemtable = @import("TableMemtable.zig");
const fuze = @import("transit_fuze");
const TableSchema = fuze.TableSchema;
const TableRow = fuze.TableRow;
const TSeg = fuze.TSeg;
const Cell = fuze.Types.Values.Cell;

test "LocalWal enforces epoch fencing, LSN ordering, and truncates torn tail on recovery" {
    const allocator = std.testing.allocator;
    var wal = LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    const log = wal.log();

    const r1 = try log.append(1, 0, 2, 3, .row_delta, "delta-0");
    try std.testing.expectEqual(@as(u64, 0), r1.lsn);
    try std.testing.expectEqual(@as(u64, 1), r1.next_lsn);
    try std.testing.expectEqual(@as(usize, 0), r1.frame_bytes % 64);

    // Reject duplicate / wrong expected LSN
    try std.testing.expectError(error.WalLsnConflict, log.append(1, 0, 2, 3, .row_delta, "dup"));

    // Reject stale writer_epoch
    try std.testing.expectError(error.StaleWriterEpoch, log.append(1, 1, 1, 3, .row_delta, "stale-writer"));

    // Append valid LSN 1
    const r2 = try log.append(1, 1, 2, 4, .row_delta, "delta-1");
    try std.testing.expectEqual(@as(u64, 1), r2.lsn);

    // Encode two frames and append 19 torn trailing bytes; verify decodeFrame detects TruncatedWalFrame
    var frame1_buf: [256]u8 = undefined;
    const f1 = try TransitLog.encodeFrame(1, 2, 3, 0, 1000, .row_delta, "delta-0", &frame1_buf);
    const dec1 = try TransitLog.decodeFrame(f1);
    try std.testing.expectEqual(f1.len, dec1.consumed_bytes);
    try std.testing.expectError(error.TruncatedWalFrame, TransitLog.decodeFrame(f1[0..19]));
}

test "S3ObjectStore signs AWS SigV4 requests and enforces conditional CAS and range reads" {
    const allocator = std.testing.allocator;
    var s3 = S3ObjectStore.S3ObjectStore.initLoopback(
        allocator,
        .{
            .access_key_id = "AKIAIOSFODNN7EXAMPLE",
            .secret_access_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            .region = "us-east-1",
        },
        "s3.us-east-1.amazonaws.com",
        "transit-segments",
    );
    defer s3.deinit();
    const store = s3.objectStore();

    const payload = "manifest-v1-bytes";
    const created = try store.putConditional("manifest/42/v1.tman", .if_none_match, payload);
    try std.testing.expect(created);
    try std.testing.expect(s3.last_signed != null);
    try std.testing.expect(std.mem.startsWith(
        u8,
        s3.last_signed.?.authorization(),
        "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20261022/us-east-1/s3/aws4_request",
    ));
    try std.testing.expectEqualStrings("*", s3.last_signed.?.if_none_match.?);

    // Duplicate `if_none_match` on the same manifest version returns false
    const duplicate = try store.putConditional("manifest/42/v1.tman", .if_none_match, payload);
    try std.testing.expect(!duplicate);

    // Range read produces `bytes=9-10`
    var range_out: [2]u8 = undefined;
    const slice = try store.getRange("manifest/42/v1.tman", 9, 2, &range_out);
    try std.testing.expectEqualStrings("v1", slice);
    try std.testing.expectEqualStrings("bytes=9-10", s3.last_signed.?.rangeHeader().?);
}

test "NvmeCache verifies SHA-256 on cached chunks and protects metadata chunks from scan eviction" {
    const allocator = std.testing.allocator;
    var local = LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer local.deinit();
    const store = local.objectStore();

    const chunk_len = NvmeCache.default_chunk_bytes;
    const blob = try allocator.alloc(u8, chunk_len);
    defer allocator.free(blob);
    @memset(blob, 0x5A);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(blob, &digest, .{});

    _ = try store.putImmutable("segments/1/footer.tseg", blob, digest);
    _ = try store.putImmutable("segments/1/colA.tseg", blob, digest);
    _ = try store.putImmutable("segments/1/colB.tseg", blob, digest);

    // Cache holds at most 2 chunks (128 KiB)
    var cache = NvmeCache.NvmeCache.init(allocator, store, chunk_len * 2);
    defer cache.deinit();

    var out: [64]u8 = undefined;
    // 1. Load metadata chunk ("footer.tseg")
    _ = try cache.getRangeVerified("segments/1/footer.tseg", 0, 64, .metadata_or_index, &out);
    // 2. Stream two sequential column chunks ("colA.tseg", "colB.tseg"), triggering eviction
    _ = try cache.getRangeVerified("segments/1/colA.tseg", 0, 64, .column_data, &out);
    _ = try cache.getRangeVerified("segments/1/colB.tseg", 0, 64, .column_data, &out);

    // Verify metadata chunk ("footer.tseg") was NOT evicted by sequential column scans!
    const hits_before = cache.stats.hits;
    _ = try cache.getRangeVerified("segments/1/footer.tseg", 0, 64, .metadata_or_index, &out);
    try std.testing.expectEqual(hits_before + 1, cache.stats.hits);

    // Corrupt cached chunk in memory and verify SHA-256 check automatically reloads from upstream
    try std.testing.expect(cache.corruptChunkForTesting("segments/1/footer.tseg", 0));
    _ = try cache.getRangeVerified("segments/1/footer.tseg", 0, 64, .metadata_or_index, &out);
    try std.testing.expectEqual(@as(u64, 1), cache.stats.corrupt_reloads);
    try std.testing.expectEqual(@as(u8, 0x5A), out[0]);
}

test "TableMemtable supports read-your-writes, flushes .tseg/.tdel, and recovers from WAL after crash" {
    const allocator = std.testing.allocator;
    var wal = LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var seg_store = LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer seg_store.deinit();
    var cache = NvmeCache.NvmeCache.init(allocator, seg_store.objectStore(), 512 * 1024);
    defer cache.deinit();

    const cols = [_]TableSchema.Column{
        .{ .id = 1, .name = "acct_id", .type = .int64, .nullable = false, .encoding = .bitpacked },
        .{ .id = 2, .name = "code", .type = .utf8, .nullable = false, .encoding = .fsst, .collation = .ascii_ci },
    };
    const pks = [_]TableSchema.ColumnId{1};
    const schema: TableSchema.Schema = .{
        .object = 500,
        .revision = 1,
        .next_column = 3,
        .columns = &cols,
        .primary_key = &pks,
    };
    const lease: PartitionLease.PartitionLease = .{
        .object_id = 500,
        .partition_id = 1,
        .holder_id = 9,
        .writer_epoch = 1,
        .policy_epoch = 1,
        .lease_until_ms = 2_000_000_000_000,
    };

    var memtable = try TableMemtable.TableMemtable.init(
        allocator,
        1,
        500,
        1,
        schema,
        lease,
        wal.log(),
        seg_store.objectStore(),
        &cache,
    );
    defer memtable.deinit();

    // Upsert 2 rows into Tier 0 Memtable
    const lsn0 = try memtable.upsertRow(.{
        .identity = .{ .origin = 1, .operation = 1, .ordinal = 0 },
        .cells = &.{ .{ .value = .{ .atom = .{ .signed = 10 } } }, .{ .value = .{ .atom = .{ .bytes = "ALPHA" } } } },
    }, 1_000);
    const lsn1 = try memtable.upsertRow(.{
        .identity = .{ .origin = 1, .operation = 2, .ordinal = 0 },
        .cells = &.{ .{ .value = .{ .atom = .{ .signed = 20 } } }, .{ .value = .{ .atom = .{ .bytes = "BETA" } } } },
    }, 1_000);
    try std.testing.expectEqual(@as(u64, 0), lsn0);
    try std.testing.expectEqual(@as(u64, 1), lsn1);

    // Read-Your-Writes from Memtable before flush
    {
        var row10 = (try memtable.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 10 } } }}, lsn1)).?;
        defer row10.deinit();
        try std.testing.expectEqualStrings("ALPHA", row10.cells[1].value.atom.bytes);
    }

    // Flush to Segment 1 (`v1.tman`)
    const man1 = (try memtable.flushToSegment(1_000)).?;
    try std.testing.expectEqual(@as(u64, 1), man1.manifest_version);
    try std.testing.expectEqual(@as(u64, 2), man1.live_row_count);
    try std.testing.expectEqual(@as(usize, 1), man1.segments.len);

    // Update acct_id=10, delete acct_id=20, and insert acct_id=30 in Memtable
    _ = try memtable.upsertRow(.{
        .identity = .{ .origin = 1, .operation = 3, .ordinal = 0 },
        .cells = &.{ .{ .value = .{ .atom = .{ .signed = 10 } } }, .{ .value = .{ .atom = .{ .bytes = "ALPHA_V2" } } } },
    }, 1_000);
    _ = try memtable.deleteByPrimaryKey(&.{.{ .value = .{ .atom = .{ .signed = 20 } } }}, 1_000);
    const lsn4 = try memtable.upsertRow(.{
        .identity = .{ .origin = 1, .operation = 5, .ordinal = 0 },
        .cells = &.{ .{ .value = .{ .atom = .{ .signed = 30 } } }, .{ .value = .{ .atom = .{ .bytes = "GAMMA" } } } },
    }, 1_000);

    // Read-Your-Writes merges uncommitted Memtable delta with committed `.tseg`
    {
        var row10_v2 = (try memtable.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 10 } } }}, lsn4)).?;
        defer row10_v2.deinit();
        try std.testing.expectEqualStrings("ALPHA_V2", row10_v2.cells[1].value.atom.bytes);
        try std.testing.expect((try memtable.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 20 } } }}, lsn4)) == null);
    }

    // Simulate ungraceful crash BEFORE second flush: instantiate a fresh TableMemtable and recoverFromWal!
    var recovered = try TableMemtable.TableMemtable.init(
        allocator,
        1,
        500,
        1,
        schema,
        lease,
        wal.log(),
        seg_store.objectStore(),
        &cache,
    );
    defer recovered.deinit();

    const replayed = try recovered.recoverFromWal();
    try std.testing.expectEqual(@as(u64, 3), replayed);

    // Now flush recovered state to `v2.tman` (emits `.tdel` on Segment 1 and writes Segment 2)
    const man2 = (try recovered.flushToSegment(1_000)).?;
    try std.testing.expectEqual(@as(u64, 2), man2.manifest_version);
    try std.testing.expectEqual(@as(u64, 2), man2.live_row_count); // acct_id 10 and 30 live; 20 deleted
    try std.testing.expect(man2.segments[0].tdel_key != null);
    try std.testing.expectEqual(@as(u32, 2), man2.segments[0].deleted_count);

    // Point lookups served from committed `.tseg` + `.tdel` via Tier 2 NVMe cache
    {
        var row10_post = (try recovered.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 10 } } }}, lsn4)).?;
        defer row10_post.deinit();
        try std.testing.expectEqualStrings("ALPHA_V2", row10_post.cells[1].value.atom.bytes);
        try std.testing.expect((try recovered.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 20 } } }}, lsn4)) == null);
        var row30_post = (try recovered.getByPrimaryKey(allocator, &.{.{ .value = .{ .atom = .{ .signed = 30 } } }}, lsn4)).?;
        defer row30_post.deinit();
        try std.testing.expectEqualStrings("GAMMA", row30_post.cells[1].value.atom.bytes);
    }
}

test "OccCoordinator automatically rebases disjoint concurrent .tseg commits and rejects overlapping PKs" {
    const allocator = std.testing.allocator;
    var seg_store = LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer seg_store.deinit();
    const store = seg_store.objectStore();

    const cols = [_]TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false, .encoding = .plain },
    };
    const pks = [_]TableSchema.ColumnId{1};
    const schema: TableSchema.Schema = .{
        .object = 900,
        .revision = 1,
        .next_column = 2,
        .columns = &cols,
        .primary_key = &pks,
    };
    const fp = try schema.layoutFingerprint();

    const Helper = struct {
        fn writeSingleRowSegment(
            alloc: std.mem.Allocator,
            st: TransitObjectStore.ObjectStore,
            s: TableSchema.Schema,
            seg_id: u64,
            pk_val: i64,
            key_str: []const u8,
            pk_buf: *[64]u8,
        ) !TableManifest.SegmentDescriptor {
            const cells = [_]Cell{.{ .value = .{ .atom = .{ .signed = pk_val } } }};
            const rows = [_]TableRow.Row{.{
                .identity = .{ .origin = 1, .operation = seg_id, .ordinal = 0 },
                .cells = &cells,
            }};
            const buf = try alloc.alloc(u8, 64 * 1024);
            defer alloc.free(buf);
            const encoded = try TSeg.writeSegment(alloc, s, &rows, .{ .segment_id = seg_id }, buf);
            var sha: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(encoded, &sha, .{});
            _ = try st.putImmutable(key_str, encoded, sha);

            var footer = try TSeg.readFooter(alloc, encoded);
            defer footer.deinit();
            const sk = footer.min_pk_sort_key;
            @memcpy(pk_buf[0..sk.len], sk);

            return .{
                .segment_id = seg_id,
                .tseg_key = key_str,
                .tseg_sha256 = sha,
                .tseg_bytes = @intCast(encoded.len),
                .row_count = 1,
                .min_pk_sort_key = pk_buf[0..sk.len],
                .max_pk_sort_key = pk_buf[0..sk.len],
            };
        }
    };

    var pk1_buf: [64]u8 = undefined;
    const seg1 = try Helper.writeSingleRowSegment(allocator, store, schema, 1, 100, "segments/900/seg-1.tseg", &pk1_buf);
    var pk2_buf: [64]u8 = undefined;
    const seg2 = try Helper.writeSingleRowSegment(allocator, store, schema, 2, 200, "segments/900/seg-2.tseg", &pk2_buf);
    var pk3_buf: [64]u8 = undefined;
    const seg3_conflict = try Helper.writeSingleRowSegment(allocator, store, schema, 3, 100, "segments/900/seg-3.tseg", &pk3_buf);

    const lease: PartitionLease.PartitionLease = .{
        .object_id = 900,
        .partition_id = 1,
        .holder_id = 1,
        .writer_epoch = 1,
        .policy_epoch = 1,
        .lease_until_ms = 2_000_000_000_000,
    };

    // Writer A commits seg1 (id=100) from base=null -> wins v1.tman
    const out_a = try PartitionLease.OccCoordinator.commitSegment(
        allocator,
        store,
        1,
        900,
        1,
        fp,
        lease,
        1_000,
        null,
        seg1,
        10,
    );
    try std.testing.expectEqual(@as(u64, 1), out_a.committed_version);
    try std.testing.expectEqual(@as(u32, 0), out_a.rebased_attempts);

    // Writer B concurrently started from base=null with disjoint seg2 (id=200) -> automatically rebases to v2.tman!
    const out_b = try PartitionLease.OccCoordinator.commitSegment(
        allocator,
        store,
        1,
        900,
        1,
        fp,
        lease,
        1_000,
        null,
        seg2,
        11,
    );
    try std.testing.expectEqual(@as(u64, 2), out_b.committed_version);
    try std.testing.expectEqual(@as(u32, 1), out_b.rebased_attempts);

    // Writer C concurrently started from base=null with conflicting seg3_conflict (id=100) -> rejected with WriteWriteConflict!
    try std.testing.expectError(
        error.WriteWriteConflict,
        PartitionLease.OccCoordinator.commitSegment(
            allocator,
            store,
            1,
            900,
            1,
            fp,
            lease,
            1_000,
            null,
            seg3_conflict,
            12,
        ),
    );
}
