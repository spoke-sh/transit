//! Owned Document collection DDL compilation and inspection syntax.
//! Catalog binding, authorization, staging and execution are separate.
const std = @import("std");
const p = @import("transit_protocol");
const sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const TableDdl = @import("TableDdl.zig");
const Schema = @import("TableSchema.zig");
const PerfectHash = @import("PerfectHash.zig");

pub const Profile = p.DocumentDeclaration.Profile;

pub const Policy = struct {
    profile: Profile = .versioned,
    retention_max_age_ms: ?u64 = null,
    pub fn validate(self: Policy) !void {
        if (self.retention_max_age_ms) |ms| {
            if (ms < 1000 or ms > 315576000000) return error.InvalidDocumentRetention;
        }
    }
};

pub const Basis = struct {
    schema: Schema.Schema,
    policy: Policy = .{},
};

pub const Create = struct {
    table: TableDdl.Create,
    policy: Policy = .{},
    pub fn bind(self: Create, object: u64) !Schema.Schema {
        return self.table.bind(object);
    }
};

pub const Alter = struct {
    table: TableDdl.Alter,
    policy: Policy,
};

pub const Drop = TableDdl.Drop;

pub const Statement = union(enum) {
    create: Create,
    alter: Alter,
    drop: Drop,
};

pub const Target = struct {
    kind: std.meta.Tag(Statement),
    name: []const u8,
};

pub fn target(allocator: std.mem.Allocator, text: []const u8) !Target {
    return targetDialect(allocator, text, null, .transit);
}

pub fn targetDialect(allocator: std.mem.Allocator, text: []const u8, location: ?*sql.Location, dialect: sql.Dialect) !Target {
    var parser = try Parser.initDialect(allocator, text, location, false, dialect);
    const kind: std.meta.Tag(Statement) = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    try parser.requireWord("DOCUMENT");
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

pub const Inspection = struct {
    name: []const u8,
    describe: bool,
};

pub fn inspection(parser: Parser) !?Inspection {
    var header = parser;
    const show = try header.takeWord("SHOW");
    const describe = if (!show) try header.takeWord("DESCRIBE") else false;
    if (!show and !describe) return null;
    if (!try header.takeWord("DOCUMENT")) return null;
    if (header.token.tag == .eof or header.token.tag == .semi) return null;
    const name = try header.named(.source);
    try header.finish();
    return .{ .name = name, .describe = describe };
}

const OptionTag = enum { profile, retention };
const Options = PerfectHash.ComptimeMap(OptionTag, true, .{
    .{ "profile", .profile },
    .{ "retention", .retention },
});
const Option = struct { tag: OptionTag, value: Parser.Literal };

const default_columns = [_]Schema.Column{
    .{ .id = 1, .name = "id", .type = .utf8, .nullable = false },
    .{ .id = 2, .name = "doc", .type = .utf8, .nullable = false },
};
const default_primary_key = [_]Schema.ColumnId{1};

pub fn compile(allocator: std.mem.Allocator, text: []const u8, basis: ?Basis, location: ?*sql.Location) !Owned {
    return compileDialect(allocator, text, basis, location, .transit);
}

pub fn compileDialect(allocator: std.mem.Allocator, text: []const u8, basis: ?Basis, location: ?*sql.Location, dialect: sql.Dialect) !Owned {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try Parser.initDialect(a, text, location, false, dialect);
    const kind: std.meta.Tag(Statement) = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    try parser.requireWord("DOCUMENT");
    const statement: Statement = switch (kind) {
        .create => blk: {
            const if_not_exists = try parser.takeWord("IF");
            if (if_not_exists) {
                try parser.requireWord("NOT");
                try parser.requireWord("EXISTS");
            }
            const name = try parser.named(.proposed);
            const table: TableDdl.Create = if (parser.token.tag == .left)
                try TableDdl.columnDefinitions(&parser, name, if_not_exists)
            else
                .{
                    .name = name,
                    .if_not_exists = if_not_exists,
                    .columns = &default_columns,
                    .primary_key = &default_primary_key,
                };
            if (table.foreign_keys.len != 0) return error.UnsupportedTableConstraint;
            _ = try table.bind(1);
            var policy: Policy = .{};
            if (try parser.takeWord("WITH")) {
                policy = try bindOptions(null, try parseOptions(&parser));
            }
            break :blk .{ .create = .{ .table = table, .policy = policy } };
        },
        .alter => blk: {
            const name = try parser.named(.source);
            const current = basis orelse return error.DocumentNotFound;
            if (try parser.takeWord("SET")) {
                const policy = try bindOptions(current.policy, try parseOptions(&parser));
                const copied = try current.schema.clone(a);
                break :blk .{
                    .alter = .{
                        .table = .{
                            .name = name,
                            .object = current.schema.object,
                            .schema = try current.schema.fingerprint(),
                            .action = .{ .columns = .{ .integrity = copied.schema } },
                        },
                        .policy = policy,
                    },
                };
            }
            const syntax = try TableDdl.alterBody(&parser, name, current.schema);
            const bound = try syntax.bind(a, current.schema, location, null);
            break :blk .{
                .alter = .{
                    .table = bound,
                    .policy = current.policy,
                },
            };
        },
        .drop => blk: {
            const if_exists = try parser.takeWord("IF");
            if (if_exists) try parser.requireWord("EXISTS");
            const name = try parser.named(.source);
            if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
            _ = try parser.takeWord("RESTRICT");
            if (basis == null and !if_exists) return error.DocumentNotFound;
            break :blk .{
                .drop = .{
                    .name = name,
                    .if_exists = if_exists,
                    .object = if (basis) |value| value.schema.object else null,
                    .schema = if (basis) |value| try value.schema.fingerprint() else null,
                },
            };
        },
    };
    try parser.finish();
    return .{ .arena = arena, .statement = statement };
}

fn parseOptions(parser: *Parser) ![]const Option {
    try parser.require(.left);
    var seen: std.EnumSet(OptionTag) = .empty;
    var values: std.ArrayList(Option) = .empty;
    while (true) {
        if (parser.token.tag != .word) return error.InvalidDocumentOption;
        const tag = Options.get(parser.token.text) orelse return error.UnsupportedDocumentOption;
        if (seen.contains(tag)) return error.DuplicateDocumentOption;
        seen.insert(tag);
        try parser.advance();
        try parser.require(.eq);
        try values.append(parser.allocator, .{ .tag = tag, .value = try parser.literal(null) });
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    return values.toOwnedSlice(parser.allocator);
}

fn bindOptions(basis: ?Policy, parsed: []const Option) !Policy {
    var result: Policy = basis orelse .{};
    for (parsed) |option| {
        const value = option.value;
        switch (option.tag) {
            .profile => {
                const text = try stringOption(value);
                const selected: Profile = if (std.ascii.eqlIgnoreCase(text, "versioned"))
                    .versioned
                else if (std.ascii.eqlIgnoreCase(text, "causal_crdt"))
                    .causal_crdt
                else
                    return error.InvalidDocumentOption;
                if (basis) |existing| if (existing.profile != selected) return error.InvalidDocumentPolicyEvolution;
                result.profile = selected;
            },
            .retention => {
                result.retention_max_age_ms = if (value.value == .null or (value.value == .string and std.ascii.eqlIgnoreCase(value.value.string, "unlimited")))
                    null
                else
                    try durationOption(try stringOption(value));
            },
        }
    }
    return result;
}

fn stringOption(value: Parser.Literal) ![]const u8 {
    if (value.value != .string or value.value.string.len == 0) return error.InvalidDocumentOption;
    return value.value.string;
}

fn durationOption(text: []const u8) !u64 {
    var end: usize = 0;
    while (end < text.len and std.ascii.isDigit(text[end])) : (end += 1) {}
    const unit = PerfectHash.ComptimeMap(u64, true, .{
        .{ "ms", 1 },
        .{ "s", 1000 },
        .{ "m", 60000 },
        .{ "h", 3600000 },
        .{ "d", 86400000 },
    }).get(text[end..]) orelse return error.InvalidDocumentOption;
    const n = std.fmt.parseInt(u64, text[0..end], 10) catch return error.InvalidDocumentOption;
    if (n == 0) return error.InvalidDocumentOption;
    return std.math.mul(u64, n, unit) catch error.InvalidDocumentOption;
}

test "Document DDL compiles default and custom column schemas and policy options" {
    const t = std.testing;
    var default_plan = try compile(t.allocator, "CREATE DOCUMENT IF NOT EXISTS docs WITH (profile = 'causal_crdt', retention = '7d')", null, null);
    defer default_plan.deinit();
    const default_schema = try default_plan.statement.create.bind(42);
    try t.expect(default_plan.statement.create.table.if_not_exists);
    try t.expectEqualStrings("docs", default_plan.statement.create.table.name);
    try t.expectEqual(@as(usize, 2), default_schema.columns.len);
    try t.expectEqualStrings("id", default_schema.columns[0].name);
    try t.expectEqualStrings("doc", default_schema.columns[1].name);
    try t.expectEqual(Profile.causal_crdt, default_plan.statement.create.policy.profile);
    try t.expectEqual(@as(?u64, 604800000), default_plan.statement.create.policy.retention_max_age_ms);

    var custom_plan = try compile(t.allocator, "CREATE DOCUMENT articles (id BIGINT PRIMARY KEY, title TEXT NOT NULL, body TEXT)", null, null);
    defer custom_plan.deinit();
    const custom_schema = try custom_plan.statement.create.bind(43);
    try t.expectEqual(@as(usize, 3), custom_schema.columns.len);
    try t.expectEqual(Profile.versioned, custom_plan.statement.create.policy.profile);
    try t.expectEqual(@as(?u64, null), custom_plan.statement.create.policy.retention_max_age_ms);

    var alter_policy = try compile(t.allocator, "ALTER DOCUMENT articles SET (retention = '24h')", .{ .schema = custom_schema, .policy = custom_plan.statement.create.policy }, null);
    defer alter_policy.deinit();
    try t.expectEqual(@as(?u64, 86400000), alter_policy.statement.alter.policy.retention_max_age_ms);

    var alter_col = try compile(t.allocator, "ALTER DOCUMENT articles ADD COLUMN tags TEXT", .{ .schema = custom_schema, .policy = custom_plan.statement.create.policy }, null);
    defer alter_col.deinit();
    try t.expect(alter_col.statement.alter.table.action == .columns);

    var drop_plan = try compile(t.allocator, "DROP DOCUMENT IF EXISTS articles", null, null);
    defer drop_plan.deinit();
    try t.expect(drop_plan.statement.drop.if_exists);
    try t.expect(drop_plan.statement.drop.object == null);
}

test "Document inspection preserves contextual Table names" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    for ([_][]const u8{ "DESCRIBE document", "DESCRIBE document;", "SHOW DOCUMENTS", "SELECT id FROM docs" }) |text| {
        const parser = try Parser.init(arena.allocator(), text, null);
        try t.expect(try inspection(parser) == null);
    }
    const show = (try inspection(try Parser.init(arena.allocator(), "SHOW DOCUMENT docs", null))).?;
    try t.expect(!show.describe);
    try t.expectEqualStrings("docs", show.name);

    const desc = (try inspection(try Parser.init(arena.allocator(), "DESCRIBE DOCUMENT docs", null))).?;
    try t.expect(desc.describe);
    try t.expectEqualStrings("docs", desc.name);
}
