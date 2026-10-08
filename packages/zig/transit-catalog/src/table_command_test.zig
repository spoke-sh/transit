const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const Command = c.TableCommand;
const f = c.fuze;
const scope: c.TableCatalogRecords.Scope = .{ .realm = 1, .resource = 7, .catalog = 9 };
const schema: f.TableSchema.Schema = .{ .object = 10, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .int64 } }, .primary_key = &.{1} };
fn basis() !Command.Basis {
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    return .{ .record = .{ .scope = scope, .object = 10, .revision = 1, .name = try c.TableMetadata.Name.init("items"), .schema = .{ .id = 1, .spec = try c.station.Publication.Digest.of(c.station.TablePages.schema_format, try schema.encode(&bytes)) }, .schema_fingerprint = try schema.fingerprint(), .principal = 17, .operation = 1, .admitted_input = 1 }, .schema = schema };
}
fn roundtrip(allocator: std.mem.Allocator, bytes: []const u8, source: ?Command.Basis) !void {
    var owned = try Command.decode(allocator, bytes, source);
    defer owned.deinit();
    var output: [8192]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try Command.encode(allocator, owned.body, &output));
}
fn check(body: Command.Body, source: ?Command.Basis) !void {
    var output: [8192]u8 = undefined;
    const bytes = try Command.encode(t.allocator, body, &output);
    try t.expectEqualDeep(body.header, try Command.inspect(bytes));
    try t.checkAllAllocationFailures(t.allocator, roundtrip, .{ bytes, source });
    for (0..bytes.len) |len| {
        if (Command.decode(t.allocator, bytes[0..len], source)) |value| {
            var owned = value;
            owned.deinit();
            return error.AcceptedTruncation;
        } else |_| {}
    }
    output[bytes.len] = 0;
    try t.expectError(error.InvalidTableCommand, Command.decode(t.allocator, output[0 .. bytes.len + 1], source));
}
test "typed command CREATE ALTER RENAME DROP roundtrip exact schema intent" {
    const source = try basis();
    const creation: c.TableDdlRequest = .{ .principal = 17, .operation = std.math.maxInt(u64), .object = 10, .expected_revision = 0, .name = source.record.name, .action = .{ .create = .{ .schema = schema, .if_not_exists = true } } };
    try check(try Command.fromDdl(scope, 3, creation, null), null);
    for ([_][]const u8{
        "ALTER TABLE items ADD COLUMN name VARCHAR(12) DEFAULT 'seed'",
        "ALTER TABLE items DROP COLUMN value",
        "ALTER TABLE items RENAME COLUMN value TO amount",
        "ALTER TABLE items ALTER COLUMN value SET DEFAULT 200",
        "ALTER TABLE items ALTER COLUMN value DROP DEFAULT",
        "ALTER TABLE items ALTER COLUMN value SET NOT NULL",
        "ALTER TABLE items ALTER COLUMN value DROP NOT NULL",
        "ALTER TABLE items ALTER COLUMN value TYPE INT128",
        "ALTER TABLE items RENAME TO renamed",
    }) |sql| {
        var compiled = try f.TableDdl.compile(t.allocator, sql, schema, null);
        defer compiled.deinit();
        const alter = compiled.statement.alter;
        const request: c.TableDdlRequest = .{ .principal = 17, .operation = 2, .object = 10, .expected_revision = 1, .name = source.record.name, .action = switch (alter.action) {
            .columns => |change| .{ .alter = .{ .schema = schema, .change = change } },
            .rename_table => |name| .{ .rename = try c.TableMetadata.Name.init(name) },
        } };
        try check(try Command.fromDdl(scope, 3, request, source.record), source);
    }
    const drop: c.TableDdlRequest = .{ .principal = 17, .operation = 3, .object = 10, .expected_revision = 1, .name = source.record.name, .action = .{ .drop = .{ .if_exists = true } } };
    try check(try Command.fromDdl(scope, 3, drop, source.record), source);
    var absent = drop;
    absent.object = 0;
    absent.expected_revision = 0;
    try check(try Command.fromDdl(scope, 3, absent, null), null);
}
test "typed native point and three-row commands fit one frame and bind original metadata" {
    const source = try basis();
    for ([_][]const u8{ "INSERT INTO items VALUES (1, 100)", "INSERT INTO items VALUES (1, 100), (2, 200), (3, 300)", "UPDATE items SET value = 200 WHERE id = 1", "DELETE FROM items WHERE id = 1" }) |sql| {
        var compiled = try f.TableDml.compile(t.allocator, sql, "items", schema, null);
        defer compiled.deinit();
        const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = 1, .spec = try source.record.spec() }, .plan = compiled.plan };
        const body = try Command.fromDml(scope, 3, request, source.record);
        var buffer: [c.station.Frame.max_payload]u8 = undefined;
        const bytes = try Command.encode(t.allocator, body, &buffer);
        var owned = try Command.decode(t.allocator, bytes, source);
        defer owned.deinit();
        try t.expectEqualSlices(u8, &try request.binding(t.allocator, scope), &try owned.body.request.dml.binding(t.allocator, scope));
        try t.checkAllAllocationFailures(t.allocator, roundtrip, .{ bytes, @as(?Command.Basis, source) });
        var changed = source;
        changed.record.name = try c.TableMetadata.Name.init("replacement");
        try t.expectError(error.CatalogDefinitionChanged, Command.decode(t.allocator, bytes, changed));
        changed = source;
        changed.schema.?.revision += 1;
        try t.expectError(error.TableSchemaChanged, Command.decode(t.allocator, bytes, changed));
        var old_envelope: [8192]u8 = undefined;
        @memcpy(old_envelope[0..Command.header_bytes], bytes[0..Command.header_bytes]);
        const old_payload = try f.TableDmlCodec.encode(t.allocator, request.plan, old_envelope[Command.header_bytes..]);
        try t.expectError(error.InvalidMutationPlan, Command.decode(t.allocator, old_envelope[0 .. Command.header_bytes + old_payload.len], source));
        var truncated: usize = Command.header_bytes;
        while (truncated < bytes.len) : (truncated += 1) {
            if (Command.decode(t.allocator, bytes[0..truncated], source)) |value| {
                var accepted = value;
                accepted.deinit();
                return error.AcceptedTruncation;
            } else |_| {}
        }
        var wrong_definition = buffer;
        wrong_definition[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, Command.decode(t.allocator, wrong_definition[0..bytes.len], source));
    }
}

test "independent command header binds full-width identities and exact metadata bytes" {
    const Fixture = struct { record_hex: []const u8, command_header_hex: []const u8, rename_command_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-metadata.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var record_buffer: [c.TableMetadata.max_bytes]u8 = undefined;
    var command_buffer: [512]u8 = undefined;
    var header_buffer: [Command.header_bytes]u8 = undefined;
    const record = try c.TableMetadata.Record.decode(try std.fmt.hexToBytes(&record_buffer, parsed.value.record_hex));
    const bytes = try std.fmt.hexToBytes(&command_buffer, parsed.value.rename_command_hex);
    const source: Command.Basis = .{ .record = record };
    var owned = try Command.decode(t.allocator, bytes, source);
    defer owned.deinit();
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&header_buffer, parsed.value.command_header_hex), &try owned.body.header.encode());
    try t.expectEqual(std.math.maxInt(u64), owned.body.header.operation);
    try t.expectEqualStrings("人々", owned.body.request.ddl.action.rename.slice());
    var output: [512]u8 = undefined;
    try t.expectEqualSlices(u8, bytes, try Command.encode(t.allocator, owned.body, &output));
    @memset(&command_buffer, 0);
    try t.expectEqualStrings("人々", owned.body.request.ddl.action.rename.slice());
    var foreign = source;
    foreign.record.scope.catalog -= 1;
    try t.expectError(error.CatalogDefinitionChanged, Command.decode(t.allocator, output[0..bytes.len], foreign));
}
