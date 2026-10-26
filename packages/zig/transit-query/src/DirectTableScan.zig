//! Fuze source over an existing direct Table pin. The caller retains ownership
//! of that durable pin; closing this local scan does not release it.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const Self = @This();
const Key = q.storage.TablePartition.KeyRange.Key;
const CountRange = @import("DirectTableCountRange.zig");
allocator: std.mem.Allocator,
client: c.DirectTableClient,
reader: c.DirectTableReader,
request_limit: u64,
requests: u64 = 2,
cancellation: ?*const std.atomic.Value(bool),
page: ?c.DirectTableReader.Batch = null,
index: usize = 0,
after: ?f.TableRow.Identity = null,
complete: bool = false,
closed: bool = false,
rejection: ?q.protocol.ErrorCode = null,
point_key: ?Key = null,
count_range: ?CountRange = null,
range_after: ?q.storage.TablePartition.KeyRange.Cursor = null,
range_complete: bool = false,
ordinal: u64 = 0,
selected: u64 = 0,

pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: c.DirectTableProtocol.Snapshot, request_limit: u64, cancellation: ?*const std.atomic.Value(bool)) !Self {
    if (request_limit < 2) return error.InvalidQueryBudget;
    if (cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    return .{ .allocator = allocator, .client = client, .reader = try c.DirectTableReader.open(allocator, client, snapshot), .request_limit = request_limit, .cancellation = cancellation };
}
pub fn deinit(self: *Self) void {
    if (self.page) |*page| page.deinit();
    self.reader.deinit();
    self.* = undefined;
}
pub fn checkCancellation(self: *const Self) !void {
    if (self.closed) return error.QueryClosed;
    if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
}
fn charge(self: *Self) !void {
    try self.checkCancellation();
    self.rejection = null;
    // A direct call acquires current native credentials, then invokes its Table
    // action. Charge both exchanges before starting either; no implicit retries.
    if (self.requests > self.request_limit or self.request_limit - self.requests < 2) return error.QueryPageBudget;
    self.requests += 2;
}
fn rejected(self: *Self, err: anyerror) anyerror {
    self.rejection = self.client.authority.last_rejection orelse self.client.service.last_rejection;
    return err;
}
pub fn validateCurrent(self: *Self) !void {
    try self.charge();
    self.reader.check(self.client) catch |err| return self.rejected(err);
    try self.checkCancellation();
}
pub fn fingerprint(self: *const Self) ![32]u8 {
    return self.reader.basis.fingerprint();
}
/// Finite SELECT may select one complete primary key. Extra conditions keep
/// the original scan and evaluation order; the engine still tests the predicate.
/// Own the encoded key so moving the scan or releasing literals cannot alter it.
pub fn selectPoint(self: *Self, plan: f.LogicalQuery.Plan) void {
    var single: [1]f.LogicalPredicate.Program.Instruction = undefined;
    const program: f.LogicalPredicate.Program = switch (plan.predicate) {
        .program => |value| value,
        .compare => |value| blk: {
            single[0] = .{ .atom = .{ .compare = value } };
            break :blk .{ .instructions = &single };
        },
        else => return,
    };
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const schema = self.reader.schema.schema;
    // A valid comparison literal need not fit the stored physical key profile
    // or its byte limit. Failed qualification leaves the valid scan unchanged.
    const values = ((f.TableDml.Plan{ .name = "retained", .schema = schema, .action = .delete, .predicate = program }).primaryKeyEquality(&cells) catch return) orelse return;
    var encoded: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const key = f.Collation.encodePrimaryKeySortKey(schema, values, false, &encoded) catch return;
    self.point_key = Key.init(key) catch unreachable; // bounded by encoded above
}
pub fn selectAccess(self: *Self, plan: f.LogicalQuery.Plan) !void {
    self.selectPoint(plan);
    if (self.point_key == null) self.count_range = CountRange.qualify(self.reader.schema.schema, plan);
    if (self.point_key != null or self.count_range != null) return;
    if (plan.predicate != .all) return self.reader.selectPlan(plan);
    const selected = try f.TableProjection.fromPlan(self.reader.schema.schema, plan);
    if (selected.len < self.reader.schema.schema.columns.len) try self.reader.selectColumns(selected.columns());
}
pub fn next(self: *Self) !?f.LogicalQuery.Row {
    try self.checkCancellation();
    if (self.complete) return null;
    if (self.point_key) |*key| {
        try self.charge();
        const row = self.reader.readKey(self.client, key.slice()) catch |err| return self.rejected(err);
        // This completes the qualified selection, not the reader's full-Table
        // coverage. A missing key has the same post-compute authorization gate.
        self.complete = true;
        const found = row orelse return null;
        self.after = found.identity;
        self.ordinal += 1;
        return .{ .arena = found.value.descriptor.arena, .cells = found.row().cells };
    }
    while (self.page == null or self.index == self.page.?.count) {
        if (self.page) |*page| page.deinit();
        self.page = null;
        self.index = 0;
        if (self.reader.failure) |failure| {
            try self.validateCurrent();
            return if (failure.state == .type_error) error.QueryTypeError else error.QueryConflict;
        }
        if (self.reader.complete or self.range_complete) {
            self.complete = true;
            return null;
        }
        try self.charge();
        if (self.count_range) |*range| {
            const page = self.reader.readRange(self.client, range.interval(), self.range_after, .{}) catch |err| return self.rejected(err);
            self.page = page.batch;
            self.range_after = page.next;
            self.range_complete = page.batch.complete;
        } else {
            var limits: q.storage.TablePartition.ReadLimits = .{};
            if (self.reader.filter) |filter| if (filter.plan.plan.limit) |limit| {
                if (self.selected >= limit) return error.IncompleteSource;
                limits.rows = @intCast(@min(limits.rows, limit - self.selected));
            };
            self.page = (self.reader.next(self.client, limits) catch |err| return self.rejected(err)) orelse return error.IncompleteSource;
        }
        if (self.page.?.count == 0) {
            if (self.reader.filter != null) continue;
            if (!self.reader.complete and !self.range_complete) return error.IncompleteSource;
            self.complete = true;
            return null;
        }
    }
    const row = self.page.?.rows[self.index].?;
    self.page.?.rows[self.index] = null;
    self.ordinal = if (self.reader.filter != null) self.page.?.ordinals[self.index] else self.ordinal + 1;
    self.selected += 1;
    self.index += 1;
    self.after = row.identity;
    // TableRow owns its value and descriptor in one arena. Transfer that arena
    // to Fuze; the source page can be freed independently of the returned row.
    return .{ .arena = row.value.descriptor.arena, .cells = row.row().cells };
}
pub fn batchOrdinal(self: *const Self) u64 {
    return self.ordinal;
}
pub fn batchCoverage(self: *const Self) u64 {
    return if (self.reader.filter != null) self.reader.consumed else self.ordinal;
}
pub fn batchFailure(self: *const Self) ?f.LogicalQuery.Failure {
    return self.reader.failure;
}
pub fn batchIdentity(self: *const Self) ?f.TableRow.Identity {
    return self.after;
}
/// Rewinds traverse the same retained identity index. The common sequential
/// call uses the already buffered page; no new snapshot or name lookup occurs.
pub fn nextAfter(self: *Self, after: ?f.TableRow.Identity) !?f.LogicalQuery.Row {
    // Relational rewinds require identity order; only the finite count owner
    // selects a range and it consumes next() without identity-based rewinds.
    std.debug.assert(self.count_range == null and self.reader.filter == null);
    try self.checkCancellation();
    if (std.meta.eql(after, self.after)) return self.next();
    if (self.page) |*page| page.deinit();
    self.page = null;
    self.index = 0;
    self.after = null;
    self.complete = false;
    self.reader.after = null;
    self.reader.consumed = 0;
    self.ordinal = 0;
    self.selected = 0;
    self.reader.complete = false;
    while (try self.next()) |value| {
        var row = value;
        if (after == null or f.RelationalExecution.identityOrder(self.after.?, after.?) == .gt) return row;
        row.deinit();
    }
    return null;
}
pub fn close(self: *Self) void {
    self.closed = true;
}
