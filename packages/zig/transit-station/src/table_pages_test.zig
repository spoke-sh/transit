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
const Write = @import("TableWrite.zig");
const Statement = @import("TableStatement.zig");
const Cleanup = @import("TableCleanup.zig");
const Alter = @import("TableAlter.zig");
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
        try t.expect(writes(turn) > 0);
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
    for (0..3) |_| {
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
        try t.expect(writes(turn) > 0);
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
    var turn = try store.capture();
    _ = try Write.step(t.allocator, &turn, insertRequest(450, 1, "one", &cells));
    try store.commit(turn);
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
    var turn = try store.capture();
    const accepted = try Write.step(t.allocator, &turn, first);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.TableCleanupNotClosed, Cleanup.step(&turn, accepted.reference));
    var large: [6000]u8 = @splat('x');
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
    const rejected = try sqlStatement(&store, 311, schema, "INSERT INTO items VALUES(4,'four'),(5,'five'),(6,'six'),(2,'duplicate')");
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
        try t.expect(writes(turn) > 0);
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
    for (0..3) |_| {
        turn = try store.capture();
        try t.expectEqual(.building, (try Statement.step(t.allocator, &turn, request)).state);
        try store.commit(turn);
    }
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
    try t.expect(cancelled.next_record > admitted.end_record);
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
    const publication: Pub = .{ .resource = 7, .domain = .table, .namespace = 9 };
    try t.expectEqual(@as(u32, 0), (try publication.budget(&turn)).records);
    const deleted = try sqlStatement(&store, 231, schema, "DELETE FROM items WHERE id>=20");
    try t.expectEqual(@as(u64, 20), deleted.changed);
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
    state: std.AutoHashMapUnmanaged(p.Value, p.Value) = .empty,
    revision: u64 = 1,
    input: u64 = 1,
    denied: bool = false,
    fn deinit(self: *Store) void {
        self.state.deinit(t.allocator);
    }
    fn capture(self: *Store) !Turn {
        self.input += 1;
        return Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 3, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 2, .principal = 65536, .generation = 3, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page });
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
                next = .{ .key = key, .value = entry.value_ptr.*, .revision = self.revision };
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
            if (mutation.value) |value| try self.state.put(t.allocator, mutation.key, value) else _ = self.state.remove(mutation.key);
        };
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
        if (bytes.len > Pages.inline_bytes) {
            // Publication cursors read a committed cut, never the private
            // descriptor just published in this turn. Preserve that gate.
            try t.expectError(error.PublicationReadAfterMutation, head.create(t.allocator, &turn));
            try self.commit(turn);
            turn = try self.capture();
        }
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
            try t.expect(writes(turn) <= 2);
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
        try t.expect(record.bytes.len <= Pages.inline_bytes);
        try t.expectEqual(.ready, try pages.stage(&turn, .{ .id = record.id, .spec = record.spec }, record.bytes));
    };
    const head = try p.Value.init("test-head");
    const receipt = try p.Value.init("test-outcome");
    try turn.put(head, p.Value.integer(@intCast(changed.data.index.root.?.id)));
    try turn.put(receipt, p.Value.integer(1));
    try t.expectEqual(@as(usize, 4), writes(turn));
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
    var broken = store.state.get(Pages.key(9, 'i', 1)).?;
    broken.data[broken.len - 1] ^= 1;
    try store.state.put(t.allocator, Pages.key(9, 'i', 1), broken);
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
    const saved = store.state.get(Pages.key(9, 'i', 1)).?;
    for (0..saved.len) |length| {
        try store.state.put(t.allocator, Pages.key(9, 'i', 1), try p.Value.init(saved.data[0..length]));
        turn = try store.capture();
        try t.expectError(error.InvalidTablePage, pages.read(&turn, ref, &output));
    }
    try store.state.put(t.allocator, Pages.key(9, 'i', 1), saved);
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
    try t.expectEqual(@as(usize, 4), writes(turn));
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
    try t.expectEqual(@as(u16, 245), head_bytes.len);
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
    const Fixture = struct { native_definition: []const u8, manifest_hex: []const u8, inline_hex: []const u8, head_hex: []const u8, head_key_hex: []const u8, page_key_hex: []const u8, write_key_hex: []const u8, write_status_hex: []const u8, write_rejection_hex: []const u8, statement_progress_hex: []const u8, statement_progress_key_hex: []const u8, cleanup_hex: []const u8, cleanup_key_hex: []const u8 };
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
    try expectHex(expected.page_key_hex, Pages.key(9, 'i', 7).slice());
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
    try expectHex(expected.inline_hex, (try turn.read(Pages.key(9, 'i', 7))).?.slice());
}

fn insertRequest(operation: u64, key_value: i128, value: []const u8, cells: *[2]f.Types.Values.Cell) Write.Request {
    cells.* = .{ .{ .value = .{ .atom = .{ .signed = key_value } } }, .{ .value = .{ .atom = .{ .bytes = value } } } };
    return .{ .resource = 7, .principal = 1, .operation = operation, .schema = schema, .change = .{ .insert = .{ .identity = .{ .origin = 2, .operation = operation, .ordinal = 0 }, .cells = cells } } };
}
test "point write publication retains exact counts, rejection and receipts after retirement" {
    var store: Store = .{};
    defer store.deinit();
    const initial = try store.table();
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(21, 1, "one", &cells);
    const ref = try request.reference(t.allocator);
    var turn = try store.capture();
    const applied = try Write.step(t.allocator, &turn, request);
    try t.expectEqual(.applied, applied.state);
    try t.expectEqual(@as(u64, 1), applied.matched);
    try t.expectEqual(@as(u64, 1), applied.changed);
    try t.expectEqual(@as(usize, 4), writes(turn));
    var before_commit = try store.capture();
    try t.expectEqualDeep(initial, try Head.load(&before_commit, 9));
    try t.expectEqual(null, try Write.status(&before_commit, ref));
    try store.commit(turn);
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

    turn = try store.capture();
    var duplicate_cells: [2]f.Types.Values.Cell = undefined;
    const duplicate = insertRequest(23, 1, "two", &duplicate_cells);
    const rejected = try Write.step(t.allocator, &turn, duplicate);
    try t.expectEqual(.rejected, rejected.state);
    try t.expectEqual(.row_exists, rejected.rejection);
    try t.expectEqual(@as(usize, 1), writes(turn));
    try store.commit(turn);

    turn = try store.capture();
    var remove = request;
    remove.operation = 24;
    remove.change = .{ .delete = request.change.insert.identity };
    const removed = try Write.step(t.allocator, &turn, remove);
    try t.expectEqual(@as(u64, 1), removed.changed);
    try t.expectEqual(@as(u64, 0), (try Head.load(&turn, 9)).rows);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(rejected, try Write.step(t.allocator, &turn, duplicate));
    remove.operation = 25;
    const absent = try Write.step(t.allocator, &turn, remove);
    try t.expectEqual(@as(u64, 0), absent.matched);
    try t.expectEqual(@as(u64, 0), absent.changed);
    try store.commit(turn);

    turn = try store.capture();
    const current = try Head.load(&turn, 9);
    var retired = current;
    retired.revision += 1;
    retired.retired = true;
    try current.replace(&turn, retired);
    try store.commit(turn);
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
    var large: [7000]u8 = @splat('x');
    var cells: [2]f.Types.Values.Cell = undefined;
    const request = insertRequest(31, 1, &large, &cells);
    var turn = try store.capture();
    var result = try Write.step(t.allocator, &turn, request);
    try t.expectEqual(.building, result.state);
    try t.expectEqual(@as(usize, 2), writes(turn));
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
    try t.expect(stages > 20);
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
    var large: [4096]u8 = @splat('x');
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
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, next)).state);
    try store.commit(turn);
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

test "compiled key patches preserve unassigned columns and original receipts after later changes" {
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
    var turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, request)).state);
    try store.commit(turn);
    var compiled = try f.TableDml.compile(t.allocator, "UPDATE items SET value='patched' WHERE id=1", "items", wide, null);
    defer compiled.deinit();
    var output: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const key = (try compiled.plan.primaryKeyEquality(&output)).?;
    const patch: Write.Request = .{ .resource = 7, .principal = 1, .operation = 62, .schema = compiled.plan.schema, .change = .{ .patch = .{ .key = key, .assignments = compiled.plan.action.update } } };
    const original_reference = try patch.reference(t.allocator);
    turn = try store.capture();
    const accepted = try Write.step(t.allocator, &turn, patch);
    try t.expectEqual(.applied, accepted.state);
    try t.expectEqual(@as(usize, 4), writes(turn));
    try store.commit(turn);
    var other = patch;
    other.operation = 63;
    other.change.patch.assignments = &.{.{ .column = 3, .value = .{ .cell = .{ .value = .{ .atom = .{ .boolean = false } } } } }};
    turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, other)).state);
    try store.commit(turn);
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
    turn = try store.capture();
    try t.expectEqual(.applied, (try Write.step(t.allocator, &turn, request)).state);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqualDeep(removed, try Write.step(t.allocator, &turn, remove));
    try t.expectEqual(@as(u64, 1), (try Head.load(&turn, 9)).rows);
    try t.expectEqual(@as(usize, 0), writes(turn));
}

test "Table page prefetch batches chunks without bypassing publication or digest checks" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const payload: [4100]u8 = @splat('x');
    const ref: Pages.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Data.row_format, &payload) };
    for (0..64) |_| {
        var turn = try store.capture();
        const step = try pages.stage(&turn, ref, &payload);
        try store.commit(turn);
        if (step == .ready) break;
    } else return error.UnfinishedTestPage;
    var turn = try store.capture();
    const Reader = struct {
        source: *Turn,
        view: p.Growth.View,
        keys: [64]?p.Value = @splat(null),
        values: [64]?p.Value = @splat(null),
        count: usize = 0,
        batches: usize = 0,
        pub fn prefetch(self: *@This(), keys: []const p.Value) !void {
            try t.expect(keys.len > 0 and keys.len <= p.Growth.page_size);
            self.batches += 1;
            for (keys) |key| {
                self.keys[self.count] = key;
                self.values[self.count] = try self.source.read(key);
                self.count += 1;
            }
        }
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            for (self.keys[0..self.count], self.values[0..self.count]) |address, value| if (address.?.eql(key)) return value;
            return error.UnbatchedTableRead;
        }
    };
    var reader: Reader = .{ .source = &turn, .view = turn.view };
    var output: [payload.len]u8 = undefined;
    try t.expectEqualStrings(&payload, try pages.read(&reader, ref, &output));
    try t.expectEqual(@as(usize, 4), reader.batches); // One header pair, then 8+8+1 chunks.
    try t.expectEqual(@as(usize, 19), reader.count);
    const location = Pub.key(.table, 9, 'c', ref.id, 0);
    var damaged = store.state.get(location).?;
    damaged.data[0] ^= 1;
    try store.state.put(t.allocator, location, damaged);
    reader = .{ .source = &turn, .view = turn.view };
    try t.expectError(error.InvalidPublicationDigest, pages.read(&reader, ref, &output));
    var descriptor = try Pub.Descriptor.decode(store.state.get(Pages.key(9, 'r', ref.id)).?);
    descriptor.state = .retired;
    try store.state.put(t.allocator, Pages.key(9, 'r', ref.id), try descriptor.encode());
    reader = .{ .source = &turn, .view = turn.view };
    try t.expectError(error.PublicationNotPublished, pages.read(&reader, ref, &output));
    try t.expectEqual(@as(usize, 1), reader.batches); // No chunk acquisition after retirement.
    store.denied = true;
    reader = .{ .source = &turn, .view = turn.view };
    try t.expectError(error.AccessDenied, pages.read(&reader, ref, &output));
}

test "Table index cache reuses bodies but rechecks basis, manifest, lifecycle and access" {
    var store: Store = .{};
    defer store.deinit();
    const pages = try store.create();
    const payload: [Index.node_bytes]u8 = @splat('x');
    const ref: Index.Reference = .{ .id = 20, .spec = try Pub.Digest.of(Index.format, &payload), .level = 0, .minimum = try Index.Key.init("a"), .entries = 1 };
    for (0..64) |_| {
        var turn = try store.capture();
        const step = try pages.stage(&turn, .{ .id = ref.id, .spec = ref.spec }, &payload);
        try store.commit(turn);
        if (step == .ready) break;
    } else return error.UnfinishedTestPage;
    var turn = try store.capture();
    const Source = struct {
        source: *Turn,
        view: p.Growth.View,
        chunks: usize = 0,
        headers: usize = 0,
        pub fn read(self: *@This(), key: p.Value) !?p.Value {
            if (key.len == 27 and key.data[14] == 'c') self.chunks += 1 else self.headers += 1;
            return self.source.read(key);
        }
    };
    var source: Source = .{ .source = &turn, .view = turn.view };
    var cache: Index.Cache = .{};
    var reader: Pages.Reader(*Source) = .{ .pages = pages, .source = &source, .cache = &cache };
    var output: [Index.node_bytes]u8 = undefined;
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    const chunks = source.chunks;
    try t.expect(chunks > 1);
    const headers = source.headers;
    // A different adapter in the same captured query can share verified nodes.
    reader = .{ .pages = pages, .source = &source, .cache = &cache };
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    try t.expectEqual(chunks, source.chunks);
    try t.expect(source.headers > headers);
    try t.expectError(error.IndexNodeTooLarge, reader.load(ref, output[0..1]));
    source.view.id += 1;
    try t.expectEqualStrings(&payload, try reader.load(ref, &output));
    try t.expectEqual(chunks * 2, source.chunks);

    const manifest_key = Pages.key(9, 'd', 0);
    const original = store.state.get(manifest_key).?;
    var incompatible = original;
    incompatible.data[4] ^= 1;
    try store.state.put(t.allocator, manifest_key, incompatible);
    try t.expectError(error.IncompatibleTableStorage, reader.load(ref, &output));
    try store.state.put(t.allocator, manifest_key, original);
    const record_key = Pages.key(9, 'r', ref.id);
    const record = store.state.get(record_key).?;
    var descriptor = try Pub.Descriptor.decode(record);
    descriptor.state = .retired;
    try store.state.put(t.allocator, record_key, try descriptor.encode());
    try t.expectError(error.PublicationNotPublished, reader.load(ref, &output));
    try store.state.put(t.allocator, record_key, record);
    store.denied = true;
    try t.expectError(error.AccessDenied, reader.load(ref, &output));
    store.denied = false;
    // A failed Station read stays failed. New access requires a fresh turn.
    turn = try store.capture();

    const location = Pub.key(.table, 9, 'c', ref.id, 0);
    var damaged = store.state.get(location).?;
    damaged.data[0] ^= 1;
    try store.state.put(t.allocator, location, damaged);
    source.view.id += 1;
    try t.expectError(error.InvalidPublicationDigest, reader.load(ref, &output));
}
