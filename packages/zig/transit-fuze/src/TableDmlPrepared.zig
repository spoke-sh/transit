//! Immutable schema-bound DML templates. Typed operands enter the shared DML
//! binder; the returned canonical intent owns bytes and never contains SQL.
const std = @import("std");
const f = @import("root.zig");
const t = f.Types;
const sql = f.Sql;
const dml = f.TableDml;
const Self = @This();
pub const max_parameters = 256;
arena: std.heap.ArenaAllocator,
schema: f.TableSchema.Owned,
name: []const u8,
syntax: dml.Syntax,
types: [max_parameters]t.Type = undefined,
sites: [max_parameters]?sql.Parameter = @splat(null),
count: u16 = 0,

pub fn init(allocator: std.mem.Allocator, text: []const u8, name: []const u8, schema: f.TableSchema.Schema, dialect: sql.Dialect, location: ?*sql.Location) !Self {
    try sql.validateText(text);
    var owned_schema = try schema.clone(allocator);
    errdefer owned_schema.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try f.SqlTyped.initDialect(a, try a.dupe(u8, text), location, true, dialect);
    const syntax = try dml.syntax(&parser, owned_schema.schema);
    try parser.finish();
    var result: Self = .{ .arena = arena, .schema = owned_schema, .name = try a.dupe(u8, name), .syntax = syntax };
    try result.infer(location);
    for (result.sites[0..result.count]) |site| if (site == null) return error.ParameterGap;
    var witnesses: [max_parameters]?t.Values.Atom = undefined;
    for (result.parameterTypes(), witnesses[0..result.count]) |kind, *value| value.* = try f.LogicalPrepared.witness(kind);
    const plan = try syntax.bindParameters(a, result.name, owned_schema.schema, location, witnesses[0..result.count]);
    _ = try plan.fingerprint(allocator);
    result.arena = arena;
    return result;
}
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.schema.deinit();
    self.* = undefined;
}
pub fn parameterTypes(self: *const Self) []const t.Type {
    return self.types[0..self.count];
}
fn register(self: *Self, site: sql.Parameter, kind: t.Type, location: ?*sql.Location) !void {
    if (location) |at| at.* = .{ .offset = site.offset };
    if (site.index == 0) return error.InvalidParameterIndex;
    if (site.index > max_parameters) return error.ParameterGap;
    const index = site.index - 1;
    if (self.sites[index] != null and !try self.types[index].eql(kind)) return error.ParameterTypeConflict;
    self.sites[index] = self.sites[index] orelse site;
    self.types[index] = kind;
    self.count = @max(self.count, @as(u16, @intCast(site.index)));
}
fn infer(self: *Self, location: ?*sql.Location) !void {
    const schema = self.schema.schema;
    switch (self.syntax.action) {
        .insert => |input| {
            const count = if (input.columns) |columns| columns.len else schema.columns.len;
            for (input.rows) |row| {
                if (row.values.len != count) return error.InvalidRowWidth;
                for (row.values, 0..) |value, ordinal| if (value.parameter) |site| {
                    const index = if (input.columns) |columns| try columns[ordinal].resolve(self.name, schema.columns, location) else ordinal;
                    try self.register(site, schema.columns[index].type, location);
                };
            }
        },
        .update => |assignments| for (assignments) |assignment| {
            if (assignment.value.parameter) |site| {
                const index = try assignment.column.resolve(self.name, schema.columns, location);
                try self.register(site, schema.columns[index].type, location);
            }
        },
        .delete => {},
    }
    if (self.syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
        if (instruction != .atom or instruction.atom != .compare) continue;
        const compare = instruction.atom.compare;
        if (compare.value != .parameter) continue;
        const index = try compare.column.resolve(self.name, schema.columns, location);
        try self.register(compare.value.parameter, schema.columns[index].type, location);
    };
}
/// New execution only. The caller separately checks catalog metadata/current
/// rights before turning the bound plan into an immutable TableIntent.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, name: []const u8, schema: f.TableSchema.Schema, values: []const ?t.Values.Atom, location: ?*sql.Location) !dml.Owned {
    if (!std.mem.eql(u8, name, self.name) or !std.mem.eql(u8, &try schema.fingerprint(), &try self.schema.schema.fingerprint())) return error.TableSchemaChanged;
    if (values.len != self.count) return error.ParameterCountMismatch;
    for (values, self.parameterTypes(), self.sites[0..self.count]) |value, kind, site| {
        if (location) |at| at.* = .{ .offset = site.?.offset };
        if (value) |atom| try f.LogicalPrepared.validate(atom, kind);
    }
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const plan = try self.syntax.bindParameters(arena.allocator(), self.name, self.schema.schema, location, values);
    // Encoding is bounded by the existing typed intent limit. Decoding into a
    // distinct owner prevents either the template or borrowed parameters escaping.
    const bytes = try allocator.alloc(u8, f.TableDmlCodec.max_bytes);
    defer allocator.free(bytes);
    return f.TableDmlCodec.decode(allocator, schema, try f.TableDmlCodec.encode(allocator, plan, bytes));
}

test {
    _ = @import("table_parameters_test.zig");
}
