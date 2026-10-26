//! Synchronous range reader for one immutable, retained TSEG object. The host
//! binds the source to its expected length/digest and verifies transport ranges;
//! this reader verifies layout, footer and selected column-page commitments.
//! No authorization, pin acquisition, cache or async task is owned here.
const std = @import("std");
const TSeg = @import("TSeg.zig");
const TableSchema = @import("TableSchema.zig");
const Values = @import("Values.zig");
const PhysicalCodecs = @import("PhysicalCodecs.zig");
const ColumnPredicate = @import("ColumnPredicate.zig");
const PredicateMachine = @import("PredicateMachine.zig");
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

pub const Filter = struct { column: usize, predicate: ColumnPredicate.Predicate };
pub const FilterFailure = struct { row: u32, column: usize, instruction: u8 = 0, outcome: ColumnPredicate.Outcome };

/// A bounded owner-selected page, in logical traversal order. Physical segment
/// ordinals may differ from that order; visibility remains the owner's decision.
pub const Candidates = struct {
    pub const max_rows = 1024;
    rows: []const u32,
    matches: ?usize = null,
    fn validate(self: Candidates, source_rows: u32) !void {
        if (self.rows.len > max_rows) return error.InvalidColumnSelection;
        for (self.rows, 0..) |row, i| {
            if (row >= source_rows) return error.InvalidColumnSelection;
            for (self.rows[0..i]) |previous| if (previous == row) return error.InvalidColumnSelection;
        }
    }
};
pub const CandidateGroup = struct {
    group: Group,
    /// Positions consumed from the supplied candidate page, including misses.
    /// A match limit may leave a suffix unexamined. This is not source coverage.
    examined: usize,
    pub fn deinit(self: *CandidateGroup) void {
        self.group.deinit();
        self.* = undefined;
    }
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

/// Use trusted, interpretation-bound zone maps before fetching the predicate
/// page. Evaluate that page without retaining decoded payloads, then decode
/// only matching rows of projected columns. Error/conflict outcomes remain
/// eager and row-addressed; no result escapes a failed group. Source order is
/// unchanged. The caller still owns snapshot, deletion and authorization gates.
pub fn filteredGroup(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, filter: Filter, limits: Limits, failure: *?FilterFailure) !Group {
    failure.* = null;
    if (filter.column >= schema.columns.len or filter.column >= TableSchema.max_columns) return error.InvalidSegmentCoordinate;
    const instructions = [_]ColumnPredicate.Program.Instruction{.{ .atom = .{ .column = @intCast(filter.column), .predicate = filter.predicate } }};
    return self.filteredProgram(allocator, source, schema, index, projection, .{ .instructions = &instructions }, limits, failure);
}

/// Evaluate a bounded eager Boolean program over encoded column outcomes.
/// Group pruning is conservative under NOT/AND/OR and unknown values. All atoms
/// remain eager; failures arbitrate by source row then original instruction.
pub fn filteredProgram(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, program: ColumnPredicate.Program, limits: Limits, failure: *?FilterFailure) !Group {
    return (try self.filterProgram(allocator, source, schema, index, projection, program, null, limits, failure)).group;
}

/// Evaluate only the owner's visible candidates, in their logical order, and
/// stop operator evaluation after the requested number of matches. Encoded page
/// validation remains complete. Omitted rows cannot introduce semantic failures;
/// invalid page bytes still reject. Returned cells are indexed by sorted physical
/// ordinal; use Group.rowIndex while traversing the original candidate prefix.
pub fn filteredCandidates(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, program: ColumnPredicate.Program, candidates: Candidates, limits: Limits, failure: *?FilterFailure) !CandidateGroup {
    return self.filterProgram(allocator, source, schema, index, projection, program, candidates, limits, failure);
}

fn filterProgram(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, program: ColumnPredicate.Program, candidates: ?Candidates, limits: Limits, failure: *?FilterFailure) !CandidateGroup {
    failure.* = null;
    if (schema.object != self.footer.object_id or schema.revision != self.footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.footer.layout_fingerprint)) return error.TableSchemaChanged;
    if (index >= self.footer.row_groups.len or
        self.footer.row_groups[index].pages.len != schema.columns.len or
        self.footer.row_groups[index].zone_maps.len != schema.columns.len) return error.InvalidSegmentCoordinate;
    if (projection.len > schema.columns.len or limits.decoded_bytes == 0) return error.SegmentReadBudgetExceeded;
    for (projection) |column_index| if (column_index >= schema.columns.len) return error.InvalidSegmentCoordinate;
    try program.validate(schema);
    const metadata = self.footer.row_groups[index];
    if (candidates) |selected| try selected.validate(metadata.row_count);
    const workspace = try Workspace.init(allocator, limits.decoded_bytes);
    errdefer workspace.deinit();
    const a = workspace.arena.allocator();
    const requested = if (candidates) |selected| selected.rows.len else metadata.row_count;
    const selection: ProgramSelection = if (requested == 0 or (candidates != null and candidates.?.matches == 0))
        .{ .rows = &.{}, .examined = 0 }
    else if (try program.mayMatch(schema, metadata.zone_maps))
        self.programRows(allocator, workspace, source, schema, index, program, candidates, limits.page_bytes, failure) catch |err| return workspace.failure(err)
    else
        .{ .rows = &.{}, .examined = requested };
    const rows = selection.rows;
    const columns = a.alloc([]Values.Cell, projection.len) catch |err| return workspace.failure(err);
    for (projection, columns) |column_index, *cells| {
        cells.* = if (rows.len == 0) &.{} else self.selectedColumn(allocator, workspace, source, schema, index, column_index, rows, limits.page_bytes) catch |err| return workspace.failure(err);
    }
    return .{ .group = .{ .workspace = workspace, .index = index, .source_rows = metadata.row_count, .columns = columns, .rows = rows }, .examined = selection.examined };
}

const OutcomeAtom = struct {
    instruction: u8,
    pub fn validateShape(self: OutcomeAtom) !void {
        if (self.instruction >= ColumnPredicate.Program.max_instructions) return error.InvalidPredicateProgram;
    }
    pub fn truth(self: OutcomeAtom, row: OutcomeRow) !@import("Finite.zig").Truth {
        return row.columns[self.instruction].?[row.row].truth();
    }
};
const OutcomeRow = struct { columns: []const ?[]ColumnPredicate.Outcome, row: usize };

const ProgramSelection = struct { rows: []const u32, examined: usize };
fn programRows(self: *const Self, allocator: std.mem.Allocator, workspace: *Workspace, source: Source, schema: TableSchema.Schema, index: usize, program: ColumnPredicate.Program, candidates: ?Candidates, page_budget: usize, failure: *?FilterFailure) !ProgramSelection {
    const row_count = self.footer.row_groups[index].row_count;
    const bounded = workspace.bounded();
    var columns: [ColumnPredicate.Program.max_instructions]?[]ColumnPredicate.Outcome = @splat(null);
    defer for (columns) |column_outcomes| if (column_outcomes) |outcomes| bounded.free(outcomes);
    var instructions: [ColumnPredicate.Program.max_instructions]PredicateMachine.Instruction(OutcomeAtom) = undefined;
    for (program.instructions, 0..) |instruction, i| {
        instructions[i] = switch (instruction) {
            .atom => |atom| blk: {
                if (atom.predicate == .all) {
                    columns[i] = try bounded.alloc(ColumnPredicate.Outcome, row_count);
                    @memset(columns[i].?, .yes);
                } else {
                    columns[i] = try self.columnOutcomes(allocator, workspace, source, schema, index, atom, page_budget);
                }
                break :blk .{ .atom = .{ .instruction = @intCast(i) } };
            },
            .negate => .negate,
            .conjunction => .conjunction,
            .disjunction => .disjunction,
        };
    }
    const code = instructions[0..program.instructions.len];
    var count: usize = 0;
    var examined: usize = 0;
    const requested = if (candidates) |selected| selected.rows.len else row_count;
    for (0..requested) |position| {
        if (candidates) |selected| if (selected.matches) |limit| if (count == limit) break;
        const row = if (candidates) |selected| selected.rows[position] else position;
        var failed_instruction: ?u8 = null;
        const truth = PredicateMachine.truthDiagnostic(code, OutcomeRow{ .columns = &columns, .row = row }, &failed_instruction) catch |err| {
            if (failed_instruction) |at| failure.* = .{ .row = @intCast(row), .column = program.instructions[at].atom.column, .instruction = at, .outcome = columns[at].?[row] };
            return err;
        };
        examined += 1;
        if (truth.selects()) count += 1;
    }
    const rows = try workspace.arena.allocator().alloc(u32, count);
    var selected: usize = 0;
    for (0..examined) |at| {
        const row = if (candidates) |page| page.rows[at] else at;
        if ((try PredicateMachine.truth(code, OutcomeRow{ .columns = &columns, .row = row })).selects()) {
            rows[selected] = @intCast(row);
            selected += 1;
        }
    }
    if (candidates != null) std.mem.sort(u32, rows, {}, std.sort.asc(u32));
    return .{ .rows = rows, .examined = examined };
}

fn columnOutcomes(self: *const Self, allocator: std.mem.Allocator, workspace: *Workspace, source: Source, schema: TableSchema.Schema, index: usize, atom: ColumnPredicate.Atom, page_budget: usize) ![]ColumnPredicate.Outcome {
    const coordinate = self.footer.row_groups[index].pages[atom.column];
    if (coordinate.length > page_budget) return error.SegmentReadBudgetExceeded;
    const bytes = try allocator.alloc(u8, coordinate.length);
    defer allocator.free(bytes);
    try source.read(source.context, coordinate.offset, bytes);
    try TSeg.verifyColumnRange(schema, &self.footer, bytes, index, atom.column);
    const bounded = workspace.bounded();
    const result = try PhysicalCodecs.evaluateColumnPage(bounded, bounded, schema.columns[atom.column], bytes, atom.predicate);
    errdefer bounded.free(result.outcomes);
    if (result.outcomes.len != self.footer.row_groups[index].row_count) return error.InvalidSegment;
    return result.outcomes;
}

fn selectedColumn(self: *const Self, allocator: std.mem.Allocator, workspace: *Workspace, source: Source, schema: TableSchema.Schema, index: usize, column_index: usize, rows: []const u32, page_budget: usize) ![]Values.Cell {
    const coordinate = self.footer.row_groups[index].pages[column_index];
    if (coordinate.length > page_budget) return error.SegmentReadBudgetExceeded;
    const bytes = try allocator.alloc(u8, coordinate.length);
    defer allocator.free(bytes);
    try source.read(source.context, coordinate.offset, bytes);
    try TSeg.verifyColumnRange(schema, &self.footer, bytes, index, column_index);
    const selected = try PhysicalCodecs.decodeColumnPageSelected(workspace.bounded(), workspace.arena.allocator(), schema.columns[column_index], bytes, rows);
    if (selected.row_count != self.footer.row_groups[index].row_count) return error.InvalidSegment;
    return selected.cells;
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
