//! Owned general Table DDL compilation. Catalog binding, authorization, staging
//! and execution are separate. ALTER requires its captured current schema.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const s = @import("TableSchema.zig");
const evolution = @import("TableEvolution.zig");
const Reference = @import("SqlReference.zig");
const Check = @import("SqlCheck.zig");
pub const ForeignKey = @import("SqlForeignKey.zig");
const Constraints = @import("TableConstraints.zig");
pub const Create = struct {
    name: []const u8,
    if_not_exists: bool,
    columns: []const s.Column,
    primary_key: []const s.ColumnId,
    integrity: Constraints.Integrity = .{},
    foreign_keys: []const ForeignKey.Syntax = &.{},
    pub fn bind(self: Create, object: u64) !s.Schema {
        if (self.foreign_keys.len != 0) return error.ForeignKeyResolutionRequired;
        return self.bindShape(object);
    }
    fn bindShape(self: Create, object: u64) !s.Schema {
        const schema: s.Schema = .{ .object = object, .revision = 1, .next_column = self.columns.len + 1, .columns = self.columns, .primary_key = self.primary_key, .integrity = self.integrity };
        try schema.validate();
        return schema;
    }
};
pub const Alter = struct {
    name: []const u8,
    object: u64,
    schema: [32]u8,
    action: union(enum) { columns: evolution.Change, rename_table: []const u8 },
};
pub const Drop = struct { name: []const u8, if_exists: bool, object: ?u64, schema: ?[32]u8 };
pub const Statement = union(enum) { create: Create, alter: Alter, drop: Drop };
pub const Target = struct { kind: std.meta.Tag(Statement), name: []const u8 };
/// Header only, for authorized catalog resolution before bound compilation.
/// The result borrows allocator storage and is never execution admission.
pub fn target(allocator: std.mem.Allocator, text: []const u8) !Target {
    return targetWithEditor(allocator, text, null);
}
pub fn targetWithEditor(allocator: std.mem.Allocator, text: []const u8, editor: ?*Parser.Editor) !Target {
    return targetContext(allocator, text, null, editor, .transit);
}
pub fn targetDiagnostic(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Target {
    return targetContext(allocator, text, location, null, .transit);
}
pub fn targetDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) !Target {
    return targetContext(allocator, text, location, null, dialect);
}
fn targetContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, editor: ?*Parser.Editor, dialect: sql.Dialect) !Target {
    var parser = try Parser.initDialect(allocator, text, location, false, dialect);
    parser.editor = editor;
    const kind: std.meta.Tag(Statement) = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    try parser.requireWord("TABLE");
    if (kind != .alter and try parser.takeWord("IF")) {
        if (kind == .create) try parser.requireWord("NOT");
        try parser.requireWord("EXISTS");
    }
    return .{ .kind = kind, .name = try parser.named(if (kind == .create) .proposed else .source) };
}
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn compile(allocator: std.mem.Allocator, text: []const u8, basis: ?s.Schema, location: ?*sql.Location) !Owned {
    return compileWithEditor(allocator, text, basis, location, null);
}
pub fn compileWithEditor(allocator: std.mem.Allocator, text: []const u8, basis: ?s.Schema, location: ?*sql.Location, editor: ?*Parser.Editor) !Owned {
    return compileContext(allocator, text, basis, location, editor, .transit, null);
}
pub fn compileDialect(allocator: std.mem.Allocator, text: []const u8, basis: ?s.Schema, location: ?*sql.Location, dialect: sql.Dialect) !Owned {
    return compileContext(allocator, text, basis, location, null, dialect, null);
}
pub fn compileWithForeignKeys(allocator: std.mem.Allocator, text: []const u8, basis: ?s.Schema, location: ?*sql.Location, dialect: sql.Dialect, resolver: ForeignKey.Resolver) !Owned {
    return compileContext(allocator, text, basis, location, null, dialect, resolver);
}
fn compileContext(allocator: std.mem.Allocator, text: []const u8, basis: ?s.Schema, location: ?*sql.Location, editor: ?*Parser.Editor, dialect: sql.Dialect, resolver: ?ForeignKey.Resolver) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.initDialect(arena.allocator(), text, location, false, dialect);
    parser.editor = editor;
    const input = try syntax(&parser, basis);
    try parser.finish();
    const statement = try input.bindWithForeignKeys(arena.allocator(), basis, location, resolver);
    return .{ .arena = arena, .statement = statement };
}
const ParsedColumn = struct { value: s.Column, primary: bool, explicit_nullable: bool };
fn column(parser: *Parser, id: s.ColumnId) !ParsedColumn {
    const name = try parser.named(.proposed);
    const data_type = try parser.dataType();
    var value: s.Column = .{ .id = id, .name = name, .type = data_type.type, .max_characters = data_type.max_characters };
    var seen_null = false;
    var seen_default = false;
    var seen_collation = false;
    var primary = false;
    while (true) {
        if (parser.word("NOT") or parser.word("NULL")) {
            if (seen_null) return error.DuplicateColumnConstraint;
            seen_null = true;
            value.nullable = (try parser.nullability(true)).value;
        } else if (try parser.takeWord("DEFAULT")) {
            if (seen_default) return error.DuplicateColumnConstraint;
            seen_default = true;
            value.default = try parser.value(data_type.type);
        } else if (try parser.takeWord("PRIMARY")) {
            if (primary) return error.MultiplePrimaryKeys;
            primary = true;
            try parser.requireWord("KEY");
        } else if (try parser.takeWord("COLLATE")) {
            if (seen_collation) return error.DuplicateColumnConstraint;
            seen_collation = true;
            if (parser.token.tag == .eof) if (parser.editor) |editor| {
                inline for (.{ "UTF8_BINARY", "ASCII_CI", "EBCDIC_CP037", "EBCDIC_037_PAD", "EBCDIC_1047_NOPAD" }) |name_| editor.word(name_);
            };
            if (parser.token.tag != .word) return error.UnsupportedColumnCollation;
            value.collation = switch (@import("PerfectHash.zig").DdlOptionMap.get(parser.token.text) orelse return error.UnsupportedColumnCollation) {
                .collation_utf8_binary => .utf8_binary,
                .collation_ascii_ci => .ascii_ci,
                .collation_ebcdic_cp037 => .ebcdic_cp037,
                .collation_ebcdic_037_pad => .ebcdic_037_pad,
                .collation_ebcdic_1047_nopad => .ebcdic_1047_nopad,
                else => return error.UnsupportedColumnCollation,
            };
            parser.annotate(.keyword);
            try parser.advance();
            try value.validateEncodingAndCollation();
        } else if (try parser.takeWord("ROUNDING")) {
            if (value.semantics.rounding != null) return error.DuplicateColumnConstraint;
            value.semantics.rounding = try semanticEnum(@import("DecimalArithmetic.zig").RoundingMode, parser);
        } else if (try parser.takeWord("METRIC")) {
            if (value.semantics.metric != null) return error.DuplicateColumnConstraint;
            value.semantics.metric = try semanticEnum(@import("VectorMetric.zig").Metric, parser);
        } else if (try parser.takeWord("TIMEZONE")) {
            if (value.semantics.timezone != null) return error.DuplicateColumnConstraint;
            const zone = try semanticBytes(parser, .utf8);
            try parser.requireWord("TZDB");
            const version = try semanticBytes(parser, .utf8);
            try parser.requireWord("TZIF");
            const bytes = try semanticBytes(parser, .binary);
            value.semantics.timezone = try @import("PinnedTimezone.zig").Descriptor.init(version, zone, bytes);
        } else if (unsupportedConstraint(parser.*)) {
            return error.UnsupportedTableConstraint;
        } else break;
    }
    const explicit_nullable = seen_null and value.nullable;
    if (primary) {
        if (explicit_nullable) return error.NullablePrimaryKey;
        value.nullable = false;
    }
    return .{ .value = value, .primary = primary, .explicit_nullable = explicit_nullable };
}
fn semanticBytes(parser: *Parser, expected: @import("Types.zig").Type) ![]const u8 {
    const cell = try parser.value(expected);
    if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidColumnSemantics;
    return cell.value.atom.bytes;
}
fn semanticEnum(comptime E: type, parser: *Parser) !E {
    const entries = comptime blk: {
        const fields = @typeInfo(E).@"enum";
        var pairs: [fields.field_names.len]struct { []const u8, E } = undefined;
        for (fields.field_names, fields.field_values, &pairs) |name, value, *pair| pair.* = .{ name, @fromBackingInt(@intCast(value)) };
        break :blk pairs;
    };
    const names = std.StaticStringMap(E).initComptime(entries);
    var spelling: [32]u8 = undefined;
    if (parser.token.tag != .word or parser.token.text.len > spelling.len) return error.InvalidColumnSemantics;
    for (parser.token.text, spelling[0..parser.token.text.len]) |byte, *out| out.* = std.ascii.toLower(byte);
    const result = names.get(spelling[0..parser.token.text.len]) orelse return error.InvalidColumnSemantics;
    parser.annotate(.keyword);
    try parser.advance();
    return result;
}
fn unsupportedConstraint(parser: Parser) bool {
    inline for (.{ "UNIQUE", "CHECK", "REFERENCES", "FOREIGN", "CONSTRAINT", "GENERATED", "IDENTITY", "AUTO_INCREMENT" }) |word| if (parser.token.tag == .word and std.ascii.eqlIgnoreCase(parser.token.text, word)) return true;
    return false;
}
fn create(parser: *Parser) !Create {
    try parser.requireWord("TABLE");
    const if_not_exists = try parser.takeWord("IF");
    if (if_not_exists) {
        try parser.requireWord("NOT");
        try parser.requireWord("EXISTS");
    }
    const name = try parser.named(.proposed);
    return columnDefinitions(parser, name, if_not_exists);
}
/// Shared logical column grammar. The caller owns its declaration keyword,
/// name and policy clauses; no SQL text is rewritten into another object kind.
pub fn columnDefinitions(parser: *Parser, name: []const u8, if_not_exists: bool) !Create {
    try parser.require(.left);
    var columns: std.ArrayList(s.Column) = .empty;
    var explicit_null: [s.max_columns]bool = @splat(false);
    var keys: std.ArrayList(s.ColumnId) = .empty;
    var key_names: std.ArrayList(Reference) = .empty;
    var checks: std.ArrayList(Check.Syntax) = .empty;
    var foreign_keys: std.ArrayList(ForeignKey.Syntax) = .empty;
    var primary = false;
    while (true) {
        if (parser.word("CONSTRAINT") or parser.word("CHECK") or parser.word("FOREIGN")) {
            if (checks.items.len + foreign_keys.items.len == Constraints.max_constraints_per_table) return error.InvalidConstraintCount;
            const constraint_name = if (try parser.takeWord("CONSTRAINT")) try parser.named(.proposed) else try std.fmt.allocPrint(parser.allocator, "constraint_{d}", .{checks.items.len + foreign_keys.items.len + 1});
            if (parser.word("CHECK")) try checks.append(parser.allocator, try Check.parse(parser, constraint_name)) else if (parser.word("FOREIGN")) try foreign_keys.append(parser.allocator, try ForeignKey.parse(parser, constraint_name)) else return error.UnsupportedTableConstraint;
        } else if (try parser.takeWord("PRIMARY")) {
            if (primary) return error.MultiplePrimaryKeys;
            primary = true;
            try parser.requireWord("KEY");
            try parser.require(.left);
            while (true) {
                if (key_names.items.len == s.max_columns) return error.InvalidPrimaryKey;
                try key_names.append(parser.allocator, try Reference.unqualified(parser, .column));
                if (!try parser.take(.comma)) break;
            }
            try parser.require(.right);
        } else {
            if (unsupportedConstraint(parser.*)) return error.UnsupportedTableConstraint;
            if (columns.items.len == s.max_columns) return error.InvalidColumnCount;
            const parsed = try column(parser, columns.items.len + 1);
            explicit_null[columns.items.len] = parsed.explicit_nullable;
            try columns.append(parser.allocator, parsed.value);
            if (parsed.primary) {
                if (primary) return error.MultiplePrimaryKeys;
                primary = true;
                try keys.append(parser.allocator, parsed.value.id);
            }
        }
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    for (key_names.items) |key_name| {
        const i = try key_name.resolve(name, columns.items, parser.location);
        if (parser.location) |at| at.* = .{ .offset = key_name.span.start };
        if (explicit_null[i]) return error.NullablePrimaryKey;
        columns.items[i].nullable = false;
        for (keys.items) |id| if (id == columns.items[i].id) return error.DuplicatePrimaryKeyColumn;
        try keys.append(parser.allocator, columns.items[i].id);
    }
    var result: Create = .{ .name = name, .if_not_exists = if_not_exists, .columns = try columns.toOwnedSlice(parser.allocator), .primary_key = try keys.toOwnedSlice(parser.allocator), .foreign_keys = try foreign_keys.toOwnedSlice(parser.allocator) };
    // Validate all pure shape/default/constraint rules before the catalog assigns
    // a real object identity. The provisional identity is never returned/stored.
    const basis = try result.bindShape(1);
    if (checks.items.len != 0) {
        const bound = try parser.allocator.alloc(Constraints.CheckConstraint, checks.items.len);
        for (bound, checks.items, 1..) |*output, input, id| output.* = try input.bind(parser.allocator, basis, name, @intCast(id), parser.location);
        result.integrity = .{ .next_id = @intCast(bound.len + 1), .checks = bound };
        _ = try result.bindShape(1);
    }
    return result;
}
pub const Syntax = union(enum) {
    create: Create,
    alter: AlterSyntax,
    drop: struct { name: []const u8, if_exists: bool },
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, basis: ?s.Schema, location: ?*sql.Location) !Statement {
        return self.bindWithForeignKeys(allocator, basis, location, null);
    }
    pub fn bindWithForeignKeys(self: Syntax, allocator: std.mem.Allocator, basis: ?s.Schema, location: ?*sql.Location, resolver: ?ForeignKey.Resolver) !Statement {
        return switch (self) {
            .create => |input| blk: {
                var value = input;
                if (value.foreign_keys.len != 0) {
                    const schema = try value.bindShape(1);
                    const bound = try allocator.alloc(Constraints.ForeignKeyConstraint, value.foreign_keys.len);
                    for (bound, value.foreign_keys) |*out, foreign| {
                        out.* = try foreign.bind(allocator, schema, value.name, value.integrity.next_id, location, resolver);
                        value.integrity.next_id = try std.math.add(u32, value.integrity.next_id, 1);
                    }
                    value.integrity.foreign_keys = bound;
                    value.foreign_keys = &.{};
                }
                _ = try value.bind(1);
                break :blk .{ .create = value };
            },
            .alter => |value| .{ .alter = try value.bind(allocator, basis orelse return error.TableSchemaRequired, location, resolver) },
            .drop => |value| blk: {
                if (basis == null and !value.if_exists) return error.TableNotFound;
                break :blk .{ .drop = .{ .name = value.name, .if_exists = value.if_exists, .object = if (basis) |schema| schema.object else null, .schema = if (basis) |schema| try schema.fingerprint() else null } };
            },
        };
    }
};
const AlterSyntax = struct {
    name: []const u8,
    column: ?Reference = null,
    action: union(enum) {
        rename_table: []const u8,
        add: @FieldType(evolution.Change, "add"),
        rename: []const u8,
        drop,
        default: ?Parser.Literal,
        nullable: bool,
        type: @import("SqlTypes.zig").Resolved,
        add_check: Check.Syntax,
        add_foreign: ForeignKey.Syntax,
        drop_constraint: []const u8,
        validate_constraint: []const u8,
    },
    fn bind(self: AlterSyntax, allocator: std.mem.Allocator, basis: s.Schema, location: ?*sql.Location, resolver: ?ForeignKey.Resolver) !Alter {
        try basis.validate();
        const index: ?usize = if (self.column) |column_| try column_.resolve(self.name, basis.columns, location) else null;
        const id: s.ColumnId = if (index) |i| basis.columns[i].id else 0;
        const action: @FieldType(Alter, "action") = switch (self.action) {
            .rename_table => |name| .{ .rename_table = name },
            .add => |added| .{ .columns = .{ .add = added } },
            .rename => |name| .{ .columns = .{ .rename = .{ .column = id, .name = name } } },
            .drop => .{ .columns = .{ .drop = id } },
            .nullable => |value| .{ .columns = .{ .nullable = .{ .column = id, .value = value } } },
            .type => |value| .{ .columns = .{ .type = .{ .column = id, .type = value.type, .max_characters = value.max_characters } } },
            .add_check, .add_foreign, .drop_constraint, .validate_constraint => blk: {
                // Own the complete successor; the source schema may be released
                // immediately after compilation or saved-intent preparation.
                const copied = try basis.clone(allocator);
                var integrity = copied.schema.integrity;
                switch (self.action) {
                    .add_foreign => |value| {
                        if (integrity.checks.len + integrity.foreign_keys.len == Constraints.max_constraints_per_table) return error.InvalidConstraintCount;
                        const keys = try allocator.alloc(Constraints.ForeignKeyConstraint, integrity.foreign_keys.len + 1);
                        @memcpy(keys[0..integrity.foreign_keys.len], integrity.foreign_keys);
                        keys[integrity.foreign_keys.len] = try value.bind(allocator, copied.schema, self.name, integrity.next_id, location, resolver);
                        integrity.next_id = try std.math.add(u32, integrity.next_id, 1);
                        integrity.foreign_keys = keys;
                    },
                    .add_check => |value| {
                        if (integrity.checks.len + integrity.foreign_keys.len == Constraints.max_constraints_per_table) return error.InvalidConstraintCount;
                        const checks = try allocator.alloc(Constraints.CheckConstraint, integrity.checks.len + 1);
                        @memcpy(checks[0..integrity.checks.len], integrity.checks);
                        checks[integrity.checks.len] = try value.bind(allocator, copied.schema, self.name, integrity.next_id, location);
                        integrity.next_id = try std.math.add(u32, integrity.next_id, 1);
                        integrity.checks = checks;
                    },
                    .drop_constraint, .validate_constraint => |name, tag| {
                        var found = false;
                        var checks: std.ArrayList(Constraints.CheckConstraint) = .empty;
                        for (integrity.checks) |check| {
                            var next = check;
                            if (std.mem.eql(u8, check.name, name)) {
                                found = true;
                                if (tag == .drop_constraint) continue;
                                next.validated = true;
                            }
                            try checks.append(allocator, next);
                        }
                        var foreign_keys: std.ArrayList(Constraints.ForeignKeyConstraint) = .empty;
                        for (integrity.foreign_keys) |fk| {
                            if (std.mem.eql(u8, fk.name, name)) {
                                if (tag == .validate_constraint) return error.ForeignKeyIndexEnforcementUnavailable;
                                found = true;
                                continue;
                            }
                            try foreign_keys.append(allocator, fk);
                        }
                        if (!found) return error.UnknownTableConstraint;
                        integrity.checks = try checks.toOwnedSlice(allocator);
                        integrity.foreign_keys = try foreign_keys.toOwnedSlice(allocator);
                    },
                    else => unreachable,
                }
                var replacement = copied.schema;
                replacement.integrity = integrity;
                break :blk .{ .columns = .{ .integrity = replacement } };
            },
            .default => |value| blk: {
                var failure: ?Parser.Literal.Span = null;
                const cell = if (value) |literal| literal.bind(allocator, basis.columns[index.?].type, &failure) catch |err| {
                    if (location) |at| at.* = .{ .offset = (failure orelse literal.span).start };
                    return err;
                } else null;
                break :blk .{ .columns = .{ .default = .{ .column = id, .value = cell } } };
            },
        };
        if (action == .columns) {
            var output: [s.max_columns]s.Column = undefined;
            _ = try evolution.apply(basis, action.columns, &output);
        }
        return .{ .name = self.name, .object = basis.object, .schema = try basis.fingerprint(), .action = action };
    }
};
/// Optional captured metadata supplies type hints, never a substitute binding.
pub fn syntax(parser: *Parser, hints: ?s.Schema) !Syntax {
    if (try parser.takeWord("CREATE")) return .{ .create = try create(parser) };
    if (try parser.takeWord("ALTER")) return .{ .alter = try alter(parser, hints) };
    if (try parser.takeWord("DROP")) return .{ .drop = try drop(parser) };
    return error.UnsupportedStatement;
}
fn alter(parser: *Parser, hints: ?s.Schema) !AlterSyntax {
    try parser.requireWord("TABLE");
    var result: AlterSyntax = .{ .name = try parser.named(.source), .action = undefined };
    result.action = if (try parser.takeWord("RENAME")) blk: {
        if (try parser.takeWord("TO")) break :blk .{ .rename_table = try parser.named(.proposed) };
        _ = try parser.takeWord("COLUMN");
        result.column = try Reference.unqualified(parser, .column);
        try parser.requireWord("TO");
        break :blk .{ .rename = try parser.named(.proposed) };
    } else if (try parser.takeWord("ADD")) blk: {
        if (parser.word("CONSTRAINT") or parser.word("CHECK") or parser.word("FOREIGN")) {
            const constraint_name = if (try parser.takeWord("CONSTRAINT")) try parser.named(.proposed) else try std.fmt.allocPrint(parser.allocator, "check_{d}", .{if (hints) |basis| basis.integrity.next_id else 1});
            if (parser.word("FOREIGN")) break :blk .{ .add_foreign = try ForeignKey.parse(parser, constraint_name) };
            if (!parser.word("CHECK")) return error.UnsupportedTableConstraint;
            break :blk .{ .add_check = try Check.parse(parser, constraint_name) };
        }
        _ = try parser.takeWord("COLUMN");
        const added = try column(parser, 1);
        if (added.primary) return error.UnsupportedTableConstraint;
        break :blk .{ .add = .{ .name = added.value.name, .type = added.value.type, .nullable = added.value.nullable, .default = added.value.default, .max_characters = added.value.max_characters, .encoding = added.value.encoding, .collation = added.value.collation, .semantics = added.value.semantics } };
    } else if (try parser.takeWord("DROP")) blk: {
        if (try parser.takeWord("CONSTRAINT")) {
            const name = try parser.named(.column);
            if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
            _ = try parser.takeWord("RESTRICT");
            break :blk .{ .drop_constraint = name };
        }
        _ = try parser.takeWord("COLUMN");
        result.column = try Reference.unqualified(parser, .column);
        if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
        _ = try parser.takeWord("RESTRICT");
        break :blk .drop;
    } else if (try parser.takeWord("VALIDATE")) blk: {
        try parser.requireWord("CONSTRAINT");
        break :blk .{ .validate_constraint = try parser.named(.column) };
    } else if (try parser.takeWord("ALTER")) blk: {
        _ = try parser.takeWord("COLUMN");
        result.column = try Reference.unqualified(parser, .column);
        if (try parser.takeWord("SET")) {
            if (try parser.takeWord("DEFAULT")) {
                var expected: ?@import("Types.zig").Type = null;
                if (hints) |basis| if (result.column.?.resolve(result.name, basis.columns, null)) |i| {
                    expected = basis.columns[i].type;
                } else |_| {};
                break :blk .{ .default = try parser.literal(expected) };
            }
            if (try parser.takeWord("NOT")) {
                try parser.requireWord("NULL");
                break :blk .{ .nullable = false };
            }
            try parser.requireWord("DATA");
            try parser.requireWord("TYPE");
        } else if (try parser.takeWord("DROP")) {
            if (try parser.takeWord("DEFAULT")) break :blk .{ .default = null };
            try parser.requireWord("NOT");
            try parser.requireWord("NULL");
            break :blk .{ .nullable = true };
        } else try parser.requireWord("TYPE");
        const data_type = try parser.dataType();
        if (parser.word("USING")) return error.UnsupportedSchemaConversion;
        break :blk .{ .type = data_type };
    } else return error.UnsupportedAlterTable;
    return result;
}
fn drop(parser: *Parser) !@FieldType(Syntax, "drop") {
    try parser.requireWord("TABLE");
    const if_exists = try parser.takeWord("IF");
    if (if_exists) try parser.requireWord("EXISTS");
    const name = try parser.named(.source);
    if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
    _ = try parser.takeWord("RESTRICT");
    return .{ .name = name, .if_exists = if_exists };
}

test {
    _ = @import("table_ddl_test.zig");
}
