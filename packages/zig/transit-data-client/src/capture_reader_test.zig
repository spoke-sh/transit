const std = @import("std");
const t = std.testing;
const Reader = @import("CaptureReader.zig");
const Catalog = @import("Catalog.zig");
const c = @import("transit_catalog");
const p = c.protocol;
const w = c.DirectSourceRead;
const Fixture = struct { saved: Reader.Saved, cursor: w.Cursor, request: c.DirectTableProtocol.Request, public_key: [32]u8 };

const Peer = struct {
    cursor: w.Cursor,
    saved: Reader.Saved,
    fail_open: bool = false,
    fail_release: bool = false,
    denied: bool = false,
    corrupt: bool = false,
    acquired: bool = false,
    releases: usize = 0,
    calls: usize = 0,
    fn transport(self: *Peer) Reader.Transport {
        return .{ .context = self, .connection = self.saved.connection, .call = call };
    }
    fn call(context: *anyopaque, output: *std.heap.ArenaAllocator, request: w.Request) !Catalog.CaptureOutcome {
        const self: *Peer = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (self.denied) return error.CatalogDenied;
        const result: w.Result = switch (request) {
            .open => |original| blk: {
                try t.expectEqualDeep(self.saved.open, original);
                self.acquired = true;
                if (self.fail_open) {
                    self.fail_open = false;
                    return error.LostAcknowledgement;
                }
                break :blk .{ .opened = self.cursor };
            },
            .inspect_open, .cancel_open => |original| blk: {
                try t.expectEqualDeep(self.saved.open, original);
                try t.expect(self.acquired);
                break :blk .{ .original = self.cursor.handle };
            },
            .next => |cursor| blk: {
                try t.expectEqualDeep(self.cursor.handle, cursor.handle);
                const total = cursor.handle.publication.evidence.body.bytes;
                var raw: [p.SourceCapture.chunk_bytes]u8 = undefined;
                const bytes = raw[0..@min(raw.len, total - cursor.offset)];
                for (bytes, 0..) |*byte, i| byte.* = @truncate((cursor.offset + i) *% 73 +% 19);
                if (self.corrupt and bytes.len != 0) bytes[0] ^= 1;
                var next = cursor;
                next.offset += bytes.len;
                break :blk .{ .page = .{ .offset = cursor.offset, .bytes = try c.DirectTableProtocol.Binary.encode(output.allocator(), bytes), .next = next, .complete = next.offset == total } };
            },
            .close => |close| blk: {
                try t.expectEqualDeep(self.saved.release, close.operation);
                try t.expectEqualDeep(self.cursor.handle, close.handle);
                self.releases += 1;
                if (self.fail_release) {
                    self.fail_release = false;
                    return error.LostAcknowledgement;
                }
                break :blk .{ .closed = .{ .release = .{ .target = close.handle.publication.target(), .operation = close.operation, .read = close.handle.read.handle() }, .accepted = .{ .partition = 93, .next_lsn = 5 } } };
            },
            else => return error.TestUnexpectedResult,
        };
        return .{ .value = .{ .result = result }, .attempt = .{} };
    }
};

test "capture reader owns batches verifies complete digest and recovers saved close originals" {
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/source-capture-read-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    const saved = try fixture.saved.save(t.allocator);
    defer t.allocator.free(saved);
    try t.expectEqualDeep(fixture.saved, try Reader.Saved.load(t.allocator, saved));
    var peer: Peer = .{ .saved = fixture.saved, .cursor = fixture.cursor };
    var reader: Reader = undefined;
    try reader.init(t.allocator, fixture.saved, peer.transport());
    defer reader.deinit();
    _ = try reader.open();
    const first = try reader.next(t.allocator);
    defer t.allocator.free(first.bytes);
    try t.expect(!first.complete);
    const last = try reader.next(t.allocator);
    defer t.allocator.free(last.bytes);
    try t.expect(last.complete);
    for (first.bytes, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate(i *% 73 +% 19)), byte);
    const terminal = try reader.next(t.allocator);
    defer t.allocator.free(terminal.bytes);
    try t.expect(terminal.complete and terminal.bytes.len == 0);
    try reader.close();
    try t.expect(reader.memory.peak <= Reader.scratch_bytes);
    // Lost acquisition and release are resolved with the same saved originals.
    var uncertain: Peer = .{ .saved = fixture.saved, .cursor = fixture.cursor, .fail_open = true, .fail_release = true };
    var recovered: Reader = undefined;
    try recovered.init(t.allocator, try Reader.Saved.load(t.allocator, saved), uncertain.transport());
    defer recovered.deinit();
    try t.expectError(error.LostAcknowledgement, recovered.open());
    try t.expectEqualDeep(fixture.cursor.handle, (try recovered.observe()).?);
    try t.expectError(error.LostAcknowledgement, recovered.close());
    try recovered.close();
    try t.expectEqual(2, uncertain.releases);
    try t.expectEqual(.closed, recovered.state);
    const at = std.mem.indexOf(u8, saved, @tagName(p.Growth.current_definition)).?;
    saved[at] = '0';
    try t.expectError(error.InvalidJsonShape, Reader.Saved.load(t.allocator, saved));
}

test "capture reader refuses corrupt completion and cannot splice a failed prefix" {
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/source-capture-read-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    for ([_]bool{ false, true }) |corrupt| {
        var peer: Peer = .{ .saved = fixture.saved, .cursor = fixture.cursor };
        var reader: Reader = undefined;
        try reader.init(t.allocator, fixture.saved, peer.transport());
        defer reader.deinit();
        _ = try reader.open();
        const prefix = try reader.next(t.allocator);
        defer t.allocator.free(prefix.bytes);
        try t.expect(!prefix.complete);
        peer.corrupt = corrupt;
        peer.denied = !corrupt;
        try t.expectError(if (corrupt) error.SourceCaptureDigestMismatch else error.CatalogDenied, reader.next(t.allocator));
        peer.denied = false;
        peer.corrupt = false;
        const calls = peer.calls;
        try t.expectError(error.SourceCaptureReaderState, reader.next(t.allocator));
        try t.expectEqual(calls, peer.calls);
        try reader.close();
    }
    var peer: Peer = .{ .saved = fixture.saved, .cursor = fixture.cursor };
    peer.cursor.handle.publication.evidence.body = .{ .bytes = 0, .sha256 = undefined };
    std.crypto.hash.sha2.Sha256.hash("", &peer.cursor.handle.publication.evidence.body.sha256, .{});
    var reader: Reader = undefined;
    try reader.init(t.allocator, fixture.saved, peer.transport());
    defer reader.deinit();
    _ = try reader.open();
    const empty = try reader.next(t.allocator);
    defer t.allocator.free(empty.bytes);
    try t.expect(empty.complete and empty.bytes.len == 0);
    try reader.close();
}
