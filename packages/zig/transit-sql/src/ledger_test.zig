const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const Store = @import("store_test.zig");
const t = std.testing;
const binding: g.Ledger.Binding = .{ .resource = 8, .catalog = 1, .owner = 9, .namespace = 7, .role = 29 };
const configuration: g.Ledger.Configuration = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .reader = 11, .account = @splat(7), .bindings = &.{binding}, .intent_bytes = 4096, .operation_quota = 1000, .byte_quota = 1024 * 1024, .pending_quota = 2 };
fn intent(id: u64) !c.TableIntent {
    const schema: c.fuze.TableSchema.Schema = .{ .object = id, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    const request: c.TableDdlRequest = .{ .principal = configuration.table_principal, .namespace = binding.namespace, .operation = id, .object = id, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = schema } } };
    return c.TableIntent.create(t.allocator, try c.TableCommand.fromDdl(.{ .realm = 1, .resource = binding.resource, .catalog = binding.catalog }, binding.owner, request, null), id);
}
test "ledger reserves identity and capacity before staged intent; only committed intent is admitted" {
    var store: Store = .{};
    defer store.deinit();
    const signing_key = try c.protocol.Ed25519.KeyPair.generateDeterministic(@splat(31));
    const config = configuration;
    const ledger: g.Ledger = .{ .configuration = config };
    var turn = try store.capture();
    try ledger.initialize(&turn, 0);
    try store.commit(turn);
    store.origin = configuration.ingress;
    turn = try store.capture();
    const item = try ledger.begin(&turn, @splat(11), binding, @splat(0));
    try t.expectEqual(turn.delivery.input.position, item.id);
    try store.commit(turn);
    // Lost begin reply: nonce finds the original ID under a later input.
    turn = try store.capture();
    const before = turn.decision;
    try t.expectEqualDeep(item, try ledger.begin(&turn, @splat(11), binding, @splat(0)));
    try t.expectError(error.SqlTokenConflict, ledger.begin(&turn, @splat(11), binding, @splat(1)));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqual(binding.namespace, item.namespace);
    try t.expectEqual(binding.role, item.selectedRole());
    var changed_binding = binding;
    changed_binding.role = null;
    try t.expectError(error.GatewayCatalogDenied, ledger.begin(&turn, @splat(11), changed_binding, @splat(0)));
    changed_binding = binding;
    changed_binding.namespace += 1;
    try t.expectError(error.GatewayCatalogDenied, ledger.begin(&turn, @splat(11), changed_binding, @splat(0)));
    try t.expectEqualDeep(before, turn.decision);
    var saved = try intent(item.id);
    defer saved.deinit();
    const spec = try g.station.Publication.Digest.of(g.LedgerRecords.intent_format, saved.bytes);
    try ledger.beginIntent(&turn, item.id, spec);
    try store.commit(turn);
    for (0..(saved.bytes.len + 127) / 128) |index| {
        turn = try store.capture();
        const offset: u32 = @intCast(index * 128);
        try ledger.intentPart(&turn, item.id, offset, saved.bytes[offset..][0..@min(128, saved.bytes.len - offset)]);
        try store.commit(turn);
    }
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try t.expectError(error.PublicationNotPublished, ledger.admitIntent(t.allocator, &turn, item.id, 1));
    store.origin = configuration.ingress;
    turn = try store.capture();
    try ledger.sealIntent(&turn, item.id);
    try store.commit(turn);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, ledger.admitIntent(t.allocator, &turn, item.id, 2));
    try ledger.admitIntent(t.allocator, &turn, item.id, 1);
    try store.commit(turn);
    turn = try store.capture();
    var committed = turn.committed();
    const ready = try ledger.operation(&committed, item.id);
    try t.expectEqual(g.LedgerRecords.Phase.ready, ready.phase);
    try t.expectEqual(@as(u64, 0), ready.pending);
    try t.expectEqual(@as(u64, 0), (try ledger.head(&committed)).sequence);
    // A second slot is available; a third admission cannot discard either one.
    store.origin = configuration.ingress;
    turn = try store.capture();
    _ = try ledger.begin(&turn, @splat(12), binding, @splat(0));
    try store.commit(turn);
    turn = try store.capture();
    const capacity_before = turn.decision;
    try t.expectError(error.GatewayAdmissionCapacity, ledger.begin(&turn, @splat(13), binding, @splat(0)));
    try t.expectEqualDeep(capacity_before, turn.decision);
    try t.expectEqual(g.LedgerRecords.Phase.ready, (try ledger.operation(&turn, item.id)).phase);
    // Only the fenced active coordinator may publish a signed step, and the
    // exact committed pending record survives a lost seal or send response.
    store.origin = configuration.coordinator;
    turn = try store.capture();
    _ = (try ledger.activate(&turn, 1)).?;
    try store.commit(turn);
    const payload = if (saved.body.len <= g.station.Frame.max_payload) try c.protocol.Value.init(saved.body) else try (c.TableControl.Command{ .begin = .{ .header = try saved.header.encode(), .namespace = saved.namespace, .spec = saved.spec } }).encode();
    const native = c.protocol.Growth;
    const step: c.TableClient.Prepared = .{ .version = 1, .definition = native.current_definition, .connection = .{ .scope = saved.header.scope, .owner = saved.header.owner, .principal = saved.header.principal, .namespace = binding.namespace, .role = binding.role }, .public_key = signing_key.public_key.toBytes(), .signed = try native.sign(.{ .realm = 1, .principal = configuration.table_principal, .sequence = 1, .command = .{ .send = .{ .pid = binding.owner, .role = binding.role, .value = try (g.station.Frame{ .kind = .cast, .payload = payload }).encode() } } }, signing_key) };
    // A valid newly signed request cannot change the operation's selected role.
    var switched = step;
    switched.connection.role = 30;
    switched.signed.request.command.send.role = 30;
    switched.signed = try native.sign(switched.signed.request, signing_key);
    const switched_record = try stage(&store, ledger, item.id, 1, switched);
    turn = try store.capture();
    try t.expectError(error.GatewayIdentityConflict, ledger.publishStep(t.allocator, &turn, item.id, 1, switched_record));
    try ledger.abandonStep(&turn, item.id, 1, switched_record);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.collectAbandonedStep(&turn, item.id, 1, switched_record);
    try store.commit(turn);
    // A valid signature at a foreign sequence remains unpublished. Its abandoned
    // attempt can be collected without ever changing/reusing its identity.
    var foreign = step;
    foreign.signed.request.sequence = 2;
    foreign.signed = try native.sign(foreign.signed.request, signing_key);
    const abandoned = try stage(&store, ledger, item.id, 1, foreign);
    turn = try store.capture();
    try t.expectError(error.GatewaySequenceConflict, ledger.publishStep(t.allocator, &turn, item.id, 1, abandoned));
    try ledger.abandonStep(&turn, item.id, 1, abandoned);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.collectAbandonedStep(&turn, item.id, 1, abandoned);
    try store.commit(turn);
    var storage: [g.SavedStep.max_bytes]u8 = undefined;
    const encoded = try g.SavedStep.encode(step, &storage);
    const step_spec = try g.station.Publication.Digest.of(g.SavedStep.format, encoded);
    turn = try store.capture();
    const record = try ledger.beginStep(&turn, item.id, 1, step_spec);
    try store.commit(turn);
    for (0..(encoded.len + 127) / 128) |index| {
        turn = try store.capture();
        const offset: u32 = @intCast(index * 128);
        try ledger.stepPart(&turn, item.id, 1, record, offset, encoded[offset..][0..@min(128, encoded.len - offset)]);
        try store.commit(turn);
    }
    turn = try store.capture();
    try ledger.publishStep(t.allocator, &turn, item.id, 1, record);
    committed = turn.committed();
    try t.expectEqual(@as(?c.TableClient.Prepared, null), try ledger.pendingStep(t.allocator, &committed, item.id));
    // A generation change fences this discarded proposal. The replacement can
    // validate the existing staged bytes and publish the same exact step.
    store.generation = 2;
    try t.expectError(error.StaleTestTurn, store.commit(turn));
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, ledger.publishStep(t.allocator, &turn, item.id, 1, record));
    try ledger.publishStep(t.allocator, &turn, item.id, 2, record);
    try store.commit(turn);
    turn = try store.capture();
    committed = turn.committed();
    try t.expectEqualDeep(step, (try ledger.pendingStep(t.allocator, &committed, item.id)).?);
    try t.expectError(error.GatewayUnresolvedStep, ledger.beginStep(&turn, item.id, 2, step_spec));
    try ledger.recordReceipt(&turn, item.id, 2, record, .{ .position = 321 });
    try store.commit(turn);
    turn = try store.capture();
    committed = turn.committed();
    try t.expectEqual(@as(u64, 1), (try ledger.head(&committed)).sequence);
    try t.expectEqualDeep(step, (try ledger.pendingStep(t.allocator, &committed, item.id)).?);
    const observed_before = turn.decision;
    try ledger.recordReceipt(&turn, item.id, 2, record, .{ .position = 321 });
    try t.expectEqualDeep(observed_before, turn.decision);
    try t.expectError(error.GatewayStepIdentityConflict, ledger.recordReceipt(&turn, item.id, 2, record, .{ .position = 322 }));
    // An operator cannot manufacture processed-input evidence or completion.
    store.origin = configuration.control;
    turn = try store.capture();
    try t.expectError(error.GatewayDenied, ledger.recordProcessed(t.allocator, &turn, item.id, 2, record, null));
    try ledger.reserveRecovery(&turn, item.id, 2048);
    try store.commit(turn);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try ledger.recordProcessed(t.allocator, &turn, item.id, 2, record, null);
    try store.commit(turn);
    turn = try store.capture();
    const processed_before = turn.decision;
    try ledger.recordProcessed(t.allocator, &turn, item.id, 2, record, null);
    try t.expectEqualDeep(processed_before, turn.decision);
    const result: c.TableClient.Outcome = .{ .ddl = .{ .operation = .{ .scope = saved.header.scope, .principal = saved.header.principal, .operation = item.id, .object = item.id, .actual_object = item.id, .digest = saved.identity.ddl.digest, .kind = .create, .state = .applied, .metadata = .{ .id = 1, .spec = .{ .format = c.TableMetadata.format, .length = 200, .digest = @splat(3) } }, .admitted_input = 321, .completed_input = 322 } } };
    try ledger.complete(&turn, item.id, 2, try g.Terminal.fromOutcome(result));
    try store.commit(turn);
    turn = try store.capture();
    const terminal_before = turn.decision;
    try ledger.complete(&turn, item.id, 2, try g.Terminal.fromOutcome(result));
    try t.expectEqualDeep(terminal_before, turn.decision);
    committed = turn.committed();
    try t.expectEqual(g.LedgerRecords.Summary.applied, (try ledger.operation(&committed, item.id)).summary);
    try t.expectEqual(@as(u64, 0), (try ledger.head(&committed)).active);
    const remaining = (try ledger.discover(&committed, @splat(12))).?;
    store.origin = configuration.control;
    turn = try store.capture();
    try ledger.request(&turn, remaining.id, .cancel);
    try store.commit(turn);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try ledger.cancelUnsent(&turn, remaining.id, 2);
    try store.commit(turn);
    turn = try store.capture();
    committed = turn.committed();
    try t.expectEqual(g.LedgerRecords.Phase.abandoned, (try ledger.operation(&committed, remaining.id)).phase);
    try t.expectEqual(@as(u64, 0), (try ledger.head(&committed)).unsettled);
    try t.expect(try ledger.indexed(&committed, .admission, 0) == null);
    try t.expect(try ledger.indexed(&committed, .ready, 0) == null);
    try t.expectEqual(@as(u64, 0), (try ledger.head(&committed)).reserved_bytes);
    try t.expectEqual(@as(u64, 2), (try ledger.head(&committed)).operations);
    try t.expect((try ledger.head(&committed)).used_bytes > saved.bytes.len);
    store.origin = configuration.control;
    turn = try store.capture();
    try t.expectError(error.GatewayCapacityDecrease, ledger.increaseCapacity(&turn, 999, config.byte_quota, 2));
    try ledger.increaseCapacity(&turn, 2000, 2 * config.byte_quota, 4);
    try store.commit(turn);
    store.origin = 99;
    turn = try store.capture();
    try t.expectError(error.GatewayDenied, ledger.begin(&turn, @splat(14), binding, @splat(0)));
}

test "gateway discovery advances across appends with current authority and rejects foreign or backward cursors" {
    var store: Store = .{};
    defer store.deinit();
    var config = configuration;
    config.pending_quota = 64;
    config.byte_quota = 16 * 1024 * 1024;
    const ledger: g.Ledger = .{ .configuration = config };
    var turn = try store.capture();
    try ledger.initialize(&turn, 0);
    try store.commit(turn);
    store.origin = config.ingress;
    for (0..27) |i| {
        turn = try store.capture();
        _ = try ledger.begin(&turn, @splat(@intCast(i)), binding, @splat(0));
        try store.commit(turn);
    }
    turn = try store.capture();
    var committed = turn.committed();
    var cursor: ?g.Ledger.Cursor = null;
    var count: usize = 0;
    var previous: u64 = 0;
    while (true) {
        const page = try ledger.list(&committed, cursor);
        for (page.entries) |slot| if (slot) |item| {
            try t.expect(item.id > previous);
            try t.expectEqualDeep(item, (try ledger.discover(&committed, item.nonce)).?);
            previous = item.id;
            count += 1;
        };
        cursor = page.next orelse break;
    }
    try t.expectEqual(@as(usize, 27), count);
    var indexed_count: usize = 0;
    previous = 0;
    while (try ledger.indexed(&committed, .admission, previous)) |item| {
        try t.expect(item.id > previous);
        previous = item.id;
        indexed_count += 1;
    }
    try t.expectEqual(count, indexed_count);
    try t.expect(try ledger.indexed(&committed, .ready, 0) == null);
    const first = try ledger.list(&committed, null);
    try t.expect(first.next != null);
    turn = try store.capture();
    _ = try ledger.begin(&turn, @splat(99), binding, @splat(0));
    try store.commit(turn);
    turn = try store.capture();
    committed = turn.committed();
    cursor = first.next;
    previous = first.entries[7].?.id;
    count = 8;
    while (true) {
        const page = try ledger.list(&committed, cursor);
        try t.expectEqual(store.revision, page.revision);
        for (page.entries) |slot| if (slot) |item| {
            try t.expect(item.id > previous);
            previous = item.id;
            count += 1;
        };
        cursor = page.next orelse break;
    }
    try t.expectEqual(@as(usize, 28), count);
    var foreign = first.next.?;
    foreign.realm += 1;
    try t.expectError(error.GatewayCursorChanged, ledger.list(&committed, foreign));
    foreign = first.next.?;
    foreign.resource += 1;
    try t.expectError(error.GatewayCursorChanged, ledger.list(&committed, foreign));
    foreign = first.next.?;
    foreign.configuration[0] ^= 1;
    try t.expectError(error.GatewayCursorChanged, ledger.list(&committed, foreign));
    foreign = first.next.?;
    foreign.revision = store.revision + 1;
    try t.expectError(error.GatewayCursorChanged, ledger.list(&committed, foreign));
    var other = ledger;
    other.configuration.account = @splat(99);
    try t.expectError(error.GatewayConfigurationChanged, other.list(&committed, null));
    store.denied = true;
    turn = try store.capture();
    committed = turn.committed();
    try t.expectError(error.AccessDenied, ledger.list(&committed, first.next));
}

fn stage(store: *Store, ledger: g.Ledger, id: u64, generation: u64, step: c.TableClient.Prepared) !u64 {
    var storage: [g.SavedStep.max_bytes]u8 = undefined;
    const bytes = try g.SavedStep.encode(step, &storage);
    var turn = try store.capture();
    const record = try ledger.beginStep(&turn, id, generation, try g.station.Publication.Digest.of(g.SavedStep.format, bytes));
    try store.commit(turn);
    for (0..(bytes.len + 127) / 128) |index| {
        turn = try store.capture();
        const offset: u32 = @intCast(index * 128);
        try ledger.stepPart(&turn, id, generation, record, offset, bytes[offset..][0..@min(128, bytes.len - offset)]);
        try store.commit(turn);
    }
    return record;
}
