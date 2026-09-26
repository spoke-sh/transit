//! Foreign growing turns use the same native state/Table/message operations.
//! All results borrow the caller's arena; no pointer escapes the ABI response.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const a = @import("Actions.zig");
pub const Action = union(enum) {
    get: p.Value,
    put: @FieldType(a.Action, "put"),
    delete: p.Value,
    cast: @FieldType(a.Action, "cast"),
    call: struct { pid: u64, value: p.Value, deadline_ms: ?u64 = null, observer: ?u64 = null },
    reply: p.Value,
    cancel: []const u8,
    effect: p.Value,
    table_create: @FieldType(a.Action, "table_create"),
    table_get: @FieldType(a.Action, "table_get"),
    table_write: @FieldType(a.Action, "table_write"),
    table_delete: @FieldType(a.Action, "table_delete"),
    page: ?[]const u8,
    table_page: struct { id: u32, cursor: ?[]const u8 = null, version: ?p.Growth.ReadVersionId = null },
    retain: void,
    release: p.Growth.ReadVersionId,
    version_get: struct { id: p.Growth.ReadVersionId, key: p.Value },
    version_page: struct { id: p.Growth.ReadVersionId, cursor: ?[]const u8 = null },
};
pub const Result = union(enum) {
    none,
    value: ?p.Value,
    correlation: []const u8,
    row: ?a.Row,
    page: struct { entries: [p.Growth.page_size]?p.Growth.Entry, next: ?[]const u8 },
    rows: struct { basis: s.fuze.model.Basis, rows: [p.Growth.page_size]?a.Row, next: ?[]const u8 },
    version: p.Growth.ReadVersionId,
};
const Cursor = struct { source: @FieldType(s.Table.Cursor, "source"), resource: u64, revision: u64, after: p.Value };

fn parseCursor(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    if (bytes.len == 0 or bytes.len > 2048) return error.InvalidCursor;
    const parsed = try std.json.parseFromSlice(T, allocator, bytes, .{});
    defer parsed.deinit();
    const canonical = try std.json.Stringify.valueAlloc(allocator, parsed.value, .{});
    if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidCursor;
    return parsed.value;
}
fn page(allocator: std.mem.Allocator, source: anytype, encoded: ?[]const u8) !Result {
    const version = @TypeOf(source.view.id) == p.Growth.ReadVersionId;
    const identity: @FieldType(Cursor, "source") = if (version) .{ .version = source.view.id } else .{ .view = source.view.id };
    const cursor = if (encoded) |bytes| try parseCursor(Cursor, allocator, bytes) else null;
    if (cursor) |saved| if (!std.meta.eql(saved.source, identity) or saved.resource != source.view.resource or saved.revision != source.view.revision) return error.StaleStateCursor;
    const batch = try source.page(if (cursor) |saved| saved.after else null);
    return .{ .page = .{ .entries = batch.entries, .next = if (batch.next) |after| try std.json.Stringify.valueAlloc(allocator, Cursor{ .source = identity, .resource = source.view.resource, .revision = source.view.revision, .after = after }, .{}) else null } };
}
fn tablePage(allocator: std.mem.Allocator, source: anytype, id: u32, encoded: ?[]const u8) !Result {
    const table = try s.Table.open(source, id);
    const cursor = if (encoded) |bytes| try parseCursor(s.Table.Cursor, allocator, bytes) else null;
    const batch = try table.page(source, cursor);
    var rows: [p.Growth.page_size]?a.Row = @splat(null);
    for (rows[0..batch.len], batch.rows[0..batch.len]) |*out, row| out.* = .{ .key = try a.decimal(allocator, row.key), .value = try a.foreignCell(allocator, row.value) };
    return .{ .rows = .{ .basis = batch.basis, .rows = rows, .next = if (batch.next) |next| try std.json.Stringify.valueAlloc(allocator, next, .{}) else null } };
}
pub fn apply(allocator: std.mem.Allocator, turn: *s.GrowingTurn, action: Action) !Result {
    if (try a.basic(Result, allocator, turn, action)) |result| return result;
    switch (action) {
        .page => |cursor| return page(allocator, turn, cursor),
        .table_page => |request| {
            if (request.version) |id| {
                var source = try turn.openVersion(id);
                return tablePage(allocator, &source, request.id, request.cursor);
            }
            return tablePage(allocator, turn, request.id, request.cursor);
        },
        .retain => return .{ .version = try turn.retain() },
        .release => |id| try turn.release(id),
        .version_get => |request| {
            var source = try turn.openVersion(request.id);
            return .{ .value = try source.read(request.key) };
        },
        .version_page => |request| {
            var source = try turn.openVersion(request.id);
            return page(allocator, &source, request.cursor);
        },
        else => unreachable,
    }
    try turn.validate();
    return .none;
}
