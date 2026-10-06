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
batch_support: bool = false,
// Scheduling only; never cache authorization, progress or application truth.
pending_observation: ?struct { signature: [64]u8, input: u64, position: u64 } = null,
pub const completion_wait_ms: u32 = 50;
pub const Connection = struct {
    scope: m.Scope,
    owner: u64,
    principal: u64,
    pub fn validate(self: Connection) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.owner);
        if (self.principal > p.max_counter) return error.InvalidCatalogIdentity;
    }
    pub fn header(self: Connection, value: c.TableCommand.Header) !void {
        try self.validate();
        try value.validate();
        if (!std.meta.eql(self.scope, value.scope) or self.owner != value.owner or self.principal != value.principal) return error.CatalogIdentityConflict;
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
        else => {},
    }
    return .{ .control = command };
}
pub const Prepared = struct {
    version: u8,
    definition: g.Definition,
    connection: Connection,
    signed: g.SignedRequest,
    pub const max_saved_bytes = 8192;
    pub fn command(self: Prepared) !Payload {
        if (self.version != 1) return error.InvalidCatalogPrepared;
        try self.connection.validate();
        try g.validate(self.signed.request);
        const envelope = self.signed.request;
        if (envelope.command != .send) return error.InvalidCatalogPrepared;
        if (envelope.realm != self.connection.scope.realm or envelope.principal != self.connection.principal or envelope.command.send.pid != self.connection.owner) return error.CatalogIdentityConflict;
        const frame = try s.Frame.decode(envelope.command.send.value);
        if (frame.kind != .cast) return error.InvalidCatalogPrepared;
        return payload(self.connection, frame.payload);
    }
    pub fn matches(self: Prepared, intent: *const Intent) !bool {
        _ = try self.command();
        try self.connection.header(intent.header);
        return intent.matches((try s.Frame.decode(self.signed.request.command.send.value)).payload);
    }
    pub fn save(self: Prepared, allocator: std.mem.Allocator) ![]u8 {
        _ = try self.command();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Prepared {
        if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidCatalogPrepared;
        const parsed = std.json.parseFromSlice(Prepared, allocator, bytes, .{}) catch |err| return if (err == error.OutOfMemory) err else error.InvalidCatalogPrepared;
        defer parsed.deinit();
        _ = parsed.value.command() catch return error.InvalidCatalogPrepared;
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidCatalogPrepared;
        return parsed.value;
    }
};
pub const Description = struct { configuration: m.Configuration, policy: m.Policy, resource_revision: u64 };
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
fn resources(self: *Self) wire.ResourceReader {
    return .{ .wire = self.transport, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key };
}
fn address(self: *Self, tag: u8, id: u64, revision: u64) p.Value {
    return c.Records.key(self.connection.scope.catalog, tag, id, revision);
}
fn batch(self: *Self, extra: []const p.Value) !wire.ResourceReader.Batch {
    try self.connection.validate();
    if (extra.len > g.page_size - 2) return error.InvalidCatalogPage;
    if (!self.batch_support) {
        _ = try self.resources().batches();
        self.batch_support = true;
    }
    var keys: [g.page_size]p.Value = undefined;
    keys[0] = self.address('c', 0, 0);
    keys[1] = self.address('p', self.connection.principal, 0);
    var count: usize = 2;
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
    metadata: wire.ResourceReader.Batch,
    reader: wire.ResourceReader.Reader,
    view: @FieldType(wire.ResourceReader.Reader, "view"),
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        for (self.metadata.keys) |slot| if (slot) |requested| if (requested.eql(key)) return self.metadata.read(key);
        return self.reader.read(key);
    }
    pub fn page(self: *@This(), after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        return self.reader.page(after);
    }
};
fn source(self: *Self, extra: []const p.Value) !Source {
    const metadata = try self.batch(extra);
    const reader: wire.ResourceReader.Reader = .{ .client = self.resources(), .view = .{ .resource = metadata.view.resource, .revision = metadata.view.revision } };
    return .{ .metadata = metadata, .reader = reader, .view = reader.view };
}
fn catalog(self: *Self, current: *Source) !c.TableCatalog {
    const config = try c.Records.decode(m.Configuration, 'C', (try current.read(self.address('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config.scope, self.connection.scope) or config.owner != self.connection.owner) return error.CatalogConfigurationChanged;
    return .{ .configuration = config };
}
pub fn describe(self: *Self) !Description {
    var current = try self.source(&.{});
    const owner = try self.catalog(&current);
    const policy = try owner.authorize(&current, self.connection.principal, .inspect);
    return .{ .configuration = owner.configuration, .policy = policy, .resource_revision = current.view.revision };
}
/// Every acquisition checks current native/scoped rights and one exact cut.
/// No current metadata observation becomes a retained query snapshot.
pub fn lookup(self: *Self, allocator: std.mem.Allocator, name: c.TableMetadata.Name) !?c.TableCatalog.Definition {
    var current = try self.source(&.{});
    return (try self.catalog(&current)).lookup(allocator, &current, self.connection.principal, name);
}
pub fn list(self: *Self, allocator: std.mem.Allocator, cursor: ?c.TableCatalog.Cursor) !c.TableCatalog.Page {
    var current = try self.source(&.{});
    return (try self.catalog(&current)).list(allocator, &current, self.connection.principal, cursor);
}
pub const CompileIdentity = struct { operation: u64, namespace: u64, create_object: ?u64 = null };
/// SQL and typed callers lower to the same immutable intent. Names resolve at
/// this preparation boundary only; saved recovery never invokes this method.
pub fn compile(self: *Self, allocator: std.mem.Allocator, text: []const u8, identity: CompileIdentity, location: ?*c.fuze.Sql.Location) !Intent {
    try self.connection.validate();
    if (identity.operation == 0 or identity.namespace == 0 or identity.create_object == 0) return error.InvalidCatalogIdentity;
    var names: std.heap.ArenaAllocator = .init(allocator);
    defer names.deinit();
    const ddl_target = c.fuze.TableDdl.target(names.allocator(), text) catch |err| switch (err) {
        error.UnsupportedStatement => null,
        else => return err,
    };
    if (ddl_target) |target| {
        if (target.kind == .create) {
            const object = identity.create_object orelse return error.InvalidCatalogIdentity;
            var statement = try c.fuze.TableDdl.compile(allocator, text, null, location);
            defer statement.deinit();
            const value = statement.statement.create;
            const request: c.TableDdlRequest = .{ .principal = self.connection.principal, .operation = identity.operation, .object = object, .expected_revision = 0, .name = try c.TableMetadata.Name.init(value.name), .action = .{ .create = .{ .schema = try value.bind(object), .if_not_exists = value.if_not_exists } } };
            return Intent.create(allocator, try c.TableCommand.fromDdl(self.connection.scope, self.connection.owner, request, null), identity.namespace);
        }
        if (identity.create_object != null) return error.InvalidCatalogIdentity;
        var definition = try self.lookup(allocator, try c.TableMetadata.Name.init(target.name));
        defer if (definition) |*value| value.deinit();
        var statement = try c.fuze.TableDdl.compile(allocator, text, if (definition) |value| value.schema.schema else null, location);
        defer statement.deinit();
        const record = if (definition) |value| value.metadata else null;
        var request: c.TableDdlRequest = .{ .principal = self.connection.principal, .operation = identity.operation, .object = if (record) |value| value.object else 0, .expected_revision = if (record) |value| value.revision else 0, .name = try c.TableMetadata.Name.init(target.name), .action = undefined };
        request.action = switch (statement.statement) {
            .create => unreachable,
            .alter => |alter| switch (alter.action) {
                .columns => |change| .{ .alter = .{ .schema = definition.?.schema.schema, .change = change } },
                .rename_table => |name| .{ .rename = try c.TableMetadata.Name.init(name) },
            },
            .drop => |drop| .{ .drop = .{ .if_exists = drop.if_exists } },
        };
        return Intent.create(allocator, try c.TableCommand.fromDdl(self.connection.scope, self.connection.owner, request, record), identity.namespace);
    }
    if (identity.create_object != null) return error.InvalidCatalogIdentity;
    const target = try c.fuze.TableDml.target(names.allocator(), text);
    var definition = (try self.lookup(allocator, try c.TableMetadata.Name.init(target.name))) orelse return error.TableNotFound;
    defer definition.deinit();
    var statement = try c.fuze.TableDml.compile(allocator, text, definition.metadata.name.slice(), definition.schema.schema, location);
    defer statement.deinit();
    const request: c.TableDmlRequest = .{ .principal = self.connection.principal, .operation = identity.operation, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .plan = statement.plan };
    return Intent.create(allocator, try c.TableCommand.fromDml(self.connection.scope, self.connection.owner, request, definition.metadata), identity.namespace);
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
    return self.outcome(&current, intent.identity);
}
fn uploadStatus(self: *Self, current: *Source, intent: *const Intent) !?c.TableUpload.Status {
    const owner = try self.catalog(current);
    const value = (c.TableUpload{ .catalog = owner }).status(current, self.connection.principal, intent.namespace) catch |err| return if (err == error.TableUploadNotFound) null else err;
    if (!std.meta.eql(value.header, intent.header) or !std.meta.eql(value.spec, intent.spec)) return error.CatalogIdentityConflict;
    return value;
}
fn sign(self: *Self, value: p.Value) !Prepared {
    _ = try payload(self.connection, value);
    const sequence = (try self.resources().query(.capabilities)).principal_sequence;
    return .{ .version = 1, .definition = g.current_definition, .connection = self.connection, .signed = try g.sign(.{ .realm = self.connection.scope.realm, .principal = self.connection.principal, .sequence = try std.math.add(u64, sequence, 1), .command = .{ .send = .{ .pid = self.connection.owner, .value = try (s.Frame{ .kind = .cast, .payload = value }).encode() } } }, self.key) };
}
fn prepareAt(self: *Self, current: *Source, value: p.Value) !Prepared {
    const command = try payload(self.connection, value);
    if (command == .control and command.control == .initialize) {
        if (try current.read(self.address('c', 0, 0)) != null and !std.meta.eql((try self.catalog(current)).configuration, command.control.initialize)) return error.CatalogConfigurationChanged;
        return self.sign(value);
    }
    const owner = try self.catalog(current);
    if (command == .inline_command) {
        _ = try owner.authorize(current, self.connection.principal, .inspect);
        _ = try owner.authorize(current, self.connection.principal, command.inline_command.right());
        return self.sign(value);
    }
    switch (command.control) {
        .initialize => unreachable,
        .policy, .dependency => if (owner.configuration.administrator != self.connection.principal) return error.CatalogDenied,
        .begin => |begin| {
            _ = try owner.authorize(current, self.connection.principal, .inspect);
            _ = try owner.authorize(current, self.connection.principal, (try c.TableCommand.inspect(&begin.header)).right());
        },
        .part, .seal, .drive, .cancel_upload, .collect_upload => {
            const namespace = switch (command.control) {
                .part => |part| part.upload.namespace,
                .seal, .drive, .cancel_upload, .collect_upload => |upload_value| upload_value.namespace,
                else => unreachable,
            };
            const upload_value = try (c.TableUpload{ .catalog = owner }).status(current, self.connection.principal, namespace);
            if (command.control == .part or command.control == .seal or command.control == .drive) _ = try owner.authorize(current, self.connection.principal, upload_value.header.right());
        },
        .cancel_ddl, .cleanup_ddl => |ref| _ = (try owner.status(current, ref.principal, ref.operation, ref.digest)) orelse return error.CatalogOperationNotFound,
        .cancel_dml, .cleanup_dml => |ref| _ = (try owner.mutationReceipt(current, self.connection.principal, ref.reference)) orelse return error.TableWriteNotFound,
    }
    return self.sign(value);
}
pub fn prepareControl(self: *Self, command: Control.Command) !Prepared {
    const value = try command.encode();
    _ = try payload(self.connection, value);
    var current = try self.source(&.{});
    return self.prepareAt(&current, value);
}
/// Prepare one next upload/send only when no automatic execution is in flight.
/// Persist the returned Prepared before submit. An uncertain prior send must
/// be retried with submit(original), never by calling next again.
pub fn next(self: *Self, intent: *const Intent) !Next {
    var current = try self.intentSource(intent, null);
    if (try self.outcome(&current, intent.identity)) |result| {
        if (result.terminal()) return .{ .terminal = result };
        return .running;
    }
    const upload_value = (try self.uploadStatus(&current, intent)) orelse {
        if (intent.body.len <= s.Frame.max_payload) return .{ .send = try self.prepareAt(&current, try p.Value.init(intent.body)) };
        return .{ .send = try self.prepareAt(&current, try (Control.Command{ .begin = .{ .header = try intent.header.encode(), .namespace = intent.namespace, .spec = intent.spec } }).encode()) };
    };
    const command: Control.Command = switch (upload_value.phase) {
        .sealed, .ready => return .running,
        .cancelled => return .upload_cancelled,
        .uploading => if (upload_value.received == upload_value.spec.length) .{ .seal = intent.upload() } else .{ .part = try Control.Part.init(intent.upload(), upload_value.received, intent.body[upload_value.received..][0..@min(c.TableUpload.part_bytes, intent.body.len - upload_value.received)]) },
    };
    return .{ .send = try self.prepareAt(&current, try command.encode()) };
}
/// Explicitly resume the same accepted intent after a paused continuation.
pub fn prepareResume(self: *Self, intent: *const Intent) !Prepared {
    try self.connection.header(intent.header);
    var current = try self.intentSource(intent, null);
    if (try self.uploadStatus(&current, intent)) |upload_value| {
        if (upload_value.phase == .cancelled) return error.TableUploadClosed;
        if (upload_value.phase == .uploading) return error.TableUploadNotReady;
        return self.prepareAt(&current, try (Control.Command{ .drive = intent.upload() }).encode());
    }
    if (intent.body.len > s.Frame.max_payload) return error.TableUploadNotFound;
    return self.prepareAt(&current, try p.Value.init(intent.body));
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    if (!std.meta.eql(self.connection, prepared.connection)) return error.CatalogIdentityConflict;
    _ = try prepared.command();
    try p.Ed25519.Signature.fromBytes(prepared.signed.signature).verify(&try g.digest(prepared.signed.request), self.key.public_key);
}
/// Exactly one attempt with original signed bytes; no metadata query or retry.
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    return self.transport.submit(prepared.signed);
}
pub fn observe(self: *Self, prepared: Prepared, input: u64) !Observation {
    return self.observeBounded(prepared, input, null);
}
pub fn waitObserve(self: *Self, prepared: Prepared, input: u64) !Observation {
    return self.observeBounded(prepared, input, completion_wait_ms);
}
fn observeBounded(self: *Self, prepared: Prepared, input: u64, milliseconds: ?u32) !Observation {
    try self.validate(prepared);
    try c.Model.nativeId(input);
    errdefer self.pending_observation = null;
    const previous = self.pending_observation;
    self.pending_observation = null;
    const query: g.Query = .{ .realm = self.connection.scope.realm, .principal = self.connection.principal, .kind = .{ .process = self.connection.owner } };
    const response = response: {
        if (milliseconds) |duration| if (previous) |cursor| {
            if (cursor.input == input and std.mem.eql(u8, &cursor.signature, &prepared.signed.signature)) {
                break :response self.transport.waitForChange(query, self.key, .{ .after = cursor.position, .milliseconds = duration }) catch |err| {
                    if (!wire.Client.unavailable(err) or self.transport.last_rejection != .HttpCapacity) return err;
                    try self.transport.http.io.sleep(.fromMilliseconds(duration), .awake);
                    break :response try self.transport.query(query, self.key);
                };
            }
        };
        break :response try self.transport.query(query, self.key);
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
    try self.validate(prepared);
    try c.Model.nativeId(input);
    const target = self.address('e', input, 0);
    var current = try self.source(&.{target});
    return self.dispositionFrom(&current, prepared, input);
}
fn dispositionFrom(self: *Self, current: *Source, prepared: Prepared, input: u64) !?Control.Disposition {
    const target = self.address('e', input, 0);
    const owner = try self.catalog(current);
    _ = try owner.authorize(current, self.connection.principal, .inspect);
    const result = try c.Records.decode(Control.Disposition, 'E', (try current.read(target)) orelse return null);
    if (!std.meta.eql(result.scope, self.connection.scope) or result.origin != .external or result.principal != self.connection.principal or result.input != input or !std.mem.eql(u8, &result.payload, &try c.Model.Disposition.fingerprint(prepared.signed.request.command.send.value))) return error.CatalogIdentityConflict;
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
    return .{ .processed = .{ .disposition = try self.dispositionFrom(&current, prepared, input), .outcome = try self.outcome(&current, intent.identity), .upload = try self.uploadStatus(&current, intent) } };
}
