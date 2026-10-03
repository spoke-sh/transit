//! Prepare ordinary native signatures without lending an operator's private key
//! to a web host. Context, payload and digest are rechecked before forwarding.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
const client = root.station.client;
const Wide = root.Model.Wide;
const Pub = root.Publication;
pub const Scope = struct {
    realm: u64,
    application: u64,
    pid: u64,
    resource: u64,
    namespace: Wide,
    pub fn validate(self: Scope) !void {
        inline for (.{ "realm", "application", "pid", "resource" }) |field| try identity(@field(self, field));
        if (self.namespace.value == 0) return error.InvalidApplicationScope;
    }
};
pub const Prepared = struct { scope: Scope, principal: u64, sequence: Wide, command: root.Request.Command, digest: [32]u8 };
pub const Signed = struct { prepared: Prepared, signature: [64]u8 };
pub const Selection = union(enum) { identity: void, state: struct { operation: Wide = .{}, record: Wide = .{}, input: u64 = 0 } };
pub const PreparedRead = struct { scope: Scope, principal: u64, selection: Selection, digest: [32]u8 };
pub const SignedRead = struct { prepared: PreparedRead, signature: [64]u8 };
pub const Identity = struct { principal: u64, sequence: Wide, permissions: u16, pid: ?u64, policy_revision: Wide };
pub const State = struct {
    revision: Wide,
    configuration: Pub.Configuration,
    policy: ?Pub.Policy,
    head: ?Pub.Head,
    receipt: ?Pub.Receipt,
    upload: ?struct { written: u32, collected: u32, reserved: bool, first_half: bool, state: root.station.Publication.State },
    disposition: ?p.Value,
    receipt_diagnostic: ?p.Diagnostic = null,
};
pub const Observation = union(enum) { identity: Identity, state: State };
fn identity(value: u64) !void {
    if (value == 0 or value > p.max_counter) return error.InvalidApplicationScope;
}
fn request(scope: Scope, principal: u64, sequence: Wide, command: root.Request.Command) !g.Request {
    try scope.validate();
    try identity(principal);
    const result: g.Request = .{ .realm = scope.realm, .principal = principal, .sequence = sequence.value, .command = .{ .send = .{ .pid = scope.pid, .value = try (root.station.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } };
    try g.validate(result);
    return result;
}
pub fn prepare(scope: Scope, principal: u64, sequence: Wide, command: root.Request.Command) !Prepared {
    return .{ .scope = scope, .principal = principal, .sequence = sequence, .command = command, .digest = try g.digest(try request(scope, principal, sequence, command)) };
}
/// Freeze the entire signed object until an authoritative receipt/rejection.
/// Preparing a new sequence cannot resolve an uncertain earlier submission.
pub fn envelope(scope: Scope, signed: Signed) !g.SignedRequest {
    if (!std.meta.eql(scope, signed.prepared.scope)) return error.ApplicationScopeChanged;
    const prepared = signed.prepared;
    const value = try request(scope, prepared.principal, prepared.sequence, prepared.command);
    if (!std.mem.eql(u8, &prepared.digest, &try g.digest(value))) return error.ApplicationDigestMismatch;
    return .{ .request = value, .signature = signed.signature };
}
pub fn submit(wire: *client.Client, scope: Scope, signed: Signed) !client.Receipt {
    return wire.submit(try envelope(scope, signed));
}
fn keys(scope: Scope, principal: u64, selected: @FieldType(Selection, "state")) ![g.page_size]?p.Value {
    if (selected.input > p.max_counter or (selected.record.value != 0 and selected.operation.value == 0)) return error.InvalidApplicationSelection;
    var result: [g.page_size]?p.Value = @splat(null);
    result[0] = root.Records.key(scope.application, 'c', 0, 0);
    result[1] = root.Records.key(scope.application, 'p', principal, 0);
    result[2] = root.Records.key(scope.application, 'h', 0, 0);
    var used: usize = 3;
    if (selected.operation.value != 0) {
        result[3] = root.Records.key(scope.application, 'o', principal, selected.operation.value);
        result[4] = root.Records.key(scope.application, 'x', principal, selected.operation.value);
        used += 2;
    }
    if (selected.input != 0) {
        result[used] = root.Records.key(scope.application, 'e', principal, selected.input);
        used += 1;
    }
    if (selected.record.value != 0) result[used] = root.station.Publication.key(.application_definition, scope.namespace.value, 'r', selected.record.value, 0);
    return result;
}
fn query(scope: Scope, principal: u64, selection: Selection) !g.Query {
    try scope.validate();
    try identity(principal);
    const value: g.Query = .{ .realm = scope.realm, .principal = principal, .kind = switch (selection) {
        .identity => .identity,
        .state => |selected| .{ .read_entries = .{ .resource = scope.resource, .keys = try keys(scope, principal, selected) } },
    } };
    try g.validateQuery(value);
    return value;
}
pub fn prepareRead(scope: Scope, principal: u64, selection: Selection) !PreparedRead {
    return .{ .scope = scope, .principal = principal, .selection = selection, .digest = try g.queryDigest(try query(scope, principal, selection)) };
}
pub fn queryEnvelope(scope: Scope, signed: SignedRead) !g.SignedQuery {
    if (!std.meta.eql(scope, signed.prepared.scope)) return error.ApplicationScopeChanged;
    const value = try query(scope, signed.prepared.principal, signed.prepared.selection);
    if (!std.mem.eql(u8, &signed.prepared.digest, &try g.queryDigest(value))) return error.ApplicationDigestMismatch;
    return .{ .query = value, .signature = signed.signature };
}
pub fn read(wire: *client.Client, scope: Scope, signed: SignedRead) !Observation {
    const native = try queryEnvelope(scope, signed);
    // The shared client validates response shape/basis; the authority checks the
    // operator's signature and current grants. No host reader identity is substituted.
    const response = try wire.call(g.Response, "/v1/query", native);
    switch (signed.prepared.selection) {
        .identity => {
            const value = response.body.identity;
            return .{ .identity = .{ .principal = value.principal, .sequence = .{ .value = response.principal_sequence }, .permissions = value.permissions, .pid = value.pid, .policy_revision = .{ .value = value.policy_revision } } };
        },
        .state => |selected| {
            const body = response.body.read_entries;
            const batch: client.ResourceReader.Batch = .{ .resource = body.resource, .view = .{ .resource = body.resource.id, .revision = body.resource.revision }, .keys = try keys(scope, signed.prepared.principal, selected), .entries = body.entries };
            const config = try root.Records.decode(Pub.Configuration, 'c', (try batch.read(batch.keys[0].?)) orelse return error.ApplicationNotInitialized);
            if (config.application != scope.application or config.realm != scope.realm or config.namespace.value != scope.namespace.value or body.resource.writer != scope.pid) return error.ApplicationScopeChanged;
            const owner: Pub = .{ .configuration = config };
            const receipt = if (selected.operation.value != 0) try owner.receipt(&batch, signed.prepared.principal, selected.operation) else null;
            var result: State = .{ .revision = .{ .value = body.resource.revision }, .configuration = config, .policy = try owner.policy(&batch, signed.prepared.principal), .head = try owner.head(&batch), .receipt = receipt, .upload = null, .disposition = if (selected.input != 0) try batch.read(root.Records.key(scope.application, 'e', signed.prepared.principal, selected.input)) else null };
            if (selected.record.value != 0 and receipt != null) {
                const operation = receipt.?;
                if (operation.proposal.record.value != selected.record.value) return error.InvalidApplicationSelection;
                if (operation.owns_record) {
                    const descriptor = try root.station.Publication.Descriptor.decode((try batch.read(root.station.Publication.key(.application_definition, scope.namespace.value, 'r', selected.record.value, 0))) orelse return error.MissingPublicationChunk);
                    if (!std.meta.eql(descriptor.spec, operation.proposal.spec)) return error.ApplicationPublicationChanged;
                    result.upload = .{ .written = descriptor.written, .collected = descriptor.collected, .reserved = descriptor.reserved, .first_half = try batch.read(root.Records.key(scope.application, 'x', signed.prepared.principal, selected.operation.value)) != null, .state = descriptor.state };
                }
            }
            if (receipt) |value| result.receipt_diagnostic = try root.PublicationDiagnostic.receipt(scope, value);
            return .{ .state = result };
        },
    }
}
