const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const s = c.station;
const Upload = c.TableUpload;
const Command = c.TableCommand;
const TestStore = @import("TestStore.zig");
const catalog: c.TableCatalog = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .database_name = c.TableAuthority.Name.init("test") catch unreachable, .authority = @import("TestStore.zig").profile, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = c.fuze.TableRow.max_bytes * 2, .staging_records = 2 } } };
const uploads: Upload = .{ .catalog = catalog };
fn ready(store: *TestStore) !void {
    var turn = try store.capture(17);
    try catalog.initialize(&turn);
    try store.commit(turn);
}
fn request() !c.TableDdlRequest {
    return .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = .{ .object = 100, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64 }, .{ .id = 2, .name = "name", .type = .utf8 } }, .primary_key = &.{} } } } };
}
fn command(buffer: []u8) ![]const u8 {
    return Command.encode(t.allocator, try Command.fromDdl(catalog.configuration.scope, catalog.configuration.owner, try request(), null), buffer);
}
fn selfTurn(store: *TestStore, pid: u64) !s.Turn {
    var turn = try store.capture(17);
    turn.delivery.input.origin = .{ .process = .{ .pid = pid, .turn = 1, .output = 0 } };
    return turn;
}
fn writes(turn: s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn stage(store: *TestStore, namespace: u64, bytes: []const u8) !Upload.Status {
    var turn = try store.capture(17);
    _ = try uploads.begin(&turn, try Command.inspect(bytes), namespace, try s.Publication.Digest.of(Command.format, bytes));
    try t.expectEqual(@as(usize, 3), writes(turn));
    try store.commit(turn);
    var offset: u32 = 0;
    while (offset < bytes.len) : (offset += Upload.part_bytes) {
        turn = try store.capture(17);
        const part = bytes[offset..][0..@min(Upload.part_bytes, bytes.len - offset)];
        const result = try uploads.append(&turn, namespace, offset, part);
        try t.expectEqual(@as(u32, @intCast(offset + part.len)), result.received);
        const expected: usize = if (offset % 256 == 128) 4 else if (bytes.len - offset <= 128) 3 else 2;
        try t.expectEqual(expected, writes(turn));
        try store.commit(turn);
        turn = try store.capture(17);
        _ = try uploads.append(&turn, namespace, offset, part);
        try t.expectEqual(@as(usize, 0), writes(turn));
    }
    turn = try store.capture(17);
    const result = try uploads.seal(&turn, namespace);
    try t.expectEqual(@as(usize, 3), writes(turn));
    try t.expectError(error.PublicationNotPublished, uploads.bind(t.allocator, &turn, namespace));
    try store.commit(turn);
    return result;
}
fn bind(store: *TestStore, namespace: u64) !Upload.Status {
    var turn = try selfTurn(store, 3);
    const result = try uploads.bind(t.allocator, &turn, namespace);
    try t.expectEqual(@as(usize, 1), writes(turn));
    try t.expectError(error.QueryAfterMutation, catalog.executeUploaded(t.allocator, &turn, namespace));
    try store.commit(turn);
    return result;
}
fn execute(store: *TestStore, namespace: u64) !void {
    for (0..2000) |_| {
        var turn = try selfTurn(store, 3);
        const complete = try catalog.executeUploaded(t.allocator, &turn, namespace);
        var repeat = try selfTurn(store, 3);
        try t.expectEqual(complete, try catalog.executeUploaded(t.allocator, &repeat, namespace));
        try t.expectEqualDeep(turn.decision, repeat.decision);
        try store.commit(turn);
        if (complete) return;
    }
    return error.TestUnexpectedResult;
}
fn collect(store: *TestStore, namespace: u64) !void {
    for (0..2000) |_| {
        var turn = try store.capture(17);
        const complete = try uploads.collect(&turn, namespace);
        try store.commit(turn);
        if (complete) return;
    }
    return error.TestUnexpectedResult;
}
test "typed upload commits bounded parts and exact binding before native-owner admission" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    var bytes: [2048]u8 = undefined;
    const body = try command(&bytes);
    const sealed = try stage(&store, 1000, body);
    try t.expectEqual(.sealed, sealed.phase);
    const bound = try bind(&store, 1000);
    try t.expectEqual(.ready, bound.phase);
    try t.expectEqual(.ddl, bound.route);
    try t.expectEqualDeep(try (try request()).digest(catalog.configuration.scope), bound.digest);
    try t.expectEqual(@as(u16, Upload.status_bytes), (try bound.encode()).len);
    try t.expectEqualDeep(bound, try Upload.Status.decode(try bound.encode()));
    var turn = try store.capture(17);
    try t.expectEqual(.absent, try uploads.application(&turn, bound));
    try t.expectError(error.TableUploadStillActive, uploads.collect(&turn, 1000));
    try execute(&store, 1000);
    turn = try store.capture(17);
    try t.expectEqual(.terminal, try uploads.application(&turn, bound));
    var definition = (try catalog.lookup(t.allocator, &turn, 17, try c.TableMetadata.Name.init("people"))).?;
    defer definition.deinit();
    try t.expectEqual(@as(u64, 100), definition.metadata.object);
    try collect(&store, 1000);
    turn = try selfTurn(&store, 3);
    try t.expect(try catalog.executeUploaded(t.allocator, &turn, 1000));
    try t.expectEqual(@as(usize, 0), writes(turn));
    try t.expectEqualDeep(bound, try uploads.status(&turn, 17, 1000));
    const pubn: s.Publication = .{ .resource = 7, .domain = .table_mutation, .namespace = 1000 };
    try t.expectEqual(.retired, (try pubn.inspect(&turn, 1)).state);
    try t.expectError(error.PublicationNotPublished, uploads.resolve(t.allocator, &turn, 1000));
}
test "upload rejects forged origins changed parts gaps headers and reused namespaces" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    var bytes: [2048]u8 = undefined;
    const body = try command(&bytes);
    const header = try Command.inspect(body);
    const spec = try s.Publication.Digest.of(Command.format, body);
    var turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogDenied, uploads.begin(&turn, header, 1000, spec));
    turn = try store.capture(18);
    try t.expectError(error.CatalogDenied, uploads.begin(&turn, header, 1000, spec));
    turn = try store.capture(17);
    _ = try uploads.begin(&turn, header, 1000, spec);
    try store.commit(turn);
    turn = try store.capture(17);
    try t.expectError(error.TableUploadGap, uploads.append(&turn, 1000, 128, body[128..256]));
    try t.expectError(error.InvalidTableUploadPart, uploads.append(&turn, 1000, 1, body[0..128]));
    try t.expectError(error.IncompletePublication, uploads.seal(&turn, 1000));
    _ = try uploads.append(&turn, 1000, 0, body[0..128]);
    try store.commit(turn);
    var corrupt: [128]u8 = body[0..128].*;
    corrupt[0] ^= 1;
    turn = try store.capture(17);
    try t.expectError(error.CatalogIdentityConflict, uploads.append(&turn, 1000, 0, &corrupt));
    var changed = header;
    changed.operation += 1;
    try t.expectError(error.CatalogIdentityConflict, uploads.begin(&turn, changed, 1000, spec));
    var foreign = uploads;
    foreign.catalog.configuration.scope.catalog += 1;
    turn = try store.capture(17);
    try foreign.catalog.initialize(&turn);
    try store.commit(turn);
    turn = try store.capture(17);
    changed.scope.catalog += 1;
    try t.expectError(error.CatalogAlreadyPopulated, foreign.begin(&turn, changed, 1000, spec));
    // Seal a valid publication whose body does not match its accepted header.
    _ = try stage(&store, 1001, body);
    turn = try store.capture(17);
    var saved = try uploads.status(&turn, 17, 1001);
    saved.header.operation += 1;
    try store.state.put(t.allocator, uploads.key(1001), try saved.encode());
    turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogIdentityConflict, uploads.bind(t.allocator, &turn, 1001));
    turn = try selfTurn(&store, 4);
    try t.expectError(error.CatalogDenied, uploads.bind(t.allocator, &turn, 1001));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
test "upload cancellation and collection close every unadmitted phase without deleting identity" {
    var bytes: [2048]u8 = undefined;
    const body = try command(&bytes);
    for (0..5) |phase| {
        var store: TestStore = .{};
        defer store.deinit();
        try ready(&store);
        var turn = try store.capture(17);
        if (phase < 3) {
            _ = try uploads.begin(&turn, try Command.inspect(body), 1000, try s.Publication.Digest.of(Command.format, body));
            try store.commit(turn);
            for (0..phase) |i| {
                turn = try store.capture(17);
                _ = try uploads.append(&turn, 1000, @intCast(i * 128), body[i * 128 ..][0..128]);
                try store.commit(turn);
            }
        } else {
            _ = try stage(&store, 1000, body);
            if (phase == 4) _ = try bind(&store, 1000);
        }
        turn = try store.capture(17);
        try t.expect(try uploads.cancel(&turn, 1000));
        try store.commit(turn);
        try collect(&store, 1000);
        turn = try selfTurn(&store, 3);
        try t.expect(try catalog.executeUploaded(t.allocator, &turn, 1000));
        const final = try uploads.status(&turn, 17, 1000);
        try t.expectEqual(.cancelled, final.phase);
        try t.expectEqual(null, try catalog.status(&turn, 17, 1, try (try request()).digest(catalog.configuration.scope)));
        turn = try store.capture(17);
        const retry = try uploads.begin(&turn, final.header, 1000, final.spec);
        try t.expectEqualDeep(final, retry);
        turn = try store.capture(17);
        try t.expectError(error.TableUploadClosed, uploads.append(&turn, 1000, 0, body[0..128]));
        const pubn: s.Publication = .{ .resource = 7, .domain = .table_mutation, .namespace = 1000 };
        try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
    }
}
test "upload recovery rechecks current action permission while inspect permits cancellation" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    var bytes: [2048]u8 = undefined;
    _ = try stage(&store, 1000, try command(&bytes));
    _ = try bind(&store, 1000);
    var turn = try selfTurn(&store, 3);
    try t.expect(!try catalog.executeUploaded(t.allocator, &turn, 1000));
    try store.commit(turn);
    turn = try store.capture(17);
    var policy = try @import("TestStore.zig").Rights.administrator(catalog.configuration.scope, 17);
    policy.revision = 2;
    policy.create = false;
    try store.setRights(policy);
    try store.commit(turn);
    turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogDenied, catalog.executeUploaded(t.allocator, &turn, 1000));
    try t.expectEqual(@as(usize, 0), writes(turn));
    turn = try store.capture(17);
    try t.expect(try uploads.cancel(&turn, 1000));
    try store.commit(turn);
    try collect(&store, 1000);
    turn = try selfTurn(&store, 3);
    try t.expect(try catalog.executeUploaded(t.allocator, &turn, 1000));
    turn = try store.capture(17);
    policy.revision = 3;
    policy.inspect = false;
    try store.setRights(policy);
    try store.commit(turn);
    turn = try selfTurn(&store, 3);
    try t.expectError(error.CatalogDenied, catalog.executeUploaded(t.allocator, &turn, 1000));
}

test "upload receipt bytes match independent oracle and reject old or malformed shapes" {
    const Fixture = struct { upload_status_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-metadata.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var bytes: [Upload.status_bytes]u8 = undefined;
    const value = try c.protocol.Value.init(try std.fmt.hexToBytes(&bytes, parsed.value.upload_status_hex));
    const original = try Upload.Status.decode(value);
    try t.expectEqual(std.math.maxInt(u64), original.namespace);
    try t.expectEqual(.sealed, original.phase);
    try t.expect(value.eql(try original.encode()));
    for (0..bytes.len) |length| try t.expectError(error.InvalidTableUpload, Upload.Status.decode(try c.protocol.Value.init(bytes[0..length])));
    var changed = value;
    changed.data[8] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Upload.Status.decode(changed));
    var invalid = original;
    invalid.received -= 1;
    try t.expectError(error.InvalidTableUpload, invalid.encode());
    invalid = original;
    invalid.phase = .ready;
    try t.expectError(error.InvalidTableUpload, invalid.encode());
    invalid = original;
    invalid.digest[0] = 1;
    try t.expectError(error.InvalidTableUpload, invalid.encode());
}

test "uploaded finite DML retains original counts after body collection" {
    var store: TestStore = .{};
    defer store.deinit();
    try ready(&store);
    var bytes: [4096]u8 = undefined;
    _ = try stage(&store, 1000, try command(&bytes));
    _ = try bind(&store, 1000);
    try execute(&store, 1000);
    var turn = try store.capture(17);
    var definition = (try catalog.lookup(t.allocator, &turn, 17, try c.TableMetadata.Name.init("people"))).?;
    defer definition.deinit();
    var compiled = try c.fuze.TableDml.compile(t.allocator, "INSERT INTO people VALUES (1, 'Ada'), (2, 'Grace')", "people", definition.schema.schema, null);
    defer compiled.deinit();
    const dml: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .plan = compiled.plan };
    const body = try Command.encode(t.allocator, try Command.fromDml(catalog.configuration.scope, 3, dml, definition.metadata), &bytes);
    _ = try stage(&store, 1001, body);
    const bound = try bind(&store, 1001);
    try t.expectEqual(.statement, bound.route);
    try execute(&store, 1001);
    try collect(&store, 1001);
    turn = try selfTurn(&store, 3);
    try t.expect(try catalog.executeUploaded(t.allocator, &turn, 1001));
    const result = (try catalog.mutationReceipt(&turn, 17, try bound.reference())).?;
    try t.expectEqual(.applied, result.state);
    try t.expectEqual(@as(u64, 2), result.matched);
    try t.expectEqual(@as(u64, 2), result.changed);
}

test "upload evidence read failures poison the whole proposal" {
    var original: TestStore = .{};
    defer original.deinit();
    try ready(&original);
    var bytes: [4096]u8 = undefined;
    const body = try command(&bytes);
    _ = try stage(&original, 1000, body);
    original.reads = 0;
    var turn = try selfTurn(&original, 3);
    _ = try uploads.bind(t.allocator, &turn, 1000);
    const count = original.reads;
    for (1..count + 1) |index| {
        original.reads = 0;
        original.fail_at = index;
        turn = try selfTurn(&original, 3);
        const before = turn.decision;
        try t.expectError(error.Unavailable, uploads.bind(t.allocator, &turn, 1000));
        try t.expectEqualDeep(before, turn.decision);
        try t.expectError(error.Unavailable, turn.validate());
    }
    original.fail_at = null;
    _ = try bind(&original, 1000);
    original.reads = 0;
    turn = try selfTurn(&original, 3);
    _ = try catalog.executeUploaded(t.allocator, &turn, 1000);
    const execution_reads = original.reads;
    for (1..execution_reads + 1) |index| {
        original.reads = 0;
        original.fail_at = index;
        turn = try selfTurn(&original, 3);
        const before = turn.decision;
        try t.expectError(error.Unavailable, catalog.executeUploaded(t.allocator, &turn, 1000));
        try t.expectEqualDeep(before, turn.decision);
        try t.expectError(error.Unavailable, turn.validate());
    }
}
