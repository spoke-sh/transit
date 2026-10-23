const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const f = c.fuze;
const w = c.DirectTableProtocol;
const I = c.DirectTableIntent;
const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = std.math.maxInt(u64) }, .branch = 1, .audience = 5, .principal = 4, .role = null };
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .uint64, .nullable = false },
    .{ .id = 2, .name = "payload", .type = .binary },
};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
test "direct saved intent consumes independent Python canonical bytes" {
    const Fixture = struct { saved: I.Saved, base64: []const u8 };
    const fixture = try c.protocol.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-intent-v1.json"));
    defer fixture.deinit();
    const bytes = try (w.Binary{ .base64 = fixture.value.base64 }).decode(t.allocator, I.max_bytes);
    defer t.allocator.free(bytes);
    var restored = try I.restore(t.allocator, bytes);
    defer restored.deinit();
    try t.expectEqualDeep(fixture.value.saved, restored.parsed.value);
    try t.expectEqual(std.math.maxInt(u64), restored.binding().identity.operation);
}
fn metadata(allocator: std.mem.Allocator) !w.Definition {
    var scratch: [f.TableSchema.max_bytes]u8 = undefined;
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 11, .name = try .init("events") };
    var declaration = try c.storage.TableDeclaration.prepare(allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = try properties.encode(&scratch) });
    defer declaration.deinit();
    return .{ .interpretation = try declaration.stored(), .namespace = 1, .authorization = 11, .name = properties.name, .position = .{ .partition = 9, .next_lsn = 10 }, .changed_lsn = 10, .row_count = 0, .schema = try w.Binary.encode(allocator, try schema.encode(&scratch)) };
}
test "saved direct INSERT owns binary operands and derives caller row identity before admission" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const selected = try metadata(arena.allocator());
    var first = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } }, .{ .value = .{ .atom = .{ .bytes = "\x00\xff" } } } };
    const second = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .unsigned = 0 } } }, .null };
    const plan: f.TableDml.Plan = .{ .name = "events", .schema = schema, .action = .{ .insert = &.{ &first, &second } } };
    var intent = try I.fromDml(t.allocator, connection, selected, std.math.maxInt(u64), plan, .point);
    defer intent.deinit();
    first[1] = .null;
    var restored = try I.restore(t.allocator, intent.bytes);
    defer restored.deinit();
    try t.expectEqualSlices(u8, intent.bytes, restored.bytes);
    try t.expectEqualDeep(intent.binding(), restored.binding());
    try t.expect(restored.binding().expected_data == null);
    const rows = try restored.parsed.value.work.rows.native(arena.allocator());
    try t.expectEqualDeep((f.TableRow.Identity{ .origin = 5, .operation = std.math.maxInt(u64), .ordinal = 0 }), rows.changes[0].put.row.identity);
    try t.expectEqual(@as(u64, 1), rows.changes[1].put.row.identity.ordinal);
    try t.expectEqualStrings("\x00\xff", rows.changes[0].put.row.cells[1].value.atom.bytes);
    try t.expectEqual(std.math.maxInt(u64), rows.changes[0].put.row.cells[0].value.atom.unsigned);
    try t.expect(rows.changes[1].put.row.cells[1] == .null);
    var other = connection;
    other.role = 0;
    try t.expectError(error.CatalogIdentityConflict, restored.check(other));
    other = connection;
    other.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, restored.check(other));
    try t.expectError(error.InvalidDataOperation, I.fromDml(t.allocator, connection, selected, 0, plan, .point));
}
test "saved direct predicate work retains its bound parameters and original data frontier" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const selected = try metadata(arena.allocator());
    var intent: I = undefined;
    {
        var template = try f.TableDmlPrepared.init(t.allocator, "UPDATE events SET payload = $1 WHERE id = $2", "events", schema, .transit, null);
        defer template.deinit();
        var bound = try template.bind(t.allocator, "events", schema, &.{ .{ .bytes = "\x00\xff" }, .{ .unsigned = 42 } }, null);
        defer bound.deinit();
        intent = try I.fromDml(t.allocator, connection, selected, 8, bound.plan, .bulk);
    }
    defer intent.deinit();
    var restored = try I.restore(t.allocator, intent.bytes);
    defer restored.deinit();
    try t.expectEqualDeep(selected.position, restored.binding().expected_data.?);
    const work = try restored.parsed.value.work.statement.native(arena.allocator());
    try t.expect(try work.statement.?.matches(&.{ .{ .value = .{ .atom = .{ .unsigned = 42 } } }, .null }));
    try t.expect(!try work.statement.?.matches(&.{ .{ .value = .{ .atom = .{ .unsigned = 41 } } }, .null }));
    try t.expectEqualStrings("\x00\xff", work.statement.?.action.update[0].value.cell.value.atom.bytes);
    var altered = restored.parsed.value;
    altered.work.statement.binding.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, I.create(t.allocator, connection, altered.work));
}
test "direct saved work rejects incompatible missing noncanonical and truncated envelopes" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var intent = try I.fromDml(t.allocator, connection, try metadata(alloc), 8, .{ .name = "events", .schema = schema, .action = .delete }, .bulk);
    defer intent.deinit();
    for ([_]usize{ 0, 1, 4, 35, 36, intent.bytes.len - 1 }) |length| {
        if (I.restore(t.allocator, intent.bytes[0..length])) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.ExpectedTruncationFailure;
        } else |_| {}
    }
    const corrupted = try alloc.dupe(u8, intent.bytes);
    corrupted[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, I.restore(t.allocator, corrupted));
    const noncanonical = try std.mem.concat(alloc, u8, &.{ intent.bytes, " " });
    try t.expectError(error.InvalidTableIntent, I.restore(t.allocator, noncanonical));
    const missing = try c.protocol.Json.valueAlloc(alloc, .{ .connection = connection, .work = intent.parsed.value.work });
    const absent = try std.mem.concat(alloc, u8, &.{ intent.bytes[0..I.prefix_bytes], missing });
    try t.expectError(error.MissingField, I.restore(t.allocator, absent));
    // DDL carries the same mandatory binding and uses the owning intent digest.
    var ddl: w.Ddl = .{ .binding = intent.binding(), .namespace = 1, .name = "events", .action = .drop };
    ddl.binding.action = .drop;
    ddl.binding.intent = try ddl.digest(alloc);
    var saved = try I.create(t.allocator, connection, .{ .ddl = ddl });
    defer saved.deinit();
    var recovered = try I.restore(t.allocator, saved.bytes);
    defer recovered.deinit();
    try t.expectEqualDeep(saved.binding(), recovered.binding());
}
