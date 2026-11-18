const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");

fn compile(text: []const u8) !*c.Product {
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "source-syntax-test" }, &diagnostic);
}
test "structural checking covers unused bodies and unselected branches" {
    const valid = "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;";
    const result = try compile("CREATE MODULE unused() AS BEGIN SELECT * FROM unknown; END;" ++ valid);
    defer result.deinit();
    try std.testing.expectEqual(1, result.steps.len);
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE MODULE unused() AS BEGIN INSERT INTO unknown VALUES (1,); END;" ++ valid));
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE TARGET default AS BEGIN IF FALSE THEN ASSERT ROWS (SELECT * FROM t) EQUAL ((1,)); END IF; CREATE PUBLIC TABLE t (id BIGINT); END;"));
    try std.testing.expectError(error.UnsupportedBuildStatement, compile("CREATE MODULE unused() AS BEGIN COMMIT; END;" ++ valid));
    try std.testing.expectError(error.InvalidSourceOperand, compile("CREATE MODULE unused() AS BEGIN SELECT * FROM t WHERE id = $1; END;" ++ valid));
}
test "SQL lexical units survive source emission and independent rebind" {
    const result = try compile("CREATE MODULE m(n BIGINT, v TEXT) AS BEGIN CREATE PUBLIC TABLE t (id BIGINT, f FLOAT64, b BYTEA, u UINT64); INSERT INTO t VALUES (-$n, 1.25e-2, X 'abcd', $n); SELECT * FROM t WHERE id != 2; END; CREATE TARGET default AS BEGIN USE m(1, '7'); END;");
    defer result.deinit();
    try std.testing.expectEqual(3, result.steps.len);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "1.25e-2") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "X 'abcd'") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.sql, "!=") != null);
}
test "template diagnostic uses exact UTF8 bytes" {
    const source = "-- 雪\r\nCREATE MODULE m() AS BEGIN INSERT INTO t VALUES ('é',); END;";
    var diagnostic: ?p.Diagnostic = null;
    try std.testing.expectError(error.InvalidSourceTemplate, c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "source-syntax-test" }, &diagnostic));
    const at = std.mem.indexOf(u8, source, ");").?;
    try std.testing.expectEqual(at, try diagnostic.?.location.?.offset.value());
}
test "formatter bounds output and left-associated expression recursion" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var location: usize = 0;
    const text = "CREATE MODULE m() AS BEGIN USE f(-(1), 1 + 2 * 3, (1 + 2) * 3, 1 - (2 - 3)); END;";
    const ast = try c.Syntax.parse(arena.allocator(), text, &location);
    var tiny: [8]u8 = undefined;
    var short: std.Io.Writer = .fixed(&tiny);
    try std.testing.expectError(error.WriteFailed, c.Format.write(text, ast, &short));
    var buffer: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try c.Format.write(text, ast, &writer);
    const again = try c.Syntax.parse(arena.allocator(), writer.buffered(), &location);
    var second: [1024]u8 = undefined;
    var output: std.Io.Writer = .fixed(&second);
    try c.Format.write(writer.buffered(), again, &output);
    try std.testing.expectEqualStrings(writer.buffered(), output.buffered());
    const chain = try std.fmt.allocPrint(arena.allocator(), "CREATE MODULE m() AS BEGIN USE f({s}1); END;", .{try repeat(arena.allocator(), "1 + ", 100)});
    const large = try c.Syntax.parse(arena.allocator(), chain, &location);
    writer = .fixed(&buffer);
    try std.testing.expectError(error.SourceDepthLimit, c.Format.write(chain, large, &writer));
}
test "source byte and structural nesting bounds remain finite" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var offset: usize = 0;
    const text = try a.alloc(u8, 1024 * 1024 + 1);
    @memset(text, ' ');
    _ = try c.Syntax.parse(a, text[0 .. 1024 * 1024], &offset);
    try std.testing.expectError(error.StatementTooLarge, c.Syntax.parse(a, text, &offset));
    const deep = try std.fmt.allocPrint(a, "CREATE MODULE m() AS BEGIN INSERT INTO t VALUES ({s}1{s}); END;", .{ try repeat(a, "LIST(", 65), try repeat(a, ")", 65) });
    try std.testing.expectError(error.SqlNestingTooDeep, c.Syntax.parse(a, deep, &offset));
}

fn repeat(a: std.mem.Allocator, text: []const u8, n: usize) ![]const u8 {
    const bytes = try a.alloc(u8, text.len * n);
    for (0..n) |i| @memcpy(bytes[i * text.len ..][0..text.len], text);
    return bytes;
}

test "diagnostic report captures token spans headlines notes and call frames" {
    const t = std.testing;
    var diagnostic: ?p.Diagnostic = null;
    var report: c.SourceDiagnostic.Report = .{};
    const syntax_src = "CREATE TARGET default BEGIN\n  SELECT * FROM t;\nEND;";
    try t.expectError(error.InvalidSourceSyntax, c.compile(t.allocator, &.{.{ .path = "build.transit", .text = syntax_src }}, .{ .compiler_revision = "source-syntax-test", .report = &report }, &diagnostic));
    try t.expectEqual(@as(u64, 5), try diagnostic.?.location.?.length.value());
    try t.expectEqualStrings("expected 'AS', found 'BEGIN'", report.headline().?);

    const mod_rows =
        \\CREATE PUBLIC DOMAIN MachineId AS BIGINT IDENTITY 'example.machine';
        \\CREATE PUBLIC DOMAIN SiteId AS BIGINT IDENTITY 'example.site';
        \\CREATE PUBLIC MODULE Rows(name IDENTIFIER, id_type TYPE, id SiteId) AS BEGIN
        \\  CREATE PUBLIC TABLE $name (id $id_type NOT NULL PRIMARY KEY);
        \\  INSERT INTO $name VALUES ($id);
        \\END;
    ;
    const mod_mid =
        \\IMPORT rows FROM 'rows.transit';
        \\CREATE PUBLIC MODULE Setup(id rows.SiteId) AS BEGIN
        \\  USE rows.Rows(NAME 'items', TYPE rows.MachineId, id);
        \\END;
    ;
    const entry_src =
        \\IMPORT rows FROM 'rows.transit';
        \\IMPORT mid FROM 'mid.transit';
        \\CREATE TARGET default AS BEGIN
        \\  USE mid.Setup(rows.SiteId(7));
        \\END;
    ;
    try t.expectError(error.SourceDomainMismatch, c.compile(t.allocator, &.{
        .{ .path = "rows.transit", .text = mod_rows },
        .{ .path = "mid.transit", .text = mod_mid },
        .{ .path = "build.transit", .text = entry_src },
    }, .{ .compiler_revision = "source-syntax-test", .report = &report }, &diagnostic));
    try t.expect(std.mem.indexOf(u8, report.headline().?, "domain mismatch") != null);
    try t.expect(std.mem.indexOf(u8, report.headline().?, "example.machine") != null);
    try t.expect(std.mem.indexOf(u8, report.headline().?, "example.site") != null);
    try t.expectEqual(@as(u64, 3), try diagnostic.?.location.?.length.value());
    try t.expectEqual(@as(u8, 2), report.frames_len);
    try t.expectEqualStrings("setup", report.frames[0].name());
    try t.expectEqualStrings("rows", report.frames[1].name());
}

const diamond_workspace_files = [_]c.Source{
    .{
        .path = "build.transit",
        .text =
        \\IMPORT MODULE apps FROM './apps/build.transit';
        \\EXPORT TARGET app_sql = apps.app_sql;
        \\EXPORT TARGET app_migrations = apps.app_migrations;
        \\EXPORT TARGET app_tests = apps.app_tests;
        \\EXPORT DEFAULT TARGET app_sql;
        ,
    },
    .{
        .path = "apps/build.transit",
        .text =
        \\IMPORT MODULE app FROM './app/build.transit';
        \\EXPORT TARGET app_sql = app.sql;
        \\EXPORT TARGET app_migrations = app.migrations;
        \\EXPORT TARGET app_tests = app.tests;
        ,
    },
    .{
        .path = "apps/app/build.transit",
        .text =
        \\IMPORT MODULE tenancy FROM './tenancy/build.transit';
        \\IMPORT MODULE networking FROM './networking/build.transit';
        \\IMPORT MODULE ingress FROM './ingress/build.transit';
        \\
        \\EXPORT MODULE application(
        \\  bindings ROW(
        \\    tenancy SCHEMA_BINDING,
        \\    networking SCHEMA_BINDING
        \\  )
        \\) AS BEGIN
        \\  LET tenancy_mod = USE MODULE tenancy.application(
        \\    schema => bindings.tenancy
        \\  );
        \\  LET net_mod = USE MODULE networking.application(
        \\    schema => bindings.networking,
        \\    tenancy => tenancy_mod
        \\  );
        \\  LET ingress_mod = USE MODULE ingress.application(
        \\    schema => bindings.networking,
        \\    tenancy => tenancy_mod,
        \\    networking => net_mod
        \\  );
        \\END;
        \\
        \\LET control = USE MODULE application(
        \\  bindings => ROW(
        \\    tenancy => SCHEMA_BINDING('tenancy'),
        \\    networking => SCHEMA_BINDING('networking')
        \\  )
        \\);
        \\
        \\EXPORT TARGET sql AS SQL OF control
        \\  INTO '../../.local/build/app/application.sql';
        \\
        \\EXPORT TARGET migrations AS MIGRATIONS OF control
        \\  FROM './releases/init/basis.json'
        \\  FOR DATABASE 'transit' SCHEMA 'public' VERSION '0002' NAME 'diamond'
        \\  INTO '../../.local/build/app/migrations';
        \\
        \\EXPORT TARGET tests AS TESTS OF control
        \\  USING SUITES (
        \\    tenancy.tests,
        \\    './tests/composition.test.transit'
        \\  );
        \\
        \\EXPORT DEFAULT TARGET sql;
        ,
    },
    .{
        .path = "apps/app/shared/helpers.transit",
        .text =
        \\CREATE PUBLIC FUNCTION normalize_label(raw TEXT) RETURNS TEXT AS BEGIN
        \\  RETURN CASE WHEN raw = '' THEN 'unnamed' ELSE raw END;
        \\END;
        ,
    },
    .{
        .path = "apps/app/tenancy/state.transit",
        .text =
        \\CREATE PUBLIC TABLE tenants (id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL);
        ,
    },
    .{
        .path = "apps/app/tenancy/guards.transit",
        .text =
        \\CREATE GUARD require_active_flag(active BOOLEAN) AS BEGIN
        \\  IF NOT active THEN
        \\    REQUIRE FALSE ELSE 'InactiveTenant';
        \\  END IF;
        \\END;
        \\CREATE GUARD require_tenant(tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL), tenant_id BIGINT) AS BEGIN
        \\  LET found = SELECT active FROM tenants_tbl WHERE id = tenant_id;
        \\  REQUIRE found IS NOT NULL ELSE 'MissingTenant';
        \\  CHECK GUARD require_active_flag(found.active);
        \\END;
        ,
    },
    .{
        .path = "apps/app/tenancy/build.transit",
        .text =
        \\EXPORT MODULE application(schema SCHEMA_BINDING) AS BEGIN
        \\  BIND SCHEMA tenancy TO schema;
        \\  DECLARE FROM './state.transit';
        \\  DECLARE FROM './guards.transit';
        \\  EXPORT TABLE tenants;
        \\  EXPORT GUARD require_tenant;
        \\END;
        \\EXPORT TEST SUITE tests FROM './tenancy.test.transit';
        ,
    },
    .{
        .path = "apps/app/tenancy/tenancy.test.transit",
        .text =
        \\TEST 'tenancy table accepts active tenant' USING MODULES (platform) AS BEGIN
        \\  ASSERT COMMAND (INSERT INTO tenants VALUES (1, TRUE, 'acme')) MATCHED 1 CHANGED 1;
        \\  ASSERT ROWS (SELECT id, label FROM tenants) EQUAL ((1, 'acme'));
        \\END;
        ,
    },
    .{
        .path = "apps/app/networking/state.transit",
        .text =
        \\CREATE PUBLIC TABLE networks (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);
        ,
    },
    .{
        .path = "apps/app/networking/procedures.transit",
        .text =
        \\CREATE PROCEDURE attach_network(
        \\  tenants_tbl TABLE(id BIGINT PRIMARY KEY, active BOOLEAN NOT NULL, label TEXT NOT NULL),
        \\  networks_tbl TABLE(id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, label TEXT NOT NULL),
        \\  net_id BIGINT,
        \\  tenant_id BIGINT,
        \\  label TEXT
        \\) RETURNS BIGINT AS BEGIN ATOMIC
        \\  CHECK GUARD tenancy.require_tenant(tenants_tbl, tenant_id);
        \\  INSERT INTO networks_tbl VALUES (net_id, tenant_id, normalize_label(label)) ON CONFLICT (id) DO ASSERT SAME ROW;
        \\  RETURN net_id;
        \\END;
        ,
    },
    .{
        .path = "apps/app/networking/build.transit",
        .text =
        \\IMPORT MODULE helpers FROM '../shared/helpers.transit';
        \\IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';
        \\EXPORT MODULE application(
        \\  schema SCHEMA_BINDING,
        \\  tenancy MODULE OF tenancy_build.application
        \\) AS BEGIN
        \\  BIND SCHEMA networking TO schema;
        \\  USE MODULE helpers;
        \\  USE MODULE tenancy;
        \\  DECLARE FROM './state.transit';
        \\  DECLARE FROM './procedures.transit';
        \\  EXPORT TABLE networks;
        \\  EXPORT PROCEDURE attach_network;
        \\END;
        ,
    },
    .{
        .path = "apps/app/ingress/flow.transit",
        .text =
        \\CREATE PUBLIC QUEUE ingress_requests (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL, label TEXT NOT NULL);
        \\CREATE PUBLIC STREAM ingress_events (id BIGINT NOT NULL, tenant_id BIGINT NOT NULL);
        \\CREATE PUBLIC DATAFLOW process_ingress FROM QUEUE ingress_requests AS req AS BEGIN
        \\  CHECK GUARD require_tenant(tenants, req.tenant_id);
        \\  BEGIN ATOMIC
        \\    LET attached = CALL networking.attach_network(tenancy.tenants, networking.networks, req.id, req.tenant_id, req.label);
        \\    PRODUCE INTO ingress_events VALUES (attached, req.tenant_id);
        \\  END;
        \\END;
        \\AUTHORIZE DATAFLOW process_ingress AS ROLE CURRENT_ROLE;
        \\ACTIVATE DATAFLOW process_ingress;
        ,
    },
    .{
        .path = "apps/app/ingress/build.transit",
        .text =
        \\IMPORT MODULE tenancy_build FROM '../tenancy/build.transit';
        \\IMPORT MODULE networking_build FROM '../networking/build.transit';
        \\EXPORT MODULE application(
        \\  schema SCHEMA_BINDING,
        \\  tenancy MODULE OF tenancy_build.application,
        \\  networking MODULE OF networking_build.application
        \\) AS BEGIN
        \\  BIND SCHEMA ingress TO schema;
        \\  USE MODULE tenancy;
        \\  USE MODULE networking;
        \\  DECLARE FROM './flow.transit';
        \\END;
        ,
    },
    .{
        .path = "apps/app/tests/composition.test.transit",
        .text =
        \\TEST 'diamond composition executes guard and returning procedure once' USING MODULES (platform) AS BEGIN
        \\  ASSERT COMMAND (INSERT INTO tenants VALUES (10, TRUE, 'core')) MATCHED 1 CHANGED 1;
        \\  ENQUEUE INTO ingress_requests VALUES (99, 10, '');
        \\  ASSERT WORKFLOW NAME 'process_ingress' COMPLETED 1 REFUSED 0 WITHIN 5 OBSERVATIONS;
        \\  ASSERT ROWS (SELECT id, tenant_id, label FROM networks) EQUAL ((99, 10, 'unnamed'));
        \\END;
        ,
    },
};

fn diamondAllocations(allocator: std.mem.Allocator) !void {
    var diagnostic: ?p.Diagnostic = null;
    const built = try c.compile(allocator, &diamond_workspace_files, .{
        .compiler_revision = "diamond-test",
        .target_explicit = false,
    }, &diagnostic);
    defer built.deinit();
}

test "diamond module instances fragments delegated targets and suite compositions evaluate deterministically" {
    const t = std.testing;
    var diagnostic: ?p.Diagnostic = null;
    var report: c.SourceDiagnostic.Report = .{};

    // Default build target resolves build.transit -> apps/build.transit -> apps/app/build.transit (sql)
    const built = try c.compile(t.allocator, &diamond_workspace_files, .{
        .compiler_revision = "diamond-test",
        .target_explicit = false,
        .report = &report,
    }, &diagnostic);
    defer built.deinit();
    try t.expectEqualStrings("app_sql", built.selected_target);
    try t.expectEqualStrings(".local/build/app/application.sql", built.declared_output_path.?);
    // tenants (1) + networks (1) + ingress_requests (1) + ingress_events (1) + process_ingress (1) + authorize (1) + activate (1) = 7 steps!
    // Critically, tenants and networks are emitted ONCE across the diamond DAG.
    try t.expectEqual(@as(usize, 7), built.steps.len);
    try t.expectEqualStrings("root/apps/app/tenancy/state.transit", built.steps[0].definition.source.?.slice());
    try t.expectEqualStrings("root/apps/app/networking/state.transit", built.steps[1].definition.source.?.slice());
    try t.expectEqualStrings("root/apps/app/ingress/flow.transit", built.steps[4].definition.source.?.slice());

    // Delegated migration target resolves basis path relative to apps/app/build.transit!
    const mig = try c.compile(t.allocator, &diamond_workspace_files, .{
        .compiler_revision = "diamond-test",
        .target = "app_migrations",
        .target_explicit = true,
        .report = &report,
    }, &diagnostic);
    defer mig.deinit();
    try t.expectEqualStrings("apps/app/releases/init/basis.json", mig.migration_basis_path.?);
    try t.expectEqualStrings(".local/build/app/migrations", mig.declared_output_path.?);

    // Omitted --target in test mode discovers unique exported test target 'app_tests'
    const suite = try c.compile(t.allocator, &diamond_workspace_files, .{
        .compiler_revision = "diamond-test",
        .mode = .test_suite,
        .target_explicit = false,
        .report = &report,
    }, &diagnostic);
    defer suite.deinit();
    try t.expectEqualStrings("app_tests", suite.selected_target);
    try t.expectEqual(@as(usize, 2), suite.cases.len);
    try t.expectEqualStrings("root/apps/app/tenancy/tenancy.test.transit", suite.cases[0].location.source.?.slice());
    try t.expectEqualStrings("root/apps/app/tests/composition.test.transit", suite.cases[1].location.source.?.slice());

    // Allocation failure determinism check!
    try t.checkAllAllocationFailures(t.allocator, diamondAllocations, .{});
}

test "composition diagnostics reject unknown named args duplicate schema bindings and unsupported test options" {
    const t = std.testing;
    var diagnostic: ?p.Diagnostic = null;
    var report: c.SourceDiagnostic.Report = .{};

    // Unknown named argument
    const bad_named =
        \\EXPORT MODULE m(a BIGINT, b TEXT) AS BEGIN
        \\  CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY);
        \\END;
        \\LET inst = USE MODULE m(a => 1, wrong => 'x');
        \\EXPORT TARGET default AS SQL OF inst;
    ;
    try t.expectError(error.UnknownSourceOperand, c.compile(t.allocator, &.{.{ .path = "build.transit", .text = bad_named }}, .{ .compiler_revision = "diag-test", .report = &report }, &diagnostic));
    try t.expect(std.mem.indexOf(u8, report.headline().?, "unknown named argument 'wrong'") != null);

    // Duplicate BIND SCHEMA in same module
    const dup_schema =
        \\EXPORT MODULE m(s SCHEMA_BINDING) AS BEGIN
        \\  BIND SCHEMA auth TO s;
        \\  BIND SCHEMA auth TO s;
        \\  CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY);
        \\END;
        \\LET inst = USE MODULE m(s => SCHEMA_BINDING('auth_phys'));
        \\EXPORT TARGET default AS SQL OF inst;
    ;
    try t.expectError(error.DuplicateSourceName, c.compile(t.allocator, &.{.{ .path = "build.transit", .text = dup_schema }}, .{ .compiler_revision = "diag-test", .report = &report }, &diagnostic));
    try t.expect(std.mem.indexOf(u8, report.headline().?, "schema 'auth' is already bound") != null);

    // Unsupported test WITH (...) option refuses explicitly instead of silently ignoring safety gates
    const unsupported_with =
        \\EXPORT MODULE m() AS BEGIN
        \\  CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY);
        \\END;
        \\LET inst = USE MODULE m();
        \\EXPORT TARGET tests AS TESTS OF inst USING SUITES ('./s.test.transit') WITH (verify_replay = TRUE);
    ;
    try t.expectError(error.UnsupportedTestOption, c.compile(t.allocator, &.{
        .{ .path = "build.transit", .text = unsupported_with },
        .{ .path = "s.test.transit", .text = "TEST 'c' USING MODULES (app) AS BEGIN ASSERT ROWS (SELECT id FROM t) EQUAL (); END;" },
    }, .{ .compiler_revision = "diag-test", .target = "tests", .mode = .test_suite, .report = &report }, &diagnostic));
    try t.expectEqualStrings("application.source.unsupported", diagnostic.?.code.slice());
    try t.expect(std.mem.indexOf(u8, report.headline().?, "verify_replay") != null);
}
