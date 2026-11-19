//! Proposed schemas only. No live catalog, authorization or execution authority.
const std = @import("std");
const f = @import("transit_sql_frontend");
const types = @import("SourceTypes.zig");
const p = @import("transit_protocol");
pub const Entry = types.Table;
pub const Program = struct { schema_name: []const u8 = "public", name: []const u8, digest: [32]u8, control: p.Dataflow.Control = .initial() };
const Self = @This();
output: std.mem.Allocator,
scratch: std.mem.Allocator,
owner: usize = 0,
encapsulate: bool = false,
bindings: []const types.Binding = &.{},
context: ?*@import("SourceDiagnostic.zig").Context = null,
schemas: std.ArrayList([]const u8) = .empty,
entries: std.ArrayList(*const Entry) = .empty,
programs: std.ArrayList(Program) = .empty,

const FkContext = struct {
    catalog: *const Self,
    default_schema: []const u8,
    fn lookup(ctx: *anyopaque, a: std.mem.Allocator, name: []const u8) !f.SqlForeignKey.Resolver.Parent {
        return lookupQualified(ctx, a, null, name);
    }
    fn lookupQualified(ctx: *anyopaque, _: std.mem.Allocator, parent_schema: ?[]const u8, name: []const u8) !f.SqlForeignKey.Resolver.Parent {
        const self: *const FkContext = @ptrCast(@alignCast(ctx));
        const s_name = parent_schema orelse self.default_schema;
        const entry = try self.catalog.findQualified(s_name, name);
        return .{
            .schema = entry.schema,
            .definition = .{
                .object = .{ .scope = .{ .realm = 1, .resource = 1, .catalog = 1 }, .branch = 1, .object = entry.schema.object },
                .revision = entry.schema.revision,
                .digest = try entry.schema.fingerprint(),
            },
        };
    }
};

pub fn hasSchema(self: Self, schema_name: []const u8) bool {
    if (std.mem.eql(u8, schema_name, "public")) return true;
    for (self.schemas.items) |s_name| if (std.mem.eql(u8, s_name, schema_name)) return true;
    return false;
}
pub fn requireSchema(self: Self, schema_name: []const u8) !void {
    if (!self.hasSchema(schema_name)) return error.UnknownBuildSchema;
}
pub fn check(self: *Self, sql: []const u8, location: *f.Sql.Location) ![32]u8 {
    try f.Sql.validateText(sql);
    var parser = try f.SqlTyped.init(self.scratch, sql, location);
    if (parser.word("CREATE")) {
        var header = parser;
        try header.requireWord("CREATE");
        if (header.word("SCHEMA")) {
            var auth = try f.AuthorizationSql.compile(self.scratch, sql, location);
            defer auth.deinit();
            if (auth.statement != .create_schema or auth.statement.create_schema.owner != .current_role)
                return error.UnsupportedBuildStatement;
            const schema_name = auth.statement.create_schema.name;
            if (self.hasSchema(schema_name)) return error.ConflictingModuleInstance;
            try self.schemas.append(self.output, try self.output.dupe(u8, schema_name));
            var hash = std.crypto.hash.sha2.Sha256.init(.{});
            hash.update("transit.source.schema.v1\x00");
            hash.update(schema_name);
            return hash.finalResult();
        }
        if (header.word("DATAFLOW")) {
            const checked = try @import("ProgramCheck.zig").check(self, sql, location);
            try self.requireSchema(checked.schema_name);
            try self.unused(checked.schema_name, checked.name);
            try self.programs.append(self.output, .{ .schema_name = checked.schema_name, .name = checked.name, .digest = checked.digest });
            return checked.digest;
        }
        if (header.word("STREAM") or header.word("QUEUE")) return self.createLog(sql, location);
        const header_target = try f.TableDdl.targetDiagnostic(self.scratch, sql, location);
        const target_schema = header_target.schema_name orelse "public";
        try self.requireSchema(target_schema);
        if (self.context) |ctx| {
            var syn_parser = try f.SqlTyped.initDialect(self.scratch, sql, location, true, .transit);
            const syn = try f.TableDdl.syntax(&syn_parser, null);
            if (syn == .create) {
                for (syn.create.foreign_keys) |fk| {
                    const parent = try self.findQualified(fk.target_schema orelse target_schema, fk.target);
                    try @import("TypedOperands.zig").checkReferenceAccess(self.owner, self.bindings, parent, fk.target_columns, fk.target_span, ctx);
                }
            }
        }
        var fk_ctx: FkContext = .{ .catalog = self, .default_schema = target_schema };
        var declaration = try f.TableDdl.compileWithForeignKeys(self.scratch, sql, null, location, .transit, .{
            .context = &fk_ctx,
            .lookup = FkContext.lookup,
            .lookup_qualified = FkContext.lookupQualified,
        });
        defer declaration.deinit();
        if (declaration.statement != .create) return error.UnsupportedBuildStatement;
        const create = declaration.statement.create;
        if (create.if_not_exists) return error.UnsupportedBuildStatement;
        try self.unused(target_schema, create.name);
        const schema = try create.bind(self.entries.items.len + 1);
        const copied = try schema.clone(self.output);
        const entry = try self.output.create(Entry);
        const domains = try self.output.alloc(?@import("Graph.zig").Ref, create.columns.len);
        @memset(domains, null);
        entry.* = .{
            .schema_name = try self.output.dupe(u8, target_schema),
            .name = try self.output.dupe(u8, create.name),
            .schema = copied.schema,
            .domains = domains,
            .owner = self.owner,
            .encapsulated = self.encapsulate,
        };
        try self.entries.append(self.output, entry);
        return schema.fingerprint();
    }
    if (try f.ApplicationControl.parse(&parser)) |control| {
        if (control.command == .refresh or (control.command == .authorize and (control.role == null or control.role.? != .current_role))) return error.UnsupportedBuildProgramControl;
        const target_schema = control.schema orelse "public";
        for (self.programs.items) |*program| if (std.mem.eql(u8, program.schema_name, target_schema) and std.mem.eql(u8, program.name, control.name)) {
            program.control = try program.control.apply(control.command);
            const encoded = try p.Json.valueAllocBounded(self.scratch, .{ .definition = program.digest, .control = program.control, .statement = control }, f.Sql.max_statement_bytes);
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
            return digest;
        };
        return error.UnknownBuildProgram;
    }
    if (parser.word("PRODUCE") or parser.word("ENQUEUE")) {
        const target = try f.LogAppendSql.target(self.scratch, sql, .transit, location);
        const entry = try self.findResourceQualified(target.source.qualifier, target.source.name);
        if (!std.mem.eql(u8, @tagName(entry.kind), @tagName(target.kind))) return error.SourceTypeMismatch;
        var prepared = try f.LogAppendSql.Prepared.init(self.scratch, sql, entry.schema, .transit, location);
        defer prepared.deinit();
        if (prepared.parameterTypes().len != 0) return error.UnboundBuildParameter;
        var bound = try prepared.bind(self.scratch, &.{}, location);
        defer bound.deinit();
        return bound.rows.plan.fingerprint(self.scratch);
    }
    if (parser.word("CONSUME")) {
        const target = try f.LogConsumeSql.target(self.scratch, sql, .transit, location);
        const entry = try self.findResourceQualified(target.qualifier, target.name);
        if (entry.kind != .stream) return error.SourceTypeMismatch;
        var prepared = try f.LogConsumeSql.Prepared.init(self.scratch, sql, entry.schema, .transit, location);
        defer prepared.deinit();
        if (prepared.parameterTypes().len != 0) return error.UnboundBuildParameter;
        var bound = try prepared.bind(self.scratch, &.{}, null);
        defer bound.deinit();
        return bound.plan.plan.fingerprint();
    }
    if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        const target = try f.TableDml.targetDiagnostic(self.scratch, sql, location);
        const entry = try self.findQualified(target.schema_name, target.name);
        var prepared = try f.TableDml.compile(self.scratch, sql, entry.name, entry.schema, location);
        defer prepared.deinit();
        return prepared.plan.fingerprint(self.scratch);
    }
    if (parser.word("SELECT")) {
        const target = try f.TableSelect.targetReferenceDiagnostic(self.scratch, sql, location);
        const entry = try self.findQualified(target.qualifier, target.name);
        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        var semantics: [f.TableSchema.max_columns]f.TableSchema.Semantics = undefined;
        for (entry.schema.columns, semantics[0..entry.schema.columns.len]) |column, *item| item.* = column.semantics;
        var diagnostic: f.Sql.Binding = .{};
        var prepared = f.LogicalPrepared.initSemantics(self.scratch, sql, entry.name, try entry.schema.rowType(&fields), try entry.schema.fingerprint(), &diagnostic, .transit, semantics[0..entry.schema.columns.len]) catch |err| {
            if (diagnostic.location) |at| location.* = at;
            return err;
        };
        defer prepared.deinit();
        if (prepared.parameterTypes().len != 0) return error.UnboundBuildParameter;
        var bound = try prepared.bind(self.scratch, entry.name, try entry.schema.rowType(&fields), try entry.schema.fingerprint(), &.{}, &diagnostic);
        defer bound.deinit();
        return bound.plan.fingerprint();
    }
    return error.UnsupportedBuildStatement;
}
pub fn find(self: Self, name: []const u8) !*const Entry {
    return self.findQualified(null, name);
}
pub fn findQualified(self: Self, schema_name: ?[]const u8, name: []const u8) !*const Entry {
    const entry = try self.findResourceQualified(schema_name, name);
    if (entry.kind != .table) return error.SourceTypeMismatch;
    return entry;
}
pub fn findResource(self: Self, name: []const u8) !*const Entry {
    return self.findResourceQualified(null, name);
}
pub fn findResourceQualified(self: Self, schema_name: ?[]const u8, name: []const u8) !*const Entry {
    const s_name = schema_name orelse "public";
    for (self.entries.items) |entry| if (std.mem.eql(u8, entry.schema_name, s_name) and std.mem.eql(u8, entry.name, name)) return entry;
    return error.UnknownBuildTable;
}
fn unused(self: Self, schema_name: []const u8, name: []const u8) !void {
    for (self.entries.items) |entry| if (std.mem.eql(u8, entry.schema_name, schema_name) and std.mem.eql(u8, entry.name, name)) return error.ConflictingModuleInstance;
    for (self.programs.items) |entry| if (std.mem.eql(u8, entry.schema_name, schema_name) and std.mem.eql(u8, entry.name, name)) return error.ConflictingModuleInstance;
}
fn createLog(self: *Self, sql: []const u8, location: *f.Sql.Location) ![32]u8 {
    var declaration = try f.LogDdl.compile(self.scratch, sql, .transit, location);
    defer declaration.deinit();
    const statement = declaration.statement;
    if (statement.action != .create) return error.UnsupportedBuildStatement;
    const target_schema = statement.schema_name orelse "public";
    try self.requireSchema(target_schema);
    try self.unused(target_schema, statement.name);
    const schema = try statement.action.create.bind(self.entries.items.len + 1);
    const configuration = try statement.configure(null, schema);
    if (configuration.configuration.partitioning.count != 1 or configuration.destination == .name) return error.UnsupportedBuildLogConfiguration;
    const copied = try schema.clone(self.output);
    const entry = try self.output.create(Entry);
    const domains = try self.output.alloc(?@import("Graph.zig").Ref, schema.columns.len);
    @memset(domains, null);
    entry.* = .{
        .schema_name = try self.output.dupe(u8, target_schema),
        .name = try self.output.dupe(u8, statement.name),
        .schema = copied.schema,
        .domains = domains,
        .owner = self.owner,
        .encapsulated = self.encapsulate,
        .kind = if (statement.kind == .stream) .stream else .queue,
        .log = configuration,
    };
    try self.entries.append(self.output, entry);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(@tagName(entry.kind));
    hash.update(&try schema.fingerprint());
    return hash.finalResult();
}
pub fn querySchema(self: *Self, sql: []const u8) !f.Types.Type {
    const parser = try f.SqlTyped.init(self.scratch, sql, null);
    if (parser.word("CONSUME")) {
        const target = try f.LogConsumeSql.target(self.scratch, sql, .transit, null);
        const entry = try self.findResourceQualified(target.qualifier, target.name);
        if (entry.kind != .stream) return error.SourceTypeMismatch;
        var prepared = try f.LogConsumeSql.Prepared.init(self.scratch, sql, entry.schema, .transit, null);
        defer prepared.deinit();
        return (try prepared.template.outputSchema(self.output)).type;
    }
    const target = try f.TableSelect.targetReferenceDiagnostic(self.scratch, sql, null);
    const entry = try self.findQualified(target.qualifier, target.name);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var semantics: [f.TableSchema.max_columns]f.TableSchema.Semantics = undefined;
    for (entry.schema.columns, semantics[0..entry.schema.columns.len]) |column, *item| item.* = column.semantics;
    var prepared = try f.LogicalPrepared.initSemantics(self.scratch, sql, entry.name, try entry.schema.rowType(&fields), try entry.schema.fingerprint(), null, .transit, semantics[0..entry.schema.columns.len]);
    defer prepared.deinit();
    return (try prepared.outputSchema(self.output)).type;
}

/// Require a TYPE source operand to occupy a type position in the ordinary
/// grammar. SQL permits some type words as identifiers; successful preparation
/// alone cannot establish the source operand's kind. Unlike presentation
/// classification, this parse must finish and allocation/parse errors propagate.
pub fn verifyTypeOperands(allocator: std.mem.Allocator, sql: []const u8, sites: []const usize, location: *f.Sql.Location) !void {
    if (sites.len == 0) return;
    const roles = try allocator.alloc(f.Sql.TokenRole, sql.len);
    @memset(roles, .unknown);
    var parser = try f.SqlTyped.initDialect(allocator, sql, location, true, .transit);
    parser.roles = roles;
    if (parser.word("CREATE")) {
        _ = try f.TableDdl.syntax(&parser, null);
    } else if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        _ = try f.TableDml.syntax(&parser, null);
    } else if (parser.word("SELECT")) {
        _ = try f.TableSelect.syntax(&parser, null);
    } else return error.UnsupportedBuildStatement;
    try parser.finish();
    for (sites) |offset| if (roles[offset] != .type_name) {
        location.* = .{ .offset = offset };
        return error.InvalidSourceTypeOperand;
    };
}
