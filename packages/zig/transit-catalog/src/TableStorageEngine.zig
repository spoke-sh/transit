//! Live table storage engine wiring `transit_storage` (`TableMemtable`, `LocalWal`,
//! `LocalSegmentStore`, `TableManifest`, `PartitionLease`, `NvmeCache`) and
//! `transit_fuze` (`.tseg` `TSeg`, `.tdel` `TDel`, `PhysicalCodecs`, `Collation`)
//! into `transit_catalog`.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const storage = c.storage;
const Self = @This();

allocator: std.mem.Allocator,
catalog_id: u64,
wal: storage.LocalWal.LocalWal,
segment_store: storage.LocalSegmentStore.LocalSegmentStore,
cache: ?*storage.NvmeCache.NvmeCache = null,
tables: std.AutoArrayHashMapUnmanaged(u64, *storage.TableMemtable.TableMemtable) = .empty,

pub fn initMemory(allocator: std.mem.Allocator, catalog_id: u64) !Self {
    if (catalog_id == 0) return error.InvalidCatalogIdentity;
    return .{
        .allocator = allocator,
        .catalog_id = catalog_id,
        .wal = storage.LocalWal.LocalWal.initMemory(allocator),
        .segment_store = storage.LocalSegmentStore.LocalSegmentStore.initMemory(allocator),
    };
}

pub fn openDisk(
    allocator: std.mem.Allocator,
    io: std.Io,
    catalog_id: u64,
    wal_dir: []const u8,
    segment_dir: []const u8,
) !Self {
    if (catalog_id == 0) return error.InvalidCatalogIdentity;
    var wal = try storage.LocalWal.LocalWal.openDisk(allocator, io, wal_dir);
    errdefer wal.deinit();
    var seg_store = try storage.LocalSegmentStore.LocalSegmentStore.openDisk(allocator, io, segment_dir);
    errdefer seg_store.deinit();
    return .{
        .allocator = allocator,
        .catalog_id = catalog_id,
        .wal = wal,
        .segment_store = seg_store,
    };
}

pub fn deinit(self: *Self) void {
    for (self.tables.values()) |memtable_ptr| {
        memtable_ptr.deinit();
        self.allocator.destroy(memtable_ptr);
    }
    self.tables.deinit(self.allocator);
    self.segment_store.deinit();
    self.wal.deinit();
    self.* = undefined;
}

pub fn registerTable(
    self: *Self,
    object_id: u64,
    partition_id: u64,
    schema: f.TableSchema.Schema,
    lease: storage.PartitionLease.PartitionLease,
) !*storage.TableMemtable.TableMemtable {
    if (object_id == 0 or lease.object_id != object_id or lease.partition_id != partition_id) {
        return error.InvalidPartitionLease;
    }
    if (self.tables.get(object_id)) |existing| {
        if (existing.partition_id != partition_id or !std.mem.eql(u8, &(try existing.schema.fingerprint()), &(try schema.fingerprint()))) return error.TableDefinitionChanged;
        if (lease.writer_epoch < existing.lease.writer_epoch or lease.policy_epoch < existing.lease.policy_epoch) return error.StaleEpoch;
        existing.lease = lease;
        return existing;
    }
    const memtable_ptr = try self.allocator.create(storage.TableMemtable.TableMemtable);
    errdefer self.allocator.destroy(memtable_ptr);
    memtable_ptr.* = try storage.TableMemtable.TableMemtable.init(
        self.allocator,
        self.catalog_id,
        object_id,
        partition_id,
        schema,
        lease,
        self.wal.log(),
        self.segment_store.objectStore(),
        self.cache,
    );
    errdefer memtable_ptr.deinit();
    try self.tables.put(self.allocator, object_id, memtable_ptr);
    return memtable_ptr;
}

pub fn getTable(self: *Self, object_id: u64) ?*storage.TableMemtable.TableMemtable {
    return self.tables.get(object_id);
}

pub fn upsertRow(
    self: *Self,
    object_id: u64,
    row: f.TableRow.Row,
    now_ms: i64,
) !u64 {
    const memtable = self.tables.get(object_id) orelse return error.TableNotFound;
    return memtable.upsertRow(row, now_ms);
}

pub fn deleteByPrimaryKey(
    self: *Self,
    object_id: u64,
    key_cells: []const f.Types.Values.Cell,
    now_ms: i64,
) !u64 {
    const memtable = self.tables.get(object_id) orelse return error.TableNotFound;
    return memtable.deleteByPrimaryKey(key_cells, now_ms);
}

pub fn getByPrimaryKey(
    self: *Self,
    allocator: std.mem.Allocator,
    object_id: u64,
    key_cells: []const f.Types.Values.Cell,
    snapshot_lsn: u64,
) !?f.TSeg.OwnedRow {
    const memtable = self.tables.get(object_id) orelse return error.TableNotFound;
    return memtable.getByPrimaryKey(allocator, key_cells, snapshot_lsn);
}

pub fn flushTable(
    self: *Self,
    object_id: u64,
    now_ms: i64,
) !?storage.TableManifest.Manifest {
    const memtable = self.tables.get(object_id) orelse return error.TableNotFound;
    return memtable.flushToSegment(now_ms);
}

pub fn recoverTable(self: *Self, object_id: u64) !u64 {
    const memtable = self.tables.get(object_id) orelse return error.TableNotFound;
    return memtable.recoverFromWal();
}

pub fn activeManifest(self: *const Self, object_id: u64) ?storage.TableManifest.Manifest {
    const memtable = self.tables.get(object_id) orelse return null;
    return if (memtable.active_manifest_owned) |owned| owned.manifest else null;
}

pub fn applyDmlRows(
    self: *Self,
    object_id: u64,
    partition_id: u64,
    schema: f.TableSchema.Schema,
    lease: storage.PartitionLease.PartitionLease,
    rows: []const f.TableRow.Row,
    now_ms: i64,
    flush_immediately: bool,
) !u64 {
    const memtable = try self.registerTable(object_id, partition_id, schema, lease);
    var last_lsn: u64 = 0;
    for (rows) |row| {
        last_lsn = try memtable.upsertRow(row, now_ms);
    }
    if (flush_immediately and rows.len != 0) {
        _ = try memtable.flushToSegment(now_ms);
    }
    return last_lsn;
}

test "registered Tables own their schema and reject implicit reinterpretation" {
    const t = std.testing;
    var engine = try Self.initMemory(t.allocator, 1);
    defer engine.deinit();
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "key", .type = .int64, .nullable = false }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const lease: storage.PartitionLease.PartitionLease = .{ .object_id = 7, .partition_id = 1, .holder_id = 2, .writer_epoch = 2, .policy_epoch = 2, .lease_until_ms = 1000 };
    var input = try schema.clone(t.allocator);
    const registered = try engine.registerTable(7, 1, input.schema, lease);
    try t.expect(input.schema.columns[0].name.ptr != registered.schema.columns[0].name.ptr);
    input.deinit();
    try t.expectEqualStrings("key", registered.schema.columns[0].name);
    var changed = schema;
    changed.revision = 2;
    try t.expectError(error.TableDefinitionChanged, engine.registerTable(7, 1, changed, lease));
    var stale = lease;
    stale.writer_epoch = 1;
    try t.expectError(error.StaleEpoch, engine.registerTable(7, 1, schema, stale));
    try t.expectEqual(@as(u64, 1), registered.schema.revision);
}

test "TableStorageEngine registers tables, ingests rows, flushes .tseg/.tdel segments, and recovers" {
    const t = std.testing;
    var engine = try Self.initMemory(t.allocator, 100);
    defer engine.deinit();

    const cols = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "ticker", .type = .utf8, .nullable = false, .encoding = .dictionary, .collation = .ascii_ci },
        .{ .id = 2, .name = "price_cents", .type = .int64, .encoding = .bitpacked },
    };
    const schema: f.TableSchema.Schema = .{
        .object = 7,
        .revision = 1,
        .next_column = 3,
        .columns = &cols,
        .primary_key = &.{1},
    };
    const lease: storage.PartitionLease.PartitionLease = .{
        .object_id = 7,
        .partition_id = 1,
        .holder_id = 42,
        .writer_epoch = 1,
        .policy_epoch = 1,
        .lease_until_ms = 60_000,
    };
    _ = try engine.registerTable(7, 1, schema, lease);

    const rows = [_]f.TableRow.Row{
        .{
            .identity = .{ .origin = 1, .operation = 1, .ordinal = 0 },
            .cells = &.{
                .{ .value = .{ .atom = .{ .bytes = "AAPL" } } },
                .{ .value = .{ .atom = .{ .signed = 18500 } } },
            },
        },
        .{
            .identity = .{ .origin = 1, .operation = 1, .ordinal = 1 },
            .cells = &.{
                .{ .value = .{ .atom = .{ .bytes = "MSFT" } } },
                .{ .value = .{ .atom = .{ .signed = 42000 } } },
            },
        },
    };

    const last_lsn = try engine.applyDmlRows(7, 1, schema, lease, &rows, 1_000, true);
    try t.expectEqual(@as(u64, 1), last_lsn);

    const manifest = engine.activeManifest(7).?;
    try t.expectEqual(@as(u64, 1), manifest.manifest_version);
    try t.expectEqual(@as(u64, 2), manifest.live_row_count);
    try t.expectEqual(@as(usize, 1), manifest.segments.len);

    // Case-insensitive primary key lookup ("aapl" matches "AAPL" under .ascii_ci)
    var found = (try engine.getByPrimaryKey(
        t.allocator,
        7,
        &.{.{ .value = .{ .atom = .{ .bytes = "aapl" } } }},
        10,
    )).?;
    defer found.deinit();
    try t.expectEqual(@as(i128, 18500), found.cells[1].value.atom.signed);

    // Delete "AAPL" and flush a .tdel deletion vector
    _ = try engine.deleteByPrimaryKey(7, &.{.{ .value = .{ .atom = .{ .bytes = "aapl" } } }}, 2_000);
    const man2 = (try engine.flushTable(7, 2_000)).?;
    try t.expectEqual(@as(u64, 2), man2.manifest_version);
    try t.expectEqual(@as(u64, 1), man2.live_row_count);
    try t.expect(man2.segments[0].tdel_key != null);

    try t.expect((try engine.getByPrimaryKey(
        t.allocator,
        7,
        &.{.{ .value = .{ .atom = .{ .bytes = "AAPL" } } }},
        10,
    )) == null);
}
