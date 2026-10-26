//! Composable pure-Zig physical codecs (analytical and enterprise/mainframe)
//! with 5-state cell preservation (`value`, `null`, `missing`, `type_error`, `conflict`).
const std = @import("std");
const Types = @import("Types.zig");
const Values = @import("Values.zig");
const TableSchema = @import("TableSchema.zig");
const Ebcdic = @import("Ebcdic037.zig");
const ColumnPredicate = @import("ColumnPredicate.zig");

pub const Encoding = TableSchema.Encoding;
pub const page_header_bytes = 41;
const definition = @import("transit_protocol").Growth.definition_bytes;

/// Encode a signed integer/decimal value into COBOL `COMP-3` (Packed Decimal / BCD)
/// with trailing sign nibble `0xC` (positive/zero) or `0xD` (negative).
pub fn encodeComp3(value: i128, byte_len: usize, out: []u8) ![]const u8 {
    if (byte_len == 0 or byte_len > 16 or out.len < byte_len) return error.InvalidComp3Length;
    const negative = value < 0;
    var magnitude: u128 = if (value == std.math.minInt(i128))
        return error.Comp3Overflow
    else
        @intCast(if (negative) -value else value);

    const max_digits = byte_len * 2 - 1;
    var nibbles: [32]u8 = @splat(0);
    var d: usize = 0;
    while (magnitude > 0) : (d += 1) {
        if (d >= max_digits) return error.Comp3Overflow;
        nibbles[d] = @intCast(magnitude % 10);
        magnitude /= 10;
    }

    const sign_nibble: u8 = if (negative) 0x0D else 0x0C;
    for (0..byte_len) |i| {
        const rev_byte = byte_len - 1 - i;
        if (rev_byte == 0) {
            const high_digit = nibbles[0];
            out[i] = (high_digit << 4) | sign_nibble;
        } else {
            const low_idx = rev_byte * 2 - 1;
            const high_idx = rev_byte * 2;
            out[i] = (nibbles[high_idx] << 4) | nibbles[low_idx];
        }
    }
    return out[0..byte_len];
}

/// Decode a COBOL `COMP-3` (Packed Decimal / BCD) byte slice into a 5-state `Values.Cell`.
/// Any non-BCD digit nibble (`> 9`) or invalid sign nibble (`< 0xA`) is captured losslessly
/// as `.{ .type_error = ... }` rather than aborting a scan.
pub fn decodeComp3(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    if (bytes.len == 0 or bytes.len > 16) return err_cell;
    var magnitude: u128 = 0;
    for (bytes, 0..) |b, i| {
        const high = b >> 4;
        const low = b & 0x0F;
        if (high > 9) return err_cell;
        magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
        magnitude = std.math.add(u128, magnitude, high) catch return err_cell;
        if (i + 1 < bytes.len) {
            if (low > 9) return err_cell;
            magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
            magnitude = std.math.add(u128, magnitude, low) catch return err_cell;
        } else {
            // Trailing sign nibble: 0xC, 0xF, 0xA, 0xE = positive; 0xD, 0xB = negative
            const negative = switch (low) {
                0x0C, 0x0F, 0x0A, 0x0E => false,
                0x0D, 0x0B => true,
                else => return err_cell,
            };
            if (magnitude > @as(u128, @intCast(std.math.maxInt(i128)))) return err_cell;
            const signed_val: i128 = if (negative and magnitude > 0) -@as(i128, @intCast(magnitude)) else @intCast(magnitude);
            return numericCellFromSigned(signed_val, expected);
        }
    }
    return err_cell;
}

/// Encode a signed integer/decimal into EBCDIC Zoned Decimal (`DISPLAY` numeric)
/// with trailing overpunched sign (`0xC0..0xC9` positive, `0xD0..0xD9` negative).
pub fn encodeZoned(value: i128, digit_len: usize, out: []u8) ![]const u8 {
    if (digit_len == 0 or digit_len > 31 or out.len < digit_len) return error.InvalidZonedLength;
    const negative = value < 0;
    var magnitude: u128 = if (value == std.math.minInt(i128))
        return error.ZonedOverflow
    else
        @intCast(if (negative) -value else value);

    var i: usize = digit_len;
    while (i > 0) {
        i -= 1;
        const digit: u8 = @intCast(magnitude % 10);
        magnitude /= 10;
        if (i + 1 == digit_len) {
            out[i] = (if (negative) @as(u8, 0xD0) else @as(u8, 0xC0)) | digit;
        } else {
            out[i] = 0xF0 | digit;
        }
    }
    if (magnitude != 0) return error.ZonedOverflow;
    return out[0..digit_len];
}

/// Decode an EBCDIC or ASCII Zoned Decimal byte slice into a 5-state `Values.Cell`.
pub fn decodeZoned(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    if (bytes.len == 0 or bytes.len > 31) return err_cell;
    var magnitude: u128 = 0;
    var negative = false;
    for (bytes, 0..) |b, i| {
        const is_edge = (i == 0 or i + 1 == bytes.len);
        const zone = b >> 4;
        const low = b & 0x0F;
        var digit: u8 = 0;
        if (zone == 0x0F and low <= 9) {
            digit = low;
        } else if (is_edge and (zone == 0x0C or zone == 0x0A or zone == 0x0E) and low <= 9) {
            digit = low;
        } else if (is_edge and (zone == 0x0D or zone == 0x0B) and low <= 9) {
            digit = low;
            negative = true;
        } else if (b >= '0' and b <= '9') {
            digit = b - '0';
        } else if (is_edge and b == '{') {
            digit = 0;
        } else if (is_edge and b >= 'A' and b <= 'I') {
            digit = (b - 'A') + 1;
        } else if (is_edge and b == '}') {
            digit = 0;
            negative = true;
        } else if (is_edge and b >= 'J' and b <= 'R') {
            digit = (b - 'J') + 1;
            negative = true;
        } else {
            return err_cell;
        }
        magnitude = std.math.mul(u128, magnitude, 10) catch return err_cell;
        magnitude = std.math.add(u128, magnitude, digit) catch return err_cell;
    }
    if (magnitude > @as(u128, @intCast(std.math.maxInt(i128)))) return err_cell;
    const signed_val: i128 = if (negative and magnitude > 0) -@as(i128, @intCast(magnitude)) else @intCast(magnitude);
    return numericCellFromSigned(signed_val, expected);
}

/// Encode a signed integer/decimal into big-endian `COMP` / `COMP-4` (2, 4, or 8 bytes).
pub fn encodeComp4(value: i128, byte_len: usize, out: []u8) ![]const u8 {
    if (out.len < byte_len) return error.BufferTooSmall;
    switch (byte_len) {
        2 => {
            const v = std.math.cast(i16, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i16, out[0..2], v, .big);
        },
        4 => {
            const v = std.math.cast(i32, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i32, out[0..4], v, .big);
        },
        8 => {
            const v = std.math.cast(i64, value) orelse return error.Comp4Overflow;
            std.mem.writeInt(i64, out[0..8], v, .big);
        },
        else => return error.InvalidComp4Length,
    }
    return out[0..byte_len];
}

/// Decode a big-endian `COMP` / `COMP-4` (2, 4, or 8 byte) field into a 5-state `Values.Cell`.
pub fn decodeComp4(bytes: []const u8, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    const signed_val: i128 = switch (bytes.len) {
        2 => std.mem.readInt(i16, bytes[0..2], .big),
        4 => std.mem.readInt(i32, bytes[0..4], .big),
        8 => std.mem.readInt(i64, bytes[0..8], .big),
        else => return err_cell,
    };
    return numericCellFromSigned(signed_val, expected);
}

pub const encodeIbmHfp64 = @import("IbmHfp.zig").encode64;
pub const decodeIbmHfp = @import("IbmHfp.zig").decode;

/// CP037 -> UTF-8; the output may need twice the source byte length.
pub const decodeEbcdic037 = Ebcdic.decode;
/// UTF-8 -> CP037; invalid UTF-8 and unmappable scalars reject.
pub const encodeEbcdic037 = Ebcdic.encode;

/// Value-dependent physical constraints are checked before Table acceptance,
/// as well as by page writers. Schema validation owns type/codec compatibility.
pub fn validateValue(column: TableSchema.Column, value: Values.Value) !void {
    switch (column.encoding) {
        .ibm_hfp => _ = try encodeIbmHfp64(value.atom.float),
        .ebcdic => try Ebcdic.validate(value.atom.bytes),
        else => {},
    }
}

fn numericCellFromSigned(val: i128, expected: Types.Type) Values.Cell {
    const err_cell: Values.Cell = .{ .type_error = Types.Kind.fromTag(expected.tag()) };
    expected.validate(.{}) catch return err_cell;
    switch (expected) {
        .int8 => {
            if (val < std.math.minInt(i8) or val > std.math.maxInt(i8)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int16 => {
            if (val < std.math.minInt(i16) or val > std.math.maxInt(i16)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int32 => {
            if (val < std.math.minInt(i32) or val > std.math.maxInt(i32)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int64 => {
            if (val < std.math.minInt(i64) or val > std.math.maxInt(i64)) return err_cell;
            return .{ .value = .{ .atom = .{ .signed = val } } };
        },
        .int128 => return .{ .value = .{ .atom = .{ .signed = val } } },
        .decimal => |dec| {
            var max_mag: i128 = 1;
            for (0..dec.precision) |_| max_mag *= 10;
            if (val <= -max_mag or val >= max_mag) return err_cell;
            return .{ .value = .{ .atom = .{ .decimal = val } } };
        },
        else => return err_cell,
    }
}

/// Encode a column slice of 5-state `Values.Cell` into a self-contained physical column page
/// using the column's declared `Encoding` ($\epsilon$).
/// Page wire format:
///   - `magic`: `"TCP1"` (4 bytes)
///   - `definition`: mandatory current shared definition (32 bytes)
///   - `encoding`: `u8` (`@intFromEnum(encoding)`)
///   - `row_count`: `u32`
///   - `tag_stream`: `row_count` bytes (`0 = value`, `1 = null`, `2 = missing`, `3 = type_error`, `4 = conflict`)
///   - `detail_stream`: for `.type_error` (`u8` kind) and `.conflict` (`u16` count + alternatives)
///   - `value_payload`: physical codec representation for all `.value` lanes (`plain`, `bitpacked`, `rle`, `dictionary`, `fsst`, `comp3`, `zoned`, `comp4`, `ibm_hfp`, `ebcdic`).
pub fn encodeColumnPage(allocator: std.mem.Allocator, column: TableSchema.Column, cells: []const Values.Cell, out: []u8) ![]const u8 {
    try column.validateEncodingAndCollation();
    if (cells.len > 65536) return error.ColumnPageRowLimitExceeded;
    for (cells) |cell| if (cell == .value) {
        try cell.validate(column.field(), .{});
        try validateValue(column, cell.value);
    };
    var writer: std.Io.Writer = .fixed(out);
    try writer.writeAll("TCP1");
    try writer.writeAll(&definition);
    try writer.writeByte(@backingInt(column.encoding));
    try writer.writeInt(u32, @intCast(cells.len), .little);

    // 1. Write 5-state tag stream
    var value_count: u32 = 0;
    for (cells) |cell| {
        const tag_byte: u8 = switch (cell) {
            .value => blk: {
                value_count += 1;
                break :blk 0;
            },
            .null => 1,
            .missing => 2,
            .type_error => 3,
            .conflict => 4,
        };
        try writer.writeByte(tag_byte);
    }

    // 2. Write detail stream for type_error and conflict cells
    for (cells) |cell| switch (cell) {
        .type_error => |kind| try writer.writeByte(@backingInt(kind)),
        .conflict => |alts| {
            try writer.writeInt(u16, @intCast(alts.len), .little);
            for (alts) |alt| {
                try writer.writeInt(u64, alt.counter, .little);
                try writer.writeInt(u64, alt.replica, .little);
                switch (alt.value) {
                    .null => try writer.writeByte(0),
                    .type_error => |kind| {
                        try writer.writeByte(1);
                        try writer.writeByte(@backingInt(kind));
                    },
                    .value => |val| {
                        try writer.writeByte(2);
                        try writeCanonicalValue(&writer, column.type, val);
                    },
                }
            }
        },
        else => {},
    };

    // 3. Collect `.value` cells for codec-specific encoding
    const values = try allocator.alloc(Values.Value, value_count);
    defer allocator.free(values);
    var vi: usize = 0;
    for (cells) |cell| if (cell == .value) {
        values[vi] = cell.value;
        vi += 1;
    };

    switch (column.encoding) {
        .plain => {
            for (values) |val| try writeCanonicalValue(&writer, column.type, val);
        },
        .bitpacked => try encodeBitpackedValues(&writer, column.type, values),
        .rle => try encodeRleValues(&writer, column.type, values),
        .dictionary => try encodeDictionaryValues(allocator, &writer, column.type, values),
        .fsst => try encodeFsstValues(&writer, values),
        .comp_3 => {
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [16]u8 = undefined;
                const encoded = try encodeComp3(num, 16, &buf);
                try writer.writeAll(encoded);
            }
        },
        .zoned => {
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [31]u8 = undefined;
                const encoded = try encodeZoned(num, 31, &buf);
                try writer.writeAll(encoded);
            }
        },
        .comp => {
            const width: usize = switch (column.type) {
                .int16 => 2,
                .int32 => 4,
                else => 8,
            };
            for (values) |val| {
                const num: i128 = switch (val.atom) {
                    .signed => |s| s,
                    .decimal => |d| d,
                    else => return error.IncompatibleColumnEncoding,
                };
                var buf: [8]u8 = undefined;
                const encoded = try encodeComp4(num, width, &buf);
                try writer.writeAll(encoded);
            }
        },
        .ibm_hfp => {
            for (values) |val| {
                const hfp = try encodeIbmHfp64(val.atom.float);
                try writer.writeAll(&hfp);
            }
        },
        .ebcdic => {
            for (values) |val| {
                const bytes = val.atom.bytes;
                const count = try std.unicode.utf8CountCodepoints(bytes);
                try writer.writeInt(u32, @intCast(count), .little);
                var iterator = try Ebcdic.Iterator.init(bytes);
                while (try iterator.next()) |byte| try writer.writeByte(byte);
            }
        },
    }
    return writer.buffered();
}

/// Decode every cell into the caller's arena. Encoded bytes can be released
/// immediately. Temporary validation state is reused between logical values.
pub fn decodeColumnPage(arena: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8) ![]Values.Cell {
    return (try decodePage(arena, arena, column, bytes, null)).cells;
}

pub const Selected = struct { row_count: u32, cells: []Values.Cell };

/// Decode strictly increasing, unique row ordinals. The complete page is still
/// validated, including unselected details, values and trailing bytes. Output
/// owns all selected children/bytes in arena. Scratch owns transient dictionary
/// entries and one reusable value workspace; it retains no result allocations.
pub fn decodeColumnPageSelected(scratch: std.mem.Allocator, arena: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8, rows: []const u32) !Selected {
    return decodePage(scratch, arena, column, bytes, rows);
}

pub const Evaluated = struct {
    outcomes: []ColumnPredicate.Outcome,
    /// Predicate evaluations over physical values (one per dictionary entry or
    /// RLE run), excluding non-value state tags. Not a device-I/O measurement.
    evaluated_values: usize,
};

/// Evaluate directly over physical values/codes/runs. The result retains one
/// byte per row, never decoded payloads. Scratch owns dictionary and reusable
/// validation work. All framing and every value are checked before success.
/// Source type errors/conflicts remain row-addressed outcomes, not hidden rows.
pub fn evaluateColumnPage(scratch: std.mem.Allocator, arena: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8, predicate: ColumnPredicate.Predicate) !Evaluated {
    try predicate.validate(column);
    var sink: PredicateSink = .{ .arena = arena, .column = column, .predicate = predicate };
    errdefer arena.free(sink.outcomes);
    _ = try decodeInto(scratch, column, bytes, &sink);
    return .{ .outcomes = sink.outcomes, .evaluated_values = sink.evaluated_values };
}

fn decodePage(scratch: std.mem.Allocator, arena: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8, rows: ?[]const u32) !Selected {
    var sink: DecodeSink = .{ .arena = arena, .column = column, .rows = rows };
    const count = try decodeInto(scratch, column, bytes, &sink);
    return .{ .row_count = count, .cells = sink.cells };
}

fn decodeInto(scratch: std.mem.Allocator, column: TableSchema.Column, bytes: []const u8, sink: anytype) !u32 {
    try column.validateEncodingAndCollation();
    if (bytes.len < page_header_bytes or !std.mem.eql(u8, bytes[0..4], "TCP1")) return error.InvalidColumnPage;
    if (!std.mem.eql(u8, bytes[4..36], &definition)) return error.IncompatibleDefinition;
    var reader: std.Io.Reader = .fixed(bytes[36..]);
    const encoding = std.enums.fromInt(Encoding, try reader.takeByte()) orelse return error.InvalidColumnPage;
    if (encoding != column.encoding) return error.ColumnEncodingMismatch;
    const row_count = try reader.takeInt(u32, .little);
    if (row_count > 65536) return error.ColumnPageRowLimitExceeded;
    const tags = try reader.take(row_count);
    var value_count: usize = 0;
    for (tags) |tag| switch (tag) {
        0 => value_count += 1,
        1...4 => {},
        else => return error.InvalidColumnPage,
    };
    var temporary = std.heap.ArenaAllocator.init(scratch);
    defer temporary.deinit();
    try sink.start(tags);
    for (tags, 0..) |tag, i| {
        const cell: Values.Cell = switch (tag) {
            0, 1 => .null,
            2 => .missing,
            3 => .{ .type_error = std.enums.fromInt(Types.Kind, try reader.takeByte()) orelse return error.InvalidColumnPage },
            4 => blk: {
                const alt_count = try reader.takeInt(u16, .little);
                if (@as(usize, alt_count) * 17 > reader.end - reader.seek) return error.InvalidColumnPage;
                const alts = try temporary.allocator().alloc(Values.Alternative, alt_count);
                for (alts) |*alt| alt.* = .{
                    .counter = try reader.takeInt(u64, .little),
                    .replica = try reader.takeInt(u64, .little),
                    .value = switch (try reader.takeByte()) {
                        0 => .null,
                        1 => .{ .type_error = std.enums.fromInt(Types.Kind, try reader.takeByte()) orelse return error.InvalidColumnPage },
                        2 => .{ .value = try readCanonicalValue(temporary.allocator(), &reader, column.type) },
                        else => return error.InvalidColumnPage,
                    },
                };
                break :blk .{ .conflict = alts };
            },
            else => unreachable,
        };
        if (tag != 0) try sink.nonValue(i, cell);
        _ = temporary.reset(.retain_capacity);
    }

    switch (column.encoding) {
        .plain => for (0..value_count) |_| {
            try sink.emit(.{ .value = try readCanonicalValue(temporary.allocator(), &reader, column.type) }, 1);
            _ = temporary.reset(.retain_capacity);
        },
        .bitpacked => try decodeBitpackedValues(&reader, value_count, sink),
        .rle => try decodeRleValues(&temporary, &reader, value_count, sink),
        .dictionary => try decodeDictionaryValues(scratch, &temporary, &reader, value_count, sink),
        .fsst => try decodeFsstValues(&temporary, &reader, value_count, sink),
        .comp_3, .zoned, .comp, .ibm_hfp => for (0..value_count) |_| {
            const cell = switch (column.encoding) {
                .comp_3 => decodeComp3(try reader.take(16), column.type),
                .zoned => decodeZoned(try reader.take(31), column.type),
                .comp => decodeComp4(try reader.take(switch (column.type) {
                    .int16 => @as(usize, 2),
                    .int32 => 4,
                    else => 8,
                }), column.type),
                .ibm_hfp => decodeIbmHfp(try reader.take(8), column.type),
                else => unreachable,
            };
            try sink.emit(cell, 1);
        },
        .ebcdic => for (0..value_count) |_| {
            const len = try reader.takeInt(u32, .little);
            const raw = try reader.take(len);
            const capacity = std.math.mul(usize, len, 2) catch return error.InvalidColumnPage;
            const buffer = try temporary.allocator().alloc(u8, capacity);
            const utf8 = try decodeEbcdic037(raw, buffer);
            try sink.emit(.{ .value = .{ .atom = .{ .bytes = utf8 } } }, 1);
            _ = temporary.reset(.retain_capacity);
        },
    }
    if (reader.seek != reader.end) return error.InvalidColumnPage;
    return row_count;
}

const DecodeSink = struct {
    arena: std.mem.Allocator,
    column: TableSchema.Column,
    rows: ?[]const u32,
    tags: []const u8 = &.{},
    cells: []Values.Cell = &.{},
    next_row: usize = 0,

    fn destination(self: *const DecodeSink, row: usize) ?usize {
        const rows = self.rows orelse return row;
        var lo: usize = 0;
        var hi = rows.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (rows[mid] < row) lo = mid + 1 else hi = mid;
        }
        return if (lo < rows.len and rows[lo] == row) lo else null;
    }
    fn start(self: *DecodeSink, tags: []const u8) !void {
        if (self.rows) |rows| for (rows, 0..) |row, i| {
            if (row >= tags.len or (i > 0 and rows[i - 1] >= row)) return error.InvalidColumnSelection;
        };
        self.tags = tags;
        self.cells = try self.arena.alloc(Values.Cell, if (self.rows) |rows| rows.len else tags.len);
    }
    fn nonValue(self: *DecodeSink, row: usize, cell: Values.Cell) !void {
        if (self.destination(row)) |slot| self.cells[slot] = try Values.cloneValidated(self.arena, cell);
    }
    const Cached = struct { cell: Values.Cell, owned: bool = false };
    fn prepare(self: *DecodeSink, cell: Values.Cell) !Cached {
        if (cell == .value) try cell.validate(self.column.field(), .{});
        return .{ .cell = cell };
    }
    fn emit(self: *DecodeSink, cell: Values.Cell, repeat: usize) !void {
        var cached = try self.prepare(cell);
        try self.emitCached(&cached, repeat);
    }
    // Selected RLE/dictionary repetitions share one detached owned value.
    fn emitCached(self: *DecodeSink, cached: *Cached, repeat: usize) !void {
        for (0..repeat) |_| {
            while (self.next_row < self.tags.len and self.tags[self.next_row] != 0) self.next_row += 1;
            if (self.next_row == self.tags.len) return error.InvalidColumnPage;
            if (self.destination(self.next_row)) |slot| {
                if (!cached.owned) {
                    cached.cell = try Values.cloneValidated(self.arena, cached.cell);
                    cached.owned = true;
                }
                self.cells[slot] = cached.cell;
            }
            self.next_row += 1;
        }
    }
};

const PredicateSink = struct {
    arena: std.mem.Allocator,
    column: TableSchema.Column,
    predicate: ColumnPredicate.Predicate,
    tags: []const u8 = &.{},
    outcomes: []ColumnPredicate.Outcome = &.{},
    next_row: usize = 0,
    evaluated_values: usize = 0,
    const Cached = ColumnPredicate.Outcome;
    fn start(self: *PredicateSink, tags: []const u8) !void {
        self.tags = tags;
        self.outcomes = try self.arena.alloc(ColumnPredicate.Outcome, tags.len);
    }
    fn nonValue(self: *PredicateSink, row: usize, cell: Values.Cell) !void {
        self.outcomes[row] = try self.predicate.evaluate(self.column, cell);
    }
    fn prepare(self: *PredicateSink, cell: Values.Cell) !Cached {
        if (cell == .value) try cell.validate(self.column.field(), .{});
        self.evaluated_values += 1;
        return self.predicate.evaluate(self.column, cell);
    }
    fn emit(self: *PredicateSink, cell: Values.Cell, repeat: usize) !void {
        var cached = try self.prepare(cell);
        try self.emitCached(&cached, repeat);
    }
    fn emitCached(self: *PredicateSink, cached: *Cached, repeat: usize) !void {
        for (0..repeat) |_| {
            while (self.next_row < self.tags.len and self.tags[self.next_row] != 0) self.next_row += 1;
            if (self.next_row == self.tags.len) return error.InvalidColumnPage;
            self.outcomes[self.next_row] = cached.*;
            self.next_row += 1;
        }
    }
};

fn scalarToU64(expected: Types.Type, val: Values.Value) u64 {
    return switch (expected) {
        .boolean => @intFromBool(val.atom.boolean),
        .uint8, .uint16, .uint32, .uint64 => @intCast(val.atom.unsigned),
        .int8, .int16, .int32, .int64 => @bitCast(@as(i64, @intCast(val.atom.signed))),
        .date => @intCast(@as(u32, @bitCast(val.atom.date))),
        .time => val.atom.time,
        .timestamp => @bitCast(val.atom.timestamp),
        else => unreachable,
    };
}

fn u64ToScalarCell(expected: Types.Type, word: u64) !Values.Cell {
    if (expected == .boolean and word > 1) return error.InvalidBitpackedPage;
    return .{ .value = .{ .atom = switch (expected) {
        .boolean => .{ .boolean = word != 0 },
        .uint8, .uint16, .uint32, .uint64 => .{ .unsigned = word },
        .int8, .int16, .int32, .int64 => .{ .signed = @as(i64, @bitCast(word)) },
        .date => .{ .date = @bitCast(@as(u32, @intCast(word))) },
        .time => .{ .time = word },
        .timestamp => .{ .timestamp = @bitCast(word) },
        else => unreachable,
    } } };
}

fn encodeBitpackedValues(writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    if (values.len == 0) return;
    var min_val: u64 = std.math.maxInt(u64);
    var max_val: u64 = 0;
    for (values) |v| {
        const w = scalarToU64(expected, v);
        min_val = @min(min_val, w);
        max_val = @max(max_val, w);
    }
    const delta = max_val - min_val;
    const bit_width: u8 = if (delta == 0) 0 else @intCast(64 - @clz(delta));
    try writer.writeInt(u64, min_val, .little);
    try writer.writeByte(bit_width);
    if (bit_width == 0) return;

    var bit_acc: u128 = 0;
    var acc_bits: u8 = 0;
    const shift_w: u7 = @intCast(bit_width);
    const mask: u64 = if (bit_width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(bit_width)) - 1;
    for (values) |v| {
        const offset = (scalarToU64(expected, v) - min_val) & mask;
        bit_acc |= (@as(u128, offset) << @intCast(acc_bits));
        acc_bits += @intCast(shift_w);
        while (acc_bits >= 8) {
            try writer.writeByte(@truncate(bit_acc));
            bit_acc >>= 8;
            acc_bits -= 8;
        }
    }
    if (acc_bits > 0) {
        try writer.writeByte(@truncate(bit_acc));
    }
}

fn decodeBitpackedValues(reader: *std.Io.Reader, count: usize, sink: anytype) !void {
    if (count == 0) return;
    const min_val = try reader.takeInt(u64, .little);
    const bit_width = try reader.takeByte();
    if (bit_width > 64) return error.InvalidBitpackedPage;
    if (bit_width == 0) {
        try sink.emit(try u64ToScalarCell(sink.column.type, min_val), count);
        return;
    }
    var bit_acc: u128 = 0;
    var acc_bits: u8 = 0;
    const mask: u64 = if (bit_width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(bit_width)) - 1;
    for (0..count) |_| {
        while (acc_bits < bit_width) {
            bit_acc |= (@as(u128, try reader.takeByte()) << @intCast(acc_bits));
            acc_bits += 8;
        }
        const offset: u64 = @as(u64, @truncate(bit_acc)) & mask;
        bit_acc >>= @intCast(bit_width);
        acc_bits -= bit_width;
        const word = std.math.add(u64, min_val, offset) catch return error.InvalidBitpackedPage;
        try sink.emit(try u64ToScalarCell(sink.column.type, word), 1);
    }
}

fn encodeRleValues(writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    if (values.len == 0) {
        try writer.writeInt(u32, 0, .little);
        return;
    }
    var runs: u32 = 1;
    for (1..values.len) |i| {
        if (!valuesEqual(expected, values[i - 1], values[i])) runs += 1;
    }
    try writer.writeInt(u32, runs, .little);
    var run_start: usize = 0;
    for (1..values.len + 1) |i| {
        if (i == values.len or !valuesEqual(expected, values[run_start], values[i])) {
            try writeCanonicalValue(writer, expected, values[run_start]);
            try writer.writeInt(u32, @intCast(i - run_start), .little);
            run_start = i;
        }
    }
}

fn decodeRleValues(temporary: *std.heap.ArenaAllocator, reader: *std.Io.Reader, count: usize, sink: anytype) !void {
    const runs = try reader.takeInt(u32, .little);
    if (runs > count) return error.InvalidRlePage;
    var pos: usize = 0;
    for (0..runs) |_| {
        const val = try readCanonicalValue(temporary.allocator(), reader, sink.column.type);
        const len = try reader.takeInt(u32, .little);
        if (len == 0 or len > count - pos) return error.InvalidRlePage;
        try sink.emit(.{ .value = val }, len);
        pos += len;
        _ = temporary.reset(.retain_capacity);
    }
    if (pos != count) return error.InvalidRlePage;
}

fn encodeDictionaryValues(allocator: std.mem.Allocator, writer: *std.Io.Writer, expected: Types.Type, values: []const Values.Value) !void {
    var dict = std.ArrayList(Values.Value).empty;
    defer dict.deinit(allocator);
    const codes = try allocator.alloc(u32, values.len);
    defer allocator.free(codes);

    for (values, 0..) |v, i| {
        var found: ?u32 = null;
        for (dict.items, 0..) |dv, di| {
            if (valuesEqual(expected, dv, v)) {
                found = @intCast(di);
                break;
            }
        }
        if (found) |code| {
            codes[i] = code;
        } else {
            const new_code: u32 = @intCast(dict.items.len);
            try dict.append(allocator, v);
            codes[i] = new_code;
        }
    }
    try writer.writeInt(u32, @intCast(dict.items.len), .little);
    for (dict.items) |dv| try writeCanonicalValue(writer, expected, dv);
    for (codes) |code| try writer.writeInt(u32, code, .little);
}

fn decodeDictionaryValues(scratch: std.mem.Allocator, temporary: *std.heap.ArenaAllocator, reader: *std.Io.Reader, count: usize, sink: anytype) !void {
    const dict_len = try reader.takeInt(u32, .little);
    if (dict_len > count) return error.InvalidDictionaryCode;
    // Decoding caches a borrowed/owned value; evaluation caches only its
    // outcome. Each physical dictionary value is validated/evaluated once.
    const dict = try scratch.alloc(@TypeOf(sink.*).Cached, dict_len);
    defer scratch.free(dict);
    for (dict) |*entry| {
        const value = try readCanonicalValue(temporary.allocator(), reader, sink.column.type);
        entry.* = try sink.prepare(.{ .value = value });
    }
    for (0..count) |_| {
        const code = try reader.takeInt(u32, .little);
        if (code >= dict.len) return error.InvalidDictionaryCode;
        try sink.emitCached(&dict[code], 1);
    }
}

/// Fast Static Symbol Table (FSST) string compression: builds a compact symbol table
/// of frequent 2-to-8 byte substrings and encodes strings as symbol codes (`0..symbol_count-1`)
/// with `0xFF` literal escape bytes.
fn encodeFsstValues(writer: *std.Io.Writer, values: []const Values.Value) !void {
    var symbols: [64][]const u8 = undefined;
    var symbol_count: u8 = 0;

    // Harvest up to 64 recurring 4-byte or 2-byte substrings from input values
    for (values) |v| {
        const s = v.atom.bytes;
        var pos: usize = 0;
        while (pos + 4 <= s.len and symbol_count < 64) : (pos += 4) {
            const cand = s[pos .. pos + 4];
            var exists = false;
            for (symbols[0..symbol_count]) |existing| {
                if (std.mem.eql(u8, existing, cand)) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                symbols[symbol_count] = cand;
                symbol_count += 1;
            }
        }
    }

    try writer.writeByte(symbol_count);
    for (symbols[0..symbol_count]) |sym| {
        try writer.writeByte(@intCast(sym.len));
        try writer.writeAll(sym);
    }

    for (values) |v| {
        const s = v.atom.bytes;
        try writer.writeInt(u32, @intCast(s.len), .little);
        // Reserve a small scratch buffer or stream compressed tokens directly
        var token_count: u32 = 0;
        var pos: usize = 0;
        while (pos < s.len) {
            var matched: ?u8 = null;
            for (symbols[0..symbol_count], 0..) |sym, idx| {
                if (pos + sym.len <= s.len and std.mem.eql(u8, s[pos .. pos + sym.len], sym)) {
                    matched = @intCast(idx);
                    pos += sym.len;
                    break;
                }
            }
            if (matched != null) {
                token_count += 1;
            } else {
                token_count += 2; // 0xFF escape + literal byte
                pos += 1;
            }
        }
        try writer.writeInt(u32, token_count, .little);
        pos = 0;
        while (pos < s.len) {
            var matched: ?u8 = null;
            for (symbols[0..symbol_count], 0..) |sym, idx| {
                if (pos + sym.len <= s.len and std.mem.eql(u8, s[pos .. pos + sym.len], sym)) {
                    matched = @intCast(idx);
                    pos += sym.len;
                    break;
                }
            }
            if (matched) |code| {
                try writer.writeByte(code);
            } else {
                try writer.writeByte(0xFF);
                try writer.writeByte(s[pos]);
                pos += 1;
            }
        }
    }
}

fn decodeFsstValues(temporary: *std.heap.ArenaAllocator, reader: *std.Io.Reader, count: usize, sink: anytype) !void {
    const symbol_count = try reader.takeByte();
    if (symbol_count > 254) return error.InvalidFsstTable;
    var symbols: [254][]const u8 = undefined;
    for (0..symbol_count) |i| {
        const sym_len = try reader.takeByte();
        if (sym_len == 0 or sym_len > 8) return error.InvalidFsstTable;
        symbols[i] = try reader.take(sym_len);
    }
    for (0..count) |_| {
        const decoded_len = try reader.takeInt(u32, .little);
        const token_len = try reader.takeInt(u32, .little);
        const tokens = try reader.take(token_len);
        if (@as(u64, decoded_len) > @as(u64, token_len) * 8) return error.InvalidFsstStream;
        const buf = try temporary.allocator().alloc(u8, decoded_len);
        var ti: usize = 0;
        var bi: usize = 0;
        while (ti < tokens.len) {
            const tok = tokens[ti];
            ti += 1;
            if (tok == 0xFF) {
                if (ti >= tokens.len or bi >= buf.len) return error.InvalidFsstStream;
                buf[bi] = tokens[ti];
                ti += 1;
                bi += 1;
            } else {
                if (tok >= symbol_count) return error.InvalidFsstStream;
                const sym = symbols[tok];
                if (bi + sym.len > buf.len) return error.InvalidFsstStream;
                @memcpy(buf[bi .. bi + sym.len], sym);
                bi += sym.len;
            }
        }
        if (bi != decoded_len) return error.InvalidFsstStream;
        try sink.emit(.{ .value = .{ .atom = .{ .bytes = buf } } }, 1);
        _ = temporary.reset(.retain_capacity);
    }
}

fn valuesEqual(expected: Types.Type, a: Values.Value, b: Values.Value) bool {
    return switch (a) {
        .atom => |la| if (la == .float)
            @as(u64, @bitCast(la.float)) == @as(u64, @bitCast(b.atom.float))
        else
            (Values.atomOrder(la, b.atom, expected) catch return false) == .eq,
        .json => |lj| std.mem.eql(u8, lj, b.json),
        else => false,
    };
}

fn writeCanonicalValue(writer: *std.Io.Writer, expected: Types.Type, val: Values.Value) !void {
    const field: Types.Field = .{ .name = "v", .type = expected, .nullable = true };
    const cell: Values.Cell = .{ .value = val };
    // Column encoders use a fixed segment budget. Encode into that remaining
    // buffer, without imposing a separate 4 KiB limit on each logical value.
    const start = writer.end;
    try writer.writeInt(u32, 0, .little);
    const encoded = try Types.Codec.encodeBound(cell, field, writer.buffer[writer.end..]);
    std.mem.writeInt(u32, writer.buffer[start..][0..4], @intCast(encoded.len), .little);
    writer.end += encoded.len;
}

fn readCanonicalValue(arena: std.mem.Allocator, reader: *std.Io.Reader, expected: Types.Type) !Values.Value {
    const field: Types.Field = .{ .name = "v", .type = expected, .nullable = true };
    const len = try reader.takeInt(u32, .little);
    const slice = try reader.take(len);
    const decoded = try Types.Codec.decodeBoundBorrowingBytes(arena, field, slice);
    if (decoded != .value) return error.InvalidColumnPage;
    return decoded.value;
}
