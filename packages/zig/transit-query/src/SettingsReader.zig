//! One authorized page at a time. Optional ordering keeps at most 256 rows;
//! history size does not determine resident memory. Work has an explicit budget.
const std = @import("std");
const q = @import("root.zig");
const C = q.settings.Contract;
const f = q.fuze;
const Cell = f.Types.Values.Cell;
const Self = @This();
allocator: std.mem.Allocator,
client: q.SettingsClient,
plan: *const q.SettingsSql.Owned,
session: q.SettingsSession,
page: ?std.json.Parsed(C.Response) = null,
cursor: ?C.Cursor = null,
index: usize = 0,
started: bool = false,
finished: bool = false,
emitted: u64 = 0,
pages: u64 = 0,
observed_revision: ?u64 = null,
origins: ?bool = null,
arena: std.heap.ArenaAllocator,
ordered: std.array_list.Managed(OwnedRow),
sorted: bool = false,
scalar_ready: bool = false,
scalar_work: f.ScalarProgram.Workspace = .{},
const OwnedRow = struct {
    arena: std.heap.ArenaAllocator,
    cells: []const Cell,
    fn deinit(self: *OwnedRow) void {
        self.arena.deinit();
    }
};
pub fn init(a: std.mem.Allocator, client: q.SettingsClient, plan: *const q.SettingsSql.Owned, session: q.SettingsSession) Self {
    return .{ .allocator = a, .client = client, .plan = plan, .session = session, .arena = .init(a), .ordered = .init(a) };
}
pub fn deinit(self: *Self) void {
    if (self.page) |page| page.deinit();
    for (self.ordered.items) |*row| row.deinit();
    self.ordered.deinit();
    self.arena.deinit();
    self.* = undefined;
}
fn raw(self: *Self) !?[]const Cell {
    _ = self.arena.reset(.retain_capacity);
    const a = self.arena.allocator();
    while (true) {
        if (self.page) |page| switch (page.value.result) {
            .settings => |value| if (self.index < value.rows.len) {
                const row = try self.session.overlay(a, value.rows[self.index]);
                self.index += 1;
                if (self.plan.statement == .show) {
                    if (self.plan.statement.show != null) return try q.SettingsSql.cells(a, .{ .value = row.value });
                    return try q.SettingsSql.cells(a, .{ .name = row.name, .value = row.value, .description = row.description });
                }
                return try q.SettingsSql.cells(a, row);
            },
            .reloads => |value| if (self.index < value.rows.len) {
                const row = value.rows[self.index];
                self.index += 1;
                return try q.SettingsSql.cells(a, row);
            },
            else => return error.InvalidConfigurationResponse,
        };
        if (self.finished) return null;
        if (self.started and self.cursor == null) {
            self.finished = true;
            return null;
        }
        if (self.pages == 10000) return error.ConfigurationReadBudgetExceeded;
        if (self.page) |page| page.deinit();
        self.page = null;
        if (self.origins == null) self.origins = try self.client.canSeeOrigins();
        const action: C.Action = if (self.plan.statement == .show or self.plan.statement.relation == .settings) .{ .settings = .{ .name = if (self.plan.statement == .show) self.plan.statement.show else null, .cursor = self.cursor, .origins = self.origins.? } } else .{ .reloads = .{ .cursor = self.cursor, .origins = self.origins.? } };
        self.page = try self.client.read(action);
        const revision = switch (self.page.?.value.result) {
            .settings => |value| value.generation,
            .reloads => |value| value.revision,
            else => return error.InvalidConfigurationResponse,
        };
        if (self.observed_revision) |prior| if (prior != revision) return error.ConfigurationSnapshotChanged;
        self.observed_revision = revision;
        self.cursor = switch (self.page.?.value.result) {
            .settings => |value| value.next,
            .reloads => |value| value.next,
            else => unreachable,
        };
        self.index = 0;
        self.started = true;
        self.pages += 1;
    }
}
fn matches(self: Self, cells: []const Cell) !bool {
    if (self.plan.query) |query| {
        var failure: ?f.LogicalQuery.Plan.PredicateFailure = null;
        return query.plan.matches(cells, &failure);
    }
    return true;
}
fn project(self: *Self, cells: []const Cell) ![]const Cell {
    if (self.plan.query) |query| {
        if (!self.scalar_ready) {
            try query.plan.scalars.prepare(query.plan.schema.structure, &self.scalar_work);
            self.scalar_ready = true;
        }
        const evaluated = try query.plan.materialize(cells, &self.scalar_work);
        const result = try self.arena.allocator().alloc(Cell, query.plan.projection.len);
        for (result, query.plan.projection) |*out, column| out.* = evaluated[column];
        return result;
    }
    return cells;
}
/// A transient transport failure leaves the failed page's exact cursor intact.
/// The caller may resume within its original deadline; previously consumed
/// pages and private ordered rows remain retained. Snapshot changes and other
/// semantic failures are terminal and must not restart at a different basis.
pub fn next(self: *Self) !?[]const Cell {
    const limit = if (self.plan.query) |query| query.plan.limit orelse std.math.maxInt(u64) else std.math.maxInt(u64);
    if (self.emitted >= limit) return null;
    if (self.plan.order) |order| {
        if (!self.sorted) {
            const maximum: usize = @intCast(@min(limit, 256));
            while (try self.raw()) |cells| {
                if (!try self.matches(cells) or maximum == 0) continue;
                var at: usize = 0;
                while (at < self.ordered.items.len and !less(cells[order.column], self.ordered.items[at].cells[order.column], order.descending)) : (at += 1) {}
                if (at >= maximum) continue;
                var owned: OwnedRow = .{ .arena = .init(self.allocator), .cells = undefined };
                errdefer owned.deinit();
                const copy = try owned.arena.allocator().alloc(Cell, cells.len);
                for (copy, cells) |*out, in| out.* = try f.Types.Values.cloneValidated(owned.arena.allocator(), in);
                owned.cells = copy;
                try self.ordered.insert(at, owned);
                if (self.ordered.items.len > maximum) {
                    var dropped = self.ordered.pop().?;
                    dropped.deinit();
                }
            }
            self.sorted = true;
        }
        if (self.emitted >= self.ordered.items.len) return null;
        _ = self.arena.reset(.retain_capacity);
        const cells = self.ordered.items[@intCast(self.emitted)].cells;
        self.emitted += 1;
        return try self.project(cells);
    }
    while (try self.raw()) |cells| {
        if (!try self.matches(cells)) continue;
        self.emitted += 1;
        return try self.project(cells);
    }
    return null;
}
fn less(left: Cell, right: Cell, descending: bool) bool {
    const order: std.math.Order = if (left == .null) (if (right == .null) .eq else .gt) else if (right == .null) .lt else switch (left.value.atom) {
        .unsigned => |v| std.math.order(v, right.value.atom.unsigned),
        .boolean => |v| std.math.order(@intFromBool(v), @intFromBool(right.value.atom.boolean)),
        .bytes => |v| std.mem.order(u8, v, right.value.atom.bytes),
        else => unreachable,
    };
    return if (descending) order == .gt else order == .lt;
}
