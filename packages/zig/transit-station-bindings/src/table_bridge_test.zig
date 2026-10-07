const std = @import("std");
const t = std.testing;
const s = @import("transit_station");
const p = s.protocol;
const f = s.fuze;
const b = @import("TableBridge.zig");
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
const Store = struct {
    values: Map = .empty,
    position: u64 = 1,
    failure: ?anyerror = null,
    fn deinit(self: *Store) void {
        self.values.deinit(t.allocator);
    }
    fn capture(self: *Store) !s.Turn {
        self.position += 1;
        return s.Turn.init(.{ .realm = 1, .principal = 65536, .pid = 2, .generation = 1, .sequence = self.position, .revision = self.position, .input = .{ .position = self.position, .ordinal = self.position, .value = try (s.Frame{ .kind = .cast }).encode(), .origin = .{ .process = .{ .pid = 2, .turn = self.position - 1, .output = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.position + 100, .pid = 2, .principal = 65536, .generation = 1, .input = self.position, .process_revision = self.position, .resource = 7, .revision = self.position, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page });
    }
    fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.failure) |err| return err;
        return self.values.get(key);
    }
    fn page(raw: *anyopaque, view: p.Growth.View, after: ?p.Value) !s.Turn.Page {
        const self: *Store = @ptrCast(@alignCast(raw));
        if (self.failure) |err| return err;
        var result: s.Turn.Page = .{};
        var cursor = after;
        for (0..result.entries.len + 1) |index| {
            var next: ?p.Value = null;
            var iterator = self.values.keyIterator();
            while (iterator.next()) |candidate| {
                if (cursor) |previous| if (std.mem.order(u8, candidate.slice(), previous.slice()) != .gt) continue;
                if (next == null or std.mem.order(u8, candidate.slice(), next.?.slice()) == .lt) next = candidate.*;
            }
            const found = next orelse return result;
            if (index == result.entries.len) {
                result.next = cursor;
                return result;
            }
            result.entries[index] = .{ .key = found, .value = self.values.get(found).?, .revision = view.revision };
            cursor = found;
        }
        unreachable;
    }
    fn commit(self: *Store, turn: *s.Turn) !void {
        try turn.validate();
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.value) |value| try self.values.put(t.allocator, mutation.key, value) else _ = self.values.remove(mutation.key);
        };
    }
    fn apply(self: *Store, arena: *std.heap.ArenaAllocator, action: b.Action) !b.Result {
        var turn = try self.capture();
        const result = try b.apply(arena, &turn, action);
        try self.commit(&turn);
        return result;
    }
    fn mutate(self: *Store, arena: *std.heap.ArenaAllocator, mutation: b.Mutation) !b.Status {
        for (0..512) |_| {
            const result = (try self.apply(arena, .{ .mutate = mutation })).mutation.?;
            if (result.state != .building) return result;
        }
        return error.StepBudgetExceeded;
    }
};
const schema: f.TableSchema.Schema = .{ .object = std.math.maxInt(u64), .revision = 1, .next_column = 5, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "name", .type = .utf8 },
    .{ .id = 3, .name = "amount", .type = .{ .decimal = .{ .precision = 18, .scale = 2 } } },
    .{ .id = 4, .name = "tags", .type = .{ .list = .{ .type = &.utf8, .nullable = true } } },
}, .primary_key = &.{1} };
fn create(store: *Store, arena: *std.heap.ArenaAllocator) !f.TableSchemaJson.Schema {
    const neutral = try f.TableSchemaJson.foreign(arena, schema);
    const action: b.Action = .{ .create = .{ .realm = 1, .resource = 7, .schema = neutral, .limits = .{ .record_bytes = 65536, .staging_bytes = "8388608", .staging_records = 1024 } } };
    for (0..64) |_| {
        if ((try store.apply(arena, action)).created.state == .applied) return neutral;
    }
    return error.StepBudgetExceeded;
}
const source: b.Source = .{ .object = "18446744073709551615" };

test "general handler bridge owns typed schemas rows plans and terminal receipts" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store: Store = .{};
    defer store.deinit();
    const neutral = try create(&store, &arena);
    const insert: b.Mutation = .{ .realm = 1, .resource = 7, .principal = 65536, .operation = "1", .schema = neutral, .mutation = .{ .predicate = null, .action = .{ .insert = &.{&.{
        .{ .column = "1", .value = .{ .cell = .{ .value = .{ .atom = .{ .signed = "7" } } } } },
        .{ .column = "2", .value = .{ .cell = .null } },
        .{ .column = "3", .value = .{ .cell = .{ .value = .{ .atom = .{ .decimal = "12345" } } } } },
        .{ .column = "4", .value = .{ .cell = .{ .value = .{ .list = &.{ .{ .value = .{ .atom = .{ .utf8 = "child" } } }, .null } } } } },
    }} } } };
    const written = try store.mutate(&arena, insert);
    try t.expectEqual(.applied, written.state);
    try t.expectEqualStrings("1", written.counts.?.changed);
    try t.expectEqualStrings(source.object, written.reference.object);
    const duplicate = try store.mutate(&arena, insert);
    try t.expectEqual(written.completed_input, duplicate.completed_input);
    try t.expectEqualStrings(written.reference.digest, duplicate.reference.digest);
    var inspect = try store.capture();
    const metadata = (try b.apply(&arena, &inspect, .{ .schema = source })).schema;
    try t.expectEqual(@as(usize, 4), metadata.schema.columns.len);
    try t.expectEqualStrings(source.object, metadata.basis.object);
    const first = (try b.apply(&arena, &inspect, .{ .page = .{ .source = source, .limit = 1 } })).page;
    try t.expectEqual(@as(usize, 1), first.rows.len);
    const row = first.rows[0];
    try t.expectEqualStrings("12345", row.cells[2].value.atom.decimal);
    try t.expectEqualStrings("child", row.cells[3].value.list[0].value.atom.utf8);
    try t.expectEqual(.null, std.meta.activeTag(row.cells[3].value.list[1]));
    const keyed = (try b.apply(&arena, &inspect, .{ .get_key = .{ .source = source, .key = &.{.{ .value = .{ .atom = .{ .signed = "7" } } }} } })).row;
    try t.expectEqualStrings(row.identity, keyed.row.?.identity);
    const by_id = (try b.apply(&arena, &inspect, .{ .get = .{ .source = source, .identity = row.identity } })).row;
    try t.expectEqualStrings("7", by_id.row.?.cells[0].value.atom.signed);
    const last = (try b.apply(&arena, &inspect, .{ .page = .{ .source = source, .cursor = first.next } })).page;
    try t.expect(last.rows.len == 0 and last.next == null);
    var moved = try store.capture();
    try t.expectError(error.StaleTableCursor, b.apply(&arena, &moved, .{ .page = .{ .source = source, .cursor = first.next } }));
    const status = (try b.apply(&arena, &inspect, .{ .status = written.reference })).mutation.?;
    try t.expectEqual(written.completed_input, status.completed_input);
    var update = insert;
    update.operation = "2";
    update.mutation = .{ .predicate = null, .action = .{ .update = &.{.{ .column = "3", .value = .{ .cell = .{ .value = .{ .atom = .{ .decimal = "54321" } } } } }} } };
    const changed = try store.mutate(&arena, update);
    try t.expectEqualStrings("1", changed.counts.?.changed);
    var deletion = insert;
    deletion.operation = "3";
    deletion.mutation = .{ .predicate = null, .action = .delete };
    try t.expectEqualStrings("1", (try store.mutate(&arena, deletion)).counts.?.changed);
    const empty = (try store.apply(&arena, .{ .page = .{ .source = source } })).page;
    try t.expect(empty.rows.len == 0 and empty.next == null);
}

test "general handler bridge preserves exact intent cancellation and read poison" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store: Store = .{};
    defer store.deinit();
    const neutral = try create(&store, &arena);
    const mutation: b.Mutation = .{ .realm = 1, .resource = 7, .principal = 65536, .operation = "7", .schema = neutral, .mutation = .{ .predicate = null, .action = .{ .insert = &.{&.{.{ .column = "1", .value = .{ .cell = .{ .value = .{ .atom = .{ .signed = "1" } } } } }}} } } };
    const admitted = (try store.apply(&arena, .{ .mutate = mutation })).mutation.?;
    try t.expectEqual(.building, admitted.state);
    var turn = try store.capture();
    const before = turn.decision;
    var changed = mutation;
    changed.mutation = .{ .predicate = null, .action = .delete };
    try t.expectError(error.TableWriteIdentityConflict, b.apply(&arena, &turn, .{ .mutate = changed }));
    try t.expect(std.meta.eql(before, turn.decision));
    changed = mutation;
    changed.resource = 8;
    try t.expectError(error.WrongResource, b.apply(&arena, &turn, .{ .mutate = changed }));
    try t.expect(std.meta.eql(before, turn.decision));
    changed = mutation;
    changed.realm = 2;
    try t.expectError(error.WrongResource, b.apply(&arena, &turn, .{ .mutate = changed }));
    var wrong = admitted.reference;
    wrong.resource += 1;
    try t.expectError(error.WrongResource, b.apply(&arena, &turn, .{ .status = wrong }));
    const closed = (try store.apply(&arena, .{ .cancel = admitted.reference })).mutation.?;
    try t.expectEqual(.cancelled, closed.state);
    try t.expect(closed.counts == null);
    try t.expectEqual(closed.completed_input, (try store.mutate(&arena, mutation)).completed_input);
    store.failure = error.AccessDenied;
    var denied = try store.capture();
    try t.expectError(error.AccessDenied, b.apply(&arena, &denied, .{ .schema = source }));
    store.failure = null;
    try t.expectError(error.AccessDenied, b.apply(&arena, &denied, .{ .status = admitted.reference }));
    try t.expectError(error.AccessDenied, denied.validate());
    const empty = (try store.apply(&arena, .{ .page = .{ .source = source } })).page;
    try t.expect(empty.rows.len == 0);
}

test "foreign Arrow cells retain rich descriptors and owned recursive values" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const list: f.Types.Type = .{ .list = .{ .type = &.{ .decimal = .{ .precision = 18, .scale = 2 } }, .nullable = true } };
    const descriptor: f.Types.Type = .{ .structure = &.{.{ .name = "amounts", .type = list }} };
    const cells = [_]f.Types.Values.Cell{.{ .value = .{ .list = &.{ .{ .value = .{ .atom = .{ .decimal = 12345 } } }, .null } } }};
    const workspace = try t.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer t.allocator.free(workspace);
    var buffer: [s.Query.records.segment_bytes]u8 = undefined;
    const bytes = try f.LogicalArrow.encode(descriptor, &.{.{ .cells = &cells }}, workspace, &buffer);
    const a = @import("Actions.zig");
    try t.expectError(error.InvalidRow, a.arrowCellBounded(arena.allocator(), bytes, 1, 0, buffer.len));
    try t.expectError(error.InvalidColumn, a.arrowCellBounded(arena.allocator(), bytes, 0, 1, buffer.len));
    const decoded = try a.arrowCellBounded(arena.allocator(), bytes, 0, 0, buffer.len);
    @memset(&buffer, 0xaa);
    @memset(workspace, 0xaa);
    try t.expectEqualStrings("amounts", decoded.name);
    try t.expect(try decoded.type.eql(list));
    try t.expectEqualStrings("12345", decoded.value.value.list[0].value.atom.decimal);
    try t.expectEqual(.null, std.meta.activeTag(decoded.value.value.list[1]));
}
