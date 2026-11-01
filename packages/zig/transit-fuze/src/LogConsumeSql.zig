//! Pure CONSUME preparation. LIMIT remains a logical output bound; it is never
//! converted into an offset span or evidence of completed native coverage.
const std = @import("std");
const f = @import("root.zig");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Predicate = @import("SqlLogicalPredicate.zig");
const Field = f.WorkloadProjection.Field;
const Atom = f.Types.Values.Atom;

fn header(parser: *Parser) !f.TableSelect.Syntax {
    try parser.requireWord("CONSUME");
    return f.TableSelect.rowHeader(parser);
}
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Reference {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return (try header(&parser)).subject;
}

const Operand = union(enum) {
    literal: struct { bytes: []const u8, offset: usize },
    parameter: f.Sql.Parameter,
    fn parse(parser: *Parser, parameters: *std.ArrayList(f.LogicalPrepared.Parameter)) !Operand {
        if (try parser.parameter()) |site| {
            try parameters.append(parser.allocator, .{ .site = site, .type = .utf8 });
            return .{ .parameter = site };
        }
        const literal = try parser.literal(.utf8);
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, .utf8, &failure) catch |err| {
            if (parser.location) |location| location.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) {
            if (parser.location) |location| location.* = .{ .offset = literal.span.start };
            return error.InvalidLogConsumeOperand;
        }
        return .{ .literal = .{ .bytes = cell.value.atom.bytes, .offset = literal.span.start } };
    }
    fn bind(self: Operand, values: []const ?Atom) ![]const u8 {
        return switch (self) {
            .literal => |value| value.bytes,
            .parameter => |site| (values[site.index - 1] orelse return error.NullWorkloadParameter).bytes,
        };
    }
    fn at(self: Operand, diagnostic: ?*f.Sql.Binding) void {
        const detail = diagnostic orelse return;
        switch (self) {
            .literal => |value| detail.location = .{ .offset = value.offset },
            .parameter => |site| {
                detail.location = .{ .offset = site.offset };
                detail.parameter = site.index;
                detail.parameter_sites[0] = site.offset;
                detail.expected = "utf8";
            },
        }
    }
};
fn field(schema: f.TableSchema.Schema, qualifier: []const u8, reference: Reference, location: ?*f.Sql.Location) !Field {
    if (reference.qualifier == null) {
        if (std.mem.eql(u8, reference.name, "_partition")) return .partition;
        if (std.mem.eql(u8, reference.name, "_offset")) return .offset;
    }
    return .{ .column = schema.columns[try reference.resolve(qualifier, schema.columns, location)].id };
}
fn add(fields: *std.ArrayList(Field), allocator: std.mem.Allocator, value: Field) !void {
    for (fields.items) |existing| if (std.meta.eql(existing, value)) return;
    if (fields.items.len == f.TableSchema.max_columns) return error.InvalidProjection;
    try fields.append(allocator, value);
}
fn waitDuration(value: []const u8) !u32 {
    var end: usize = 0;
    while (end < value.len and std.ascii.isDigit(value[end])) : (end += 1) {}
    const multiplier = f.PerfectHash.ComptimeMap(u64, true, .{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "m", 60000 } }).get(value[end..]) orelse return error.InvalidLogWait;
    const number = std.fmt.parseInt(u64, value[0..end], 10) catch return error.InvalidLogWait;
    if (number == 0) return error.InvalidLogWait;
    return std.math.cast(u32, std.math.mul(u64, number, multiplier) catch return error.InvalidLogWait) orelse error.InvalidLogWait;
}

pub const Prepared = struct {
    template: f.LogicalPrepared,
    schema: f.TableSchema.Owned,
    fields: []const Field,
    group: ?Operand,
    wait: ?Operand,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, schema: f.TableSchema.Schema, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Prepared {
        try f.Sql.validateText(text);
        var owned = try schema.clone(allocator);
        errdefer owned.deinit();
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var parser = try Parser.initDialect(a, try a.dupe(u8, text), location, true, dialect);
        var syntax = try header(&parser);
        var parameters: std.ArrayList(f.LogicalPrepared.Parameter) = .empty;
        const group = if (try parser.takeWord("GROUP")) try Operand.parse(&parser, &parameters) else null;
        if (try parser.takeWord("WHERE")) syntax.predicate = try Predicate.syntax(&parser, null, syntax.qualifier, error.UnsupportedConstruct);
        if (try parser.takeWord("LIMIT")) {
            if (try parser.parameter()) |site| {
                syntax.limit_parameter = site;
            } else {
                if (parser.token.tag != .integer) return error.InvalidSqlSyntax;
                syntax.limit = std.fmt.parseInt(u64, parser.token.text, 10) catch return error.LiteralOutOfRange;
                try parser.advance();
            }
        }
        const wait = if (try parser.takeWord("WAIT")) try Operand.parse(&parser, &parameters) else null;
        try parser.finish();
        var fields: std.ArrayList(Field) = .empty;
        if (syntax.selection.star) {
            // Predicate-only metadata belongs to the input layout, never to
            // application-column star expansion. Freeze that expansion first.
            syntax.selection.star = false;
            syntax.selection.count = owned.schema.columns.len;
            for (owned.schema.columns, 0..) |column, i| {
                try add(&fields, a, .{ .column = column.id });
                syntax.selection.items[i] = .{ .column = .{
                    .name = try a.dupe(u8, column.name),
                    .span = syntax.subject.span,
                    .qualifier = syntax.qualifier,
                }, .alias = null };
            }
        } else for (syntax.selection.items[0..syntax.selection.count]) |item| try add(&fields, a, try field(owned.schema, syntax.qualifier, item.column, location));
        if (syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
            if (instruction == .atom) switch (instruction.atom) {
                inline else => |atom| try add(&fields, a, try field(owned.schema, syntax.qualifier, atom.column, location)),
            };
        };
        const input = try f.WorkloadProjection.schemaLayout(owned.schema, fields.items, .rows);
        var diagnostic: f.Sql.Binding = .{};
        const template = f.LogicalPrepared.adoptSyntax(allocator, &arena, syntax, syntax.subject.name, input.typeOf(), try owned.schema.fingerprint(), parameters.items, &diagnostic) catch |err| {
            if (location) |at| {
                if (diagnostic.location) |where| at.* = where;
            }
            return err;
        };
        return .{ .template = template, .schema = owned, .fields = fields.items, .group = group, .wait = wait };
    }
    pub fn deinit(self: *Prepared) void {
        self.template.deinit();
        self.schema.deinit();
        self.* = undefined;
    }
    pub fn parameterTypes(self: *const Prepared) []const f.Types.Type {
        return self.template.parameterTypes();
    }
    pub fn bind(self: *const Prepared, allocator: std.mem.Allocator, values: []const ?Atom, diagnostic: ?*f.Sql.Binding) !Bound {
        var plan = try self.template.bind(allocator, self.template.name, self.template.descriptor.type, self.template.basis, values, diagnostic);
        errdefer plan.deinit();
        const group = if (self.group) |operand| blk: {
            errdefer operand.at(diagnostic);
            const name = try operand.bind(values);
            if (name.len == 0) return error.InvalidLogGroupName;
            break :blk name;
        } else null;
        const wait_ms = if (self.wait) |operand| blk: {
            errdefer operand.at(diagnostic);
            break :blk try waitDuration(try operand.bind(values));
        } else null;
        const layout = try f.WorkloadProjection.schemaLayout(self.schema.schema, self.fields, .rows);
        plan.plan.collations = layout.collations;
        try plan.plan.validate();
        const fields = try allocator.dupe(Field, self.fields);
        errdefer allocator.free(fields);
        return .{ .allocator = allocator, .plan = plan, .fields = fields, .group = if (group) |name| try allocator.dupe(u8, name) else null, .wait_ms = wait_ms };
    }
};
pub const Bound = struct {
    allocator: std.mem.Allocator,
    plan: f.LogicalPlanCodec.Owned,
    fields: []const Field,
    group: ?[]const u8,
    wait_ms: ?u32,
    pub fn deinit(self: *Bound) void {
        self.plan.deinit();
        self.allocator.free(self.fields);
        if (self.group) |name| self.allocator.free(name);
        self.* = undefined;
    }
};

const test_columns = [_]f.TableSchema.Column{
    .{ .id = 3, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 9, .name = "body", .type = .utf8, .nullable = true, .collation = .ascii_ci },
};
const test_schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 10, .columns = &test_columns, .primary_key = &.{} };

fn consumeOwned(allocator: std.mem.Allocator) !void {
    const t = std.testing;
    var text = "CONSUME e.id AS event_id, _offset FROM events AS e GROUP $1 WHERE body = $2 AND _partition = $3 LIMIT $4 WAIT $5".*;
    var prepared = try Prepared.init(allocator, &text, test_schema, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    @memset(&text, 0);
    try t.expectEqualSlices(f.Types.Type, &.{ .utf8, .utf8, .uint64, .uint64, .utf8 }, prepared.parameterTypes());
    var group = "billing".*;
    var body = "MiXeD".*;
    var bound = try prepared.bind(allocator, &.{ .{ .bytes = &group }, .{ .bytes = &body }, .{ .unsigned = 2 }, .{ .unsigned = 10 }, .{ .bytes = "250ms" } }, null);
    defer bound.deinit();
    prepared.deinit();
    live = false;
    @memset(&group, 0);
    @memset(&body, 0);
    try t.expectEqualStrings("billing", bound.group.?);
    try t.expectEqual(@as(?u32, 250), bound.wait_ms);
    try t.expectEqual(@as(?u64, 10), bound.plan.plan.limit);
    try t.expectEqualStrings("event_id", bound.plan.plan.output_names[0].?);
    try t.expectEqualSlices(u8, &.{ 0, 1 }, bound.plan.plan.projection);
    try t.expectEqualSlices(Field, &.{ .{ .column = 3 }, .offset, .{ .column = 9 }, .partition }, bound.fields);
    var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
    try t.expect(try bound.plan.plan.matches(&.{
        .{ .value = .{ .atom = .{ .signed = 23 } } },
        .{ .value = .{ .atom = .{ .unsigned = 1234 } } },
        .{ .value = .{ .atom = .{ .bytes = "mixed" } } },
        .{ .value = .{ .atom = .{ .unsigned = 2 } } },
    }, &failure));
}

test "log consume SQL owns typed projection predicate group and wait operands" {
    try consumeOwned(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, consumeOwned, .{});
}

test "log consume SQL star excludes predicate metadata and keeps finite output limits" {
    const t = std.testing;
    var prepared = try Prepared.init(t.allocator, "CONSUME * FROM events WHERE _offset >= 1000 LIMIT 3", test_schema, .transit, null);
    defer prepared.deinit();
    var bound = try prepared.bind(t.allocator, &.{}, null);
    defer bound.deinit();
    try t.expectEqualSlices(Field, &.{ .{ .column = 3 }, .{ .column = 9 }, .offset }, bound.fields);
    try t.expectEqualSlices(u8, &.{ 0, 1 }, bound.plan.plan.projection);
    try t.expectEqual(@as(?u64, 3), bound.plan.plan.limit);
    try t.expect(bound.group == null and bound.wait_ms == null);
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const output = try bound.plan.plan.outputSchema(&fields);
    try t.expectEqual(@as(usize, 2), output.structure.len);
    try t.expectEqualStrings("body", output.structure[1].name);
    var mysql = try Prepared.init(t.allocator, "CONSUME `id` FROM `events` GROUP ? WHERE id = ? LIMIT ? WAIT ?", test_schema, .mysql, null);
    defer mysql.deinit();
    try t.expectEqualSlices(f.Types.Type, &.{ .utf8, .int64, .uint64, .utf8 }, mysql.parameterTypes());
}

test "log consume SQL refuses conflicting parameters malformed waits and unsafe shapes" {
    const t = std.testing;
    try t.expectError(error.ParameterTypeConflict, Prepared.init(t.allocator, "CONSUME id FROM events GROUP $1 WHERE id = $1", test_schema, .transit, null));
    try t.expectError(error.ParameterGap, Prepared.init(t.allocator, "CONSUME id FROM events GROUP $2", test_schema, .transit, null));
    var prepared = try Prepared.init(t.allocator, "CONSUME id FROM events GROUP $1 LIMIT $2 WAIT $3", test_schema, .transit, null);
    defer prepared.deinit();
    try t.expectError(error.NullWorkloadParameter, prepared.bind(t.allocator, &.{ null, .{ .unsigned = 1 }, .{ .bytes = "1s" } }, null));
    try t.expectError(error.NullLimitParameter, prepared.bind(t.allocator, &.{ .{ .bytes = "group" }, null, .{ .bytes = "1s" } }, null));
    try t.expectError(error.InvalidLogGroupName, prepared.bind(t.allocator, &.{ .{ .bytes = "" }, .{ .unsigned = 1 }, .{ .bytes = "1s" } }, null));
    for ([_][]const u8{ "", "ms", "0ms", "-1s", "1.5s", "1d", "4294967296ms", "18446744073709551615m" }) |wait| {
        var diagnostic: f.Sql.Binding = .{};
        try t.expectError(error.InvalidLogWait, prepared.bind(t.allocator, &.{ .{ .bytes = "group" }, .{ .unsigned = 1 }, .{ .bytes = wait } }, &diagnostic));
        try t.expectEqual(@as(?u32, 3), diagnostic.parameter);
        try t.expect(diagnostic.location != null);
    }
    for ([_][]const u8{
        "CONSUME COUNT(*) FROM events",
        "CONSUME id FROM (SELECT id FROM events)",
        "CONSUME id FROM events JOIN other ON id = id",
        "CONSUME id FROM events ORDER BY id",
        "CONSUME id FROM events WHERE id = 1 GROUP 'late'",
        "CONSUME _lease_epoch FROM events",
        "CONSUME _timestamp FROM events",
        "CONSUME id FROM events; CONSUME id FROM events",
        "CONSUME id, id FROM events",
        "CONSUME wrong.id FROM events",
    }) |sql| {
        if (Prepared.init(t.allocator, sql, test_schema, .transit, null)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}
