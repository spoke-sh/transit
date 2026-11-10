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
// Each disk schedule runs independently through both placements.
var typed_dispatch = false;

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
    return collectDirectBeforeSweep(engine, catalog, null);
}
const CollectionHook = struct { context: *anyopaque, run: *const fn (*anyopaque) anyerror!void };
fn collectDirectBeforeSweep(engine: *Engine, catalog: *D, after_mark: ?CollectionHook) !void {
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
    var admission: @import("DirectStorageMemory.zig") = undefined;
    try admission.init(t.allocator, .{ .admission = .{ .data_bytes = 1024 * 1024, .control_bytes = 1024 * 1024 } });
    defer admission.deinit();
    const held = try admission.allocator(false).alloc(u8, admission.data.limit);
    defer admission.allocator(false).free(held);
    const previous_quota = owner.collection_quota;
    owner.collection_quota = &admission.collection;
    defer owner.collection_quota = previous_quota;
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
    if (after_mark) |hook| try hook.run(hook.context);
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
    try t.expect(admission.collection.peak.load(.acquire) > 0);
    try t.expectEqual(admission.data.limit, admission.total.used.load(.acquire));
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

// These schedules retain many responses across nested revocation callbacks.
// Keep the large protocol union off their stacks, including expectError's
// temporary error unions, while retaining leak-checked ownership of every reply.
const Response = struct {
    owner: *std.json.Parsed(c.DirectTableProtocol.Response),
    value: *const c.DirectTableProtocol.Response,

    fn deinit(self: Response) void {
        self.owner.deinit();
        t.allocator.destroy(self.owner);
    }
};

fn dispatch(service: anytype, action: c.DirectTableProtocol.Action) !Response {
    return dispatchDelegated(service, action, null);
}
fn dispatchDelegated(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation) !Response {
    return dispatchBorrowed(service, action, delegation, null);
}
fn dispatchBorrowed(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow) !Response {
    return dispatchWithSeed(service, action, delegation, borrow, 29);
}
fn dispatchWithSeed(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow, seed: u8) !Response {
    return dispatchContext(service, action, delegation, borrow, seed, null);
}
fn dispatchContext(service: anytype, action: c.DirectTableProtocol.Action, delegation: ?c.DirectReadDelegation, borrow: ?c.DirectReadDelegation.Borrow, seed: u8, transaction: ?c.DirectTransactionRead.Context) !Response {
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const input: w.Request.Input = .{ .definition = g.current_definition, .connection = .{ .scope = service.configuration.scope, .branch = service.configuration.branch, .audience = service.configuration.audience, .principal = 101, .role = null }, .delegation = delegation, .borrow = borrow, .nonce = @splat(7), .action = action, .transaction = transaction };
    const context = try w.Request.context(input, alloc);
    const executor = if (borrow) |value| value.binding.executor else if (delegation) |value| value.binding.executor else 101;
    const signed = if (delegation != null) try a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = executor, .credential_epoch = (try service.engine.principal(executor)).credential_epoch, .role = null, .audience = service.configuration.audience, .context = context }, try key(if (borrow != null) 33 else 31)) else try proofWithSeed(service.engine, context, seed);
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .borrow = input.borrow, .transaction = input.transaction, .proof = signed };
    const bytes = try p.Json.valueAlloc(alloc, request);
    const parsed = try w.Request.parse(alloc, bytes);
    const response = try t.allocator.create(std.json.Parsed(w.Response));
    errdefer t.allocator.destroy(response);
    response.* = response: {
        if (comptime @hasDecl(@TypeOf(service.*), "executeResult")) {
            if (typed_dispatch) {
                const output = try t.allocator.create(std.heap.ArenaAllocator);
                errdefer t.allocator.destroy(output);
                output.* = .init(t.allocator);
                errdefer output.deinit();
                const result = work: {
                    var temporary: std.heap.ArenaAllocator = .init(t.allocator);
                    defer temporary.deinit();
                    break :work try service.executeResult(.typed, &temporary, output.allocator(), parsed.value);
                };
                break :response .{ .arena = output, .value = result };
            }
        }
        const encoded = work: {
            var temporary = std.heap.ArenaAllocator.init(t.allocator);
            defer temporary.deinit();
            break :work try service.execute(&temporary, t.allocator, parsed.value);
        };
        defer t.allocator.free(encoded);
        break :response try p.Json.parseFromSliceOwned(w.Response, t.allocator, encoded);
    };
    // Validate after all request/owner scratch has been released in both modes.
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
    return .{ .owner = response, .value = &response.value };
}

fn hostLookup(service: *@import("LocalTableService.zig"), name: []const u8, native_table: u64, owner_role: u64) !void {
    const Host = @import("LocalTableHost.zig");
    const Adapter = struct {
        host: *Host,
        engine: *Engine,
        configuration: D.Configuration,
        control: bool = false,
        memory: ?@import("DirectRequestMemory.zig").Report = null,
        fn execute(self: *@This(), arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: c.DirectTableProtocol.Request) ![]const u8 {
            return self.host.executeMeasured(self.engine.journal.backend.io, self.engine, arena, output_allocator, request, self.control, &self.memory);
        }
    };
    var options = service.options;
    options.table_recovery = null;
    var admission: @import("DirectStorageMemory.zig") = undefined;
    try admission.init(t.allocator, .{ .admission = .{ .data_bytes = 16 * 1024 * 1024 } });
    defer admission.deinit();
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = options, .recovery = service.recovery_state.?.*, .admission = &admission };
    host.resident_memory.attach(&admission);
    defer host.deinit();
    var adapter: Adapter = .{ .host = &host, .engine = service.engine, .configuration = service.configuration };
    const action: c.DirectTableProtocol.Action = .{ .lookup = .{ .namespace = 1, .name = name } };
    const disk = service.engine.journal.backend.wal.disk.?;
    const before = disk.read_frames;
    const cold = try dispatch(&adapter, action);
    defer cold.deinit();
    const cold_frames = disk.read_frames - before;
    const cold_memory = adapter.memory.?;
    const warmed = disk.read_frames;
    const warm = try dispatch(&adapter, action);
    defer warm.deinit();
    const warm_frames = disk.read_frames - warmed;
    try t.expectEqualDeep(cold.value, warm.value);
    try t.expect(warm_frames < cold_frames);
    // Reusing declaration/index backing reduces allocations, while temporary
    // guard/record decoding and schema encoding still allocate per request.
    try t.expect(adapter.memory.?.acquired_bytes < cold_memory.acquired_bytes);
    try t.expectEqual(cold_memory.live_bytes, adapter.memory.?.live_bytes);
    try t.expect(adapter.memory.?.live_bytes > 0);
    // A different serialized workspace advances the same real Table log.
    // The live cache must refresh, without losing the retained original cut.
    const metadata = cold.value.result.lookup.?;
    const pinned = try dispatch(service, .{ .pin = .{ .object = metadata.interpretation.interpretation.object, .owner = .{ .scope = service.configuration.scope, .principal = 101, .operation = 90001 }, .expected = metadata.position } });
    defer pinned.deinit();
    {
        const retained = admission.data.used.load(.acquire);
        try t.expect(retained > host.resident_memory.data.used.load(.acquire)); // Metadata is included once.
        const held_response = try admission.allocator(false).alloc(u8, admission.data.limit - retained);
        defer admission.allocator(false).free(held_response);
        try t.expectError(error.StorageQuota, dispatch(&adapter, action));
        try t.expect(admission.data.refusals.load(.acquire) > 0);
        adapter.control = true;
        defer adapter.control = false;
        const original = try dispatch(&adapter, .{ .pin_status = .{ .object = metadata.interpretation.interpretation.object, .owner = pinned.value.result.pin.owner } });
        defer original.deinit();
        try t.expectEqualDeep(pinned.value.result.pin, original.value.result.pin_state.handle.?);
        try t.expect(admission.control.used.load(.acquire) > 0);
    }
    {
        var bounded: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = options, .recovery = service.recovery_state.?.* };
        defer bounded.deinit();
        bounded.resident_memory.data.limit = 1;
        var limited: Adapter = .{ .host = &bounded, .engine = service.engine, .configuration = service.configuration };
        try t.expectError(error.StorageQuota, dispatch(&limited, action));
        try t.expectEqual(0, bounded.resident_memory.data.used.load(.acquire));
        limited.control = true;
        const original = try dispatch(&limited, .{ .pin_status = .{ .object = metadata.interpretation.interpretation.object, .owner = pinned.value.result.pin.owner } });
        defer original.deinit();
        try t.expectEqualDeep(pinned.value.result.pin, original.value.result.pin_state.handle.?);
        try t.expect(bounded.resident_memory.control.used.load(.acquire) > 0);
    }
    const refreshed = try dispatch(&adapter, action);
    defer refreshed.deinit();
    try t.expectEqual(metadata.position.next_lsn + 1, refreshed.value.result.lookup.?.position.next_lsn);
    try t.expectEqual(metadata.changed_lsn, refreshed.value.result.lookup.?.changed_lsn);
    const snapshot = try dispatch(&adapter, .{ .snapshot = .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin } });
    defer snapshot.deinit();
    const released = try dispatch(service, .{ .release = .{ .object = metadata.interpretation.interpretation.object, .handle = pinned.value.result.pin } });
    defer released.deinit();
    // The name selects only a volatile slot. Its retained root cannot preserve
    // disclosure rights after the actual native object's owner is replaced.
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = 0 } });
    try t.expectError(error.Forbidden, dispatch(&adapter, action));
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_table), .owner = owner_role } });
    const restored = try dispatch(&adapter, action);
    defer restored.deinit();
    try t.expectEqualDeep(metadata.interpretation, restored.value.result.lookup.?.interpretation);
    try t.expectEqual(metadata.position.next_lsn + 2, restored.value.result.lookup.?.position.next_lsn);
    std.debug.print("Name lookup WAL frames: cold {d}, warm {d}; revocation rechecked.\n", .{ cold_frames, warm_frames });
}

fn dispatchWithoutOutput(service: *@import("LocalTableService.zig"), action: c.DirectTableProtocol.Action) !void {
    const Adapter = struct {
        service: *@import("LocalTableService.zig"),
        engine: *Engine,
        configuration: D.Configuration,
        quota: bool = false,
        fn execute(self: *@This(), arena: *std.heap.ArenaAllocator, _: std.mem.Allocator, request: c.DirectTableProtocol.Request) ![]const u8 {
            if (self.quota) {
                var quota: c.fuze.memory.Quota = .{ .limit = 0 };
                var output: c.fuze.memory.Quota.Allocator = .{ .parent = t.allocator, .quota = &quota };
                const result = self.service.execute(arena, output.allocator(), request);
                try t.expect(quota.refusals.load(.acquire) > 0);
                try t.expectEqual(0, quota.used.load(.acquire));
                return result;
            }
            var failure = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
            const result = self.service.execute(arena, failure.allocator(), request);
            try t.expect(failure.has_induced_failure);
            return result;
        }
    };
    var adapter: Adapter = .{ .service = service, .engine = service.engine, .configuration = service.configuration };
    try t.expectError(error.OutOfMemory, dispatch(&adapter, action));
    // Resolve the same signed operation, never a replacement identity. Losing
    // its response to shared admission must preserve the original outcome too.
    adapter.quota = true;
    try t.expectError(error.OutOfMemory, dispatch(&adapter, action));
}

fn dispatchWithMemory(service: *@import("LocalTableService.zig"), memory: *@import("DirectRequestMemory.zig"), action: c.DirectTableProtocol.Action) !Response {
    const Adapter = struct {
        service: *@import("LocalTableService.zig"),
        memory: *@import("DirectRequestMemory.zig"),
        engine: *Engine,
        configuration: D.Configuration,
        fn execute(self: *@This(), _: *std.heap.ArenaAllocator, output: std.mem.Allocator, request: c.DirectTableProtocol.Request) ![]const u8 {
            var budget = self.memory.request(t.allocator, request.transport().control != null);
            defer t.expectEqual(0, budget.used) catch unreachable;
            const encoded = work: {
                var arena = std.heap.ArenaAllocator.init(budget.allocator());
                defer arena.deinit();
                break :work try self.service.execute(&arena, budget.allocator(), request);
            };
            defer budget.allocator().free(encoded);
            try t.expectEqual(encoded.len, budget.used);
            // The test decoder retains an independent copy after the same
            // scratch/response lifetimes used by the HTTP handler have ended.
            return output.dupe(u8, encoded);
        }
    };
    var adapter: Adapter = .{ .service = service, .memory = memory, .engine = service.engine, .configuration = service.configuration };
    return dispatch(&adapter, action);
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
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init("through_dispatch"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
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
    // Output allocation fails after the accepted mutation. Inspect the exact
    // original operation; never invent another identity or infer rejection.
    try dispatchWithoutOutput(&service, .{ .operation = .{ .binding = work.binding, .command = .execute, .steps = 1 } });
    try t.expect(table_recovered == null);
    var request_memory: @import("DirectRequestMemory.zig") = .{};
    // Outstanding foreground work cannot consume recovery capacity. Resolve
    // the accepted INSERT's original identity even with all data bytes reserved.
    try request_memory.data.reserve(request_memory.data.limit);
    try t.expectError(error.OutOfMemory, dispatchWithMemory(&service, &request_memory, .{ .lookup = .{ .namespace = 1, .name = ddl.name } }));
    const rows = try dispatchWithMemory(&service, &request_memory, .{ .operation = .{ .binding = work.binding, .command = .inspect, .steps = 1 } });
    defer rows.deinit();
    request_memory.data.release(request_memory.data.limit);
    try t.expectEqual(0, request_memory.control.used.load(.acquire));
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
    try request_memory.data.reserve(request_memory.data.limit);
    const released = try dispatchWithMemory(&service, &request_memory, .{ .release = snapshot });
    defer released.deinit();
    request_memory.data.release(request_memory.data.limit);
    try t.expectEqual(0, request_memory.control.used.load(.acquire));
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
    // Staging appends no native transition. Both the immutable intent and its
    // original operation binding are charged to the Table request diagnostics.
    try t.expectEqual(native_before_stage, engine.head.position);
    var binding_bytes: [c.OperationBinding.max_bytes]u8 = undefined;
    const staged_binding = try c.OperationBinding.encodeData(statement.binding, &binding_bytes);
    try t.expectEqual(staged.value.result.staged.content.bytes + staged_binding.bytes.len, engine.journal.observe.metrics.request_payload_bytes - staged_bytes_before);
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
        const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
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
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init("dependency_source"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
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
    const drop_intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = intent.name, .action = .drop };
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
    defer host.deinit();
    var work: Work = .{ .host = &host, .allocator = t.allocator };
    defer work.deinit();
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
        PhysicalPause.entered = .unset;
        PhysicalPause.release = .unset;
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
    var restarted: Work = .{ .host = &host, .allocator = t.allocator };
    defer restarted.deinit();
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
    defer host.deinit();
    var allocations: c.fuze.memory.AllocationProbe = .{ .parent = t.allocator };
    var work: Work = .{ .host = &host, .allocator = allocations.allocator() };
    defer work.deinit();
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
            work.deinit();
            work = .{ .host = &host, .allocator = allocations.allocator() };
            host.table_recovery = @splat(null);
            idle = 0;
        }
        const progressed = Work.step(&work, engine, settings, signed) catch |err| {
            std.debug.print("Table maintenance unit {d}, class {s}, object {?d}: {s}\n", .{ units, if (work.last_class) |value| @tagName(value) else "none", work.last_object, @errorName(err) });
            return err;
        };
        peak = @max(peak, work.last_peak_bytes);
        try t.expect(work.last_peak_bytes <= settings.resident_bytes);
        try t.expectEqual(0, allocations.live_bytes);
        idle = if (progressed) 0 else idle + 1;
    }
    const active_allocations = allocations.counts;
    const active_peak = allocations.peak_bytes;
    allocations.begin(false);
    for (0..16) |_| try t.expect(!try Work.step(&work, engine, settings, signed));
    try t.expectEqual(0, allocations.live_bytes);
    const measurement = try std.json.Stringify.valueAlloc(t.allocator, .{
        .boundary = "private_table_maintenance",
        .tables = before.items.len,
        .active_units = units,
        .active = active_allocations,
        .active_peak_bytes = active_peak,
        .idle_units = 16,
        .idle = allocations.counts,
        .idle_peak_bytes = allocations.peak_bytes,
        .retained_bytes = allocations.live_bytes,
    }, .{});
    defer t.allocator.free(measurement);
    std.debug.print("Local Table maintenance backing allocations: {s}\n", .{measurement});
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
    typed_dispatch = false;
    try catalogSchedule();
}
test "typed local dispatch preserves signed lifecycle, disclosure and retained responses" {
    typed_dispatch = true;
    defer typed_dispatch = false;
    try catalogSchedule();
}
fn catalogSchedule() !void {
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
    const stream_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.stream) } })).?;
    const queue_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.queue) } })).?;
    const kv_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.kv) } })).?;
    const connection_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.connection) } })).?;
    const source_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.source) } })).?;
    const sink_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.sink) } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .stream_domain = stream_domain, .queue_domain = queue_domain, .kv_domain = kv_domain, .connection_domain = connection_domain, .source_domain = source_domain, .sink_domain = sink_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
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
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try c.TableAuthority.Name.init("events"), .action = .{ .create = .{ .owner = role, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} } } } };
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
        .spec = .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } },
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

fn transactionDispatch(service: *@import("LocalTableService.zig"), owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const scope = service.configuration.scope;
    // More Tables than a single native authorization Guard can hold. Each
    // scoped check is current, while the final disclosure checks their epoch.
    for (0..12) |i| {
        const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
        const schema: c.fuze.TableSchema.Schema = .{ .object = 100000 + i, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
        var name: [40]u8 = undefined;
        const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init(try std.fmt.bufPrint(&name, "tx_selected_{d}", .{i})), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
        const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 100000 + i }, .target = .{ .scope = scope, .branch = 1, .object = 100000 + i }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(allocator) };
        var encoded: [65536]u8 = undefined;
        const admitted = try dispatch(service, .{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = intent.name.slice(), .action = .{ .create = .{ .owner = owner_role, .schema = try w.Binary.encode(allocator, try schema.encode(&encoded)) } } } });
        admitted.deinit();
        const done = try dispatch(service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 4 } });
        defer done.deinit();
        try t.expect(done.value.result.ddl == .committed);
        _ = arena.reset(.retain_capacity);
    }
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    const token: c.DirectClientToken.Key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(80), .token = @splat(81) };
    const begin: c.DirectTransactionRequest.Begin = .{ .key = token, .fingerprint = @splat(82), .operation = .{ .scope = scope, .principal = 101, .operation = 110000 }, .namespace = 1, .mode = .serializable, .selection = .authorized_catalog_tables, .limits = c.DirectTransaction.default_limits, .deadline = null, .budget = .{} };
    const begun = try dispatch(service, .{ .transaction = .{ .begin = begin } });
    defer begun.deinit();
    try t.expect(begun.value.result.transaction.begun.binding.intent.transaction.begin.objects.count >= 12);
    const acquired = try dispatch(service, .{ .transaction = .{ .acquire = token } });
    defer acquired.deinit();
    try t.expect(acquired.value.result.transaction.acquired.cut.sources.count >= 12);
    var authorization = try service.engine.authorization();
    var revoked = (try authorization.bound(service.configuration.authority.table_domain, try c.TableAuthority.binding(scope, .table, 100011))).?.reference.id;
    const Revoke = struct {
        fn run(raw: *anyopaque, engine: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(raw));
            _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    service.before_reply = .{ .context = &revoked, .run = Revoke.run };
    defer service.before_reply = null;
    // The immutable acquired cut was already buffered. A changed native policy
    // epoch prevents its disclosure, even though CONNECT remains permitted.
    try t.expectError(error.AuthorizationChanged, dispatch(service, .{ .transaction = .{ .acquire = token } }));
    service.before_reply = null;
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(revoked), .owner = owner_role } });
    const resumed = try dispatch(service, .{ .transaction = .{ .acquire = token } });
    defer resumed.deinit();
    try t.expectEqualDeep(acquired.value.result, resumed.value.result);
    for (0..2) |i| {
        var name: [40]u8 = undefined;
        const table_name = try std.fmt.bufPrint(&name, "tx_selected_{d}", .{i});
        const metadata = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = table_name } });
        defer metadata.deinit();
        const definition = metadata.value.result.lookup.?;
        try t.expectEqual(@as(u64, 0), definition.row_count);
        const schema_bytes = try definition.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
        var schema = try c.fuze.TableSchema.decode(allocator, schema_bytes);
        defer schema.deinit();
        const sql = try std.fmt.allocPrint(allocator, "INSERT INTO {s} VALUES (7)", .{table_name});
        var plan = try c.fuze.TableDml.compile(allocator, sql, table_name, schema.schema, null);
        defer plan.deinit();
        var intent = try c.DirectTableIntent.fromDml(allocator, connection, definition, 120000 + i, plan.plan, .bulk);
        defer intent.deinit();
        const before_stage = try dispatch(service, .{ .transaction = .{ .inspect = token } });
        defer before_stage.deinit();
        const staged = try dispatch(service, .{ .transaction = .{ .stage = .{ .key = token, .basis = before_stage.value.result.transaction.status.revision, .sequence = i + 1, .work = intent.parsed.value.work } } });
        defer staged.deinit();
        const original = staged.value.result.transaction.staged;
        const executed = try dispatch(service, .{ .transaction = .{ .statement = .{ .key = token, .request = original, .execute = true } } });
        defer executed.deinit();
        try t.expectEqual(@as(u64, 1), executed.value.result.transaction.statement.?.provisional.affected);
        const repeated = try dispatch(service, .{ .transaction = .{ .statement = .{ .key = token, .request = original, .execute = true } } });
        defer repeated.deinit();
        try t.expectEqualDeep(executed.value.result, repeated.value.result);
        const public = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = table_name } });
        defer public.deinit();
        try t.expectEqual(@as(u64, 0), public.value.result.lookup.?.row_count);
    }
    const status = try dispatch(service, .{ .transaction = .{ .inspect = token } });
    defer status.deinit();
    const context: c.DirectTransactionRead.Context = .{ .key = token, .revision = status.value.result.transaction.status.revision };
    const private_metadata = try dispatchContext(service, .{ .lookup = .{ .namespace = 1, .name = "tx_selected_0" } }, null, null, 29, context);
    defer private_metadata.deinit();
    const private = private_metadata.value.result.lookup.?;
    try t.expectEqual(@as(u64, 1), private.row_count);
    const view = private.workspace.?;
    const snapshot: w.Snapshot = .{ .object = private.interpretation.interpretation.object, .handle = .{ .owner = view.cut.begin.identity.begin, .content = view.private } };
    const source = try dispatchContext(service, .{ .snapshot = snapshot }, null, null, 29, context);
    defer source.deinit();
    try t.expectEqualDeep(view, source.value.result.snapshot.workspace.?);
    revoked = (try authorization.bound(service.configuration.authority.table_domain, try c.TableAuthority.binding(scope, .table, 100000))).?.reference.id;
    service.before_reply = .{ .context = &revoked, .run = Revoke.run };
    try t.expectError(error.AuthorizationChanged, dispatchContext(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, null, null, 29, context));
    service.before_reply = null;
    _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(revoked), .owner = owner_role } });
    const page = try dispatchContext(service, .{ .scan = .{ .snapshot = snapshot, .after = null, .limits = .{} } }, null, null, 29, context);
    defer page.deinit();
    try t.expectEqual(@as(usize, 1), page.value.result.page.rows.len);
    try t.expectEqualDeep(view.source.source.accepted, page.value.result.page.accepted);
    const save: c.DirectTransactionSavepoint.Request = .{ .transaction = view.cut.begin.identity, .operation = .{ .scope = scope, .principal = 101, .operation = 130000 }, .sequence = 1, .basis = context.revision, .action = .{ .create = try c.TableAuthority.Name.init("private_rows") } };
    const saved = try dispatch(service, .{ .transaction = .{ .savepoint = .{ .key = token, .request = save, .steps = 1 } } });
    defer saved.deinit();
    const rollback: c.DirectTransactionSavepoint.Request = .{ .transaction = view.cut.begin.identity, .operation = .{ .scope = scope, .principal = 101, .operation = 130001 }, .sequence = 2, .basis = saved.value.result.transaction.savepoint.completed.?, .action = .{ .rollback = try c.TableAuthority.Name.init("private_rows") } };
    const rolling = try dispatch(service, .{ .transaction = .{ .savepoint = .{ .key = token, .request = rollback, .steps = 1 } } });
    defer rolling.deinit();
    try t.expect(rolling.value.result.transaction.savepoint.completed == null);
    for (0..2) |i| {
        const advanced = try dispatch(service, .{ .transaction = .{ .advance = .{ .key = token, .steps = 1 } } });
        defer advanced.deinit();
        try t.expectEqual(i == 0, advanced.value.result.transaction.status.pending_control);
    }
    const restored = try dispatch(service, .{ .transaction = .{ .savepoint = .{ .key = token, .request = rollback, .steps = 1 } } });
    defer restored.deinit();
    try t.expect(restored.value.result.transaction.savepoint.completed != null);
    try t.expectError(error.TransactionReadChanged, dispatchContext(service, .{ .snapshot = snapshot }, null, null, 29, context));
    const settled = try dispatch(service, .{ .transaction = .{ .settle = .{ .key = token, .operation = .{ .scope = scope, .principal = 101, .operation = 110001 }, .command = .commit, .steps = 256 } } });
    defer settled.deinit();
    try t.expect(settled.value.result.transaction.status.cleanup_complete);
    try t.expect(settled.value.result.transaction.status.observation.decided.outcome == .committed);
    try t.expectError(error.TransactionReadChanged, dispatchContext(service, .{ .snapshot = snapshot }, null, null, 29, context));

    // Physical collection advances storage authority without revoking grants.
    // Withhold the buffered status, but preserve the original transaction for
    // a fresh observation instead of reporting a permanent permission denial.
    const Fence = struct {
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*u64, @ptrCast(@alignCast(raw))).* };
        }
        fn run(raw: *anyopaque, engine: *Engine) !void {
            const previous = engine.clock;
            defer engine.clock = previous;
            engine.clock = .{ .context = raw, .read = read };
            _ = try command(engine, .{ .storage_fence = {} });
        }
    };
    var fence_context = service.engine.head.time_floor_ms + 100;
    const policy_revision = service.engine.head.authorization.revision;
    service.before_reply = .{ .context = &fence_context, .run = Fence.run };
    try t.expectError(error.StaleStorageEpoch, dispatch(service, .{ .transaction = .{ .inspect = token } }));
    service.before_reply = null;
    try t.expectEqual(policy_revision, service.engine.head.authorization.revision);
    const after_fence = try dispatch(service, .{ .transaction = .{ .inspect = token } });
    defer after_fence.deinit();
    try t.expectEqualDeep(settled.value.result.transaction.status, after_fence.value.result.transaction.status);

    // A fence between separate scoped checks has the same classification as
    // one after buffering. Each guard still authenticates the current caller.
    const digest: [32]u8 = @splat(83);
    var policy = try Policy.init(service.engine, service.configuration, try proof(service.engine, digest), digest, null);
    policy.paged = true;
    const api = policy.policy();
    const requirement = try c.TableAuthority.guard(api.subject, service.configuration.authority, null, null, .database);
    const first_guard = try api.make_guard(api.context, allocator, requirement, null);
    _ = try first_guard.acquire(first_guard.context);
    first_guard.release(first_guard.context);
    fence_context += 100;
    try Fence.run(&fence_context, service.engine);
    const next_guard = try api.make_guard(api.context, allocator, requirement, null);
    try t.expectError(error.StaleStorageEpoch, next_guard.acquire(next_guard.context));
}

test "signed transaction controls preserve paged policy and private atomic work" {
    typed_dispatch = false;
    try transactionSchedule();
}
test "typed transaction controls preserve paged policy and private atomic work" {
    typed_dispatch = true;
    defer typed_dispatch = false;
    try transactionSchedule();
}
fn transactionSchedule() !void {
    try dataSchedule(transactionDispatch);
}

const NativeDataFixture = struct {
    directory: std.Io.Dir,
    owner: backend.Backend = undefined,
    pages: backend.PageStore = undefined,
    journal: backend.Store = undefined,
    engine: Engine = undefined,
    owner_open: bool = false,
    pages_open: bool = false,

    fn open(self: *@This(), fresh: bool) !void {
        self.owner = try backend.Backend.open(t.allocator, t.io, self.directory, "native", .{});
        self.owner_open = true;
        errdefer self.close();
        self.pages = try backend.PageStore.init(&self.owner, 1);
        self.pages_open = true;
        self.journal = .{ .backend = &self.owner };
        const genesis: @FieldType(Engine, "genesis") = .{ .realm = 42, .root_key = (try key(17)).public_key.toBytes(), .max_clock_error_ms = 5 };
        self.engine = if (fresh) try Engine.bootstrap(&self.journal, &self.pages, genesis) else try Engine.open(&self.journal, &self.pages, genesis);
    }
    fn close(self: *@This()) void {
        if (self.pages_open) self.pages.deinit();
        if (self.owner_open) self.owner.deinit();
        self.pages_open = false;
        self.owner_open = false;
    }
    fn reopen(self: *@This()) !void {
        self.close();
        try self.open(false);
    }
};

fn dataSchedule(comptime run: anytype) !void {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var fixture: NativeDataFixture = .{ .directory = tmp.dir };
    try fixture.open(true);
    defer fixture.close();
    const engine = &fixture.engine;
    const pid = try command(engine, .{ .spawn = .{} });
    const resource = try command(engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    const role = (try change(engine, .{ .create_role = .{ .name = try p.Value.init("catalog-owner"), .login = true } })).?;
    _ = try change(engine, .{ .bind_credential = .{ .principal = 101, .role = role, .public_key = (try key(29)).public_key.toBytes() } });
    const database_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const stream_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.stream) } })).?;
    const queue_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.queue) } })).?;
    const kv_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.kv) } })).?;
    const connection_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.connection) } })).?;
    const source_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.source) } })).?;
    const sink_domain = (try change(engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.sink) } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .stream_domain = stream_domain, .queue_domain = queue_domain, .kv_domain = kv_domain, .connection_domain = connection_domain, .source_domain = source_domain, .sink_domain = sink_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    const initialized = try dispatch(&service, .initialize);
    initialized.deinit();
    try run(&service, role);
}

test "SOURCE native registration resumes original acceptance and fences revoked creation" {
    try dataSchedule(sourceRegistrationSchedule);
}

fn sourceRegistrationSchedule(service: *@import("LocalTableService.zig"), owner_role: u64) !void {
    const engine = service.engine;
    const config = service.configuration;
    const digest: [32]u8 = @splat(91);
    var policy = try Policy.init(engine, config, try proof(engine, digest), digest, null);
    var control: backend.DataStore = .{ .backend = engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = engine.journal.backend };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    const intent: c.DirectSource.Intent = .{ .kind = .connection, .namespace = 1, .name = try .init("upstream"), .action = .{ .create = .{ .owner = owner_role, .payload = .{ .connection = .{ .endpoint = "https://example.com" } } } } };
    const request: c.DirectSource.Request = .{ .intent = intent, .binding = .{
        .definition = g.current_definition,
        .identity = .{ .scope = config.scope, .principal = 101, .operation = 15000 },
        .target = .{ .scope = config.scope, .branch = 1, .object = 15000 },
        .action = .create,
        .expected_definition = null,
        .expected_data = null,
        .intent = try intent.digest(t.allocator),
    } };
    try t.expectError(error.SourceReservationRequired, catalog.sourceRegistration(request, policy.policy()));
    _ = try catalog.sourceOperation(request, .reserve, policy.policy());
    try t.expectError(error.CatalogRegistrationRequired, catalog.sourceOperation(request, .execute, policy.policy()));
    const registration = (try catalog.sourceRegistration(request, policy.policy())).?;
    try t.expectEqual(config.authority.connection_domain, registration.action.domain);
    try t.expectEqual(owner_role, registration.action.owner);
    const position = catalog.store.root.next_lsn;
    const signed = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .{ .authorization = .{ .begin = .{ .expected_revision = registration.authorization_revision, .action = .{ .register_object = registration.action } } } } }, try key(17));
    // Lose the registration begin observation, rebuild the Catalog owner, then
    // resolve the identical native request instead of creating another change.
    const original_change = try engine.submit(signed);
    catalog.deinit();
    catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    try catalog.recover();
    try t.expectEqual(original_change, try engine.submit(signed));
    try t.expectEqual(position, catalog.store.root.next_lsn);
    try t.expect(try catalog.resolveSource(t.allocator, .{ .namespace = 1, .kind = .connection }, intent.name, policy.policy()) == null);
    const registered = (try finish(engine, original_change)).?;
    try t.expect(try catalog.sourceRegistration(request, policy.policy()) == null);
    // A lost attachment reply retains the same native object and declaration
    // reservation. The runner completes the original after Catalog recovery.
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.sourceOperation(request, .execute, policy.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    var runner: @import("LocalCatalogRunner.zig") = .{ .engine = engine, .principal = 0, .key = try key(17) };
    const accepted = (try runner.runSource(&catalog, request, policy.policy(), 32)).operation;
    try t.expectEqual(.applied, accepted.phase);
    try t.expectEqual(registered, accepted.resulting.?.declaration.properties.authorization);
    try t.expectEqualDeep(accepted, (try runner.runSource(&catalog, request, policy.policy(), 32)).operation);

    var raced = request;
    raced.binding.identity.operation += 1;
    raced.binding.target.object += 1;
    raced.intent.name = try .init("revoked_upstream");
    raced.binding.intent = try raced.intent.digest(t.allocator);
    _ = try catalog.sourceOperation(raced, .reserve, policy.policy());
    const Revoke = struct {
        schema: u64,
        role: u64,
        calls: usize = 0,
        fn run(raw: *anyopaque, authority: *Engine) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            _ = try change(authority, .{ .revoke_privileges = .{ .object = c.TableAuthority.reference(self.schema), .grantee = self.role, .privileges = c.TableAuthority.create } });
        }
    };
    var revoke: Revoke = .{ .schema = config.authority.initial_schema_authority, .role = owner_role };
    runner.after_prepare = .{ .context = &revoke, .run = Revoke.run };
    try t.expectError(error.Forbidden, runner.runSource(&catalog, raced, policy.policy(), 32));
    try t.expectEqual(1, revoke.calls);
    var authority = try engine.authorization();
    try t.expect(try authority.bound(config.authority.connection_domain, try c.TableAuthority.binding(config.scope, .connection, raced.binding.target.object)) == null);
    try t.expect(try catalog.resolveSource(t.allocator, .{ .namespace = 1, .kind = .connection }, raced.intent.name, policy.policy()) == null);
    runner.after_prepare = null;
    _ = try change(engine, .{ .grant = .{ .object = c.TableAuthority.reference(revoke.schema), .grantee = owner_role, .privileges = c.TableAuthority.create } });
    const recovered = (try runner.runSource(&catalog, raced, policy.policy(), 32)).operation;
    try t.expectEqual(.applied, recovered.phase);
    try t.expectEqualDeep(raced.binding, recovered.binding);
    try t.expect(recovered.resulting.?.declaration.properties.authorization != registered);
}

test "shared refusals distinguish current denial from storage and missing-owner failures" {
    const failure = @import("ServiceFailure.zig");
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.SourceCaptureCursorUnauthenticated).code);
    try t.expectEqual(p.ErrorCode.NotFound, failure.table(error.SourceCaptureNotPublished).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.SourceCapturePublicationPending).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.SourceCaptureReadUnavailable).code);
    try t.expectEqual(p.ErrorCode.QueryExpired, failure.table(error.HistoricalSnapshotReleased).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.HistoricalArtifactUnavailable).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.InvalidHistoricalArtifact).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.HistoricalSourceChanged).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.HistoricalRetentionOwned).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.HistoricalRetentionPending).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidHistoricalCursor).code);
    try t.expectEqual(p.ErrorCode.StorageQuota, failure.table(error.HistoricalObjectLimit).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.BranchSourceChanged).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.BranchRetentionOwned).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidBranchCursor).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.BranchArtifactMissing).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidTransactionTarget).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidTransactionParticipant).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidTransactionTransfer).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidLogIntent).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidWorkloadIntent).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidWorkloadResultBudget).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.WorkloadResultRowTooLarge).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.WorkloadResultUnavailable).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.WorkloadResultConflict).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.WorkloadResultClosed).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidWorkloadProjection).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.WorkloadProjectionUnavailable).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.WorkloadProjectionSourceChanged).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.ClientTokenBudget).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.WorkloadServiceUnavailable).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.ClientOperationPending).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidTransactionSettlement).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidTransactionDeadline).code);
    try t.expectEqual(p.ErrorCode.DeadlineExpired, failure.table(error.TransactionDeadlineElapsed).code);
    try t.expectEqual(std.http.Status.unprocessable_entity, failure.table(error.TransactionDeadlineElapsed).status);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidKVKey).code);
    try t.expectEqual(p.ErrorCode.StorageQuota, failure.table(error.KVBuildBudget).code);
    // A provider AccessDenied is not itself a native authorization decision.
    try t.expectEqual(std.http.Status.unprocessable_entity, failure.native(error.AccessDenied).status);
    try t.expectEqual(std.http.Status.forbidden, failure.native(error.Forbidden).status);
    try t.expectEqual(std.http.Status.forbidden, failure.table(error.CatalogDenied).status);
    try t.expectEqual(std.http.Status.conflict, failure.table(error.CatalogDefinitionChanged).status);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.CatalogDefinitionChanged).code);
    // Missing data inside an admitted operation remains a rejection. A missing
    // ingress route has its separate 404 path before operation execution.
    try t.expectEqual(std.http.Status.unprocessable_entity, failure.table(error.NotFound).status);
    const unavailable = failure.table(error.InjectedStorageUnavailable);
    try t.expectEqual(std.http.Status.service_unavailable, unavailable.status);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, unavailable.code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.LogGroupFenced).code);
    try t.expectEqual(p.ErrorCode.QueryExpired, failure.table(error.StreamReadReleased).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.StreamCursorUnauthenticated).code);
    try t.expectEqual(p.ErrorCode.ClockUnavailable, failure.table(error.LogTimeUnavailable).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.LogRetentionWindowElapsed).code);
    try t.expectEqual(p.ErrorCode.HistoryReclaimed, failure.table(error.LogRangeExpired).code);
    try t.expectEqual(p.ErrorCode.AuthorityUnavailable, failure.table(error.LogHistoryUnavailable).code);
    try t.expectEqual(p.ErrorCode.ClockUnavailable, failure.table(error.QueueTimeUnavailable).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.QueueLeaseFenced).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.QueueLeaseExpired).code);
    try t.expectEqual(p.ErrorCode.StorageQuota, failure.table(error.QueueLeaseCapacityExceeded).code);
    try t.expectEqual(p.ErrorCode.StorageQuota, failure.table(error.QueueCheckpointBacklog).code);
    try t.expectEqual(std.http.Status.service_unavailable, failure.table(error.QueueCheckpointBacklog).status);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.QueueReadBudgetExceeded).code);
    try t.expectEqual(p.ErrorCode.QueryExpired, failure.table(error.QueueReadReleased).code);
    try t.expectEqual(p.ErrorCode.Conflict, failure.table(error.QueueReadReleaseConflict).code);
    try t.expectEqual(p.ErrorCode.InvalidRequest, failure.table(error.InvalidQueueReadRelease).code);
}

test "log privileges enforce separate native domains and current disclosure rights" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
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
    const stream_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.stream) } })).?;
    const queue_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.queue) } })).?;
    const kv_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.kv) } })).?;
    const connection_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.connection) } })).?;
    const source_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.source) } })).?;
    const sink_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.sink) } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .stream_domain = stream_domain, .queue_domain = queue_domain, .kv_domain = kv_domain, .connection_domain = connection_domain, .source_domain = source_domain, .sink_domain = sink_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    const alloc = scratch.allocator();
    const namespace_record: c.TableAuthority.Schema = .{ .scope = scope, .id = 1, .authorization = namespace, .name = config.initial_schema_name, .revision = 1 };
    try logLifecycleDispatch(&engine, config, role);
    for ([_]c.TableAuthority.Kind{ .stream, .queue }, 0..) |kind, i| {
        const object_id: u64 = 200 + i;
        const native_id = (try change(&engine, .{ .register_object = .{ .domain = config.authority.domain(kind), .owner = 0, .schema = c.TableAuthority.reference(namespace), .binding = try c.TableAuthority.binding(scope, kind, object_id) } })).?;
        const target: c.TableAuthority.Table = .{ .id = object_id, .schema = 1, .authorization = native_id };
        const context: [32]u8 = @splat(9);
        var policy = try Policy.init(&engine, config, try proof(&engine, context), context, null);
        const registered = (try policy.policy().registered(&policy, kind, object_id)).?;
        try c.TableAuthority.validateObject(config.authority, scope, kind, object_id, c.TableAuthority.reference(namespace), registered);
        try t.expectError(error.InvalidCatalogConfiguration, c.TableAuthority.validateObject(config.authority, scope, if (kind == .stream) .queue else .stream, object_id, c.TableAuthority.reference(namespace), registered));
        const masks = [_]u64{ c.LogAuthority.inspect, c.LogAuthority.read, c.LogAuthority.append, c.LogAuthority.read | c.LogAuthority.acquire, c.LogAuthority.settle };
        for ([_]c.LogAuthority.Access{ .inspect, .read, .append, .acquire, .settle }, masks) |access, mask| {
            _ = scratch.reset(.retain_capacity);
            policy = try Policy.init(&engine, config, try proof(&engine, context), context, null);
            const requirements = try c.LogAuthority.requirements(config.authority, policy.policy().subject, namespace_record, target, access);
            const guard = try policy.policy().make_guard(&policy, alloc, requirements, null);
            try t.expectError(error.Forbidden, guard.acquire(guard.context));
            _ = try change(&engine, .{ .grant = .{ .object = registered.reference, .grantee = role, .privileges = mask } });
            _ = try guard.acquire(guard.context);
            guard.release(guard.context);
            _ = try policy.check();
            _ = try change(&engine, .{ .revoke_privileges = .{ .object = registered.reference, .grantee = role, .privileges = mask, .behavior = .cascade } });
            // Both the original operation guard and already-buffered response
            // must fail after revocation; a saved signed proof grants no rights.
            try t.expectError(error.Forbidden, guard.acquire(guard.context));
            try t.expectError(error.Forbidden, policy.check());
        }
    }
}

fn logLifecycleDispatch(engine: *Engine, config: D.Configuration, role: u64) !void {
    var service: @import("LocalTableService.zig") = .{ .engine = engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } } };
    (try dispatch(&service, .initialize)).deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const cols = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const intent: c.DirectLog.Intent = .{ .kind = .stream, .namespace = 1, .name = try .init("registered_stream"), .action = .{ .create = .{
        .owner = role,
        .schema = .{ .object = 300, .revision = 1, .next_column = 2, .columns = &cols, .primary_key = &.{} },
        .configuration = .{ .partitioning = .{ .count = 2, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = 1, .timestamp_column = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 300 }, .target = .{ .scope = config.scope, .branch = 1, .object = 300 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) };
    const ddl = try c.DirectLogProtocol.Ddl.encode(arena.allocator(), .{ .binding = binding, .intent = intent });
    (try dispatch(&service, .{ .log_admit = ddl })).deinit();
    const pending = try dispatch(&service, .{ .log_pending = .{ .namespace = 1, .after = null } });
    defer pending.deinit();
    try t.expectEqualDeep(binding, pending.value.result.log_pending.entries[0].?.binding);
    const finished = try dispatch(&service, .{ .log_operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer finished.deinit();
    try t.expectEqual(.complete, finished.value.result.log_operation.operation.phase);
    try t.expectEqual(@as(u32, 2), finished.value.result.log_operation.operation.initialized);
    const found = try dispatch(&service, .{ .log_lookup = .{ .namespace = 1, .name = "registered_stream" } });
    defer found.deinit();
    try t.expectEqualDeep(finished.value.result.log_operation.operation.resulting.?, found.value.result.log_lookup.?.declaration);
    const retained_page = try streamPayloadDispatch(&service, found.value.result.log_lookup.?.declaration, intent.action.create.schema);
    const Revoke = struct {
        fn prepare(current: *Engine, id: u64) !u64 {
            const change_id = try command(current, .{ .authorization = .{ .begin = .{ .expected_revision = current.head.authorization.revision, .action = .{ .transfer_object = .{ .object = c.TableAuthority.reference(id), .owner = 0 } } } } });
            for (0..256) |_| {
                const observed = try outcome(current, change_id);
                if (observed.status == .ready) return change_id;
                try t.expectEqual(.preparing, observed.status);
                _ = try command(current, .{ .authorization = .{ .advance = change_id } });
            }
            return error.PolicyPreparationBudget;
        }
        fn publish(current: *Engine, id: u64) !void {
            _ = try command(current, .{ .authorization = .{ .publish = id } });
        }
        fn transfer(current: *Engine, id: u64, new_owner: u64) !void {
            _ = try change(current, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id), .owner = new_owner } });
        }
        fn run(raw: *anyopaque, current: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(raw));
            _ = try change(current, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var native_id = found.value.result.log_lookup.?.declaration.properties.authorization;
    try @import("local_log_wait_test.zig").exercise(&service, found.value.result.log_lookup.?.declaration, intent.action.create.schema, role, Revoke.prepare, Revoke.publish, Revoke.transfer);
    const maintenance_context: [32]u8 = @splat(19);
    var maintenance_policy = try Policy.init(engine, config, try proof(engine, maintenance_context), maintenance_context, null);
    try @import("local_stream_maintenance_test.zig").exercise(&service, found.value.result.log_lookup.?.declaration, maintenance_policy.policy());
    var retention = intent.action.create.configuration;
    retention.retention.max_age_ms = 100;
    const expiry_intent: c.DirectLog.Intent = .{ .kind = .stream, .namespace = 1, .name = intent.name, .action = .{ .alter = .{ .configuration = retention, .limits = intent.action.create.limits } } };
    const expiry_binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 400 }, .target = binding.target, .action = .alter, .expected_definition = found.value.result.log_lookup.?.declaration.stored.declaration.interpretation, .expected_data = null, .intent = try expiry_intent.digest(t.allocator) };
    const expiry_ddl = try c.DirectLogProtocol.Ddl.encode(arena.allocator(), .{ .binding = expiry_binding, .intent = expiry_intent });
    (try dispatch(&service, .{ .log_admit = expiry_ddl })).deinit();
    const expiry = try dispatch(&service, .{ .log_operation = .{ .binding = expiry_binding, .command = .execute, .steps = 32 } });
    defer expiry.deinit();
    try @import("local_stream_maintenance_test.zig").expire(&service, expiry.value.result.log_operation.operation.resulting.?);
    var queue_intent = intent;
    queue_intent.kind = .queue;
    queue_intent.name = try .init("registered_queue");
    queue_intent.action.create.schema.object = 301;
    queue_intent.action.create.configuration.retention.max_age_ms = 100;
    queue_intent.action.create.configuration.policy = .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } };
    var queue_binding = binding;
    queue_binding.identity.operation = 500;
    queue_binding.target.object = 301;
    queue_binding.intent = try queue_intent.digest(t.allocator);
    const queue_ddl = try c.DirectLogProtocol.Ddl.encode(arena.allocator(), .{ .binding = queue_binding, .intent = queue_intent });
    (try dispatch(&service, .{ .log_admit = queue_ddl })).deinit();
    const queue_created = try dispatch(&service, .{ .log_operation = .{ .binding = queue_binding, .command = .execute, .steps = 32 } });
    defer queue_created.deinit();
    const queue_declared = queue_created.value.result.log_operation.operation.resulting.?;
    const queue_terminal = try @import("local_queue_test.zig").exercise(&service, queue_declared, queue_intent.action.create.schema, try key(29));
    var queue_native_id = queue_declared.properties.authorization;
    service.before_reply = .{ .context = &queue_native_id, .run = Revoke.run };
    try t.expectError(error.Forbidden, dispatch(&service, .{ .queue = queue_terminal }));
    service.before_reply = null;
    _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(queue_native_id), .owner = role } });
    try @import("local_queue_maintenance_test.zig").exercise(&service, queue_declared, queue_intent.action.create.schema, maintenance_policy.policy());
    var wait_intent = queue_intent;
    wait_intent.name = try .init("waiting_queue");
    wait_intent.action.create.schema.object = 302;
    wait_intent.action.create.configuration.partitioning.count = 1;
    var wait_binding = queue_binding;
    wait_binding.identity.operation = 649;
    wait_binding.target.object = 302;
    wait_binding.intent = try wait_intent.digest(t.allocator);
    const wait_ddl = try c.DirectLogProtocol.Ddl.encode(arena.allocator(), .{ .binding = wait_binding, .intent = wait_intent });
    (try dispatch(&service, .{ .log_admit = wait_ddl })).deinit();
    const wait_created = try dispatch(&service, .{ .log_operation = .{ .binding = wait_binding, .command = .execute, .steps = 32 } });
    defer wait_created.deinit();
    try @import("local_log_wait_test.zig").exerciseQueue(&service, wait_created.value.result.log_operation.operation.resulting.?, wait_intent.action.create.schema, role, Revoke.prepare, Revoke.publish, Revoke.transfer);
    const disclosures = [_]c.DirectTableProtocol.Action{
        .{ .stream = retained_page },
        .{ .log_lookup = .{ .namespace = 1, .name = "registered_stream" } },
        .{ .log_list = .{ .namespace = 1, .after = null } },
        .{ .log_operation = .{ .binding = binding, .command = .inspect, .steps = 1 } },
    };
    for (disclosures) |action| {
        service.before_reply = .{ .context = &native_id, .run = Revoke.run };
        try t.expectError(error.Forbidden, dispatch(&service, action));
        service.before_reply = null;
        const filtered = try dispatch(&service, .{ .log_list = .{ .namespace = 1, .after = null } });
        defer filtered.deinit();
        for (filtered.value.result.log_list.entries) |entry| if (entry) |visible| {
            try t.expect(visible.properties.authorization != native_id);
        };
        _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(native_id), .owner = role } });
    }
}

fn streamPayloadDispatch(service: *@import("LocalTableService.zig"), declaration: c.DirectLog.Definition, schema: c.fuze.TableSchema.Schema) !c.DirectStream.Request {
    const q = p.StreamQueue;
    const Clock = struct {
        fn read(_: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = 100, .error_ms = 5 };
        }
    };
    const previous_clock = service.engine.clock;
    defer service.engine.clock = previous_clock;
    service.engine.clock = .{ .context = service, .read = Clock.read };
    const target: q.Partition = .{ .definition = g.current_definition, .interpretation = declaration.stored.declaration.interpretation, .partition = 0 };
    const identity: p.DataLifecycle.Operation = .{ .scope = service.configuration.scope, .principal = 101, .operation = 301 };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    var buffer: [8192]u8 = undefined;
    const payload = try c.storage.LogBatch.encode(schema, identity, .stream, &.{ .{ .cells = &cells }, .{ .cells = &cells } }, &buffer);
    const append: c.DirectStreamMutation.Request = .{ .append = .{ .target = target, .operation = identity, .kind = .stream, .producer = null, .rows = 2, .payload = c.storage.LogBatch.content(payload) } };
    const connection: c.DirectTableProtocol.Connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    const saved = try c.DirectStreamClient.save(t.allocator, connection, .{ .work = append, .payload = payload });
    defer t.allocator.free(saved);
    const original = try c.DirectStreamClient.load(t.allocator, saved);
    defer original.deinit();
    try dispatchWithoutOutput(service, .{ .stream = .{ .mutate = original.value.work } });
    service.engine.clock = null; // Original acceptance survives clock loss.
    const accepted = try dispatch(service, .{ .stream = .{ .operation = append } });
    defer accepted.deinit();
    try t.expectEqual(@as(u64, 2), accepted.value.result.stream.operation.?.append.next);
    try t.expectEqual(@as(?u64, 105), accepted.value.result.stream.operation.?.append.observed_ms);
    const repeated = try dispatch(service, .{ .stream = .{ .mutate = original.value.work } });
    defer repeated.deinit();
    try t.expectEqualDeep(accepted.value.result.stream, repeated.value.result.stream);

    const read: p.StreamRead.Request = .{ .target = target, .operation = .{ .scope = identity.scope, .principal = identity.principal, .operation = 302 }, .group = null, .from = 0, .until = null, .timestamp = null };
    try dispatchWithoutOutput(service, .{ .stream = .{ .mutate = .{ .work = .{ .consume = read }, .payload = null } } });
    const pinned = try dispatch(service, .{ .stream = .{ .operation = .{ .consume = read } } });
    defer pinned.deinit();
    const cursor = try dispatch(service, .{ .stream = .{ .cursor = .{ .target = target, .read = pinned.value.result.stream.operation.?.consume.handle() } } });
    defer cursor.deinit();
    const page_request: c.DirectStream.Request = .{ .page = .{ .cursor = cursor.value.result.stream.cursor, .limits = .{ .rows = 1, .encoded_bytes = 8192, .scanned_rows = 2 } } };

    // The real shared caller crosses the typed endpoint and destroys its wire
    // response before these decoded output rows are inspected.
    const Endpoint = struct {
        fn run(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) !void {
            const current: *@import("LocalTableService.zig") = @ptrCast(@alignCast(raw));
            try t.expectEqualStrings("/table/v1", invocation.path);
            var scratch: std.heap.ArenaAllocator = .init(t.allocator);
            defer scratch.deinit();
            try invocation.respond(try current.executeResult(.typed, &scratch, invocation.allocator, try invocation.request(c.DirectTableProtocol.Request)));
        }
    };
    var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = service, .invoke = Endpoint.run };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = try key(29), .credential_epoch = (try service.engine.principal(101)).credential_epoch };
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const first = (try c.DirectStreamClient.apply(&output, caller, .{ .page = page_request.page })).page;
    try t.expectEqual(@as(usize, 1), first.rows.len);
    try t.expect(!first.cursor.coverage.complete);
    const second = (try c.DirectStreamClient.apply(&output, caller, .{ .page = .{ .cursor = first.cursor, .limits = page_request.page.limits } })).page;
    try t.expect(second.cursor.coverage.complete);
    try t.expectEqual(@as(u64, 2), second.cursor.coverage.rows);
    const terminal = (try c.DirectStreamClient.apply(&output, caller, .{ .page = .{ .cursor = second.cursor, .limits = page_request.page.limits } })).page;
    try t.expect(terminal.cursor.coverage.complete);
    try t.expectEqual(@as(usize, 0), terminal.rows.len);
    try t.expectEqual(@as(i64, 42), first.rows[0].value.cells[0].value.atom.signed);
    try t.expectEqual(@as(u64, 0), first.rows[0].offset);
    try t.expectEqual(@as(u64, 1), second.rows[0].offset);

    const cut = (try c.DirectStreamClient.apply(&output, caller, .{ .observe = target })).cut;
    const group: q.Group = .{ .id = 1, .generation = 1, .principal = 101 };
    const assignment: c.DirectStreamMutation.Request = .{ .assign = .{ .operation = .{ .scope = identity.scope, .principal = 101, .operation = 303 }, .cut = cut, .expected = null, .group = group, .next = 0 } };
    _ = try c.DirectStreamClient.apply(&output, caller, .{ .mutate = .{ .work = assignment } });
    var grouped = read;
    grouped.operation.operation = 304;
    grouped.group = group;
    const group_read = (try c.DirectStreamClient.apply(&output, caller, .{ .mutate = .{ .work = .{ .consume = grouped } } })).operation.?.consume;
    const group_cursor = (try c.DirectStreamClient.apply(&output, caller, .{ .cursor = .{ .target = target, .read = group_read.handle() } })).cursor;
    const consumed = (try c.DirectStreamClient.apply(&output, caller, .{ .page = .{ .cursor = group_cursor, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } })).page;
    const progress = try c.protocol.StreamRead.Progress.between(group_cursor, consumed.cursor);
    try t.expect(progress == .exhausted);
    const commit: c.DirectStreamMutation.Request = .{ .offset = .{
        .commit = .{ .operation = .{ .scope = identity.scope, .principal = 101, .operation = 305 }, .group = group, .coverage = try progress.coverage(), .expected_next = 0, .next = 2 },
        .progress = progress,
    } };
    try dispatchWithoutOutput(service, .{ .stream = .{ .mutate = .{ .work = commit, .payload = null } } });
    _ = (try c.DirectStreamClient.apply(&output, caller, .{ .operation = commit })).operation.?.offset;
    try t.expectEqual(@as(u64, 2), (try c.DirectStreamClient.apply(&output, caller, .{ .group = .{ .target = target, .id = 1 } })).group.?.next);
    const release: c.DirectStreamMutation.Request = .{ .release = .{ .operation = .{ .scope = identity.scope, .principal = 101, .operation = 306 }, .target = target, .read = group_read.handle() } };
    try dispatchWithoutOutput(service, .{ .stream = .{ .mutate = .{ .work = release, .payload = null } } });
    _ = (try c.DirectStreamClient.apply(&output, caller, .{ .operation = release })).operation.?.release;
    try t.expectError(error.StreamReadReleased, c.DirectStreamClient.apply(&output, caller, .{ .page = .{ .cursor = group_cursor, .limits = page_request.page.limits } }));
    return page_request;
}

fn branchInsert(service: *@import("LocalTableService.zig"), operation: u64, sql: []const u8) !void {
    try insertTableRows(service, "branch_source", operation, sql);
}
fn insertTableRows(service: *@import("LocalTableService.zig"), name: []const u8, operation: u64, sql: []const u8) !void {
    const metadata = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = name } });
    defer metadata.deinit();
    const definition = metadata.value.result.lookup.?;
    const bytes = try definition.schema.decode(t.allocator, c.fuze.TableSchema.max_bytes);
    defer t.allocator.free(bytes);
    var schema = try c.fuze.TableSchema.decode(t.allocator, bytes);
    defer schema.deinit();
    var plan = try c.fuze.TableDml.compile(t.allocator, sql, name, schema.schema, null);
    defer plan.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    var intent = try c.DirectTableIntent.fromDml(t.allocator, connection, definition, operation, plan.plan, .point);
    defer intent.deinit();
    const admitted = try dispatch(service, .{ .admit_rows = intent.parsed.value.work.rows });
    admitted.deinit();
    const done = try dispatch(service, .{ .operation = .{ .binding = intent.binding(), .command = .execute, .steps = 8 } });
    defer done.deinit();
    try t.expect(done.value.result.rows == .committed);
}

fn branchDispatch(service: *@import("LocalTableService.zig"), owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    const scope = service.configuration.scope;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 100000, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init("branch_source"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 100000 }, .target = .{ .scope = scope, .branch = 1, .object = 100000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) };
    var encoded: [65536]u8 = undefined;
    const binary = try w.Binary.encode(t.allocator, try schema.encode(&encoded));
    defer t.allocator.free(binary.base64);
    const admitted = try dispatch(service, .{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = "branch_source", .action = .{ .create = .{ .owner = owner_role, .schema = binary } } } });
    admitted.deinit();
    const created = try dispatch(service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 4 } });
    created.deinit();
    try branchInsert(service, 100001, "INSERT INTO branch_source VALUES (10), (20), (30)");
    const metadata = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "branch_source" } });
    defer metadata.deinit();
    const definition = metadata.value.result.lookup.?;
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    const request: @FieldType(c.DirectBranch.Request, "create") = .{
        .key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(90), .token = @splat(91) },
        .intent = .{ .connection = connection, .namespace = 1, .operation = 100002, .name = try .init("trial"), .source = .{ .interpretation = definition.interpretation.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = definition.position }, .mode = .full_data, .parent = null },
    };
    const published = try dispatch(service, .{ .branch = .{ .create = request } });
    defer published.deinit();
    const head = published.value.result.branch.status.?.state.head.?;
    var empty_request = request;
    empty_request.key.token = @splat(92);
    empty_request.intent.operation += 1;
    empty_request.intent.name = try .init("empty_trial");
    empty_request.intent.mode = .schema_only;
    empty_request.intent.parent = head;
    const empty = try dispatch(service, .{ .branch = .{ .create = empty_request } });
    defer empty.deinit();
    const empty_head = empty.value.result.branch.status.?.state.head.?;
    try branchInsert(service, 100004, "INSERT INTO branch_source VALUES (99)");
    var child_request = request;
    child_request.key.token = @splat(93);
    child_request.intent.operation = 100005;
    child_request.intent.name = try .init("child_trial");
    child_request.intent.parent = head;
    const child = try dispatch(service, .{ .branch = .{ .create = child_request } });
    defer child.deinit();
    const child_head = child.value.result.branch.status.?.state.head.?;
    const advanced = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "branch_source" } });
    defer advanced.deinit();
    const flushed = try dispatch(service, .{ .flush = .{ .object = binding.target, .through = advanced.value.result.lookup.?.position } });
    flushed.deinit();
    // Real physical collection must retain the accepted branch directory and
    // unflushed snapshot while reclaiming an independently witnessed orphan.
    var control: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
    var catalog = try D.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    try collectDirect(service.engine, &catalog);
    const repeated = try dispatch(service, .{ .branch = .{ .create = request } });
    defer repeated.deinit();
    try t.expectEqualDeep(published.value.result, repeated.value.result);
    const lookup = try dispatch(service, .{ .branch = .{ .lookup = .{ .namespace = 1, .name = request.intent.name } } });
    defer lookup.deinit();
    try t.expectEqualDeep(published.value.result, lookup.value.result);
    // The public caller also crosses the real resident host, exercising its
    // exclusive branch coordination and cached Table refresh. Request scratch
    // is gone before the caller validates or consumes any response bytes.
    const Host = @import("LocalTableHost.zig");
    const Endpoint = struct {
        host: *Host,
        service: *@import("LocalTableService.zig"),
        fn run(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try t.expectEqualStrings("/table/v1", invocation.path);
            var scratch: std.heap.ArenaAllocator = .init(t.allocator);
            defer scratch.deinit();
            const incoming = try invocation.request(w.Request);
            try invocation.respond(try self.host.executeTyped(t.io, self.service.engine, &scratch, invocation.allocator, incoming, incoming.transport().control != null, invocation.deadline));
        }
    };
    var host: Host = .{ .configuration = service.configuration, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState() };
    defer host.deinit();
    var endpoint: Endpoint = .{ .host = &host, .service = service };
    var transport = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer transport.deinit();
    transport.local = .{ .context = &endpoint, .invoke = Endpoint.run };
    const caller: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &transport, .service = &transport, .connection = connection, .key = try key(29), .credential_epoch = (try service.engine.principal(101)).credential_epoch };
    const original = try c.DirectBranch.call(caller, .{ .create = request });
    defer original.deinit();
    try t.expectEqualDeep(published.value.result, original.value.result);
    const source = try c.DirectBranch.call(caller, .{ .source = head });
    defer source.deinit();
    try t.expectEqual(3, source.value.result.branch.source.rows);
    var cursor: ?c.storage.TablePartition.SnapshotCursor = null;
    var count: usize = 0;
    while (true) {
        const response = try c.DirectBranch.call(caller, .{ .scan = .{ .head = head, .after = cursor, .limits = .{ .rows = 1 } } });
        defer response.deinit();
        const page = response.value.result.branch.page;
        try t.expectEqual(3, page.total_rows);
        for (page.rows) |row| {
            const bytes = try row.decode(t.allocator, c.fuze.TableRow.max_bytes);
            defer t.allocator.free(bytes);
            var decoded = try c.fuze.TableRow.decode(t.allocator, schema, bytes);
            defer decoded.deinit();
            count += 1;
            try t.expectEqual(@as(i64, @intCast(count * 10)), decoded.row().cells[0].value.atom.signed);
        }
        cursor = page.next orelse break;
    }
    try t.expectEqual(3, count);
    const Revoke = struct {
        fn run(raw: *anyopaque, engine: *Engine) !void {
            const id: *u64 = @ptrCast(@alignCast(raw));
            _ = try change(engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id.*), .owner = 0 } });
        }
    };
    var revoked = definition.authorization;
    // Current policy is checked after buffering data, empty results and schema.
    for ([_]c.DirectBranch.Request{
        .{ .scan = .{ .head = head, .after = null, .limits = .{} } },
        .{ .scan = .{ .head = empty_head, .after = null, .limits = .{} } },
        .{ .scan = .{ .head = child_head, .after = null, .limits = .{} } },
        .{ .source = head },
        .{ .list = .{ .namespace = 1, .after = null } },
    }) |read| {
        service.before_reply = .{ .context = &revoked, .run = Revoke.run };
        defer service.before_reply = null;
        try t.expectError(error.Forbidden, dispatch(service, .{ .branch = read }));
        service.before_reply = null;
        _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(revoked), .owner = owner_role } });
    }
    const empty_rows = try dispatch(service, .{ .branch = .{ .scan = .{ .head = empty_head, .after = null, .limits = .{} } } });
    defer empty_rows.deinit();
    try t.expectEqual(0, empty_rows.value.result.branch.page.total_rows);
    try t.expect(empty_rows.value.result.branch.page.next == null);
    const listing = try c.DirectBranch.call(caller, .{ .list = .{ .namespace = 1, .after = null } });
    defer listing.deinit();
    try t.expectEqualDeep(head, listing.value.result.branch.listing.entries[0].?.head);
    try t.expectEqualDeep(empty_head, listing.value.result.branch.listing.entries[1].?.head);
    try t.expectEqualDeep(child_head, listing.value.result.branch.listing.entries[2].?.head);
    try t.expect(listing.value.result.branch.listing.next == null);
    const retire: c.DirectBranch.Request = .{ .retire = .{ .key = request.key, .expected = head } };
    const retiring = try dispatch(service, .{ .branch = retire });
    defer retiring.deinit();
    try t.expectEqual(c.DirectBranch.Phase.retiring, retiring.value.result.branch.status.?.state.phase);
    try t.expectError(error.BranchRetired, c.DirectBranch.call(caller, .{ .source = head }));
    const retired = try c.DirectBranch.call(caller, retire);
    defer retired.deinit();
    try t.expectEqual(c.DirectBranch.Phase.retired, retired.value.result.branch.status.?.state.phase);
    try t.expectEqualDeep(published.value.result.branch.status.?.receipt, retired.value.result.branch.status.?.receipt);
    try t.expectEqualDeep(head, retired.value.result.branch.status.?.state.head.?);
    // First collection can delete released data; the next must traverse the
    // retained publication evidence without reopening that released snapshot.
    try catalog.recover();
    try collectDirect(service.engine, &catalog);
    try collectDirect(service.engine, &catalog);
    const after_collection = try c.DirectBranch.call(caller, .{ .create = request });
    defer after_collection.deinit();
    try t.expectEqualDeep(retired.value.result, after_collection.value.result);
    const still_live = try c.DirectBranch.call(caller, .{ .source = empty_head });
    defer still_live.deinit();
    try t.expectEqual(0, still_live.value.result.branch.source.rows);
    const child_source = try c.DirectBranch.call(caller, .{ .source = child_head });
    defer child_source.deinit();
    try t.expectEqual(3, child_source.value.result.branch.source.rows);
    const child_rows = try c.DirectBranch.call(caller, .{ .scan = .{ .head = child_head, .after = null, .limits = .{} } });
    defer child_rows.deinit();
    try t.expectEqual(3, child_rows.value.result.branch.page.rows.len);
    try t.expect(child_rows.value.result.branch.page.next == null);
    const child_retry = try c.DirectBranch.call(caller, .{ .create = child_request });
    defer child_retry.deinit();
    try t.expectEqualDeep(child.value.result, child_retry.value.result);
    const remaining = try c.DirectBranch.call(caller, .{ .list = .{ .namespace = 1, .after = null } });
    defer remaining.deinit();
    try t.expectEqualDeep(empty_head, remaining.value.result.branch.listing.entries[0].?.head);
    try t.expectEqualDeep(child_head, remaining.value.result.branch.listing.entries[1].?.head);
    try t.expect(remaining.value.result.branch.listing.entries[2] == null);
}

test "signed branch reads survive collection and fence buffered disclosure" {
    typed_dispatch = false;
    try dataSchedule(branchDispatch);
}
test "typed branch reads survive collection and fence buffered disclosure" {
    typed_dispatch = true;
    defer typed_dispatch = false;
    try dataSchedule(branchDispatch);
}

const HistoricalCollection = struct {
    const Service = @import("LocalTableService.zig");
    const H = c.DirectHistory;
    const P = c.storage.TablePartition;
    const object_id = 110000;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = object_id, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };

    fn step(service: *Service, request: H.Request) !H.Status {
        const response = try dispatch(service, .{ .historical_catalog = request });
        defer response.deinit();
        return response.value.result.historical_catalog.status.?;
    }
    fn lost(service: *Service, request: H.Request, original: c.DirectClientToken.Key) !H.Status {
        const Loss = struct {
            fn run(raw: *anyopaque, _: *Engine) !void {
                const count: *usize = @ptrCast(@alignCast(raw));
                count.* += 1;
                return error.FixtureHistoryReplyLost;
            }
        };
        var count: usize = 0;
        service.before_reply = .{ .context = &count, .run = Loss.run };
        defer service.before_reply = null;
        try t.expectError(error.FixtureHistoryReplyLost, dispatch(service, .{ .historical_catalog = request }));
        try t.expectEqual(@as(usize, 1), count);
        service.before_reply = null;
        return step(service, .{ .inspect = original });
    }
    fn finishHistory(service: *Service, original: c.DirectClientToken.Key, phase: H.Phase) !H.Status {
        var status = try step(service, .{ .inspect = original });
        for (0..16) |_| {
            if (status.state.phase == phase) return status;
            status = try step(service, .{ .advance = original });
        }
        return error.FixtureBudget;
    }
    fn collectAndReopen(service: *Service) !void {
        {
            var control: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
            var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
            var catalog = try D.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), service.options);
            defer catalog.deinit();
            try catalog.recover();
            // Uses the real allocation inventory, epoch/time fences and sweep;
            // its orphan witness must disappear on every completed pass.
            try collectDirect(service.engine, &catalog);
        }
        // Drop the native page cache, all WAL owners and object-store handles.
        // Reopen only this fixture's original disk directory, with one page.
        const fixture: *NativeDataFixture = @fieldParentPtr("engine", service.engine);
        try fixture.reopen();
    }
    fn pinState(service: *Service, identity: p.DataLifecycle.Operation) !c.DirectTableProtocol.PinState {
        const response = try dispatch(service, .{ .pin_status = .{ .object = .{ .scope = service.configuration.scope, .branch = 1, .object = object_id }, .owner = identity } });
        defer response.deinit();
        return response.value.result.pin_state;
    }
    fn expectRows(service: *Service, snapshot: p.DataLifecycle.Snapshot) !void {
        var after: ?P.SnapshotCursor = null;
        var rows: usize = 0;
        const expected = [_]i64{ 10, 20, 30 };
        for (0..4) |_| {
            const response = try dispatch(service, .{ .historical_catalog = .{ .scan = .{ .snapshot = snapshot, .object = object_id, .after = after, .limits = .{ .rows = 1 } } } });
            defer response.deinit();
            const page = response.value.result.historical_catalog.page;
            try t.expectEqualDeep(snapshot, page.snapshot);
            try t.expectEqual(@as(u64, 3), page.total_rows);
            try t.expectEqual(@as(usize, 1), page.rows.len);
            const bytes = try page.rows[0].decode(t.allocator, c.fuze.TableRow.max_bytes);
            defer t.allocator.free(bytes);
            var decoded = try c.fuze.TableRow.decode(t.allocator, schema, bytes);
            defer decoded.deinit();
            try t.expect(rows < expected.len);
            try t.expectEqual(expected[rows], decoded.row().cells[0].value.atom.signed);
            rows += 1;
            after = page.next orelse break;
        } else return error.FixtureBudget;
        try t.expectEqual(expected.len, rows);
    }
    fn run(service: *Service, owner_role: u64) !void {
        const w = c.DirectTableProtocol;
        const scope = service.configuration.scope;
        const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
        const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init("history_source"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
        const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = object_id }, .target = .{ .scope = scope, .branch = 1, .object = object_id }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) };
        var encoded: [65536]u8 = undefined;
        const binary = try w.Binary.encode(t.allocator, try schema.encode(&encoded));
        defer t.allocator.free(binary.base64);
        try dispatchWithoutOutput(service, .{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = "history_source", .action = .{ .create = .{ .owner = owner_role, .schema = binary } } } });
        try dispatchWithoutOutput(service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 4 } });
        try insertTableRows(service, "history_source", 110001, "INSERT INTO history_source VALUES (10), (20), (30)");
        const metadata = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "history_source" } });
        defer metadata.deinit();
        const private_owner: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 101, .operation = 110002 };
        const pinned = try dispatch(service, .{ .pin = .{ .object = binding.target, .owner = private_owner, .expected = metadata.value.result.lookup.?.position } });
        defer pinned.deinit();
        const private_pin: w.Snapshot = .{ .object = binding.target, .handle = pinned.value.result.pin };

        var requests: [2]@FieldType(H.Request, "acquire") = undefined;
        var pending: [2]H.Status = undefined;
        var pins: [2]P.SnapshotHandle = undefined;
        for (&requests, &pending, &pins, 0..) |*request, *status, *pin, index| {
            const identity: p.DataLifecycle.Operation = .{ .scope = scope, .principal = 101, .operation = 110010 + index };
            const selection = try dispatch(service, .{ .historical_catalog = .{ .select = .{ .selection = .{ .owner = identity, .branch = 1, .directory = null }, .namespace = 1, .name = try .init("history_source") } } });
            defer selection.deinit();
            request.* = .{ .key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(90), .token = @splat(@as(u8, @intCast(91 + index))) }, .intent = .{ .connection = connection, .namespace = 1, .operation = identity.operation, .selection = selection.value.result.historical_catalog.selection.directory.?, .common = null } };
            const admitted = try lost(service, .{ .acquire = request.* }, request.key);
            try t.expect(admitted.state.inflight != null and admitted.state.snapshot == null);
            status.* = try lost(service, .{ .advance = request.key }, request.key);
            try t.expectEqual(H.Phase.acquiring, status.state.phase);
            try t.expectEqual(@as(u64, 1), status.state.retained.?.count);
            try t.expect(status.state.snapshot == null);
            pin.* = (try pinState(service, identity)).handle.?;
            try t.expectError(error.HistoricalRetentionOwned, dispatch(service, .{ .release = .{ .object = binding.target, .handle = pin.* } }));
        }
        try insertTableRows(service, "history_source", 110020, "INSERT INTO history_source VALUES (99)");
        const latest = try dispatch(service, .{ .lookup = .{ .namespace = 1, .name = "history_source" } });
        defer latest.deinit();
        const target: D.FlushTarget = .{ .object = binding.target, .through = latest.value.result.lookup.?.position };
        for (0..8) |_| {
            const flushed = try dispatch(service, .{ .flush = target });
            defer flushed.deinit();
            if (flushed.value.result.flush.complete) break;
        } else return error.FixtureBudget;
        try collectAndReopen(service);
        for (requests, pending, pins) |request, expected, pin| {
            try t.expectEqualDeep(expected, try step(service, .{ .inspect = request.key }));
            const retained = try pinState(service, request.intent.identity());
            try t.expect(!retained.released);
            try t.expectEqualDeep(pin, retained.handle.?);
        }

        const abandoning = try lost(service, .{ .abandon = requests[1].key }, requests[1].key);
        try t.expectEqual(H.Phase.abandoning, abandoning.state.phase);
        const published = try finishHistory(service, requests[0].key, .published);
        const snapshot = published.state.snapshot.?;
        try expectRows(service, snapshot);

        const releasing = try lost(service, .{ .release = requests[0].key }, requests[0].key);
        try t.expectEqual(H.Phase.releasing, releasing.state.phase);
        try t.expectEqualDeep(snapshot, releasing.state.snapshot.?);
        try t.expectError(error.HistoricalSnapshotReleased, dispatch(service, .{ .historical_catalog = .{ .source = .{ .snapshot = snapshot, .object = object_id } } }));
        // Both closure owners are paused before releasing their pins. One
        // sweep checks both obligations without repeating the same disk work.
        try collectAndReopen(service);
        try t.expectEqualDeep(abandoning, try step(service, .{ .inspect = requests[1].key }));
        try t.expectEqualDeep(releasing, try step(service, .{ .inspect = requests[0].key }));
        const cancelled = try finishHistory(service, requests[1].key, .cancelled);
        try t.expect(cancelled.state.snapshot == null);
        try t.expect((try pinState(service, requests[1].intent.identity())).released);
        try t.expect(!(try pinState(service, requests[0].intent.identity())).released);
        try t.expect(!(try pinState(service, private_owner)).released);
        _ = try lost(service, .{ .advance = requests[0].key }, requests[0].key);
        const released = try finishHistory(service, requests[0].key, .released);
        try t.expectEqualDeep(snapshot, released.state.snapshot.?);
        try t.expectEqualDeep(published.receipt, released.receipt);
        try collectAndReopen(service);
        // Collection must traverse retained terminal evidence without
        // reopening a released pin, while the independent private pin survives.
        try t.expectEqualDeep(released, try step(service, .{ .acquire = requests[0] }));
        try t.expectEqualDeep(cancelled, try step(service, .{ .acquire = requests[1] }));
        for (requests, pins) |request, pin| {
            const closed = try pinState(service, request.intent.identity());
            try t.expect(closed.released);
            try t.expectEqualDeep(pin, closed.handle.?);
        }
        const independent = try pinState(service, private_owner);
        try t.expect(!independent.released);
        try t.expectEqualDeep(private_pin.handle, independent.handle.?);
        const old = try dispatch(service, .{ .snapshot = private_pin });
        defer old.deinit();
        try t.expectEqual(@as(u64, 3), old.value.result.snapshot.row_count);
        try dispatchWithoutOutput(service, .{ .release = private_pin });
        std.debug.print("Historical disk collection: two original acquisitions, seven lost replies, three physical collections/reopens, exact three-row cut, abandonment and release, independent pin ownership passed ({s}).\n", .{if (typed_dispatch) "typed" else "signed JSON"});
    }
};

test "signed historical acquisition and release survive physical collection and disk reopen" {
    typed_dispatch = false;
    try dataSchedule(HistoricalCollection.run);
}
test "typed historical acquisition and release survive physical collection and disk reopen" {
    typed_dispatch = true;
    defer typed_dispatch = false;
    try dataSchedule(HistoricalCollection.run);
}

test "automatic Queue maintenance requires its database signer and resumes the original paired decision" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
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
    const stream_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.stream) } })).?;
    const queue_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.queue) } })).?;
    const kv_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.kv) } })).?;
    const connection_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.connection) } })).?;
    const source_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.source) } })).?;
    const sink_domain = (try change(&engine, .{ .register_domain = .{ .lifetime_resource = resource, .registrar = 0, .actions = c.TableAuthority.actions(.sink) } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .stream_domain = stream_domain, .queue_domain = queue_domain, .kv_domain = kv_domain, .connection_domain = connection_domain, .source_domain = source_domain, .sink_domain = sink_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };

    var service: @import("LocalTableService.zig") = .{ .engine = &engine, .configuration = config, .registrar = .{ .principal = 0, .key = try key(17) }, .options = .{ .resident_pages = 1 } };
    (try dispatch(&service, .initialize)).deinit();
    const Fixture = struct {
        const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
        fn schema(object: u64) c.fuze.TableSchema.Schema {
            return .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} };
        }
        fn create(current: *@import("LocalTableService.zig"), owner_role: u64, object: u64, name: []const u8, destination: ?p.DataLifecycle.Definition) !c.DirectLog.Definition {
            var arena = std.heap.ArenaAllocator.init(t.allocator);
            defer arena.deinit();
            const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init(name), .action = .{ .create = .{
                .owner = owner_role,
                .schema = schema(object),
                .configuration = .{ .partitioning = .{ .count = if (destination == null) 3 else 2, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 1, .backoff = .{ .initial_ms = 0, .maximum_ms = 0, .multiplier = 1 }, .dead_letter = destination } } },
                .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 16 },
            } } };
            const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = current.configuration.scope, .principal = 101, .operation = object }, .target = .{ .scope = current.configuration.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) };
            (try dispatch(current, .{ .log_admit = try c.DirectLogProtocol.Ddl.encode(arena.allocator(), .{ .binding = binding, .intent = intent }) })).deinit();
            const response = try dispatch(current, .{ .log_operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
            defer response.deinit();
            try t.expectEqual(.complete, response.value.result.log_operation.operation.phase);
            return response.value.result.log_operation.operation.resulting.?;
        }
        fn signed(current: *Engine) !g.SignedRequest {
            return g.sign(.{ .realm = 42, .principal = 0, .sequence = (try current.principal(0)).sequence + 1, .command = .checkpoint }, try key(17));
        }
        fn operation(configuration: D.Configuration, id: u64) p.DataLifecycle.Operation {
            return .{ .scope = configuration.scope, .principal = 101, .operation = id };
        }
    };
    const destination = try Fixture.create(&service, role, 300, "dead_letters", null);
    const source = try Fixture.create(&service, role, 301, "inbox", destination.stored.declaration.interpretation);
    const Clock = struct {
        now: u64 = 1000,
        fn read(raw: *anyopaque) !@import("transit_core").Time.Sample {
            return .{ .unix_ms = @as(*@This(), @ptrCast(@alignCast(raw))).now, .error_ms = 5 };
        }
    };
    var clock: Clock = .{};
    engine.clock = .{ .context = &clock, .read = Clock.read };
    const target: p.StreamQueue.Partition = .{ .definition = g.current_definition, .interpretation = source.stored.declaration.interpretation, .partition = 1 };
    var buffer: [8192]u8 = undefined;
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 77 } } }};
    const payload = try c.storage.LogBatch.encode(Fixture.schema(301), Fixture.operation(config, 90000), .queue, &.{ .{ .cells = &cells, .visible_ms = 75 }, .{ .cells = &cells, .visible_ms = 75 } }, &buffer);
    const binary = try c.DirectTableProtocol.Binary.encode(t.allocator, payload);
    defer t.allocator.free(binary.base64);
    (try dispatch(&service, .{ .queue = .{ .mutate = .{ .work = .{ .enqueue = .{ .target = target, .operation = Fixture.operation(config, 90000), .kind = .queue, .producer = null, .rows = 2, .payload = c.storage.LogBatch.content(payload) } }, .payload = binary } } })).deinit();
    const claimed = try dispatch(&service, .{ .queue = .{ .mutate = .{ .work = .{ .claim = .{ .target = target, .operation = Fixture.operation(config, 90001), .maximum = 1, .lease_ms = 100, .predicate = null } }, .payload = null } } });
    defer claimed.deinit();
    const claim = claimed.value.result.queue.operation.?.claim;
    const input = try dispatch(&service, .{ .queue = .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } } });
    defer input.deinit();
    (try dispatch(&service, .{ .queue = .{ .mutate = .{ .work = .{ .settle = .{ .operation = Fixture.operation(config, 90002), .lease = input.value.result.queue.page.rows[0].lease.original, .action = .{ .nack = .{ .visible_ms = 0 } } } }, .payload = null } } })).deinit();
    clock.now = 1020;
    var control: backend.DataStore = .{ .backend = &owner, .control = true };
    var data: backend.DataStore = .{ .backend = &owner };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), service.options);
    defer catalog.deinit();
    try catalog.recover();
    const Host = @import("LocalTableHost.zig");
    const Transfers = @import("LocalQueueTransfers.zig");
    var host: Host = .{ .configuration = config, .registrar = service.registrar, .options = service.options, .recovery = try catalog.recoveryState() };
    defer host.deinit();
    var memory: c.fuze.MemoryBudget = .{ .parent = t.allocator, .limit = 32 * 1024 * 1024 };
    var worker: Transfers = .{};
    defer worker.deinit();
    // A native checkpoint signer alone never starts application DLQ work.
    try t.expect(!try worker.step(memory.allocator(), &host, &engine, try Fixture.signed(&engine)));
    const identity: Transfers.Identity = .{ .principal = 101, .key = try key(29), .role = null, .account = @splat(42), .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 1024 * 1024, .participants = 2, .statements = 1, .savepoints = 1 }, .budget = .{ .bytes = 16 * 1024 } };
    host.queue_transfers = identity;
    var original: ?c.DirectClientToken.Receipt = null;
    for (0..64) |_| {
        _ = try worker.step(memory.allocator(), &host, &engine, try Fixture.signed(&engine));
        try catalog.recover();
        if ((try catalog.store.queueTransferPending(null)).entries[0]) |pending| {
            original = pending.receipt;
            break;
        }
    }
    const receipt = original orelse return error.FixtureBudget;
    // Admission must fit the existing 32 MiB ceiling without retaining a second
    // Queue owner. The unexamined row keeps this finite discovery sweep open.
    try t.expect(worker.workspace == null);
    try t.expectEqual(@as(usize, 0), memory.used);
    try t.expectEqual(@as(u64, 1), worker.cursor.?.next);
    try t.expectEqual(@as(u64, 2), worker.cursor.?.until);
    const plan = try c.DirectQueueTransferPlan.fromReceipt(t.allocator, catalog.data_objects, receipt);
    try t.expectEqual(@as(u32, 1), plan.transfer.destination.target.partition);
    try t.expectEqualDeep(destination.stored.declaration.interpretation, plan.transfer.destination.target.interpretation);
    try t.expectEqual(@as(u64, 1), catalog.store.root.client_token_count);
    // Before acquisition, collection must retain the exact staged payload.
    try collectDirect(&engine, &catalog);
    // Collection advances trusted time through its grace interval. Restore a
    // clock at that new floor, not the pre-collection sample.
    clock.now = @max(clock.now, engine.head.time_floor_ms);
    worker.deinit();
    worker = .{};
    try t.expectEqual(@as(usize, 0), memory.used);
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(destination.properties.authorization), .owner = 0 } });
    try t.expectError(error.Forbidden, worker.step(memory.allocator(), &host, &engine, try Fixture.signed(&engine)));
    try catalog.recover();
    try t.expect((try catalog.store.queueTransferPending(null)).entries[0] != null);
    try t.expectEqual(@as(u64, 1), catalog.store.root.client_token_count);
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(destination.properties.authorization), .owner = role } });
    // Another account may inspect physical metadata, but cannot adopt this
    // original or create a fresh attempt for the already bound source.
    host.queue_transfers.?.account = @splat(43);
    for (0..16) |_| _ = try worker.step(memory.allocator(), &host, &engine, try Fixture.signed(&engine));
    try catalog.recover();
    try t.expectEqual(@as(u64, 1), catalog.store.root.client_token_count);
    try t.expect((try catalog.store.queueTransferPending(null)).entries[0] != null);
    host.queue_transfers = identity;
    var second: Transfers = .{};
    defer second.deinit();
    for (0..256) |i| {
        const selected = if (i % 2 == 0) &worker else &second;
        _ = try selected.step(memory.allocator(), &host, &engine, try Fixture.signed(&engine));
        try catalog.recover();
        if ((try catalog.store.queueTransferPending(null)).entries[0] == null) break;
    }
    try t.expect((try catalog.store.queueTransferPending(null)).entries[0] == null);
    const terminal = (try catalog.store.queueTransferSource(try plan.sourceKey())).?;
    try t.expectEqualDeep(receipt, terminal.receipt);
    try t.expect(!terminal.pending);
    const completed = try c.DirectTransactionControl.load(t.allocator, catalog.data_objects, terminal);
    try t.expectEqual(.committed, completed.decision.?.outcome);
    try t.expect(completed.cleanup_complete);
    try t.expectEqual(@as(u64, 1), catalog.store.root.client_token_count);
    const after = try dispatch(&service, .{ .queue = .{ .page = .{ .cursor = .{ .receipt = claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 8192 } } } });
    defer after.deinit();
    try t.expectEqual(p.QueueRead.State.archived, after.value.result.queue.page.rows[0].lease.state);
    const delivery = try dispatch(&service, .{ .queue = .{ .mutate = .{ .work = .{ .claim = .{ .target = plan.transfer.destination.target, .operation = Fixture.operation(config, 90003), .maximum = 2, .lease_ms = 100, .predicate = null } }, .payload = null } } });
    defer delivery.deinit();
    try t.expectEqual(@as(u32, 1), delivery.value.result.queue.operation.?.claim.rows);
    const output = try dispatch(&service, .{ .queue = .{ .page = .{ .cursor = .{ .receipt = delivery.value.result.queue.operation.?.claim, .next = 0 }, .limits = .{ .rows = 2, .encoded_bytes = 8192 } } } });
    defer output.deinit();
    try t.expect(output.value.result.queue.page.cursor.complete());
    const output_bytes = try output.value.result.queue.page.rows[0].encoded.decode(t.allocator, c.fuze.TableRow.max_bytes);
    defer t.allocator.free(output_bytes);
    var decoded = try c.fuze.TableRow.decode(t.allocator, Fixture.schema(300), output_bytes);
    defer decoded.deinit();
    try t.expectEqual(@as(i128, 77), decoded.row().cells[0].value.atom.signed);
    try t.expect(memory.peak <= memory.limit);
    worker.deinit();
    worker = .{};
    second.deinit();
    second = .{};
    try t.expectEqual(@as(usize, 0), memory.used);
}

test "transaction owned records survive local collection and closed abort payloads are reclaimed" {
    typed_dispatch = false;
    try dataSchedule(ownedRecordsDispatch);
}

fn ownedRecordsDispatch(service: *@import("LocalTableService.zig"), owner_role: u64) !void {
    const w = c.DirectTableProtocol;
    const scope = service.configuration.scope;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 100000, .revision = 1, .next_column = 2, .columns = &columns };
    const intent: D.Intent = .{ .kind = .table, .namespace = 1, .name = try .init("record_source"), .action = .{ .create = .{ .schema = schema, .owner = owner_role } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 100000 }, .target = .{ .scope = scope, .branch = 1, .object = 100000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var encoded: [65536]u8 = undefined;
    (try dispatch(service, .{ .admit_ddl = .{ .binding = binding, .namespace = 1, .name = "record_source", .action = .{ .create = .{ .owner = owner_role, .schema = try w.Binary.encode(allocator, try schema.encode(&encoded)) } } } })).deinit();
    (try dispatch(service, .{ .operation = .{ .binding = binding, .command = .execute, .steps = 4 } })).deinit();
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    const digest: [32]u8 = @splat(17);
    var policy = try Policy.init(service.engine, service.configuration, try proof(service.engine, digest), digest, null);
    var control: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
    var catalog = try D.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    var requests: [4]c.DirectRecord.Request = undefined;
    var references: [4]c.DirectRecord.Reference = undefined;
    for (&requests, &references, 0..) |*request, *reference, i| {
        const token: c.DirectClientToken.Key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(80), .token = @splat(@as(u8, @intCast(81 + i))) };
        (try dispatch(service, .{ .transaction = .{ .begin = .{ .key = token, .fingerprint = @splat(82), .operation = .{ .scope = scope, .principal = 101, .operation = 110000 + i }, .namespace = 1, .mode = .serializable, .selection = .authorized_catalog_tables, .limits = c.DirectTransaction.default_limits, .deadline = null, .budget = .{} } } })).deinit();
        (try dispatch(service, .{ .transaction = .{ .acquire = token } })).deinit();
        const guarded = try c.DirectRecord.encodeGuarded(allocator, connection, &.{binding.target}, "candidate");
        request.* = .{ .stage_transaction = .{ .transaction = token, .format = c.DirectRecord.guarded_bit | 17, .bytes = try w.Binary.encode(allocator, guarded) } };
        reference.* = try c.DirectRecord.reference(token.scope(), c.DirectTransactionRecord.format, try c.DirectTransactionRecord.encode(allocator, token, request.stage_transaction.format, guarded));
        if (i == 3) {
            // Durable inventory can exist before any physical object creation.
            try catalog.recover();
            catalog.store.lose_reply = true;
            try t.expectError(error.LostAcknowledgement, catalog.directRecord(allocator, request.*, policy.policy()));
            catalog.store.lose_reply = false;
        } else {
            const staged = try dispatch(service, .{ .record = request.* });
            defer staged.deinit();
            try reference.requireSame(staged.value.result.record.reference);
            if (i == 0) continue;
            for (0..8) |_| {
                const status = try dispatch(service, .{ .transaction = .{ .settle = .{ .key = token, .operation = .{ .scope = scope, .principal = 101, .operation = 120000 + i }, .command = if (i == 1) .commit else .abort, .steps = 32 } } });
                defer status.deinit();
                if (status.value.result.transaction.status.cleanup_complete) break;
            } else return error.FixtureBudget;
        }
    }
    try catalog.recover();
    const CreateDuringGrace = struct {
        catalog: *D,
        allocator: std.mem.Allocator,
        policy: D.Policy,
        request: c.DirectRecord.Request,
        reference: c.DirectRecord.Reference,
        called: bool = false,
        fn run(raw: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try self.reference.requireSame((try self.catalog.directRecord(self.allocator, self.request, self.policy)).reference);
            self.called = true;
        }
    };
    var creation: CreateDuringGrace = .{ .catalog = &catalog, .allocator = allocator, .policy = policy.policy(), .request = requests[3], .reference = references[3] };
    // The graph sees a reservation with no bytes. Creation after marking must
    // survive the original cut's sweep through the backend allocation fence.
    try collectDirectBeforeSweep(service.engine, &catalog, .{ .context = &creation, .run = CreateDuringGrace.run });
    try t.expect(creation.called);
    var name: [96]u8 = undefined;
    for (references, 0..) |reference, i| {
        try t.expectEqual(i != 2, try data.objects().head(try c.DirectRecord.key(reference, &name)) != null);
        if (i != 2) (try dispatch(service, .{ .record = .{ .read = reference } })).deinit();
    }
    try t.expectError(error.TransactionRecordClosed, catalog.directRecord(allocator, requests[2], policy.policy()));
    try references[3].requireSame((try catalog.directRecord(allocator, requests[3], policy.policy())).reference);
    try t.expect(try data.objects().head(try c.DirectRecord.key(references[2], &name)) == null);
}

test "owned progress collection protects reservation creation and reclaims superseded records" {
    typed_dispatch = false;
    try dataSchedule(progressRecordsDispatch);
    typed_dispatch = true;
    try dataSchedule(progressRecordsDispatch);
}

fn progressRecordsDispatch(service: *@import("LocalTableService.zig"), _: u64) !void {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    const token: c.DirectClientToken.Key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(94), .token = @splat(1) };
    const staged = try dispatch(service, .{ .record = .{ .stage = .{ .scope = token.scope(), .format = 17, .bytes = try c.DirectTableProtocol.Binary.encode(allocator, "original admission") } } });
    defer staged.deinit();
    const admission = staged.value.result.record.reference;
    const bound = try dispatch(service, .{ .client_token = .{ .bind = .{ .key = token, .fingerprint = @splat(17), .intent = .{ .external = .{ .connection = connection, .namespace = 1, .operation = 130000, .record = admission } } } } });
    defer bound.deinit();
    var request: c.DirectProgressRecord.Advance = .{ .key = token, .expected = bound.value.result.client_token.?.position, .pending = true, .cancel = false, .format = 17, .bytes = try c.DirectTableProtocol.Binary.encode(allocator, "first progress") };
    const first_reply = try dispatch(service, .{ .client_progress = .{ .advance = request } });
    defer first_reply.deinit();
    const first = first_reply.value.result.client_progress.state.?;
    const digest: [32]u8 = @splat(17);
    var policy = try Policy.init(service.engine, service.configuration, try proof(service.engine, digest), digest, null);
    var control: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
    var catalog = try D.init(t.allocator, service.configuration, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    request.expected = first.revision;
    request.bytes = try c.DirectTableProtocol.Binary.encode(allocator, "replacement progress");
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.clientProgress(.{ .advance = request }, policy.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const reserved = (try catalog.clientProgress(.{ .inspect = token }, policy.policy())).state.?;
    const candidate = reserved.staged.?.reference;
    var name: [96]u8 = undefined;
    try t.expect(try data.objects().head(try c.DirectRecord.key(candidate, &name)) == null);
    const CreateDuringGrace = struct {
        catalog: *D,
        policy: D.Policy,
        request: c.DirectProgressRecord.Advance,
        result: ?c.DirectClientToken.Progress = null,
        fn run(raw: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.result = (try self.catalog.clientProgress(.{ .advance = self.request }, self.policy)).state.?;
        }
    };
    var creation: CreateDuringGrace = .{ .catalog = &catalog, .policy = policy.policy(), .request = request };
    try collectDirectBeforeSweep(service.engine, &catalog, .{ .context = &creation, .run = CreateDuringGrace.run });
    try candidate.requireSame(creation.result.?.record.?);
    try t.expect(try data.objects().head(try c.DirectRecord.key(first.record.?, &name)) != null);
    try t.expect(try data.objects().head(try c.DirectRecord.key(candidate, &name)) != null);
    // A later cut releases the superseded payload while preserving replay of
    // every old catalog action, the current payload and original admission.
    try collectDirect(service.engine, &catalog);
    try t.expect(try data.objects().head(try c.DirectRecord.key(first.record.?, &name)) == null);
    try t.expect(try data.objects().head(try c.DirectRecord.key(candidate, &name)) != null);
    (try dispatch(service, .{ .record = .{ .read = candidate } })).deinit();
    (try dispatch(service, .{ .record = .{ .read = admission } })).deinit();
    const recovered = (try catalog.clientProgress(.{ .advance = request }, policy.policy())).state.?;
    try t.expectEqualDeep(creation.result.?, recovered);
    request.expected = recovered.revision;
    request.pending = false;
    request.bytes = try c.DirectTableProtocol.Binary.encode(allocator, "completed progress");
    const terminal = (try catalog.clientProgress(.{ .advance = request }, policy.policy())).state.?;
    try collectDirect(service.engine, &catalog);
    try t.expect(try data.objects().head(try c.DirectRecord.key(candidate, &name)) == null);
    try t.expect(try data.objects().head(try c.DirectRecord.key(terminal.record.?, &name)) != null);
    (try dispatch(service, .{ .record = .{ .read = terminal.record.? } })).deinit();
    try t.expectEqualDeep(terminal, (try catalog.clientProgress(.{ .advance = request }, policy.policy())).state.?);
}

test "owned original staging and explicit closure survive physical collection" {
    typed_dispatch = false;
    try dataSchedule(originalRecordsDispatch);
    typed_dispatch = true;
    try dataSchedule(originalRecordsDispatch);
}
fn originalRecordsDispatch(service: *@import("LocalTableService.zig"), _: u64) !void {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = service.configuration.scope, .branch = 1, .audience = service.configuration.audience, .principal = 101, .role = null };
    var requests: [3]c.DirectOwnedRecord.Stage = undefined;
    for (&requests, 0..) |*request, i| {
        const token: c.DirectClientToken.Key = .{ .definition = g.current_definition, .connection = connection, .account = @splat(96), .token = @splat(@intCast(i + 1)) };
        const payload = try c.DirectTableProtocol.Binary.encode(allocator, "owned original bytes");
        const encoded = try c.DirectOwnedRecord.encode(allocator, token, 17, payload);
        request.* = .{ .binding = .{ .key = token, .fingerprint = @splat(17), .budget = .{ .bytes = 64 * 1024 }, .intent = .{ .external = .{ .connection = connection, .namespace = 1, .operation = 140000 + i, .record = try c.DirectRecord.reference(token.scope(), c.DirectOwnedRecord.format, encoded) } } }, .format = 17, .bytes = payload };
        if (i == 0) continue;
        const reply = try dispatch(service, .{ .client_progress = .{ .stage_original = request.* } });
        defer reply.deinit();
        const state = reply.value.result.client_progress.state.?;
        const control_value: c.DirectOwnedRecord.Control = .{ .key = token, .expected = state.revision };
        (try dispatch(service, .{ .client_progress = if (i == 1) .{ .retain_original = control_value } else .{ .close_original = control_value } })).deinit();
    }
    const digest: [32]u8 = @splat(17);
    var policy = try Policy.init(service.engine, service.configuration, try proof(service.engine, digest), digest, null);
    var control_store: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
    var catalog = try D.init(t.allocator, service.configuration, control_store.log(), control_store.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    catalog.store.lose_reply = true;
    try t.expectError(error.LostAcknowledgement, catalog.clientProgress(.{ .stage_original = requests[0] }, policy.policy()));
    catalog.store.lose_reply = false;
    try catalog.recover();
    const CreateDuringGrace = struct {
        catalog: *D,
        policy: D.Policy,
        request: c.DirectOwnedRecord.Stage,
        result: ?c.DirectClientToken.Progress = null,
        fn run(raw: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.result = (try self.catalog.clientProgress(.{ .stage_original = self.request }, self.policy)).state.?;
        }
    };
    var creation: CreateDuringGrace = .{ .catalog = &catalog, .policy = policy.policy(), .request = requests[0] };
    try collectDirectBeforeSweep(service.engine, &catalog, .{ .context = &creation, .run = CreateDuringGrace.run });
    var path: [96]u8 = undefined;
    for (requests, 0..) |request, i| try t.expect((try data.objects().head(try c.DirectRecord.key(request.binding.intent.external.record, &path)) != null) == (i != 2));
    const closed = (try catalog.clientProgress(.{ .close_original = .{ .key = requests[0].binding.key, .expected = creation.result.?.revision } }, policy.policy())).state.?;
    try collectDirect(service.engine, &catalog);
    try t.expect(try data.objects().head(try c.DirectRecord.key(requests[0].binding.intent.external.record, &path)) == null);
    try t.expect(try data.objects().head(try c.DirectRecord.key(requests[1].binding.intent.external.record, &path)) != null);
    try catalog.recover();
    try t.expectEqualDeep(closed, (try catalog.clientProgress(.{ .stage_original = requests[0] }, policy.policy())).state.?);
    (try dispatch(service, .{ .record = .{ .read = requests[1].binding.intent.external.record } })).deinit();
    const late = try dispatch(service, .{ .client_progress = .{ .stage_original = requests[0] } });
    defer late.deinit();
    try t.expectEqualDeep(closed, late.value.result.client_progress.state.?);
    try t.expect(try data.objects().head(try c.DirectRecord.key(requests[0].binding.intent.external.record, &path)) == null);
}

// Capture mutation is deliberately supplied by this trusted component host;
// readers enter the installed service implementation with native credentials.
test "SOURCE published capture reads cross the native signed service boundary" {
    try dataSchedule(sourceCaptureReadSchedule);
}
fn sourceCaptureReadSchedule(service: *@import("LocalTableService.zig"), owner_role: u64) !void {
    const Capture = c.DirectSourceCapture;
    const config = service.configuration;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var ddl = try c.fuze.LogDdl.compile(t.allocator, "CREATE STREAM captures (capture_id UUID NOT NULL, source_sequence UINT64 NOT NULL, observed_at TIMESTAMPTZ NOT NULL, http_status INTEGER NOT NULL, body_ref BINARY NOT NULL, body_bytes UINT64 NOT NULL, body_sha256 BINARY NOT NULL)", .transit, null);
    defer ddl.deinit();
    const intent: c.DirectLog.Intent = .{ .kind = .stream, .namespace = 1, .name = try .init("captures"), .action = .{ .create = .{
        .owner = owner_role,
        .schema = try ddl.statement.action.create.bind(300),
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const binding: p.DataLifecycle.Binding = .{ .definition = g.current_definition, .identity = .{ .scope = config.scope, .principal = 101, .operation = 300 }, .target = .{ .scope = config.scope, .branch = 1, .object = 300 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(alloc) };
    (try dispatch(service, .{ .log_admit = try c.DirectLogProtocol.Ddl.encode(alloc, .{ .binding = binding, .intent = intent }) })).deinit();
    const created = try dispatch(service, .{ .log_operation = .{ .binding = binding, .command = .execute, .steps = 32 } });
    defer created.deinit();
    const stream = created.value.result.log_operation.operation.resulting.?;
    const Helper = struct {
        fn declaration(current: *@import("LocalTableService.zig"), role: u64, object: u64, name: []const u8, payload: c.SourceDeclaration.Payload) !c.DirectSource.State {
            const value: c.DirectSource.Intent = .{ .kind = std.meta.activeTag(payload), .namespace = 1, .name = try .init(name), .action = .{ .create = .{ .owner = role, .payload = payload } } };
            const request: c.DirectSource.Request = .{ .intent = value, .binding = .{ .definition = g.current_definition, .identity = .{ .scope = current.configuration.scope, .principal = 101, .operation = object }, .target = .{ .scope = current.configuration.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try value.digest(t.allocator) } };
            (try dispatch(current, .{ .source = .{ .declaration = .{ .request = request, .command = .reserve, .steps = 1 } } })).deinit();
            const result = try dispatch(current, .{ .source = .{ .declaration = .{ .request = request, .command = .execute, .steps = 32 } } });
            defer result.deinit();
            return result.value.result.source.observation.operation.resulting.?;
        }
    };
    const connection = try Helper.declaration(service, owner_role, 301, "upstream", .{ .connection = .{ .endpoint = "https://example.com" } });
    const source_payload: c.SourceDeclaration.Payload = .{ .source = .{ .connection = connection.declaration.interpretation, .destination = stream.stored.declaration.interpretation, .executor = 99, .http = .{ .method = .GET, .path = "/feed", .poll_interval_ms = 1000, .request_timeout_ms = 500, .response_max_bytes = 4 * 1024 * 1024 }, .columns = .{ 1, 2, 3, 4, 5, 6, 7 } } };
    const source = try Helper.declaration(service, owner_role, 302, "earthquakes", source_payload);
    const digest: [32]u8 = @splat(91);
    var policy = try Policy.init(service.engine, config, try proof(service.engine, digest), digest, null);
    var control: backend.DataStore = .{ .backend = service.engine.journal.backend, .control = true };
    var data: backend.DataStore = .{ .backend = service.engine.journal.backend };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1 });
    defer catalog.deinit();
    try catalog.recover();
    var body: [65537]u8 = undefined;
    for (&body, 0..) |*byte, i| byte.* = @truncate(i *% 73 +% 19);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&body, &hash, .{});
    const operation: p.DataLifecycle.Operation = .{ .scope = config.scope, .principal = 101, .operation = 90000 };
    const descriptor: Capture.Descriptor = .{
        .key = .{ .definition = g.current_definition, .connection = .{ .scope = config.scope, .branch = 1, .audience = config.audience, .principal = 101, .role = null }, .account = @splat(98), .token = @splat(1) },
        .operation = operation,
        .namespace = 1,
        .evidence = .{ .definition = g.current_definition, .poll = .{ .definition = g.current_definition, .source = source.declaration.interpretation, .operation = operation, .capture_id = @splat(1), .sequence = 1, .control_epoch = 1, .due_ms = 100, .state = .captured }, .connection = connection.declaration.interpretation, .destination = stream.stored.declaration.interpretation, .columns = .{ 1, 2, 3, 4, 5, 6, 7 }, .attempt = .{ .scope = config.scope, .principal = 99, .operation = 92000 }, .exchange = .{ .bytes = 200, .sha256 = @splat(1) }, .terminal = .{ .bytes = 100, .sha256 = @splat(2) }, .verifier = source.declaration.interpretation, .observed_at_ms = 200, .http_status = 200, .body = .{ .bytes = body.len, .sha256 = hash } },
        .budget = .{ .bytes = 32 * 1024 * 1024 },
        .limits = .{ .work_bytes = 128 * 1024 * 1024, .work_pages = 100000 },
    };
    const Host = struct {
        policy: D.Policy,
        expected: p.SourceCapture.Evidence,
        fn verify(raw: *anyopaque, evidence: p.SourceCapture.Evidence) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (!std.meta.eql(self.expected, evidence)) return error.SourceOriginalUnverified;
        }
        fn guard(raw: *anyopaque, allocator: std.mem.Allocator, required: a.Guard, evidence: p.SourceCapture.Evidence) !c.storage.PublicationGuard {
            const self: *@This() = @ptrCast(@alignCast(raw));
            try verify(raw, evidence);
            return self.policy.make_guard(self.policy.context, allocator, required, null);
        }
    };
    var host: Host = .{ .policy = policy.policy(), .expected = descriptor.evidence };
    var admission: Capture.Admission = .{};
    const authority: Capture.Authority = .{ .context = &host, .admission = &admission, .verify_original = Host.verify, .make_guard = Host.guard };
    var observed = try catalog.captureReserve(descriptor, policy.policy(), authority);
    var offset: usize = 0;
    while (offset < body.len) {
        const chunk = body[offset..@min(body.len, offset + Capture.storage.chunk_bytes)];
        observed = try catalog.captureUpload(.{ .control = .{ .key = descriptor.key, .expected = observed.revision }, .chunk = .{ .offset = offset, .content = c.storage.LogBatch.content(chunk) }, .bytes = chunk }, policy.policy(), authority);
        offset += chunk.len;
    }
    var verifier = try Capture.Verifier.init(descriptor.key, &admission);
    defer verifier.deinit();
    while (!verifier.done) observed = try catalog.captureVerify(&verifier, .{ .bytes = Capture.storage.chunk_bytes, .pages = 64 }, policy.policy(), authority);
    var output_key = descriptor.key;
    output_key.token = @splat(2);
    var begin = operation;
    begin.operation += 1;
    var append = operation;
    append.operation += 2;
    var settlement = operation;
    settlement.operation += 3;
    const plan: c.DirectSourcePublication = .{ .definition = g.current_definition, .candidate = descriptor.key, .key = output_key, .reference = .{ .definition = g.current_definition, .candidate = try descriptor.key.digest(), .destination = descriptor.evidence.destination, .manifest = observed.state.manifest.? }, .namespace = 1, .operation = begin, .append = append, .settlement = settlement, .limits = .{ .resident_bytes = 8 * 1024 * 1024, .workspace_bytes = 16 * 1024 * 1024, .participants = 1, .statements = 1, .savepoints = 1 }, .budget = .{ .bytes = 16 * 1024 * 1024 } };
    observed = try catalog.capturePublish(plan, policy.policy(), authority);
    while (observed.state.phase == .publishing) observed = try catalog.captureAdvance(plan.candidate, .commit, 8, policy.policy(), authority);
    try t.expectEqual(0, observed.state.outcome.?.append.?.first);
    // Withhold source/connection permissions and all Stream mutation rights.
    for ([_]u64{ source.declaration.properties.authorization, connection.declaration.properties.authorization, stream.properties.authorization }) |id| {
        _ = try change(service.engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(id), .owner = 0 } });
    }
    _ = try change(service.engine, .{ .grant = .{ .object = c.TableAuthority.reference(stream.properties.authorization), .grantee = owner_role, .privileges = c.LogAuthority.read } });
    try t.expectError(error.Forbidden, dispatch(service, .{ .source = .{ .inspect = source.declaration.interpretation } }));
    var open_operation = operation;
    open_operation.operation = 100000;
    const opened = try dispatch(service, .{ .capture_read = .{ .open = .{ .reference = plan.reference, .operation = open_operation } } });
    defer opened.deinit();
    const original = opened.value.result.capture_read.opened;
    try t.expectEqual(owner_role, original.handle.role.?);
    var cursor = original;
    offset = 0;
    while (true) {
        const response = try dispatch(service, .{ .capture_read = .{ .next = cursor } });
        defer response.deinit();
        const page = response.value.result.capture_read.page;
        const bytes = try page.bytes.decode(t.allocator, Capture.storage.chunk_bytes);
        defer t.allocator.free(bytes);
        try t.expectEqualSlices(u8, body[offset..][0..bytes.len], bytes);
        offset += bytes.len;
        cursor = page.next;
        if (page.complete) break;
    }
    try t.expectEqual(body.len, offset);
    _ = try change(service.engine, .{ .revoke_privileges = .{ .object = c.TableAuthority.reference(stream.properties.authorization), .grantee = owner_role, .privileges = c.LogAuthority.read } });
    try t.expectError(error.Forbidden, dispatch(service, .{ .capture_read = .{ .next = cursor } }));
    _ = try change(service.engine, .{ .grant = .{ .object = c.TableAuthority.reference(stream.properties.authorization), .grantee = owner_role, .privileges = c.LogAuthority.read } });
    open_operation.operation += 1;
    (try dispatch(service, .{ .capture_read = .{ .close = .{ .handle = original.handle, .operation = open_operation } } })).deinit();
}
