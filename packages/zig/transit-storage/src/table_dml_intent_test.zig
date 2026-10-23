const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const f = @import("transit_fuze");
const p = @import("transit_protocol");
const Intent = s.TableDmlIntent;
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .float64, .nullable = false },
};
const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const definition: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} }, .properties = "" };
fn request(stored: s.TableDeclaration.Stored, changes: []const s.TablePartition.Change) Intent.Request {
    return .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = 9 }, .target = object, .action = .update, .expected_definition = stored.interpretation, .expected_data = .{ .partition = 17, .next_lsn = 8 }, .intent = @splat(7) }, .interpretation = stored, .changes = changes, .ingestion = .point };
}

test "frozen Table row work retains exact floating bits and complete expectations on disk" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const bits: u64 = 0x3ff0000000000001;
    const precise = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .float = @bitCast(bits) } } } };
    const negative_zero = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 2 } } }, .{ .value = .{ .atom = .{ .float = -0.0 } } } };
    const changes = [_]s.TablePartition.Change{
        .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &precise }, .expect = .present } },
        .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 1 }, .cells = &negative_zero }, .expect = .present } },
    };
    var retained: p.DataLifecycle.Content = undefined;
    var binding: p.DataLifecycle.Binding = undefined;
    {
        var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
        defer objects.deinit();
        var declaration = try s.TableDeclaration.prepare(t.allocator, definition);
        defer declaration.deinit();
        const work = request(try s.TableDeclaration.stage(objects.objectStore(), &declaration), &changes);
        binding = work.binding;
        retained = try Intent.stage(t.allocator, objects.objectStore(), work);
        try t.expectEqualDeep(retained, try Intent.stage(t.allocator, objects.objectStore(), work));
        var different = work;
        different.binding.expected_data.?.next_lsn += 1;
        try t.expect(!std.meta.eql(retained, try Intent.stage(t.allocator, objects.objectStore(), different)));
        different = work;
        different.binding.action = .delete;
        try t.expectError(error.UnsupportedTableMutationShape, Intent.stage(t.allocator, objects.objectStore(), different));
    }
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(t.allocator, t.io, tmp.dir, "objects");
    defer objects.deinit();
    var restored = try Intent.load(t.allocator, objects.objectStore(), retained);
    defer restored.deinit();
    try t.expectEqualDeep(binding, restored.request.binding);
    try t.expectEqual(bits, @as(u64, @bitCast(restored.request.changes[0].put.row.cells[1].value.atom.float)));
    try t.expectEqual(@as(u64, 0x8000000000000000), @as(u64, @bitCast(restored.request.changes[1].put.row.cells[1].value.atom.float)));
    try t.expectEqualDeep(retained, try Intent.stage(t.allocator, objects.objectStore(), restored.request));
    var key_bytes: [96]u8 = undefined;
    try objects.deleteObject(try Intent.key(retained, &key_bytes));
    try t.expectError(error.TableMutationIntentMissing, Intent.load(t.allocator, objects.objectStore(), retained));
}

test "frozen Table row work rejects foreign definitions with a valid recomputed content digest" {
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    var declaration = try s.TableDeclaration.prepare(t.allocator, definition);
    defer declaration.deinit();
    const work = request(try s.TableDeclaration.stage(objects.objectStore(), &declaration), &.{});
    const original = try Intent.stage(t.allocator, objects.objectStore(), work);
    const bytes = try t.allocator.alloc(u8, @intCast(original.bytes));
    defer t.allocator.free(bytes);
    var key_bytes: [96]u8 = undefined;
    _ = try objects.objectStore().getRange(try Intent.key(original, &key_bytes), 0, @intCast(bytes.len), bytes);
    bytes[8] ^= 1;
    var foreign = original;
    std.crypto.hash.sha2.Sha256.hash(bytes, &foreign.sha256, .{});
    _ = try objects.objectStore().putImmutable(try Intent.key(foreign, &key_bytes), bytes, foreign.sha256);
    try t.expectError(error.IncompatibleDefinition, Intent.load(t.allocator, objects.objectStore(), foreign));
}
