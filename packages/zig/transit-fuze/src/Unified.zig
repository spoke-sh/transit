//! Versioned pure state-query model. Authorization and durable source adapters
//! belong to transit-query. Borrowed row/plan bytes never outlive their owner.
const std = @import("std");
pub const max_columns = 8;
pub const max_rows = 8;
pub const max_cell_bytes = 4096;
pub const max_conflicts = 8;
pub const Type = @import("Scalar.zig").Type;
pub const Kind = @import("Scalar.zig").Kind;
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
    version: u8 = 1,
    columns: []const Column,
    pub fn validate(self: Schema) !void {
        if (self.version != 1) return error.UnsupportedSchema;
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
        hash.update("transit.fuze.schema.v1\x00");
        hash.update(&.{@intCast(self.columns.len)});
        for (self.columns) |item| {
            hash.update(&.{ item.name.len, @backingInt(item.type) });
            hash.update(item.name.slice());
        }
        return hash.finalResult();
    }
};
pub const Scalar = @import("Scalar.zig").Scalar;
pub const Alternative = @import("Scalar.zig").Alternative;
pub const State = @import("Scalar.zig").State;
pub const Cell = @import("Scalar.zig").Cell;
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

/// Hash a canonical source declaration produced by its owning adapter.
pub fn sourceFingerprint(encoded: []const u8) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.source.v1\x00");
    hash.update(encoded);
    return hash.finalResult();
}
