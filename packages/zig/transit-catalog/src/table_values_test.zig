const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const v = c.TableValues;
const typed = c.TableTyped;
const f = c.fuze;
const connection: c.TableClient.Connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .principal = 17 };
const schema: f.TableSchema.Schema = .{ .object = std.math.maxInt(u64), .revision = 1, .next_column = 4, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int32, .nullable = false },
    .{ .id = 2, .name = "name", .type = .utf8, .default = .{ .value = .{ .atom = .{ .bytes = "default" } } }, .max_characters = 200 },
    .{ .id = 3, .name = "active", .type = .boolean, .default = .{ .value = .{ .atom = .{ .boolean = true } } } },
}, .primary_key = &.{1} };
fn definition(allocator: std.mem.Allocator) !c.TableCatalog.Definition {
    var buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const ref: c.station.TablePages.Reference = .{ .id = 1, .spec = try c.station.Publication.Digest.of(c.station.TablePages.schema_format, try schema.encode(&buffer)) };
    return .{ .metadata = .{ .scope = connection.scope, .object = schema.object, .revision = 1, .name = try c.TableMetadata.Name.init("people"), .schema = ref, .schema_fingerprint = try schema.fingerprint(), .principal = 17, .operation = 1, .admitted_input = 10 }, .head = .{ .resource = 7, .object = schema.object, .revision = 1, .schema = ref, .next_record = 2 }, .schema = try schema.clone(allocator) };
}
fn basis(allocator: std.mem.Allocator) !v.Basis {
    return .{ .object = "18446744073709551615", .revision = "1", .schema_fingerprint = try v.hex(allocator, &try schema.fingerprint()) };
}
fn number(column: []const u8, value: []const u8) typed.Assignment {
    return .{ .column = column, .value = .{ .cell = .{ .value = .{ .atom = .{ .signed = value } } } } };
}
test "neutral general catalog identities rights names and pages preserve full widths and ownership" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const scope = try v.Scope.foreign(allocator, connection.scope);
    try t.expectEqualDeep(connection.scope, try scope.native());
    try t.expectEqualDeep(connection, try (v.Connection{ .scope = scope, .owner = 3, .principal = 17 }).native());
    for ([_][]const u8{ "", "01", "-1", "+1", "18446744073709551616", "123456789012345678901" }) |invalid| try t.expectError(error.InvalidCatalogInteger, v.unsigned(invalid));
    var native_policy = try c.TableCatalogRecords.Policy.administrator(connection.scope, 17);
    native_policy.revision = std.math.maxInt(u64);
    native_policy.read = false;
    const policy = try v.Policy.foreign(allocator, native_policy);
    try t.expectEqualDeep(native_policy, try policy.native());
    try t.expectEqualDeep(native_policy, (try (v.PolicyChange{ .expected_revision = "18446744073709551614", .policy = policy }).native()).policy);
    const config: c.TableCatalogRecords.Configuration = .{ .scope = connection.scope, .owner = 3, .administrator = 17, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = std.math.maxInt(u64), .staging_records = 1000 } };
    try t.expectEqualDeep(config, try (try v.Configuration.foreign(allocator, config)).native());
    const dependency = try (v.DependencyChange{ .scope = scope, .object = "18446744073709551615", .identity = "18446744073709551615", .owner = 3, .kind = .history, .present = true }).native();
    try t.expect(!dependency.dependency.restricts());
    var current = try definition(t.allocator);
    defer current.deinit();
    current.metadata.name = try c.TableMetadata.Name.init("人々 with spaces");
    var page: c.TableCatalog.Page = .{ .resource_revision = 10, .next = .{ .scope = connection.scope, .resource_revision = 10, .after_object = schema.object } };
    page.entries[0] = .{ .metadata = current.metadata, .head = current.head };
    const output = try v.Page.foreign(allocator, page);
    try t.expectEqualDeep(try current.metadata.spec(), output.entries[0].?.metadata.commitment);
    const described = try v.Definition.foreign(&arena, current);
    try t.expectEqualDeep(output.entries[0].?.metadata.commitment, described.metadata.commitment);
    var renamed = current.metadata;
    renamed.name = try c.TableMetadata.Name.init("renamed");
    const changed = try v.Metadata.foreign(allocator, renamed);
    try t.expect(!std.mem.eql(u8, &changed.commitment.digest, &described.metadata.commitment.digest));
    var corrupt = page;
    corrupt.entries[1] = corrupt.entries[0];
    try t.expectError(error.InvalidCatalogPage, v.Page.foreign(allocator, corrupt));
    corrupt = page;
    corrupt.entries[1] = corrupt.entries[0];
    corrupt.entries[0] = null;
    try t.expectError(error.InvalidCatalogPage, v.Page.foreign(allocator, corrupt));
    corrupt = page;
    corrupt.entries[0].?.head.object = 42;
    try t.expectError(error.CatalogSourceChanged, v.Page.foreign(allocator, corrupt));
    // An empty page may scan only initializing/retired objects and continue.
    corrupt = page;
    corrupt.entries = @splat(null);
    _ = try v.Page.foreign(allocator, corrupt);
    @memset(&page.entries[0].?.metadata.name.data, 0);
    try t.expectEqualStrings("人々 with spaces", output.entries[0].?.metadata.name);
    try t.expectEqualDeep(page.next.?, try output.next.?.native());
    var invalid_cursor = output.next.?;
    invalid_cursor.after_object = "0";
    try t.expectError(error.InvalidCatalogPage, invalid_cursor.native());
    const bytes = try c.protocol.Json.valueAlloc(allocator, output);
    const decoded = try c.protocol.Json.parseFromSlice(v.Page, allocator, bytes);
    try t.expectEqualDeep(output, decoded.value);
}
test "typed CREATE and SQL compile to the same saved intent" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const request: typed.Request = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .operation = "2", .namespace = "18446744073709551615" }, .name = "people", .action = .{ .create = .{ .schema = try f.TableSchemaJson.foreign(&arena, schema), .if_not_exists = false } } };
    var intent = try typed.intent(t.allocator, connection, request, null);
    defer intent.deinit();
    var client: c.TableClient = .{ .transport = undefined, .connection = connection, .key = try c.protocol.Ed25519.KeyPair.generateDeterministic(@splat(1)) };
    var compiled = try client.compile(t.allocator, "CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) DEFAULT 'default', active BOOLEAN DEFAULT TRUE)", .{ .operation = 2, .namespace = std.math.maxInt(u64), .create_object = schema.object }, null);
    defer compiled.deinit();
    try t.expectEqualSlices(u8, compiled.bytes, intent.bytes);
}
test "typed DML shares defaults constraints finite predicates and point qualification with SQL" {
    var current = try definition(t.allocator);
    defer current.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const key: typed.Instruction = .{ .atom = .{ .compare = .{ .column = "1", .op = .eq, .value = .{ .signed = "7" } } } };
    const state: typed.Instruction = .{ .atom = .{ .state = .{ .column = "2", .value = .null } } };
    const assign: typed.Assignment = .{ .column = "2", .value = .{ .cell = .{ .value = .{ .atom = .{ .utf8 = "人々" } } } } };
    for ([_]struct { sql: []const u8, mutation: typed.Mutation, route: c.station.TableWrite.Status.Route }{
        .{ .sql = "INSERT INTO people (name,id) VALUES ('人々',7)", .mutation = .{ .action = .{ .insert = &.{&.{ assign, number("1", "7") }} }, .predicate = null }, .route = .point },
        .{ .sql = "INSERT INTO people (id,name) VALUES (7,DEFAULT),(8,NULL)", .mutation = .{ .action = .{ .insert = &.{ &.{number("1", "7")}, &.{ number("1", "8"), .{ .column = "2", .value = .{ .cell = .null } } } } }, .predicate = null }, .route = .statement },
        .{ .sql = "UPDATE people SET name='人々' WHERE id=7", .mutation = .{ .action = .{ .update = &.{assign} }, .predicate = &.{key} }, .route = .point },
        .{ .sql = "UPDATE people SET name=DEFAULT WHERE id=7 AND name IS NULL", .mutation = .{ .action = .{ .update = &.{.{ .column = "2", .value = .default }} }, .predicate = &.{ key, state, .conjunction } }, .route = .statement },
        .{ .sql = "DELETE FROM people WHERE NOT id=7 OR name IS NULL", .mutation = .{ .action = .delete, .predicate = &.{ key, .negate, state, .disjunction } }, .route = .statement },
        .{ .sql = "DELETE FROM people", .mutation = .{ .action = .delete, .predicate = null }, .route = .statement },
    }) |case| {
        var sql = try f.TableDml.compile(t.allocator, case.sql, "people", schema, null);
        defer sql.deinit();
        const request: typed.Request = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .operation = "2", .namespace = "1000" }, .name = "people", .action = .{ .mutate = .{ .basis = try basis(arena.allocator()), .mutation = case.mutation } } };
        var intent = try typed.intent(t.allocator, connection, request, current);
        defer intent.deinit();
        const sql_request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = 1, .spec = try current.metadata.spec() }, .plan = sql.plan };
        var expected = try c.TableIntent.create(t.allocator, try c.TableCommand.fromDml(connection.scope, 3, sql_request, current.metadata), 1000);
        defer expected.deinit();
        try t.expectEqualSlices(u8, expected.bytes, intent.bytes);
        try t.expectEqual(case.route, intent.identity.dml.route);
    }
}
test "typed schema changes share all selected evolution checks" {
    var current = try definition(t.allocator);
    defer current.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    for ([_]typed.Change{
        .{ .add = .{ .name = "tags", .type = .{ .list = .{ .type = &.int64, .nullable = true } }, .nullable = true, .default = .{ .value = .{ .list = &.{.null} } }, .max_characters = null } },
        .{ .drop = "3" },
        .{ .rename = .{ .column = "2", .name = "full name" } },
        .{ .default = .{ .column = "2", .value = null } },
        .{ .default = .{ .column = "2", .value = .null } },
        .{ .nullable = .{ .column = "2", .value = false } },
        .{ .type = .{ .column = "1", .type = .int64, .max_characters = null } },
    }) |value| {
        const request: typed.Request = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .operation = "2", .namespace = "1000" }, .name = "people", .action = .{ .alter = .{ .basis = try basis(arena.allocator()), .change = value } } };
        var intent = try typed.intent(t.allocator, connection, request, current);
        defer intent.deinit();
        var restored = try intent.command(t.allocator);
        defer restored.deinit();
        try t.expect(restored.body.request.ddl.action == .alter);
    }
    try t.expectError(error.PrimaryKeyColumnRequired, typed.change(&arena, schema, .{ .drop = "1" }));
    try t.expectError(error.NullablePrimaryKey, typed.change(&arena, schema, .{ .nullable = .{ .column = "1", .value = true } }));
    try t.expectError(error.UnsupportedSchemaConversion, typed.change(&arena, schema, .{ .type = .{ .column = "1", .type = .utf8, .max_characters = null } }));
}
test "typed requests refuse stale schema object name and omitted DROP basis" {
    var current = try definition(t.allocator);
    defer current.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var request: typed.Request = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .operation = "2", .namespace = "1000" }, .name = "people", .action = .{ .rename = .{ .basis = try basis(arena.allocator()), .name = "persons" } } };
    var original = try typed.intent(t.allocator, connection, request, current);
    defer original.deinit();
    try t.expectEqual(.rename, original.header.kind);
    for (0..4) |which| {
        var stale = request;
        switch (which) {
            0 => stale.action.rename.basis.object = "42",
            1 => stale.action.rename.basis.revision = "2",
            2 => stale.action.rename.basis.schema_fingerprint = "0000000000000000000000000000000000000000000000000000000000000000",
            3 => stale.name = "replacement",
            else => unreachable,
        }
        try t.expectError(error.CatalogDefinitionChanged, typed.intent(t.allocator, connection, stale, current));
    }
    request.action = .{ .drop = .{ .basis = null, .if_exists = true } };
    try t.expectError(error.CatalogDefinitionChanged, typed.intent(t.allocator, connection, request, current));
    var missing = try typed.intent(t.allocator, connection, request, null);
    defer missing.deinit();
    try t.expectEqual(@as(u64, 0), missing.header.object);
    request.action.drop.basis = try basis(arena.allocator());
    try t.expectError(error.TableNotFound, typed.intent(t.allocator, connection, request, null));
    var found = try typed.intent(t.allocator, connection, request, current);
    defer found.deinit();
    try t.expectEqual(schema.object, found.header.object);
}
test "typed rows accept large nested values without SQL text conversion and reject storage states" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const typed_schema: f.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "nested", .type = .{ .list = .{ .type = &.binary, .nullable = true } } }} };
    const text = try arena.allocator().alloc(u8, 128 * 1024);
    @memset(text, 'a');
    const value: typed.Assignment = .{ .column = "1", .value = .{ .cell = .{ .value = .{ .list = &.{ .null, .{ .value = .{ .atom = .{ .binary = text } } } } } } } };
    const result = try typed.plan(&arena, typed_schema, "nested", .{ .action = .{ .insert = &.{&.{value}} }, .predicate = null });
    try t.expectEqual(@as(usize, 65536), result.action.insert[0][0].value.list[1].value.atom.bytes.len);
    try t.expectEqual(@as(u8, 0xaa), result.action.insert[0][0].value.list[1].value.atom.bytes[0]);
    for ([_]Cell{ .missing, .{ .type_error = .binary } }) |invalid| {
        const bad: typed.Assignment = .{ .column = "1", .value = .{ .cell = invalid } };
        if (typed.plan(&arena, typed_schema, "nested", .{ .action = .{ .insert = &.{&.{bad}} }, .predicate = null })) |_| return error.TestUnexpectedResult else |_| {}
    }
}
const Cell = f.LogicalJson.Cell;
test "typed conversion rejects aggregate payloads before allocating the complete input" {
    const hex = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(hex);
    @memset(hex, 'a');
    const large: typed.Assignment = .{ .column = "1", .value = .{ .cell = .{ .value = .{ .atom = .{ .binary = hex } } } } };
    const binary_schema: f.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "data", .type = .binary }} };
    const rows: [f.TableDml.max_rows][]const typed.Assignment = @splat(&.{large});
    var tracker: t.FailingAllocator = .init(t.allocator, .{ .resize_fail_index = 0 });
    var arena: std.heap.ArenaAllocator = .init(tracker.allocator());
    defer arena.deinit();
    // The input describes 512 MiB of decoded data. Admission stops near the
    // four-MiB intent limit, including geometric arena allocation overhead.
    try t.expectError(error.MutationBatchTooLarge, typed.plan(&arena, binary_schema, "data", .{ .action = .{ .insert = &rows }, .predicate = null }));
    try t.expect(tracker.allocated_bytes < 32 * 1024 * 1024);
    _ = arena.reset(.free_all);
    try t.expectEqual(tracker.allocated_bytes, tracker.freed_bytes);
    // Shared defaults do not allocate per row, but their repeated canonical
    // payloads still count toward complete intent admission.
    const text = try t.allocator.alloc(u8, 32768);
    defer t.allocator.free(text);
    @memset(text, 'x');
    const default_schema: f.TableSchema.Schema = .{ .object = 101, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "data", .type = .utf8, .default = .{ .value = .{ .atom = .{ .bytes = text } } } }} };
    const omitted: [f.TableDml.max_rows][]const typed.Assignment = @splat(&.{});
    try t.expectError(error.MutationBatchTooLarge, typed.plan(&arena, default_schema, "data", .{ .action = .{ .insert = &omitted }, .predicate = null }));
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var current = try definition(allocator);
    defer current.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const request: typed.Request = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .operation = "2", .namespace = "1000" }, .name = "people", .action = .{ .mutate = .{ .basis = try basis(arena.allocator()), .mutation = .{ .action = .{ .insert = &.{&.{number("1", "7")}} }, .predicate = null } } } };
    var intent = try typed.intent(allocator, connection, request, current);
    defer intent.deinit();
    var restored = try intent.command(allocator);
    defer restored.deinit();
    try t.expectEqualStrings("default", restored.body.request.dml.plan.action.insert[0][1].value.atom.bytes);
}
test "typed neutral admission cleans partial conversions under every allocation failure" {
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), allocationSchedule, .{});
}
