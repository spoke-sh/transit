//! Columnar `.tseg` + `.tdel` + Tier 0 `TableMemtable` scan for `transit_query`.
//! Performs collation-aware Zone-Map + Bloom filter row-group pruning and feeds
//! both `f.Batch` (`VectorBatch`) and `f.LogicalQuery.Execution`.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const storage = c.storage;
const Self = @This();

pub const ZoneFilter = struct {
    column: u8,
    op: enum { eq, lt, le, gt, ge },
    target_sort_key: []const u8,
};

pub const CandidateRow = struct {
    pk_sort_key: []const u8,
    identity: f.TableRow.Identity,
    cells: []const f.Types.Values.Cell,
};

fn lessThanCandidate(_: void, a: CandidateRow, b: CandidateRow) bool {
    const cmp = std.mem.order(u8, a.pk_sort_key, b.pk_sort_key);
    if (cmp != .eq) return cmp == .lt;
    const enc_a = a.identity.encode() catch unreachable;
    const enc_b = b.identity.encode() catch unreachable;
    return std.mem.order(u8, &enc_a, &enc_b) == .lt;
}

allocator: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
schema: f.TableSchema.Schema,
rows: []const CandidateRow,
cursor: usize = 0,
scanned: u64 = 0,
complete: bool = false,
segments_inspected: u64 = 0,
segments_pruned: u64 = 0,
row_groups_inspected: u64 = 0,
row_groups_pruned: u64 = 0,
rows_decoded: u64 = 0,

pub fn init(
    allocator: std.mem.Allocator,
    memtable: *storage.TableMemtable.TableMemtable,
    snapshot_lsn: u64,
    plan: ?f.LogicalQuery.Plan,
) !Self {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();

    const schema = memtable.schema;
    const filters = try extractZoneFilters(a, schema, plan);

    // 1. Collect latest Tier 0 MVCC Memtable state per pk_sort_key at `<= snapshot_lsn`
    var mem_by_pk: std.StringArrayHashMapUnmanaged(storage.TableMemtable.VersionedEntry) = .empty;
    for (memtable.entries.items) |entry| {
        if (entry.lsn > snapshot_lsn) continue;
        try mem_by_pk.put(a, entry.pk_sort_key, entry);
    }

    var live_by_pk: std.StringArrayHashMapUnmanaged(CandidateRow) = .empty;
    var segments_inspected: u64 = 0;
    var segments_pruned: u64 = 0;
    var row_groups_inspected: u64 = 0;
    var row_groups_pruned: u64 = 0;
    var rows_decoded: u64 = 0;

    // 2. Scan committed `.tseg` segments from oldest to newest
    if (memtable.active_manifest_owned) |man_owned| {
        for (man_owned.manifest.segments) |seg| {
            segments_inspected += 1;
            if (seg.liveRows() == 0) {
                segments_pruned += 1;
                continue;
            }

            const tseg_bytes = try a.alloc(u8, seg.tseg_bytes);
            if (memtable.cache) |cache| {
                _ = try cache.getRangeVerified(seg.tseg_key, 0, seg.tseg_bytes, .column_data, tseg_bytes);
            } else {
                _ = try memtable.store.getRange(seg.tseg_key, 0, seg.tseg_bytes, tseg_bytes);
            }

            var footer = try f.TSeg.readFooter(a, tseg_bytes);
            defer footer.deinit();

            var maybe_del: ?f.TDel.DeletionVector = null;
            defer if (maybe_del) |*d| d.deinit();
            if (seg.tdel_key) |dk| {
                const tdel_bytes = try a.alloc(u8, seg.tdel_bytes);
                if (memtable.cache) |cache| {
                    _ = try cache.getRangeVerified(dk, 0, seg.tdel_bytes, .metadata_or_index, tdel_bytes);
                } else {
                    _ = try memtable.store.getRange(dk, 0, seg.tdel_bytes, tdel_bytes);
                }
                maybe_del = try f.TDel.DeletionVector.decode(a, tdel_bytes);
            }

            for (footer.row_groups, 0..) |rg, gi| {
                row_groups_inspected += 1;
                if (!rowGroupMayMatch(rg, filters)) {
                    row_groups_pruned += 1;
                    continue;
                }

                // Check if all rows in this row group are deleted in `.tdel`
                var any_live_in_group = false;
                for (0..rg.row_count) |r_in_g| {
                    const global_off: u32 = rg.start_row_offset + @as(u32, @intCast(r_in_g));
                    if (maybe_del) |*del| {
                        if (del.isDeleted(global_off)) continue;
                    }
                    const pke = footer.pk_index[global_off];
                    if (mem_by_pk.contains(pke.pk_sort_key)) continue;
                    any_live_in_group = true;
                    break;
                }
                if (!any_live_in_group) {
                    row_groups_pruned += 1;
                    continue;
                }

                // Decode column pages for this surviving row group
                const decoded_cols = try a.alloc([]f.Types.Values.Cell, schema.columns.len);
                for (0..schema.columns.len) |ci| {
                    decoded_cols[ci] = try f.TSeg.decodeRowGroupColumn(a, schema, &footer, tseg_bytes, gi, ci);
                }

                for (0..rg.row_count) |r_in_g| {
                    const global_off: u32 = rg.start_row_offset + @as(u32, @intCast(r_in_g));
                    if (maybe_del) |*del| {
                        if (del.isDeleted(global_off)) continue;
                    }
                    const pke = footer.pk_index[global_off];
                    if (mem_by_pk.contains(pke.pk_sort_key)) continue;

                    const cells = try a.alloc(f.Types.Values.Cell, schema.columns.len);
                    for (0..schema.columns.len) |ci| {
                        cells[ci] = decoded_cols[ci][r_in_g];
                    }
                    const pk_copy = try a.dupe(u8, pke.pk_sort_key);
                    try live_by_pk.put(a, pk_copy, .{
                        .pk_sort_key = pk_copy,
                        .identity = pke.identity,
                        .cells = cells,
                    });
                    rows_decoded += 1;
                }
            }
        }
    }

    // 3. Merge uncommitted live `.upsert` entries from Tier 0 `TableMemtable`
    var mem_it = mem_by_pk.iterator();
    while (mem_it.next()) |kv| {
        const entry = kv.value_ptr.*;
        if (entry.op == .delete) {
            _ = live_by_pk.swapRemove(kv.key_ptr.*);
            continue;
        }
        const decoded = try f.TableRow.decode(a, schema, entry.encoded_row);
        const r = decoded.row();
        const pk_copy = try a.dupe(u8, entry.pk_sort_key);
        try live_by_pk.put(a, pk_copy, .{
            .pk_sort_key = pk_copy,
            .identity = r.identity,
            .cells = r.cells,
        });
        rows_decoded += 1;
    }

    // 4. Sort live rows by canonical primary-key sort key
    const candidates = try a.alloc(CandidateRow, live_by_pk.count());
    for (live_by_pk.values(), 0..) |cand, idx| {
        candidates[idx] = cand;
    }
    std.mem.sort(CandidateRow, candidates, {}, lessThanCandidate);

    return .{
        .allocator = allocator,
        .arena = arena,
        .schema = schema,
        .rows = candidates,
        .segments_inspected = segments_inspected,
        .segments_pruned = segments_pruned,
        .row_groups_inspected = row_groups_inspected,
        .row_groups_pruned = row_groups_pruned,
        .rows_decoded = rows_decoded,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.* = undefined;
}

pub fn reset(self: *Self) void {
    self.cursor = 0;
    self.scanned = 0;
    self.complete = false;
}

pub fn next(self: *Self) !?f.LogicalQuery.Row {
    return self.nextAllocated(self.allocator);
}

pub fn nextAllocated(self: *Self, row_allocator: std.mem.Allocator) !?f.LogicalQuery.Row {
    if (self.complete) return null;
    if (self.cursor >= self.rows.len) {
        self.complete = true;
        return null;
    }
    const cand = self.rows[self.cursor];
    self.cursor += 1;
    self.scanned += 1;

    var row_arena = std.heap.ArenaAllocator.init(row_allocator);
    errdefer row_arena.deinit();
    const ra = row_arena.allocator();
    const cloned_cells = try ra.alloc(f.Types.Values.Cell, cand.cells.len);
    for (cand.cells, 0..) |cell, i| {
        cloned_cells[i] = try f.Types.Values.cloneValidated(ra, cell);
    }
    return .{
        .arena = row_arena,
        .cells = cloned_cells,
    };
}

/// Fills a vectorized `f.Batch` (`VectorBatch`) from the remaining rows in the scan
/// and evaluates the batch's vectorized predicate kernel (`batch.evaluate()`).
pub fn fillBatch(self: *Self, batch: *f.Batch) !usize {
    batch.reset();
    var appended: usize = 0;
    while (self.cursor < self.rows.len and batch.len < batch.capacity) {
        const cand = self.rows[self.cursor];
        const row_num: u64 = @intCast(self.cursor + 1);
        batch.appendValidated(cand.cells, .{
            .row = row_num,
            .boundary = row_num,
            .identity = cand.identity,
        }) catch |err| switch (err) {
            error.BatchFull => break,
            else => return err,
        };
        self.cursor += 1;
        self.scanned += 1;
        appended += 1;
    }
    if (self.cursor >= self.rows.len) self.complete = true;
    if (appended > 0) batch.evaluate();
    return appended;
}

fn rowGroupMayMatch(rg: f.TSeg.RowGroupFooter, filters: []const ZoneFilter) bool {
    for (filters) |flt| {
        if (flt.column >= rg.zone_maps.len) continue;
        const zm = rg.zone_maps[flt.column];
        const matches = switch (flt.op) {
            .eq => zm.mayMatch(.eq, flt.target_sort_key),
            .lt => zm.mayMatch(.lt, flt.target_sort_key),
            .le => zm.mayMatch(.le, flt.target_sort_key),
            .gt => zm.mayMatch(.gt, flt.target_sort_key),
            .ge => zm.mayMatch(.ge, flt.target_sort_key),
        };
        if (!matches) return false;
    }
    return true;
}

fn extractZoneFilters(
    arena: std.mem.Allocator,
    schema: f.TableSchema.Schema,
    maybe_plan: ?f.LogicalQuery.Plan,
) ![]const ZoneFilter {
    const plan = maybe_plan orelse return &.{};
    var list: std.ArrayListUnmanaged(ZoneFilter) = .empty;
    switch (plan.predicate) {
        .compare => |cmp| {
            if (try buildZoneFilter(arena, schema, cmp)) |zf| {
                try list.append(arena, zf);
            }
        },
        .program => |prog| {
            // Only extract conjunctive atoms if the program has no disjunction or negation
            var purely_conjunctive = true;
            for (prog.instructions) |inst| {
                switch (inst) {
                    .atom, .conjunction => {},
                    .negate, .disjunction => {
                        purely_conjunctive = false;
                        break;
                    },
                }
            }
            if (purely_conjunctive) {
                for (prog.instructions) |inst| {
                    if (inst == .atom and inst.atom == .compare) {
                        if (try buildZoneFilter(arena, schema, inst.atom.compare)) |zf| {
                            try list.append(arena, zf);
                        }
                    }
                }
            }
        },
        else => {},
    }
    return list.items;
}

fn buildZoneFilter(
    arena: std.mem.Allocator,
    schema: f.TableSchema.Schema,
    cmp: @FieldType(f.LogicalQuery.Plan.Atom, "compare"),
) !?ZoneFilter {
    if (cmp.column >= schema.columns.len) return null;
    const col = schema.columns[cmp.column];
    // logical.Plan comparisons evaluate with standard UTF-8 binary order on text
    // unless the column uses binary/numeric ordering; only prune when the column's
    // Zone Map collation is order-compatible with the predicate.
    if (col.type == .utf8 and col.collation != .none and col.collation != .utf8_binary) {
        return null;
    }
    const zm_op: @FieldType(ZoneFilter, "op") = switch (cmp.op) {
        .eq => .eq,
        .lt => .lt,
        .le => .le,
        .gt => .gt,
        .ge => .ge,
        .ne => return null,
    };
    var sk_buf: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const cell: f.Types.Values.Cell = .{ .value = .{ .atom = cmp.value } };
    const sk = f.Collation.encodeSortKey(cell, col.type, col.collation, &sk_buf) catch return null;
    return .{
        .column = cmp.column,
        .op = zm_op,
        .target_sort_key = try arena.dupe(u8, sk),
    };
}

test "TableSegmentScan prunes .tseg row groups via Zone Maps and feeds vectorized Batch + LogicalQuery.Execution" {
    const t = std.testing;
    var engine = try c.TableStorageEngine.initMemory(t.allocator, 1);
    defer engine.deinit();

    const cols = [_]f.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false, .encoding = .bitpacked },
        .{ .id = 2, .name = "venue", .type = .utf8, .encoding = .dictionary, .collation = .utf8_binary },
        .{ .id = 3, .name = "qty", .type = .int64, .encoding = .rle },
    };
    const schema: f.TableSchema.Schema = .{
        .object = 10,
        .revision = 1,
        .next_column = 4,
        .columns = &cols,
        .primary_key = &.{1},
    };
    const lease: storage.PartitionLease.PartitionLease = .{
        .object_id = 10,
        .partition_id = 1,
        .holder_id = 1,
        .writer_epoch = 1,
        .policy_epoch = 1,
        .lease_until_ms = 60_000,
    };
    const memtable = try engine.registerTable(10, 1, schema, lease);

    // Write 2 segments:
    // Segment 1: id 1..4 (qty 10..40)
    // Segment 2: id 100..103 (qty 1000..4000)
    for (0..4) |i| {
        const id_val: i128 = @intCast(i + 1);
        _ = try engine.upsertRow(10, .{
            .identity = .{ .origin = 1, .operation = 1, .ordinal = @intCast(i) },
            .cells = &.{
                .{ .value = .{ .atom = .{ .signed = id_val } } },
                .{ .value = .{ .atom = .{ .bytes = "XNAS" } } },
                .{ .value = .{ .atom = .{ .signed = id_val * 10 } } },
            },
        }, 1_000);
    }
    _ = try engine.flushTable(10, 1_000);

    for (0..4) |i| {
        const id_val: i128 = @intCast(100 + i);
        _ = try engine.upsertRow(10, .{
            .identity = .{ .origin = 1, .operation = 2, .ordinal = @intCast(i) },
            .cells = &.{
                .{ .value = .{ .atom = .{ .signed = id_val } } },
                .{ .value = .{ .atom = .{ .bytes = "XNYS" } } },
                .{ .value = .{ .atom = .{ .signed = id_val * 10 } } },
            },
        }, 2_000);
    }
    _ = try engine.flushTable(10, 2_000);

    // Also add 1 uncommitted row in Tier 0 Memtable (id = 200, qty = 5000)
    const latest_lsn = try engine.upsertRow(10, .{
        .identity = .{ .origin = 1, .operation = 3, .ordinal = 0 },
        .cells = &.{
            .{ .value = .{ .atom = .{ .signed = 200 } } },
            .{ .value = .{ .atom = .{ .bytes = "XNAS" } } },
            .{ .value = .{ .atom = .{ .signed = 5000 } } },
        },
    }, 3_000);

    const plan: f.LogicalQuery.Plan = .{
        .schema = .{
            .structure = &.{
                .{ .name = "id", .type = .int64 },
                .{ .name = "venue", .type = .utf8 },
                .{ .name = "qty", .type = .int64 },
            },
        },
        .source_basis = @splat(0x42),
        .projection = &.{ 0, 1, 2 },
        .predicate = .{
            .compare = .{
                .column = 0,
                .op = .ge,
                .value = .{ .signed = 100 },
            },
        },
    };

    var seg_scan = try Self.init(t.allocator, memtable, latest_lsn, plan);
    defer seg_scan.deinit();

    // Segment 1's row group (id 1..4) must be pruned by Zone Map for `id >= 100`!
    try t.expectEqual(@as(u64, 2), seg_scan.segments_inspected);
    try t.expectEqual(@as(u64, 2), seg_scan.row_groups_inspected);
    try t.expectEqual(@as(u64, 1), seg_scan.row_groups_pruned);
    // Only Segment 2 (4 rows) + Tier 0 Memtable (1 row) = 5 rows decoded
    try t.expectEqual(@as(u64, 5), seg_scan.rows_decoded);

    // Fill a vectorized Batch and verify all 5 rows evaluate to true
    var batch = try f.Batch.init(t.allocator, plan, .{ .rows = 64, .bytes = 65536 });
    defer batch.deinit();
    const count = try seg_scan.fillBatch(&batch);
    try t.expectEqual(@as(usize, 5), count);
    for (batch.outcomes[0..count]) |outcome| {
        try t.expect(outcome.truth.selects());
    }

    // Reset and run through LogicalQuery.Execution
    seg_scan.reset();
    var exec = try f.LogicalQuery.Execution(*Self, .full_source).init(&seg_scan, plan);
    var selected_rows: usize = 0;
    while (try exec.next()) |owned_row| {
        var row = owned_row;
        defer row.deinit();
        try t.expect(row.cells[0].value.atom.signed >= 100);
        selected_rows += 1;
    }
    try t.expectEqual(@as(usize, 5), selected_rows);
}
