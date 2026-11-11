//! Proposed schemas only. No live catalog, authorization or execution authority.
const std = @import("std");
const f = @import("transit_fuze");
const types = @import("SourceTypes.zig");
pub const Entry = types.Table;
const Self = @This();
output: std.mem.Allocator,
scratch: std.mem.Allocator,
owner: usize = 0,
entries: std.ArrayList(*const Entry) = .empty,
pub fn check(self: *Self, sql: []const u8, location: *f.Sql.Location) ![32]u8 {
    try f.Sql.validateText(sql);
    var parser = try f.SqlTyped.init(self.scratch, sql, location);
    if (parser.word("CREATE")) {
        var header = parser;
        try header.requireWord("CREATE");
        if (header.word("STREAM") or header.word("QUEUE")) return self.createLog(sql, location);
        var declaration = try f.TableDdl.compile(self.scratch, sql, null, location);
        defer declaration.deinit();
        if (declaration.statement != .create) return error.UnsupportedBuildStatement;
        const create = declaration.statement.create;
        if (create.if_not_exists) return error.UnsupportedBuildStatement;
        try self.unused(create.name);
        const schema = try create.bind(self.entries.items.len + 1);
        const copied = try schema.clone(self.output);
        const entry = try self.output.create(Entry);
        const domains = try self.output.alloc(?@import("Graph.zig").Ref, create.columns.len);
        @memset(domains, null);
        entry.* = .{ .name = try self.output.dupe(u8, create.name), .schema = copied.schema, .domains = domains, .owner = self.owner };
        try self.entries.append(self.output, entry);
        return schema.fingerprint();
    }
    if (parser.word("PRODUCE") or parser.word("ENQUEUE")) {
        const target = try f.LogAppendSql.target(self.scratch, sql, .transit, location);
        const entry = try self.findResource(target.source.name);
        if (!std.mem.eql(u8, @tagName(entry.kind), @tagName(target.kind))) return error.SourceTypeMismatch;
        var prepared = try f.LogAppendSql.Prepared.init(self.scratch, sql, entry.schema, .transit, location);
        defer prepared.deinit();
        if (prepared.parameterTypes().len != 0) return error.UnboundBuildParameter;
        var bound = try prepared.bind(self.scratch, &.{}, location);
        defer bound.deinit();
        return bound.rows.plan.fingerprint(self.scratch);
    }
    if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        const target = try f.TableDml.targetDiagnostic(self.scratch, sql, location);
        const entry = try self.find(target.name);
        var prepared = try f.TableDml.compile(self.scratch, sql, entry.name, entry.schema, location);
        defer prepared.deinit();
        return prepared.plan.fingerprint(self.scratch);
    }
    if (parser.word("SELECT")) {
        const target = try f.TableSelect.targetDiagnostic(self.scratch, sql, location);
        const entry = try self.find(target);
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
    const entry = try self.findResource(name);
    if (entry.kind != .table) return error.SourceTypeMismatch;
    return entry;
}
pub fn findResource(self: Self, name: []const u8) !*const Entry {
    for (self.entries.items) |entry| if (std.mem.eql(u8, entry.name, name)) return entry;
    return error.UnknownBuildTable;
}
fn unused(self: Self, name: []const u8) !void {
    for (self.entries.items) |entry| if (std.mem.eql(u8, entry.name, name)) return error.ConflictingModuleInstance;
}
fn createLog(self: *Self, sql: []const u8, location: *f.Sql.Location) ![32]u8 {
    var declaration = try f.LogDdl.compile(self.scratch, sql, .transit, location);
    defer declaration.deinit();
    const statement = declaration.statement;
    if (statement.action != .create) return error.UnsupportedBuildStatement;
    try self.unused(statement.name);
    const schema = try statement.action.create.bind(self.entries.items.len + 1);
    const configuration = try statement.configure(null, schema);
    if (configuration.configuration.partitioning.count != 1 or configuration.destination == .name) return error.UnsupportedBuildLogConfiguration;
    const copied = try schema.clone(self.output);
    const entry = try self.output.create(Entry);
    const domains = try self.output.alloc(?@import("Graph.zig").Ref, schema.columns.len);
    @memset(domains, null);
    entry.* = .{ .name = try self.output.dupe(u8, statement.name), .schema = copied.schema, .domains = domains, .owner = self.owner, .kind = if (statement.kind == .stream) .stream else .queue, .log = configuration };
    try self.entries.append(self.output, entry);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(@tagName(entry.kind));
    hash.update(&try schema.fingerprint());
    return hash.finalResult();
}
pub fn querySchema(self: *Self, sql: []const u8) !f.Types.Type {
    const target = try f.TableSelect.targetDiagnostic(self.scratch, sql, null);
    const entry = try self.find(target);
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
pub fn verifyTypeOperands(allocator: std.mem.Allocator, sql: []const u8, sites: []const bool, location: *f.Sql.Location) !void {
    if (std.mem.indexOfScalar(bool, sites, true) == null) return;
    var roles: [f.Sql.max_statement_bytes]f.Sql.TokenRole = @splat(.unknown);
    var parser = try f.SqlTyped.initDialect(allocator, sql, location, true, .transit);
    parser.roles = roles[0..sql.len];
    if (parser.word("CREATE")) {
        _ = try f.TableDdl.syntax(&parser, null);
    } else if (parser.word("INSERT") or parser.word("UPDATE") or parser.word("DELETE")) {
        _ = try f.TableDml.syntax(&parser, null);
    } else if (parser.word("SELECT")) {
        _ = try f.TableSelect.syntax(&parser, null);
    } else return error.UnsupportedBuildStatement;
    try parser.finish();
    for (sites, 0..) |site, i| if (site and roles[i] != .type_name) {
        location.* = .{ .offset = i };
        return error.InvalidSourceTypeOperand;
    };
}
