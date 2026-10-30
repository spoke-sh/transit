//! Adaptive `.tseg` Document path shredder (`DocumentShredder`).
//!
//! Shreds declared and frequent document paths into typed five-state subcolumns
//! with `transit-bitmap` (`RBC1`) presence, null, and conflict bitmaps and
//! collation-aware (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`) zone maps, while
//! retaining `SuccinctTree` topologies for unshredded residual paths.
const std = @import("std");
const bitmap = @import("transit_bitmap");
const doc_lib = @import("transit_document");
const p = @import("transit_protocol");
const vm = doc_lib.VersionedMerge;
const SuccinctTree = doc_lib.SuccinctTree;
const Collation = p.DocumentDeclaration.Collation;
const Shredding = p.DocumentDeclaration.Shredding;

pub const max_rows_per_segment: usize = bitmap.values_per_container;

pub const Error = error{
    EmptyDocumentBatch,
    BatchTooLarge,
    RowOutOfBounds,
    InvalidDocumentShredding,
    InvalidBitmapCardinality,
    BitmapBufferAlias,
    BitmapOutputTooSmall,
    InvalidBitmapEncoding,
    NonCanonicalBitmap,
    InvalidProvenanceSpan,
    EmptySuccinctTree,
    InvalidSuccinctTree,
    NodeOutOfBounds,
    TreeTooLarge,
    OutOfMemory,
};

pub const ZoneMap = struct {
    row_count: u32 = 0,
    value_count: u32 = 0,
    null_count: u32 = 0,
    missing_count: u32 = 0,
    type_error_count: u32 = 0,
    conflict_count: u32 = 0,
    min_int64: ?i64 = null,
    max_int64: ?i64 = null,
    min_string: ?[]u8 = null,
    max_string: ?[]u8 = null,
    min_prefix_u32: ?u32 = null,
    max_prefix_u32: ?u32 = null,

    pub fn deinit(self: *ZoneMap, allocator: std.mem.Allocator) void {
        if (self.min_string) |s| allocator.free(s);
        if (self.max_string) |s| allocator.free(s);
        self.* = undefined;
    }

    pub fn mayContainInt64(self: ZoneMap, needle: i64) bool {
        const lo = self.min_int64 orelse return false;
        const hi = self.max_int64 orelse return false;
        return needle >= lo and needle <= hi;
    }

    pub fn mayContainString(self: ZoneMap, collation: Collation, needle: []const u8) bool {
        const lo = self.min_string orelse return false;
        const hi = self.max_string orelse return false;
        const needle_p = computePrefixU32(collation, needle);
        if (self.min_prefix_u32) |lo_p| {
            if (needle_p < lo_p) return false;
        }
        if (self.max_prefix_u32) |hi_p| {
            if (needle_p > hi_p) return false;
        }
        return compareStrings(collation, needle, lo) != .lt and
            compareStrings(collation, needle, hi) != .gt;
    }
};

pub const Subcolumn = struct {
    path: []u8,
    collation: Collation,
    states: []vm.CellState,
    cells: []OwnedCell,
    present_bitmap_bytes: []u8,
    null_bitmap_bytes: []u8,
    conflict_bitmap_bytes: []u8,
    zone_map: ZoneMap,

    pub const OwnedCell = union(vm.CellState) {
        value: vm.Scalar,
        null_value: void,
        missing: void,
        type_error: []u8,
        conflict: []vm.Scalar,

        pub fn deinit(self: *OwnedCell, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .value => |s| s.deinit(allocator),
                .null_value, .missing => {},
                .type_error => |msg| allocator.free(msg),
                .conflict => |items| {
                    for (items) |s| s.deinit(allocator);
                    allocator.free(items);
                },
            }
            self.* = undefined;
        }

        pub fn view(self: *const OwnedCell) vm.Cell {
            return switch (self.*) {
                .value => |s| .{ .value = s },
                .null_value => .null_value,
                .missing => .missing,
                .type_error => |msg| .{ .type_error = msg },
                .conflict => |items| .{ .conflict = items },
            };
        }
    };

    pub fn deinit(self: *Subcolumn, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.states);
        for (self.cells) |*c| c.deinit(allocator);
        allocator.free(self.cells);
        allocator.free(self.present_bitmap_bytes);
        allocator.free(self.null_bitmap_bytes);
        allocator.free(self.conflict_bitmap_bytes);
        self.zone_map.deinit(allocator);
        self.* = undefined;
    }

    pub fn presentView(self: *const Subcolumn) Error!bitmap.View {
        return bitmap.View.parse(self.present_bitmap_bytes);
    }

    pub fn nullView(self: *const Subcolumn) Error!bitmap.View {
        return bitmap.View.parse(self.null_bitmap_bytes);
    }

    pub fn conflictView(self: *const Subcolumn) Error!bitmap.View {
        return bitmap.View.parse(self.conflict_bitmap_bytes);
    }
};

pub const ShreddedBatch = struct {
    row_count: u32,
    subcolumns: []Subcolumn,
    residual_trees: []SuccinctTree,

    pub fn deinit(self: *ShreddedBatch, allocator: std.mem.Allocator) void {
        for (self.subcolumns) |*col| col.deinit(allocator);
        allocator.free(self.subcolumns);
        for (self.residual_trees) |*tree| tree.deinit(allocator);
        allocator.free(self.residual_trees);
        self.* = undefined;
    }

    pub fn findSubcolumn(self: *const ShreddedBatch, dot_path: []const u8) ?*const Subcolumn {
        for (self.subcolumns) |*col| {
            if (std.mem.eql(u8, col.path, dot_path)) return col;
        }
        return null;
    }

    /// Evaluates `path_segments` for `row_index`: uses the shredded subcolumn in
    /// $O(1)$ if `path_segments` was shredded, or falls back to residual tree
    /// traversal over `fallback_root`.
    pub fn evaluatePath(
        self: *const ShreddedBatch,
        scratch: std.mem.Allocator,
        row_index: usize,
        fallback_root: *const vm.Node,
        path_segments: []const []const u8,
    ) Error!vm.Cell {
        if (row_index >= self.row_count) return error.RowOutOfBounds;
        const dot_path = try joinPath(scratch, path_segments);
        if (self.findSubcolumn(dot_path)) |col| {
            return col.cells[row_index].view();
        }
        return vm.evaluatePath(fallback_root, path_segments);
    }
};

pub fn shredBatch(
    output: std.mem.Allocator,
    scratch: std.mem.Allocator,
    config: Shredding,
    declared_paths: []const []const []const u8,
    documents: []const vm.Node,
) Error!ShreddedBatch {
    try config.validate();
    if (documents.len == 0) return error.EmptyDocumentBatch;
    if (documents.len > max_rows_per_segment) return error.BatchTooLarge;

    const PathEntry = struct {
        dot: []const u8,
        segments: []const []const u8,
        count: u32,
        declared: bool,
    };

    var path_map: std.StringArrayHashMapUnmanaged(PathEntry) = .empty;
    for (declared_paths) |segments| {
        if (segments.len == 0) continue;
        const dot = try joinPath(scratch, segments);
        try path_map.put(scratch, dot, .{
            .dot = dot,
            .segments = segments,
            .count = 0,
            .declared = true,
        });
    }

    var prefix: std.ArrayListUnmanaged([]const u8) = .empty;
    for (documents) |*doc| {
        prefix.clearRetainingCapacity();
        try collectDocumentPaths(scratch, &path_map, &prefix, doc);
    }

    var selected: std.ArrayListUnmanaged(PathEntry) = .empty;
    for (path_map.values()) |entry| {
        if (entry.declared or entry.count >= config.frequent_path_threshold) {
            try selected.append(scratch, entry);
        }
    }

    // Sort declared first, then descending frequency, then canonical dot path.
    std.mem.sort(PathEntry, selected.items, {}, struct {
        fn lessThan(_: void, a: PathEntry, b: PathEntry) bool {
            if (a.declared != b.declared) return a.declared;
            if (a.count != b.count) return a.count > b.count;
            return std.mem.order(u8, a.dot, b.dot) == .lt;
        }
    }.lessThan);

    const col_count = @min(selected.items.len, config.max_shredded_columns);
    const chosen = selected.items[0..col_count];

    // Sort chosen columns by canonical dot path for deterministic layout.
    std.mem.sort(PathEntry, chosen, {}, struct {
        fn lessThan(_: void, a: PathEntry, b: PathEntry) bool {
            return std.mem.order(u8, a.dot, b.dot) == .lt;
        }
    }.lessThan);

    const subcolumns = try output.alloc(Subcolumn, col_count);
    var built_cols: usize = 0;
    errdefer {
        for (subcolumns[0..built_cols]) |*c| c.deinit(output);
        output.free(subcolumns);
    }

    const present_container = try scratch.create(bitmap.Container);
    const null_container = try scratch.create(bitmap.Container);
    const conflict_container = try scratch.create(bitmap.Container);
    const encode_scratch = try scratch.alloc(u8, bitmap.max_encoded_bytes);

    for (chosen, 0..) |entry, col_idx| {
        subcolumns[col_idx] = try buildSubcolumn(
            output,
            entry.dot,
            entry.segments,
            config.default_collation,
            documents,
            present_container,
            null_container,
            conflict_container,
            encode_scratch,
        );
        built_cols += 1;
    }

    const residual_trees = try output.alloc(SuccinctTree, documents.len);
    var built_trees: usize = 0;
    errdefer {
        for (residual_trees[0..built_trees]) |*tr| tr.deinit(output);
        output.free(residual_trees);
    }
    for (documents, 0..) |*doc, row_idx| {
        residual_trees[row_idx] = try vm.buildSuccinctTree(output, scratch, doc);
        built_trees += 1;
    }

    return .{
        .row_count = @intCast(documents.len),
        .subcolumns = subcolumns,
        .residual_trees = residual_trees,
    };
}

pub fn compareStrings(collation: Collation, a: []const u8, b: []const u8) std.math.Order {
    switch (collation) {
        .utf8_binary => return std.mem.order(u8, a, b),
        .ascii_ci => {
            const min_len = @min(a.len, b.len);
            for (a[0..min_len], b[0..min_len]) |ca, cb| {
                const la = std.ascii.toLower(ca);
                const lb = std.ascii.toLower(cb);
                if (la != lb) return std.math.order(la, lb);
            }
            return std.math.order(a.len, b.len);
        },
        .ebcdic_cp037 => {
            const min_len = @min(a.len, b.len);
            for (a[0..min_len], b[0..min_len]) |ca, cb| {
                const ea = asciiToEbcdicWeight(ca);
                const eb = asciiToEbcdicWeight(cb);
                if (ea != eb) return std.math.order(ea, eb);
            }
            return std.math.order(a.len, b.len);
        },
    }
}

fn asciiToEbcdicWeight(c: u8) u8 {
    // In EBCDIC CP037, lowercase letters (0x81..0xA9) sort before uppercase
    // letters (0xC1..0xE9), and both sort before digits (0xF0..0xF9).
    if (std.ascii.isLower(c)) return 0x80 + (c - 'a');
    if (std.ascii.isUpper(c)) return 0xC0 + (c - 'A');
    if (std.ascii.isDigit(c)) return 0xF0 + (c - '0');
    return c & 0x7F;
}

pub fn computePrefixU32(collation: Collation, s: []const u8) u32 {
    var pref: [4]u8 = @splat(0);
    const n = @min(s.len, 4);
    for (s[0..n], 0..) |c, i| {
        pref[i] = switch (collation) {
            .utf8_binary => c,
            .ascii_ci => std.ascii.toLower(c),
            .ebcdic_cp037 => asciiToEbcdicWeight(c),
        };
    }
    return std.mem.readInt(u32, &pref, .big);
}

fn buildSubcolumn(
    output: std.mem.Allocator,
    dot_path: []const u8,
    segments: []const []const u8,
    collation: Collation,
    documents: []const vm.Node,
    present_container: *bitmap.Container,
    null_container: *bitmap.Container,
    conflict_container: *bitmap.Container,
    encode_scratch: []u8,
) Error!Subcolumn {
    present_container.clear();
    null_container.clear();
    conflict_container.clear();

    const path_copy = try output.dupe(u8, dot_path);
    errdefer output.free(path_copy);

    const states = try output.alloc(vm.CellState, documents.len);
    errdefer output.free(states);

    const cells = try output.alloc(Subcolumn.OwnedCell, documents.len);
    var initialized_cells: usize = 0;
    errdefer {
        for (cells[0..initialized_cells]) |*c| c.deinit(output);
        output.free(cells);
    }

    var zm: ZoneMap = .{ .row_count = @intCast(documents.len) };
    errdefer zm.deinit(output);

    for (documents, 0..) |*doc, row_idx| {
        const cell = vm.evaluatePath(doc, segments);
        const state = std.meta.activeTag(cell);
        states[row_idx] = state;
        const r16: u16 = @intCast(row_idx);

        switch (cell) {
            .value => |s| {
                _ = present_container.set(r16);
                zm.value_count += 1;
                cells[row_idx] = .{ .value = try s.clone(output) };
                initialized_cells += 1;
                try updateZoneMap(output, collation, &zm, s);
            },
            .null_value => {
                _ = null_container.set(r16);
                zm.null_count += 1;
                cells[row_idx] = .null_value;
                initialized_cells += 1;
            },
            .missing => {
                zm.missing_count += 1;
                cells[row_idx] = .missing;
                initialized_cells += 1;
            },
            .type_error => |msg| {
                zm.type_error_count += 1;
                cells[row_idx] = .{ .type_error = try output.dupe(u8, msg) };
                initialized_cells += 1;
            },
            .conflict => |items| {
                _ = conflict_container.set(r16);
                zm.conflict_count += 1;
                const copy = try output.alloc(vm.Scalar, items.len);
                var init_s: usize = 0;
                errdefer {
                    for (copy[0..init_s]) |item| item.deinit(output);
                    output.free(copy);
                }
                for (items, 0..) |item, i| {
                    copy[i] = try item.clone(output);
                    init_s += 1;
                }
                cells[row_idx] = .{ .conflict = copy };
                initialized_cells += 1;
            },
        }
    }

    const present_bytes = try output.dupe(u8, try present_container.encode(encode_scratch));
    errdefer output.free(present_bytes);
    const null_bytes = try output.dupe(u8, try null_container.encode(encode_scratch));
    errdefer output.free(null_bytes);
    const conflict_bytes = try output.dupe(u8, try conflict_container.encode(encode_scratch));
    errdefer output.free(conflict_bytes);

    return .{
        .path = path_copy,
        .collation = collation,
        .states = states,
        .cells = cells,
        .present_bitmap_bytes = present_bytes,
        .null_bitmap_bytes = null_bytes,
        .conflict_bitmap_bytes = conflict_bytes,
        .zone_map = zm,
    };
}

fn updateZoneMap(
    output: std.mem.Allocator,
    collation: Collation,
    zm: *ZoneMap,
    s: vm.Scalar,
) Error!void {
    switch (s) {
        .int64 => |v| {
            zm.min_int64 = if (zm.min_int64) |cur| @min(cur, v) else v;
            zm.max_int64 = if (zm.max_int64) |cur| @max(cur, v) else v;
        },
        .string => |v| {
            const p = computePrefixU32(collation, v);
            if (zm.min_string == null or compareStrings(collation, v, zm.min_string.?) == .lt) {
                const copy = try output.dupe(u8, v);
                if (zm.min_string) |old| output.free(old);
                zm.min_string = copy;
                zm.min_prefix_u32 = p;
            }
            if (zm.max_string == null or compareStrings(collation, v, zm.max_string.?) == .gt) {
                const copy = try output.dupe(u8, v);
                if (zm.max_string) |old| output.free(old);
                zm.max_string = copy;
                zm.max_prefix_u32 = p;
            }
        },
        else => {},
    }
}

fn collectDocumentPaths(
    scratch: std.mem.Allocator,
    path_map: anytype,
    prefix: *std.ArrayListUnmanaged([]const u8),
    node: *const vm.Node,
) Error!void {
    switch (node.kind) {
        .object => |fields| {
            for (fields) |*f| {
                try prefix.append(scratch, f.name);
                defer _ = prefix.pop();
                if (f.value.kind == .object) {
                    try collectDocumentPaths(scratch, path_map, prefix, &f.value);
                } else {
                    const dot = try joinPath(scratch, prefix.items);
                    if (path_map.getPtr(dot)) |existing| {
                        existing.count += 1;
                    } else {
                        const segs = try scratch.dupe([]const u8, prefix.items);
                        try path_map.put(scratch, dot, .{
                            .dot = dot,
                            .segments = segs,
                            .count = 1,
                            .declared = false,
                        });
                    }
                }
            }
        },
        else => {},
    }
}

fn joinPath(allocator: std.mem.Allocator, segments: []const []const u8) Error![]u8 {
    if (segments.len == 0) return allocator.dupe(u8, "");
    var total: usize = segments.len - 1;
    for (segments) |s| total += s.len;
    const buf = try allocator.alloc(u8, total);
    var pos: usize = 0;
    for (segments, 0..) |s, i| {
        if (i > 0) {
            buf[pos] = '.';
            pos += 1;
        }
        @memcpy(buf[pos .. pos + s.len], s);
        pos += s.len;
    }
    return buf;
}
