const std = @import("std");
const p = @import("transit_protocol");
const t = std.testing;
const s = @import("root.zig");
const B = s.BitmapDirectory;
const Tack = s.Tack;

fn manifest(first: u64, next: u64, states: Tack.Roots) Tack {
    return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{
        .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 },
        .revision = 1,
        .digest = @splat(5),
    }, .partition = 6 }, .segment = 7, .first = first, .next = next, .accepted = .{ .partition = 8, .next_lsn = 9 }, .states = states };
}

fn audit(value: Tack, directory: *B, scratch: *B.Container) !void {
    var cursor = try Tack.Audit.init(value);
    while (!try cursor.page(directory, scratch)) {}
}

test "tack disk reopen validates coverage and preserves historical states" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var before: Tack = undefined;
    var after: Tack = undefined;
    var bytes: [Tack.encoded_bytes]u8 = undefined;
    var scratch: B.Container = .{};
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "tack");
        defer objects.deinit();
        var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
        defer tree.deinit();
        var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
        try tree.begin(1024 * 1024);
        defer tree.end();
        var available: B.Root = .empty;
        available = try directory.edit(available, 0, &.{.{ .offset = 65535, .present = true }}, &scratch);
        available = try directory.edit(available, 1, &.{ .{ .offset = 0, .present = true }, .{ .offset = 1, .present = true } }, &scratch);
        before = manifest(65535, 65538, .{ available, .empty, .empty, .empty });
        after = before;
        after.states = try after.transition(&directory, 65535, .available, .acquired, &scratch);
        after.states = try after.transition(&directory, 65535, .acquired, .acked, &scratch);
        after.accepted.next_lsn += 2;
        _ = try after.encode(&bytes);
        try audit(before, &directory, &scratch);
        try audit(after, &directory, &scratch);
        try t.expectError(error.InvalidQueueStateTransition, after.transition(&directory, 65535, .acked, .available, &scratch));
        try t.expectError(error.QueueStateConflict, after.transition(&directory, 65535, .available, .acquired, &scratch));
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "tack");
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    const decoded = try Tack.decode(&bytes);
    try t.expectEqualDeep(after, decoded);
    try audit(decoded, &directory, &scratch);
    try audit(before, &directory, &scratch);
    try t.expect(try directory.contains(before.states[0], 65535));
    try t.expect(try directory.contains(after.states[2], 65535));
    try t.expect(!try after.terminal());
    try decoded.requireBinding(after.target, 7, 65535, 65538, after.accepted);
    var foreign = after.target;
    foreign.partition += 1;
    try t.expectError(error.LogPartitionConflict, decoded.requireBinding(foreign, 7, 65535, 65538, after.accepted));
    try t.expectError(error.QueueSidecarConflict, decoded.requireBinding(after.target, 8, 65535, 65538, after.accepted));
    var earlier = after.accepted;
    earlier.next_lsn -= 1;
    try t.expectError(error.QueueSidecarConflict, decoded.requireBinding(after.target, 7, 65535, 65538, earlier));
    // The manifest is not complete evidence when a referenced container is lost.
    const ref = (try directory.reference(after.states[2], 0)).?;
    var key: [96]u8 = undefined;
    try objects.objectStore().delete(try B.objectKey(ref, &key));
    directory.cached = null;
    try t.expectError(error.MissingBitmapContainer, audit(decoded, &directory, &scratch));
}

test "tack rejects overlap omitted ranges counts corrupt envelopes and staged failure" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var tree = try s.TreeStore.init(t.allocator, objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: B.Container = .{};
    try tree.begin(1024 * 1024);
    const one = try directory.edit(.empty, 0, &.{.{ .offset = 10, .present = true }}, &scratch);
    const two = try directory.edit(one, 0, &.{.{ .offset = 11, .present = true }}, &scratch);
    tree.end();
    const overlap = manifest(10, 12, .{ one, one, .empty, .empty });
    try t.expectError(error.QueueSidecarOverlap, audit(overlap, &directory, &scratch));
    const missing = manifest(10, 12, .{ one, .empty, .empty, .empty });
    try t.expectError(error.InvalidQueueSidecar, missing.validate());
    const outside = manifest(11, 13, .{ two, .empty, .empty, .empty });
    try t.expectError(error.QueueSidecarOffsetOutOfRange, audit(outside, &directory, &scratch));
    var forged = manifest(10, 13, .{ two, .empty, .empty, .empty });
    forged.states[0].cardinality = 3;
    try t.expectError(error.InvalidQueueSidecar, audit(forged, &directory, &scratch));
    const original = manifest(10, 12, .{ two, .empty, .empty, .empty });
    try tree.begin(1);
    try t.expectError(error.StorageCandidateTooLarge, original.transition(&directory, 10, .available, .acquired, &scratch));
    tree.end();
    try audit(original, &directory, &scratch);
    // Fail after staging the source removal but before staging the destination.
    try tree.begin(1024 * 1024);
    _ = try directory.edit(two, 0, &.{.{ .offset = 10, .present = false }}, &scratch);
    const removal_bytes = tree.candidate.?.staged;
    tree.end();
    try tree.begin(removal_bytes);
    try t.expectError(error.StorageCandidateTooLarge, original.transition(&directory, 10, .available, .acquired, &scratch));
    tree.end();
    try audit(original, &directory, &scratch);
    var bytes: [Tack.encoded_bytes]u8 = undefined;
    _ = try original.encode(&bytes);
    bytes[40] ^= 1;
    try t.expectError(error.CorruptQueueSidecar, Tack.decode(&bytes));
    bytes[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Tack.decode(&bytes));
    _ = try original.encode(&bytes);
    // Absent roots must use zero reference bytes, even with a valid checksum.
    bytes[164 + 73 + 1] = 1;
    std.crypto.hash.sha2.Sha256.hash(bytes[0 .. bytes.len - 32], bytes[bytes.len - 32 ..], .{});
    try t.expectError(error.InvalidQueueSidecar, Tack.decode(&bytes));
    const terminal = manifest(10, 12, .{ .empty, .empty, two, .empty });
    try t.expect(try terminal.terminal());
    try audit(terminal, &directory, &scratch);
}

test "tack audit exceeds one-page cache without allocating per container" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var failing = t.FailingAllocator.init(t.allocator, .{});
    var tree = try s.TreeStore.init(failing.allocator(), objects.objectStore(), 1);
    defer tree.deinit();
    var directory: B = .{ .store = &tree, .objects = objects.objectStore() };
    var scratch: B.Container = .{};
    @memset(&scratch.words, std.math.maxInt(u64));
    scratch.cardinality = 65536;
    var available: B.Root = .empty;
    const allocations = failing.alloc_index;
    failing.fail_index = allocations;
    for (0..17) |prefix| {
        try tree.begin(1024 * 1024);
        defer tree.end();
        available = try directory.replace(available, prefix, &scratch);
    }
    const value = manifest(0, 17 * 65536, .{ available, .empty, .empty, .empty });
    tree.clearCache();
    directory.cached = null;
    var cursor = try Tack.Audit.init(value);
    var pages: usize = 0;
    while (true) {
        pages += 1;
        if (try cursor.page(&directory, &scratch)) break;
    }
    try t.expect(pages >= 6);
    try t.expectEqual(allocations, failing.alloc_index);
}
