//! Hybrid OLTP/OLAP `.tseg` (`"TSEG"` v1) columnar segment format.
//! Combines 64-byte-aligned physical column pages, 5-state cell tag streams,
//! collation-aware zone maps, Bloom filters and a sorted primary-key directory.
//! Binary search applies after reading that directory; it is not a paged B-tree.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const TableRow = @import("TableRow.zig");
const Collation = @import("Collation.zig");
const PhysicalCodecs = @import("PhysicalCodecs.zig");
const TDel = @import("TDel.zig");

pub const alignment: usize = 64;
pub const default_rows_per_group: u32 = 1024;
pub const max_segment_bytes: usize = 16 * 1024 * 1024;

pub const ZoneMap = struct {
    min_sort_key: []const u8 = "",
    max_sort_key: []const u8 = "",
    value_count: u32 = 0,
    null_count: u32 = 0,
    missing_count: u32 = 0,
    error_count: u32 = 0,
    conflict_count: u32 = 0,
    bloom_mask: u64 = 0,

    pub fn bloomBit(sort_key: []const u8) u64 {
        const h1 = std.hash.Wyhash.hash(0x54534547, sort_key);
        const h2 = std.hash.Wyhash.hash(0xCAFEBABE, sort_key);
        return (@as(u64, 1) << @intCast(h1 & 63)) | (@as(u64, 1) << @intCast(h2 & 63));
    }

    /// Return whether this row group may contain rows matching `(op, target_sort_key)`.
    /// Zone map bounds (`min_sort_key`, `max_sort_key`) are encoded using the column's
    /// declared `Collation`, so range pruning is sound for `utf8_binary`, `ascii_ci`,
    /// and `ebcdic_cp037`. ICU profiles reject at schema admission.
    pub fn mayMatch(self: ZoneMap, op: enum { eq, lt, le, gt, ge }, target_sort_key: []const u8) bool {
        if (self.value_count == 0) return false;
        // A missing bound denotes an unindexed value group, not an empty group.
        // Long or unsupported sort keys must never make range pruning unsound.
        if (self.min_sort_key.len == 0 or self.max_sort_key.len == 0) return true;
        const cmp_min = std.mem.order(u8, target_sort_key, self.min_sort_key);
        const cmp_max = std.mem.order(u8, target_sort_key, self.max_sort_key);
        return switch (op) {
            .eq => {
                if (cmp_min == .lt or cmp_max == .gt) return false;
                const mask = bloomBit(target_sort_key);
                return (self.bloom_mask & mask) == mask;
            },
            .lt => cmp_min == .gt,
            .le => cmp_min != .lt,
            .gt => cmp_max == .lt,
            .ge => cmp_max != .gt,
        };
    }
};

pub const PageSlice = struct {
    offset: u64,
    length: u32,
    digest: [32]u8,
};

pub const RowGroupFooter = struct {
    row_count: u32,
    start_row_offset: u32,
    pages: []const PageSlice,
    zone_maps: []const ZoneMap,
};

pub const PkIndexEntry = struct {
    pk_sort_key: []const u8,
    identity: TableRow.Identity,
    row_group: u16,
    row_in_group: u16,
    global_row_offset: u32,
};

pub const Footer = struct {
    arena: std.heap.ArenaAllocator,
    segment_id: u64,
    object_id: u64,
    schema_revision: u64,
    layout_fingerprint: [32]u8,
    total_rows: u32,
    min_pk_sort_key: []const u8,
    max_pk_sort_key: []const u8,
    row_groups: []const RowGroupFooter,
    pk_index: []const PkIndexEntry,

    pub fn deinit(self: *Footer) void {
        self.arena.deinit();
        self.* = undefined;
    }

    /// O(log N) binary search over the already decoded primary-key directory.
    pub fn findPrimaryKeySortKey(self: *const Footer, target_pk_sort_key: []const u8) ?PkIndexEntry {
        if (self.pk_index.len == 0) return null;
        if (std.mem.order(u8, target_pk_sort_key, self.min_pk_sort_key) == .lt or
            std.mem.order(u8, target_pk_sort_key, self.max_pk_sort_key) == .gt)
        {
            return null;
        }
        var low: usize = 0;
        var high: usize = self.pk_index.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            const entry = self.pk_index[mid];
            switch (std.mem.order(u8, entry.pk_sort_key, target_pk_sort_key)) {
                .lt => low = mid + 1,
                .gt => high = mid,
                .eq => return entry,
            }
        }
        return null;
    }

    /// Check whether two segments have any overlapping primary keys.
    /// First checks `[min_pk_sort_key, max_pk_sort_key]` bounds in O(1),
    /// then performs a sorted merge/gallop intersection over `pk_index`.
    pub fn overlapsPrimaryKeys(self: *const Footer, other: *const Footer) bool {
        if (self.pk_index.len == 0 or other.pk_index.len == 0) return false;
        if (std.mem.order(u8, self.max_pk_sort_key, other.min_pk_sort_key) == .lt or
            std.mem.order(u8, other.max_pk_sort_key, self.min_pk_sort_key) == .lt)
        {
            return false;
        }
        var i: usize = 0;
        var j: usize = 0;
        while (i < self.pk_index.len and j < other.pk_index.len) {
            switch (std.mem.order(u8, self.pk_index[i].pk_sort_key, other.pk_index[j].pk_sort_key)) {
                .lt => i += 1,
                .gt => j += 1,
                .eq => return true,
            }
        }
        return false;
    }
};

pub const OwnedRow = struct {
    arena: std.heap.ArenaAllocator,
    identity: TableRow.Identity,
    cells: []const Values.Cell,
    pub fn row(self: *const OwnedRow) TableRow.Row {
        return .{ .identity = self.identity, .cells = self.cells };
    }
    pub fn deinit(self: *OwnedRow) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const BuildOptions = struct {
    segment_id: u64,
    rows_per_group: u32 = default_rows_per_group,
};

const SortableRow = struct {
    row: TableRow.Row,
    pk_sort_key: []const u8,
};

fn lessThanSortableRow(_: void, a: SortableRow, b: SortableRow) bool {
    const cmp = std.mem.order(u8, a.pk_sort_key, b.pk_sort_key);
    if (cmp != .eq) return cmp == .lt;
    const enc_a = a.row.identity.encode() catch unreachable;
    const enc_b = b.row.identity.encode() catch unreachable;
    return std.mem.order(u8, &enc_a, &enc_b) == .lt;
}

fn padTo64(writer: *std.Io.Writer) !void {
    const rem = writer.buffered().len % alignment;
    if (rem == 0) return;
    const pad = alignment - rem;
    var zeros: [alignment]u8 = @splat(0);
    try writer.writeAll(zeros[0..pad]);
}

/// Build an immutable `.tseg` segment from `rows` and `schema` into `out`.
/// Rows are sorted by their composite primary-key order-preserving sort key,
/// partitioned into row groups, encoded with each column's physical codec,
/// and indexed with collation-aware zone maps and a sorted PK footer directory.
pub fn writeSegment(
    allocator: std.mem.Allocator,
    schema: TableSchema.Schema,
    rows: []const TableRow.Row,
    options: BuildOptions,
    out: []u8,
) ![]const u8 {
    try schema.validate();
    if (options.segment_id == 0 or options.rows_per_group == 0 or options.rows_per_group > 65536) return error.InvalidSegmentOptions;
    if (out.len < 128) return error.BufferTooSmall;

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // 1. Validate rows and compute composite primary-key sort keys
    const sorted = try arena.alloc(SortableRow, rows.len);
    for (rows, 0..) |row, i| {
        try row.identity.validate();
        try schema.validateRow(row.cells);
        var key_buf: [Collation.max_sort_key_bytes]u8 = undefined;
        const pk_key = try row.storageKey(schema, &key_buf);
        sorted[i] = .{
            .row = row,
            .pk_sort_key = try arena.dupe(u8, pk_key),
        };
    }
    std.mem.sort(SortableRow, sorted, {}, lessThanSortableRow);

    // Ensure no duplicate primary keys within the same segment
    for (@min(1, sorted.len)..sorted.len) |i| {
        if (std.mem.eql(u8, sorted[i - 1].pk_sort_key, sorted[i].pk_sort_key)) {
            if (schema.primary_key.len == 0) return error.DuplicateRowIdentity;
            return error.DuplicatePrimaryKey;
        }
    }

    const layout_fp = try schema.layoutFingerprint();
    const num_cols = schema.columns.len;
    const group_count: usize = if (sorted.len == 0) 0 else (sorted.len + options.rows_per_group - 1) / options.rows_per_group;

    var writer: std.Io.Writer = .fixed(out);
    // Reserve 64-byte header (filled once footer_offset is known)
    var header_zeros: [64]u8 = @splat(0);
    try writer.writeAll(&header_zeros);

    const group_footers = try arena.alloc(RowGroupFooter, group_count);
    const pk_entries = try arena.alloc(PkIndexEntry, sorted.len);

    for (0..group_count) |gi| {
        const start_row: usize = gi * options.rows_per_group;
        const end_row: usize = @min(sorted.len, start_row + options.rows_per_group);
        const group_rows = sorted[start_row..end_row];

        for (group_rows, 0..) |sr, r_in_g| {
            pk_entries[start_row + r_in_g] = .{
                .pk_sort_key = sr.pk_sort_key,
                .identity = sr.row.identity,
                .row_group = @intCast(gi),
                .row_in_group = @intCast(r_in_g),
                .global_row_offset = @intCast(start_row + r_in_g),
            };
        }

        const pages = try arena.alloc(PageSlice, num_cols);
        const zone_maps = try arena.alloc(ZoneMap, num_cols);
        const col_cells = try arena.alloc(Values.Cell, group_rows.len);

        for (schema.columns, 0..) |col, ci| {
            var zm: ZoneMap = .{};
            var min_key: ?[]const u8 = null;
            var max_key: ?[]const u8 = null;
            var indexed = true;

            for (group_rows, 0..) |sr, ri| {
                const cell = sr.row.cells[ci];
                col_cells[ri] = cell;
                switch (cell) {
                    .value => {
                        zm.value_count += 1;
                        var sk_buf: [Collation.max_sort_key_bytes]u8 = undefined;
                        if (Collation.encodeSortKey(cell, col.type, col.collation, &sk_buf)) |sk| {
                            zm.bloom_mask |= ZoneMap.bloomBit(sk);
                            if (min_key == null or std.mem.order(u8, sk, min_key.?) == .lt) {
                                min_key = try arena.dupe(u8, sk);
                            }
                            if (max_key == null or std.mem.order(u8, sk, max_key.?) == .gt) {
                                max_key = try arena.dupe(u8, sk);
                            }
                        } else |_| {
                            indexed = false;
                        }
                    },
                    .null => zm.null_count += 1,
                    .missing => zm.missing_count += 1,
                    .type_error => zm.error_count += 1,
                    .conflict => zm.conflict_count += 1,
                }
            }
            zm.min_sort_key = if (indexed) min_key orelse "" else "";
            zm.max_sort_key = if (indexed) max_key orelse "" else "";
            if (!indexed) zm.bloom_mask = std.math.maxInt(u64);
            zone_maps[ci] = zm;

            try padTo64(&writer);
            const page_offset: u64 = @intCast(writer.buffered().len);
            const encoded_page = try PhysicalCodecs.encodeColumnPage(arena, col, col_cells, writer.buffer[writer.end..]);
            var page_digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(encoded_page, &page_digest, .{});
            writer.end += encoded_page.len;
            pages[ci] = .{
                .offset = page_offset,
                .length = @intCast(encoded_page.len),
                .digest = page_digest,
            };
        }

        group_footers[gi] = .{
            .row_count = @intCast(group_rows.len),
            .start_row_offset = @intCast(start_row),
            .pages = pages,
            .zone_maps = zone_maps,
        };
    }

    // 2. Write 64-byte-aligned Segment Footer
    try padTo64(&writer);
    const footer_offset: u64 = @intCast(writer.buffered().len);

    try writer.writeAll("TSF1");
    try writer.writeAll(&@import("transit_protocol").Growth.definition_bytes);
    try writer.writeInt(u64, options.segment_id, .little);
    try writer.writeInt(u64, schema.object, .little);
    try writer.writeInt(u64, schema.revision, .little);
    try writer.writeAll(&layout_fp);
    try writer.writeInt(u32, @intCast(sorted.len), .little);
    try writer.writeInt(u16, @intCast(group_count), .little);
    try writer.writeInt(u16, @intCast(num_cols), .little);

    const min_pk = if (pk_entries.len > 0) pk_entries[0].pk_sort_key else "";
    const max_pk = if (pk_entries.len > 0) pk_entries[pk_entries.len - 1].pk_sort_key else "";
    try writer.writeInt(u16, @intCast(min_pk.len), .little);
    try writer.writeAll(min_pk);
    try writer.writeInt(u16, @intCast(max_pk.len), .little);
    try writer.writeAll(max_pk);

    for (group_footers) |gf| {
        try writer.writeInt(u32, gf.row_count, .little);
        try writer.writeInt(u32, gf.start_row_offset, .little);
        for (gf.pages) |pg| {
            try writer.writeInt(u64, pg.offset, .little);
            try writer.writeInt(u32, pg.length, .little);
            try writer.writeAll(&pg.digest);
        }
        for (gf.zone_maps) |zm| {
            try writer.writeInt(u16, @intCast(zm.min_sort_key.len), .little);
            try writer.writeAll(zm.min_sort_key);
            try writer.writeInt(u16, @intCast(zm.max_sort_key.len), .little);
            try writer.writeAll(zm.max_sort_key);
            try writer.writeInt(u32, zm.value_count, .little);
            try writer.writeInt(u32, zm.null_count, .little);
            try writer.writeInt(u32, zm.missing_count, .little);
            try writer.writeInt(u32, zm.error_count, .little);
            try writer.writeInt(u32, zm.conflict_count, .little);
            try writer.writeInt(u64, zm.bloom_mask, .little);
        }
    }

    for (pk_entries) |pke| {
        try writer.writeInt(u16, @intCast(pke.pk_sort_key.len), .little);
        try writer.writeAll(pke.pk_sort_key);
        const id_bytes = try pke.identity.encode();
        try writer.writeAll(&id_bytes);
        try writer.writeInt(u16, pke.row_group, .little);
        try writer.writeInt(u16, pke.row_in_group, .little);
        try writer.writeInt(u32, pke.global_row_offset, .little);
    }

    const footer_body = writer.buffered()[@intCast(footer_offset)..];
    var footer_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(footer_body, &footer_digest, .{});
    try writer.writeAll(&footer_digest);

    const footer_length: u32 = @intCast(writer.buffered().len - @as(usize, @intCast(footer_offset)));
    // Write 16-byte trailer (`footer_offset: u64`, `footer_length: u32`, `"TSEG"`)
    try writer.writeInt(u64, footer_offset, .little);
    try writer.writeInt(u32, footer_length, .little);
    try writer.writeAll("TSEG");

    // 3. Fill in 64-byte header at offset 0
    var hdr_writer: std.Io.Writer = .fixed(out[0..64]);
    try hdr_writer.writeAll("TSEG");
    try hdr_writer.writeInt(u32, 1, .little); // version 1
    try hdr_writer.writeInt(u64, options.segment_id, .little);
    try hdr_writer.writeInt(u64, schema.object, .little);
    try hdr_writer.writeInt(u64, schema.revision, .little);
    try hdr_writer.writeInt(u32, @intCast(sorted.len), .little);
    try hdr_writer.writeInt(u16, @intCast(group_count), .little);
    try hdr_writer.writeInt(u16, @intCast(num_cols), .little);
    try hdr_writer.writeInt(u64, footer_offset, .little);
    try hdr_writer.writeInt(u32, footer_length, .little);
    try hdr_writer.writeAll(layout_fp[0..12]);

    return writer.buffered();
}

/// Read and verify the `.tseg` Segment Footer from `segment_bytes`.
pub fn readFooter(allocator: std.mem.Allocator, segment_bytes: []const u8) !Footer {
    if (segment_bytes.len < 64 + 136 + 16 or segment_bytes.len > max_segment_bytes) return error.InvalidSegment;
    const trailer = segment_bytes[segment_bytes.len - 16 ..];
    const location = try footerLocation(segment_bytes[0..64], trailer, segment_bytes.len);
    return readFooterParts(allocator, segment_bytes[0..64], segment_bytes[@intCast(location.offset)..][0..location.length], trailer, segment_bytes.len);
}

pub const FooterLocation = struct { offset: u64, length: u32 };

/// Validate the small fixed ranges before allocating or requesting the footer.
/// The source owner must bind these bytes to its expected immutable object.
pub fn footerLocation(header: []const u8, trailer: []const u8, segment_length: u64) !FooterLocation {
    if (header.len != 64 or trailer.len != 16 or segment_length < 64 + 136 + 16 or segment_length > max_segment_bytes) return error.InvalidSegment;
    if (!std.mem.eql(u8, header[0..4], "TSEG") or std.mem.readInt(u32, header[4..8], .little) != 1) return error.InvalidSegment;
    if (!std.mem.eql(u8, trailer[12..16], "TSEG")) return error.InvalidSegment;
    const footer_offset = std.mem.readInt(u64, trailer[0..8], .little);
    const footer_length = std.mem.readInt(u32, trailer[8..12], .little);
    if (footer_offset < 64 or footer_offset % alignment != 0 or footer_offset > segment_length - 16 or
        footer_length < 136 or footer_length != segment_length - 16 - footer_offset or
        footer_offset != std.mem.readInt(u64, header[40..48], .little) or
        footer_length != std.mem.readInt(u32, header[48..52], .little))
    {
        return error.InvalidSegment;
    }
    return .{ .offset = footer_offset, .length = footer_length };
}

/// Decode owned metadata from verified ranges. No column payload is required.
/// Counts and page/row coordinates are checked before they control allocation
/// or later range I/O. The directory is bounded by the encoded footer length.
pub fn readFooterParts(allocator: std.mem.Allocator, header: []const u8, footer_slice: []const u8, trailer: []const u8, segment_length: u64) !Footer {
    const location = try footerLocation(header, trailer, segment_length);
    if (footer_slice.len != location.length) return error.InvalidSegment;
    const footer_length = location.length;
    const footer_body = footer_slice[0 .. footer_length - 32];
    const expected_digest = footer_slice[footer_length - 32 ..][0..32];
    var actual_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(footer_body, &actual_digest, .{});
    if (!std.mem.eql(u8, &actual_digest, expected_digest)) return error.CorruptSegmentFooter;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();

    var reader: std.Io.Reader = .fixed(footer_body);
    if (!std.mem.eql(u8, try reader.take(4), "TSF1")) return error.InvalidSegment;
    if (!std.mem.eql(u8, try reader.take(32), &@import("transit_protocol").Growth.definition_bytes)) return error.IncompatibleDefinition;
    const segment_id = try reader.takeInt(u64, .little);
    const object_id = try reader.takeInt(u64, .little);
    const schema_revision = try reader.takeInt(u64, .little);
    var layout_fp: [32]u8 = undefined;
    layout_fp = (try reader.take(32))[0..32].*;
    const total_rows = try reader.takeInt(u32, .little);
    const group_count = try reader.takeInt(u16, .little);
    const col_count = try reader.takeInt(u16, .little);
    if (segment_id == 0 or object_id == 0 or schema_revision == 0 or col_count == 0 or col_count > 128 or
        segment_id != std.mem.readInt(u64, header[8..16], .little) or
        object_id != std.mem.readInt(u64, header[16..24], .little) or
        schema_revision != std.mem.readInt(u64, header[24..32], .little) or
        total_rows != std.mem.readInt(u32, header[32..36], .little) or
        group_count != std.mem.readInt(u16, header[36..38], .little) or
        col_count != std.mem.readInt(u16, header[38..40], .little) or
        !std.mem.eql(u8, layout_fp[0..12], header[52..64])) return error.InvalidSegment;
    // Even an empty key requires 30 bytes per directory entry. Every group
    // requires two u32 fields and at least 76 bytes per column. Do not allocate
    // attacker-supplied counts before proving their minimum encoded footprint.
    const minimum = @as(u64, total_rows) * 30 + @as(u64, group_count) * (8 + @as(u64, col_count) * 76) + 4;
    if (minimum > reader.bufferedLen() or (total_rows == 0) != (group_count == 0)) return error.InvalidSegment;

    const min_pk_len = try reader.takeInt(u16, .little);
    const min_pk = try a.dupe(u8, try reader.take(min_pk_len));
    const max_pk_len = try reader.takeInt(u16, .little);
    const max_pk = try a.dupe(u8, try reader.take(max_pk_len));

    const groups = try a.alloc(RowGroupFooter, group_count);
    var covered_rows: u64 = 0;
    var page_end: u64 = 64;
    for (groups) |*gf| {
        const rc = try reader.takeInt(u32, .little);
        const start_off = try reader.takeInt(u32, .little);
        if (rc == 0 or rc > 65536 or start_off != covered_rows or rc > total_rows - covered_rows) return error.InvalidSegment;
        covered_rows += rc;
        const pages = try a.alloc(PageSlice, col_count);
        for (pages) |*pg| {
            pg.* = .{
                .offset = try reader.takeInt(u64, .little),
                .length = try reader.takeInt(u32, .little),
                .digest = (try reader.take(32))[0..32].*,
            };
            if (pg.offset < page_end or pg.offset % alignment != 0 or pg.offset > location.offset or
                pg.length == 0 or pg.length > location.offset - pg.offset) return error.InvalidSegment;
            page_end = pg.offset + pg.length;
        }
        const zms = try a.alloc(ZoneMap, col_count);
        for (zms) |*zm| {
            const min_len = try reader.takeInt(u16, .little);
            const min_sk = try a.dupe(u8, try reader.take(min_len));
            const max_len = try reader.takeInt(u16, .little);
            const max_sk = try a.dupe(u8, try reader.take(max_len));
            zm.* = .{
                .min_sort_key = min_sk,
                .max_sort_key = max_sk,
                .value_count = try reader.takeInt(u32, .little),
                .null_count = try reader.takeInt(u32, .little),
                .missing_count = try reader.takeInt(u32, .little),
                .error_count = try reader.takeInt(u32, .little),
                .conflict_count = try reader.takeInt(u32, .little),
                .bloom_mask = try reader.takeInt(u64, .little),
            };
            if (@as(u64, zm.value_count) + zm.null_count + zm.missing_count + zm.error_count + zm.conflict_count != rc) return error.InvalidSegment;
            if ((min_sk.len == 0) != (max_sk.len == 0) or std.mem.order(u8, min_sk, max_sk) == .gt) return error.InvalidSegment;
        }
        gf.* = .{
            .row_count = rc,
            .start_row_offset = start_off,
            .pages = pages,
            .zone_maps = zms,
        };
    }
    if (covered_rows != total_rows) return error.InvalidSegment;

    const pk_index = try a.alloc(PkIndexEntry, total_rows);
    for (pk_index, 0..) |*pke, i| {
        const pk_len = try reader.takeInt(u16, .little);
        const pk_sk = try a.dupe(u8, try reader.take(pk_len));
        const id_raw = try reader.take(TableRow.Identity.encoded_bytes);
        const id = try TableRow.Identity.decode(id_raw[0..TableRow.Identity.encoded_bytes]);
        pke.* = .{
            .pk_sort_key = pk_sk,
            .identity = id,
            .row_group = try reader.takeInt(u16, .little),
            .row_in_group = try reader.takeInt(u16, .little),
            .global_row_offset = try reader.takeInt(u32, .little),
        };
        if (pke.row_group >= groups.len or pke.global_row_offset != i) return error.InvalidSegment;
        const group = groups[pke.row_group];
        if (pke.row_in_group >= group.row_count or @as(u64, group.start_row_offset) + pke.row_in_group != i) return error.InvalidSegment;
        if (i > 0 and std.mem.order(u8, pk_index[i - 1].pk_sort_key, pk_sk) != .lt) return error.InvalidSegment;
    }
    if (reader.bufferedLen() != 0) return error.InvalidSegment;
    if (pk_index.len == 0) {
        if (min_pk.len != 0 or max_pk.len != 0) return error.InvalidSegment;
    } else if (!std.mem.eql(u8, min_pk, pk_index[0].pk_sort_key) or !std.mem.eql(u8, max_pk, pk_index[pk_index.len - 1].pk_sort_key)) return error.InvalidSegment;

    return .{
        .arena = arena,
        .segment_id = segment_id,
        .object_id = object_id,
        .schema_revision = schema_revision,
        .layout_fingerprint = layout_fp,
        .total_rows = total_rows,
        .min_pk_sort_key = min_pk,
        .max_pk_sort_key = max_pk,
        .row_groups = groups,
        .pk_index = pk_index,
    };
}

/// Read and verify a single column page from `segment_bytes` for `(row_group_index, column_index)`.
pub fn decodeRowGroupColumn(
    arena: std.mem.Allocator,
    schema: TableSchema.Schema,
    footer: *const Footer,
    segment_bytes: []const u8,
    row_group_index: usize,
    column_index: usize,
) ![]Values.Cell {
    try requireInterpretation(schema, footer);
    if (row_group_index >= footer.row_groups.len or column_index >= schema.columns.len or
        column_index >= footer.row_groups[row_group_index].pages.len)
    {
        return error.InvalidSegmentCoordinate;
    }
    const page_meta = footer.row_groups[row_group_index].pages[column_index];
    if (page_meta.offset > segment_bytes.len or page_meta.length > segment_bytes.len - page_meta.offset) return error.InvalidSegment;
    const slice = segment_bytes[@intCast(page_meta.offset)..][0..page_meta.length];
    return decodeColumnRange(arena, schema, footer, slice, row_group_index, column_index);
}

/// Decode one complete verified column range. Values own their bytes in arena;
/// the caller can release the encoded range immediately after this returns.
pub fn decodeColumnRange(arena: std.mem.Allocator, schema: TableSchema.Schema, footer: *const Footer, slice: []const u8, row_group_index: usize, column_index: usize) ![]Values.Cell {
    try verifyColumnRange(schema, footer, slice, row_group_index, column_index);
    const cells = try PhysicalCodecs.decodeColumnPage(arena, schema.columns[column_index], slice);
    if (cells.len != footer.row_groups[row_group_index].row_count) return error.InvalidSegment;
    return cells;
}

/// Verify the exact encoded page before retaining it for repeated selections.
/// Logical decoding must still validate the page and its declared row count.
pub fn verifyColumnRange(schema: TableSchema.Schema, footer: *const Footer, slice: []const u8, row_group_index: usize, column_index: usize) !void {
    try requireInterpretation(schema, footer);
    if (row_group_index >= footer.row_groups.len or column_index >= schema.columns.len or
        column_index >= footer.row_groups[row_group_index].pages.len) return error.InvalidSegmentCoordinate;
    const page_meta = footer.row_groups[row_group_index].pages[column_index];
    if (slice.len != page_meta.length) return error.InvalidSegment;
    var actual_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(slice, &actual_digest, .{});
    if (!std.mem.eql(u8, &actual_digest, &page_meta.digest)) return error.CorruptSegmentPage;
}

/// Perform an O(log N) Primary-Key point lookup on a `.tseg` segment, respecting an optional
/// `.tdel` deletion vector. Decodes only the target row group!
pub fn lookupPrimaryKey(
    allocator: std.mem.Allocator,
    schema: TableSchema.Schema,
    footer: *const Footer,
    segment_bytes: []const u8,
    deletion_vector: ?*const TDel.DeletionVector,
    key_cells: []const Values.Cell,
) !?OwnedRow {
    var pk_buf: [Collation.max_sort_key_bytes]u8 = undefined;
    const pk_sort_key = try Collation.encodePrimaryKeySortKey(schema, key_cells, false, &pk_buf);
    return lookupStorageKey(allocator, schema, footer, segment_bytes, deletion_vector, pk_sort_key);
}

pub fn lookupIdentity(
    allocator: std.mem.Allocator,
    schema: TableSchema.Schema,
    footer: *const Footer,
    segment_bytes: []const u8,
    deletion_vector: ?*const TDel.DeletionVector,
    identity: TableRow.Identity,
) !?OwnedRow {
    if (schema.primary_key.len != 0) return error.TableHasPrimaryKey;
    return lookupStorageKey(allocator, schema, footer, segment_bytes, deletion_vector, &try identity.encode());
}

fn requireInterpretation(schema: TableSchema.Schema, footer: *const Footer) !void {
    if (schema.object != footer.object_id or schema.revision != footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &footer.layout_fingerprint)) return error.TableSchemaChanged;
}

pub fn lookupStorageKey(
    allocator: std.mem.Allocator,
    schema: TableSchema.Schema,
    footer: *const Footer,
    segment_bytes: []const u8,
    deletion_vector: ?*const TDel.DeletionVector,
    pk_sort_key: []const u8,
) !?OwnedRow {
    try requireInterpretation(schema, footer);
    if (deletion_vector) |del| {
        if (del.segment_id != footer.segment_id or del.total_rows != footer.total_rows) return error.IncompatibleDeletionVector;
    }
    const entry = footer.findPrimaryKeySortKey(pk_sort_key) orelse return null;
    if (deletion_vector) |del| {
        if (del.isDeleted(entry.global_row_offset)) return null;
    }

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();

    const row_cells = try a.alloc(Values.Cell, schema.columns.len);
    for (0..schema.columns.len) |ci| {
        const col_cells = try decodeRowGroupColumn(a, schema, footer, segment_bytes, entry.row_group, ci);
        row_cells[ci] = col_cells[entry.row_in_group];
    }
    return .{
        .arena = arena,
        .identity = entry.identity,
        .cells = row_cells,
    };
}
