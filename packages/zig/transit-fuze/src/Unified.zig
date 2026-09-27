//! Versioned pure state-query model. Authorization and durable source adapters
//! belong to transit-query. Borrowed row/plan bytes never outlive their owner.
const std = @import("std");
pub const max_columns = 8;
pub const max_rows = 8;
pub const max_cell_bytes = 4096;
pub const max_conflicts = 8;
pub const Type = enum(u8) { int64 = 1, uint64 = 2, float64 = 3, boolean = 4, utf8 = 5, binary = 6 };
pub const Kind = enum(u8) { unknown = 0, int64 = 1, uint64 = 2, float64 = 3, boolean = 4, utf8 = 5, binary = 6, null_value = 7, map = 8, list = 9, text = 10, character = 11 };
pub const SourceKind = enum(u8) { kv = 1, table = 2, document = 3 };
pub const Name = struct {
    bytes: [32]u8 = @splat(0),
    len: u8 = 0,
    pub fn init(bytes: []const u8) !Name {
        if (bytes.len == 0 or bytes.len > 32) return error.InvalidColumnName;
        for (bytes, 0..) |byte, i| if (!(std.ascii.isAlphabetic(byte) or byte == '_' or (i > 0 and std.ascii.isDigit(byte)))) return error.InvalidColumnName;
        var result: Name = .{ .len = @intCast(bytes.len) };
        @memcpy(result.bytes[0..bytes.len], bytes);
        return result;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Column = struct { name: Name, type: Type };
pub const Schema = struct {
    version: u8 = 2,
    columns: []const Column,
    pub fn validate(self: Schema) !void {
        if (self.version != 2) return error.UnsupportedSchema;
        if (self.columns.len == 0 or self.columns.len > max_columns) return error.InvalidColumnCount;
        for (self.columns, 0..) |item, index| {
            if (item.name.len > 32 or !std.meta.eql(item.name, try Name.init(item.name.slice()))) return error.InvalidColumnName;
            for (self.columns[0..index]) |previous| if (std.meta.eql(previous.name, item.name)) return error.DuplicateColumn;
        }
    }
    pub fn column(self: Schema, index: u8) !Column {
        if (index >= self.columns.len) return error.UnknownColumn;
        return self.columns[index];
    }
    pub fn fingerprint(self: Schema) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.fuze.schema.v2\x00");
        hash.update(&.{@intCast(self.columns.len)});
        for (self.columns) |item| {
            hash.update(&.{ item.name.len, @backingInt(item.type) });
            hash.update(item.name.slice());
        }
        return hash.finalResult();
    }
};
pub const Scalar = union(Type) {
    int64: i64,
    uint64: u64,
    float64: f64,
    boolean: bool,
    utf8: []const u8,
    binary: []const u8,
    pub fn validate(self: Scalar, expected: Type) !void {
        if (std.meta.activeTag(self) != expected) return error.TypeMismatch;
        switch (self) {
            .float64 => |value| if (!std.math.isFinite(value)) return error.NonFiniteValue,
            .utf8, .binary => |bytes| {
                if (bytes.len > max_cell_bytes) return error.CellTooLarge;
                if (self == .utf8 and !std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
            },
            else => {},
        }
    }
    pub fn kind(self: Scalar) Kind {
        return @fromBackingInt(@intCast(@backingInt(std.meta.activeTag(self))));
    }
    pub fn order(left: Scalar, right: Scalar) !std.math.Order {
        try left.validate(std.meta.activeTag(right));
        try right.validate(std.meta.activeTag(left));
        return switch (left) {
            .int64 => |value| std.math.order(value, right.int64),
            .uint64 => |value| std.math.order(value, right.uint64),
            .float64 => |value| std.math.order(value, right.float64),
            .boolean => |value| std.math.order(@intFromBool(value), @intFromBool(right.boolean)),
            .utf8 => |value| std.mem.order(u8, value, right.utf8),
            .binary => |value| std.mem.order(u8, value, right.binary),
        };
    }
};
pub const Alternative = struct {
    counter: u64,
    replica: u64,
    value: union(enum) { null, type_error: Kind, value: Scalar },
};
pub const State = enum(u8) { missing = 0, null = 1, type_error = 2, value = 3, conflict = 4 };
pub const Cell = union(State) {
    missing,
    null,
    type_error: Kind,
    value: Scalar,
    conflict: []const Alternative,
    pub fn validate(self: Cell, expected: Type) !void {
        switch (self) {
            .value => |value| try value.validate(expected),
            .conflict => |values| {
                if (values.len < 2 or values.len > max_conflicts) return error.InvalidConflict;
                for (values, 0..) |value, index| {
                    if (value.counter == 0 or value.replica == 0) return error.InvalidConflict;
                    if (index > 0) {
                        const previous = values[index - 1];
                        if (value.counter < previous.counter or (value.counter == previous.counter and value.replica <= previous.replica)) return error.InvalidConflict;
                    }
                    switch (value.value) {
                        .value => |scalar| try scalar.validate(expected),
                        else => {},
                    }
                }
            },
            else => {},
        }
    }
};
pub const Row = struct { cells: []const Cell };
pub const Basis = struct {
    kind: SourceKind,
    resource: u64,
    revision: u64,
    contract: [32]u8,
    schema: [32]u8,
    pub fn validate(self: Basis, schema: Schema) !void {
        if (self.resource == 0 or !std.mem.eql(u8, &self.schema, &try schema.fingerprint())) return error.SourceChanged;
    }
};
pub const Page = struct {
    basis: Basis,
    ordinal: u64,
    rows: []const Row,
    end: bool,
    pub fn validate(self: Page, schema: Schema) !void {
        try self.basis.validate(schema);
        if (self.rows.len > max_rows) return error.SourceBudgetExceeded;
        for (self.rows) |row| {
            if (row.cells.len != schema.columns.len) return error.InvalidColumnCount;
            for (row.cells, schema.columns) |cell, column| try cell.validate(column.type);
        }
    }
};
pub const Plan = @import("UnifiedPlan.zig");
pub const Codec = @import("UnifiedCodec.zig");
pub const Arrow = @import("UnifiedArrow.zig");
pub const Inspect = @import("UnifiedInspect.zig");
pub const Stream = @import("UnifiedStream.zig");
pub const Sql = @import("UnifiedSql.zig");
test {
    _ = @import("unified_test.zig");
    _ = @import("unified_sql_test.zig");
}
