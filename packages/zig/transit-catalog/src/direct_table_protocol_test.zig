const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const p = c.protocol;

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

test "direct Table request proof binds the complete typed action and current definition" {
    const connection: w.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 1 }, .branch = 1, .principal = 4, .role = null, .audience = 5 };
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .nonce = @splat(7), .action = .{ .lookup = .{ .namespace = 1, .name = "events" } } };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = try w.Request.context(input, t.allocator) }, key);
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .proof = proof };
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
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .principal = 4, .role = null, .audience = 5 }, .nonce = @splat(1), .action = .{ .operation = .{ .binding = binding, .command = .inspect, .steps = 1 } } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .proof = proof };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .result = .{ .rows = .{ .committed = .{ .binding = binding, .resulting = stored, .outcome = .{ .position = .{ .partition = 2, .next_lsn = 9 }, .matched = 1, .affected = 0, .live_rows = 1 } } } } };
    try c.DirectTableClient.validateResponse(alloc, request, response);
    var altered = response;
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
    const input: w.Request.Input = .{ .definition = p.Growth.current_definition, .connection = connection, .nonce = @splat(7), .action = .{ .preview = proposal } };
    const context = try w.Request.context(input, alloc);
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 42, .principal = 4, .role = null, .audience = 5, .credential_epoch = 1, .context = context }, try p.Ed25519.KeyPair.generateDeterministic(@splat(9)));
    const request: w.Request = .{ .definition = input.definition, .connection = input.connection, .nonce = input.nonce, .action = input.action, .proof = proof };
    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = context, .policy_revision = 1, .result = .{ .preview = .{ .binding = proposal.binding, .directory_position = .{ .partition = 1, .next_lsn = 1 }, .current = null, .reason = .none, .work = .metadata, .schema_fingerprint = try schema.fingerprint() } } };
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
