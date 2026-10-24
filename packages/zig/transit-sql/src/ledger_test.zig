const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const Store = @import("store_test.zig");
const t = std.testing;
const binding: g.Ledger.Binding = .{ .resource = 8, .catalog = 1, .owner = 9, .namespace = 7, .role = 29 };
const configuration: g.Ledger.Configuration = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .account = @splat(7), .bindings = &.{binding}, .intent_bytes = 4096, .operation_quota = 1000, .byte_quota = 1024 * 1024, .pending_quota = 2 };
fn reference(id: u64) g.IntentReference.Reference {
    const scope: c.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = binding.resource, .catalog = binding.catalog };
    return .{ .table = .{ .definition = c.protocol.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = binding.owner, .principal = configuration.table_principal, .role = binding.role }, .namespace = binding.namespace, .content = .{ .bytes = 512, .sha256 = @splat(17) }, .binding = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = scope, .principal = configuration.table_principal, .operation = id }, .target = .{ .scope = scope, .branch = 1, .object = id }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(9) } } };
}
fn terminal(ref: g.IntentReference.Reference) !g.Terminal {
    const schema: c.fuze.TableSchema.Schema = .{ .object = ref.table.binding.target.object, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64 }} };
    var declaration = try c.storage.TableDeclaration.prepare(t.allocator, .{ .object = ref.table.binding.target, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    return (try g.Terminal.fromResult(ref.table.binding, .{ .ddl = .{ .committed = .{ .binding = ref.table.binding, .resulting = try declaration.stored(), .outcome = .{ .position = .{ .partition = 10, .next_lsn = 1 }, .matched = 0, .affected = 0, .live_rows = 0 } } } })).?;
}
fn publish(store: *Store, ledger: g.Ledger, ref: g.IntentReference.Reference) !void {
    var storage: [g.IntentReference.max_bytes]u8 = undefined;
    const bytes = try g.IntentReference.encode(ref, &storage);
    store.origin = configuration.ingress;
    var turn = try store.capture();
    try ledger.beginIntent(&turn, ref.identity().operation, try g.station.Publication.Digest.of(g.LedgerRecords.intent_format, bytes));
    try store.commit(turn);
    var offset: u32 = 0;
    while (offset < bytes.len) {
        turn = try store.capture();
        const count = @min(128, bytes.len - offset);
        try ledger.intentPart(&turn, ref.identity().operation, offset, bytes[offset..][0..count]);
        try store.commit(turn);
        offset += @intCast(count);
    }
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try t.expectError(error.PublicationNotPublished, ledger.admitIntent(t.allocator, &turn, ref.identity().operation, store.generation));
    store.origin = configuration.ingress;
    turn = try store.capture();
    try ledger.sealIntent(&turn, ref.identity().operation);
    try store.commit(turn);
}
test "frozen direct reference rejects altered connection, content and incompatible canonical bytes" {
    const ref = reference(19);
    var storage: [g.IntentReference.max_bytes]u8 = undefined;
    const bytes = try g.IntentReference.encode(ref, &storage);
    try t.expectEqualDeep(ref, try g.IntentReference.decode(t.allocator, bytes));
    for (0..bytes.len) |end| {
        if (g.IntentReference.decode(t.allocator, bytes[0..end])) |_| return error.ExpectedTruncationFailure else |_| {}
    }
    storage[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, g.IntentReference.decode(t.allocator, bytes));
    storage[4] ^= 1;
    const outcome = try terminal(ref);
    try outcome.matches(ref.table.binding);
    try t.expectEqualDeep(outcome, try g.LedgerRecords.decode(g.Terminal, try g.LedgerRecords.encode(outcome)));
    var altered = ref;
    altered.table.binding.target.object += 1;
    try t.expectError(error.GatewayIdentityConflict, outcome.matches(altered.table.binding));
    altered = ref;
    altered.table.binding.intent[0] ^= 1;
    try t.expectError(error.GatewayIdentityConflict, outcome.matches(altered.table.binding));
}
test "ledger gates direct dispatch durably and retains original binding through lost replies and replacement" {
    var store: Store = .{};
    defer store.deinit();
    const ledger: g.Ledger = .{ .configuration = configuration };
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    turn = try store.capture();
    const item = try ledger.begin(&turn, @splat(11), binding, @splat(0));
    try store.commit(turn);
    turn = try store.capture();
    const before = turn.decision;
    try t.expectEqualDeep(item, try ledger.begin(&turn, @splat(11), binding, @splat(0)));
    try t.expectError(error.SqlTokenConflict, ledger.begin(&turn, @splat(11), binding, @splat(1)));
    try t.expectEqualDeep(before, turn.decision);
    const ref = reference(item.id);
    var changed = ref;
    changed.table.connection.role = null;
    try t.expectError(error.GatewayIdentityConflict, ledger.checkReference(item, changed));
    changed = ref;
    changed.table.namespace += 1;
    try t.expectError(error.GatewayIdentityConflict, ledger.checkReference(item, changed));
    try publish(&store, ledger, ref);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, ledger.admitIntent(t.allocator, &turn, item.id, 2));
    try ledger.admitIntent(t.allocator, &turn, item.id, 1);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(item.id, (try ledger.activate(&turn, 1)).?.id);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.authorizeDispatch(&turn, item.id, 1);
    var committed = turn.committed();
    try t.expectEqual(@as(u8, 0), (try ledger.operation(&committed, item.id)).published);
    try store.commit(turn);
    // The dispatch gate's response is lost. Replacement sees the committed bit
    // and can only recover the exact reference; it cannot call the work unsent.
    store.generation = 2;
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, ledger.authorizeDispatch(&turn, item.id, 1));
    try ledger.authorizeDispatch(&turn, item.id, 2);
    committed = turn.committed();
    const active = try ledger.operation(&committed, item.id);
    try t.expectEqual(@as(u8, 1), active.published);
    try ref.requireSame(try ledger.readReference(t.allocator, &committed, active));
    store.origin = configuration.ingress;
    turn = try store.capture();
    try ledger.sessionRequest(&turn, item.id, .cancel);
    try store.commit(turn);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try t.expectError(error.GatewayRequiresQualifiedCancellation, ledger.cancelUnsent(&turn, item.id, 2));
    var outcome = try terminal(ref);
    outcome.identity[0] ^= 1;
    try t.expectError(error.GatewayIdentityConflict, ledger.complete(&turn, item.id, 2, outcome));
    outcome.identity[0] ^= 1;
    try ledger.complete(&turn, item.id, 2, outcome);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.complete(&turn, item.id, 2, outcome);
    outcome.next_lsn += 1;
    try t.expectError(error.GatewayIdentityConflict, ledger.complete(&turn, item.id, 2, outcome));
    try t.expectEqual(@as(u64, 0), (try ledger.head(&turn)).unsettled);
    try t.expectEqual(.terminal, (try ledger.operation(&turn, item.id)).phase);
}
test "cancellation before dispatch abandons SQL work without fabricating a Table outcome" {
    var store: Store = .{};
    defer store.deinit();
    const ledger: g.Ledger = .{ .configuration = configuration };
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    for (0..3) |phase| {
        store.origin = configuration.ingress;
        turn = try store.capture();
        const item = try ledger.begin(&turn, @splat(@intCast(phase + 1)), binding, @splat(0));
        try store.commit(turn);
        if (phase != 0) {
            try publish(&store, ledger, reference(item.id));
            store.origin = configuration.coordinator;
            turn = try store.capture();
            try ledger.admitIntent(t.allocator, &turn, item.id, 1);
            try store.commit(turn);
            if (phase == 2) {
                turn = try store.capture();
                _ = try ledger.activate(&turn, 1);
                try store.commit(turn);
            }
        }
        store.origin = configuration.ingress;
        turn = try store.capture();
        try ledger.sessionRequest(&turn, item.id, .cancel);
        try store.commit(turn);
        store.origin = configuration.coordinator;
        turn = try store.capture();
        if (phase == 2) try t.expectError(error.GatewayRequiresQualifiedCancellation, ledger.authorizeDispatch(&turn, item.id, 1));
        try ledger.cancelUnsent(&turn, item.id, 1);
        try store.commit(turn);
        turn = try store.capture();
        const observed = try ledger.operation(&turn, item.id);
        try t.expectEqual(.abandoned, observed.phase);
        try t.expectEqual(.none, observed.summary);
        try t.expectEqual(@as(u8, 0), observed.published);
        try t.expectEqual(@as(u64, 0), (try ledger.head(&turn)).unsettled);
    }
}
test "gateway discovery advances across appends with current authority and rejects foreign or backward cursors" {
    var store: Store = .{};
    defer store.deinit();
    var config = configuration;
    config.pending_quota = 64;
    config.byte_quota = 16 * 1024 * 1024;
    const ledger: g.Ledger = .{ .configuration = config };
    var turn = try store.capture();
    try ledger.initialize(&turn);
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

test "typed operation index binds tokens once and retains owner identities through quota release" {
    var store: Store = .{};
    defer store.deinit();
    const ledger: g.Ledger = .{ .configuration = configuration };
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    turn = try store.capture();
    const request: g.SessionOperations.Begin = .{ .nonce = @splat(7), .fingerprint = @splat(8), .kind = .configuration, .binding = binding, .original = @splat(9), .source = @splat(10), .expected_generation = 3, .reservation = 8192 };
    const original = try g.SessionOperations.begin(ledger, &turn, request);
    try store.commit(turn);
    turn = try store.capture();
    var retry = request;
    retry.original = @splat(99);
    retry.expected_generation = 9;
    try t.expectEqualDeep(original, try g.SessionOperations.begin(ledger, &turn, retry));
    retry.fingerprint = @splat(77);
    try t.expectError(error.SqlTokenConflict, g.SessionOperations.begin(ledger, &turn, retry));
    try t.expectError(error.SqlTokenConflict, ledger.begin(&turn, request.nonce, binding, @splat(88)));
    try t.expectError(error.InvalidSqlOperationReference, g.SessionOperations.complete(ledger, &turn, original.id, 1, .applied));
    try g.SessionOperations.ready(ledger, &turn, original.id, 1, 1024, @splat(12));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.StaleGatewayCoordinator, g.SessionOperations.complete(ledger, &turn, original.id, 2, .applied));
    try g.SessionOperations.complete(ledger, &turn, original.id, 1, .applied);
    try store.commit(turn);
    turn = try store.capture();
    const result = try g.SessionOperations.external(ledger, &turn, original.id);
    try t.expectEqual(.terminal, result.phase);
    try t.expectEqual(request.original, result.original);
    const head = try ledger.head(&turn);
    try t.expectEqual(@as(u64, 0), head.unsettled);
    try t.expectEqual(@as(u64, 8192), head.used_bytes);
    try t.expectEqual(@as(u64, 0), head.reserved_bytes);
    const all = try g.SessionOperations.list(ledger, &turn, 0, false);
    try t.expectEqual(original.id, all.entries[0].?.id);
    try t.expectEqual(@as(?g.SessionOperations.Reference, null), (try g.SessionOperations.list(ledger, &turn, 0, true)).entries[0]);
    try t.expectEqual(original.id, (try g.SessionOperations.lookup(ledger, &turn, request.nonce, request.fingerprint)).?.id);
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, g.SessionOperations.lookup(ledger, &turn, request.nonce, request.fingerprint));
}

test "SQL terminal rejects an acceptance position outside the frozen data expectation" {
    const ref = reference(17);
    const schema: c.fuze.TableSchema.Schema = .{ .object = ref.table.binding.target.object, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64 }} };
    var declaration = try c.storage.TableDeclaration.prepare(t.allocator, .{ .object = ref.table.binding.target, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    const stored = try declaration.stored();
    var original = ref.table.binding;
    original.action = .update;
    original.expected_definition = stored.interpretation;
    original.expected_data = .{ .partition = 10, .next_lsn = 20 };
    var evidence: c.storage.TablePartition.Evidence = .{ .binding = original, .resulting = stored, .outcome = .{ .position = .{ .partition = 10, .next_lsn = 21 }, .matched = 1, .affected = 1, .live_rows = 1 } };
    try t.expect((try g.Terminal.fromResult(original, .{ .rows = .{ .committed = evidence } })) != null);
    evidence.outcome.position.partition = 11;
    try t.expectError(error.InvalidGatewayTerminal, g.Terminal.fromResult(original, .{ .rows = .{ .committed = evidence } }));
    evidence.outcome.position = original.expected_data.?;
    try t.expectError(error.InvalidGatewayTerminal, g.Terminal.fromResult(original, .{ .rows = .{ .committed = evidence } }));
}

test "conditional DDL retains catalog evidence without inventing a Table commit" {
    var store: Store = .{};
    defer store.deinit();
    const ledger: g.Ledger = .{ .configuration = configuration };
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    turn = try store.capture();
    const item = try ledger.begin(&turn, @splat(81), binding, @splat(0));
    try store.commit(turn);
    const base = reference(item.id).table;
    const ref: g.IntentReference.Reference = .{ .name_assertion = .{ .definition = c.protocol.Growth.current_definition, .connection = base.connection, .operation = item.id, .namespace = binding.namespace, .name = try .init("absent"), .action = .drop_if_exists, .expected = null, .intent = @splat(81) } };
    try publish(&store, ledger, ref);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try ledger.admitIntent(t.allocator, &turn, item.id, 1);
    try store.commit(turn);
    turn = try store.capture();
    _ = try ledger.activate(&turn, 1);
    try store.commit(turn);
    const result: c.DirectTableProtocol.Result = .{ .name_assertion = .{ .outcome = .{ .binding = ref.name_assertion, .position = .{ .partition = 1, .next_lsn = 31 }, .state = .unchanged, .reason = .none } } };
    const outcome = (try g.Terminal.fromReference(ref, result)).?;
    try t.expectEqual(.catalog_assertion, outcome.kind);
    try t.expectEqual(.unchanged, outcome.state);
    try t.expectEqual(@as(u64, 0), outcome.object);
    try t.expectEqual(@as(u64, 0), outcome.resulting_revision);
    turn = try store.capture();
    try t.expectError(error.GatewayUnresolvedStep, ledger.complete(&turn, item.id, 1, outcome));
    try ledger.authorizeDispatch(&turn, item.id, 1);
    try store.commit(turn);
    store.generation = 2;
    turn = try store.capture();
    var committed = turn.committed();
    try ref.requireSame(try ledger.readReference(t.allocator, &committed, try ledger.operation(&committed, item.id)));
    try ledger.complete(&turn, item.id, 2, outcome);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.complete(&turn, item.id, 2, outcome);
    try t.expectEqual(.unchanged, (try ledger.operation(&turn, item.id)).summary);
    var changed = result;
    changed.name_assertion.outcome.binding.name = try .init("replacement");
    try t.expectError(error.DataIdentityConflict, g.Terminal.fromReference(ref, changed));
    try t.expectError(error.InvalidGatewayTerminal, g.Terminal.fromReference(ref, .{ .ddl = .not_observed }));
    var forged = outcome;
    forged.kind = .ddl;
    try t.expectError(error.InvalidGatewayTerminal, forged.validate());
    forged = outcome;
    forged.state = .applied;
    try t.expectError(error.InvalidGatewayTerminal, forged.validate());
    forged = outcome;
    forged.partition = 0;
    try t.expectError(error.InvalidGatewayTerminal, forged.validate());
    for ([_]@FieldType(c.NameAssertion.Outcome, "state"){ .rejected, .cancelled }) |state| {
        changed = result;
        changed.name_assertion.outcome.state = state;
        changed.name_assertion.outcome.reason = if (state == .rejected) .condition_changed else .none;
        const terminal_value = (try g.Terminal.fromReference(ref, changed)).?;
        try t.expectEqual(@as(u64, 31), terminal_value.next_lsn);
        try t.expectEqualDeep(terminal_value, try g.LedgerRecords.decode(g.Terminal, try g.LedgerRecords.encode(terminal_value)));
        try t.expectError(error.GatewayIdentityConflict, ledger.complete(&turn, item.id, 2, terminal_value));
    }
}

test "namespace dispatch retains selected context and exact catalog completion across replacement" {
    var store: Store = .{};
    defer store.deinit();
    const ledger: g.Ledger = .{ .configuration = configuration };
    var turn = try store.capture();
    try ledger.initialize(&turn);
    try store.commit(turn);
    store.origin = configuration.ingress;
    turn = try store.capture();
    const item = try ledger.begin(&turn, @splat(82), binding, @splat(0));
    try store.commit(turn);
    const ref: g.IntentReference.Reference = .{ .namespace_change = .{ .namespace = binding.namespace, .binding = .{
        .definition = c.protocol.Growth.current_definition,
        .connection = reference(item.id).connection(),
        .operation = item.id,
        .namespace = 101,
        .expected = null,
        .action = .{ .create = .{ .name = try .init("application_data"), .owner = 29 } },
    } } };
    try publish(&store, ledger, ref);
    store.origin = configuration.coordinator;
    turn = try store.capture();
    try ledger.admitIntent(t.allocator, &turn, item.id, 1);
    try store.commit(turn);
    turn = try store.capture();
    _ = try ledger.activate(&turn, 1);
    try store.commit(turn);
    const result: c.DirectTableProtocol.Result = .{ .namespace_operation = .{ .operation = .{
        .binding = ref.namespace_change.binding,
        .position = .{ .partition = 1, .next_lsn = 31 },
        .phase = .applied,
        .reason = .none,
        .after = null,
        .resulting = .{ .scope = ref.connection().scope, .id = 101, .authorization = 201, .name = try .init("application_data"), .revision = 1 },
    } } };
    const outcome = (try g.Terminal.fromReference(ref, result)).?;
    try t.expectEqual(.namespace_change, outcome.kind);
    try t.expectEqual(null, try result.namespace_operation.operation.diagnostic());
    try t.expectEqual(@as(u64, 101), outcome.object);
    try t.expectEqual(@as(u64, 0), outcome.matched);
    turn = try store.capture();
    try t.expectError(error.GatewayUnresolvedStep, ledger.complete(&turn, item.id, 1, outcome));
    try ledger.authorizeDispatch(&turn, item.id, 1);
    try store.commit(turn);
    store.generation = 2;
    turn = try store.capture();
    var committed = turn.committed();
    try ref.requireSame(try ledger.readReference(t.allocator, &committed, try ledger.operation(&committed, item.id)));
    try ledger.complete(&turn, item.id, 2, outcome);
    try store.commit(turn);
    turn = try store.capture();
    try ledger.complete(&turn, item.id, 2, outcome);
    var foreign = ref;
    foreign.namespace_change.namespace += 1;
    try t.expectError(error.GatewayIdentityConflict, ledger.checkReference(item, foreign));
    var changed = result;
    changed.namespace_operation.operation.binding.operation += 1;
    try t.expectError(error.DataIdentityConflict, g.Terminal.fromReference(ref, changed));
    try t.expectError(error.InvalidGatewayTerminal, g.Terminal.fromReference(ref, .{ .ddl = .not_observed }));
    for ([_]@FieldType(c.DirectNamespace.Operation, "phase"){ .admitted, .rejected, .cancelled }) |phase| {
        changed = result;
        changed.namespace_operation.operation.phase = phase;
        changed.namespace_operation.operation.reason = if (phase == .rejected) .dependency else .none;
        changed.namespace_operation.operation.resulting = null;
        const terminal_value = try g.Terminal.fromReference(ref, changed);
        const diagnostic = try changed.namespace_operation.operation.diagnostic();
        if (phase == .admitted) {
            try t.expect(terminal_value == null);
            try t.expectEqual(null, diagnostic);
        } else {
            try t.expectEqual(if (phase == .rejected) c.protocol.Diagnostic.Outcome.rejected else .cancelled, diagnostic.?.outcome);
            try t.expectEqual(item.id, try diagnostic.?.identity.?.id.value());
            if (phase == .rejected) {
                try t.expectEqualStrings("schema.drop_restricted", diagnostic.?.code.slice());
                try t.expectEqual(.withheld, diagnostic.?.facts[0].?.availability);
            }
            try t.expectEqualDeep(terminal_value.?, try g.LedgerRecords.decode(g.Terminal, try g.LedgerRecords.encode(terminal_value.?)));
            try t.expectError(error.GatewayIdentityConflict, ledger.complete(&turn, item.id, 2, terminal_value.?));
        }
    }
}
