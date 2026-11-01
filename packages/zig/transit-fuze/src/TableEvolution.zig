//! Pure, single-revision schema transitions and row rewrites. A successful
//! schema transition is not proof that existing rows satisfy tighter rules.
const std = @import("std");
const s = @import("TableSchema.zig");
const t = @import("Types.zig");
const Cell = t.Values.Cell;
pub const Change = union(enum) {
    add: struct { name: []const u8, type: t.Type, nullable: bool = true, default: ?Cell = null, max_characters: ?u32 = null, encoding: s.Encoding = .plain, collation: s.Collation = .none },
    drop: s.ColumnId,
    rename: struct { column: s.ColumnId, name: []const u8 },
    default: struct { column: s.ColumnId, value: ?Cell },
    nullable: struct { column: s.ColumnId, value: bool },
    type: struct { column: s.ColumnId, type: t.Type, max_characters: ?u32 = null },
    physical: struct { column: s.ColumnId, encoding: s.Encoding = .plain, collation: s.Collation = .none },
    /// Complete captured source schema with only integrity replaced. The owner
    /// checks the rest verbatim before advancing the schema revision.
    integrity: s.Schema,
};
pub const Work = enum { metadata, validate_rows, rewrite_rows };
pub const Transition = struct {
    before: s.Schema,
    after: s.Schema,
    work: Work,
    rebuild_key: bool,
    /// Narrow lazy-edit matrix. This only classifies interpretation; the owner
    /// must persist original ADD values and all referenced physical schemas.
    /// Other edits retain their complete validation/rewrite requirement.
    pub fn canProject(self: Transition) !bool {
        if (self.before.object != self.after.object or self.after.revision != try std.math.add(u64, self.before.revision, 1)) return error.InvalidSchemaTransition;
        if (self.rebuild_key) return false;
        if (self.work == .validate_rows) return false;
        const Projection = @import("TableSchemaProjection.zig");
        var initials: [s.max_columns]Projection.Initial = undefined;
        var count: usize = 0;
        for (self.after.columns) |column| {
            _ = self.before.index(column.id) catch |err| {
                if (err != error.UnknownColumn) return err;
                initials[count] = .{ .column = column.id, .value = column.initial() };
                count += 1;
                continue;
            };
        }
        _ = Projection.init(self.before, self.after, initials[0..count]) catch |err| switch (err) {
            error.IncompatibleSchemaProjection, error.MissingRequiredField => return false,
            else => return err,
        };
        return true;
    }
    /// Scratch and returned cells borrow before/after schemas and source values.
    /// Publish only after every source row has passed under a frozen source cut.
    pub fn row(self: Transition, values: []const Cell, output: []Cell) ![]const Cell {
        return self.rowDetailed(values, output, null);
    }
    pub fn rowDetailed(self: Transition, values: []const Cell, output: []Cell, failure: ?*?s.ColumnId) ![]const Cell {
        if (failure) |column| column.* = null;
        try self.before.validateRow(values);
        try self.after.validate();
        if (self.before.object != self.after.object or self.after.revision != try std.math.add(u64, self.before.revision, 1)) return error.InvalidSchemaTransition;
        if (output.len < self.after.columns.len) return error.RowBufferTooSmall;
        const result = output[0..self.after.columns.len];
        for (self.after.columns, result) |column, *cell| {
            const index = self.before.index(column.id) catch |err| {
                if (err != error.UnknownColumn) return err;
                if (column.id < self.before.next_column) return error.ReusedColumnIdentity;
                cell.* = column.initial();
                continue;
            };
            cell.* = convert(values[index], self.before.columns[index].type, column.type) catch |err| {
                if (failure) |selected| selected.* = column.id;
                return err;
            };
        }
        try self.after.validateRowDetailed(result, failure);
        var violation: @import("TableConstraints.zig").CheckViolation = undefined;
        self.after.integrity.validateExisting(self.after, result, &violation) catch |err| {
            if (err == error.CheckConstraintViolation) if (failure) |column| {
                column.* = violation.column_id;
            };
            return err;
        };
        return result;
    }
};
/// Produces a borrowed successor. Storage owns the frozen source cut, complete
/// validation/rewrite, indexes, concurrent-write fence and conditional head swap.
pub fn apply(before: s.Schema, change: Change, columns: *[s.max_columns]s.Column) !Transition {
    try before.validate();
    try @import("TableConstraints.zig").validateChangeAgainstConstraints(before, change, before.integrity.checks, before.integrity.foreign_keys, &.{});
    var after = before;
    after.revision = try std.math.add(u64, before.revision, 1);
    @memcpy(columns[0..before.columns.len], before.columns);
    var count = before.columns.len;
    var key_changed = false;
    var validate_rows = false;
    switch (change) {
        .integrity => |value| {
            try value.validate();
            var basis = value;
            basis.integrity = before.integrity;
            if (!std.mem.eql(u8, &try basis.fingerprint(), &try before.fingerprint())) return error.InvalidSchemaTransition;
            validate_rows = try @import("TableConstraints.zig").Integrity.evolution(before.integrity, value.integrity);
            after.integrity = value.integrity;
        },
        .add => |column| {
            if (count == columns.len) return error.InvalidColumnCount;
            validate_rows = !column.nullable and column.default == null;
            after.next_column = try std.math.add(u64, before.next_column, 1);
            columns[count] = .{ .id = before.next_column, .name = column.name, .type = column.type, .nullable = column.nullable, .default = column.default, .max_characters = column.max_characters, .encoding = column.encoding, .collation = column.collation };
            count += 1;
        },
        .drop => |id| {
            for (before.primary_key) |key| if (key == id) return error.PrimaryKeyColumnRequired;
            const index = try before.index(id);
            std.mem.copyForwards(s.Column, columns[index .. count - 1], columns[index + 1 .. count]);
            count -= 1;
        },
        .rename => |value| columns[try before.index(value.column)].name = value.name,
        .default => |value| columns[try before.index(value.column)].default = value.value,
        .nullable => |value| {
            const column = &columns[try before.index(value.column)];
            validate_rows = column.nullable and !value.value;
            column.nullable = value.value;
        },
        .type => |value| {
            const column = &columns[try before.index(value.column)];
            if (!try castSupported(column.type, value.type)) return error.UnsupportedSchemaConversion;
            if (column.default) |cell| column.default = try convert(cell, column.type, value.type);
            for (before.primary_key) |id| if (id == column.id and !try column.type.eql(value.type)) {
                key_changed = true;
            };
            validate_rows = if (value.max_characters) |limit| column.max_characters == null or limit < column.max_characters.? else false;
            column.type = value.type;
            column.max_characters = value.max_characters;
        },
        .physical => |value| {
            const column = &columns[try before.index(value.column)];
            for (before.primary_key) |id| if (id == column.id and column.collation != value.collation) {
                key_changed = true;
            };
            column.encoding = value.encoding;
            column.collation = value.collation;
        },
    }
    after.columns = columns[0..count];
    try after.validate();
    const physical_change = !std.mem.eql(u8, &try before.layoutFingerprint(), &try after.layoutFingerprint());
    const rewrite = switch (change) {
        .physical => physical_change,
        .type => |value| !try before.columns[try before.index(value.column)].type.eql(value.type),
        else => false,
    };
    return .{ .before = before, .after = after, .work = if (rewrite) .rewrite_rows else if (validate_rows) .validate_rows else .metadata, .rebuild_key = key_changed };
}
/// Exact numeric casts only. A supported pair still requires per-value overflow
/// and precision checks. No implicit text/temporal/nested conversion is admitted.
pub fn castSupported(from: t.Type, to: t.Type) !bool {
    if (try from.eql(to)) return true;
    const from_integer = t.Semantics.integer(from) != null;
    const to_integer = t.Semantics.integer(to) != null;
    if ((from_integer or from == .decimal) and (to_integer or to == .decimal)) return true;
    return (from_integer or from == .float32 or from == .float64) and (to == .float32 or to == .float64);
}
fn convert(cell: Cell, from: t.Type, to: t.Type) !Cell {
    if (try from.eql(to) or cell == .null) return cell;
    if (!try castSupported(from, to) or cell != .value or cell.value != .atom) return error.UnsupportedSchemaConversion;
    return .{ .value = .{ .atom = try t.Semantics.cast(cell.value.atom, from, to, .reject) } };
}

test {
    _ = @import("table_evolution_test.zig");
}
