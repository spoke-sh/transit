//! Allowlisted accepted Document metadata; no application value interpretation.
const std = @import("std");
const api = @import("root.zig");
pub const adapter = @import("transit_station_document");
pub const Detail = struct {
    document: []const u8,
    epoch: []const u8,
    type_revision: u32,
    change_format: u32 = adapter.Model.format,
    revision: []const u8,
    floor: []const u8,
    merge_window: []const u8,
    active_job: []const u8,
    retired: bool,
};
pub const Lens = struct { version: u8 = 1, source: @FieldType(api.Lens, "source"), declaration: Detail };
pub const Response = struct {
    version: u8 = 1,
    source: @FieldType(api.Lens, "source"),
    declaration: Detail,
    // Counts cover only this page of retained registers, including detached ones.
    registers: ?struct { count: u8, conflicts: u8, assignments: u8, next: ?[]const u8 },
};
fn decimal(gpa: std.mem.Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(gpa, "{d}", .{value});
}
pub fn project(gpa: std.mem.Allocator, head: adapter.Service.Head) !Detail {
    return .{ .document = try decimal(gpa, head.state.document), .epoch = try decimal(gpa, head.state.epoch), .type_revision = head.state.type_revision, .revision = try decimal(gpa, head.state.revision), .floor = try decimal(gpa, head.floor), .merge_window = try decimal(gpa, head.merge_window), .active_job = try decimal(gpa, head.active_job), .retired = head.retired };
}
pub fn decode(gpa: std.mem.Allocator, key: api.protocol.Value, value: api.protocol.Value) !?Detail {
    const bytes = key.slice();
    if (bytes.len != 19 or !std.mem.eql(u8, bytes[0..2], "\x00D") or bytes[10] != 'h' or std.mem.readInt(u64, bytes[11..19], .big) != 0) return null;
    const head = adapter.Service.Head.decode(value) catch return null;
    if (head.state.document != std.mem.readInt(u64, bytes[2..10], .big)) return null;
    return try project(gpa, head);
}
test "Document lens rejects mismatched or unknown records and hides index contents" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const service: adapter.Service = .{ .resource = 3, .document = std.math.maxInt(u64) };
    const head: adapter.Service.Head = .{ .state = .{ .document = service.document, .epoch = 1, .type_revision = 2, .revision = 4 }, .floor = 3 };
    const value = try head.encode();
    const detail = (try decode(arena.allocator(), service.key('h', 0), value)).?;
    try t.expectEqualStrings("18446744073709551615", detail.document);
    try t.expectEqualStrings("3", detail.floor);
    try t.expectEqual(null, try decode(arena.allocator(), service.key('h', 1), value));
    try t.expectEqual(null, try decode(arena.allocator(), service.key('j', 0), value));
    try t.expectEqual(null, try decode(arena.allocator(), service.key('h', 0), try api.protocol.Value.init("unknown")));
    const other: adapter.Service = .{ .resource = 3, .document = 7 };
    try t.expectEqual(null, try decode(arena.allocator(), other.key('h', 0), value));
    const json = try std.json.Stringify.valueAlloc(arena.allocator(), detail, .{});
    try t.expect(std.mem.indexOf(u8, json, "index") == null);
}
