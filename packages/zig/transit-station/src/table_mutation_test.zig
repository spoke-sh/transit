const std = @import("std");
const t = std.testing;
const s = @import("root.zig");
const p = s.protocol;
const Store = @import("TestStore.zig");
const mutations = s.TableMutation;
fn table() !s.Table {
    return .{ .resource = 7, .id = 1, .schema = .{ .names = .{ try s.fuze.model.Name.init("id"), try s.fuze.model.Name.init("value") }, .value_type = .int64 } };
}
fn fixture(value: s.Table) !Store {
    var store: Store = .{};
    store.entries[0] = .{ .key = s.Table.descriptorKey(value.id), .value = try s.Table.encodeSchema(value.schema), .revision = 0 };
    return store;
}
fn apply(turn: *s.Turn, value: s.Table, text: []const u8) !u8 {
    return (try mutations.applySql(turn, value, try s.fuze.model.Name.init("items"), text)).affected_rows;
}

test "bounded mutations count matched rows and restore the whole proposal on rejection" {
    const value = try table();
    var store = try fixture(value);
    var turn = try store.turn(.{});
    try t.expectEqual(@as(u8, 3), try apply(&turn, value, "INSERT INTO items (id,value) VALUES(1,2),(2,NULL),(3,4)"));
    try t.expectEqual(@as(i64, 2), (try value.get(&turn, 1)).?.value.int64);
    try t.expect((try value.get(&turn, 2)).?.value == .null);
    try t.expectEqual(@as(u8, 1), try apply(&turn, value, "UPDATE items SET value=2 WHERE id=1"));
    try t.expectEqual(@as(u8, 1), try apply(&turn, value, "UPDATE items SET value=NULL WHERE id=3"));
    try t.expect((try value.get(&turn, 3)).?.value == .null);
    try turn.cast(8, try p.Value.init("earlier output"));
    const before = turn.decision;
    try t.expectEqual(@as(u8, 0), try apply(&turn, value, "UPDATE items SET value=2 WHERE id=99"));
    try t.expectEqual(@as(u8, 0), try apply(&turn, value, "DELETE FROM items WHERE id=99"));
    try t.expect(std.meta.eql(before, turn.decision));
    try t.expectError(error.RowExists, apply(&turn, value, "INSERT INTO items (id,value) VALUES(4,5),(1,6)"));
    try t.expect(std.meta.eql(before, turn.decision));
    try t.expectError(error.MutationBudgetExceeded, apply(&turn, value, "INSERT INTO items (id,value) VALUES(4,5),(5,6)"));
    try t.expect(std.meta.eql(before, turn.decision));
    try t.expect(try value.get(&turn, 4) == null);
    try t.expectEqual(@as(u8, 1), try apply(&turn, value, "DELETE FROM items WHERE id=1"));
    try t.expectEqual(@as(u8, 0), try apply(&turn, value, "DELETE FROM items WHERE id=1"));
    try t.expect(try value.get(&turn, 1) == null);
}

test "mutation failure preserves read poison, source identity and schema checks" {
    const value = try table();
    const Failing = struct {
        store: Store,
        fn read(raw: *anyopaque, view: p.Growth.View, key: p.Value) !?p.Value {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (key.eql(s.Table.rowKey(1, 2))) return error.Unavailable;
            return Store.read(&self.store, view, key);
        }
    };
    var failing: Failing = .{ .store = try fixture(value) };
    var turn = try failing.store.turn(.{});
    turn.reader = .{ .context = &failing, .read = Failing.read };
    const before = turn.decision;
    try t.expectError(error.Unavailable, apply(&turn, value, "INSERT INTO items (id,value) VALUES(1,2),(2,3)"));
    try t.expect(std.meta.eql(before, turn.decision));
    try t.expectEqual(error.Unavailable, turn.read_error.?);
    try t.expectError(error.Unavailable, turn.validate());
    var clean = try failing.store.turn(.{});
    var foreign = value;
    foreign.resource += 1;
    try t.expectError(error.CrossResourceTransaction, apply(&clean, foreign, "DELETE FROM items WHERE id=1"));
    foreign = value;
    foreign.schema.value_type = .utf8;
    try t.expectError(error.TableSchemaChanged, apply(&clean, foreign, "DELETE FROM items WHERE id=1"));
    const plan = try s.fuze.TableMutation.compile("DELETE FROM items WHERE id=1", .{ .name = try s.fuze.model.Name.init("items"), .schema = foreign.schema });
    try t.expectError(error.TableSchemaChanged, mutations.apply(&clean, value, plan));
}
