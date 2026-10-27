const std = @import("std");
const adapter = @import("transit_backend_ursula");
const ursula = adapter.ursula;
const check = std.testing;

fn longPoll(client: *ursula.Client, stream: ursula.Stream) anyerror!void {
    var response = try client.send(.{ .read = .{ .stream = stream, .options = .{
        .position = .{ .record = 0 },
        .live = .long_poll,
        .max_records = 1,
    } } });
    defer response.deinit();
    try response.head.requireSuccess();
    try check.expectEqualStrings("{\"live\":true}\n", response.body);
    const meta = try response.head.metadata();
    try check.expectEqual(@as(?u64, 1), meta.record_next);
    const cursor = meta.cursor orelse return error.MissingLiveCursor;
    const offset = meta.next_offset orelse return error.MissingOffset;
    const journal: adapter.Journal = .{ .client = client, .stream = stream };
    try check.expect(try journal.append(1, "{\"continued\":true}"));

    // Position selects the unread data; the cursor is an independent cache token.
    // Both values borrow response storage, which remains alive for these reads.
    var resumed = try client.send(.{ .read = .{ .stream = stream, .options = .{
        .position = .{ .offset = offset },
        .cursor = cursor,
        .live = .long_poll,
        .max_bytes = adapter.max_record_bytes,
    } } });
    defer resumed.deinit();
    try resumed.head.requireSuccess();
    try check.expectEqualStrings("{\"continued\":true}\n", resumed.body);
    const resumed_meta = try resumed.head.metadata();

    var by_record = try client.send(.{ .read = .{ .stream = stream, .options = .{
        .position = .{ .record = meta.record_next.? },
        .cursor = cursor,
        .live = .long_poll,
        .max_records = 1,
    } } });
    defer by_record.deinit();
    try by_record.head.requireSuccess();
    try check.expectEqualStrings("{\"continued\":true}\n", by_record.body);
    try check.expectEqual(@as(?u64, 2), (try by_record.head.metadata()).record_next);

    var continued = try client.send(.{ .read = .{ .stream = stream, .options = .{
        .position = .{ .offset = resumed_meta.next_offset orelse return error.MissingOffset },
        .cursor = resumed_meta.cursor orelse return error.MissingLiveCursor,
        .max_bytes = adapter.max_record_bytes,
    } } });
    defer continued.deinit();
    try continued.head.requireSuccess();
    try check.expectEqual(@as(usize, 0), continued.body.len);
}
fn delayedAppend(io: std.Io, journal: adapter.Journal) anyerror!void {
    try io.sleep(.fromMilliseconds(100), .awake);
    try check.expect(try journal.append(0, "{\"live\":true}"));
}
fn timeout(io: std.Io) anyerror!void {
    try io.sleep(.fromSeconds(10), .awake);
}
fn proveLive(init: std.process.Init, url: []const u8, reader: *ursula.Client) !void {
    var writer = try ursula.Client.init(init.gpa, init.io, .{ .base_url = url });
    defer writer.deinit();
    const journal: adapter.Journal = .{ .client = &writer, .stream = .{ .bucket = "transit-proof", .name = "live" } };
    try journal.create();
    const Result = union(enum) { read: anyerror!void, write: anyerror!void, timeout: anyerror!void };
    var values: [3]Result = undefined;
    var select: std.Io.Select(Result) = .init(init.io, &values);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{init.io});
    try select.concurrent(.read, longPoll, .{ reader, journal.stream });
    try select.concurrent(.write, delayedAppend, .{ init.io, journal });
    var done: usize = 0;
    while (done < 2) : (done += 1) switch (try select.await()) {
        .read, .write => |result| try result,
        .timeout => return error.LiveReadTimeout,
    };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1] });
    defer client.deinit();
    const journal: adapter.Journal = .{ .client = &client, .stream = .{ .bucket = "transit-proof", .name = "journal" } };
    if (std.mem.eql(u8, args[2], "write")) {
        try proveLive(init, args[1], &client);
        try journal.create();
        const first = try journal.tail();
        try check.expectEqual(@as(u64, 0), first);
        // Two proposals derive from the same prefix; only one may become visible.
        try check.expect(try journal.append(first, "{\"winner\":1}"));
        try check.expect(!try journal.append(first, "{\"winner\":2}"));
        // Discard the successful receipt, then retry as if its ack were lost.
        _ = try journal.append(1, "{\"uncertain\":true}");
        try check.expect(!try journal.append(1, "{\"uncertain\":true}"));
        for (2..40) |i| {
            const body = try init.gpa.print("{{\"n\":{d}}}", .{i});
            defer init.gpa.free(body);
            try check.expect(try journal.append(i, body));
        }
    } else if (std.mem.eql(u8, args[2], "recover") or std.mem.eql(u8, args[2], "checkpoint") or std.mem.eql(u8, args[2], "trim_recover")) {
        try check.expectEqual(@as(u64, 40), try journal.tail());
        try check.expect(!try journal.append(0, "{\"stale\":true}"));
        var at: u64 = 0;
        while (at < 40) {
            var batch = try journal.read(at);
            defer batch.deinit();
            const next = (try batch.head.metadata()).record_next.?;
            try check.expect(next > at);
            if (at == 0) {
                try check.expect(std.mem.startsWith(u8, batch.body, "{\"winner\":1}\n{\"uncertain\":true}\n"));
                try check.expect(std.mem.indexOf(u8, batch.body, "winner\":2") == null);
            }
            at = next;
        }
        try check.expectEqual(@as(u64, 40), at);
    } else return error.UnknownPhase;
    std.debug.print("storage {s}: passed\n", .{args[2]});
}
