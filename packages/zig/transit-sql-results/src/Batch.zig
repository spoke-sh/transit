//! Borrowed logical batch views. Layout and source-buffer ownership are separate
//! from result progress. Slicing and row/column access allocate no value storage.
const std = @import("std");
const r = @import("root.zig");
const Self = @This();
pub const Column = union(enum) {
    cells: []const r.Types.Values.Cell,
    vector: r.fuze.Batch.View,
    /// Admitted by PhysicalCodecs.borrowPlainColumn; retain its verified page
    /// and detail owner. Its buffers expose Arrow's nullable value child while
    /// tags/details retain Transit's other cell states.
    plain: r.fuze.PhysicalCodecs.PlainColumn,
    pub fn len(self: Column) usize {
        return switch (self) {
            .cells => |value| value.len,
            .vector => |value| value.len(),
            .plain => |value| value.buffers.tags.len,
        };
    }
    pub fn cell(self: Column, row: usize) r.Types.Values.Cell {
        return switch (self) {
            .cells => |value| value[row],
            .vector => |value| value.cell(row),
            .plain => |value| value.cell(row),
        };
    }
    fn validate(self: Column, field: r.Types.Field, count: usize) !void {
        if (self.len() != count) return error.InvalidResultColumn;
        switch (self) {
            .vector => |view| switch (view) {
                .flat => |value| {
                    if (!try value.type.eql(field.type) or value.details.len < count) return error.InvalidResultColumn;
                    switch (value.data) {
                        .states_only => return error.InvalidResultColumn,
                        .words => |words| if (words.len < count or !r.fuze.Batch.kernels.hot(value.type)) return error.InvalidResultColumn,
                        .values => |values| if (values.len < count) return error.InvalidResultColumn,
                    }
                    for (value.states, value.details[0..count]) |state, detail| switch (state) {
                        .type_error => if (detail != .type_error) return error.InvalidResultColumn,
                        .conflict => if (detail != .conflict) return error.InvalidResultColumn,
                        else => {},
                    };
                },
                .logical => |value| for (value.rows) |row| {
                    if (value.column >= row.cells.len) return error.InvalidResultColumn;
                },
                .constant => {},
                .unified => return error.InvalidResultColumn, // predicate-only view
            },
            .plain => |value| if (!try value.buffers.kind.eql(field.type)) return error.InvalidResultColumn,
            .cells => {},
        }
        for (0..count) |i| try self.cell(i).validate(field, .{});
    }
};
pub const Layout = union(enum) {
    rows: []const r.Row,
    columns: struct { values: []const Column, rows: usize },
};
layout: Layout = .{ .rows = &.{} },
offset: usize = 0,
len: usize = 0,

pub fn fromRows(rows: []const r.Row) Self {
    return .{ .layout = .{ .rows = rows }, .len = rows.len };
}
pub fn fromColumns(columns: []const Column, rows: usize) Self {
    return .{ .layout = .{ .columns = .{ .values = columns, .rows = rows } }, .len = rows };
}
pub fn validate(self: Self, fields: []const r.Types.Field) !void {
    const count = switch (self.layout) {
        .rows => |rows| rows.len,
        .columns => |columns| columns.rows,
    };
    if (self.offset > count or self.len > count - self.offset) return error.InvalidResultChunk;
    switch (self.layout) {
        .rows => |rows| for (rows[self.offset..][0..self.len]) |row| {
            if (row.len != fields.len) return error.InvalidResultRow;
            for (row, fields) |value, field| try value.validate(field, .{});
        },
        .columns => |columns| {
            if (columns.values.len != fields.len) return error.InvalidResultColumn;
            for (columns.values, fields) |column, field| try column.validate(field, count);
        },
    }
}
pub fn slice(self: Self, start: usize, count: usize) !Self {
    if (start > self.len or count > self.len - start) return error.InvalidResultChunk;
    return .{ .layout = self.layout, .offset = self.offset + start, .len = count };
}
pub fn cell(self: Self, row: usize, column: usize) r.Types.Values.Cell {
    std.debug.assert(row < self.len);
    return switch (self.layout) {
        .rows => |rows| rows[self.offset + row][column],
        .columns => |columns| columns.values[column].cell(self.offset + row),
    };
}
/// Row layouts return the original row. Column layouts populate only the caller's
/// cell descriptor scratch; payload buffers remain borrowed, never transposed.
pub fn rowInto(self: Self, index: usize, scratch: []r.Types.Values.Cell) !r.Row {
    if (index >= self.len) return error.InvalidResultRow;
    return switch (self.layout) {
        .rows => |rows| rows[self.offset + index],
        .columns => |columns| blk: {
            if (scratch.len < columns.values.len) return error.InvalidResultRow;
            for (columns.values, scratch[0..columns.values.len]) |column, *value| value.* = column.cell(self.offset + index);
            break :blk scratch[0..columns.values.len];
        },
    };
}

/// A column view also works over row-backed input without transposing it.
pub const ColumnView = struct {
    batch: Self,
    index: usize,
    pub fn cell(self: ColumnView, ordinal: usize) r.Types.Values.Cell {
        return self.batch.cell(ordinal, self.index);
    }
    /// Borrow the Arrow-compatible nullable value child when already present.
    /// Keep this column view for missing/type-error/conflict state and details.
    /// The caller's directory and source owner must outlive the Arrow view.
    pub fn arrowValues(self: ColumnView, buffers: *[3]r.fuze.arrow.SharedBuffer) !r.fuze.arrow.ArrayData {
        const columns = switch (self.batch.layout) {
            .columns => |value| value.values,
            .rows => return error.UnsupportedResultColumnLayout,
        };
        const plain = switch (columns[self.index]) {
            .plain => |value| value,
            else => return error.UnsupportedResultColumnLayout,
        };
        const data = try plain.buffers.arrowValues(buffers);
        return data.slice(self.batch.offset, self.batch.len);
    }
};
pub fn columnAt(self: Self, index: usize) !ColumnView {
    const count = switch (self.layout) {
        .columns => |value| value.values.len,
        .rows => |rows| if (rows.len != 0) rows[0].len else return error.InvalidResultColumn,
    };
    if (index >= count) return error.InvalidResultColumn;
    return .{ .batch = self, .index = index };
}
test {
    _ = @import("batch_test.zig");
}
