//! Check source annotations against the owning Fuze syntax before erasure.
const std = @import("std");
const f = @import("transit_fuze");
const Graph = @import("Graph.zig");
const types = @import("SourceTypes.zig");
const Catalog = @import("WorkingCatalog.zig");
const Context = @import("SourceDiagnostic.zig").Context;
pub const Site = struct { start: usize, end: usize, value: types.Value };
pub const Origin = struct { start: usize, end: usize, source: usize };
pub const Column = struct { name: []const u8, domain: ?[]const u8 };
pub const Operand = struct { role: enum { assignment, predicate }, column: []const u8, domain: ?[]const u8, value: ?types.Primitive };
/// In-memory checked evidence. Not a persisted artifact or a runtime grant.
pub const Checked = struct { table: []const u8, schema: [32]u8, columns: []const Column, operands: []const Operand, program: ?@import("ProgramAnnotations.zig").Evidence = null };
const Span = f.SqlTyped.Literal.Span;
const Self = @This();
a: std.mem.Allocator,
sites: []const Site,
used: []bool,
graph: Graph,
context: *Context,
operands: std.ArrayList(Operand) = .empty,

fn at(self: *Self, span: Span) ?types.Value {
    for (self.sites, 0..) |site, i| if (site.start == span.start and site.end == span.end) {
        self.used[i] = true;
        return site.value;
    };
    return null;
}
fn target(self: *Self, span: Span, table: *const types.Table) !void {
    if (self.at(span)) |value| switch (value) {
        .table, .stream, .queue => |resource| if (resource != table) return error.SourceTableBindingMismatch,
        else => {},
    };
}
fn scalar(self: *Self, span: Span, table: *const types.Table, column: usize, role: @FieldType(Operand, "role")) !void {
    const expected = table.domains[column];
    const value = self.at(span);
    const actual = if (value) |v| if (v.scalar()) |ty| ty.domain else null else null;
    self.context.* = .{ .offset = span.start, .name = table.name, .column = table.schema.columns[column].name, .expected = if (expected) |ref| self.graph.getDefinition(ref).domain.?.identity else @tagName(table.schema.columns[column].type), .actual = if (value) |v| if (v.scalar()) |ty| ty.label(self.graph) else @tagName(v) else "ordinary SQL scalar" };
    if (!std.meta.eql(actual, expected)) return error.SourceDomainMismatch;
    if (value) |v| {
        if (v == .symbolic and !try v.symbolic.physical().eql(table.schema.columns[column].type)) return error.SourceTypeMismatch;
        if (v.scalar() != null) try self.operands.append(self.a, .{
            .role = role,
            .column = table.schema.columns[column].name,
            .domain = if (actual) |ref| self.graph.getDefinition(ref).domain.?.identity else null,
            .value = if (v == .symbolic) null else try v.primitive(),
        });
    }
}
fn predicate(self: *Self, input: anytype, table: *const types.Table, qualifier: []const u8) !void {
    for (input.instructions) |instruction| if (instruction == .atom) switch (instruction.atom) {
        .state => |v| {
            _ = try v.column.resolve(qualifier, table.schema.columns, null);
        },
        .compare => |v| {
            const index = try v.column.resolve(qualifier, table.schema.columns, null);
            if (table.domains[index] != null and v.op != .eq and v.op != .ne) return error.UnsupportedNominalOperation;
            const span: Span = switch (v.value) {
                .literal => |literal| literal.span,
                .parameter => |parameter| blk: {
                    for (self.sites) |site| if (site.start == parameter.offset) break :blk .{ .start = site.start, .end = site.end };
                    return error.InvalidSourceOperand;
                },
            };
            try self.scalar(span, table, index, .predicate);
        },
    };
}
fn selection(self: *Self, input: anytype, table: *const types.Table, qualifier: []const u8) !bool {
    if (input.star) return for (table.domains) |domain| {
        if (domain != null) break true;
    } else false;
    var nominal_projection = false;
    for (input.items[0..input.count]) |item| {
        if (item.scalar) |expression| {
            for (expression.nodes) |node| if (node == .input) {
                const column = try node.input.resolve(qualifier, table.schema.columns, null);
                if (table.domains[column] != null) return error.UnsupportedNominalOperation;
            };
        } else {
            const column = try item.column.resolve(qualifier, table.schema.columns, null);
            if (table.domains[column] != null) {
                if (input.aggregate != .rows) return error.UnsupportedNominalOperation;
                nominal_projection = true;
            }
        }
    }
    _ = self;
    return nominal_projection;
}

fn parameters(self: *Self, expected: []const f.Types.Type) !void {
    var index: usize = 0;
    for (self.sites) |site| if (site.value == .symbolic or site.value == .nominal) {
        if (index == expected.len or !try site.value.scalar().?.physical().eql(expected[index])) return error.SourceTypeMismatch;
        index += 1;
    };
    if (index != expected.len) return error.InvalidSourceOperand;
}
fn declaration(self: *Self, output: std.mem.Allocator, catalog: *Catalog, create: f.TableDdl.Create) !*const types.Table {
    const table = try catalog.findResource(create.name);
    const domains = try output.alloc(?Graph.Ref, create.columns.len);
    @memset(domains, null);
    for (create.columns, create.column_type_spans, 0..) |column, span, i| {
        if (self.at(span)) |value| {
            self.context.* = .{ .offset = span.start, .name = table.name, .column = table.schema.columns[i].name };
            if (value != .type) return error.InvalidSourceTypeOperand;
            domains[i] = value.type.domain;
            if (domains[i] != null) {
                if (column.nullable or column.default != null) return error.UnsupportedNominalColumn;
                for (create.integrity.checks) |constraint| if (constraint.referencesColumn(column.id)) return error.UnsupportedNominalColumn;
            }
        }
    }
    const annotated = try output.create(types.Table);
    annotated.* = table.*;
    annotated.domains = domains;
    // The just-created definition is immutable once exported.
    catalog.entries.items[catalog.entries.items.len - 1] = annotated;
    return annotated;
}
fn insert(self: *Self, input: @FieldType(@FieldType(f.TableDml.Syntax, "action"), "insert"), table: *const types.Table) !void {
    const width = if (input.columns) |columns| columns.len else table.schema.columns.len;
    for (input.rows) |row| {
        if (row.values.len != width) return error.InvalidRowWidth;
        for (row.values, 0..) |value, i| {
            const column = if (input.columns) |columns| try columns[i].resolve(table.name, table.schema.columns, null) else i;
            try self.scalar(value.span, table, column, .assignment);
        }
    }
    if (input.columns) |columns| for (table.domains, table.schema.columns) |domain, column| {
        if (domain != null) {
            const present = for (columns) |chosen| {
                if (std.mem.eql(u8, chosen.name, column.name)) break true;
            } else false;
            if (!present) {
                self.context.* = .{ .name = table.name, .column = column.name, .expected = self.graph.getDefinition(domain.?).domain.?.identity, .actual = "omitted column" };
                return error.SourceDomainMismatch;
            }
        }
    };
}
/// Reuse the workload owner's selected input layout, including metadata. This
/// temporary view is only for source annotations; its schema is never emitted.
fn consume(self: *Self, table: *const types.Table, prepared: *const f.LogConsumeSql.Prepared) !void {
    var view = table.*;
    const fields = prepared.template.descriptor.type.structure;
    const columns = try self.a.alloc(f.TableSchema.Column, fields.len);
    const domains = try self.a.alloc(?Graph.Ref, fields.len);
    for (fields, prepared.fields, columns, domains, 0..) |field, selected, *column, *domain, i| {
        domain.* = null;
        if (selected == .column) {
            const index = try table.schema.index(selected.column);
            column.* = table.schema.columns[index];
            domain.* = table.domains[index];
        } else column.* = .{ .id = i + 1, .name = switch (selected) {
            .partition => "_partition",
            .offset => "_offset",
            else => return error.UnsupportedLogOperand,
        }, .type = field.type, .nullable = field.nullable };
    }
    view.schema.columns = columns;
    view.domains = domains;
    const input = prepared.template.syntax;
    _ = try self.selection(input.selection, &view, input.qualifier);
    if (input.predicate) |predicate_| try self.predicate(predicate_, &view, input.qualifier);
    try self.parameters(prepared.parameterTypes());
}

pub fn check(a: std.mem.Allocator, output: std.mem.Allocator, graph: Graph, catalog: *Catalog, sql: []const u8, sites: []const Site, symbolic: bool, context: *Context) !Checked {
    const used = try a.alloc(bool, sites.len);
    @memset(used, false);
    var self: Self = .{ .a = a, .sites = sites, .used = used, .graph = graph, .context = context };
    var checked_table: *const types.Table = undefined;
    var parser = try f.SqlTyped.initDialect(a, sql, null, true, .transit);
    if (parser.word("CREATE")) {
        var header = parser;
        try header.requireWord("CREATE");
        if (header.word("STREAM") or header.word("QUEUE")) {
            var log = try f.LogDdl.compile(a, sql, .transit, null);
            defer log.deinit();
            if (log.statement.action != .create) return error.UnsupportedBuildStatement;
            checked_table = try self.declaration(output, catalog, log.statement.action.create);
        } else {
            const input = try f.TableDdl.syntax(&parser, null);
            try parser.finish();
            if (input != .create) return error.UnsupportedBuildStatement;
            checked_table = try self.declaration(output, catalog, input.create);
        }
    } else if (parser.word("PRODUCE") or parser.word("ENQUEUE")) {
        const selected = try f.LogAppendSql.target(a, sql, .transit, null);
        const table = try catalog.findResource(selected.source.name);
        checked_table = table;
        if (!std.mem.eql(u8, @tagName(table.kind), @tagName(selected.kind))) return error.SourceTypeMismatch;
        self.context.* = .{ .name = table.name };
        try self.target(selected.source.span, table);
        var prepared = try f.LogAppendSql.Prepared.init(a, sql, table.schema, .transit, null);
        defer prepared.deinit();
        try self.insert(prepared.template.syntax.action.insert, table);
        try self.parameters(prepared.parameterTypes());
    } else if (parser.word("CONSUME")) {
        const selected = try f.LogConsumeSql.target(a, sql, .transit, null);
        const table = try catalog.findResource(selected.name);
        checked_table = table;
        if (table.kind != .stream) return error.SourceTypeMismatch;
        self.context.* = .{ .name = table.name };
        try self.target(selected.span, table);
        var prepared = try f.LogConsumeSql.Prepared.init(a, sql, table.schema, .transit, null);
        defer prepared.deinit();
        try self.consume(table, &prepared);
    } else if (parser.word("SELECT")) {
        const input = try f.TableSelect.syntax(&parser, null);
        try parser.finish();
        const table = try catalog.find(input.subject.name);
        checked_table = table;
        try self.target(input.subject.span, table);
        const nominal_projection = try self.selection(input.selection, table, input.qualifier);
        // Raw derived projections keep ordinary semantics; carrying annotations
        // through a derived alias needs an explicit typed projection contract.
        if (input.outer != null and nominal_projection) return error.UnsupportedNominalOperation;
        if (input.predicate) |predicate_| try self.predicate(predicate_, table, input.qualifier);
        if (symbolic) {
            var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
            var prepared = try f.LogicalPrepared.init(a, sql, table.name, try table.schema.rowType(&fields), try table.schema.fingerprint(), null);
            defer prepared.deinit();
            try self.parameters(prepared.parameterTypes());
        }
    } else {
        const input = try f.TableDml.syntax(&parser, null);
        try parser.finish();
        const table = try catalog.find(input.subject.name);
        checked_table = table;
        try self.target(input.subject_span, table);
        switch (input.action) {
            .insert => |input_| try self.insert(input_, table),
            .update => |assignments| for (assignments) |assignment| {
                const column = try assignment.column.resolve(table.name, table.schema.columns, null);
                try self.scalar(assignment.value.span, table, column, .assignment);
            },
            .delete => {},
        }
        if (input.predicate) |predicate_| try self.predicate(predicate_, table, table.name);
        if (symbolic) {
            var prepared = try f.TableDmlPrepared.init(a, sql, table.name, table.schema, .transit, null);
            defer prepared.deinit();
            try self.parameters(prepared.parameterTypes());
        }
    }
    for (sites, used) |site, consumed| {
        if (consumed) continue;
        if (site.value == .table or site.value == .stream or site.value == .queue or site.value == .nominal or (site.value == .symbolic and site.value.symbolic.domain != null) or
            (site.value == .type and site.value.type.domain != null)) return error.InvalidSourceOperand;
    }
    const columns = try output.alloc(Column, checked_table.domains.len);
    for (checked_table.schema.columns, checked_table.domains, columns) |column, domain, *result| result.* = .{
        .name = column.name,
        .domain = if (domain) |ref| graph.getDefinition(ref).domain.?.identity else null,
    };
    return .{ .table = checked_table.name, .schema = try checked_table.schema.fingerprint(), .columns = columns, .operands = try output.dupe(Operand, self.operands.items) };
}
