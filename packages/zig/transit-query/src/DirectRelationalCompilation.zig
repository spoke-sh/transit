//! Metadata-only relational plans for direct Tables. Independent Table heads
//! are not a consistent catalog snapshot; execution receives explicit pins.
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
bindings: [r.max_sources]c.DirectTableBinding = undefined,
positions: [r.max_sources]q.protocol.DataLifecycle.Position = undefined,
schemas: [r.max_sources]?f.TableSchema.Owned = @splat(null),
sources: [r.max_sources]r.Source = undefined,
plan: r.Plan,
pub const resident_base = @sizeOf(Self) + r.max_sources * f.TableSchema.max_bytes;

pub fn prepare(allocator: std.mem.Allocator, clients: []const c.DirectTableClient, namespace: u64, text: []const u8, lifetime: r.Lifetime, options: q.RelationalQuery.Options, location: ?*f.Sql.Location) !*Self {
    if (options.consistency != .independent_table_snapshots) return error.UnsupportedRelationalConsistency;
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests == 0 or options.spill_work == 0) return error.InvalidQueryBudget;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    self.schemas = @splat(null);
    self.syntax = try f.RelationalSql.parseDialect(self.memory.allocator(), text, location, options.dialect);
    errdefer self.syntax.deinit();
    if (clients.len != self.syntax.targets.len or clients.len == 0) return error.InvalidRelationalSources;
    errdefer for (&self.schemas) |*slot| if (slot.*) |*schema| schema.deinit();
    for (clients, self.syntax.targets, 0..) |client, target, i| {
        if (!std.meta.eql(client.connection, clients[0].connection) or client.service != clients[0].service or client.authority != clients[0].authority or !std.mem.eql(u8, &client.key.public_key.bytes, &clients[0].key.public_key.bytes)) return error.RelationalCallerChanged;
        const response = try client.call(.{ .lookup = .{ .namespace = namespace, .name = target.name } });
        defer response.deinit();
        const metadata = response.value.result.lookup orelse return error.TableNotFound;
        self.bindings[i] = try c.DirectTableBinding.init(client.connection, metadata);
        self.positions[i] = metadata.position;
        _ = try self.bindings[i].require(client, .read);
        const bytes = try metadata.schema.decode(self.memory.allocator(), f.TableSchema.max_bytes);
        defer self.memory.allocator().free(bytes);
        self.schemas[i] = try f.TableSchema.decode(self.memory.allocator(), bytes);
        try q.DirectTableQuery.qualify(self.schemas[i].?.schema);
        const connection = client.connection;
        self.sources[i] = .{ .alias = target.alias, .realm = connection.scope.realm, .resource = connection.scope.resource, .catalog = connection.scope.catalog, .owner = connection.audience, .schema = self.schemas[i].?.schema };
    }
    self.plan = try self.syntax.bind(self.sources[0..clients.len], lifetime, options.budgets, location);
    try self.validate(clients[0]);
    return self;
}
pub fn validate(self: *const Self, client: c.DirectTableClient) !void {
    try self.validateBindings(client);
    var checks: [r.max_sources]c.DirectTableProtocol.ReadCheck = undefined;
    for (self.bindings[0..self.syntax.targets.len], 0..) |binding, i| {
        checks[i] = .{ .access = .{ .namespace = binding.namespace, .target = binding.interpretation.interpretation, .access = .read } };
    }
    const response = try client.call(.{ .check_set = checks[0..self.syntax.targets.len] });
    defer response.deinit();
}
/// Local binding validity is separate from current-name resolution. A retained
/// reader checks current rights against its snapshots before every disclosure.
pub fn validateBindings(self: *const Self, client: c.DirectTableClient) !void {
    for (self.bindings[0..self.syntax.targets.len]) |binding| {
        try binding.validate();
        if (!std.meta.eql(binding.connection, client.connection)) return error.CatalogIdentityConflict;
    }
}
/// Bind an explicitly requested query to original saved interpretations and
/// retained schemas. This does not resolve live names, acquire or release pins,
/// or resume the row cursor of a lost interactive executor.
pub fn fromRetained(allocator: std.mem.Allocator, client: c.DirectTableClient, namespace: u64, text: []const u8, bindings: []const c.DirectTableBinding, snapshots: []const c.DirectTableProtocol.Snapshot, options: q.RelationalQuery.Options, location: ?*f.Sql.Location) !*Self {
    if (options.consistency != .independent_table_snapshots) return error.UnsupportedRelationalConsistency;
    if (options.budgets.resident_bytes <= resident_base or options.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    if (options.requests == 0 or options.spill_work == 0) return error.InvalidQueryBudget;
    if (bindings.len == 0 or bindings.len > r.max_sources or snapshots.len != bindings.len) return error.InvalidRelationalSources;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.parent = allocator;
    self.memory = .{ .parent = allocator, .limit = @intCast(options.budgets.resident_bytes - resident_base) };
    self.schemas = @splat(null);
    self.syntax = try f.RelationalSql.parseDialect(self.memory.allocator(), text, location, options.dialect);
    errdefer self.syntax.deinit();
    if (self.syntax.targets.len != bindings.len) return error.InvalidRelationalSources;
    errdefer for (&self.schemas) |*slot| if (slot.*) |*schema| schema.deinit();
    for (bindings, snapshots, self.syntax.targets, 0..) |binding, snapshot, target, i| {
        try binding.validate();
        if (!std.meta.eql(binding.connection, client.connection)) return error.RelationalCallerChanged;
        if (namespace != binding.namespace or !std.mem.eql(u8, binding.name.slice(), target.name) or !std.meta.eql(snapshot.object, binding.interpretation.interpretation.object)) return error.RelationalSourceChanged;
        const response = try client.call(.{ .snapshot = snapshot });
        defer response.deinit();
        const source = response.value.result.snapshot;
        if (!std.meta.eql(source.interpretation, binding.interpretation)) return error.RelationalSourceChanged;
        self.bindings[i] = binding;
        self.positions[i] = source.accepted;
        const bytes = try source.schema.decode(self.memory.allocator(), f.TableSchema.max_bytes);
        defer self.memory.allocator().free(bytes);
        self.schemas[i] = try f.TableSchema.decode(self.memory.allocator(), bytes);
        try q.DirectTableQuery.qualify(self.schemas[i].?.schema);
        self.sources[i] = .{ .alias = target.alias, .realm = client.connection.scope.realm, .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .schema = self.schemas[i].?.schema };
    }
    self.plan = try self.syntax.bind(self.sources[0..bindings.len], .interactive, options.budgets, location);
    try self.validateBindings(client);
    // Recheck every source together after buffering all original schemas.
    var checks: [r.max_sources]c.DirectTableProtocol.ReadCheck = undefined;
    for (snapshots, 0..) |snapshot, i| checks[i] = .{ .snapshot = snapshot };
    const checked = try client.call(.{ .check_set = checks[0..snapshots.len] });
    defer checked.deinit();
    return self;
}
pub fn grouped(self: *const Self) bool {
    if (self.plan.group_by.len != 0) return true;
    for (self.plan.outputs) |output| if (output.expression != .column) return true;
    return false;
}
pub fn deinit(self: *Self) void {
    const allocator = self.parent;
    for (&self.schemas) |*slot| if (slot.*) |*schema| schema.deinit();
    self.syntax.deinit();
    std.debug.assert(self.memory.used == 0);
    allocator.destroy(self);
}
