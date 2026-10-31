const std = @import("std");
const pg = @import("root.zig");
const s = pg.wire.Session;
const t = std.testing;
const Peer = struct {
    mutation: bool = false,
    parameter: bool = false,
    writes: usize = 0,
    reads: usize = 0,
    closes: usize = 0,
    destroys: usize = 0,
    cursor: usize = 0,
    output: [8192]u8 = undefined,
    len: usize = 0,
    fragment: usize = 1,
    cells: [2][1]pg.wire.fuze.Types.Values.Cell = .{
        .{.{ .value = .{ .atom = .{ .signed = 11 } } }},
        .{.{ .value = .{ .atom = .{ .signed = 22 } } }},
    },
    fn respond(self: *Peer, request: s.Request) !s.Result {
        return switch (request) {
            .begin, .end, .status => .{ .status = .idle },
            .prepare => .{ .prepared = .{ .handle = 1, .parameters = if (self.parameter) &.{.utf8} else &.{}, .fields = if (self.mutation) &.{} else &.{.{ .name = "n", .type = .int64, .nullable = false }}, .empty = false, .mutation = self.mutation } },
            .validate, .bind => .ok,
            .destroy => blk: {
                self.destroys += 1;
                break :blk .ok;
            },
            .open_read => blk: {
                self.reads += 1;
                self.cursor = 0;
                break :blk .{ .read = 2 };
            },
            .close_read => blk: {
                self.closes += 1;
                break :blk .ok;
            },
            .next_batch => |request_batch| blk: {
                var batch: pg.wire.ReadBatch = .{};
                while (self.cursor < self.cells.len and batch.len < request_batch.maximum) : (self.cursor += 1) {
                    batch.rows[batch.len] = &self.cells[self.cursor];
                    batch.len += 1;
                }
                batch.complete = self.cursor == self.cells.len;
                break :blk .{ .batch = batch };
            },
            .write => blk: {
                self.writes += 1;
                break :blk .{ .completion = .{ .kind = .update, .outcome = .applied, .counts = .{ .matched = 1, .changed = 1 }, .operation = .{ .account = @splat(1), .id = 7 }, .pending_restart = false, .diagnostic = null } };
            },
            .output => |output| blk: {
                const count = @min(self.fragment, output.bytes.len);
                @memcpy(self.output[self.len..][0..count], output.bytes[0..count]);
                self.len += count;
                break :blk .{ .written = count };
            },
            .diagnostic => .{ .diagnostic = .{ .state = "0A000".*, .message = "Rejected", .detail = null } },
            else => return error.UnexpectedRequest,
        };
    }
    fn drain(self: *Peer, session: *pg.Session) !bool {
        while (true) switch (try session.poll()) {
            .done => |open| return open,
            .request => |event| try session.complete(event.token, try self.respond(event.request)),
        };
    }
    fn command(self: *Peer, session: *pg.Session, tag: u8, payload: []const u8) !void {
        try session.start(tag, payload);
        try t.expect(try self.drain(session));
    }
};
test "pure sessions pause at host work and drain one immutable output byte at a time" {
    var session = try pg.Session.init(t.allocator, .{}, 41);
    defer session.deinit();
    var peer: Peer = .{};
    try session.start('Q', "READ\x00");
    const first = (try session.poll()).request;
    try t.expect(first.request == .begin);
    try t.expectError(error.WireCommandPending, session.start('Q', "READ\x00"));
    try t.expectEqual(first.token, (try session.poll()).request.token);
    try session.complete(first.token, .{ .status = .idle });
    try t.expectError(error.StaleWireCompletion, session.complete(first.token, .{ .status = .idle }));
    try t.expect(try peer.drain(&session));
    var offset: usize = 0;
    var tags: [5]u8 = undefined;
    for (&tags) |*tag| {
        const frame = (try pg.Frame.decode(peer.output[offset..peer.len], pg.wire.Limits.max_frame_bytes)).?;
        tag.* = frame.tag;
        offset += frame.consumed;
    }
    try t.expectEqualStrings("TDDCZ", &tags);
    try t.expectEqual(peer.len, offset);
    try t.expectEqual(@as(usize, 1), peer.reads);
    try t.expectEqual(@as(usize, 1), peer.closes);
}
test "a deferred write is one host event and cancellation rejects its late completion" {
    var session = try pg.Session.init(t.allocator, .{}, 7);
    defer session.deinit();
    var peer: Peer = .{ .mutation = true };
    try peer.command(&session, 'P', "s\x00WRITE\x00\x00\x00");
    try peer.command(&session, 'B', "\x00s\x00\x00\x00\x00\x00\x00\x00");
    try peer.command(&session, 'E', "\x00\x00\x00\x00\x00");
    try t.expectEqual(@as(usize, 0), peer.writes);
    try session.start('S', "");
    const pending = while (true) {
        const event = (try session.poll()).request;
        if (event.request == .write) break event;
        try session.complete(event.token, try peer.respond(event.request));
    };
    const accepted = try peer.respond(pending.request);
    try t.expectEqual(@as(usize, 1), peer.writes);
    session.abort(error.Cancelled);
    try t.expectError(error.StaleWireCompletion, session.complete(pending.token, accepted));
    try t.expectError(error.Cancelled, session.poll());
    try t.expectEqual(@as(usize, 1), peer.writes);
}
test "buffered rows carry a current disclosure guard and refusal exposes no row" {
    var session = try pg.Session.init(t.allocator, .{}, 9);
    defer session.deinit();
    var peer: Peer = .{};
    try session.start('Q', "READ\x00");
    while (true) {
        const event = (try session.poll()).request;
        if (event.request == .output and event.request.output.guard == .read) {
            try t.expectEqual(@as(u8, 'D'), event.request.output.bytes[0]);
            // The encoded row is already buffered; no bytes have been disclosed.
            try session.complete(event.token, .{ .refused = error.AccessDenied });
            break;
        }
        try session.complete(event.token, try peer.respond(event.request));
    }
    try t.expect(try peer.drain(&session));
    var offset: usize = 0;
    for ("TEZ") |tag| {
        const frame = (try pg.Frame.decode(peer.output[offset..peer.len], pg.wire.Limits.max_frame_bytes)).?;
        try t.expectEqual(tag, frame.tag);
        offset += frame.consumed;
    }
    try t.expectEqual(peer.len, offset);
    try t.expectEqual(@as(usize, 1), peer.closes);
}
test "warmed Parse Bind Execute Sync transitions reuse portal and output capacity" {
    var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
    var session = try pg.Session.init(allocator.allocator(), .{}, 1);
    defer session.deinit();
    var peer: Peer = .{ .parameter = true, .fragment = 1024 };
    try peer.command(&session, 'P', "s\x00PARAM\x00\x00\x00");
    for (0..101) |iteration| {
        peer.len = 0;
        try peer.command(&session, 'B', "\x00s\x00\x00\x00\x00\x01\x00\x00\x00\x05hello\x00\x00");
        try peer.command(&session, 'E', "\x00\x00\x00\x00\x00");
        try peer.command(&session, 'S', "");
        if (iteration == 0) {
            allocator.fail_index = allocator.alloc_index;
            allocator.resize_fail_index = allocator.resize_index;
        }
    }
    try t.expect(!allocator.has_induced_failure);
    try t.expectEqual(@as(usize, 101), peer.reads);
    try t.expectEqual(peer.reads, peer.closes);
}
