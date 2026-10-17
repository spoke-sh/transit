//! SQL classification and metadata lowering shared by console and wire adapters.
//! Administrative calls are accepted only as complete standalone statements.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const C = q.settings.Contract;
const R = q.settings.Registry;
const Parser = f.SqlTyped;
pub const Catalog = enum { databases, schemas, tables };
pub const Relation = enum { settings, reloads };
pub const Statement = union(enum) {
    show: ?[]const u8,
    relation: Relation,
    reload,
    catalog: Catalog,
    set: struct { name: []const u8, value: ?u64 },
    reset: ?[]const u8,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    query: ?f.TableSelect.Owned = null,
    order: ?struct { column: usize, descending: bool } = null,
    pub fn deinit(self: *Owned) void {
        if (self.query) |*query| query.deinit();
        self.arena.deinit();
        self.* = undefined;
    }
    pub fn fields(self: *const Owned) []const f.Types.Field {
        if (self.query) |query| return query.plan.schema.structure; // output() owns projected descriptor
        return switch (self.statement) {
            .show => |name| if (name != null) &.{.{ .name = "value", .type = .utf8, .nullable = true }} else &.{ .{ .name = "name", .type = .utf8 }, .{ .name = "value", .type = .utf8, .nullable = true }, .{ .name = "description", .type = .utf8 } },
            .reload => &.{.{ .name = "transit_reload_conf", .type = .utf8 }},
            .catalog => |kind| switch (kind) {
                .databases => &.{.{ .name = "database", .type = .utf8 }},
                .schemas => &.{.{ .name = "schema", .type = .utf8 }},
                .tables => &.{.{ .name = "table", .type = .utf8 }},
            },
            .set, .reset => &.{},
            .relation => unreachable,
        };
    }
    pub fn output(self: *const Owned, a: std.mem.Allocator) !f.Types.Decoded {
        if (self.query) |query| {
            var columns: [f.TableSchema.max_columns]f.Types.Field = undefined;
            return (try query.plan.outputSchema(&columns)).clone(a);
        }
        return (f.Types.Type{ .structure = self.fields() }).clone(a);
    }
};
pub fn fields(comptime T: type) []const f.Types.Field {
    const meta = @typeInfo(T).@"struct";
    const result = comptime blk: {
        var result: [meta.field_names.len]f.Types.Field = undefined;
        for (meta.field_names, meta.field_types, 0..) |name, Field, i| {
            const nullable = @typeInfo(Field) == .optional;
            const Type = if (nullable) @typeInfo(Field).optional.child else Field;
            result[i] = .{ .name = name, .nullable = nullable, .type = if (Type == bool) .boolean else if (Type == u64) .uint64 else .utf8 };
        }
        break :blk result;
    };
    return &result;
}
pub fn cells(a: std.mem.Allocator, value: anytype) ![]const f.Types.Values.Cell {
    const T = @TypeOf(value);
    const meta = @typeInfo(T).@"struct";
    const result = try a.alloc(f.Types.Values.Cell, meta.field_names.len);
    inline for (meta.field_names, 0..) |name, i| result[i] = try cell(a, @field(value, name));
    return result;
}
fn cell(a: std.mem.Allocator, value: anytype) !f.Types.Values.Cell {
    const T = @TypeOf(value);
    if (@typeInfo(T) == .optional) return if (value) |present| cell(a, present) else .null;
    const atom: f.Types.Values.Atom = if (T == bool) .{ .boolean = value } else if (T == u64) .{ .unsigned = value } else .{ .bytes = if (@typeInfo(T) == .@"enum") @tagName(value) else if (T == []const u8) value else try q.protocol.Json.valueAlloc(a, value) };
    return .{ .value = .{ .atom = atom } };
}
pub fn parse(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect) !?Owned {
    var owned: Owned = .{ .arena = .init(allocator), .statement = undefined };
    errdefer owned.deinit();
    const a = owned.arena.allocator();
    var parser = try Parser.initDialect(a, text, null, false, dialect);
    if (try parser.takeWord("SHOW")) {
        if (try parser.takeWord("ALL")) owned.statement = .{ .show = null } else {
            inline for (.{ .{ "DATABASES", Catalog.databases }, .{ "SCHEMAS", Catalog.schemas }, .{ "TABLES", Catalog.tables } }) |pair| if (try parser.takeWord(pair[0])) {
                try parser.finish();
                owned.statement = .{ .catalog = pair[1] };
                return owned;
            };
            owned.statement = .{ .show = try key(&parser) };
        }
        try parser.finish();
        return owned;
    }
    if (parser.word("SET") or parser.word("RESET")) {
        const setting = try parser.takeWord("SET");
        if (!setting) try parser.requireWord("RESET");
        // Existing role and wire-compatibility settings retain their owner.
        if (parser.word("ROLE") or parser.word("LOCAL") or parser.word("NAMES") or parser.word("SESSION")) {
            owned.deinit();
            return null;
        }
        if (!setting and try parser.takeWord("ALL")) {
            try parser.finish();
            owned.statement = .{ .reset = null };
            return owned;
        }
        const name = try key(&parser);
        if (std.mem.indexOfScalar(u8, name, '.') == null) {
            owned.deinit();
            return null;
        }
        if (!std.mem.eql(u8, name, "query.statement_timeout")) return error.SettingNotSessionMutable;
        if (!setting) {
            try parser.finish();
            owned.statement = .{ .reset = name };
            return owned;
        }
        if (!try parser.take(.eq)) try parser.requireWord("TO");
        const value: ?u64 = if (try parser.takeWord("DEFAULT")) null else value: {
            const literal = try parser.literal(null);
            break :value switch (literal.value) {
                .string => |raw| try R.quantity(raw, .duration),
                .number => |raw| std.fmt.parseInt(u64, raw, 10) catch return error.InvalidSettingValue,
                else => return error.InvalidSettingValue,
            };
        };
        if (value) |number| if (number > 86400000) return error.SettingOutOfRange;
        try parser.finish();
        owned.statement = .{ .set = .{ .name = name, .value = value } };
        return owned;
    }
    if (!try parser.takeWord("SELECT")) {
        owned.deinit();
        return null;
    }
    if (try parser.takeWord("transit_reload_conf")) {
        try parser.require(.left);
        try parser.require(.right);
        try parser.finish();
        owned.statement = .reload;
        return owned;
    }
    // Only the top-level FROM may identify a metadata relation. Expressions,
    // nested calls and joins do not acquire administrative semantics.
    while (!parser.word("FROM") and parser.token.tag != .eof) {
        if (parser.word("transit_reload_conf")) return error.StandaloneConfigurationOperationRequired;
        try parser.advance();
    }
    if (!try parser.takeWord("FROM")) {
        owned.deinit();
        return null;
    }
    const relation: Relation = if (parser.word("transit_settings")) .settings else if (parser.word("transit_config_reloads")) .reloads else {
        owned.deinit();
        return null;
    };
    const relation_name = if (relation == .settings) "transit_settings" else "transit_config_reloads";
    try parser.advance();
    const start = parser.lexer.start;
    try parser.require(.left);
    try parser.require(.right);
    const end = parser.previous_end;
    const normalized = try a.dupe(u8, text);
    @memset(normalized[start..end], ' ');
    const schema: f.Types.Type = .{ .structure = if (relation == .settings) fields(C.Row) else fields(C.Outcome) };
    while (parser.token.tag != .eof) {
        if (parser.word("ORDER")) {
            const order_start = parser.lexer.start;
            try parser.advance();
            try parser.requireWord("BY");
            const column_name = try parser.name();
            const column = for (schema.structure, 0..) |field, i| {
                if (std.mem.eql(u8, field.name, column_name)) break i;
            } else return error.UnknownColumn;
            const descending = try parser.takeWord("DESC");
            if (!descending) _ = try parser.takeWord("ASC");
            @memset(normalized[order_start..parser.previous_end], ' ');
            owned.order = .{ .column = column, .descending = descending };
            break;
        }
        try parser.advance();
    }
    owned.query = try f.TableSelect.compile(allocator, normalized, relation_name, schema, @splat(0), null);
    if (owned.query.?.plan.aggregate != .rows) return error.UnsupportedAggregate;
    if (owned.order != null and relation == .reloads and (owned.query.?.plan.limit == null or owned.query.?.plan.limit.? > 256)) return error.ConfigurationSortRequiresBoundedLimit;
    owned.statement = .{ .relation = relation };
    return owned;
}
fn key(parser: *Parser) ![]const u8 {
    var buffer: std.Io.Writer.Allocating = .init(parser.allocator);
    defer buffer.deinit();
    try buffer.writer.writeAll(try parser.name());
    while (try parser.take(.dot)) {
        try buffer.writer.writeByte('.');
        try buffer.writer.writeAll(try parser.name());
    }
    const name = try buffer.toOwnedSlice();
    try R.validateName(name);
    return name;
}
test "settings grammar is standalone and metadata lowers through Fuze" {
    const t = std.testing;
    for ([_][]const u8{ "SHOW ALL;", "SHOW query.statement_timeout", "SHOW SCHEMAS", "SET query.statement_timeout = '5s'", "RESET ALL", "SELECT transit_reload_conf()", "SELECT name, value FROM transit_settings() WHERE owner = 'gateway' ORDER BY name LIMIT 4" }) |sql| {
        var plan = (try parse(t.allocator, sql, .transit)).?;
        defer plan.deinit();
    }
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "SELECT transit_reload_conf() FROM items", .transit));
    try t.expectError(error.UnsupportedConstruct, parse(t.allocator, "SELECT transit_reload_conf(); SELECT 1", .transit));
    try t.expectError(error.SettingNotSessionMutable, parse(t.allocator, "SET ports.gateway = 99", .transit));
    try t.expectError(error.ConfigurationSortRequiresBoundedLimit, parse(t.allocator, "SELECT * FROM transit_config_reloads() ORDER BY ordinal", .transit));
}
