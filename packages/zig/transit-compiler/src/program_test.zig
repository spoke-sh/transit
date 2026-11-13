const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");

const declarations =
    \\CREATE DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id';
    \\CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id';
    \\CREATE DOMAIN Label AS TEXT IDENTITY 'example.label';
    \\CREATE DOMAIN Flag AS BOOLEAN IDENTITY 'example.flag';
    \\CREATE MODULE Resources(machine TYPE, site TYPE, label TYPE, flag TYPE) AS BEGIN
    \\  CREATE PUBLIC QUEUE requests (id $machine NOT NULL, other $site NOT NULL, label $label NOT NULL, flag $flag NOT NULL, body TEXT NOT NULL);
    \\  CREATE PUBLIC TABLE machines (id $machine PRIMARY KEY, label TEXT NOT NULL);
    \\  CREATE PUBLIC TABLE accepted (id $machine PRIMARY KEY, body TEXT NOT NULL);
    \\  CREATE PUBLIC STREAM events (id $machine NOT NULL, body TEXT NOT NULL);
    \\  CREATE PUBLIC STREAM raw (id BIGINT NOT NULL);
    \\END;
;
const suffix = " END; CREATE TARGET default AS BEGIN USE Resources(TYPE MachineId, TYPE SiteId, TYPE Label, TYPE Flag); USE Workflow(MachineId(-7), Label('a''雪')); END;";
fn source(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s} CREATE MODULE Workflow(expected MachineId, text Label) AS BEGIN CREATE PUBLIC DATAFLOW process FROM QUEUE requests AS request AS BEGIN {s} END;{s}", .{ declarations, body, suffix });
}
fn build(allocator: std.mem.Allocator, body: []const u8) !*c.Product {
    const text = try source(allocator, body);
    defer allocator.free(text);
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "program-types" }, &diagnostic);
}
const valid =
    \\LET alias = request.id;
    \\REQUIRE alias = $expected ELSE 'WrongId';
    \\REQUIRE request.label = $text ELSE 'WrongLabel';
    \\BEGIN ATOMIC
    \\  LET found = SELECT id FROM machines WHERE label = request.body;
    \\  REQUIRE found IS NOT NULL ELSE 'Missing';
    \\  REQUIRE found.id = alias ELSE 'WrongMachine';
    \\  LET chosen = CASE WHEN request.body = 'ready' THEN alias ELSE found.id END;
    \\  LET optional = CASE WHEN TRUE THEN chosen ELSE NULL END;
    \\  LET pair = ROW(optional, request.other);
    \\  INSERT INTO accepted VALUES (chosen, request.body) ON CONFLICT (id) DO ASSERT SAME ROW;
    \\  REQUIRE request.body <> 'reject' ELSE 'Refused';
    \\  IF request.body = 'ready' THEN
    \\    PRODUCE INTO events VALUES (alias, request.body);
    \\  ELSE
    \\    PRODUCE INTO events VALUES (optional, request.body);
    \\  END IF;
    \\END;
;
test "program evidence preserves nominal holes nullable records and ordered boundaries" {
    const product = try build(std.testing.allocator, valid);
    defer product.deinit();
    const checked = product.steps[5].checked.program.?;
    var bindings: usize = 0;
    for (checked.nodes) |node| {
        if (!std.mem.eql(u8, node.kind, "binding")) continue;
        switch (bindings) {
            0 => {
                try std.testing.expectEqualStrings("example.machine-id", node.type.domain.?);
                try std.testing.expect(!node.type.nullable);
            },
            1 => {
                try std.testing.expectEqual(.record, node.type.kind);
                try std.testing.expect(node.type.nullable);
                try std.testing.expectEqualStrings("example.machine-id", node.type.fields[0].value.domain.?);
            },
            2, 3 => {
                try std.testing.expect(node.type.nullable);
                try std.testing.expectEqualStrings("example.machine-id", node.type.domain.?);
            },
            4 => {
                try std.testing.expectEqualStrings("example.machine-id", node.type.fields[0].value.domain.?);
                try std.testing.expect(node.type.fields[0].value.nullable);
                try std.testing.expectEqualStrings("example.site-id", node.type.fields[1].value.domain.?);
            },
            else => return error.UnexpectedBinding,
        }
        bindings += 1;
    }
    try std.testing.expectEqual(5, bindings);
    const expected = [_][]const u8{ "acquire", "let", "require", "require", "atomic_begin", "read", "require", "require", "let", "let", "let", "insert", "require", "branch_begin", "append", "branch_else", "append", "branch_end", "atomic_end" };
    try std.testing.expectEqual(expected.len, checked.events.len);
    for (expected, checked.events) |kind, event| try std.testing.expectEqualStrings(kind, @tagName(event.kind));
    try std.testing.expectEqualStrings("example.machine-id", checked.events[11].columns[0].domain.?);
    try std.testing.expect(checked.events[11].columns[0].value != null);
    try std.testing.expect(std.mem.indexOf(u8, product.steps[5].sql, "-7") != null);
    try std.testing.expect(std.mem.indexOf(u8, product.steps[5].sql, "'a''雪'") != null);
}
test "all runtime paths reject domain loss even for equal scalars and constant branches" {
    const refusals = [_][]const u8{
        "REQUIRE request.id = request.other ELSE 'No';",
        "REQUIRE request.id = -7 ELSE 'No';",
        "LET bad = CASE WHEN TRUE THEN request.id ELSE request.other END;",
        "LET bad = CASE WHEN TRUE THEN request.id ELSE -7 END;",
        "BEGIN ATOMIC IF TRUE THEN REQUIRE TRUE ELSE 'No'; ELSE PRODUCE INTO events VALUES (request.other, request.body); END IF; END;",
        "BEGIN ATOMIC INSERT INTO accepted VALUES (-7, request.body) ON CONFLICT (id) DO ASSERT SAME ROW; END;",
        "BEGIN ATOMIC PRODUCE INTO raw VALUES (request.id); END;",
        "BEGIN ATOMIC LET found = SELECT id FROM machines WHERE id = request.other; END;",
    };
    for (refusals) |body| try std.testing.expectError(error.SourceDomainMismatch, build(std.testing.allocator, body));
    const operations = [_][]const u8{
        "LET bad = request.id + 1;",           "REQUIRE request.id > $expected ELSE 'No';",
        "LET bad = CAST(request.id AS TEXT);", "LET bad = S256(request.label);",
        "REQUIRE request.flag ELSE 'No';",     "LET bad = request.label || 'suffix';",
    };
    for (operations) |body| try std.testing.expectError(error.UnsupportedNominalOperation, build(std.testing.allocator, body));
}
test "program lexical shadowing and failure continuation follow physical scopes" {
    // The LET shadows the SELECT column of the same name, so comparing it with
    // the raw text payload is valid. Looking up the Table annotation first fails.
    const product = try build(std.testing.allocator, "LET id = request.body; BEGIN ATOMIC LET found = SELECT id FROM machines WHERE id = request.body; REQUIRE found IS NOT NULL ELSE 'Missing'; END;");
    defer product.deinit();
    const failure = try build(std.testing.allocator, "LET local = request.id; REQUIRE FALSE ELSE 'No'; ON FAILURE failure BEGIN ATOMIC PRODUCE INTO events VALUES (request.id, failure.effect_outcome); END;");
    defer failure.deinit();
    try std.testing.expectEqualStrings("failure_begin", @tagName(failure.steps[5].checked.program.?.events[3].kind));
    try std.testing.expectError(error.UnknownProgramVariable, build(std.testing.allocator, "LET local = request.id; REQUIRE FALSE ELSE 'No'; ON FAILURE failure BEGIN ATOMIC PRODUCE INTO events VALUES (local, failure.effect_outcome); END;"));
}
test "nominal acquisition predicates must also satisfy native lowering" {
    const text = try source(std.testing.allocator, "REQUIRE TRUE ELSE 'No';");
    defer std.testing.allocator.free(text);
    const cases = .{
        .{ " WHERE id = $expected", @as(?anyerror, null) },
        .{ " WHERE id = other", @as(?anyerror, error.SourceDomainMismatch) },
        .{ " WHERE id = id", @as(?anyerror, error.InvalidQueuePredicate) },
        .{ " WHERE NOW() IS NOT NULL", @as(?anyerror, error.InvalidQueuePredicate) },
    };
    inline for (cases) |case| {
        const changed = try std.mem.replaceOwned(u8, std.testing.allocator, text, "AS request AS BEGIN", "AS request" ++ case[0] ++ " AS BEGIN");
        defer std.testing.allocator.free(changed);
        var diagnostic: ?p.Diagnostic = null;
        const result = c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = changed }}, .{ .compiler_revision = "predicate-test" }, &diagnostic);
        if (case[1]) |err| {
            try std.testing.expectError(err, result);
        } else (try result).deinit();
    }
}
fn allocations(allocator: std.mem.Allocator) !void {
    const product = try build(allocator, valid);
    defer product.deinit();
}
test "nominal program evidence cleans up each failed allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocations, .{});
}

test "program annotations obey compiler budgets and whole-statement bounds" {
    const text = try source(std.testing.allocator, valid);
    defer std.testing.allocator.free(text);
    const limits = .{
        .{ c.Compiler.Limits{ .work = 60 }, error.BuildWorkLimit },
        .{ c.Compiler.Limits{ .memory_bytes = 65536 }, error.BuildMemoryLimit },
        .{ c.Compiler.Limits{ .output_bytes = 1000 }, error.BuildOutputLimit },
    };
    inline for (limits) |case| {
        var diagnostic: ?p.Diagnostic = null;
        try std.testing.expectError(case[1], c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "program-bounds", .limits = case[0] }, &diagnostic));
        try diagnostic.?.validate();
    }
    var body: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer body.deinit();
    for (0..200) |_| try body.writer.writeAll("REQUIRE request.id = $expected ELSE 'WrongId'; ");
    try std.testing.expectError(error.BuildStatementLimit, build(std.testing.allocator, body.written()));
}
