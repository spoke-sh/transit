//! The work-item application's two reviewed layouts over general typed Tables.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const f = q.fuze;
pub const Identity = f.TableRow.Identity;
pub const Row = struct { identity: Identity, key: i64, state: i64 };
pub const limits: s.Publication.Limits = .{ .record_bytes = 4096, .staging_bytes = 32768, .staging_records = 8 };
const old_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "status", .type = .int64, .nullable = false },
};
const new_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "state", .type = .int64, .nullable = false },
};
pub fn schema(object: u32) f.TableSchema.Schema {
    return .{ .object = object, .revision = 1, .next_column = 3, .columns = if (object == 1) &old_columns else &new_columns, .primary_key = &.{1} };
}
pub fn name(object: u32) !q.catalog.TableMetadata.Name {
    var bytes: [32]u8 = undefined;
    return .init(try std.fmt.bufPrint(&bytes, "work_items_{d}", .{object}));
}
fn row(owned: f.TableRow.Owned) !Row {
    const value = owned.row();
    if (value.cells.len != 2) return error.WorkItemSourceInvalid;
    for (value.cells) |cell| if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.WorkItemSourceInvalid;
    return .{ .identity = value.identity, .key = std.math.cast(i64, value.cells[0].value.atom.signed) orelse return error.WorkItemSourceInvalid, .state = std.math.cast(i64, value.cells[1].value.atom.signed) orelse return error.WorkItemSourceInvalid };
}
pub fn get(allocator: std.mem.Allocator, source: anytype, object: u32, key: i64) !?Row {
    const head = try s.TableHead.load(source, object);
    var reader: s.TablePages.Reader(@TypeOf(source)) = .{ .pages = .{ .resource = head.resource, .object = object }, .source = source };
    const data: s.TableData = .{ .schema = schema(object), .index = head.index };
    const id = (try data.findKey(allocator, &reader, &.{.{ .value = .{ .atom = .{ .signed = key } } }})) orelse return null;
    var owned = (try data.get(allocator, &reader, id)) orelse return error.InvalidTableIndex;
    defer owned.deinit();
    return try row(owned);
}
pub fn next(allocator: std.mem.Allocator, source: anytype, object: u32, after: ?Identity) !?Row {
    const head = try s.TableHead.load(source, object);
    var reader: s.TablePages.Reader(@TypeOf(source)) = .{ .pages = .{ .resource = head.resource, .object = object }, .source = source };
    const data: s.TableData = .{ .schema = schema(object), .index = head.index };
    var owned = (try data.next(allocator, &reader, after)) orelse return null;
    defer owned.deinit();
    return try row(owned);
}
pub fn write(allocator: std.mem.Allocator, turn: *s.Turn, object: u32, principal: u64, operation: u64, value: Row, insert: bool, binding: [32]u8, reserve: u8) !s.TableWrite.Status {
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = value.key } } }, .{ .value = .{ .atom = .{ .signed = value.state } } } };
    const value_row: f.TableRow.Row = .{ .identity = value.identity, .cells = &cells };
    return s.TableWrite.stepWithReserve(allocator, turn, .{ .resource = turn.view.resource, .principal = principal, .operation = operation, .schema = schema(object), .change = if (insert) .{ .insert = value_row } else .{ .update = value_row }, .owner_binding = binding }, reserve);
}
