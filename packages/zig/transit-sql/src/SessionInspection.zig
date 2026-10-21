//! Native DESCRIBE/EXPLAIN results are ordinary logical rows. Preparation owns
//! metadata only; every disclosure rechecks current rights and source identity.
const std = @import("std");
const g = @import("root.zig");
const f = g.fuze;
const c = g.catalog;
const Self = @This();
arena: std.heap.ArenaAllocator,
name: ?c.TableMetadata.Name = null,
metadata: ?c.TableMetadata.Record = null,
statement: ?g.Statement = null,
rows: []const []const f.Types.Values.Cell,
output: []const f.Types.Field,
const describe_fields = [_]f.Types.Field{
    .{ .name = "name", .type = .utf8 },                      .{ .name = "type", .type = .utf8 },
    .{ .name = "nullable", .type = .boolean },               .{ .name = "primary_key", .type = .boolean },
    .{ .name = "default", .type = .utf8, .nullable = true }, .{ .name = "max_characters", .type = .uint32, .nullable = true },
    .{ .name = "object", .type = .uint64 },                  .{ .name = "schema_revision", .type = .uint64 },
    .{ .name = "column_id", .type = .uint64 },
};
const explain_fields = [_]f.Types.Field{.{ .name = "plan", .type = .utf8 }};
fn text(bytes: []const u8) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .bytes = bytes } } };
}
fn boolean(value: bool) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .boolean = value } } };
}
fn unsigned(value: u64) f.Types.Values.Cell {
    return .{ .value = .{ .atom = .{ .unsigned = value } } };
}
pub fn prepare(host: *g.Session, sql: []const u8) !?Self {
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    var parser = try f.SqlTyped.init(a, sql, null);
    if (try parser.takeWord("DESCRIBE")) {
        const name = try c.TableMetadata.Name.init(try parser.name());
        try parser.finish();
        var definition = (try host.table.lookup(host.allocator, name)) orelse return error.CatalogNameNotFound;
        defer definition.deinit();
        const schema = definition.schema.schema;
        const rows = try a.alloc([]const f.Types.Values.Cell, schema.columns.len);
        for (schema.columns, rows) |column, *row| {
            var type_text: std.Io.Writer.Allocating = .init(a);
            try f.LogicalDisplay.typeName(&type_text.writer, column.type);
            row.* = try a.dupe(f.Types.Values.Cell, &.{
                text(try a.dupe(u8, column.name)),                                                                                                          text(type_text.written()),                                     boolean(column.nullable), boolean(std.mem.indexOfScalar(u64, schema.primary_key, column.id) != null),
                if (column.default) |cell| text(try std.json.Stringify.valueAlloc(a, try f.LogicalJson.foreignCell(a, cell, column.type), .{})) else .null, if (column.max_characters) |limit| unsigned(limit) else .null, unsigned(schema.object),  unsigned(schema.revision),
                unsigned(column.id),
            });
        }
        return .{ .arena = arena, .name = name, .metadata = definition.metadata, .rows = rows, .output = &describe_fields };
    }
    if (try parser.takeWord("EXPLAIN")) {
        var statement = try g.Statement.prepare(host.allocator, &host.table, sql[parser.lexer.start..], host.dialect, .native, g.Session.read_options);
        errdefer statement.deinit();
        if (statement.kind() != .select or statement.parameters().len != 0) return error.UnsupportedConstruct;
        const plan = switch (statement.plan) {
            .select => |*selected| blk: {
                const template = &selected.template;
                var bound = try template.bind(host.allocator, template.name, template.descriptor.type, template.basis, &.{}, null);
                defer bound.deinit();
                break :blk try std.json.Stringify.valueAlloc(a, .{
                    .object = selected.binding.metadata.object,
                    .filter = bound.plan.predicate != .all,
                    .aggregate = @tagName(bound.plan.aggregate),
                    .limit = bound.plan.limit,
                    .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                    .executed = false,
                    .basis = @as(?[]const u8, null),
                }, .{});
            },
            .relational => |compilation| try std.json.Stringify.valueAlloc(a, .{
                .consistency = "per_resource_snapshot_vector",
                .sources = compilation.plan.sources.len,
                .join = if (compilation.plan.join) |join| @tagName(join.kind) else "none",
                .grouped = compilation.grouped(),
                .group_columns = compilation.plan.group_by.len,
                .schema = f.LogicalJson.TypeEnvelope{ .definition = f.Types.definition, .type = statement.output.?.type },
                .executed = false,
                .basis = @as(?[]const u8, null),
            }, .{}),
            else => unreachable,
        };
        const rows = try a.alloc([]const f.Types.Values.Cell, 1);
        rows[0] = try a.dupe(f.Types.Values.Cell, &.{text(plan)});
        return .{ .arena = arena, .statement = statement, .rows = rows, .output = &explain_fields };
    }
    arena.deinit();
    return null;
}
pub fn validate(self: *Self, host: *g.Session) !void {
    if (self.name) |name| {
        var definition = (try host.table.lookup(host.allocator, name)) orelse return error.CatalogNameNotFound;
        defer definition.deinit();
        if (!std.meta.eql(definition.metadata, self.metadata.?)) return error.CatalogDefinitionChanged;
    }
    if (self.statement) |*statement| try statement.validate(&host.table);
}
pub fn deinit(self: *Self) void {
    if (self.statement) |*statement| statement.deinit();
    self.arena.deinit();
}
pub const Read = struct {
    host: *g.Session,
    prepared: *Self,
    index: usize = 0,
    pub fn next(self: *Read) !?[]const f.Types.Values.Cell {
        try self.prepared.validate(self.host);
        if (self.index == self.prepared.rows.len) return null;
        defer self.index += 1;
        return self.prepared.rows[self.index];
    }
};
