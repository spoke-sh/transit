//! Read-only SQL administration resolution through the direct catalog. Plans
//! still publish through native authorization against one observed policy basis.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = p.Authorization;
const syntax = c.fuze.AuthorizationSql;
const w = c.DirectTableProtocol;

pub const Limits = struct { requests: u32 = 128 };
const Resolver = struct {
    client: c.DirectTableClient,
    authority: c.station.client.AuthorizationClient,
    description: struct { configuration: c.DirectCatalog.Configuration, subject: a.Verified },
    policy_revision: u64,
    default_namespace: u64,
    remaining: u32,

    fn consume(self: *Resolver) !void {
        if (self.remaining == 0) return error.QueryPageBudget;
        self.remaining -= 1;
    }
    fn revision(self: *Resolver, value: u64) !void {
        if (value != self.policy_revision) return error.StaleAuthorizationRevision;
    }
    fn call(self: *Resolver, action: w.Action) !std.json.Parsed(w.Response) {
        try self.consume();
        const response = try self.client.call(action);
        errdefer response.deinit();
        try self.revision(response.value.policy_revision);
        const subject = response.value.subject;
        const expected = self.description.subject;
        if (subject.principal != expected.principal or subject.login_role != expected.login_role or subject.role != expected.role or subject.credential_epoch != expected.credential_epoch) return error.StaleAuthorizationCredential;
        return response;
    }
    fn read(self: *Resolver, kind: @FieldType(a.Query, "kind")) !p.Growth.Response {
        try self.consume();
        const response = try self.authority.read(kind);
        try self.revision(response.body.authorization.revision);
        return response;
    }
    pub fn role(self: *Resolver, value: syntax.Role) !u64 {
        return switch (value) {
            .public => a.public_role,
            .current_role => self.description.subject.role,
            .session_user => self.description.subject.login_role,
            .named => |name| (try self.read(.{ .resolve = try .init(name) })).body.authorization.body.resolve.id,
        };
    }
    pub fn namespace(self: *Resolver, name: []const u8) !c.TableAuthority.Schema {
        _ = try c.TableAuthority.Name.init(name);
        var after: ?u64 = null;
        var position: ?p.DataLifecycle.Position = null;
        while (true) {
            const response = try self.call(.{ .namespaces = .{ .after = after } });
            defer response.deinit();
            const page = response.value.result.namespaces;
            if (position) |expected| if (!std.meta.eql(expected, page.directory_position)) return error.CatalogDirectoryChanged;
            position = page.directory_position;
            for (page.entries) |entry| if (entry) |found| {
                if (std.mem.eql(u8, found.name.slice(), name)) return found;
            };
            after = page.next orelse return error.CatalogSchemaMissing;
        }
    }
    pub fn object(self: *Resolver, value: syntax.Object) !a.ObjectRef {
        return switch (value.kind) {
            .database => result: {
                if (value.name.schema != null or !std.mem.eql(u8, value.name.name, self.description.configuration.database_name.slice())) return error.CatalogDatabaseMismatch;
                break :result c.TableAuthority.reference(self.description.configuration.authority.database);
            },
            .schema => c.TableAuthority.reference((try self.namespace(value.name.name)).authorization),
            .table => result: {
                const namespace_id = if (value.name.schema) |name| (try self.namespace(name)).id else self.default_namespace;
                const response = try self.call(.{ .lookup = .{ .namespace = namespace_id, .name = value.name.name } });
                defer response.deinit();
                const found = response.value.result.lookup orelse return error.TableNotFound;
                break :result c.TableAuthority.reference(found.authorization);
            },
        };
    }
    pub fn select(self: *Resolver, selected: ?u64) !void {
        // The proof is signed by this caller; a retained description never
        // substitutes for current SET eligibility or CONNECT permission.
        try self.consume();
        const subject = try self.authority.proof(self.client.connection.audience, try c.TableAuthority.binding(self.client.connection.scope, .database, 0));
        var guard = try c.TableAuthority.guard(subject, self.description.configuration.authority, null, null, .database);
        guard.selectable = selected orelse self.description.subject.login_role;
        _ = try self.read(.{ .check = guard });
    }
};

/// No resource blocks, actor messages, registration or policy changes. A name
/// becomes its stable native object reference; publication rechecks authority
/// and rejects a changed policy revision. Metadata pages have a finite request
/// budget, independent of total durable catalog cardinality.
pub fn compile(client: c.DirectTableClient, namespace_id: u64, text: []const u8, limits: Limits, location: ?*c.fuze.Sql.Location) !c.AuthorizationSql.Plan {
    try client.connection.validate();
    try c.Model.nativeId(namespace_id);
    if (limits.requests == 0) return error.QueryPageBudget;
    var parsed = try syntax.compile(client.allocator, text, location);
    defer parsed.deinit();
    switch (parsed.statement) {
        .create_schema, .rename_schema, .drop_schema => return error.UnsupportedDirectSchemaAdministration,
        else => {},
    }
    const description = try client.call(.describe);
    defer description.deinit();
    var resolver: Resolver = .{
        .client = client,
        .authority = .{ .transport = client.authority, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key },
        .description = .{ .configuration = description.value.result.description, .subject = description.value.subject },
        .policy_revision = description.value.policy_revision,
        .default_namespace = namespace_id,
        .remaining = limits.requests - 1,
    };
    const action = try c.AuthorizationSql.lower(parsed.statement, &resolver, .{});
    _ = try resolver.read(.identity);
    const plan: c.AuthorizationSql.Plan = .{ .definition = p.Growth.current_definition, .scope = client.connection.scope, .principal = resolver.description.subject.principal, .role = resolver.description.subject.role, .expected_revision = resolver.policy_revision, .action = action };
    try plan.validate();
    return plan;
}
