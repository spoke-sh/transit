//! Finite relational execution over explicitly retained direct Table pins.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Memory = @import("QueryMemory.zig");
const Self = @This();
const Run = e.Execution(*q.DirectRelationalTables, *q.RelationalSpill);
pub const Options = q.RelationalQuery.Options;
parent: std.mem.Allocator,
memory: Memory,
owned: f.RelationalCodec.Owned,
tables: q.DirectRelationalTables,
spill: q.RelationalSpill,
execution: Run,
complete: bool = false,
failed: bool = false,
pub const resident_base = @sizeOf(Self) + 4 * @sizeOf(q.DirectRelationalTables) + Run.residentBytes + q.RelationalSpill.resident_bytes + 4 * f.TableSchema.max_bytes + 2 * f.TableRow.max_bytes;

/// Owns the plan and local traversal/spill state, borrowing only transport and
/// cancellation. The original durable pins remain the caller's responsibility.
pub fn openPreparedRetained(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, spill_name: []const u8, client: q.catalog.DirectTableClient, prepared: *const q.DirectRelationalCompilation, snapshots: []const q.catalog.DirectTableProtocol.Snapshot, options: Options, cancellation: ?*const std.atomic.Value(bool)) !*Self {
    if (options.consistency != .independent_table_snapshots) return error.UnsupportedRelationalConsistency;
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests < 2 or options.spill_work == 0) return error.InvalidQueryBudget;
    if (snapshots.len != prepared.plan.sources.len) return error.InvalidRelationalSources;
    try prepared.validateBindings(client);
    for (snapshots, prepared.bindings[0..snapshots.len]) |snapshot, binding| if (!std.meta.eql(snapshot.object, binding.interpretation.interpretation.object)) return error.RelationalSourceChanged;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    const owned = self.memory.allocator();
    const bytes = try owned.alloc(u8, f.RelationalCodec.max_bytes);
    defer owned.free(bytes);
    self.owned = try f.RelationalCodec.decode(owned, try f.RelationalCodec.encode(prepared.plan, bytes));
    errdefer self.owned.deinit();
    self.owned.plan.budgets = options.budgets;
    self.owned.plan.lifetime = .interactive;
    self.tables = try q.DirectRelationalTables.open(owned, client, snapshots, self.owned.plan.sources, options.requests - 2, cancellation);
    errdefer self.tables.deinit();
    for (prepared.bindings[0..snapshots.len], self.tables.scans[0..snapshots.len]) |binding, scan| {
        if (!std.meta.eql(binding.interpretation, scan.?.reader.basis.interpretation)) return error.RelationalSourceChanged;
    }
    const bound: r.Bound = .{ .plan = self.owned.plan, .cuts = self.tables.cuts[0..snapshots.len] };
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
        .row => |row| {
            // Include all sources, even an empty join input, in the final
            // authorization check after row buffering and before disclosure.
            try self.tables.validate(self.execution.bound);
            return row;
        },
        .complete => {
            try self.tables.validate(self.execution.bound);
            self.complete = true;
            return null;
        },
    };
}
pub fn close(self: *Self) void {
    self.tables.close();
}
pub fn deinit(self: *Self) void {
    const allocator = self.parent;
    self.spill.deinit();
    self.tables.deinit();
    self.owned.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}
