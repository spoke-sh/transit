//! Lossless common scalar matrix. NULL is a cell state, never a logical type.
const std = @import("std");
const f = @import("root.zig").fuze;
const Self = @This();
pub const Kind = union(enum) {
    int8,
    int16,
    int32,
    int64,
    uint8,
    uint16,
    uint32,
    uint64,
    float32,
    float64,
    decimal: f.Types.Decimal,
    boolean,
    utf8,
    binary,
};
kind: Kind,
nullable: bool,
pub const Operation = enum { declaration, result, parameter };
pub const Failure = struct {
    // Both database error-frame encoders admit at most 512 message bytes.
    bytes: [512]u8 = undefined,
    len: usize = 0,
    pub fn message(self: *const Failure) []const u8 {
        return self.bytes[0..self.len];
    }
    fn set(self: *Failure, field: f.Types.Field, dialect: f.Sql.Dialect, operation: Operation) void {
        var writer: std.Io.Writer = .fixed(&self.bytes);
        writer.print("{s} cannot {s} {s} \"{f}\" with type ", .{
            if (dialect == .mysql) "MySQL" else "PostgreSQL",
            switch (operation) {
                .declaration => "declare",
                .result => "return",
                .parameter => "bind",
            },
            if (operation == .parameter) "parameter" else "column",
            std.zig.fmtString(field.name),
        }) catch {};
        f.LogicalDisplay.typeName(&writer, field.type) catch {};
        self.len = writer.buffered().len;
    }
};
/// Read-only capability admission. Authorization and durable admission belong
/// to the caller; retain only already authorized column/parameter metadata.
pub fn admit(field: f.Types.Field, dialect: f.Sql.Dialect, operation: Operation, failure: ?*Failure) !Self {
    return admitInner(field, dialect) catch |err| {
        if (err == error.UnsupportedWireType) if (failure) |detail| detail.set(field, dialect, operation);
        return err;
    };
}
fn admitInner(field: f.Types.Field, dialect: f.Sql.Dialect) !Self {
    const result = try from(field);
    // MySQL's DECIMAL domain has at most 30 fractional digits. PostgreSQL
    // NUMERIC carries all native scales. Never silently trim a stored scale.
    if (dialect == .mysql and result.kind == .decimal and result.kind.decimal.scale > 30) return error.UnsupportedWireType;
    return result;
}
pub fn from(field: f.Types.Field) !Self {
    return .{ .kind = switch (field.type) {
        .decimal => |d| blk: {
            try field.type.validate(.{});
            break :blk .{ .decimal = d };
        },
        inline .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .float32, .float64, .boolean, .utf8, .binary => |_, tag| @unionInit(Kind, @tagName(tag), {}),
        else => return error.UnsupportedWireType,
    }, .nullable = field.nullable };
}
pub fn logical(self: Self) f.Types.Type {
    return switch (self.kind) {
        .decimal => |d| .{ .decimal = d },
        inline else => |_, tag| @unionInit(f.Types.Type, @tagName(tag), {}),
    };
}
pub fn value(self: Self, cell: f.Types.Values.Cell) !?f.Types.Values.Atom {
    return switch (cell) {
        .null => if (self.nullable) null else error.NullNotAllowed,
        .missing => error.MissingWireValue,
        .type_error => error.QueryTypeError,
        .conflict => error.QueryConflict,
        .value => |v| blk: {
            if (v != .atom) return error.UnsupportedWireType;
            try f.LogicalPrepared.validate(v.atom, self.logical());
            break :blk v.atom;
        },
    };
}
test "wire admission refuses unsupported descriptors and non-SQL states" {
    const t = std.testing;
    try t.expectError(error.UnsupportedWireType, from(.{ .name = "x", .type = .int128, .nullable = true }));
    const column = try from(.{ .name = "x", .type = .uint64, .nullable = true });
    try t.expectEqual(@as(?f.Types.Values.Atom, null), try column.value(.null));
    try t.expectError(error.MissingWireValue, column.value(.missing));
    try t.expectError(error.QueryTypeError, column.value(.{ .type_error = .uint64 }));
    try t.expectEqual(@as(u128, std.math.maxInt(u64)), (try column.value(.{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } })).?.unsigned);
}

pub fn validate(kind: Kind, atom: f.Types.Values.Atom) !void {
    f.LogicalPrepared.validate(atom, (Self{ .kind = kind, .nullable = false }).logical()) catch |err| return scalarError(err);
}
pub fn scalarError(err: anyerror) anyerror {
    return switch (err) {
        error.Overflow => error.WireValueOutOfRange,
        error.Inexact => error.InexactDecimalRounding,
        error.InvalidLiteral, error.NonFiniteValue => error.InvalidWireValue,
        else => err,
    };
}
pub fn decimalParse(text: []const u8, descriptor: f.Types.Decimal) !f.Types.Values.Atom {
    return f.Types.Semantics.bind(text, .{ .decimal = descriptor }) catch |err| return scalarError(err);
}
/// Exact decimal rendering into caller scratch, including declared trailing zeros.
pub fn decimalText(buffer: []u8, coefficient: i128, scale: u8) ![]const u8 {
    var digits: [40]u8 = undefined;
    const text = try std.fmt.bufPrint(&digits, "{d}", .{@abs(coefficient)});
    const width = @max(text.len, @as(usize, scale) + 1);
    const negative: usize = @intFromBool(coefficient < 0);
    const length = negative + width + @intFromBool(scale != 0);
    if (length > buffer.len) return error.NoSpaceLeft;
    var offset: usize = 0;
    if (negative != 0) {
        buffer[0] = '-';
        offset = 1;
    }
    for (0..width) |i| {
        if (scale != 0 and i == width - scale) {
            buffer[offset] = '.';
            offset += 1;
        }
        buffer[offset] = if (i < width - text.len) '0' else text[i - (width - text.len)];
        offset += 1;
    }
    return buffer[0..offset];
}

test "wire scalar admission retains descriptors and rejects unsupported declarations" {
    const t = std.testing;
    inline for (comptime std.meta.tags(std.meta.Tag(Kind))) |tag| {
        const kind: Kind = if (comptime tag == .decimal) .{ .decimal = .{ .precision = 38, .scale = 2 } } else @unionInit(Kind, @tagName(tag), {});
        const column: Self = .{ .kind = kind, .nullable = true };
        inline for (.{ f.Sql.Dialect.transit, f.Sql.Dialect.mysql }) |dialect| {
            const admitted = try admit(.{ .name = "value", .type = column.logical(), .nullable = true }, dialect, .declaration, null);
            try t.expectEqualDeep(column, admitted);
        }
    }
    var failure: Failure = .{};
    const field: f.Types.Field = .{ .name = "fraction", .type = .{ .decimal = .{ .precision = 38, .scale = 38 } } };
    _ = try admit(field, .transit, .result, null);
    try t.expectError(error.UnsupportedWireType, admit(field, .mysql, .declaration, &failure));
    try t.expect(std.mem.indexOf(u8, failure.message(), "fraction") != null);
    try t.expect(std.mem.indexOf(u8, failure.message(), "38") != null);
    try t.expectError(error.UnsupportedWireType, admit(.{ .name = "bad\nname", .type = .int128 }, .transit, .result, &failure));
    try t.expect(std.mem.indexOfScalar(u8, failure.message(), '\n') == null);
    const nested: [40]f.Types.Field = @splat(.{ .name = "long_nested_column", .type = .int128 });
    try t.expectError(error.UnsupportedWireType, admit(.{ .name = "wide", .type = .{ .structure = &nested } }, .mysql, .result, &failure));
    try t.expect(failure.len <= 512);
    try t.expect(std.unicode.utf8ValidateSlice(failure.message()));
    try t.expectError(error.WireValueOutOfRange, validate(.int8, .{ .signed = 128 }));
    try t.expectError(error.WireValueOutOfRange, validate(.uint16, .{ .unsigned = 65536 }));
    try t.expectError(error.InexactDecimalRounding, decimalParse("1.001", .{ .precision = 10, .scale = 2 }));
    try t.expectError(error.WireValueOutOfRange, decimalParse("100000000", .{ .precision = 10, .scale = 2 }));
    try t.expectEqual(@as(i128, -120), (try decimalParse("-1.2000", .{ .precision = 10, .scale = 2 })).decimal);
}
