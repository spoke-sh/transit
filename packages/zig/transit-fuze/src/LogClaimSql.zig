//! Pure Queue acquisition preparation. A predicate and maximum select work
//! before leases are created; neither is a filter/limit on an accepted claim.
const std = @import("std");
const f = @import("root.zig");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Predicate = @import("SqlLogicalPredicate.zig");
const Shared = @import("LogReadSql.zig");
const Operand = Shared.Operand;
const Field = f.WorkloadProjection.Field;
const Atom = f.Types.Values.Atom;

fn header(parser: *Parser) !f.TableSelect.Syntax {
    try parser.requireWord("CLAIM");
    return f.TableSelect.rowHeader(parser);
}
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Reference {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return (try header(&parser)).subject;
}

pub const Prepared = struct {
    template: f.LogicalPrepared,
    schema: f.TableSchema.Owned,
    fields: []const Field,
    lease: Operand,
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
        try parser.requireWord("WITH");
        try parser.requireWord("LEASE");
        var parameters: std.ArrayList(f.LogicalPrepared.Parameter) = .empty;
        const lease = try Operand.parse(&parser, &parameters, error.InvalidLogClaimOperand);
        const wait = if (try parser.takeWord("WAIT")) try Operand.parse(&parser, &parameters, error.InvalidLogClaimOperand) else null;
        try parser.finish();
        const fields = try Shared.input(a, owned.schema, &syntax, location, .queue);
        const input = try f.WorkloadProjection.schemaLayout(owned.schema, fields, .claim);
        var diagnostic: f.Sql.Binding = .{};
        const template = f.LogicalPrepared.adoptSyntax(allocator, &arena, syntax, syntax.subject.name, input.typeOf(), try owned.schema.fingerprint(), parameters.items, &diagnostic) catch |err| {
            if (location) |at| if (diagnostic.location) |where| {
                at.* = where;
            };
            return err;
        };
        return .{ .template = template, .schema = owned, .fields = fields, .lease = lease, .wait = wait };
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
        const maximum: ?u32 = if (plan.plan.limit) |limit| blk: {
            const value = std.math.cast(u32, limit) orelse return error.InvalidLogClaimMaximum;
            if (value == 0) return error.InvalidLogClaimMaximum;
            break :blk value;
        } else null;
        // This is an acquisition budget. Keeping it in the output plan would
        // allow result delivery to hide rows whose leases were already accepted.
        plan.plan.limit = null;
        const lease_ms = blk: {
            errdefer self.lease.at(diagnostic);
            break :blk try Shared.leaseDuration(try self.lease.bind(values));
        };
        const wait_ms = if (self.wait) |operand| blk: {
            errdefer operand.at(diagnostic);
            break :blk try Shared.waitDuration(try operand.bind(values));
        } else null;
        const layout = try f.WorkloadProjection.schemaLayout(self.schema.schema, self.fields, .claim);
        plan.plan.collations = layout.collations;
        try plan.plan.validate();
        return .{ .allocator = allocator, .plan = plan, .fields = try allocator.dupe(Field, self.fields), .maximum = maximum, .lease_ms = lease_ms, .wait_ms = wait_ms };
    }
};

pub const Bound = struct {
    allocator: std.mem.Allocator,
    /// A typed selection plan for the native acquisition owner. It must never
    /// be used to post-filter a previously accepted Queue claim.
    plan: f.LogicalPlanCodec.Owned,
    fields: []const Field,
    maximum: ?u32,
    lease_ms: u64,
    wait_ms: ?u32,
    pub fn deinit(self: *Bound) void {
        self.plan.deinit();
        self.allocator.free(self.fields);
        self.* = undefined;
    }
};

const test_columns = [_]f.TableSchema.Column{
    .{ .id = 3, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 9, .name = "body", .type = .utf8, .nullable = true, .collation = .ascii_ci },
};
const test_schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 10, .columns = &test_columns, .primary_key = &.{} };

fn claimOwned(allocator: std.mem.Allocator) !void {
    const t = std.testing;
    var text = "CLAIM q.id AS task_id, _lease_epoch, _attempt FROM tasks AS q WHERE body = $1 AND _partition = $2 LIMIT $3 WITH LEASE $4 WAIT $5".*;
    var prepared = try Prepared.init(allocator, &text, test_schema, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    @memset(&text, 0);
    try t.expectEqualSlices(f.Types.Type, &.{ .utf8, .uint64, .uint64, .utf8, .utf8 }, prepared.parameterTypes());
    var body = "MiXeD".*;
    var bound = try prepared.bind(allocator, &.{ .{ .bytes = &body }, .{ .unsigned = 2 }, .{ .unsigned = 1 }, .{ .bytes = "30s" }, .{ .bytes = "250ms" } }, null);
    defer bound.deinit();
    prepared.deinit();
    live = false;
    @memset(&body, 0);
    try t.expectEqual(@as(?u32, 1), bound.maximum);
    try t.expectEqual(@as(u64, 30000), bound.lease_ms);
    try t.expectEqual(@as(?u32, 250), bound.wait_ms);
    try t.expect(bound.plan.plan.limit == null);
    try t.expectEqualStrings("task_id", bound.plan.plan.output_names[0].?);
    try t.expectEqualSlices(Field, &.{ .{ .column = 3 }, .lease_epoch, .attempt, .{ .column = 9 }, .partition }, bound.fields);
    var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
    for (0..3) |i| try t.expect(try bound.plan.plan.matches(&.{
        .{ .value = .{ .atom = .{ .signed = @intCast(i) } } },
        .{ .value = .{ .atom = .{ .unsigned = 19 } } },
        .{ .value = .{ .atom = .{ .unsigned = 2 } } },
        .{ .value = .{ .atom = .{ .bytes = "mixed" } } },
        .{ .value = .{ .atom = .{ .unsigned = 2 } } },
    }, &failure));
}

test "log claim SQL owns its acquisition predicate and separates the lease maximum" {
    try claimOwned(std.testing.allocator);
    // Arena growth can resize in place in only some failure schedules. Disable
    // that optimization while enumerating allocation failures; the ordinary
    // allocator path is independently exercised above.
    var no_resize = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    try std.testing.checkAllAllocationFailures(no_resize.allocator(), claimOwned, .{});
}

test "log claim SQL defaults its maximum without limiting original result delivery" {
    const t = std.testing;
    var prepared = try Prepared.init(t.allocator, "CLAIM * FROM tasks WHERE _offset >= 10 WITH LEASE '1s'", test_schema, .transit, null);
    defer prepared.deinit();
    var bound = try prepared.bind(t.allocator, &.{}, null);
    defer bound.deinit();
    try t.expect(bound.maximum == null and bound.wait_ms == null and bound.plan.plan.limit == null);
    try t.expectEqualSlices(Field, &.{ .{ .column = 3 }, .{ .column = 9 }, .offset }, bound.fields);
    try t.expectEqualSlices(u8, &.{ 0, 1 }, bound.plan.plan.projection);
    var mysql = try Prepared.init(t.allocator, "CLAIM `id` FROM `tasks` WHERE id = ? LIMIT ? WITH LEASE ? WAIT ?", test_schema, .mysql, null);
    defer mysql.deinit();
    try t.expectEqualSlices(f.Types.Type, &.{ .int64, .uint64, .utf8, .utf8 }, mysql.parameterTypes());
}

test "log claim SQL refuses generated acquisition predicates and invalid budgets" {
    const t = std.testing;
    for ([_][]const u8{ "CLAIM id FROM tasks WHERE _lease_epoch = 1 WITH LEASE '1s'", "CLAIM id FROM tasks WHERE _attempt > 2 WITH LEASE '1s'" }) |text| {
        try t.expectError(error.InvalidLogClaimPredicate, Prepared.init(t.allocator, text, test_schema, .transit, null));
    }
    try t.expectError(error.ParameterTypeConflict, Prepared.init(t.allocator, "CLAIM id FROM tasks WHERE id = $1 WITH LEASE $1", test_schema, .transit, null));
    var prepared = try Prepared.init(t.allocator, "CLAIM id FROM tasks LIMIT $1 WITH LEASE $2 WAIT $3", test_schema, .transit, null);
    defer prepared.deinit();
    for ([_]u64{ 0, 4294967296 }) |maximum| try t.expectError(error.InvalidLogClaimMaximum, prepared.bind(t.allocator, &.{ .{ .unsigned = maximum }, .{ .bytes = "1s" }, .{ .bytes = "1ms" } }, null));
    try t.expectError(error.NullLimitParameter, prepared.bind(t.allocator, &.{ null, .{ .bytes = "1s" }, .{ .bytes = "1ms" } }, null));
    try t.expectError(error.NullWorkloadParameter, prepared.bind(t.allocator, &.{ .{ .unsigned = 1 }, null, .{ .bytes = "1ms" } }, null));
    for ([_][]const u8{ "", "0ms", "-1s", "1.5s", "18446744073709551616ms", "18446744073709551615m" }) |lease| {
        var diagnostic: f.Sql.Binding = .{};
        try t.expectError(error.InvalidLogLeaseDuration, prepared.bind(t.allocator, &.{ .{ .unsigned = 1 }, .{ .bytes = lease }, .{ .bytes = "1ms" } }, &diagnostic));
        try t.expectEqual(@as(?u32, 2), diagnostic.parameter);
        try t.expect(diagnostic.location != null);
    }
    for ([_][]const u8{
        "CLAIM id FROM tasks",
        "CLAIM COUNT(*) FROM tasks WITH LEASE '1s'",
        "CLAIM id FROM tasks GROUP 'workers' WITH LEASE '1s'",
        "CLAIM id FROM tasks ORDER BY id WITH LEASE '1s'",
        "CLAIM _receipt_handle FROM tasks WITH LEASE '1s'",
        "CLAIM id FROM tasks WITH LEASE '1s'; CLAIM id FROM tasks WITH LEASE '1s'",
    }) |text| {
        if (Prepared.init(t.allocator, text, test_schema, .transit, null)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.TestUnexpectedResult;
        } else |_| {}
    }
}
