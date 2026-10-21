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
    if (definition.resource != configuration.connection.resource) return error.QueryIdentityMismatch;
    try (try configuration.workspace.limits.native()).validate();
    self.* = .{ .host = host, .configuration = configuration, .arena = arena, .definition = definition, .client = .{ .wire = &host.wire, .connection = configuration.connection, .key = key }, .fingerprint = undefined };
    self.fingerprint = try bindingFingerprint(host.allocator, configuration, key.public_key.toBytes());
    try self.current();
    _ = try self.client.describe(self.definition);
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
    pub fn deinit(self: *Prepared) void {
        self.template.deinit();
        self.output.deinit();
    }
};
pub fn prepare(self: *Self, sql: []const u8) !Prepared {
    try self.current();
    _ = try self.client.describe(self.definition);
    var template = try q.SqlTemplate.initDiagnostic(self.host.allocator, self.definition, self.configuration.workspace.name, sql, &self.host.compile_binding);
    errdefer template.deinit();
    _ = try self.client.describe(self.definition);
    return .{ .template = template, .output = try template.template.outputSchema(self.host.allocator) };
}
pub fn validate(self: *Self, prepared: *Prepared) !void {
    try self.current();
    _ = try self.client.describe(self.definition);
    if (!std.mem.eql(u8, &prepared.template.definition, &try self.definition.fingerprint())) return error.QuerySourceChanged;
}
pub fn bind(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !q.SqlTemplate.Bound {
    try self.validate(prepared);
    var atoms: [f.LogicalPrepared.max_parameters]f.Types.Values.Atom = undefined;
    if (values.len > atoms.len) return error.ParameterCountMismatch;
    for (values, atoms[0..values.len]) |value, *atom| atom.* = value orelse return error.NullParameterUnsupported;
    return self.client.bindSql(self.host.allocator, &prepared.template, self.definition, atoms[0..values.len], try self.configuration.workspace.limits.native());
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
    decoded: ?f.LogicalInspect.Batch = null,
    index: usize = 0,
    pub fn init(source: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !Read {
        var bound = try source.bind(prepared, values);
        errdefer bound.deinit();
        var nonce: [16]u8 = undefined;
        try source.host.io.randomSecure(&nonce);
        var query = try q.Interactive.open(&source.client, bound.bundle, nonce, source.host.allocator);
        errdefer query.close() catch {};
        var arena: std.heap.ArenaAllocator = .init(source.host.allocator);
        errdefer arena.deinit();
        const workspace = try arena.allocator().alloc(u8, f.LogicalArrow.working_bytes);
        const arrow = try arena.allocator().alloc(u8, f.LogicalArrow.segment_bytes);
        const adapter = try arena.allocator().alloc(u8, q.UnifiedBehavior.adapter_bytes);
        return .{ .source = source, .bound = bound, .query = query, .arena = arena, .page_arena = .init(source.host.allocator), .workspace = workspace, .arrow = arrow, .adapter = adapter };
    }
    pub fn deinit(self: *Read) void {
        self.query.close() catch {};
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
            const segment = try self.query.next(&self.source.client, memory.allocator(), self.workspace, self.arrow, self.source.host.cancellation);
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
