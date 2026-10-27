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

/// A deferred filter decision. Unknown and false both skip the row; eager
/// semantic failures remain data until the owner visits this physical ordinal.
pub const Decision = struct {
    selected: bool = false,
    failure: ?struct { column: u8, instruction: u8, outcome: ColumnPredicate.Outcome } = null,
};
pub const Decisions = struct {
    workspace: *Workspace,
    index: usize,
    rows: []const Decision,
    pub fn deinit(self: *Decisions) void {
        self.workspace.deinit();
        self.* = undefined;
    }
    pub fn allocatedBytes(self: Decisions) usize {
        return self.workspace.used;
    }
};

/// Evaluate encoded atoms once for bounded reuse across owner-selected rows.
/// This visits no logical source rows: the owner decides visibility, ordering,
/// LIMIT and failure disclosure. Pruning represents only a non-selection, not
/// exact three-valued truth. Structural/page integrity errors still fail now.
pub fn decisions(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, program: ColumnPredicate.Program, limits: Limits) !Decisions {
    if (schema.object != self.footer.object_id or schema.revision != self.footer.schema_revision or
        !std.mem.eql(u8, &try schema.layoutFingerprint(), &self.footer.layout_fingerprint)) return error.TableSchemaChanged;
    if (index >= self.footer.row_groups.len or self.footer.row_groups[index].pages.len != schema.columns.len) return error.InvalidSegmentCoordinate;
    try program.validate(schema);
    const workspace = try Workspace.init(allocator, limits.decoded_bytes);
    errdefer workspace.deinit();
    const metadata = self.footer.row_groups[index];
    const rows = workspace.arena.allocator().alloc(Decision, metadata.row_count) catch |err| return workspace.failure(err);
    @memset(rows, .{});
    if (try program.mayMatch(schema, metadata.zone_maps)) {
        var columns = ProgramColumns.init(self, allocator, workspace, source, schema, index, program, limits.page_bytes) catch |err| return workspace.failure(err);
        defer columns.deinit();
        for (rows, 0..) |*row, ordinal| row.* = try columns.decision(program, ordinal);
    }
    return .{ .workspace = workspace, .index = index, .rows = rows };
}

pub const Column = union(enum) {
    cells: []Values.Cell,
    plain: PhysicalCodecs.PlainColumn,
    pub fn len(self: Column) usize {
        return switch (self) {
            .cells => |cells| cells.len,
            .plain => |plain| plain.buffers.tags.len,
        };
    }
    pub fn cell(self: Column, row: usize) Values.Cell {
        return switch (self) {
            .cells => |cells| cells[row],
            .plain => |plain| plain.cell(row),
        };
    }
};
pub const Group = struct {
    workspace: *Workspace,
    index: usize,
    source_rows: u32,
    columns: []Column,
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

/// One independently owned group with plain byte payloads borrowed from its
/// verified page buffers. Release decoded metadata before those buffers. The
/// source and reader can close immediately; views cannot outlive this owner.
pub const BufferedGroup = struct {
    encoded: EncodedGroup,
    decoded: Group,
    pub fn deinit(self: *BufferedGroup) void {
        self.decoded.deinit();
        self.encoded.deinit();
        self.* = undefined;
    }
};

/// Shared ownership of a verified group and its five-state metadata. Arrow
/// value children retain this owner through slices and C release callbacks.
/// Reference counting does not grant access or retain a durable source lease.
pub const SharedGroup = struct {
    allocator: std.mem.Allocator,
    references: std.atomic.Value(usize),
    group: BufferedGroup,

    /// Transfer the group on success. On failure the caller still owns it.
    pub fn init(allocator: std.mem.Allocator, owned: BufferedGroup) !*SharedGroup {
        const self = try allocator.create(SharedGroup);
        self.* = .{ .allocator = allocator, .references = .init(1), .group = owned };
        return self;
    }
    pub fn retain(self: *SharedGroup) *SharedGroup {
        const previous = self.references.fetchAdd(1, .monotonic);
        std.debug.assert(previous != 0 and previous != std.math.maxInt(usize));
        return self;
    }
    pub fn release(self: *SharedGroup) void {
        if (self.references.fetchSub(1, .acq_rel) != 1) return;
        const allocator = self.allocator;
        self.group.deinit();
        allocator.destroy(self);
    }
    /// Own the small Arrow buffer directory; borrow aligned payloads by pinning
    /// this group. `index` addresses the selected projection. Non-value states
    /// remain NULL in this value child; use `group.decoded` for their full cells.
    /// An ArrayRef or C export can outlive the caller's SharedGroup reference.
    pub fn arrowValues(self: *SharedGroup, index: usize) !@import("zarrow").ArrayRef {
        const arrow = @import("zarrow");
        if (index >= self.group.decoded.columns.len) return error.InvalidSegmentCoordinate;
        const selected = self.group.decoded.columns[index];
        if (selected != .plain) return error.UnsupportedPlainColumn;
        var directory: [3]arrow.SharedBuffer = undefined;
        var layout = try selected.plain.buffers.arrowValues(&directory);
        layout.buffers = try self.allocator.dupe(arrow.SharedBuffer, layout.buffers);
        errdefer self.allocator.free(layout.buffers);
        return arrow.ArrayRef.fromOwnedWithOwner(self.allocator, layout, self, retainOwner, releaseOwner);
    }
    fn retainOwner(context: ?*anyopaque) void {
        const self: *SharedGroup = @ptrCast(@alignCast(context.?));
        _ = self.retain();
    }
    fn releaseOwner(context: ?*anyopaque) void {
        const self: *SharedGroup = @ptrCast(@alignCast(context.?));
        self.release();
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
    const Page = struct { column: usize, bytes: []align(64) u8 };

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
        const columns = a.alloc(Column, self.pages.len) catch |err| return workspace.failure(err);
        for (self.pages, columns) |page, *cells| {
            const selected = PhysicalCodecs.decodeColumnPageSelected(workspace.bounded(), a, schema.columns[page.column], page.bytes, rows) catch |err| return workspace.failure(err);
            if (selected.row_count != self.row_count) return error.InvalidSegment;
            cells.* = .{ .cells = selected.cells };
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
    const cells = workspace.arena.allocator().alloc(Column, projection.len) catch |err| return workspace.failure(err);
    for (projection, cells) |column_index, *out| {
        out.* = .{ .cells = self.column(allocator, workspace.arena.allocator(), source, schema, index, column_index, limits.page_bytes) catch |err| return workspace.failure(err) };
    }
    return .{ .workspace = workspace, .index = index, .source_rows = self.footer.row_groups[index].row_count, .columns = cells };
}

/// Retain projected verified pages under a total encoded-byte allowance and
/// borrow compatible plain payloads while decoding bounded cell metadata.
/// Compressed columns use the same bounded owned expansion as `group`.
pub fn bufferedGroup(self: *const Self, allocator: std.mem.Allocator, source: Source, schema: TableSchema.Schema, index: usize, projection: []const usize, encoded_budget: usize, decoded_budget: usize) !BufferedGroup {
    if (decoded_budget == 0) return error.SegmentReadBudgetExceeded;
    var encoded = try self.encodedGroup(allocator, source, schema, index, projection, encoded_budget);
    errdefer encoded.deinit();
    const workspace = try Workspace.init(allocator, decoded_budget);
    errdefer workspace.deinit();
    const a = workspace.arena.allocator();
    const columns = a.alloc(Column, projection.len) catch |err| return workspace.failure(err);
    for (encoded.pages, columns) |page, *cells| {
        const descriptor = schema.columns[page.column];
        if (descriptor.encoding == .plain and PhysicalCodecs.PlainBuffers.supports(descriptor.type)) {
            const plain = PhysicalCodecs.borrowPlainColumn(workspace.bounded(), a, descriptor, page.bytes) catch |err| return workspace.failure(err);
            if (plain.buffers.tags.len != encoded.row_count) return error.InvalidSegment;
            cells.* = .{ .plain = plain };
        } else {
            const decoded = PhysicalCodecs.decodeColumnPageBorrowingBytes(workspace.bounded(), a, descriptor, page.bytes, null) catch |err| return workspace.failure(err);
            if (decoded.row_count != encoded.row_count) return error.InvalidSegment;
            cells.* = .{ .cells = decoded.cells };
        }
    }
    return .{ .encoded = encoded, .decoded = .{ .workspace = workspace, .index = index, .source_rows = encoded.row_count, .columns = columns } };
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
    const columns = a.alloc(Column, projection.len) catch |err| return workspace.failure(err);
    for (projection, columns) |column_index, *cells| {
        cells.* = .{ .cells = if (rows.len == 0) &.{} else self.selectedColumn(allocator, workspace, source, schema, index, column_index, rows, limits.page_bytes) catch |err| return workspace.failure(err) };
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

const ProgramColumns = struct {
    allocator: std.mem.Allocator,
    columns: [ColumnPredicate.Program.max_instructions]?[]ColumnPredicate.Outcome = @splat(null),
    instructions: [ColumnPredicate.Program.max_instructions]PredicateMachine.Instruction(OutcomeAtom) = undefined,
    fn init(reader: *const Self, allocator: std.mem.Allocator, workspace: *Workspace, source: Source, schema: TableSchema.Schema, index: usize, program: ColumnPredicate.Program, page_budget: usize) !ProgramColumns {
        var result: ProgramColumns = .{ .allocator = workspace.bounded() };
        errdefer result.deinit();
        for (program.instructions, 0..) |instruction, i| {
            result.instructions[i] = switch (instruction) {
                .atom => |atom| blk: {
                    if (atom.predicate == .all) {
                        result.columns[i] = try result.allocator.alloc(ColumnPredicate.Outcome, reader.footer.row_groups[index].row_count);
                        @memset(result.columns[i].?, .yes);
                    } else {
                        result.columns[i] = try reader.columnOutcomes(allocator, workspace, source, schema, index, atom, page_budget);
                    }
                    break :blk .{ .atom = .{ .instruction = @intCast(i) } };
                },
                .negate => .negate,
                .conjunction => .conjunction,
                .disjunction => .disjunction,
            };
        }
        return result;
    }
    fn deinit(self: *ProgramColumns) void {
        for (self.columns) |slot| if (slot) |outcomes| self.allocator.free(outcomes);
    }
    fn decision(self: *const ProgramColumns, program: ColumnPredicate.Program, row: usize) !Decision {
        var instruction: ?u8 = null;
        const truth = PredicateMachine.truthDiagnostic(self.instructions[0..program.instructions.len], OutcomeRow{ .columns = &self.columns, .row = row }, &instruction) catch |err| switch (err) {
            error.QueryTypeError, error.QueryConflict => {
                const at = instruction orelse return err;
                return .{ .failure = .{ .column = program.instructions[at].atom.column, .instruction = at, .outcome = self.columns[at].?[row] } };
            },
            else => return err,
        };
        return .{ .selected = truth.selects() };
    }
};

const ProgramSelection = struct { rows: []const u32, examined: usize };
fn programRows(self: *const Self, allocator: std.mem.Allocator, workspace: *Workspace, source: Source, schema: TableSchema.Schema, index: usize, program: ColumnPredicate.Program, candidates: ?Candidates, page_budget: usize, failure: *?FilterFailure) !ProgramSelection {
    const row_count = self.footer.row_groups[index].row_count;
    var columns = try ProgramColumns.init(self, allocator, workspace, source, schema, index, program, page_budget);
    defer columns.deinit();
    var count: usize = 0;
    var examined: usize = 0;
    const requested = if (candidates) |selected| selected.rows.len else row_count;
    for (0..requested) |position| {
        if (candidates) |selected| if (selected.matches) |limit| if (count == limit) break;
        const row = if (candidates) |selected| selected.rows[position] else position;
        const decision = try columns.decision(program, row);
        if (decision.failure) |failed| {
            failure.* = .{ .row = @intCast(row), .column = failed.column, .instruction = failed.instruction, .outcome = failed.outcome };
            _ = try failed.outcome.truth();
            unreachable;
        }
        examined += 1;
        if (decision.selected) count += 1;
    }
    const rows = try workspace.arena.allocator().alloc(u32, count);
    var selected: usize = 0;
    for (0..examined) |at| {
        const row = if (candidates) |page| page.rows[at] else at;
        if ((try columns.decision(program, row)).selected) {
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
        page.* = .{ .column = column_index, .bytes = try allocator.alignedAlloc(u8, .fromByteUnits(64), coordinate.length) };
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
