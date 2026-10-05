const std = @import("std");
const e = std.testing;
const f = @import("transit_fuze");
const Data = @import("TableData.zig");
const Index = @import("ImmutableIndex.zig");
const Pub = @import("Publication.zig");
const Cell = f.Types.Values.Cell;
const Row = f.TableRow;
const Store = struct {
    allocator: std.mem.Allocator = e.allocator,
    records: std.ArrayList([]const u8) = .empty,
    denied: bool = false,
    fail_after: ?usize = null,
    max_index_read: usize = 0,
    fn deinit(self: *Store) void {
        for (self.records.items) |record| self.allocator.free(record);
        self.records.deinit(self.allocator);
    }
    fn read(self: *Store, id: u64, output: []u8) ![]const u8 {
        if (self.denied) return error.AccessDenied;
        if (id == 0 or id > self.records.items.len) return error.MissingPage;
        const bytes = self.records.items[@intCast(id - 1)];
        if (bytes.len > output.len) return error.PageTooLarge;
        @memcpy(output[0..bytes.len], bytes);
        return output[0..bytes.len];
    }
    pub fn load(self: *Store, ref: Index.Reference, output: []u8) ![]const u8 {
        const bytes = try self.read(ref.id, output);
        self.max_index_read = @max(self.max_index_read, bytes.len);
        return bytes;
    }
    pub fn loadBlob(self: *Store, ref: Data.Blob, output: []u8) ![]const u8 {
        return self.read(ref.id, output);
    }
    pub fn save(self: *Store, spec: Pub.Spec, bytes: []const u8) !u64 {
        if (self.denied) return error.AccessDenied;
        if (self.fail_after) |limit| if (self.records.items.len >= limit) return error.StorageUnavailable;
        try e.expectEqualDeep(try Pub.Digest.of(spec.format, bytes), spec);
        const owned = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(owned);
        try self.records.append(self.allocator, owned);
        return self.records.items.len;
    }
    pub fn saveBlob(self: *Store, spec: Pub.Spec, bytes: []const u8) !u64 {
        return self.save(spec, bytes);
    }
};
const schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 4, .columns = &.{
    .{ .id = 1, .name = "tenant", .type = .utf8, .nullable = false },
    .{ .id = 2, .name = "id", .type = .int32, .nullable = false },
    .{ .id = 3, .name = "value", .type = .utf8 },
}, .primary_key = &.{ 1, 2 } };
fn integer(number: i128) Cell {
    return .{ .value = .{ .atom = .{ .signed = number } } };
}
fn text(bytes: []const u8) Cell {
    return .{ .value = .{ .atom = .{ .bytes = bytes } } };
}
fn identity(ordinal: u32) Row.Identity {
    return .{ .origin = 10, .operation = 20, .ordinal = ordinal };
}
test "general Table candidates preserve composite uniqueness, retained roots and exact mutation counts" {
    var store: Store = .{};
    defer store.deinit();
    var data: Data = .{ .schema = schema };
    for (0..72) |i| {
        const row: Row.Row = .{ .identity = identity(@intCast(i)), .cells = &.{ text("tenant"), integer(@intCast(i)), text("payload") } };
        const candidate = try data.insert(e.allocator, &store, row);
        try e.expectEqual(@as(u64, 1), candidate.matched);
        try e.expectEqual(@as(u64, 1), candidate.changed);
        data = candidate.data;
    }
    const retained = data;
    try e.expectEqualDeep(identity(12), (try data.findKey(e.allocator, &store, &.{ text("tenant"), integer(12) })).?);
    try e.expectEqual(null, try data.findKey(e.allocator, &store, &.{ text("tenant"), integer(999) }));
    try e.expectError(error.RowExists, data.insert(e.allocator, &store, .{ .identity = identity(99), .cells = &.{ text("tenant"), integer(12), .null } }));
    try e.expectError(error.RowIdentityExists, data.insert(e.allocator, &store, .{ .identity = identity(12), .cells = &.{ text("other"), integer(12), .null } }));
    const count = store.records.items.len;
    const no_change = try data.update(e.allocator, &store, .{ .identity = identity(12), .cells = &.{ text("tenant"), integer(12), text("payload") } });
    try e.expectEqual(@as(u64, 1), no_change.matched);
    try e.expectEqual(@as(u64, 0), no_change.changed);
    try e.expectEqual(count, store.records.items.len);
    try e.expectError(error.RowExists, data.update(e.allocator, &store, .{ .identity = identity(12), .cells = &.{ text("tenant"), integer(13), .null } }));
    data = (try data.update(e.allocator, &store, .{ .identity = identity(12), .cells = &.{ text("tenant"), integer(99), text("updated") } })).data;
    try e.expectEqual(null, try data.findKey(e.allocator, &store, &.{ text("tenant"), integer(12) }));
    try e.expectEqualDeep(identity(12), (try data.findKey(e.allocator, &store, &.{ text("tenant"), integer(99) })).?);
    const removed = try data.delete(e.allocator, &store, identity(12));
    try e.expectEqual(@as(u64, 1), removed.changed);
    data = removed.data;
    try e.expectEqual(null, try data.get(e.allocator, &store, identity(12)));
    try e.expectEqual(null, try data.findKey(e.allocator, &store, &.{ text("tenant"), integer(99) }));
    try e.expectEqual(@as(u64, 0), (try data.delete(e.allocator, &store, identity(12))).matched);
    var original = (try retained.get(e.allocator, &store, identity(12))).?;
    defer original.deinit();
    try e.expectEqualStrings("payload", original.row().cells[2].value.atom.bytes);
    var after: ?Row.Identity = null;
    var rows: usize = 0;
    while (try data.next(e.allocator, &store, after)) |result| {
        var owned = result;
        defer owned.deinit();
        try e.expect(owned.identity.ordinal != 12);
        after = owned.identity;
        rows += 1;
    }
    try e.expectEqual(@as(usize, 71), rows);
    try e.expect(store.max_index_read <= Index.node_bytes);
    store.denied = true;
    try e.expectError(error.AccessDenied, data.next(e.allocator, &store, null));
}
test "unkeyed duplicate rows retain distinct identities and wide values exceed native inline size" {
    var store: Store = .{};
    defer store.deinit();
    var unkeyed = schema;
    unkeyed.primary_key = &.{};
    var data: Data = .{ .schema = unkeyed };
    const large = try e.allocator.alloc(u8, 32768);
    defer e.allocator.free(large);
    @memset(large, 'x');
    const values = [_]Cell{ text("tenant"), integer(1), text(large) };
    data = (try data.insert(e.allocator, &store, .{ .identity = identity(1), .cells = &values })).data;
    data = (try data.insert(e.allocator, &store, .{ .identity = identity(2), .cells = &values })).data;
    @memset(large, 'z');
    var first = (try data.get(e.allocator, &store, identity(1))).?;
    defer first.deinit();
    try e.expectEqual(@as(usize, 32768), first.row().cells[2].value.atom.bytes.len);
    try e.expect(std.mem.allEqual(u8, first.row().cells[2].value.atom.bytes, 'x'));
    try e.expectEqual(@as(u64, 2), data.index.root.?.entries);
    try e.expectError(error.NoPrimaryKey, data.findKey(e.allocator, &store, &.{}));
}
test "publication failure after row staging cannot publish a successful statement prefix" {
    var store: Store = .{};
    defer store.deinit();
    const data: Data = .{ .schema = schema };
    store.fail_after = 1;
    const row: Row.Row = .{ .identity = identity(1), .cells = &.{ text("tenant"), integer(1), .null } };
    try e.expectError(error.StorageUnavailable, data.insert(e.allocator, &store, row));
    try e.expectEqual(null, data.index.root);
    try e.expectEqual(null, try data.get(e.allocator, &store, row.identity));
    store.fail_after = null;
    const accepted = (try data.insert(e.allocator, &store, row)).data;
    store.fail_after = store.records.items.len + 1;
    try e.expectError(error.StorageUnavailable, accepted.update(e.allocator, &store, .{ .identity = identity(1), .cells = &.{ text("tenant"), integer(2), text("change") } }));
    try e.expectEqualDeep(identity(1), (try accepted.findKey(e.allocator, &store, &.{ text("tenant"), integer(1) })).?);
    try e.expectEqual(null, try accepted.findKey(e.allocator, &store, &.{ text("tenant"), integer(2) }));
}
test "a digest bucket compares actual keys instead of rejecting its first unequal candidate" {
    var store: Store = .{};
    defer store.deinit();
    var data: Data = .{ .schema = schema };
    data = (try data.insert(e.allocator, &store, .{ .identity = identity(1), .cells = &.{ text("tenant"), integer(1), .null } })).data;
    var buffer: [4096]u8 = undefined;
    const wanted = [_]Cell{ text("tenant"), integer(2), .null };
    const digest = try Row.keyDigest(schema, &wanted, &buffer);
    // Synthetic collision candidate: real SHA-256 collisions are not required
    // to exercise the comparison path. The candidate names a different real row.
    var key: [53]u8 = undefined;
    key[0] = 'K';
    key[1..33].* = digest;
    key[33..53].* = try identity(1).encode();
    data.index = try data.index.put(&store, try Index.Key.init(&key), try Index.Value.init(""));
    try e.expectEqual(null, try data.findKey(e.allocator, &store, wanted[0..2]));
    data = (try data.insert(e.allocator, &store, .{ .identity = identity(2), .cells = &wanted })).data;
    try e.expectEqualDeep(identity(2), (try data.findKey(e.allocator, &store, wanted[0..2])).?);
}
test "general Table candidate allocation failures retain ownership and original roots" {
    try e.checkAllAllocationFailures(e.allocator, allocationCase, .{});
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var store: Store = .{ .allocator = allocator };
    defer store.deinit();
    const empty: Data = .{ .schema = schema };
    const candidate = try empty.insert(allocator, &store, .{ .identity = identity(1), .cells = &.{ text("tenant"), integer(1), text("payload") } });
    var owned = (try candidate.data.get(allocator, &store, identity(1))).?;
    defer owned.deinit();
    try e.expectEqualStrings("payload", owned.row().cells[2].value.atom.bytes);
    try e.expectEqual(null, empty.index.root);
}
