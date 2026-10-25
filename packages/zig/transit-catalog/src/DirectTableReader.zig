//! Bounded traversal of an explicitly retained Table source. The durable pin
//! belongs to the caller; local destruction never releases or replaces it.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const f = c.fuze;
const d = c.protocol.DataLifecycle;
const P = c.storage.TablePartition;
const Self = @This();

pub const Basis = struct {
    snapshot: w.Snapshot,
    interpretation: c.storage.TableDeclaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    row_count: u64,
    authority: c.DirectReadAuthority,
    fn from(source: w.Source) Basis {
        return .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.row_count, .authority = source.authority };
    }
    /// Complete source evidence, independent of a native KV revision. The
    /// immutable declaration and pin content bind interpretation and WAL/root
    /// coverage; logical-change progress remains explicit for freshness checks.
    pub fn fingerprint(self: Basis) ![32]u8 {
        var bytes: [4096]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try c.protocol.Json.write(self, &encoder);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        digest.update("transit.table.direct.query.source.v1\x00");
        digest.update(&c.protocol.Growth.definition_bytes);
        digest.update(writer.buffered());
        return digest.finalResult();
    }
};

test "maximum direct source evidence fits the bounded canonical fingerprint" {
    const t = std.testing;
    const native = c.protocol.max_counter;
    const wide = std.math.maxInt(u64);
    const scope: d.Scope = .{ .realm = native, .resource = native, .catalog = wide };
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = wide };
    const basis: Basis = .{
        .snapshot = .{ .object = object, .handle = .{ .owner = .{ .scope = scope, .principal = native, .operation = wide }, .content = .{ .bytes = wide, .sha256 = @splat(255) } } },
        .interpretation = .{ .interpretation = .{ .object = object, .revision = wide, .digest = @splat(255) }, .content = .{ .bytes = c.storage.TableDeclaration.max_bytes, .sha256 = @splat(255) }, .schema_fingerprint = @splat(255), .retired = false },
        .accepted = .{ .partition = wide, .next_lsn = wide },
        .changed_lsn = wide,
        .row_count = wide,
        .authority = .{ .database = native, .schema = native, .table = native },
    };
    try basis.interpretation.validate();
    const canonical = try c.protocol.Json.valueAlloc(t.allocator, basis);
    defer t.allocator.free(canonical);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.table.direct.query.source.v1\x00");
    hash.update(&c.protocol.Growth.definition_bytes);
    hash.update(canonical);
    try t.expectEqualSlices(u8, &hash.finalResult(), &try basis.fingerprint());
}
pub const Batch = struct {
    rows: [8]?f.TableRow.Owned = @splat(null),
    count: usize = 0,
    complete: bool,
    pub fn deinit(self: *Batch) void {
        for (&self.rows) |*slot| if (slot.*) |*row| row.deinit();
        self.* = undefined;
    }
};
pub const RangeBatch = struct {
    batch: Batch,
    next: ?P.KeyRange.Cursor,
    pub fn deinit(self: *RangeBatch) void {
        self.batch.deinit();
        self.* = undefined;
    }
};

allocator: std.mem.Allocator,
connection: w.Connection,
basis: Basis,
schema: f.TableSchema.Owned,
after: ?P.SnapshotCursor = null,
consumed: u64 = 0,
complete: bool = false,
released: bool = false,
history_point: ?P.HistoryPoint = null,

/// Opening inspects an existing pin. Retain `snapshot` separately so an open
/// failure never loses the durable handle needed for retry or explicit release.
pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot) !Self {
    const response = try client.call(.{ .snapshot = snapshot });
    defer response.deinit();
    return init(allocator, client.connection, response.value.result.snapshot);
}
pub fn openHistoryStart(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot) !Self {
    const response = try client.call(.{ .history_start = snapshot });
    defer response.deinit();
    return initHistory(allocator, client.connection, response.value.result.history_source);
}
pub fn openHistory(allocator: std.mem.Allocator, client: c.DirectTableClient, source: w.Historical) !Self {
    const response = try client.call(.{ .history_source = source });
    defer response.deinit();
    return initHistory(allocator, client.connection, response.value.result.history_source);
}
fn initHistory(allocator: std.mem.Allocator, connection: w.Connection, source: w.HistorySource) !Self {
    _ = try source.point.cursorSource();
    if (!std.meta.eql(source.point.lease, source.source.snapshot.handle) or !std.meta.eql(source.point.position, source.source.accepted)) return error.InvalidTableResponse;
    var result = try init(allocator, connection, source.source);
    result.history_point = source.point;
    return result;
}
fn init(allocator: std.mem.Allocator, connection: w.Connection, source: w.Source) !Self {
    try connection.validate();
    try connection.object(source.snapshot.object);
    try connection.owner(source.snapshot.handle.owner);
    try source.snapshot.handle.content.validate();
    try source.interpretation.validate();
    try source.accepted.validate();
    try source.authority.validate();
    if (!std.meta.eql(source.snapshot.object, source.interpretation.interpretation.object) or
        source.accepted.next_lsn == 0 or source.changed_lsn > source.accepted.next_lsn) return error.InvalidTableResponse;
    const bytes = try source.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var schema = try f.TableSchema.decode(allocator, bytes);
    errdefer schema.deinit();
    if (schema.schema.object != source.snapshot.object.object or
        !std.mem.eql(u8, &try schema.schema.fingerprint(), &source.interpretation.schema_fingerprint)) return error.InvalidTableResponse;
    return .{ .allocator = allocator, .connection = connection, .basis = Basis.from(source), .schema = schema };
}
pub fn deinit(self: *Self) void {
    self.schema.deinit();
    self.* = undefined;
}
fn requireClient(self: *const Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    if (self.released) return error.TableSnapshotReleased;
}
/// Recheck current rights and exact source attribution before disclosing a
/// result computed from cached rows. Cached data carries no authorization.
pub fn check(self: *const Self, client: c.DirectTableClient) !void {
    try self.requireClient(client);
    const response = try client.call(if (self.history_point) |point| .{ .history_source = .{ .object = self.basis.snapshot.object, .point = point } } else .{ .snapshot = self.basis.snapshot });
    defer response.deinit();
    const source = if (self.history_point != null) response.value.result.history_source.source else response.value.result.snapshot;
    if (!std.meta.eql(self.basis, Basis.from(source))) return error.InvalidTableResponse;
}
fn scanAction(self: *const Self, after: ?P.SnapshotCursor, limits: P.ReadLimits) w.Action {
    return if (self.history_point) |point|
        .{ .history_scan = .{ .source = .{ .object = self.basis.snapshot.object, .point = point }, .after = after, .limits = limits } }
    else
        .{ .scan = .{ .snapshot = self.basis.snapshot, .after = after, .limits = limits } };
}
fn cursorSource(self: *const Self) !d.Content {
    return if (self.history_point) |point| point.cursorSource() else self.basis.snapshot.handle.content;
}
/// A failed exchange, invalid page or decode failure leaves traversal progress
/// unchanged. Returned rows own their values independently of this reader.
pub fn next(self: *Self, client: c.DirectTableClient, limits: P.ReadLimits) !?Batch {
    try self.requireClient(client);
    try limits.validate();
    if (limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
    if (self.complete) {
        try self.check(client);
        return null;
    }
    const response = try client.call(self.scanAction(self.after, limits));
    defer response.deinit();
    return try self.consume(if (self.history_point != null) response.value.result.history_page.page else response.value.result.page, limits);
}
/// Ordered lookup on the same retained identity index, without changing this
/// reader's sequential coverage cursor. A resumed relational operator supplies
/// its accepted identity; an empty suffix does not claim full-table consumption.
pub fn readAfter(self: *const Self, client: c.DirectTableClient, after: ?f.TableRow.Identity, limits: P.ReadLimits) !Batch {
    try self.requireClient(client);
    try limits.validate();
    if (limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
    const cursor: ?P.SnapshotCursor = if (after) |identity| .{ .source = try self.cursorSource(), .after = try identity.encode() } else null;
    const response = try client.call(self.scanAction(cursor, limits));
    defer response.deinit();
    return self.decodePage(if (self.history_point != null) response.value.result.history_page.page else response.value.result.page, limits, cursor);
}
/// Collision-safe lookup under the retained schema's physical key semantics.
/// Neither a hit nor absence changes sequential coverage or its cursor.
pub fn readKey(self: *const Self, client: c.DirectTableClient, key: []const u8) !?f.TableRow.Owned {
    try self.requireClient(client);
    if (self.history_point != null) return error.UnsupportedHistoricalPointRead;
    if (key.len == 0 or key.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
    const binary = try w.Binary.encode(self.allocator, key);
    defer self.allocator.free(binary.base64);
    const response = try client.call(.{ .read_key = .{ .snapshot = self.basis.snapshot, .key = binary } });
    defer response.deinit();
    return self.decodePoint(response.value.result.point, key);
}
fn decodePoint(self: *const Self, point: w.Point, key: []const u8) !?f.TableRow.Owned {
    if (self.released or !std.meta.eql(self.basis.snapshot, point.snapshot) or
        !std.meta.eql(self.basis.interpretation, point.interpretation) or
        !std.meta.eql(self.basis.accepted, point.accepted) or self.basis.changed_lsn != point.changed_lsn or
        self.basis.row_count != point.total_rows) return error.InvalidTableResponse;
    const binary = point.row orelse return null;
    if (self.basis.row_count == 0) return error.InvalidTableResponse;
    const bytes = try binary.decode(self.allocator, f.TableRow.max_bytes);
    defer self.allocator.free(bytes);
    var row = try f.TableRow.decode(self.allocator, self.schema.schema, bytes);
    errdefer row.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.mem.eql(u8, key, try row.row().storageKey(self.schema.schema, &actual))) return error.InvalidTableResponse;
    return row;
}

/// One ordered interval page over this retained source. The caller owns the
/// continuation; this does not alter the reader's full-table coverage cursor.
pub fn readRange(self: *const Self, client: c.DirectTableClient, interval: P.KeyRange, after: ?P.KeyRange.Cursor, limits: P.ReadLimits) !RangeBatch {
    try self.requireClient(client);
    if (self.history_point != null) return error.UnsupportedHistoricalRangeRead;
    try limits.validate();
    if (limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const response = try client.call(.{ .key_range = .{
        .snapshot = self.basis.snapshot,
        .interval = try w.KeyInterval.encode(arena.allocator(), interval),
        .after = if (after) |cursor| try w.KeyCursor.encode(arena.allocator(), cursor) else null,
        .limits = limits,
    } });
    defer response.deinit();
    return self.decodeRange(response.value.result.key_range, interval, after, limits);
}
fn decodeRange(self: *const Self, page: w.KeyRangePage, interval: P.KeyRange, after: ?P.KeyRange.Cursor, limits: P.ReadLimits) !RangeBatch {
    if (self.released or !std.meta.eql(self.basis.snapshot, page.snapshot) or
        !std.meta.eql(self.basis.interpretation, page.interpretation) or
        !std.meta.eql(self.basis.accepted, page.accepted) or self.basis.changed_lsn != page.changed_lsn or
        self.basis.row_count != page.total_rows or page.rows.len > limits.rows or page.rows.len > 8 or
        page.rows.len > self.basis.row_count or page.encoded_bytes > limits.encoded_bytes) return error.InvalidTableResponse;
    const fingerprint = try interval.fingerprint();
    var previous: ?P.KeyRange.Key = null;
    if (after) |cursor| {
        try cursor.after.validate();
        if (!std.meta.eql(cursor.source, self.basis.snapshot.handle.content) or !std.mem.eql(u8, &cursor.interval, &fingerprint) or !interval.contains(cursor.after.slice())) return error.InvalidTableCursor;
        previous = cursor.after;
    }
    var result: RangeBatch = .{ .batch = .{ .complete = page.next == null }, .next = null };
    errdefer result.deinit();
    var encoded_bytes: u64 = 0;
    for (page.rows, 0..) |binary, i| {
        const bytes = try binary.decode(self.allocator, f.TableRow.max_bytes);
        defer self.allocator.free(bytes);
        encoded_bytes += bytes.len;
        if (encoded_bytes > limits.encoded_bytes) return error.InvalidTableResponse;
        result.batch.rows[i] = try f.TableRow.decode(self.allocator, self.schema.schema, bytes);
        result.batch.count += 1;
        var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const key = try result.batch.rows[i].?.row().storageKey(self.schema.schema, &key_bytes);
        if (!interval.contains(key)) return error.InvalidTableResponse;
        if (previous) |before| if (std.mem.order(u8, key, before.slice()) != .gt) return error.InvalidTableResponse;
        previous = try P.KeyRange.Key.init(key);
    }
    if (page.next) |encoded| {
        const cursor = try encoded.native(self.allocator);
        if (page.rows.len == 0 or previous == null or !std.meta.eql(cursor.source, self.basis.snapshot.handle.content) or
            !std.mem.eql(u8, &cursor.interval, &fingerprint) or !std.meta.eql(cursor.after, previous.?)) return error.InvalidTableResponse;
        result.next = cursor;
    }
    if (encoded_bytes != page.encoded_bytes) return error.InvalidTableResponse;
    return result;
}
fn consume(self: *Self, page: w.Page, limits: P.ReadLimits) !Batch {
    if (self.complete or self.released) return error.InvalidTableResponse;
    const consumed = std.math.add(u64, self.consumed, page.rows.len) catch return error.InvalidTableResponse;
    if (consumed > self.basis.row_count) return error.InvalidTableResponse;
    if (page.next != null) {
        if (consumed == self.basis.row_count) return error.InvalidTableResponse;
    } else if (consumed != self.basis.row_count) return error.InvalidTableResponse;
    const batch = try self.decodePage(page, limits, self.after);
    self.after = page.next;
    self.consumed = consumed;
    self.complete = batch.complete;
    return batch;
}
fn decodePage(self: *const Self, page: w.Page, limits: P.ReadLimits, after: ?P.SnapshotCursor) !Batch {
    if (self.released or !std.meta.eql(self.basis.snapshot, page.snapshot) or
        !std.meta.eql(self.basis.interpretation, page.interpretation) or
        !std.meta.eql(self.basis.accepted, page.accepted) or self.basis.changed_lsn != page.changed_lsn or
        self.basis.row_count != page.total_rows or page.rows.len > limits.rows or page.rows.len > 8 or
        page.encoded_bytes > limits.encoded_bytes) return error.InvalidTableResponse;
    if (page.rows.len > self.basis.row_count or (after == null and page.rows.len == 0 and self.basis.row_count != 0)) return error.InvalidTableResponse;
    if (page.next) |cursor| {
        if (page.rows.len == 0 or
            !std.meta.eql(cursor.source, try self.cursorSource())) return error.InvalidTableResponse;
        if (after) |previous| if (std.mem.order(u8, &cursor.after, &previous.after) != .gt) return error.InvalidTableResponse;
    }
    var batch: Batch = .{ .complete = page.next == null };
    errdefer batch.deinit();
    var encoded_bytes: u64 = 0;
    var previous: ?[f.TableRow.Identity.encoded_bytes]u8 = if (after) |cursor| cursor.after else null;
    for (page.rows, 0..) |binary, i| {
        const bytes = try binary.decode(self.allocator, f.TableRow.max_bytes);
        defer self.allocator.free(bytes);
        encoded_bytes += bytes.len;
        if (encoded_bytes > limits.encoded_bytes) return error.InvalidTableResponse;
        batch.rows[i] = try f.TableRow.decode(self.allocator, self.schema.schema, bytes);
        batch.count += 1;
        const identity = try batch.rows[i].?.identity.encode();
        if (previous) |before| if (std.mem.order(u8, &identity, &before) != .gt) return error.InvalidTableResponse;
        previous = identity;
    }
    if (page.next) |cursor| if (previous == null or !std.meta.eql(cursor.after, previous.?)) return error.InvalidTableResponse;
    if (encoded_bytes != page.encoded_bytes) return error.InvalidTableResponse;
    return batch;
}
/// Explicit and retryable. If its reply is lost, retain this original reader or
/// snapshot handle and retry release; destruction alone performs no remote work.
pub fn release(self: *Self, client: c.DirectTableClient) !void {
    if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
    const response = try client.call(.{ .release = self.basis.snapshot });
    defer response.deinit();
    self.released = true;
}

fn pointAllocationFailures(allocator: std.mem.Allocator, connection: w.Connection, source: w.Source, point: w.Point, key: []const u8) !void {
    var reader = try init(allocator, connection, source);
    defer reader.deinit();
    var row = (try reader.decodePoint(point, key)) orelse return error.MissingTestRow;
    defer row.deinit();
    try std.testing.expectEqual(@as(u64, 0), reader.consumed);
}
fn rangeAllocationFailures(allocator: std.mem.Allocator, connection: w.Connection, source: w.Source, page: w.KeyRangePage, interval: P.KeyRange) !void {
    var reader = try init(allocator, connection, source);
    defer reader.deinit();
    var batch = try reader.decodeRange(page, interval, null, .{});
    defer batch.deinit();
    try std.testing.expectEqual(@as(u64, 0), reader.consumed);
}

test "retained reader binds pages, complete consumption and original schema without advancing failed reads" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "value", .type = .binary }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns };
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    var scratch: [65536]u8 = undefined;
    const source: w.Source = .{
        .snapshot = .{ .object = declaration.definition.object, .handle = .{ .owner = .{ .scope = connection.scope, .principal = 4, .operation = 2 }, .content = .{ .bytes = 1, .sha256 = @splat(1) } } },
        .interpretation = try declaration.stored(),
        .accepted = .{ .partition = 2, .next_lsn = 3 },
        .changed_lsn = 2,
        .row_count = 3,
        .schema = try w.Binary.encode(alloc, try schema.encode(&scratch)),
        .authority = .{ .database = 11, .schema = 12, .table = 13 },
    };
    var reader = try init(t.allocator, connection, source);
    defer reader.deinit();
    const cells = [_]f.Types.Values.Cell{.{ .value = .{ .atom = .{ .bytes = "\x00\xff\x80" } } }};
    var binary: [3]w.Binary = undefined;
    var lengths: [3]u32 = undefined;
    for (&binary, &lengths, 0..) |*encoded, *length, i| {
        const row: f.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = @intCast(i) }, .cells = &cells };
        const bytes = try row.encode(schema, &scratch);
        encoded.* = try w.Binary.encode(alloc, bytes);
        length.* = @intCast(bytes.len);
    }
    const first: w.Page = .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .total_rows = 3, .rows = binary[0..1], .encoded_bytes = lengths[0], .next = .{ .source = source.snapshot.handle.content, .after = try (f.TableRow.Identity{ .origin = 7, .operation = 1, .ordinal = 0 }).encode() } };
    var bad = first;
    bad.accepted.next_lsn += 1;
    try t.expectError(error.InvalidTableResponse, reader.consume(bad, .{}));
    bad = first;
    bad.changed_lsn += 1;
    try t.expectError(error.InvalidTableResponse, reader.consume(bad, .{}));
    bad = first;
    bad.next = null;
    try t.expectError(error.InvalidTableResponse, reader.consume(bad, .{}));
    try t.expectEqual(@as(u64, 0), reader.consumed);
    var batch = try reader.consume(first, .{});
    defer batch.deinit();
    try t.expectEqualStrings("\x00\xff\x80", batch.rows[0].?.row().cells[0].value.atom.bytes);
    const final: w.Page = .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .total_rows = 3, .rows = binary[1..], .encoded_bytes = lengths[1] + lengths[2], .next = null };
    bad = final;
    bad.rows = &.{ binary[1], try w.Binary.encode(alloc, "broken") };
    try t.expectError(error.InvalidTableRowEncoding, reader.consume(bad, .{}));
    try t.expectEqual(@as(u64, 1), reader.consumed);
    try t.expectEqualDeep(first.next, reader.after);
    bad = final;
    bad.next = first.next;
    try t.expectError(error.InvalidTableResponse, reader.consume(bad, .{}));
    var ending = try reader.consume(final, .{});
    defer ending.deinit();
    try t.expect(ending.complete and reader.complete);
    try t.expectEqual(@as(u64, 3), reader.consumed);
    try t.expectError(error.InvalidTableResponse, reader.consume(final, .{}));
    // Relational resume can seek a suffix without pretending it traversed the
    // earlier rows or changing an independent sequential cursor.
    var suffix = try reader.decodePage(final, .{}, first.next);
    defer suffix.deinit();
    try t.expectEqual(@as(usize, 2), suffix.count);
    try t.expect(suffix.complete and reader.complete);
    try t.expectEqual(@as(u64, 3), reader.consumed);
    bad = final;
    bad.rows = &.{binary[0]};
    bad.encoded_bytes = lengths[0];
    try t.expectError(error.InvalidTableResponse, reader.decodePage(bad, .{}, first.next));
    bad = final;
    bad.accepted.next_lsn += 1;
    try t.expectError(error.InvalidTableResponse, reader.decodePage(bad, .{}, first.next));
    bad = final;
    bad.rows = &.{};
    bad.encoded_bytes = 0;
    try t.expectError(error.InvalidTableResponse, reader.decodePage(bad, .{}, null));
    var point: w.Point = .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .total_rows = source.row_count, .row = binary[0] };
    const identity = try (f.TableRow.Identity{ .origin = 7, .operation = 1, .ordinal = 0 }).encode();
    var found = (try reader.decodePoint(point, &identity)).?;
    defer found.deinit();
    try t.expectEqualStrings("\x00\xff\x80", found.row().cells[0].value.atom.bytes);
    try t.checkAllAllocationFailures(t.allocator, pointAllocationFailures, .{ connection, source, point, &identity });
    try t.expectError(error.InvalidTableResponse, reader.decodePoint(point, &try (f.TableRow.Identity{ .origin = 7, .operation = 1, .ordinal = 1 }).encode()));
    point.row = null;
    try t.expect(try reader.decodePoint(point, &identity) == null);
    point.accepted.next_lsn += 1;
    try t.expectError(error.InvalidTableResponse, reader.decodePoint(point, &identity));
    try t.expectEqual(@as(u64, 3), reader.consumed);
    try t.expect(reader.complete);

    const limit_key = try (f.TableRow.Identity{ .origin = 7, .operation = 1, .ordinal = 2 }).encode();
    const interval: P.KeyRange = .{ .lower = .{ .key = &identity }, .upper = .{ .key = &limit_key, .inclusive = false } };
    var range_page: w.KeyRangePage = .{
        .snapshot = source.snapshot,
        .interpretation = source.interpretation,
        .accepted = source.accepted,
        .changed_lsn = source.changed_lsn,
        .total_rows = 3,
        .rows = binary[0..1],
        .encoded_bytes = lengths[0],
        .next = try w.KeyCursor.encode(alloc, .{ .source = source.snapshot.handle.content, .interval = try interval.fingerprint(), .after = try P.KeyRange.Key.init(&identity) }),
    };
    var range_first = try reader.decodeRange(range_page, interval, null, .{});
    defer range_first.deinit();
    try t.expect(!range_first.batch.complete and range_first.next != null);
    try t.checkAllAllocationFailures(t.allocator, rangeAllocationFailures, .{ connection, source, range_page, interval });
    var invalid_range = range_page;
    invalid_range.next.?.interval[0] ^= 1;
    try t.expectError(error.InvalidTableResponse, reader.decodeRange(invalid_range, interval, null, .{}));
    invalid_range = range_page;
    invalid_range.rows = binary[2..3]; // Upper bound excludes this valid row.
    invalid_range.encoded_bytes = lengths[2];
    try t.expectError(error.InvalidTableResponse, reader.decodeRange(invalid_range, interval, null, .{}));
    try t.expectError(error.InvalidTableResponse, reader.decodeRange(range_page, interval, range_first.next, .{}));
    range_page.rows = binary[1..2];
    range_page.encoded_bytes = lengths[1];
    range_page.next = null;
    var range_last = try reader.decodeRange(range_page, interval, range_first.next, .{});
    defer range_last.deinit();
    try t.expect(range_last.batch.complete and range_last.next == null);
    try t.expectEqual(@as(usize, 1), range_last.batch.count);
    try t.expectEqual(@as(u32, 1), range_last.batch.rows[0].?.identity.ordinal);
    try t.expectEqual(@as(u64, 3), reader.consumed); // Independent sequential coverage.

    const historical_point: P.HistoryPoint = .{ .lease = source.snapshot.handle, .position = source.accepted, .commitment = @splat(9) };
    var historical = try initHistory(t.allocator, connection, .{ .point = historical_point, .source = source });
    defer historical.deinit();
    // A valid ordinary snapshot cursor is still foreign to a historical read.
    try t.expectError(error.InvalidTableResponse, historical.consume(first, .{}));
    try t.expectEqual(@as(u64, 0), historical.consumed);
    var historical_first = first;
    historical_first.next.?.source = try historical_point.cursorSource();
    var historical_batch = try historical.consume(historical_first, .{});
    defer historical_batch.deinit();
    try t.expectEqual(@as(usize, 1), historical_batch.count);
    var historical_final = try historical.consume(final, .{});
    defer historical_final.deinit();
    try t.expect(historical.complete and historical_final.count == 2);
    var different_point = historical_point;
    different_point.commitment[0] ^= 1;
    var different = try initHistory(t.allocator, connection, .{ .point = different_point, .source = source });
    defer different.deinit();
    try t.expectError(error.InvalidTableResponse, different.consume(historical_first, .{}));
}
