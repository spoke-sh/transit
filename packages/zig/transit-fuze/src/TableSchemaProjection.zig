//! Direct physical-to-logical Table interpretation by stable column identity.
//! The storage owner supplies exact retained schemas and frozen ADD-time values;
//! neither current defaults nor an unbounded ancestry walk supply missing cells.
const std = @import("std");
const s = @import("TableSchema.zig");
const Cell = @import("Types.zig").Values.Cell;
const Self = @This();

pub const Initial = struct { column: s.ColumnId, value: Cell };
pub const Source = union(enum) { physical: u8, initial: Cell };

physical: s.Schema,
logical: s.Schema,
sources: [s.max_columns]Source,

/// Schemas, initial values and projected cells borrow their original owners.
/// Callers must detach cells before releasing an interpretation or source row.
/// This mapping establishes no access, retention or publication authority.
pub fn init(physical: s.Schema, logical: s.Schema, initials: []const Initial) !Self {
    try physical.validate();
    try logical.validate();
    if (physical.object != logical.object or physical.revision > logical.revision or
        physical.next_column > logical.next_column or initials.len > logical.columns.len or
        !std.mem.eql(s.ColumnId, physical.primary_key, logical.primary_key)) return error.IncompatibleSchemaProjection;
    if (physical.revision == logical.revision and
        !std.mem.eql(u8, &try physical.fingerprint(), &try logical.fingerprint())) return error.IncompatibleSchemaProjection;
    for (initials, 0..) |initial, i| {
        _ = try logical.index(initial.column);
        for (initials[0..i]) |previous| if (previous.column == initial.column) return error.DuplicateSchemaInitialValue;
        if (physical.index(initial.column)) |_| return error.UnexpectedSchemaInitialValue else |err| if (err != error.UnknownColumn) return err;
    }
    var result: Self = .{ .physical = physical, .logical = logical, .sources = undefined };
    for (logical.columns, 0..) |column, i| {
        const index = physical.index(column.id) catch |err| {
            if (err != error.UnknownColumn) return err;
            if (column.id < physical.next_column) return error.ReusedColumnIdentity;
            const initial = for (initials) |initial| {
                if (initial.column == column.id) break initial.value;
            } else return error.MissingSchemaInitialValue;
            try column.validateCell(initial);
            result.sources[i] = .{ .initial = initial };
            continue;
        };
        if (!try compatibleColumn(physical.columns[index], column)) return error.IncompatibleSchemaProjection;
        result.sources[i] = .{ .physical = @intCast(index) };
    }
    return result;
}

fn compatibleColumn(before: s.Column, after: s.Column) !bool {
    // Tighter nullability/length limits are checked by the publication owner's
    // validation scan and by validateRow on each projected result. They do not
    // require changing the physical representation of an existing cell.
    return try before.type.eql(after.type) and before.encoding == after.encoding and
        before.collation == after.collation and before.semantics.eql(after.semantics);
}

/// Validate the complete physical row before selecting cells, including dropped
/// columns. Preserve source states; an absent historical column uses only its
/// explicitly supplied initial value, never the current insertion default.
/// Output must not overlap values. On failure its contents are unusable.
pub fn row(self: Self, values: []const Cell, output: []Cell) ![]const Cell {
    try self.physical.validateRow(values);
    if (output.len < self.logical.columns.len) return error.RowBufferTooSmall;
    const result = output[0..self.logical.columns.len];
    for (self.sources[0..result.len], result) |source, *cell| cell.* = switch (source) {
        .physical => |index| values[index],
        .initial => |value| value,
    };
    try self.logical.validateRow(result);
    return result;
}

test {
    _ = @import("table_schema_projection_test.zig");
}
