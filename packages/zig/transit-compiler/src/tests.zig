const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");
const rows = "CREATE PUBLIC MODULE Rows(name IDENTIFIER, element TYPE, initial BIGINT) AS BEGIN CREATE PUBLIC TABLE $name (id $element PRIMARY KEY); INSERT INTO $name VALUES ($initial); END;";
const build = "IMPORT rows FROM 'rows.transit'; CREATE INTERFACE Factory(name IDENTIFIER, element TYPE, initial BIGINT); CREATE MODULE Repeat(factory MODULE Factory, name IDENTIFIER, remaining BIGINT) AS BEGIN IF remaining = 0 THEN USE factory(name, TYPE BIGINT, 9); ELSE USE Repeat(factory, name, remaining - 1); END IF; END; CREATE TARGET default AS BEGIN USE rows.Rows(NAME 'first', TYPE BIGINT, 7); USE Repeat(rows.Rows, NAME 'second', 3); UPDATE first SET id = 8 WHERE id = 7; DELETE FROM second WHERE id = 100; SELECT * FROM first; SELECT * FROM second; END;";
const sources = [_]c.Source{ .{ .path = "build.transit", .text = build }, .{ .path = "rows.transit", .text = rows } };
test "higher order recursive modules emit independently prepared SQL" {
    var diagnostic: ?p.Diagnostic = null;
    const product = c.compile(std.testing.allocator, &sources, .{ .compiler_revision = "test" }, &diagnostic) catch |err| {
        std.debug.print("compiler failed {s}\n", .{@errorName(err)});
        return err;
    };
    defer product.deinit();
    try std.testing.expectEqual(8, product.steps.len);
    try std.testing.expectEqualStrings("CREATE TABLE \"first\" ( ID BIGINT PRIMARY KEY )", product.steps[0].sql);
    try std.testing.expectEqualStrings("INSERT INTO \"second\" VALUES ( 9 )", product.steps[3].sql);
    try std.testing.expectEqualStrings("UPDATE FIRST SET ID = 8 WHERE ID = 7", product.steps[4].sql);
    try std.testing.expect(product.steps[0].call != null);
    try std.testing.expect(product.work > 12);
}

fn one(text: []const u8, options: c.Options) !*c.Product {
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = text }}, options, &diagnostic);
}
fn refuses(expected: anyerror, input: []const c.Source, options: c.Options) !void {
    var diagnostic: ?p.Diagnostic = null;
    try std.testing.expectError(expected, c.compile(std.testing.allocator, input, options, &diagnostic));
    try std.testing.expect(diagnostic != null);
    try std.testing.expectEqual(.not_submitted, diagnostic.?.outcome);
}
const simple = "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE items (id BIGINT PRIMARY KEY); INSERT INTO items VALUES (1); SELECT * FROM items; END;";
test "contextual names survive source framing and ordinary SQL verification" {
    const product = try one("CREATE MODULE begin(case BIGINT, end BOOLEAN) AS BEGIN IF end THEN CREATE PUBLIC TABLE case (begin BIGINT, end BIGINT); INSERT INTO case VALUES ($case, 2); SELECT begin AS end, end AS begin FROM case; END IF; END; CREATE TARGET default AS BEGIN USE begin(1, TRUE); END;", .{ .compiler_revision = "test" });
    defer product.deinit();
    try std.testing.expectEqual(3, product.steps.len);
    try std.testing.expectEqualStrings("SELECT BEGIN AS END , END AS BEGIN FROM CASE", product.steps[2].sql);
}
test "source argument kinds, arity and module interfaces reject" {
    const wrong_type = "CREATE MODULE M(x BIGINT) AS BEGIN CREATE PUBLIC TABLE items (id BIGINT); END; CREATE TARGET default AS BEGIN USE M('text'); END;";
    try std.testing.expectError(error.SourceTypeMismatch, one(wrong_type, .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.SourceArgumentCount, one("CREATE MODULE M(x BIGINT) AS BEGIN END; CREATE TARGET default AS BEGIN USE M(); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.ModuleInterfaceMismatch, one("CREATE INTERFACE I(x BIGINT); CREATE MODULE M(x TEXT) AS BEGIN END; CREATE MODULE Apply(m MODULE I) AS BEGIN USE m(1); END; CREATE TARGET default AS BEGIN USE Apply(M); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.InvalidModuleInterface, one("CREATE MODULE M() AS BEGIN END; CREATE MODULE Apply(m MODULE M) AS BEGIN END; CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;", .{ .compiler_revision = "test" }));
}
test "source-private helpers and cycles cannot leak across imports" {
    try refuses(error.PrivateSourceSymbol, &.{ .{ .path = "build.transit", .text = "IMPORT lib FROM 'lib.transit'; CREATE TARGET default AS BEGIN USE lib.Hidden(); END;" }, .{ .path = "lib.transit", .text = "CREATE MODULE Hidden() AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;" } }, .{ .compiler_revision = "test" });
    try refuses(error.SourceImportCycle, &.{ .{ .path = "build.transit", .text = "IMPORT lib FROM 'lib.transit';" }, .{ .path = "lib.transit", .text = "IMPORT root FROM 'build.transit';" } }, .{ .compiler_revision = "test" });
    try refuses(error.InvalidSourcePath, &.{.{ .path = "build.transit", .text = "IMPORT lib FROM '../lib.transit';" }}, .{ .compiler_revision = "test" });
    try refuses(error.MissingSource, &.{.{ .path = "build.transit", .text = "IMPORT lib FROM 'lib.transit';" }}, .{ .compiler_revision = "test" });
    try refuses(error.UndeclaredDependency, &.{.{ .path = "build.transit", .text = "IMPORT lib FROM PACKAGE missing FILE 'build.transit';" }}, .{ .compiler_revision = "test" });
}
test "unsupported runtime capabilities and conflicting names reject before output" {
    for ([_][]const u8{
        "CREATE TARGET default AS BEGIN CREATE TABLE hidden (id BIGINT); END;",
        "CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE work (id BIGINT); END;",
        "CREATE TARGET default AS BEGIN CREATE PUBLIC PROCEDURE run() AS BEGIN SELECT 1; END; END;",
    }) |source| try std.testing.expectError(error.RuntimePrivateOrUnsupportedDeclaration, one(source, .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.ConflictingModuleInstance, one("CREATE MODULE M(name IDENTIFIER) AS BEGIN CREATE PUBLIC TABLE $name (id BIGINT); END; CREATE TARGET default AS BEGIN USE M(NAME 'same'); USE M(NAME 'same'); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.UnknownBuildTable, one("CREATE TARGET default AS BEGIN SELECT * FROM absent; END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.UnsupportedBuildStatement, one("CREATE TARGET default AS BEGIN COMMIT; END;", .{ .compiler_revision = "test" }));
}
test "work, constructor, graph, source, output and allocation budgets reject" {
    try std.testing.expectError(error.BuildWorkLimit, one(simple, .{ .compiler_revision = "test", .limits = .{ .work = 1 } }));
    try std.testing.expectError(error.SourceDepthLimit, one("CREATE MODULE Forever() AS BEGIN USE Forever(); END; CREATE TARGET default AS BEGIN USE Forever(); END;", .{ .compiler_revision = "test", .limits = .{ .depth = 5 } }));
    try refuses(error.SourceDepthLimit, &sources, .{ .compiler_revision = "test", .limits = .{ .depth = 1 } });
    try refuses(error.SourceFileLimit, &sources, .{ .compiler_revision = "test", .limits = .{ .files = 1 } });
    try std.testing.expectError(error.SourceBytesLimit, one(simple, .{ .compiler_revision = "test", .limits = .{ .source_bytes = 10 } }));
    try std.testing.expectError(error.BuildOutputLimit, one(simple, .{ .compiler_revision = "test", .limits = .{ .output_bytes = 10 } }));
    try std.testing.expectError(error.BuildMemoryLimit, one(simple, .{ .compiler_revision = "test", .limits = .{ .memory_bytes = 100 } }));
    try std.testing.expectError(error.InvalidBuildBudget, one(simple, .{ .compiler_revision = "test", .limits = .{ .work = 100001 } }));
}
test "deterministic SQL and cache identity follow all inputs" {
    var diagnostic: ?p.Diagnostic = null;
    const first = try c.compile(std.testing.allocator, &sources, .{ .compiler_revision = "one" }, &diagnostic);
    defer first.deinit();
    const reordered = [_]c.Source{ sources[1], sources[0] };
    const second = try c.compile(std.testing.allocator, &reordered, .{ .compiler_revision = "one" }, &diagnostic);
    defer second.deinit();
    try std.testing.expectEqualSlices(u8, first.sql, second.sql);
    try std.testing.expectEqualSlices(u8, &first.input_digest, &second.input_digest);
    for ([_]c.Options{ .{ .compiler_revision = "two" }, .{ .compiler_revision = "one", .limits = .{ .work = 99999 } }, .{ .compiler_revision = "one", .resolution_digest = @splat(1) } }) |options| {
        const changed = try c.compile(std.testing.allocator, &sources, options, &diagnostic);
        defer changed.deinit();
        try std.testing.expect(!std.mem.eql(u8, &first.input_digest, &changed.input_digest));
        try std.testing.expectEqualSlices(u8, first.sql, changed.sql);
    }
}
test "relocating source preserves explicit runtime bindings" {
    var diagnostic: ?p.Diagnostic = null;
    const original = try c.compile(std.testing.allocator, &sources, .{ .compiler_revision = "test" }, &diagnostic);
    defer original.deinit();
    const relocated = [_]c.Source{ .{ .path = "sub/build.transit", .text = build }, .{ .path = "sub/rows.transit", .text = rows } };
    const moved = try c.compile(std.testing.allocator, &relocated, .{ .compiler_revision = "test", .entry = "sub/build.transit" }, &diagnostic);
    defer moved.deinit();
    try std.testing.expectEqualStrings(original.sql, moved.sql);
    try std.testing.expect(!std.mem.eql(u8, &original.input_digest, &moved.input_digest));
}
test "literal quoting, comments and nulls survive ordinary owner verification" {
    const product = try one("CREATE MODULE M(name IDENTIFIER, v TEXT) AS BEGIN CREATE PUBLIC TABLE $name (id BIGINT PRIMARY KEY, note TEXT); INSERT INTO $name VALUES (1, $v); INSERT INTO $name VALUES (2, NULL); -- $missing;\n SELECT * FROM $name WHERE id <= 2; END; CREATE TARGET default AS BEGIN USE M(NAME 'quoted', 'it''s $missing;'); END;", .{ .compiler_revision = "test" });
    defer product.deinit();
    try std.testing.expect(std.mem.indexOf(u8, product.sql, "'it''s $missing;'") != null);
    try std.testing.expect(std.mem.indexOf(u8, product.sql, "NULL") != null);
    try std.testing.expect(std.mem.indexOf(u8, product.sql, "<=") != null);
}
test "checked arithmetic and condition typing" {
    try std.testing.expectError(error.Overflow, one("CREATE MODULE M(n BIGINT) AS BEGIN END; CREATE TARGET default AS BEGIN USE M(9223372036854775807 + 1); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.SourceTypeMismatch, one("CREATE TARGET default AS BEGIN IF 1 THEN CREATE PUBLIC TABLE t (id BIGINT); END IF; END;", .{ .compiler_revision = "test" }));
}
fn allocationFailure(a: std.mem.Allocator) !void {
    var diagnostic: ?p.Diagnostic = null;
    const product = try c.compile(a, &sources, .{ .compiler_revision = "test" }, &diagnostic);
    defer product.deinit();
}
test "every compiler allocation failure cleans up" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailure, .{});
}

test "minimum signed operand and source hygiene" {
    const product = try one("CREATE MODULE Helper(name IDENTIFIER, x BIGINT) AS BEGIN CREATE PUBLIC TABLE $name (id BIGINT PRIMARY KEY); INSERT INTO $name VALUES ($x); END; CREATE MODULE Outer(name IDENTIFIER) AS BEGIN USE Helper(name, -9223372036854775808); END; CREATE TARGET default AS BEGIN USE Outer(NAME 'items'); END;", .{ .compiler_revision = "test" });
    defer product.deinit();
    try std.testing.expect(std.mem.indexOf(u8, product.sql, "-9223372036854775808") != null);
    try std.testing.expect(product.budget.peak <= product.budget.limit);
}
test "source package content identity is ordered and byte sensitive" {
    const before = try c.Graph.treeDigest(&sources, "root", std.testing.allocator);
    const reordered = [_]c.Source{ sources[1], sources[0] };
    try std.testing.expectEqual(before, try c.Graph.treeDigest(&reordered, "root", std.testing.allocator));
    const changed = [_]c.Source{ sources[0], .{ .path = sources[1].path, .text = rows ++ "\n" } };
    try std.testing.expect(!std.mem.eql(u8, &before, &try c.Graph.treeDigest(&changed, "root", std.testing.allocator)));
}

test "dependency closure cycles and conflicting global pins reject" {
    const pinned = "DEPENDENCY a FROM '/repository-a' REVISION '1111111111111111111111111111111111111111';";
    const nested = "DEPENDENCY b FROM '/repository-b' REVISION '2222222222222222222222222222222222222222';";
    try refuses(error.SourceDependencyCycle, &.{ .{ .path = "build.transit", .text = pinned }, .{ .package = "a", .path = "build.transit", .text = nested }, .{ .package = "b", .path = "build.transit", .text = pinned } }, .{ .compiler_revision = "test" });
    try refuses(error.ConflictingDependency, &.{ .{ .path = "build.transit", .text = pinned }, .{ .path = "other.transit", .text = "DEPENDENCY a FROM '/other-repository' REVISION '1111111111111111111111111111111111111111';" } }, .{ .compiler_revision = "test" });
    try refuses(error.RepositoryCredentialsForbidden, &.{.{ .path = "build.transit", .text = "DEPENDENCY a FROM 'https://user:secret@example.invalid/repository' REVISION '1111111111111111111111111111111111111111';" }}, .{ .compiler_revision = "test" });
}

test "type operands cannot become object or column identifiers" {
    try std.testing.expectError(error.InvalidSourceTypeOperand, one("CREATE MODULE M(t TYPE) AS BEGIN CREATE PUBLIC TABLE $t (id BIGINT); END; CREATE TARGET default AS BEGIN USE M(TYPE BIGINT); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.InvalidSourceTypeOperand, one("CREATE MODULE M(t TYPE) AS BEGIN CREATE PUBLIC TABLE items ($t BIGINT); END; CREATE TARGET default AS BEGIN USE M(TYPE BIGINT); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.InvalidSourceTypeOperand, one("CREATE MODULE M(t TYPE) AS BEGIN CREATE PUBLIC TABLE items (bigint BIGINT); SELECT $t FROM items; END; CREATE TARGET default AS BEGIN USE M(TYPE BIGINT); END;", .{ .compiler_revision = "test" }));
}

test "shared higher order interface graphs consume the evaluation work budget" {
    const graph =
        "CREATE INTERFACE I0();" ++
        "CREATE INTERFACE I1(a MODULE I0, b MODULE I0);" ++
        "CREATE INTERFACE I2(a MODULE I1, b MODULE I1);" ++
        "CREATE INTERFACE I3(a MODULE I2, b MODULE I2);" ++
        "CREATE INTERFACE I4(a MODULE I3, b MODULE I3);" ++
        "CREATE INTERFACE I5(a MODULE I4, b MODULE I4);" ++
        "CREATE MODULE M(a MODULE I4, b MODULE I4) AS BEGIN END;" ++
        "CREATE MODULE Apply(m MODULE I5) AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;" ++
        "CREATE TARGET default AS BEGIN USE Apply(M); END;";
    const product = try one(graph, .{ .compiler_revision = "test" });
    defer product.deinit();
    try std.testing.expectEqual(1, product.steps.len);
    try std.testing.expect(product.work > 16);
    try refuses(error.BuildWorkLimit, &.{.{ .path = "build.transit", .text = graph }}, .{ .compiler_revision = "test", .limits = .{ .work = 16 } });
}

const test_source =
    \\CREATE MODULE Rows(n IDENTIFIER, value BIGINT) AS BEGIN
    \\  CREATE PUBLIC TABLE $n (id BIGINT PRIMARY KEY, label TEXT);
    \\  INSERT INTO $n VALUES ($value, NULL);
    \\END;
    \\CREATE PUBLIC MODULE Checks(value BIGINT) AS BEGIN
    \\  TEST 'typed rows' USING MODULES (Rows(NAME 'items', value)) AS BEGIN
    \\    ASSERT COMMAND (INSERT INTO items VALUES (9, 'text')) MATCHED 1 CHANGED 1;
    \\    ASSERT ROWS (SELECT * FROM items) EQUAL ((9, 'text'), ($value, NULL));
    \\    ASSERT STATEMENT (INSERT INTO items VALUES (9, NULL)) FAILS WITH 'duplicate_key';
    \\    ASSERT ROWS (SELECT id FROM items WHERE id = 10) EQUAL ();
    \\  END;
    \\END;
    \\CREATE TARGET default AS BEGIN USE Rows(NAME 'items', 5); END;
    \\CREATE TEST TARGET tests AS BEGIN USE Checks(7); USE Checks(8); END;
;
const test_options: c.Options = .{ .compiler_revision = "test", .target = "tests", .mode = .test_suite };
test "test targets compose independent catalogs and typed expectations through production SQL" {
    const product = try one(test_source, test_options);
    defer product.deinit();
    try std.testing.expectEqual(2, product.cases.len);
    try std.testing.expectEqual(0, product.steps.len);
    try std.testing.expectEqual(0, product.sql.len);
    for (product.cases) |case| {
        try std.testing.expectEqual(6, case.steps.len);
        try std.testing.expectEqual(6, case.actions.len);
        try std.testing.expectEqualStrings("CREATE TABLE \"items\" ( ID BIGINT PRIMARY KEY , LABEL TEXT )", case.steps[0].sql);
        try std.testing.expectEqual(2, case.actions[3].expectation.rows.values.len);
        try std.testing.expectEqual(0, case.actions[5].expectation.rows.values.len);
        try std.testing.expect(std.mem.indexOf(u8, case.sql, "ASSERT") == null);
        try std.testing.expect(case.steps[0].call != null);
    }
    try std.testing.expect(!std.mem.eql(u8, &product.cases[0].identity, &product.cases[1].identity));
    const repeat = try one(test_source, test_options);
    defer repeat.deinit();
    try std.testing.expectEqualSlices(u8, &product.input_digest, &repeat.input_digest);
    const built = try one(test_source, .{ .compiler_revision = "test" });
    defer built.deinit();
    try std.testing.expectEqual(2, built.steps.len);
    try std.testing.expectEqual(0, built.cases.len);
}
test "test stage violations and unsupported expectations fail before a product" {
    const inputs = [_]struct { err: anyerror, text: []const u8 }{
        .{ .err = error.EmptyTestTarget, .text = "CREATE TEST TARGET tests AS BEGIN END;" },
        .{ .err = error.TestStatementOutsideCase, .text = "CREATE TEST TARGET tests AS BEGIN CREATE PUBLIC TABLE t(id BIGINT); END;" },
        .{ .err = error.TestAssertionOutsideCase, .text = "CREATE TEST TARGET tests AS BEGIN ASSERT ROWS (SELECT id FROM t) EQUAL (); END;" },
        .{ .err = error.NestedTestCase, .text = "CREATE TEST TARGET tests AS BEGIN TEST 'outer' USING MODULES () AS BEGIN TEST 'inner' USING MODULES () AS BEGIN END; END; END;" },
        .{ .err = error.UnsupportedTestRefusal, .text = "CREATE TEST TARGET tests AS BEGIN TEST 'bad' USING MODULES () AS BEGIN ASSERT STATEMENT (DELETE FROM t) FAILS WITH 'AuthorityTimeout'; END; END;" },
        .{ .err = error.WrongSourceTargetKind, .text = "CREATE TARGET tests AS BEGIN END;" },
    };
    for (inputs) |input| try std.testing.expectError(input.err, one(input.text, test_options));
    try std.testing.expectError(error.TestInBuildTarget, one("CREATE TARGET default AS BEGIN TEST 'bad' USING MODULES () AS BEGIN END; END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.DuplicateTestCase, one("CREATE TEST TARGET tests AS BEGIN TEST 'same' USING MODULES () AS BEGIN CREATE PUBLIC TABLE t(id BIGINT); END; TEST 'same' USING MODULES () AS BEGIN CREATE PUBLIC TABLE t(id BIGINT); END; END;", test_options));
}
fn allocationTestSuite(allocator: std.mem.Allocator) !void {
    var diagnostic: ?p.Diagnostic = null;
    const result = try c.compile(allocator, &.{.{ .path = "build.transit", .text = test_source }}, test_options, &diagnostic);
    defer result.deinit();
    try std.testing.expectEqual(2, result.cases.len);
}
test "test compilation cleans up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTestSuite, .{});
}

test "case and action ceilings admit the boundary and reject the next item" {
    var source: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer source.deinit();
    try source.writer.writeAll("CREATE TEST TARGET tests AS BEGIN ");
    for (0..c.Test.max_cases) |i| try source.writer.print("TEST 'case-{d}' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items(id BIGINT); END; ", .{i});
    const closing = source.written().len;
    try source.writer.writeAll("END;");
    const boundary = try one(source.written(), test_options);
    boundary.deinit();
    source.writer.end = closing;
    try source.writer.writeAll("TEST 'overflow' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items(id BIGINT); END; END;");
    try std.testing.expectError(error.TestCaseLimit, one(source.written(), test_options));
    source.writer.end = 0;
    try source.writer.writeAll("CREATE TEST TARGET tests AS BEGIN TEST 'actions' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items(id BIGINT);");
    for (1..c.Test.max_actions) |_| try source.writer.writeAll("SELECT * FROM items;");
    const end = source.written().len;
    try source.writer.writeAll("END; END;");
    const actions = try one(source.written(), test_options);
    actions.deinit();
    source.writer.end = end;
    try source.writer.writeAll("SELECT * FROM items; END; END;");
    try std.testing.expectError(error.TestActionLimit, one(source.written(), test_options));
}

test "expected row limits aggregate across assertions within one case" {
    var source: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer source.deinit();
    try source.writer.writeAll("CREATE TEST TARGET tests AS BEGIN TEST 'rows' USING MODULES () AS BEGIN CREATE PUBLIC TABLE items(id BIGINT);");
    for (0..100) |_| {
        try source.writer.writeAll("ASSERT ROWS (SELECT * FROM items) EQUAL (");
        for (0..100) |i| try source.writer.print("{s}({d})", .{ if (i == 0) "" else ",", i });
        try source.writer.writeAll(");");
    }
    const end = source.written().len;
    try source.writer.writeAll("END; END;");
    const boundary = try one(source.written(), test_options);
    boundary.deinit();
    source.writer.end = end;
    try source.writer.writeAll("ASSERT ROWS (SELECT * FROM items) EQUAL ((1)); END; END;");
    try std.testing.expectError(error.TestRowsLimit, one(source.written(), test_options));
}

const target_types =
    "CREATE DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id'; " ++
    "CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id'; " ++
    "CREATE VARIANT Target AS (Machine(id MachineId), Site(id SiteId)); ";
const typed_tables =
    "CREATE MODULE Rows(name IDENTIFIER, element TYPE) AS BEGIN " ++
    "CREATE PUBLIC TABLE $name (id $element PRIMARY KEY); EXPORT TABLE $name AS rows; END; " ++
    "CREATE MODULE InsertMachine(rows TABLE(id MachineId PRIMARY KEY), id MachineId) AS BEGIN INSERT INTO $rows VALUES ($id); END; " ++
    "CREATE MODULE InsertSite(rows TABLE(id SiteId PRIMARY KEY), id SiteId) AS BEGIN INSERT INTO $rows VALUES ($id); END; ";
const typed_setup =
    "USE Rows(NAME 'machines', TYPE MachineId) AS machines; " ++
    "USE Rows(NAME 'sites', TYPE SiteId) AS sites; ";
const typed_route =
    "CREATE MODULE Route(target Target, machines TABLE(id MachineId PRIMARY KEY), sites TABLE(id SiteId PRIMARY KEY)) AS BEGIN " ++
    "MATCH target WHEN Target.Machine(id) THEN USE InsertMachine(machines, id); " ++
    "WHEN Target.Site(id) THEN USE InsertSite(sites, id); END MATCH; END; ";
const typed_application = target_types ++ typed_tables ++ typed_route ++
    "CREATE TARGET default AS BEGIN " ++ typed_setup ++
    "USE Route(Target.Machine(MachineId(7)), machines.rows, sites.rows); " ++
    "USE Route(Target.Site(SiteId(7)), machines.rows, sites.rows); " ++
    "SELECT * FROM machines; SELECT * FROM sites; END;";
test "nominal targets specialize both constructors into independently verified SQL" {
    const product = try one(typed_application, .{ .compiler_revision = "test" });
    defer product.deinit();
    try std.testing.expectEqual(6, product.steps.len);
    try std.testing.expectEqualStrings("INSERT INTO \"machines\" VALUES ( 7 )", product.steps[2].sql);
    try std.testing.expectEqualStrings("INSERT INTO \"sites\" VALUES ( 7 )", product.steps[3].sql);
    try std.testing.expect(std.mem.indexOf(u8, product.sql, "MachineId") == null);
}
test "nominal parameters cannot erase, rebrand, or substitute equal raw values" {
    try std.testing.expectError(error.SourceTypeMismatch, one(target_types ++ typed_tables ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE InsertMachine(machines.rows, SiteId(7)); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.TableInterfaceMismatch, one(target_types ++ typed_tables ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE InsertMachine(sites.rows, MachineId(7)); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.SourceTypeMismatch, one(target_types ++
        "CREATE MODULE Raw(x BIGINT) AS BEGIN END; CREATE TARGET default AS BEGIN USE Raw(MachineId(7)); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.SourceTypeMismatch, one(target_types ++
        "CREATE MODULE Nominal(x MachineId) AS BEGIN END; CREATE TARGET default AS BEGIN USE Nominal(MachineId(SiteId(7))); END;", .{ .compiler_revision = "test" }));
}
test "literal Table names cannot bypass nominal operand checks" {
    try std.testing.expectError(error.SourceDomainMismatch, one(target_types ++ typed_tables ++
        "CREATE MODULE Wrong(id SiteId) AS BEGIN INSERT INTO machines VALUES ($id); END; " ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE Wrong(SiteId(7)); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.SourceDomainMismatch, one(target_types ++ typed_tables ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "INSERT INTO machines VALUES (7); END;", .{ .compiler_revision = "test" }));
}
test "unselected MATCH arms are checked with symbolic payload types" {
    try std.testing.expectError(error.SourceDomainMismatch, one(target_types ++ typed_tables ++
        "CREATE MODULE Route(target Target) AS BEGIN MATCH target " ++
        "WHEN Target.Machine(id) THEN INSERT INTO machines VALUES ($id); " ++
        "WHEN Target.Site(id) THEN INSERT INTO machines VALUES ($id); END MATCH; END; " ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE Route(Target.Machine(MachineId(7))); END;", .{ .compiler_revision = "test" }));
    try std.testing.expectError(error.NonExhaustiveSourceMatch, one(target_types ++
        "CREATE MODULE Route(target Target) AS BEGIN MATCH target WHEN Target.Machine(id) THEN END MATCH; END; " ++
        "CREATE TARGET default AS BEGIN USE Route(Target.Machine(MachineId(7))); END;", .{ .compiler_revision = "test" }));
}
fn typedAllocationFailure(a: std.mem.Allocator) !void {
    var diagnostic: ?p.Diagnostic = null;
    const product = try c.compile(a, &.{.{ .path = "build.transit", .text = typed_application }}, .{ .compiler_revision = "test" }, &diagnostic);
    defer product.deinit();
}
test "typed MATCH and proposed catalog branches clean up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, typedAllocationFailure, .{});
}

test "typed DML assignments aliases and predicates retain source annotations" {
    const product = try one(target_types ++ typed_tables ++
        "CREATE MODULE Mutate(rows TABLE(id MachineId PRIMARY KEY), id MachineId, replacement MachineId) AS BEGIN " ++
        "INSERT INTO $rows (id) VALUES ($id); UPDATE machines SET id = $replacement WHERE id = $id; " ++
        "SELECT m.id FROM machines AS m WHERE m.id <> $id; DELETE FROM machines WHERE id = $replacement; END; " ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE Mutate(machines.rows, MachineId(7), MachineId(9)); END;", .{ .compiler_revision = "test" });
    defer product.deinit();
    const update = product.steps[3].checked;
    try std.testing.expectEqualStrings("machines", update.table);
    try std.testing.expectEqualStrings("example.machine-id", update.columns[0].domain.?);
    try std.testing.expectEqual(2, update.operands.len);
    try std.testing.expectEqual(.assignment, update.operands[0].role);
    try std.testing.expectEqual(9, update.operands[0].value.?.integer);
    try std.testing.expectEqual(.predicate, update.operands[1].role);
    try std.testing.expectEqual(7, update.operands[1].value.?.integer);
    try std.testing.expectEqualStrings("example.machine-id", update.operands[1].domain.?);
}
test "typed rows assertions check unselected arms without materializing symbolic payloads" {
    const source = target_types ++ typed_tables ++
        "CREATE MODULE Route(value Target) AS BEGIN MATCH value " ++
        "WHEN Target.Machine(id) THEN ASSERT ROWS (SELECT * FROM machines WHERE id = $id) EQUAL (); " ++
        "WHEN Target.Site(id) THEN ASSERT ROWS (SELECT * FROM sites WHERE id = $id) EQUAL (); END MATCH; END; " ++
        "CREATE TEST TARGET tests AS BEGIN TEST 'empty' USING MODULES () AS BEGIN " ++ typed_setup ++
        "USE Route(Target.Machine(MachineId(7))); END; END;";
    const product = try one(source, .{ .compiler_revision = "test", .mode = .test_suite, .target = "tests" });
    defer product.deinit();
    try std.testing.expectEqual(1, product.cases.len);
    try std.testing.expectEqual(3, product.cases[0].actions.len);
    const bad = try std.mem.replaceOwned(u8, std.testing.allocator, source, "SELECT * FROM sites WHERE id = $id", "SELECT * FROM machines WHERE id = $id");
    defer std.testing.allocator.free(bad);
    try std.testing.expectError(error.SourceDomainMismatch, one(bad, .{ .compiler_revision = "test", .mode = .test_suite, .target = "tests" }));
}
test "unselected recursive checking validates bodies and preserves call diagnostics" {
    const source = target_types ++ typed_tables ++
        "CREATE MODULE Loop(n BIGINT, id SiteId) AS BEGIN IF n = 0 THEN INSERT INTO machines VALUES ($id); ELSE USE Loop(n - 1, id); END IF; END; " ++
        "CREATE MODULE Route(value Target) AS BEGIN MATCH value WHEN Target.Machine(id) THEN INSERT INTO machines VALUES ($id); " ++
        "WHEN Target.Site(id) THEN USE Loop(1, id); END MATCH; END; " ++
        "CREATE TARGET default AS BEGIN " ++ typed_setup ++ "USE Route(Target.Machine(MachineId(7))); END;";
    var diagnostic: ?p.Diagnostic = null;
    try std.testing.expectError(error.SourceDomainMismatch, c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "test" }, &diagnostic));
    try std.testing.expect(diagnostic != null);
    try std.testing.expectEqual(std.mem.indexOf(u8, source, "INSERT INTO machines VALUES ($id)").?, try diagnostic.?.location.?.offset.value());
    try std.testing.expectEqual(.first_occurrence, diagnostic.?.facts[1].?.field);
    try std.testing.expectEqual(std.mem.indexOf(u8, source, "USE Loop(1, id)").?, try diagnostic.?.facts[1].?.value.?.location.offset.value());
}
