//! Proposed schemas only. No live catalog, authorization or execution authority.
const std = @import("std");
const f = @import("transit_fuze");
const Entry = struct { name: []const u8, schema: f.TableSchema.Schema };
const Self = @This();
output: std.mem.Allocator,
scratch: std.mem.Allocator,
entries: std.ArrayList(Entry) = .empty,
pub fn check(self: *Self, sql: []const u8, location: *f.Sql.Location) ![32]u8 {
    try f.Sql.validateText(sql);
    var parser = try f.SqlTyped.init(self.scratch, sql, location);
    if (parser.word("CREATE")) {
        var declaration = try f.TableDdl.compile(self.scratch, sql, null, location);
        defer declaration.deinit();
        if (declaration.statement != .create) return error.UnsupportedBuildStatement;
        const create = declaration.statement.create;
        if (create.if_not_exists) return error.UnsupportedBuildStatement;
        for (self.entries.items) |entry| if (std.mem.eql(u8, entry.name, create.name)) return error.ConflictingModuleInstance;
        const schema = try create.bind(self.entries.items.len + 1);
        const copied = try schema.clone(self.output);
        try self.entries.append(self.output, .{ .name = try self.output.dupe(u8, create.name), .schema = copied.schema });
        return schema.fingerprint();
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
fn find(self: Self, name: []const u8) !Entry {
    for (self.entries.items) |entry| if (std.mem.eql(u8, entry.name, name)) return entry;
    return error.UnknownBuildTable;
}
