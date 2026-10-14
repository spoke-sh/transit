//! Owned interactive relational SQL. The bounded executor, private spill and
//! shared native source vector have one lifetime and one explicit completion.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Memory = @import("QueryMemory.zig");
const Self = @This();
const Run = e.Execution(*q.RelationalTables, *q.RelationalSpill);
pub const Options = struct {
    dialect: f.Sql.Dialect = .transit,
    consistency: q.RelationalTables.Consistency,
    budgets: r.Budgets,
    /// Physical access limits supplement the logical operation budget.
    requests: u64,
    spill_work: u64,
};
parent: std.mem.Allocator,
memory: Memory,
syntax: f.RelationalSql.Owned,
tables: q.RelationalTables,
spill: q.RelationalSpill,
execution: Run,
complete: bool = false,
failed: bool = false,
// Reserve bounded descriptor/codec/source traversal frames separately from all
// owned heap allocations. Transport memory belongs to the caller's Client.
pub const resident_base = @sizeOf(Self) + 4 * @sizeOf(q.RelationalTables) + Run.residentBytes + q.RelationalSpill.resident_bytes + 4 * f.TableSchema.max_bytes + 2 * f.TableRow.max_bytes;

/// clients contains one authorized catalog route per FROM/JOIN target, in SQL
/// order. Supplying the same route twice is explicit and shares a resource pin.
/// The result owns a stable address; clients and spill path borrow the caller.
pub fn open(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, spill_name: []const u8, clients: []const *q.catalog.TableClient, text: []const u8, nonces: [r.max_sources][16]u8, options: Options, cancellation: ?*const std.atomic.Value(bool), location: ?*f.Sql.Location) !*Self {
    if (options.consistency != .per_resource_snapshot_vector) return error.UnsupportedRelationalConsistency;
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests == 0 or options.spill_work == 0) return error.InvalidQueryBudget;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    const owned = self.memory.allocator();
    self.syntax = try f.RelationalSql.parseDialect(owned, text, location, options.dialect);
    errdefer self.syntax.deinit();
    if (clients.len != self.syntax.targets.len) return error.InvalidRelationalSources;
    var resources: usize = 0;
    for (clients, 0..) |client, i| {
        var found = false;
        for (clients[0..i]) |earlier| if (client.connection.scope.resource == earlier.connection.scope.resource) {
            found = true;
        };
        if (!found) resources += 1;
    }
    if (options.budgets.source_pins < resources or options.budgets.source_pins > r.max_sources) return error.InvalidRelationalBudgets;
    var bindings: [r.max_sources]q.RelationalTables.Binding = undefined;
    for (clients, self.syntax.targets, 0..) |client, target, i| bindings[i] = .{ .client = client, .name = try q.catalog.TableMetadata.Name.init(target.name), .alias = target.alias };
    self.tables = try q.RelationalTables.open(owned, bindings[0..clients.len], nonces, options.consistency, options.requests, cancellation);
    errdefer self.tables.deinit();
    const plan = try self.syntax.bind(self.tables.declarations[0..self.tables.count], .interactive, options.budgets, location);
    const bound: r.Bound = .{ .plan = plan, .cuts = self.tables.cuts[0..self.tables.count] };
    self.spill = try q.RelationalSpill.open(io, directory, spill_name, bound, options.spill_work, cancellation);
    errdefer self.spill.deinit();
    self.execution = try Run.init(bound, &self.tables, &self.spill);
    self.complete = false;
    self.failed = false;
    return self;
}
pub fn schema(self: *Self, fields: []f.Types.Field) !f.Types.Type {
    if (self.failed) return error.FailedRelationalQuery;
    try self.tables.validate(self.execution.bound);
    return self.execution.bound.plan.outputSchema(fields);
}
pub fn next(self: *Self) !?e.Output {
    if (self.failed) return error.FailedRelationalQuery;
    errdefer self.failed = true;
    while (true) switch (self.execution.step() catch |err| {
        if (err == error.OutOfMemory and self.memory.exhausted) return error.RelationalResidentBudget;
        return err;
    }) {
        .progress => {},
        .row => |row| return row,
        .complete => {
            self.complete = true;
            return null;
        },
    };
}
pub fn close(self: *Self) !void {
    try self.tables.close();
}
pub fn deinit(self: *Self) void {
    const allocator = self.parent;
    self.spill.deinit();
    self.tables.deinit();
    self.syntax.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}

test "relational owner rejects unsupported consistency and insufficient resident capacity before I/O" {
    const t = std.testing;
    var options: Options = .{ .consistency = .atomic, .budgets = .{ .resident_bytes = resident_base + 1, .spill_bytes = 0, .result_bytes = 1024, .output_rows = 10, .work_steps = 10, .source_pins = 1 }, .requests = 10, .spill_work = 10 };
    try t.expectError(error.UnsupportedRelationalConsistency, open(t.allocator, t.io, .cwd(), "unused", &.{}, "SELECT COUNT(*) FROM t", @splat(@splat(1)), options, null, null));
    options.consistency = .per_resource_snapshot_vector;
    options.budgets.resident_bytes = resident_base;
    try t.expectError(error.RelationalResidentBudget, open(t.allocator, t.io, .cwd(), "unused", &.{}, "SELECT COUNT(*) FROM t", @splat(@splat(1)), options, null, null));
}
