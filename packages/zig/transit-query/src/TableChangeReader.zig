//! Snapshot/change handoff over an explicitly retained direct Table history.
//! A checkpoint names a complete acceptance, never a delivered row prefix.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const p = q.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const P = c.storage.TablePartition;
const Reader = c.DirectTableReader;
const Self = @This();

pub const Options = struct {
    requests: u64,
    cancellation: ?*const std.atomic.Value(bool) = null,
    row_bytes: u32 = f.TableRow.max_bytes,
    fn validate(self: Options) !void {
        if (self.requests < 2) return error.InvalidQueryBudget;
        try (P.ReadLimits{ .rows = 1, .encoded_bytes = self.row_bytes }).validate();
        if (self.row_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
        if (self.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
    }
};
pub const Position = struct {
    version: u8,
    definition: p.Growth.Definition,
    connection: w.Connection,
    source: w.Historical,
    pub fn validate(self: Position) !void {
        if (self.version != 1 or self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.object(self.source.object);
        try self.connection.owner(self.source.point.lease.owner);
        _ = try self.source.point.cursorSource();
    }
    pub fn snapshot(self: Position) w.Snapshot {
        return .{ .object = self.source.object, .handle = self.source.point.lease };
    }
};
pub const Change = struct {
    identity: f.TableRow.Identity,
    before: ?f.TableRow.Owned = null,
    after: ?f.TableRow.Owned = null,
    pub fn deinit(self: *Change) void {
        if (self.before) |*row| row.deinit();
        if (self.after) |*row| row.deinit();
        self.* = undefined;
    }
};
pub const Event = union(enum) {
    /// One bounded physical scan or unchanged row comparison.
    progress,
    /// The caller owns at most two rows, each under its original schema.
    change: Change,
    /// Save next only together with applying this complete transaction.
    transaction: struct { previous: Position, next: Position, before: Reader.Basis, after: Reader.Basis, receipt: P.HistoryReceipt, changes: u64 },
    /// Complete coverage through the explicitly supplied exclusive upper bound.
    caught_up,
};

allocator: std.mem.Allocator,
client: c.DirectTableClient,
reader: Reader,
position: Position,
through: d.Position,
scan: d.Position,
options: Options,
requests: u64 = 2,
snapshot_after: ?f.TableRow.Identity = null,
snapshot_rows: u64 = 0,
snapshot_complete: bool,
following: ?Reader = null,
receipt: ?P.HistoryReceipt = null,
after: ?f.TableRow.Identity = null,
before_after: ?f.TableRow.Identity = null,
after_after: ?f.TableRow.Identity = null,
changes: u64 = 0,
before_rows: u64 = 0,
after_rows: u64 = 0,
closed: bool = false,

/// Acquisition belongs to the caller. Save its exact intent and retain the same
/// durable history lease across backfill, disconnection and successive tails.
pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot, through: d.Position, options: Options) !Self {
    try options.validate();
    var reader = try Reader.openHistoryStart(allocator, client, snapshot);
    errdefer reader.deinit();
    return init(allocator, client, reader, through, options, false);
}
/// Reopening repeats a partially delivered transaction from its beginning.
/// It neither acquires a replacement lease nor resolves the Table by name.
pub fn openTail(allocator: std.mem.Allocator, client: c.DirectTableClient, position: Position, through: d.Position, options: Options) !Self {
    try options.validate();
    try position.validate();
    if (!std.meta.eql(position.connection, client.connection)) return error.RelationalCallerChanged;
    var reader = try Reader.openHistory(allocator, client, position.source);
    errdefer reader.deinit();
    return init(allocator, client, reader, through, options, true);
}
fn init(allocator: std.mem.Allocator, client: c.DirectTableClient, reader: Reader, through: d.Position, options: Options, snapshot_complete: bool) !Self {
    try through.validate();
    const point = reader.history_point.?;
    if (through.partition != point.position.partition or through.next_lsn < point.position.next_lsn) return error.InvalidTableBasis;
    return .{ .allocator = allocator, .client = client, .reader = reader, .position = .{ .version = 1, .definition = p.Growth.current_definition, .connection = client.connection, .source = .{ .object = reader.basis.snapshot.object, .point = point } }, .through = through, .scan = point.position, .options = options, .snapshot_complete = snapshot_complete };
}
pub fn deinit(self: *Self) void {
    if (self.following) |*reader| reader.deinit();
    self.reader.deinit();
    self.* = undefined;
}
/// Local closure only. Explicitly release the saved durable lease after the
/// consumer retires its history requirement; retain uncertain closure for retry.
pub fn close(self: *Self) void {
    self.closed = true;
}
fn checkCancellation(self: *const Self) !void {
    if (self.closed) return error.QueryClosed;
    if (self.options.cancellation) |flag| if (flag.load(.acquire)) return error.Cancelled;
}
fn charge(self: *Self) !void {
    try self.checkCancellation();
    // Each direct call fetches a current native credential before its action.
    if (self.requests > self.options.requests or self.options.requests - self.requests < 2) return error.QueryPageBudget;
    self.requests += 2;
}
fn check(self: *Self) !void {
    try self.charge();
    try self.reader.check(self.client);
    try self.checkCancellation();
}
fn rowAfter(self: *Self, reader: *const Reader, after: ?f.TableRow.Identity) !?f.TableRow.Owned {
    try self.charge();
    var batch = try reader.readAfter(self.client, after, .{ .rows = 1, .encoded_bytes = self.options.row_bytes });
    defer batch.deinit();
    if (batch.count == 0) return null;
    const row = batch.rows[0].?;
    batch.rows[0] = null;
    return row;
}
/// A failed read or final authorization check leaves the row cursor unchanged.
pub fn snapshotNext(self: *Self) !?f.TableRow.Owned {
    try self.checkCancellation();
    if (self.snapshot_complete) {
        try self.check();
        return null;
    }
    var row = try self.rowAfter(&self.reader, self.snapshot_after);
    errdefer if (row) |*value| value.deinit();
    if (row == null and self.snapshot_rows != self.reader.basis.row_count) return error.IncompleteSource;
    if (row != null and self.snapshot_rows >= self.reader.basis.row_count) return error.InvalidTableResponse;
    try self.check();
    if (row) |value| {
        self.snapshot_after = value.identity;
        self.snapshot_rows += 1;
    } else self.snapshot_complete = true;
    return row;
}
pub fn checkpoint(self: *Self) !Position {
    try self.checkCancellation();
    if (!self.snapshot_complete or self.following != null) return error.IncompleteTableChanges;
    try self.check();
    return self.position;
}
pub fn next(self: *Self) !Event {
    try self.checkCancellation();
    if (!self.snapshot_complete) return error.IncompleteTableChanges;
    if (self.following == null) {
        try self.check();
        if (self.scan.next_lsn == self.through.next_lsn) return .caught_up;
        try self.charge();
        const response = try self.client.call(.{ .history = .{ .snapshot = self.position.snapshot(), .from = self.scan, .through = self.through, .frames = 1 } });
        defer response.deinit();
        const page = response.value.result.history;
        if (page.entries.len == 0) {
            try self.check();
            self.scan = page.next;
            return .progress;
        }
        const entry = page.entries[0];
        try self.charge();
        var reader = try Reader.openHistory(self.allocator, self.client, .{ .object = self.position.source.object, .point = entry.point });
        errdefer reader.deinit();
        if (!std.meta.eql(reader.basis.interpretation, entry.interpretation) or reader.basis.changed_lsn != entry.changed_lsn or reader.basis.row_count != entry.row_count or
            !std.meta.eql(reader.basis.authority, self.reader.basis.authority)) return error.InvalidTableResponse;
        try self.check();
        self.following = reader;
        self.receipt = entry.receipt;
        self.after = null;
        self.before_after = null;
        self.after_after = null;
        self.changes = 0;
        self.before_rows = 0;
        self.after_rows = 0;
    }
    // A logical no-op still has an acceptance boundary, but needs no row scan.
    if (self.reader.basis.changed_lsn == self.following.?.basis.changed_lsn and
        std.meta.eql(self.reader.basis.interpretation, self.following.?.basis.interpretation)) return self.complete();
    // A retained scan cursor must name a row in that exact source. Inserts and
    // deletes therefore advance each side independently, never with the other
    // side's last emitted identity.
    var before = try self.rowAfter(&self.reader, self.before_after);
    defer if (before) |*row| row.deinit();
    var after = try self.rowAfter(&self.following.?, self.after_after);
    defer if (after) |*row| row.deinit();
    if ((before == null and self.before_rows != self.reader.basis.row_count) or
        (after == null and self.after_rows != self.following.?.basis.row_count)) return error.IncompleteSource;
    if ((before != null and self.before_rows >= self.reader.basis.row_count) or
        (after != null and self.after_rows >= self.following.?.basis.row_count)) return error.InvalidTableResponse;
    if (before == null and after == null) return self.complete();
    const order: std.math.Order = if (before == null) .gt else if (after == null) .lt else std.mem.order(u8, &try before.?.identity.encode(), &try after.?.identity.encode());
    const identity = if (order == .gt) after.?.identity else before.?.identity;
    const changed = order != .eq or !try self.sameRow(before.?, after.?);
    const changes = if (changed) try std.math.add(u64, self.changes, 1) else self.changes;
    try self.check();
    self.after = identity;
    self.changes = changes;
    if (order != .gt) {
        self.before_rows += 1;
        self.before_after = identity;
    }
    if (order != .lt) {
        self.after_rows += 1;
        self.after_after = identity;
    }
    if (!changed) return .progress;
    const change: Change = .{ .identity = identity, .before = if (order != .gt) before else null, .after = if (order != .lt) after else null };
    if (order != .gt) before = null;
    if (order != .lt) after = null;
    return .{ .change = change };
}
fn sameRow(self: *Self, before: f.TableRow.Owned, after: f.TableRow.Owned) !bool {
    // Exact canonical values preserve physical distinctions such as signed zero;
    // SQL equality or a digest alone cannot prove unchanged stored values.
    const left = try self.allocator.alloc(u8, f.TableRow.max_bytes);
    defer self.allocator.free(left);
    const right = try self.allocator.alloc(u8, f.TableRow.max_bytes);
    defer self.allocator.free(right);
    return std.mem.eql(u8, try before.row().encode(self.reader.schema.schema, left), try after.row().encode(self.following.?.schema.schema, right));
}
fn complete(self: *Self) !Event {
    try self.check();
    const previous = self.position;
    const before = self.reader.basis;
    const after = self.following.?.basis;
    self.position.source.point = self.following.?.history_point.?;
    self.scan = self.position.source.point.position;
    self.reader.deinit();
    self.reader = self.following.?;
    self.following = null;
    const receipt = self.receipt.?;
    self.receipt = null;
    return .{ .transaction = .{ .previous = previous, .next = self.position, .before = before, .after = after, .receipt = receipt, .changes = self.changes } };
}

test "change checkpoints require the current definition and exact original connection and lease" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const original: Position = .{ .version = 1, .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = null }, .source = .{ .object = .{ .scope = scope, .branch = 1, .object = 6 }, .point = .{ .lease = .{ .owner = .{ .scope = scope, .principal = 5, .operation = 7 }, .content = .{ .bytes = 1, .sha256 = @splat(1) } }, .position = .{ .partition = 8, .next_lsn = 9 }, .commitment = @splat(2) } } };
    try original.validate();
    const encoded = try p.Json.valueAlloc(t.allocator, original);
    defer t.allocator.free(encoded);
    const decoded = try p.Json.parseFromSlice(Position, t.allocator, encoded);
    defer decoded.deinit();
    try t.expectEqualDeep(original, decoded.value);
    const missing = try p.Json.valueAlloc(t.allocator, .{ .version = original.version, .connection = original.connection, .source = original.source });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(Position, t.allocator, missing));
    const old = try p.Json.valueAlloc(t.allocator, .{ .version = original.version, .definition = "f444c2a15245cf6a5852c727ebf3922f214a7fb8d3e078ea2d92b6b1eb668463", .connection = original.connection, .source = original.source });
    defer t.allocator.free(old);
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(Position, t.allocator, old));
    var foreign = original;
    foreign.version = 0;
    try t.expectError(error.IncompatibleDefinition, foreign.validate());
    foreign = original;
    foreign.source.point.commitment = @splat(0);
    try t.expectError(error.InvalidTableHistory, foreign.validate());
    foreign = original;
    foreign.source.point.lease.owner.operation = 0;
    try t.expectError(error.InvalidDataOperation, foreign.validate());
}
