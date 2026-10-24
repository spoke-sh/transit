const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const p = c.protocol;

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
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = context }, .result = .{ .rows = .{ .committed = .{ .binding = binding, .resulting = stored, .outcome = .{ .position = .{ .partition = 2, .next_lsn = 9 }, .matched = 1, .affected = 0, .live_rows = 1 } } } } };
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
