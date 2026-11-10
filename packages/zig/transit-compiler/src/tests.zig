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
