//! Metadata-only relational compilation. A prepared plan describes immutable
//! schemas and proposed budgets; it contains no captured execution basis.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const c = q.catalog;
const Memory = @import("QueryMemory.zig");
const Self = @This();
parent: std.mem.Allocator,
memory: Memory,
syntax: f.RelationalSql.Owned,
definitions: [r.max_sources]?c.TableCatalog.Definition = @splat(null),
sources: [r.max_sources]r.Source = undefined,
plan: r.Plan,

pub const resident_base = @sizeOf(Self) + 4 * f.TableSchema.max_bytes;

/// Each catalog is observed and rechecked through its current authorized public
/// metadata route. A concurrent resource revision change rejects preparation.
/// This is not an atomic multi-resource observation or a reservation for SELECT.
/// Clients borrow the caller only during this function; the result owns all
/// schema and SQL strings at a stable address until deinit.
pub fn prepare(allocator: std.mem.Allocator, clients: []const *c.TableClient, text: []const u8, lifetime: r.Lifetime, options: q.RelationalQuery.Options, location: ?*f.Sql.Location) !*Self {
    if (options.consistency != .per_resource_snapshot_vector) return error.UnsupportedRelationalConsistency;
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests == 0 or options.spill_work == 0) return error.InvalidQueryBudget;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    self.definitions = @splat(null);
    self.syntax = try f.RelationalSql.parse(self.memory.allocator(), text, location);
    errdefer self.syntax.deinit();
    if (clients.len != self.syntax.targets.len) return error.InvalidRelationalSources;
    var bindings: [r.max_sources]q.RelationalTables.Binding = undefined;
    for (clients, self.syntax.targets, 0..) |client, target, i| bindings[i] = .{ .client = client, .name = try c.TableMetadata.Name.init(target.name), .alias = target.alias };
    try q.RelationalTables.validateBindings(bindings[0..clients.len]);
    var before: [r.max_sources]c.TableClient.Description = undefined;
    errdefer for (&self.definitions) |*slot| if (slot.*) |*definition| definition.deinit();
    for (bindings[0..clients.len], 0..) |binding, i| {
        before[i] = try binding.client.describe();
        self.definitions[i] = (try binding.client.lookup(self.memory.allocator(), binding.name)) orelse return error.TableNotFound;
        const connection = binding.client.connection;
        self.sources[i] = .{ .alias = binding.alias, .realm = connection.scope.realm, .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.owner, .schema = self.definitions[i].?.schema.schema };
    }
    self.plan = try self.syntax.bind(self.sources[0..clients.len], lifetime, options.budgets, location);
    // Inspect permission suffices for EXPLAIN. Executing the resulting logical
    // shape must independently capture exact sources with current read rights.
    for (clients, 0..) |client, i| if (!std.meta.eql(before[i], try client.describe())) return error.CatalogDefinitionChanged;
    return self;
}
pub fn grouped(self: *const Self) bool {
    if (self.plan.group_by.len != 0) return true;
    for (self.plan.outputs) |output| if (output.expression != .column) return true;
    return false;
}
pub fn deinit(self: *Self) void {
    const allocator = self.parent;
    for (&self.definitions) |*slot| if (slot.*) |*definition| definition.deinit();
    self.syntax.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}

test "metadata preparation rejects route counts and parse failures without transport" {
    const t = std.testing;
    const options: q.RelationalQuery.Options = .{ .consistency = .per_resource_snapshot_vector, .budgets = .{ .resident_bytes = resident_base + 65536, .spill_bytes = 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 10, .source_pins = 1 }, .requests = 100, .spill_work = 100 };
    try t.expectError(error.InvalidRelationalSources, prepare(t.allocator, &.{}, "SELECT COUNT(*) FROM t", .interactive, options, null));
}
