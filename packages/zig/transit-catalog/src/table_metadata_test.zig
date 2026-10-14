const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const Meta = c.TableMetadata;
const Records = c.TableMetadataStore;
const Store = @import("TestStore.zig");
const Pages = c.station.TablePages;
const Pub = c.station.Publication;
const scope: Meta.Scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) };
const schema: c.fuze.TableSchema.Schema = .{ .object = std.math.maxInt(u64), .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int32, .nullable = false },
    .{ .id = 2, .name = "name", .type = .utf8 },
}, .primary_key = &.{1} };
const longest_name: [255]u8 = blk: {
    var bytes: [255]u8 = undefined;
    for (0..85) |i| @memcpy(bytes[i * 3 ..][0..3], "人");
    break :blk bytes;
};
const too_long: [256]u8 = @splat('x');
fn metadata() !Meta.Record {
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    return .{ .scope = scope, .object = schema.object, .revision = 1, .name = try Meta.Name.init("people"), .schema = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, try schema.encode(&bytes)) }, .schema_fingerprint = try schema.fingerprint(), .principal = 17, .operation = std.math.maxInt(u64), .admitted_input = 1 };
}
fn count(turn: c.station.Turn) usize {
    var total: usize = 0;
    for (turn.decision.mutations) |slot| total += @intFromBool(slot != null);
    return total;
}
test "general metadata owns UTF-8 names and complete immutable schema references" {
    const record = try metadata();
    var bytes: [Meta.max_bytes]u8 = undefined;
    const encoded = try record.encode(&bytes);
    const decoded = try Meta.Record.decode(encoded);
    try t.expectEqualDeep(record, decoded);
    @memset(bytes[0..encoded.len], 0);
    try t.expectEqualStrings("people", decoded.name.slice());
    var longest = record;
    longest.name = try Meta.Name.init(&longest_name);
    const full = try longest.encode(&bytes);
    try t.expectEqual(@as(usize, Meta.max_bytes), full.len);
    try t.expectEqualDeep(longest, try Meta.Record.decode(full));
    inline for (.{ "", &too_long, "bad\x00name", "\xff" }) |invalid| try t.expectError(error.InvalidCatalogName, Meta.Name.init(invalid));
    const upper = try Meta.Name.init("People");
    try t.expect(!record.name.eql(&upper));
    try t.expect(!std.mem.eql(u8, &try record.name.digest(), &try upper.digest()));
    const collision: [32]u8 = @splat(3);
    const first = try Meta.nameKey(scope.catalog, collision, 1);
    const second = try Meta.nameKey(scope.catalog, collision, std.math.maxInt(u64));
    try t.expectEqual(@as(usize, 32), first.len);
    try c.protocol.State.key(first);
    try c.protocol.State.key(second);
    try t.expectEqual(.lt, std.mem.order(u8, first.slice(), second.slice()));
    try t.expectEqualSlices(u8, first.data[0..24], second.data[0..24]);
}
test "general catalog metadata matches independent Python layouts" {
    const Fixture = struct { definition: []const u8, record_hex: []const u8, name_digest_hex: []const u8, name_key_hex: []const u8, manifest_hex: []const u8, command_header_hex: []const u8, rename_command_hex: []const u8, upload_status_hex: []const u8, rename_intent_hex: []const u8, inline_key_hex: []const u8, controls: struct { configuration: []const u8, object: []const u8, operation: []const u8, restricted: []const u8, dependency: []const u8 } };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-metadata.json"), .{});
    defer parsed.deinit();
    const expected = parsed.value;
    try t.expectEqualStrings(@tagName(c.protocol.Growth.current_definition), expected.definition);
    var record = try metadata();
    record.revision = 3;
    record.schema = .{ .id = 7, .spec = .{ .format = Pages.schema_format, .length = 120, .digest = @splat(17) } };
    record.schema_fingerprint = @splat(34);
    record.admitted_input = 5;
    var buffer: [Meta.max_bytes]u8 = undefined;
    try expectHex(expected.record_hex, try record.encode(&buffer));
    try expectHex(expected.name_digest_hex, &try record.name.digest());
    try expectHex(expected.name_key_hex, (try Meta.nameKey(scope.catalog, try record.name.digest(), record.object)).slice());
    try expectHex(expected.inline_key_hex, Records.key(record.object, 'i', record.revision).slice());
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture(17);
    const records: Records = .{ .scope = scope, .object = record.object };
    try records.create(&turn);
    try expectHex(expected.manifest_hex, (try turn.read(Records.key(record.object, 'd', 0))).?.slice());
    const m = c.TableCatalogRecords;
    const reference: Records.Reference = .{ .id = 3, .spec = .{ .format = Meta.format, .length = 195, .digest = @splat(51) } };
    const configuration: m.Configuration = .{ .scope = scope, .owner = 3, .administrator = 17, .authority = @import("TestStore.zig").profile, .table_limits = .{ .record_bytes = 4096, .staging_bytes = 8192, .staging_records = 2 } };
    const object: m.Object = .{ .scope = scope, .object = record.object, .namespace = 1, .authorization = 100, .state = .live, .metadata = reference, .next_revision = 4 };
    const operation: m.Operation = .{ .scope = scope, .principal = 17, .operation = std.math.maxInt(u64), .object = record.object, .actual_object = record.object, .digest = @splat(68), .kind = .rename, .state = .applied, .metadata = reference, .admitted_input = 5, .completed_input = 7 };
    var restricted = operation;
    restricted.kind = .drop;
    restricted.state = .rejected;
    restricted.reason = .dependency;
    restricted.metadata = m.empty_reference;
    restricted.blocker = .{ .dependency = .{ .identity = std.math.maxInt(u64), .owner = 4, .kind = .writer } };
    const dependency: m.Dependency = .{ .scope = scope, .object = record.object, .identity = 15, .owner = 4, .kind = .query_source };
    inline for (.{ "configuration", "object", "operation", "restricted", "dependency" }, .{ 'C', 'O', 'R', 'R', 'B' }, .{ configuration, object, operation, restricted, dependency }) |name, tag, value| {
        const encoded = try c.Records.encode(tag, value);
        try expectHex(@field(expected.controls, name), encoded.slice());
        try t.expectEqualDeep(value, try c.Records.decode(@TypeOf(value), tag, encoded));
        for (0..encoded.len) |length| {
            if (c.Records.decode(@TypeOf(value), tag, try c.protocol.Value.init(encoded.data[0..length]))) |_| return error.AcceptedTruncation else |_| {}
        }
        var foreign = encoded;
        foreign.data[5] ^= 1;
        try t.expectError(error.IncompatibleDefinition, c.Records.decode(@TypeOf(value), tag, foreign));
    }
}
fn expectHex(text: []const u8, bytes: []const u8) !void {
    var buffer: [Meta.max_bytes]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&buffer, text), bytes);
}
test "metadata encodings reject truncation foreign definitions and malformed identities" {
    const record = try metadata();
    var buffer: [Meta.max_bytes + 1]u8 = undefined;
    const bytes = try record.encode(&buffer);
    for (0..bytes.len) |length| {
        if (Meta.Record.decode(bytes[0..length])) |_| return error.AcceptedTruncation else |_| {}
    }
    buffer[bytes.len] = 0;
    try t.expectError(error.InvalidCatalogDefinition, Meta.Record.decode(buffer[0 .. bytes.len + 1]));
    buffer[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Meta.Record.decode(bytes));
    var invalid = record;
    invalid.schema.spec.format = 0;
    try t.expectError(error.InvalidCatalogDefinition, invalid.encode(&buffer));
    invalid = record;
    invalid.admitted_input = 0;
    try t.expectError(error.InvalidCatalogDefinition, invalid.encode(&buffer));
}
test "metadata staging resumes large names and refuses same-revision content changes" {
    var store: Store = .{};
    defer store.deinit();
    const records: Records = .{ .scope = scope, .object = schema.object };
    var turn = try store.capture(17);
    try records.create(&turn);
    try t.expectEqual(@as(usize, 2), count(turn));
    try store.commit(turn);
    var record = try metadata();
    turn = try store.capture(17);
    try t.expectEqual(.ready, try records.stage(&turn, record));
    try t.expectEqual(@as(usize, 1), count(turn));
    const original_ref: Records.Reference = .{ .id = record.revision, .spec = try record.spec() };
    try t.expectEqualDeep(record, try records.read(&turn, original_ref));
    try store.commit(turn);
    var renamed = record;
    renamed.revision = 2;
    renamed.name = try Meta.Name.init(&longest_name);
    const next_ref: Records.Reference = .{ .id = renamed.revision, .spec = try renamed.spec() };
    for (0..8) |_| {
        var lost = try store.capture(17);
        _ = try records.stage(&lost, renamed);
        turn = try store.capture(17);
        const result = try records.stage(&turn, renamed);
        try t.expect(count(turn) <= 4);
        if (result == .ready) try t.expectError(error.PublicationReadAfterMutation, records.read(&turn, next_ref));
        try store.commit(turn);
        if (result == .ready) break;
    }
    turn = try store.capture(17);
    try t.expectEqualDeep(renamed, try records.read(&turn, next_ref));
    try t.expectEqualDeep(record, try records.read(&turn, original_ref));
    try t.expectEqual(@as(u32, 0), (try (Pub{ .resource = scope.resource, .domain = .catalog, .namespace = schema.object }).budget(&turn)).records);
    record.name = try Meta.Name.init("changed");
    try t.expectError(error.CatalogIdentityConflict, records.stage(&turn, record));
    renamed.name = record.name;
    try t.expectError(error.CatalogIdentityConflict, records.stage(&turn, renamed));
    try t.expectEqual(@as(usize, 0), count(turn));
    var wrong = next_ref;
    wrong.spec.digest[0] ^= 1;
    try t.expectError(error.CatalogDefinitionChanged, records.read(&turn, wrong));
}
fn schemaReadAllocation(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    const record = try metadata();
    var turn = try store.capture(17);
    const pages = try Pages.create(&turn, schema.object, .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = c.fuze.TableRow.max_bytes, .staging_records = 1 });
    try store.commit(turn);
    var buffer: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    const bytes = try schema.encode(&buffer);
    for (0..10) |_| {
        turn = try store.capture(17);
        const result = try pages.stage(&turn, record.schema, bytes);
        try store.commit(turn);
        if (result == .ready) break;
    }
    turn = try store.capture(17);
    var owned = try record.readSchema(allocator, &turn);
    defer owned.deinit();
    try t.expectEqual(try schema.fingerprint(), try owned.schema.fingerprint());
    var wrong = record;
    wrong.schema_fingerprint[0] ^= 1;
    try t.expectError(error.CatalogDefinitionChanged, wrong.readSchema(t.allocator, &turn));
}
test "metadata schema reads own their values and release every failed allocation" {
    try t.checkAllAllocationFailures(t.allocator, schemaReadAllocation, .{});
}
test "metadata manifests refuse orphan adoption scope drift and poisoned reads" {
    var store: Store = .{};
    defer store.deinit();
    const records: Records = .{ .scope = scope, .object = schema.object };
    var turn = try store.capture(17);
    try records.create(&turn);
    try store.commit(turn);
    turn = try store.capture(17);
    try records.create(&turn);
    try t.expectEqual(@as(usize, 0), count(turn));
    var wrong = records;
    wrong.scope.catalog = 1;
    try t.expectError(error.IncompatibleDefinition, wrong.create(&turn));
    turn.view.resource = 8;
    try t.expectError(error.CrossResourceTransaction, records.create(&turn));
    turn = try store.capture(17);
    store.fail_at = store.reads + 1;
    try t.expectError(error.Unavailable, records.stage(&turn, try metadata()));
    try t.expectError(error.Unavailable, turn.validate());
    store.fail_at = null;
    _ = store.state.remove(Records.key(schema.object, 'd', 0));
    turn = try store.capture(17);
    try t.expectError(error.CatalogAlreadyPopulated, records.create(&turn));
    try t.expectEqual(@as(usize, 0), count(turn));
}
