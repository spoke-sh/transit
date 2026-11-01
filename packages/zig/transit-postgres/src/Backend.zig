//! Bounded backend frames. Returned bytes borrow this reusable builder; write
//! them before the next call. Encoding supplies no authority or SQL completion.
const std = @import("std");
const pg = @import("root.zig");
const g = pg.wire;
const Self = @This();
allocator: std.mem.Allocator,
maximum: u32 = g.Limits.max_frame_bytes,
bytes: std.ArrayList(u8) = .empty,
scalar: std.ArrayList(u8) = .empty,
pub const Column = struct { name: []const u8, type: g.Type };
pub const Completion = g.Completion;
pub fn deinit(self: *Self) void {
    self.bytes.deinit(self.allocator);
    self.scalar.deinit(self.allocator);
    self.* = undefined;
}
fn begin(self: *Self, tag: u8) !void {
    self.bytes.clearRetainingCapacity();
    const header = try pg.Frame.header(tag, 0, self.maximum);
    try self.bytes.appendSlice(self.allocator, &header);
}
fn append(self: *Self, bytes: []const u8) !void {
    if (self.bytes.items.len == 0 or self.bytes.items.len > @as(usize, self.maximum) + 1 or bytes.len > @as(usize, self.maximum) + 1 - self.bytes.items.len) return error.FrameTooLarge;
    try self.bytes.appendSlice(self.allocator, bytes);
}
fn int(self: *Self, comptime T: type, value: T) !void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .big);
    try self.append(&bytes);
}
fn string(self: *Self, bytes: []const u8, maximum: usize) !void {
    if (bytes.len > maximum or std.mem.indexOfScalar(u8, bytes, 0) != null or !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidWireText;
    try self.append(bytes);
    try self.append(&.{0});
}
fn finish(self: *Self) []const u8 {
    std.mem.writeInt(u32, self.bytes.items[1..5], @intCast(self.bytes.items.len - 1), .big);
    return self.bytes.items;
}
pub fn empty(self: *Self, tag: enum { parse_complete, bind_complete, close_complete, no_data, empty_query, suspended }) ![]const u8 {
    try self.begin(switch (tag) {
        .parse_complete => '1',
        .bind_complete => '2',
        .close_complete => '3',
        .no_data => 'n',
        .empty_query => 'I',
        .suspended => 's',
    });
    return self.finish();
}
pub fn ready(self: *Self, state: g.results.Transaction.SessionState) ![]const u8 {
    try self.begin('Z');
    errdefer self.bytes.clearRetainingCapacity();
    try self.append(switch (state) {
        .idle => "I",
        .active => "T",
        .failed => "E",
    });
    return self.finish();
}
pub fn authenticate(self: *Self, kind: enum { mechanisms, challenge, final, ok }, data: []const u8) ![]const u8 {
    try self.begin('R');
    errdefer self.bytes.clearRetainingCapacity();
    if (data.len > 512 or ((kind == .mechanisms or kind == .ok) and data.len != 0)) return error.InvalidAuthentication;
    try self.int(u32, switch (kind) {
        .mechanisms => 10,
        .challenge => 11,
        .final => 12,
        .ok => 0,
    });
    try self.append(if (kind == .mechanisms) "SCRAM-SHA-256\x00\x00" else data);
    return self.finish();
}
pub fn parameter(self: *Self, name: []const u8, value: []const u8) ![]const u8 {
    try self.begin('S');
    errdefer self.bytes.clearRetainingCapacity();
    try self.string(name, 63);
    try self.string(value, 256);
    return self.finish();
}
pub fn key(self: *Self, session: u32, secret: u32) ![]const u8 {
    try self.begin('K');
    errdefer self.bytes.clearRetainingCapacity();
    try self.int(u32, session);
    try self.int(u32, secret);
    return self.finish();
}
pub fn negotiate(self: *Self, unsupported: []const []const u8) ![]const u8 {
    try self.begin('v');
    errdefer self.bytes.clearRetainingCapacity();
    if (unsupported.len > 16) return error.TooManyStartupOptions;
    try self.int(u32, 0); // Select minor 0, including four-byte cancel secrets.
    try self.int(u32, @intCast(unsupported.len));
    for (unsupported) |option| try self.string(option, 63);
    return self.finish();
}
pub fn parameters(self: *Self, oids: []const u32) ![]const u8 {
    try self.begin('t');
    errdefer self.bytes.clearRetainingCapacity();
    if (oids.len > g.Limits.max_parameters) return error.TooManyWireParameters;
    try self.int(u16, @intCast(oids.len));
    for (oids) |oid| try self.int(u32, oid);
    return self.finish();
}
pub fn describe(self: *Self, columns: []const Column, formats: *const pg.Frontend.Formats) ![]const u8 {
    try self.begin('T');
    errdefer self.bytes.clearRetainingCapacity();
    if (columns.len > g.Limits.max_parameters) return error.TooManyWireColumns;
    try formats.validate(columns.len);
    try self.int(u16, @intCast(columns.len));
    for (columns, 0..) |column, index| {
        const descriptor = pg.Scalar.descriptor(column.type.kind);
        try self.string(column.name, 256);
        try self.int(u32, 0); // Native Table identities are not PostgreSQL OIDs.
        try self.int(u16, 0);
        try self.int(u32, descriptor.oid);
        try self.int(i16, descriptor.size);
        try self.int(i32, descriptor.modifier);
        try self.int(u16, @backingInt(formats.at(index)));
    }
    return self.finish();
}
pub fn row(self: *Self, columns: []const Column, formats: *const pg.Frontend.Formats, cells: []const g.fuze.Types.Values.Cell) ![]const u8 {
    try self.begin('D');
    errdefer self.bytes.clearRetainingCapacity();
    if (columns.len > g.Limits.max_parameters or columns.len != cells.len) return error.WireColumnCountMismatch;
    try formats.validate(columns.len);
    try self.int(u16, @intCast(columns.len));
    for (columns, cells, 0..) |column, cell, index| {
        if (try column.type.value(cell)) |atom| {
            self.scalar.clearRetainingCapacity();
            try pg.Scalar.encode(self.allocator, &self.scalar, column.type.kind, formats.at(index), atom);
            try self.int(u32, @intCast(self.scalar.items.len));
            try self.append(self.scalar.items);
        } else try self.int(i32, -1);
    }
    return self.finish();
}
pub fn complete(self: *Self, kind: Completion, count: u64) ![]const u8 {
    try self.begin('C');
    errdefer self.bytes.clearRetainingCapacity();
    var buffer: [64]u8 = undefined;
    const value = switch (kind) {
        .create_dataflow => "CREATE DATAFLOW",
        .control_dataflow => "CONTROL DATAFLOW",
        .select => try std.fmt.bufPrint(&buffer, "SELECT {d}", .{count}),
        .insert => try std.fmt.bufPrint(&buffer, "INSERT 0 {d}", .{count}),
        .update => try std.fmt.bufPrint(&buffer, "UPDATE {d}", .{count}),
        .delete => try std.fmt.bufPrint(&buffer, "DELETE {d}", .{count}),
        .produce => try std.fmt.bufPrint(&buffer, "PRODUCE {d}", .{count}),
        .enqueue => try std.fmt.bufPrint(&buffer, "ENQUEUE {d}", .{count}),
        .consume => try std.fmt.bufPrint(&buffer, "CONSUME {d}", .{count}),
        .claim => try std.fmt.bufPrint(&buffer, "CLAIM {d}", .{count}),
        .create_table => "CREATE TABLE",
        .create_schema => "CREATE SCHEMA",
        .alter_schema => "ALTER SCHEMA",
        .drop_schema => "DROP SCHEMA",
        .alter_table => "ALTER TABLE",
        .drop_table => "DROP TABLE",
        .create_stream => "CREATE STREAM",
        .alter_stream => "ALTER STREAM",
        .drop_stream => "DROP STREAM",
        .create_queue => "CREATE QUEUE",
        .alter_queue => "ALTER QUEUE",
        .drop_queue => "DROP QUEUE",
        .set => "SET",
        .reset => "RESET",
        .show => "SHOW",
        .discard_all => "DISCARD ALL",
        .begin => "BEGIN",
        .commit => "COMMIT",
        .rollback, .rollback_to_savepoint => "ROLLBACK",
        .savepoint => "SAVEPOINT",
        .release_savepoint => "RELEASE",
        .empty, .reload, .capture, .commit_offset, .ack, .nack, .extend_lease => return error.UnsupportedWireCompletion,
    };
    try self.string(value, buffer.len);
    return self.finish();
}
/// Callers supply a classified safe message. Values, SQL and credentials do not
/// become diagnostics through this encoder. Error replies do not imply rollback.
pub fn failure(self: *Self, fatal: bool, state: [5]u8, message: []const u8, detail: ?[]const u8) ![]const u8 {
    try self.begin('E');
    errdefer self.bytes.clearRetainingCapacity();
    for (state) |byte| if (!std.ascii.isDigit(byte) and !std.ascii.isUpper(byte)) return error.InvalidSqlState;
    for ("SV") |tag| {
        try self.append(&.{tag});
        try self.string(if (fatal) "FATAL" else "ERROR", 5);
    }
    try self.append("C");
    try self.string(&state, 5);
    try self.append("M");
    try self.string(message, 512);
    if (detail) |value| {
        try self.append("D");
        try self.string(value, 512);
    }
    try self.append(&.{0});
    return self.finish();
}
test "backend frames retain NULL, numeric metadata, full counts and bounded errors" {
    const t = std.testing;
    var backend: Self = .{ .allocator = t.allocator, .maximum = 1024 };
    defer backend.deinit();
    try t.expectEqualStrings("Z\x00\x00\x00\x05I", try backend.ready(.idle));
    const formats: pg.Frontend.Formats = .{};
    const columns = [_]Column{ .{ .name = "value", .type = .{ .kind = .uint64, .nullable = false } }, .{ .name = "label", .type = .{ .kind = .utf8, .nullable = true } } };
    const data = try backend.row(&columns, &formats, &.{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } }, .null });
    try t.expectEqualStrings("D\x00\x00\x00\x22\x00\x02\x00\x00\x00\x1418446744073709551615\xff\xff\xff\xff", data);
    try t.expectEqualStrings("C\x00\x00\x00\x20UPDATE 18446744073709551615\x00", try backend.complete(.update, std.math.maxInt(u64)));
    _ = try backend.describe(&columns, &formats);
    try t.expectError(error.MissingWireValue, backend.row(columns[0..1], &formats, &.{.missing}));
    try t.expectEqual(@as(usize, 0), backend.bytes.items.len);
    try t.expectError(error.InvalidSqlState, backend.failure(false, "ab123".*, "safe", null));
    try t.expectError(error.InvalidWireText, backend.parameter("client_encoding", "UTF8\x00bad"));
    backend.maximum = 8;
    try t.expectError(error.FrameTooLarge, backend.complete(.select, 100));
    try t.expectEqual(@as(usize, 0), backend.bytes.items.len);
}
