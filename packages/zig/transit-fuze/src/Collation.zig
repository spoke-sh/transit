//! Collation comparators and order-preserving sort keys for column values,
//! zone maps, B-tree indexes, and vectorized filter/sort kernels.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");

pub const Collation = TableSchema.Collation;
pub const max_sort_key_bytes: usize = 4096;

/// Complete collation profile descriptor covering both wire TableSchema.Collation
/// tags and standards-ledger EBCDIC pad / CP1047 profiles.
pub const Profile = enum(u8) {
    none = 0,
    utf8_binary = 1,
    ascii_ci = 2,
    ebcdic_cp037 = 3,
    icu_root = 4,
    ebcdic_037_pad = 5,
    ebcdic_1047_nopad = 6,

    pub fn fromCollation(collation: Collation) Profile {
        return switch (collation) {
            .none => .none,
            .utf8_binary => .utf8_binary,
            .ascii_ci => .ascii_ci,
            .ebcdic_cp037 => .ebcdic_cp037,
            .icu_root => .icu_root,
        };
    }
};

const Ebcdic = @import("Ebcdic037.zig");
pub const Ebcdic1047 = @import("Ebcdic1047.zig");
pub const ebcdic037_to_latin1 = Ebcdic.to_latin1;
pub const latin1_to_ebcdic037 = Ebcdic.from_latin1;
pub const ebcdic1047_to_latin1 = Ebcdic1047.to_latin1;
pub const latin1_to_ebcdic1047 = Ebcdic1047.from_latin1;

pub fn validate(collation: Collation) !void {
    if (collation == .icu_root) return error.UnsupportedColumnCollation;
}
pub fn validateProfile(profile: Profile) !void {
    if (profile == .icu_root) return error.UnsupportedColumnCollation;
}
pub fn validateBytes(bytes: []const u8, collation: Collation) !void {
    try validate(collation);
    if (collation == .ebcdic_cp037) try Ebcdic.validate(bytes);
}
pub fn validateBytesProfile(bytes: []const u8, profile: Profile) !void {
    try validateProfile(profile);
    switch (profile) {
        .ebcdic_cp037, .ebcdic_037_pad => try Ebcdic.validate(bytes),
        .ebcdic_1047_nopad => try Ebcdic1047.validate(bytes),
        else => {},
    }
}

pub inline fn stripTrailingAsciiSpaces(bytes: []const u8) []const u8 {
    var end = bytes.len;
    while (end > 0 and bytes[end - 1] == ' ') end -= 1;
    return bytes[0..end];
}

pub inline fn asciiLower(byte: u8) u8 {
    return if (byte >= 'A' and byte <= 'Z') byte + ('a' - 'A') else byte;
}

/// Compare two UTF-8 / binary slices under the declared Collation.
pub fn compareBytes(left: []const u8, right: []const u8, collation: Collation) !std.math.Order {
    return compareBytesProfile(left, right, Profile.fromCollation(collation));
}

/// Compare two UTF-8 / binary slices under any admitted Collation.Profile.
pub fn compareBytesProfile(left: []const u8, right: []const u8, profile: Profile) !std.math.Order {
    try validateBytesProfile(left, profile);
    try validateBytesProfile(right, profile);
    switch (profile) {
        .none, .utf8_binary => return std.mem.order(u8, left, right),
        .ascii_ci => {
            const min_len = @min(left.len, right.len);
            for (left[0..min_len], right[0..min_len]) |l, r| {
                const fl = asciiLower(l);
                const fr = asciiLower(r);
                if (fl != fr) return std.math.order(fl, fr);
            }
            return std.math.order(left.len, right.len);
        },
        .ebcdic_cp037 => {
            var l = try Ebcdic.Iterator.init(left);
            var r = try Ebcdic.Iterator.init(right);
            while (try l.next()) |lb| {
                const rb = try r.next() orelse return .gt;
                if (lb != rb) return std.math.order(lb, rb);
            }
            return if (try r.next() != null) .lt else .eq;
        },
        .ebcdic_037_pad => {
            var l = try Ebcdic.Iterator.init(stripTrailingAsciiSpaces(left));
            var r = try Ebcdic.Iterator.init(stripTrailingAsciiSpaces(right));
            while (try l.next()) |lb| {
                const rb = try r.next() orelse return .gt;
                if (lb != rb) return std.math.order(lb, rb);
            }
            return if (try r.next() != null) .lt else .eq;
        },
        .ebcdic_1047_nopad => {
            var l = try Ebcdic1047.Iterator.init(left);
            var r = try Ebcdic1047.Iterator.init(right);
            while (try l.next()) |lb| {
                const rb = try r.next() orelse return .gt;
                if (lb != rb) return std.math.order(lb, rb);
            }
            return if (try r.next() != null) .lt else .eq;
        },
        .icu_root => return error.UnsupportedColumnCollation,
    }
}

/// Compare two validated Atoms under the column's logical type and collation.
pub fn compareAtom(left: Values.Atom, right: Values.Atom, expected: Types.Type, collation: Collation) !std.math.Order {
    try validate(collation);
    try Types.Semantics.validate(left, expected);
    try Types.Semantics.validate(right, expected);
    return switch (left) {
        .signed => |v| std.math.order(v, right.signed),
        .unsigned => |v| std.math.order(v, right.unsigned),
        .float => |v| floatTotalOrder(v, right.float),
        .decimal => |v| std.math.order(v, right.decimal),
        .boolean => |v| std.math.order(@intFromBool(v), @intFromBool(right.boolean)),
        .bytes => |v| compareBytes(v, right.bytes, collation),
        .date => |v| std.math.order(v, right.date),
        .time => |v| std.math.order(v, right.time),
        .timestamp => |v| std.math.order(v, right.timestamp),
        .uuid => |v| std.mem.order(u8, &v, &right.uuid),
        .interval => error.UnorderedType,
    };
}

pub fn floatTotalOrder(a: f64, b: f64) std.math.Order {
    const ka = floatSortKeyBits(a);
    const kb = floatSortKeyBits(b);
    return std.math.order(ka, kb);
}

pub inline fn floatSortKeyBits(val: f64) u64 {
    // Canonicalize -0.0 to +0.0 so IEEE zero sign matches query equality
    const canonical: f64 = if (val == 0.0) 0.0 else val;
    const bits: u64 = @bitCast(canonical);
    return if ((bits & (@as(u64, 1) << 63)) != 0) ~bits else (bits ^ (@as(u64, 1) << 63));
}

fn stateRank(state: Types.State) u8 {
    return switch (state) {
        .missing => 0,
        .null => 1,
        .type_error => 2,
        .conflict => 3,
        .value => 4,
    };
}

/// Total order over 5-state Cells (`missing < null < type_error < conflict < value`),
/// respecting the column's declared Collation when both cells are `.value`.
pub fn compareCell(left: Values.Cell, right: Values.Cell, expected: Types.Type, collation: Collation) !std.math.Order {
    try validate(collation);
    const rl = stateRank(std.meta.activeTag(left));
    const rr = stateRank(std.meta.activeTag(right));
    if (rl != rr) return std.math.order(rl, rr);
    return switch (left) {
        .missing, .null => .eq,
        .type_error => |kl| std.math.order(@backingInt(kl), @backingInt(right.type_error)),
        .conflict => |cl| std.math.order(cl.len, right.conflict.len),
        .value => |vl| switch (vl) {
            .atom => |al| compareAtom(al, right.value.atom, expected, collation),
            .json => |jl| compareBytes(jl, right.value.json, collation),
            else => error.UnorderedType,
        },
    };
}

fn writeStuffedByte(writer: *std.Io.Writer, byte: u8) !void {
    if (byte == 0x00) {
        try writer.writeAll(&.{ 0x00, 0xFF });
    } else {
        try writer.writeByte(byte);
    }
}

fn writeCollatedBytes(writer: *std.Io.Writer, bytes: []const u8, profile: Profile) !void {
    switch (profile) {
        .none, .utf8_binary => {
            for (bytes) |b| try writeStuffedByte(writer, b);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ascii_ci => {
            for (bytes) |b| try writeStuffedByte(writer, asciiLower(b));
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ebcdic_cp037 => {
            var iterator = try Ebcdic.Iterator.init(bytes);
            while (try iterator.next()) |byte| try writeStuffedByte(writer, byte);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ebcdic_037_pad => {
            var iterator = try Ebcdic.Iterator.init(stripTrailingAsciiSpaces(bytes));
            while (try iterator.next()) |byte| try writeStuffedByte(writer, byte);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ebcdic_1047_nopad => {
            var iterator = try Ebcdic1047.Iterator.init(bytes);
            while (try iterator.next()) |byte| try writeStuffedByte(writer, byte);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .icu_root => return error.UnsupportedColumnCollation,
    }
}

/// Encode a single 5-state Cell into an order-preserving sort key such that
/// `std.mem.order(u8, keyA, keyB) == compareCell(cellA, cellB, expected, collation)`.
pub fn encodeSortKey(cell: Values.Cell, expected: Types.Type, collation: Collation, out: []u8) ![]const u8 {
    return encodeSortKeyProfile(cell, expected, Profile.fromCollation(collation), out);
}

pub fn encodeSortKeyProfile(cell: Values.Cell, expected: Types.Type, profile: Profile, out: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(out);
    try appendSortKeyProfile(&writer, cell, expected, profile);
    return writer.buffered();
}

pub fn appendSortKey(writer: *std.Io.Writer, cell: Values.Cell, expected: Types.Type, collation: Collation) !void {
    return appendSortKeyProfile(writer, cell, expected, Profile.fromCollation(collation));
}

pub fn appendSortKeyProfile(writer: *std.Io.Writer, cell: Values.Cell, expected: Types.Type, profile: Profile) !void {
    try validateProfile(profile);
    try writer.writeByte(stateRank(std.meta.activeTag(cell)));
    switch (cell) {
        .missing, .null => {},
        .type_error => |kind| try writer.writeByte(@backingInt(kind)),
        .conflict => |alts| try writer.writeInt(u32, @intCast(alts.len), .big),
        .value => |val| switch (val) {
            .atom => |atom| {
                try Types.Semantics.validate(atom, expected);
                switch (atom) {
                    .signed => |v| {
                        const mapped: u128 = @as(u128, @bitCast(v)) ^ (@as(u128, 1) << 127);
                        try writer.writeInt(u128, mapped, .big);
                    },
                    .unsigned => |v| try writer.writeInt(u128, v, .big),
                    .float => |v| try writer.writeInt(u64, floatSortKeyBits(v), .big),
                    .decimal => |v| {
                        const mapped: u128 = @as(u128, @bitCast(v)) ^ (@as(u128, 1) << 127);
                        try writer.writeInt(u128, mapped, .big);
                    },
                    .boolean => |v| try writer.writeByte(@intFromBool(v)),
                    .bytes => |v| try writeCollatedBytes(writer, v, profile),
                    .date => |v| {
                        const mapped: u32 = @as(u32, @bitCast(v)) ^ (@as(u32, 1) << 31);
                        try writer.writeInt(u32, mapped, .big);
                    },
                    .time => |v| try writer.writeInt(u64, v, .big),
                    .timestamp => |v| {
                        const mapped: u64 = @as(u64, @bitCast(v)) ^ (@as(u64, 1) << 63);
                        try writer.writeInt(u64, mapped, .big);
                    },
                    .uuid => |v| try writer.writeAll(&v),
                    .interval => return error.UnorderedType,
                }
            },
            .json => |bytes| try writeCollatedBytes(writer, bytes, profile),
            else => return error.UnorderedType,
        },
    }
}

/// Encode a composite primary-key sort key across all primary-key columns of `schema`,
/// respecting each key column's declared `Collation`.
pub fn encodePrimaryKeySortKey(schema: TableSchema.Schema, row_or_key_cells: []const Values.Cell, is_full_row: bool, out: []u8) ![]const u8 {
    if (schema.primary_key.len == 0) return error.MissingPrimaryKey;
    var writer: std.Io.Writer = .fixed(out);
    if (!is_full_row and row_or_key_cells.len != schema.primary_key.len) return error.InvalidKeyColumnCount;
    if (is_full_row and row_or_key_cells.len != schema.columns.len) return error.InvalidColumnCount;
    for (schema.primary_key, 0..) |col_id, pk_idx| {
        const col_idx = try schema.index(col_id);
        const col = schema.columns[col_idx];
        const cell = if (is_full_row) row_or_key_cells[col_idx] else row_or_key_cells[pk_idx];
        try appendSortKey(&writer, cell, col.type, col.collation);
    }
    return writer.buffered();
}
