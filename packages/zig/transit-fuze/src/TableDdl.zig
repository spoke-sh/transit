//! Owned general Table DDL compilation. Catalog binding, authorization, staging
//! and execution are separate. ALTER requires its captured current schema.
const std = @import("std");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const s = @import("TableSchema.zig");
const evolution = @import("TableEvolution.zig");
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
    var parser = try Parser.init(allocator, text, null);
    parser.editor = editor;
    const kind: std.meta.Tag(Statement) = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    try parser.requireWord("TABLE");
    if (try parser.takeWord("IF")) {
        if (kind == .create) try parser.requireWord("NOT") else if (kind != .drop) return error.InvalidSqlSyntax;
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
    const statement: Statement = if (try parser.takeWord("CREATE")) .{ .create = try create(&parser) } else if (try parser.takeWord("ALTER")) .{ .alter = try alter(&parser, basis orelse return error.TableSchemaRequired) } else if (try parser.takeWord("DROP")) .{ .drop = try drop(&parser, basis) } else return error.UnsupportedStatement;
    try parser.finish();
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
    var key_names: std.ArrayList([]const u8) = .empty;
    var primary = false;
    while (true) {
        if (try parser.takeWord("PRIMARY")) {
            if (primary) return error.MultiplePrimaryKeys;
            primary = true;
            try parser.requireWord("KEY");
            try parser.require(.left);
            while (true) {
                if (key_names.items.len == s.max_columns) return error.InvalidPrimaryKey;
                try key_names.append(parser.allocator, try parser.name());
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
        var found: ?usize = null;
        for (columns.items, 0..) |value, i| if (std.mem.eql(u8, key_name, value.name)) {
            found = i;
            break;
        };
        const i = found orelse return error.UnknownColumn;
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
fn selectedColumn(parser: *Parser, schema: s.Schema) !s.ColumnId {
    const name = try parser.named(.column);
    return schema.columns[try schema.named(name)].id;
}
fn alter(parser: *Parser, basis: s.Schema) !Alter {
    try basis.validate();
    try parser.requireWord("TABLE");
    const name = try parser.named(.source);
    const action: @FieldType(Alter, "action") = if (try parser.takeWord("RENAME")) blk: {
        if (try parser.takeWord("TO")) break :blk .{ .rename_table = try parser.name() };
        _ = try parser.takeWord("COLUMN");
        const id = try selectedColumn(parser, basis);
        try parser.requireWord("TO");
        break :blk .{ .columns = .{ .rename = .{ .column = id, .name = try parser.name() } } };
    } else if (try parser.takeWord("ADD")) blk: {
        _ = try parser.takeWord("COLUMN");
        const added = try column(parser, basis.next_column);
        if (added.primary) return error.UnsupportedTableConstraint;
        break :blk .{ .columns = .{ .add = .{ .name = added.value.name, .type = added.value.type, .nullable = added.value.nullable, .default = added.value.default, .max_characters = added.value.max_characters } } };
    } else if (try parser.takeWord("DROP")) blk: {
        _ = try parser.takeWord("COLUMN");
        const id = try selectedColumn(parser, basis);
        if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
        _ = try parser.takeWord("RESTRICT");
        break :blk .{ .columns = .{ .drop = id } };
    } else if (try parser.takeWord("ALTER")) blk: {
        _ = try parser.takeWord("COLUMN");
        const id = try selectedColumn(parser, basis);
        if (try parser.takeWord("SET")) {
            if (try parser.takeWord("DEFAULT")) break :blk .{ .columns = .{ .default = .{ .column = id, .value = try parser.value(basis.columns[try basis.index(id)].type) } } };
            if (try parser.takeWord("NOT")) {
                try parser.requireWord("NULL");
                break :blk .{ .columns = .{ .nullable = .{ .column = id, .value = false } } };
            }
            try parser.requireWord("DATA");
            try parser.requireWord("TYPE");
        } else if (try parser.takeWord("DROP")) {
            if (try parser.takeWord("DEFAULT")) break :blk .{ .columns = .{ .default = .{ .column = id, .value = null } } };
            try parser.requireWord("NOT");
            try parser.requireWord("NULL");
            break :blk .{ .columns = .{ .nullable = .{ .column = id, .value = true } } };
        } else try parser.requireWord("TYPE");
        const data_type = try parser.dataType();
        if (parser.word("USING")) return error.UnsupportedSchemaConversion;
        break :blk .{ .columns = .{ .type = .{ .column = id, .type = data_type.type, .max_characters = data_type.max_characters } } };
    } else return error.UnsupportedAlterTable;
    if (action == .columns) {
        var output: [s.max_columns]s.Column = undefined;
        _ = try evolution.apply(basis, action.columns, &output);
    }
    return .{ .name = name, .object = basis.object, .schema = try basis.fingerprint(), .action = action };
}
fn drop(parser: *Parser, basis: ?s.Schema) !Drop {
    try parser.requireWord("TABLE");
    const if_exists = try parser.takeWord("IF");
    if (if_exists) try parser.requireWord("EXISTS");
    const name = try parser.named(.source);
    if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
    _ = try parser.takeWord("RESTRICT");
    if (basis == null and !if_exists) return error.TableNotFound;
    return .{ .name = name, .if_exists = if_exists, .object = if (basis) |schema| schema.object else null, .schema = if (basis) |schema| try schema.fingerprint() else null };
}

test {
    _ = @import("table_ddl_test.zig");
}
