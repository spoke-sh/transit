//! Current-authority inspection over an explicit source scope. No data snapshot,
//! query namespace, request upload or admission is created by this operation.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const v = q.Values;
const a = q.document.JsonValues;
const Allocator = std.mem.Allocator;
pub const Scope = struct { name: []const u8, source: v.Source, limits: v.Limits };
pub const Request = struct { scope: Scope, sql: []const u8 };
pub const Operator = enum { scan, filter, limit, project, count, sum, count_values };
pub const PredicateAtom = union(enum) {
    all,
    state: struct { column: []const u8, value: m.State },
    compare: struct { column: []const u8, op: m.Plan.Comparison, type: m.Type },
};
pub const PredicateInstruction = union(enum) {
    atom: PredicateAtom,
    negate,
    conjunction,
    disjunction,
};
pub const Predicate = union(enum) {
    pub const json_schema_sequence_bounds = .{ .program = m.PredicateProgram.max_instructions };
    all,
    state: @FieldType(PredicateAtom, "state"),
    compare: @FieldType(PredicateAtom, "compare"),
    program: []const PredicateInstruction,
};
fn inspectAtom(allocator: Allocator, atom: m.Plan.Atom, schema: m.Schema) !PredicateAtom {
    return switch (atom) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = try allocator.dupe(u8, (try schema.column(state.column)).name.slice()), .value = state.value } },
        .compare => |comparison| .{ .compare = .{ .column = try allocator.dupe(u8, (try schema.column(comparison.column)).name.slice()), .op = comparison.op, .type = std.meta.activeTag(comparison.value) } },
    };
}
fn inspectPredicate(allocator: Allocator, predicate: m.Plan.Predicate, schema: m.Schema) !Predicate {
    return switch (predicate) {
        .program => |*program| blk: {
            const view = try program.view();
            const result = try allocator.alloc(PredicateInstruction, view.instructions.len);
            for (view.instructions, result) |instruction, *out| out.* = switch (instruction) {
                .atom => |atom| .{ .atom = try inspectAtom(allocator, atom, schema) },
                inline else => |_, tag| @unionInit(PredicateInstruction, @tagName(tag), {}),
            };
            break :blk .{ .program = result };
        },
        inline else => |value, tag| switch (try inspectAtom(allocator, @unionInit(m.Plan.Atom, @tagName(tag), value), schema)) {
            inline else => |atom_value, atom_tag| @unionInit(Predicate, @tagName(atom_tag), atom_value),
        },
    };
}
pub const Explanation = struct {
    operators: []const Operator,
    predicate: Predicate,
    projection: []const []const u8,
    limit: ?[]const u8,
    aggregate: m.Plan.Aggregate,
    columns: []const v.Column,
    budgets: v.Limits,
};
pub const Details = union(enum) {
    description: struct { columns: []const v.Column },
    tables: []const []const u8,
    explanation: Explanation,
};
pub const Result = struct {
    version: u8 = 1,
    scope: enum { configured_source } = .configured_source,
    name: []const u8,
    resource: u64,
    source_kind: m.SourceKind,
    contract: [32]u8,
    schema: [32]u8,
    resource_revision: u64,
    policy_revision: []const u8,
    details: Details,
};
/// Slices belong to the supplied result arena. The generic client boundary also
/// lets tests assert that failures never call an execution/admission interface.
pub fn apply(allocator: Allocator, client: anytype, request: Request) !Result {
    return applyDiagnostic(allocator, client, request, null);
}
pub fn applyDiagnostic(allocator: Allocator, client: anytype, request: Request, detail: ?*q.fuze.Sql.Binding) !Result {
    if (detail) |value| value.* = .{};
    const definition = try request.scope.source.native(allocator);
    const name = try m.Name.init(request.scope.name);
    const limits = try request.scope.limits.native();
    _ = try client.describe(definition);
    var location: q.fuze.Sql.Location = .{ .offset = 0 };
    const ast = (q.fuze.Sql.parseInspectionLocated(request.sql, &location) catch |err| {
        if (detail) |value| value.location = location;
        return err;
    }) orelse return error.UnsupportedStatement;
    var columns: [m.max_columns]m.Column = undefined;
    const schema = try definition.schema(&columns);
    const details: Details = switch (ast) {
        .describe => |target| blk: {
            if (!std.mem.eql(u8, target.slice(), name.slice())) {
                if (detail) |value| {
                    value.subject = target;
                    @memcpy(value.scope[0..name.slice().len], name.slice());
                    value.scope_len = name.slice().len;
                }
                return error.UnknownSource;
            }
            break :blk .{ .description = .{ .columns = try v.foreignColumns(allocator, schema) } };
        },
        .show => |catalog| blk: {
            if (catalog != .tables) return error.UnsupportedCatalog;
            const names = try allocator.alloc([]const u8, if (definition.source == .table) 1 else 0);
            if (names.len != 0) names[0] = try allocator.dupe(u8, name.slice());
            break :blk .{ .tables = names };
        },
        .explain => |select| .{ .explanation = try explain(allocator, try m.Sql.compileDiagnostic(allocator, select, .{ .name = name, .schema = schema }, detail), schema, limits) },
    };
    const current = try client.describe(definition);
    if (details == .explanation and !current.limits.permits(limits)) return error.QueryBudgetExceeded;
    return .{
        .name = try allocator.dupe(u8, name.slice()),
        .resource = definition.resource,
        .source_kind = std.meta.activeTag(definition.source),
        .contract = try definition.fingerprint(),
        .schema = try schema.fingerprint(),
        .resource_revision = current.resource_revision,
        .policy_revision = try a.decimal(allocator, current.policy_revision),
        .details = details,
    };
}
fn explain(allocator: Allocator, plan: m.Plan, schema: m.Schema, limits: q.Bundle.Limits) !Explanation {
    var output: [m.max_columns]m.Column = undefined;
    const output_schema = try plan.outputSchema(schema, &output);
    var operators: [4]Operator = undefined;
    var count: usize = 1;
    operators[0] = .scan;
    if (plan.predicate != .all) {
        operators[count] = .filter;
        count += 1;
    }
    if (plan.limit != null) {
        operators[count] = .limit;
        count += 1;
    }
    operators[count] = switch (plan.aggregate) {
        .rows => .project,
        .count => .count,
        .count_values => .count_values,
        .sum => .sum,
    };
    count += 1;
    const projection = try allocator.alloc([]const u8, plan.projection.len);
    for (plan.projection, projection) |index, *target| target.* = try allocator.dupe(u8, (try schema.column(index)).name.slice());
    return .{
        .operators = try allocator.dupe(Operator, operators[0..count]),
        .predicate = try inspectPredicate(allocator, plan.predicate, schema),
        .projection = projection,
        .limit = if (plan.limit) |limit| try a.decimal(allocator, limit) else null,
        .aggregate = plan.aggregate,
        .columns = try v.foreignColumns(allocator, output_schema),
        .budgets = try v.Limits.fromNative(allocator, limits),
    };
}

test "compound explanation preserves instruction order and omits literals" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const schema: m.Schema = .{ .columns = &.{.{ .name = try m.Name.init("label"), .type = .utf8 }} };
    const plan: m.Plan = .{ .projection = &.{0}, .predicate = .{ .program = try .init(&.{
        .{ .atom = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .utf8 = "private-literal" } } } },
        .negate,
        .{ .atom = .{ .state = .{ .column = 0, .value = .null } } },
        .disjunction,
    }) } };
    const value = try explain(arena.allocator(), plan, schema, .{ .pages = 10, .segments = 10, .result_bytes = 1000 });
    try t.expectEqualSlices(Operator, &.{ .scan, .filter, .project }, value.operators);
    try t.expectEqual(4, value.predicate.program.len);
    try t.expectEqualStrings("label", value.predicate.program[0].atom.compare.column);
    try t.expectEqual(m.Type.utf8, value.predicate.program[0].atom.compare.type);
    try t.expect(value.predicate.program[1] == .negate);
    try t.expectEqual(m.State.null, value.predicate.program[2].atom.state.value);
    try t.expect(value.predicate.program[3] == .disjunction);
    const encoded = try std.json.Stringify.valueAlloc(arena.allocator(), value, .{});
    try t.expect(std.mem.indexOf(u8, encoded, "private-literal") == null);
}

const TestClient = struct {
    reads: usize = 0,
    deny_at: ?usize = null,
    shrink_budget: bool = false,
    pub fn describe(self: *@This(), definition: q.SourceDefinition) !q.UnifiedClient.Description {
        self.reads += 1;
        if (self.deny_at == self.reads) return error.QueryDenied;
        return .{ .definition = definition, .resource_revision = 29 + self.reads, .policy_revision = std.math.maxInt(u64), .limits = .{ .pages = if (self.shrink_budget and self.reads > 1) 1 else 100, .segments = 100, .result_bytes = 1048576 }, .active = null };
    }
};
const Fixture = struct { version: u8, scope: Scope, cases: []const struct { sql: []const u8, details: Details } };
test "inspection fixtures share typed lowering and final authority without an execution interface" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fixture = (try std.json.parseFromSlice(Fixture, allocator, @embedFile("fixtures/sql-inspection-v1.json"), .{})).value;
    try t.expectEqual(1, fixture.version);
    for (fixture.cases) |case| {
        var client: TestClient = .{};
        const result = try apply(allocator, &client, .{ .scope = fixture.scope, .sql = case.sql });
        try t.expectEqual(2, client.reads);
        try t.expectEqual(31, result.resource_revision);
        try t.expectEqualStrings("18446744073709551615", result.policy_revision);
        try t.expectEqualStrings(try std.json.Stringify.valueAlloc(allocator, case.details, .{}), try std.json.Stringify.valueAlloc(allocator, result.details, .{}));
        try t.expectEqual(m.SourceKind.table, result.source_kind);
        try t.expectEqual(17, result.resource);
        const encoded = try std.json.Stringify.valueAlloc(allocator, result, .{});
        try t.expect(std.mem.indexOf(u8, encoded, "123456789") == null);
    }
    // Access is checked before resolving a foreign name and after assembling
    // metadata. A client exposing only describe cannot dispatch any command.
    var denied: TestClient = .{ .deny_at = 1 };
    try t.expectError(error.QueryDenied, apply(allocator, &denied, .{ .scope = fixture.scope, .sql = "DESCRIBE private" }));
    var revoked: TestClient = .{ .deny_at = 2 };
    try t.expectError(error.QueryDenied, apply(allocator, &revoked, .{ .scope = fixture.scope, .sql = "SHOW TABLES" }));
    var limited: TestClient = .{ .shrink_budget = true };
    try t.expectError(error.QueryBudgetExceeded, apply(allocator, &limited, .{ .scope = fixture.scope, .sql = "EXPLAIN SELECT * FROM items" }));
    var client: TestClient = .{};
    try t.expectError(error.UnknownSource, apply(allocator, &client, .{ .scope = fixture.scope, .sql = "DESCRIBE private" }));
    try t.expectError(error.UnknownSource, apply(allocator, &client, .{ .scope = fixture.scope, .sql = "EXPLAIN SELECT * FROM private" }));
    try t.expectError(error.UnsupportedCatalog, apply(allocator, &client, .{ .scope = fixture.scope, .sql = "SHOW SOURCES" }));
    var detail: q.fuze.Sql.Binding = .{};
    const invalid: Request = .{ .scope = fixture.scope, .sql = "EXPLAIN SELECT missing FROM items" };
    try t.expectError(error.UnknownColumn, applyDiagnostic(allocator, &client, invalid, &detail));
    const diagnostic = try q.ApiDiagnostic.project(.{ .inspect = invalid }, error.UnknownColumn, detail, false, null);
    try t.expectEqualStrings("sql.unknown_column", diagnostic.code.slice());
    try t.expectEqualStrings("missing", diagnostic.facts[0].?.value.?.text.slice());
    try t.expectEqual(@as(u64, 15), try diagnostic.location.?.offset.value());
    var denied_detail: q.fuze.Sql.Binding = .{};
    var private: TestClient = .{ .deny_at = 1 };
    try t.expectError(error.QueryDenied, applyDiagnostic(allocator, &private, invalid, &denied_detail));
    try t.expect(denied_detail.subject == null and denied_detail.location == null);
    var kv_scope = fixture.scope;
    kv_scope.source.source = .{ .kv = .{ .prefix = "", .key = .{ .type = .utf8 }, .value = .{ .type = .uint64 } } };
    const empty = try apply(allocator, &client, .{ .scope = kv_scope, .sql = "SHOW TABLES" });
    try t.expectEqual(0, empty.details.tables.len);
    const value = try apply(allocator, &client, .{ .scope = kv_scope, .sql = "EXPLAIN SELECT value FROM items WHERE value = '18446744073709551615'::uint64" });
    try t.expectEqual(m.Type.uint64, value.details.explanation.predicate.compare.type);
    const compound_sql = "EXPLAIN SELECT value FROM items WHERE NOT (value = '123456789'::uint64 OR value IS NULL)";
    const compound = try apply(allocator, &client, .{ .scope = kv_scope, .sql = compound_sql });
    const program = compound.details.explanation.predicate.program;
    try t.expectEqual(4, program.len);
    try t.expectEqual(m.Type.uint64, program[0].atom.compare.type);
    try t.expectEqual(m.State.null, program[1].atom.state.value);
    try t.expect(program[2] == .disjunction and program[3] == .negate);
    const inspected = try std.json.Stringify.valueAlloc(allocator, compound, .{});
    try t.expect(std.mem.indexOf(u8, inspected, "123456789") == null);
    var compound_revoked: TestClient = .{ .deny_at = 2 };
    try t.expectError(error.QueryDenied, apply(allocator, &compound_revoked, .{ .scope = kv_scope, .sql = compound_sql }));
}
