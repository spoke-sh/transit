//! Dedicated point-keyed KV workload grammar (PUT, GET, DELETE ... KEY/KEYS).
//! Preparation performs no catalog lookup, authorization or durable admission.
const std = @import("std");
const f = @import("root.zig");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Atom = f.Types.Values.Atom;
const Cell = f.Types.Values.Cell;
const Spec = f.KVDdl.Spec;

pub const max_changes: usize = 1024;
pub const max_key_bytes: usize = 1024;

pub const Kind = enum { put, get, delete };
pub const Expectation = enum { any, absent, present };
pub const Target = struct {
    kind: Kind,
    source: Reference,
    pub fn deinit(self: Target, allocator: std.mem.Allocator) void {
        allocator.free(self.source.name);
    }
};

/// Recognizes PUT INTO, GET FROM, and DELETE FROM <name> KEY/KEYS.
/// Returns null if the statement is not a KV workload statement (for example,
/// relational DELETE FROM <table> WHERE ...).
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !?Target {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    if (try parser.takeWord("PUT")) {
        try parser.requireWord("INTO");
        return .{ .kind = .put, .source = try Reference.unqualified(&parser, .source) };
    }
    if (try parser.takeWord("GET")) {
        try parser.requireWord("FROM");
        return .{ .kind = .get, .source = try Reference.unqualified(&parser, .source) };
    }
    if (try parser.takeWord("DELETE")) {
        if (!try parser.takeWord("FROM")) return null;
        if (parser.token.tag != .word and parser.token.tag != .quoted) return null;
        const source = try Reference.unqualified(&parser, .source);
        if (parser.word("KEY") or parser.word("KEYS")) return .{ .kind = .delete, .source = source };
        allocator.free(source.name);
        return null;
    }
    return null;
}

pub fn isDelete(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect) !bool {
    if (try target(allocator, text, dialect, null)) |selected| {
        defer selected.deinit(allocator);
        return selected.kind == .delete;
    }
    return false;
}

fn addParameter(allocator: std.mem.Allocator, parameters: *std.ArrayList(f.TableDmlPrepared.Parameter), site: f.Sql.Parameter, kind: f.Types.Type) !void {
    for (parameters.items) |existing| if (existing.site.index == site.index) {
        if (!try existing.type.eql(kind)) return error.ParameterTypeConflict;
        return;
    };
    if (parameters.items.len == 64) return error.InvalidParameterIndex;
    try parameters.append(allocator, .{ .site = site, .type = kind });
}

fn finalizeParameterTypes(allocator: std.mem.Allocator, parameters: []const f.TableDmlPrepared.Parameter) ![]const f.Types.Type {
    var max_index: u32 = 0;
    for (parameters) |param| max_index = @max(max_index, param.site.index);
    const types = try allocator.alloc(f.Types.Type, max_index);
    errdefer allocator.free(types);
    for (0..max_index) |i| {
        const index: u32 = @intCast(i + 1);
        types[i] = for (parameters) |param| {
            if (param.site.index == index) break param.type;
        } else return error.ParameterGap;
    }
    return types;
}

pub const KeyOperand = struct {
    value: union(enum) { literal: []const u8, parameter: f.Sql.Parameter },

    fn parse(parser: *Parser, parameters: *std.ArrayList(f.TableDmlPrepared.Parameter)) !KeyOperand {
        if (try parser.parameter()) |site| {
            try addParameter(parser.allocator, parameters, site, .utf8);
            return .{ .value = .{ .parameter = site } };
        }
        const literal = try parser.literal(.utf8);
        if (literal.value == .null) return error.NullKVKey;
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, .utf8, &failure) catch |err| {
            if (parser.location) |location| location.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) return error.InvalidKVKey;
        const bytes = cell.value.atom.bytes;
        if (bytes.len == 0 or bytes.len > max_key_bytes) return error.InvalidKVKey;
        return .{ .value = .{ .literal = bytes } };
    }

    pub fn bind(self: KeyOperand, allocator: std.mem.Allocator, values: []const ?Atom) ![]u8 {
        const raw: []const u8 = switch (self.value) {
            .literal => |bytes| bytes,
            .parameter => |site| blk: {
                if (site.index == 0 or site.index > values.len) return error.ParameterCountMismatch;
                const atom = values[site.index - 1] orelse return error.NullKVKey;
                try f.LogicalPrepared.validate(atom, .utf8);
                break :blk atom.bytes;
            },
        };
        if (raw.len == 0 or raw.len > max_key_bytes) return error.InvalidKVKey;
        return allocator.dupe(u8, raw);
    }
};

pub const ValueOperand = struct {
    value: union(enum) { literal: Cell, parameter: f.Sql.Parameter },

    fn parse(parser: *Parser, spec: Spec, parameters: *std.ArrayList(f.TableDmlPrepared.Parameter)) !ValueOperand {
        const kind = spec.typeOf();
        if (try parser.parameter()) |site| {
            try addParameter(parser.allocator, parameters, site, kind);
            return .{ .value = .{ .parameter = site } };
        }
        const literal = try parser.literal(kind);
        if (literal.value == .null) {
            if (!spec.nullable) return error.NullConstraintViolation;
            return .{ .value = .{ .literal = .null } };
        }
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, kind, &failure) catch |err| {
            if (parser.location) |location| location.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        try cell.validate(.{ .name = "value", .type = kind, .nullable = spec.nullable }, .{});
        return .{ .value = .{ .literal = cell } };
    }

    pub fn bind(self: ValueOperand, allocator: std.mem.Allocator, spec: Spec, values: []const ?Atom) !Cell {
        return switch (self.value) {
            .literal => |cell| f.Types.Values.cloneValidated(allocator, cell),
            .parameter => |site| {
                if (site.index == 0 or site.index > values.len) return error.ParameterCountMismatch;
                const atom = values[site.index - 1] orelse {
                    if (!spec.nullable) return error.NullConstraintViolation;
                    return .null;
                };
                try f.LogicalPrepared.validate(atom, spec.typeOf());
                return f.Types.Values.cloneValidated(allocator, .{ .value = .{ .atom = atom } });
            },
        };
    }
};

pub const Entry = union(enum) {
    put: struct { key: KeyOperand, value: ValueOperand, expect: Expectation },
    remove: KeyOperand,
};

pub const BoundChange = union(enum) {
    put: struct { key: []const u8, value: Cell, expect: Expectation },
    remove: []const u8,
};

pub const BoundWrite = struct {
    arena: std.heap.ArenaAllocator,
    changes: []const BoundChange,

    pub fn deinit(self: *BoundWrite) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const PreparedWrite = struct {
    arena: std.heap.ArenaAllocator,
    target: Target,
    spec: Spec,
    entries: []const Entry,
    parameter_types: []const f.Types.Type,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, input_spec: Spec, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !PreparedWrite {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        const spec = try input_spec.cloneInto(a);
        var parser = try Parser.initDialect(a, try a.dupe(u8, text), location, true, dialect);
        var entries: std.ArrayList(Entry) = .empty;
        var parameters: std.ArrayList(f.TableDmlPrepared.Parameter) = .empty;
        if (try parser.takeWord("PUT")) {
            try parser.requireWord("INTO");
            const source = try Reference.unqualified(&parser, .source);
            if (try parser.takeWord("KEY")) {
                const key = try KeyOperand.parse(&parser, &parameters);
                try parser.requireWord("VALUE");
                const val = try ValueOperand.parse(&parser, spec, &parameters);
                const expect = try parseExpectation(&parser);
                try parser.finish();
                try entries.append(a, .{ .put = .{ .key = key, .value = val, .expect = expect } });
            } else if (try parser.takeWord("VALUES")) {
                while (true) {
                    if (entries.items.len == max_changes) return error.KVBatchTooLarge;
                    try parser.require(.left);
                    const key = try KeyOperand.parse(&parser, &parameters);
                    try parser.require(.comma);
                    const val = try ValueOperand.parse(&parser, spec, &parameters);
                    try parser.require(.right);
                    try entries.append(a, .{ .put = .{ .key = key, .value = val, .expect = .any } });
                    if (!try parser.take(.comma)) break;
                }
                const expect = try parseExpectation(&parser);
                try parser.finish();
                for (entries.items) |*item| item.put.expect = expect;
            } else return error.InvalidSqlSyntax;
            try rejectLiteralDuplicates(entries.items);
            const param_types = try finalizeParameterTypes(a, parameters.items);
            return .{ .arena = arena, .target = .{ .kind = .put, .source = source }, .spec = spec, .entries = try entries.toOwnedSlice(a), .parameter_types = param_types };
        }
        if (try parser.takeWord("DELETE")) {
            try parser.requireWord("FROM");
            const source = try Reference.unqualified(&parser, .source);
            if (try parser.takeWord("KEY")) {
                const key = try KeyOperand.parse(&parser, &parameters);
                try parser.finish();
                try entries.append(a, .{ .remove = key });
            } else if (try parser.takeWord("KEYS")) {
                try parser.require(.left);
                while (true) {
                    if (entries.items.len == max_changes) return error.KVBatchTooLarge;
                    const key = try KeyOperand.parse(&parser, &parameters);
                    try entries.append(a, .{ .remove = key });
                    if (!try parser.take(.comma)) break;
                }
                try parser.require(.right);
                try parser.finish();
            } else return error.InvalidSqlSyntax;
            try rejectLiteralDuplicates(entries.items);
            const param_types = try finalizeParameterTypes(a, parameters.items);
            return .{ .arena = arena, .target = .{ .kind = .delete, .source = source }, .spec = spec, .entries = try entries.toOwnedSlice(a), .parameter_types = param_types };
        }
        return error.UnsupportedStatement;
    }

    pub fn deinit(self: *PreparedWrite) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn parameterTypes(self: *const PreparedWrite) []const f.Types.Type {
        return self.parameter_types;
    }

    pub fn bind(self: *const PreparedWrite, allocator: std.mem.Allocator, values: []const ?Atom) !BoundWrite {
        if (values.len != self.parameter_types.len) return error.ParameterCountMismatch;
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        const changes = try a.alloc(BoundChange, self.entries.len);
        for (self.entries, changes, 0..) |entry, *out, i| {
            out.* = switch (entry) {
                .put => |put| .{ .put = .{ .key = try put.key.bind(a, values), .value = try put.value.bind(a, self.spec, values), .expect = put.expect } },
                .remove => |key| .{ .remove = try key.bind(a, values) },
            };
            const current_key = switch (out.*) {
                .put => |put| put.key,
                .remove => |key| key,
            };
            for (changes[0..i]) |earlier| {
                const earlier_key = switch (earlier) {
                    .put => |put| put.key,
                    .remove => |key| key,
                };
                if (std.mem.eql(u8, earlier_key, current_key)) return error.DuplicateKVKey;
            }
        }
        return .{ .arena = arena, .changes = changes };
    }
};

fn parseExpectation(parser: *Parser) !Expectation {
    if (!try parser.takeWord("IF")) return .any;
    if (try parser.takeWord("ABSENT")) return .absent;
    if (try parser.takeWord("PRESENT")) return .present;
    return error.InvalidSqlSyntax;
}

fn rejectLiteralDuplicates(entries: []const Entry) !void {
    for (entries, 0..) |entry, i| {
        const key_op = switch (entry) {
            .put => |put| put.key,
            .remove => |key| key,
        };
        if (key_op.value != .literal) continue;
        for (entries[0..i]) |earlier| {
            const earlier_op = switch (earlier) {
                .put => |put| put.key,
                .remove => |key| key,
            };
            if (earlier_op.value == .literal and std.mem.eql(u8, earlier_op.value.literal, key_op.value.literal)) return error.DuplicateKVKey;
        }
    }
}

pub const PreparedGet = struct {
    arena: std.heap.ArenaAllocator,
    target: Target,
    spec: Spec,
    key: KeyOperand,
    parameter_types: []const f.Types.Type,
    output: f.Types.Decoded,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, input_spec: Spec, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !PreparedGet {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        const spec = try input_spec.cloneInto(a);
        var parser = try Parser.initDialect(a, try a.dupe(u8, text), location, true, dialect);
        try parser.requireWord("GET");
        try parser.requireWord("FROM");
        const source = try Reference.unqualified(&parser, .source);
        try parser.requireWord("KEY");
        var parameters: std.ArrayList(f.TableDmlPrepared.Parameter) = .empty;
        const key = try KeyOperand.parse(&parser, &parameters);
        try parser.finish();
        const param_types = try finalizeParameterTypes(a, parameters.items);
        const fields = [_]f.Types.Field{
            .{ .name = "key", .type = .utf8, .nullable = false },
            .{ .name = "value", .type = spec.typeOf(), .nullable = spec.nullable },
        };
        const output = try (f.Types.Type{ .structure = &fields }).clone(allocator);
        return .{ .arena = arena, .target = .{ .kind = .get, .source = source }, .spec = spec, .key = key, .parameter_types = param_types, .output = output };
    }

    pub fn deinit(self: *PreparedGet) void {
        self.output.deinit();
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn parameterTypes(self: *const PreparedGet) []const f.Types.Type {
        return self.parameter_types;
    }

    pub fn bind(self: *const PreparedGet, allocator: std.mem.Allocator, values: []const ?Atom) ![]u8 {
        if (values.len != self.parameter_types.len) return error.ParameterCountMismatch;
        return self.key.bind(allocator, values);
    }
};

test "KV ROW workload literals retain logical field constraints" {
    var declaration = try f.KVDdl.compile(std.testing.allocator, "CREATE KV sessions (ROW (identity VARCHAR(1), revoked BOOLEAN NOT NULL))", .transit, null);
    defer declaration.deinit();
    const spec = declaration.statement.action.create.spec;
    var prepared = try PreparedWrite.init(std.testing.allocator, "PUT INTO sessions KEY 'key' VALUE ROW('é', FALSE) IF ABSENT", spec, .transit, null);
    defer prepared.deinit();
    var bound = try prepared.bind(std.testing.allocator, &.{});
    defer bound.deinit();
    try std.testing.expectEqual(.absent, bound.changes[0].put.expect);
    try std.testing.expectEqualStrings("é", bound.changes[0].put.value.value.structure[0].value.atom.bytes);
    try std.testing.expectError(error.CharacterLimitExceeded, PreparedWrite.init(std.testing.allocator, "PUT INTO sessions KEY 'key' VALUE ROW('éé', FALSE)", spec, .transit, null));
    try std.testing.expectError(error.NullNotAllowed, PreparedWrite.init(std.testing.allocator, "PUT INTO sessions KEY 'key' VALUE ROW('é', NULL)", spec, .transit, null));
}

test "KV workload SQL compiles PUT GET and DELETE with conditional expectations and parameters" {
    const t = std.testing;
    const spec: Spec = .{ .value_type = .utf8, .nullable = false };
    try t.expect(!try isDelete(t.allocator, "DELETE FROM items WHERE id = 1", .transit));
    try t.expect(try isDelete(t.allocator, "DELETE FROM cache KEY 'k1'", .transit));

    var put_single = try PreparedWrite.init(t.allocator, "PUT INTO cache KEY $1 VALUE $2 IF ABSENT", spec, .transit, null);
    defer put_single.deinit();
    try t.expectEqual(@as(usize, 2), put_single.parameterTypes().len);
    var bound_single = try put_single.bind(t.allocator, &.{ .{ .bytes = "user:1" }, .{ .bytes = "active" } });
    defer bound_single.deinit();
    try t.expectEqual(@as(usize, 1), bound_single.changes.len);
    try t.expectEqual(Expectation.absent, bound_single.changes[0].put.expect);
    try t.expectEqualStrings("user:1", bound_single.changes[0].put.key);
    try t.expectEqualStrings("active", bound_single.changes[0].put.value.value.atom.bytes);

    var put_batch = try PreparedWrite.init(t.allocator, "PUT INTO cache VALUES ('k1', 'v1'), ('k2', 'v2') IF PRESENT", spec, .transit, null);
    defer put_batch.deinit();
    var bound_batch = try put_batch.bind(t.allocator, &.{});
    defer bound_batch.deinit();
    try t.expectEqual(@as(usize, 2), bound_batch.changes.len);
    try t.expectEqual(Expectation.present, bound_batch.changes[1].put.expect);

    var del_keys = try PreparedWrite.init(t.allocator, "DELETE FROM cache KEYS ('k1', $1)", spec, .transit, null);
    defer del_keys.deinit();
    var bound_del = try del_keys.bind(t.allocator, &.{.{ .bytes = "k2" }});
    defer bound_del.deinit();
    try t.expectEqual(@as(usize, 2), bound_del.changes.len);
    try t.expectError(error.DuplicateKVKey, del_keys.bind(t.allocator, &.{.{ .bytes = "k1" }}));

    var get_stmt = try PreparedGet.init(t.allocator, "GET FROM cache KEY $1", spec, .transit, null);
    defer get_stmt.deinit();
    const key = try get_stmt.bind(t.allocator, &.{.{ .bytes = "user:1" }});
    defer t.allocator.free(key);
    try t.expectEqualStrings("user:1", key);
    try t.expectEqual(@as(usize, 2), get_stmt.output.type.structure.len);
}
