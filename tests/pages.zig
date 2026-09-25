//! Storage-primitive qualification, not a new public authority profile.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const p = core.pages;
const t = std.testing;
const Root = struct { version: u32 = 2, root: p.Reference, entries: u64 };
const Checkpoint = struct { version: u32 = 2, position: u64 = 2, current: Root, view: Root };

fn checkpoint(journal: adapter.Journal) !Checkpoint {
    var latest = try journal.client.send(.{ .read_snapshot = .{ .stream = journal.stream } });
    defer latest.deinit();
    if (latest.head.status != .temporary_redirect) return error.MissingPageCheckpoint;
    const offset = (try latest.head.metadata()).snapshot_offset orelse return error.MissingPageCheckpoint;
    var response = try journal.client.send(.{ .read_snapshot = .{ .stream = journal.stream, .offset = offset } });
    defer response.deinit();
    try response.head.requireSuccess();
    const parsed = try std.json.parseFromSlice(Checkpoint, journal.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    if (parsed.value.version != 2 or parsed.value.position != 2) return error.InvalidPageCheckpoint;
    return parsed.value;
}

fn key(index: usize) p.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, index, .big);
    return p.Key.init(&bytes) catch unreachable;
}
fn value(index: usize) p.Value {
    var bytes: [1024]u8 = @splat(42);
    std.mem.writeInt(u64, bytes[0..8], index, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn publish(journal: adapter.Journal, at: u64, root: Root) !bool {
    var bytes: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(root, .{}, &writer);
    return journal.append(at, writer.buffered());
}
fn recorded(journal: adapter.Journal, at: u64) !Root {
    var response = try journal.read(at);
    defer response.deinit();
    var lines = std.mem.splitScalar(u8, response.body, '\n');
    const first = lines.next() orelse return error.MissingRoot;
    const parsed = try std.json.parseFromSlice(Root, journal.client.http.allocator, first, .{});
    defer parsed.deinit();
    if (parsed.value.version != 2) return error.UnsupportedRoot;
    return parsed.value;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 6) return error.ExpectedUrlPhaseKeysCacheAndLayout;
    if (std.mem.eql(u8, args[5], "packed")) return run(adapter.PackedPageStore, init, args);
    if (std.mem.eql(u8, args[5], "closed")) return run(adapter.PageStore, init, args);
    return error.UnknownPageLayout;
}
fn run(comptime PageStore: type, init: std.process.Init, args: []const [:0]const u8) !void {
    const keys = try std.fmt.parseInt(usize, args[3], 10);
    const cache_pages = try std.fmt.parseInt(usize, args[4], 10);
    if (keys < 64 or keys > 16384 or keys % 2 != 0) return error.InvalidDataset;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    const journal: adapter.Journal = .{ .client = &client, .stream = .{ .bucket = "transit-page-proof", .name = "roots" } };
    var store = try PageStore.init(init.gpa, journal, cache_pages);
    defer store.deinit();
    const tree: p.Tree(PageStore) = .{ .store = &store };
    if (std.mem.eql(u8, args[2], "write")) {
        try journal.create();
        var missing: p.Reference = .{ .digest = @splat(1) };
        if (PageStore == adapter.PackedPageStore) {
            try store.create();
            missing.location[0] = 1;
        }
        try t.expectError(error.PageUnavailable, store.load(missing));
        var root: ?p.Reference = null;
        for (0..keys) |i| root = try tree.put(root, key(i), value(i));
        try t.expect(keys * 1024 > store.residentBytes());
        try t.expect(try publish(journal, 0, .{ .root = root.?, .entries = keys }));
        const snapshot = root;
        for (0..keys / 2) |i| root = try tree.remove(root, key(i * 2));
        try t.expect(try publish(journal, 1, .{ .root = root.?, .entries = keys / 2 }));
        try t.expect(!try publish(journal, 1, .{ .root = snapshot.?, .entries = keys }));
        // Staged orphan is not a publication; root discovery comes only from
        // the authoritative journal, never page timestamps or stream listing.
        _ = try tree.put(root, key(keys + 1), value(keys + 1));
        try t.expectEqual(@as(u64, 2), try journal.tail());
        if (PageStore == adapter.PackedPageStore) {
            // A packed locator is not trusted without the matching digest.
            var wrong = root.?;
            wrong.location[8..16].* = @splat(0);
            store.clearCache();
            try t.expectError(error.CorruptPage, store.load(wrong));
            var page: p.Page = .{ .count = 1, .body = .{ .leaf = @splat(null) } };
            page.body.leaf[0] = .{ .key = key(keys + 2), .value = value(keys + 2) };
            _ = try store.stage(try page.reference(), &page);
            var competing = try PageStore.init(init.gpa, journal, 0);
            defer competing.deinit();
            _ = try competing.stage(try page.reference(), &page);
            try t.expectError(error.Conflict, store.stage(try page.reference(), &page));
            _ = try store.stage(try page.reference(), &page); // Explicit retry reconciles the tail.
            try t.expectEqual(@as(u64, 2), try journal.tail());
        }
    } else if (!std.mem.eql(u8, args[2], "recover") and !std.mem.eql(u8, args[2], "checkpoint") and !std.mem.eql(u8, args[2], "trim_recover")) return error.UnknownPhase;

    store.clearCache();
    const trimmed = std.mem.eql(u8, args[2], "trim_recover");
    const before = if (trimmed) (try checkpoint(journal)).view else try recorded(journal, 0);
    const current = if (trimmed) (try checkpoint(journal)).current else try recorded(journal, 1);
    if (trimmed) try t.expectError(error.HistoryReclaimed, journal.read(0));
    for (0..keys) |i| {
        const found = (try tree.get(before.root, key(i))).?;
        try t.expectEqualSlices(u8, value(i).slice(), found.slice());
        const latest = try tree.get(current.root, key(i));
        if (i % 2 == 0) {
            try t.expect(latest == null);
        } else try t.expectEqualSlices(u8, value(i).slice(), latest.?.slice());
    }
    try t.expect((try tree.get(current.root, key(keys + 1))) == null);
    var after: ?p.Key = null;
    var count: u64 = 0;
    while (true) {
        const page = try tree.scan(current.root, after);
        for (page.entries) |slot| if (slot) |entry| {
            try t.expectEqualSlices(u8, key(count * 2 + 1).slice(), entry.key.slice());
            count += 1;
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(current.entries, count);
    if (std.mem.eql(u8, args[2], "checkpoint")) {
        // This fixture owns its raw root journal. It tests storage mechanisms,
        // not application authorization to trim or collect live pages.
        const manifest: Checkpoint = .{ .current = current, .view = before };
        const bytes = try std.json.Stringify.valueAlloc(init.gpa, manifest, .{});
        defer init.gpa.free(bytes);
        try t.expect(bytes.len < 1024); // Roots only; no resource materialization.
        var published = try client.send(.{ .publish_snapshot = .{ .stream = journal.stream, .at = .{ .record = 2 }, .body = bytes, .content_type = "application/json" } });
        defer published.deinit();
        try published.head.requireSuccess();
        try t.expect(std.meta.eql(manifest, try checkpoint(journal)));
        var advanced = try client.send(.{ .advance_retention = .{ .stream = journal.stream, .at = .{ .record = 2 } } });
        defer advanced.deinit();
        try advanced.head.requireSuccess();
    }
    var output_buffer: [2048]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    try std.json.Stringify.value(.{ .page_version = p.version, .layout = args[5], .phase = args[2], .keys = keys, .retained_value_bytes = keys * 1024, .resident_pages = cache_pages, .cache_bytes = store.residentBytes(), .hits = store.hits, .misses = store.misses, .created_pages = store.created, .created_page_streams = if (PageStore == adapter.PackedPageStore) @as(u64, if (std.mem.eql(u8, args[2], "write")) 1 else 0) else store.created, .page_http_requests = store.requests, .page_payload_bytes_attempted = store.create_payload_bytes_attempted }, .{}, &output.interface);
    try output.interface.writeByte('\n');
    try output.interface.flush();
}
