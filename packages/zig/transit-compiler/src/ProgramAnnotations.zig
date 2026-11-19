//! Source-domain obligations over an already bound ordinary program. Physical
//! kinds, nullable reads, scopes, capabilities and execution remain Fuze-owned.
const std = @import("std");
const a = @import("transit_sql_frontend").ApplicationProgram;
const Graph = @import("Graph.zig");
const types = @import("SourceTypes.zig");
const Operands = @import("TypedOperands.zig");
const Catalog = @import("WorkingCatalog.zig");
const Context = @import("SourceDiagnostic.zig").Context;

pub const Field = struct { name: []const u8, value: Type };
pub const Type = struct { kind: a.Types.Kind, nullable: bool, domain: ?[]const u8, fields: []const Field };
pub const Node = struct { id: a.Id, source_offset: usize, kind: []const u8, type: Type };
pub const Association = struct { column: []const u8, domain: ?[]const u8, value: ?a.Id };
pub const Event = struct {
    kind: enum { acquire, let, read, require, atomic_begin, atomic_end, branch_begin, branch_else, branch_end, insert, append, failure_begin, failure_end },
    node: ?a.Id,
    source_offset: usize,
    resource: ?[]const u8 = null,
    columns: []const Association = &.{},
};
/// Internal evidence only. Step.jsonStringify never persists this projection.
pub const Evidence = struct { nodes: []const Node, events: []const Event };
pub const RowField = struct {
    name: []const u8,
    expected: Expected,
};
pub const Expected = union(enum) {
    scalar: types.Scalar,
    row: []const RowField,
};
pub const Obligation = struct {
    target: union(enum) {
        binding: []const u8,
        span: struct { start: usize, end: usize },
    },
    expected: Expected,
    name: []const u8,
};
const Value = struct { domain: ?Graph.Ref = null, fields: []const Named = &.{} };
const Named = struct { name: []const u8, value: Value };
const Self = @This();
scratch: std.mem.Allocator,
output: std.mem.Allocator,
graph: Graph,
catalog: *Catalog,
bound: *const a.Types.Bound,
sql: []const u8,
sites: []const Operands.Site,
origins: []const Operands.Origin,
obligations: []const Obligation,
used: []bool,
obligation_used: []bool,
context: *Context,
work: *usize,
work_limit: usize,
symbols: std.ArrayList(Named) = .empty,
columns: []const Named = &.{},
nodes: std.ArrayList(Node) = .empty,
events: std.ArrayList(Event) = .empty,

pub fn check(scratch: std.mem.Allocator, output: std.mem.Allocator, graph: Graph, catalog: *Catalog, program: a.Program, bound: *const a.Types.Bound, sql: []const u8, sites: []const Operands.Site, origins: []const Operands.Origin, obligations: []const Obligation, context: *Context, work: *usize, work_limit: usize) !Evidence {
    const used = try scratch.alloc(bool, sites.len);
    @memset(used, false);
    const obligation_used = try scratch.alloc(bool, obligations.len);
    @memset(obligation_used, false);
    var self: Self = .{ .scratch = scratch, .output = output, .graph = graph, .catalog = catalog, .bound = bound, .sql = sql, .sites = sites, .origins = origins, .obligations = obligations, .used = used, .obligation_used = obligation_used, .context = context, .work = work, .work_limit = work_limit };
    const input = try catalog.findResourceQualified(program.queue_schema, program.queue);
    const input_record = try self.record(input);
    try self.symbols.append(scratch, .{ .name = program.input, .value = input_record });
    try self.event(.acquire, null, 0, input, &.{});
    if (program.predicate) |predicate| {
        self.columns = input_record.fields;
        try self.condition(predicate);
        self.columns = &.{};
    }
    try self.block(program.body.instructions);
    if (program.failure) |failure| {
        self.symbols.shrinkRetainingCapacity(1);
        try self.symbols.append(scratch, .{ .name = failure.name, .value = .{} });
        try self.event(.failure_begin, null, 0, null, &.{});
        try self.block(failure.instructions);
        try self.event(.failure_end, null, 0, null, &.{});
    }
    for (sites, used) |site, consumed| if (site.value == .nominal and !consumed) {
        context.* = .{ .offset = site.start };
        return error.InvalidSourceOperand;
    };
    for (obligation_used) |consumed| if (!consumed) return error.BuildEmissionMismatch;
    return .{ .nodes = try self.nodes.toOwnedSlice(output), .events = try self.events.toOwnedSlice(output) };
}
fn tick(self: *Self) !void {
    if (self.work.* == self.work_limit) return error.BuildWorkLimit;
    self.work.* += 1;
}
fn origin(self: Self, offset: usize) usize {
    for (self.origins) |site| if (offset >= site.start and offset < site.end) return site.source;
    return if (self.origins.len == 0) 0 else self.origins[0].source;
}
fn domain(self: Self, ref: ?Graph.Ref) ?[]const u8 {
    return if (ref) |value| self.graph.getDefinition(value).domain.?.identity else null;
}
fn convertNested(scratch: std.mem.Allocator, items: []const types.FieldDomain) anyerror![]const Named {
    if (items.len == 0) return &.{};
    const out = try scratch.alloc(Named, items.len);
    for (items, out) |item, *slot| {
        slot.* = .{ .name = item.name, .value = .{ .domain = item.domain, .fields = try convertNested(scratch, item.fields) } };
    }
    return out;
}
fn record(self: *Self, resource: *const types.Table) !Value {
    const fields = try self.scratch.alloc(Named, resource.domains.len);
    for (resource.schema.columns, resource.domains, fields, 0..) |column, annotation, *item, idx| {
        const nested = if (idx < resource.nested_domains.len) try convertNested(self.scratch, resource.nested_domains[idx]) else &.{};
        item.* = .{ .name = column.name, .value = .{ .domain = annotation, .fields = nested } };
    }
    return .{ .fields = fields };
}
fn field(value: Value, name: []const u8) Value {
    for (value.fields) |item| if (std.mem.eql(u8, item.name, name)) return item.value;
    // The physical binder already checked field existence. Unannotated nested
    // records and native failure metadata carry no source-domain obligation.
    return .{};
}
fn nominal(value: Value) bool {
    if (value.domain != null) return true;
    for (value.fields) |item| if (nominal(item.value)) return true;
    return false;
}
fn same(left: Value, right: Value) bool {
    if (!std.meta.eql(left.domain, right.domain)) return false;
    if (!nominal(left) and !nominal(right)) return true;
    if (left.fields.len != right.fields.len) return false;
    for (left.fields, right.fields) |l, r| if (!std.mem.eql(u8, l.name, r.name) or !same(l.value, r.value)) return false;
    return true;
}
fn agree(self: *Self, expected: Value, actual: Value, offset: usize) !void {
    self.context.* = .{ .offset = offset, .expected = self.domain(expected.domain) orelse "ordinary scalar or matching record fields", .actual = self.domain(actual.domain) orelse "ordinary scalar or different record fields" };
    if (!same(expected, actual)) return error.SourceDomainMismatch;
}
fn ordinary(self: *Self, value: Value, offset: usize) !void {
    self.context.* = .{ .offset = offset, .expected = "ordinary scalar", .actual = self.domain(value.domain) orelse "record containing nominal fields" };
    if (nominal(value)) return error.UnsupportedNominalOperation;
}
fn physical(self: Self, id: a.Id) !a.Types.Value {
    if (id >= self.bound.values.len) return error.InvalidSourceOperand;
    return self.bound.values[id] orelse error.InvalidSourceOperand;
}
fn project(self: *Self, value: Value, physical_: a.Types.Value, depth: usize) anyerror!Type {
    try self.tick();
    if (depth > a.max_depth) return error.ProgramTooDeep;
    const fields = try self.output.alloc(Field, physical_.fields.len);
    for (physical_.fields, fields, 0..) |input, *out, i| {
        const annotation = if (input.name.len == 0 and i < value.fields.len) value.fields[i].value else field(value, input.name);
        out.* = .{ .name = try self.output.dupe(u8, input.name), .value = try self.project(annotation, input.value, depth + 1) };
    }
    return .{ .kind = physical_.kind, .nullable = physical_.nullable, .domain = self.domain(value.domain), .fields = fields };
}
fn checkExpected(self: *Self, expected: Expected, name: []const u8, actual: Value, physical_: a.Types.Value, offset: usize) anyerror!void {
    switch (expected) {
        .scalar => |want_scalar| {
            const want_kind: a.Types.Kind = switch (want_scalar.base) {
                .bigint => .integer,
                .text => .text,
                .boolean => .boolean,
                .uuid => .uuid,
                .timestamptz => .timestamp,
                .binary => .binary,
            };
            if (physical_.kind != .null and physical_.kind != want_kind) {
                self.context.* = .{ .offset = offset, .name = name, .expected = want_scalar.label(self.graph), .actual = @tagName(physical_.kind) };
                return error.ProgramTypeMismatch;
            }
            if (!std.meta.eql(want_scalar.domain, actual.domain) or (want_scalar.domain == null and nominal(actual))) {
                self.context.* = .{ .offset = offset, .name = name, .expected = want_scalar.label(self.graph), .actual = self.domain(actual.domain) orelse @tagName(physical_.kind) };
                return error.SourceDomainMismatch;
            }
        },
        .row => |want_fields| {
            if (physical_.kind == .null) return;
            if (physical_.kind != .record) {
                self.context.* = .{ .offset = offset, .name = name, .expected = "ROW", .actual = @tagName(physical_.kind) };
                return error.ProgramTypeMismatch;
            }
            const positional = physical_.fields.len > 0 and physical_.fields[0].name.len == 0;
            if (positional and physical_.fields.len != want_fields.len) {
                self.context.* = .{ .offset = offset, .name = name, .expected = "ROW", .actual = @tagName(physical_.kind) };
                return error.ProgramTypeMismatch;
            }
            for (want_fields, 0..) |rf, idx| {
                const phys_field = if (positional) physical_.fields[idx] else blk: {
                    for (physical_.fields) |pf| if (std.mem.eql(u8, pf.name, rf.name)) break :blk pf;
                    self.context.* = .{ .offset = offset, .name = rf.name, .expected = rf.name, .actual = "missing field" };
                    return error.ProgramTypeMismatch;
                };
                const act_field = if (positional and idx < actual.fields.len) actual.fields[idx].value else field(actual, rf.name);
                try self.checkExpected(rf.expected, rf.name, act_field, phys_field.value, offset);
            }
        },
    }
}
fn checkObligation(self: *Self, ob: Obligation, actual: Value, physical_: a.Types.Value, offset: usize) !void {
    return self.checkExpected(ob.expected, ob.name, actual, physical_, offset);
}
fn node(self: *Self, id: a.Id, offset: usize, kind: []const u8, value: Value) !void {
    try self.nodes.append(self.output, .{ .id = id, .source_offset = self.origin(offset), .kind = kind, .type = try self.project(value, try self.physical(id), 0) });
}
fn expression(self: *Self, input: *const a.Expression) anyerror!Value {
    self.context.* = .{ .offset = input.span.start };
    try self.tick();
    var value: Value = switch (input.value) {
        .null, .boolean, .integer, .text, .bytes, .uuid, .timestamp => .{},
        .name => |name| blk: {
            // Match the shared binder's lexical-before-column precedence.
            for (self.symbols.items) |symbol| if (std.mem.eql(u8, symbol.name, name)) break :blk symbol.value;
            for (self.columns) |column| if (std.mem.eql(u8, column.name, name)) break :blk column.value;
            break :blk .{};
        },
        .field => |item| field(try self.expression(item.base), item.name),
        .unary => |item| blk: {
            const operand = try self.expression(item.operand);
            if (item.operator != .is_null and item.operator != .is_not_null) try self.ordinary(operand, input.span.start);
            break :blk .{};
        },
        .binary => |item| blk: {
            const left = try self.expression(item.left);
            const right = try self.expression(item.right);
            if (item.operator == .equal or item.operator == .not_equal) {
                try self.agree(left, right, input.span.start);
            } else {
                try self.ordinary(left, item.left.span.start);
                try self.ordinary(right, item.right.span.start);
            }
            break :blk .{};
        },
        .case => |item| blk: {
            try self.condition(item.condition);
            const yes = try self.expression(item.yes);
            const no = try self.expression(item.no);
            if ((try self.physical(item.yes.id)).kind == .null) break :blk no;
            if ((try self.physical(item.no.id)).kind == .null) break :blk yes;
            try self.agree(yes, no, input.span.start);
            break :blk yes;
        },
        .call => |item| blk: {
            for (item.arguments) |argument| try self.ordinary(try self.expression(argument), argument.span.start);
            break :blk .{};
        },
        .text_cast => |item| blk: {
            try self.ordinary(try self.expression(item), input.span.start);
            break :blk .{};
        },
        .row => |items| blk: {
            const fields = try self.scratch.alloc(Named, items.len);
            for (items, fields) |item, *out| out.* = .{ .name = "", .value = try self.expression(item) };
            break :blk .{ .fields = fields };
        },
    };
    // Source holes are emitted as complete scalar literals in program SQL.
    // Match the recorded expansion extent, including the parser's trailing
    // whitespace convention; never infer domains from equal scalar values.
    for (self.sites, 0..) |site, i| if (site.value == .nominal and site.start == input.span.start and site.end <= input.span.end and
        std.mem.trim(u8, self.sql[site.end..input.span.end], " \t\r\n").len == 0)
    {
        self.used[i] = true;
        value.domain = site.value.nominal.type.domain;
    };
    const phys = try self.physical(input.id);
    for (self.obligations, 0..) |ob, idx| if (ob.target == .span and ob.target.span.start == input.span.start and ob.target.span.end == input.span.end) {
        self.obligation_used[idx] = true;
        try self.checkObligation(ob, value, phys, input.span.start);
    };
    try self.node(input.id, input.span.start, @tagName(input.value), value);
    return value;
}
fn condition(self: *Self, input: *const a.Expression) !void {
    try self.ordinary(try self.expression(input), input.span.start);
}
fn select(self: *Self, input: a.Select) !Value {
    const resource = try self.catalog.findResourceQualified(input.schema, input.target);
    const record_ = try self.record(resource);
    const before = self.columns;
    self.columns = record_.fields;
    defer self.columns = before;
    if (input.predicate) |predicate| try self.condition(predicate);
    if (input.columns) |names| {
        const fields = try self.scratch.alloc(Named, names.len);
        for (names, fields) |name, *out| out.* = .{ .name = name, .value = field(record_, name) };
        return .{ .fields = fields };
    }
    return record_;
}
fn event(self: *Self, kind: @FieldType(Event, "kind"), id: ?a.Id, offset: usize, resource: ?*const types.Table, expressions: []const *a.Expression) !void {
    const columns = try self.output.alloc(Association, if (resource) |value| value.domains.len else 0);
    if (resource) |value| {
        for (value.schema.columns, value.domains, columns, 0..) |column, annotation, *out, i| out.* = .{
            .column = column.name,
            .domain = self.domain(annotation),
            .value = if (i < expressions.len) expressions[i].id else null,
        };
    }
    try self.events.append(self.output, .{ .kind = kind, .node = id, .source_offset = self.origin(offset), .resource = if (resource) |value| value.name else null, .columns = columns });
}
fn write(self: *Self, schema: ?[]const u8, target: []const u8, expressions: []const *a.Expression) !*const types.Table {
    const resource = try self.catalog.findResourceQualified(schema, target);
    if (expressions.len != resource.domains.len) return error.SourceTypeMismatch;
    for (expressions, resource.domains, resource.schema.columns) |input, expected, column| {
        const actual = try self.expression(input);
        self.context.* = .{ .offset = input.span.start, .name = resource.name, .column = column.name, .expected = self.domain(expected) orelse @tagName(column.type), .actual = self.domain(actual.domain) orelse @tagName((try self.physical(input.id)).kind) };
        if (!std.meta.eql(expected, actual.domain) or (expected == null and nominal(actual))) return error.SourceDomainMismatch;
    }
    return resource;
}
fn block(self: *Self, instructions: []const a.Instruction) anyerror!void {
    for (instructions) |instruction| {
        self.context.* = .{ .offset = instruction.span.start };
        try self.tick();
        const id = instruction.id;
        const offset = instruction.span.start;
        switch (instruction.value) {
            .let => |binding| {
                const value = switch (binding.value) {
                    .expression => |input| try self.expression(input),
                    .select => |input| try self.select(input),
                    else => return error.ApplicationHostUnavailable,
                };
                const phys = try self.physical(id);
                for (self.obligations, 0..) |ob, idx| if (ob.target == .binding and std.mem.eql(u8, ob.target.binding, binding.name)) {
                    self.obligation_used[idx] = true;
                    const err_offset = if (binding.value == .expression) binding.value.expression.span.start else offset;
                    try self.checkObligation(ob, value, phys, err_offset);
                };
                try self.symbols.append(self.scratch, .{ .name = binding.name, .value = value });
                try self.node(id, offset, "binding", value);
                const resource = if (binding.value == .select) try self.catalog.findResourceQualified(binding.value.select.schema, binding.value.select.target) else null;
                try self.event(if (resource != null) .read else .let, id, offset, resource, &.{});
            },
            .require => |input| {
                try self.condition(input.condition);
                try self.event(.require, id, offset, null, &.{});
            },
            .atomic => |body| {
                try self.event(.atomic_begin, id, offset, null, &.{});
                const count = self.symbols.items.len;
                try self.block(body);
                self.symbols.shrinkRetainingCapacity(count);
                try self.event(.atomic_end, id, offset, null, &.{});
            },
            .conditional => |input| {
                try self.condition(input.condition);
                try self.event(.branch_begin, id, offset, null, &.{});
                const count = self.symbols.items.len;
                try self.block(input.yes);
                self.symbols.shrinkRetainingCapacity(count);
                try self.event(.branch_else, id, offset, null, &.{});
                try self.block(input.no);
                self.symbols.shrinkRetainingCapacity(count);
                try self.event(.branch_end, id, offset, null, &.{});
            },
            .insert => |input| try self.event(.insert, id, offset, try self.write(input.target_schema, input.target, input.values), input.values),
            .append => |input| try self.event(.append, id, offset, try self.write(input.target_schema, input.target, input.values), input.values),
            else => return error.ApplicationHostUnavailable,
        }
    }
}
