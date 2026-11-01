const std = @import("std");
const f = @import("root.zig");
const t = std.testing;
const Cell = f.Types.Values.Cell;
const schema: f.Types.Type = .{ .structure = &.{.{ .name = "name", .type = .utf8, .nullable = true, .optional = true }} };
fn text(value: []const u8) Cell {
    return .{ .value = .{ .atom = .{ .bytes = value } } };
}

test "query collations preserve independent masks through saved scalar batch and page plans" {
    const inputs = [_]Cell{ text("a"), text("A"), text("0"), text("B"), text("b"), text("z"), .null, .missing };
    // CP037 a,b,z sort before A; UTF-8 and folded ASCII place 0 before A.
    const Case = struct { collation: f.TableSchema.Collation, mask: u8 };
    for ([_]Case{
        .{ .collation = .utf8_binary, .mask = 0b00000100 },
        .{ .collation = .ascii_ci, .mask = 0b00000100 },
        .{ .collation = .ebcdic_cp037, .mask = 0b00110001 },
        .{ .collation = .ebcdic_037_pad, .mask = 0b00110001 },
        .{ .collation = .ebcdic_1047_nopad, .mask = 0b00110001 },
    }) |case| {
        var compiled = try f.TableSelect.compile(t.allocator, "SELECT name FROM people WHERE name < 'A'", "people", schema, @splat(7), null);
        defer compiled.deinit();
        compiled.plan.collations.columns[0] = case.collation;
        var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
        const encoded = try f.LogicalPlanCodec.encode(compiled.plan, &bytes);
        var restored = try f.LogicalPlanCodec.decode(t.allocator, schema, @splat(7), encoded);
        defer restored.deinit();
        @memset(&bytes, 0);
        try t.expectEqual(case.collation, restored.plan.collations.columns[0]);
        var batch = try f.Batch.init(t.allocator, restored.plan, .{ .rows = 8, .bytes = 65536 });
        defer batch.deinit();
        var rows: [inputs.len]f.LogicalArrow.Row = undefined;
        for (&inputs, 0..) |*cell, i| {
            rows[i] = .{ .cells = @as(*const [1]Cell, @ptrCast(cell)) };
            try batch.append(rows[i].cells, .{ .row = i + 1, .boundary = 1 });
        }
        batch.evaluate();
        var outcomes: [inputs.len]@import("VectorPage.zig").Outcome = undefined;
        var sites: [inputs.len]u8 = undefined;
        @import("VectorPage.zig").logicalPage(restored.plan, &rows, &outcomes, &sites);
        for (rows, 0..) |row, i| {
            const expected = (case.mask & (@as(u8, 1) << @intCast(i))) != 0;
            var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
            try t.expectEqual(expected, try restored.plan.matches(row.cells, &failure));
            try t.expectEqual(expected, batch.outcomes[i].truth.selects());
            try t.expectEqual(expected, outcomes[i].truth.selects());
            if (i >= 6) try t.expectEqual(.unknown, outcomes[i].truth);
        }
    }
}

test "query collations bind equality fingerprints eager failures and oversized fallback" {
    var compiled = try f.TableSelect.compile(t.allocator, "SELECT name FROM people WHERE name = 'A' OR name IS TYPE_ERROR", "people", schema, @splat(7), null);
    defer compiled.deinit();
    const binary = try compiled.plan.fingerprint();
    compiled.plan.collations.columns[0] = .ascii_ci;
    try t.expect(!std.mem.eql(u8, &binary, &try compiled.plan.fingerprint()));
    var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
    try t.expect(try compiled.plan.matches(&.{text("a")}, &failure));
    const error_row = [_]Cell{.{ .type_error = .utf8 }};
    try t.expectError(error.QueryTypeError, compiled.plan.matches(&error_row, &failure));
    try t.expectEqual(@as(u8, 0), failure.?.instruction);
    var batch = try f.Batch.init(t.allocator, compiled.plan, .{ .rows = 8, .bytes = 65536 });
    defer batch.deinit();
    try batch.append(&error_row, .{ .row = 1, .boundary = 1 });
    batch.evaluate();
    try t.expect(batch.outcomes[0] == .type_error);
    try t.expectEqual(@as(u8, 0), batch.predicateFailure(0).instruction);
    // The oversized-row fallback uses Counters, independently of vector kernels.
    var counters: f.LogicalQuery.Counters = .{};
    var site: ?f.LogicalQuery.Counters.FailureSite = null;
    try t.expect(try counters.observe(compiled.plan, &.{text("a")}, &site));
    try t.expectError(error.QueryTypeError, counters.observe(compiled.plan, &error_row, &site));
}

test "query collation admission rejects foreign plans invalid profiles and unmappable values" {
    var plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(7), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = "A" } } } };
    plan.collations.columns[0] = .ebcdic_cp037;
    try plan.validate();
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const encoded = try f.LogicalPlanCodec.encode(plan, &bytes);
    bytes[4] ^= 1;
    try t.expectError(error.UnsupportedPlanDefinition, f.LogicalPlanCodec.decode(t.allocator, schema, plan.source_basis, encoded));
    bytes[4] ^= 1;
    try t.expectError(error.EndOfStream, f.LogicalPlanCodec.decode(t.allocator, schema, plan.source_basis, encoded[0 .. encoded.len - 1]));
    plan.predicate.compare.value.bytes = "東京";
    try t.expectError(error.UnrepresentableEbcdic037, plan.validate());
    plan.predicate = .all;
    var batch = try f.Batch.init(t.allocator, plan, .{ .rows = 8, .bytes = 65536 });
    defer batch.deinit();
    try t.expectError(error.UnrepresentableEbcdic037, batch.append(&.{text("東京")}, .{ .row = 1, .boundary = 1 }));
    try t.expectEqual(@as(usize, 0), batch.len);
    plan.collations.columns[0] = .icu_root;
    try t.expectError(error.UnsupportedColumnCollation, plan.validate());
    plan.collations.columns[0] = .none;
    plan.collations.columns[1] = .ascii_ci;
    try t.expectError(error.InvalidQueryCollations, plan.validate());
}

test "Table DML predicates use declared collations with independent equality and order outcomes" {
    for ([_]f.TableSchema.Collation{ .utf8_binary, .ascii_ci, .ebcdic_cp037, .ebcdic_037_pad, .ebcdic_1047_nopad }) |collation| {
        const ebcdic = collation == .ebcdic_cp037 or collation == .ebcdic_037_pad or collation == .ebcdic_1047_nopad;
        const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "name", .type = .utf8, .collation = collation }};
        const table: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 2, .columns = &columns };
        var equality = try f.TableDml.compile(t.allocator, "DELETE FROM people WHERE name = 'A'", "people", table, null);
        defer equality.deinit();
        try t.expectEqual(collation == .ascii_ci, try equality.plan.matches(&.{text("a")}));
        var order = try f.TableDml.compile(t.allocator, "UPDATE people SET name = 'X' WHERE name < 'A'", "people", table, null);
        defer order.deinit();
        try t.expectEqual(ebcdic, try order.plan.matches(&.{text("z")}));
        try t.expectEqual(!ebcdic, try order.plan.matches(&.{text("0")}));
    }
}

test "SQL column collations bind declarations defaults and added columns" {
    var ddl = try f.TableDdl.compile(t.allocator, "CREATE TABLE people (name TEXT COLLATE ASCII_CI PRIMARY KEY, code TEXT DEFAULT 'A' COLLATE EBCDIC_CP037)", null, null);
    defer ddl.deinit();
    const table = try ddl.statement.create.bind(1);
    try t.expectEqual(.ascii_ci, table.columns[0].collation);
    try t.expectEqual(.ebcdic_cp037, table.columns[1].collation);
    var added = try f.TableDdl.compile(t.allocator, "ALTER TABLE people ADD COLUMN label TEXT COLLATE UTF8_BINARY", table, null);
    defer added.deinit();
    try t.expectEqual(.utf8_binary, added.statement.alter.action.columns.add.collation);
    try t.expectError(error.IncompatibleColumnCollation, f.TableDdl.compile(t.allocator, "CREATE TABLE bad (n BIGINT COLLATE ASCII_CI)", null, null));
    try t.expectError(error.DuplicateColumnConstraint, f.TableDdl.compile(t.allocator, "CREATE TABLE bad (s TEXT COLLATE ASCII_CI COLLATE UTF8_BINARY)", null, null));
    try t.expectError(error.UnsupportedColumnCollation, f.TableDdl.compile(t.allocator, "CREATE TABLE bad (s TEXT COLLATE ICU_ROOT)", null, null));
    try t.expectError(error.UnrepresentableEbcdic037, f.TableDdl.compile(t.allocator, "CREATE TABLE bad (s TEXT COLLATE EBCDIC_CP037 DEFAULT '東京')", null, null));
}

test "EBCDIC Table collations preserve schema keys and eager repertoire admission" {
    inline for (.{
        .{ "EBCDIC_037_PAD", f.TableSchema.Collation.ebcdic_037_pad, error.UnrepresentableEbcdic037 },
        .{ "EBCDIC_1047_NOPAD", f.TableSchema.Collation.ebcdic_1047_nopad, error.UnrepresentableEbcdic1047 },
    }) |case| {
        var ddl = try f.TableDdl.compile(t.allocator, "CREATE TABLE codes (name TEXT COLLATE " ++ case[0] ++ " PRIMARY KEY)", null, null);
        defer ddl.deinit();
        const table = try ddl.statement.create.bind(1);
        var bytes: [f.TableSchema.max_bytes]u8 = undefined;
        const encoded = try table.encode(&bytes);
        var restored = try f.TableSchema.decode(t.allocator, encoded);
        defer restored.deinit();
        try t.expectEqual(case[1], restored.schema.columns[0].collation);
        var left: [f.Collation.max_sort_key_bytes]u8 = undefined;
        var right: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const a = try f.Collation.encodePrimaryKeySortKey(restored.schema, &.{text("A")}, false, &left);
        const b = try f.Collation.encodePrimaryKeySortKey(restored.schema, &.{text("A ")}, false, &right);
        try t.expectEqual(case[1] == .ebcdic_037_pad, std.mem.eql(u8, a, b));
        try t.expectError(case[2], table.columns[0].validateCell(text("東京")));
        var plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(7), .projection = &.{0}, .collations = .fromTable(table) };
        var batch = try f.Batch.init(t.allocator, plan, .{ .rows = 8, .bytes = 65536 });
        defer batch.deinit();
        // No predicate is needed to reject invalid input before it enters a batch.
        try t.expectError(case[2], batch.append(&.{text("東京")}, .{ .row = 1, .boundary = 1 }));
        try t.expectEqual(@as(usize, 0), batch.len);
        plan.predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = "A " } } };
        var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
        try t.expectEqual(case[1] == .ebcdic_037_pad, try plan.matches(&.{text("A")}, &failure));
        try t.expectError(case[2], f.TableDdl.compile(t.allocator, "CREATE TABLE bad (name TEXT COLLATE " ++ case[0] ++ " DEFAULT '東京')", null, null));
        try t.expectError(error.IncompatibleColumnCollation, f.TableDdl.compile(t.allocator, "CREATE TABLE bad (n BIGINT COLLATE " ++ case[0] ++ ")", null, null));
    }
}

test "CP1047 public comparison distinguishes CP037 punctuation independently of codec" {
    // Independently specified IBM code-page weights: CP037 not-sign 5F,
    // caret B0; CP1047 caret 5F, not-sign B0.
    try t.expectEqual(.lt, try f.Collation.compareBytes("¬", "^", .ebcdic_cp037));
    try t.expectEqual(.gt, try f.Collation.compareBytes("¬", "^", .ebcdic_1047_nopad));
    for ([_]f.TableSchema.Encoding{ .plain, .dictionary, .fsst, .ebcdic }) |encoding| {
        const column: f.TableSchema.Column = .{ .id = 1, .name = "code", .type = .utf8, .collation = .ebcdic_1047_nopad, .encoding = encoding };
        try column.validateCell(text("¬"));
        try column.validateCell(text("^"));
    }
}

test "compact string batch owns raw bytes and conflict details across allocation-free resets" {
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(7), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .bytes = "MiXeD" } } } };
    plan.collations.columns[0] = .ascii_ci;
    var batch = try f.Batch.init(probe.allocator(), plan, .{ .rows = 8, .bytes = 65536 });
    defer batch.deinit();
    try t.expectEqual(@as(usize, 16), @sizeOf(f.Batch.kernels.StringValue));
    try t.expectEqual(@as(usize, 0), @intFromPtr(batch.columns[0].data.strings.ptr) % 64);
    try t.expectEqual(@as(usize, 0), @intFromPtr(batch.columns[0].states.ptr) % 64);
    try t.expectEqual(@as(usize, 0), @intFromPtr(batch.selection.ptr) % 64);
    probe.begin(true);
    for (0..300) |_| {
        batch.reset();
        var short = "MiXeD".*;
        var long = "MiXeD Original Long Payload  ".*;
        var alternatives = [_]f.Types.Values.Alternative{
            .{ .counter = 1, .replica = 1, .value = .null },
            .{ .counter = 2, .replica = 1, .value = .{ .value = .{ .atom = .{ .bytes = &long } } } },
        };
        const before_short = batch.memory.end_index;
        try batch.append(&.{text(&short)}, .{ .row = 1, .boundary = 1 });
        try t.expectEqual(before_short, batch.memory.end_index);
        try batch.append(&.{text(&long)}, .{ .row = 2, .boundary = 1 });
        try batch.append(&.{.null}, .{ .row = 3, .boundary = 1 });
        try batch.append(&.{.missing}, .{ .row = 4, .boundary = 1 });
        try batch.append(&.{.{ .type_error = .binary }}, .{ .row = 5, .boundary = 1 });
        try batch.append(&.{.{ .conflict = &alternatives }}, .{ .row = 6, .boundary = 1 });
        @memset(&short, 'x');
        @memset(&long, 'x');
        alternatives[1].value = .null;
        batch.evaluate();
        const view = batch.columns[0].view(batch.len);
        try t.expectEqualStrings("MiXeD", view.cell(0).value.atom.bytes);
        try t.expectEqualStrings("MiXeD Original Long Payload  ", view.cell(1).value.atom.bytes);
        try t.expectEqualStrings("MiXeD Original Long Payload  ", view.cell(5).conflict[1].value.value.atom.bytes);
        try t.expectEqualSlices(f.Batch.Outcome, &.{ .{ .truth = .true_value }, .{ .truth = .false_value }, .{ .truth = .unknown }, .{ .truth = .unknown }, .type_error, .conflict }, batch.outcomes[0..6]);
    }
    try probe.verify();
}

test "compact borrowed strings preserve binary and unicode at the inline boundary" {
    const texts = [_][]const u8{ "", "a\x00", "ABCDEFGHIJKL", "ABCDEFGHIJKLM", "éÖa", "éÖa long payload", "same-prefix-aa", "same-prefix-ab" };
    for ([_]f.TableSchema.Collation{ .utf8_binary, .ascii_ci, .ebcdic_cp037 }) |collation| {
        for (texts) |literal| {
            var plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = @splat(7), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .lt, .value = .{ .bytes = literal } } } };
            plan.collations.columns[0] = collation;
            var batch = try f.Batch.init(t.allocator, plan, .{ .rows = 8, .bytes = 65536 });
            defer batch.deinit();
            for (texts, 0..) |input, i| try batch.appendBorrowedValidated(&.{text(input)}, .{ .row = i + 1, .boundary = 1 });
            batch.evaluate();
            for (texts, 0..) |input, i| {
                try t.expectEqualStrings(input, batch.columns[0].view(batch.len).cell(i).value.atom.bytes);
                var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
                try t.expectEqual(try plan.matches(&.{text(input)}, &failure), batch.outcomes[i].truth.selects());
            }
        }
    }
}
