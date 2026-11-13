//! Owned traversal of one private transaction revision. The transaction owns
//! its source pins; this reader owns only local schema and traversal memory.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.DataLifecycle;
const Self = @This();
pub const Table = struct {
    namespace: u64,
    name: c.TableAuthority.Name,
    expected: ?d.Definition = null,
};
pub const KV = struct { object: d.Object, key: []const u8, expected: ?d.Definition = null };
pub const Description = struct {
    basis: c.DirectTableReader.Basis,
    schema: c.fuze.TableSchema.Owned,
    pub fn deinit(self: *Description) void {
        self.schema.deinit();
        self.* = undefined;
    }
};

context: c.DirectTransactionRead.Context,
reader: c.DirectTableReader,

pub fn get(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, key: c.DirectClientToken.Key, request: KV) !c.DirectKVClient.Read {
    const private = try c.DirectTransactionSession.privateClient(client, key);
    const value = (try c.DirectKVClient.apply(output, private, .{ .get = .{ .object = request.object, .key = request.key } })).value;
    const view = value.workspace orelse return error.InvalidTransactionRead;
    if (!std.meta.eql(view.revision, private.transaction.?.revision)) return error.TransactionReadChanged;
    if (request.expected) |expected| if (!std.meta.eql(expected, value.interpretation.interpretation)) return error.CatalogIdentityConflict;
    return value;
}

/// Resolves against the accepted catalog root, then retains only an owned
/// interpretation and a virtual private descriptor, never another durable pin.
pub fn open(allocator: std.mem.Allocator, client: c.DirectTableClient, key: c.DirectClientToken.Key, request: Table) !Self {
    const private = try c.DirectTransactionSession.privateClient(client, key);
    const lookup = try private.call(.{ .lookup = .{ .namespace = request.namespace, .name = request.name.slice() } });
    defer lookup.deinit();
    const metadata = lookup.value.result.lookup orelse return error.TableNotFound;
    const view = metadata.workspace orelse return error.InvalidTransactionRead;
    if (request.expected) |expected| if (!std.meta.eql(expected, metadata.interpretation.interpretation)) return error.CatalogIdentityConflict;
    const pinned = try private.call(.{ .pin = .{
        .object = metadata.interpretation.interpretation.object,
        .owner = view.cut.begin.identity.begin,
        .expected = metadata.position,
        .interpretation = metadata.interpretation.interpretation,
    } });
    defer pinned.deinit();
    var reader = try c.DirectTableReader.open(allocator, private, .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin });
    errdefer reader.deinit();
    if (!std.meta.eql(reader.basis.workspace, metadata.workspace) or !std.meta.eql(view.revision, private.transaction.?.revision)) return error.InvalidTransactionRead;
    return .{ .context = private.transaction.?, .reader = reader };
}

pub fn deinit(self: *Self) void {
    self.reader.deinit();
    self.* = undefined;
}

/// Binds the saved revision, never inspects and replaces it with current state.
fn bound(self: *const Self, client: c.DirectTableClient, key: c.DirectClientToken.Key) !c.DirectTableClient {
    if (!std.meta.eql(key, self.context.key) or !std.meta.eql(client.connection, key.connection)) return error.CatalogIdentityConflict;
    if (client.transaction) |context| if (!std.meta.eql(context, self.context)) return error.TransactionReadChanged;
    var result = client;
    result.transaction = self.context;
    return result;
}

/// Fresh disclosure of metadata rechecks current access even after completion.
pub fn describe(self: *const Self, client: c.DirectTableClient, key: c.DirectClientToken.Key, output: std.mem.Allocator) !Description {
    try self.reader.check(try self.bound(client, key));
    return .{ .basis = self.reader.basis, .schema = try self.reader.schema.schema.clone(output) };
}

/// Rows use output, not the reader's schema allocator. Failed exchanges or
/// decoding never advance the committed local cursor. Output survives deinit.
pub fn next(self: *Self, client: c.DirectTableClient, key: c.DirectClientToken.Key, output: std.mem.Allocator, limits: c.storage.TablePartition.ReadLimits) !?c.DirectTableReader.Batch {
    var working = self.reader;
    working.allocator = output;
    const result = try working.next(try self.bound(client, key), limits);
    self.reader.after = working.after;
    self.reader.consumed = working.consumed;
    self.reader.complete = working.complete;
    return result;
}

pub fn readKey(self: *const Self, client: c.DirectTableClient, key: c.DirectClientToken.Key, output: std.mem.Allocator, cells: []const c.fuze.Types.Values.Cell) !?c.fuze.TableRow.Owned {
    var working = self.reader;
    working.allocator = output;
    var buffer: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    return working.readKey(try self.bound(client, key), try encodeKey(self.reader.schema.schema, cells, &buffer));
}

pub fn encodeKey(schema: c.fuze.TableSchema.Schema, keys: []const c.fuze.Types.Values.Cell, buffer: []u8) ![]const u8 {
    if (keys.len != schema.primary_key.len or keys.len == 0) return error.InvalidTableKey;
    var cells: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = @splat(.null);
    for (schema.primary_key, keys) |column, cell| cells[try schema.index(column)] = cell;
    return c.fuze.Collation.encodePrimaryKeySortKey(schema, cells[0..schema.columns.len], true, buffer);
}

test "transaction primary keys preserve schema order and collation" {
    const t = std.testing;
    const schema: c.fuze.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 4, .columns = &.{
        .{ .id = 1, .name = "payload", .type = .binary },
        .{ .id = 2, .name = "region", .type = .utf8, .collation = .ascii_ci, .nullable = false },
        .{ .id = 3, .name = "number", .type = .int64, .nullable = false },
    }, .primary_key = &.{ 2, 3 } };
    var left: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    var right: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const a = try encodeKey(schema, &.{ .{ .value = .{ .atom = .{ .bytes = "WEST" } } }, .{ .value = .{ .atom = .{ .signed = 42 } } } }, &left);
    const b = try encodeKey(schema, &.{ .{ .value = .{ .atom = .{ .bytes = "west" } } }, .{ .value = .{ .atom = .{ .signed = 42 } } } }, &right);
    try t.expectEqualSlices(u8, a, b);
    try t.expectError(error.InvalidTableKey, encodeKey(schema, &.{}, &right));
    const other = try encodeKey(schema, &.{ .{ .value = .{ .atom = .{ .bytes = "west" } } }, .{ .value = .{ .atom = .{ .signed = 43 } } } }, &right);
    try t.expect(std.mem.order(u8, a, other) == .lt);
}
