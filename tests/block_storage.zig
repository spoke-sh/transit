//! Immutable block/index storage proof, not a public authority or grant profile.
const std = @import("std");
const core = @import("transit_core");
const adapter = @import("transit_backend_ursula");
const b = core.protocol.Blocks;
const t = std.testing;
const Root = struct { version: u32 = 1, index: core.blocks.Snapshot };

fn recorded(journal: adapter.Journal, position: u64) !Root {
    var response = try journal.send(.{ .read = .{ .stream = journal.stream, .options = .{ .position = .{ .record = position }, .max_records = 1 } } });
    defer response.deinit();
    try response.head.requireSuccess();
    const parsed = try std.json.parseFromSlice(Root, journal.client.http.allocator, response.body, .{});
    defer parsed.deinit();
    if (parsed.value.version != 1) return error.UnsupportedRoot;
    return parsed.value;
}
fn publish(journal: adapter.Journal, position: u64, snapshot: core.blocks.Snapshot) !bool {
    var buffer: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try std.json.Stringify.value(Root{ .index = snapshot }, .{}, &writer);
    return journal.append(position, writer.buffered());
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.ExpectedUrlAndPhase;
    var client = try adapter.ursula.Client.init(init.gpa, init.io, .{ .base_url = args[1], .max_response_bytes = 256 * 1024 });
    defer client.deinit();
    const journal: adapter.Journal = .{ .client = &client, .stream = .{ .bucket = "transit-block-proof", .name = "roots" } };
    var store = try adapter.PackedPageStore.init(init.gpa, journal, 1);
    defer store.deinit();
    const index: core.blocks.Index(adapter.PackedPageStore) = .{ .store = &store };
    const first: [b.max_block_bytes]u8 = @splat(17);
    const second: [b.max_block_bytes]u8 = @splat(29);
    if (std.mem.eql(u8, args[2], "write")) {
        try journal.create();
        try store.create();
        var batch: b.Batch = .{};
        try batch.put(try .init("a"), &first);
        try batch.put(try .init("b"), &second);
        try batch.put(try .init("empty"), "");
        const old = try index.publish(.{}, batch.mutations, &batch.body, 1);
        try t.expect(try publish(journal, 0, old));
        var changed: b.Batch = .{};
        try changed.put(try .init("a"), null);
        try changed.put(try .init("b"), "replacement");
        const next = try index.publish(old, changed.mutations, &changed.body, 2);
        try t.expect(try publish(journal, 1, next));
        try t.expect(!try publish(journal, 1, old));
        try t.expect(first.len + second.len > store.residentBytes());
    } else if (std.mem.eql(u8, args[2], "staging-fault")) {
        const old = try recorded(journal, 1);
        var candidate: b.Batch = .{};
        try candidate.put(try .init("orphan"), &first);
        if (index.publish(old.index, candidate.mutations, &candidate.body, 3)) |_| return error.ExpectedStagingFailure else |_| {}
        try t.expectEqual(2, try journal.tail());
        try t.expectEqualDeep(old, try recorded(journal, 1));
    } else if (std.mem.eql(u8, args[2], "verify")) {
        try t.expectEqual(2, try journal.tail());
        const old = try recorded(journal, 0);
        const current = try recorded(journal, 1);
        const keys: [core.protocol.Growth.page_size]?core.Value = .{ try .init("a"), try .init("b"), try .init("empty"), null, null, null, null, null };
        var body: b.Body = .{};
        const retained = try index.read(old.index, keys, &body);
        try t.expectEqual(1, retained[0].?.revision);
        try t.expectEqual(0, retained[2].?.value.bytes);
        try t.expectEqualSlices(u8, &first, body.slice()[0..first.len]);
        try t.expectEqualSlices(u8, &second, body.slice()[first.len..]);
        const changed = try index.read(current.index, keys, &body);
        try t.expectEqual(null, changed[0]);
        try t.expectEqual(2, changed[1].?.revision);
        try t.expectEqualStrings("replacement", body.slice());
    } else return error.UnknownPhase;
    var buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writer(init.io, &buffer);
    try output.interface.print("Block storage {s}: passed\n", .{args[2]});
    try output.interface.flush();
}
