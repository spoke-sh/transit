const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = @import("transit_protocol");
const x = p.Transaction;
const D = s.TransactionDirectory;
const support = @import("transaction_test_support.zig");
const identity = support.identity;
const participant = support.participant;
const begin = support.begin;
const attempt = support.attempt;
const preparation = support.preparation;

test "transaction directories page beyond resident cache and retain frozen roots on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var original: x.Directory = undefined;
    var full: x.Directory = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var directory = try D.init(t.allocator, objects.objectStore(), identity, .participants, 1000, 1, 1024 * 1024);
        defer directory.deinit();
        for (1..74) |i| {
            try directory.put(participant(i));
            if (i == 8) original = try directory.seal();
        }
        full = try directory.seal();
        try t.expectEqualDeep(full, try directory.commitment());
        try t.expectEqual(@as(usize, 1), directory.index.cache.len);
        const staged = directory.index.staged_pages;
        try directory.put(participant(1));
        try t.expectEqual(staged, directory.index.staged_pages);
        var conflict = participant(1);
        conflict.participant.state.access = .read;
        try t.expectError(error.TransactionIdentityConflict, directory.put(conflict));
        try t.expectEqualDeep(full, try directory.commitment());
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var directory = try D.init(t.allocator, objects.objectStore(), identity, .participants, 1000, 0, 1024 * 1024);
    defer directory.deinit();
    for ([_]x.Directory{ original, full }) |selected| {
        try directory.restore(selected);
        var after: ?u64 = null;
        var count: u64 = 0;
        while (true) {
            const page = try directory.page(after);
            for (page.entries) |entry| if (entry) |value| {
                count += 1;
                try t.expectEqualDeep(participant(count), value);
            };
            after = page.next orelse break;
        }
        try t.expectEqual(selected.count, count);
        try t.expectEqual(selected.count, directory.root.writes);
    }
    var forged = full;
    forged.count -= 1;
    try t.expectError(error.InvalidTransactionDirectory, directory.restore(forged));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try D.objectKey(full.content, &name));
    try t.expectError(error.MissingTransactionDirectory, directory.restore(full));
    try directory.restore(original);
}

test "transaction directory refusal leaves accepted selection and private root unchanged" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var directory = try D.init(t.allocator, objects.objectStore(), identity, .participants, 1, 1, 1024 * 1024);
    defer directory.deinit();
    try directory.put(participant(1));
    const original = try directory.seal();
    try t.expectError(error.TransactionParticipantLimit, directory.put(participant(2)));
    directory.entry_limit = 2;
    directory.index_work_bytes = 1;
    try t.expectError(error.StorageCandidateTooLarge, directory.put(participant(2)));
    try t.expectEqualDeep(original, try directory.commitment());
    try t.expect((try directory.get(2)) == null);
    try directory.put(participant(1));
}

test "transaction preparation requires exact complete membership and original attempt" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var participants = try D.init(t.allocator, objects.objectStore(), identity, .participants, 1000, 1, 1024 * 1024);
    defer participants.deinit();
    try participants.put(participant(1));
    try participants.put(participant(2));
    var reader = participant(3);
    reader.participant.state.access = .read;
    try participants.put(reader);
    const selected = try participants.seal();
    var frozen = attempt(selected);
    frozen.writes = 2;
    var prepared = try D.init(t.allocator, objects.objectStore(), identity, .preparations, 1000, 1, 1024 * 1024);
    defer prepared.deinit();
    try prepared.put(preparation(1, frozen));
    try t.expectError(error.IncompleteTransactionPreparation, participants.requireComplete(&prepared, begin(selected), frozen));
    try prepared.put(preparation(2, frozen));
    try participants.requireComplete(&prepared, begin(selected), frozen);
    var wrong = frozen;
    wrong.workspace.sha256[0] ^= 1;
    try t.expectError(error.TransactionIdentityConflict, participants.requireComplete(&prepared, begin(selected), wrong));
    // Extra preparations, including a read-only participant, cannot commit.
    try prepared.put(preparation(3, frozen));
    try t.expectError(error.IncompleteTransactionPreparation, participants.requireComplete(&prepared, begin(selected), frozen));
}
