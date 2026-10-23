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
    return dispatchDelegated(service, action, null);
}
fn dispatchDelegated(service: *@import("LocalTableService.zig"), action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return dispatchBorrowed(service, action, delegation, null);
}
fn dispatchBorrowed(service: *@import("LocalTableService.zig"), action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow) !std.json.Parsed(c.DirectTableProtocol.Response) {
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const input: w.Request.Input = .{ .definition = g.current_definition, .connection = .{ .scope = service.configuration.scope, .branch = service.configuration.branch, .audience = service.configuration.audience, .principal = 101, .role = null }, .delegation = delegation, .borrow = borrow, .nonce = @splat(7), .action = action };
    const context = try w.Request.context(input, alloc);
    const executor = if (borrow) |value| value.binding.executor else if (delegation) |value| value.binding.executor else 101;
    const signed = if (delegation != null) try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = executor, .credential_epoch = (try service.engine.principal(executor)).credential_epoch, .role = null, .audience = service.configuration.audience, .context = context }, try key(if (borrow != null) 33 else 31)) else try proof(service.engine, context);
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .borrow = input.borrow, .proof = signed };
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
    if (response.value.result == .point) {
        var altered = response.value;
        altered.result.point.snapshot.handle.owner.operation += 1;
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
    const present_key = try w.Binary.encode(alloc, try row.storageKey(schema, &buffer));
    const absent_key = try w.Binary.encode(alloc, try c.fuze.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = 99 } } }}, false, &buffer));
    const point = try dispatch(&service, .{ .read_key = .{ .snapshot = snapshot, .key = present_key } });
    defer point.deinit();
    const point_row = try c.fuze.TableRow.decode(alloc, schema, try point.value.result.point.row.?.decode(alloc, buffer.len));
    try t.expectEqualDeep(row, point_row.row());
    const absent = try dispatch(&service, .{ .read_key = .{ .snapshot = snapshot, .key = absent_key } });
    defer absent.deinit();
    try t.expect(absent.value.result.point.row == null);
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
    try delegatedDispatch(&service, snapshot, historical.value.result.snapshot, owner_role, native_table);
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
    for ([_]w.Binary{ present_key, absent_key }) |lookup_key| {
        service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatch(&service, .{ .read_key = .{ .snapshot = snapshot, .key = lookup_key } }));
        service.before_reply = null;
        _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    }
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
    var saved = try c.DirectTableIntent.create(alloc, .{ .scope = config.scope, .branch = config.branch, .audience = config.audience, .principal = 101, .role = null }, .{ .statement = statement });
    defer saved.deinit();
    const staged = try dispatch(&service, .{ .stage = .{ .namespace = 1, .intent = saved.parsed.value } });
    defer staged.deinit();
    try (try saved.reference(1)).requireSame(staged.value.result.staged);
    const unstaged_position = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = ddl.name } });
    defer unstaged_position.deinit();
    try t.expectEqualDeep(basis.value.result.lookup.?.position, unstaged_position.value.result.lookup.?.position);
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(config.authority.initial_schema_authority), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&service, .{ .admit_saved = staged.value.result.staged }));
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(config.authority.initial_schema_authority), .owner = owner_role } });
    const private_admission = try dispatch(&service, .{ .admit_saved = staged.value.result.staged });
    defer private_admission.deinit();
    try t.expect(private_admission.value.result.rows == .admitted);
    const private_result = try dispatch(&service, .{ .operation = .{ .binding = statement.binding, .command = .execute, .steps = 1 } });
    defer private_result.deinit();
    try t.expectEqual(@as(u64, 1), private_result.value.result.rows.committed.outcome.affected);
    try t.expectError(error.Forbidden, dispatch(&service, .{ .pin = .{ .object = binding.target, .owner = .{ .scope = config.scope, .principal = 101, .operation = 205 }, .expected = private_result.value.result.rows.committed.outcome.position } }));
}

fn delegatedDispatch(service: *@import("LocalTableService.zig"), snapshot: c.DirectTableProtocol.Snapshot, source: c.DirectTableProtocol.Source, owner_role: u64, native_table: u64) !void {
    const w = c.DirectTableProtocol;
    const engine = service.engine;
    const executor_role = (try change(engine, .{ .create_role = .{ .name = try .init("read-executor"), .login = true } })).?;
    _ = try change(engine, .{ .bind_credential = .{ .principal = 102, .role = executor_role, .public_key = (try key(31)).public_key.toBytes() } });
    const binding: c.DirectReadDelegation.Binding = .{
        .definition = g.current_definition,
        .connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null },
        .executor = 102,
        .interpretation = source.interpretation.interpretation,
        .expected = source.accepted,
        .owner = snapshot.handle.owner,
        .retention = .snapshot,
        .purpose = @splat(19),
    };
    const grant: c.DirectReadDelegation = .{ .binding = binding, .proof = try proof(engine, try binding.context(t.allocator)) };
    const worker_proof = try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 102, .credential_epoch = (try engine.principal(102)).credential_epoch, .role = null, .audience = service.configuration.audience, .context = @splat(21) }, try key(31));
    // The executor has no CONNECT or Table privileges of its own.
    try t.expectError(error.Forbidden, Policy.init(engine, service.configuration, worker_proof, @splat(21), null));
    const read = try dispatchDelegated(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, grant);
    defer read.deinit();
    try t.expectEqual(@as(usize, 1), read.value.result.page.rows.len);
    try t.expectEqualDeep(grant.proof.claim.context, read.value.subject.context);
    try t.expectEqual(@as(u64, 101), read.value.subject.principal);
    const schema_bytes = try source.schema.decode(t.allocator, c.fuze.TableSchema.max_bytes);
    defer t.allocator.free(schema_bytes);
    var schema = try c.fuze.TableSchema.decode(t.allocator, schema_bytes);
    defer schema.deinit();
    var key_bytes: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const point_key = try w.Binary.encode(t.allocator, try c.fuze.Collation.encodePrimaryKeySortKey(schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 12 } } }}, false, &key_bytes));
    defer t.allocator.free(point_key.base64);
    const point = try dispatchDelegated(service, .{ .read_key = .{ .snapshot = snapshot, .key = point_key } }, grant);
    defer point.deinit();
    try t.expectEqualStrings(read.value.result.page.rows[0].base64, point.value.result.point.row.?.base64);
    try t.expectEqualDeep(grant.proof.claim.context, point.value.subject.context);
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .describe, grant));

    const current = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "through_dispatch" } });
    defer current.deinit();
    var fresh = binding;
    fresh.owner.operation = 206;
    fresh.expected = current.value.result.lookup.?.position;
    const acquire: c.DirectReadDelegation = .{ .binding = fresh, .proof = try proof(engine, try fresh.context(t.allocator)) };
    const acquisition: w.Action = .{ .pin = .{ .object = fresh.interpretation.object, .owner = fresh.owner, .expected = fresh.expected } };
    const pinned = try dispatchDelegated(service, acquisition, acquire);
    defer pinned.deinit();
    const retry = try dispatchDelegated(service, acquisition, acquire);
    defer retry.deinit();
    try t.expectEqualDeep(pinned.value.result, retry.value.result);
    const fresh_snapshot: w.Snapshot = .{ .object = fresh.interpretation.object, .handle = pinned.value.result.pin };
    const released = try dispatchDelegated(service, .{ .release = fresh_snapshot }, acquire);
    released.deinit();
    const released_again = try dispatchDelegated(service, .{ .release = fresh_snapshot }, acquire);
    released_again.deinit();
    try t.expectError(error.TableSnapshotReleased, dispatchDelegated(service, acquisition, acquire));

    const borrower_role = (try change(engine, .{ .create_role = .{ .name = try .init("borrowed-reader"), .login = true } })).?;
    _ = try change(engine, .{ .bind_credential = .{ .principal = 103, .role = borrower_role, .public_key = (try key(33)).public_key.toBytes() } });
    const borrowed = try makeBorrow(service, grant, .{ .snapshot = snapshot });
    const borrowed_rows = try dispatchBorrowed(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, grant, borrowed);
    defer borrowed_rows.deinit();
    try t.expectEqualStrings(read.value.result.page.rows[0].base64, borrowed_rows.value.result.page.rows[0].base64);
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, .{ .release = snapshot }, grant, borrowed));
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, acquisition, grant, borrowed));

    try delegatedHistory(service, grant, owner_role, native_table);

    var wrong = binding;
    wrong.interpretation.revision += 1;
    const wrong_grant: c.DirectReadDelegation = .{ .binding = wrong, .proof = try proof(engine, try wrong.context(t.allocator)) };
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .snapshot = snapshot }, wrong_grant));
    try t.expectError(error.TableDefinitionChanged, dispatchDelegated(service, .{ .pin = .{ .object = wrong.interpretation.object, .owner = wrong.owner, .expected = wrong.expected } }, wrong_grant));

    const Rotation = struct {
        principal: u64,
        seed: u8,
        fn run(context: *anyopaque, current_engine: *Engine) !void {
            const value: *@This() = @ptrCast(@alignCast(context));
            _ = try change(current_engine, .{ .rotate_credential = .{ .principal = value.principal, .expected_epoch = (try current_engine.principal(value.principal)).credential_epoch, .public_key = (try key(value.seed)).public_key.toBytes() } });
        }
    };
    var worker_rotation: Rotation = .{ .principal = 102, .seed = 32 };
    service.before_reply = .{ .context = &worker_rotation, .run = Rotation.run };
    try t.expectError(error.StaleAuthorizationCredential, dispatchDelegated(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, grant));
    service.before_reply = null;
    // A fresh executor proof can resume under the retained original delegation.
    worker_rotation.seed = 31;
    try Rotation.run(&worker_rotation, engine);
    const resumed = try dispatchDelegated(service, .{ .snapshot = snapshot }, grant);
    resumed.deinit();

    const Revoke = struct {
        fn run(context: *anyopaque, current_engine: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(context));
            _ = try change(current_engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var table = native_table;
    service.before_reply = .{ .context = &table, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatchDelegated(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, grant));
    service.before_reply = null;
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = owner_role } });

    var caller_rotation: Rotation = .{ .principal = 101, .seed = 30 };
    service.before_reply = .{ .context = &caller_rotation, .run = Rotation.run };
    try t.expectError(error.StaleAuthorizationCredential, dispatchDelegated(service, .{ .snapshot = snapshot }, grant));
    service.before_reply = null;
    // Retrying never refreshes the original accepted caller proof.
    caller_rotation.seed = 29;
    try Rotation.run(&caller_rotation, engine);
    try t.expectError(error.StaleAuthorizationCredential, dispatchBorrowed(service, .{ .snapshot = snapshot }, grant, borrowed));
    try t.expectError(error.StaleAuthorizationCredential, dispatchDelegated(service, .{ .snapshot = snapshot }, grant));
}

fn makeBorrow(service: *@import("LocalTableService.zig"), grant: c.DirectReadDelegation, target: c.DirectReadDelegation.Borrow.Target) !c.DirectReadDelegation.Borrow {
    const binding: c.DirectReadDelegation.Borrow.Binding = .{ .executor = 103, .target = target, .purpose = @splat(71) };
    const signed = try proof(service.engine, try binding.context(grant, t.allocator));
    try t.expectEqual(grant.proof.claim.credential_epoch, signed.claim.credential_epoch);
    return .{ .binding = binding, .signature = signed.signature };
}

fn delegatedHistory(service: *@import("LocalTableService.zig"), snapshot_grant: c.DirectReadDelegation, owner_role: u64, native_table: u64) !void {
    const w = c.DirectTableProtocol;
    const current = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "through_dispatch" } });
    defer current.deinit();
    const definition = current.value.result.lookup.?;
    var binding = snapshot_grant.binding;
    binding.owner.operation = 1200;
    binding.expected = definition.position;
    binding.retention = .history;
    const grant: c.DirectReadDelegation = .{ .binding = binding, .proof = try proof(service.engine, try binding.context(t.allocator)) };
    const acquisition: w.Acquisition = .{ .object = binding.interpretation.object, .owner = binding.owner, .expected = binding.expected };
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .pin = acquisition }, grant));
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .retain_history = acquisition }, snapshot_grant));
    const acquired = try dispatchDelegated(service, .{ .retain_history = acquisition }, grant);
    defer acquired.deinit();
    const snapshot: w.Snapshot = .{ .object = acquisition.object, .handle = acquired.value.result.pin };
    const original = try dispatchDelegated(service, .{ .history_start = snapshot }, grant);
    defer original.deinit();
    const point = original.value.result.history_source.point;
    try t.expectEqualDeep(binding.expected, point.position);
    const read_action: w.Action = .{ .history_scan = .{ .source = .{ .object = snapshot.object, .point = point }, .after = null, .limits = .{} } };
    const initial = try dispatchDelegated(service, read_action, grant);
    defer initial.deinit();
    try t.expectEqual(@as(usize, 1), initial.value.result.history_page.page.rows.len);
    // A freshly signed snapshot grant for the same owner still cannot read
    // history or reinterpret an existing history lease as an ordinary pin.
    var ordinary = binding;
    ordinary.retention = .snapshot;
    const wrong: c.DirectReadDelegation = .{ .binding = ordinary, .proof = try proof(service.engine, try ordinary.context(t.allocator)) };
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, read_action, wrong));
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .snapshot = snapshot }, wrong));
    try t.expectError(error.DataIdentityConflict, dispatchDelegated(service, .{ .pin = acquisition }, wrong));

    const bytes = try definition.schema.decode(t.allocator, c.fuze.TableSchema.max_bytes);
    defer t.allocator.free(bytes);
    var schema = try c.fuze.TableSchema.decode(t.allocator, bytes);
    defer schema.deinit();
    var scratch: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const absent = try w.Binary.encode(t.allocator, try c.fuze.Collation.encodePrimaryKeySortKey(schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 99 } } }}, false, &scratch));
    defer t.allocator.free(absent.base64);
    var mutation: w.Rows = .{ .binding = .{ .definition = g.current_definition, .identity = binding.owner, .target = snapshot.object, .action = .delete, .expected_definition = definition.interpretation.interpretation, .expected_data = null, .intent = @splat(1) }, .interpretation = definition.interpretation, .schema = definition.schema, .changes = &.{.{ .delete = absent }}, .ingestion = .point };
    mutation.binding.identity.operation = 1201;
    mutation.binding.intent = try mutation.digest(t.allocator);
    const admitted = try dispatch(service, .{ .admit_rows = mutation });
    admitted.deinit();
    const accepted = try dispatch(service, .{ .operation = .{ .binding = mutation.binding, .command = .execute, .steps = 1 } });
    defer accepted.deinit();
    const upper = accepted.value.result.rows.committed.outcome.position;
    var position = point.position;
    var entries: usize = 0;
    var empty: usize = 0;
    var successor: c.storage.TablePartition.HistoryPoint = undefined;
    while (position.next_lsn < upper.next_lsn) {
        const response = try dispatchDelegated(service, .{ .history = .{ .snapshot = snapshot, .from = position, .through = upper, .frames = 1 } }, grant);
        defer response.deinit();
        const page = response.value.result.history;
        try t.expectEqual(@as(u8, 1), page.scanned);
        if (page.entries.len == 0) empty += 1;
        for (page.entries) |entry| {
            entries += 1;
            try t.expectEqual(@as(u64, 1201), entry.receipt.binding.identity.operation);
            try t.expectEqual(@as(u64, 0), entry.receipt.outcome.affected);
            try t.expectEqual(original.value.result.history_source.source.changed_lsn, entry.changed_lsn);
            successor = entry.point;
        }
        position = page.next;
    }
    try t.expectEqual(@as(usize, 1), entries);
    try t.expect(empty >= 2); // Lease and durable row admission.
    const next = try dispatchDelegated(service, .{ .history_source = .{ .object = snapshot.object, .point = successor } }, grant);
    defer next.deinit();
    try t.expectEqual(@as(u64, 1), next.value.result.history_source.source.row_count);
    try t.expect(!std.mem.eql(u8, &point.commitment, &successor.commitment));
    const borrowed = try makeBorrow(service, grant, .{ .history = .{ .object = snapshot.object, .point = point } });
    const frozen = try dispatchBorrowed(service, read_action, grant, borrowed);
    defer frozen.deinit();
    try t.expectEqual(@as(usize, 1), frozen.value.result.history_page.page.rows.len);
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, .{ .history_source = .{ .object = snapshot.object, .point = successor } }, grant, borrowed));
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, .{ .history = .{ .snapshot = snapshot, .from = point.position, .through = upper, .frames = 1 } }, grant, borrowed));
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, .{ .release = snapshot }, grant, borrowed));
    const retry = try dispatchDelegated(service, .{ .retain_history = acquisition }, grant);
    defer retry.deinit();
    try t.expectEqualDeep(snapshot.handle, retry.value.result.pin);
    var corrupt = successor;
    corrupt.commitment[0] ^= 1;
    try t.expectError(error.TableHistoryConflict, dispatchDelegated(service, .{ .history_source = .{ .object = snapshot.object, .point = corrupt } }, grant));

    const Revoke = struct {
        fn run(context: *anyopaque, engine: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(context));
            _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var table = native_table;
    // Buffered rows and empty history pages both require current rights.
    for ([_]w.Action{ read_action, .{ .history = .{ .snapshot = snapshot, .from = upper, .through = upper, .frames = 1 } } }) |action| {
        service.before_reply = .{ .context = &table, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatchDelegated(service, action, grant));
        service.before_reply = null;
        _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = owner_role } });
    }
    service.before_reply = .{ .context = &table, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatchBorrowed(service, read_action, grant, borrowed));
    service.before_reply = null;
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = owner_role } });
    const released = try dispatchDelegated(service, .{ .release = snapshot }, grant);
    released.deinit();
    try t.expectError(error.TableSnapshotReleased, dispatchBorrowed(service, read_action, grant, borrowed));
    try t.expectError(error.TableSnapshotReleased, dispatchDelegated(service, read_action, grant));
    try t.expectError(error.TableSnapshotReleased, dispatchDelegated(service, .{ .retain_history = acquisition }, grant));
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
    const database_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
    const request_digest: [32]u8 = @splat(5);
    var signed = try proof(&engine, request_digest);
    try t.expectError(error.InvalidAuthorizationCredential, Policy.init(&engine, config, signed, @splat(6), null));
    var forged = signed;
    forged.signature[0] ^= 1;
    try t.expectError(error.Forbidden, Policy.init(&engine, config, forged, request_digest, null));
    var policy = try Policy.init(&engine, config, signed, request_digest, null);
    var control: backend.DataStore = .{ .backend = &owner, .control = true };
    var data: backend.DataStore = .{ .backend = &owner };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    defer catalog.deinit();
    try catalog.recover();
    try catalog.initialize(policy.policy());
    try directDispatch(&engine, config, role);
    // The dispatch proof deliberately rotates the caller. Later independent
    // requests prepare a new proof; accepted delegated work keeps its old one.
    signed = try proof(&engine, request_digest);
    policy = try Policy.init(&engine, config, signed, request_digest, null);
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
    // Native domain authorization checks its lifetime before disclosing catalog
    // state. Retirement therefore denies the object guard; the direct owner
    // cannot reach its later, more specific resource-lifetime check.
    try t.expectError(error.Forbidden, runner.run(&catalog, interrupted.binding, policy.policy(), 16));
    try t.expectError(error.StateResourceExpired, engine.requireResourceLifetime(resource));
    var authority = try engine.authorization();
    try t.expect(try authority.bound(table_domain, try c.TableAuthority.binding(scope, .table, 9)) == null);
    try t.expectError(error.Forbidden, catalog.status(request.binding, policy.policy()));
    try t.expectError(error.Forbidden, catalog.rowStatus(succeeding.binding, policy.policy()));
}
