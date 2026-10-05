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
// Only a scheduling position for the last pending input. Never cache progress,
// policy, a terminal result or permission to disclose it.
pending_observation: ?struct { signature: [64]u8, input: u64, position: u64 } = null,
pub const completion_wait_ms: u32 = 50;

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
pub const Outcome = struct {
    disposition: ?q.TableMutationWriter.Disposition,
    status: ?r.Status,
};
pub const Progress = union(enum) { pending, processed: Outcome };
pub const Next = union(enum) { prepared: Prepared, complete: r.Status };

fn reference(command: r.Command) !Ref {
    return switch (command) {
        .execute => |value| try value.request.reference(value.namespace),
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
    const ref = try reference(command);
    const target = prepared.connection;
    if (request.realm != target.realm or request.principal != target.principal or request.command.send.pid != target.writer or ref.resource != target.resource) return error.MutationIdentityConflict;
    if (command == .execute) {
        const value = command.execute.request;
        if (value.realm != target.realm or value.writer != target.writer or value.resource != target.resource or value.table != target.table) return error.MutationIdentityConflict;
    }
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
    return self.compileSqlDiagnostic(name, text, null);
}
pub fn compileSqlDiagnostic(self: *Self, name: q.fuze.model.Name, text: []const u8, binding: ?*q.fuze.Sql.Binding) !Request {
    if (binding) |detail| detail.* = .{};
    const description = try self.describe();
    const request = try Request.fromSqlDiagnostic(self.connection.realm, self.connection.writer, description.table, name, text, binding);
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
    try self.checkReference(try reference(command));
    if (command == .execute) {
        const value = command.execute;
        const next = (try self.prepareNext(value.namespace, value.request)) orelse return error.MutationUploadClosed;
        const frame = try s.Frame.decode(next.signed.request.command.send.value);
        if (!(try command.encode()).eql(frame.payload)) return error.MutationIdentityConflict;
        return next;
    } else if (command == .begin) {
        const current = try self.describe();
        if (command.begin.table != self.connection.table) return error.MutationIdentityConflict;
        if (current.policy.revision != command.begin.policy_revision) return error.StaleMutationPolicy;
        try self.available(current.active, command.begin.reference.namespace);
        if (try self.status(command.begin.reference)) |existing| {
            if (existing.policy_revision != command.begin.policy_revision) return error.MutationIdentityConflict;
        }
    } else _ = (try self.status(try reference(command))) orelse return error.MutationNotFound;
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
    return self.observeBounded(prepared, input, null);
}
/// One fresh observation, optionally waiting after an earlier pending read of
/// this exact input. Every wake/timeout rechecks current authority. Capacity
/// exhaustion falls back to an ordinary read after bounded backoff, so busy
/// wait admission cannot hide a completed input indefinitely.
pub fn waitObserve(self: *Self, prepared: Prepared, input: u64) !Observation {
    return self.observeBounded(prepared, input, completion_wait_ms);
}
fn observeBounded(self: *Self, prepared: Prepared, input: u64, milliseconds: ?u32) !Observation {
    try self.validate(prepared);
    if (input == 0 or input > p.max_counter) return error.InvalidMutationPrepared;
    errdefer self.pending_observation = null;
    const previous = self.pending_observation;
    self.pending_observation = null;
    const query: g.Query = .{ .realm = self.connection.realm, .principal = self.connection.principal, .kind = .{ .process = self.connection.writer } };
    const response = response: {
        if (milliseconds) |duration| if (previous) |cursor| {
            if (cursor.input == input and std.mem.eql(u8, &cursor.signature, &prepared.signed.signature)) {
                break :response self.wire.waitForChange(query, self.key, .{ .after = cursor.position, .milliseconds = duration }) catch |err| {
                    if (!q.wire.Client.unavailable(err) or self.wire.last_rejection != .HttpCapacity) return err;
                    try self.wire.http.io.sleep(.fromMilliseconds(duration), .awake);
                    break :response try self.wire.query(query, self.key);
                };
            }
        };
        break :response try self.wire.query(query, self.key);
    };
    if (input > response.position) return error.InvalidMutationPrepared;
    if (response.body != .process) return error.InvalidAuthorityResponse;
    const state = response.body.process;
    if (state.process.lifecycle != .running or state.process.failure != null) return error.MutationWriterUnavailable;
    if (state.input) |head| {
        if (head.position == input) {
            if (head.origin != .external or head.origin.external.principal != self.connection.principal or !head.value.eql(prepared.signed.request.command.send.value)) return error.MutationIdentityConflict;
        }
        if (head.position <= input) {
            self.pending_observation = .{ .signature = prepared.signed.signature, .input = input, .position = response.position };
            return .pending;
        }
    }
    return .processed;
}
/// A supplied writer records rejected inputs independently of terminal request
/// status. Check this after processed observation before advancing an upload.
pub fn rejection(self: *Self, prepared: Prepared, input: u64) !?q.TableMutationWriter.Rejection {
    return if (try self.inputDisposition(prepared, input)) |value| value.reason else null;
}
/// The complete, currently authorized input evidence; it is separate from a
/// mutation's terminal status and retains its original payload identity.
pub fn inputDisposition(self: *Self, prepared: Prepared, input: u64) !?q.TableMutationWriter.Disposition {
    try self.validate(prepared);
    if (input == 0 or input > p.max_counter) return error.InvalidMutationPrepared;
    const current = try self.batch(&.{r.key('e', input, 0)});
    return self.dispositionFrom(&current, prepared, input);
}
fn dispositionFrom(self: *Self, current: *const q.wire.ResourceReader.Batch, prepared: Prepared, input: u64) !?q.TableMutationWriter.Disposition {
    const value = (try current.read(r.key('e', input, 0))) orelse return null;
    const result = try q.TableMutationWriter.Disposition.decode(value);
    if (result.input != input or result.principal != self.connection.principal or !std.mem.eql(u8, &result.payload, &try q.TableMutationWriter.Disposition.fingerprint(prepared.signed.request.command.send.value))) return error.MutationIdentityConflict;
    return result;
}
/// Retain the mailbox progress check, then acquire both kinds of outcome at one
/// current authorized resource cut. A terminal request alone cannot establish
/// that this particular admitted input was processed.
pub fn progress(self: *Self, prepared: Prepared, input: u64) !Progress {
    if (try self.observe(prepared, input) == .pending) return .pending;
    return self.processed(prepared, input);
}
/// The same result contract as progress, with bounded notification scheduling.
pub fn waitProgress(self: *Self, prepared: Prepared, input: u64) !Progress {
    if (try self.waitObserve(prepared, input) == .pending) return .pending;
    return self.processed(prepared, input);
}
fn processed(self: *Self, prepared: Prepared, input: u64) !Progress {
    const ref = try checkedReference(prepared);
    const current = try self.batch(&.{ r.key('e', input, 0), r.key('u', ref.namespace, 0) });
    return .{ .processed = .{
        .disposition = try self.dispositionFrom(&current, prepared, input),
        .status = try self.statusFrom(&current, ref),
    } };
}
/// A new namespace must be unused, even when an existing request is terminal
/// and happens to have identical bytes. Preparation never adopts other work.
pub fn prepareNew(self: *Self, namespace: u64, request: Request) !Prepared {
    return (try self.selectNext(namespace, request, true)).prepared;
}
/// Select one successor only after reconciling the preceding Prepared receipt
/// and observing its input processed. Canonical request/reference identity stays
/// fixed throughout upload, seal and apply; this is never an uncertain-send retry.
pub fn prepareNext(self: *Self, namespace: u64, request: Request) !?Prepared {
    return switch (try self.prepareNextResult(namespace, request)) {
        .prepared => |value| value,
        .complete => null,
    };
}
/// Returns the terminal evidence already read while selecting a successor.
pub fn prepareNextResult(self: *Self, namespace: u64, request: Request) !Next {
    return self.selectNext(namespace, request, false);
}
fn selectNext(self: *Self, namespace: u64, request: Request, fresh: bool) !Next {
    try request.validate();
    if (request.realm != self.connection.realm or request.writer != self.connection.writer or request.resource != self.connection.resource or request.table != self.connection.table) return error.MutationIdentityConflict;
    const ref = try request.reference(namespace);
    const current = try self.batch(&.{ r.key('u', namespace, 0), s.Publication.key(.table_mutation, namespace, 'r', ref.record, 0), r.key('h', namespace, 0), s.Table.descriptorKey(self.connection.table), r.key('p', self.connection.principal, self.connection.table), r.key('a', 0, 0) });
    const stored = (try self.statusFrom(&current, ref)) orelse {
        const description = try self.grant(&current);
        if (!std.meta.eql(description.table.schema, request.plan.schema)) return error.MutationSourceChanged;
        if (!description.policy.permits(request.plan.operation)) return error.MutationDenied;
        try self.available(description.active, namespace);
        if (ref.spec.length <= r.inline_bytes) return .{ .prepared = try self.sign(.{ .execute = .{ .namespace = namespace, .policy_revision = description.policy.revision, .request = request } }) };
        return .{ .prepared = try self.sign(.{ .begin = .{ .reference = ref, .table = request.table, .policy_revision = description.policy.revision } }) };
    };
    if (fresh) return error.MutationIdentityConflict;
    if (stored.terminal()) return .{ .complete = stored };
    if (try a.active(&current) != namespace) return error.MutationNotActive;
    if (stored.phase == .sealed) return .{ .prepared = try self.sign(.{ .apply = ref }) };
    const description = try self.grant(&current);
    if (description.policy.revision != stored.policy_revision) return error.StaleMutationPolicy;
    if (!std.meta.eql(description.table.schema, request.plan.schema) or !std.mem.eql(u8, &description.policy.declaration, &stored.declaration)) return error.MutationSourceChanged;
    const descriptor = try ref.publication().inspect(&current, ref.record);
    if (descriptor.state != .staging or !std.meta.eql(descriptor.spec, ref.spec)) return error.InvalidMutationRecord;
    if (descriptor.written == ref.spec.chunks()) return .{ .prepared = try self.sign(.{ .seal = ref }) };
    var buffer: [Request.max_bytes]u8 = undefined;
    const bytes = try request.encode(&buffer);
    const chunk = bytes[descriptor.written * s.Publication.chunk_bytes ..][0..try ref.spec.size(descriptor.written)];
    const first = try current.read(r.key('h', namespace, 0));
    if (first) |half| {
        if (chunk.len <= r.part_bytes or half.len != r.part_bytes or !std.mem.eql(u8, half.slice(), chunk[0..r.part_bytes])) return error.MutationIdentityConflict;
    }
    const offset: usize = if (first != null) r.part_bytes else 0;
    return .{ .prepared = try self.sign(.{ .part = .{ .reference = ref, .ordinal = descriptor.written, .second = first != null, .bytes = chunk[offset..@min(offset + r.part_bytes, chunk.len)] } }) };
}
