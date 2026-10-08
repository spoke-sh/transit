//! Owned general Table DDL compilation. Catalog binding, authorization, staging
//! and execution are separate. ALTER requires its captured current schema.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const s = @import("TableSchema.zig");
const evolution = @import("TableEvolution.zig");
const Reference = @import("SqlReference.zig");
pub const Create = struct {
    name: []const u8,
    if_not_exists: bool,
    columns: []const s.Column,
    primary_key: []const s.ColumnId,
    pub fn bind(self: Create, object: u64) !s.Schema {
        const schema: s.Schema = .{ .object = object, .revision = 1, .next_column = self.columns.len + 1, .columns = self.columns, .primary_key = self.primary_key };
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
    return targetContext(allocator, text, null, editor);
}
pub fn targetDiagnostic(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location) !Target {
    return targetContext(allocator, text, location, null);
}
fn targetContext(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, editor: ?*Parser.Editor) !Target {
    var parser = try Parser.init(allocator, text, location);
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
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.init(arena.allocator(), text, location);
    parser.editor = editor;
    const input = try syntax(&parser, basis);
    try parser.finish();
    const statement = try input.bind(arena.allocator(), basis, location);
    return .{ .arena = arena, .statement = statement };
}
const ParsedColumn = struct { value: s.Column, primary: bool, explicit_nullable: bool };
fn column(parser: *Parser, id: s.ColumnId) !ParsedColumn {
    const name = try parser.named(.proposed);
    const data_type = try parser.dataType();
    var value: s.Column = .{ .id = id, .name = name, .type = data_type.type, .max_characters = data_type.max_characters };
    var seen_null = false;
    var seen_default = false;
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
fn unsupportedConstraint(parser: Parser) bool {
    inline for (.{ "UNIQUE", "CHECK", "REFERENCES", "FOREIGN", "CONSTRAINT", "GENERATED", "IDENTITY", "COLLATE", "AUTO_INCREMENT" }) |word| if (parser.token.tag == .word and std.ascii.eqlIgnoreCase(parser.token.text, word)) return true;
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
    try parser.require(.left);
    var columns: std.ArrayList(s.Column) = .empty;
    var explicit_null: [s.max_columns]bool = @splat(false);
    var keys: std.ArrayList(s.ColumnId) = .empty;
    var key_names: std.ArrayList(Reference) = .empty;
    var primary = false;
    while (true) {
        if (try parser.takeWord("PRIMARY")) {
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
    const result: Create = .{ .name = name, .if_not_exists = if_not_exists, .columns = try columns.toOwnedSlice(parser.allocator), .primary_key = try keys.toOwnedSlice(parser.allocator) };
    // Validate all pure shape/default/constraint rules before the catalog assigns
    // a real object identity. The provisional identity is never returned/stored.
    _ = try result.bind(1);
    return result;
}
pub const Syntax = union(enum) {
    create: Create,
    alter: AlterSyntax,
    drop: struct { name: []const u8, if_exists: bool },
    pub fn bind(self: Syntax, allocator: std.mem.Allocator, basis: ?s.Schema, location: ?*sql.Location) !Statement {
        return switch (self) {
            .create => |value| .{ .create = value },
            .alter => |value| .{ .alter = try value.bind(allocator, basis orelse return error.TableSchemaRequired, location) },
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
    },
    fn bind(self: AlterSyntax, allocator: std.mem.Allocator, basis: s.Schema, location: ?*sql.Location) !Alter {
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
        _ = try parser.takeWord("COLUMN");
        const added = try column(parser, 1);
        if (added.primary) return error.UnsupportedTableConstraint;
        break :blk .{ .add = .{ .name = added.value.name, .type = added.value.type, .nullable = added.value.nullable, .default = added.value.default, .max_characters = added.value.max_characters } };
    } else if (try parser.takeWord("DROP")) blk: {
        _ = try parser.takeWord("COLUMN");
        result.column = try Reference.unqualified(parser, .column);
        if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
        _ = try parser.takeWord("RESTRICT");
        break :blk .drop;
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
