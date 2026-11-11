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
test "resource kind, shape, ownership and unsupported nominal log columns reject" {
    try std.testing.expectError(error.SourceTypeMismatch, compile(resources ++ writer ++ "CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE Write(r.events, r.requests); END;"));
    try std.testing.expectError(error.TableInterfaceMismatch, compile(resources ++ "CREATE MODULE M(input QUEUE(id BIGINT NOT NULL)) AS BEGIN ENQUEUE INTO $input VALUES (1); END; CREATE TARGET default AS BEGIN USE Resources(NAME 'jobs', NAME 'events') AS r; USE M(r.requests); END;"));
    try std.testing.expectError(error.SourceTypeMismatch, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC STREAM events (id BIGINT); ENQUEUE INTO events VALUES (1); END;"));
    try std.testing.expectError(error.ForeignTableExport, compile("CREATE MODULE M(name IDENTIFIER) AS BEGIN EXPORT QUEUE $name AS work; END; CREATE TARGET default AS BEGIN CREATE PUBLIC QUEUE jobs (id BIGINT); USE M(NAME 'jobs'); END;"));
    try std.testing.expectError(error.UnsupportedNominalLog, compile("CREATE DOMAIN Id AS BIGINT IDENTITY 'id'; CREATE MODULE M(ty TYPE) AS BEGIN CREATE PUBLIC QUEUE jobs (id $ty NOT NULL); END; CREATE TARGET default AS BEGIN USE M(TYPE Id); END;"));
    try std.testing.expectError(error.ConflictingModuleInstance, compile("CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE jobs (id BIGINT); CREATE PUBLIC QUEUE jobs (id BIGINT); END;"));
}
test "log template syntax is checked in unused modules" {
    try std.testing.expectError(error.InvalidSourceTemplate, compile("CREATE MODULE unused() AS BEGIN ENQUEUE INTO absent VALUES (1,); END; CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;"));
}
