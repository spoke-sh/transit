//! Station Table storage values and descriptors; query execution uses Unified.
const std = @import("std");
pub const max_cell_bytes = 220;
pub const Type = enum(u8) { int64 = 1, boolean = 2, utf8 = 3, binary = 4 };
pub const Name = struct {
    bytes: [16]u8 = @splat(0),
    len: u8 = 0,
    pub fn init(value: []const u8) !Name {
        if (value.len == 0 or value.len > 16) return error.InvalidColumnName;
        for (value, 0..) |byte, i| {
            if (!(std.ascii.isAlphabetic(byte) or byte == '_' or (i > 0 and std.ascii.isDigit(byte)))) return error.InvalidColumnName;
        }
        var result: Name = .{ .len = @intCast(value.len) };
        @memcpy(result.bytes[0..value.len], value);
        return result;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Schema = struct {
    version: u8 = 1,
    names: [2]Name,
    value_type: Type,
    pub fn validate(self: Schema) !void {
        if (self.version != 1) return error.UnsupportedSchema;
        for (self.names) |name| {
            if (name.len > 16) return error.InvalidColumnName;
            if (!std.meta.eql(try Name.init(name.slice()), name)) return error.InvalidColumnName;
        }
        if (std.mem.eql(u8, self.names[0].slice(), self.names[1].slice())) return error.DuplicateColumn;
    }
    pub fn fingerprint(self: Schema) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(&.{ self.version, @backingInt(self.value_type) });
        for (self.names) |name| {
            hash.update(&.{name.len});
            hash.update(name.slice());
        }
        return hash.finalResult();
    }
    pub fn columnType(self: Schema, column: u8) !Type {
        return switch (column) {
            0 => .int64,
            1 => self.value_type,
            else => error.UnknownColumn,
        };
    }
};
pub const Bytes = struct {
    data: [max_cell_bytes]u8 = @splat(0),
    len: u8 = 0,
    pub fn init(value: []const u8) !Bytes {
        if (value.len > max_cell_bytes) return error.CellTooLarge;
        var bytes: Bytes = .{ .len = @intCast(value.len) };
        @memcpy(bytes.data[0..value.len], value);
        return bytes;
    }
    pub fn slice(self: *const Bytes) []const u8 {
        return self.data[0..self.len];
    }
};
pub const Cell = union(enum) {
    null,
    int64: i64,
    boolean: bool,
    utf8: Bytes,
    binary: Bytes,
    pub fn validate(self: Cell, data_type: Type) !void {
        if (self == .null) return;
        switch (self) {
            .int64 => if (data_type != .int64) return error.TypeMismatch,
            .boolean => if (data_type != .boolean) return error.TypeMismatch,
            .utf8, .binary => |bytes| {
                if ((self == .utf8 and data_type != .utf8) or (self == .binary and data_type != .binary)) return error.TypeMismatch;
                if (bytes.len > max_cell_bytes) return error.CellTooLarge;
                if (self == .utf8 and !std.unicode.utf8ValidateSlice(bytes.slice())) return error.InvalidUtf8;
            },
            .null => unreachable,
        }
    }
};
pub const Row = struct {
    key: i64,
    value: Cell,
    pub fn cell(self: Row, column: u8) !Cell {
        return switch (column) {
            0 => .{ .int64 = self.key },
            1 => self.value,
            else => error.UnknownColumn,
        };
    }
};
pub const Basis = struct { resource: u64, revision: u64, schema: [32]u8 };
