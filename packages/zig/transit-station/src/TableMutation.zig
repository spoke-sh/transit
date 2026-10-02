//! Explicit application-owned SQL writes within one private Station turn.
const std = @import("std");
const Table = @import("Table.zig");
const f = @import("transit_fuze");
pub const Plan = f.TableMutation.Plan;
pub const Result = struct { affected_rows: u8 };

/// The caller owns authorization and admission; this helper neither commits nor
/// routes work. Any failure restores the complete proposal. Read poison remains.
pub fn apply(turn: anytype, table: Table, plan: Plan) !Result {
    return applyDetailed(turn, table, plan, null);
}

pub fn applyDetailed(turn: anytype, table: Table, plan: Plan, conflict: ?*?f.TableMutation.Conflict) !Result {
    if (conflict) |detail| detail.* = null;
    try plan.validate();
    if (!std.meta.eql(table.schema, plan.schema)) return error.TableSchemaChanged;
    const before = turn.decision;
    errdefer turn.decision = before;
    var affected: u8 = 0;
    switch (plan.operation) {
        .insert => |rows| for (rows, 1..) |slot, ordinal| {
            const row = slot orelse break;
            table.insert(turn, row) catch |err| {
                if (err == error.RowExists) if (conflict) |detail| {
                    detail.* = .{ .key = row.key, .row = @intCast(ordinal) };
                };
                return err;
            };
            affected += 1;
        },
        .update => |row| if (try table.get(turn, row.key) != null) {
            // Existence was checked in this same private view. Upsert retains
            // schema/write checks without reading the row a second time.
            try table.upsert(turn, row);
            affected = 1;
        },
        .delete => |key| if (try table.get(turn, key) != null) {
            try table.delete(turn, key);
            affected = 1;
        },
    }
    try turn.validate();
    return .{ .affected_rows = affected };
}

pub fn applySql(turn: anytype, table: Table, name: f.model.Name, text: []const u8) !Result {
    return apply(turn, table, try f.TableMutation.compile(text, .{ .name = name, .schema = table.schema }));
}
