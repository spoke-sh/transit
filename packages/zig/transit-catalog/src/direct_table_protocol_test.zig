const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const p = c.protocol;

const ResourceFixture = struct { request: w.Request, public_key: [32]u8, resource: c.DirectResource.Definition, digest: [32]u8 };

test "direct storage responses bind physical coverage to the original Table and flush cut" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const object: p.DataLifecycle.Object = .{ .scope = connection.scope, .branch = 1, .object = 7 };
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = object, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }} }, .properties = "" });
    defer declaration.deinit();
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .storage = .{ .object = object, .pending_limit = 1 } } };
    const context = try w.Request.context(input, alloc);
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, key);
    var request: w.Request = .{ .definition = input.definition, .connection = connection, .nonce = input.nonce, .action = input.action, .delegation = null, .proof = proof };
    const observation: c.DirectCatalog.StorageObservation = .{
        .interpretation = try declaration.stored(),
        .position = .{ .partition = 2, .next_lsn = 8 },
        .changed_lsn = 7,
        .live_rows = 3,
        .pending = .{ .rows = 1, .bytes = 100, .complete = false, .oldest_lsn = 4 },
        .archive_through = 2,
        .recovery_through = 3,
        .history_floor = 0,
        .next_segment = 4,
        .maintenance = .{
            .archive_source_lsn = 7,
            .archived_source_lsn = 1,
            .archive_target = .{ .through_lsn = 6, .source_lsn = 6, .checkpoint_lsn = null },
            .compaction_source_lsn = 7,
            .compacted_source_lsn = 1,
            .compaction_target = .{ .before_segment = 3, .source_lsn = 7, .after_segment = 1 },
        },
    };
    var response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .storage = observation } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    try t.expect(!request.transport().mutation and request.transport().control == null);
    inline for (0..19) |case| {
        var changed = response;
        const value = &changed.result.storage;
        switch (case) {
            0 => value.interpretation.interpretation.object.object += 1,
            1 => value.pending.rows = 2,
            2 => value.pending.bytes = 0,
            3 => value.pending.oldest_lsn = null,
            4 => value.pending.oldest_lsn = 8,
            5 => value.archive_through = 8,
            6 => value.recovery_through = 0,
            7 => value.history_floor = 9,
            8 => value.live_rows = 1,
            9 => value.next_segment = 0,
            10 => value.maintenance.archived_source_lsn = 8,
            11 => value.maintenance.compaction_source_lsn = 8,
            12 => value.maintenance.archive_target.?.through_lsn = 8,
            13 => value.maintenance.archive_target.?.checkpoint_lsn = 3,
            14 => value.maintenance.compaction_target.?.before_segment = 5,
            15 => value.maintenance.compacted_source_lsn = 8,
            16 => value.maintenance.compaction_target.?.source_lsn = 0,
            17 => value.maintenance.archive_source_lsn = 9,
            18 => value.maintenance.compaction_target.?.after_segment = 3,
            else => unreachable,
        }
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    }
    const target: c.DirectCatalog.FlushTarget = .{ .object = object, .through = .{ .partition = 2, .next_lsn = 4 } };
    request.action = .{ .flush = target };
    request.proof.claim.context = try w.Request.context(request.input(), alloc);
    request.proof = try p.Authorization.Proof.sign(request.proof.claim, key);
    response.context = request.proof.claim.context;
    response.subject.context = request.proof.claim.context;
    response.result = .{ .flush = .{ .target = target, .observed = observation, .complete = true } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    try t.expect(request.transport().mutation and request.transport().control == null);
    inline for (0..4) |case| {
        var changed = response;
        switch (case) {
            0 => changed.result.flush.target.through.next_lsn += 1,
            1 => changed.result.flush.complete = false,
            2 => changed.result.flush.observed.position.partition += 1,
            3 => changed.result.flush.observed.pending.oldest_lsn = 3,
            else => unreachable,
        }
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    }
}
test "named resource consumes independent signed intent and exact definition digest" {
    const parsed = try p.Json.parseFromSlice(ResourceFixture, t.allocator, @embedFile("fixtures/direct-resource-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    try t.expectEqual(std.math.maxInt(u64), fixture.request.action.resource_operation.binding.operation);
    try t.expectEqualDeep(fixture.digest, (try fixture.resource.interpretation(t.allocator)).digest);
    const saved = try c.DirectResourceClient.save(t.allocator, fixture.request.action.resource_operation.binding);
    defer t.allocator.free(saved);
    try t.expectEqualDeep(fixture.request.action.resource_operation.binding, try c.DirectResourceClient.load(t.allocator, saved));
    var changed = fixture.request;
    changed.action.resource_operation.binding.action.create.owned = true;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = fixture.request;
    changed.action.resource_operation.command = .cancel;
    try t.expectEqualStrings("table", changed.transport().control.?);
    try t.expect(changed.transport().mutation);
    changed.action.resource_operation.command = .inspect;
    try t.expectEqualStrings("table", changed.transport().control.?);
    try t.expect(!changed.transport().mutation);
}

test "named resource responses reject substituted allocation and malformed listing coverage" {
    const parsed = try p.Json.parseFromSlice(ResourceFixture, t.allocator, @embedFile("fixtures/direct-resource-v1.json"));
    defer parsed.deinit();
    var request = parsed.value.request;
    const binding = request.action.resource_operation.binding;
    const definition = parsed.value.resource;
    const operation: c.DirectResource.Operation = .{ .binding = binding, .position = .{ .partition = 1, .next_lsn = 5 }, .phase = .complete, .reason = .none, .resulting = definition, .allocation = definition.allocation, .retired = false };
    var response: w.Response = .{ .definition = p.Growth.current_definition, .context = request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = request.proof.claim.context }, .result = .{ .resource_operation = .{ .operation = operation } } };
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    var changed = response;
    changed.result.resource_operation.operation.resulting.?.allocation.sequence += 1;
    try t.expectError(error.InvalidNamedResourceOperation, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.resource_operation.operation.phase = .prepared;
    try t.expectError(error.InvalidNamedResourceOperation, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    request.action = .{ .resource_list = .{ .namespace = 1, .after = null } };
    request.proof.claim.context = try w.Request.context(request.input(), t.allocator);
    request.proof = try p.Authorization.Proof.sign(request.proof.claim, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    response.context = request.proof.claim.context;
    response.subject.context = request.proof.claim.context;
    response.result = .{ .resource_list = .{ .entries = @splat(null), .next = null, .position = .{ .partition = 1, .next_lsn = 5 } } };
    const view: c.DirectCatalog.ResourceView = .{ .definition = definition, .interpretation = try definition.interpretation(t.allocator), .position = operation.position };
    response.result.resource_list.entries[0] = view;
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    changed = response;
    changed.result.resource_list.entries[0].?.definition.resource += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.resource_list.entries[0].?.position.next_lsn += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.resource_list.entries[1] = view;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.resource_list.entries[1] = view;
    changed.result.resource_list.entries[0] = null;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.resource_list.next = 0;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    // A filtered page can be empty while advancing through claimed identities.
    changed.result.resource_list.entries = @splat(null);
    changed.result.resource_list.next = definition.object.object;
    try c.DirectTableClient.validateResponse(t.allocator, request, changed);
}

test "pin status binds mandatory current interpretation to the requested object" {
    const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .object = 7 };
    const owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 99 };
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = object.scope, .branch = 1, .principal = 4, .role = null, .audience = 5 }, .delegation = null, .nonce = @splat(7), .action = .{ .pin_status = .{ .object = object, .owner = owner } } };
    const context = try w.Request.context(input, t.allocator);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = null, .proof = proof };
    const state: w.PinState = .{ .interpretation = .{ .object = object, .revision = 2, .digest = @splat(3) }, .position = .{ .partition = 9, .next_lsn = 10 }, .retired = false, .handle = null, .released = false, .authority = .{ .database = 1, .schema = 2, .table = 3 } };
    var response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .pin_state = state } };
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    response.result.pin_state.interpretation.object.object += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, response));
    const missing = try p.Json.valueAlloc(t.allocator, .{ .position = state.position, .retired = state.retired, .handle = state.handle, .released = state.released, .authority = state.authority });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(w.PinState, t.allocator, missing));
}

test "direct Table consumes independently signed Python OpenSSL request bytes" {
    const Fixture = struct { request: w.Request, context: [32]u8, public_key: [32]u8, binary: struct { bytes: [4]u8, base64: []const u8 } };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-v1.json"));
    defer parsed.deinit();
    try parsed.value.request.validate(t.allocator);
    try parsed.value.request.proof.verify(parsed.value.public_key);
    try t.expectEqualDeep(parsed.value.context, try w.Request.context(parsed.value.request.input(), t.allocator));
    try t.expectEqual(std.math.maxInt(u64), parsed.value.request.connection.scope.catalog);
    const binary = try (w.Binary{ .base64 = parsed.value.binary.base64 }).decode(t.allocator, 4);
    defer t.allocator.free(binary);
    try t.expectEqualSlices(u8, &parsed.value.binary.bytes, binary);
}

test "current Table read consumes an independent full-width signed seek request" {
    const Fixture = struct { request: w.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-current-read-v1.json"));
    defer parsed.deinit();
    try parsed.value.request.validate(t.allocator);
    try parsed.value.request.proof.verify(parsed.value.public_key);
    const after = parsed.value.request.action.read_current.selection.rows.after.?;
    try t.expectEqual(std.math.maxInt(u64), after.origin);
    try t.expectEqual(std.math.maxInt(u64) - 1, after.operation);
    try t.expectEqual(std.math.maxInt(u32), after.ordinal);
}

test "direct Table request proof binds the complete typed action and current definition" {
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .lookup = .{ .namespace = 1, .name = "events" } } };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = try w.Request.context(input, t.allocator) }, key);
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .proof = proof };
    const bytes = try p.Json.valueAlloc(t.allocator, request);
    defer t.allocator.free(bytes);
    const parsed = try w.Request.parse(t.allocator, bytes);
    defer parsed.deinit();
    try t.expectEqualDeep(request, parsed.value);
    var changed = request;
    changed.action.lookup.name = "replacement";
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = request;
    changed.connection.role = 10;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    // Removing rather than defaulting the compatibility field rejects.
    const missing = try p.Json.valueAlloc(t.allocator, .{ .connection = request.connection, .nonce = request.nonce, .action = request.action, .proof = request.proof });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, w.Request.parse(t.allocator, missing));
}

test "direct Queue signs frozen claims and requires saved definition" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8, release_request: w.Request, release_intent_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-queue-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    const work = request.action.queue.mutate.work;
    try t.expectEqual(std.math.maxInt(u64), work.identity().operation);
    try t.expectEqualDeep(parsed.value.intent_digest, (try work.binding(t.allocator)).intent);
    try t.expect(request.transport().mutation and request.transport().control == null);
    const release_request = parsed.value.release_request;
    try release_request.validate(t.allocator);
    try release_request.proof.verify(parsed.value.public_key);
    try t.expectEqualDeep(parsed.value.release_intent_digest, (try release_request.action.queue.mutate.work.binding(t.allocator)).intent);
    try t.expect(release_request.transport().mutation and release_request.transport().control != null);
    var changed_release = release_request;
    changed_release.action.queue.mutate.work.release.claim.leases.?.sha256[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed_release.validate(t.allocator));
    const bytes = try c.DirectQueueClient.save(t.allocator, request.connection, .{ .work = work });
    defer t.allocator.free(bytes);
    const saved = try c.DirectQueueClient.load(t.allocator, bytes);
    defer saved.deinit();
    try t.expectEqualDeep(request.action.queue.mutate, saved.value.work);
    var changed = request;
    changed.action.queue.mutate.work.claim.maximum = 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    @memset(foreign[at..][0..64], '0');
    try t.expectError(error.InvalidJsonShape, c.DirectQueueClient.load(t.allocator, foreign));
    const missing = try p.Json.valueAlloc(t.allocator, .{ .connection = saved.value.connection, .work = saved.value.work });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, c.DirectQueueClient.load(t.allocator, missing));
    changed = request;
    changed.action = .{ .queue = .{ .operation = work } };
    try t.expect(!changed.transport().mutation and changed.transport().control != null);
}

test "direct Stream preserves independent signed work and required saved definition" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-stream-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    const work = request.action.stream.mutate.work;
    try t.expectEqual(std.math.maxInt(u64), work.identity().operation);
    try t.expectEqualDeep(parsed.value.intent_digest, (try work.binding(t.allocator)).intent);
    const bytes = try c.DirectStreamClient.save(t.allocator, request.connection, .{ .work = work });
    defer t.allocator.free(bytes);
    const saved = try c.DirectStreamClient.load(t.allocator, bytes);
    defer saved.deinit();
    try t.expectEqualDeep(request.action.stream.mutate, saved.value.work);
    var changed = request;
    changed.action.stream.mutate.work.consume.from = 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    @memset(foreign[at..][0..64], '0');
    try t.expectError(error.InvalidJsonShape, c.DirectStreamClient.load(t.allocator, foreign));
    const missing = try p.Json.valueAlloc(t.allocator, .{ .connection = saved.value.connection, .work = saved.value.work });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, c.DirectStreamClient.load(t.allocator, missing));
}

test "direct Stream wait binds its scheduling duration while preserving the consume intent" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-stream-wait-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    const work: c.DirectStreamMutation.Request = .{ .consume = request.action.stream.wait.consume };
    try t.expectEqualDeep(parsed.value.intent_digest, (try work.binding(t.allocator)).intent);
    try t.expectEqualDeep(c.client.WaitHint{ .after = 0, .milliseconds = 1000 }, request.transport().wait.?);
    try t.expect(request.transport().mutation and request.transport().control == null);
    var changed = request;
    changed.action.stream.wait.milliseconds = 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    var action = request.action.stream;
    action.wait.milliseconds = 0;
    try t.expectError(error.InvalidStreamWait, action.validate(request.connection.principal, request.connection.scope));
    action.wait.milliseconds = 1001;
    try t.expectError(error.InvalidStreamWait, action.validate(request.connection.principal, request.connection.scope));
}

test "direct log consumes independent signed intent and preserves saved full-width identity" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-log-v1.json"));
    defer parsed.deinit();
    try parsed.value.request.validate(t.allocator);
    try parsed.value.request.proof.verify(parsed.value.public_key);
    var scratch: std.heap.ArenaAllocator = .init(t.allocator);
    defer scratch.deinit();
    const request = try parsed.value.request.action.log_admit.request(scratch.allocator());
    try t.expectEqual(std.math.maxInt(u64), request.binding.identity.operation);
    try t.expectEqualDeep(parsed.value.intent_digest, try request.intent.digest(t.allocator));
    const bytes = try c.DirectLogClient.save(t.allocator, parsed.value.request.connection, request);
    defer t.allocator.free(bytes);
    const saved = try c.DirectLogClient.load(t.allocator, bytes);
    defer saved.deinit();
    try t.expectEqualDeep(parsed.value.request.action.log_admit, saved.value.work);
    var changed = parsed.value.request;
    changed.action.log_admit.kind = .stream;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    var substituted = saved.value;
    substituted.work.action.rename = "retargeted";
    try t.expectError(error.DataIdentityConflict, substituted.validate(t.allocator));
    const foreign = try t.allocator.dupe(u8, bytes);
    defer t.allocator.free(foreign);
    const at = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    @memset(foreign[at..][0..64], '0');
    try t.expectError(error.InvalidJsonShape, c.DirectLogClient.load(t.allocator, foreign));
    const missing = try p.Json.valueAlloc(t.allocator, .{ .connection = saved.value.connection, .work = saved.value.work });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, c.DirectLogClient.load(t.allocator, missing));
}

test "direct dependency consumes independently signed full-width registration and binary digest" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer parsed.deinit();
    try parsed.value.request.validate(t.allocator);
    try parsed.value.request.proof.verify(parsed.value.public_key);
    const binding = parsed.value.request.action.dependency_operation.binding;
    try t.expectEqual(std.math.maxInt(u64), binding.operation);
    try t.expectEqual(std.math.maxInt(u64), binding.edge.dependent.interpretation.revision);
    try t.expectEqualDeep(parsed.value.edge_digest, try binding.edge.digest());
    var changed = parsed.value.request;
    changed.action.dependency_operation.binding.authority = .catalog_administrator;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}

test "direct dependency graph response rejects substituted objects and mixed observations" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer parsed.deinit();
    const edge = parsed.value.request.action.dependency_operation.binding.edge;
    var request = parsed.value.request;
    const selection: c.DirectDependency.Selection = .{ .dependents = edge.source.object };
    request.action = .{ .dependencies = .{ .selection = selection, .cursor = null, .authority = .dependent } };
    request.proof.claim.context = try w.Request.context(request.input(), t.allocator);
    request.proof = try p.Authorization.Proof.sign(request.proof.claim, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const position: p.DataLifecycle.Position = .{ .partition = 1, .next_lsn = 10 };
    const cursor: c.DirectDependency.Cursor = .{ .selection = selection, .authority = .dependent, .position = position, .after = try edge.digest() };
    const page: c.DirectDependency.Page = .{ .entries = .{ edge, null, null, null }, .next = cursor, .position = position };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = request.proof.claim.context }, .result = .{ .dependencies = page } };
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    var changed = response;
    changed.result.dependencies.entries[0].?.source.object.object -= 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.dependencies.next.?.position.next_lsn += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.dependencies.next.?.authority = .catalog_administrator;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    changed = response;
    changed.result.dependencies.entries[1] = edge;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    // Filtered work may produce an empty, incomplete page with a valid cursor.
    changed = response;
    changed.result.dependencies.entries = @splat(null);
    try c.DirectTableClient.validateResponse(t.allocator, request, changed);
}

test "direct Table delegation consumes independent caller and executor signatures" {
    const Fixture = struct { request: w.Request, caller_key: [32]u8, executor_key: [32]u8, retained_grant: []const u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-delegation-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.executor_key);
    try request.delegation.?.proof.verify(parsed.value.caller_key);
    const retained = try (w.Binary{ .base64 = parsed.value.retained_grant }).decode(t.allocator, c.DirectReadDelegation.encoded_bytes);
    defer t.allocator.free(retained);
    try t.expectEqualSlices(u8, retained, &try request.delegation.?.encode(t.allocator));
    const restored = try c.DirectReadDelegation.decode(t.allocator, retained);
    try t.expectEqualDeep(request.delegation.?, restored);
    try restored.proof.verify(parsed.value.caller_key);
    try t.expectEqual(@as(u64, 4), request.connection.principal);
    try t.expectEqual(@as(u64, 9), request.proof.claim.principal);
    var changed = request;
    changed.action = .describe;
    try t.expectError(error.TableDelegationDenied, changed.validate(t.allocator));
    changed = request;
    changed.action.pin.owner.operation -= 1;
    try t.expectError(error.TableDelegationDenied, changed.validate(t.allocator));
    changed = request;
    changed.action.pin.expected.next_lsn += 1;
    try t.expectError(error.TableDelegationDenied, changed.validate(t.allocator));
    changed = request;
    changed.proof.claim.principal = request.connection.principal;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    const missing = try p.Json.valueAlloc(t.allocator, .{ .definition = request.definition, .connection = request.connection, .nonce = request.nonce, .action = request.action, .proof = request.proof });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, w.Request.parse(t.allocator, missing));
}

test "direct Table binary representation is canonical and bounded before allocation" {
    const encoded = try w.Binary.encode(t.allocator, &.{ 0, 255, 128, 1 });
    defer t.allocator.free(encoded.base64);
    try t.expectEqualStrings("AP+AAQ==", encoded.base64);
    const decoded = try encoded.decode(t.allocator, 4);
    defer t.allocator.free(decoded);
    try t.expectEqualSlices(u8, &.{ 0, 255, 128, 1 }, decoded);
    try t.expectError(error.TablePayloadTooLarge, encoded.decode(t.allocator, 3));
    for ([_][]const u8{ "AQ", "AR==", "AQ===", "AQ==\n", "_w==" }) |invalid| {
        try t.expectError(error.InvalidTableBinary, (w.Binary{ .base64 = invalid }).decode(t.allocator, 8));
    }
}

test "direct Table row conversion preserves full width values and action constraints" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = 3, .catalog = std.math.maxInt(u64) };
    const columns = [_]c.fuze.TableSchema.Column{
        .{ .id = 1, .name = "id", .type = .uint64, .nullable = false },
        .{ .id = 2, .name = "value", .type = .binary },
        .{ .id = 3, .name = "zero", .type = .float64 },
    };
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 4, .columns = &columns, .primary_key = &.{1} };
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    var scratch: [65536]u8 = undefined;
    const schema_wire = try w.Binary.encode(alloc, try schema.encode(&scratch));
    const cells = [_]c.fuze.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } },
        .{ .value = .{ .atom = .{ .bytes = "\x00\xff\x80" } } },
        .{ .value = .{ .atom = .{ .float = -0.0 } } },
    };
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 5, .operation = std.math.maxInt(u64), .ordinal = 0 }, .cells = &cells };
    const row_wire = try w.Binary.encode(alloc, try row.encode(schema, &scratch));
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 4, .operation = std.math.maxInt(u64) }, .target = declaration.definition.object, .action = .insert, .expected_definition = (try declaration.stored()).interpretation, .expected_data = null, .intent = @splat(3) };
    var work: w.Rows = .{ .binding = binding, .interpretation = try declaration.stored(), .schema = schema_wire, .changes = &.{.{ .insert = row_wire }}, .ingestion = .bulk };
    work.binding.intent = try work.digest(alloc);
    const native = try work.native(alloc);
    try t.expectEqualDeep(row, native.changes[0].put.row);
    try t.expectEqual(@as(u64, 1) << 63, @as(u64, @bitCast(native.changes[0].put.row.cells[2].value.atom.float)));
    work.binding.action = .delete;
    try t.expectError(error.UnsupportedTableMutationShape, work.native(alloc));
    work.binding.action = .insert;
    work.interpretation.schema_fingerprint[0] ^= 1;
    try t.expectError(error.TableSchemaChanged, work.native(alloc));
    work.interpretation.schema_fingerprint[0] ^= 1;
    work.binding.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, work.native(alloc));
}

test "direct Table responses reject unrelated requests, altered receipts and malformed phases" {
    _ = &c.DirectTableClient.call;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = 3, .catalog = 1 };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns }, .properties = "" });
    defer declaration.deinit();
    const stored = try declaration.stored();
    const binding: p.DataLifecycle.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 4, .operation = 1 }, .target = declaration.definition.object, .action = .update, .expected_definition = stored.interpretation, .expected_data = .{ .partition = 2, .next_lsn = 8 }, .intent = @splat(3) };
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .principal = 4, .role = null, .audience = 5 }, .delegation = null, .nonce = @splat(1), .action = .{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .proof = proof };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .rows = .{ .committed = .{ .binding = binding, .resulting = stored, .transaction = null, .outcome = .{ .position = .{ .partition = 2, .next_lsn = 9 }, .matched = 1, .affected = 0, .live_rows = 1 } } } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    var altered = response;
    altered.subject.role += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.subject.credential_epoch += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.context[0] ^= 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.result.rows.committed.binding.identity.operation += 1;
    try t.expectError(error.DataIdentityConflict, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.result.rows.committed.outcome.affected = 2;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.result.rows.committed.outcome.position.partition += 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.result = .{ .rows = .{ .admitted = .{ .binding = binding, .intent = .{ .bytes = 1, .sha256 = @splat(4) }, .basis = .{ .interpretation = stored.interpretation, .position = binding.expected_data.?, .changed_lsn = 8 }, .phase = .cancelled, .reason = .none } } };
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
    altered = response;
    altered.result = .released;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, altered));
}

test "DDL preview responses preserve proposed schema and never imply an accepted outcome" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns };
    var bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    var proposal: w.Ddl = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = connection.scope, .principal = 4, .operation = 1 }, .target = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) },
        .namespace = 1,
        .name = "events",
        .action = .{ .create = .{ .owner = 0, .schema = try w.Binary.encode(alloc, try schema.encode(&bytes)) } },
    };
    proposal.binding.intent = try proposal.digest(alloc);
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .preview = proposal } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .proof = proof };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .preview = .{ .binding = proposal.binding, .directory_position = .{ .partition = 1, .next_lsn = 1 }, .current = null, .reason = .none, .work = .metadata, .schema_fingerprint = try schema.fingerprint() } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    var changed = response;
    changed.result.preview.schema_fingerprint.?[0] ^= 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result.preview.reason = .name_conflict;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result.preview.binding.target.object += 1;
    try t.expectError(error.DataIdentityConflict, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result = .{ .ddl = .not_observed };
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    try t.expect(!request.transport().mutation and request.transport().control == null);
}

test "direct statement conversion freezes typed predicates and requires a data basis" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = 3, .catalog = 1 };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    var compiled = try c.fuze.TableDml.compile(alloc, "DELETE FROM events WHERE id >= 42", "events", schema, null);
    defer compiled.deinit();
    const scratch = try alloc.alloc(u8, c.fuze.TableDmlCodec.max_bytes);
    var work: w.Statement = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 4, .operation = 2 }, .target = declaration.definition.object, .action = .delete, .expected_definition = (try declaration.stored()).interpretation, .expected_data = .{ .partition = 17, .next_lsn = 8 }, .intent = @splat(0) },
        .interpretation = try declaration.stored(),
        .schema = try w.Binary.encode(alloc, try schema.encode(scratch)),
        .plan = try w.Binary.encode(alloc, try c.fuze.TableDmlCodec.encode(alloc, compiled.plan, scratch)),
    };
    work.binding.intent = try work.digest(alloc);
    const native = try work.native(alloc);
    try t.expect(native.changes.len == 0 and native.statement.?.action == .delete);
    try t.expect(try native.statement.?.matches(&.{.{ .value = .{ .atom = .{ .signed = 42 } } }}));
    try t.expect(!try native.statement.?.matches(&.{.{ .value = .{ .atom = .{ .signed = 41 } } }}));
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .preview_statement = work } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = null, .proof = proof };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .row_preview = .{ .binding = work.binding, .directory_position = .{ .partition = 1, .next_lsn = 2 }, .current = .{ .interpretation = work.interpretation, .position = .{ .partition = 17, .next_lsn = 8 }, .changed_lsn = 7, .row_count = 1 }, .reason = .none } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    try t.expect(!request.transport().mutation and request.transport().control == null);
    var changed = response;
    changed.result.row_preview.reason = .stale_data;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result.row_preview.current.position.next_lsn = 9;
    changed.result.row_preview.current.changed_lsn = 9;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed.result.row_preview.reason = .stale_data;
    try c.DirectTableClient.validateResponse(alloc, request, changed);
    changed = response;
    changed.result.row_preview.current.interpretation.schema_fingerprint[0] ^= 1;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result.row_preview.reason = .stale_definition;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    changed = response;
    changed.result.row_preview.binding.identity.operation += 1;
    try t.expectError(error.DataIdentityConflict, c.DirectTableClient.validateResponse(alloc, request, changed));
    work.binding.expected_data = null;
    try t.expectError(error.InvalidTableStatementIntent, work.native(alloc));
    work.binding.expected_data = .{ .partition = 17, .next_lsn = 8 };
    work.binding.action = .update;
    try t.expectError(error.InvalidTableStatementIntent, work.native(alloc));
    work.binding.action = .delete;
    work.binding.intent[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, work.native(alloc));
}

test "borrowed Table reads bind independent signatures and deny lifecycle control" {
    const Fixture = struct { request: w.Request, caller_key: [32]u8, executor_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-borrow-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    const original = request.delegation.?;
    const borrow = request.borrow.?;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.executor_key);
    try (try borrow.proof(original, t.allocator)).verify(parsed.value.caller_key);
    try t.expectEqual(@as(u64, 10), request.proof.claim.principal);
    try t.expectEqual(@as(u64, 9), original.binding.executor);
    const snapshot = borrow.binding.target.snapshot;
    for ([_]w.Action{
        .{ .observe = .{ .namespace = 1, .interpretation = original.binding.interpretation, .rows = null } },
        .{ .pin = .{ .object = snapshot.object, .owner = snapshot.handle.owner, .expected = original.binding.expected } },
        .{ .release = snapshot },
        .{ .pin_status = .{ .object = snapshot.object, .owner = snapshot.handle.owner } },
        .describe,
    }) |action| try t.expectError(error.TableDelegationDenied, borrow.allow(action));
    try t.expectError(error.TableDelegationDenied, borrow.allow(.{ .read_authority = snapshot.object }));
    try t.expectError(error.TableDelegationDenied, original.allow(.{ .read_authority = snapshot.object }));
    try t.expectError(error.TableDelegationDenied, original.allow(.{ .observe = .{ .namespace = 1, .interpretation = original.binding.interpretation, .rows = .{} } }));
    var changed = borrow;
    changed.binding.target.snapshot.handle.content.sha256[0] ^= 1;
    try t.expectError(error.TableDelegationDenied, changed.allow(request.action));
    try t.expectError(error.SignatureVerificationFailed, (try changed.proof(original, t.allocator)).verify(parsed.value.caller_key));
    inline for (.{ "executor", "purpose" }) |field| {
        changed = borrow;
        if (comptime std.mem.eql(u8, field, "executor")) changed.binding.executor += 1 else changed.binding.purpose[0] ^= 1;
        try t.expectError(error.SignatureVerificationFailed, (try changed.proof(original, t.allocator)).verify(parsed.value.caller_key));
    }
    var rotated = original;
    rotated.proof.claim.credential_epoch += 1;
    try t.expectError(error.SignatureVerificationFailed, (try borrow.proof(rotated, t.allocator)).verify(parsed.value.caller_key));
    var invalid = request;
    invalid.closure = .{ .credential_epoch = 1, .signature = @splat(0) };
    try t.expectError(error.InvalidTableDelegation, invalid.validate(t.allocator));
    invalid = request;
    invalid.delegation = null;
    try t.expectError(error.InvalidTableDelegation, invalid.validate(t.allocator));
}

test "dependency membership binds exact edges and keeps receipts separate from current state" {
    const Fixture = struct { request: w.Request, public_key: [32]u8, edge_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-dependency-v1.json"));
    defer parsed.deinit();
    var request = parsed.value.request;
    const edge = request.action.dependency_operation.binding.edge;
    request.action = .{ .dependency_state = edge };
    request.proof.claim.context = try w.Request.context(request.input(), t.allocator);
    request.proof = try p.Authorization.Proof.sign(request.proof.claim, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    try request.validate(t.allocator);
    try t.expect(!request.transport().mutation and request.transport().control == null);
    const claim = request.proof.claim;
    var response: w.Response = .{ .definition = p.Growth.current_definition, .context = claim.context, .policy_revision = 1, .subject = .{ .principal = claim.principal, .login_role = claim.principal, .role = claim.role orelse claim.principal, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context }, .result = .{ .dependency_state = .{ .edge = edge, .position = .{ .partition = 3, .next_lsn = 7 }, .present = true } } };
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    response.result.dependency_state.present = false;
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    inline for (0..4) |case| {
        var changed = response;
        switch (case) {
            0 => changed.result.dependency_state.edge.source.digest[0] ^= 1,
            1 => changed.result.dependency_state.edge.dependent.interpretation.digest[0] ^= 1,
            2 => changed.result.dependency_state.position.next_lsn = 0,
            3 => changed.result = .{ .dependency_operation = .not_observed },
            else => unreachable,
        }
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, changed));
    }
    const incomplete = try p.Json.valueAlloc(t.allocator, .{ .edge = edge, .position = response.result.dependency_state.position });
    defer t.allocator.free(incomplete);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(c.DirectDependency.State, t.allocator, incomplete));
}

test "current observations reject wrong definitions invented coverage and altered row pages" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns };
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 13, .name = try .init("events") };
    var property_bytes: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = try properties.encode(&property_bytes) });
    defer declaration.deinit();
    const stored = try declaration.stored();
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .observe = .{ .namespace = 1, .interpretation = stored.interpretation, .rows = .{ .rows = 2 } } } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .delegation = input.delegation, .proof = proof };
    const scratch = try alloc.alloc(u8, c.fuze.TableRow.max_bytes);
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 2, .operation = 3, .ordinal = 0 }, .cells = &cells };
    const bytes = try row.encode(schema, scratch);
    const row_binary = try w.Binary.encode(alloc, bytes);
    const row_len: u32 = @intCast(bytes.len);
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .observation = .{
        .definition = .{ .interpretation = stored, .namespace = 1, .authorization = 13, .name = properties.name, .position = .{ .partition = 2, .next_lsn = 8 }, .changed_lsn = 7, .row_count = 3, .schema = try w.Binary.encode(alloc, try schema.encode(scratch)) },
        .authority = .{ .database = 11, .schema = 12, .table = 13 },
        .page = .{ .rows = &.{row_binary}, .encoded_bytes = row_len, .more = true },
    } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    try t.expect(!request.transport().mutation and request.transport().control == null);
    inline for (0..8) |case| {
        var changed = response;
        const found = &changed.result.observation;
        switch (case) {
            0 => found.definition.interpretation.interpretation.revision += 1,
            1 => found.definition.changed_lsn = 9,
            2 => found.authority.table = 14,
            3 => found.page = null,
            4 => found.page.?.more = false,
            5 => found.page.?.encoded_bytes += 1,
            6 => found.definition.row_count = 1,
            7 => {
                found.page.?.rows = &.{ row_binary, row_binary };
                found.page.?.encoded_bytes = 2 * row_len;
            },
            else => unreachable,
        }
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    }
}

test "current suffix and point responses bind logical basis ordered seek and requested key" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const schema: c.fuze.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 13, .name = try .init("events") };
    var property_bytes: [c.storage.TableDeclaration.max_properties_bytes]u8 = undefined;
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 7 }, .revision = 1, .schema = schema, .properties = try properties.encode(&property_bytes) });
    defer declaration.deinit();
    const stored = try declaration.stored();
    const scratch = try alloc.alloc(u8, c.fuze.TableRow.max_bytes);
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 42 } } }};
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 2, .operation = 3, .ordinal = 1 }, .cells = &cells };
    const bytes = try row.encode(schema, scratch);
    const row_binary = try w.Binary.encode(alloc, bytes);
    const row_len: u32 = @intCast(bytes.len);
    const before: c.fuze.TableRow.Identity = .{ .origin = 2, .operation = 3, .ordinal = 0 };
    const read: w.CurrentRead = .{ .namespace = 1, .interpretation = stored.interpretation, .expected = .{ .partition = 2, .next_lsn = 7 }, .selection = .{ .rows = .{ .after = before, .limits = .{ .rows = 2 } } } };
    const request = try signedCurrentRead(alloc, connection, read);
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = request.proof.claim.context }, .result = .{ .current_read = .{
        .definition = .{ .interpretation = stored, .namespace = 1, .authorization = 13, .name = properties.name, .position = .{ .partition = 2, .next_lsn = 8 }, .changed_lsn = 7, .row_count = 3, .schema = try w.Binary.encode(alloc, try schema.encode(scratch)) },
        .authority = .{ .database = 11, .schema = 12, .table = 13 },
        .selection = .{ .rows = .{ .rows = &.{row_binary}, .encoded_bytes = row_len, .next = row.identity } },
    } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    try t.expect(!request.transport().mutation and request.transport().control == null);
    inline for (0..10) |case| {
        var changed = response;
        const found = &changed.result.current_read;
        switch (case) {
            0 => found.definition.interpretation.interpretation.revision += 1,
            1 => found.definition.changed_lsn = 8,
            2 => found.definition.position.next_lsn = 6,
            3 => found.definition.position.partition += 1,
            4 => found.authority.table += 1,
            5 => found.selection.rows.encoded_bytes += 1,
            6 => found.selection.rows.next.?.ordinal += 1,
            7 => found.definition.row_count = 1,
            8 => {
                found.selection.rows.rows = &.{ row_binary, row_binary };
                found.selection.rows.encoded_bytes = 2 * row_len;
            },
            9 => found.selection = .{ .key = row_binary },
            else => unreachable,
        }
        try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, request, changed));
    }
    var later = read;
    later.selection.rows.after = row.identity;
    const later_request = try signedCurrentRead(alloc, connection, later);
    var repeated = response;
    repeated.context = later_request.proof.claim.context;
    repeated.subject.context = later_request.proof.claim.context;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, later_request, repeated));
    repeated.result.current_read.selection.rows = .{ .rows = &.{}, .encoded_bytes = 0, .next = null };
    try c.DirectTableClient.validateResponse(alloc, later_request, repeated);
    // An empty suffix proves exhaustion at this seek, not prior coverage.
    var point = read;
    point.selection = .{ .key = try w.Binary.encode(alloc, try row.storageKey(schema, scratch)) };
    const point_request = try signedCurrentRead(alloc, connection, point);
    var point_response = response;
    point_response.context = point_request.proof.claim.context;
    point_response.subject.context = point_request.proof.claim.context;
    point_response.result.current_read.selection = .{ .key = row_binary };
    try c.DirectTableClient.validateResponse(alloc, point_request, point_response);
    const wrong: c.fuze.TableRow.Row = .{ .identity = row.identity, .cells = &.{.{ .value = .{ .atom = .{ .signed = 43 } } }} };
    point_response.result.current_read.selection.key = try w.Binary.encode(alloc, try wrong.encode(schema, scratch));
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(alloc, point_request, point_response));
    point_response.result.current_read.selection.key = null;
    try c.DirectTableClient.validateResponse(alloc, point_request, point_response);
}

fn signedCurrentRead(allocator: std.mem.Allocator, connection: w.Connection, read: w.CurrentRead) !w.Request {
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .delegation = null, .nonce = @splat(7), .action = .{ .read_current = read } };
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = try w.Request.context(input, allocator) }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    return .{ .definition = input.definition, .connection = connection, .nonce = input.nonce, .action = input.action, .delegation = null, .proof = proof };
}

test "retained key range consumes independent signed bounds and interval fingerprint" {
    const Fixture = struct { request: w.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-key-range-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const interval = try request.action.key_range.interval.native(arena.allocator());
    try t.expectEqualDeep(request.action.key_range.after.?.interval, try interval.fingerprint());
    var changed = request;
    changed.action.key_range.interval.lower.?.inclusive = false;
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
    changed = request;
    changed.action.key_range.after.?.source.bytes += 1;
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
    changed = request;
    changed.action.key_range.after.?.after.base64 = "";
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
}

test "retained column scan consumes independent signed projection and cursor fingerprint" {
    const Fixture = struct { request: w.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-projection-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    const selected = try request.action.column_scan.projection();
    try t.expectEqualSlices(u8, &.{ 0, 2, 127 }, selected.columns());
    try t.expectEqualDeep(request.action.column_scan.after.?.source, try selected.cursorSource(request.action.column_scan.snapshot.handle.content));
    for ([_][]const u16{ &.{}, &.{ 2, 0 }, &.{ 0, 0 }, &.{ 0, 128 }, &.{65535} }) |columns| {
        var changed = request;
        changed.action.column_scan.columns = columns;
        changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
        try t.expectError(error.InvalidProjection, changed.validate(t.allocator));
    }
    var changed = request;
    changed.action.column_scan.columns = &.{ 0, 2 };
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
    changed = request;
    changed.action.column_scan.after.?.source = request.action.column_scan.snapshot.handle.content;
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
}

test "retained filter scan binds independent signed cursor and sparse coverage envelope" {
    const Fixture = struct { request: w.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-table-filter-v1.json"));
    defer parsed.deinit();
    const request = parsed.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(parsed.value.public_key);
    try t.expect(!request.transport().mutation);
    const scan = request.action.filter_scan;
    try t.expectEqualDeep(scan.after.?.source, try c.storage.TablePartition.filteredCursorFingerprint(scan.snapshot.handle, scan.fingerprint));
    var changed = request;
    changed.action.filter_scan.fingerprint[0] ^= 1;
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidTableCursor, changed.validate(t.allocator));
    changed = request;
    changed.action.filter_scan.plan.base64 = "";
    changed.proof.claim.context = try w.Request.context(changed.input(), t.allocator);
    try t.expectError(error.InvalidPlanEncoding, changed.validate(t.allocator));
    const page: w.Page = .{
        .snapshot = scan.snapshot,
        .interpretation = .{ .kind = .table, .interpretation = .{ .object = scan.snapshot.object, .revision = 1, .digest = @splat(3) }, .content = .{ .bytes = 104, .sha256 = @splat(3) }, .schema_fingerprint = @splat(5), .retired = false },
        .accepted = .{ .partition = 9, .next_lsn = 10 },
        .changed_lsn = 9,
        .total_rows = 24,
        .rows = &.{},
        .encoded_bytes = 0,
        .next = .{ .source = scan.after.?.source, .after = try (c.fuze.TableRow.Identity{ .origin = 4, .operation = 10, .ordinal = 10 }).encode() },
    };
    var value: w.FilteredPage = .{ .page = page, .examined = 8, .offsets = @splat(0), .failure = null };
    var response: w.Response = .{ .definition = p.Growth.current_definition, .context = request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = request.proof.claim.context }, .result = .{ .filtered_page = value } };
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    value.examined = 0;
    response.result.filtered_page.page.interpretation.kind = .kv;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, response));
    response.result.filtered_page.page.interpretation.kind = .table;
    try t.expectError(error.InvalidTableResponse, value.validate());
    value.examined = 9;
    try t.expectError(error.InvalidTableResponse, value.validate());
    value.examined = 8;
    value.offsets[0] = 1;
    try t.expectError(error.InvalidTableResponse, value.validate());
    value.offsets[0] = 0;
    value.page.next.?.source = scan.snapshot.handle.content;
    response.result.filtered_page = value;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, response));
    value.page.next = null;
    value.examined = 3;
    value.failure = .{ .identity = .{ .origin = 4, .operation = 10, .ordinal = 6 }, .column = 0, .instruction = 0, .outcome = .type_error };
    response.result.filtered_page = value;
    try c.DirectTableClient.validateResponse(t.allocator, request, response);
    value.failure.?.identity.ordinal = 2;
    response.result.filtered_page = value;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, request, response));
    value.failure.?.instruction = 64;
    try t.expectError(error.InvalidTableResponse, value.validate());
    value.failure.?.instruction = 0;
    value.page.next = page.next;
    try t.expectError(error.InvalidTableResponse, value.validate());
}

test "retained filter plan admission binds source schema collations and complete fingerprint" {
    const f = c.fuze;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "label", .type = .utf8, .collation = .ascii_ci }};
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns };
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var plan: f.LogicalQuery.Plan = .{ .schema = try schema.rowType(&fields), .source_basis = @splat(17), .projection = &.{0}, .collations = .fromTable(schema), .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = "A" } } } };
    var encoded: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const fixture = try p.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8 }, a, @embedFile("fixtures/direct-table-filter-v1.json"));
    var scan = fixture.value.request.action.filter_scan;
    scan.plan = try w.Binary.encode(a, try f.LogicalPlanCodec.encode(plan, &encoded));
    scan.fingerprint = try plan.fingerprint();
    const decoded = try scan.decodePlan(a, schema, plan.source_basis);
    try t.expectEqualDeep(scan.fingerprint, try decoded.fingerprint());
    try t.expectEqualDeep(plan.collations, decoded.collations);
    try t.expectError(error.InvalidPlanEncoding, scan.decodePlan(a, schema, @splat(18)));
    scan.fingerprint[0] ^= 1;
    try t.expectError(error.SourceChanged, scan.decodePlan(a, schema, plan.source_basis));
    scan.fingerprint = try plan.fingerprint();
    var changed = schema;
    changed.columns = &.{.{ .id = 1, .name = "label", .type = .utf8, .collation = .utf8_binary }};
    try t.expectError(error.SourceChanged, scan.decodePlan(a, changed, plan.source_basis));
    encoded[4] ^= 1;
    scan.plan = try w.Binary.encode(a, encoded[0..(try scan.plan.decode(a, f.LogicalPlanCodec.max_bytes)).len]);
    try t.expectError(error.InvalidPlanEncoding, scan.decodePlan(a, schema, plan.source_basis));
    plan.limit = 1;
    scan.plan = try w.Binary.encode(a, try f.LogicalPlanCodec.encode(plan, &encoded));
    try t.expectError(error.SourceChanged, scan.decodePlan(a, schema, plan.source_basis));
}
