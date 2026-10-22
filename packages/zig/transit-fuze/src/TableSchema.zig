//! Pure Table schema and row semantics. Slices borrow their caller; decode owns
//! an arena. No catalog resolution, storage, policy, clock or I/O is implicit.
const std = @import("std");
const t = @import("Types.zig");
const v = t.Values;
pub const definition = "transit.table.schema.v1.2026-10-05";
pub const max_columns = 128;
pub const max_bytes = 65536;
pub const ColumnId = u64;
/// Orthogonal physical column representation ($\epsilon$). Logical values and
/// expressions evaluate over `Type` ($\tau$) independently of physical codec.
pub const Encoding = enum(u8) {
    plain = 0,
    bitpacked = 1,
    rle = 2,
    dictionary = 3,
    fsst = 4,
    comp = 5,
    comp_3 = 6,
    zoned = 7,
    ibm_hfp = 8,
    ebcdic = 9,
};
/// Orthogonal ordering and equality collation ($\kappa$) for text columns.
pub const Collation = enum(u8) {
    none = 0,
    utf8_binary = 1,
    ascii_ci = 2,
    ebcdic_cp037 = 3,
    icu_root = 4,
};
pub const Column = struct {
    id: ColumnId,
    name: []const u8,
    type: t.Type,
    nullable: bool = true,
    default: ?v.Cell = null,
    /// Unicode scalar count, separate from the encoded-byte/work budgets.
    max_characters: ?u32 = null,
    encoding: Encoding = .plain,
    collation: Collation = .none,

    pub fn field(self: Column) t.Field {
        return .{ .name = self.name, .type = self.type, .nullable = self.nullable };
    }
    pub fn validateEncodingAndCollation(self: Column) !void {
        const is_integer = switch (self.type) {
            .int8, .int16, .int32, .int64, .int128, .uint8, .uint16, .uint32, .uint64, .uint128 => true,
            else => false,
        };
        const valid_encoding = switch (self.encoding) {
            .plain => true,
            .bitpacked => is_integer or self.type == .boolean,
            .rle, .dictionary => keyType(self.type),
            .fsst, .ebcdic => self.type == .utf8 or self.type == .binary,
            .comp => is_integer,
            .comp_3, .zoned => is_integer or self.type == .decimal,
            .ibm_hfp => self.type == .float32 or self.type == .float64,
        };
        if (!valid_encoding) return error.IncompatibleColumnEncoding;
        const valid_collation = switch (self.collation) {
            .none => true,
            .utf8_binary, .ascii_ci, .ebcdic_cp037, .icu_root => self.type == .utf8,
        };
        if (!valid_collation) return error.IncompatibleColumnCollation;
    }
    pub fn validateCell(self: Column, cell: v.Cell) !void {
        try cell.validate(self.field(), .{});
        try stored(cell);
        if (self.max_characters) |maximum| {
            if (cell == .value) {
                if (self.type != .utf8 or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidCharacterLimit;
                if (try std.unicode.utf8CountCodepoints(cell.value.atom.bytes) > maximum) return error.CharacterLimitExceeded;
            }
        }
    }
    pub fn initial(self: Column) v.Cell {
        return self.default orelse if (self.nullable) .null else .missing;
    }
};
pub const Assignment = struct {
    column: ColumnId,
    value: union(enum) { default, cell: v.Cell },
};
pub const Schema = struct {
    /// Stable catalog object identity, independent of physical Table location.
    object: u64,
    revision: u64,
    /// Monotonic floor retained even when the highest column is dropped.
    next_column: ColumnId,
    columns: []const Column,
    /// Empty means internal row identity; column position never implies a key.
    primary_key: []const ColumnId = &.{},

    pub fn index(self: Schema, id: ColumnId) !usize {
        for (self.columns, 0..) |column, i| if (column.id == id) return i;
        return error.UnknownColumn;
    }
    pub fn named(self: Schema, name: []const u8) !usize {
        for (self.columns, 0..) |column, i| if (std.mem.eql(u8, column.name, name)) return i;
        return error.UnknownColumn;
    }
    pub fn rowType(self: Schema, output: *[max_columns]t.Field) !t.Type {
        if (self.columns.len == 0 or self.columns.len > max_columns) return error.InvalidColumnCount;
        for (self.columns, output[0..self.columns.len]) |column, *field| field.* = column.field();
        return .{ .structure = output[0..self.columns.len] };
    }
    /// The physical descriptor uses column identities as field labels. User
    /// renames/default changes do not change stored value bytes or layout.
    pub fn storageType(self: Schema, output: *[max_columns]t.Field, names: *[max_columns][16]u8) !t.Type {
        _ = try self.rowType(output);
        for (self.columns, 0..) |column, i| {
            var id: [8]u8 = undefined;
            std.mem.writeInt(u64, &id, column.id, .big);
            names[i] = std.fmt.bytesToHex(&id, .lower);
            output[i].name = &names[i];
        }
        return .{ .structure = output[0..self.columns.len] };
    }
    pub fn hasPhysicalAttributes(self: Schema) bool {
        for (self.columns) |column| {
            if (column.encoding != .plain or column.collation != .none) return true;
        }
        return false;
    }
    /// Physical row interpretation only. Preparation/admission must retain the
    /// full schema fingerprint; this digest never authorizes stale operations.
    pub fn layoutFingerprint(self: Schema) ![32]u8 {
        try self.validate();
        var fields: [max_columns]t.Field = undefined;
        var names: [max_columns][16]u8 = undefined;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.layout.v1\x00");
        hash.update(definition);
        var object: [8]u8 = undefined;
        std.mem.writeInt(u64, &object, self.object, .little);
        hash.update(&object);
        hash.update(&try (try self.storageType(&fields, &names)).fingerprint());
        if (self.hasPhysicalAttributes()) {
            hash.update("FTP1");
            for (self.columns) |column| {
                hash.update(&.{ @backingInt(column.encoding), @backingInt(column.collation) });
            }
        }
        return hash.finalResult();
    }
    pub fn validate(self: Schema) !void {
        if (self.object == 0 or self.revision == 0 or self.next_column == 0) return error.InvalidTableSchemaIdentity;
        var fields: [max_columns]t.Field = undefined;
        const row_type = try self.rowType(&fields);
        for (self.columns, 0..) |column, i| {
            if (column.id == 0 or column.id >= self.next_column) return error.InvalidColumnIdentity;
            for (self.columns[0..i]) |previous| {
                if (previous.id == column.id) return error.DuplicateColumnIdentity;
                if (std.mem.eql(u8, previous.name, column.name)) return error.DuplicateColumn;
            }
            if (column.max_characters) |limit| if (limit == 0 or column.type != .utf8) return error.InvalidCharacterLimit;
            try column.validateEncodingAndCollation();
            if (column.default) |value| try column.validateCell(value);
        }
        try row_type.validate(.{});
        var names: [max_columns][16]u8 = undefined;
        try (try self.storageType(&fields, &names)).validate(.{});
        if (self.primary_key.len > self.columns.len) return error.InvalidPrimaryKey;
        for (self.primary_key, 0..) |id, i| {
            const column = self.columns[try self.index(id)];
            if (column.nullable) return error.NullablePrimaryKey;
            if (!keyType(column.type)) return error.UnsupportedPrimaryKeyType;
            for (self.primary_key[0..i]) |previous| if (previous == id) return error.DuplicatePrimaryKeyColumn;
        }
        var scratch: [256]u8 = undefined;
        var count: std.Io.Writer.Discarding = .init(&scratch);
        try self.write(&count.writer);
        if (count.fullCount() > max_bytes) return error.TableSchemaTooLarge;
    }
    pub fn validateRow(self: Schema, cells: []const v.Cell) !void {
        return self.validateRowDetailed(cells, null);
    }
    /// Reports the stable column ID at the actual failing cell. A shared
    /// whole-row budget failure has no invented column attribution.
    pub fn validateRowDetailed(self: Schema, cells: []const v.Cell, failure: ?*?ColumnId) !void {
        if (failure) |column| column.* = null;
        try self.validate();
        if (cells.len != self.columns.len) return error.InvalidRowWidth;
        for (cells, self.columns) |cell, column| column.validateCell(cell) catch |err| {
            if (failure) |selected| selected.* = column.id;
            return err;
        };
        // Validate the entire row under one shared recursive byte/child budget.
        var fields: [max_columns]t.Field = undefined;
        const row: v.Cell = .{ .value = .{ .structure = cells } };
        try row.validate(.{ .name = "row", .type = try self.rowType(&fields) }, .{});
    }
    pub fn validateKey(self: Schema, cells: []const v.Cell) !void {
        try self.validate();
        if (self.primary_key.len == 0) return error.NoPrimaryKey;
        if (cells.len != self.primary_key.len) return error.InvalidKeyWidth;
        var fields: [max_columns]t.Field = undefined;
        for (self.primary_key, cells, 0..) |id, cell, i| {
            const column = self.columns[try self.index(id)];
            fields[i] = column.field();
            try column.validateCell(cell);
        }
        const row: v.Cell = .{ .value = .{ .structure = cells } };
        try row.validate(.{ .name = "key", .type = .{ .structure = fields[0..cells.len] } }, .{});
    }
    /// Output cells borrow the original cells/defaults. The caller retains both
    /// owners. Failure leaves scratch output unusable and publishes nothing.
    pub fn insert(self: Schema, assignments: []const Assignment, output: []v.Cell) ![]const v.Cell {
        try self.validate();
        if (output.len < self.columns.len) return error.RowBufferTooSmall;
        const row = output[0..self.columns.len];
        for (self.columns, row) |column, *cell| cell.* = column.initial();
        try self.assign(assignments, row);
        try self.validateRow(row);
        return row;
    }
    pub fn update(self: Schema, previous: []const v.Cell, assignments: []const Assignment, output: []v.Cell) ![]const v.Cell {
        try self.validateRow(previous);
        if (output.len < self.columns.len) return error.RowBufferTooSmall;
        const row = output[0..self.columns.len];
        std.mem.copyForwards(v.Cell, row, previous);
        try self.assign(assignments, row);
        try self.validateRow(row);
        return row;
    }
    fn assign(self: Schema, assignments: []const Assignment, output: []v.Cell) !void {
        try self.validateAssignments(assignments);
        for (assignments) |assignment| {
            const i = try self.index(assignment.column);
            output[i] = switch (assignment.value) {
                .default => self.columns[i].initial(),
                .cell => |cell| cell,
            };
        }
    }
    /// Validate a typed patch independently of row existence. Omitted columns
    /// remain unassigned; explicit DEFAULT must satisfy the column contract.
    pub fn validateAssignments(self: Schema, assignments: []const Assignment) !void {
        try self.validate();
        if (assignments.len > self.columns.len) return error.InvalidRowWidth;
        var seen: [max_columns]bool = @splat(false);
        for (assignments) |assignment| {
            const i = try self.index(assignment.column);
            if (seen[i]) return error.DuplicateAssignment;
            seen[i] = true;
            try self.columns[i].validateCell(switch (assignment.value) {
                .default => self.columns[i].initial(),
                .cell => |cell| cell,
            });
        }
    }
    pub fn encode(self: Schema, output: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
        try self.write(&writer);
        return writer.buffered();
    }
    fn write(self: Schema, writer: *std.Io.Writer) !void {
        try writer.writeAll("FTS1");
        try writer.writeByte(definition.len);
        try writer.writeAll(definition);
        try writer.writeInt(u64, self.object, .little);
        try writer.writeInt(u64, self.revision, .little);
        try writer.writeInt(u64, self.next_column, .little);
        try writer.writeInt(u16, @intCast(self.columns.len), .little);
        var descriptor: [t.max_encoding_bytes]u8 = undefined;
        var value: [max_bytes]u8 = undefined;
        for (self.columns) |column| {
            try writer.writeInt(u64, column.id, .little);
            try writer.writeByte(@intCast(column.name.len));
            try writer.writeAll(column.name);
            const bytes = try column.type.encode(&descriptor);
            try writer.writeInt(u16, @intCast(bytes.len), .little);
            try writer.writeAll(bytes);
            try writer.writeByte(@intFromBool(column.nullable));
            try writer.writeInt(u32, column.max_characters orelse 0, .little);
            try writer.writeByte(@intFromBool(column.default != null));
            if (column.default) |cell| {
                const encoded = t.Codec.encode(cell, column.field(), &value) catch |err| return if (err == error.WriteFailed) error.TableSchemaTooLarge else err;
                try writer.writeInt(u32, @intCast(encoded.len), .little);
                try writer.writeAll(encoded);
            }
        }
        try writer.writeInt(u16, @intCast(self.primary_key.len), .little);
        for (self.primary_key) |id| try writer.writeInt(u64, id, .little);
        if (self.hasPhysicalAttributes()) {
            try writer.writeAll("FTP1");
            for (self.columns) |column| {
                try writer.writeByte(@backingInt(column.encoding));
                try writer.writeByte(@backingInt(column.collation));
            }
        }
    }
    pub fn fingerprint(self: Schema) ![32]u8 {
        var bytes: [max_bytes]u8 = undefined;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(try self.encode(&bytes), &digest, .{});
        return digest;
    }
    pub fn clone(self: Schema, allocator: std.mem.Allocator) !Owned {
        var bytes: [max_bytes]u8 = undefined;
        return decode(allocator, try self.encode(&bytes));
    }
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    schema: Schema,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    if (bytes.len > max_bytes) return error.TableSchemaTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FTS1")) return error.InvalidTableSchemaEncoding;
    if (!std.mem.eql(u8, try reader.take(try reader.takeByte()), definition)) return error.UnsupportedTableSchemaDefinition;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var schema: Schema = .{
        .object = try reader.takeInt(u64, .little),
        .revision = try reader.takeInt(u64, .little),
        .next_column = try reader.takeInt(u64, .little),
        .columns = undefined,
    };
    const count = try reader.takeInt(u16, .little);
    if (count == 0 or count > max_columns) return error.InvalidColumnCount;
    const columns = try a.alloc(Column, count);
    for (columns) |*column| {
        const id = try reader.takeInt(u64, .little);
        const name = try a.dupe(u8, try reader.take(try reader.takeByte()));
        // Child codecs allocate exclusively through this arena. Its lifetime
        // owns their descriptor/value allocations, including nested arenas.
        const data_type = try t.decode(a, try reader.take(try reader.takeInt(u16, .little)));
        const nullable = try boolean(&reader);
        const limit = try reader.takeInt(u32, .little);
        column.* = .{ .id = id, .name = name, .type = data_type.type, .nullable = nullable, .max_characters = if (limit == 0) null else limit };
        if (try boolean(&reader)) {
            const size = try reader.takeInt(u32, .little);
            if (size > max_bytes) return error.TableSchemaTooLarge;
            const value = try t.Codec.decode(a, try reader.take(size));
            if (value.field.nullable != nullable or value.field.optional or !try value.field.type.eql(column.type)) return error.InvalidTableDefault;
            column.default = value.cell;
        }
    }
    schema.columns = columns;
    const keys = try reader.takeInt(u16, .little);
    if (keys > count) return error.InvalidPrimaryKey;
    const primary = try a.alloc(ColumnId, keys);
    for (primary) |*id| id.* = try reader.takeInt(u64, .little);
    schema.primary_key = primary;
    if (reader.seek < bytes.len) {
        if (bytes.len - reader.seek != 4 + columns.len * 2) return error.InvalidTableSchemaEncoding;
        if (!std.mem.eql(u8, try reader.take(4), "FTP1")) return error.InvalidTableSchemaEncoding;
        var has_physical = false;
        for (columns) |*column| {
            column.encoding = std.enums.fromInt(Encoding, try reader.takeByte()) orelse return error.InvalidTableSchemaEncoding;
            column.collation = std.enums.fromInt(Collation, try reader.takeByte()) orelse return error.InvalidTableSchemaEncoding;
            if (column.encoding != .plain or column.collation != .none) has_physical = true;
        }
        if (!has_physical) return error.InvalidTableSchemaEncoding;
    }
    if (reader.seek != bytes.len) return error.InvalidTableSchemaEncoding;
    try schema.validate();
    return .{ .arena = arena, .schema = schema };
}
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidTableSchemaEncoding,
    };
}
pub fn keyType(data_type: t.Type) bool {
    return switch (data_type) {
        .structure, .list, .array, .map, .tagged_union, .json, .interval => false,
        else => true,
    };
}
/// Values have already passed bounded structural validation before this walk.
fn stored(cell: v.Cell) anyerror!void {
    switch (cell) {
        .type_error => return error.TableTypeError,
        .conflict => return error.TableConflict,
        .missing, .null => {},
        .value => |value| switch (value) {
            .atom, .json => {},
            .structure, .list, .array => |children| for (children) |child| try stored(child),
            .map => |entries| for (entries) |entry| try stored(entry.value),
            .tagged_union => |tagged| try stored(tagged.value.*),
        },
    }
}

test {
    _ = @import("table_schema_test.zig");
}
