const std = @import("std");
const m = @import("root.zig");
const s = m.wire.Session;
const t = std.testing;
const Peer = struct {
    mutation: bool = false,
    cursor: usize = 0,
    pulls: usize = 0,
    writes: usize = 0,
    closes: usize = 0,
    destroys: usize = 0,
    fragment: usize = 1,
    bytes: [16384]u8 = undefined,
    len: usize = 0,
    cells: [32][1]m.wire.fuze.Types.Values.Cell = undefined,
    fn respond(self: *Peer, request: s.Request) !s.Result {
        return switch (request) {
            .begin, .end, .status => .{ .status = .idle },
            .prepare => .{ .prepared = .{ .handle = 1, .parameters = &.{}, .fields = if (self.mutation) &.{} else &.{.{ .name = "n", .type = .uint64, .nullable = false }}, .mutation = self.mutation, .empty = false } },
            .validate, .bind => .ok,
            .destroy => blk: {
                self.destroys += 1;
                break :blk .ok;
            },
            .open_read => blk: {
                self.cursor = 0;
                break :blk .{ .read = 2 };
            },
            .close_read => blk: {
                self.closes += 1;
                break :blk .ok;
            },
            .next_batch => |input| blk: {
                self.pulls += 1;
                var batch: m.wire.ReadBatch = .{};
                while (self.cursor < 33 and batch.len < input.maximum) : (self.cursor += 1) {
                    self.cells[batch.len][0] = .{ .value = .{ .atom = .{ .unsigned = self.cursor } } };
                    batch.rows[batch.len] = &self.cells[batch.len];
                    batch.len += 1;
                }
                batch.complete = self.cursor == 33;
                break :blk .{ .batch = batch };
            },
            .write => blk: {
                self.writes += 1;
                break :blk .{ .completion = .{ .kind = .update, .outcome = .applied, .counts = .{ .matched = 3, .changed = 1 }, .operation = .{ .account = @splat(1), .id = 8 }, .pending_restart = false, .diagnostic = null } };
            },
            .output => |output| blk: {
                const count = @min(output.bytes.len, self.fragment);
                @memcpy(self.bytes[self.len..][0..count], output.bytes[0..count]);
                self.len += count;
                break :blk .{ .written = count };
            },
            .diagnostic => .{ .diagnostic = .{ .state = "42501".*, .message = "Denied", .detail = null } },
            else => return error.UnexpectedRequest,
        };
    }
    fn drain(self: *Peer, session: *m.Session) !void {
        while (true) switch (try session.poll()) {
            .done => |open| {
                try t.expect(open);
                return;
            },
            .request => |event| try session.complete(event.token, try self.respond(event.request)),
        };
    }
};
test "partial packet drains preserve sequence and every row across bounded pulls" {
    for ([_]bool{ false, true }) |deprecated| {
        var session = try m.Session.init(t.allocator, .{}, m.Handshake.required | if (deprecated) m.Handshake.deprecate_eof else @as(u32, 0), 5);
        defer session.deinit();
        var peer: Peer = .{};
        try session.start("\x03SELECT n");
        try peer.drain(&session);
        var offset: usize = 0;
        var sequence: u8 = 1;
        const metadata_packets: usize = if (deprecated) 2 else 3;
        for (0..metadata_packets + 34) |packet_index| {
            const packet = (try m.Frame.decode(peer.bytes[offset..peer.len], sequence, m.wire.Limits.max_frame_bytes)).?;
            if (packet_index >= metadata_packets and packet_index < metadata_packets + 33) {
                var reader: m.wire.Bytes = .{ .bytes = packet.payload };
                const size = try m.Codec.length(&reader);
                const number = try reader.take(@intCast(size));
                try t.expectEqual(packet_index - metadata_packets, try std.fmt.parseInt(usize, number, 10));
                try t.expectEqual(packet.payload.len, reader.offset);
            }
            offset += packet.consumed;
            sequence +%= 1;
        }
        try t.expectEqual(peer.len, offset);
        try t.expectEqual(@as(usize, 2), peer.pulls);
        try t.expectEqual(@as(usize, 1), peer.closes);
        try t.expectEqual(@as(usize, 1), peer.destroys);
    }
}
test "partial OK failure closes without replaying the accepted write or emitting ERR" {
    var session = try m.Session.init(t.allocator, .{}, m.Handshake.required, 7);
    defer session.deinit();
    var peer: Peer = .{ .mutation = true };
    try session.start("\x03UPDATE n");
    const output = while (true) {
        const event = (try session.poll()).request;
        if (event.request == .output) break event;
        try session.complete(event.token, try peer.respond(event.request));
    };
    try t.expectEqual(@as(usize, 1), peer.writes);
    try t.expect(output.request.output.guard == .completion);
    try session.complete(output.token, .{ .written = 2 });
    try t.expectError(error.StaleWireCompletion, session.complete(output.token, .{ .written = 2 }));
    const rest = (try session.poll()).request;
    try session.complete(rest.token, .{ .failed = error.BrokenPipe });
    try t.expectError(error.BrokenPipe, session.poll());
    try t.expectEqual(@as(usize, 1), peer.writes);
}
test "warmed query events and packet encoding require no backing allocations" {
    var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
    var session = try m.Session.init(allocator.allocator(), .{}, m.Handshake.required, 1);
    defer session.deinit();
    var peer: Peer = .{ .fragment = 1024 };
    for (0..101) |iteration| {
        peer.len = 0;
        try session.start("\x03SELECT n");
        try peer.drain(&session);
        if (iteration == 0) {
            allocator.fail_index = allocator.alloc_index;
            allocator.resize_fail_index = allocator.resize_index;
        }
    }
    try t.expect(!allocator.has_induced_failure);
    try t.expectEqual(@as(usize, 202), peer.pulls);
    try t.expectEqual(@as(usize, 101), peer.closes);
}

test "refused metadata row and terminal output retain the next packet sequence" {
    // Refuse the initial metadata packet, a buffered row, or the final
    // completion boundary. No refused bytes may escape or skip a sequence.
    for ([_]usize{ 0, 3, 36 }) |refused_index| {
        var session = try m.Session.init(t.allocator, .{}, m.Handshake.required, 9);
        defer session.deinit();
        var peer: Peer = .{ .fragment = 16384 };
        try session.start("\x03SELECT n");
        var output_index: usize = 0;
        var refused = false;
        while (true) switch (try session.poll()) {
            .done => break,
            .request => |event| {
                if (event.request == .output) {
                    if (output_index == refused_index) {
                        try t.expect(event.request.output.guard != .none);
                        try session.complete(event.token, .{ .refused = error.AccessDenied });
                        refused = true;
                        output_index += 1;
                        continue;
                    }
                    output_index += 1;
                }
                try session.complete(event.token, try peer.respond(event.request));
            },
        };
        try t.expect(refused);
        var offset: usize = 0;
        var sequence: u8 = 1;
        var last: []const u8 = "";
        while (offset < peer.len) {
            const packet = (try m.Frame.decode(peer.bytes[offset..peer.len], sequence, m.wire.Limits.max_frame_bytes)).?;
            last = packet.payload;
            offset += packet.consumed;
            sequence +%= 1;
        }
        try t.expectEqual(@as(u8, 0xff), last[0]);
        try t.expectEqual(@as(usize, 1), peer.closes);
        try t.expectEqual(@as(usize, 1), peer.destroys);
    }
}
