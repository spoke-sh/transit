//! Finite relational execution over explicitly retained direct Table pins.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Memory = @import("root.zig").QueryMemory;
const Self = @This();
const Run = e.Execution(*q.DirectRelationalTables, *q.RelationalSpill);
pub const Consistency = q.catalog.ManagedTableRecords.Consistency;
pub const Options = q.catalog.ManagedTableRecords.Options;
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
    return openBoundPreparedRetained(allocator, io, directory, spill_name, client, prepared, &.{}, snapshots, options, cancellation);
}
pub fn openBoundPreparedRetained(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, spill_name: []const u8, client: q.catalog.DirectTableClient, prepared: *const q.DirectRelationalCompilation, values: []const ?f.Types.Values.Atom, snapshots: []const q.catalog.DirectTableProtocol.Snapshot, options: Options, cancellation: ?*const std.atomic.Value(bool)) !*Self {
    if (snapshots.len > r.max_sources) return error.InvalidRelationalSources;
    var pins: [r.max_sources]q.DirectRelationalTables.SourcePin = undefined;
    for (snapshots, pins[0..snapshots.len]) |snapshot, *pin| pin.* = .{ .table = snapshot };
    return openBoundPreparedPins(allocator, io, directory, spill_name, client, prepared, values, pins[0..snapshots.len], options, cancellation);
}
pub fn openBoundPreparedPins(allocator: std.mem.Allocator, io: std.Io, directory: std.Io.Dir, spill_name: []const u8, client: q.catalog.DirectTableClient, prepared: *const q.DirectRelationalCompilation, values: []const ?f.Types.Values.Atom, pins: []const q.DirectRelationalTables.SourcePin, options: Options, cancellation: ?*const std.atomic.Value(bool)) !*Self {
    try options.requireClient(client);
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests < 2 or options.spill_work == 0) return error.InvalidQueryBudget;
    if (pins.len != prepared.plan.sources.len) return error.InvalidRelationalSources;
    try prepared.validateBindings(client);
    for (pins, prepared.bindings[0..pins.len], prepared.streams[0..pins.len]) |pin, binding, stream_source| {
        switch (pin) {
            .table => |snapshot| {
                if (stream_source != null or !std.meta.eql(snapshot.object, binding.interpretation.interpretation.object)) return error.RelationalSourceChanged;
            },
            .stream => |stream_pin| {
                const expected = stream_source orelse return error.RelationalSourceChanged;
                if (stream_pin.namespace != binding.namespace or
                    !std.meta.eql(stream_pin.receipt.request.target.interpretation, binding.interpretation.interpretation) or
                    stream_pin.receipt.request.target.partition != expected.slice.partition)
                {
                    return error.RelationalSourceChanged;
                }
            },
        }
    }
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    const owned = self.memory.allocator();
    self.owned = try prepared.bindValues(owned, values);
    errdefer self.owned.deinit();
    self.owned.plan.budgets = options.budgets;
    self.owned.plan.lifetime = .interactive;
    var adjusted_pins: [r.max_sources]q.DirectRelationalTables.SourcePin = undefined;
    for (pins, adjusted_pins[0..pins.len], 0..) |pin, *out, i| {
        out.* = pin;
        if (out.* == .stream) {
            const declared = prepared.streams[i].?.definition.stored.declaration.limits;
            out.stream.limits = .{
                .rows = @min(1000, declared.read_rows),
                .encoded_bytes = @min(1024 * 1024, declared.read_bytes),
            };
            out.stream.include_tombstones = if (q.DirectStreamSliceScan.tombstoneColumnId(self.owned.plan.sources[i].schema)) |tomb_id|
                self.owned.plan.referencesColumn(@intCast(i), tomb_id)
            else
                false;
        }
    }
    self.tables = try q.DirectRelationalTables.openPinsProjectedAt(owned, client, adjusted_pins[0..pins.len], self.owned.plan.sources, options.requests - 2, cancellation, prepared.catalog, prepared.projections[0..pins.len]);
    errdefer self.tables.deinit();
    self.tables.projection = try e.Projection.init(self.owned.plan);
    for (prepared.bindings[0..pins.len], self.tables.scans[0..pins.len], self.tables.stream_scans[0..pins.len]) |binding, scan, stream_scan| {
        if (scan) |table_scan| {
            if (!std.meta.eql(binding.interpretation, table_scan.reader.basis.interpretation)) return error.RelationalSourceChanged;
        } else if (stream_scan) |s_scan| {
            if (!std.meta.eql(binding.interpretation.interpretation, s_scan.receipt.request.target.interpretation)) return error.RelationalSourceChanged;
        } else return error.RelationalSourceChanged;
    }
    const bound: r.Bound = .{ .plan = self.owned.plan, .cuts = self.tables.cuts[0..pins.len] };
    self.spill = try q.RelationalSpill.open(owned, io, directory, spill_name, bound, options.spill_work, cancellation);
    errdefer self.spill.deinit();
    self.execution = try Run.init(owned, bound, &self.tables, &self.spill);
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
        .row => |returned| {
            var row = returned;
            errdefer row.deinit();
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
    self.execution.deinit();
    self.spill.deinit();
    self.tables.deinit();
    self.owned.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}
