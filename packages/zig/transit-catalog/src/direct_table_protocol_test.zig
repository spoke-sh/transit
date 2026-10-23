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
    const row: c.fuze.TableRow.Row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &cells };
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
