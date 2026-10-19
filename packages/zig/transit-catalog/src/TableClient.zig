//! Signed general Table caller. Exact native sends, typed intent, input progress
//! and SQL outcomes are separate recovery objects; no uncertain send is re-signed.
const std = @import("std");
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const g = p.Growth;
const wire = s.client;
const m = c.TableCatalogRecords;
const Control = c.TableControl;
const Intent = c.TableIntent;
const Self = @This();
transport: *wire.Client,
connection: Connection,
key: p.Ed25519.KeyPair,
/// Explicit trusted mediation: private storage credentials and original subject.
/// With no override the caller is an explicitly privileged raw-resource reader.
reader: ?wire.ResourceReader = null,
authority: ?c.TableAuthority.Context = null,
batch_support: bool = false,
// Scheduling only; never cache authorization, progress or application truth.
pending_observation: ?struct { signature: [64]u8, input: u64, position: u64 } = null,
pending_change: ?struct { connection: Connection, identity: Intent.Identity, namespace: u64, position: u64 } = null,
pub const completion_wait_ms: u32 = 50;
pub const Connection = struct {
    scope: m.Scope,
    owner: u64,
    principal: u64,
    role: ?u64 = null,
    namespace: u64 = 1,
    pub fn validate(self: Connection) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.owner);
        try c.Model.nativeId(self.namespace);
        if (self.role) |role| if (role > p.max_counter) return error.InvalidCatalogIdentity;
        if (self.principal > p.max_counter) return error.InvalidCatalogIdentity;
    }
    pub fn header(self: Connection, value: c.TableCommand.Header) !void {
        try self.validate();
        try value.validate();
        if (!std.meta.eql(self.scope, value.scope) or self.owner != value.owner or self.principal != value.principal or self.namespace != value.namespace) return error.CatalogIdentityConflict;
    }
};
pub const Payload = union(enum) { inline_command: c.TableCommand.Header, control: Control.Command };
fn payload(connection: Connection, value: p.Value) !Payload {
    try connection.validate();
    if (value.len > s.Frame.max_payload) return error.MessageTooLarge;
    if (std.mem.startsWith(u8, value.slice(), "TCQ1")) {
        const header = try c.TableCommand.inspect(value.slice());
        try connection.header(header);
        return .{ .inline_command = header };
    }
    const command = try Control.Command.decode(value);
    if (!std.meta.eql(try command.scope(), connection.scope)) return error.CatalogScopeChanged;
    switch (command) {
        .initialize => |value_config| if (value_config.owner != connection.owner or value_config.administrator != connection.principal) return error.CatalogIdentityConflict,
        .begin => |value_begin| try connection.header(try c.TableCommand.inspect(&value_begin.header)),
        .cancel_ddl, .cleanup_ddl => |ref| if (ref.principal != connection.principal) return error.CatalogIdentityConflict,
        .cancel_dml, .cleanup_dml => |ref| if (ref.reference.principal != connection.principal) return error.CatalogIdentityConflict,
        .schema => |request| if (request.principal != connection.principal) return error.CatalogIdentityConflict,
        else => {},
    }
    return .{ .control = command };
}
/// A reviewable native request without credentials or a fabricated signature.
/// The original caller supplies its next native sequence and signs it locally.
pub const Candidate = struct {
    definition: g.Definition,
    connection: Connection,
    request: g.Request,
    pub fn command(self: Candidate) !Payload {
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try g.validate(self.request);
        if (self.request.command != .send) return error.InvalidCatalogPrepared;
        const send = self.request.command.send;
        if (self.request.realm != self.connection.scope.realm or self.request.principal != self.connection.principal or send.pid != self.connection.owner or send.role != self.connection.role) return error.CatalogIdentityConflict;
        const frame = try s.Frame.decode(send.value);
        if (frame.kind != .cast) return error.InvalidCatalogPrepared;
        return payload(self.connection, frame.payload);
    }
    pub fn matches(self: Candidate, intent: *const Intent) !bool {
        _ = try self.command();
        try self.connection.header(intent.header);
        return intent.matches((try s.Frame.decode(self.request.command.send.value)).payload);
    }
    pub fn sign(self: Candidate, key: p.Ed25519.KeyPair) !Prepared {
        _ = try self.command();
        return .{ .version = 1, .definition = self.definition, .connection = self.connection, .public_key = key.public_key.toBytes(), .signed = try g.sign(self.request, key) };
    }
};
pub const Prepared = struct {
    version: u8,
    definition: g.Definition,
    connection: Connection,
    public_key: [32]u8,
    signed: g.SignedRequest,
    pub const max_saved_bytes = 8192;
    pub fn command(self: Prepared) !Payload {
        if (self.version != 1) return error.InvalidCatalogPrepared;
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try g.validate(self.signed.request);
        const envelope = self.signed.request;
        if (envelope.command != .send) return error.InvalidCatalogPrepared;
        if (envelope.realm != self.connection.scope.realm or envelope.principal != self.connection.principal or envelope.command.send.pid != self.connection.owner or envelope.command.send.role != self.connection.role) return error.CatalogIdentityConflict;
        const frame = try s.Frame.decode(envelope.command.send.value);
        if (frame.kind != .cast) return error.InvalidCatalogPrepared;
        return payload(self.connection, frame.payload);
    }
    pub fn matches(self: Prepared, intent: *const Intent) !bool {
        _ = try self.command();
        try self.connection.header(intent.header);
        return intent.matches((try s.Frame.decode(self.signed.request.command.send.value)).payload);
    }
    pub fn verify(self: Prepared) !void {
        _ = try self.command();
        try p.Ed25519.Signature.fromBytes(self.signed.signature).verify(&try g.digest(self.signed.request), try p.Ed25519.PublicKey.fromBytes(self.public_key));
    }
    pub fn save(self: Prepared, allocator: std.mem.Allocator) ![]u8 {
        try self.verify();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Prepared {
        if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidCatalogPrepared;
        const parsed = std.json.parseFromSlice(Prepared, allocator, bytes, .{}) catch |err| return if (err == error.OutOfMemory) err else error.InvalidCatalogPrepared;
        defer parsed.deinit();
        parsed.value.verify() catch return error.InvalidCatalogPrepared;
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidCatalogPrepared;
        return parsed.value;
    }
};
pub const Description = struct { configuration: m.Configuration, subject: p.Authorization.Verified, authorization_revision: u64, resource_revision: u64 };
pub const Outcome = union(enum) {
    ddl: c.TableCatalog.Outcome,
    dml: s.TableWrite.Status,
    pub fn terminal(self: Outcome) bool {
        return switch (self) {
            .ddl => |value| value.terminal(),
            .dml => |value| value.state != .building,
        };
    }
};
pub const Next = union(enum) { send: Prepared, running, terminal: Outcome, upload_cancelled };
pub const Observation = enum { pending, processed };
pub const Progress = union(enum) {
    pending,
    processed: struct { disposition: ?Control.Disposition, outcome: ?Outcome, upload: ?c.TableUpload.Status },
};
pub const State = struct { outcome: ?Outcome, upload: ?c.TableUpload.Status };
/// Current authorized observation only. Never prepares a successor send or
/// treats a closed command upload as a Table operation outcome.
pub fn inspectIntent(self: *Self, intent: *const Intent) !State {
    var current = try self.intentSource(intent, null);
    const result: State = .{ .outcome = try self.outcome(&current, intent.identity), .upload = try self.uploadStatus(&current, intent) };
    try current.finish();
    return result;
}
pub fn resources(self: *Self) wire.ResourceReader {
    if (self.reader) |value| return value;
    return .{ .wire = self.transport, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key };
}
pub fn authorizationContext(self: *Self) !c.TableAuthority.Context {
    if (self.authority) |value| {
        _ = try value.authorizationSubject(self.connection.principal);
        return value;
    }
    const native: wire.AuthorizationClient = .{ .transport = self.transport, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key, .role = self.connection.role };
    // The caller signs its own subject; the trusted reader verifies that
    // subject through its scoped inspection identity. Storage access never
    // substitutes the reader's role for the caller's object privileges.
    const inspector: wire.AuthorizationClient = if (self.reader) |reader|
        .{ .transport = reader.wire, .realm = reader.realm, .principal = reader.principal, .key = reader.key }
    else
        native;
    return .{ .client = inspector, .subject = try native.proof(self.connection.owner, try c.TableAuthority.binding(self.connection.scope, .database, 0)) };
}
fn address(self: *Self, tag: u8, id: u64, revision: u64) p.Value {
    return c.Records.key(self.connection.scope.catalog, tag, id, revision);
}
fn batch(self: *Self, extra: []const p.Value) !wire.ResourceReader.Batch {
    try self.connection.validate();
    if (extra.len > g.page_size - 1) return error.InvalidCatalogPage;
    if (!self.batch_support) {
        _ = try self.resources().batches();
        self.batch_support = true;
    }
    var keys: [g.page_size]p.Value = undefined;
    keys[0] = self.address('c', 0, 0);
    var count: usize = 1;
    next: for (extra) |key| {
        for (keys[0..count]) |old| if (old.eql(key)) continue :next;
        keys[count] = key;
        count += 1;
    }
    const result = try (wire.ResourceReader.Batches{ .client = self.resources() }).read(self.connection.scope.resource, null, keys[0..count]);
    if (result.resource.id != self.connection.scope.resource or result.resource.writer != self.connection.owner or result.resource.phase != .active) return error.CatalogOwnerChanged;
    return result;
}
const Source = struct {
    authority: c.TableAuthority.Context,
    authorization_revision: u64 = 0,
    guard: ?p.Authorization.Guard = null,
    position: u64,
    cache: wire.ResourceReader.Cached(wire.ResourceReader.Batches),
    reader: wire.ResourceReader.Reader,
    view: @FieldType(wire.ResourceReader.Reader, "view"),
    pub fn authorizationSubject(self: *@This(), who: u64) !p.Authorization.Subject {
        return self.authority.authorizationSubject(who);
    }
    pub fn requireAuthorization(self: *@This(), requested: p.Authorization.Guard) !p.Authorization.Verified {
        const response = try self.authority.observe(requested);
        self.guard = if (self.guard) |previous| try previous.merge(requested) else requested;
        self.authorization_revision = response.body.authorization.revision;
        return response.body.authorization.body.check;
    }
    pub fn finish(self: *@This()) !void {
        if (self.cache.failed) |err| return err;
        if (self.guard) |required| {
            const response = try self.authority.observe(required);
            self.authorization_revision = response.body.authorization.revision;
        }
    }
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        return self.cache.read(key);
    }
    pub fn readBlock(self: *@This(), key: p.Value, output: []u8) !?[]const u8 {
        return self.cache.readBlock(key, output);
    }
    pub fn prefetchBlocks(self: *@This(), keys: []const p.Value) !void {
        return self.cache.prefetchBlocks(keys);
    }
    pub fn prefetch(self: *@This(), keys: []const p.Value) !void {
        try self.cache.prefetch(keys);
    }
    pub fn page(self: *@This(), after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        if (self.cache.failed) |err| return err;
        return self.reader.page(after) catch |err| {
            self.cache.failed = err;
            return err;
        };
    }
};
fn source(self: *Self, extra: []const p.Value) !Source {
    const metadata = try self.batch(extra);
    const reader: wire.ResourceReader.Reader = .{ .client = self.resources(), .view = .{ .resource = metadata.view.resource, .revision = metadata.view.revision } };
    return .{ .authority = try self.authorizationContext(), .position = metadata.position, .cache = (wire.ResourceReader.Batches{ .client = self.resources() }).cached(metadata), .reader = reader, .view = reader.view };
}
fn catalog(self: *Self, current: *Source) !c.TableCatalog {
    const config = try c.Records.decode(m.Configuration, 'C', (try current.read(self.address('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config.scope, self.connection.scope) or config.owner != self.connection.owner) return error.CatalogConfigurationChanged;
    return .{ .configuration = config, .namespace = self.connection.namespace };
}
pub fn describe(self: *Self) !Description {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const subject = try owner.authorize(&current, self.connection.principal, .inspect);
    try current.finish();
    return .{ .configuration = owner.configuration, .subject = subject, .authorization_revision = current.authorization_revision, .resource_revision = current.view.revision };
}
pub fn describeDatabase(self: *Self) !Description {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const subject = try owner.authorizeDatabase(&current, self.connection.principal);
    try current.finish();
    return .{ .configuration = owner.configuration, .subject = subject, .authorization_revision = current.authorization_revision, .resource_revision = current.view.revision };
}
pub fn schema(self: *Self, name: c.TableAuthority.Name) !?c.TableAuthority.Schema {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const result = try (c.SchemaCatalog{ .configuration = owner.configuration }).lookup(&current, self.connection.principal, name);
    try current.finish();
    return result;
}
pub fn schemas(self: *Self, cursor: ?c.SchemaCatalog.Cursor) !c.SchemaCatalog.Page {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const result = try (c.SchemaCatalog{ .configuration = owner.configuration }).list(&current, self.connection.principal, cursor);
    try current.finish();
    return result;
}
pub fn schemaStatus(self: *Self, request: c.SchemaCatalog.Request) !?c.SchemaCatalog.Outcome {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const result = try (c.SchemaCatalog{ .configuration = owner.configuration }).status(&current, self.connection.principal, request);
    try current.finish();
    return result;
}
/// Every acquisition checks current native/scoped rights and one exact cut.
/// No current metadata observation becomes a retained query snapshot.
pub fn requireObject(self: *Self, id: u64, right: m.Right) !p.Authorization.Verified {
    var current = try self.source(&.{});
    return (try self.catalog(&current)).authorizeObject(&current, self.connection.principal, id, right);
}
pub fn lookup(self: *Self, allocator: std.mem.Allocator, name: c.TableMetadata.Name) !?c.TableCatalog.Definition {
    var current = try self.source(&.{});
    var result = try (try self.catalog(&current)).lookup(allocator, &current, self.connection.principal, name);
    errdefer if (result) |*value| value.deinit();
    try current.finish();
    return result;
}
pub fn list(self: *Self, cursor: ?c.TableCatalog.Cursor) !c.TableCatalog.Page {
    var current = try self.source(&.{});
    const result = try (try self.catalog(&current)).list(&current, self.connection.principal, cursor);
    try current.finish();
    return result;
}
pub fn definition(self: *Self, allocator: std.mem.Allocator, object: u64, revision: u64) !?c.TableCatalog.HistoricalDefinition {
    if (object == 0 or revision == 0) return error.InvalidCatalogIdentity;
    var current = try self.source(&.{
        self.address('O', object, 0),
        c.TableMetadataStore.key(object, 'd', 0),
        c.TableMetadataStore.key(object, 'i', revision),
        c.TableMetadataStore.key(object, 'r', revision),
    });
    var result = try (try self.catalog(&current)).definition(allocator, &current, self.connection.principal, object, revision);
    errdefer if (result) |*value| value.deinit();
    try current.finish();
    return result;
}
pub const CompileIdentity = struct { operation: u64, namespace: u64, create_object: ?u64 = null };
/// SQL and typed callers lower to the same immutable intent. Names resolve at
/// this preparation boundary only; saved recovery never invokes this method.
pub fn compile(self: *Self, allocator: std.mem.Allocator, text: []const u8, identity: CompileIdentity, location: ?*c.fuze.Sql.Location) !Intent {
    var result = try self.compileDefinition(allocator, text, identity, location);
    errdefer result.deinit();
    // CREATE can be compiled offline; preparing its native candidate checks CREATE.
    if (result.header.kind != .create) _ = try self.requireObject(result.header.object, result.header.right());
    return result;
}
fn compileDefinition(self: *Self, allocator: std.mem.Allocator, text: []const u8, identity: CompileIdentity, location: ?*c.fuze.Sql.Location) !Intent {
    try self.connection.validate();
    if (identity.operation == 0 or identity.namespace == 0 or identity.create_object == 0) return error.InvalidCatalogIdentity;
    var names: std.heap.ArenaAllocator = .init(allocator);
    defer names.deinit();
    const ddl_target = c.fuze.TableDdl.targetDiagnostic(names.allocator(), text, location) catch |err| switch (err) {
        error.UnsupportedStatement => null,
        else => return err,
    };
    if (ddl_target) |target| {
        if (target.kind == .create) {
            const object = identity.create_object orelse return error.InvalidCatalogIdentity;
            var statement = try c.fuze.TableDdl.compile(allocator, text, null, location);
            defer statement.deinit();
            const value = statement.statement.create;
            const request: c.TableDdlRequest = .{ .principal = self.connection.principal, .namespace = self.connection.namespace, .operation = identity.operation, .object = object, .expected_revision = 0, .name = try c.TableMetadata.Name.init(value.name), .action = .{ .create = .{ .schema = try value.bind(object), .if_not_exists = value.if_not_exists } } };
            return Intent.create(allocator, try c.TableCommand.fromDdl(self.connection.scope, self.connection.owner, request, null), identity.namespace);
        }
        if (identity.create_object != null) return error.InvalidCatalogIdentity;
        var resolved = try self.lookup(allocator, try c.TableMetadata.Name.init(target.name));
        defer if (resolved) |*value| value.deinit();
        var statement = try c.fuze.TableDdl.compile(allocator, text, if (resolved) |value| value.schema.schema else null, location);
        defer statement.deinit();
        const record = if (resolved) |value| value.metadata else null;
        var request: c.TableDdlRequest = .{ .principal = self.connection.principal, .namespace = self.connection.namespace, .operation = identity.operation, .object = if (record) |value| value.object else 0, .expected_revision = if (record) |value| value.revision else 0, .name = try c.TableMetadata.Name.init(target.name), .action = undefined };
        request.action = switch (statement.statement) {
            .create => unreachable,
            .alter => |alter| switch (alter.action) {
                .columns => |change| .{ .alter = .{ .schema = resolved.?.schema.schema, .change = change } },
                .rename_table => |name| .{ .rename = try c.TableMetadata.Name.init(name) },
            },
            .drop => |drop| .{ .drop = .{ .if_exists = drop.if_exists } },
        };
        return Intent.create(allocator, try c.TableCommand.fromDdl(self.connection.scope, self.connection.owner, request, record), identity.namespace);
    }
    if (identity.create_object != null) return error.InvalidCatalogIdentity;
    const target = try c.fuze.TableDml.targetDiagnostic(names.allocator(), text, location);
    var resolved = (try self.lookup(allocator, try c.TableMetadata.Name.init(target.name))) orelse return error.TableNotFound;
    defer resolved.deinit();
    var statement = try c.fuze.TableDml.compile(allocator, text, resolved.metadata.name.slice(), resolved.schema.schema, location);
    defer statement.deinit();
    const request: c.TableDmlRequest = .{ .principal = self.connection.principal, .operation = identity.operation, .metadata = .{ .id = resolved.metadata.revision, .spec = try resolved.metadata.spec() }, .plan = statement.plan };
    return Intent.create(allocator, try c.TableCommand.fromDml(self.connection.scope, self.connection.owner, request, resolved.metadata), identity.namespace);
}
fn outcome(self: *Self, current: *Source, identity: Intent.Identity) !?Outcome {
    const owner = try self.catalog(current);
    return switch (identity) {
        .ddl => |ref| blk: {
            if (!std.meta.eql(ref.scope, self.connection.scope) or ref.principal != self.connection.principal) return error.CatalogIdentityConflict;
            break :blk if (try owner.status(current, ref.principal, ref.operation, ref.digest)) |value| .{ .ddl = value } else null;
        },
        .dml => |ref| blk: {
            const result = (try owner.mutationReceipt(current, self.connection.principal, ref.reference)) orelse return null;
            if (result.route != ref.route) return error.CatalogIdentityConflict;
            break :blk .{ .dml = result };
        },
    };
}
fn intentSource(self: *Self, intent: *const Intent, input: ?u64) !Source {
    try self.connection.header(intent.header);
    var extra: [4]p.Value = undefined;
    extra[0] = self.address('U', intent.namespace, 0);
    var count: usize = 2;
    switch (intent.identity) {
        .ddl => |ref| {
            extra[1] = self.address('o', ref.principal, ref.operation);
        },
        .dml => |ref| {
            extra[1] = ref.reference.key();
            extra[2] = self.address('O', ref.reference.object, 0);
            count = 3;
        },
    }
    if (input) |position| {
        extra[count] = self.address('e', position, 0);
        count += 1;
    }
    return self.source(extra[0..count]);
}
pub fn status(self: *Self, intent: *const Intent) !?Outcome {
    var current = try self.intentSource(intent, null);
    const result = try self.outcome(&current, intent.identity);
    try current.finish();
    return result;
}
fn uploadStatus(self: *Self, current: *Source, intent: *const Intent) !?c.TableUpload.Status {
    const owner = try self.catalog(current);
    const value = (c.TableUpload{ .catalog = owner }).status(current, self.connection.principal, intent.namespace) catch |err| return if (err == error.TableUploadNotFound) null else err;
    if (!std.meta.eql(value.header, intent.header) or !std.meta.eql(value.spec, intent.spec)) return error.CatalogIdentityConflict;
    return value;
}
fn sign(self: *Self, value: p.Value) !Prepared {
    if (self.authority != null or self.reader != null) return error.CatalogSigningUnavailable;
    _ = try payload(self.connection, value);
    const sequence = (try self.resources().query(.capabilities)).principal_sequence;
    return (try self.candidate(value, try std.math.add(u64, sequence, 1))).sign(self.key);
}
fn prepareAt(self: *Self, current: *Source, value: p.Value) !p.Value {
    const command = try payload(self.connection, value);
    if (command == .control and command.control == .initialize) {
        if (try current.read(self.address('c', 0, 0)) != null and !std.meta.eql((try self.catalog(current)).configuration, command.control.initialize)) return error.CatalogConfigurationChanged;
        return value;
    }
    const owner = try self.catalog(current);
    if (command == .inline_command) {
        _ = try owner.authorize(current, self.connection.principal, .inspect);
        _ = try owner.authorizeObject(current, self.connection.principal, command.inline_command.object, command.inline_command.right());
        return value;
    }
    switch (command.control) {
        .initialize => unreachable,
        .schema => |request| try (c.SchemaCatalog{ .configuration = owner.configuration }).prepare(current, request),
        .dependency => |change| _ = try owner.authorizeObject(current, self.connection.principal, change.dependency.object, .alter),
        .begin => |begin| {
            _ = try owner.authorize(current, self.connection.principal, .inspect);
            _ = try owner.authorizeObject(current, self.connection.principal, (try c.TableCommand.inspect(&begin.header)).object, (try c.TableCommand.inspect(&begin.header)).right());
        },
        .part, .seal, .drive, .cancel_upload, .collect_upload => {
            const namespace = switch (command.control) {
                .part => |part| part.upload.namespace,
                .seal, .drive, .cancel_upload, .collect_upload => |upload_value| upload_value.namespace,
                else => unreachable,
            };
            const upload_value = try (c.TableUpload{ .catalog = owner }).status(current, self.connection.principal, namespace);
            if (command.control == .part or command.control == .seal or command.control == .drive) _ = try owner.authorizeObject(current, self.connection.principal, upload_value.header.object, upload_value.header.right());
        },
        .cancel_ddl, .cleanup_ddl => |ref| _ = (try owner.status(current, ref.principal, ref.operation, ref.digest)) orelse return error.CatalogOperationNotFound,
        .cancel_dml, .cleanup_dml => |ref| _ = (try owner.mutationReceipt(current, self.connection.principal, ref.reference)) orelse return error.TableWriteNotFound,
    }
    return value;
}
pub fn prepareControl(self: *Self, command: Control.Command) !Prepared {
    const value = try command.encode();
    _ = try payload(self.connection, value);
    var current = try self.source(&.{});
    const prepared = try self.prepareAt(&current, value);
    try current.finish();
    return self.sign(prepared);
}
fn schemaPlanValue(self: *Self, plan: c.AuthorizationSql.Plan) !p.Value {
    try plan.validate();
    if (plan.action != .schema or plan.principal != self.connection.principal or !std.meta.eql(plan.scope, self.connection.scope)) return error.InvalidAuthorizationPlan;
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const subject = try owner.authorizeDatabase(&current, self.connection.principal);
    if (subject.role != plan.role or current.authorization_revision != plan.expected_revision) return error.StaleAuthorizationRevision;
    const prepared = try self.prepareAt(&current, try (Control.Command{ .schema = plan.action.schema }).encode());
    try current.finish();
    if (current.authorization_revision != plan.expected_revision) return error.StaleAuthorizationRevision;
    return prepared;
}
pub fn prepareSchemaPlan(self: *Self, plan: c.AuthorizationSql.Plan) !Prepared {
    return self.sign(try self.schemaPlanValue(plan));
}
pub fn schemaPlanCandidate(self: *Self, plan: c.AuthorizationSql.Plan, sequence: u64) !Candidate {
    return self.candidate(try self.schemaPlanValue(plan), sequence);
}
/// Prepare one next upload/send only when no automatic execution is in flight.
/// Persist the returned Prepared before submit. An uncertain prior send must
/// be retried with submit(original), never by calling next again.
const NextValue = union(enum) { send: p.Value, running, terminal: Outcome, upload_cancelled };
fn nextValue(self: *Self, intent: *const Intent) !NextValue {
    self.pending_change = null;
    var current = try self.intentSource(intent, null);
    const next_value = try self.nextAt(&current, intent);
    try current.finish();
    return next_value;
}
fn nextAt(self: *Self, current: *Source, intent: *const Intent) !NextValue {
    if (try self.outcome(current, intent.identity)) |result| {
        if (result.terminal()) return .{ .terminal = result };
        self.pending_change = .{ .connection = self.connection, .identity = intent.identity, .namespace = intent.namespace, .position = current.position };
        return .running;
    }
    const upload_value = (try self.uploadStatus(current, intent)) orelse {
        if (intent.body.len <= s.Frame.max_payload) return .{ .send = try self.prepareAt(current, try p.Value.init(intent.body)) };
        return .{ .send = try self.prepareAt(current, try (Control.Command{ .begin = .{ .header = try intent.header.encode(), .namespace = intent.namespace, .spec = intent.spec } }).encode()) };
    };
    const command: Control.Command = switch (upload_value.phase) {
        .sealed, .ready => {
            self.pending_change = .{ .connection = self.connection, .identity = intent.identity, .namespace = intent.namespace, .position = current.position };
            return .running;
        },
        .cancelled => return .upload_cancelled,
        .uploading => if (upload_value.received == upload_value.spec.length) .{ .seal = intent.upload() } else .{ .part = try Control.Part.init(intent.upload(), upload_value.received, intent.body[upload_value.received..][0..@min(c.TableUpload.part_bytes, intent.body.len - upload_value.received)]) },
    };
    return .{ .send = try self.prepareAt(current, try command.encode()) };
}
pub fn next(self: *Self, intent: *const Intent) !Next {
    return switch (try self.nextValue(intent)) {
        .send => |value| .{ .send = try self.sign(value) },
        .running => .running,
        .terminal => |value| .{ .terminal = value },
        .upload_cancelled => .upload_cancelled,
    };
}
pub const CandidateNext = union(enum) { send: Candidate, running, terminal: Outcome, upload_cancelled };
fn candidate(self: *Self, value: p.Value, sequence: u64) !Candidate {
    _ = try payload(self.connection, value);
    const result: Candidate = .{ .definition = g.current_definition, .connection = self.connection, .request = .{ .realm = self.connection.scope.realm, .principal = self.connection.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.connection.owner, .role = self.connection.role, .value = try (s.Frame{ .kind = .cast, .payload = value }).encode() } } } };
    _ = try result.command();
    return result;
}
pub fn nextCandidate(self: *Self, intent: *const Intent, sequence: u64) !CandidateNext {
    return switch (try self.nextValue(intent)) {
        .send => |value| .{ .send = try self.candidate(value, sequence) },
        .running => .running,
        .terminal => |value| .{ .terminal = value },
        .upload_cancelled => .upload_cancelled,
    };
}
pub fn controlCandidate(self: *Self, command: Control.Command, sequence: u64) !Candidate {
    const value = try command.encode();
    _ = try payload(self.connection, value);
    var current = try self.source(&.{});
    const prepared = try self.prepareAt(&current, value);
    try current.finish();
    return self.candidate(prepared, sequence);
}
/// Advisory scheduling after next reports running. This consumes no durable
/// cursor and says nothing about completion; the caller must acquire next again.
/// The process read requires current native inspection rights. Resource/scoped
/// authority is independently rechecked by the following metadata acquisition.
pub fn waitForChange(self: *Self, intent: *const Intent) !void {
    errdefer self.pending_change = null;
    try self.connection.header(intent.header);
    const cursor = self.pending_change orelse return;
    self.pending_change = null;
    if (!std.meta.eql(cursor.connection, self.connection) or !std.meta.eql(cursor.identity, intent.identity) or cursor.namespace != intent.namespace) return error.CatalogIdentityConflict;
    const response = self.transport.waitForChange(.{ .realm = self.connection.scope.realm, .principal = self.connection.principal, .kind = .{ .process = self.connection.owner } }, self.key, .{ .after = cursor.position, .milliseconds = completion_wait_ms }) catch |err| {
        if (!wire.Client.unavailable(err) or self.transport.last_rejection != .HttpCapacity) return err;
        try self.transport.http.io.sleep(.fromMilliseconds(completion_wait_ms), .awake);
        return;
    };
    if (response.body != .process) return error.InvalidAuthorityResponse;
}
/// Explicitly resume the same accepted intent after a paused continuation.
pub fn prepareResume(self: *Self, intent: *const Intent) !Prepared {
    return self.sign(try self.resumeValue(intent));
}
pub fn resumeCandidate(self: *Self, intent: *const Intent, sequence: u64) !Candidate {
    return self.candidate(try self.resumeValue(intent), sequence);
}
fn resumeValue(self: *Self, intent: *const Intent) !p.Value {
    try self.connection.header(intent.header);
    var current = try self.intentSource(intent, null);
    if (try self.uploadStatus(&current, intent)) |upload_value| {
        if (upload_value.phase == .cancelled) return error.TableUploadClosed;
        if (upload_value.phase == .uploading) return error.TableUploadNotReady;
        const value = try self.prepareAt(&current, try (Control.Command{ .drive = intent.upload() }).encode());
        try current.finish();
        return value;
    }
    if (intent.body.len > s.Frame.max_payload) return error.TableUploadNotFound;
    const value = try self.prepareAt(&current, try p.Value.init(intent.body));
    try current.finish();
    return value;
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    if (!std.meta.eql(self.connection, prepared.connection)) return error.CatalogIdentityConflict;
    try prepared.verify();
}
/// Exactly one attempt with original signed bytes; no metadata query or retry.
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    return self.transport.submit(prepared.signed);
}
/// Receipt recovery authenticates the current credential but addresses the old
/// exact request. Absence never authorizes replacing its sequence or signature.
pub fn receipt(self: *Self, prepared: Prepared) !?p.Receipt {
    try self.validate(prepared);
    const authority: wire.AuthorizationClient = .{ .transport = self.transport, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key };
    return (try authority.read(.{ .receipt = prepared.signed.request })).body.authorization.body.receipt;
}
pub fn observe(self: *Self, prepared: Prepared, input: u64) !Observation {
    return self.observeBounded(prepared, input, null);
}
pub fn waitObserve(self: *Self, prepared: Prepared, input: u64) !Observation {
    return self.observeBounded(prepared, input, completion_wait_ms);
}
fn observeBounded(self: *Self, prepared: Prepared, input: u64, milliseconds: ?u32) !Observation {
    try c.Model.nativeId(input);
    try self.inspectPrepared(prepared);
    const result = try self.observeNative(prepared, input, milliseconds);
    try self.inspectPrepared(prepared);
    return result;
}
/// Verify retained signing bytes independently from a current credential. The
/// current subject still needs disclosure rights; only native evidence proves
/// that a saved request was accepted, including after rotation.
pub fn inspectPrepared(self: *Self, prepared: Prepared) !void {
    try self.validate(prepared);
    const command = try prepared.command();
    if (command == .control and command.control == .initialize) {
        // Provisioning uses the direct native operator profile. The mediated
        // caller surface cannot use an uninstalled configuration as authority.
        if (self.authority != null or self.reader != null) return error.CatalogDenied;
        return;
    }
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    if (command == .inline_command) {
        try self.inspectHeader(&current, owner, command.inline_command);
    } else switch (command.control) {
        .initialize => unreachable,
        .schema => |request| _ = try (c.SchemaCatalog{ .configuration = owner.configuration }).status(&current, self.connection.principal, request),
        .dependency => |change| _ = try owner.authorizeObject(&current, self.connection.principal, change.dependency.object, .inspect),
        .begin => |begin| try self.inspectHeader(&current, owner, try c.TableCommand.inspect(&begin.header)),
        .part, .seal, .drive, .cancel_upload, .collect_upload => {
            const namespace = switch (command.control) {
                .part => |part| part.upload.namespace,
                .seal, .drive, .cancel_upload, .collect_upload => |upload_value| upload_value.namespace,
                else => unreachable,
            };
            _ = try (c.TableUpload{ .catalog = owner }).status(&current, self.connection.principal, namespace);
        },
        .cancel_ddl, .cleanup_ddl => |ref| _ = (try owner.status(&current, ref.principal, ref.operation, ref.digest)) orelse return error.CatalogOperationNotFound,
        .cancel_dml, .cleanup_dml => |ref| _ = (try owner.mutationReceipt(&current, self.connection.principal, ref.reference)) orelse return error.TableWriteNotFound,
    }
    try current.finish();
}
fn inspectHeader(self: *Self, current: *Source, owner: c.TableCatalog, header: c.TableCommand.Header) !void {
    if (header.right() == .create) {
        _ = try owner.authorizeCreationInspection(current, self.connection.principal, header.object);
        return;
    }
    _ = try owner.authorizeObject(current, self.connection.principal, header.object, .inspect);
}
fn observeNative(self: *Self, prepared: Prepared, input: u64, milliseconds: ?u32) !Observation {
    try self.validate(prepared);
    try c.Model.nativeId(input);
    try self.verifyAdmission(prepared, input);
    errdefer self.pending_observation = null;
    const previous = self.pending_observation;
    self.pending_observation = null;
    const resources_value = self.resources();
    const query: g.Query = .{ .realm = self.connection.scope.realm, .principal = resources_value.principal, .kind = .{ .process = self.connection.owner } };
    const response = response: {
        if (milliseconds) |duration| if (previous) |cursor| {
            if (cursor.input == input and std.mem.eql(u8, &cursor.signature, &prepared.signed.signature)) {
                break :response resources_value.wire.waitForChange(query, resources_value.key, .{ .after = cursor.position, .milliseconds = duration }) catch |err| {
                    if (!wire.Client.unavailable(err) or self.transport.last_rejection != .HttpCapacity) return err;
                    try self.transport.http.io.sleep(.fromMilliseconds(duration), .awake);
                    break :response try resources_value.wire.query(query, resources_value.key);
                };
            }
        };
        break :response try resources_value.wire.query(query, resources_value.key);
    };
    if (input > response.position) return error.InvalidCatalogPrepared;
    if (response.body != .process) return error.InvalidAuthorityResponse;
    const state = response.body.process;
    if (state.process.lifecycle != .running or state.process.failure != null) return error.CatalogOwnerUnavailable;
    if (state.input) |head| {
        if (head.position == input and (head.origin != .external or head.origin.external.principal != self.connection.principal or !head.value.eql(prepared.signed.request.command.send.value))) return error.CatalogIdentityConflict;
        if (head.position <= input) {
            self.pending_observation = .{ .signature = prepared.signed.signature, .input = input, .position = response.position };
            return .pending;
        }
    }
    return .processed;
}
pub fn inputDisposition(self: *Self, prepared: Prepared, input: u64) !?Control.Disposition {
    try c.Model.nativeId(input);
    try self.inspectPrepared(prepared);
    try self.verifyAdmission(prepared, input);
    const target = self.address('e', input, 0);
    var current = try self.source(&.{target});
    const result = try self.dispositionFrom(&current, prepared, input);
    try current.finish();
    try self.inspectPrepared(prepared);
    return result;
}
fn verifyAdmission(self: *Self, prepared: Prepared, input: u64) !void {
    const resources_value = self.resources();
    const authority: wire.AuthorizationClient = .{ .transport = resources_value.wire, .realm = self.connection.scope.realm, .principal = resources_value.principal, .key = resources_value.key };
    const accepted = (try authority.read(.{ .receipt = prepared.signed.request })).body.authorization.body.receipt orelse return error.InvalidCatalogPrepared;
    if (accepted.position != input) return error.CatalogIdentityConflict;
}
fn dispositionFrom(self: *Self, current: *Source, prepared: Prepared, input: u64) !?Control.Disposition {
    const target = self.address('e', input, 0);
    const owner = try self.catalog(current);
    _ = try owner.authorize(current, self.connection.principal, .inspect);
    const result = try c.Records.decode(Control.Disposition, 'E', (try current.read(target)) orelse return null);
    if (!std.meta.eql(result.scope, self.connection.scope) or result.origin != .external or result.principal != self.connection.principal or result.input != input or !std.mem.eql(u8, &result.payload, &try c.Model.fingerprint(prepared.signed.request.command.send.value))) return error.CatalogIdentityConflict;
    return result;
}
/// Mailbox processing and both result domains are acquired separately. The
/// latter share one current authorized cut; terminal SQL alone is not proof
/// that this particular native input was processed.
pub fn progress(self: *Self, intent: *const Intent, prepared: Prepared, input: u64) !Progress {
    if (!try prepared.matches(intent)) return error.CatalogIdentityConflict;
    if (try self.observe(prepared, input) == .pending) return .pending;
    return self.processed(intent, prepared, input);
}
pub fn waitProgress(self: *Self, intent: *const Intent, prepared: Prepared, input: u64) !Progress {
    if (!try prepared.matches(intent)) return error.CatalogIdentityConflict;
    if (try self.waitObserve(prepared, input) == .pending) return .pending;
    return self.processed(intent, prepared, input);
}
fn processed(self: *Self, intent: *const Intent, prepared: Prepared, input: u64) !Progress {
    var current = try self.intentSource(intent, input);
    const result: Progress = .{ .processed = .{ .disposition = try self.dispositionFrom(&current, prepared, input), .outcome = try self.outcome(&current, intent.identity), .upload = try self.uploadStatus(&current, intent) } };
    try current.finish();
    return result;
}
