const std = @import("std");
const c = @import("root.zig");
const p = @import("transit_protocol");

fn compile(text: []const u8) !*c.Product {
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "resource-test" }, &diagnostic);
}
const resources =
    \\CREATE MODULE Resources(input IDENTIFIER, output IDENTIFIER) AS BEGIN
    \\  CREATE PUBLIC QUEUE $input (id BIGINT NOT NULL, body TEXT NOT NULL);
    \\  CREATE PUBLIC STREAM $output (id BIGINT NOT NULL, body TEXT NOT NULL);
    \\  EXPORT QUEUE $input AS requests;
    \\  EXPORT STREAM $output AS events;
    \\END;
;
const writer =
    \\CREATE MODULE Write(input QUEUE(id BIGINT NOT NULL, body TEXT NOT NULL), output STREAM(id BIGINT NOT NULL, body TEXT NOT NULL)) AS BEGIN
    \\  ENQUEUE INTO $input VALUES (1, 'request');
    \\  PRODUCE INTO $output VALUES (2, 'event');
    \\END;
;
test "typed log exports bind ordinary append SQL and survive formatting" {
    const source = resources ++ writer ++ "CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE Write(r.requests, r.events); END;";
    const result = try compile(source);
    defer result.deinit();
    try std.testing.expectEqual(4, result.steps.len);
    try std.testing.expectEqualStrings("ENQUEUE INTO \"jobs\" VALUES ( 1 , 'request' )", result.steps[2].sql);
    try std.testing.expectEqualStrings("PRODUCE INTO \"events\" VALUES ( 2 , 'event' )", result.steps[3].sql);
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var offset: usize = 0;
    const ast = try c.Syntax.parse(arena.allocator(), source, &offset);
    var buffer: [8192]u8 = undefined;
    var formatted: std.Io.Writer = .fixed(&buffer);
    try c.Format.write(source, ast, &formatted);
    const again = try compile(formatted.buffered());
    defer again.deinit();
    try std.testing.expectEqualStrings(result.sql, again.sql);
}
test "resource kind, shape, ownership and conflicting log definitions reject" {
    try std.testing.expectError(error.SourceTypeMismatch, compile(resources ++ writer ++ "CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE Write(r.events, r.requests); END;"));
    try std.testing.expectError(error.TableInterfaceMismatch, compile(resources ++ "CREATE MODULE M(input QUEUE(id BIGINT NOT NULL)) AS BEGIN ENQUEUE INTO $input VALUES (1); END; CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE M(r.requests); END;"));
    try std.testing.expectError(error.SourceTypeMismatch, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC STREAM events (id BIGINT); ENQUEUE INTO events VALUES (1); END;"));
    try std.testing.expectError(error.ForeignTableExport, compile("CREATE MODULE M(name IDENTIFIER) AS BEGIN EXPORT QUEUE $name AS work; END; CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE jobs (id BIGINT); USE M(NAME 'jobs'); END;"));
    try std.testing.expectError(error.ConflictingModuleInstance, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE jobs (id BIGINT); CREATE PUBLIC QUEUE jobs (id BIGINT); END;"));
}

const nominal_logs =
    \\CREATE DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id';
    \\CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id';
    \\CREATE MODULE Logs(id_type TYPE, input_name IDENTIFIER, output_name IDENTIFIER) AS BEGIN
    \\  CREATE PUBLIC QUEUE $input_name (id $id_type NOT NULL, body TEXT NOT NULL);
    \\  CREATE PUBLIC STREAM $output_name (id $id_type NOT NULL, body TEXT NOT NULL);
    \\  EXPORT QUEUE $input_name AS input;
    \\  EXPORT STREAM $output_name AS output;
    \\END;
;
test "nominal log schemas assignments projections and predicates survive scalar erasure" {
    const source = nominal_logs ++
        "CREATE MODULE Write(input QUEUE(id MachineId NOT NULL, body TEXT NOT NULL), output STREAM(id MachineId NOT NULL, body TEXT NOT NULL), id MachineId) AS BEGIN " ++
        "ENQUEUE INTO $input (body, id) VALUES ('request', $id); PRODUCE INTO $output VALUES ($id, 'event'); " ++
        "CONSUME e.id, _offset FROM events AS e WHERE e.id = $id AND _partition = 0; END; " ++
        "CREATE TARGET default AS BEGIN USE Logs(TYPE MachineId, NAME 'requests', NAME 'events') AS data; USE Write(data.input, data.output, MachineId(7)); END;";
    const product = try compile(source);
    defer product.deinit();
    try std.testing.expectEqual(5, product.steps.len);
    try std.testing.expectEqualStrings("example.machine-id", product.steps[0].checked.columns[0].domain.?);
    try std.testing.expectEqualStrings("ENQUEUE INTO \"requests\" ( BODY , ID ) VALUES ( 'request' , 7 )", product.steps[2].sql);
    for (product.steps[2..]) |step| {
        try std.testing.expectEqualStrings("example.machine-id", step.checked.operands[0].domain.?);
        try std.testing.expectEqual(7, step.checked.operands[0].value.?.integer);
    }
    try std.testing.expectEqual(.predicate, product.steps[4].checked.operands[0].role);
}
test "nominal log checks cover literal names identifier holes metadata and omitted fields" {
    const cases = .{
        .{ "ENQUEUE INTO requests VALUES (7, 'raw');", error.SourceDomainMismatch },
        .{ "PRODUCE INTO events VALUES ($foreign, 'foreign');", error.SourceDomainMismatch },
        .{ "PRODUCE INTO $name VALUES (7, 'raw');", error.SourceDomainMismatch },
        .{ "PRODUCE INTO raw VALUES ($id);", error.SourceDomainMismatch },
        .{ "CONSUME id FROM events WHERE id > $id;", error.UnsupportedNominalOperation },
        .{ "CONSUME id FROM events WHERE id = 7;", error.SourceDomainMismatch },
        .{ "CONSUME id FROM events WHERE _offset = $id;", error.SourceDomainMismatch },
        .{ "ENQUEUE INTO requests (body) VALUES ('missing');", error.MissingRequiredField },
    };
    inline for (cases) |case| {
        const source = nominal_logs ++ "CREATE MODULE Check(id MachineId, foreign SiteId, name IDENTIFIER) AS BEGIN " ++ case[0] ++ " END; " ++
            "CREATE TARGET default AS BEGIN USE Logs(TYPE MachineId, NAME 'requests', NAME 'events'); CREATE PUBLIC STREAM raw (id BIGINT NOT NULL); USE Check(MachineId(7), SiteId(7), NAME 'events'); END;";
        try std.testing.expectError(case[1], compile(source));
    }
    const invalid_columns = .{
        .{ "id $ty", error.UnsupportedNominalColumn },
        .{ "id $ty NOT NULL DEFAULT 7", error.UnsupportedNominalColumn },
        .{ "id $ty NOT NULL, CHECK (id > 0)", error.UnsupportedTableConstraint },
    };
    inline for (invalid_columns) |case| {
        const source = try std.fmt.allocPrint(std.testing.allocator, "CREATE DOMAIN Id AS BIGINT IDENTITY 'id'; CREATE MODULE Logs(ty TYPE) AS BEGIN CREATE PUBLIC QUEUE jobs ({s}); END; CREATE TARGET default AS BEGIN USE Logs(TYPE Id); END;", .{case[0]});
        defer std.testing.allocator.free(source);
        try std.testing.expectError(case[1], compile(source));
    }
}
fn nominalLogAllocations(allocator: std.mem.Allocator) !void {
    const source = nominal_logs ++
        "CREATE MODULE Write(id MachineId) AS BEGIN ENQUEUE INTO requests VALUES ($id, 'request'); CONSUME id FROM events WHERE id = $id; END; " ++
        "CREATE TARGET default AS BEGIN USE Logs(TYPE MachineId, NAME 'requests', NAME 'events'); USE Write(MachineId(7)); END;";
    var diagnostic: ?p.Diagnostic = null;
    const product = try c.compile(allocator, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "resource-test" }, &diagnostic);
    defer product.deinit();
    try std.testing.expectEqualStrings("example.machine-id", product.steps[2].checked.operands[0].domain.?);
}
test "nominal log checking cleans up every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, nominalLogAllocations, .{});
}
test "log template syntax is checked in unused modules" {
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE MODULE unused() AS BEGIN ENQUEUE INTO absent VALUES (1,); END; CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;"));
}

const program =
    \\CREATE MODULE Workflow(name IDENTIFIER, input QUEUE(id BIGINT NOT NULL, body TEXT NOT NULL), output STREAM(id BIGINT NOT NULL, body TEXT NOT NULL)) AS BEGIN
    \\  CREATE PUBLIC TABLE accepted (id BIGINT PRIMARY KEY, body TEXT NOT NULL);
    \\  CREATE PUBLIC DATAFLOW $name FROM QUEUE $input AS request AS BEGIN
    \\    LET body = request.body || '!';
    \\    REQUIRE request.id > 0 ELSE 'InvalidId';
    \\    BEGIN ATOMIC
    \\      INSERT INTO accepted VALUES (request.id, body) ON CONFLICT (id) DO ASSERT SAME ROW;
    \\      PRODUCE INTO $output VALUES (request.id, body);
    \\    END;
    \\  END;
    \\  AUTHORIZE DATAFLOW $name AS ROLE CURRENT_ROLE;
    \\  ACTIVATE DATAFLOW $name;
    \\END;
;
test "Queue program emission binds public resources and preserves ordered atomic instructions" {
    const result = try compile(resources ++ program ++ "CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE Workflow(NAME 'process', r.requests, r.events); END;");
    defer result.deinit();
    try std.testing.expectEqual(6, result.steps.len);
    try std.testing.expect(std.mem.indexOf(u8, result.steps[3].sql, "BEGIN ATOMIC INSERT INTO ACCEPTED") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.steps[3].sql, "REQUEST . BODY || '!'") != null);
    try std.testing.expectEqualStrings("ACTIVATE DATAFLOW \"process\"", result.steps[5].sql);
}
test "program validation preserves atomic and lifecycle boundaries" {
    try std.testing.expectError(error.MutationOutsideAtomic, compile("CREATE MODULE unused() AS BEGIN CREATE PUBLIC DATAFLOW p FROM QUEUE q AS request AS BEGIN ENQUEUE INTO q VALUES (1); END; END;"));
    try std.testing.expectError(error.InvalidDataflowTransition, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE q (id BIGINT NOT NULL); CREATE PUBLIC DATAFLOW p FROM QUEUE q AS request AS BEGIN REQUIRE TRUE ELSE 'No'; END; ACTIVATE DATAFLOW p; END;"));
    try std.testing.expectError(error.ProgramTypeMismatch, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE q (id BIGINT NOT NULL); CREATE PUBLIC DATAFLOW p FROM QUEUE q AS request AS BEGIN REQUIRE request.id ELSE 'No'; END; END;"));
    try std.testing.expectError(error.ApplicationHostUnavailable, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE q (id BIGINT NOT NULL); CREATE PUBLIC DATAFLOW p FROM QUEUE q AS request AS BEGIN LET secret = SECRET('key'); END; END;"));
    try std.testing.expectError(error.UnsupportedNominalProgram, compile("CREATE DOMAIN Id AS BIGINT IDENTITY 'id'; CREATE MODULE M(ty TYPE) AS BEGIN CREATE PUBLIC TABLE state (id $ty PRIMARY KEY); CREATE PUBLIC QUEUE q (id BIGINT NOT NULL); CREATE PUBLIC DATAFLOW p FROM QUEUE q AS request AS BEGIN BEGIN ATOMIC INSERT INTO state VALUES (request.id) ON CONFLICT (id) DO ASSERT SAME ROW; END; END; END; CREATE TARGET default AS BEGIN USE M(TYPE Id); END;"));
}
