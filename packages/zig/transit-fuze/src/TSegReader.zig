//! Synchronous range reader for one immutable, retained TSEG object. The host
//! binds the source to its expected length/digest and verifies transport ranges;
//! this reader verifies layout, footer and selected column-page commitments.
//! No authorization, pin acquisition, cache or async task is owned here.
const std = @import("std");
const TSeg = @import("TSeg.zig");
const TableSchema = @import("TableSchema.zig");
const Values = @import("Values.zig");
const PhysicalCodecs = @import("PhysicalCodecs.zig");
const Self = @This();

pub const Source = struct {
    context: *anyopaque,
    /// Fill the complete output or return an error. No output or callback
    /// context may be retained after return. All calls address the same object.
    read: *const fn (*anyopaque, u64, []u8) anyerror!void,
};

pub const Limits = struct {
    page_bytes: usize = TSeg.max_segment_bytes,
    decoded_bytes: usize = 64 * 1024 * 1024,
};

pub const Group = struct {
    workspace: *Workspace,
    index: usize,
    source_rows: u32,
    columns: [][]Values.Cell,
    /// Null denotes all rows; otherwise ordinals are owned, sorted and unique.
    rows: ?[]const u32 = null,
    pub fn deinit(self: *Group) void {
        self.workspace.deinit();
        self.* = undefined;
    }
    /// Actual live arena backing allocations, excluding the small owner and
    /// the separately bounded transient encoded-page buffer.
    pub fn allocatedBytes(self: Group) usize {
        return self.workspace.used;
    }
    /// Includes simultaneously live dictionary and validation workspaces.
    pub fn peakAllocatedBytes(self: Group) usize {
        return self.workspace.peak;
    }
    pub fn rowIndex(self: Group, row: u32) ?usize {
        if (row >= self.source_rows) return null;
        const rows = self.rows orelse return row;
        for (rows, 0..) |ordinal, i| {
            if (ordinal == row) return i;
            if (ordinal > row) break;
        }
        return null;
    }
};

/// Owned encoded pages for one projected group. Repeated point selections can
/// reuse verified bytes without retaining unrelated expanded values. This is
/// an explicit owner, independent of the source and reader lifetimes.
pub const EncodedGroup = struct {
    allocator: std.mem.Allocator,
    index: usize,
    object: u64,
    revision: u64,
    layout: [32]u8,
    row_count: u32,
    pages: []Page,
    bytes: usize,
    const Page = struct { column: usize, bytes: []u8 };

    pub fn deinit(self: *EncodedGroup) void {
        for (self.pages) |page| self.allocator.free(page.bytes);
        self.allocator.free(self.pages);
        self.* = undefined;
    }
    /// Requested backing bytes, including the page directory. Allocator
    /// implementation overhead and this small owner are not included.
    pub fn allocatedBytes(self: EncodedGroup) usize {
        return self.bytes;
    }
    pub fn select(self: *const EncodedGroup, allocator: std.mem.Allocator, schema: TableSchema.Schema, rows: []const u32, decoded_budget: usize) !Group {
        if (schema.object != self.object or schema.revision != self.revision or
            !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.layout)) return error.TableSchemaChanged;
        for (rows, 0..) |row, i| {
            if (row >= self.row_count or (i > 0 and rows[i - 1] >= row)) return error.InvalidColumnSelection;
        }
        if (decoded_budget == 0) return error.SegmentReadBudgetExceeded;
        const workspace = try Workspace.init(allocator, decoded_budget);
        errdefer workspace.deinit();
        const a = workspace.arena.allocator();
        const owned_rows = a.dupe(u32, rows) catch |err| return workspace.failure(err);
        const columns = a.alloc([]Values.Cell, self.pages.len) catch |err| return workspace.failure(err);
        for (self.pages, columns) |page, *cells| {
            const selected = PhysicalCodecs.decodeColumnPageSelected(workspace.bounded(), a, schema.columns[page.column], page.bytes, rows) catch |err| return workspace.failure(err);
            if (selected.row_count != self.row_count) return error.InvalidSegment;
            cells.* = selected.cells;
        }
        return .{ .workspace = workspace, .index = self.index, .source_rows = self.row_count, .columns = columns, .rows = owned_rows };
    }
};

footer: TSeg.Footer,
footer_bytes: u32,

pub fn open(allocator: std.mem.Allocator, source: Source, length: u64, footer_budget: usize) !Self {
    if (length < 64 + 136 + 16 or length > TSeg.max_segment_bytes) return error.InvalidSegment;
    var header: [64]u8 = undefined;
    var trailer: [16]u8 = undefined;
    try source.read(source.context, 0, &header);
    try source.read(source.context, length - trailer.len, &trailer);
    const location = try TSeg.footerLocation(&header, &trailer, length);
    if (location.length > footer_budget) return error.SegmentReadBudgetExceeded;
    const bytes = try allocator.alloc(u8, location.length);
    defer allocator.free(bytes);
    try source.read(source.context, location.offset, bytes);
    return .{
        .footer = try TSeg.readFooterParts(allocator, &header, bytes, &trailer, length),
        .footer_bytes = location.length,
    };
}

pub fn deinit(self: *Self) void {
    self.footer.deinit();
    self.* = undefined;
}

/// Only this column's encoded range is read. Scratch owns the transient encoded
/// page; values owns every returned cell and nested value. Use an arena for
/// values and discard it on error. Closing the reader or releasing scratch does
/// not invalidate returned cells. Budgets do not imply zero-copy Arrow layout.
pub fn column(self: *const Self, scratch: std.mem.Allocator, values: std.mem.Allocator, source: Source, schema: TableSchema.Schema, group_index: usize, index: usize, page_budget: usize) ![]Values.Cell {
    if (schema.object != self.footer.object_id or schema.revision != self.footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.footer.layout_fingerprint)) return error.TableSchemaChanged;
    if (group_index >= self.footer.row_groups.len or index >= schema.columns.len or
        self.footer.row_groups[group_index].pages.len != schema.columns.len) return error.InvalidSegmentCoordinate;
    const page = self.footer.row_groups[group_index].pages[index];
    if (page.length > page_budget) return error.SegmentReadBudgetExceeded;
    const bytes = try scratch.alloc(u8, page.length);
    defer scratch.free(bytes);
    try source.read(source.context, page.offset, bytes);
    return TSeg.decodeColumnRange(values, schema, &self.footer, bytes, group_index, index);
}

/// Decode a caller-selected projection under one resident allocation budget.
/// Projection order is output order; no omitted column payload is requested.
/// The returned owner remains valid across source/reader destruction.
pub fn group(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, limits: Limits) !Group {
    if (schema.object != self.footer.object_id or schema.revision != self.footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.footer.layout_fingerprint)) return error.TableSchemaChanged;
    if (index >= self.footer.row_groups.len or self.footer.row_groups[index].pages.len != schema.columns.len) return error.InvalidSegmentCoordinate;
    if (projection.len > schema.columns.len or limits.decoded_bytes == 0) return error.SegmentReadBudgetExceeded;
    const workspace = try Workspace.init(allocator, limits.decoded_bytes);
    errdefer workspace.deinit();
    const cells = workspace.arena.allocator().alloc([]Values.Cell, projection.len) catch |err| return workspace.failure(err);
    for (projection, cells) |column_index, *out| {
        out.* = self.column(allocator, workspace.arena.allocator(), source, schema, index, column_index, limits.page_bytes) catch |err| return workspace.failure(err);
    }
    return .{ .workspace = workspace, .index = index, .source_rows = self.footer.row_groups[index].row_count, .columns = cells };
}

/// Read and verify projected encoded pages under a total retained-byte budget.
/// No page payload is fetched until every coordinate and the sum fit. The
/// footer remains owned by the reader; the returned group copies its binding.
pub fn encodedGroup(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, encoded_budget: usize) !EncodedGroup {
    if (schema.object != self.footer.object_id or schema.revision != self.footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.footer.layout_fingerprint)) return error.TableSchemaChanged;
    if (index >= self.footer.row_groups.len or self.footer.row_groups[index].pages.len != schema.columns.len) return error.InvalidSegmentCoordinate;
    if (projection.len > schema.columns.len) return error.SegmentReadBudgetExceeded;
    const metadata = self.footer.row_groups[index];
    var bytes = projection.len * @sizeOf(EncodedGroup.Page);
    for (projection) |column_index| {
        if (column_index >= schema.columns.len) return error.InvalidSegmentCoordinate;
        bytes = std.math.add(usize, bytes, metadata.pages[column_index].length) catch return error.SegmentReadBudgetExceeded;
    }
    if (bytes > encoded_budget) return error.SegmentReadBudgetExceeded;
    const pages = try allocator.alloc(EncodedGroup.Page, projection.len);
    errdefer allocator.free(pages);
    var loaded: usize = 0;
    errdefer for (pages[0..loaded]) |page| allocator.free(page.bytes);
    for (projection, pages) |column_index, *page| {
        const coordinate = metadata.pages[column_index];
        page.* = .{ .column = column_index, .bytes = try allocator.alloc(u8, coordinate.length) };
        loaded += 1;
        try source.read(source.context, coordinate.offset, page.bytes);
        try TSeg.verifyColumnRange(schema, &self.footer, page.bytes, index, column_index);
    }
    return .{
        .allocator = allocator,
        .index = index,
        .object = schema.object,
        .revision = schema.revision,
        .layout = self.footer.layout_fingerprint,
        .row_count = metadata.row_count,
        .pages = pages,
        .bytes = bytes,
    };
}

// Stable address: the ArenaAllocator's child allocator points to this owner.
// Account the arena's real blocks (including growth slack), not just cell sizes.
const Workspace = struct {
    backing: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    limit: usize,
    used: usize = 0,
    peak: usize = 0,
    exhausted: bool = false,
    fn init(backing: std.mem.Allocator, limit: usize) !*Workspace {
        const self = try backing.create(Workspace);
        self.* = .{ .backing = backing, .arena = undefined, .limit = limit };
        self.arena = std.heap.ArenaAllocator.init(self.bounded());
        return self;
    }
    fn bounded(self: *Workspace) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn deinit(self: *Workspace) void {
        self.arena.deinit();
        std.debug.assert(self.used == 0);
        self.backing.destroy(self);
    }
    fn failure(self: *Workspace, err: anyerror) anyerror {
        return if (self.exhausted) error.SegmentReadBudgetExceeded else err;
    }
    fn allow(self: *Workspace, old: usize, new: usize) bool {
        self.exhausted = false;
        if (new > self.limit - (self.used - old)) {
            self.exhausted = true;
            return false;
        }
        return true;
    }
    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Workspace = @ptrCast(@alignCast(context));
        if (!self.allow(0, len)) return null;
        const result = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.used += len;
        self.peak = @max(self.peak, self.used);
        return result;
    }
    fn resize(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Workspace = @ptrCast(@alignCast(context));
        if (!self.allow(bytes.len, len) or !self.backing.rawResize(bytes, alignment, len, ret)) return false;
        self.used = self.used - bytes.len + len;
        self.peak = @max(self.peak, self.used);
        return true;
    }
    fn remap(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Workspace = @ptrCast(@alignCast(context));
        if (!self.allow(bytes.len, len)) return null;
        const result = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
        self.used = self.used - bytes.len + len;
        self.peak = @max(self.peak, self.used);
        return result;
    }
    fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Workspace = @ptrCast(@alignCast(context));
        self.backing.rawFree(bytes, alignment, ret);
        self.used -= bytes.len;
    }
};
