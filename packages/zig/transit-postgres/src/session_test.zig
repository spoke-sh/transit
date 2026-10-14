const std = @import("std");
const pg = @import("root.zig");
const g = pg.gateway;
const f = g.fuze;
const Host = struct {
    allocator: std.mem.Allocator,
    writes: usize = 0,
    snapshots: usize = 0,
    closed: usize = 0,
    data: [2]i64 = .{ 1, 2 },
    denied: bool = false,
    pub const Prepared = struct {
        write: bool,
        pub fn parameters(_: *const Prepared) []const f.Types.Type {
            return &.{};
        }
        pub fn fields(self: *const Prepared) []const f.Types.Field {
            return if (self.write) &.{} else &.{.{ .name = "n", .type = .int64, .nullable = false }};
        }
        pub fn mutation(self: *const Prepared) bool {
            return self.write;
        }
        pub fn empty(_: *const Prepared) bool {
            return false;
        }
    };
    pub const Read = struct {
        host: *Host,
        data: [2]i64,
        cursor: usize = 0,
        cells: [1]f.Types.Values.Cell = undefined,
        pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
            if (self.host.denied) return error.CatalogDenied;
            if (self.cursor == self.data.len) return null;
            self.cells[0] = .{ .value = .{ .atom = .{ .signed = self.data[self.cursor] } } };
            self.cursor += 1;
            return &self.cells;
        }
    };
    pub fn prepare(self: *Host, sql: []const u8) !*Prepared {
        if (!std.mem.eql(u8, sql, "READ") and !std.mem.eql(u8, sql, "WRITE")) return error.UnsupportedGatewayStatement;
        const value = try self.allocator.create(Prepared);
        value.* = .{ .write = std.mem.eql(u8, sql, "WRITE") };
        return value;
    }
    pub fn destroy(self: *Host, value: *Prepared) void {
        self.allocator.destroy(value);
    }
    pub fn validate(self: *Host, _: *Prepared) !void {
        if (self.denied) return error.CatalogDenied;
    }
    pub fn bind(_: *Host, _: *Prepared, values: []const ?f.Types.Values.Atom) !void {
        if (values.len != 0) return error.WireParameterCountMismatch;
    }
    pub fn openRead(self: *Host, _: *Prepared, _: []const ?f.Types.Values.Atom) !*Read {
        self.snapshots += 1;
        const result = try self.allocator.create(Read);
        result.* = .{ .host = self, .data = self.data };
        return result;
    }
    pub fn closeRead(self: *Host, value: *Read) void {
        self.closed += 1;
        self.allocator.destroy(value);
    }
    pub fn write(self: *Host, _: *Prepared, _: []const ?f.Types.Values.Atom) !struct { kind: pg.Backend.Completion, count: u64 } {
        self.writes += 1;
        return .{ .kind = .update, .count = 1 };
    }
    pub fn begin(_: *Host) !void {}
    pub fn end(_: *Host) void {}
    pub fn diagnostic(_: *Host, _: anyerror) struct { state: [5]u8, message: []const u8, detail: ?[]const u8 } {
        return .{ .state = "0A000".*, .message = "Request rejected", .detail = null };
    }
};
const Transport = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    fail: bool = false,
    pub fn writeAll(self: *@This(), bytes: []const u8) !void {
        if (self.fail) return error.ConnectionResetByPeer;
        try self.bytes.appendSlice(self.allocator, bytes);
    }
};
const Engine = pg.Session.Engine(Host, Transport);
const bind_body = "\x00s\x00\x00\x00\x00\x00\x00\x00";
const execute_all = "\x00\x00\x00\x00\x00";
fn tags(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < bytes.len) {
        const frame = (try pg.Frame.decode(bytes[offset..], g.Limits.max_frame_bytes)).?;
        try out.append(allocator, frame.tag);
        offset += frame.consumed;
    }
    return out.toOwnedSlice(allocator);
}
test "live command engine dispatches a write only after one valid Sync and recovers from failure" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = try Engine.init(t.allocator, &host, &transport, .{});
    defer engine.deinit();
    _ = try engine.handle('P', "s\x00WRITE\x00\x00\x00");
    _ = try engine.handle('S', "");
    for ("HEPBQCD") |forbidden| {
        _ = try engine.handle('B', bind_body);
        _ = try engine.handle('E', execute_all);
        try t.expectEqual(@as(usize, 0), host.writes);
        _ = try engine.handle(forbidden, if (forbidden == 'E') execute_all else if (forbidden == 'Q') "WRITE\x00" else "");
        _ = try engine.handle('S', "");
        try t.expectEqual(@as(usize, 0), host.writes);
    }
    _ = try engine.handle('B', bind_body);
    _ = try engine.handle('E', execute_all);
    _ = try engine.handle('S', "invalid");
    try t.expectEqual(@as(usize, 0), host.writes);
    try t.expectEqual(.failed, engine.cycle.state);
    _ = try engine.handle('S', "");
    _ = try engine.handle('B', bind_body);
    _ = try engine.handle('E', execute_all);
    _ = try engine.handle('S', "");
    try t.expectEqual(@as(usize, 1), host.writes);
    try t.expect(engine.portals[0] == null);
    _ = try engine.handle('E', execute_all);
    _ = try engine.handle('S', "");
    try t.expectEqual(@as(usize, 1), host.writes);
}
test "suspended portals retain one cut, Sync closes them, and cached metadata rechecks authority" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = try Engine.init(t.allocator, &host, &transport, .{});
    defer engine.deinit();
    _ = try engine.handle('P', "s\x00READ\x00\x00\x00");
    _ = try engine.handle('B', bind_body);
    _ = try engine.handle('D', "P\x00");
    _ = try engine.handle('E', "\x00\x00\x00\x00\x01");
    host.data = .{ 100, 200 };
    _ = try engine.handle('H', "");
    _ = try engine.handle('E', execute_all);
    _ = try engine.handle('S', "");
    try t.expectEqual(@as(usize, 1), host.snapshots);
    try t.expectEqual(@as(usize, 1), host.closed);
    const observed = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(observed);
    try t.expectEqualStrings("12TDsDCZ", observed);
    try t.expect(std.mem.indexOf(u8, transport.bytes.items, "200") == null);
    host.denied = true;
    transport.bytes.clearRetainingCapacity();
    _ = try engine.handle('D', "Ss\x00");
    _ = try engine.handle('S', "");
    const denied = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(denied);
    try t.expectEqualStrings("EZ", denied);
}
test "closing a statement closes its portal and a failed socket never triggers an error-frame retry" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = try Engine.init(t.allocator, &host, &transport, .{});
    defer engine.deinit();
    _ = try engine.handle('P', "s\x00READ\x00\x00\x00");
    _ = try engine.handle('B', bind_body);
    _ = try engine.handle('E', "\x00\x00\x00\x00\x01");
    _ = try engine.handle('C', "Ss\x00");
    try t.expectEqual(@as(usize, 1), host.closed);
    try t.expect(engine.portals[0] == null);
    _ = try engine.handle('S', "");
    _ = try engine.handle('C', "Sabsent\x00");
    _ = try engine.handle('S', "");
    transport.fail = true;
    try t.expectError(error.ConnectionResetByPeer, engine.handle('Q', "WRITE\x00"));
    try t.expectEqual(@as(usize, 1), host.writes);
}
