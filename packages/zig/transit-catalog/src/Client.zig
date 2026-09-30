//! Shared signed catalog caller. Preparation and receipt recovery remain
//! explicit; a native send receipt does not establish catalog publication.
const std = @import("std");
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const g = p.Growth;
const m = c.Model;
const r = c.Records;
const wire = s.client;
const Self = @This();
transport: *wire.Client,
connection: Connection,
key: p.Ed25519.KeyPair,
batch_support: bool = false,

pub const Connection = struct {
    scope: m.Scope,
    owner: u64,
    principal: u64,
    pub fn validate(self: Connection) !void {
        try self.scope.validate();
        try m.nativeId(self.owner);
        if (self.principal > p.max_counter) return error.InvalidCatalogIdentity;
    }
};
pub const Description = struct {
    configuration: m.Configuration,
    policy: m.Policy,
    resource_revision: u64,
};
pub const Prepared = struct {
    version: u8,
    definition: g.Definition,
    connection: Connection,
    signed: g.SignedRequest,
    pub const max_saved_bytes = 8192;
    pub fn command(self: Prepared) !m.Command {
        if (self.version != 1) return error.InvalidCatalogPrepared;
        try self.connection.validate();
        try g.validate(self.signed.request);
        const envelope = self.signed.request;
        if (envelope.command != .send) return error.InvalidCatalogPrepared;
        if (envelope.realm != self.connection.scope.realm or envelope.principal != self.connection.principal or envelope.command.send.pid != self.connection.owner) return error.CatalogIdentityConflict;
        const frame = try s.Frame.decode(envelope.command.send.value);
        if (frame.kind != .cast) return error.InvalidCatalogPrepared;
        const result = try m.Command.decode(frame.payload);
        if (!std.meta.eql(result.scope(), self.connection.scope)) return error.CatalogScopeChanged;
        if (result == .initialize and (result.initialize.owner != self.connection.owner or result.initialize.administrator != self.connection.principal)) return error.CatalogIdentityConflict;
        return result;
    }
    pub fn request(self: Prepared) !m.CreateTable {
        return switch (try self.command()) {
            .create_table => |value| value,
            else => error.InvalidCatalogPrepared,
        };
    }
    pub fn save(self: Prepared, allocator: std.mem.Allocator) ![]u8 {
        _ = try self.command();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
    /// Complete canonical input, mandatory definitions and owned values. This
    /// validates structure; submit additionally verifies the caller's signature.
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
pub const Observation = enum { pending, processed };

fn resources(self: *Self) wire.ResourceReader {
    return .{ .wire = self.transport, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key };
}
fn address(self: *Self, tag: u8, id: u64, revision: u64) p.Value {
    return r.key(self.connection.scope.catalog, tag, id, revision);
}
fn batch(self: *Self, operation: ?u64) !wire.ResourceReader.Batch {
    const keys = [_]p.Value{
        self.address('c', 0, 0),
        self.address('p', self.connection.principal, 0),
        self.address('o', self.connection.principal, operation orelse 0),
    };
    return self.batchKeys(keys[0..if (operation == null) @as(usize, 2) else 3]);
}
fn batchKeys(self: *Self, keys: []const p.Value) !wire.ResourceReader.Batch {
    try self.connection.validate();
    if (!self.batch_support) {
        _ = try self.resources().batches();
        self.batch_support = true;
    }
    const result = try (wire.ResourceReader.Batches{ .client = self.resources() }).read(self.connection.scope.resource, null, keys);
    if (result.resource.id != self.connection.scope.resource or result.resource.writer != self.connection.owner or result.resource.phase != .active) return error.CatalogOwnerChanged;
    return result;
}
fn configuration(self: *Self, source: *const wire.ResourceReader.Batch) !m.Configuration {
    const config = try r.decode(m.Configuration, 'c', (try source.read(self.address('c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config.scope, self.connection.scope) or config.owner != self.connection.owner) return error.CatalogConfigurationChanged;
    return config;
}
fn describeBatch(self: *Self, source: *const wire.ResourceReader.Batch) !Description {
    const config = try self.configuration(source);
    const policy = try r.decode(m.Policy, 'p', (try source.read(self.address('p', self.connection.principal, 0))) orelse return error.CatalogDenied);
    if (!std.meta.eql(policy.scope, config.scope) or policy.principal != self.connection.principal) return error.InvalidCatalogPolicy;
    if (!policy.create and !policy.inspect) return error.CatalogDenied;
    return .{ .configuration = config, .policy = policy, .resource_revision = source.view.revision };
}
fn receiptFrom(self: *Self, source: *const wire.ResourceReader.Batch, request: m.CreateTable) !?m.Receipt {
    const value = (try source.read(self.address('o', self.connection.principal, request.operation))) orelse return null;
    const result = try r.decode(m.Receipt, 'o', value);
    if (result.principal != self.connection.principal or !std.meta.eql(result.request, request)) return error.CatalogIdentityConflict;
    return result;
}
fn checkRequest(self: *Self, request: m.CreateTable) !void {
    try self.connection.validate();
    try request.validate();
    if (!std.meta.eql(self.connection.scope, request.scope)) return error.CatalogScopeChanged;
}
/// One current metadata batch. No retained view, permission cache or admission.
pub fn describe(self: *Self) !Description {
    const current = try self.batch(null);
    return self.describeBatch(&current);
}
const MetadataReader = struct {
    metadata: wire.ResourceReader.Batch,
    prefetched: ?wire.ResourceReader.Batch = null,
    current: wire.ResourceReader.Reader,
    view: @FieldType(wire.ResourceReader.Reader, "view"),
    pub fn read(self: *@This(), key: p.Value) !?p.Value {
        // Only the configuration and policy from this operation's initial
        // authorized batch are cached. Other reads enforce its exact cut.
        for (self.metadata.keys) |slot| if (slot) |requested| {
            if (requested.eql(key)) return self.metadata.read(key);
        };
        if (self.prefetched) |*batch_value| {
            for (batch_value.keys) |slot| if (slot) |requested| {
                if (requested.eql(key)) return batch_value.read(key);
            };
        }
        return self.current.read(key);
    }
    pub fn prefetch(self: *@This(), keys: []const p.Value) !void {
        if (keys.len > g.page_size) return error.InvalidCatalogPage;
        var unique: [g.page_size]p.Value = undefined;
        var count: usize = 0;
        next_key: for (keys) |key| {
            for (unique[0..count]) |old| if (old.eql(key)) continue :next_key;
            unique[count] = key;
            count += 1;
        }
        if (count == 0) return;
        // Batch support was negotiated by metadataReader. This observation is
        // confined to this operation and replaces the preceding dependency
        // layer; it does not cache authority or grow with the catalog.
        const batch_value = try (wire.ResourceReader.Batches{ .client = self.current.client }).read(self.view.resource, self.view.revision, unique[0..count]);
        if (batch_value.resource.id != self.view.resource or batch_value.resource.revision != self.view.revision or batch_value.resource.phase != .active or batch_value.resource.writer != self.metadata.resource.writer) return error.CatalogOwnerChanged;
        self.prefetched = batch_value;
    }
    pub fn page(self: *@This(), after: ?p.Value) !g.Batch(g.Entry, p.Value) {
        return self.current.page(after);
    }
};
fn metadataReader(self: *Self) !MetadataReader {
    const metadata = try self.batch(null);
    const reader: wire.ResourceReader.Reader = .{ .client = self.resources(), .view = .{ .resource = metadata.view.resource, .revision = metadata.view.revision } };
    return .{ .metadata = metadata, .current = reader, .view = reader.view };
}
/// Current-policy metadata reads create neither retained views nor admissions.
pub fn lookup(self: *Self, name: c.fuze.model.Name) !?m.Definition {
    var source = try self.metadataReader();
    return (c.Inspection{ .configuration = try self.configuration(&source.metadata), .principal = self.connection.principal }).lookup(&source, name);
}
pub fn definition(self: *Self, object: u64, revision: u64) !?m.Definition {
    if (object == 0 or revision == 0) return error.InvalidCatalogIdentity;
    var source = try self.metadataReader();
    return (c.Inspection{ .configuration = try self.configuration(&source.metadata), .principal = self.connection.principal }).definition(&source, object, revision);
}
/// At most eight name-ordered definitions. Each page requires current native
/// and catalog inspection rights; a changed revision rejects continuation.
pub fn list(self: *Self, cursor: ?c.Inspection.Cursor) !c.Inspection.Page {
    var source = try self.metadataReader();
    return (c.Inspection{ .configuration = try self.configuration(&source.metadata), .principal = self.connection.principal }).list(&source, cursor);
}
/// Prepare a new signed send after checking current create policy and exact
/// application identity. Reusing a principal concurrently can race its sequence;
/// never prepare again to retry an uncertain send.
pub fn prepareCreate(self: *Self, request: m.CreateTable) !Prepared {
    try self.checkRequest(request);
    const current = try self.batch(request.operation);
    if (!(try self.describeBatch(&current)).policy.create) return error.CatalogDenied;
    _ = try self.receiptFrom(&current, request);
    return self.sign(.{ .create_table = request });
}
/// Provisioning is explicit. Missing configuration permits a proposal only;
/// the supplied owner still checks empty state and the authenticated administrator.
pub fn prepareInitialize(self: *Self, config: m.Configuration) !Prepared {
    try self.connection.validate();
    try config.validate();
    if (!std.meta.eql(config.scope, self.connection.scope)) return error.CatalogScopeChanged;
    if (config.owner != self.connection.owner or config.administrator != self.connection.principal) return error.CatalogIdentityConflict;
    const current = try self.batchKeys(&.{self.address('c', 0, 0)});
    if (try current.read(self.address('c', 0, 0))) |_| {
        if (!std.meta.eql(config, try self.configuration(&current))) return error.CatalogConfigurationChanged;
    }
    return self.sign(.{ .initialize = config });
}
/// Administrator authority is independent of that principal's create/inspect
/// policy. The owner rechecks this conditional transition at application time.
pub fn preparePolicy(self: *Self, change: m.PolicyChange) !Prepared {
    try self.connection.validate();
    try change.validate();
    if (!std.meta.eql(change.policy.scope, self.connection.scope)) return error.CatalogScopeChanged;
    const address_policy = self.address('p', change.policy.principal, 0);
    const current = try self.batchKeys(&.{ self.address('c', 0, 0), address_policy });
    if ((try self.configuration(&current)).administrator != self.connection.principal) return error.CatalogDenied;
    if (try current.read(address_policy)) |bytes| {
        const previous = try r.decode(m.Policy, 'p', bytes);
        if (!std.meta.eql(previous.scope, self.connection.scope) or previous.principal != change.policy.principal) return error.InvalidCatalogPolicy;
        if (!std.meta.eql(previous, change.policy) and previous.revision != change.expected_revision) return error.CatalogPolicyConflict;
    } else if (change.expected_revision != 0) return error.CatalogPolicyConflict;
    return self.sign(.{ .set_policy = change });
}
fn sign(self: *Self, command: m.Command) !Prepared {
    const sequence = (try self.resources().query(.capabilities)).principal_sequence;
    return .{ .version = 1, .definition = g.current_definition, .connection = self.connection, .signed = try g.sign(.{
        .realm = self.connection.scope.realm,
        .principal = self.connection.principal,
        .sequence = try std.math.add(u64, sequence, 1),
        .command = .{ .send = .{ .pid = self.connection.owner, .value = try (s.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } },
    }, self.key) };
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    if (!std.meta.eql(self.connection, prepared.connection)) return error.CatalogIdentityConflict;
    _ = try prepared.command();
    try p.Ed25519.Signature.fromBytes(prepared.signed.signature).verify(&try g.digest(prepared.signed.request), self.key.public_key);
}
/// Exactly one transport attempt with the original signature/sequence. It makes
/// no metadata lookup, re-signing decision or automatic retry.
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    return self.transport.submit(prepared.signed);
}
/// Current native and catalog inspection rights apply to original outcomes too.
/// The complete original request prevents retargeting an operation ID.
pub fn status(self: *Self, request: m.CreateTable) !?m.Receipt {
    try self.checkRequest(request);
    const current = try self.batch(request.operation);
    if (!(try self.describeBatch(&current)).policy.inspect) return error.CatalogDenied;
    return self.receiptFrom(&current, request);
}
/// A supplied behavior records rejected inputs separately from application
/// receipts. Absence is not proof of success; current inspect rights still apply.
pub fn inputDisposition(self: *Self, prepared: Prepared, input: u64) !?m.Disposition {
    try self.validate(prepared);
    try m.nativeId(input);
    const target = self.address('e', input, 0);
    const current = try self.batchKeys(&.{ self.address('c', 0, 0), self.address('p', self.connection.principal, 0), target });
    if (!(try self.describeBatch(&current)).policy.inspect) return error.CatalogDenied;
    const value = (try current.read(target)) orelse return null;
    const result = try r.decode(m.Disposition, 'e', value);
    if (!std.meta.eql(result.scope, self.connection.scope) or result.origin != .external or result.principal != self.connection.principal or result.input != input or !std.mem.eql(u8, &result.payload, &try m.Disposition.fingerprint(prepared.signed.request.command.send.value))) return error.CatalogIdentityConflict;
    return result;
}
/// Input processing is separate from application success. Supply the position
/// from this exact send's native receipt and inspect status after processing.
pub fn observe(self: *Self, prepared: Prepared, input: u64) !Observation {
    try self.validate(prepared);
    try m.nativeId(input);
    const response = try self.resources().query(.{ .process = self.connection.owner });
    if (input > response.position) return error.InvalidCatalogPrepared;
    const state = response.body.process;
    if (state.process.lifecycle != .running or state.process.failure != null) return error.CatalogOwnerUnavailable;
    if (state.input) |head| {
        if (head.position == input and (head.origin != .external or head.origin.external.principal != self.connection.principal or !head.value.eql(prepared.signed.request.command.send.value))) return error.CatalogIdentityConflict;
        if (head.position <= input) return .pending;
    }
    return .processed;
}
