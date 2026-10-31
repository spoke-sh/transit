const std = @import("std");
const pg = @import("transit_postgres");
const g = pg.wire;
const f = g.fuze;
const Host = struct {
    allocator: std.mem.Allocator,
    writes: usize = 0,
    outcome: g.results.Outcome = .applied,
    invalid_counts: bool = false,
    snapshots: usize = 0,
    closed: usize = 0,
    data: [2]i64 = .{ 1, 2 },
    denied: bool = false,
    allocation_failed: bool = false,
    pulled: usize = 0,
    deny_after_pull: bool = false,
    invalid_batch: bool = false,
    cache_disclosure: bool = false,
    completion_checks: usize = 0,
    forbid_postwrite_validation: bool = false,
    pub const Prepared = struct {
        write: bool,
        parameter: bool = false,
        pub fn parameters(self: *const Prepared) []const f.Types.Type {
            return if (self.parameter) &.{.utf8} else &.{};
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
        cached_disclosure: bool = false,
        cells: [g.ReadBatch.max_rows][1]f.Types.Values.Cell = undefined,
        pub fn validateDisclosure(self: *Read) !void {
            if (self.cached_disclosure) {
                self.cached_disclosure = false;
                return;
            }
            if (self.host.denied) return error.CatalogDenied;
        }
        pub fn resumeWire(self: *Read) void {
            self.cached_disclosure = false;
        }
        pub fn nextBatch(self: *Read, maximum: u8) !g.ReadBatch {
            if (self.host.denied) return error.CatalogDenied;
            if (self.host.invalid_batch) return .{};
            var batch: g.ReadBatch = .{};
            while (batch.len < maximum and self.cursor < self.data.len) : (self.cursor += 1) {
                self.cells[batch.len][0] = .{ .value = .{ .atom = .{ .signed = self.data[self.cursor] } } };
                batch.rows[batch.len] = &self.cells[batch.len];
                batch.len += 1;
                self.host.pulled += 1;
            }
            batch.complete = self.cursor == self.data.len;
            if (self.host.deny_after_pull) self.host.denied = true;
            self.cached_disclosure = self.host.cache_disclosure;
            return batch;
        }
    };
    pub fn prepare(self: *Host, sql: []const u8) !*Prepared {
        if (!std.mem.eql(u8, sql, "READ") and !std.mem.eql(u8, sql, "WRITE") and !std.mem.eql(u8, sql, "PARAM")) return error.UnsupportedGatewayStatement;
        const value = try self.allocator.create(Prepared);
        value.* = .{ .write = std.mem.eql(u8, sql, "WRITE"), .parameter = std.mem.eql(u8, sql, "PARAM") };
        return value;
    }
    pub fn destroy(self: *Host, value: *Prepared) void {
        self.allocator.destroy(value);
    }
    pub fn validate(self: *Host, _: *Prepared) !void {
        if (self.denied) return error.CatalogDenied;
        if (self.forbid_postwrite_validation and self.writes != 0) return error.ExecutionNoLongerValid;
    }
    pub fn validateWireCompletion(self: *Host, _: *Prepared, completion: g.results.CommandCompletion) !void {
        if (self.denied) return error.CatalogDenied;
        try std.testing.expectEqual(@as(u64, 42), completion.operation.?.id);
        self.completion_checks += 1;
    }
    pub fn bind(_: *Host, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !void {
        if (values.len != @intFromBool(prepared.parameter)) return error.WireParameterCountMismatch;
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
    pub fn write(self: *Host, _: *Prepared, _: []const ?f.Types.Values.Atom) !g.results.CommandCompletion {
        self.writes += 1;
        return .{ .kind = .update, .outcome = self.outcome, .counts = .{ .matched = 1, .changed = if (self.invalid_counts) 2 else 0 }, .operation = .{ .account = @splat(7), .id = 42 }, .pending_restart = false, .diagnostic = null };
    }
    pub fn transactionStatus(_: *Host) g.results.Transaction.SessionState {
        return .idle;
    }
    pub fn begin(_: *Host) !void {}
    pub fn end(_: *Host) void {}
    pub fn diagnostic(self: *Host, err: anyerror) struct { state: [5]u8, message: []const u8, detail: ?[]const u8 } {
        if (err == error.OutOfMemory) self.allocation_failed = true;
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
const Engine = @import("WireSessionDriver.zig").Driver(pg.Session, Host, Transport);
const bind_body = "\x00s\x00\x00\x00\x00\x00\x00\x00";
const execute_all = "\x00\x00\x00\x00\x00";
test "command frames require a successful typed completion with valid owner counts" {
    const t = std.testing;
    for ([_]g.results.Outcome{ .applied, .unchanged, .rejected, .cancelled }) |outcome| {
        for ([_]bool{ false, true }) |invalid| {
            var host: Host = .{ .allocator = t.allocator, .outcome = outcome, .invalid_counts = invalid };
            var transport: Transport = .{ .allocator = t.allocator };
            defer transport.bytes.deinit(t.allocator);
            var engine = Engine.init(&host, &transport, try pg.Session.init(t.allocator, .{}, 1));
            defer engine.deinit();
            _ = try engine.run(.{ 'Q', "WRITE\x00" });
            const observed = try tags(t.allocator, transport.bytes.items);
            defer t.allocator.free(observed);
            const success = !invalid and (outcome == .applied or outcome == .unchanged);
            try t.expectEqualStrings(if (success) "CZ" else "EZ", observed);
            if (success) try t.expect(std.mem.indexOf(u8, transport.bytes.items, "UPDATE 1\x00") != null);
            try t.expectEqual(@as(usize, 1), host.writes);
        }
    }
}
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
fn allocationCycle(allocator: std.mem.Allocator) !void {
    var host: Host = .{ .allocator = allocator };
    var transport: Transport = .{ .allocator = allocator };
    defer transport.bytes.deinit(allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(allocator, .{}, 1));
    defer engine.deinit();
    _ = try engine.run(.{ 'P', "s\x00PARAM\x00\x00\x00" });
    _ = try engine.run(.{ 'B', "\x00s\x00\x00\x00\x00\x01\x00\x00\x00\x05hello\x00\x00" });
    _ = try engine.run(.{ 'E', "\x00\x00\x00\x00\x01" });
    _ = try engine.run(.{ 'S', "" });
    // Protocol errors deliberately translate OOM; tell the allocator checker
    // that the induced failure was observed after releasing session resources.
    if (host.allocation_failed) return error.OutOfMemory;
}
test "every allocation failure releases copied binds, prepared statements and suspended reads" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCycle, .{});
}
test "live command engine dispatches a write only after one valid Sync and recovers from failure" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(t.allocator, .{}, 1));
    defer engine.deinit();
    _ = try engine.run(.{ 'P', "s\x00WRITE\x00\x00\x00" });
    _ = try engine.run(.{ 'S', "" });
    for ("HEPBQCD") |forbidden| {
        _ = try engine.run(.{ 'B', bind_body });
        _ = try engine.run(.{ 'E', execute_all });
        try t.expectEqual(@as(usize, 0), host.writes);
        _ = try engine.run(.{ forbidden, if (forbidden == 'E') execute_all else if (forbidden == 'Q') "WRITE\x00" else "" });
        _ = try engine.run(.{ 'S', "" });
        try t.expectEqual(@as(usize, 0), host.writes);
    }
    _ = try engine.run(.{ 'B', bind_body });
    _ = try engine.run(.{ 'E', execute_all });
    _ = try engine.run(.{ 'S', "invalid" });
    try t.expectEqual(@as(usize, 0), host.writes);
    try t.expectEqual(.failed, engine.session.cycle.state);
    _ = try engine.run(.{ 'S', "" });
    _ = try engine.run(.{ 'B', bind_body });
    _ = try engine.run(.{ 'E', execute_all });
    _ = try engine.run(.{ 'S', "" });
    try t.expectEqual(@as(usize, 1), host.writes);
    try t.expect(engine.session.portals[0] == null);
    _ = try engine.run(.{ 'E', execute_all });
    _ = try engine.run(.{ 'S', "" });
    try t.expectEqual(@as(usize, 1), host.writes);
}
test "suspended portals retain one cut, Sync closes them, and cached metadata rechecks authority" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(t.allocator, .{}, 1));
    defer engine.deinit();
    _ = try engine.run(.{ 'P', "s\x00READ\x00\x00\x00" });
    _ = try engine.run(.{ 'B', bind_body });
    _ = try engine.run(.{ 'D', "P\x00" });
    _ = try engine.run(.{ 'E', "\x00\x00\x00\x00\x01" });
    host.data = .{ 100, 200 };
    _ = try engine.run(.{ 'H', "" });
    _ = try engine.run(.{ 'E', execute_all });
    _ = try engine.run(.{ 'S', "" });
    try t.expectEqual(@as(usize, 1), host.snapshots);
    try t.expectEqual(@as(usize, 1), host.closed);
    const observed = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(observed);
    try t.expectEqualStrings("12TDsDCZ", observed);
    try t.expect(std.mem.indexOf(u8, transport.bytes.items, "200") == null);
    host.denied = true;
    transport.bytes.clearRetainingCapacity();
    _ = try engine.run(.{ 'D', "Ss\x00" });
    _ = try engine.run(.{ 'S', "" });
    const denied = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(denied);
    try t.expectEqualStrings("EZ", denied);
}
test "closing a statement closes its portal and a failed socket never triggers an error-frame retry" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(t.allocator, .{}, 1));
    defer engine.deinit();
    _ = try engine.run(.{ 'P', "s\x00READ\x00\x00\x00" });
    _ = try engine.run(.{ 'B', bind_body });
    _ = try engine.run(.{ 'E', "\x00\x00\x00\x00\x01" });
    _ = try engine.run(.{ 'C', "Ss\x00" });
    try t.expectEqual(@as(usize, 1), host.closed);
    try t.expect(engine.session.portals[0] == null);
    _ = try engine.run(.{ 'S', "" });
    _ = try engine.run(.{ 'C', "Sabsent\x00" });
    _ = try engine.run(.{ 'S', "" });
    transport.fail = true;
    try t.expectError(error.ConnectionResetByPeer, engine.run(.{ 'Q', "WRITE\x00" }));
    try t.expectEqual(@as(usize, 1), host.writes);
}

test "disclosure batches stop at Execute boundaries and recheck after buffering" {
    const t = std.testing;
    var host: Host = .{ .allocator = t.allocator };
    var transport: Transport = .{ .allocator = t.allocator };
    defer transport.bytes.deinit(t.allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(t.allocator, .{}, 1));
    defer engine.deinit();
    _ = try engine.run(.{ 'P', "s\x00READ\x00\x00\x00" });
    _ = try engine.run(.{ 'B', bind_body });
    _ = try engine.run(.{ 'E', "\x00\x00\x00\x00\x01" });
    try t.expectEqual(@as(usize, 1), host.pulled);
    transport.bytes.clearRetainingCapacity();
    host.denied = true;
    _ = try engine.run(.{ 'E', execute_all });
    const revoked = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(revoked);
    try t.expectEqualStrings("E", revoked);
    try t.expectEqual(@as(usize, 1), host.pulled);
    _ = try engine.run(.{ 'S', "" });
    host.denied = false;
    host.deny_after_pull = true;
    _ = try engine.run(.{ 'B', bind_body });
    transport.bytes.clearRetainingCapacity();
    _ = try engine.run(.{ 'E', execute_all });
    const buffered = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(buffered);
    try t.expectEqualStrings("E", buffered);
    try t.expectEqual(@as(usize, 3), host.pulled);
    _ = try engine.run(.{ 'S', "" });
    host.denied = false;
    host.deny_after_pull = false;
    host.invalid_batch = true;
    _ = try engine.run(.{ 'B', bind_body });
    transport.bytes.clearRetainingCapacity();
    _ = try engine.run(.{ 'E', execute_all });
    const malformed = try tags(t.allocator, transport.bytes.items);
    defer t.allocator.free(malformed);
    try t.expectEqualStrings("E", malformed);
}

test "scheduled output invalidates cached disclosure before both first and later rows" {
    for (0..2) |before_row| {
        var host: Host = .{ .allocator = std.testing.allocator, .cache_disclosure = true };
        var transport: Transport = .{ .allocator = std.testing.allocator };
        defer transport.bytes.deinit(std.testing.allocator);
        var engine = Engine.init(&host, &transport, try pg.Session.init(std.testing.allocator, .{}, 19));
        defer engine.deinit();
        try engine.session.start('Q', "READ\x00");
        var row: usize = 0;
        while (true) switch (try engine.session.poll()) {
            .done => break,
            .request => |event| {
                if (event.request == .output and event.request.output.bytes[0] == 'D') {
                    if (row == before_row) host.denied = true;
                    row += 1;
                }
                const result = engine.perform(event.request) catch |err| g.Session.Result{ .failed = err };
                try engine.session.complete(event.token, result);
            },
        };
        const observed = try tags(std.testing.allocator, transport.bytes.items);
        defer std.testing.allocator.free(observed);
        try std.testing.expectEqualStrings(if (before_row == 0) "TEZ" else "TDEZ", observed);
        try std.testing.expectEqual(@as(usize, 1), host.closed);
    }
}

test "a resumed successful mutation verifies its original outcome without re-execution" {
    var host: Host = .{ .allocator = std.testing.allocator, .forbid_postwrite_validation = true };
    var transport: Transport = .{ .allocator = std.testing.allocator };
    defer transport.bytes.deinit(std.testing.allocator);
    var engine = Engine.init(&host, &transport, try pg.Session.init(std.testing.allocator, .{}, 29));
    defer engine.deinit();
    try engine.session.start('Q', "WRITE\x00");
    while (true) switch (try engine.session.poll()) {
        .done => break,
        .request => |event| {
            const result = engine.perform(event.request) catch |err| g.Session.Result{ .failed = err };
            try engine.session.complete(event.token, result);
        },
    };
    const observed = try tags(std.testing.allocator, transport.bytes.items);
    defer std.testing.allocator.free(observed);
    try std.testing.expectEqualStrings("CZ", observed);
    try std.testing.expectEqual(@as(usize, 1), host.writes);
    try std.testing.expectEqual(@as(usize, 1), host.completion_checks);
}
