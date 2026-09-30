//! Signed application-owned Table mutations. Preparation never submits; callers
//! preserve the exact Prepared value until its native receipt is reconciled.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const r = q.TableMutationRecords;
const a = q.TableMutationAdmission;
const Request = q.TableMutationRequest;
const Ref = s.PublicationReference;
const Self = @This();
wire: *q.wire.Client,
connection: Connection,
key: p.Ed25519.KeyPair,
batch_support: bool = false,

pub const Connection = struct {
    realm: u64,
    principal: u64,
    writer: u64,
    resource: u64,
    table: u32,
    pub fn validate(self: Connection) !void {
        inline for (.{ "realm", "principal", "writer", "resource" }) |field| {
            const id = @field(self, field);
            if (id == 0 or id > p.max_counter) return error.InvalidMutationConnection;
        }
        if (self.table == 0) return error.InvalidMutationConnection;
    }
};
pub const Description = struct {
    table: s.Table,
    policy: r.Policy,
    resource_revision: u64,
    active: ?u64,
};
pub const Prepared = struct {
    version: u8,
    definition: g.Definition,
    connection: Connection,
    signed: g.SignedRequest,
    pub const max_saved_bytes = 8192;
    pub fn save(self: Prepared, allocator: std.mem.Allocator) ![]u8 {
        _ = try checkedReference(self);
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
    /// Owns all fields after return. Required definition and canonical equality
    /// reject old/defaulted envelopes before any native query or submission.
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Prepared {
        if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidMutationPrepared;
        const parsed = std.json.parseFromSlice(Prepared, allocator, bytes, .{}) catch |err| return if (err == error.OutOfMemory) err else error.InvalidMutationPrepared;
        defer parsed.deinit();
        _ = try checkedReference(parsed.value);
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidMutationPrepared;
        return parsed.value;
    }
};
/// Processed means this admitted input is behind the current mailbox head. Only
/// a terminal Status describes whether rows were applied, rejected or cancelled.
pub const Observation = enum { pending, processed };

fn reference(command: r.Command) Ref {
    return switch (command) {
        .begin => |value| value.reference,
        .part => |value| value.reference,
        .seal, .apply, .cancel => |value| value,
    };
}
fn checkedReference(prepared: Prepared) !Ref {
    if (prepared.version != 1) return error.InvalidMutationPrepared;
    try prepared.connection.validate();
    const request = prepared.signed.request;
    try g.validate(request);
    if (request.command != .send) return error.InvalidMutationPrepared;
    const frame = try s.Frame.decode(request.command.send.value);
    if (frame.kind != .cast) return error.InvalidMutationPrepared;
    const command = try r.Command.decode(&frame.payload);
    const ref = reference(command);
    const target = prepared.connection;
    if (request.realm != target.realm or request.principal != target.principal or request.command.send.pid != target.writer or ref.resource != target.resource) return error.MutationIdentityConflict;
    if (command == .begin and command.begin.table != target.table) return error.MutationIdentityConflict;
    return ref;
}
pub fn resources(self: *Self) q.wire.ResourceReader {
    return .{ .wire = self.wire, .realm = self.connection.realm, .principal = self.connection.principal, .key = self.key };
}
fn batch(self: *Self, keys: []const p.Value) !q.wire.ResourceReader.Batch {
    try self.connection.validate();
    if (!self.batch_support) {
        _ = try self.resources().batches();
        self.batch_support = true;
    }
    // Cache only feature support; credentials and target scope always come from
    // this call's connection, never a previous metadata acquisition.
    const result = try (q.wire.ResourceReader.Batches{ .client = self.resources() }).read(self.connection.resource, null, keys);
    if (result.resource.writer != self.connection.writer or result.resource.phase != .active) return error.MutationWriterUnavailable;
    return result;
}
fn grant(self: *Self, source: *const q.wire.ResourceReader.Batch) !Description {
    const table = try s.Table.open(source, self.connection.table);
    const policy = (try a.policy(source, self.connection.principal, self.connection.table)) orelse return error.MutationDenied;
    if (policy.permissions == 0) return error.MutationDenied;
    if (!std.mem.eql(u8, &policy.declaration, &try r.declaration(table))) return error.MutationSourceChanged;
    return .{ .table = table, .policy = policy, .resource_revision = source.view.revision, .active = try a.active(source) };
}
/// One current authorized metadata batch. It is not a retained view, permission
/// cache, admitted statement or evidence that a supplied host exposes writes.
pub fn describe(self: *Self) !Description {
    const current = try self.batch(&.{ s.Table.descriptorKey(self.connection.table), r.key('p', self.connection.principal, self.connection.table), r.key('a', 0, 0) });
    return self.grant(&current);
}
pub fn compileSql(self: *Self, name: q.fuze.model.Name, text: []const u8) !Request {
    const description = try self.describe();
    const request = try Request.fromSql(self.connection.realm, self.connection.writer, description.table, name, text);
    if (!description.policy.permits(request.plan.operation)) return error.MutationDenied;
    return request;
}
fn checkReference(self: *Self, ref: Ref) !void {
    try self.connection.validate();
    try Request.checkReference(ref);
    if (ref.resource != self.connection.resource) return error.MutationIdentityConflict;
}
fn statusFrom(self: *Self, source: *const q.wire.ResourceReader.Batch, ref: Ref) !?r.Status {
    const current = (try a.status(source, ref.namespace)) orelse return null;
    if (current.principal != self.connection.principal) return error.MutationPrincipalMismatch;
    if (current.table != self.connection.table or !std.meta.eql(current.reference, ref)) return error.MutationIdentityConflict;
    return current;
}
/// Status lookup requires the original full reference; a namespace alone cannot
/// select new work. Native current read rights apply even to terminal outcomes.
pub fn status(self: *Self, ref: Ref) !?r.Status {
    try self.checkReference(ref);
    const current = try self.batch(&.{r.key('u', ref.namespace, 0)});
    return self.statusFrom(&current, ref);
}
fn available(self: *Self, active: ?u64, namespace: u64) !void {
    const previous = active orelse return;
    if (previous == namespace) return;
    const source = try self.batch(&.{r.key('u', previous, 0)});
    const current = (try a.status(&source, previous)) orelse return error.InvalidMutationRecord;
    if (!current.terminal()) return error.MutationBusy;
}
fn sign(self: *Self, command: r.Command) !Prepared {
    const payload = try command.encode();
    const sequence = (try self.resources().query(.capabilities)).principal_sequence;
    return .{ .version = 1, .definition = g.current_definition, .connection = self.connection, .signed = try g.sign(.{ .realm = self.connection.realm, .principal = self.connection.principal, .sequence = try std.math.add(u64, sequence, 1), .command = .{ .send = .{ .pid = self.connection.writer, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key) };
}
/// Prepares one signed cast without submitting it. Concurrent handles sharing a
/// principal can race for the native sequence; that conflict never permits
/// silently re-signing an uncertain operation.
pub fn prepare(self: *Self, command: r.Command) !Prepared {
    _ = try command.encode();
    try self.checkReference(reference(command));
    if (command == .begin) {
        const current = try self.describe();
        if (command.begin.table != self.connection.table) return error.MutationIdentityConflict;
        if (current.policy.revision != command.begin.policy_revision) return error.StaleMutationPolicy;
        try self.available(current.active, command.begin.reference.namespace);
        if (try self.status(command.begin.reference)) |existing| {
            if (existing.policy_revision != command.begin.policy_revision) return error.MutationIdentityConflict;
        }
    } else _ = (try self.status(reference(command))) orelse return error.MutationNotFound;
    // Apply/cancel remain preparable after policy revocation so the owner can
    // record denial or cancellation. Preparation does not promise acceptance.
    return self.sign(command);
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    if (!std.meta.eql(self.connection, prepared.connection)) return error.MutationIdentityConflict;
    const ref = try checkedReference(prepared);
    try self.checkReference(ref);
    const request = prepared.signed.request;
    if (request.realm != self.connection.realm or request.principal != self.connection.principal or request.command.send.pid != self.connection.writer) return error.MutationIdentityConflict;
    const frame = try s.Frame.decode(request.command.send.value);
    const command = try r.Command.decode(&frame.payload);
    if (command == .begin and command.begin.table != self.connection.table) return error.MutationIdentityConflict;
    try p.Ed25519.Signature.fromBytes(prepared.signed.signature).verify(&try g.digest(request), self.key.public_key);
}
/// Performs no metadata lookup, new signing or automatic retry. Keep this exact
/// Prepared value on transport uncertainty; the native authority rechecks grants.
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    return self.wire.submit(prepared.signed);
}
/// Supply the receipt position returned for this exact prepared send. This does
/// not fabricate a mutation result from a native send acknowledgement.
pub fn observe(self: *Self, prepared: Prepared, input: u64) !Observation {
    try self.validate(prepared);
    if (input == 0 or input > p.max_counter) return error.InvalidMutationPrepared;
    const response = try self.resources().query(.{ .process = self.connection.writer });
    if (input > response.position) return error.InvalidMutationPrepared;
    const state = response.body.process;
    if (state.process.lifecycle != .running or state.process.failure != null) return error.MutationWriterUnavailable;
    if (state.input) |head| {
        if (head.position == input) {
            if (head.origin != .external or head.origin.external.principal != self.connection.principal or !head.value.eql(prepared.signed.request.command.send.value)) return error.MutationIdentityConflict;
        }
        if (head.position <= input) return .pending;
    }
    return .processed;
}
/// A supplied writer records rejected inputs independently of terminal request
/// status. Check this after processed observation before advancing an upload.
pub fn rejection(self: *Self, prepared: Prepared, input: u64) !?q.TableMutationWriter.Rejection {
    try self.validate(prepared);
    if (input == 0 or input > p.max_counter) return error.InvalidMutationPrepared;
    const current = try self.batch(&.{r.key('e', input, 0)});
    const value = (try current.read(r.key('e', input, 0))) orelse return null;
    const result = try q.TableMutationWriter.Disposition.decode(value);
    if (result.input != input or result.principal != self.connection.principal or !std.mem.eql(u8, &result.payload, &try q.TableMutationWriter.Disposition.fingerprint(prepared.signed.request.command.send.value))) return error.MutationIdentityConflict;
    return result.reason;
}
/// Select one successor only after reconciling the preceding Prepared receipt
/// and observing its input processed. Canonical request/reference identity stays
/// fixed throughout upload, seal and apply; this is never an uncertain-send retry.
pub fn prepareNext(self: *Self, namespace: u64, request: Request) !?Prepared {
    try request.validate();
    if (request.realm != self.connection.realm or request.writer != self.connection.writer or request.resource != self.connection.resource or request.table != self.connection.table) return error.MutationIdentityConflict;
    const ref = try request.reference(namespace);
    const current = try self.batch(&.{ r.key('u', namespace, 0), s.Publication.key(.table_mutation, namespace, 'r', ref.record, 0), r.key('h', namespace, 0), s.Table.descriptorKey(self.connection.table), r.key('p', self.connection.principal, self.connection.table), r.key('a', 0, 0) });
    const stored = (try self.statusFrom(&current, ref)) orelse {
        const description = try self.grant(&current);
        if (!std.meta.eql(description.table.schema, request.plan.schema)) return error.MutationSourceChanged;
        if (!description.policy.permits(request.plan.operation)) return error.MutationDenied;
        try self.available(description.active, namespace);
        return try self.sign(.{ .begin = .{ .reference = ref, .table = request.table, .policy_revision = description.policy.revision } });
    };
    if (stored.terminal()) return null;
    if (try a.active(&current) != namespace) return error.MutationNotActive;
    if (stored.phase == .sealed) return try self.sign(.{ .apply = ref });
    const description = try self.grant(&current);
    if (description.policy.revision != stored.policy_revision) return error.StaleMutationPolicy;
    if (!std.meta.eql(description.table.schema, request.plan.schema) or !std.mem.eql(u8, &description.policy.declaration, &stored.declaration)) return error.MutationSourceChanged;
    const descriptor = try ref.publication().inspect(&current, ref.record);
    if (descriptor.state != .staging or !std.meta.eql(descriptor.spec, ref.spec)) return error.InvalidMutationRecord;
    if (descriptor.written == ref.spec.chunks()) return try self.sign(.{ .seal = ref });
    var buffer: [Request.max_bytes]u8 = undefined;
    const bytes = try request.encode(&buffer);
    const chunk = bytes[descriptor.written * s.Publication.chunk_bytes ..][0..try ref.spec.size(descriptor.written)];
    const first = try current.read(r.key('h', namespace, 0));
    if (first) |half| {
        if (chunk.len <= r.part_bytes or half.len != r.part_bytes or !std.mem.eql(u8, half.slice(), chunk[0..r.part_bytes])) return error.MutationIdentityConflict;
    }
    const offset: usize = if (first != null) r.part_bytes else 0;
    return try self.sign(.{ .part = .{ .reference = ref, .ordinal = descriptor.written, .second = first != null, .bytes = chunk[offset..@min(offset + r.part_bytes, chunk.len)] } });
}
