//! Signed v1 caller operations. A Prepared command is frozen across uncertainty;
//! only an observed, committed upload step permits preparing its successor.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const r = q.UnifiedRecords;
const Self = @This();
wire: *q.wire.Client,
connection: Connection,
key: p.Ed25519.KeyPair,
tables: ?q.catalog.DirectTableClient = null,
batch_reads: ?q.wire.ResourceReader.Batches = null,
snapshot_support: ?q.wire.SnapshotReader.Support = null,
pub const Connection = struct { realm: u64, principal: u64, source: u64, resource: u64, requester: u64, requests: u64, role: ?u64 = null };
pub const Capabilities = struct {
    version: u8 = 1,
    source: u8 = 1,
    plan: u8 = 1,
    result: u8 = 1,
    bundle_bytes: u32 = q.Bundle.max_bytes,
    part_bytes: u16 = q.UnifiedRequest.part_bytes,
    segment_bytes: u32 = q.fuze.Unified.Arrow.segment_bytes,
    batch_rows: u8 = q.fuze.Unified.max_rows,
    columns: u8 = q.SourceDefinition.max_columns,
    kv: bool = true,
    table: bool = true,
    document: bool = true,
};
pub const Description = struct {
    capabilities: Capabilities = .{},
    definition: q.SourceDefinition,
    resource_revision: u64,
    policy_revision: u64,
    limits: q.Bundle.Limits,
    active: ?u64,
};
pub const Prepared = struct { version: u8 = 1, signed: g.SignedRequest };
pub const Observation = union(enum) { pending, committed, rejected: p.Value };
/// Only a stale observation may restart at a fresh current cut. This never
/// retries a signed mutation, denial or an unavailable resource.
pub fn readConflict(self: *Self, err: anyerror) bool {
    return err == error.QueryReadConflict or ((err == error.Rejected or err == error.Conflict) and (self.wire.last_rejection == .StaleStateResource or self.wire.last_rejection == .QueryExpired));
}
fn read(self: *Self, comptime operation: anytype, args: anytype) @typeInfo(@TypeOf(operation)).@"fn".return_type.? {
    for (0..3) |_| return @call(.auto, operation, .{self} ++ args) catch |err| {
        if (self.readConflict(err)) continue;
        return err;
    };
    return error.QueryReadConflict;
}
pub fn resources(self: *Self) q.wire.ResourceReader {
    return .{ .wire = self.wire, .realm = self.connection.realm, .principal = self.connection.principal, .key = self.key };
}
pub fn authorizationClient(self: *Self) q.wire.AuthorizationClient {
    return .{ .transport = self.wire, .realm = self.connection.realm, .principal = self.connection.principal, .key = self.key, .role = self.connection.role };
}
/// Pure compilation returns an unsigned description. Table activation must
/// explicitly supply its pin operation, executor and expected Table frontier.
pub fn authorizeBundle(self: *Self, bundle: q.Bundle) !q.Bundle {
    _ = self;
    if (bundle.source.source == .table) return error.QueryCaptureRequired;
    return bundle;
}
pub fn authorizeCapture(self: *Self, bundle: q.Bundle, capture: q.Bundle.Capture) !q.Bundle {
    return bundle.authorizeCapture(self.authorizationClient(), self.tables orelse return error.QuerySourceUnavailable, self.connection.source, self.connection.resource, self.connection.requester, self.connection.requests, capture);
}
/// Explicitly authorize a NEW finite read of a verified completed template.
/// The caller must retain the returned bytes; retrying an accepted upload never
/// calls this operation or substitutes another capture identity.
pub fn authorizeRefresh(self: *Self, allocator: std.mem.Allocator, template: u64, operation: u64) !q.Bundle {
    const status_value = (try self.status(template)) orelse return error.QueryUploadNotFound;
    if (status_value.phase != .complete) return error.IncompleteResult;
    const reference = status_value.manifest.?;
    const expected: q.UnifiedResult.Expected = .{ .resource = self.connection.resource, .source = self.connection.source, .requester = self.connection.requester, .correlation = status_value.correlation, .request = status_value.reference };
    const opened = try q.UnifiedResult.open(reference, try expected.authorize(reference, null, self.authorizationClient()), self.resources(), allocator);
    var description = opened.bundle;
    if (description.source.source != .table) return error.QueryCaptureRequired;
    const original = description.retention orelse return error.QueryCaptureRequired;
    if (operation == 0 or operation == original.binding.owner.operation) return error.QueryUploadIdentityConflict;
    const table = description.source.source.table;
    const direct = self.tables orelse return error.QuerySourceUnavailable;
    try table.requireConnection(direct);
    const current = try direct.call(.{ .observe = .{ .namespace = table.namespace, .interpretation = table.interpretation.interpretation, .rows = null } });
    defer current.deinit();
    description.authorization = null;
    description.retention = null;
    return self.authorizeCapture(description, .{ .executor = original.binding.executor, .operation = operation, .expected = current.value.result.observation.definition.position, .selection = .current });
}
/// Fresh permission closes the exact accepted pin; the original executable
/// bundle and its credential epoch remain unchanged. Save/retry Prepared bytes.
pub fn prepareCleanup(self: *Self, namespace: u64, bundle: q.Bundle) !Prepared {
    try bundle.validate();
    const grant = bundle.retention orelse return error.QueryCaptureRequired;
    const original = bundle.authorization orelse return error.QueryDenied;
    try original.caller(self.connection.principal, self.connection.role);
    _ = try bundle.subject(self.connection.source, self.connection.requester, self.connection.requests);
    if (!std.mem.eql(u8, &grant.binding.purpose, &try bundle.retentionPurpose(self.connection.source, self.connection.resource, self.connection.requester, self.connection.requests))) return error.QueryDenied;
    const permission = try q.catalog.DirectReadDelegation.Closure.prepare(self.tables orelse return error.QuerySourceUnavailable, grant);
    return self.prepare(.{ .retry_cleanup = .{ .namespace = namespace, .authorization = permission } });
}
fn currentSource(self: *Self, data: q.wire.ResourceReader.Batch, definition: q.SourceDefinition, principal: ?u64, check_definition: bool) !void {
    if (definition.source == .table) {
        if (principal != self.connection.principal) return error.QueryDenied;
        const client = self.tables orelse return error.QuerySourceUnavailable;
        if (client.connection.principal != self.connection.principal or client.connection.role != self.connection.role) return error.QueryDenied;
        try definition.source.table.requireConnection(client);
        // Retained uploads validate the original pin grant below. Requiring the
        // live definition here would incorrectly rebind accepted work after ALTER.
        if (check_definition) try definition.source.table.checkDefinition(client);
    } else try q.UnifiedSource.checkCurrent(definition, &data, principal);
}
fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    return self.resources().query(kind);
}
fn checked(self: *Self, resource: u64, pid: u64) !q.wire.ResourceReader.Reader {
    const metadata = (try self.query(.{ .resource = resource })).body.resource;
    if (metadata.id != resource or metadata.writer != pid or metadata.phase != .active) return error.QuerySourceUnavailable;
    return .{ .client = self.resources(), .view = .{ .resource = resource, .revision = metadata.revision } };
}
fn requester(self: *Self) !q.wire.ResourceReader.Reader {
    var reader = try self.checked(self.connection.requests, self.connection.requester);
    try (q.UnifiedBehavior.Requester{ .principal = self.connection.principal, .source = self.connection.source }).check(&reader);
    return reader;
}
pub fn describe(self: *Self, definition: q.SourceDefinition) !Description {
    return self.read(describeOnce, .{ definition, true });
}
/// Current rights for exact upload recovery and retained results. This checks
/// authority without rebinding their immutable schema to the live catalog.
pub fn authorize(self: *Self, definition: q.SourceDefinition) !Description {
    return self.read(describeOnce, .{ definition, false });
}
pub fn inspectSql(self: *Self, allocator: std.mem.Allocator, request: q.SqlInspection.Request) !q.SqlInspection.Result {
    return q.SqlInspection.apply(allocator, self, request);
}
/// The complete current source evidence for both inspection and interactive
/// reads. These are generic keys to the authority, not retained source data.
fn sourceMetadata(self: *Self, definition: q.SourceDefinition, keys: *[3]p.Value) ![]const p.Value {
    if (definition.source != .table and definition.resource != self.connection.resource) return error.QueryIdentityMismatch;
    keys[0] = r.key('p', self.connection.requester, 0);
    switch (definition.source) {
        .kv => return keys[0..1],
        .table => return keys[0..1],
        .document => |document| {
            const service = try document.reference.identity().service();
            keys[1] = service.key('h', 0);
            keys[2] = service.key('v', document.reference.revision);
            return keys[0..3];
        },
    }
}
/// Generic keys only: the native authority never interprets source policy,
/// requester identity, Table descriptors or Document lifecycle records.
pub fn interactiveMetadata(self: *Self, definition: q.SourceDefinition) ![g.SnapshotRead.current_resources]?g.SnapshotRead.Current {
    var source_keys: [3]p.Value = undefined;
    var keys: g.SnapshotRead.Keys = @splat(null);
    for (try self.sourceMetadata(definition, &source_keys), 0..) |key, i| keys[i] = key;
    var requester_keys: g.SnapshotRead.Keys = @splat(null);
    requester_keys[0] = r.key('w', 0, 0);
    return .{ .{ .resource = self.connection.resource, .keys = keys }, .{ .resource = self.connection.requests, .keys = requester_keys } };
}
pub fn interactiveBatch(request: g.SnapshotRead.Current, value: g.SnapshotRead.CurrentResult) q.wire.ResourceReader.Batch {
    return .{ .resource = value.resource, .view = .{ .resource = value.resource.id, .revision = value.resource.revision }, .keys = request.keys, .entries = value.entries };
}
pub fn interactiveDescription(self: *Self, definition: q.SourceDefinition, requests: [g.SnapshotRead.current_resources]?g.SnapshotRead.Current, result: g.SnapshotRead.Result) !Description {
    const source = interactiveBatch(requests[0].?, result.current[0] orelse return error.InvalidResourceRead);
    const requester_source = interactiveBatch(requests[1].?, result.current[1] orelse return error.InvalidResourceRead);
    if (source.resource.writer != self.connection.source or requester_source.resource.writer != self.connection.requester) return error.QuerySourceUnavailable;
    try (q.UnifiedBehavior.Requester{ .principal = self.connection.principal, .source = self.connection.source }).check(&requester_source);
    const grant = (try q.UnifiedCapture.policy(&source, self.connection.requester)) orelse return error.QueryDenied;
    if (!grant.allow or grant.requests != self.connection.requests) return error.QueryDenied;
    try self.currentSource(source, definition, try grant.principal(definition), false);
    return .{ .definition = definition, .resource_revision = source.view.revision, .policy_revision = grant.revision, .limits = grant.limits, .active = null };
}
/// Resolve SQL only against this currently authorized declaration and explicit
/// budgets. This allocates a finite bundle, performs no admission and takes no
/// retained pin; the source captures the committed basis when it admits the call.
pub fn compileSql(self: *Self, allocator: std.mem.Allocator, definition: q.SourceDefinition, name: []const u8, text: []const u8, limits: q.Bundle.Limits) !q.Bundle {
    const current = try self.describe(definition);
    if (!current.limits.permits(limits)) return error.QueryBudgetExceeded;
    return q.Bundle.fromSql(allocator, definition, name, text, limits);
}
/// A template retains exact source identity, not permission or a source pin.
pub fn prepareSql(self: *Self, allocator: std.mem.Allocator, definition: q.SourceDefinition, name: []const u8, text: []const u8) !q.SqlTemplate {
    return q.SqlTemplate.prepareCurrent(allocator, self, definition, name, text);
}
/// A new binding is a new finite query. Retry uncertain uploads using their
/// original saved Bundle/Prepared commands instead of binding again.
pub fn bindSql(self: *Self, allocator: std.mem.Allocator, template: *const q.SqlTemplate, definition: q.SourceDefinition, values: []const q.fuze.Types.Values.Atom, limits: q.Bundle.Limits) !q.SqlTemplate.Bound {
    return template.bindCurrent(allocator, self, definition, values, limits);
}
pub fn batchSupport(self: *Self) !q.wire.ResourceReader.Batches {
    if (self.batch_reads == null) {
        const reader = self.resources();
        const capabilities = (try reader.query(.capabilities)).body.capabilities;
        self.batch_reads = try q.wire.ResourceReader.Batches.init(reader, capabilities);
        // Both owners validate their own required flags from the same checked
        // reply. Cache no grants, source metadata, values or principal sequence.
        self.snapshot_support = q.wire.SnapshotReader.Support.init(reader, capabilities) catch null;
    }
    return self.batch_reads.?;
}
fn describeOnce(self: *Self, definition: q.SourceDefinition, check_definition: bool) !Description {
    var storage: [3]p.Value = undefined;
    const keys = try self.sourceMetadata(definition, &storage);
    const batches = try self.batchSupport();
    const source = try batches.read(self.connection.resource, null, keys);
    const requests = try batches.read(self.connection.requests, null, &.{ r.key('w', 0, 0), r.key('a', 0, 0) });
    if (source.resource.writer != self.connection.source or requests.resource.writer != self.connection.requester) return error.QuerySourceUnavailable;
    try (q.UnifiedBehavior.Requester{ .principal = self.connection.principal, .source = self.connection.source }).check(&requests);
    const grant = (try q.UnifiedCapture.policy(&source, self.connection.requester)) orelse return error.QueryDenied;
    if (!grant.allow or grant.requests != self.connection.requests) return error.QueryDenied;
    try self.currentSource(source, definition, try grant.principal(definition), check_definition);
    return .{ .definition = definition, .resource_revision = source.view.revision, .policy_revision = grant.revision, .limits = grant.limits, .active = try q.UnifiedUpload.active(&requests) };
}
/// Prepare only one command. After any uncertain submit, retain and resubmit
/// this object; do not call prepare/prepareNext to invent another sequence.
pub fn prepare(self: *Self, command: q.UnifiedRequest.Command) !Prepared {
    inline for (.{ "realm", "principal", "source", "resource", "requester", "requests" }) |name| try r.identity(@field(self.connection, name));
    if (command == .initialize) _ = try self.checked(self.connection.requests, self.connection.requester) else _ = try self.requester();
    if (command == .begin and command.begin.resource != self.connection.requests) return error.QueryIdentityMismatch;
    const payload = try command.encode();
    const sequence = (try self.query(.{ .capabilities = {} })).principal_sequence;
    return .{ .signed = try g.sign(.{ .realm = self.connection.realm, .principal = self.connection.principal, .sequence = try std.math.add(u64, sequence, 1), .command = .{ .send = .{ .pid = self.connection.requester, .role = self.connection.role, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key) };
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    const request = prepared.signed.request;
    if (prepared.version != 1 or request.realm != self.connection.realm or request.principal != self.connection.principal or request.command != .send or request.command.send.pid != self.connection.requester or request.command.send.role != self.connection.role) return error.InvalidQueryRequest;
    const frame = s.Frame.decode(request.command.send.value) catch return error.InvalidQueryRequest;
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    const command = q.UnifiedRequest.Command.decode(&frame.payload) catch return error.InvalidQueryRequest;
    if (command == .begin and command.begin.resource != self.connection.requests) return error.QueryIdentityMismatch;
}
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    // No fresh preparation or policy-dependent replacement of an uncertain
    // command. Node grants, requester identity and source policy remain live.
    return self.wire.submit(prepared.signed);
}
/// Receipt position is the requester input, not its ordinal. The public head
/// can prove that input is still pending or that all earlier input has committed.
pub fn observe(self: *Self, input: u64) !Observation {
    return self.read(observeOnce, .{input});
}
fn observeOnce(self: *Self, input: u64) !Observation {
    try r.identity(input);
    const response = try self.query(.{ .process = self.connection.requester });
    if (input > response.position) return error.InvalidQueryIdentity;
    const state = response.body.process;
    if (state.process.lifecycle != .running) return error.QueryRequesterUnavailable;
    if (state.process.failure != null) return error.QueryRequesterFailed;
    if (state.input) |head| if (head.position <= input) return .pending;
    var reader = try self.requester();
    if (try reader.read(r.key('e', input, 0))) |reason| return .{ .rejected = reason };
    return .committed;
}
pub fn status(self: *Self, namespace: u64) !?q.UnifiedRequest.Status {
    return self.read(statusOnce, .{namespace});
}
pub fn draft(self: *Self, generation: ?u64) !?q.Draft.Record {
    return self.read(draftOnce, .{generation});
}
fn draftOnce(self: *Self, generation: ?u64) !?q.Draft.Record {
    var reader = try self.requester();
    const selected = generation orelse try q.Draft.head(&reader);
    return if (selected == 0) null else q.Draft.status(&reader, selected);
}
fn statusOnce(self: *Self, namespace: u64) !?q.UnifiedRequest.Status {
    var reader = try self.requester();
    return q.UnifiedUpload.status(&reader, namespace);
}
/// Canonical finite input must remain owned by the caller while uploading.
/// This selects one bounded next step from committed state. Invoke only after
/// observe confirms the preceding exact signed command has committed.
pub fn prepareNext(self: *Self, namespace: u64, bundle: q.Bundle) !?Prepared {
    return self.prepareNextWithDraft(namespace, bundle, null);
}
pub fn prepareNextWithDraft(self: *Self, namespace: u64, bundle: q.Bundle, generation: ?u64) !?Prepared {
    // Preparation has no mutation side effects. Restart a conflicted current
    // observation before freezing the next command; never replace a dispatched one.
    return self.read(prepareNextOnce, .{ namespace, bundle, generation, false });
}
/// Upload and retain a prepared query without admitting execution. The caller
/// preserves its signed bundle and every uncertain command exactly as usual.
pub fn prepareTemplateNext(self: *Self, namespace: u64, bundle: q.Bundle) !?Prepared {
    return self.read(prepareNextOnce, .{ namespace, bundle, @as(?u64, null), true });
}
fn prepareNextOnce(self: *Self, namespace: u64, bundle: q.Bundle, generation: ?u64, prepare_only: bool) !?Prepared {
    try bundle.validate();
    if (try bundle.subject(self.connection.source, self.connection.requester, self.connection.requests)) |original| {
        try bundle.authorization.?.caller(self.connection.principal, self.connection.role);
        _ = try self.authorizationClient().authenticate(original);
    }
    if (bundle.source.source == .table) {
        const grant = bundle.retention orelse return error.QueryCaptureRequired;
        try bundle.source.source.table.requireGrant(self.wire.http.allocator, grant);
        if (!std.mem.eql(u8, &grant.binding.purpose, &try bundle.retentionPurpose(self.connection.source, self.connection.resource, self.connection.requester, self.connection.requests))) return error.QueryDenied;
        const direct = self.tables orelse return error.QuerySourceUnavailable;
        const checked_pin = try direct.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } });
        defer checked_pin.deinit();
    }
    const description = try self.authorize(bundle.source);
    if (!description.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    const reference = try bundle.reference(self.connection.requests, namespace);
    var reader = try self.requester();
    const existing = try q.UnifiedUpload.status(&reader, namespace);
    if (generation) |selected| {
        const record = (try q.Draft.status(&reader, selected)) orelse return error.QueryDraftNotFound;
        if (!std.mem.eql(u8, &record.open.contract, &try bundle.source.fingerprint())) return error.QueryDraftConflict;
        if (!record.open.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
        if (existing == null or existing.?.correlation == 0) {
            if (try q.Draft.head(&reader) != selected or !record.enabled) return error.QueryDraftClosed;
            if (record.starts == record.open.limit) return error.QueryDraftExhausted;
        } else {
            var found = false;
            for (record.namespaces[0..record.starts]) |id| if (id == namespace) {
                found = true;
            };
            if (!found) return error.QueryDraftConflict;
        }
    }
    const current = existing orelse return try self.prepare(.{ .begin = reference });
    if (!std.meta.eql(current.reference, reference)) return error.QueryUploadIdentityConflict;
    switch (current.phase) {
        .uploading => {
            const descriptor = try reference.publication().inspect(&reader, reference.record);
            if (!std.meta.eql(descriptor.spec, reference.spec) or descriptor.state != .staging) return error.InvalidQueryUpload;
            if (descriptor.written == descriptor.spec.chunks()) return try self.prepare(.{ .seal = namespace });
            var buffer: [q.Bundle.max_bytes]u8 = undefined;
            const bytes = try bundle.encode(&buffer);
            const chunk = bytes[descriptor.written * s.Publication.chunk_bytes ..][0..try descriptor.spec.size(descriptor.written)];
            const first = try reader.read(r.key('h', namespace, 0));
            if (first) |part| {
                if (chunk.len <= q.UnifiedRequest.part_bytes or part.len != q.UnifiedRequest.part_bytes or !std.mem.eql(u8, part.slice(), chunk[0..q.UnifiedRequest.part_bytes])) return error.QueryUploadIdentityConflict;
            }
            const offset: usize = if (first != null) q.UnifiedRequest.part_bytes else 0;
            return try self.prepare(.{ .part = .{ .namespace = namespace, .ordinal = descriptor.written, .second = first != null, .bytes = chunk[offset..@min(offset + q.UnifiedRequest.part_bytes, chunk.len)] } });
        },
        .sealed => return try self.prepare(if (prepare_only) .{ .prepare = namespace } else if (generation) |selected| .{ .draft_submit = .{ .generation = selected, .namespace = namespace } } else .{ .submit = namespace }),
        .prepared => return if (prepare_only) null else try self.prepare(.{ .activate = namespace }),
        else => return null,
    }
}
pub fn page(self: *Self, namespace: u64, cursor: ?q.UnifiedResult.Cursor, allocator: std.mem.Allocator, workspace: []u8, output: []u8, decoded: *q.fuze.LogicalInspect.Batch) !q.UnifiedResult.Page {
    const current = (try self.status(namespace)) orelse return error.QueryUploadNotFound;
    if (current.phase != .complete) return error.IncompleteResult;
    const expected: q.UnifiedResult.Expected = .{ .resource = self.connection.resource, .source = self.connection.source, .requester = self.connection.requester, .correlation = current.correlation, .request = current.reference };
    return q.UnifiedResult.page(current.manifest.?, try expected.authorize(current.manifest.?, cursor, self.authorizationClient()), cursor, self.resources(), allocator, workspace, output, decoded);
}
