const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Policy = @import("LocalCatalogPolicy.zig");
const p = c.protocol;
const g = p.Growth;
const a = p.Authorization;
const Engine = backend.DataAuthority.Engine;
const D = c.DirectCatalog;

fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}
fn command(engine: *Engine, value: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = value }, try key(17)));
}
fn outcome(engine: *Engine, id: u64) !a.Outcome {
    const response = try engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = .{ .authorization = .{ .kind = .{ .change = id } } } }, try key(17)));
    return response.body.authorization.body.change;
}
fn change(engine: *Engine, action: a.Action) !?u64 {
    const id = try command(engine, .{ .authorization = .{ .begin = .{ .expected_revision = engine.head.authorization.revision, .action = action } } });
    return finish(engine, id);
}
fn finish(engine: *Engine, id: u64) !?u64 {
    while (true) {
        const observed = try outcome(engine, id);
        switch (observed.status) {
            .preparing => _ = try command(engine, .{ .authorization = .{ .advance = id } }),
            .ready => _ = try command(engine, .{ .authorization = .{ .publish = id } }),
            .published => return observed.created_id,
            .abandoned => return error.UnexpectedAbandonedChange,
        }
    }
}
fn proof(engine: *Engine, context: [32]u8) !a.Proof {
    return a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 101, .credential_epoch = (try engine.principal(101)).credential_epoch, .role = null, .audience = 100, .context = context }, try key(29));
}

fn dispatch(service: *@import("LocalTableService.zig"), action: c.DirectTableProtocol.Action) !std.json.Parsed(c.DirectTableProtocol.Response) {
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const input: w.Request.Input = .{ .definition = g.current_definition, .connection = .{ .scope = service.configuration.scope, .branch = service.configuration.branch, .audience = service.configuration.audience, .principal = 101, .role = null }, .nonce = @splat(7), .action = action };
    const signed = try proof(service.engine, try w.Request.context(input, alloc));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .proof = signed };
    const bytes = try p.Json.valueAlloc(alloc, request);
    const parsed = try w.Request.parse(alloc, bytes);
    const output = try alloc.alloc(u8, 1024 * 1024);
    const response = try p.Json.parseFromSliceOwned(w.Response, t.allocator, try service.execute(&arena, parsed.value, output));
    errdefer response.deinit();
    try c.DirectTableClient.validateResponse(alloc, parsed.value, response.value);
    if (response.value.result == .lookup and response.value.result.lookup != null) {
        var altered = response.value;
        altered.result.lookup.?.authorization += 1;
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, parsed.value, altered));
    }
    if (response.value.result == .page) {
        var altered = response.value;
        altered.result.page.encoded_bytes += 1;
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, parsed.value, altered));
        altered = response.value;
        altered.result.page.snapshot.handle.owner.operation += 1;
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, parsed.value, altered));
    }
    try t.expectEqualDeep(signed.claim.context, response.value.context);
    return response;
}

fn directDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .namespace = 1, .name = try .init("through_dispatch"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 200 }, .target = .{ .scope = config.scope, .branch = 1, .object = 10 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc) };
    var buffer: [65536]u8 = undefined;
    const schema_wire = try w.Binary.encode(alloc, try schema.encode(&buffer));
    const ddl: w.Ddl = .{ .binding = binding, .namespace = 1, .name = intent.name.slice(), .action = .{ .create = .{ .owner = owner_role, .schema = schema_wire } } };
    const admitted = try dispatch(&service, .{ .admit_ddl = ddl });
    defer admitted.deinit();
    try t.expect(admitted.value.result.ddl == .admitted);
    const hidden = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = ddl.name } });
    defer hidden.deinit();
    try t.expect(hidden.value.result.lookup == null);
    const head = engine.head.position;
    const pending = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } });
    defer pending.deinit();
    try t.expect(pending.value.result.ddl == .admitted);
    try t.expectEqual(head, engine.head.position);
    const committed = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer committed.deinit();
    try t.expect(committed.value.result.ddl == .committed);
    const repeated = try dispatch(&service, .{ .admit_ddl = ddl });
    defer repeated.deinit();
    try t.expectEqualDeep(committed.value.result, repeated.value.result);
    const definition = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = ddl.name } });
    defer definition.deinit();
    try t.expectEqual(engine.head.authorization.revision, definition.value.policy_revision);
    const selected = definition.value.result.lookup.?;
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 201, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 12 } } }} };
    var work: w.Rows = .{ .binding = binding, .interpretation = selected.interpretation, .schema = schema_wire, .changes = &.{.{ .insert = try w.Binary.encode(alloc, try row.encode(schema, &buffer)) }}, .ingestion = .bulk };
    work.binding.identity.operation = 201;
    work.binding.action = .insert;
    work.binding.expected_definition = selected.interpretation.interpretation;
    work.binding.intent = try work.digest(alloc);
    const row_admitted = try dispatch(&service, .{ .admit_rows = work });
    defer row_admitted.deinit();
    try t.expect(row_admitted.value.result.rows == .admitted);
    const rows = try dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } });
    defer rows.deinit();
    try t.expectEqual(@as(u64, 1), rows.value.result.rows.committed.outcome.affected);
    const pinned = try dispatch(&service, .{ .pin = .{ .object = binding.target, .owner = .{ .scope = config.scope, .principal = 101, .operation = 202 }, .expected = rows.value.result.rows.committed.outcome.position } });
    defer pinned.deinit();
    const snapshot: w.Snapshot = .{ .object = binding.target, .handle = pinned.value.result.pin };
    const historical = try dispatch(&service, .{ .snapshot = snapshot });
    defer historical.deinit();
    try t.expectEqual(@as(u64, 1), historical.value.result.snapshot.row_count);
    const scanned = try dispatch(&service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } });
    defer scanned.deinit();
    try t.expectEqual(@as(usize, 1), scanned.value.result.page.rows.len);
    try t.expect(scanned.value.result.page.next == null);
    const decoded = try c.fuze.TableRow.decode(alloc, schema, try scanned.value.result.page.rows[0].decode(alloc, buffer.len));
    try t.expectEqualDeep(row, decoded.row());
    // Read/modify/write uses the pinned source frontier. Acquiring that pin
    // advances control history but must not make its own data basis stale.
    work.binding.identity.operation = 203;
    work.binding.action = .update;
    work.binding.expected_data = historical.value.result.snapshot.accepted;
    work.changes = &.{.{ .update = .{ .key = try w.Binary.encode(alloc, try row.storageKey(schema, &buffer)), .row = work.changes[0].insert } }};
    work.binding.intent = try work.digest(alloc);
    const from_pin = try dispatch(&service, .{ .admit_rows = work });
    defer from_pin.deinit();
    try t.expect(from_pin.value.result.rows == .admitted);
    const unchanged = try dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } });
    defer unchanged.deinit();
    try t.expectEqual(@as(u64, 1), unchanged.value.result.rows.committed.outcome.matched);
    try t.expectEqual(@as(u64, 0), unchanged.value.result.rows.committed.outcome.affected);
    // The service accumulates checked rights and suppresses already-buffered
    // rows if native ownership changes before the final disclosure fence.
    var store = try engine.authorization();
    const native_table = (try store.bound(config.authority.table_domain, try c.TableAuthority.binding(config.scope, .table, 10))).?.reference.id;
    const Revoke = struct {
        fn run(context: *anyopaque, current: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(context));
            _ = try change(current, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var revoke_id = native_table;
    service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }));
    service.before_reply = null;
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    const released = try dispatch(&service, .{ .release = snapshot });
    defer released.deinit();
    try t.expect(released.value.result == .released);
    // Predicate evaluation is private work under UPDATE, not a SELECT disclosure.
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = 0 } });
    _ = try change(engine, .{ .grant = .{ .object = c.TableAuthority.reference(native_table), .grantee = owner_role, .privileges = c.TableAuthority.update } });
    const basis = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = ddl.name } });
    defer basis.deinit();
    const access = try dispatch(&service, .{ .check = .{ .namespace = 1, .target = basis.value.result.lookup.?.interpretation.interpretation, .access = .update } });
    defer access.deinit();
    try t.expect(access.value.result == .checked);
    try t.expectEqual(owner_role, access.value.subject.role);
    try t.expectError(error.Forbidden, dispatch(&service, .{ .check = .{ .namespace = 1, .target = basis.value.result.lookup.?.interpretation.interpretation, .access = .read } }));
    var compiled = try c.fuze.TableDml.compile(alloc, "UPDATE through_dispatch SET id = 13 WHERE id = 12", ddl.name, schema, null);
    defer compiled.deinit();
    var statement: w.Statement = .{ .binding = work.binding, .interpretation = selected.interpretation, .schema = schema_wire, .plan = try w.Binary.encode(alloc, try c.fuze.TableDmlCodec.encode(alloc, compiled.plan, &buffer)) };
    statement.binding.identity.operation = 204;
    statement.binding.expected_data = basis.value.result.lookup.?.position;
    statement.binding.intent = try statement.digest(alloc);
    const private_admission = try dispatch(&service, .{ .admit_statement = statement });
    defer private_admission.deinit();
    try t.expect(private_admission.value.result.rows == .admitted);
    const private_result = try dispatch(&service, .{ .operation = .{ .binding = statement.binding, .command = .execute, .steps = 1 } });
    defer private_result.deinit();
    try t.expectEqual(@as(u64, 1), private_result.value.result.rows.committed.outcome.affected);
    try t.expectError(error.Forbidden, dispatch(&service, .{ .pin = .{ .object = binding.target, .owner = .{ .scope = config.scope, .principal = 101, .operation = 205 }, .expected = private_result.value.result.rows.committed.outcome.position } }));
}

test "local catalog checks real native registrations, current ownership and exact request proof" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, .{ .realm = 42, .root_key = (try key(17)).public_key.toBytes() });
    const pid = try command(&engine, .{ .spawn = .{} });
    const resource = try command(&engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    const role = (try change(&engine, .{ .create_role = .{ .name = try p.Value.init("catalog-owner"), .login = true } })).?;
    _ = try change(&engine, .{ .bind_credential = .{ .principal = 101, .role = role, .public_key = (try key(29)).public_key.toBytes() } });
    const database_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
    const request_digest: [32]u8 = @splat(5);
    const signed = try proof(&engine, request_digest);
    try t.expectError(error.InvalidAuthorizationCredential, Policy.init(&engine, config, signed, @splat(6)));
    var forged = signed;
    forged.signature[0] ^= 1;
    try t.expectError(error.Forbidden, Policy.init(&engine, config, forged, request_digest));
    var policy = try Policy.init(&engine, config, signed, request_digest);
    var control: backend.DataStore = .{ .backend = &owner, .control = true };
    var data: backend.DataStore = .{ .backend = &owner };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    defer catalog.deinit();
    try catalog.recover();
    try catalog.initialize(policy.policy());
    try directDispatch(&engine, config, role);
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const intent: D.Intent = .{ .namespace = 1, .name = try c.TableAuthority.Name.init("events"), .action = .{ .create = .{ .owner = role, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} } } } };
    const request: D.Request = .{ .intent = intent, .binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 1 }, .target = .{ .scope = scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) } };
    _ = try catalog.admit(request, policy.policy());
    try t.expectError(error.CatalogRegistrationRequired, catalog.perform(request.binding, policy.policy()));
    const registration = (try catalog.registration(request.binding, policy.policy())).?;
    try t.expectEqual(role, registration.action.owner);
    const at = catalog.store.root.next_lsn;
    _ = try change(&engine, .{ .create_role = .{ .name = try p.Value.init("unrelated-policy-change") } });
    try t.expectError(error.StaleAuthorizationRevision, command(&engine, .{ .authorization = .{ .begin = .{ .expected_revision = registration.authorization_revision, .action = .{ .register_object = registration.action } } } }));
    const fresh = (try catalog.registration(request.binding, policy.policy())).?;
    const prepared = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .{ .authorization = .{ .begin = .{ .expected_revision = fresh.authorization_revision, .action = .{ .register_object = fresh.action } } } } }, try key(17));
    const native_change = try engine.submit(prepared);
    try t.expectEqual(native_change, try engine.submit(prepared));
    try catalog.recover();
    try t.expectEqual(at, catalog.store.root.next_lsn);
    try t.expect((try catalog.status(request.binding, policy.policy())) == .admitted);
    try t.expect((try catalog.resolve(t.allocator, 1, intent.name, policy.policy())) == null);
    const table = (try finish(&engine, native_change)).?;
    try t.expect((try catalog.registration(request.binding, policy.policy())) == null);
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.attachRegistration(request.binding, policy.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    try t.expectEqual(.ready, (try catalog.status(request.binding, policy.policy())).admitted.phase);
    const ready_at = catalog.store.root.next_lsn;
    _ = try catalog.attachRegistration(request.binding, policy.policy());
    try t.expectEqual(ready_at, catalog.store.root.next_lsn);
    try t.expect((try catalog.resolve(t.allocator, 1, intent.name, policy.policy())) == null);
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.perform(request.binding, policy.policy()));
    try t.expect((try catalog.resolve(t.allocator, 1, intent.name, policy.policy())) == null);
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    try t.expect((try catalog.perform(request.binding, policy.policy())) == .committed);
    var view = (try catalog.resolve(t.allocator, 1, intent.name, policy.policy())).?;
    defer view.deinit();
    try t.expectEqual(@as(u64, 7), view.table.root.interpretation.object.object);
    // Domain ownership works without granting the caller raw resource access.
    var raw: a.Guard = .{ .subject = .{ .signed = signed }, .requirements = @splat(null) };
    raw.requirements[0] = .{ .object = .{ .kind = .resource, .id = resource }, .privileges = p.State.permission(.read) };
    try t.expectError(error.Forbidden, engine.authorizeDomain(raw, config.audience));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.status(request.binding, policy.policy()));
    try t.expectError(error.Forbidden, catalog.resolve(t.allocator, 1, intent.name, policy.policy()));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    try t.expect((try catalog.status(request.binding, policy.policy())) == .committed);
    const row_cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 1 } } }};
    const row_request: c.storage.TableDmlIntent.Request = .{
        .binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 2 }, .target = request.binding.target, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(9) },
        .interpretation = view.table.root.declared(),
        .changes = &.{.{ .put = .{ .row = .{ .identity = .{ .origin = 102, .operation = 2, .ordinal = 0 }, .cells = &row_cells }, .expect = .absent } }},
        .ingestion = .point,
    };
    const directory = catalog.store.root;
    _ = try catalog.admitRows(row_request, policy.policy());
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.performRows(row_request.binding, policy.policy()));
    try t.expectError(error.Forbidden, catalog.cancelRows(row_request.binding, policy.policy()));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    // Exhausted ordinary capacity does not evict admitted work. Explicit
    // cancellation uses the same physical namespace's reserved control budget.
    const limits = owner.limits;
    owner.limits.bytes = owner.allocated;
    try t.expectError(error.StorageQuota, catalog.performRows(row_request.binding, policy.policy()));
    try t.expect((try catalog.rowStatus(row_request.binding, policy.policy())) == .admitted);
    try t.expect((try catalog.cancelRows(row_request.binding, policy.policy())) == .cancelled);
    try t.expectEqualDeep(directory, catalog.store.root);
    owner.limits = limits;
    var succeeding = row_request;
    succeeding.binding.identity.operation = 3;
    var inserted = row_request.changes[0];
    inserted.put.row.identity = try c.storage.TableDmlIntent.insertIdentity(succeeding.binding.identity, 0);
    succeeding.changes = &.{inserted};
    const accepted = (try catalog.applyRows(succeeding, policy.policy())).committed;
    try t.expectEqual(@as(u64, 1), accepted.outcome.affected);
    const retained = try catalog.pinRows(request.binding.target, .{ .scope = scope, .principal = 101, .operation = 80 }, accepted.outcome.position, policy.policy());
    var read = try catalog.scanRows(t.allocator, request.binding.target, retained, null, .{}, policy.policy());
    defer read.deinit();
    try t.expectEqual(@as(u8, 1), read.count);
    try t.expectEqual(@as(i128, 1), read.rows[0].?.row().cells[0].value.atom.signed);
    var historical = try catalog.snapshotDefinition(t.allocator, request.binding.target, retained, policy.policy());
    defer historical.deinit();
    try t.expectEqualDeep(accepted.resulting, historical.root.declared());
    var another_principal = retained;
    another_principal.owner.principal = 0;
    try t.expectError(error.CatalogDenied, catalog.scanRows(t.allocator, request.binding.target, another_principal, null, .{}, policy.policy()));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.scanRows(t.allocator, request.binding.target, retained, null, .{}, policy.policy()));
    try t.expectError(error.Forbidden, catalog.releaseRows(request.binding.target, retained, policy.policy()));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    owner.limits.bytes = owner.allocated;
    try catalog.releaseRows(request.binding.target, retained, policy.policy());
    owner.limits = limits;
    try t.expectError(error.TableSnapshotReleased, catalog.scanRows(t.allocator, request.binding.target, retained, null, .{}, policy.policy()));
    var runner: @import("LocalCatalogRunner.zig") = .{ .engine = &engine, .principal = 0, .key = try key(17) };
    try t.expectError(error.InvalidCatalogStepBudget, runner.run(&catalog, request.binding, policy.policy(), 0));
    var unknown = request.binding;
    unknown.identity.operation = 999;
    const before_unknown = engine.head.position;
    try t.expect((try runner.run(&catalog, unknown, policy.policy(), 1)).observation == .not_observed);
    try t.expectEqual(before_unknown, engine.head.position);
    var automatic = request;
    automatic.intent.name = try c.TableAuthority.Name.init("runner");
    automatic.intent.action.create.schema.object = 8;
    automatic.binding.identity.operation = 4;
    automatic.binding.target.object = 8;
    automatic.binding.intent = try automatic.intent.digest(t.allocator);
    _ = try catalog.admit(automatic, policy.policy());
    const one_step = try runner.run(&catalog, automatic.binding, policy.policy(), 1);
    try t.expect(one_step.observation == .admitted);
    try t.expectEqual(@as(u16, 1), one_step.native_steps);
    journal.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, runner.run(&catalog, automatic.binding, policy.policy(), 1));
    journal.lose_reply = false;
    engine = try Engine.open(&journal, &pages, engine.genesis);
    try catalog.recover();
    const executed = try runner.run(&catalog, automatic.binding, policy.policy(), 16);
    try t.expect(executed.observation == .committed);
    const native_position = engine.head.position;
    try t.expectEqualDeep(executed.observation, (try runner.run(&catalog, automatic.binding, policy.policy(), 16)).observation);
    try t.expectEqual(native_position, engine.head.position);
    var resolved = (try catalog.resolve(t.allocator, 1, automatic.intent.name, policy.policy())).?;
    defer resolved.deinit();
    try t.expectEqual(@as(u64, 8), resolved.table.root.interpretation.object.object);
    var interrupted = automatic;
    interrupted.intent.name = try c.TableAuthority.Name.init("interrupted");
    interrupted.intent.action.create.schema.object = 9;
    interrupted.binding.identity.operation = 5;
    interrupted.binding.target.object = 9;
    interrupted.binding.intent = try interrupted.intent.digest(t.allocator);
    _ = try catalog.admit(interrupted, policy.policy());
    const Race = struct {
        resource: u64,
        fn retire(context: *anyopaque, authority: *Engine) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            _ = try command(authority, .{ .retire_resource = self.resource });
        }
    };
    var race: Race = .{ .resource = resource };
    runner.after_prepare = .{ .context = &race, .run = Race.retire };
    try t.expectError(error.StateResourceExpired, runner.run(&catalog, interrupted.binding, policy.policy(), 16));
    var authority = try engine.authorization();
    try t.expect(try authority.bound(table_domain, try c.TableAuthority.binding(scope, .table, 9)) == null);
    try t.expectError(error.StateResourceExpired, catalog.status(request.binding, policy.policy()));
    try t.expectError(error.StateResourceExpired, catalog.rowStatus(succeeding.binding, policy.policy()));
}
