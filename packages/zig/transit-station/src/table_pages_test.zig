const std = @import("std");
const t = std.testing;
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Index = @import("ImmutableIndex.zig");
const Data = @import("TableData.zig");
const Candidate = @import("TableCandidate.zig");
const Pages = @import("TablePages.zig");
const Head = @import("TableHead.zig");
const History = @import("TableHistory.zig");
const Changes = @import("TableChanges.zig");
const Write = @import("TableWrite.zig");
const Statement = @import("TableStatement.zig");
const Cleanup = @import("TableCleanup.zig");
const Alter = @import("TableAlter.zig");
const TableReader = @import("TableReader.zig");
const TableCreation = @import("TableCreation.zig");

test "handler creation freezes its schema and quotas and recovers the original publication receipt" {
    const limits: Pub.Limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 };
    const text: [1024]u8 = @splat('a');
    var columns = [_]f.TableSchema.Column{
        schema.columns[0],
        .{ .id = 2, .name = "value", .type = .utf8, .default = .{ .value = .{ .atom = .{ .bytes = &text } } } },
        .{ .id = 3, .name = "amount", .type = .{ .decimal = .{ .precision = 18, .scale = 2 } } },
    };
    const wide: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 4, .columns = &columns, .primary_key = &.{1} };
    for ([_]f.TableSchema.Schema{ schema, wide }) |definition| {
        var store: Store = .{};
        defer store.deinit();
        var completed: ?TableCreation.Result = null;
        var admitted: ?u64 = null;
        for (0..100) |_| {
            var discarded = try store.capture();
            _ = try TableCreation.step(t.allocator, &discarded, definition, limits);
            // Lost private proposals cannot expose a head or complete receipt.
            var turn = try store.capture();
            try t.expectError(error.TableNotFound, Head.load(&turn, 9));
            const result = try TableCreation.step(t.allocator, &turn, definition, limits);
            try t.expect(writes(turn) <= 4);
            if (admitted) |input| try t.expectEqual(input, result.admitted_input) else admitted = result.admitted_input;
            try store.commit(turn);
            if (result.state == .applied) {
                completed = result;
                break;
            }
            var changed = definition;
            changed.primary_key = &.{};
            turn = try store.capture();
            try t.expectError(error.TableCreationConflict, TableCreation.step(t.allocator, &turn, changed, limits));
            try t.expectEqual(0, writes(turn));
            var changed_limits = limits;
            changed_limits.staging_records += 1;
            try t.expectError(error.TableCreationConflict, TableCreation.step(t.allocator, &turn, definition, changed_limits));
            try t.expectEqual(0, writes(turn));
        }
        const result = completed orelse return error.CreationDidNotComplete;
        try t.expect(result.completed_input > result.admitted_input);
        var turn = try store.capture();
        var reader = try TableReader.open(t.allocator, &turn, 9);
        defer reader.deinit();
        try t.expectEqualDeep(try definition.fingerprint(), try reader.schema.schema.fingerprint());
        try t.expectEqualDeep(result, try TableCreation.step(t.allocator, &turn, definition, limits));
        try t.expectEqual(0, writes(turn));
        // The original creation result is independent of a later schema and
        // retirement. Repeating it cannot re-create or reset the Table.
        try t.expectEqual(.applied, (try sqlAlter(&store, 763, "ALTER TABLE items RENAME COLUMN value TO label")).state);
        turn = try store.capture();
        const head = try Head.load(&turn, 9);
        var retired = head;
        retired.revision += 1;
        retired.retired = true;
        try head.replace(&turn, retired);
        try store.commit(turn);
        turn = try store.capture();
        try t.expectEqualDeep(result, try TableCreation.step(t.allocator, &turn, definition, limits));
        try t.expectEqual(0, writes(turn));
        try t.expect((try Head.load(&turn, 9)).retired);
        var foreign = store.state.get(TableCreation.key(9)).?;
        foreign.data[4] ^= 1;
        try store.state.put(t.allocator, TableCreation.key(9), foreign);
        turn = try store.capture();
        try t.expectError(error.IncompatibleTableStorage, TableCreation.step(t.allocator, &turn, definition, limits));
        try t.expectEqual(0, writes(turn));
    }
}

test "handler creation cannot adopt an independently populated Table namespace" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var turn = try store.capture();
    try t.expectError(error.TableExists, TableCreation.step(t.allocator, &turn, schema, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 }));
    try t.expectEqual(0, writes(turn));
}

test "handler creation and typed row readers release allocation failures without partial work" {
    const limits: Pub.Limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 };
    const Run = struct {
        fn create(allocator: std.mem.Allocator, store: *Store) !void {
            var turn = try store.capture();
            const before = turn.decision;
            const result = TableCreation.step(allocator, &turn, schema, limits) catch |err| {
                try t.expectEqualDeep(before, turn.decision);
                return err;
            };
            try t.expectEqual(.applied, result.state);
        }
        fn read(allocator: std.mem.Allocator, store: *Store) !void {
            var turn = try store.capture();
            var reader = try TableReader.open(allocator, &turn, 9);
            defer reader.deinit();
            var page = try reader.page(allocator, &turn, null, 2);
            defer page.deinit();
            try t.expectEqual(2, page.len);
            try t.expectEqual(0, writes(turn));
        }
    };
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    try t.expectEqual(.building, (try TableCreation.step(t.allocator, &turn, schema, limits)).state);
    try store.commit(turn);
    try t.checkAllAllocationFailures(t.allocator, Run.create, .{&store});
    turn = try store.capture();
    try t.expectEqual(.applied, (try TableCreation.step(t.allocator, &turn, schema, limits)).state);
    try store.commit(turn);
    _ = try sqlStatement(&store, 764, schema, "INSERT INTO items VALUES(1,'one'),(2,'two')");
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), Run.read, .{&store});
}

test "general handler reads own wide typed rows and keep cursors at one committed cut" {
    var store: Store = .{};
    defer store.deinit();
    var definition = try f.TableDdl.compile(t.allocator, "CREATE TABLE items(id INT64 PRIMARY KEY, value TEXT, score DECIMAL(8,2), tags LIST(BOOL))", null, null);
    defer definition.deinit();
    const wide = try definition.statement.create.bind(9);
    _ = try store.tableSchema(wide);
    _ = try sqlStatement(&store, 760, wide, "INSERT INTO items VALUES(20,'one',1.25,LIST(TRUE,NULL)),(10,NULL,-2.50,LIST(FALSE)),(30,'three',NULL,LIST())");
    var turn = try store.capture();
    var reader = try TableReader.open(t.allocator, &turn, 9);
    defer reader.deinit();
    try t.expectEqual(@as(usize, 4), reader.schema.schema.columns.len);
    var first = try reader.page(t.allocator, &turn, null, 2);
    defer first.deinit();
    try t.expectEqual(2, first.len);
    try t.expectEqual(20, first.rows[0].?.row().cells[0].value.atom.signed);
    try t.expectEqual(10, first.rows[1].?.row().cells[0].value.atom.signed);
    try t.expect(first.rows[0].?.row().cells[3].value.list[1] == .null);
    const cursor = first.next.?;
    var last = try reader.page(t.allocator, &turn, cursor, 2);
    defer last.deinit();
    try t.expectEqual(1, last.len);
    try t.expectEqual(null, last.next);
    try t.expectEqual(30, last.rows[0].?.row().cells[0].value.atom.signed);
    var point = (try reader.getKey(t.allocator, &turn, &.{.{ .value = .{ .atom = .{ .signed = 10 } } }})).?;
    defer point.deinit();
    try t.expectEqual(-250, point.row().cells[2].value.atom.decimal);
    try t.expectEqual(null, try reader.get(t.allocator, &turn, .{ .origin = 2, .operation = 760, .ordinal = 30 }));
    try t.expectError(error.InvalidTablePageSize, reader.page(t.allocator, &turn, null, 0));
    try t.expectError(error.InvalidTablePageSize, reader.page(t.allocator, &turn, null, TableReader.max_page_rows + 1));
    var foreign = cursor;
    foreign.basis.object += 1;
    try t.expectError(error.StaleTableCursor, reader.page(t.allocator, &turn, foreign, 2));
    var another = try store.capture();
    try t.expectError(error.StaleTableCursor, reader.page(t.allocator, &another, cursor, 2));

    // A private head replacement is invisible to every read helper, including
    // point lookup. Nothing is implicitly committed or allowed to change cuts.
    var retired = reader.head;
    retired.revision += 1;
    retired.retired = true;
    try reader.head.replace(&turn, retired);
    const before = turn.decision;
    var private = (try reader.get(t.allocator, &turn, point.identity)).?;
    defer private.deinit();
    try t.expectEqual(-250, private.row().cells[2].value.atom.decimal);
    try t.expectEqualDeep(before, turn.decision);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.TableRetired, TableReader.open(t.allocator, &turn, 9));
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, TableReader.open(t.allocator, &turn, 9));
    try t.expectError(error.AccessDenied, turn.validate());
}

test "general Table pages preserve extreme keys, separate objects and bind every cursor field" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var sql: std.Io.Writer.Allocating = .init(t.allocator);
    defer sql.deinit();
    try sql.writer.writeAll("INSERT INTO items VALUES ");
    for (0..41) |i| {
        const key: i64 = if (i == 0) std.math.minInt(i64) else if (i == 40) std.math.maxInt(i64) else 20 - @as(i64, @intCast(i));
        if (i != 0) try sql.writer.writeByte(',');
        try sql.writer.print("({d},NULL)", .{key});
    }
    try t.expectEqual(.applied, (try sqlStatement(&store, 770, schema, sql.written())).state);
    var neighbor = schema;
    neighbor.object = 10;
    for (0..20) |_| {
        var turn = try store.capture();
        const result = try TableCreation.step(t.allocator, &turn, neighbor, .{ .record_bytes = 65536, .staging_bytes = 131072, .staging_records = 2 });
        try store.commit(turn);
        if (result.state == .applied) break;
    }
    var turn = try store.capture();
    var table = try TableReader.open(t.allocator, &turn, 9);
    defer table.deinit();
    var other = try TableReader.open(t.allocator, &turn, 10);
    defer other.deinit();
    var empty = try other.page(t.allocator, &turn, null, 8);
    defer empty.deinit();
    try t.expect(empty.len == 0 and empty.next == null);
    var cursor: ?TableReader.Cursor = null;
    var first: ?TableReader.Cursor = null;
    var count: usize = 0;
    var pages: usize = 0;
    while (true) {
        var page = try table.page(t.allocator, &turn, cursor, 8);
        defer page.deinit();
        pages += 1;
        for (page.rows[0..page.len]) |slot| {
            const row_value = slot.?.row();
            const expected: i64 = if (count == 0) std.math.minInt(i64) else if (count == 40) std.math.maxInt(i64) else 20 - @as(i64, @intCast(count));
            try t.expectEqual(expected, row_value.cells[0].value.atom.signed);
            try t.expect(row_value.cells[1] == .null);
            count += 1;
        }
        cursor = page.next;
        if (first == null) first = cursor;
        if (cursor == null) break;
    }
    try t.expectEqual(41, count);
    try t.expectEqual(6, pages);
    // Key lookup follows exact typed equality, independently of page order.
    for ([_]i64{ std.math.minInt(i64), std.math.maxInt(i64) }) |key| {
        var found = (try table.getKey(t.allocator, &turn, &.{.{ .value = .{ .atom = .{ .signed = key } } }})).?;
        defer found.deinit();
        try t.expectEqual(key, found.row().cells[0].value.atom.signed);
    }
    try t.expectError(error.StaleTableCursor, other.page(t.allocator, &turn, first, 8));
    for (0..5) |field| {
        var forged = first.?;
        switch (field) {
            0 => forged.basis.cut.view += 1,
            1 => forged.basis.resource += 1,
            2 => forged.basis.revision += 1,
            3 => forged.basis.object += 1,
            4 => forged.basis.head[0] ^= 1,
            else => unreachable,
        }
        try t.expectError(error.StaleTableCursor, table.page(t.allocator, &turn, forged, 8));
    }
    var denied = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, TableReader.open(t.allocator, &denied, 9));
    try t.expectError(error.AccessDenied, denied.validate());
}

test "general handler retained cursors preserve original schemas across current evolution" {
    const Retained = struct {
        store: *Store,
        view: p.Growth.ReadVersion,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            if (self.store.denied) return error.AccessDenied;
            return self.store.state.get(key);
        }
        pub fn prefetchBlocks(_: *@This(), _: []const p.Value) !void {}
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            if (self.store.denied) return error.AccessDenied;
            const value = self.store.blocks.records.get(key) orelse return null;
            if (value.bytes.len > output.len) return error.BlockBufferTooSmall;
            @memcpy(output[0..value.bytes.len], value.bytes);
            return output[0..value.bytes.len];
        }
    };
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    _ = try sqlStatement(&store, 761, schema, "INSERT INTO items VALUES(1,'one'),(2,'two')");
    var saved: Store = .{ .blocks = try store.blocks.clone(t.allocator), .state = try store.state.clone(t.allocator), .revision = store.revision };
    defer saved.deinit();
    var source: Retained = .{ .store = &saved, .view = .{ .id = .{ .pid = 2, .input = 40, .index = 0 }, .resource = 7, .revision = saved.revision, .created_at = 41 } };
    var reader = try TableReader.open(t.allocator, &source, 9);
    var first = try reader.page(t.allocator, &source, null, 1);
    defer first.deinit();
    try t.expectEqual(.applied, (try sqlAlter(&store, 762, "ALTER TABLE items RENAME COLUMN value TO label")).state);
    var turn = try store.capture();
    var current = try TableReader.open(t.allocator, &turn, 9);
    defer current.deinit();
    try t.expectEqualStrings("label", current.schema.schema.columns[1].name);
    try t.expectEqualStrings("value", reader.schema.schema.columns[1].name);
    try t.expectError(error.StaleTableCursor, current.page(t.allocator, &turn, first.next, 1));
    var second = try reader.page(t.allocator, &source, first.next, 1);
    defer second.deinit();
    reader.deinit();
    // Rows own their field descriptors and values after the reader is released.
    try t.expectEqualStrings("two", second.rows[0].?.row().cells[1].value.atom.bytes);
    try t.expectEqualStrings("one", first.rows[0].?.row().cells[1].value.atom.bytes);
}

fn runAlter(store: *Store, request: Alter.Request) !Write.Status {
    var turn = try store.capture();
    const original = try Head.load(&turn, 9);
    for (0..20000) |_| {
        var discarded = try store.capture();
        _ = try Alter.step(t.allocator, &discarded, request);
        turn = try store.capture();
        const head = try Head.load(&turn, 9);
        try t.expectEqualDeep(original.schema, head.schema);
        try t.expectEqualDeep(original.index, head.index);
        try t.expectEqual(original.rows, head.rows);
        const result = try Alter.step(t.allocator, &turn, request);
        try t.expect(writes(turn) <= 4);
        try store.commit(turn);
        if (result.state != .building) {
            turn = try store.capture();
            try t.expectEqualDeep(result, try Alter.step(t.allocator, &turn, request));
            try t.expectEqual(@as(usize, 0), writes(turn));
            try t.expectEqual(null, try turn.read(Statement.Progress.key(result.reference)));
            return result;
        }
        try t.expect(writes(turn) + blockWrites(turn) > 0);
    }
    return error.AlterDidNotComplete;
}
fn currentSchema(store: *Store) !f.TableSchema.Owned {
    var turn = try store.capture();
    return (try Head.load(&turn, 9)).readSchema(t.allocator, &turn);
}
fn sqlAlter(store: *Store, operation: u64, sql: []const u8) !Write.Status {
    var current = try currentSchema(store);
    defer current.deinit();
    var compiled = try f.TableDdl.compile(t.allocator, sql, current.schema, null);
    defer compiled.deinit();
    return runAlter(store, .{ .resource = 7, .principal = 1, .operation = operation, .schema = current.schema, .change = compiled.statement.alter.action.columns });
}
test "schema rewrites preserve identity, old decoders and defaults with atomic publication" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    _ = try sqlStatement(&store, 400, schema, "INSERT INTO items VALUES(1,'one'),(2,NULL),(3,'three')");
    var turn = try store.capture();
    const original = try Head.load(&turn, 9);
    try t.expectEqual(.applied, (try sqlAlter(&store, 401, "ALTER TABLE items ADD COLUMN email VARCHAR(100)")).state);
    turn = try store.capture();
    const added = try Head.load(&turn, 9);
    var added_schema = try added.readSchema(t.allocator, &turn);
    defer added_schema.deinit();
    try t.expectEqual(@as(usize, 3), added_schema.schema.columns.len);
    try t.expectEqual(@as(u64, 3), added_schema.schema.columns[2].id);
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    const identity: f.TableRow.Identity = .{ .origin = 2, .operation = 400, .ordinal = 0 };
    var rewritten = (try (Data{ .schema = added_schema.schema, .index = added.index }).get(t.allocator, &reader, identity)).?;
    defer rewritten.deinit();
    try t.expect(rewritten.row().cells[2] == .null);
    var old = (try (Data{ .schema = schema, .index = original.index }).get(t.allocator, &reader, identity)).?;
    defer old.deinit();
    try t.expectEqual(@as(usize, 2), old.row().cells.len);
    try t.expectEqualStrings("one", old.row().cells[1].value.atom.bytes);
    try t.expectEqual(.applied, (try sqlAlter(&store, 402, "ALTER TABLE items ALTER COLUMN email SET DEFAULT 'unknown'")).state);
    turn = try store.capture();
    const defaulted = try Head.load(&turn, 9);
    try t.expectEqualDeep(added.index, defaulted.index);
    var with_default = try currentSchema(&store);
    defer with_default.deinit();
    _ = try sqlStatement(&store, 403, with_default.schema, "INSERT INTO items(id,value) VALUES(4,'four')");
    turn = try store.capture();
    const inserted = try Head.load(&turn, 9);
    var future = (try (Data{ .schema = with_default.schema, .index = inserted.index }).get(t.allocator, &reader, .{ .origin = 2, .operation = 403, .ordinal = 0 })).?;
    defer future.deinit();
    try t.expectEqualStrings("unknown", future.row().cells[2].value.atom.bytes);
    try t.expectEqual(.applied, (try sqlAlter(&store, 404, "ALTER TABLE items RENAME COLUMN value TO full_name")).state);
    turn = try store.capture();
    try t.expectEqualDeep(inserted.index, (try Head.load(&turn, 9)).index);
    try t.expectEqual(.applied, (try sqlAlter(&store, 405, "ALTER TABLE items DROP COLUMN email")).state);
    try t.expectEqual(.applied, (try sqlAlter(&store, 406, "ALTER TABLE items ADD COLUMN email TEXT DEFAULT 'new'")).state);
    var replaced = try currentSchema(&store);
    defer replaced.deinit();
    try t.expectEqual(@as(u64, 4), replaced.schema.columns[2].id);
    try t.expectEqual(@as(u64, 2), replaced.schema.columns[1].id);
    try t.expectEqualStrings("full_name", replaced.schema.columns[1].name);
    const null_rejection = try sqlAlter(&store, 407, "ALTER TABLE items ALTER COLUMN full_name SET NOT NULL");
    try t.expectEqual(.null_not_allowed, null_rejection.rejection);
    try t.expectEqual(.stored, null_rejection.witness.source);
    try t.expectEqual(@as(u64, 2), null_rejection.witness.column);
    try t.expectEqualStrings("NULL", null_rejection.witness.text());
    try cleanCandidate(&store, null_rejection);
    _ = try sqlStatement(&store, 408, replaced.schema, "UPDATE items SET full_name='two' WHERE full_name IS NULL");
    try t.expectEqual(.applied, (try sqlAlter(&store, 409, "ALTER TABLE items ALTER COLUMN full_name SET NOT NULL")).state);
    var required = try currentSchema(&store);
    defer required.deinit();
    try t.expect(!required.schema.columns[1].nullable);
    const length_rejection = try sqlAlter(&store, 410, "ALTER TABLE items ALTER COLUMN full_name TYPE VARCHAR(3)");
    try t.expectEqual(.character_limit_exceeded, length_rejection.rejection);
    try cleanCandidate(&store, length_rejection);
    turn = try store.capture();
    const before_bound = try Head.load(&turn, 9);
    try t.expectEqual(.applied, (try sqlAlter(&store, 411, "ALTER TABLE items ALTER COLUMN full_name TYPE VARCHAR(30)")).state);
    turn = try store.capture();
    try t.expectEqualDeep(before_bound.index, (try Head.load(&turn, 9)).index);
    try t.expectEqual(.applied, (try sqlAlter(&store, 412, "ALTER TABLE items ALTER COLUMN id TYPE INTEGER")).state);
    turn = try store.capture();
    const converted = try Head.load(&turn, 9);
    var converted_schema = try converted.readSchema(t.allocator, &turn);
    defer converted_schema.deinit();
    try t.expect(converted_schema.schema.columns[0].type == .int32);
    const converted_data: Data = .{ .schema = converted_schema.schema, .index = converted.index };
    try t.expectEqual(identity, (try converted_data.findKey(t.allocator, &reader, &.{.{ .value = .{ .atom = .{ .signed = 1 } } }})).?);
    // Saved old work cannot be rebound to the new physical layout.
    var stale_cells: [2]f.Types.Values.Cell = undefined;
    try t.expectError(error.TableSchemaChanged, Write.step(t.allocator, &turn, insertRequest(413, 5, "stale", &stale_cells)));
}
test "late conversion failures retain original schemas and terminal rejection after conflict removal" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    _ = try sqlStatement(&store, 420, schema, "INSERT INTO items VALUES(1,'small'),(9007199254740993,'large')");
    const request: Alter.Request = .{ .resource = 7, .principal = 1, .operation = 421, .schema = schema, .change = .{ .type = .{ .column = 1, .type = .float64 } } };
    const rejected = try runAlter(&store, request);
    try t.expectEqual(.inexact, rejected.rejection);
    try t.expectEqual(@as(u64, 1), rejected.witness.column);
    try t.expectEqualStrings("9007199254740993", rejected.witness.text());
    try t.expectEqual(@as(u64, 0), rejected.changed);
    try cleanCandidate(&store, rejected);
    const overflow = try sqlAlter(&store, 422, "ALTER TABLE items ALTER COLUMN id TYPE INT8");
    try t.expectEqual(.overflow, overflow.rejection);
    try cleanCandidate(&store, overflow);
    _ = try sqlStatement(&store, 423, schema, "DELETE FROM items WHERE id>1");
    try t.expectEqualDeep(rejected, try runAlter(&store, request));
    var retry = request;
    retry.operation = 424;
    try t.expectEqual(.applied, (try runAlter(&store, retry)).state);
    var current = try currentSchema(&store);
    defer current.deinit();
    try t.expect(current.schema.columns[0].type == .float64);
    try t.expectEqualDeep(rejected, try runAlter(&store, request));
}
test "required columns, empty Tables and cancellation retain schema fences" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    _ = try sqlStatement(&store, 430, schema, "INSERT INTO items VALUES(1,'one')");
    const missing = try sqlAlter(&store, 431, "ALTER TABLE items ADD COLUMN required BOOL NOT NULL");
    try t.expectEqual(.missing_required_field, missing.rejection);
    try cleanCandidate(&store, missing);
    const request: Alter.Request = .{ .resource = 7, .principal = 1, .operation = 432, .schema = schema, .change = .{ .add = .{ .name = "extra", .type = .int64 } } };
    var turn = try store.capture();
    const admitted = try Alter.step(t.allocator, &turn, request);
    try store.commit(turn);
    for (0..1) |_| {
        turn = try store.capture();
        try t.expectEqual(.building, (try Alter.step(t.allocator, &turn, request)).state);
        try store.commit(turn);
    }
    turn = try store.capture();
    var other = request;
    other.operation = 433;
    try t.expectError(error.TableBusy, Alter.step(t.allocator, &turn, other));
    var cells: [2]f.Types.Values.Cell = undefined;
    try t.expectError(error.TableBusy, Write.step(t.allocator, &turn, insertRequest(434, 2, "blocked", &cells)));
    const cancelled = try Alter.cancel(&turn, admitted.reference);
    try store.commit(turn);
    try cleanCandidate(&store, cancelled);
    try t.expectEqualDeep(cancelled, try runAlter(&store, request));
    _ = try sqlStatement(&store, 435, schema, "DELETE FROM items");
    try t.expectEqual(.applied, (try sqlAlter(&store, 436, "ALTER TABLE items ADD COLUMN required BOOL NOT NULL")).state);
    var current = try currentSchema(&store);
    defer current.deinit();
    try t.expectEqual(@as(usize, 3), current.schema.columns.len);
    try t.expect(!current.schema.columns[2].nullable);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
}
fn cleanCandidate(store: *Store, result: Write.Status) !void {
    var turn = try store.capture();
    const head = try Head.load(&turn, 9);
    for (0..256) |_| {
        var lost = try store.capture();
        _ = try Cleanup.step(&lost, result.reference);
        turn = try store.capture();
        const complete = try Cleanup.step(&turn, result.reference);
        try t.expect(writes(turn) <= 4);
        try t.expectEqualDeep(head, try Head.load(&turn, 9));
        try t.expectEqualDeep(result, (try Write.status(&turn, result.reference)).?);
        try store.commit(turn);
        if (complete) {
            turn = try store.capture();
            try t.expect(try Cleanup.step(&turn, result.reference));
            try t.expectEqual(@as(usize, 0), writes(turn));
            return;
        }
        try t.expect(writes(turn) + blockWrites(turn) > 0);
    }
    return error.CleanupDidNotComplete;
}
test "large ALTER schema and rows resume without reading private Publications" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var source_value: [6000]u8 = @splat('s');
    var cells: [2]f.Types.Values.Cell = undefined;
    const inserted = insertRequest(440, 1, &source_value, &cells);
    for (0..100) |_| {
        var turn = try store.capture();
        const result = try Write.step(t.allocator, &turn, inserted);
        try store.commit(turn);
        if (result.state == .applied) break;
    }
    var default_value: [5000]u8 = @splat('d');
    const request: Alter.Request = .{ .resource = 7, .principal = 1, .operation = 441, .schema = schema, .change = .{ .add = .{ .name = "payload", .type = .binary, .nullable = false, .default = .{ .value = .{ .atom = .{ .bytes = &default_value } } } } } };
    try t.expectEqual(.applied, (try runAlter(&store, request)).state);
    var turn = try store.capture();
    const head = try Head.load(&turn, 9);
    var current = try head.readSchema(t.allocator, &turn);
    defer current.deinit();
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var found = (try (Data{ .schema = current.schema, .index = head.index }).get(t.allocator, &reader, inserted.change.insert.identity)).?;
    defer found.deinit();
    try t.expectEqualStrings(&source_value, found.row().cells[1].value.atom.bytes);
    try t.expectEqualStrings(&default_value, found.row().cells[2].value.atom.bytes);
    const publication: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 0), (try publication.budget(&turn)).records);
}
fn alterAllocation(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    _ = try pointToCompletion(&store, insertRequest(450, 1, "one", &cells));
    var turn = try store.capture();
    const request: Alter.Request = .{ .resource = 7, .principal = 1, .operation = 451, .schema = schema, .change = .{ .add = .{ .name = "extra", .type = .int64 } } };
    turn = try store.capture();
    _ = Alter.step(allocator, &turn, request) catch |err| {
        try t.expectEqual(@as(usize, 0), writes(turn));
        return err;
    };
    try store.commit(turn);
    // Finish the schema Publication so the injected allocation covers both old
    // row decoding and the rewritten candidate, not just schema staging.
    for (0..10) |_| {
        turn = try store.capture();
        _ = try Alter.step(t.allocator, &turn, request);
        try store.commit(turn);
        const ref = try request.reference();
        const first = (try Write.status(&turn, ref)).?.first_record;
        if (try turn.read(Pages.key(9, 'i', first)) != null) break;
        if (try turn.read(Pages.key(9, 'r', first))) |value| {
            if ((try Pub.Descriptor.decode(value)).state == .published) break;
        }
    }
    turn = try store.capture();
    _ = Alter.step(allocator, &turn, request) catch |err| {
        try t.expectEqual(@as(usize, 0), writes(turn));
        return err;
    };
}
test "ALTER allocation failure and changed progress never publish a successor" {
    try t.checkAllAllocationFailures(t.allocator, alterAllocation, .{});
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    const request: Alter.Request = .{ .resource = 7, .principal = 1, .operation = 452, .schema = schema, .change = .{ .add = .{ .name = "extra", .type = .int64 } } };
    var turn = try store.capture();
    const admitted = try Alter.step(t.allocator, &turn, request);
    try store.commit(turn);
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, Alter.step(t.allocator, &turn, request));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    turn = try store.capture();
    const location = Statement.Progress.key(admitted.reference);
    var progress = try Statement.Progress.decode((try turn.read(location)).?);
    progress.head_revision += 1;
    try turn.write(location, try progress.encode());
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.TableWriteBasisChanged, Alter.step(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
test "closed candidate cleanup releases quota without changing receipts or accepted roots" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var small_cells: [2]f.Types.Values.Cell = undefined;
    const first = insertRequest(300, 1, "accepted", &small_cells);
    const accepted = try pointToCompletion(&store, first);
    var turn = try store.capture();
    try t.expectError(error.TableCleanupNotClosed, Cleanup.step(&turn, accepted.reference));
    var large: [700000]u8 = @splat('x');
    var large_cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(301, 2, &large, &large_cells);
    const reference = try request.reference(t.allocator);
    for (0..5) |_| {
        turn = try store.capture();
        try t.expectEqual(.building, (try Write.step(t.allocator, &turn, request)).state);
        try store.commit(turn);
    }
    turn = try store.capture();
    try t.expectError(error.TableCleanupNotClosed, Cleanup.step(&turn, reference));
    const cancelled = try Write.cancel(&turn, reference);
    try store.commit(turn);
    turn = try store.capture();
    const publication: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 1), (try publication.budget(&turn)).records);
    store.denied = true;
    try t.expectError(error.AccessDenied, Cleanup.step(&turn, reference));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    try cleanCandidate(&store, cancelled);
    turn = try store.capture();
    try t.expectEqual(@as(u32, 0), (try publication.budget(&turn)).records);
    const head = try Head.load(&turn, 9);
    try t.expect(head.next_record >= cancelled.end_record);
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var kept = (try (Data{ .schema = schema, .index = head.index }).get(t.allocator, &reader, first.change.insert.identity)).?;
    defer kept.deinit();
    try t.expectEqualStrings("accepted", kept.row().cells[1].value.atom.bytes);
    try t.expectEqualDeep(cancelled, try Write.step(t.allocator, &turn, request));
    var replacement = request;
    replacement.operation = 302;
    replacement.change.insert.identity.operation = 302;
    try t.expectEqual(.building, (try Write.step(t.allocator, &turn, replacement)).state);
}
test "rejected statement cleanup skips unused IDs and retires only unpublished candidates" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    _ = try sqlStatement(&store, 310, schema, "INSERT INTO items VALUES(1,'one'),(2,'two'),(3,'three')");
    // Cross two complete scheduling batches before the duplicate so cleanup
    // still proves multiple consumed intervals and partially staged indexes.
    const rejected = try sqlStatement(&store, 311, schema, "INSERT INTO items VALUES(4,'four'),(5,'five'),(6,'six'),(7,'seven'),(8,'eight'),(9,'nine'),(10,'ten'),(11,'eleven'),(12,'twelve'),(13,'thirteen'),(14,'fourteen'),(15,'fifteen'),(16,'sixteen'),(17,'seventeen'),(18,'eighteen'),(19,'nineteen'),(20,'twenty'),(2,'duplicate')");
    try t.expectEqual(.rejected, rejected.state);
    try t.expect(rejected.end_record - rejected.first_record > 500);
    try cleanCandidate(&store, rejected);
    var turn = try store.capture();
    const head = try Head.load(&turn, 9);
    try t.expectEqual(@as(u64, 3), head.rows);
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var found = (try (Data{ .schema = schema, .index = head.index }).get(t.allocator, &reader, .{ .origin = 2, .operation = 310, .ordinal = 2 })).?;
    defer found.deinit();
    try t.expectEqualStrings("three", found.row().cells[1].value.atom.bytes);
    var records = store.state.iterator();
    while (records.next()) |entry| {
        const key = entry.key_ptr.*;
        const prefix = Pages.key(9, 'i', 0);
        if (key.len != 27 or !std.mem.eql(u8, key.data[0..14], prefix.data[0..14])) continue;
        const id = std.mem.readInt(u64, key.data[15..23], .big);
        if (id < rejected.first_record or id >= rejected.end_record) continue;
        try t.expect(key.data[14] != 'i' and key.data[14] != 'c');
        if (key.data[14] == 'r') {
            const descriptor = try Pub.Descriptor.decode(entry.value_ptr.*);
            try t.expectEqual(.retired, descriptor.state);
            try t.expectEqual(descriptor.written, descriptor.collected);
        }
    }
}
test "cleanup cursor rejects changed ranges, definitions and malformed records" {
    const cursor: Cleanup.Cursor = .{ .digest = @splat(3), .first = 2, .end = 9, .next = 4, .phase = .publications };
    const bytes = try cursor.encode();
    try t.expectEqualDeep(cursor, try Cleanup.Cursor.decode(bytes));
    for (0..bytes.len) |length| try t.expectError(error.InvalidTableCleanup, Cleanup.Cursor.decode(try p.Value.init(bytes.data[0..length])));
    var foreign = bytes;
    foreign.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Cleanup.Cursor.decode(foreign));
    var invalid = cursor;
    invalid.next = 10;
    try t.expectError(error.InvalidTableCleanup, invalid.encode());
    invalid = cursor;
    invalid.phase = .complete;
    try t.expectError(error.InvalidTableCleanup, invalid.encode());
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    const closed = try sqlStatement(&store, 320, schema, "INSERT INTO items VALUES(1,'one'),(1,'duplicate')");
    var turn = try store.capture();
    try turn.write(Cleanup.Cursor.key(closed.reference), bytes);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.InvalidTableCleanup, Cleanup.step(&turn, closed.reference));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
fn runStatement(store: *Store, request: Statement.Request) !Write.Status {
    var initial_turn = try store.capture();
    const initial = try Head.load(&initial_turn, 9);
    const reference = try request.reference(t.allocator);
    for (0..20000) |_| {
        var discarded = try store.capture();
        _ = try Statement.step(t.allocator, &discarded, request);
        // Discard every proposal once. No successful row prefix is observable.
        var turn = try store.capture();
        const visible = try Head.load(&turn, 9);
        try t.expectEqualDeep(initial.index, visible.index);
        try t.expectEqual(initial.rows, visible.rows);
        const result = try Statement.step(t.allocator, &turn, request);
        try t.expect(writes(turn) <= 4);
        try store.commit(turn);
        if (result.state != .building) {
            turn = try store.capture();
            try t.expectEqualDeep(result, try Statement.step(t.allocator, &turn, request));
            try t.expectEqual(@as(usize, 0), writes(turn));
            try t.expectEqual(null, try turn.read(Statement.Progress.key(reference)));
            return result;
        }
        try t.expect(writes(turn) + blockWrites(turn) > 0);
    }
    return error.StatementDidNotComplete;
}
fn sqlStatement(store: *Store, operation: u64, definition: f.TableSchema.Schema, sql: []const u8) !Write.Status {
    var compiled = try f.TableDml.compile(t.allocator, sql, "items", definition, null);
    defer compiled.deinit();
    return runStatement(store, .{ .resource = 7, .principal = 1, .operation = operation, .plan = compiled.plan });
}
test "finite statements publish all rows or none, exact counts and original receipts" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    const inserted = try sqlStatement(&store, 200, schema, "INSERT INTO items VALUES (1,'one'),(2,'two'),(3,'three')");
    try t.expectEqual(.applied, inserted.state);
    try t.expectEqual(@as(u64, 3), inserted.matched);
    try t.expectEqual(@as(u64, 3), inserted.changed);
    var turn = try store.capture();
    const original = try Head.load(&turn, 9);
    const rejected = try sqlStatement(&store, 201, schema, "INSERT INTO items VALUES (4,'four'),(5,'five'),(2,'duplicate')");
    try t.expectEqual(.rejected, rejected.state);
    try t.expectEqual(.row_exists, rejected.rejection);
    try t.expectEqual(.input, rejected.witness.source);
    try t.expectEqual(@as(u32, 2), rejected.witness.row.ordinal);
    try t.expectEqualStrings("2", rejected.witness.text());
    try t.expectEqual(@as(u64, 0), rejected.changed);
    turn = try store.capture();
    try t.expectEqualDeep(original.index, (try Head.load(&turn, 9)).index);
    const updated = try sqlStatement(&store, 202, schema, "UPDATE items SET value='changed' WHERE id>=2");
    try t.expectEqual(@as(u64, 2), updated.matched);
    try t.expectEqual(@as(u64, 2), updated.changed);
    const same = try sqlStatement(&store, 203, schema, "UPDATE items SET value='changed' WHERE id>=2");
    try t.expectEqual(@as(u64, 2), same.matched);
    try t.expectEqual(@as(u64, 0), same.changed);
    const absent = try sqlStatement(&store, 204, schema, "DELETE FROM items WHERE id>10");
    try t.expectEqual(@as(u64, 0), absent.matched);
    const duplicate = try sqlStatement(&store, 205, schema, "UPDATE items SET id=9 WHERE id>=2");
    try t.expectEqual(.row_exists, duplicate.rejection);
    try t.expectEqual(.stored, duplicate.witness.source);
    try t.expectEqualStrings("9", duplicate.witness.text());
    try t.expectEqual(@as(u64, 200), duplicate.witness.row.operation);
    try t.expectEqual(@as(u32, 2), duplicate.witness.row.ordinal);
    const deleted = try sqlStatement(&store, 206, schema, "DELETE FROM items WHERE id>=2");
    try t.expectEqual(@as(u64, 2), deleted.changed);
    // Conflict disappeared, but this identity still returns its original error.
    try t.expectEqualDeep(rejected, try sqlStatement(&store, 201, schema, "INSERT INTO items VALUES (4,'four'),(5,'five'),(2,'duplicate')"));
    turn = try store.capture();
    try t.expectEqual(@as(u64, 1), (try Head.load(&turn, 9)).rows);
    // The old immutable root remains readable with the old schema.
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var old = (try (Data{ .schema = schema, .index = original.index }).get(t.allocator, &reader, .{ .origin = 2, .operation = 200, .ordinal = 1 })).?;
    defer old.deinit();
    try t.expectEqualStrings("two", old.row().cells[1].value.atom.bytes);
    try t.expectError(error.TableWriteIdentityConflict, sqlStatement(&store, 201, schema, "DELETE FROM items"));
}
test "INSERT batches discard intermediate paths and reject a duplicate after a saved batch" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var compiled = try f.TableDml.compile(t.allocator, "INSERT INTO items VALUES(1,'one'),(2,'two'),(3,'three')", "items", schema, null);
    defer compiled.deinit();
    const request: Statement.Request = .{ .resource = 7, .principal = 1, .operation = 250, .plan = compiled.plan };
    var completed = false;
    for (0..3) |iteration| {
        var lost = try store.capture();
        _ = try Statement.step(t.allocator, &lost, request);
        var turn = try store.capture();
        const visible = try Head.load(&turn, 9);
        try t.expectEqualDeep(initial.index, visible.index);
        try t.expectEqual(initial.rows, visible.rows);
        const result = try Statement.step(t.allocator, &turn, request);
        try t.expect(writes(turn) + blockWrites(turn) > 0 and writes(turn) <= 4);
        if (iteration == 0) {
            try t.expectEqual(@as(usize, 3), writes(turn));
            var history_bytes: [256]u8 = undefined;
            try t.expect((try turn.readBlock(History.key(9, initial.revision), &history_bytes)) != null);
            try t.expectEqual(null, try turn.read(Pages.key(9, 'i', initial.next_record)));
            var committed = lost.committed();
            try t.expectEqual(null, try committed.read(Pages.key(9, 'i', initial.next_record)));
        }
        try store.commit(turn);
        if (result.state == .applied) {
            try t.expectEqual(@as(u64, 3), result.changed);
            completed = true;
            break;
        }
    }
    try t.expect(completed);
    var turn = try store.capture();
    const saved = try Head.load(&turn, 9);
    // Ordinal eight is in the next scheduling batch. Earlier staged rows must
    // remain invisible when it conflicts with that batch's first row.
    const rejected = try sqlStatement(&store, 251, schema, "INSERT INTO items VALUES(10,'a'),(11,'b'),(12,'c'),(13,'d'),(14,'e'),(15,'f'),(16,'g'),(17,'h'),(10,'duplicate')");
    try t.expectEqual(.rejected, rejected.state);
    try t.expectEqual(@as(u32, 8), rejected.witness.row.ordinal);
    try t.expectEqual(@as(u64, 0), rejected.changed);
    turn = try store.capture();
    try t.expectEqualDeep(saved.index, (try Head.load(&turn, 9)).index);
    try cleanCandidate(&store, rejected);
}
test "unkeyed duplicate rows retain identities across predicate updates and deletes" {
    var store: Store = .{};
    defer store.deinit();
    var unkeyed = schema;
    unkeyed.primary_key = &.{};
    _ = try store.tableSchema(unkeyed);
    const inserted = try sqlStatement(&store, 210, unkeyed, "INSERT INTO items VALUES(1,'same'),(1,'same'),(1,'same')");
    try t.expectEqual(@as(u64, 3), inserted.changed);
    const updated = try sqlStatement(&store, 211, unkeyed, "UPDATE items SET id=2");
    try t.expectEqual(@as(u64, 3), updated.changed);
    var turn = try store.capture();
    const head = try Head.load(&turn, 9);
    const data: Data = .{ .schema = unkeyed, .index = head.index };
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    for (0..3) |ordinal| {
        var found = (try data.get(t.allocator, &reader, .{ .origin = 2, .operation = 210, .ordinal = @intCast(ordinal) })).?;
        defer found.deinit();
        try t.expectEqual(@as(i128, 2), found.row().cells[0].value.atom.signed);
    }
    const deleted = try sqlStatement(&store, 212, unkeyed, "DELETE FROM items");
    try t.expectEqual(@as(u64, 3), deleted.changed);
    turn = try store.capture();
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
}
test "statement reservations fence competing work and cancellation preserves exact identity" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var compiled = try f.TableDml.compile(t.allocator, "INSERT INTO items VALUES(1,'one'),(2,'two')", "items", schema, null);
    defer compiled.deinit();
    const request: Statement.Request = .{ .resource = 7, .principal = 1, .operation = 220, .plan = compiled.plan };
    const reference = try request.reference(t.allocator);
    var turn = try store.capture();
    const admitted = try Statement.step(t.allocator, &turn, request);
    try t.expectEqual(.building, admitted.state);
    try t.expectEqual(@as(usize, 3), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    var competitor = request;
    competitor.operation += 1;
    try t.expectError(error.TableBusy, Statement.step(t.allocator, &turn, competitor));
    var cells: [2]f.Types.Values.Cell = undefined;
    try t.expectError(error.TableBusy, Write.step(t.allocator, &turn, insertRequest(222, 3, "point", &cells)));
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, Statement.cancel(&turn, reference));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    turn = try store.capture();
    const closed = try Statement.cancel(&turn, reference);
    try t.expectEqual(.cancelled, closed.state);
    try t.expectEqual(@as(u64, 0), closed.matched);
    try store.commit(turn);
    turn = try store.capture();
    const cancelled = try Head.load(&turn, 9);
    try t.expectEqualDeep(initial.index, cancelled.index);
    try t.expectEqual(@as(u64, 0), cancelled.pending);
    try t.expect(cancelled.next_record >= admitted.end_record);
    try t.expectEqualDeep(closed, try Statement.step(t.allocator, &turn, request));
    try t.expectEqualDeep(closed, try Statement.cancel(&turn, reference));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const later = try runStatement(&store, competitor);
    try t.expectEqual(.applied, later.state);
    try t.expectEqual(cancelled.next_record, later.first_record);
}
test "multi-level finite candidates retain bounded turns with a large value" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var large: [6000]u8 = @splat('x');
    var cells: [40][2]f.Types.Values.Cell = undefined;
    var input: [40][]const f.Types.Values.Cell = undefined;
    for (&cells, &input, 0..) |*storage, *value, ordinal| value.* = row(@intCast(ordinal), if (ordinal == 0) &large else "value", storage).cells;
    const request: Statement.Request = .{ .resource = 7, .principal = 1, .operation = 230, .plan = .{ .schema = schema, .name = "items", .action = .{ .insert = &input } } };
    const inserted = try runStatement(&store, request);
    try t.expectEqual(@as(u64, 40), inserted.changed);
    var turn = try store.capture();
    const head = try Head.load(&turn, 9);
    try t.expect(head.index.root.?.level >= 2);
    // A new admission must reconstruct from already published index nodes even
    // while its reservation is private. An empty-table test cannot expose this.
    const later = try sqlStatement(&store, 231, schema, "INSERT INTO items VALUES(100,'later'),(101,'last')");
    try t.expectEqual(@as(u64, 2), later.changed);
    const publication: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 0), (try publication.budget(&turn)).records);
    const deleted = try sqlStatement(&store, 232, schema, "DELETE FROM items WHERE id>=20");
    try t.expectEqual(@as(u64, 22), deleted.changed);
}
fn statementAllocation(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var compiled = try f.TableDml.compile(t.allocator, "INSERT INTO items VALUES(1,'one'),(2,'two')", "items", schema, null);
    defer compiled.deinit();
    const request: Statement.Request = .{ .resource = 7, .principal = 1, .operation = 240, .plan = compiled.plan };
    var turn = try store.capture();
    const admitted = Statement.step(allocator, &turn, request) catch |err| {
        try t.expectEqual(@as(usize, 0), writes(turn));
        return err;
    };
    try t.expectEqual(.building, admitted.state);
    try store.commit(turn);
    turn = try store.capture();
    _ = Statement.step(allocator, &turn, request) catch |err| {
        try t.expectEqual(@as(usize, 0), writes(turn));
        return err;
    };
}
test "statement allocation errors restore proposals and malformed progress rejects" {
    try t.checkAllAllocationFailures(t.allocator, statementAllocation, .{});
    const progress: Statement.Progress = .{ .digest = @splat(3), .head_revision = 4, .index = .{}, .ordinal = 0 };
    const bytes = try progress.encode();
    try t.expectEqualDeep(progress, try Statement.Progress.decode(bytes));
    for (0..bytes.len) |length| try t.expectError(error.InvalidTableStatementProgress, Statement.Progress.decode(try p.Value.init(bytes.data[0..length])));
    var foreign = bytes;
    foreign.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Statement.Progress.decode(foreign));
    var trailing = bytes;
    trailing.len += 1;
    trailing.data[trailing.len - 1] = 0;
    try t.expectError(error.InvalidTableStatementProgress, Statement.Progress.decode(trailing));
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var compiled = try f.TableDml.compile(t.allocator, "DELETE FROM items", "items", schema, null);
    defer compiled.deinit();
    var turn = try store.capture();
    try turn.write(try p.Value.init("one"), .{});
    try turn.write(try p.Value.init("two"), .{});
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Statement.step(t.allocator, &turn, .{ .resource = 7, .principal = 1, .operation = 241, .plan = compiled.plan }));
    try t.expectEqualDeep(before, turn.decision);
}
const Store = struct {
    blocks: @import("TestBlocks.zig") = .{},
    block_calls: usize = 0,
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    changed_at: std.AutoHashMapUnmanaged(p.Value, u64) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    denied: bool = false,
    fn deinit(self: *Store) void {
        self.blocks.deinit(t.allocator);
        self.state.deinit(t.allocator);
        self.changed_at.deinit(t.allocator);
    }
    fn capture(self: *Store) !Turn {
        self.input += 1;
        const turn = try Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page, .blocks = readBlocks });
        try self.blocks.views.put(t.allocator, turn.view.id, turn.view);
        return turn;
    }
    fn readBlocks(raw: *anyopaque, query: p.Growth.BlockRead.Query, body: *p.Blocks.Body) !p.Growth.BlockRead.Result {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        self.block_calls += 1;
        return self.blocks.read(query, body, self.blocks.views.get(query.source.view) orelse return error.InvalidRead);
    }
    fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !Turn.Page {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        var result: Turn.Page = .{};
        var cursor = after;
        for (&result.entries) |*slot| {
            var next: ?p.Growth.Entry = null;
            var entries = self.state.iterator();
            while (entries.next()) |entry| {
                const key = entry.key_ptr.*;
                if (cursor) |old| if (std.mem.order(u8, key.slice(), old.slice()) != .gt) continue;
                if (next) |found| if (std.mem.order(u8, key.slice(), found.key.slice()) != .lt) continue;
                next = .{ .key = key, .value = entry.value_ptr.*, .revision = self.changed_at.get(key) orelse self.revision };
            }
            slot.* = next;
            cursor = if (next) |found| found.key else return result;
        }
        result.next = cursor;
        return result;
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.denied) return error.AccessDenied;
        return self.state.get(key);
    }
    fn commit(self: *Store, turn: Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| {
                try self.state.put(t.allocator, mutation.key, value);
                try self.changed_at.put(t.allocator, mutation.key, self.revision + 1);
            } else {
                _ = self.state.remove(mutation.key);
                _ = self.changed_at.remove(mutation.key);
            }
        };
        try self.blocks.apply(t.allocator, &turn.decision.blocks, self.revision + 1);
        self.revision += 1;
    }
    fn create(self: *Store) !Pages {
        var turn = try self.capture();
        const pages = try Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 });
        try self.commit(turn);
        return pages;
    }
    fn table(self: *Store) !Head {
        return self.tableSchema(schema);
    }
    fn tableSchema(self: *Store, definition: f.TableSchema.Schema) !Head {
        const pages = try self.create();
        var buffer: [f.TableSchema.max_bytes]u8 = undefined;
        const bytes = try definition.encode(&buffer);
        const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, bytes) };
        var turn = try self.capture();
        while (try pages.stage(&turn, ref, bytes) == .progress) {
            try self.commit(turn);
            turn = try self.capture();
        }
        const head: Head = .{ .resource = 7, .object = 9, .revision = 1, .schema = ref, .next_record = 2 };
        try head.create(t.allocator, &turn);
        try self.commit(turn);
        return head;
    }
};
const schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .utf8 },
}, .primary_key = &.{1} };
fn row(ordinal: u32, value: []const u8, cells: *[2]f.Types.Values.Cell) f.TableRow.Row {
    cells.* = .{ .{ .value = .{ .atom = .{ .signed = ordinal } } }, .{ .value = .{ .atom = .{ .bytes = value } } } };
    return .{ .identity = .{ .origin = 2, .operation = 20, .ordinal = ordinal }, .cells = cells };
}
fn blockWrites(turn: Turn) usize {
    var count: usize = 0;
    for (turn.decision.blocks.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn writes(turn: Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn flush(store: *Store, pages: Pages, overlay: anytype) !void {
    for (overlay.records.items) |record| if (record.reachable) {
        while (true) {
            var turn = try store.capture();
            const result = try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes);
            try t.expect(writes(turn) <= 4);
            // A lost pre-commit turn must not advance immutable publication.
            var retry = try store.capture();
            const repeated = try pages.stage(&retry, .{ .id = record.id, .spec = record.spec }, record.bytes);
            try t.expectEqual(result, repeated);
            // The replacement input owns its own publication attribution.
            try t.expectEqual(writes(turn), writes(retry));
            try store.commit(retry);
            if (result == .ready) break;
        }
    };
}
test "small typed insert fits row, final index, head and outcome in one turn" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, 1, 1 + Candidate.max_records);
    defer overlay.deinit();
    var cells: [2]f.Types.Values.Cell = undefined;
    const data: Data = .{ .schema = schema };
    const changed = try data.insert(t.allocator, &overlay, row(1, "Ada", &cells));
    try t.expectEqual(@as(usize, 3), overlay.records.items.len);
    try t.expectEqual(@as(usize, 2), try overlay.finish(changed.data.index));
    for (overlay.records.items) |record| if (record.reachable) {
        try t.expect(record.bytes.len <= @import("BlockRecord.zig").block_bytes);
        try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes));
    };
    const head = try p.Value.init("test-head");
    const receipt = try p.Value.init("test-outcome");
    try turn.put(head, p.Value.integer(@intCast(changed.data.index.root.?.id)));
    try turn.put(receipt, p.Value.integer(1));
    try t.expectEqual(@as(usize, 2), writes(turn));
    try t.expectEqual(null, store.state.get(head));
    try store.commit(turn);
    turn = try store.capture();
    var found = (try changed.data.get(t.allocator, &reader, row(1, "Ada", &cells).identity)).?;
    defer found.deinit();
    try t.expectEqualStrings("Ada", found.row().cells[1].value.atom.bytes);
    try t.expectEqual(null, store.state.get(Pages.key(9, 'i', 2)));
    try t.expectEqualStrings("1", store.state.get(receipt).?.slice());
}
test "large records and multi-level candidates restart staging and retain old rows" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var data: Data = .{ .schema = schema };
    var next_id: u64 = 1;
    var first: ?Data = null;
    var large: [4096]u8 = @splat('x');
    for (0..40) |i| {
        var turn = try store.capture();
        var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
        var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, next_id, next_id + Candidate.max_records);
        defer overlay.deinit();
        var cells: [2]f.Types.Values.Cell = undefined;
        const inserted = row(@intCast(i), if (i == 0) &large else "short", &cells);
        const changed = try data.insert(t.allocator, &overlay, inserted);
        _ = try overlay.finish(changed.data.index);
        try flush(&store, pages, &overlay);
        turn = try store.capture();
        // Staging has not made the successor visible through the original root.
        try t.expectEqual(null, try data.get(t.allocator, &reader, inserted.identity));
        data = changed.data;
        next_id = overlay.nextId();
        if (i == 0) first = data;
        var actual = (try data.get(t.allocator, &reader, inserted.identity)).?;
        defer actual.deinit();
        try t.expectEqualStrings(inserted.cells[1].value.atom.bytes, actual.row().cells[1].value.atom.bytes);
    }
    try t.expect(data.index.root.?.level >= 2);
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var cells: [2]f.Types.Values.Cell = undefined;
    var retained = (try first.?.get(t.allocator, &reader, row(0, "", &cells).identity)).?;
    defer retained.deinit();
    try t.expectEqualStrings(&large, retained.row().cells[1].value.atom.bytes);
    const pubn: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
}
test "Table pages reject definition drift, identity conflicts, denial and cross-resource reads" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const bytes = "record";
    const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, bytes) };
    var turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, ref, bytes));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, ref, bytes));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const other: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "changed") };
    try t.expectError(error.TablePageIdentityConflict, pages.stage(&turn, other, "changed"));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var output: [256]u8 = undefined;
    try t.expectEqualStrings(bytes, try pages.read(&turn, ref, &output));
    turn.view.resource = 99;
    try t.expectError(error.CrossResourceTransaction, pages.read(&turn, ref, &output));
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, pages.read(&turn, ref, &output));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    const manifest_key = Pages.key(9, 'd', 0);
    const saved = store.state.get(manifest_key).?;
    var incompatible = saved;
    incompatible.data[4] ^= 1;
    try store.state.put(t.allocator, manifest_key, incompatible);
    turn = try store.capture();
    try t.expectError(error.IncompatibleTableStorage, pages.read(&turn, ref, &output));
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 }));
    try t.expectEqual(@as(usize, 0), writes(turn));
    _ = store.state.remove(manifest_key);
    try t.expectError(error.TableStorageNotFound, pages.read(&turn, ref, &output));
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 }));
    try store.state.put(t.allocator, manifest_key, saved);
    const broken = store.blocks.records.get(Pages.key(9, 'c', 1)).?;
    broken.bytes[broken.bytes.len - 1] ^= 1;
    try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
}
fn allocationCase(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(allocator, &reader, 1, 1 + Candidate.max_records);
    defer overlay.deinit();
    const data: Data = .{ .schema = schema };
    var cells: [2]f.Types.Values.Cell = undefined;
    const changed = try data.insert(allocator, &overlay, row(1, "Ada", &cells));
    _ = try overlay.finish(changed.data.index);
    try t.expectError(error.TableCandidateSealed, overlay.finish(changed.data.index));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
test "private candidate allocations unwind without changing the captured turn" {
    try t.checkAllAllocationFailures(t.allocator, allocationCase, .{});
}
test "a full private candidate rolls back only its unfinished batch row" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    // The first keyed row needs three records. The next row's blob fits, but
    // its first index path does not. None of that second row can escape.
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, 1, 5);
    defer overlay.deinit();
    var cells: [2]f.Types.Values.Cell = undefined;
    const first = try (Data{ .schema = schema }).insert(t.allocator, &overlay, row(1, "first", &cells));
    const count = overlay.records.items.len;
    const bytes = overlay.bytes;
    try t.expectError(error.TableCandidateCapacity, first.data.insert(t.allocator, &overlay, row(2, "second", &cells)));
    try t.expect(overlay.records.items.len > count);
    overlay.discardAfter(count);
    try t.expectEqual(bytes, overlay.bytes);
    var retained = (try first.data.get(t.allocator, &overlay, row(1, "first", &cells).identity)).?;
    defer retained.deinit();
    try t.expectEqualStrings("first", retained.row().cells[1].value.atom.bytes);
    try t.expectEqual(@as(usize, 2), try overlay.finish(first.data.index));
    try t.expectEqual(@as(usize, 0), writes(turn));
}

test "Table page bounds and failed turn composition preserve prior private writes" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    for (0..3) |i| try turn.put(p.Value.integer(@intCast(i)), p.Value.integer(1));
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Pages.create(&turn, 9, .{ .record_bytes = 4, .staging_bytes = 4, .staging_records = 1 }));
    try t.expectEqualDeep(before, turn.decision);
    turn = try store.capture();
    const pages = try Pages.create(&turn, 9, .{ .record_bytes = 4, .staging_bytes = 4, .staging_records = 1 });
    try store.commit(turn);
    turn = try store.capture();
    const too_big: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "large") };
    try t.expectError(error.PublicationTooLarge, pages.stage(&turn, too_big, "large"));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, "data") };
    try t.expectEqual(.ready, try pages.stage(&turn, ref, "data"));
    try store.commit(turn);
    var output: [256]u8 = undefined;
    const saved = try t.allocator.dupe(u8, store.blocks.records.get(Pages.key(9, 'c', 1)).?.bytes);
    defer t.allocator.free(saved);
    for (0..saved.len) |length| {
        try store.blocks.put(t.allocator, Pages.key(9, 'c', 1), saved[0..length], store.revision);
        turn = try store.capture();
        try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
    }
    try store.blocks.put(t.allocator, Pages.key(9, 'c', 1), saved, store.revision);
    turn = try store.capture();
    try t.expectError(error.TablePageBufferTooSmall, pages.read(&turn, ref, output[0..3]));
}

test "Table namespace initialization refuses orphan records without adopting their definition" {
    var store: Store = .{};
    defer store.deinit();
    const orphan = Pages.key(9, 'i', 7);
    try store.state.put(t.allocator, orphan, try p.Value.init("orphan"));
    var turn = try store.capture();
    const limits: Pub.Limits = .{ .record_bytes = 256, .staging_bytes = 256, .staging_records = 1 };
    try t.expectError(error.IncompatibleTableStorage, Pages.create(&turn, 9, limits));
    try t.expectEqual(@as(usize, 0), writes(turn));
    _ = store.state.remove(orphan);
    try turn.write(orphan, try p.Value.init("private orphan"));
    try t.expectError(error.InvalidTableStorage, Pages.create(&turn, 9, limits));
    try t.expectEqual(@as(usize, 1), writes(turn));
}

test "Table head binds schema and exact successor, retains retired data and rejects reset" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&bytes);
    const schema_ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, encoded) };
    var turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, schema_ref, encoded));
    const head: Head = .{ .resource = 7, .object = 9, .revision = 1, .schema = schema_ref, .next_record = 2 };
    try head.create(t.allocator, &turn);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(head, try Head.load(&turn, 9));
    try t.expectError(error.TableExists, head.create(t.allocator, &turn));
    var owned = try head.readSchema(t.allocator, &turn);
    defer owned.deinit();
    try t.expectEqualDeep(try schema.fingerprint(), try owned.schema.fingerprint());

    try archiveCurrent(&store);
    turn = try store.capture();
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = &turn };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(t.allocator, &reader, 2, 2 + Candidate.max_records);
    defer overlay.deinit();
    const data: Data = .{ .schema = owned.schema, .index = head.index };
    var cells: [2]f.Types.Values.Cell = undefined;
    const changed = try data.insert(t.allocator, &overlay, row(1, "Ada", &cells));
    _ = try overlay.finish(changed.data.index);
    for (overlay.records.items) |record| if (record.reachable) try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes));
    var after = head;
    after.revision += 1;
    after.index = changed.data.index;
    after.rows = 1;
    after.next_record = overlay.nextId();
    try head.replace(&turn, after);
    try turn.put(try p.Value.init("outcome"), p.Value.integer(1));
    try t.expectEqual(@as(usize, 2), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.TableHeadChanged, head.replace(&turn, after));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var retired = after;
    retired.revision += 1;
    retired.retired = true;
    try after.replace(&turn, retired);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(retired, try Head.load(&turn, 9));
    try t.expectError(error.TableRetired, retired.replace(&turn, after));
    try t.expectError(error.TableExists, head.create(t.allocator, &turn));
    var retained = (try changed.data.get(t.allocator, &reader, row(1, "", &cells).identity)).?;
    defer retained.deinit();
    try t.expectEqualStrings("Ada", retained.row().cells[1].value.atom.bytes);
    var retired_schema = try retired.readSchema(t.allocator, &turn);
    defer retired_schema.deinit();

    const head_bytes = try after.encode();
    try t.expectEqual(@as(u16, 229), head_bytes.len);
    try t.expectEqualDeep(after, try Head.decode(head_bytes));
    for (0..head_bytes.len) |length| try t.expectError(error.InvalidTableHead, Head.decode(try p.Value.init(head_bytes.data[0..length])));
    var bad = head_bytes;
    bad.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Head.decode(bad));
    bad = head_bytes;
    bad.data[bad.len] = 0;
    bad.len += 1;
    try t.expectError(error.InvalidTableHead, Head.decode(bad));
    var invalid = after;
    invalid.next_record = invalid.schema.id;
    try t.expectError(error.InvalidTableHead, invalid.encode());
    invalid = retired;
    invalid.pending = 1;
    try t.expectError(error.InvalidTableHead, invalid.encode());
    invalid = after;
    invalid.rows = 2;
    try t.expectError(error.InvalidTableHead, invalid.readSchema(t.allocator, &turn));
}

fn expectHex(hex: []const u8, bytes: []const u8) !void {
    var output: [512]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&output, hex), bytes);
}
test "typed Table head and page layouts match independent Python bytes" {
    const Fixture = struct { native_definition: []const u8, creation_receipt_hex: []const u8, creation_key_hex: []const u8, manifest_hex: []const u8, block_hex: []const u8, head_hex: []const u8, head_key_hex: []const u8, history_hex: []const u8, history_key_hex: []const u8, page_key_hex: []const u8, write_key_hex: []const u8, write_status_hex: []const u8, write_rejection_hex: []const u8, statement_progress_hex: []const u8, statement_progress_key_hex: []const u8, cleanup_hex: []const u8, cleanup_key_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-storage.json"), .{});
    defer fixture.deinit();
    const expected = fixture.value;
    try t.expectEqualStrings(@tagName(p.Growth.current_definition), expected.native_definition);
    var minimum: [21]u8 = undefined;
    minimum[0] = 'R';
    minimum[1..].* = try (f.TableRow.Identity{ .origin = 2, .operation = 30, .ordinal = 0 }).encode();
    const head: Head = .{
        .resource = 7,
        .object = 9,
        .revision = 4,
        .schema = .{ .id = 7, .spec = .{ .format = Pages.schema_format, .length = 120, .digest = @splat(17) } },
        .index = .{ .root = .{ .id = 9, .spec = .{ .format = Index.format, .length = 180, .digest = @splat(34) }, .level = 0, .minimum = try Index.Key.init(&minimum), .entries = 3 } },
        .rows = 3,
        .next_record = 10,
    };
    const encoded = try head.encode();
    try expectHex(expected.head_hex, encoded.slice());
    try t.expectEqualDeep(head, try Head.decode(encoded));
    try expectHex(expected.head_key_hex, Head.key(9).slice());
    const history: History.Record = .{ .head = head, .committed = 27 };
    try expectHex(expected.history_hex, (try history.encode()).slice());
    try t.expectEqualDeep(history, try History.Record.decode(try history.encode()));
    try expectHex(expected.history_key_hex, History.key(9, 4).slice());
    try expectHex(expected.page_key_hex, Pages.key(9, 'c', 7).slice());
    const receipt: Write.Status = .{
        .reference = .{ .resource = 7, .object = 9, .principal = 1, .operation = 21, .digest = @splat(51) },
        .admitted_input = 12,
        .completed_input = 15,
        .basis_revision = 1,
        .first_record = 2,
        .end_record = 5,
        .matched = 1,
        .changed = 1,
        .state = .applied,
    };
    const receipt_bytes = try receipt.encode();
    try expectHex(expected.write_key_hex, receipt.reference.key().slice());
    try expectHex(expected.write_status_hex, receipt_bytes.slice());
    var rejected = receipt;
    rejected.state = .rejected;
    rejected.rejection = .row_exists;
    rejected.route = .statement;
    rejected.matched = 0;
    rejected.changed = 0;
    const evidence_schema: f.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    rejected.witness = try f.TableWitness.key(.input, evidence_schema, .{ .identity = .{ .origin = 2, .operation = 21, .ordinal = 4 }, .cells = &.{.{ .value = .{ .atom = .{ .signed = 5 } } }} });
    try expectHex(expected.write_rejection_hex, (try rejected.encode()).slice());
    try t.expectEqualDeep(rejected, try Write.Status.decode(try rejected.encode()));
    const progress: Statement.Progress = .{ .digest = receipt.reference.digest, .head_revision = 8, .index = head.index, .cursor = .{ .origin = 2, .operation = 30, .ordinal = 1 }, .matched = 2, .changed = 1 };
    const progress_bytes = try progress.encode();
    try expectHex(expected.statement_progress_hex, progress_bytes.slice());
    try expectHex(expected.statement_progress_key_hex, Statement.Progress.key(receipt.reference).slice());
    try t.expectEqualDeep(progress, try Statement.Progress.decode(progress_bytes));
    const cleanup: Cleanup.Cursor = .{ .digest = receipt.reference.digest, .first = 2, .end = 600, .next = 199, .phase = .publications };
    const cleanup_bytes = try cleanup.encode();
    try expectHex(expected.cleanup_hex, cleanup_bytes.slice());
    try expectHex(expected.cleanup_key_hex, Cleanup.Cursor.key(receipt.reference).slice());
    try t.expectEqualDeep(cleanup, try Cleanup.Cursor.decode(cleanup_bytes));
    try t.expectEqualDeep(receipt, try Write.Status.decode(receipt_bytes));
    var invalid_route = receipt_bytes;
    invalid_route.data[158] = 0;
    try t.expectError(error.InvalidTableWriteStatus, Write.Status.decode(invalid_route));
    invalid_route.data[158] = 3; // ALTER cannot claim the point receipt's row counts.
    try t.expectError(error.InvalidTableWriteStatus, Write.Status.decode(invalid_route));
    for (0..receipt_bytes.len) |length| try t.expectError(error.InvalidTableWriteStatus, Write.Status.decode(try p.Value.init(receipt_bytes.data[0..length])));
    var wrong = receipt_bytes;
    wrong.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Write.Status.decode(wrong));
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const pages = try Pages.create(&turn, 9, .{ .record_bytes = 65536, .staging_bytes = 65536, .staging_records = 1 });
    try expectHex(expected.manifest_hex, (try turn.read(Pages.key(9, 'd', 0))).?.slice());
    const bytes = "typed page";
    try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = 7, .spec = try Pub.Digest.of(Pages.schema_format, bytes) }, bytes));
    var block_buffer: [p.Blocks.max_block_bytes]u8 = undefined;
    try expectHex(expected.block_hex, (try turn.readBlock(Pages.key(9, 'c', 7), &block_buffer)).?);
}

fn archiveCurrent(store: *Store) !void {
    var turn = try store.capture();
    _ = try History.stage(try Head.load(&turn, 9), &turn);
    try store.commit(turn);
}
fn pointToCompletion(store: *Store, request: Write.Request) !Write.Status {
    for (0..100) |_| {
        var turn = try store.capture();
        const result = try Write.step(t.allocator, &turn, request);
        try t.expect(writes(turn) <= 4);
        try store.commit(turn);
        if (result.state != .building) return result;
    }
    return error.UnfinishedPointWrite;
}

test "Table snapshot and complete tail retain paired changes and explicit no-op revisions" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var turn = try store.capture();
    var source = turn.committed();
    const initial = try History.current(&source, 9);
    var first_cells: [2]f.Types.Values.Cell = undefined;
    var second_cells: [2]f.Types.Values.Cell = undefined;
    const first = insertRequest(600, 1, "one", &first_cells);
    const second = insertRequest(601, 2, "two", &second_cells);
    _ = try pointToCompletion(&store, first);
    _ = try pointToCompletion(&store, second);
    var update = first;
    update.operation = 602;
    var changed_cells = first_cells;
    changed_cells[1] = .{ .value = .{ .atom = .{ .bytes = "changed" } } };
    update.change = .{ .update = .{ .identity = first.change.insert.identity, .cells = &changed_cells } };
    _ = try pointToCompletion(&store, update);
    update.operation = 603;
    const unchanged = try pointToCompletion(&store, update);
    try t.expectEqual(0, unchanged.changed);
    var remove = second;
    remove.operation = 604;
    remove.change = .{ .delete = second.change.insert.identity };
    _ = try pointToCompletion(&store, remove);

    // Backfill was delayed while all later changes committed. One current
    // captured source still proves every original predecessor and successor.
    turn = try store.capture();
    source = turn.committed();
    const upper = try History.current(&source, 9);
    try t.expectEqual(@as(u64, 6), upper.head.revision);
    try t.expectEqualDeep(initial, try History.at(&source, upper, initial.committed));
    try t.expectEqualDeep(upper, try History.at(&source, upper, turn.view.revision));
    var accepted = initial;
    var changes: usize = 0;
    var empty: usize = 0;
    while (try Changes.next(&source, accepted)) |transaction| {
        var diff = try Changes.Diff.open(t.allocator, &source, transaction);
        defer diff.deinit();
        var cursor: Changes.Cursor = .{};
        while (true) switch (try diff.step(&source, &cursor)) {
            .progress => {},
            .complete => break,
            .change => |value| {
                var change = value;
                defer change.deinit();
                switch (changes) {
                    0 => {
                        try t.expect(change.before == null);
                        try t.expectEqualDeep(first.change.insert.identity, change.identity);
                        try t.expectEqualStrings("one", change.after.?.row().cells[1].value.atom.bytes);
                    },
                    1 => {
                        try t.expect(change.before == null);
                        try t.expectEqualDeep(second.change.insert.identity, change.identity);
                        try t.expectEqualStrings("two", change.after.?.row().cells[1].value.atom.bytes);
                    },
                    2 => {
                        try t.expectEqualDeep(first.change.insert.identity, change.identity);
                        try t.expectEqualStrings("one", change.before.?.row().cells[1].value.atom.bytes);
                        try t.expectEqualStrings("changed", change.after.?.row().cells[1].value.atom.bytes);
                    },
                    3 => {
                        try t.expect(change.after == null);
                        try t.expectEqualDeep(second.change.insert.identity, change.identity);
                        try t.expectEqualStrings("two", change.before.?.row().cells[1].value.atom.bytes);
                    },
                    else => return error.ExtraChange,
                }
                changes += 1;
            },
        };
        try t.expect(cursor.complete);
        if (cursor.changes == 0) empty += 1;
        // This is the same exact transaction on retry; local cursor progress
        // did not acknowledge it or advance the source owner's history.
        try t.expectEqualDeep(transaction, (try Changes.next(&source, accepted)).?);
        accepted = transaction.after;
        try t.expectEqualDeep(accepted, try History.at(&source, upper, accepted.committed));
    }
    try t.expectEqual(4, changes);
    try t.expect(empty >= 1);
    try t.expectEqualDeep(upper, accepted);
    const saved = try accepted.encode();
    try t.expectEqualDeep(accepted, try History.Record.decode(saved));
    for (0..saved.len) |size| {
        if (History.Record.decode(try p.Value.init(saved.slice()[0..size]))) |_| return error.AcceptedTruncatedHistory else |_| {}
    }
    var incompatible = saved;
    incompatible.data[16] ^= 1; // Definition inside the complete STH1 record.
    try t.expectError(error.IncompatibleTableStorage, History.Record.decode(incompatible));
    const first_history = History.key(9, initial.head.revision);
    const original = store.blocks.records.fetchRemove(first_history).?.value;
    try t.expectError(error.TableHistoryGap, Changes.next(&source, initial));
    try store.blocks.records.put(t.allocator, first_history, original);
    store.denied = true;
    try t.expectError(error.AccessDenied, Changes.next(&source, accepted));
}
fn insertRequest(operation: u64, key_value: i128, value: []const u8, cells: *[2]f.Types.Values.Cell) Write.Request {
    cells.* = .{ .{ .value = .{ .atom = .{ .signed = key_value } } }, .{ .value = .{ .atom = .{ .bytes = value } } } };
    return .{ .resource = 7, .principal = 1, .operation = operation, .schema = schema, .change = .{ .insert = .{ .identity = .{ .origin = 2, .operation = operation, .ordinal = 0 }, .cells = cells } } };
}
fn allocationChanges(allocator: std.mem.Allocator, store: *Store, transaction: Changes.Transaction) !void {
    var turn = try store.capture();
    var source = turn.committed();
    var diff = try Changes.Diff.open(allocator, &source, transaction);
    defer diff.deinit();
    var cursor: Changes.Cursor = .{};
    var step = diff.step(&source, &cursor) catch |err| {
        try t.expectEqualDeep(Changes.Cursor{}, cursor);
        return err;
    };
    try t.expectEqual(.change, std.meta.activeTag(step));
    defer step.change.deinit();
    try t.expectEqual(@as(usize, 2), step.change.before.?.row().cells.len);
    try t.expectEqual(@as(usize, 3), step.change.after.?.row().cells.len);
    try t.expectEqual(@as(i128, 7), step.change.after.?.row().cells[2].value.atom.signed);
    try t.expectEqual(.complete, try diff.step(&source, &cursor));
}
test "Table change pairs retain both schemas and allocation failure never advances a row" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    _ = try pointToCompletion(&store, insertRequest(650, 1, "value", &cells));
    var turn = try store.capture();
    var source = turn.committed();
    var previous = try History.current(&source, 9);
    _ = try sqlAlter(&store, 651, "ALTER TABLE items ADD COLUMN amount BIGINT DEFAULT 7");
    turn = try store.capture();
    source = turn.committed();
    var transition: ?Changes.Transaction = null;
    while (try Changes.next(&source, previous)) |transaction| {
        if (!std.meta.eql(transaction.before.head.schema, transaction.after.head.schema)) transition = transaction;
        previous = transaction.after;
    }
    try t.expect(transition != null);
    try t.checkAllAllocationFailures(t.allocator, allocationChanges, .{ &store, transition.? });
}
test "point write publication retains exact counts, rejection and receipts after retirement after explicit predecessor staging" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(21, 1, "one", &cells);
    const ref = try request.reference(t.allocator);
    try archiveCurrent(&store);
    var turn = try store.capture();
    const applied = try Write.step(t.allocator, &turn, request);
    try t.expectEqual(.applied, applied.state);
    try t.expectEqual(@as(u64, 1), applied.matched);
    try t.expectEqual(@as(u64, 1), applied.changed);
    try t.expectEqual(@as(usize, 2), writes(turn));
    var before_commit = try store.capture();
    try t.expectEqualDeep(initial, try Head.load(&before_commit, 9));
    try t.expectEqual(null, try Write.status(&before_commit, ref));
    try store.commit(turn);
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqualDeep(applied, try Write.step(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const inserted = try Head.load(&turn, 9);

    var update = request;
    update.operation = 22;
    update.change = .{ .update = request.change.insert };
    const same = try Write.step(t.allocator, &turn, update);
    try t.expectEqual(.applied, same.state);
    try t.expectEqual(@as(u64, 1), same.matched);
    try t.expectEqual(@as(u64, 0), same.changed);
    try t.expectEqual(@as(usize, 2), writes(turn));
    try t.expectEqual(inserted.next_record, (try Head.load(&turn, 9)).next_record);
    try store.commit(turn);

    try archiveCurrent(&store);
    turn = try store.capture();
    var duplicate_cells: [2]f.Types.Values.Cell = undefined;
    const duplicate = insertRequest(23, 1, "two", &duplicate_cells);
    const rejected = try Write.step(t.allocator, &turn, duplicate);
    try t.expectEqual(.rejected, rejected.state);
    try t.expectEqual(.row_exists, rejected.rejection);
    try t.expectEqual(@as(usize, 1), writes(turn));
    try store.commit(turn);

    try archiveCurrent(&store);
    turn = try store.capture();
    var remove = request;
    remove.operation = 24;
    remove.change = .{ .delete = request.change.insert.identity };
    const removed = try Write.step(t.allocator, &turn, remove);
    try t.expectEqual(@as(u64, 1), removed.changed);
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
    try store.commit(turn);
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqualDeep(rejected, try Write.step(t.allocator, &turn, duplicate));
    remove.operation = 25;
    const absent = try Write.step(t.allocator, &turn, remove);
    try t.expectEqual(@as(u64, 0), absent.matched);
    try t.expectEqual(@as(u64, 0), absent.changed);
    try store.commit(turn);

    try archiveCurrent(&store);
    turn = try store.capture();
    const current = try Head.load(&turn, 9);
    var retired = current;
    retired.revision += 1;
    retired.retired = true;
    try current.replace(&turn, retired);
    try store.commit(turn);
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqualDeep(applied, try Write.step(t.allocator, &turn, request));
    try t.expectEqualDeep(rejected, try Write.step(t.allocator, &turn, duplicate));
    var conflicting = request;
    conflicting.change.insert.cells = &duplicate_cells;
    try t.expectError(error.TableWriteIdentityConflict, Write.step(t.allocator, &turn, conflicting));
    try t.expectEqual(@as(usize, 0), writes(turn));
}
test "large point write reserves before staging, fences competitors and accepts one complete root" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var large: [300000]u8 = @splat('x');
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(31, 1, &large, &cells);
    var turn = try store.capture();
    var result = try Write.step(t.allocator, &turn, request);
    try t.expectEqual(.building, result.state);
    try t.expectEqual(@as(usize, 4), writes(turn));
    try t.expectEqual(.staging, (try (Pub{ .resource = 7, .domain = .table, .namespace = 9 }).inspect(&turn, initial.next_record)).state);
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
    try t.expectEqual(initial.next_record, result.first_record);
    try store.commit(turn);
    const admitted = result;
    turn = try store.capture();
    var other_cells: [2]f.Types.Values.Cell = undefined;
    const other = insertRequest(32, 2, "blocked", &other_cells);
    try t.expectError(error.TableBusy, Write.step(t.allocator, &turn, other));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var stages: usize = 0;
    while (result.state == .building) {
        turn = try store.capture();
        result = try Write.step(t.allocator, &turn, request);
        try t.expectEqual(admitted.admitted_input, result.admitted_input);
        try t.expectEqual(admitted.first_record, result.first_record);
        try t.expectEqual(admitted.end_record, result.end_record);
        var observer = try store.capture();
        try t.expectEqual(@as(u64, 0), (try Head.load(&observer, 9)).rows);
        try t.expectEqual(.building, (try Write.status(&observer, try request.reference(t.allocator))).?.state);
        // Discard this private proposal, recompute from the persisted source,
        // then lose the successful reply by resuming again on the next iteration.
        turn = try store.capture();
        result = try Write.step(t.allocator, &turn, request);
        try store.commit(turn);
        stages += 1;
        try t.expect(stages < 64);
    }
    // Packed staging still crosses committed cuts and exercises exact resumption.
    try t.expect(stages > 1 and stages <= 16);
    try t.expectEqual(.applied, result.state);
    turn = try store.capture();
    try t.expectEqualDeep(result, try Write.step(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const head = try Head.load(&turn, 9);
    try t.expectEqual(@as(u64, 1), head.rows);
    try t.expectEqual(@as(u64, 0), head.pending);
    try t.expectEqual(admitted.end_record, head.next_record);
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var saved = (try (Data{ .schema = schema, .index = head.index }).get(t.allocator, &reader, request.change.insert.identity)).?;
    defer saved.deinit();
    try t.expectEqualStrings(&large, saved.row().cells[1].value.atom.bytes);
}
test "point cancellation retains reservation and exact terminal result while new work proceeds" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    var large: [700000]u8 = @splat('x');
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(41, 1, &large, &cells);
    const ref = try request.reference(t.allocator);
    var turn = try store.capture();
    const admitted = try Write.step(t.allocator, &turn, request);
    try store.commit(turn);
    for (0..2) |_| {
        turn = try store.capture();
        try t.expectEqual(.building, (try Write.step(t.allocator, &turn, request)).state);
        try store.commit(turn);
    }
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, Write.cancel(&turn, ref));
    try t.expectError(error.AccessDenied, turn.validate());
    store.denied = false;
    turn = try store.capture();
    const cancelled = try Write.cancel(&turn, ref);
    try t.expectEqual(.cancelled, cancelled.state);
    try t.expectEqual(@as(usize, 2), writes(turn));
    try store.commit(turn);
    turn = try store.capture();
    const empty = try Head.load(&turn, 9);
    try t.expectEqual(@as(u64, 0), empty.rows);
    try t.expectEqual(admitted.end_record, empty.next_record);
    var next_cells: [2]f.Types.Values.Cell = undefined;
    const next = insertRequest(42, 2, "next", &next_cells);
    try t.expectEqual(.applied, (try pointToCompletion(&store, next)).state);
    turn = try store.capture();
    try t.expectEqualDeep(cancelled, try Write.cancel(&turn, ref));
    try t.expectEqualDeep(cancelled, try Write.step(t.allocator, &turn, request));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const budget = try (Pub{ .resource = 7, .domain = .table, .namespace = 9 }).budget(&turn);
    try t.expectEqual(@as(u32, 1), budget.records);
}

fn writeAllocationCase(allocator: std.mem.Allocator) !void {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(51, 1, "one", &cells);
    var turn = try store.capture();
    const before = turn.decision;
    _ = Write.step(allocator, &turn, request) catch |err| {
        try t.expectEqualDeep(before, turn.decision);
        try t.expectEqualDeep(initial, try Head.load(&turn, 9));
        return err;
    };
}
test "point write allocation and turn-budget failures leave no private accepted prefix" {
    try t.checkAllAllocationFailures(t.allocator, writeAllocationCase, .{});
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(51, 1, "one", &cells);
    var turn = try store.capture();
    var foreign = request;
    foreign.resource += 1;
    try t.expectError(error.CrossResourceTransaction, Write.step(t.allocator, &turn, foreign));
    try t.expectEqual(0, writes(turn));
    for (0..3) |i| try turn.put(p.Value.integer(@intCast(i)), p.Value.integer(1));
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Write.step(t.allocator, &turn, request));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqualDeep(initial, try Head.load(&turn, 9));
    try t.expectEqual(null, try Write.status(&turn, try request.reference(t.allocator)));
    var invalid = request;
    invalid.change.insert.identity.operation += 1;
    try t.expectError(error.InvalidTableWrite, invalid.reference(t.allocator));
}

test "compiled key patches preserve unassigned columns and original receipts after later changes after explicit predecessor staging" {
    const columns = schema.columns[0..2].* ++ [_]f.TableSchema.Column{.{ .id = 3, .name = "active", .type = .boolean }};
    var wide = schema;
    wide.columns = &columns;
    wide.next_column = 4;
    var store: Store = .{};
    defer store.deinit();
    _ = try store.tableSchema(wide);
    var cells: [3]f.Types.Values.Cell = .{
        .{ .value = .{ .atom = .{ .signed = 1 } } },
        .{ .value = .{ .atom = .{ .bytes = "first" } } },
        .{ .value = .{ .atom = .{ .boolean = true } } },
    };
    var request: Write.Request = .{ .resource = 7, .principal = 1, .operation = 61, .schema = wide, .change = .{ .insert = .{ .identity = .{ .origin = 2, .operation = 61, .ordinal = 0 }, .cells = &cells } } };
    try archiveCurrent(&store);
    var turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, request)).state);
    try store.commit(turn);
    var compiled = try f.TableDml.compile(t.allocator, "UPDATE items SET value='patched' WHERE id=1", "items", wide, null);
    defer compiled.deinit();
    var output: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const key = (try compiled.plan.primaryKeyEquality(&output)).?;
    const patch: Write.Request = .{ .resource = 7, .principal = 1, .operation = 62, .schema = compiled.plan.schema, .change = .{ .patch = .{ .key = key, .assignments = compiled.plan.action.update } } };
    const original_reference = try patch.reference(t.allocator);
    try archiveCurrent(&store);
    turn = try store.capture();
    const accepted = try Write.step(t.allocator, &turn, patch);
    try t.expectEqual(.applied, accepted.state);
    try t.expectEqual(@as(usize, 2), writes(turn));
    try store.commit(turn);
    var other = patch;
    other.operation = 63;
    other.change.patch.assignments = &.{.{ .column = 3, .value = .{ .cell = .{ .value = .{ .atom = .{ .boolean = false } } } } }};
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, other)).state);
    try store.commit(turn);
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqualDeep(original_reference, try patch.reference(t.allocator));
    try t.expectEqualDeep(accepted, try Write.step(t.allocator, &turn, patch));
    try t.expectEqual(@as(usize, 0), writes(turn));
    var changed_intent = patch;
    changed_intent.change.patch.assignments = &.{.{ .column = 2, .value = .{ .cell = .{ .value = .{ .atom = .{ .bytes = "changed" } } } } }};
    try t.expectError(error.TableWriteIdentityConflict, Write.step(t.allocator, &turn, changed_intent));
    changed_intent = patch;
    changed_intent.change.patch.key = &.{.{ .value = .{ .atom = .{ .signed = 2 } } }};
    try t.expectError(error.TableWriteIdentityConflict, Write.step(t.allocator, &turn, changed_intent));
    try t.expectEqual(@as(usize, 0), writes(turn));
    const head = try Head.load(&turn, 9);
    var reader: Pages.Reader(*Turn) = .{ .pages = .{ .resource = 7, .object = 9 }, .source = &turn };
    var saved = (try (Data{ .schema = wide, .index = head.index }).get(t.allocator, &reader, request.change.insert.identity)).?;
    defer saved.deinit();
    try t.expectEqualStrings("patched", saved.row().cells[1].value.atom.bytes);
    try t.expect(!saved.row().cells[2].value.atom.boolean);

    var remove = patch;
    remove.operation = 64;
    remove.change = .{ .delete_key = key };
    const removed = try Write.step(t.allocator, &turn, remove);
    try t.expectEqual(@as(u64, 1), removed.changed);
    try store.commit(turn);
    request.operation = 65;
    request.change.insert.identity.operation = 65;
    cells[1] = .{ .value = .{ .atom = .{ .bytes = "replacement" } } };
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, request)).state);
    try store.commit(turn);
    try archiveCurrent(&store);
    turn = try store.capture();
    try t.expectEqualDeep(removed, try Write.step(t.allocator, &turn, remove));
    try t.expectEqual(@as(u64, 1), (try Head.load(&turn, 9)).rows);
    try t.expectEqual(@as(usize, 0), writes(turn));
}

test "complete Table blocks preserve manifest, format, length and digest checks" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const payload: [4100]u8 = @splat('x');
    const ref: Pages.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Data.row_format, &payload) };
    var turn = try store.capture();
    try t.expectEqual(.ready, try pages.stage(&turn, ref, &payload));
    try t.expectEqual(@as(usize, 0), writes(turn));
    try t.expectEqual(@as(usize, 1), blockWrites(turn));
    var output: [payload.len]u8 = undefined;
    try t.expectEqualStrings(&payload, try pages.read(&turn, ref, &output));
    var untouched = try store.capture();
    try t.expectError(error.TablePageNotFound, pages.read(&untouched, ref, &output));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualStrings(&payload, try pages.read(&turn, ref, &output));
    const location = Pub.key(.table, 9, 'c', ref.id, 0);
    const original = try t.allocator.dupe(u8, store.blocks.records.get(location).?.bytes);
    defer t.allocator.free(original);
    for ([_]usize{ 0, 4, 8, 12, original.len - 1 }) |offset| {
        try store.blocks.put(t.allocator, location, original, store.revision);
        store.blocks.records.get(location).?.bytes[offset] ^= 1;
        turn = try store.capture();
        try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
    }
    try store.blocks.put(t.allocator, location, original, store.revision);
    turn = try store.capture();
    store.denied = true;
    try t.expectError(error.AccessDenied, pages.read(&turn, ref, &output));
    try t.expectError(error.AccessDenied, turn.validate());
}

test "Table node cache binds the exact cut and rechecks its source before reuse" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const payload: [Index.node_bytes]u8 = @splat('x');
    const ref: Index.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Index.format, &payload), .level = 0, .minimum = try Index.Key.init("a"), .entries = 1 };
    var turn = try store.capture();
    _ = try pages.stage(&turn, .{ .id = ref.id, .spec = ref.spec }, &payload);
    try store.commit(turn);
    turn = try store.capture();
    const Source = struct {
        source: *Turn,
        view: p.Growth.View,
        bodies: usize = 0,
        headers: usize = 0,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            self.headers += 1;
            return self.source.read(key);
        }
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            self.bodies += 1;
            return self.source.readBlock(key, output);
        }
    };
    var source: Source = .{ .source = &turn, .view = turn.view };
    var cache: Pages.Cache = .{};
    var reader: Pages.Reader(*Source) = .{ .pages = pages, .source = &source, .cache = &cache };
    var output: [Index.node_bytes]u8 = undefined;
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    try t.expectEqual(@as(usize, 1), source.bodies);
    const headers = source.headers;
    reader = .{ .pages = pages, .source = &source, .cache = &cache };
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    try t.expectEqual(@as(usize, 1), source.bodies);
    try t.expect(source.headers > headers);
    try t.expectError(error.TablePageBufferTooSmall, reader.load(ref, output[0..1]));
    turn = try store.capture();
    source.view = turn.view;
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    try t.expectEqual(@as(usize, 2), source.bodies);
    const manifest_key = Pages.key(9, 'd', 0);
    const original = store.state.get(manifest_key).?;
    var incompatible = original;
    incompatible.data[4] ^= 1;
    try store.state.put(t.allocator, manifest_key, incompatible);
    try t.expectError(error.IncompatibleTableStorage, reader.load(ref, &output));
    try store.state.put(t.allocator, manifest_key, original);
    store.denied = true;
    try t.expectError(error.AccessDenied, reader.load(ref, &output));
    store.denied = false;
    turn = try store.capture();
    source.view = turn.view;
    store.blocks.records.get(Pages.key(9, 'c', ref.id)).?.bytes[44] ^= 1;
    try t.expectError(error.InvalidTablePage, reader.load(ref, &output));
}

test "row lookahead fetches eight bounded blocks once without granting disclosure rights" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const payload: [600]u8 = @splat('z');
    var refs: [8]Data.Blob = undefined;
    var turn = try store.capture();
    for (&refs, 0..) |*ref, i| {
        ref.* = .{ .id = 20 + i, .spec = try Pub.Digest.of(Data.row_format, &payload) };
        _ = try pages.stage(&turn, .{ .id = ref.id, .spec = ref.spec }, &payload);
    }
    try store.commit(turn);
    turn = try store.capture();
    turn.reader.cache_reads = true;
    const Source = struct {
        source: *Turn,
        store: *Store,
        view: p.Growth.View,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            return Store.read(self.store, self.view, key);
        }
        pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
            return self.source.readBlock(key, output);
        }
        pub fn prefetchBlocks(self: *@This(), keys: []const p.Value) !void {
            return self.source.prefetchBlocks(keys);
        }
    };
    var source: Source = .{ .source = &turn, .store = &store, .view = turn.view };
    var reader: Pages.Reader(*Source) = .{ .pages = pages, .source = &source };
    const reads = store.block_calls;
    try reader.prefetchBlobs(&refs);
    var output: [payload.len]u8 = undefined;
    for (refs) |ref| try t.expectEqualStrings(&payload, try reader.loadBlob(ref, &output));
    try t.expectEqual(reads + 1, store.block_calls);
    store.denied = true;
    try t.expectError(error.AccessDenied, reader.loadBlob(refs[0], &output));
    store.denied = false;
    turn = try store.capture();
    source.view = turn.view;
    store.blocks.records.get(Pages.key(9, 'c', refs[0].id)).?.bytes[44] ^= 1;
    try t.expectError(error.InvalidTablePage, reader.loadBlob(refs[0], &output));
}

test "point publication reserves application completion writes across staging and lost proposals" {
    const progress_key = try p.Value.init("application.progress");
    const receipt_key = try p.Value.init("application.receipt");
    const large: [300000]u8 = @splat('x');
    for ([_][]const u8{ "one", &large }) |value| for ([_]u8{ 1, 2 }) |reserved| {
        var store: Store = .{};
        defer store.deinit();
        _ = try store.table();
        var cells: [2]f.Types.Values.Cell = undefined;
        const request = insertRequest(80, 1, value, &cells);
        var building = false;
        var completed: Write.Status = undefined;
        for (0..2000) |_| {
            var lost = try store.capture();
            const proposal = try Write.stepWithReserve(t.allocator, &lost, request, reserved);
            if (proposal.state != .building) {
                try t.expect(writes(lost) + reserved <= 4);
                try lost.write(progress_key, p.Value.integer(1));
                if (reserved == 2) try lost.write(receipt_key, p.Value.integer(80));
            }
            // Lose the whole private proposal, including application progress.
            // A new owner turn still sees the old rows and original intent.
            var turn = try store.capture();
            try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
            try t.expectEqual(null, try turn.read(progress_key));
            try t.expectEqual(null, try turn.read(receipt_key));
            const result = try Write.stepWithReserve(t.allocator, &turn, request, reserved);
            try t.expectEqual(proposal.state, result.state);
            if (result.state == .building) {
                building = true;
                try t.expect(writes(turn) + blockWrites(turn) > 0 and writes(turn) <= 4);
                try store.commit(turn);
                continue;
            }
            try t.expectEqual(.applied, result.state);
            try t.expect(writes(turn) + reserved <= 4);
            try turn.write(progress_key, p.Value.integer(1));
            if (reserved == 2) try turn.write(receipt_key, p.Value.integer(80));
            try store.commit(turn);
            completed = result;
            break;
        } else return error.UnfinishedReservedWrite;
        try t.expectEqual(value.len > @import("BlockRecord.zig").block_bytes, building);
        var turn = try store.capture();
        try t.expectEqual(@as(u64, 1), (try Head.load(&turn, 9)).rows);
        try t.expectEqual(@as(i64, 1), try (try turn.read(progress_key)).?.asInteger());
        if (reserved == 2) try t.expectEqual(@as(i64, 80), try (try turn.read(receipt_key)).?.asInteger());
        // An old receipt retains completion identity and makes no new proposal.
        try t.expectEqualDeep(completed, try Write.stepWithReserve(t.allocator, &turn, request, reserved));
        try t.expectEqual(@as(usize, 0), writes(turn));
        var duplicate_cells: [2]f.Types.Values.Cell = undefined;
        const duplicate = insertRequest(81, 1, value, &duplicate_cells);
        const rejected = try Write.stepWithReserve(t.allocator, &turn, duplicate, reserved);
        try t.expectEqual(.rejected, rejected.state);
        try t.expectEqual(.row_exists, rejected.rejection);
        try t.expect(writes(turn) + reserved <= 4);
    };
}

test "invalid or exhausted application completion reservation restores the private proposal" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(82, 1, "one", &cells);
    var turn = try store.capture();
    try turn.write(try p.Value.init("application.pending"), p.Value.integer(82));
    const before = turn.decision;
    try t.expectError(error.MutationBudgetExceeded, Write.stepWithReserve(t.allocator, &turn, request, 3));
    try t.expectEqualDeep(before, turn.decision);
    try t.expectEqualDeep(initial, try Head.load(&turn, 9));
    try t.expectEqual(.building, (try Write.stepWithReserve(t.allocator, &turn, request, 2)).state);
    try store.commit(turn);
    turn = try store.capture();
    for (0..4) |i| try turn.write(p.Value.integer(@intCast(i)), p.Value.integer(1));
    for (0..p.Blocks.max_records) |i| try turn.writeBlock(p.Value.integer(@intCast(i)), "occupied");
    const occupied = turn.decision;
    // Staging can make progress with a full turn, but cannot leak a partial
    // publication when even its next immutable page does not fit.
    try t.expectError(error.MutationBudgetExceeded, Write.stepWithReserve(t.allocator, &turn, request, 2));
    try t.expectEqualDeep(occupied, turn.decision);
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
}

test "bounded Table blocks resume large records with exact quota and retry identity" {
    const sizes = [_]usize{ 257, 65280, 65281, 131000, 300000 };
    for (sizes) |length| {
        var store: Store = .{};
        defer store.deinit();
        const pages = try store.create();
        const bytes = try t.allocator.alloc(u8, length);
        defer t.allocator.free(bytes);
        @memset(bytes, 's');
        const ref: Pages.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Data.row_format, bytes) };
        const pubn: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
        var complete = false;
        var steps: usize = 0;
        while (!complete) : (steps += 1) {
            var turn = try store.capture();
            const state = try pages.stage(&turn, ref, bytes);
            try t.expect(writes(turn) <= 4 and blockWrites(turn) <= p.Blocks.max_records);
            try t.expect(turn.decision.blocks.body.len <= p.Blocks.max_batch_bytes);
            var untouched = try store.capture();
            const output = try t.allocator.alloc(u8, length);
            defer t.allocator.free(output);
            if (steps == 0) try t.expectError(error.TablePageNotFound, pages.read(&untouched, .{ .id = 99, .spec = try Pub.Digest.of(Data.row_format, "missing") }, output));
            // A lost proposal cannot advance descriptors or leak its bytes.
            var replay = try store.capture();
            try t.expectEqual(state, try pages.stage(&replay, ref, bytes));
            try t.expectEqualDeep(turn.decision.blocks, replay.decision.blocks);
            try store.commit(replay);
            complete = state == .ready;
            try t.expect(steps < 8);
        }
        var turn = try store.capture();
        const output = try t.allocator.alloc(u8, length);
        defer t.allocator.free(output);
        try t.expectEqualSlices(u8, bytes, try pages.read(&turn, ref, output));
        try t.expectEqual(@as(u32, 0), (try pubn.budget(&turn)).records);
        try t.expectEqual(.ready, try pages.stage(&turn, ref, bytes));
        try t.expectEqual(@as(usize, 0), writes(turn) + blockWrites(turn));
        bytes[0] ^= 1;
        const wrong: Pages.Reference = .{ .id = ref.id, .spec = try Pub.Digest.of(Data.row_format, bytes) };
        try t.expectError(error.TablePageIdentityConflict, pages.stage(&turn, wrong, bytes));
    }
}

test "Table block identity and capacity errors restore the complete private proposal" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const bytes: [512]u8 = @splat('x');
    const ref: Pages.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Data.row_format, &bytes) };
    const location = Pub.key(.table, 9, 'c', ref.id, 0);
    try store.blocks.put(t.allocator, location, "unaccounted", store.revision);
    var turn = try store.capture();
    try turn.put(p.Value.integer(1), p.Value.integer(7));
    const before = turn.decision;
    try t.expectError(error.InvalidPublicationChunk, pages.stage(&turn, ref, &bytes));
    try t.expectEqualDeep(before, turn.decision);
    var capacity = try store.capture();
    for (0..p.Blocks.max_records) |i| try capacity.writeBlock(p.Value.integer(@intCast(i)), "occupied");
    const full = capacity.decision;
    var fresh = ref;
    fresh.id += 1;
    try t.expectError(error.MutationBudgetExceeded, pages.stage(&capacity, fresh, &bytes));
    try t.expectEqualDeep(full, capacity.decision);
}

test "point writes publish rows and indexes with head and receipt in one bounded turn" {
    var store: Store = .{};
    defer store.deinit();
    _ = try store.table();
    for (0..6) |i| {
        var cells: [2]f.Types.Values.Cell = undefined;
        const request = insertRequest(200 + i, i + 1, "value", &cells);
        var turn = try store.capture();
        const outcome = try Write.step(t.allocator, &turn, request);
        try t.expectEqual(.applied, outcome.state);
        try t.expectEqual(@as(usize, 2), writes(turn));
        try t.expect(blockWrites(turn) >= 3); // row, final index and predecessor
        var observer = try store.capture();
        try t.expectEqual(@as(u64, i), (try Head.load(&observer, 9)).rows);
        try t.expectEqual(null, try Write.status(&observer, outcome.reference));
        try store.commit(turn);
        turn = try store.capture();
        try t.expectEqual(@as(u64, i + 1), (try Head.load(&turn, 9)).rows);
        try t.expectEqualDeep(outcome, try Write.step(t.allocator, &turn, request));
        try t.expectEqual(@as(usize, 0), writes(turn) + blockWrites(turn));
    }
}

test "private bulk proposals stay separate from committed cached reads and failures poison the turn" {
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture();
    const key = try p.Value.init("block");
    const bytes: [1024]u8 = @splat(255);
    try turn.writeBlock(key, &bytes);
    var output: [1024]u8 = undefined;
    try t.expectEqualSlices(u8, &bytes, (try turn.readBlock(key, &output)).?);
    var committed = turn.committed();
    try t.expectEqual(null, try committed.readBlock(key, &output));
    try store.commit(turn);
    turn = try store.capture();
    turn.reader.cache_reads = true;
    const before = store.block_calls;
    try turn.prefetchBlocks(&.{key});
    try t.expectEqualSlices(u8, &bytes, (try turn.readBlock(key, &output)).?);
    try t.expectEqual(before + 1, store.block_calls);
    try turn.writeBlock(key, null);
    try t.expectEqual(null, try turn.readBlock(key, &output));
    committed = turn.committed();
    try t.expectEqualSlices(u8, &bytes, (try committed.readBlock(key, &output)).?);
    turn = try store.capture();
    turn.reader.blocks = null;
    try t.expectError(error.UnsupportedBlockStorage, turn.readBlock(key, &output));
    try t.expectError(error.UnsupportedBlockStorage, turn.writeBlock(key, "new"));
    try t.expectError(error.UnsupportedBlockStorage, turn.validate());
}
