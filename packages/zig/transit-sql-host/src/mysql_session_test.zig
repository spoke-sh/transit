const std = @import("std");
const m = @import("transit_mysql");
const f = m.wire.fuze;
const Host = struct {
    allocator: std.mem.Allocator,
    writes: usize = 0,
    closed: usize = 0,
    outcome: m.wire.results.Outcome = .applied,
    invalid_counts: bool = false,
    value: u64 = 0,
    allocation_failed: bool = false,
    diagnostic_state: [5]u8 = "0A000".*,
    pub const Prepared = struct {
        returning: bool = false,
        pub fn parameters(self: *const Prepared) []const f.Types.Type {
            return if (self.returning) &.{} else &.{.uint64};
        }
        pub fn fields(self: *const Prepared) []const f.Types.Field {
            return if (self.returning) &.{.{ .name = "n", .type = .uint64 }} else &.{};
        }
        pub fn mutation(_: *const Prepared) bool {
            return true;
        }
        pub fn empty(_: *const Prepared) bool {
            return false;
        }
        pub fn rowCommand(_: *const Prepared) !m.wire.results.Command {
            return .select;
        }
    };
    pub const Read = struct {
        cells: [1]f.Types.Values.Cell = .{.{ .value = .{ .atom = .{ .unsigned = 17 } } }},
        pub fn validateDisclosure(_: *Read) !void {}
        pub fn nextBatch(self: *Read, _: u8) !m.wire.ReadBatch {
            var result: m.wire.ReadBatch = .{ .len = 1, .complete = true };
            result.rows[0] = &self.cells;
            return result;
        }
    };
    pub fn prepare(self: *Host, sql: []const u8) !*Prepared {
        const returning = std.mem.eql(u8, sql, "APPEND");
        if (!returning and !std.mem.eql(u8, sql, "UPDATE")) return error.UnsupportedGatewayStatement;
        const value = try self.allocator.create(Prepared);
        value.* = .{ .returning = returning };
        return value;
    }
    pub fn destroy(self: *Host, value: *Prepared) void {
        self.allocator.destroy(value);
    }
    pub fn validate(_: *Host, _: *Prepared) !void {}
    pub fn bind(_: *Host, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !void {
        if (prepared.returning) return if (values.len == 0) {} else error.InvalidWireValue;
        if (values.len != 1 or values[0] == null) return error.InvalidWireValue;
    }
    pub fn openRead(self: *Host, prepared: *Prepared, _: []const ?f.Types.Values.Atom) !*Read {
        if (!prepared.returning) return error.UnexpectedRead;
        self.writes += 1;
        const read = try self.allocator.create(Read);
        read.* = .{};
        return read;
    }
    pub fn closeRead(self: *Host, read: *Read) void {
        self.closed += 1;
        self.allocator.destroy(read);
    }
    pub fn write(self: *Host, _: *Prepared, values: []const ?f.Types.Values.Atom) !m.wire.results.CommandCompletion {
        self.writes += 1;
        self.value = @intCast(values[0].?.unsigned);
        return .{ .kind = .update, .outcome = self.outcome, .counts = .{ .matched = 1, .changed = if (self.invalid_counts) 2 else 0 }, .operation = .{ .account = @splat(7), .id = 42 }, .pending_restart = false, .diagnostic = null };
    }
    pub fn transactionStatus(_: *Host) m.wire.results.Transaction.SessionState {
        return .idle;
    }
    pub fn begin(_: *Host) !void {}
    pub fn end(_: *Host) void {}
    pub fn reset(_: *Host) !void {}
    pub fn selectDatabase(_: *Host, _: []const u8) !void {
        return error.GatewayDatabaseDenied;
    }
    pub fn diagnostic(self: *Host, err: anyerror) struct { state: [5]u8, message: []const u8, detail: ?[]const u8 } {
        if (err == error.OutOfMemory) self.allocation_failed = true;
        return .{ .state = self.diagnostic_state, .message = "Request rejected", .detail = null };
    }
};
const Transport = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    pub fn writeAll(self: *@This(), bytes: []const u8) !void {
        try self.bytes.appendSlice(self.allocator, bytes);
    }
};
const Engine = @import("WireSessionDriver.zig").Driver(m.Session, Host, Transport);
const execute_new = "\x17\x01\x00\x00\x00\x00\x01\x00\x00\x00\x00\x01\x08\x80\xff\xff\xff\xff\xff\xff\xff\xff";
const execute_again = "\x17\x01\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00";
test "row-returning MySQL mutation delivers one result and closes its reader" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try m.Session.init(t.allocator, .{}, m.Handshake.required, 1));
    defer engine.deinit();
    _ = try engine.run(.{"\x03APPEND"});
    var offset: usize = 0;
    var sequence: u8 = 1;
    while (offset < transport.bytes.items.len) : (sequence += 1) {
        const packet = (try m.Frame.decode(transport.bytes.items[offset..], sequence, m.wire.Limits.max_frame_bytes)).?;
        if (sequence == 1) try t.expectEqualSlices(u8, &.{1}, packet.payload);
        if (sequence == 4) try t.expectEqualStrings("\x0217", packet.payload);
        if (sequence == 5) try t.expectEqual(@as(u8, 0xfe), packet.payload[0]);
        offset += packet.consumed;
    }
    try t.expectEqual(@as(u8, 6), sequence);
    try t.expectEqual(@as(usize, 1), host.writes);
    try t.expectEqual(@as(usize, 1), host.closed);
}
test "OK requires a successful typed completion with valid owner counts" {
    const t = std.testing;
    for ([_]m.wire.results.Outcome{ .rejected, .cancelled, .applied }) |outcome| {
        var host: Host = .{ .allocator = t.allocator, .outcome = outcome, .invalid_counts = outcome == .applied };
        var transport: Transport = .{ .allocator = t.allocator };
        defer transport.bytes.deinit(t.allocator);
        var engine = Engine.init(&host, &transport, try m.Session.init(t.allocator, .{}, m.Handshake.required, 1));
        defer engine.deinit();
        _ = try engine.run(.{"\x16UPDATE"});
        transport.bytes.clearRetainingCapacity();
        _ = try engine.run(.{execute_new});
        const packet = (try m.Frame.decode(transport.bytes.items, 1, m.wire.Limits.max_frame_bytes)).?;
        try t.expectEqual(@as(u8, 255), packet.payload[0]);
        try t.expectEqual(@as(usize, 1), host.writes);
    }
}
test "native capacity refusal projects a MySQL resource error without execution" {
    var host: Host = .{ .allocator = std.testing.allocator, .diagnostic_state = "53000".* };
    var transport: Transport = .{ .allocator = std.testing.allocator };
    defer transport.bytes.deinit(std.testing.allocator);
    var engine = Engine.init(&host, &transport, try m.Session.init(std.testing.allocator, .{}, m.Handshake.required, 1));
    defer engine.deinit();
    _ = try engine.run(.{"\xff"});
    const packet = (try m.Frame.decode(transport.bytes.items, 1, m.wire.Limits.max_frame_bytes)).?;
    try std.testing.expectEqual(@as(u8, 255), packet.payload[0]);
    try std.testing.expectEqual(@as(u16, 1041), std.mem.readInt(u16, packet.payload[1..3], .little));
    try std.testing.expectEqualStrings("#HY000", packet.payload[3..9]);
    try std.testing.expectEqual(@as(usize, 0), host.writes);
}
test "CHECK rejection maps to the MySQL constraint error without reporting success" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator, .diagnostic_state = "23514".*, .outcome = .rejected };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try m.Session.init(t.allocator, .{}, m.Handshake.required, 1));
    defer engine.deinit();
    _ = try engine.run(.{"\x16UPDATE"});
    transport.bytes.clearRetainingCapacity();
    _ = try engine.run(.{execute_new});
    const packet = (try m.Frame.decode(transport.bytes.items, 1, m.wire.Limits.max_frame_bytes)).?;
    try t.expectEqual(@as(u8, 255), packet.payload[0]);
    try t.expectEqual(@as(u16, 3819), std.mem.readInt(u16, packet.payload[1..3], .little));
    try t.expectEqualStrings("#HY000", packet.payload[3..9]);
    try t.expectEqual(@as(usize, 1), host.writes);
}
test "MySQL commands preserve unsigned values and remembered types, with exact affected-row selection" {
    const t = std.testing;
    for ([_]bool{ false, true }) |found| {
        var host: Host = .{ .allocator = t.allocator };
        var transport: Transport = .{ .allocator = t.allocator };
        defer transport.bytes.deinit(t.allocator);
        var engine = Engine.init(&host, &transport, try m.Session.init(t.allocator, .{}, m.Handshake.required | if (found) m.Handshake.found_rows else @as(u32, 0), 1));
        defer engine.deinit();
        _ = try engine.run(.{"\x16UPDATE"});
        transport.bytes.clearRetainingCapacity();
        _ = try engine.run(.{execute_new});
        try t.expectEqual(std.math.maxInt(u64), host.value);
        const packet = (try m.Frame.decode(transport.bytes.items, 1, m.wire.Limits.max_frame_bytes)).?;
        var result: m.wire.Bytes = .{ .bytes = packet.payload };
        try t.expectEqual(@as(u8, 0), try result.byte());
        try t.expectEqual(@as(u64, @intFromBool(found)), try m.Codec.length(&result));
        _ = try engine.run(.{"\x1a\x01\x00\x00\x00"});
        _ = try engine.run(.{execute_again});
        try t.expectEqual(@as(usize, 2), host.writes);
        try t.expectEqual(@as(u64, 1), host.value);
        // Cursor/iteration violations reject before execution without destroying
        // the last valid type vector or the statement itself.
        _ = try engine.run(.{"\x17\x01\x00\x00\x00\x01\x01\x00\x00\x00"});
        try t.expectEqual(@as(usize, 2), host.writes);
        _ = try engine.run(.{execute_again});
        try t.expectEqual(@as(usize, 3), host.writes);
        _ = try engine.run(.{"\x1f"});
        _ = try engine.run(.{execute_again});
        try t.expectEqual(@as(usize, 3), host.writes);
        _ = try engine.run(.{"\x16UPDATE"});
        try t.expectEqual(@as(u32, 2), engine.session.statements[0].?.id);
        transport.bytes.clearRetainingCapacity();
        _ = try engine.run(.{"\x19\x02\x00\x00\x00"});
        _ = try engine.run(.{"\x19\x02\x00\x00\x00"});
        try t.expectEqual(@as(usize, 0), transport.bytes.items.len);
        try t.expect(!try engine.run(.{"\x01"}));
    }
}
fn allocationCycle(allocator: std.mem.Allocator) !void {
    var host: Host = .{ .allocator = allocator };
    var transport: Transport = .{ .allocator = allocator };
    defer transport.bytes.deinit(allocator);
    var engine = Engine.init(&host, &transport, try m.Session.init(allocator, .{}, m.Handshake.required, 1));
    defer engine.deinit();
    _ = try engine.run(.{"\x16UPDATE"});
    _ = try engine.run(.{execute_new});
    _ = try engine.run(.{"\x1f"});
    try std.testing.expect(host.writes <= 1);
    if (host.allocation_failed) return error.OutOfMemory;
}
test "allocation failures release prepared metadata and never replay a write" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCycle, .{});
}
