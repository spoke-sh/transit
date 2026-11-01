//! Bounded staged foreign-key syntax. Catalog resolution is explicit and occurs
//! before a saved declaration is created; replay never resolves SQL names again.
const std = @import("std");
const Parser = @import("SqlTyped.zig");
const Reference = @import("SqlReference.zig");
const sql = @import("Sql.zig");
const s = @import("TableSchema.zig");
const c = @import("TableConstraints.zig");
const Definition = @import("transit_protocol").DataLifecycle.Definition;
pub const Resolver = struct {
    pub const Parent = struct { schema: s.Schema, definition: Definition };
    context: *anyopaque,
    lookup: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!Parent,
};
pub const Syntax = struct {
    name: []const u8,
    local_columns: []const Reference,
    target: []const u8,
    target_columns: []const Reference,
    on_delete: c.ReferentialAction,
    on_update: c.ReferentialAction,
    pub fn bind(self: Syntax, a: std.mem.Allocator, schema: s.Schema, table: []const u8, id: c.ConstraintId, location: ?*sql.Location, resolver: ?Resolver) !c.ForeignKeyConstraint {
        const resolve = resolver orelse return error.ForeignKeyResolutionRequired;
        const parent = try resolve.lookup(resolve.context, a, self.target);
        const local = try a.alloc(s.ColumnId, self.local_columns.len);
        const target = try a.alloc(s.ColumnId, self.target_columns.len);
        for (local, self.local_columns) |*out, ref| out.* = schema.columns[try ref.resolve(table, schema.columns, location)].id;
        for (target, self.target_columns) |*out, ref| out.* = parent.schema.columns[try ref.resolve(self.target, parent.schema.columns, location)].id;
        const result: c.ForeignKeyConstraint = .{ .id = id, .name = self.name, .local_columns = local, .target_object = parent.schema.object, .target_revision = parent.schema.revision, .target_definition = parent.definition, .target_columns = target, .on_delete = self.on_delete, .on_update = self.on_update };
        try result.validateAgainstSchemas(schema, parent.schema);
        return result;
    }
};
fn columns(parser: *Parser) ![]const Reference {
    try parser.require(.left);
    var out: std.ArrayList(Reference) = .empty;
    while (true) {
        if (out.items.len == s.max_columns) return error.InvalidForeignKeyArity;
        try out.append(parser.allocator, try Reference.unqualified(parser, .column));
        if (!try parser.take(.comma)) break;
    }
    try parser.require(.right);
    return out.toOwnedSlice(parser.allocator);
}
fn action(parser: *Parser) !c.ReferentialAction {
    if (try parser.takeWord("RESTRICT")) return .restrict;
    if (try parser.takeWord("CASCADE")) return .cascade;
    if (try parser.takeWord("NO")) {
        try parser.requireWord("ACTION");
        return .no_action;
    }
    if (try parser.takeWord("SET")) {
        try parser.requireWord("NULL");
        return .set_null;
    }
    return error.InvalidForeignKeyAction;
}
pub fn parse(parser: *Parser, name: []const u8) !Syntax {
    try parser.requireWord("FOREIGN");
    try parser.requireWord("KEY");
    const local = try columns(parser);
    try parser.requireWord("REFERENCES");
    const target = try parser.named(.source);
    const remote = try columns(parser);
    if (local.len != remote.len) return error.InvalidForeignKeyArity;
    var on_delete: c.ReferentialAction = .restrict;
    var on_update: c.ReferentialAction = .restrict;
    var seen_delete = false;
    var seen_update = false;
    while (try parser.takeWord("ON")) {
        if (try parser.takeWord("DELETE")) {
            if (seen_delete) return error.InvalidForeignKeyAction;
            seen_delete = true;
            on_delete = try action(parser);
        } else {
            try parser.requireWord("UPDATE");
            if (seen_update) return error.InvalidForeignKeyAction;
            seen_update = true;
            on_update = try action(parser);
        }
    }
    // Never turn an ordinary enforced SQL FK into advisory metadata silently.
    if (!try parser.takeWord("NOT")) return error.ForeignKeyIndexEnforcementUnavailable;
    try parser.requireWord("ENFORCED");
    return .{ .name = name, .local_columns = local, .target = target, .target_columns = remote, .on_delete = on_delete, .on_update = on_update };
}
