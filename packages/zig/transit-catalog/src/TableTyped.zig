//! Neutral typed DDL/DML lowering. Column identities bind to an explicit catalog
//! basis; values reuse Fuze admission and produce the same immutable SQL intent.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const v = c.TableValues;
pub const Request = struct {
    definition: c.protocol.Growth.Definition,
    identity: v.Identity,
    name: []const u8,
    action: union(enum) {
        create: struct { schema: v.Schema, if_not_exists: bool },
        alter: struct { basis: v.Basis, change: c.TableLowering.Change },
        rename: struct { basis: v.Basis, name: []const u8 },
        drop: struct { basis: ?v.Basis, if_exists: bool },
        mutate: struct { basis: v.Basis, mutation: c.TableLowering.Mutation },
    },
    pub fn basis(self: Request) ?v.Basis {
        return switch (self.action) {
            .create => null,
            inline else => |value| value.basis,
        };
    }
};
/// An authorized lookup supplies the optional current definition. CREATE uses
/// no current definition; missing DROP IF EXISTS must remain explicitly absent.
pub fn intent(allocator: std.mem.Allocator, connection: c.TableClient.Connection, request: Request, current: ?c.TableCatalog.Definition) !c.TableIntent {
    if (request.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    try connection.validate();
    const identity = try request.identity.native();
    const name = try c.TableMetadata.Name.init(request.name);
    if (request.basis()) |basis| {
        const selected = current orelse return error.TableNotFound;
        try basis.check(selected.metadata);
        if (!selected.metadata.name.eql(&name) or !std.meta.eql(selected.metadata.scope, connection.scope) or selected.schema.schema.object != selected.metadata.object or !std.mem.eql(u8, &try selected.schema.schema.fingerprint(), &selected.metadata.schema_fingerprint)) return error.CatalogDefinitionChanged;
    } else if (current != null or (request.action != .create and (request.action != .drop or !request.action.drop.if_exists))) return error.CatalogDefinitionChanged;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    if (request.action == .mutate) {
        const selected = current.?;
        const mutation: c.TableDmlRequest = .{ .principal = connection.principal, .operation = identity.operation, .metadata = .{ .id = selected.metadata.revision, .spec = try selected.metadata.spec() }, .plan = try c.TableLowering.plan(&arena, selected.schema.schema, request.name, request.action.mutate.mutation) };
        return c.TableIntent.create(allocator, try c.TableCommand.fromDml(connection.scope, connection.owner, mutation, selected.metadata), identity.namespace);
    }
    var ddl: c.TableDdlRequest = .{ .namespace = connection.namespace, .principal = connection.principal, .operation = identity.operation, .object = if (current) |value| value.metadata.object else 0, .expected_revision = if (current) |value| value.metadata.revision else 0, .name = name, .action = undefined };
    ddl.action = switch (request.action) {
        .create => |value| blk: {
            const schema = try f.TableSchemaJson.native(&arena, value.schema);
            ddl.object = schema.object;
            break :blk .{ .create = .{ .schema = schema, .if_not_exists = value.if_not_exists } };
        },
        .alter => |value| .{ .alter = .{ .schema = current.?.schema.schema, .change = try c.TableLowering.change(&arena, current.?.schema.schema, value.change) } },
        .rename => |value| .{ .rename = try c.TableMetadata.Name.init(value.name) },
        .drop => |value| .{ .drop = .{ .if_exists = value.if_exists } },
        .mutate => unreachable,
    };
    return c.TableIntent.create(allocator, try c.TableCommand.fromDdl(connection.scope, connection.owner, ddl, if (current) |value| value.metadata else null), identity.namespace);
}
