const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const m = q.fuze.Unified;
const Definition = q.SourceDefinition;
fn pageSource(definition: Definition, basis: q.Basis, cursor: q.UnifiedSource.Cursor, data: anytype, current: anytype, allocator: std.mem.Allocator, batch: *q.UnifiedSource.Batch) !void {
    var fields: [Definition.max_columns]q.fuze.Types.Field = undefined;
    const plan: q.fuze.LogicalQuery.Plan = .{ .schema = try (try definition.schema(&fields)).cloneInto(allocator), .source_basis = try basis.fingerprint(), .projection = &.{0} };
    return q.UnifiedSource.page(definition, plan, basis, cursor, data, current, if (definition.source == .table) 17 else null, allocator, batch);
}
test "declared KV decoders retain full values and distinguish malformed bytes" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const d = q.Decoder.decode;
    try t.expectEqual(std.math.minInt(i64), (try d(.{ .type = .int64 }, allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 128 })).value.int64);
    try t.expectEqual(std.math.maxInt(u64), (try d(.{ .type = .uint64 }, allocator, &.{ 255, 255, 255, 255, 255, 255, 255, 255 })).value.uint64);
    try t.expectEqual(@as(u64, 1 << 63), @as(u64, @bitCast((try d(.{ .type = .float64 }, allocator, &.{ 0, 0, 0, 0, 0, 0, 0, 128 })).value.float64)));
    try t.expectEqualStrings("🙂", (try d(.{ .type = .utf8 }, allocator, "🙂")).value.utf8);
    try t.expectEqualSlices(u8, &.{ 0, 255 }, (try d(.{ .type = .binary }, allocator, &.{ 0, 255 })).value.binary);
    try t.expect((try d(.{ .type = .utf8 }, allocator, "")).value.utf8.len == 0);
    try t.expect((try d(.{ .type = .boolean }, allocator, &.{0})).value.boolean == false);
    for ([_]m.Type{ .int64, .uint64, .float64, .boolean }) |data_type| try t.expect((try d(.{ .type = data_type }, allocator, "")) == .type_error);
    try t.expect((try d(.{ .type = .utf8 }, allocator, "\xff")) == .type_error);
    try t.expect((try d(.{ .type = .boolean }, allocator, &.{2})) == .type_error);
    try t.expect((try d(.{ .type = .float64 }, allocator, &.{ 0, 0, 0, 0, 0, 0, 240, 127 })) == .type_error);
    try t.expectError(error.UnsupportedDecoder, d(.{ .version = 2, .type = .binary }, allocator, ""));
}
test "UQS1 binds decoder versions exact Document references and projection budgets" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var output: [Definition.max_bytes]u8 = undefined;
    const kv: Definition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = try q.protocol.Value.init("data/"), .key = .{ .type = .binary }, .value = .{ .type = .uint64 } } } };
    const expected = "UQS1" ++ q.catalog.TableMetadata.definition() ++ "\x07\x00\x00\x00\x00\x00\x00\x00\x01\x05data/\x01\x06\x01\x02";
    try t.expectEqualSlices(u8, expected, try kv.encode(&output));
    try t.expectEqualSlices(u8, &try kv.fingerprint(), &try (try Definition.decode(allocator, expected)).fingerprint());
    var fixture = try @import("direct_query_fixture_test.zig").init(t.allocator, .captured, false);
    defer fixture.deinit();
    const prepared = fixture.bundle.sources[0];
    const table: Definition = .{ .resource = prepared.scope.resource, .source = .{ .table = prepared } };
    const projections = [_]Definition.Projection{
        .{ .column = .{ .name = try m.Name.init("title"), .type = .utf8 }, .path = &.{try q.document.Model.Name.init("title")} },
        .{ .column = .{ .name = try m.Name.init("body"), .type = .utf8 }, .path = &.{try q.document.Model.Name.init("body")}, .mode = .text },
    };
    const document: Definition = .{ .resource = 7, .source = .{ .document = .{ .reference = .{ .resource = 7, .document = std.math.maxInt(u64), .epoch = 3, .type_revision = 1, .revision = 42 }, .projections = &projections } } };
    for ([_]Definition{ kv, table, document }) |definition| {
        const bytes = try definition.encode(&output);
        const decoded = try Definition.decode(allocator, bytes);
        try t.expectEqualSlices(u8, &try definition.fingerprint(), &try decoded.fingerprint());
        for (0..bytes.len) |length| {
            if (Definition.decode(allocator, bytes[0..length])) |_| return error.AcceptedTruncatedDefinition else |_| {}
        }
        output[bytes.len] = 0;
        try t.expectError(error.InvalidSourceEncoding, Definition.decode(allocator, output[0 .. bytes.len + 1]));
    }
    var changed = document;
    changed.source.document.reference.revision += 1;
    try t.expect(!std.mem.eql(u8, &try changed.fingerprint(), &try document.fingerprint()));
    changed.source.document.reference.resource = 8;
    try t.expectError(error.UnsupportedDocumentSource, changed.encode(&output));
    changed = kv;
    changed.source.kv.value.version = 2;
    try t.expectError(error.UnsupportedDecoder, changed.encode(&output));
}

test "KV adapters page exact cuts and reject source or decoder substitution" {
    const Memory = @import("source_store_test.zig");
    const source = q.UnifiedSource;
    var store: Memory = .{};
    defer store.deinit();
    for (0..40) |index| {
        var turn = try store.capture();
        var key_bytes: [4]u8 = .{ 'a', 'b', 0, @intCast(index) };
        if (index == 0) key_bytes[0] = 'a' - 1;
        if (index == 39) key_bytes[0] = 'a' + 1;
        var value: [8]u8 = undefined;
        std.mem.writeInt(u64, &value, std.math.maxInt(u64) - index, .little);
        try turn.write(try q.protocol.Value.init(&key_bytes), try q.protocol.Value.init(if (index == 3) &.{255} else &value));
        try store.commit(turn);
    }
    const definition: Definition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = try q.protocol.Value.init("ab"), .key = .{ .type = .binary }, .value = .{ .type = .uint64 } } } };
    var data = try store.capture();
    const cut = try source.basis(definition, data.view.revision);
    var cursor: source.Cursor = .{};
    var count: usize = 0;
    var errors: usize = 0;
    while (!cursor.done) {
        var arena = std.heap.ArenaAllocator.init(t.allocator);
        defer arena.deinit();
        var batch: source.Batch = .{};
        try pageSource(definition, cut, cursor, &data, &data, arena.allocator(), &batch);
        for (batch.engine().rows) |row| {
            count += 1;
            try t.expectEqual(@as(u8, @intCast(count)), row.cells[0].value.atom.bytes[3]);
            if (row.cells[1] == .type_error) errors += 1 else try t.expectEqual(std.math.maxInt(u64) - count, row.cells[1].value.atom.unsigned);
        }
        cursor = batch.next;
        batch.deinit();
    }
    try t.expectEqual(@as(usize, 38), count);
    try t.expectEqual(@as(usize, 1), errors);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var batch: source.Batch = .{};
    var changed = definition;
    changed.source.kv.value.type = .binary;
    try t.expectError(error.SourceChanged, pageSource(changed, cut, .{}, &data, &data, arena.allocator(), &batch));
    store.denied = true;
    try t.expectError(error.AccessDenied, pageSource(definition, cut, .{}, &data, &data, arena.allocator(), &batch));
    store.denied = false;
}

pub fn changeDocument(store: *@import("source_store_test.zig"), service: q.document.Service, job: u64, replica: u64, first: u64, operations: []const q.document.Operation) !void {
    var change: q.document.Change = .{ .document = service.document, .epoch = 1, .replica = replica, .previous = if (replica == 1) first - 1 else 0, .first = first, .len = @intCast(operations.len) };
    @memcpy(change.operations[0..operations.len], operations);
    var turn = try store.capture();
    _ = try service.prepare(&turn, job, change, 512);
    try store.commit(turn);
    for (0..32) |_| {
        turn = try store.capture();
        const complete = try service.upload(&turn, job, change);
        try store.commit(turn);
        if (complete) break;
    } else return error.UploadIncomplete;
    for (0..10000) |_| {
        turn = try store.capture();
        const result = try service.advance(&turn, job);
        try store.commit(turn);
        if (result != .progress) return;
    }
    return error.ChangeIncomplete;
}

// Acquire exactly the production current-metadata key set from the reference
// store. Batch.read refuses any additional lookup, including payload access.
fn currentMetadata(store: *@import("source_store_test.zig"), definition: Definition) !q.wire.ResourceReader.Batch {
    var client: q.UnifiedClient = .{
        .wire = undefined,
        .key = undefined,
        .connection = .{ .realm = 1, .principal = 2, .source = store.pid, .resource = store.resource, .requester = 9, .requests = 10 },
    };
    const request = (try client.interactiveMetadata(definition))[0].?;
    var result: q.wire.ResourceReader.Batch = .{
        .resource = .{ .id = store.resource, .writer = store.pid, .owner = null, .revision = store.revision, .deadline_ms = null },
        .view = .{ .resource = store.resource, .revision = store.revision },
        .keys = request.keys,
        .entries = @splat(null),
    };
    var turn = try store.capture();
    for (request.keys, 0..) |slot, i| if (slot) |key| {
        if (try turn.read(key)) |value| result.entries[i] = .{ .key = key, .value = value, .revision = store.revisions.get(key).? };
    };
    return result;
}
test "accepted Document paths text conflicts and list pages retain live lifecycle checks" {
    const Memory = @import("source_store_test.zig");
    const source = q.UnifiedSource;
    const d = q.document.Model;
    var store: Memory = .{};
    defer store.deinit();
    const service: q.document.Service = .{ .resource = 7, .document = 17 };
    var turn = try store.capture();
    try service.create(&turn, 1, .{ .record_bytes = 4096, .staging_bytes = 4096, .staging_records = 1 });
    try store.commit(turn);
    try changeDocument(&store, service, 1, 1, 1, &.{
        .{ .assign = .{ .field = try d.Name.init("items"), .value = .list } },
        .{ .assign = .{ .field = try d.Name.init("body"), .value = .text } },
        .{ .insert = .{ .object = .{ .counter = 2, .replica = 1 }, .value = .{ .character = 0x1f642 } } },
        .{ .assign = .{ .field = try d.Name.init("title"), .value = .{ .string = try d.Bytes.init("first") } } },
        .{ .assign = .{ .field = try d.Name.init("optional"), .value = .null_value } },
        .{ .assign = .{ .field = try d.Name.init("nested"), .value = .map } },
        .{ .assign = .{ .object = .{ .counter = 6, .replica = 1 }, .field = try d.Name.init("child"), .value = .{ .unsigned = std.math.maxInt(u64) } } },
        .{ .assign = .{ .field = try d.Name.init("wrong"), .value = .{ .boolean = true } } },
    });
    var operations: [8]q.document.Operation = undefined;
    for (&operations, 0..) |*operation, index| operation.* = .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = if (index == 0) .root else .{ .counter = 8 + index, .replica = 1 }, .value = .{ .signed = @intCast(index) } } };
    try changeDocument(&store, service, 2, 1, 9, &operations);
    for (operations[0..4], 0..) |*operation, index| operation.* = .{ .insert = .{ .object = .{ .counter = 1, .replica = 1 }, .after = .{ .counter = 16 + index, .replica = 1 }, .value = .{ .signed = @intCast(8 + index) } } };
    try changeDocument(&store, service, 3, 1, 17, operations[0..4]);
    try changeDocument(&store, service, 4, 2, 9, &.{.{ .assign = .{ .field = try d.Name.init("title"), .value = .{ .string = try d.Bytes.init("second") } } }});
    var snapshot_store = try store.clone();
    defer snapshot_store.deinit();
    var snapshot = try snapshot_store.capture();
    var current = try store.capture();
    const reference: q.document.Client.Reference = .{ .resource = 7, .document = 17, .epoch = 1, .type_revision = 1, .revision = 4 };
    var projections = [_]Definition.Projection{
        .{ .column = .{ .name = try m.Name.init("missing"), .type = .utf8 }, .path = &.{try d.Name.init("absent")} },
        .{ .column = .{ .name = try m.Name.init("optional"), .type = .utf8 }, .path = &.{try d.Name.init("optional")} },
        .{ .column = .{ .name = try m.Name.init("wrong"), .type = .utf8 }, .path = &.{try d.Name.init("wrong")} },
        .{ .column = .{ .name = try m.Name.init("title"), .type = .utf8 }, .path = &.{try d.Name.init("title")} },
        .{ .column = .{ .name = try m.Name.init("body"), .type = .utf8 }, .path = &.{try d.Name.init("body")}, .mode = .text },
        .{ .column = .{ .name = try m.Name.init("child"), .type = .uint64 }, .path = &.{ try d.Name.init("nested"), try d.Name.init("child") } },
    };
    var definition: Definition = .{ .resource = 7, .source = .{ .document = .{ .reference = reference, .projections = &projections } } };
    var metadata = try currentMetadata(&store, definition);
    try source.checkCurrent(definition, &metadata, null);
    var foreign = definition;
    foreign.source.document.reference.epoch += 1;
    try t.expectError(error.DocumentIdentityMismatch, source.checkCurrent(foreign, &metadata, null));
    var incomplete = metadata;
    incomplete.keys[2] = null;
    try t.expectError(error.UnrequestedResourceKey, source.checkCurrent(definition, &incomplete, null));
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var batch: source.Batch = .{};
    try pageSource(definition, try source.basis(definition, snapshot.view.revision), .{}, &snapshot, &current, arena.allocator(), &batch);
    const row = batch.engine().rows[0];
    try t.expect(row.cells[0] == .missing);
    try t.expect(row.cells[1] == .null);
    try t.expectEqual(q.fuze.Types.Kind.boolean, row.cells[2].type_error);
    try t.expectEqual(@as(usize, 2), row.cells[3].conflict.len);
    try t.expectEqualStrings("first", row.cells[3].conflict[0].value.value.atom.bytes);
    try t.expectEqualStrings("second", row.cells[3].conflict[1].value.value.atom.bytes);
    try t.expectEqualStrings("🙂", row.cells[4].value.atom.bytes);
    try t.expectEqual(std.math.maxInt(u64), row.cells[5].value.atom.unsigned);
    batch.deinit();
    projections[4].text_bytes = 3;
    try t.expectError(error.QueryProjectionBudget, pageSource(definition, try source.basis(definition, snapshot.view.revision), .{}, &snapshot, &current, arena.allocator(), &batch));
    projections[4].text_bytes = 4096;
    const list_projections = [_]Definition.Projection{
        .{ .column = .{ .name = try m.Name.init("element"), .type = .int64 }, .path = &.{}, .relative = true },
        .{ .column = .{ .name = try m.Name.init("counter"), .type = .uint64 }, .path = &.{}, .relative = true, .mode = .element_counter },
    };
    definition.source.document.expand = &.{try d.Name.init("items")};
    definition.source.document.projections = &list_projections;
    const cut = try source.basis(definition, snapshot.view.revision);
    var cursor: source.Cursor = .{};
    var count: usize = 0;
    while (!cursor.done) {
        try pageSource(definition, cut, cursor, &snapshot, &current, arena.allocator(), &batch);
        for (batch.engine().rows) |element| {
            try t.expectEqual(@as(i64, @intCast(count)), element.cells[0].value.atom.signed);
            try t.expectEqual(@as(u64, 9 + count), element.cells[1].value.atom.unsigned);
            count += 1;
        }
        cursor = batch.next;
        batch.deinit();
    }
    try t.expectEqual(@as(usize, 12), count);
    store.denied = true;
    current = try store.capture();
    try t.expectError(error.AccessDenied, currentMetadata(&store, definition));
    try t.expectError(error.AccessDenied, pageSource(definition, cut, .{}, &snapshot, &current, arena.allocator(), &batch));
    store.denied = false;
    turn = try store.capture();
    try service.configureMergeWindow(&turn, 1);
    try store.commit(turn);
    turn = try store.capture();
    try q.document.Checkpoint.begin(service, &turn, 90);
    try store.commit(turn);
    for (0..10000) |_| {
        turn = try store.capture();
        const result = try q.document.Checkpoint.step(service, &turn, 90);
        try store.commit(turn);
        if (result == .complete) break;
    } else return error.CheckpointIncomplete;
    current = try store.capture();
    try t.expectError(error.DocumentHistoryGap, pageSource(definition, cut, .{}, &snapshot, &current, arena.allocator(), &batch));
    metadata = try currentMetadata(&store, definition);
    try t.expectError(error.DocumentHistoryGap, source.checkCurrent(definition, &metadata, null));
    turn = try store.capture();
    try service.retire(&turn);
    try store.commit(turn);
    current = try store.capture();
    try t.expectError(error.DocumentRetired, pageSource(definition, cut, .{}, &snapshot, &current, arena.allocator(), &batch));
    metadata = try currentMetadata(&store, definition);
    try t.expectError(error.DocumentRetired, source.checkCurrent(definition, &metadata, null));
}

test "independent UQS1 fixtures preserve all three source declarations" {
    const Case = struct { kind: []const u8, wire_hex: []const u8, digest: []const u8 };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = try std.json.parseFromSlice([]const Case, allocator, @embedFile("fixtures/sources.json"), .{});
    for (fixture.value) |item| {
        var bytes: [Definition.max_bytes]u8 = undefined;
        const encoded = try std.fmt.hexToBytes(&bytes, item.wire_hex);
        const definition = try Definition.decode(allocator, encoded);
        try t.expectEqualStrings(item.kind, @tagName(definition.source));
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, item.digest);
        try t.expectEqualSlices(u8, &expected, &try definition.fingerprint());
    }
}

// Direct Table page, exact-interpretation and predicate checks run against the
// public service in tests/direct_table_predicates.zig and direct_captured_query.zig.
