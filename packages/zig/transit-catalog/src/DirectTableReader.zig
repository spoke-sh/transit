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
    fn from(source: w.Source) Basis {
        return .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.row_count };
    }
};
pub const Batch = struct {
    rows: [8]?f.TableRow.Owned = @splat(null),
    count: usize = 0,
    complete: bool,
    pub fn deinit(self: *Batch) void {
        for (&self.rows) |*slot| if (slot.*) |*row| row.deinit();
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

/// Opening inspects an existing pin. Retain `snapshot` separately so an open
/// failure never loses the durable handle needed for retry or explicit release.
pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot) !Self {
    const response = try client.call(.{ .snapshot = snapshot });
    defer response.deinit();
    return init(allocator, client.connection, response.value.result.snapshot);
}
fn init(allocator: std.mem.Allocator, connection: w.Connection, source: w.Source) !Self {
    try connection.validate();
    try connection.object(source.snapshot.object);
    try connection.owner(source.snapshot.handle.owner);
    try source.snapshot.handle.content.validate();
    try source.interpretation.validate();
    try source.accepted.validate();
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
    const response = try client.call(.{ .snapshot = self.basis.snapshot });
    defer response.deinit();
    if (!std.meta.eql(self.basis, Basis.from(response.value.result.snapshot))) return error.InvalidTableResponse;
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
    const response = try client.call(.{ .scan = .{ .snapshot = self.basis.snapshot, .after = self.after, .limits = limits } });
    defer response.deinit();
    return try self.consume(response.value.result.page, limits);
}
fn consume(self: *Self, page: w.Page, limits: P.ReadLimits) !Batch {
    if (self.complete or self.released or !std.meta.eql(self.basis.snapshot, page.snapshot) or
        !std.meta.eql(self.basis.interpretation, page.interpretation) or
        !std.meta.eql(self.basis.accepted, page.accepted) or self.basis.changed_lsn != page.changed_lsn or
        self.basis.row_count != page.total_rows or page.rows.len > limits.rows or page.rows.len > 8 or
        page.encoded_bytes > limits.encoded_bytes) return error.InvalidTableResponse;
    const consumed = std.math.add(u64, self.consumed, page.rows.len) catch return error.InvalidTableResponse;
    if (consumed > self.basis.row_count) return error.InvalidTableResponse;
    if (page.next) |cursor| {
        if (page.rows.len == 0 or consumed == self.basis.row_count or
            !std.meta.eql(cursor.source, self.basis.snapshot.handle.content)) return error.InvalidTableResponse;
        if (self.after) |previous| if (std.mem.order(u8, &cursor.after, &previous.after) != .gt) return error.InvalidTableResponse;
    } else if (consumed != self.basis.row_count) return error.InvalidTableResponse;
    var batch: Batch = .{ .complete = page.next == null };
    errdefer batch.deinit();
    var encoded_bytes: u64 = 0;
    var previous: ?[f.TableRow.Identity.encoded_bytes]u8 = if (self.after) |cursor| cursor.after else null;
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
    self.after = page.next;
    self.consumed = consumed;
    self.complete = batch.complete;
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
}
