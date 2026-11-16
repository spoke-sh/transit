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
    var medium: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer medium.deinit();
    for (0..120) |_| try medium.writer.writeAll("REQUIRE request.id = $expected ELSE 'WrongId'; ");
    const expanded = try build(std.testing.allocator, medium.written());
    defer expanded.deinit();
    try std.testing.expect(expanded.steps[5].sql.len > 4096);
    const long_lit = try std.testing.allocator.alloc(u8, 300_000);
    defer std.testing.allocator.free(long_lit);
    @memset(long_lit, 'x');
    const program_oversized = try std.fmt.allocPrint(
        std.testing.allocator,
        "{s} CREATE MODULE Workflow(expected MachineId, text Label) AS BEGIN CREATE PUBLIC DATAFLOW process FROM QUEUE requests AS request AS BEGIN REQUIRE request.label = $text ELSE 'WrongLabel'; REQUIRE request.label = $text ELSE 'WrongLabel'; REQUIRE request.label = $text ELSE 'WrongLabel'; REQUIRE request.label = $text ELSE 'WrongLabel'; END; END; CREATE TARGET default AS BEGIN USE Resources(TYPE MachineId, TYPE SiteId, TYPE Label, TYPE Flag); USE Workflow(MachineId(-7), Label('{s}')); END;",
        .{ declarations, long_lit },
    );
    defer std.testing.allocator.free(program_oversized);
    var limit_diag: ?p.Diagnostic = null;
    try std.testing.expectError(error.BuildStatementLimit, c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = program_oversized }}, .{ .compiler_revision = "program-bounds" }, &limit_diag));
    try limit_diag.?.validate();
    const non_program_oversized = try std.fmt.allocPrint(
        std.testing.allocator,
        "CREATE MODULE Seed(label TEXT) AS BEGIN CREATE PUBLIC TABLE items (id BIGINT PRIMARY KEY, a TEXT NOT NULL, b TEXT NOT NULL, c TEXT NOT NULL, d TEXT NOT NULL); INSERT INTO items VALUES (1, $label, $label, $label, $label); END; CREATE TARGET default AS BEGIN USE Seed('{s}'); END;",
        .{long_lit},
    );
    defer std.testing.allocator.free(non_program_oversized);
    var sql_diag: ?p.Diagnostic = null;
    try std.testing.expectError(error.BuildStatementLimit, c.compile(std.testing.allocator, &.{.{ .path = "build.transit", .text = non_program_oversized }}, .{ .compiler_revision = "program-bounds" }, &sql_diag));
    try sql_diag.?.validate();
}

const helper_types_file =
    \\CREATE PUBLIC DOMAIN OrderId AS BIGINT IDENTITY 'example.order-id';
    \\CREATE PUBLIC DOMAIN AccountId AS BIGINT IDENTITY 'example.account-id';
;

const helper_lib_file =
    \\IMPORT ids FROM 'types.transit';
    \\CREATE PUBLIC FUNCTION is_eligible(priority BIGINT, ignored ids.OrderId) RETURNS BOOLEAN AS BEGIN
    \\  RETURN priority >= 0;
    \\END;
    \\CREATE FUNCTION format_inner(prefix TEXT, body TEXT) RETURNS TEXT AS BEGIN
    \\  RETURN CASE WHEN body = '' THEN prefix ELSE prefix || ':' || body END;
    \\END;
    \\CREATE PUBLIC FUNCTION tag_note(body TEXT, ignored BIGINT) RETURNS TEXT AS BEGIN
    \\  RETURN format_inner('ord', body);
    \\END;
    \\CREATE PUBLIC FUNCTION keep_order_id(id ids.OrderId, ignored BIGINT) RETURNS ids.OrderId AS BEGIN
    \\  RETURN id;
    \\END;
    \\CREATE PUBLIC FUNCTION pair_token(tok TEXT) RETURNS TEXT AS BEGIN
    \\  RETURN tok || ':' || tok;
    \\END;
    \\CREATE PUBLIC FUNCTION append_bang(body TEXT) RETURNS TEXT AS BEGIN
    \\  RETURN body || '!';
    \\END;
    \\CREATE GUARD ensure_enabled(active BOOLEAN) AS BEGIN
    \\  IF NOT active THEN
    \\    REQUIRE FALSE ELSE 'InactiveAccount';
    \\  END IF;
    \\END;
    \\CREATE PUBLIC GUARD valid_account(accounts TABLE(id ids.AccountId PRIMARY KEY, active BOOLEAN NOT NULL), target ids.AccountId) AS BEGIN
    \\  LET found = SELECT active FROM accounts WHERE id = target;
    \\  REQUIRE found IS NOT NULL ELSE 'MissingAccount';
    \\  CHECK GUARD ensure_enabled(found.active);
    \\END;
    \\CREATE PROCEDURE publish_effects(events STREAM(id ids.OrderId NOT NULL, note TEXT NOT NULL), jobs QUEUE(id ids.OrderId NOT NULL), id ids.OrderId, note TEXT) AS BEGIN ATOMIC
    \\  PRODUCE INTO events VALUES (id, note);
    \\  ENQUEUE INTO jobs VALUES (id);
    \\END;
    \\CREATE PUBLIC PROCEDURE commit_order(
    \\  accounts TABLE(id ids.AccountId PRIMARY KEY, active BOOLEAN NOT NULL),
    \\  orders TABLE(id ids.OrderId PRIMARY KEY, account_id ids.AccountId NOT NULL, note TEXT NOT NULL),
    \\  events STREAM(id ids.OrderId NOT NULL, note TEXT NOT NULL),
    \\  jobs QUEUE(id ids.OrderId NOT NULL),
    \\  id ids.OrderId,
    \\  account_id ids.AccountId,
    \\  note TEXT
    \\) AS BEGIN ATOMIC
    \\  CHECK GUARD valid_account(accounts, account_id);
    \\  INSERT INTO orders VALUES (id, account_id, note) ON CONFLICT (id) DO ASSERT SAME ROW;
    \\  CALL publish_effects(events, jobs, id, note);
    \\END;
;

const helper_build_file =
    \\IMPORT ids FROM 'types.transit';
    \\IMPORT lib FROM 'lib.transit';
    \\CREATE MODULE Setup(in_name IDENTIFIER, acc_name IDENTIFIER, ord_name IDENTIFIER, ev_name IDENTIFIER, fol_name IDENTIFIER, order_type TYPE, account_type TYPE) AS BEGIN
    \\  CREATE PUBLIC QUEUE $in_name (id $order_type NOT NULL, account_id $account_type NOT NULL, priority BIGINT NOT NULL, note TEXT NOT NULL);
    \\  CREATE PUBLIC TABLE $acc_name (id $account_type PRIMARY KEY, active BOOLEAN NOT NULL);
    \\  CREATE PUBLIC TABLE $ord_name (id $order_type PRIMARY KEY, account_id $account_type NOT NULL, note TEXT NOT NULL);
    \\  CREATE PUBLIC STREAM $ev_name (id $order_type NOT NULL, note TEXT NOT NULL);
    \\  CREATE PUBLIC QUEUE $fol_name (id $order_type NOT NULL);
    \\  EXPORT QUEUE $in_name AS incoming;
    \\  EXPORT TABLE $acc_name AS accounts;
    \\  EXPORT TABLE $ord_name AS orders;
    \\  EXPORT STREAM $ev_name AS events;
    \\  EXPORT QUEUE $fol_name AS followups;
    \\END;
    \\CREATE MODULE Pipeline(
    \\  name IDENTIFIER,
    \\  incoming QUEUE(id ids.OrderId NOT NULL, account_id ids.AccountId NOT NULL, priority BIGINT NOT NULL, note TEXT NOT NULL),
    \\  accounts TABLE(id ids.AccountId PRIMARY KEY, active BOOLEAN NOT NULL),
    \\  orders TABLE(id ids.OrderId PRIMARY KEY, account_id ids.AccountId NOT NULL, note TEXT NOT NULL),
    \\  events STREAM(id ids.OrderId NOT NULL, note TEXT NOT NULL),
    \\  followups QUEUE(id ids.OrderId NOT NULL)
    \\) AS BEGIN
    \\  CREATE PUBLIC DATAFLOW $name FROM QUEUE $incoming AS request
    \\  WHERE lib.is_eligible(request.priority, request.id)
    \\  AS BEGIN
    \\    LET id = request.account_id;
    \\    CHECK GUARD lib.valid_account($accounts, id);
    \\    CHECK GUARD lib.valid_account($accounts, request.account_id);
    \\    LET nonce = lib.pair_token(RANDOM_TOKEN(16));
    \\    LET tagged = lib.tag_note(request.note, 0) || ':' || nonce;
    \\    LET order_id = lib.keep_order_id(request.id, 1);
    \\    BEGIN ATOMIC
    \\      CALL lib.commit_order($accounts, $orders, $events, $followups, order_id, id, tagged);
    \\    END;
    \\  END;
    \\END;
    \\CREATE TARGET default AS BEGIN
    \\  USE Setup(NAME 'incoming', NAME 'accounts', NAME 'orders', NAME 'events', NAME 'followups', TYPE ids.OrderId, TYPE ids.AccountId) AS s;
    \\  USE Pipeline(NAME 'process_orders', s.incoming, s.accounts, s.orders, s.events, s.followups);
    \\END;
;

fn compileHelperFixture(allocator: std.mem.Allocator) !*c.Product {
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(allocator, &.{
        .{ .path = "types.transit", .text = helper_types_file },
        .{ .path = "lib.transit", .text = helper_lib_file },
        .{ .path = "build.transit", .text = helper_build_file },
    }, .{ .compiler_revision = "helper-lowering" }, &diagnostic);
}

test "functions ordered guards and inline procedures lower hygienically across modules" {
    const product = try compileHelperFixture(std.testing.allocator);
    defer product.deinit();
    try std.testing.expectEqual(@as(usize, 6), product.steps.len);
    const step = product.steps[5];
    try std.testing.expectEqualStrings("root/build.transit", step.definition.source.?.slice());
    try std.testing.expectEqualStrings("root/build.transit", step.call.?.source.?.slice());

    // Multi-use impure argument RANDOM_TOKEN(16) is hoisted once into a LET binding.
    const first_rand = std.mem.indexOf(u8, step.sql, "RANDOM_TOKEN") orelse return error.TestExpectedEqual;
    try std.testing.expect(std.mem.indexOfPos(u8, step.sql, first_rand + 1, "RANDOM_TOKEN") == null);

    // Flattened CALL procedures emit exactly one BEGIN ATOMIC ... END block.
    const checked = step.checked.program.?;
    var atomic_begins: usize = 0;
    var atomic_ends: usize = 0;
    var inserts: usize = 0;
    var appends: usize = 0;
    for (checked.events) |ev| {
        if (ev.kind == .atomic_begin) atomic_begins += 1;
        if (ev.kind == .atomic_end) atomic_ends += 1;
        if (ev.kind == .insert) inserts += 1;
        if (ev.kind == .append) appends += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), atomic_begins);
    try std.testing.expectEqual(@as(usize, 1), atomic_ends);
    try std.testing.expectEqual(@as(usize, 1), inserts);
    try std.testing.expectEqual(@as(usize, 2), appends);
}

fn helperAllocations(allocator: std.mem.Allocator) !void {
    const product = try compileHelperFixture(allocator);
    defer product.deinit();
}

test "helper lowering cleans up each failed allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, helperAllocations, .{});
}

test "helper validation rejects unused invalid bodies recursion impurity visibility and mismatches" {
    const Case = struct { build_src: []const u8, lib_extra: []const u8 = "", expected: anyerror };
    const base_build =
        \\IMPORT ids FROM 'types.transit';
        \\IMPORT lib FROM 'lib.transit';
        \\CREATE MODULE Resources(order_type TYPE, account_type TYPE) AS BEGIN
        \\  CREATE PUBLIC QUEUE q (id $order_type NOT NULL, account_id $account_type NOT NULL, priority BIGINT NOT NULL, note TEXT NOT NULL);
        \\  CREATE PUBLIC TABLE accounts (id $account_type PRIMARY KEY, active BOOLEAN NOT NULL);
        \\  CREATE PUBLIC TABLE orders (id $order_type PRIMARY KEY, account_id $account_type NOT NULL, note TEXT NOT NULL);
        \\  CREATE PUBLIC STREAM events (id $order_type NOT NULL, note TEXT NOT NULL);
        \\  CREATE PUBLIC QUEUE jobs (id $order_type NOT NULL);
        \\END;
        \\CREATE TARGET default AS BEGIN
        \\  USE Resources(TYPE ids.OrderId, TYPE ids.AccountId);
    ;
    const cases = [_]Case{
        // Unused invalid helpers rejected at definition time.
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE FUNCTION unused_bad_domain(x ids.AccountId) RETURNS ids.OrderId AS BEGIN RETURN x; END;",
            .expected = error.SourceDomainMismatch,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE FUNCTION unused_impure_call() RETURNS BIGINT AS BEGIN RETURN LENGTH(RANDOM_TOKEN(16)); END;",
            .expected = error.ImpureSourceFunction,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE FUNCTION unused_impure_word() RETURNS BOOLEAN AS BEGIN RETURN CURRENT_TIMESTAMP IS NOT NULL; END;",
            .expected = error.ImpureSourceFunction,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE GUARD unused_bad_guard(t TABLE(id BIGINT PRIMARY KEY)) AS BEGIN LET r = SELECT missing FROM t WHERE id = 1; END;",
            .expected = error.UnknownProgramField,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE PROCEDURE unused_bad_proc(t TABLE(id ids.OrderId PRIMARY KEY), raw BIGINT) AS BEGIN ATOMIC INSERT INTO t VALUES (raw) ON CONFLICT (id) DO ASSERT SAME ROW; END;",
            .expected = error.SourceDomainMismatch,
        },
        // Direct and mutual recursion.
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE FUNCTION self_rec(x BIGINT) RETURNS BIGINT AS BEGIN RETURN self_rec(x); END;",
            .expected = error.RecursiveSourceCall,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE FUNCTION ping(x BIGINT) RETURNS BIGINT AS BEGIN RETURN pong(x); END; CREATE FUNCTION pong(x BIGINT) RETURNS BIGINT AS BEGIN RETURN ping(x); END;",
            .expected = error.RecursiveSourceCall,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE GUARD g1(x BIGINT) AS BEGIN CHECK GUARD g2(x); END; CREATE GUARD g2(x BIGINT) AS BEGIN CHECK GUARD g1(x); END;",
            .expected = error.RecursiveSourceCall,
        },
        .{
            .build_src = base_build ++ "END;",
            .lib_extra = "CREATE PROCEDURE p1(x BIGINT) AS BEGIN ATOMIC CALL p2(x); END; CREATE PROCEDURE p2(x BIGINT) AS BEGIN ATOMIC CALL p1(x); END;",
            .expected = error.RecursiveSourceCall,
        },
        // Cross-file visibility.
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET s = lib.format_inner('a', r.note); END; END;",
            .expected = error.PrivateSourceSymbol,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN CHECK GUARD lib.ensure_enabled(TRUE); END; END;",
            .expected = error.PrivateSourceSymbol,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN BEGIN ATOMIC CALL lib.publish_effects(events, jobs, r.id, r.note); END; END; END;",
            .expected = error.PrivateSourceSymbol,
        },
        // Helper kind mismatches and arity mismatches.
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN CHECK GUARD lib.tag_note(r.note, 0); END; END;",
            .expected = error.SourceTypeMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = lib.valid_account(accounts, r.account_id); END; END;",
            .expected = error.SourceTypeMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = lib.tag_note(r.note); END; END;",
            .expected = error.SourceArgumentCount,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN CHECK GUARD lib.valid_account(accounts); END; END;",
            .expected = error.SourceArgumentCount,
        },
        // Resource signature and domain mismatches (including unused function parameters).
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN CHECK GUARD lib.valid_account(orders, r.account_id); END; END;",
            .expected = error.TableInterfaceMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN CHECK GUARD lib.valid_account(accounts, r.id); END; END;",
            .expected = error.SourceDomainMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = lib.keep_order_id(r.account_id, 0); END; END;",
            .expected = error.SourceDomainMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = lib.tag_note(r.note, r.id); END; END;",
            .expected = error.SourceDomainMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r WHERE lib.is_eligible(r.priority, r.account_id) AS BEGIN END; END;",
            .expected = error.SourceDomainMismatch,
        },
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = lib.tag_note(r.priority, 0); END; END;",
            .expected = error.ProgramTypeMismatch,
        },
        // Multi-use impure argument in short-circuit branch cannot hoist safely.
        .{
            .build_src = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r AS BEGIN LET x = CASE WHEN r.priority > 0 THEN lib.pair_token(RANDOM_TOKEN(16)) ELSE '' END; END; END;",
            .expected = error.ImpureSourceFunction,
        },
    };
    for (cases) |case| {
        const lib_text = try std.fmt.allocPrint(std.testing.allocator, "{s}\n{s}", .{ helper_lib_file, case.lib_extra });
        defer std.testing.allocator.free(lib_text);
        var diagnostic: ?p.Diagnostic = null;
        try std.testing.expectError(case.expected, c.compile(std.testing.allocator, &.{
            .{ .path = "types.transit", .text = helper_types_file },
            .{ .path = "lib.transit", .text = lib_text },
            .{ .path = "build.transit", .text = case.build_src },
        }, .{ .compiler_revision = "helper-negative" }, &diagnostic));
        try diagnostic.?.validate();
    }

    // Cross-file dual-span diagnostic: pure string concatenation is valid in lib.transit,
    // but rejected when specialized inside a Queue acquisition predicate in build.transit.
    const bad_pred_build = base_build ++ "CREATE PUBLIC DATAFLOW d FROM QUEUE q AS r WHERE lib.append_bang(r.note) = 'x!' AS BEGIN END; END;";
    var dual_diag: ?p.Diagnostic = null;
    try std.testing.expectError(error.InvalidQueuePredicate, c.compile(std.testing.allocator, &.{
        .{ .path = "types.transit", .text = helper_types_file },
        .{ .path = "lib.transit", .text = helper_lib_file },
        .{ .path = "build.transit", .text = bad_pred_build },
    }, .{ .compiler_revision = "helper-dual-span" }, &dual_diag));
    try dual_diag.?.validate();
    try std.testing.expectEqualStrings("root/lib.transit", dual_diag.?.location.?.source.?.slice());
    var found_call_site = false;
    for (dual_diag.?.facts) |fact_opt| if (fact_opt) |fact| if (fact.field == .first_occurrence) {
        try std.testing.expectEqualStrings("root/build.transit", fact.value.?.location.source.?.slice());
        found_call_site = true;
    };
    try std.testing.expect(found_call_site);
}

fn returning(allocator: std.mem.Allocator, declaration: []const u8, body: []const u8) !*c.Product {
    const text = try std.fmt.allocPrint(allocator, "CREATE DOMAIN Id AS BIGINT IDENTITY 'example.id'; {s} " ++
        "CREATE MODULE App(ty TYPE) AS BEGIN CREATE PUBLIC QUEUE q(id $ty NOT NULL); " ++
        "CREATE PUBLIC TABLE t(id $ty PRIMARY KEY, note TEXT NOT NULL); " ++
        "CREATE PUBLIC DATAFLOW flow FROM QUEUE q AS request AS BEGIN BEGIN ATOMIC {s} END; END; END; " ++
        "CREATE TARGET default AS BEGIN USE App(TYPE Id); END;", .{ declaration, body });
    defer allocator.free(text);
    var diagnostic: ?p.Diagnostic = null;
    return c.compile(allocator, &.{.{ .path = "build.transit", .text = text }}, .{ .compiler_revision = "returns" }, &diagnostic);
}
const returning_proc =
    "CREATE PROCEDURE save(t TABLE(id Id PRIMARY KEY, note TEXT NOT NULL), id Id, note TEXT) RETURNS Id AS BEGIN ATOMIC " ++
    "LET local = id; INSERT INTO t VALUES (local, note) ON CONFLICT (id) DO ASSERT SAME ROW; RETURN local; END; " ++
    "CREATE PROCEDURE nested(t TABLE(id Id PRIMARY KEY, note TEXT NOT NULL), id Id, note TEXT) RETURNS Id AS BEGIN ATOMIC " ++
    "LET result = CALL save(t, id, note); RETURN result; END; ";
const returning_body = "LET result = CALL nested(t, request.id, RANDOM_TOKEN(16)); REQUIRE result = request.id ELSE 'WrongResult'; REQUIRE FALSE ELSE 'Rollback';";
test "returning procedure calls preserve nominal values single evaluation and one atomic boundary" {
    const product = try returning(std.testing.allocator, returning_proc, returning_body);
    defer product.deinit();
    const sql = product.steps[2].sql;
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, sql, "RANDOM_TOKEN"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, sql, "BEGIN ATOMIC"));
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, sql, "INSERT INTO"));
    try std.testing.expect(std.mem.indexOf(u8, sql, "RETURN") == null);
    const events = product.steps[2].checked.program.?.events;
    try std.testing.expectEqual(.require, events[events.len - 2].kind);
    try std.testing.expectEqual(.atomic_end, events[events.len - 1].kind);
}
test "returning procedures refuse missing early void mismatched and escaping results" {
    const Case = struct { declaration: []const u8, body: []const u8 = "", expected: anyerror };
    const cases = [_]Case{
        .{ .declaration = "CREATE PROCEDURE bad() RETURNS BIGINT AS BEGIN ATOMIC END;", .expected = error.MissingProcedureReturn },
        .{ .declaration = "CREATE PROCEDURE bad() AS BEGIN ATOMIC RETURN 1; END;", .expected = error.UnexpectedProcedureReturn },
        .{ .declaration = "CREATE PROCEDURE bad() RETURNS BIGINT AS BEGIN ATOMIC IF TRUE THEN RETURN 1; END IF; RETURN 2; END;", .expected = error.InvalidSourceTemplate },
        .{ .declaration = "CREATE PROCEDURE bad() RETURNS BIGINT AS BEGIN ATOMIC RETURN 'wrong'; END;", .expected = error.ProgramTypeMismatch },
        .{ .declaration = "CREATE PROCEDURE bad() RETURNS Id AS BEGIN ATOMIC RETURN 1; END;", .expected = error.SourceDomainMismatch },
        .{ .declaration = "CREATE PROCEDURE nothing() AS BEGIN ATOMIC END;", .body = "LET x = CALL nothing();", .expected = error.ProcedureHasNoResult },
        .{ .declaration = returning_proc, .body = "IF TRUE THEN LET x = CALL nested(t, request.id, 'ok'); END IF; REQUIRE x = request.id ELSE 'No';", .expected = error.UnknownProgramVariable },
    };
    for (cases) |case| try std.testing.expectError(case.expected, returning(std.testing.allocator, case.declaration, case.body));
}
fn returningAllocations(allocator: std.mem.Allocator) !void {
    const product = try returning(allocator, returning_proc, returning_body);
    defer product.deinit();
}
test "returning calls release every failed allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, returningAllocations, .{});
}
