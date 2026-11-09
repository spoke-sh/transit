//! Pure KV declaration and inspection syntax. Catalog identities, authorization
//! and admission belong to the caller.
const std = @import("std");
const Sql = @import("Sql.zig");
const Parser = @import("SqlTyped.zig");
const Types = @import("Types.zig");

pub const ValueType = enum(u8) {
    int64 = 1,
    boolean = 2,
    utf8 = 3,
    binary = 4,
    row = 5,

    pub fn typeOf(self: ValueType, fields: []const Types.Field) Types.Type {
        return switch (self) {
            .int64 => .int64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
            .row => .{ .structure = fields },
        };
    }

    pub fn fromLogical(value: Types.Type) !ValueType {
        return switch (value) {
            .int64 => .int64,
            .boolean => .boolean,
            .utf8 => .utf8,
            .binary => .binary,
            .structure => .row,
            else => error.UnsupportedKVValueType,
        };
    }
};

pub const Spec = struct {
    pub const json_schema_sequence_bounds = .{ .fields = 64 };
    value_type: ValueType,
    nullable: bool = false,
    fields: []const Types.Field = &.{},

    pub fn typeOf(self: Spec) Types.Type {
        return self.value_type.typeOf(self.fields);
    }
    pub fn validate(self: Spec) !void {
        if ((self.value_type == .row) != (self.fields.len != 0) or self.fields.len > 64) return error.UnsupportedKVValueType;
        try self.typeOf().validate(.{});
    }
    pub fn cloneInto(self: Spec, allocator: std.mem.Allocator) !Spec {
        try self.validate();
        var result = self;
        if (self.value_type == .row) result.fields = (try self.typeOf().cloneInto(allocator)).structure;
        return result;
    }
};

pub const Statement = struct {
    name: []const u8,
    action: union(enum) {
        create: struct { if_not_exists: bool = false, spec: Spec, native_binding: ?@import("NativeBinding.zig").Kind = null },
        rename: []const u8,
        drop: struct { if_exists: bool = false },
    },
};

pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    statement: Statement,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Inspection = struct { name: []const u8, describe: bool };

/// Pure named-KV inspection syntax. The name belongs to the parser allocator;
/// definition lookup and current disclosure authority remain with the service.
pub fn inspection(parser: Parser) !?Inspection {
    var header = parser;
    const show = try header.takeWord("SHOW");
    const describe = if (!show) try header.takeWord("DESCRIBE") else false;
    if (!show and !describe) return null;
    if (!try header.takeWord("KV")) return null;
    // DESCRIBE kv can still name a Table with that contextual name.
    if (header.token.tag == .eof or header.token.tag == .semi) return null;
    const name = try header.named(.source);
    try header.finish();
    return .{ .name = name, .describe = describe };
}

pub fn compile(allocator: std.mem.Allocator, text: []const u8, dialect: Sql.Dialect, location: ?*Sql.Location) !Owned {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    var parser = try Parser.initDialect(arena.allocator(), text, location, false, dialect);
    const verb: enum { create, alter, drop } = if (try parser.takeWord("CREATE")) .create else if (try parser.takeWord("ALTER")) .alter else if (try parser.takeWord("DROP")) .drop else return error.UnsupportedStatement;
    if (!try parser.takeWord("KV")) return error.UnsupportedStatement;
    switch (verb) {
        .create => {
            const if_not_exists = try parser.takeWord("IF");
            if (if_not_exists) {
                try parser.requireWord("NOT");
                try parser.requireWord("EXISTS");
            }
            const name = try parser.named(.proposed);
            try parser.require(.left);
            const data_type = try parser.dataType();
            if (data_type.max_characters != null) return error.UnsupportedKVValueType;
            const value_type = try ValueType.fromLogical(data_type.type);
            const nullability = try parser.nullability(false);
            if (parser.word("NOT") or parser.word("NULL")) return error.DuplicateColumnConstraint;
            try parser.require(.right);
            const native_binding = try @import("NativeBinding.zig").clause(&parser);
            if (native_binding) |binding| if (!binding.isKV()) return error.InvalidNativeBindingKind;
            try parser.finish();
            const spec: Spec = .{ .value_type = value_type, .nullable = nullability.value, .fields = if (data_type.type == .structure) data_type.type.structure else &.{} };
            try spec.validate();
            return .{ .arena = arena, .statement = .{ .name = name, .action = .{ .create = .{ .if_not_exists = if_not_exists, .spec = spec, .native_binding = native_binding } } } };
        },
        .alter => {
            if (parser.word("IF")) return error.UnsupportedConstruct;
            const name = try parser.named(.source);
            try parser.requireWord("RENAME");
            try parser.requireWord("TO");
            const renamed = try parser.named(.proposed);
            try parser.finish();
            return .{ .arena = arena, .statement = .{ .name = name, .action = .{ .rename = renamed } } };
        },
        .drop => {
            const if_exists = try parser.takeWord("IF");
            if (if_exists) try parser.requireWord("EXISTS");
            const name = try parser.named(.source);
            if (try parser.takeWord("CASCADE")) return error.UnsupportedCascade;
            _ = try parser.takeWord("RESTRICT");
            try parser.finish();
            return .{ .arena = arena, .statement = .{ .name = name, .action = .{ .drop = .{ .if_exists = if_exists } } } };
        },
    }
}

test "KV inspection preserves contextual Table names and dialect quotes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for ([_][]const u8{ "DESCRIBE kv", "DESCRIBE kv;", "SHOW KVS", "SELECT id FROM items" }) |text| {
        const parser = try Parser.init(arena.allocator(), text, null);
        try std.testing.expect(try inspection(parser) == null);
    }
    const parser = try Parser.initDialect(arena.allocator(), "DESCRIBE KV `cache with spaces`", null, false, .mysql);
    const value = (try inspection(parser)).?;
    try std.testing.expect(value.describe);
    try std.testing.expectEqualStrings("cache with spaces", value.name);
    const show = try Parser.init(arena.allocator(), "SHOW KV session_cache", null);
    const show_val = (try inspection(show)).?;
    try std.testing.expect(!show_val.describe);
    try std.testing.expectEqualStrings("session_cache", show_val.name);
}

test "KV DDL compiles CREATE ALTER RENAME and DROP with value type validation" {
    const t = std.testing;
    var create_text = try compile(t.allocator, "CREATE KV session_cache (TEXT NOT NULL)", .transit, null);
    defer create_text.deinit();
    try t.expectEqualStrings("session_cache", create_text.statement.name);
    try t.expect(!create_text.statement.action.create.if_not_exists);
    try t.expectEqual(ValueType.utf8, create_text.statement.action.create.spec.value_type);
    try t.expect(!create_text.statement.action.create.spec.nullable);

    var create_nullable = try compile(t.allocator, "CREATE KV IF NOT EXISTS flags (BOOLEAN NULL)", .transit, null);
    defer create_nullable.deinit();
    try t.expect(create_nullable.statement.action.create.if_not_exists);
    try t.expectEqual(ValueType.boolean, create_nullable.statement.action.create.spec.value_type);
    try t.expect(create_nullable.statement.action.create.spec.nullable);

    var rename = try compile(t.allocator, "ALTER KV flags RENAME TO feature_flags", .transit, null);
    defer rename.deinit();
    try t.expectEqualStrings("feature_flags", rename.statement.action.rename);

    var drop = try compile(t.allocator, "DROP KV IF EXISTS feature_flags RESTRICT", .transit, null);
    defer drop.deinit();
    try t.expect(drop.statement.action.drop.if_exists);

    try t.expectError(error.UnsupportedKVValueType, compile(t.allocator, "CREATE KV bad (JSON)", .transit, null));
    try t.expectError(error.UnsupportedKVValueType, compile(t.allocator, "CREATE KV bad (VARCHAR(16))", .transit, null));
    try t.expectError(error.UnsupportedCascade, compile(t.allocator, "DROP KV flags CASCADE", .transit, null));
}

test "KV ROW declarations own nested logical constraints" {
    var compiled = try compile(std.testing.allocator, "CREATE KV sessions (ROW (identity_id VARCHAR(64), created_at TIMESTAMPTZ NOT NULL, revoked BOOLEAN))", .transit, null);
    defer compiled.deinit();
    const spec = compiled.statement.action.create.spec;
    try std.testing.expectEqual(.row, spec.value_type);
    try std.testing.expectEqual(@as(usize, 3), spec.fields.len);
    try std.testing.expectEqual(@as(?u32, 64), spec.fields[0].max_characters);
    try std.testing.expect(spec.fields[0].nullable);
    try std.testing.expect(!spec.fields[1].nullable);
    var owned = try spec.typeOf().clone(std.testing.allocator);
    defer owned.deinit();
    try std.testing.expect(try owned.type.eql(spec.typeOf()));
    try std.testing.expectError(error.UnsupportedKVValueType, (Spec{ .value_type = .row }).validate());
    try std.testing.expectError(error.UnsupportedKVValueType, (Spec{ .value_type = .binary, .fields = spec.fields }).validate());
}
