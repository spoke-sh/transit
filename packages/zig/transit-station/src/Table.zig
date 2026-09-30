//! Typed, fixed-schema tables share a resource and its atomic turn budget.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const m = f.model;
const Turn = @import("Turn.zig");
const Table = @This();
resource: u64,
id: u32,
schema: m.Schema,

pub fn descriptorKey(id: u32) p.Value {
    var bytes: [6]u8 = undefined;
    bytes[0..2].* = "\x00t".*;
    std.mem.writeInt(u32, bytes[2..6], id, .little);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn rowKey(id: u32, key: i64) p.Value {
    var bytes: [14]u8 = undefined;
    bytes[0..2].* = "\x00r".*;
    std.mem.writeInt(u32, bytes[2..6], id, .little);
    std.mem.writeInt(u64, bytes[6..14], @as(u64, @bitCast(key)) ^ (@as(u64, 1) << 63), .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn encodeSchema(schema: m.Schema) !p.Value {
    try schema.validate();
    var bytes: [39]u8 = @splat(0);
    bytes[0..4].* = "TBL1".*;
    bytes[4] = @backingInt(schema.value_type);
    var offset: usize = 5;
    for (schema.names) |name| {
        bytes[offset] = name.len;
        offset += 1;
        @memcpy(bytes[offset..][0..name.len], name.slice());
        offset += name.len;
    }
    return p.Value.init(bytes[0..offset]);
}
pub fn decodeSchema(value: p.Value) !m.Schema {
    try value.validate();
    if (value.len < 9 or !std.mem.eql(u8, value.data[0..4], "TBL1")) return error.InvalidTableDescriptor;
    var schema: m.Schema = .{ .names = undefined, .value_type = std.enums.fromInt(m.Type, value.data[4]) orelse return error.UnsupportedTableType };
    var offset: usize = 5;
    for (&schema.names) |*name| {
        if (offset >= value.len) return error.InvalidTableDescriptor;
        const len = value.data[offset];
        offset += 1;
        if (offset + len > value.len) return error.InvalidTableDescriptor;
        name.* = try m.Name.init(value.data[offset..][0..len]);
        offset += len;
    }
    if (offset != value.len) return error.InvalidTableDescriptor;
    try schema.validate();
    return schema;
}
pub fn create(turn: anytype, id: u32, schema: m.Schema) !Table {
    if (id == 0) return error.InvalidTableId;
    if (try turn.read(descriptorKey(id)) != null) return error.TableExists;
    try turn.write(descriptorKey(id), try encodeSchema(schema));
    return .{ .resource = turn.view.resource, .id = id, .schema = schema };
}
pub fn open(turn: anytype, id: u32) !Table {
    const descriptor = (try turn.read(descriptorKey(id))) orelse return error.TableNotFound;
    return .{ .resource = turn.view.resource, .id = id, .schema = try decodeSchema(descriptor) };
}
fn check(self: Table, turn: anytype) !void {
    if (self.resource != turn.view.resource) return error.CrossResourceTransaction;
    const current = try open(turn, self.id);
    if (!std.meta.eql(self.schema, current.schema)) return error.TableSchemaChanged;
}
pub fn get(self: Table, turn: anytype, key: i64) !?m.Row {
    try self.check(turn);
    return if (try turn.read(rowKey(self.id, key))) |value| .{ .key = key, .value = try self.decodeCell(value) } else null;
}
pub fn insert(self: Table, turn: anytype, row: m.Row) !void {
    if (try self.get(turn, row.key) != null) return error.RowExists;
    try self.upsert(turn, row);
}
pub fn update(self: Table, turn: anytype, row: m.Row) !void {
    if (try self.get(turn, row.key) == null) return error.RowNotFound;
    try self.upsert(turn, row);
}
pub fn upsert(self: Table, turn: anytype, row: m.Row) !void {
    try self.check(turn);
    try turn.write(rowKey(self.id, row.key), try self.encodeCell(row.value));
}
pub fn delete(self: Table, turn: anytype, key: i64) !void {
    try self.check(turn);
    try turn.write(rowKey(self.id, key), null);
}
fn encodeCell(self: Table, cell: m.Cell) !p.Value {
    try cell.validate(self.schema.value_type);
    var bytes: [m.max_cell_bytes + 2]u8 = @splat(0);
    bytes[0] = 1;
    bytes[1] = @intFromBool(cell != .null);
    const len: usize = switch (cell) {
        .null => 2,
        .int64 => |value| blk: {
            std.mem.writeInt(i64, bytes[2..10], value, .little);
            break :blk 10;
        },
        .boolean => |value| blk: {
            bytes[2] = @intFromBool(value);
            break :blk 3;
        },
        .utf8, .binary => |value| blk: {
            @memcpy(bytes[2..][0..value.len], value.slice());
            break :blk 2 + @as(usize, value.len);
        },
    };
    return p.Value.init(bytes[0..len]);
}
fn decodeCell(self: Table, value: p.Value) !m.Cell {
    try value.validate();
    if (value.len < 2 or value.data[0] != 1 or value.data[1] > 1) return error.InvalidTableRow;
    if (value.data[1] == 0) {
        if (value.len != 2) return error.InvalidTableRow;
        return .null;
    }
    const cell: m.Cell = switch (self.schema.value_type) {
        .int64 => blk: {
            if (value.len != 10) return error.InvalidTableRow;
            break :blk .{ .int64 = std.mem.readInt(i64, value.data[2..10], .little) };
        },
        .boolean => blk: {
            if (value.len != 3 or value.data[2] > 1) return error.InvalidTableRow;
            break :blk .{ .boolean = value.data[2] == 1 };
        },
        .utf8 => .{ .utf8 = try m.Bytes.init(value.slice()[2..]) },
        .binary => .{ .binary = try m.Bytes.init(value.slice()[2..]) },
    };
    try cell.validate(self.schema.value_type);
    return cell;
}
/// Local continuation, not a bearer capability. It cannot be reused with a
/// different view, resource, Table or schema to silently mix query versions.
pub const Cursor = struct {
    source: union(enum) { view: u64, version: p.Growth.ReadVersionId },
    resource: u64,
    revision: u64,
    table: u32,
    schema: [32]u8,
    after: i64,
};
pub const Page = struct {
    rows: [p.Growth.page_size]m.Row = undefined,
    len: u8 = 0,
    basis: m.Basis,
    next: ?Cursor = null,
};
pub fn page(self: Table, turn: anytype, cursor: ?Cursor) !Page {
    const fingerprint = try self.schema.fingerprint();
    const source: @FieldType(Cursor, "source") = if (@TypeOf(turn.view.id) == u64) .{ .view = turn.view.id } else .{ .version = turn.view.id };
    if (cursor) |previous| {
        if (!std.meta.eql(previous.source, source) or previous.resource != self.resource or
            previous.revision != turn.view.revision or previous.table != self.id or
            !std.mem.eql(u8, &previous.schema, &fingerprint)) return error.StaleTableCursor;
    }
    try self.check(turn);
    const prefix = try p.Value.init(rowKey(self.id, 0).data[0..6]);
    const batch = try turn.page(if (cursor) |previous| rowKey(self.id, previous.after) else prefix);
    var result: Page = .{ .basis = .{ .resource = self.resource, .revision = turn.view.revision, .schema = fingerprint } };
    for (batch.entries) |slot| if (slot) |entry| {
        if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return result;
        if (entry.key.len != 14) return error.InvalidTableRow;
        result.rows[result.len] = .{ .key = @bitCast(std.mem.readInt(u64, entry.key.data[6..14], .big) ^ (@as(u64, 1) << 63)), .value = try self.decodeCell(entry.value) };
        result.len += 1;
    };
    if (batch.next != null and result.len != 0) result.next = .{ .source = source, .resource = self.resource, .revision = turn.view.revision, .table = self.id, .schema = fingerprint, .after = result.rows[result.len - 1].key };
    return result;
}
pub const Change = struct { table: Table, operation: union(enum) { insert: m.Row, update: m.Row, upsert: m.Row, delete: i64 } };
pub fn atomic(turn: anytype, changes: []const Change) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    for (changes) |change| {
        try change.table.check(turn);
        switch (change.operation) {
            .insert => |row| try change.table.insert(turn, row),
            .update => |row| try change.table.update(turn, row),
            .upsert => |row| try change.table.upsert(turn, row),
            .delete => |key| try change.table.delete(turn, key),
        }
    }
    try turn.validate();
}

test "two logical tables commit privately together; rollback cross-resource and oversize batches" {
    var turn_store: @import("TestStore.zig") = .{};
    var turn = try turn_store.turn(.{});
    const schema: m.Schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("amount") }, .value_type = .int64 };
    const first = try create(&turn, 1, schema);
    const second = try create(&turn, 2, schema);
    try atomic(&turn, &.{ .{ .table = first, .operation = .{ .insert = .{ .key = 1, .value = .{ .int64 = 4 } } } }, .{ .table = second, .operation = .{ .insert = .{ .key = 1, .value = .{ .int64 = 4 } } } } });
    try std.testing.expectEqual(@as(i64, 4), (try second.get(&turn, 1)).?.value.int64);
    const before = turn.decision;
    var foreign = second;
    foreign.resource += 1;
    try std.testing.expectError(error.CrossResourceTransaction, atomic(&turn, &.{ .{ .table = first, .operation = .{ .delete = 1 } }, .{ .table = foreign, .operation = .{ .delete = 1 } } }));
    try std.testing.expect(std.meta.eql(before, turn.decision));
    try std.testing.expectError(error.MutationBudgetExceeded, atomic(&turn, &.{ .{ .table = first, .operation = .{ .delete = 1 } }, .{ .table = second, .operation = .{ .insert = .{ .key = 2, .value = .null } } } }));
    try std.testing.expect(std.meta.eql(before, turn.decision));
    try first.delete(&turn, 1);
    try std.testing.expect(try first.get(&turn, 1) == null);
    try first.insert(&turn, .{ .key = 1, .value = .null });
    try std.testing.expect((try first.get(&turn, 1)).?.value == .null);
    try std.testing.expectError(error.QueryAfterMutation, first.page(&turn, null));
}
