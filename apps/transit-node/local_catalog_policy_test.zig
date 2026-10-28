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

fn collectDirect(engine: *Engine, catalog: *D) !void {
    const Collection = backend.DataCollection.Collector(c.DirectStorageGraph);
    const Clock = struct {
        now: u64,
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now };
        }
    };
    var clock: Clock = .{ .now = engine.head.time_floor_ms + 100 };
    const previous_clock = engine.clock;
    defer engine.clock = previous_clock;
    engine.clock = .{ .context = &clock, .read = Clock.read };
    const owner = engine.journal.backend;
    // An unreferenced managed object and an independently retained namespace
    // distinguish real collection from a pass that merely preserves everything.
    const orphan = "table-segments/unpublished.tseg";
    try owner.put(orphan, "private orphan", false);
    try owner.put("direct-intents/saved.data", "independently retained saved bytes", false);
    const fence = try command(engine, .{ .storage_fence = {} });
    var collection: Collection = .{ .backend = owner };
    try collection.start(engine, fence);
    var steps: usize = 0;
    while ((try collection.current()).?.phase != .wait) : (steps += 1) {
        if (steps == 100_000) return error.FixtureBudget;
        try t.expect(try collection.step(engine, .{ .unix_ms = clock.now }));
    }
    clock.now = (try collection.current()).?.grace_until_ms + 1;
    _ = try command(engine, .{ .storage_fence = {} });
    while ((try collection.current()).?.phase != .complete) : (steps += 1) {
        if (steps == 200_000) return error.FixtureBudget;
        try t.expect(try collection.step(engine, .{ .unix_ms = clock.now }));
    }
    const completed = (try collection.current()).?;
    try t.expect(!completed.aborted and completed.reclaimed_objects != 0);
    try t.expect(try owner.objects.objectStore().head(orphan) == null);
    var bytes: [64]u8 = undefined;
    try t.expectEqualStrings("independently retained saved bytes", try owner.read("direct-intents/saved.data", &bytes));
    // Catalog recovery must traverse its old control roots after physical
    // reclamation; a latest-root-only collector fails this check.
    try catalog.recover();
    std.debug.print("Direct graph collection: {d} steps, {d} confirmed allocations reclaimed.\n", .{ steps, completed.reclaimed_objects });
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
    return proofWithSeed(engine, context, 29);
}
fn proofWithSeed(engine: *Engine, context: [32]u8, seed: u8) !a.Proof {
    return a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 101, .credential_epoch = (try engine.principal(101)).credential_epoch, .role = null, .audience = 100, .context = context }, try key(seed));
}

fn dispatch(service: anytype, action: c.DirectTableProtocol.Action) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return dispatchDelegated(service, action, null);
}
fn dispatchDelegated(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return dispatchBorrowed(service, action, delegation, null);
}
fn dispatchBorrowed(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return dispatchWithSeed(service, action, delegation, borrow, 29);
}
fn dispatchWithSeed(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow, seed: u8) !std.json.Parsed(c.DirectTableProtocol.Response) {
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const input: w.Request.Input = .{ .definition = g.current_definition, .connection = .{ .scope = service.configuration.scope, .branch = service.configuration.branch, .audience = service.configuration.audience, .principal = 101, .role = null }, .delegation = delegation, .borrow = borrow, .nonce = @splat(7), .action = action };
    const context = try w.Request.context(input, alloc);
    const executor = if (borrow) |value| value.binding.executor else if (delegation) |value| value.binding.executor else 101;
    const signed = if (delegation != null) try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = executor, .credential_epoch = (try service.engine.principal(executor)).credential_epoch, .role = null, .audience = service.configuration.audience, .context = context }, try key(if (borrow != null) 33 else 31)) else try proofWithSeed(service.engine, context, seed);
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .borrow = input.borrow, .proof = signed };
    const bytes = try p.Json.valueAlloc(alloc, request);
    const parsed = try w.Request.parse(alloc, bytes);
    const response = try p.Json.parseFromSliceOwned(w.Response, t.allocator, try service.execute(&arena, parsed.value));
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
    if (response.value.result == .key_range) {
        var altered = response.value;
        altered.result.key_range.encoded_bytes += 1;
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, parsed.value, altered));
        altered = response.value;
        altered.result.key_range.snapshot.handle.owner.operation += 1;
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

fn hostLookup(service: *@import("LocalTableService.zig"), name: []const u8, native_table: u64, owner_role: u64) !void {
    const Host = @import("LocalTableHost.zig");
    const Adapter = struct {
        host: *Host,
        engine: *Engine,
        configuration: D.Configuration,
        fn execute(self: *@This(), arena: *std.heap.ArenaAllocator, request: c.DirectTableProtocol.Request) ![]const u8 {
            return self.host.execute(self.engine.journal.backend.io, self.engine, arena, request);
        }
    };
    var options = service.options;
    options.table_recovery = null;
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = options, .recovery = service.recovery_state.?.* };
    var adapter: Adapter = .{ .host = &host, .engine = service.engine, .configuration = service.configuration };
    const action: c.DirectTableProtocol.Action = .{ .lookup = .{ .namespace = 1, .name = name } };
    const disk = service.engine.journal.backend.wal.disk.?;
    const before = disk.read_frames;
    const cold = try dispatch(&adapter, action);
    defer cold.deinit();
    const cold_frames = disk.read_frames - before;
    const warmed = disk.read_frames;
    const warm = try dispatch(&adapter, action);
    defer warm.deinit();
    const warm_frames = disk.read_frames - warmed;
    try t.expectEqualDeep(cold.value, warm.value);
    try t.expect(warm_frames < cold_frames);
    // The name selects only a volatile slot. Its retained root cannot preserve
    // disclosure rights after the actual native object's owner is replaced.
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&adapter, action));
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    const restored = try dispatch(&adapter, action);
    defer restored.deinit();
    try t.expectEqualDeep(cold.value.result, restored.value.result);
    std.debug.print("Name lookup WAL frames: cold {d}, warm {d}; revocation rechecked.\n", .{ cold_frames, warm_frames });
}

fn directDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !c.DirectClientToken.Receipt {
    const w = c.DirectTableProtocol;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    var recovered = blk: {
        var control: backend.DataStore = .{ .backend = engine.journal.backend, .control = true };
        var data: backend.DataStore = .{ .backend = engine.journal.backend };
        var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), service.options);
        defer catalog.deinit();
        try catalog.recover();
        break :blk try catalog.recoveryState();
    };
    // The signed dispatcher schedule below includes current revocation after
    // response buffering; a retained catalog prefix must not cache permission.
    service.recovery_state = &recovered;
    var table_recovered: ?c.storage.TablePartition.RecoveryState = null;
    service.options.table_recovery = &table_recovered;
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
    const empty_storage = try dispatch(&service, .{ .storage = .{ .object = binding.target, .pending_limit = 1 } });
    defer empty_storage.deinit();
    try t.expectEqualDeep(selected.position, empty_storage.value.result.storage.position);
    try t.expect(empty_storage.value.result.storage.pending.complete and empty_storage.value.result.storage.pending.rows == 0);
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
    const bulk_storage = try dispatch(&service, .{ .storage = .{ .object = binding.target, .pending_limit = 1 } });
    defer bulk_storage.deinit();
    try t.expectEqual(@as(u64, 0), bulk_storage.value.result.storage.pending.rows);
    const bulk_target: D.FlushTarget = .{ .object = binding.target, .through = bulk_storage.value.result.storage.position };
    const bulk_flush = try dispatch(&service, .{ .flush = bulk_target });
    defer bulk_flush.deinit();
    try t.expect(bulk_flush.value.result.flush.complete);
    try t.expectEqualDeep(bulk_storage.value.result.storage, bulk_flush.value.result.flush.observed);
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
    const intervals = [_]w.KeyInterval{
        .{ .lower = .{ .key = present_key, .inclusive = true }, .upper = .{ .key = present_key, .inclusive = true } },
        .{ .lower = .{ .key = absent_key, .inclusive = true }, .upper = null },
    };
    for (intervals, 0..) |interval, i| {
        const ranged = try dispatch(&service, .{ .key_range = .{ .snapshot = snapshot, .interval = interval, .after = null, .limits = .{} } });
        defer ranged.deinit();
        try t.expectEqual(@as(usize, if (i == 0) 1 else 0), ranged.value.result.key_range.rows.len);
        try t.expect(ranged.value.result.key_range.next == null);
        if (i == 0) try t.expectEqualStrings(scanned.value.result.page.rows[0].base64, ranged.value.result.key_range.rows[0].base64);
    }
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
    try hostLookup(&service, ddl.name, native_table, owner_role);
    try delegatedDispatch(&service, snapshot, historical.value.result.snapshot, owner_role, native_table);
    const Revoke = struct {
        fn run(context: *anyopaque, current: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(context));
            _ = try change(current, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var revoke_id = native_table;
    const warmed = try dispatch(&service, .{ .snapshot = snapshot });
    warmed.deinit();
    try t.expect(table_recovered != null);
    service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }));
    try t.expect(table_recovered == null);
    service.before_reply = null;
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    for ([_]w.Binary{ present_key, absent_key }) |lookup_key| {
        service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatch(&service, .{ .read_key = .{ .snapshot = snapshot, .key = lookup_key } }));
        service.before_reply = null;
        _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    }
    for (intervals) |interval| {
        service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatch(&service, .{ .key_range = .{ .snapshot = snapshot, .interval = interval, .after = null, .limits = .{} } }));
        service.before_reply = null;
        _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    }
    const selections = [_]@FieldType(w.CurrentRead, "selection"){
        .{ .key = present_key },
        .{ .key = absent_key },
        .{ .rows = .{ .after = null, .limits = .{} } },
        .{ .rows = .{ .after = row.identity, .limits = .{} } },
    };
    for (selections) |selection| {
        const action: w.Action = .{ .read_current = .{ .namespace = 1, .interpretation = selected.interpretation.interpretation, .expected = historical.value.result.snapshot.accepted, .selection = selection } };
        // Pins and the accepted no-op above preserve this earlier logical basis.
        (try dispatch(&service, action)).deinit();
        service.before_reply = .{ .context = &revoke_id, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatch(&service, action));
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
    const native_before_stage = engine.head.position;
    const staged_bytes_before = engine.journal.observe.metrics.request_payload_bytes;
    const staged = try dispatch(&service, .{ .stage = .{ .namespace = 1, .intent = saved.parsed.value } });
    defer staged.deinit();
    // Staging appends no native transition. Its exact immutable intent bytes
    // must nevertheless appear in the Table request's provider diagnostics.
    try t.expectEqual(native_before_stage, engine.head.position);
    try t.expectEqual(staged.value.result.staged.content.bytes, engine.journal.observe.metrics.request_payload_bytes - staged_bytes_before);
    try (try saved.reference(1)).requireSame(staged.value.result.staged);
    const token_binding: c.DirectClientToken.Binding = .{
        .key = .{ .definition = g.current_definition, .connection = saved.parsed.value.connection, .account = @splat(4), .token = @splat(5) },
        .fingerprint = @splat(6),
        .intent = .{ .table = staged.value.result.staged },
    };
    const bound = try dispatch(&service, .{ .client_token = .{ .bind = token_binding } });
    defer bound.deinit();
    try t.expectEqual(native_before_stage, engine.head.position);
    try t.expectEqualDeep(token_binding, bound.value.result.client_token.?.binding);
    var duplicate = token_binding;
    duplicate.intent.table.binding.identity.operation += 1000;
    const original_token = try dispatch(&service, .{ .client_token = .{ .bind = duplicate } });
    defer original_token.deinit();
    try t.expectEqualDeep(bound.value.result.client_token, original_token.value.result.client_token);
    duplicate.fingerprint[0] ^= 1;
    try t.expectError(error.ClientTokenConflict, dispatch(&service, .{ .client_token = .{ .bind = duplicate } }));
    // A receipt accepted before policy revocation cannot be disclosed. Recovery
    // after restoring rights returns that same reference, without native turns.
    var lost = token_binding;
    lost.key.token = @splat(7);
    var schema_authority = config.authority.initial_schema_authority;
    service.before_reply = .{ .context = &schema_authority, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .client_token = .{ .bind = lost } }));
    service.before_reply = null;
    try t.expectError(error.Forbidden, dispatch(&service, .{ .client_token = .{ .lookup = lost.key } }));
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(schema_authority), .owner = owner_role } });
    const recovered_token = try dispatch(&service, .{ .client_token = .{ .lookup = lost.key } });
    defer recovered_token.deinit();
    try t.expectEqualDeep(lost, recovered_token.value.result.client_token.?.binding);
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
    return recovered_token.value.result.client_token.?;
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
    const basis: c.DirectTableReader.Basis = .{ .snapshot = source.snapshot, .interpretation = source.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .row_count = source.row_count, .authority = source.authority };
    var fields: [c.fuze.TableSchema.max_columns]c.fuze.Types.Field = undefined;
    const plan: c.fuze.LogicalQuery.Plan = .{ .schema = try schema.schema.rowType(&fields), .source_basis = try basis.fingerprint(), .projection = &.{0}, .collations = .fromTable(schema.schema) };
    var plan_buffer: [c.fuze.LogicalPlanCodec.max_bytes]u8 = undefined;
    const plan_wire = try w.Binary.encode(t.allocator, try c.fuze.LogicalPlanCodec.encode(plan, &plan_buffer));
    defer t.allocator.free(plan_wire.base64);
    const filter_action: w.Action = .{ .filter_scan = .{ .snapshot = snapshot, .plan = plan_wire, .fingerprint = try plan.fingerprint(), .after = null, .limits = .{} } };
    const filtered = try dispatchDelegated(service, filter_action, grant);
    defer filtered.deinit();
    try t.expectEqual(@as(usize, 1), filtered.value.result.filtered_page.page.rows.len);
    try t.expectEqualDeep(grant.proof.claim.context, filtered.value.subject.context);
    var key_bytes: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const point_key = try w.Binary.encode(t.allocator, try c.fuze.Collation.encodePrimaryKeySortKey(schema.schema, &.{.{ .value = .{ .atom = .{ .signed = 12 } } }}, false, &key_bytes));
    defer t.allocator.free(point_key.base64);
    const point = try dispatchDelegated(service, .{ .read_key = .{ .snapshot = snapshot, .key = point_key } }, grant);
    defer point.deinit();
    try t.expectEqualStrings(read.value.result.page.rows[0].base64, point.value.result.point.row.?.base64);
    try t.expectEqualDeep(grant.proof.claim.context, point.value.subject.context);
    const range_action: w.Action = .{ .key_range = .{ .snapshot = snapshot, .interval = .{ .lower = .{ .key = point_key, .inclusive = true }, .upper = null }, .after = null, .limits = .{} } };
    const ranged = try dispatchDelegated(service, range_action, grant);
    defer ranged.deinit();
    try t.expectEqualStrings(read.value.result.page.rows[0].base64, ranged.value.result.key_range.rows[0].base64);
    try t.expectEqualDeep(grant.proof.claim.context, ranged.value.subject.context);
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .describe, grant));
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .read_current = .{ .namespace = 1, .interpretation = source.interpretation.interpretation, .expected = source.accepted, .selection = .{ .key = point_key } } }, grant));

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
    const borrowed_range = try dispatchBorrowed(service, range_action, grant, borrowed);
    defer borrowed_range.deinit();
    try t.expectEqualStrings(read.value.result.page.rows[0].base64, borrowed_range.value.result.key_range.rows[0].base64);
    const borrowed_filter = try dispatchBorrowed(service, filter_action, grant, borrowed);
    defer borrowed_filter.deinit();
    try t.expectEqualDeep(filtered.value.result.filtered_page.offsets, borrowed_filter.value.result.filtered_page.offsets);
    try t.expectEqualStrings(filtered.value.result.filtered_page.page.rows[0].base64, borrowed_filter.value.result.filtered_page.page.rows[0].base64);
    var other_filter = filter_action;
    other_filter.filter_scan.snapshot.handle.content.sha256[0] ^= 1;
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, other_filter, grant, borrowed));
    var other_range = range_action;
    other_range.key_range.snapshot.handle.content.sha256[0] ^= 1;
    try t.expectError(error.TableDelegationDenied, dispatchBorrowed(service, other_range, grant, borrowed));
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
    try t.expectError(error.Forbidden, dispatchDelegated(service, filter_action, grant));
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
    // A wrong original grant must reject before reading a selected successor,
    // even when that successor would independently fail integrity validation.
    var foreign_basis = binding;
    foreign_basis.interpretation.revision += 1;
    const foreign_grant: c.DirectReadDelegation = .{ .binding = foreign_basis, .proof = try proof(service.engine, try foreign_basis.context(t.allocator)) };
    try t.expectError(error.TableDelegationDenied, dispatchDelegated(service, .{ .history_source = .{ .object = snapshot.object, .point = corrupt } }, foreign_grant));

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

fn prerequisiteDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const pid = try command(engine, .{ .spawn = .{} });
    const role = (try change(engine, .{ .create_role = .{ .name = try .init("original-input-caller"), .login = true } })).?;
    _ = try change(engine, .{ .bind_credential = .{ .principal = 201, .role = role, .public_key = (try key(41)).public_key.toBytes() } });
    const grant: @FieldType(a.Action, "grant") = .{ .object = .{ .kind = .process, .id = pid }, .grantee = role, .privileges = p.permission(.send) };
    _ = try change(engine, .{ .grant = grant });
    const input = try engine.submit(try g.sign(.{ .realm = 42, .principal = 201, .sequence = (try engine.principal(201)).sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try .init("original work") } } }, try key(41)));
    var condition: a.Guard = .{ .subject = .{ .accepted = .{ .pid = pid, .input = input, .principal = 201 } }, .requirements = @splat(null) };
    condition.requirements[0] = .{ .object = grant.object, .privileges = grant.privileges };
    const revoke: a.Action = .{ .revoke_privileges = .{ .object = grant.object, .grantee = role, .privileges = grant.privileges, .grant_option_only = false, .behavior = .cascade } };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    var row_schema: c.fuze.TableSchema.Schema = undefined;
    var selected: w.Definition = undefined;
    var current_binding: p.DataLifecycle.Binding = undefined;
    var buffer: [65536]u8 = undefined;
    for ([_]u64{ 20, 21 }) |object| {
        const schema: c.fuze.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
        const name = try std.fmt.allocPrint(alloc, "conditioned_{d}", .{object});
        const intent: D.Intent = .{ .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
        const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 400 + object }, .target = .{ .scope = config.scope, .branch = config.branch, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc), .prerequisite = condition };
        const ddl: w.Ddl = .{ .binding = binding, .namespace = 1, .name = name, .action = .{ .create = .{ .owner = owner_role, .schema = try w.Binary.encode(alloc, try schema.encode(&buffer)) } } };
        (try dispatch(&service, .{ .admit_ddl = ddl })).deinit();
        _ = try change(engine, revoke);
        try t.expectError(error.Forbidden, dispatch(&service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } }));
        const pending = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } });
        defer pending.deinit();
        try t.expect(pending.value.result.ddl == .admitted);
        if (object == 20) {
            const closed = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .cancel, .steps = 1 } });
            defer closed.deinit();
            try t.expect(closed.value.result.ddl == .cancelled);
        }
        _ = try change(engine, .{ .grant = grant });
        if (object == 20) continue;
        const applied = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
        defer applied.deinit();
        try t.expect(applied.value.result.ddl == .committed);
        const lookup = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = name } });
        defer lookup.deinit();
        selected = lookup.value.result.lookup.?;
        current_binding = binding;
        row_schema = schema;
    }
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 450, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 45 } } }} };
    var work: w.Rows = .{ .binding = current_binding, .interpretation = selected.interpretation, .schema = try w.Binary.encode(alloc, try row_schema.encode(&buffer)), .changes = &.{.{ .insert = try w.Binary.encode(alloc, try row.encode(row_schema, &buffer)) }}, .ingestion = .point };
    work.binding.identity.operation = 450;
    work.binding.action = .insert;
    work.binding.expected_definition = selected.interpretation.interpretation;
    work.binding.intent = try work.digest(alloc);
    // The original caller's condition does not supply the worker's Table rights.
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(selected.authorization), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&service, .{ .preview_rows = work }));
    try t.expectError(error.Forbidden, dispatch(&service, .{ .admit_rows = work }));
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(selected.authorization), .owner = owner_role } });
    const preview = try dispatch(&service, .{ .preview_rows = work });
    defer preview.deinit();
    try t.expectEqual(.none, preview.value.result.row_preview.reason);
    (try dispatch(&service, .{ .admit_rows = work })).deinit();
    _ = try change(engine, revoke);
    try t.expectError(error.Forbidden, dispatch(&service, .{ .preview_rows = work }));
    try t.expectError(error.Forbidden, dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } }));
    _ = try change(engine, .{ .grant = grant });
    // A replacement worker authenticates afresh but retains the original input.
    _ = try change(engine, .{ .rotate_credential = .{ .principal = 101, .expected_epoch = (try engine.principal(101)).credential_epoch, .public_key = (try key(47)).public_key.toBytes() } });
    const committed = try dispatchWithSeed(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } }, null, null, 47);
    defer committed.deinit();
    try t.expectEqual(@as(u64, 1), committed.value.result.rows.committed.outcome.affected);
    try work.binding.requireSame(committed.value.result.rows.committed.binding);
    _ = try change(engine, .{ .rotate_credential = .{ .principal = 101, .expected_epoch = (try engine.principal(101)).credential_epoch, .public_key = (try key(29)).public_key.toBytes() } });

    work.binding.identity.operation = 451;
    const next_row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 102, .operation = 451, .ordinal = 0 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 46 } } }} };
    work.changes = &.{.{ .insert = try w.Binary.encode(alloc, try next_row.encode(row_schema, &buffer)) }};
    work.binding.intent = try work.digest(alloc);
    var saved = try c.DirectTableIntent.create(alloc, .{ .scope = config.scope, .branch = config.branch, .audience = config.audience, .principal = 101, .role = null }, .{ .rows = work });
    defer saved.deinit();
    const staged = try dispatch(&service, .{ .stage = .{ .namespace = 1, .intent = saved.parsed.value } });
    defer staged.deinit();
    try (try saved.reference(1)).requireSame(staged.value.result.staged);
    (try dispatch(&service, .{ .admit_saved = staged.value.result.staged })).deinit();
    // Reopen native history; each service dispatch separately recovers the
    // retained catalog and Table logs. Neither condition depends on live memory.
    engine.* = try Engine.open(engine.journal, engine.page_store, engine.genesis);
    var stripped = work.binding;
    stripped.prerequisite = null;
    try t.expectError(error.DataIdentityConflict, dispatch(&service, .{ .operation = .{ .binding = stripped, .command = .inspect, .steps = 1 } }));
    _ = try change(engine, .{ .rotate_credential = .{ .principal = 201, .expected_epoch = (try engine.principal(201)).credential_epoch, .public_key = (try key(43)).public_key.toBytes() } });
    try t.expectError(error.StaleAuthorizationCredential, dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } }));
    const pending = try dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .inspect, .steps = 1 } });
    defer pending.deinit();
    try t.expect(pending.value.result.rows == .admitted);
    const closed = try dispatch(&service, .{ .operation = .{ .binding = work.binding, .command = .cancel, .steps = 1 } });
    defer closed.deinit();
    try t.expect(closed.value.result.rows == .cancelled);
    const earlier = try dispatch(&service, .{ .operation = .{ .binding = committed.value.result.rows.committed.binding, .command = .inspect, .steps = 1 } });
    defer earlier.deinit();
    try t.expectEqualDeep(committed.value.result, earlier.value.result);
    const final = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = "conditioned_21" } });
    defer final.deinit();
    try t.expectEqual(@as(u64, 1), final.value.result.lookup.?.row_count);
}

fn namespaceDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !void {
    const N = c.DirectNamespace;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    const binding: N.Binding = .{ .definition = g.current_definition, .connection = .{ .scope = config.scope, .branch = 1, .audience = config.audience, .principal = 101, .role = null }, .operation = 800, .namespace = 30, .expected = null, .action = .{ .create = .{ .name = try .init("application_namespace"), .owner = owner_role } } };
    const before = engine.head.position;
    const preview = try dispatch(&service, .{ .namespace_preview = binding });
    defer preview.deinit();
    try t.expectEqual(.none, preview.value.result.namespace_preview.reason);
    try t.expectEqual(before, engine.head.position);
    (try dispatch(&service, .{ .namespace_operation = .{ .binding = binding, .command = .admit, .steps = 1 } })).deinit();
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(config.authority.database), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&service, .{ .namespace_operation = .{ .binding = binding, .command = .execute, .steps = 32 } }));
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(config.authority.database), .owner = owner_role } });
    const hidden = try dispatch(&service, .{ .namespace = 30 });
    defer hidden.deinit();
    try t.expect(hidden.value.result.namespace == null);
    const Revoke = struct {
        fn run(raw: *anyopaque, current_engine: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(raw));
            _ = try change(current_engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var database = config.authority.database;
    service.before_reply = .{ .context = &database, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .namespace_operation = .{ .binding = binding, .command = .execute, .steps = 32 } }));
    service.before_reply = null;
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(database), .owner = owner_role } });
    // A withheld accepted response is recovered after reopening native authority
    // and every data/catalog owner. A new key authenticates the original binding.
    engine.* = try Engine.open(engine.journal, engine.page_store, engine.genesis);
    _ = try change(engine, .{ .rotate_credential = .{ .principal = 101, .expected_epoch = (try engine.principal(101)).credential_epoch, .public_key = (try key(49)).public_key.toBytes() } });
    const recovered = try dispatchWithSeed(&service, .{ .namespace_operation = .{ .binding = binding, .command = .inspect, .steps = 1 } }, null, null, 49);
    defer recovered.deinit();
    const created = recovered.value.result.namespace_operation.operation;
    try t.expectEqual(.applied, created.phase);
    _ = try change(engine, .{ .rotate_credential = .{ .principal = 101, .expected_epoch = (try engine.principal(101)).credential_epoch, .public_key = (try key(29)).public_key.toBytes() } });
    var rename = binding;
    rename.operation = 801;
    rename.expected = created.resulting;
    rename.action = .{ .rename = try .init("renamed_application") };
    (try dispatch(&service, .{ .namespace_operation = .{ .binding = rename, .command = .admit, .steps = 1 } })).deinit();
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(created.resulting.?.authorization), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&service, .{ .namespace_operation = .{ .binding = rename, .command = .execute, .steps = 1 } }));
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(created.resulting.?.authorization), .owner = owner_role } });
    const renamed = try dispatch(&service, .{ .namespace_operation = .{ .binding = rename, .command = .execute, .steps = 1 } });
    defer renamed.deinit();
    try t.expectEqual(.applied, renamed.value.result.namespace_operation.operation.phase);
    var drop = rename;
    drop.operation = 802;
    drop.expected = renamed.value.result.namespace_operation.operation.resulting;
    drop.action = .drop;
    (try dispatch(&service, .{ .namespace_operation = .{ .binding = drop, .command = .admit, .steps = 1 } })).deinit();
    var completed = false;
    for (0..32) |_| {
        const response = try dispatch(&service, .{ .namespace_operation = .{ .binding = drop, .command = .execute, .steps = 1 } });
        defer response.deinit();
        const observed = response.value.result.namespace_operation.operation;
        if (observed.phase == .applied) {
            try t.expect(observed.resulting.?.retired);
            completed = true;
            break;
        }
        try t.expectEqual(.admitted, observed.phase);
    }
    try t.expect(completed);
    const original = try dispatch(&service, .{ .namespace_operation = .{ .binding = binding, .command = .inspect, .steps = 1 } });
    defer original.deinit();
    try t.expectEqualDeep(created, original.value.result.namespace_operation.operation);
}

fn dependencyDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 40, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .namespace = 1, .name = try .init("dependency_source"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 10000 }, .target = .{ .scope = config.scope, .branch = 1, .object = 40 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc) };
    var bytes: [65536]u8 = undefined;
    const admitted = try dispatch(&service, .{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = intent.name.slice(), .action = .{ .create = .{ .owner = owner_role, .schema = try w.Binary.encode(alloc, try schema.encode(&bytes)) } } } });
    defer admitted.deinit();
    const created = try dispatch(&service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer created.deinit();
    const interpretation = created.value.result.ddl.committed.resulting.interpretation;
    const metadata = try dispatch(&service, .{ .lookup = .{ .namespace = 1, .name = intent.name.slice() } });
    defer metadata.deinit();
    _ = try change(engine, .{ .grant = .{ .object = c.TableAuthority.reference(metadata.value.result.lookup.?.authorization), .grantee = owner_role, .privileges = c.TableAuthority.select } });
    const pid = try command(engine, .{ .spawn = .{} });
    const resource = try command(engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    const dependency: c.DirectDependency.Binding = .{
        .definition = g.current_definition,
        .connection = .{ .scope = config.scope, .branch = 1, .audience = config.audience, .principal = 101, .role = null },
        .operation = 10001,
        .edge = .{ .source = interpretation, .dependent = .{ .kind = .captured, .interpretation = .{
            .object = .{ .scope = .{ .realm = 42, .resource = resource, .catalog = 9 }, .branch = 1, .object = 99 },
            .revision = 1,
            .digest = @splat(7),
        } }, .privileges = c.TableAuthority.select },
        .action = .register,
        .authority = .dependent,
    };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependency_operation = .{ .binding = dependency, .command = .accept } }));
    // Metadata inspect/write grants suffice; no read of dependent data is implied.
    _ = try command(engine, .{ .grant_resource = .{ .resource = resource, .subject = 101, .permissions = 5 } });
    const Race = struct {
        resource: u64,
        fn revoke(raw: *anyopaque, authority: *Engine) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            _ = try command(authority, .{ .grant_resource = .{ .resource = self.resource, .subject = 101, .permissions = 0 } });
        }
    };
    var race: Race = .{ .resource = resource };
    service.before_reply = .{ .context = &race, .run = Race.revoke };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependency_operation = .{ .binding = dependency, .command = .accept } }));
    service.before_reply = null;
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependency_operation = .{ .binding = dependency, .command = .inspect } }));
    const hidden = try dispatch(&service, .{ .dependencies = .{ .selection = .{ .dependents = interpretation.object }, .cursor = null, .authority = .dependent } });
    defer hidden.deinit();
    try t.expect(hidden.value.result.dependencies.entries[0] == null);
    var drop = binding;
    const drop_intent: D.Intent = .{ .namespace = 1, .name = intent.name, .action = .drop };
    drop.identity.operation = 10002;
    drop.action = .drop;
    drop.expected_definition = interpretation;
    drop.intent = try drop_intent.digest(alloc);
    const restricted = try dispatch(&service, .{ .preview = .{ .binding = drop, .namespace = 1, .name = intent.name.slice(), .action = .drop } });
    defer restricted.deinit();
    try t.expectEqual(.dependency, restricted.value.result.preview.reason);
    _ = try command(engine, .{ .grant_resource = .{ .resource = resource, .subject = 101, .permissions = 1 } });
    const recovered = try dispatch(&service, .{ .dependency_operation = .{ .binding = dependency, .command = .inspect } });
    defer recovered.deinit();
    try t.expect(recovered.value.result.dependency_operation.outcome.changed);
    var removal = dependency;
    removal.operation = 10003;
    removal.action = .remove;
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependency_operation = .{ .binding = removal, .command = .accept } }));
    const visible = try dispatch(&service, .{ .dependencies = .{ .selection = .{ .dependencies = dependency.edge.dependent.interpretation.object }, .cursor = null, .authority = .dependent } });
    defer visible.deinit();
    try t.expectEqualDeep(dependency.edge, visible.value.result.dependencies.entries[0].?);
    _ = try command(engine, .{ .grant_resource = .{ .resource = resource, .subject = 101, .permissions = 5 } });
    const removed = try dispatch(&service, .{ .dependency_operation = .{ .binding = removal, .command = .accept } });
    defer removed.deinit();
    try t.expect(removed.value.result.dependency_operation.outcome.changed);
    var orphan = dependency;
    orphan.operation = 10004;
    const registered = try dispatch(&service, .{ .dependency_operation = .{ .binding = orphan, .command = .accept } });
    defer registered.deinit();
    _ = try command(engine, .{ .retire_resource = resource });
    // Native metadata rights can survive logical resource retirement. They do
    // not make that resource usable for another accepted computation.
    const retired_receipt = try dispatch(&service, .{ .dependency_operation = .{ .binding = orphan, .command = .inspect } });
    defer retired_receipt.deinit();
    try t.expect(retired_receipt.value.result.dependency_operation.outcome.changed);
    _ = try command(engine, .{ .grant_resource = .{ .resource = resource, .subject = 101, .permissions = 0 } });
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependency_operation = .{ .binding = orphan, .command = .inspect } }));
    // Retirement does not silently remove the edge. Explicit administration can
    // inspect its retained catalog metadata without reading the expired resource.
    try t.expectError(error.Forbidden, dispatch(&service, .{ .dependencies = .{ .selection = .{ .dependents = interpretation.object }, .cursor = null, .authority = .catalog_administrator } }));
    _ = try change(engine, .{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = owner_role, .privileges = p.permission(.admin) } });
    const orphaned = try dispatch(&service, .{ .dependencies = .{ .selection = .{ .dependents = interpretation.object }, .cursor = null, .authority = .catalog_administrator } });
    defer orphaned.deinit();
    try t.expectEqualDeep(orphan.edge, orphaned.value.result.dependencies.entries[0].?);
    var cleanup = orphan;
    cleanup.operation = 10005;
    cleanup.action = .remove;
    cleanup.authority = .catalog_administrator;
    const cleaned = try dispatch(&service, .{ .dependency_operation = .{ .binding = cleanup, .command = .accept } });
    defer cleaned.deinit();
    try t.expect(cleaned.value.result.dependency_operation.outcome.changed);
    _ = try change(engine, .{ .revoke_privileges = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = owner_role, .privileges = p.permission(.admin) } });
}

const PhysicalPause = struct {
    var real: *const std.Io.VTable = undefined;
    var armed: std.atomic.Value(bool) = .init(false);
    var entered: std.Io.Event = .unset;
    var release: std.Io.Event = .unset;
    fn sync(context: ?*anyopaque, file: std.Io.File) std.Io.File.SyncError!void {
        if (armed.swap(false, .acq_rel)) {
            entered.set(t.io);
            try release.wait(t.io);
        }
        return real.fileSync(context, file);
    }
    fn wait(event: *std.Io.Event) !void {
        const Result = union(enum) { ready: anyerror!void, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(t.io, &results);
        defer select.cancelDiscard();
        try select.concurrent(.timeout, std.Io.sleep, .{ t.io, .fromSeconds(10), .awake });
        try select.concurrent(.ready, std.Io.Event.wait, .{ event, t.io });
        switch (try select.await()) {
            .ready => |result| try result,
            .timeout => |result| {
                try result;
                return error.ProgressTimeout;
            },
        }
    }
    fn fence(owner: *backend.Backend, genesis: @FieldType(Engine, "genesis"), done: *std.Io.Event) !void {
        defer done.set(t.io);
        // Store.append owns the exclusive native publication fence. Acquiring
        // it here would recursively lock the same non-reentrant boundary.
        var pages = try backend.PageStore.init(owner, 1);
        defer pages.deinit();
        var journal: backend.Store = .{ .backend = owner };
        var control = try Engine.open(&journal, &pages, genesis);
        const Clock = struct {
            now: u64,
            fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
                return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now };
            }
        };
        var clock: Clock = .{ .now = control.head.time_floor_ms + 100 };
        control.clock = .{ .context = &clock, .read = Clock.read };
        // This publication must finish while the Table's private sync remains
        // paused. The later flush must reject its old captured storage epoch.
        _ = try command(&control, .{ .storage_fence = {} });
    }
};

fn physicalFlush(engine: *Engine, catalog: *D, policy: *Policy, name: c.TableAuthority.Name, expected: c.storage.TablePartition.Evidence, retained: c.storage.TablePartition.SnapshotHandle) !void {
    const Work = @import("LocalTableMaintenance.zig");
    var host: @import("LocalTableHost.zig") = .{ .configuration = catalog.store.root.configuration, .registrar = .{ .principal = 0, .key = try key(17), .role = null }, .options = catalog.options, .recovery = try catalog.recoveryState() };
    var work: Work = .{ .host = &host };
    const settings: p.Storage.Maintenance = .{ .flush = .{ .enabled = true } };
    const request: g.Request = .{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .checkpoint };
    const signed = try g.sign(request, try key(17));
    var denied = request;
    denied.principal = 101;
    const initial_cursor = work.cursors.flush;
    try t.expectError(error.Forbidden, Work.step(&work, engine, settings, try g.sign(denied, try key(29))));
    try t.expectEqualDeep(initial_cursor, work.cursors.flush);
    const clock = engine.clock;
    defer engine.clock = clock;
    engine.clock = null; // Physical flushing neither samples nor requires UTC.
    const owner = engine.journal.backend;
    const limits = owner.limits;
    owner.limits.bytes = owner.allocated;
    defer owner.limits = limits;
    try t.expectError(error.StorageQuota, Work.step(&work, engine, settings, signed));
    try t.expectEqual(@as(?u64, expected.binding.target.object), work.cursors.flush.after);
    owner.limits = limits;
    {
        // Revisit this Table within the already captured pass boundary.
        work.cursors.flush.after = expected.binding.target.object - 1;
        PhysicalPause.armed.store(true, .release);
        var flushing = try t.io.concurrent(Work.step, .{ @as(*anyopaque, &work), engine, settings, signed });
        defer _ = flushing.cancel(t.io) catch {};
        defer PhysicalPause.release.set(t.io);
        PhysicalPause.wait(&PhysicalPause.entered) catch |err| {
            std.debug.print("Physical flush did not reach private sync: {s}\n", .{@errorName(err)});
            return err;
        };
        var done: std.Io.Event = .unset;
        var control = try t.io.concurrent(PhysicalPause.fence, .{ owner, engine.genesis, &done });
        defer _ = control.cancel(t.io) catch {};
        PhysicalPause.wait(&done) catch |err| {
            std.debug.print("Native fence did not finish during paused private sync: {s}\n", .{@errorName(err)});
            return err;
        };
        try control.await(t.io);
        try t.expect(!PhysicalPause.release.isSet());
        PhysicalPause.release.set(t.io);
        try t.expectError(error.StaleStorageEpoch, flushing.await(t.io));
        const pending = try catalog.inspectStorage(expected.binding.target, 1, policy.policy());
        try t.expect(pending.pending.rows == 1 and pending.changed_lsn == expected.outcome.position.next_lsn);
    }
    const begin = std.Io.Clock.awake.now(t.io);
    var peak: usize = 0;
    var steps: usize = 0;
    while (true) : (steps += 1) {
        const progressed = try Work.step(&work, engine, settings, signed);
        peak = @max(peak, work.last_peak_bytes);
        if (progressed and work.last_object == expected.binding.target.object) break;
        if (steps == 32) return error.FixtureBudget;
    }
    peak = @max(peak, work.last_peak_bytes);
    try t.expect(work.last_rows > 0 and peak <= settings.resident_bytes);
    std.debug.print("Local physical flush: {d} scheduled entries, {d} peak private bytes, {d} ms.\n", .{ steps + 1, peak, begin.durationTo(std.Io.Clock.awake.now(t.io)).toMilliseconds() });
    var current = (try catalog.resolve(t.allocator, 1, name, policy.policy())).?;
    defer current.deinit();
    try t.expectEqual(expected.outcome.position.next_lsn, current.table.root.changed_lsn);
    try t.expect(current.table.root.next_lsn > expected.outcome.position.next_lsn);
    try t.expectEqualDeep(expected, (try catalog.rowStatus(expected.binding, policy.policy())).committed);
    var old = try catalog.scanRows(t.allocator, expected.binding.target, retained, null, .{}, policy.policy());
    defer old.deinit();
    try t.expectEqual(@as(u8, 1), old.count);
    try t.expectEqual(@as(i128, 1), old.rows[0].?.row().cells[0].value.atom.signed);
    // Page ownership no longer exposes the physical row representation. The
    // same retained point still resolves to WAL after the live root is flushed.
    var key_buffer: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
    const retained_key = try old.rows[0].?.row().storageKey(current.table.declaration.schema.schema, &key_buffer);
    var point = (try catalog.readRow(t.allocator, expected.binding.target, retained, retained_key, policy.policy())).?;
    defer point.deinit();
    try t.expect(point == .wal);
    try t.expectEqualDeep(old.rows[0].?.row(), point.row());
    // Fresh volatile work resumes from persisted discovery and observes no
    // pending rows in the already flushed Table. No accepted work is recreated.
    var restarted: Work = .{ .host = &host };
    const after = current.table.root;
    _ = try Work.step(&restarted, engine, settings, signed);
    try current.table.recover();
    try t.expectEqualDeep(after, current.table.root);
}

fn physicalMaintenance(engine: *Engine, catalog: *D, policy: *Policy, expected: c.storage.TablePartition.Evidence, retained: c.storage.TablePartition.SnapshotHandle) !void {
    const Work = @import("LocalTableMaintenance.zig");
    const P = c.storage.TablePartition;
    const Guard = struct {
        engine: *Engine,
        signed: g.SignedRequest,
        resource: u64,
        fn acquire(raw: *anyopaque) !P.Guard.Fence {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const owner = self.engine.journal.backend;
            try owner.authority.lockShared(owner.io);
            errdefer owner.authority.unlockShared(owner.io);
            try self.engine.authorizeMaintenance(self.signed);
            try self.engine.requireResourceLifetime(self.resource);
            return .{ .writer_epoch = self.engine.head.storage_epoch, .policy_epoch = self.engine.head.authorization.revision + 1 };
        }
        fn release(raw: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const owner = self.engine.journal.backend;
            owner.authority.unlockShared(owner.io);
        }
    };
    const request: g.Request = .{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .checkpoint };
    const signed = try g.sign(request, try key(17));
    var authority: Guard = .{ .engine = engine, .signed = signed, .resource = catalog.store.root.configuration.scope.resource };
    const guard: P.Guard = .{ .context = &authority, .acquire = Guard.acquire, .release = Guard.release };
    const Before = struct { object: u64, root: P.Root };
    var before: std.ArrayList(Before) = .empty;
    defer before.deinit(t.allocator);
    var cursor: D.MaintenanceCursor = .{};
    while (true) {
        const entry = try catalog.maintenanceNext(&cursor, guard);
        if (entry.object) |object| {
            var view = (try catalog.maintenanceOpen(t.allocator, object, guard)).?;
            defer view.deinit();
            try before.append(t.allocator, .{ .object = object, .root = view.table.root });
        }
        if (entry.pass_complete) break;
    }
    try t.expect(before.items.len >= 4);
    var host: @import("LocalTableHost.zig") = .{ .configuration = catalog.store.root.configuration, .registrar = .{ .principal = 0, .key = try key(17), .role = null }, .options = catalog.options, .recovery = try catalog.recoveryState() };
    var work: Work = .{ .host = &host };
    const settings: p.Storage.Maintenance = .{
        .flush = .{ .enabled = true, .rows = 1, .work_rows = 2 },
        .archive = .{ .enabled = true, .work_frames = 2 },
        .compact = true,
        .compaction_rows = 2,
    };
    const clock = engine.clock;
    defer engine.clock = clock;
    engine.clock = null;
    const begin = std.Io.Clock.awake.now(t.io);
    var idle: usize = 0;
    var units: usize = 0;
    var peak: usize = 0;
    while (idle < before.items.len * 4 + 8) : (units += 1) {
        if (units == 4096) return error.FixtureBudget;
        if (units == 17) {
            // Lose scheduling/recovery hints once while accepted targets remain.
            work = .{ .host = &host };
            host.table_recovery = @splat(null);
            idle = 0;
        }
        const progressed = Work.step(&work, engine, settings, signed) catch |err| {
            std.debug.print("Table maintenance unit {d}, class {s}, object {?d}: {s}\n", .{ units, if (work.last_class) |value| @tagName(value) else "none", work.last_object, @errorName(err) });
            return err;
        };
        peak = @max(peak, work.last_peak_bytes);
        try t.expect(work.last_peak_bytes <= settings.resident_bytes);
        idle = if (progressed) 0 else idle + 1;
    }
    for (before.items) |original| {
        var view = (try catalog.maintenanceOpen(t.allocator, original.object, guard)).?;
        defer view.deinit();
        const root = view.table.root;
        try t.expectEqualDeep(original.root.declared(), root.declared());
        try t.expectEqual(original.root.changed_lsn, root.changed_lsn);
        try t.expectEqual(original.root.live_rows, root.live_rows);
        try t.expectEqual(original.root.history_floor, root.history_floor);
        try t.expectEqualDeep(original.root.receipts, root.receipts);
        try t.expectEqualDeep(original.root.pins, root.pins);
        try t.expect(root.maintenance.archive_target == null and root.maintenance.compaction_target == null);
        try t.expectEqual(root.maintenance.archive_source_lsn, root.maintenance.archived_source_lsn);
        if (!root.retired and root.next_segment > 1) try t.expectEqual(root.maintenance.compaction_source_lsn, root.maintenance.compacted_source_lsn);
        if (!root.retired) try t.expectEqual(@as(usize, 0), (try view.table.pendingRows(1, guard)).rows);
    }
    try t.expectEqualDeep(expected, (try catalog.rowStatus(expected.binding, policy.policy())).committed);
    var old = try catalog.scanRows(t.allocator, expected.binding.target, retained, null, .{}, policy.policy());
    defer old.deinit();
    try t.expectEqual(@as(i128, 1), old.rows[0].?.row().cells[0].value.atom.signed);
    std.debug.print("Local physical maintenance: {d} Tables, {d} units, {d} peak private bytes, {d} ms.\n", .{ before.items.len, units, peak, begin.durationTo(std.Io.Clock.awake.now(t.io)).toMilliseconds() });
}

test "local catalog checks real native registrations, current ownership and exact request proof" {
    PhysicalPause.real = t.io.vtable;
    var vtable = t.io.vtable.*;
    vtable.fileSync = PhysicalPause.sync;
    var io = t.io;
    io.vtable = &vtable;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, .{ .realm = 42, .root_key = (try key(17)).public_key.toBytes(), .max_clock_error_ms = 5 });
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
    const token_receipt = try directDispatch(&engine, config, role);
    try prerequisiteDispatch(&engine, config, role);
    try namespaceDispatch(&engine, config, role);
    try dependencyDispatch(&engine, config, role);
    try namedResourceDispatch(&engine, config, role);
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
    try physicalFlush(&engine, &catalog, &policy, intent.name, accepted, retained);
    physicalMaintenance(&engine, &catalog, &policy, accepted, retained) catch |err| {
        std.debug.print("Local maintenance integration: {s}\n", .{@errorName(err)});
        return err;
    };
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
    try collectDirect(&engine, &catalog);
    try t.expectEqualDeep(token_receipt, (try catalog.clientToken(.{ .lookup = token_receipt.binding.key }, policy.policy())).?);
    var token_intent = try c.DirectTableIntentStore.load(t.allocator, catalog.data_objects, token_receipt.binding.intent.table);
    defer token_intent.deinit();
    try token_receipt.binding.intent.table.requireSame(try token_intent.reference(1));
    try t.expect((try catalog.status(request.binding, policy.policy())) == .committed);
    try t.expect((try catalog.rowStatus(succeeding.binding, policy.policy())) == .committed);
    var collected_view = (try catalog.resolve(t.allocator, 1, intent.name, policy.policy())).?;
    defer collected_view.deinit();
    try t.expectEqual(@as(u64, 1), collected_view.table.root.live_rows);
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

fn namedResourceDispatch(engine: *Engine, config: D.Configuration, owner_role: u64) !void {
    const R = c.DirectResource;
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    const writer = try command(engine, .{ .spawn = .{} });
    const binding: R.Binding = .{ .definition = g.current_definition, .connection = .{ .scope = config.scope, .branch = 1, .audience = config.audience, .principal = 101, .role = null }, .operation = 12000, .object = .{ .scope = config.scope, .branch = 1, .object = 800 }, .expected = null, .action = .{ .create = .{
        .namespace = 1,
        .name = try .init("native_resource"),
        .owner = owner_role,
        .writer = writer,
        .owned = false,
        .deadline_ms = null,
        .history_ms = null,
        .spec = .{ .kv = .{ .value_type = .int64, .nullable = false, .key_encoding = .native_bytes, .value_encoding = .fvl1 } },
    } } };
    var action: c.DirectTableProtocol.Action = .{ .resource_operation = .{ .binding = binding, .command = .admit, .steps = 64, .signed_allocation = null } };
    // Namespace and resource declarations share one operation identity space.
    var reused = action;
    reused.resource_operation.binding.operation = 800;
    try t.expectError(error.DataIdentityConflict, dispatch(&service, reused));
    (try dispatch(&service, action)).deinit();
    action.resource_operation.command = .execute;
    // Catalog CREATE and ownership do not grant native resource allocation.
    try t.expectError(error.Forbidden, dispatch(&service, action));
    _ = try change(engine, .{ .grant = .{ .object = .{ .kind = .process, .id = writer }, .grantee = owner_role, .privileges = p.permission(.admin) } });
    const prepared = try dispatch(&service, action);
    defer prepared.deinit();
    const work = prepared.value.result.resource_operation.operation;
    try t.expectEqual(.prepared, work.phase);
    try t.expectEqual((try engine.principal(101)).sequence + 1, work.allocation.?.sequence);
    const signed_allocation = try g.sign(try binding.allocation(work.allocation.?), try key(29));
    action.resource_operation.signed_allocation = .{ .allocation = work.allocation.?, .signature = signed_allocation.signature };
    // The native owner accepts allocation before any data grant exists. The
    // denied attachment must retain its original sequence and recover receipt.
    try t.expectError(error.Forbidden, dispatch(&service, action));
    const receipt = (try engine.query(try g.signQuery(.{ .realm = 42, .principal = 101, .kind = .{ .authorization = .{ .kind = .{ .receipt = signed_allocation.request } } } }, try key(29)))).body.authorization.body.receipt.?;
    const resource = receipt.position;
    try t.expectEqual(resource, try engine.submit(signed_allocation));
    const hidden = try dispatch(&service, .{ .resource_lookup = .{ .namespace = 1, .name = "native_resource" } });
    defer hidden.deinit();
    try t.expectEqual(null, hidden.value.result.resource_lookup);
    _ = try change(engine, .{ .grant = .{ .object = .{ .kind = .resource, .id = resource }, .grantee = owner_role, .privileges = p.State.permission(.inspect) | p.State.permission(.read) } });
    const allocated = try dispatch(&service, action);
    defer allocated.deinit();
    try t.expectEqual(.allocated, allocated.value.result.resource_operation.operation.phase);
    try t.expectEqual(resource, allocated.value.result.resource_operation.operation.resulting.?.resource);
    try t.expectEqual(work.allocation, allocated.value.result.resource_operation.operation.allocation);
    const native_head = engine.head.position;
    const again = try dispatch(&service, action);
    defer again.deinit();
    try t.expectEqualDeep(allocated.value.result.resource_operation, again.value.result.resource_operation);
    try t.expectEqual(native_head, engine.head.position);
    _ = try command(engine, .{ .retire_resource = resource });
    try t.expectError(error.StateResourceExpired, dispatch(&service, action));
    action.resource_operation.command = .cancel;
    action.resource_operation.signed_allocation = null;
    const closed = try dispatch(&service, action);
    defer closed.deinit();
    try t.expectEqual(.cancelled, closed.value.result.resource_operation.operation.phase);
    try t.expectEqual(resource, closed.value.result.resource_operation.operation.resulting.?.resource);

    // A caller may also be the registrar. The native allocation sequence is
    // chosen only after registration, then persisted before it is signed.
    var root_binding = binding;
    root_binding.connection.principal = 0;
    root_binding.object.object = 801;
    root_binding.operation = 12001;
    root_binding.action.create.name = try .init("shared_sequence");
    root_binding.action.create.owner = 0;
    // Registrar/root native authority is not an implicit catalog data grant.
    _ = try change(engine, .{ .grant = .{ .object = c.TableAuthority.reference(config.authority.database), .grantee = 0, .privileges = c.TableAuthority.connect } });
    _ = try change(engine, .{ .grant = .{ .object = c.TableAuthority.reference(config.authority.initial_schema_authority), .grantee = 0, .privileges = c.TableAuthority.usage | c.TableAuthority.create } });
    _ = try change(engine, .{ .grant = .{ .object = .{ .kind = .process, .id = writer }, .grantee = 0, .privileges = p.permission(.admin) } });
    const digest: [32]u8 = @splat(18);
    const signed_proof = try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 0, .credential_epoch = (try engine.principal(0)).credential_epoch, .role = null, .audience = config.audience, .context = digest }, try key(17));
    var policy = try Policy.init(engine, config, signed_proof, digest, null);
    var control: backend.DataStore = .{ .backend = engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = engine.journal.backend };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    _ = try catalog.resourceOperation(root_binding, .admit, policy.policy());
    var runner: @import("LocalCatalogRunner.zig") = .{ .engine = engine, .principal = 0, .key = try key(17) };
    const before = (try engine.principal(0)).sequence;
    const planned = (try runner.runResource(&catalog, root_binding, policy.policy(), .execute, 64, null)).observation.operation;
    try t.expectEqual(.prepared, planned.phase);
    try t.expect(planned.allocation.?.sequence > before + 1);
    try t.expectEqual((try engine.principal(0)).sequence + 1, planned.allocation.?.sequence);
    const signed = try g.sign(try root_binding.allocation(planned.allocation.?), try key(17));
    try t.expectError(error.Forbidden, runner.runResource(&catalog, root_binding, policy.policy(), .execute, 64, .{ .allocation = planned.allocation.?, .signature = signed.signature }));
    const root_resource = try engine.submit(signed);
    _ = try change(engine, .{ .grant = .{ .object = .{ .kind = .resource, .id = root_resource }, .grantee = 0, .privileges = p.State.permission(.inspect) | p.State.permission(.read) } });
    const actual = (try runner.runResource(&catalog, root_binding, policy.policy(), .execute, 64, .{ .allocation = planned.allocation.?, .signature = signed.signature })).observation.operation;
    try t.expectEqual(.allocated, actual.phase);
    try t.expectEqual(actual.resulting.?.resource, try engine.submit(signed));
    _ = try runner.runResource(&catalog, root_binding, policy.policy(), .cancel, 1, null);
    _ = try command(engine, .{ .retire_resource = actual.resulting.?.resource });
}
