//! Collation comparators and order-preserving sort keys for column values,
//! zone maps, B-tree indexes, and vectorized filter/sort kernels.
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");

pub const Collation = TableSchema.Collation;
pub const max_sort_key_bytes: usize = 4096;

/// Bijective US/Canada EBCDIC CP037 -> ASCII/Latin-1 translation table.
/// In EBCDIC CP037, lowercase 'a'..'z' (0x81..0xA9) sort BEFORE uppercase
/// 'A'..'Z' (0xC1..0xE9), which sort BEFORE digits '0'..'9' (0xF0..0xF9).
pub const ebcdic037_to_latin1: [256]u8 = blk: {
    var table: [256]u8 = undefined;
    for (0..256) |i| table[i] = @intCast(i);
    // Standard CP037 printable mappings
    table[0x40] = ' ';
    table[0x4B] = '.';
    table[0x4C] = '<';
    table[0x4D] = '(';
    table[0x4E] = '+';
    table[0x4F] = '|';
    table[0x50] = '&';
    table[0x5A] = '!';
    table[0x5B] = '$';
    table[0x5C] = '*';
    table[0x5D] = ')';
    table[0x5E] = ';';
    table[0x60] = '-';
    table[0x61] = '/';
    table[0x6B] = ',';
    table[0x6C] = '%';
    table[0x6D] = '_';
    table[0x6E] = '>';
    table[0x6F] = '?';
    table[0x79] = '`';
    table[0x7A] = ':';
    table[0x7B] = '#';
    table[0x7C] = '@';
    table[0x7D] = '\'';
    table[0x7E] = '=';
    table[0x7F] = '"';
    // Lowercase a-i (0x81..0x89), j-r (0x91..0x99), s-z (0xA2..0xA9)
    for (0..9) |k| table[0x81 + k] = @intCast('a' + k);
    for (0..9) |k| table[0x91 + k] = @intCast('j' + k);
    for (0..8) |k| table[0xA2 + k] = @intCast('s' + k);
    table[0xA1] = '~';
    table[0xAD] = '[';
    table[0xBD] = ']';
    table[0xC0] = '{';
    table[0xD0] = '}';
    table[0xE0] = '\\';
    table[0x5F] = '^';
    // Uppercase A-I (0xC1..0xC9), J-R (0xD1..0xD9), S-Z (0xE2..0xE9)
    for (0..9) |k| table[0xC1 + k] = @intCast('A' + k);
    for (0..9) |k| table[0xD1 + k] = @intCast('J' + k);
    for (0..8) |k| table[0xE2 + k] = @intCast('S' + k);
    // Digits 0-9 (0xF0..0xF9)
    for (0..10) |k| table[0xF0 + k] = @intCast('0' + k);
    break :blk table;
};

pub const latin1_to_ebcdic037: [256]u8 = blk: {
    var inv: [256]u8 = undefined;
    for (0..256) |i| inv[i] = @intCast(i);
    inv[' '] = 0x40;
    inv['.'] = 0x4B;
    inv['<'] = 0x4C;
    inv['('] = 0x4D;
    inv['+'] = 0x4E;
    inv['|'] = 0x4F;
    inv['&'] = 0x50;
    inv['!'] = 0x5A;
    inv['$'] = 0x5B;
    inv['*'] = 0x5C;
    inv[')'] = 0x5D;
    inv[';'] = 0x5E;
    inv['^'] = 0x5F;
    inv['-'] = 0x60;
    inv['/'] = 0x61;
    inv[','] = 0x6B;
    inv['%'] = 0x6C;
    inv['_'] = 0x6D;
    inv['>'] = 0x6E;
    inv['?'] = 0x6F;
    inv['`'] = 0x79;
    inv[':'] = 0x7A;
    inv['#'] = 0x7B;
    inv['@'] = 0x7C;
    inv['\''] = 0x7D;
    inv['='] = 0x7E;
    inv['"'] = 0x7F;
    for (0..9) |k| inv['a' + k] = @intCast(0x81 + k);
    for (0..9) |k| inv['j' + k] = @intCast(0x91 + k);
    for (0..8) |k| inv['s' + k] = @intCast(0xA2 + k);
    inv['~'] = 0xA1;
    inv['['] = 0xAD;
    inv[']'] = 0xBD;
    inv['{'] = 0xC0;
    inv['}'] = 0xD0;
    inv['\\'] = 0xE0;
    for (0..9) |k| inv['A' + k] = @intCast(0xC1 + k);
    for (0..9) |k| inv['J' + k] = @intCast(0xD1 + k);
    for (0..8) |k| inv['S' + k] = @intCast(0xE2 + k);
    for (0..10) |k| inv['0' + k] = @intCast(0xF0 + k);
    break :blk inv;
};

pub inline fn asciiLower(byte: u8) u8 {
    return if (byte >= 'A' and byte <= 'Z') byte + ('a' - 'A') else byte;
}

/// UCA-like primary weight for a byte: whitespace/control < punctuation < digits < case-folded letters.
/// Secondary weight breaks ties on case (lowercase before uppercase) so ordering is deterministic.
fn ucaPrimaryWeight(byte: u8) u8 {
    if (byte >= 'a' and byte <= 'z') return 0x80 + (byte - 'a');
    if (byte >= 'A' and byte <= 'Z') return 0x80 + (byte - 'A');
    if (byte >= '0' and byte <= '9') return 0x60 + (byte - '0');
    return byte;
}

fn ucaSecondaryWeight(byte: u8) u8 {
    if (byte >= 'A' and byte <= 'Z') return 2;
    if (byte >= 'a' and byte <= 'z') return 1;
    return 0;
}

/// Compare two UTF-8 / binary slices under the declared Collation.
pub fn compareBytes(left: []const u8, right: []const u8, collation: Collation) std.math.Order {
    switch (collation) {
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
            const min_len = @min(left.len, right.len);
            for (left[0..min_len], right[0..min_len]) |l, r| {
                const el = latin1_to_ebcdic037[l];
                const er = latin1_to_ebcdic037[r];
                if (el != er) return std.math.order(el, er);
            }
            return std.math.order(left.len, right.len);
        },
        .icu_root => {
            const min_len = @min(left.len, right.len);
            // Pass 1: primary case-insensitive weights
            for (left[0..min_len], right[0..min_len]) |l, r| {
                const pl = ucaPrimaryWeight(l);
                const pr = ucaPrimaryWeight(r);
                if (pl != pr) return std.math.order(pl, pr);
            }
            if (left.len != right.len) return std.math.order(left.len, right.len);
            // Pass 2: secondary case weights
            for (left, right) |l, r| {
                const sl = ucaSecondaryWeight(l);
                const sr = ucaSecondaryWeight(r);
                if (sl != sr) return std.math.order(sl, sr);
            }
            return .eq;
        },
    }
}

/// Compare two validated Atoms under the column's logical type and collation.
pub fn compareAtom(left: Values.Atom, right: Values.Atom, expected: Types.Type, collation: Collation) !std.math.Order {
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
    const rl = stateRank(std.meta.activeTag(left));
    const rr = stateRank(std.meta.activeTag(right));
    if (rl != rr) return std.math.order(rl, rr);
    return switch (left) {
        .missing, .null => .eq,
        .type_error => |kl| std.math.order(@intFromEnum(kl), @intFromEnum(right.type_error)),
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

fn writeCollatedBytes(writer: *std.Io.Writer, bytes: []const u8, collation: Collation) !void {
    switch (collation) {
        .none, .utf8_binary => {
            for (bytes) |b| try writeStuffedByte(writer, b);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ascii_ci => {
            for (bytes) |b| try writeStuffedByte(writer, asciiLower(b));
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .ebcdic_cp037 => {
            for (bytes) |b| try writeStuffedByte(writer, latin1_to_ebcdic037[b]);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
        .icu_root => {
            for (bytes) |b| try writeStuffedByte(writer, ucaPrimaryWeight(b));
            // Separator between primary and secondary weights; because primary weights
            // are byte-stuffed (>= 0x00FF or >= 0x01), 0x00 0x01 orders shorter strings first.
            try writer.writeAll(&.{ 0x00, 0x01 });
            for (bytes) |b| try writer.writeByte(ucaSecondaryWeight(b) + 1);
            try writer.writeAll(&.{ 0x00, 0x00 });
        },
    }
}

/// Encode a single 5-state Cell into an order-preserving sort key such that
/// `std.mem.order(u8, keyA, keyB) == compareCell(cellA, cellB, expected, collation)`.
pub fn encodeSortKey(cell: Values.Cell, expected: Types.Type, collation: Collation, out: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(out);
    try appendSortKey(&writer, cell, expected, collation);
    return writer.buffered();
}

pub fn appendSortKey(writer: *std.Io.Writer, cell: Values.Cell, expected: Types.Type, collation: Collation) !void {
    try writer.writeByte(stateRank(std.meta.activeTag(cell)));
    switch (cell) {
        .missing, .null => {},
        .type_error => |kind| try writer.writeByte(@intFromEnum(kind)),
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
                    .bytes => |v| try writeCollatedBytes(writer, v, collation),
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
            .json => |bytes| try writeCollatedBytes(writer, bytes, collation),
            else => return error.UnorderedType,
        },
    }
}

/// Encode a composite primary-key sort key across all primary-key columns of `schema`,
/// respecting each key column's declared `Collation`.
pub fn encodePrimaryKeySortKey(schema: TableSchema.Schema, row_or_key_cells: []const Values.Cell, is_full_row: bool, out: []u8) ![]const u8 {
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
