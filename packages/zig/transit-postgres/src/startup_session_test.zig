const std = @import("std");
const pg = @import("root.zig");
const w = pg.wire.Startup;
const t = std.testing;
const Peer = struct {
    input: []const u8,
    cursor: usize = 0,
    split: usize = 0,
    output: [4096]u8 = undefined,
    len: usize = 0,
    fragment: usize = 1,
    method: w.Method = .trust,
    fail: ?std.meta.Tag(w.Request) = null,
    upgrades: usize = 0,
    admits: usize = 0,
    cancels: usize = 0,
    verified: bool = false,
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
                const count = @min(bytes.len, self.fragment);
                @memcpy(self.output[self.len..][0..count], bytes[0..count]);
                self.len += count;
                break :blk .{ .written = count };
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
            .scram_start => |bytes| blk: {
                try t.expectEqualStrings("n,,n=alice,r=0123456789abcdef", bytes);
                break :blk .{ .challenge = "r=nonce,s=salt,i=4096" };
            },
            .scram_finish => |bytes| blk: {
                try t.expectEqualStrings("c=biws,r=nonce,p=proof", bytes);
                self.verified = true;
                var proof: [46]u8 = @splat('x');
                proof[0..2].* = "v=".*;
                break :blk .{ .proof = proof };
            },
            .admit => blk: {
                try t.expect(self.method == .trust or self.verified);
                self.admits += 1;
                break :blk .ok;
            },
            .cancel => |bytes| blk: {
                try t.expectEqualSlices(u8, "\x00\x00\x00\x07\x00\x00\x00\x09", &bytes);
                self.cancels += 1;
                break :blk .ok;
            },
            else => return error.UnexpectedRequest,
        };
    }
    fn run(self: *Peer, session: *pg.StartupSession) !void {
        while (try session.poll()) |event| try session.complete(event.token, try self.respond(event.request));
    }
};
fn startup(allocator: std.mem.Allocator) ![]u8 {
    const body = "user\x00alice\x00database\x00tables\x00application_name\x00test\x00\x00";
    const bytes = try allocator.alloc(u8, body.len + 8);
    std.mem.writeInt(u32, bytes[0..4], @intCast(bytes.len), .big);
    std.mem.writeInt(u32, bytes[4..8], 196608, .big);
    @memcpy(bytes[8..], body);
    return bytes;
}
fn passwordFrame(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, body.len + 5);
    bytes[0] = 'p';
    std.mem.writeInt(u32, bytes[1..5], @intCast(body.len + 4), .big);
    @memcpy(bytes[5..], body);
    return bytes;
}
fn passwordInput(allocator: std.mem.Allocator, first: []const u8) ![]u8 {
    const initial = "n,,n=alice,r=0123456789abcdef";
    var length: [4]u8 = undefined;
    std.mem.writeInt(u32, &length, initial.len, .big);
    const body = try std.mem.concat(allocator, u8, &.{ "SCRAM-SHA-256\x00", &length, initial });
    defer allocator.free(body);
    const a = try passwordFrame(allocator, body);
    defer allocator.free(a);
    const b = try passwordFrame(allocator, "c=biws,r=nonce,p=proof");
    defer allocator.free(b);
    return std.mem.concat(allocator, u8, &.{ first, a, b });
}
fn authenticationCodes(bytes: []const u8, expected: []const u32) !void {
    var offset: usize = 0;
    var codes: usize = 0;
    while (offset < bytes.len) {
        const length = std.mem.readInt(u32, bytes[offset + 1 ..][0..4], .big);
        if (bytes[offset] == 'R') {
            try t.expect(codes < expected.len);
            try t.expectEqual(expected[codes], std.mem.readInt(u32, bytes[offset + 5 ..][0..4], .big));
            codes += 1;
        }
        offset += length + 1;
    }
    try t.expectEqual(expected.len, codes);
}
const options: pg.StartupSession.Options = .{ .tls = .disabled, .generation = 9, .id = 7, .secret = 9 };
test "startup and SCRAM preserve every input split and one-byte output drains" {
    const first = try startup(t.allocator);
    defer t.allocator.free(first);
    const password = try passwordInput(t.allocator, first);
    defer t.allocator.free(password);
    for ([_]w.Method{ .trust, .password }) |method| {
        const bytes = if (method == .trust) first else password;
        for (0..bytes.len + 1) |split| {
            var allocator = std.testing.FailingAllocator.init(t.allocator, .{});
            var session = try pg.StartupSession.init(allocator.allocator(), options);
            defer session.deinit();
            allocator.fail_index = allocator.alloc_index;
            allocator.resize_fail_index = allocator.resize_index;
            var peer: Peer = .{ .input = bytes, .split = split, .method = method };
            try peer.run(&session);
            try t.expectEqual(bytes.len, peer.cursor);
            try t.expectEqual(@as(usize, 1), peer.admits);
            try authenticationCodes(peer.output[0..peer.len], if (method == .trust) &.{0} else &.{ 10, 11, 12, 0 });
            try t.expectEqualStrings("Z\x00\x00\x00\x05I", peer.output[peer.len - 6 .. peer.len]);
            try t.expect(std.mem.allEqual(u8, &session.bytes, 0));
            try t.expect(!allocator.has_induced_failure);
        }
    }
}
test "upgrade confirmation precedes encrypted startup and failed upgrades close" {
    const first = try startup(t.allocator);
    defer t.allocator.free(first);
    const bytes = try std.mem.concat(t.allocator, u8, &.{ "\x00\x00\x00\x08\x04\xd2\x16\x30", "\x00\x00\x00\x08\x04\xd2\x16\x2f", first });
    defer t.allocator.free(bytes);
    for ([_]bool{ false, true }) |failure| {
        var config = options;
        config.tls = .required;
        var session = try pg.StartupSession.init(t.allocator, config);
        defer session.deinit();
        var peer: Peer = .{ .input = bytes, .fail = if (failure) .upgrade else null };
        if (failure) {
            try t.expectError(error.AccessDenied, peer.run(&session));
            try t.expectEqual(@as(usize, 16), peer.cursor);
            try t.expectEqual(@as(usize, 0), peer.admits);
        } else {
            try peer.run(&session);
            try t.expectEqual(@as(usize, 1), peer.upgrades);
            try authenticationCodes(peer.output[2..peer.len], &.{0});
        }
        try t.expectEqualStrings("NS", peer.output[0..2]);
    }
}
test "lookup and session-admission failures cannot publish login success" {
    const first = try startup(t.allocator);
    defer t.allocator.free(first);
    for ([_]std.meta.Tag(w.Request){ .lookup, .admit }) |failure| {
        var session = try pg.StartupSession.init(t.allocator, options);
        defer session.deinit();
        var peer: Peer = .{ .input = first, .fail = failure };
        try t.expectError(error.AccessDenied, peer.run(&session));
        try t.expectEqual(@as(u8, 'E'), peer.output[0]);
        try authenticationCodes(peer.output[0..peer.len], &.{});
    }
}
test "SCRAM failures never publish a proof or authentication success" {
    const first = try startup(t.allocator);
    defer t.allocator.free(first);
    const bytes = try passwordInput(t.allocator, first);
    defer t.allocator.free(bytes);
    for ([_]std.meta.Tag(w.Request){ .scram_start, .scram_finish }) |failure| {
        var session = try pg.StartupSession.init(t.allocator, options);
        defer session.deinit();
        var peer: Peer = .{ .input = bytes, .method = .password, .fail = failure };
        try t.expectError(error.AccessDenied, peer.run(&session));
        try authenticationCodes(peer.output[0..peer.len], if (failure == .scram_start) &.{10} else &.{ 10, 11 });
        try t.expectEqual(@as(usize, 0), peer.admits);
        try t.expect(std.mem.allEqual(u8, &session.bytes, 0));
    }
}
test "cancellation startup, partial EOF and oversized lengths never admit SQL" {
    var config = options;
    config.cancellation_only = true;
    var session = try pg.StartupSession.init(t.allocator, config);
    defer session.deinit();
    var peer: Peer = .{ .input = "\x00\x00\x00\x10\x04\xd2\x16\x2e\x00\x00\x00\x07\x00\x00\x00\x09" };
    try peer.run(&session);
    try t.expectEqual(@as(usize, 1), peer.cancels);
    try t.expectEqual(@as(usize, 0), peer.admits);
    try t.expectEqual(@as(usize, 0), peer.len);
    for ([_][]const u8{ "\x00\x00", "\xff\xff\xff\xff\x00\x03\x00\x00" }) |bytes| {
        var invalid = try pg.StartupSession.init(t.allocator, options);
        defer invalid.deinit();
        var truncated: Peer = .{ .input = bytes };
        try t.expectError(if (bytes.len == 2) error.EndOfStream else error.InvalidStartupLength, truncated.run(&invalid));
        try t.expectEqual(@as(usize, 0), truncated.admits);
    }
}
