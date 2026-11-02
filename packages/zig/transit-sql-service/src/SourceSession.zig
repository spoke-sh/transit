//! Explicit service-owned source bindings. Selection grants no authority: the
//! current SQL login, source caller role, policy and source identity are checked
//! independently. One session owns its read transport and leased snapshot.
const std = @import("std");
const g = @import("root.zig");
const q = g.query;
const f = g.fuze;
const Self = @This();
host: *g.Session,
configuration: *const g.Configuration.Source,
arena: std.heap.ArenaAllocator,
definition: q.SourceDefinition,
client: q.UnifiedClient,
fingerprint: [32]u8,

pub fn init(host: *g.Session, configuration: *const g.Configuration.Source) !*Self {
    const self = try host.allocator.create(Self);
    errdefer host.allocator.destroy(self);
    var arena: std.heap.ArenaAllocator = .init(host.allocator);
    errdefer arena.deinit();
    const key = try q.wire.readKey(host.allocator, host.io, configuration.key_file);
    const definition = try configuration.workspace.source.native(arena.allocator());
    if (definition.source != .table and definition.resource != configuration.connection.resource) return error.QueryIdentityMismatch;
    try (try configuration.workspace.limits.native()).validate();
    var caller: q.UnifiedClient = .{ .wire = &host.wire, .connection = configuration.connection, .key = key };
    caller.tables = try q.Workspace.directTables(arena.allocator(), &caller, configuration.workspace);
    if (caller.tables) |*tables| tables.allocator = host.allocator;
    self.* = .{ .host = host, .configuration = configuration, .arena = arena, .definition = definition, .client = caller, .fingerprint = undefined };
    self.fingerprint = try bindingFingerprint(host.allocator, configuration, key.public_key.toBytes());
    try self.current();
    // A source configuration fixes a route and policy, not the current Table
    // schema. Accepted historical work must be recoverable after live DDL.
    return self;
}
pub fn bindingFingerprint(allocator: std.mem.Allocator, configuration: *const g.Configuration.Source, public_key: [32]u8) ![32]u8 {
    const identity = try q.protocol.Json.valueAlloc(allocator, .{ configuration.name, configuration.database, configuration.connection, public_key, configuration.workspace });
    defer allocator.free(identity);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(identity, &digest, .{});
    return digest;
}
pub fn deinit(self: *Self) void {
    const allocator = self.host.allocator;
    self.arena.deinit();
    std.crypto.secureZero(u8, std.mem.asBytes(self));
    allocator.destroy(self);
}
pub fn current(self: *Self) !void {
    const key = try q.wire.readKey(self.host.allocator, self.host.io, self.configuration.key_file);
    if (!std.mem.eql(u8, &key.public_key.toBytes(), &self.client.key.public_key.toBytes())) return error.SqlSourceCredentialChanged;
    const identity = (try self.client.authorizationClient().read(.identity)).body.authorization.body.identity;
    if (identity.principal != self.client.connection.principal or identity.login_role != self.host.credential.login_role) return error.SqlSourceIdentityMismatch;
    _ = try self.client.authorize(self.definition);
}
pub const Prepared = struct {
    template: q.SqlTemplate,
    output: f.Types.Decoded,
    selected: ?q.TableSource.Owned = null,
    pub fn deinit(self: *Prepared) void {
        self.template.deinit();
        self.output.deinit();
        if (self.selected) |*selected| selected.deinit();
    }
};
pub fn prepare(self: *Self, sql: []const u8) !Prepared {
    try self.current();
    const selection = try g.database.HistoricalSql.select(sql, self.host.dialect);
    var selected: ?q.TableSource.Owned = null;
    errdefer if (selected) |*owned| owned.deinit();
    var scratch: std.heap.ArenaAllocator = .init(self.host.allocator);
    defer scratch.deinit();
    var name = self.configuration.workspace.name;
    if (selection.snapshot) |snapshot| {
        if (self.host.transaction.active()) return error.UnsupportedHistoricalTransaction;
        if (self.definition.source != .table) return error.UnsupportedHistoricalKind;
        const tables = self.client.tables orelse return error.QuerySourceUnavailable;
        const namespace = try selection.resolveNamespace(tables, self.definition.source.table.namespace);
        name = try f.TableSelect.targetDialect(scratch.allocator(), selection.statement, null, self.host.dialect);
        const response = try g.catalog.DirectHistory.resolve(tables, snapshot, namespace, name, true);
        defer response.deinit();
        const historical = response.value.result.historical_catalog.source;
        const projected = if (selection.projection) |target| try g.catalog.DirectSchemaProjection.resolve(tables, historical.binding.declaration, target) else null;
        defer if (projected) |value| value.deinit();
        selected = try q.TableSource.fromHistoricalProjected(self.host.allocator, tables.connection, historical, if (projected) |value| value.value.result.schema_projection.prepared else null);
    }
    const definition: q.SourceDefinition = if (selected) |owned| .{ .resource = owned.source.scope.resource, .source = .{ .table = owned.source } } else self.definition;
    _ = try self.client.describe(definition);
    var template = try q.SqlTemplate.initDiagnostic(self.host.allocator, definition, name, selection.statement, &self.host.compile_binding);
    errdefer template.deinit();
    _ = try self.client.describe(definition);
    return .{ .template = template, .output = try template.template.outputSchema(self.host.allocator), .selected = selected };
}
pub fn boundDefinition(self: *Self, prepared: *const Prepared) q.SourceDefinition {
    return if (prepared.selected) |selected| .{ .resource = selected.source.scope.resource, .source = .{ .table = selected.source } } else self.definition;
}
pub fn validate(self: *Self, prepared: *Prepared) !void {
    try self.current();
    const definition = self.boundDefinition(prepared);
    _ = try self.client.describe(definition);
    if (!std.mem.eql(u8, &prepared.template.definition, &try definition.fingerprint())) return error.QuerySourceChanged;
}
pub fn bind(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !q.SqlTemplate.Bound {
    return self.host.fresh(bindOnce, .{ self, prepared, values });
}
fn bindOnce(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !q.SqlTemplate.Bound {
    try self.validate(prepared);
    var atoms: [f.LogicalPrepared.max_parameters]f.Types.Values.Atom = undefined;
    if (values.len > atoms.len) return error.ParameterCountMismatch;
    for (values, atoms[0..values.len]) |value, *atom| atom.* = value orelse return error.NullParameterUnsupported;
    return self.client.bindSql(self.host.allocator, &prepared.template, self.boundDefinition(prepared), atoms[0..values.len], try self.configuration.workspace.limits.native());
}
pub const Read = struct {
    source: *Self,
    bound: q.SqlTemplate.Bound,
    query: q.Interactive,
    arena: std.heap.ArenaAllocator,
    page_arena: std.heap.ArenaAllocator,
    workspace: []u8,
    arrow: []u8,
    adapter: []u8,
    pin: ?g.ReadCache.Record = null,
    decoded: ?f.LogicalInspect.Batch = null,
    index: usize = 0,
    pub fn init(source: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !Read {
        var bound = try source.bind(prepared, values);
        errdefer bound.deinit();
        var pin: ?g.ReadCache.Record = null;
        errdefer closePin(source, pin);
        var query = if (source.client.tables) |tables| table: {
            const declaration = bound.bundle.source.source.table;
            if (declaration.historical) |history| break :table try q.Interactive.openTable(&source.client, bound.bundle, .{ .object = declaration.interpretation.interpretation.object, .handle = history.handle() }, source.host.allocator);
            const response = try tables.call(.{ .observe = .{ .namespace = declaration.namespace, .interpretation = declaration.interpretation.interpretation, .rows = null } });
            defer response.deinit();
            const metadata = response.value.result.observation.definition;
            const binding = try g.catalog.DirectTableBinding.init(tables.connection, metadata);
            if (!std.meta.eql(binding.interpretation, declaration.interpretation)) return error.TableDefinitionChanged;
            pin = try source.host.runtime.read_pins.?.acquireCurrent(tables, binding);
            break :table try q.Interactive.openTable(&source.client, bound.bundle, try pin.?.snapshot(), source.host.allocator);
        } else native: {
            var nonce: [16]u8 = undefined;
            try source.host.io.randomSecure(&nonce);
            break :native try q.Interactive.open(&source.client, bound.bundle, nonce, source.host.allocator);
        };
        errdefer query.close() catch {};
        var arena: std.heap.ArenaAllocator = .init(source.host.allocator);
        errdefer arena.deinit();
        const workspace = try arena.allocator().alloc(u8, f.LogicalArrow.working_bytes);
        const arrow = try arena.allocator().alloc(u8, f.LogicalArrow.segment_bytes);
        const adapter = try arena.allocator().alloc(u8, q.UnifiedBehavior.adapter_bytes);
        return .{ .source = source, .bound = bound, .query = query, .arena = arena, .page_arena = .init(source.host.allocator), .workspace = workspace, .arrow = arrow, .adapter = adapter, .pin = pin };
    }
    fn closePin(source: *Self, pin: ?g.ReadCache.Record) void {
        if (pin) |record| {
            const rejection = source.host.wire.last_rejection;
            defer source.host.wire.last_rejection = rejection;
            source.host.runtime.read_pins.?.close(source.client.tables.?, record) catch |err| {
                source.host.runtime.read_cleanup_failure.store(@intFromError(err), .release);
            };
        }
    }
    pub fn deinit(self: *Read) void {
        self.query.close() catch {};
        closePin(self.source, self.pin);
        if (self.decoded) |*decoded| decoded.deinit();
        self.page_arena.deinit();
        self.arena.deinit();
        self.bound.deinit();
    }
    pub fn next(self: *Read, maximum: u8) !g.ReadBatch {
        try self.source.host.fresh(Self.current, .{self.source});
        var result: g.ReadBatch = .{};
        while (self.decoded == null or self.index == self.decoded.?.rows.len) {
            if (self.decoded) |*decoded| decoded.deinit();
            self.decoded = null;
            self.index = 0;
            _ = self.page_arena.reset(.free_all);
            if (self.query.complete()) {
                result.complete = true;
                return result;
            }
            try self.source.host.deadline.check(self.source.host.io);
            var memory: std.heap.FixedBufferAllocator = .init(self.adapter);
            const segment = self.query.next(&self.source.client, memory.allocator(), self.workspace, self.arrow, self.source.host.cancellation) catch |err| {
                self.source.host.execution_diagnostic = self.query.diagnostic;
                return err;
            };
            if (segment) |part| {
                var fields: [q.SourceDefinition.max_columns]f.Types.Field = undefined;
                self.decoded = try f.LogicalInspect.decode(self.page_arena.allocator(), try self.query.schema(&fields), part.bytes, part.rows, self.workspace);
            }
        }
        const count = @min(maximum, self.decoded.?.rows.len - self.index);
        for (result.rows[0..count], self.decoded.?.rows[self.index..][0..count]) |*to, row| to.* = row.cells;
        self.index += count;
        result.len = @intCast(count);
        result.complete = self.query.complete() and self.index == self.decoded.?.rows.len;
        return result;
    }
};
