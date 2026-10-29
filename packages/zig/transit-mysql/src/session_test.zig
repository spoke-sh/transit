const std = @import("std");
const m = @import("root.zig");
const f = m.gateway.fuze;
const Host = struct {
    allocator: std.mem.Allocator,
    writes: usize = 0,
    outcome: m.gateway.results.Outcome = .applied,
    invalid_counts: bool = false,
    value: u64 = 0,
    allocation_failed: bool = false,
    diagnostic_state: [5]u8 = "0A000".*,
    pub const Prepared = struct {
        pub fn parameters(_: *const Prepared) []const f.Types.Type {
            return &.{.uint64};
        }
        pub fn fields(_: *const Prepared) []const f.Types.Field {
            return &.{};
        }
        pub fn mutation(_: *const Prepared) bool {
            return true;
        }
        pub fn empty(_: *const Prepared) bool {
            return false;
        }
    };
    pub const Read = struct {
        pub fn validateDisclosure(_: *Read) !void {}
        pub fn nextBatch(_: *Read, _: u8) !m.gateway.ReadBatch {
            return .{ .complete = true };
        }
    };
    pub fn prepare(self: *Host, sql: []const u8) !*Prepared {
        if (!std.mem.eql(u8, sql, "UPDATE")) return error.UnsupportedGatewayStatement;
        return self.allocator.create(Prepared);
    }
    pub fn destroy(self: *Host, value: *Prepared) void {
        self.allocator.destroy(value);
    }
    pub fn validate(_: *Host, _: *Prepared) !void {}
    pub fn bind(_: *Host, _: *Prepared, values: []const ?f.Types.Values.Atom) !void {
        if (values.len != 1 or values[0] == null) return error.InvalidWireValue;
    }
    pub fn openRead(_: *Host, _: *Prepared, _: []const ?f.Types.Values.Atom) !*Read {
        return error.UnexpectedRead;
    }
    pub fn closeRead(_: *Host, _: *Read) void {}
    pub fn write(self: *Host, _: *Prepared, values: []const ?f.Types.Values.Atom) !m.gateway.results.CommandCompletion {
        self.writes += 1;
        self.value = @intCast(values[0].?.unsigned);
        return .{ .kind = .update, .outcome = self.outcome, .counts = .{ .matched = 1, .changed = if (self.invalid_counts) 2 else 0 }, .operation = .{ .account = @splat(7), .id = 42 }, .pending_restart = false, .diagnostic = null };
    }
    pub fn transactionStatus(_: *Host) m.gateway.results.Transaction.SessionState {
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
const Engine = m.Session.Engine(Host, Transport);
const execute_new = "\x17\x01\x00\x00\x00\x00\x01\x00\x00\x00\x00\x01\x08\x80\xff\xff\xff\xff\xff\xff\xff\xff";
const execute_again = "\x17\x01\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00";
test "OK requires a successful typed completion with valid owner counts" {
    const t = std.testing;
    for ([_]m.gateway.results.Outcome{ .rejected, .cancelled, .applied }) |outcome| {
        var host: Host = .{ .allocator = t.allocator, .outcome = outcome, .invalid_counts = outcome == .applied };
        var transport: Transport = .{ .allocator = t.allocator };
        defer transport.bytes.deinit(t.allocator);
        var engine = try Engine.init(t.allocator, &host, &transport, .{}, m.Handshake.required);
        defer engine.deinit();
        _ = try engine.handle("\x16UPDATE");
        transport.bytes.clearRetainingCapacity();
        _ = try engine.handle(execute_new);
        const packet = (try m.Frame.decode(transport.bytes.items, 1, m.gateway.Limits.max_frame_bytes)).?;
        try t.expectEqual(@as(u8, 255), packet.payload[0]);
        try t.expectEqual(@as(usize, 1), host.writes);
    }
}
test "native capacity refusal projects a MySQL resource error without execution" {
    var host: Host = .{ .allocator = std.testing.allocator, .diagnostic_state = "53000".* };
    var transport: Transport = .{ .allocator = std.testing.allocator };
    defer transport.bytes.deinit(std.testing.allocator);
    var engine = try Engine.init(std.testing.allocator, &host, &transport, .{}, m.Handshake.required);
    defer engine.deinit();
    _ = try engine.handle("\xff");
    const packet = (try m.Frame.decode(transport.bytes.items, 1, m.gateway.Limits.max_frame_bytes)).?;
    try std.testing.expectEqual(@as(u8, 255), packet.payload[0]);
    try std.testing.expectEqual(@as(u16, 1041), std.mem.readInt(u16, packet.payload[1..3], .little));
    try std.testing.expectEqualStrings("#HY000", packet.payload[3..9]);
    try std.testing.expectEqual(@as(usize, 0), host.writes);
}
test "MySQL commands preserve unsigned values and remembered types, with exact affected-row selection" {
    const t = std.testing;
    for ([_]bool{ false, true }) |found| {
        var host: Host = .{ .allocator = t.allocator };
        var transport: Transport = .{ .allocator = t.allocator };
        defer transport.bytes.deinit(t.allocator);
        var engine = try Engine.init(t.allocator, &host, &transport, .{}, m.Handshake.required | if (found) m.Handshake.found_rows else @as(u32, 0));
        defer engine.deinit();
        _ = try engine.handle("\x16UPDATE");
        transport.bytes.clearRetainingCapacity();
        _ = try engine.handle(execute_new);
        try t.expectEqual(std.math.maxInt(u64), host.value);
        const packet = (try m.Frame.decode(transport.bytes.items, 1, m.gateway.Limits.max_frame_bytes)).?;
        var result: m.gateway.Bytes = .{ .bytes = packet.payload };
        try t.expectEqual(@as(u8, 0), try result.byte());
        try t.expectEqual(@as(u64, @intFromBool(found)), try m.Codec.length(&result));
        _ = try engine.handle("\x1a\x01\x00\x00\x00");
        _ = try engine.handle(execute_again);
        try t.expectEqual(@as(usize, 2), host.writes);
        try t.expectEqual(@as(u64, 1), host.value);
        // Cursor/iteration violations reject before execution without destroying
        // the last valid type vector or the statement itself.
        _ = try engine.handle("\x17\x01\x00\x00\x00\x01\x01\x00\x00\x00");
        try t.expectEqual(@as(usize, 2), host.writes);
        _ = try engine.handle(execute_again);
        try t.expectEqual(@as(usize, 3), host.writes);
        _ = try engine.handle("\x1f");
        _ = try engine.handle(execute_again);
        try t.expectEqual(@as(usize, 3), host.writes);
        _ = try engine.handle("\x16UPDATE");
        try t.expectEqual(@as(u32, 2), engine.statements[0].?.id);
        transport.bytes.clearRetainingCapacity();
        _ = try engine.handle("\x19\x02\x00\x00\x00");
        _ = try engine.handle("\x19\x02\x00\x00\x00");
        try t.expectEqual(@as(usize, 0), transport.bytes.items.len);
        try t.expect(!try engine.handle("\x01"));
    }
}
fn allocationCycle(allocator: std.mem.Allocator) !void {
    var host: Host = .{ .allocator = allocator };
    var transport: Transport = .{ .allocator = allocator };
    defer transport.bytes.deinit(allocator);
    var engine = try Engine.init(allocator, &host, &transport, .{}, m.Handshake.required);
    defer engine.deinit();
    _ = try engine.handle("\x16UPDATE");
    _ = try engine.handle(execute_new);
    _ = try engine.handle("\x1f");
    try std.testing.expect(host.writes <= 1);
    if (host.allocation_failed) return error.OutOfMemory;
}
test "allocation failures release prepared metadata and never replay a write" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCycle, .{});
}
