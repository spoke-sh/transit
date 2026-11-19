const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");
const d = c.CatalogDiff;
const compiler = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
fn desired(a: std.mem.Allocator, basis: []const u8, version: []const u8, body: []const u8) !*c.Product {
    const source = try std.fmt.allocPrint(a, "CREATE MIGRATION TARGET default FROM {s} FOR DATABASE 'transit' SCHEMA 'public' VERSION '{s}' NAME 'schema' AS BEGIN {s} END;", .{ basis, version, body });
    defer a.free(source);
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(a, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "test" }, &diagnostic);
}
const initial = "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial');";
const additive = "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial', extra TEXT DEFAULT 'a,b', amount BIGINT NOT NULL DEFAULT 7);";
test "synthesized migration filenames preserve the version at the native boundary" {
    const a = std.testing.allocator;
    const path = try d.fileName(a, "2026.11.15", "add_note");
    defer a.free(path);
    try std.testing.expectEqualStrings("2026.11.15-add_note.sql", path);
    for ([_][]const u8{ "0001_patch", "_0001", "0001-patch" }) |version| {
        try std.testing.expectError(error.InvalidMigrationVersion, d.fileName(a, version, "schema"));
    }
}
test "migration synthesis preserves history projects additions and emits zero unchanged steps" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(std.testing.allocator, "EMPTY", "0001", initial);
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    try std.testing.expectEqual(1, first.steps);
    const two = try desired(std.testing.allocator, "'prior/basis.json'", "0002", additive);
    defer two.deinit();
    const second = try d.build(a, two, first.basis, first.files, compiler, &context);
    try std.testing.expectEqual(2, second.steps);
    try std.testing.expectEqualStrings(first.files[0].sql, second.files[0].sql);
    try std.testing.expect(std.mem.indexOf(u8, second.sql, "ADD COLUMN") != null);
    try std.testing.expect(std.mem.indexOf(u8, second.sql, "'a,b'") != null);
    const same = try desired(std.testing.allocator, "'prior/basis.json'", "0003", additive);
    defer same.deinit();
    const unchanged = try d.build(a, same, second.basis, second.files, compiler, &context);
    try std.testing.expectEqual(0, unchanged.steps);
    try std.testing.expectEqual(2, unchanged.files.len);
    const fresh = try desired(std.testing.allocator, "EMPTY", "0001", additive);
    defer fresh.deinit();
    const fresh_result = try d.build(a, fresh, null, &.{}, compiler, &context);
    try std.testing.expectEqualSlices(u8, &fresh_result.basis.tables[0].definition_digest, &second.basis.tables[0].definition_digest);
    const repeated = try d.build(a, two, first.basis, first.files, compiler, &context);
    try std.testing.expectEqualStrings(second.sql, repeated.sql);
}
test "migration synthesis refuses destructive ambiguous and validation requiring changes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(std.testing.allocator, "EMPTY", "0001", initial);
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    for ([_][]const u8{
        "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY);",
        "CREATE PUBLIC TABLE renamed (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial');",
        "CREATE PUBLIC TABLE t (id TEXT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial');",
        "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'changed');",
        "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial', required TEXT NOT NULL);",
        "CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY, note TEXT NOT NULL DEFAULT 'initial', CHECK (id > 0));",
    }) |body| {
        const next = try desired(std.testing.allocator, "'prior/basis.json'", "0002", body);
        defer next.deinit();
        try std.testing.expectError(error.MigrationTransformRequired, d.build(a, next, first.basis, first.files, compiler, &context));
        try std.testing.expectEqualStrings("t", context.name.?);
    }
}
test "migration basis rejects changed history foreign definitions duplicates and stale versions" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(std.testing.allocator, "EMPTY", "0001", initial);
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    const next = try desired(std.testing.allocator, "'prior/basis.json'", "0002", additive);
    defer next.deinit();
    const changed: d.File = .{ .path = first.files[0].path, .sql = "CREATE TABLE t(id TEXT);" };
    try std.testing.expectError(error.MigrationHistoryChanged, d.build(a, next, first.basis, &.{changed}, compiler, &context));
    var basis = first.basis;
    basis.definition = "foreign";
    try std.testing.expectError(error.IncompatibleMigrationBasis, d.build(a, next, basis, first.files, compiler, &context));
    basis = first.basis;
    basis.database = "other";
    try std.testing.expectError(error.MigrationNamespaceMismatch, d.build(a, next, basis, first.files, compiler, &context));
    basis = first.basis;
    var table = basis.tables[0];
    table.definition_digest[0] ^= 1;
    basis.tables = &.{table};
    try std.testing.expectError(error.MigrationBasisMismatch, d.build(a, next, basis, first.files, compiler, &context));
    const stale = try desired(std.testing.allocator, "'prior/basis.json'", "0001", initial);
    defer stale.deinit();
    try std.testing.expectError(error.MigrationVersionOrder, d.build(a, stale, first.basis, first.files, compiler, &context));
    try std.testing.expectError(error.MissingMigrationBasis, d.build(a, next, null, &.{}, compiler, &context));
}
test "migration history cannot smuggle data transforms or source-only semantics" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(std.testing.allocator, "EMPTY", "0001", initial ++ " INSERT INTO t VALUES (1, 'x');");
    defer one.deinit();
    try std.testing.expectError(error.UnsupportedMigrationDefinition, d.build(a, one, null, &.{}, compiler, &context));
}
test "migration synthesis preserves the existing 64 step version bound" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(std.testing.allocator, "EMPTY", "0001", "CREATE PUBLIC TABLE t(id BIGINT PRIMARY KEY);");
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    for ([_]usize{ 64, 65 }) |count| {
        var body: std.Io.Writer.Allocating = .init(a);
        try body.writer.writeAll("CREATE PUBLIC TABLE t(id BIGINT PRIMARY KEY");
        for (0..count) |i| try body.writer.print(", field_{d} TEXT", .{i});
        try body.writer.writeAll(");");
        const next = try desired(std.testing.allocator, "'basis.json'", "0002", body.written());
        defer next.deinit();
        if (count == 64) {
            const result = try d.build(a, next, first.basis, first.files, compiler, &context);
            try std.testing.expectEqual(64, result.steps);
        } else try std.testing.expectError(error.MigrationStepLimit, d.build(a, next, first.basis, first.files, compiler, &context));
    }
}
test "migration synthesis refuses nominal identity changes with identical physical types" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const source = "CREATE DOMAIN Id AS BIGINT IDENTITY 'example.first'; CREATE MODULE Rows(ty TYPE) AS BEGIN CREATE PUBLIC TABLE t(id $ty PRIMARY KEY); END; CREATE MIGRATION TARGET default FROM EMPTY FOR DATABASE 'transit' SCHEMA 'public' VERSION '0001' NAME 'initial' AS BEGIN USE Rows(TYPE Id); END;";
    var diagnostic: ?p.Diagnostic = null;
    const one = try c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "test" }, &diagnostic);
    defer one.deinit();
    var context: c.SourceDiagnostic.Context = .{};
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    var changed = try std.mem.replaceOwned(u8, a, source, "example.first", "example.second");
    changed = try std.mem.replaceOwned(u8, a, changed, "FROM EMPTY", "FROM 'basis.json'");
    changed = try std.mem.replaceOwned(u8, a, changed, "'0001'", "'0002'");
    const two = try c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = changed }}, .{ .compiler_revision = "test" }, &diagnostic);
    defer two.deinit();
    try std.testing.expectError(error.MigrationTransformRequired, d.build(a, two, first.basis, first.files, compiler, &context));
}
fn allocationFailures(parent: std.mem.Allocator) !void {
    var arena: std.heap.ArenaAllocator = .init(parent);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    const one = try desired(parent, "EMPTY", "0001", initial);
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    const two = try desired(parent, "'basis.json'", "0002", additive);
    defer two.deinit();
    _ = try d.build(a, two, first.basis, first.files, compiler, &context);
}
test "migration allocation failures leave no partial result" {
    // Arena growth may reuse an in-place resize depending on allocator layout.
    // Deny resizing for this sweep so each injected allocation is reproducible.
    var baseline: std.testing.FailingAllocator = .init(std.testing.allocator, .{ .resize_fail_index = 0 });
    try allocationFailures(baseline.allocator());
    for (0..baseline.alloc_index) |i| {
        var failing: std.testing.FailingAllocator = .init(std.testing.allocator, .{ .resize_fail_index = 0, .fail_index = i });
        try std.testing.expectError(error.OutOfMemory, allocationFailures(failing.allocator()));
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

test "multi-schema AS MIGRATIONS OF synthesizes CREATE SCHEMA NOT ENFORCED foreign keys and qualified ADD COLUMN" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var context: c.SourceDiagnostic.Context = .{};
    var diagnostic: ?p.Diagnostic = null;

    const v1_source =
        \\CREATE DOMAIN EnvId AS UUID IDENTITY 'platform.env_id';
        \\EXPORT MODULE app(t_schema SCHEMA_BINDING, n_schema SCHEMA_BINDING, env_ty TYPE) AS BEGIN
        \\  BIND SCHEMA tenancy TO t_schema;
        \\  BIND SCHEMA networking TO n_schema;
        \\  CREATE SCHEMA tenancy;
        \\  CREATE SCHEMA networking;
        \\  CREATE PUBLIC TABLE tenancy.environments (id $env_ty PRIMARY KEY, label TEXT NOT NULL);
        \\  CREATE PUBLIC TABLE networking.networks (
        \\    id UUID PRIMARY KEY,
        \\    env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED
        \\  );
        \\END;
        \\LET control = USE MODULE app(
        \\  t_schema => SCHEMA_BINDING('tenancy'),
        \\  n_schema => SCHEMA_BINDING('networking'),
        \\  env_ty => TYPE EnvId
        \\);
        \\EXPORT TARGET initial_migrations AS MIGRATIONS OF control FROM EMPTY VERSION '0001-platform';
    ;
    const one = try c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = v1_source }}, .{ .compiler_revision = "mig-multi", .target = "initial_migrations" }, &diagnostic);
    defer one.deinit();
    const first = try d.build(a, one, null, &.{}, compiler, &context);
    try std.testing.expectEqual(@as(usize, 4), first.steps);
    try std.testing.expectEqualStrings("0001-platform.sql", first.files[0].path);
    try std.testing.expectEqual(@as(usize, 3), first.basis.schemas.len);
    try std.testing.expect(std.mem.indexOf(u8, first.sql, "CREATE SCHEMA \"tenancy\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, first.sql, "REFERENCES \"tenancy\" . ENVIRONMENTS") != null);

    // v2 adds a trailing nullable column to tenancy.environments (parent of FK!) AND a new schema 'deployments' + table
    const v2_source =
        \\CREATE DOMAIN EnvId AS UUID IDENTITY 'platform.env_id';
        \\EXPORT MODULE app(t_schema SCHEMA_BINDING, n_schema SCHEMA_BINDING, d_schema SCHEMA_BINDING, env_ty TYPE) AS BEGIN
        \\  BIND SCHEMA tenancy TO t_schema;
        \\  BIND SCHEMA networking TO n_schema;
        \\  BIND SCHEMA deployments TO d_schema;
        \\  CREATE SCHEMA tenancy;
        \\  CREATE SCHEMA networking;
        \\  CREATE SCHEMA deployments;
        \\  CREATE PUBLIC TABLE tenancy.environments (id $env_ty PRIMARY KEY, label TEXT NOT NULL, region TEXT);
        \\  CREATE PUBLIC TABLE networking.networks (
        \\    id UUID PRIMARY KEY,
        \\    env_id $env_ty NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT NOT ENFORCED
        \\  );
        \\  CREATE PUBLIC TABLE deployments.instances (
        \\    id UUID PRIMARY KEY,
        \\    net_id UUID NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT NOT ENFORCED
        \\  );
        \\END;
        \\LET control = USE MODULE app(
        \\  t_schema => SCHEMA_BINDING('tenancy'),
        \\  n_schema => SCHEMA_BINDING('networking'),
        \\  d_schema => SCHEMA_BINDING('deployments'),
        \\  env_ty => TYPE EnvId
        \\);
        \\EXPORT TARGET next_migrations AS MIGRATIONS OF control FROM 'prior/basis.json' VERSION '0002-deployments';
    ;
    const two = try c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = v2_source }}, .{ .compiler_revision = "mig-multi", .target = "next_migrations" }, &diagnostic);
    defer two.deinit();
    const second = try d.build(a, two, first.basis, first.files, compiler, &context);
    try std.testing.expectEqual(@as(usize, 3), second.steps);
    try std.testing.expectEqualStrings("0002-deployments.sql", second.files[1].path);
    try std.testing.expect(std.mem.indexOf(u8, second.sql, "CREATE SCHEMA \"deployments\";") != null);
    try std.testing.expect(std.mem.indexOf(u8, second.sql, "ALTER TABLE \"tenancy\".\"environments\" ADD COLUMN REGION TEXT;") != null);
    try std.testing.expect(std.mem.indexOf(u8, second.sql, "CREATE TABLE \"deployments\" . INSTANCES") != null);
}
