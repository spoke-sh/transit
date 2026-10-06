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
    const Fixture = struct { native_definition: []const u8, manifest_hex: []const u8, inline_hex: []const u8, head_hex: []const u8, head_key_hex: []const u8, page_key_hex: []const u8, write_key_hex: []const u8, write_status_hex: []const u8, statement_progress_hex: []const u8, statement_progress_key_hex: []const u8 };
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
    const progress: Statement.Progress = .{ .digest = receipt.reference.digest, .head_revision = 8, .index = head.index, .cursor = .{ .origin = 2, .operation = 30, .ordinal = 1 }, .matched = 2, .changed = 1 };
    const progress_bytes = try progress.encode();
    try expectHex(expected.statement_progress_hex, progress_bytes.slice());
    try expectHex(expected.statement_progress_key_hex, Statement.Progress.key(receipt.reference).slice());
    try t.expectEqualDeep(progress, try Statement.Progress.decode(progress_bytes));
    try t.expectEqualDeep(receipt, try Write.Status.decode(receipt_bytes));
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
