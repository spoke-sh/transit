const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const D = s.LogDeclaration;
const support = @import("log_test_support.zig");

test "log declarations bind schema policy and catalog properties across disk reopen" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var stored: D.Stored = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "declaration");
        defer objects.deinit();
        var owned = try D.prepare(t.allocator, support.definition(.queue));
        defer owned.deinit();
        stored = try D.stage(objects.objectStore(), &owned);
        try t.expectEqualStrings("LDECL001", owned.bytes[0..8]);
        try t.expectEqual(@as(u64, 4), std.mem.readInt(u64, owned.bytes[72..80], .big));
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "declaration");
    defer objects.deinit();
    var loaded = try D.load(t.allocator, objects.objectStore(), stored);
    defer loaded.deinit();
    try t.expectEqualDeep(stored, try loaded.stored());
    try t.expectEqualStrings("catalog-owned-properties", loaded.definition.properties);
    try t.expectEqualStrings("key", loaded.schema.schema.columns[0].name);
    try t.expectEqual(.ascii_ci, loaded.schema.schema.columns[0].collation);
    var foreign = stored;
    foreign.declaration.configuration.policy.queue.lease_ms += 1;
    try t.expectError(error.InvalidLogDeclaration, D.load(t.allocator, objects.objectStore(), foreign));
    foreign = stored;
    foreign.declaration.schema.sha256[0] ^= 1;
    try t.expectError(error.InvalidLogDeclaration, D.load(t.allocator, objects.objectStore(), foreign));
    var name: [96]u8 = undefined;
    try objects.objectStore().delete(try D.key(stored.content, &name));
    try t.expectError(error.LogDeclarationMissing, D.load(t.allocator, objects.objectStore(), stored));
}

test "log declarations reject undefined nullable keys relational uniqueness and foreign DLQ" {
    var definition = support.definition(.stream);
    definition.configuration.partitioning.key_column = 3;
    try t.expectError(error.UnknownColumn, definition.validate());
    definition = support.definition(.queue);
    var columns = definition.schema.columns[0..2].*;
    columns[0].nullable = true;
    definition.schema.columns = &columns;
    try t.expectError(error.InvalidLogKeyColumn, definition.validate());
    definition = support.definition(.stream);
    definition.schema.primary_key = &.{1};
    try t.expectError(error.UnsupportedLogPrimaryKey, definition.validate());
    definition = support.definition(.queue);
    definition.configuration.policy.queue.dead_letter = .{ .object = definition.object, .revision = 1, .digest = @splat(1) };
    try t.expectError(error.InvalidQueueDestination, definition.validate());
}
