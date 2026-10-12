const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const p = c.protocol;
const s = c.station;
const Store = @import("TestStore.zig");
const config: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .table_limits = .{ .record_bytes = c.fuze.TableRow.max_bytes, .staging_bytes = c.fuze.TableRow.max_bytes * 2, .staging_records = 2 } };
const catalog: c.TableCatalog = .{ .configuration = config };
const uploads: c.TableUpload = .{ .catalog = catalog };
const upload: c.TableControl.Upload = .{ .scope = config.scope, .namespace = 1000 };
fn external(who: u64) p.Growth.Origin {
    return .{ .external = .{ .principal = who, .policy_revision = 1 } };
}
fn process(pid: u64) p.Growth.Origin {
    return .{ .process = .{ .pid = pid, .turn = 1, .output = 0 } };
}
fn frame(command: c.TableControl.Command) !p.Value {
    return (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode();
}
fn dispatch(store: *Store, behavior: *c.TableBehavior, origin: p.Growth.Origin, value: p.Value) !s.Turn {
    var turn = try store.capture(17);
    turn.delivery.input.origin = origin;
    turn.delivery.input.value = value;
    const initializing = try turn.read(s.GenServer.descriptor_key) == null;
    if (initializing) try turn.write(s.GenServer.descriptor_key, s.GenServer.descriptor);
    const guard = behavior.guard();
    if (try guard.reject(guard.context, &turn)) {
        if (initializing) return error.UninitializedCatalog;
        return turn;
    }
    const handler = behavior.interface();
    if (initializing) try handler.initialize.?(handler.context, &turn);
    try handler.handle(handler.context, &turn, try s.Frame.decode(value));
    try turn.validate();
    return turn;
}
fn disposition(turn: *s.Turn) !?c.TableControl.Disposition {
    return if (try turn.read(catalog.key('e', turn.delivery.input.position, 0))) |value| try c.Records.decode(c.TableControl.Disposition, 'E', value) else null;
}
fn writes(turn: s.Turn) usize {
    var result: usize = 0;
    for (turn.decision.mutations) |slot| result += @intFromBool(slot != null);
    return result;
}
fn ready(store: *Store, behavior: *c.TableBehavior) !void {
    var turn = try dispatch(store, behavior, external(17), try frame(.{ .initialize = config }));
    try t.expectEqual(@as(usize, 4), writes(turn));
    try t.expectEqual(.initialized, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
}
fn creation(buffer: []u8) ![]const u8 {
    const request: c.TableDdlRequest = .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = .{ .object = 100, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64 }, .{ .id = 2, .name = "name", .type = .utf8 } }, .primary_key = &.{} } } } };
    return c.TableCommand.encode(t.allocator, try c.TableCommand.fromDdl(config.scope, config.owner, request, null), buffer);
}
fn stage(store: *Store, behavior: *c.TableBehavior, body: []const u8) !p.Value {
    try store.commit(try dispatch(store, behavior, external(17), try frame(.{ .begin = .{ .header = try (try c.TableCommand.inspect(body)).encode(), .namespace = upload.namespace, .spec = try s.Publication.Digest.of(c.TableCommand.format, body) } })));
    var offset: u32 = 0;
    while (offset < body.len) : (offset += c.TableUpload.part_bytes) {
        const part = try c.TableControl.Part.init(upload, offset, body[offset..][0..@min(c.TableUpload.part_bytes, body.len - offset)]);
        try store.commit(try dispatch(store, behavior, external(17), try frame(.{ .part = part })));
    }
    const sealed = try dispatch(store, behavior, external(17), try frame(.{ .seal = upload }));
    const message = sealed.decision.outputs[0].?.value;
    try store.commit(sealed);
    return message;
}
fn drain(store: *Store, behavior: *c.TableBehavior, initial: p.Value) !void {
    var message = initial;
    for (0..2000) |_| {
        var turn = try dispatch(store, behavior, process(3), message);
        try t.expectEqual(null, try disposition(&turn));
        var replacement = try store.clone();
        defer replacement.deinit();
        var restored: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
        const repeat = try dispatch(&replacement, &restored, process(3), message);
        try t.expectEqualDeep(turn.decision, repeat.decision);
        try store.commit(turn);
        const next = turn.decision.outputs[0] orelse return;
        try t.expectEqual(@as(u64, 3), next.pid);
        try t.expectEqual(null, turn.decision.outputs[1]);
        message = next.value;
    }
    return error.TestUnexpectedResult;
}
fn create(store: *Store, behavior: *c.TableBehavior) !void {
    var buffer: [4096]u8 = undefined;
    try drain(store, behavior, try stage(store, behavior, try creation(&buffer)));
}
fn dml(store: *Store, sql: []const u8, operation: u64) !p.Value {
    var turn = try store.capture(17);
    var definition = (try catalog.lookup(t.allocator, &turn, 17, try c.TableMetadata.Name.init("people"))).?;
    defer definition.deinit();
    var compiled = try c.fuze.TableDml.compile(t.allocator, sql, "people", definition.schema.schema, null);
    defer compiled.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = operation, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .plan = compiled.plan };
    var buffer: [4096]u8 = undefined;
    const body = try c.TableCommand.encode(t.allocator, try c.TableCommand.fromDml(config.scope, 3, request, definition.metadata), &buffer);
    return (s.Frame{ .kind = .cast, .payload = try p.Value.init(body) }).encode();
}
test "general Table owner schedules uploaded DDL and inline DML without a fifth write" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
    try ready(&store, &behavior);
    try create(&store, &behavior);
    const insert = try dml(&store, "INSERT INTO people VALUES (1, 'Ada')", 2);
    var turn = try dispatch(&store, &behavior, external(17), insert);
    try t.expectEqual(@as(usize, 4), writes(turn));
    try t.expectEqual(null, try disposition(&turn));
    const insertion = turn.decision.outputs[0].?.value;
    try store.commit(turn);
    try drain(&store, &behavior, insertion);
    turn = try dispatch(&store, &behavior, external(17), insert);
    try t.expectEqual(@as(usize, 0), writes(turn));
    const deletion = try dml(&store, "DELETE FROM people", 3);
    turn = try dispatch(&store, &behavior, process(3), deletion);
    try t.expectEqual(.blocked, (try disposition(&turn)).?.outcome);
    try t.expectEqual(null, turn.decision.outputs[0]);
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(17), deletion);
    const message = turn.decision.outputs[0].?.value;
    try t.expectEqual(null, try disposition(&turn));
    try store.commit(turn);
    try drain(&store, &behavior, message);
    turn = try store.capture(17);
    try t.expectEqual(@as(u64, 0), (try s.TableHead.load(&turn, 100)).rows);
}
test "general owner pauses denied continuations and resumes original accepted work" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
    try ready(&store, &behavior);
    try create(&store, &behavior);
    const insertion = try dispatch(&store, &behavior, external(17), try dml(&store, "INSERT INTO people VALUES (1, 'Ada')", 2));
    try store.commit(insertion);
    try drain(&store, &behavior, insertion.decision.outputs[0].?.value);
    const deletion = try dml(&store, "DELETE FROM people", 3);
    var turn = try dispatch(&store, &behavior, external(17), deletion);
    const message = turn.decision.outputs[0].?.value;
    try store.commit(turn);
    var policy = try c.TableCatalogRecords.Policy.administrator(config.scope, 17);
    policy.revision = 2;
    policy.delete = false;
    try store.commit(try dispatch(&store, &behavior, external(17), try frame(.{ .policy = .{ .expected_revision = 1, .policy = policy } })));
    turn = try dispatch(&store, &behavior, process(3), message);
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
    try t.expectEqual(@as(usize, 1), writes(turn));
    try t.expectEqual(null, turn.decision.outputs[0]);
    try t.expectEqual(@as(u64, 1), (try s.TableHead.load(&turn, 100)).rows);
    try store.commit(turn);
    policy.revision = 3;
    policy.delete = true;
    try store.commit(try dispatch(&store, &behavior, external(17), try frame(.{ .policy = .{ .expected_revision = 2, .policy = policy } })));
    turn = try dispatch(&store, &behavior, external(17), deletion);
    const resumed = turn.decision.outputs[0].?.value;
    try store.commit(turn);
    try drain(&store, &behavior, resumed);
    turn = try store.capture(17);
    try t.expectEqual(@as(u64, 0), (try s.TableHead.load(&turn, 100)).rows);
}
test "general owner rejects forged controls malformed bodies and unknown definitions" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
    try t.expectError(error.UninitializedCatalog, dispatch(&store, &behavior, external(18), try frame(.{ .initialize = config })));
    try ready(&store, &behavior);
    var turn = try dispatch(&store, &behavior, external(18), try frame(.{ .initialize = config }));
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, process(4), try frame(.{ .drive = upload }));
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    var foreign = try frame(.{ .drive = upload });
    foreign.data[s.Frame.header_bytes + 5] ^= 1;
    turn = try dispatch(&store, &behavior, external(17), foreign);
    try t.expectEqual(.invalid_command, (try disposition(&turn)).?.outcome);
    try store.commit(turn);
    try create(&store, &behavior);
    var invalid = try dml(&store, "DELETE FROM people", 3);
    invalid.len -= 1;
    turn = try dispatch(&store, &behavior, external(17), invalid);
    try t.expectEqual(.invalid_command, (try disposition(&turn)).?.outcome);
    try t.expectEqual(@as(usize, 1), writes(turn));
    try store.commit(turn);
    turn = try dispatch(&store, &behavior, external(18), try dml(&store, "DELETE FROM people", 3));
    try t.expectEqual(.denied, (try disposition(&turn)).?.outcome);
}
test "general owner never acknowledges an unavailable read as an input rejection" {
    var store: Store = .{};
    defer store.deinit();
    var behavior: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
    try ready(&store, &behavior);
    try create(&store, &behavior);
    const insertion = try dml(&store, "INSERT INTO people VALUES (1, 'Ada')", 2);
    store.reads = 0;
    _ = try dispatch(&store, &behavior, external(17), insertion);
    const reads = store.reads;
    const count = store.state.count();
    for (1..reads + 1) |index| {
        store.reads = 0;
        store.fail_at = index;
        try t.expectError(error.Unavailable, dispatch(&store, &behavior, external(17), insertion));
        try t.expectEqual(count, store.state.count());
    }
}
test "native Table controls round trip within one frame and reject padding" {
    var buffer: [4096]u8 = undefined;
    const body = try creation(&buffer);
    const reference: s.TableWrite.Reference = .{ .resource = 7, .object = 100, .principal = 17, .operation = 2, .digest = @splat(1) };
    const ddl: c.TableControl.Ddl = .{ .scope = config.scope, .principal = 17, .operation = 1, .digest = @splat(2) };
    const data: c.TableControl.Dml = .{ .scope = config.scope, .reference = reference };
    const commands = [_]c.TableControl.Command{
        .{ .initialize = config },
        .{ .policy = .{ .expected_revision = 0, .policy = try c.TableCatalogRecords.Policy.administrator(config.scope, 18) } },
        .{ .dependency = .{ .dependency = .{ .scope = config.scope, .object = 100, .identity = 1, .owner = 4, .kind = .history }, .present = true } },
        .{ .cancel_ddl = ddl },
        .{ .cleanup_ddl = ddl },
        .{ .cancel_dml = data },
        .{ .cleanup_dml = data },
        .{ .begin = .{ .header = try (try c.TableCommand.inspect(body)).encode(), .namespace = 1000, .spec = try s.Publication.Digest.of(c.TableCommand.format, body) } },
        .{ .part = try c.TableControl.Part.init(upload, 0, "abc") },
        .{ .seal = upload },
        .{ .drive = upload },
        .{ .cancel_upload = upload },
        .{ .collect_upload = upload },
    };
    for (commands) |value| {
        const encoded = try value.encode();
        try t.expect(encoded.len <= s.Frame.max_payload);
        try t.expectEqualDeep(value, try c.TableControl.Command.decode(encoded));
        _ = try frame(value);
        for (0..encoded.len) |length| {
            if (c.TableControl.Command.decode(try p.Value.init(encoded.slice()[0..length]))) |_| return error.TestUnexpectedResult else |_| {}
        }
    }
    var part = try c.TableControl.Part.init(upload, 0, "abc");
    part.bytes[3] = 1;
    try t.expectError(error.InvalidTableUploadPart, part.validate());
}

test "malformed staged intent is disposed while corrupted published evidence is not acknowledged" {
    for ([_]bool{ false, true }) |corrupt_storage| {
        var store: Store = .{};
        defer store.deinit();
        var behavior: c.TableBehavior = .{ .allocator = t.allocator, .configuration = config };
        try ready(&store, &behavior);
        var buffer: [4096]u8 = undefined;
        const complete = try creation(&buffer);
        const body = if (corrupt_storage) complete else complete[0 .. complete.len - 1];
        const message = try stage(&store, &behavior, body);
        if (corrupt_storage) {
            const key = s.Publication.key(.table_mutation, 1000, 'c', 1, 0);
            var chunk = store.state.get(key).?;
            chunk.data[0] ^= 1;
            try store.state.put(t.allocator, key, chunk);
            try t.expectError(error.InvalidPublicationDigest, dispatch(&store, &behavior, process(3), message));
            try t.expectEqual(null, store.state.get(catalog.key('e', store.input, 0)));
        } else {
            var turn = try dispatch(&store, &behavior, process(3), message);
            try t.expectEqual(.invalid_command, (try disposition(&turn)).?.outcome);
            try t.expectEqual(null, turn.decision.outputs[0]);
            try store.commit(turn);
            turn = try dispatch(&store, &behavior, external(17), try frame(.{ .cancel_upload = upload }));
            try store.commit(turn);
            turn = try store.capture(17);
            try t.expectEqual(.cancelled, (try uploads.status(&turn, 17, 1000)).phase);
        }
    }
}
