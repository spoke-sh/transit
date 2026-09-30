const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const s = q.station;
const r = q.TableMutationRecords;
const admission = q.TableMutationAdmission;
const Request = q.TableMutationRequest;
const m = q.fuze.model;
const Store = q.testing.Store;

fn setup(store: *Store) !s.Table {
    var turn = try store.capture();
    const table = try s.Table.create(&turn, 1, .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = .utf8 });
    try admission.setPolicy(&turn, 0, .{ .principal = 10, .table = table.id, .revision = 1, .declaration = try r.declaration(table), .permissions = 7 });
    try store.commit(turn);
    return table;
}
fn input(store: *Store, principal: u64, command: r.Command) !s.Turn {
    var turn = try store.capture();
    turn.delivery.input.origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } };
    turn.delivery.input.value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode();
    return turn;
}
fn execute(store: *Store, command: r.Command) !r.Status {
    var turn = try input(store, 10, command);
    const result = try admission.dispatch(&turn);
    try store.commit(turn);
    return result;
}
fn prepare(store: *Store, request: Request, namespace: u64) !void {
    const ref = try request.reference(namespace);
    _ = try execute(store, .{ .begin = .{ .reference = ref, .table = request.table, .policy_revision = 1 } });
    var buffer: [Request.max_bytes]u8 = undefined;
    const bytes = try request.encode(&buffer);
    try parts(store, ref, bytes);
    _ = try execute(store, .{ .seal = ref });
}
fn reference(store: *Store, namespace: u64) !s.PublicationReference {
    var turn = try store.capture();
    return (try admission.status(&turn, namespace)).?.reference;
}
fn parts(store: *Store, ref: s.PublicationReference, bytes: []const u8) !void {
    for (0..ref.spec.chunks()) |ordinal| {
        const offset = ordinal * s.Publication.chunk_bytes;
        const chunk = bytes[offset..][0..try ref.spec.size(@intCast(ordinal))];
        _ = try execute(store, .{ .part = .{ .reference = ref, .ordinal = @intCast(ordinal), .second = false, .bytes = chunk[0..@min(chunk.len, r.part_bytes)] } });
        if (chunk.len > r.part_bytes) _ = try execute(store, .{ .part = .{ .reference = ref, .ordinal = @intCast(ordinal), .second = true, .bytes = chunk[r.part_bytes..] } });
    }
}
fn sql(store: *Store, table: s.Table, text: []const u8) !Request {
    return Request.fromSql(1, store.pid, table, try m.Name.init("items"), text);
}
fn row(store: *Store, table: s.Table, key: i64) !?m.Row {
    var turn = try store.capture();
    return table.get(&turn, key);
}
fn mutations(turn: s.Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        count += 1;
    };
    return count;
}

test "mutation staging recovers owned halves and atomically proposes three rows and one stable result" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    const text: [180]u8 = @splat('x');
    var request = try sql(&store, table, "DELETE FROM items WHERE id=1");
    const value: m.Cell = .{ .utf8 = try m.Bytes.init(&text) };
    request.plan.operation = .{ .insert = .{ .{ .key = 1, .value = value }, .{ .key = 2, .value = value }, .{ .key = 3, .value = value } } };
    const ref = try request.reference(900);
    var turn = try input(&store, 10, .{ .begin = .{ .reference = ref, .table = 1, .policy_revision = 1 } });
    const started = try admission.dispatch(&turn);
    try t.expectEqual(.uploading, started.phase);
    try t.expectEqual(4, mutations(turn));
    try t.expectEqual(null, try row(&store, table, 1));
    try store.commit(turn);
    _ = try execute(&store, .{ .begin = .{ .reference = ref, .table = 1, .policy_revision = 1 } });
    var buffer: [Request.max_bytes]u8 = undefined;
    const bytes = try request.encode(&buffer);
    const half: r.Command = .{ .part = .{ .reference = ref, .ordinal = 0, .second = false, .bytes = bytes[0..r.part_bytes] } };
    _ = try execute(&store, half);
    var recovered = try store.clone();
    defer recovered.deinit();
    _ = try execute(&recovered, half); // Reconstructed owner; same half is harmless.
    try parts(&recovered, ref, bytes);
    _ = try execute(&recovered, .{ .seal = try reference(&recovered, 900) });
    turn = try input(&recovered, 10, .{ .apply = try reference(&recovered, 900) });
    const result = try admission.dispatch(&turn);
    try t.expectEqual(.applied, result.phase);
    try t.expectEqual(3, result.affected_rows);
    try t.expectEqual(4, mutations(turn));
    try t.expectEqual(null, try row(&recovered, table, 1));
    var replay = try input(&recovered, 10, .{ .apply = try reference(&recovered, 900) });
    try t.expect(std.meta.eql(result, try admission.dispatch(&replay)));
    try t.expect(std.meta.eql(turn.decision, replay.decision));
    try recovered.commit(turn);
    for (1..4) |key| try t.expectEqualStrings(&text, (try row(&recovered, table, @intCast(key))).?.value.utf8.slice());
    turn = try input(&recovered, 10, .{ .apply = try reference(&recovered, 900) });
    try t.expect(std.meta.eql(result, try admission.dispatch(&turn)));
    try t.expectEqual(0, mutations(turn));
    try t.expectEqual(@as(?u64, 900), try admission.active(&turn));
    try t.expect(std.meta.eql(result, try execute(&recovered, .{ .cancel = try reference(&recovered, 900) })));
    // A later begin replaces a terminal pointer in four slots; old results stay.
    const next = try sql(&recovered, table, "DELETE FROM items WHERE id=3");
    try prepare(&recovered, next, 901);
    try t.expectEqual(1, (try execute(&recovered, .{ .apply = try reference(&recovered, 901) })).affected_rows);
    turn = try recovered.capture();
    try t.expect(std.meta.eql(result, (try admission.status(&turn, 900)).?));
}

test "duplicate insert rolls back all rows; UPDATE and DELETE counts include no-op selection" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    try prepare(&store, try sql(&store, table, "INSERT INTO items (id,value) VALUES(2,'old')"), 1);
    _ = try execute(&store, .{ .apply = try reference(&store, 1) });
    try prepare(&store, try sql(&store, table, "INSERT INTO items (id,value) VALUES(1,'new'),(2,'conflict'),(3,'new')"), 2);
    var turn = try input(&store, 10, .{ .apply = try reference(&store, 2) });
    const rejected = try admission.dispatch(&turn);
    try t.expectEqual(.row_exists, rejected.reason);
    try t.expectEqual(.rejected, rejected.phase);
    try t.expectEqual(1, mutations(turn));
    try store.commit(turn);
    try t.expectEqual(null, try row(&store, table, 1));
    try t.expectEqual(null, try row(&store, table, 3));
    try t.expectEqualStrings("old", (try row(&store, table, 2)).?.value.utf8.slice());
    const statements = [_][]const u8{ "UPDATE items SET value='old' WHERE id=2", "UPDATE items SET value=NULL WHERE id=9", "DELETE FROM items WHERE id=2", "DELETE FROM items WHERE id=2" };
    for (statements, [_]u8{ 1, 0, 1, 0 }, 3..) |text, expected, namespace| {
        try prepare(&store, try sql(&store, table, text), namespace);
        const result = try execute(&store, .{ .apply = try reference(&store, namespace) });
        try t.expectEqual(.applied, result.phase);
        try t.expectEqual(expected, result.affected_rows);
    }
}

test "mutation policy revisions fence uploads; revocation permits only closure and original results" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    const request = try sql(&store, table, "INSERT INTO items (id,value) VALUES(1,'x')");
    try prepare(&store, request, 1);
    var turn = try store.capture();
    var grant = (try admission.policy(&turn, 10, 1)).?;
    grant.revision = 2;
    grant.permissions = 0;
    try t.expectError(error.StaleMutationPolicy, admission.setPolicy(&turn, 0, grant));
    try admission.setPolicy(&turn, 1, grant);
    try store.commit(turn);
    const result = try execute(&store, .{ .apply = try reference(&store, 1) });
    try t.expectEqual(.denied, result.reason);
    try t.expectEqual(null, try row(&store, table, 1));
    turn = try input(&store, 10, .{ .begin = .{ .reference = try request.reference(2), .table = 1, .policy_revision = 1 } });
    try t.expectError(error.MutationDenied, admission.dispatch(&turn));
    try t.expectEqual(0, mutations(turn));
    turn = try store.capture();
    grant.revision = 3;
    grant.permissions = 2; // UPDATE only, not INSERT.
    try admission.setPolicy(&turn, 2, grant);
    try store.commit(turn);
    _ = try execute(&store, .{ .begin = .{ .reference = try request.reference(2), .table = 1, .policy_revision = 3 } });
    var buffer: [Request.max_bytes]u8 = undefined;
    try parts(&store, try request.reference(2), try request.encode(&buffer));
    _ = try execute(&store, .{ .seal = try reference(&store, 2) });
    try t.expectEqual(.denied, (try execute(&store, .{ .apply = try reference(&store, 2) })).reason);
    try t.expect(std.meta.eql(result, try execute(&store, .{ .apply = try reference(&store, 1) })));
    _ = try execute(&store, .{ .begin = .{ .reference = try request.reference(3), .table = 1, .policy_revision = 3 } });
    turn = try store.capture();
    grant.revision = 4; // Even an unchanged permission mask fences old uploads.
    try admission.setPolicy(&turn, 3, grant);
    try store.commit(turn);
    turn = try input(&store, 10, .{ .seal = try reference(&store, 3) });
    try t.expectError(error.MutationDenied, admission.dispatch(&turn));
    try t.expectEqual(.cancelled, (try execute(&store, .{ .cancel = try reference(&store, 3) })).phase);
}

test "only the authenticated principal may stage; busy and immutable namespace conflicts preserve proposals" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    const request = try sql(&store, table, "DELETE FROM items WHERE id=1");
    const ref = try request.reference(8);
    const begin: r.Command = .{ .begin = .{ .reference = ref, .table = 1, .policy_revision = 1 } };
    var turn = try input(&store, 10, begin);
    turn.delivery.input.origin = .{ .process = .{ .pid = 10, .turn = 1, .output = 0 } };
    try t.expectError(error.ExpectedExternalOrigin, admission.dispatch(&turn));
    _ = try execute(&store, begin);
    inline for (.{ begin, r.Command{ .seal = ref }, r.Command{ .apply = ref }, r.Command{ .cancel = ref } }) |command| {
        turn = try input(&store, 11, command);
        try t.expectError(error.MutationPrincipalMismatch, admission.dispatch(&turn));
        try t.expectEqual(0, mutations(turn));
    }
    turn = try input(&store, 10, .{ .begin = .{ .reference = try request.reference(9), .table = 1, .policy_revision = 1 } });
    try t.expectError(error.MutationBusy, admission.dispatch(&turn));
    var conflict = ref;
    conflict.spec.digest[0] ^= 1;
    turn = try input(&store, 10, .{ .begin = .{ .reference = conflict, .table = 1, .policy_revision = 1 } });
    try t.expectError(error.MutationIdentityConflict, admission.dispatch(&turn));
    try t.expectEqual(.cancelled, (try execute(&store, .{ .cancel = try reference(&store, 8) })).phase);
    turn = try store.capture();
    _ = try s.Publication.create(&turn, .table_mutation, 9, .{ .record_bytes = 1, .staging_bytes = 1, .staging_records = 1 });
    try store.commit(turn);
    turn = try input(&store, 10, .{ .begin = .{ .reference = try request.reference(9), .table = 1, .policy_revision = 1 } });
    try t.expectError(error.MutationNamespaceInUse, admission.dispatch(&turn));
    try t.expectEqual(0, mutations(turn));
}

test "source changes and malformed immutable requests reject without rows; unavailable reads never become results" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    var request = try sql(&store, table, "INSERT INTO items (id,value) VALUES(1,'x')");
    request.writer += 1;
    try prepare(&store, request, 1);
    try t.expectEqual(.invalid_request, (try execute(&store, .{ .apply = try reference(&store, 1) })).reason);
    request.writer -= 1;
    try prepare(&store, request, 2);
    var turn = try input(&store, 10, .{ .apply = try reference(&store, 2) });
    try turn.put(try q.protocol.Value.init("prior"), .{});
    const before = turn.decision;
    try t.expectError(error.MutationAfterWrite, admission.dispatch(&turn));
    try t.expect(std.meta.eql(before, turn.decision));
    turn = try input(&store, 10, .{ .apply = try reference(&store, 2) });
    store.denied = true;
    try t.expectError(error.AccessDenied, admission.dispatch(&turn));
    try t.expectEqual(error.AccessDenied, turn.read_error.?);
    try t.expectError(error.AccessDenied, turn.validate());
    try t.expectEqual(0, mutations(turn));
    store.denied = false;
    turn = try store.capture();
    var changed = table.schema;
    changed.value_type = .binary;
    try turn.write(s.Table.descriptorKey(1), try s.Table.encodeSchema(changed));
    try store.commit(turn);
    try t.expectEqual(.source_changed, (try execute(&store, .{ .apply = try reference(&store, 2) })).reason);
    try t.expectEqual(null, store.state.get(s.Table.rowKey(1, 1)));
}

test "mutation policy, statuses and command bytes agree with the independent fixture" {
    const Fixture = struct {
        version: u8,
        declaration: []const u8,
        reference: []const u8,
        policy: []const u8,
        statuses: []const struct { phase: u8, affected: u8, reason: u8, input: u64, wire_hex: []const u8 },
        commands: []const []const u8,
    };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-mutation-records-v1.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try t.expectEqual(1, fixture.version);
    var bytes: [pvalue.max_bytes]u8 = undefined;
    const grant = try r.Policy.decode(try pvalue.init(try std.fmt.hexToBytes(&bytes, fixture.policy)));
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.policy), (try grant.encode()).slice());
    try t.expectEqual(10, grant.principal);
    try t.expectEqual(9, grant.table);
    try t.expectEqual(4, grant.revision);
    const table: s.Table = .{ .resource = 7, .id = 9, .schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = .int64 } };
    try t.expectEqualSlices(u8, &try r.declaration(table), &grant.declaration);
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.declaration), &grant.declaration);
    const fixture_reference = try s.PublicationReference.decode(try pvalue.init(try std.fmt.hexToBytes(&bytes, fixture.reference)));
    for (fixture.statuses) |case| {
        const encoded = try pvalue.init(try std.fmt.hexToBytes(&bytes, case.wire_hex));
        const current = try r.Status.decode(encoded);
        try t.expectEqual(case.phase, @backingInt(current.phase));
        try t.expectEqual(case.reason, @backingInt(current.reason));
        try t.expectEqual(case.affected, current.affected_rows);
        try t.expectEqual(case.input, current.input);
        try t.expect(std.meta.eql(fixture_reference, current.reference));
        try t.expectEqualSlices(u8, encoded.slice(), (try current.encode()).slice());
        for (0..encoded.len) |len| {
            if (r.Status.decode(try pvalue.init(encoded.slice()[0..len]))) |_| return error.AcceptedTruncation else |_| {}
        }
        var changed = current;
        if (current.terminal()) changed.input = 0 else changed.input = 1;
        try t.expectError(error.InvalidMutationRecord, changed.encode());
        changed = current;
        changed.affected_rows = 4;
        try t.expectError(error.InvalidMutationRecord, changed.encode());
    }
    for (fixture.commands) |hex| {
        const encoded = try pvalue.init(try std.fmt.hexToBytes(&bytes, hex));
        const command = try r.Command.decode(&encoded);
        try t.expectEqualSlices(u8, encoded.slice(), (try command.encode()).slice());
        _ = try (s.Frame{ .kind = .cast, .payload = encoded }).encode();
        if (command != .part) for (0..encoded.len) |len| {
            const truncated = try pvalue.init(encoded.slice()[0..len]);
            if (r.Command.decode(&truncated)) |_| return error.AcceptedTruncation else |_| {}
        };
        if (command == .part) {
            var malformed = encoded;
            malformed.data[4 + s.PublicationReference.encoded_bytes + 4] = 2;
            try t.expectError(error.InvalidMutationCommand, r.Command.decode(&malformed));
        }
    }
    var invalid = grant;
    invalid.permissions = 8;
    try t.expectError(error.InvalidMutationRecord, invalid.encode());
    invalid = grant;
    invalid.revision = 0;
    try t.expectError(error.InvalidMutationRecord, invalid.encode());
    const encoded = try grant.encode();
    for (0..encoded.len) |len| {
        if (r.Policy.decode(try pvalue.init(encoded.slice()[0..len]))) |_| return error.AcceptedTruncation else |_| {}
    }
    try t.expectError(error.InvalidMutationCommand, (r.Command{ .part = .{ .reference = fixture_reference, .ordinal = 4, .second = false, .bytes = "x" } }).encode());
    try t.expectError(error.InvalidMutationCommand, (r.Command{ .part = .{ .reference = fixture_reference, .ordinal = 0, .second = false, .bytes = &@as([129]u8, @splat(1)) } }).encode());
}
const pvalue = q.protocol.Value;

test "every mutation command remains bound to the original resource and request" {
    var first: Store = .{};
    defer first.deinit();
    const table = try setup(&first);
    const request = try sql(&first, table, "INSERT INTO items (id,value) VALUES(1,'original')");
    const original = try request.reference(1);
    try prepare(&first, request, 1);
    var other: Store = .{ .resource = first.resource + 1 };
    defer other.deinit();
    const other_table = try setup(&other);
    const other_request = try sql(&other, other_table, "INSERT INTO items (id,value) VALUES(1,'other')");
    try prepare(&other, other_request, 1);

    // Same writer, principal, Table, policy revision and namespace, but a new
    // associated resource: an already delivered old command cannot target it.
    for ([_]r.Command{
        .{ .part = .{ .reference = original, .ordinal = 0, .second = false, .bytes = "x" } },
        .{ .seal = original },
        .{ .apply = original },
        .{ .cancel = original },
    }) |command| {
        var turn = try input(&other, 10, command);
        const before = turn.decision;
        try t.expectError(error.MutationIdentityConflict, admission.dispatch(&turn));
        try t.expect(std.meta.eql(before, turn.decision));
    }
    // Even in the original resource, another digest or length is not this work.
    for (0..2) |change| {
        var altered = original;
        if (change == 0) altered.spec.digest[0] ^= 1 else altered.spec.length += 1;
        for ([_]r.Command{
            .{ .part = .{ .reference = altered, .ordinal = 0, .second = false, .bytes = "x" } },
            .{ .seal = altered },
            .{ .apply = altered },
            .{ .cancel = altered },
        }) |command| {
            var turn = try input(&first, 10, command);
            try t.expectError(error.MutationIdentityConflict, admission.dispatch(&turn));
            try t.expectEqual(0, mutations(turn));
        }
    }
    try t.expectEqual(null, try row(&first, table, 1));
    try t.expectEqual(null, try row(&other, other_table, 1));
    _ = try execute(&first, .{ .apply = original });
    // Terminal results are bound too; a bad reference cannot cancel/reuse them.
    var altered = original;
    altered.spec.digest[0] ^= 1;
    var turn = try input(&first, 10, .{ .cancel = altered });
    try t.expectError(error.MutationIdentityConflict, admission.dispatch(&turn));
    try t.expectEqual(0, mutations(turn));
    try t.expectEqual(.applied, (try execute(&first, .{ .apply = original })).phase);
}

test "namespace-only mutation command bytes reject rather than being reinterpreted" {
    // Previous payloads have no immutable resource/reference identity.
    for ([_][]const u8{ "TMP1", "TMZ1", "TMX1", "TMK1" }) |tag| {
        var bytes: [145]u8 = @splat(0);
        @memcpy(bytes[0..4], tag);
        std.mem.writeInt(u64, bytes[4..12], 1, .little);
        const value = try pvalue.init(bytes[0..if (std.mem.eql(u8, tag, "TMP1")) 145 else 12]);
        if (r.Command.decode(&value)) |_| return error.AcceptedNamespaceOnlyCommand else |_| {}
    }
}

const FaultReader = struct {
    reader: s.Turn.Reader,
    fail_key: pvalue,
    fn read(raw: *anyopaque, view: q.protocol.Growth.View, key: pvalue) !?pvalue {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (key.eql(self.fail_key)) return error.Unavailable;
        return self.reader.read(self.reader.context, view, key);
    }
};
test "failed second-row read preserves sticky poison and rolls back first row plus outcome" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    const request = try sql(&store, table, "INSERT INTO items (id,value) VALUES(1,'one'),(2,'two'),(3,'three')");
    try prepare(&store, request, 1);
    var turn = try input(&store, 10, .{ .apply = try reference(&store, 1) });
    var fault: FaultReader = .{ .reader = turn.reader, .fail_key = s.Table.rowKey(1, 2) };
    turn.reader = .{ .context = &fault, .read = FaultReader.read };
    try t.expectError(error.Unavailable, admission.dispatch(&turn));
    try t.expectEqual(0, mutations(turn));
    try t.expectError(error.Unavailable, turn.validate());
    var check = try store.capture();
    try t.expectEqual(.sealed, (try admission.status(&check, 1)).?.phase);
    try t.expectEqual(null, try row(&store, table, 1));
    try t.expectEqual(3, (try execute(&store, .{ .apply = try reference(&store, 1) })).affected_rows);
}

test "invalid definition bytes are rejected but corrupt published chunks remain infrastructure errors" {
    var store: Store = .{};
    defer store.deinit();
    const table = try setup(&store);
    const request = try sql(&store, table, "INSERT INTO items (id,value) VALUES(1,'one')");
    var buffer: [Request.max_bytes]u8 = undefined;
    const length = (try request.encode(&buffer)).len;
    buffer[4] ^= 1; // Foreign definition, still a valid immutable publication.
    const ref: s.PublicationReference = .{ .domain = .table_mutation, .resource = table.resource, .namespace = 1, .record = 1, .spec = try s.Publication.Digest.of(Request.format, buffer[0..length]) };
    _ = try execute(&store, .{ .begin = .{ .reference = ref, .table = 1, .policy_revision = 1 } });
    try parts(&store, ref, buffer[0..length]);
    _ = try execute(&store, .{ .seal = try reference(&store, 1) });
    try t.expectEqual(.invalid_request, (try execute(&store, .{ .apply = try reference(&store, 1) })).reason);
    try prepare(&store, request, 2);
    // Model storage corruption after publication, not caller-controlled bytes.
    const key = s.Publication.key(.table_mutation, 2, 'c', 1, 0);
    var broken = store.state.get(key).?;
    broken.data[0] ^= 1;
    try store.state.put(t.allocator, key, broken);
    var turn = try input(&store, 10, .{ .apply = try reference(&store, 2) });
    try t.expectError(error.InvalidPublicationDigest, admission.dispatch(&turn));
    try t.expectEqual(0, mutations(turn));
    try t.expectEqual(.sealed, (try admission.status(&turn, 2)).?.phase);
    try t.expectEqual(null, try row(&store, table, 1));
}
