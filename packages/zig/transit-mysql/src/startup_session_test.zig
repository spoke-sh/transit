const std = @import("std");
const m = @import("root.zig");
const w = m.wire.Startup;
const t = std.testing;
const Peer = struct {
    input: []const u8,
    cursor: usize = 0,
    split: usize = 0,
    output: [4096]u8 = undefined,
    len: usize = 0,
    method: w.Method = .trust,
    fail: ?std.meta.Tag(w.Request) = null,
    upgrades: usize = 0,
    admits: usize = 0,
    passwords: usize = 0,
    fn respond(self: *Peer, request: w.Request) !w.Result {
        if (self.fail) |tag| if (std.meta.activeTag(request) == tag) return .{ .failed = error.AccessDenied };
        return switch (request) {
            .input => |bytes| blk: {
                const end = if (self.cursor < self.split) self.split else self.input.len;
                const count = @min(bytes.len, end - self.cursor);
                if (count == 0) break :blk .{ .failed = error.EndOfStream };
                @memcpy(bytes[0..count], self.input[self.cursor..][0..count]);
                self.cursor += count;
                break :blk .{ .received = count };
            },
            .output => |bytes| blk: {
                self.output[self.len] = bytes[0];
                self.len += 1;
                break :blk .{ .written = 1 };
            },
            .upgrade => blk: {
                self.upgrades += 1;
                break :blk .ok;
            },
            .lookup => |selection| blk: {
                try t.expectEqualStrings("alice", selection.account);
                try t.expectEqualStrings("tables", selection.database);
                break :blk .{ .method = self.method };
            },
            .password => |bytes| blk: {
                try t.expectEqualStrings("secret", bytes);
                self.passwords += 1;
                break :blk .ok;
            },
            .admit => blk: {
                try t.expect(self.method == .trust or self.passwords == 1);
                self.admits += 1;
                break :blk .ok;
            },
            else => return error.UnexpectedRequest,
        };
    }
    fn run(self: *Peer, session: *m.StartupSession) !void {
        while (try session.poll()) |event| try session.complete(event.token, try self.respond(event.request));
    }
};
fn packet(allocator: std.mem.Allocator, sequence: u8, body: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, body.len + 4);
    std.mem.writeInt(u24, bytes[0..3], @intCast(body.len), .little);
    bytes[3] = sequence;
    @memcpy(bytes[4..], body);
    return bytes;
}
fn input(allocator: std.mem.Allocator, secure: bool, password: bool) ![]u8 {
    var prefix: [32]u8 = @splat(0);
    // Independent Protocol 4.1 offers: database, secure connection, plugin auth.
    std.mem.writeInt(u32, prefix[0..4], 0x88208 | (if (secure) @as(u32, 0x800) else 0), .little);
    std.mem.writeInt(u32, prefix[4..8], 1024 * 1024, .little);
    prefix[8] = 255;
    const upgrade = try packet(allocator, 1, &prefix);
    defer allocator.free(upgrade);
    const body = try std.mem.concat(allocator, u8, &.{ &prefix, "alice\x00\x00tables\x00caching_sha2_password\x00" });
    defer allocator.free(body);
    const response = try packet(allocator, if (secure) 2 else 1, body);
    defer allocator.free(response);
    const secret = try packet(allocator, 4, "secret\x00");
    defer allocator.free(secret);
    return std.mem.concat(allocator, u8, &.{ if (secure) upgrade else "", response, if (password) secret else "" });
}
const options: m.StartupSession.Options = .{ .tls = .optional, .generation = 3, .id = 7, .nonce = @splat('n') };
fn packets(bytes: []const u8, sequences: []const u8, tags: []const u8) !void {
    var cursor: usize = 0;
    for (sequences, tags) |sequence, tag| {
        try t.expectEqual(sequence, bytes[cursor + 3]);
        try t.expectEqual(tag, bytes[cursor + 4]);
        cursor += 4 + std.mem.readInt(u24, bytes[cursor..][0..3], .little);
    }
    try t.expectEqual(bytes.len, cursor);
}
test "classic startup preserves fragmentation sequence and admitted output without backing allocations" {
    for ([_]bool{ false, true }) |secure| {
        for ([_]w.Method{ .trust, .password }) |method| {
            if (!secure and method == .password) continue;
            const bytes = try input(t.allocator, secure, method == .password);
            defer t.allocator.free(bytes);
            for (0..bytes.len + 1) |split| {
                var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
                var session = try m.StartupSession.init(allocator.allocator(), options);
                defer session.deinit();
                allocator.fail_index = allocator.alloc_index;
                allocator.resize_fail_index = allocator.resize_index;
                var peer: Peer = .{ .input = bytes, .split = split, .method = method };
                try peer.run(&session);
                try t.expectEqual(bytes.len, peer.cursor);
                try t.expectEqual(@as(usize, 1), peer.admits);
                try packets(peer.output[0..peer.len], if (method == .password) &.{ 0, 3, 5 } else if (secure) &.{ 0, 3 } else &.{ 0, 2 }, if (method == .password) &.{ 10, 1, 0 } else &.{ 10, 0 });
                try t.expect(std.mem.allEqual(u8, &session.bytes, 0));
                try t.expect(!allocator.has_induced_failure);
            }
        }
    }
}
test "password requests require completed TLS and exact upgrade capabilities" {
    const bytes = try input(t.allocator, false, false);
    defer t.allocator.free(bytes);
    var session = try m.StartupSession.init(t.allocator, options);
    defer session.deinit();
    var peer: Peer = .{ .input = bytes, .method = .password };
    try t.expectError(error.TlsRequired, peer.run(&session));
    try packets(peer.output[0..peer.len], &.{ 0, 2 }, &.{ 10, 0xff });
    try t.expectEqual(@as(usize, 0), peer.passwords);
    const encrypted = try input(t.allocator, true, true);
    defer t.allocator.free(encrypted);
    // SSLRequest is 36 bytes; mutate the response charset after its header.
    encrypted[36 + 4 + 8] = 45;
    var changed = try m.StartupSession.init(t.allocator, options);
    defer changed.deinit();
    var renegotiated: Peer = .{ .input = encrypted, .method = .password };
    try t.expectError(error.WireNegotiationChanged, renegotiated.run(&changed));
    try t.expectEqual(@as(usize, 0), renegotiated.passwords);
    try t.expectEqual(@as(usize, 0), renegotiated.admits);
}
test "failed upgrade credential verification and admission cannot become login success" {
    const bytes = try input(t.allocator, true, true);
    defer t.allocator.free(bytes);
    for ([_]std.meta.Tag(w.Request){ .upgrade, .lookup, .password, .admit }) |failure| {
        var session = try m.StartupSession.init(t.allocator, options);
        defer session.deinit();
        var peer: Peer = .{ .input = bytes, .method = .password, .fail = failure };
        try t.expectError(error.AccessDenied, peer.run(&session));
        var cursor: usize = 0;
        while (cursor < peer.len) {
            try t.expect(peer.output[cursor + 4] != 0);
            cursor += 4 + std.mem.readInt(u24, peer.output[cursor..][0..3], .little);
        }
        if (failure == .upgrade) try t.expectEqual(@as(usize, 36), peer.cursor);
    }
}
test "partial EOF oversized and wrong-sequence startup refuse before body or admission" {
    for ([_][]const u8{ "\x00\x00", "\xff\xff\xff\x01", "\x20\x00\x00\x02" }, [_]anyerror{ error.EndOfStream, error.FrameTooLarge, error.PacketSequenceMismatch }) |bytes, expected| {
        var session = try m.StartupSession.init(t.allocator, options);
        defer session.deinit();
        var peer: Peer = .{ .input = bytes };
        try t.expectError(expected, peer.run(&session));
        try t.expectEqual(@as(usize, 0), peer.admits);
    }
}
