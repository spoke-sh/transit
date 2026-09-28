const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const g = p.Growth;
const f = q.fuze;
const m = q.Model;
const r = q.Request;
const Self = @This();
wire: *q.wire.Client,
connection: m.Connection,
key: p.Ed25519.KeyPair,

pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    return self.wire.queryGrowing(.{ .realm = self.connection.realm, .principal = self.connection.principal, .kind = kind }, self.key) catch |err| {
        if (err == error.Rejected and self.wire.last_rejection == .StateResourceExpired) return error.QuerySourceUnavailable;
        return err;
    };
}
/// An exact current resource cut, not an offline cache. Every point read still
/// checks current authority and fails if that resource has changed.
pub const Reader = struct {
    client: *Self,
    resource: g.Resource,
    delivery: struct { pid: u64 },
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        const entries = (try self.client.query(.{ .entries = .{ .resource = self.resource.id, .revision = self.resource.revision, .key = key } })).body.entries.page;
        return if (entries.entries[0]) |entry| entry.value else null;
    }
    pub fn waiting(self: *Reader, correlation: u64) !?s.GrowingTurn.Wait {
        return if (try self.read(s.GrowingTurn.waitKey(correlation))) |value| try s.GrowingTurn.Wait.decode(value) else null;
    }
};
fn reader(self: *Self, resource: u64, pid: u64) !Reader {
    const meta = (try self.query(.{ .resource = resource })).body.resource;
    if (meta.writer != pid or meta.phase != .active) return error.QuerySourceUnavailable;
    return .{ .client = self, .resource = meta, .delivery = .{ .pid = pid } };
}
fn requests(self: *Self) !Reader {
    var view = try self.reader(self.connection.requests, self.connection.requester);
    if (try r.readIdentity((try view.read(r.principalKey())) orelse return error.QueryNotReady) != self.connection.principal or
        try r.readIdentity((try view.read(r.sourceKey())) orelse return error.QueryNotReady) != self.connection.source) return error.QueryAccessDenied;
    return view;
}
fn policy(self: *Self, view: *Reader, revision: ?u64) !s.Query.Policy {
    const grant = (try s.Query.policy(view, self.connection.requester)) orelse return error.QueryAccessDenied;
    if (!grant.allow or grant.table != self.connection.table or (revision != null and revision.? != grant.revision)) return error.QueryAccessDenied;
    return grant;
}
pub fn describe(self: *Self) !m.Source {
    for (0..3) |_| return self.describeOnce() catch |err| {
        if (self.changed(err)) continue;
        return err;
    };
    return error.QueryChanged;
}
fn changed(self: *Self, err: anyerror) bool {
    return (err == error.Rejected or err == error.Conflict) and (self.wire.last_rejection == .StaleStateResource or self.wire.last_rejection == .QueryExpired);
}
fn describeOnce(self: *Self) !m.Source {
    const c = self.connection;
    _ = try f.model.Name.init(c.name);
    var source = try self.reader(c.resource, c.source);
    const policy_value = try self.policy(&source, null);
    const descriptor = (try self.query(.{ .entries = .{ .resource = c.resource, .revision = source.resource.revision, .key = s.Table.descriptorKey(c.table) } })).body.entries.page.entries[0] orelse return error.TableNotFound;
    var request = try self.requests();
    const active = if (try request.read(r.activeKey())) |value| try r.readIdentity(value) else null;
    const seq = (try self.query(.{ .capabilities = {} })).principal_sequence;
    return .{ .connection = c, .resource_revision = source.resource.revision, .descriptor_revision = descriptor.revision, .schema = try s.Table.decodeSchema(descriptor.value), .policy_revision = policy_value.revision, .sequence = seq, .active = active };
}
pub fn prepare(self: *Self, sql: []const u8) !m.Prepared {
    const source = try self.describe();
    if (source.active != null) return error.QueryBusy;
    const plan = f.Sql.plan(sql, .{ .name = try .init(self.connection.name), .schema = source.schema }) catch return error.UnsupportedQuery;
    const start: r.Start = .{ .schema = try source.schema.fingerprint(), .plan = plan };
    return .{ .source = source, .plan = plan, .signed = try self.freeze(source.sequence + 1, try start.encode()) };
}
fn freeze(self: *Self, sequence: u64, payload: p.Value) !g.SignedRequest {
    return g.sign(.{ .realm = self.connection.realm, .principal = self.connection.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.connection.requester, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key);
}
/// Compile against an explicitly published schema using an explicit native
/// sequence. This pure preparation can reconstruct identical bytes after host
/// loss. It neither reserves the sequence nor infers that a prior send failed.
pub fn prepareSequence(self: *Self, sql: []const u8, schema: f.model.Schema, sequence: u64) !g.SignedRequest {
    if (sequence == 0 or sequence > p.max_counter) return error.InvalidQueryIdentity;
    const plan = f.Sql.plan(sql, .{ .name = try .init(self.connection.name), .schema = schema }) catch return error.UnsupportedQuery;
    return self.freeze(sequence, try (r.Start{ .schema = try schema.fingerprint(), .plan = plan }).encode());
}
/// Admission still checks current published source/requester authorization.
/// An exact retry may refer to an already completed query, so an active newer
/// query is not permission to replace or reject the original native identity.
pub fn submitSequence(self: *Self, signed: g.SignedRequest) !p.Receipt {
    const request = signed.request;
    if (request.realm != self.connection.realm or request.principal != self.connection.principal or request.command != .send or request.command.send.pid != self.connection.requester) return error.InvalidQueryRequest;
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.digest(request), self.key.public_key);
    const frame = try s.Frame.decode(request.command.send.value);
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    _ = try r.Start.decode(frame.payload);
    _ = try self.describe();
    return self.wire.submitGrowing(signed);
}

pub const Captured = struct {
    result: s.GrowingQuery.Manifest,
    segment: s.GrowingQuery.Segment,
    /// Borrows the caller's fixed output buffer; never a complete result cache.
    bytes: []const u8,
};
/// A bounded raw IPC segment for protocol adapters. Uses the same durable
/// transfer/manifest checks as page(), validates IPC, and rechecks current
/// source/requester rights after copying. A prefix does not prove full coverage.
pub fn segment(self: *Self, correlation: u64, ordinal: u64, output: []u8, workspace: []u8) !Captured {
    for (0..3) |_| return self.segmentOnce(correlation, ordinal, output, workspace) catch |err| {
        if (self.changed(err)) continue;
        return err;
    };
    return error.QueryChanged;
}
fn segmentOnce(self: *Self, correlation: u64, ordinal: u64, output: []u8, workspace: []u8) !Captured {
    var source = try self.reader(self.connection.resource, self.connection.source);
    var request = try self.requests();
    const manifest = try s.GrowingQuery.completed(&request, correlation);
    try self.checkManifest(&source, manifest);
    const captured = try s.GrowingQuery.completedSegment(&request, correlation, ordinal, output);
    if (!std.mem.eql(u8, &(try f.Inspect.segment(captured.bytes, captured.manifest.rows, workspace)), &manifest.schema)) return error.InvalidResultSchema;
    var current = try self.reader(self.connection.resource, self.connection.source);
    try self.checkManifest(&current, manifest);
    _ = try request.read(r.principalKey());
    return .{ .result = manifest, .segment = captured.manifest, .bytes = captured.bytes };
}
/// A submission receipt identifies the requester input/correlation. It does not
/// mean the behavior admitted the query. On uncertainty retain these exact bytes.
pub fn submit(self: *Self, prepared: m.Prepared) !p.Receipt {
    const request = prepared.signed.request;
    if (prepared.version != 1 or request.realm != self.connection.realm or request.principal != self.connection.principal or request.command != .send or request.command.send.pid != self.connection.requester) return error.InvalidQueryRequest;
    var connection = prepared.source.connection;
    if (!std.mem.eql(u8, connection.name, self.connection.name)) return error.InvalidQueryRequest;
    connection.name = self.connection.name;
    if (!std.meta.eql(connection, self.connection) or prepared.source.version != 1) return error.InvalidQueryRequest;
    const frame = s.Frame.decode(request.command.send.value) catch return error.InvalidQueryRequest;
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    const start = r.Start.decode(frame.payload) catch return error.InvalidQueryRequest;
    const schema = prepared.source.schema.fingerprint() catch return error.InvalidQueryRequest;
    if (!std.meta.eql(start.plan, prepared.plan) or !std.mem.eql(u8, &start.schema, &schema)) return error.InvalidQueryRequest;
    _ = try self.describe(); // Explicit current resource/policy checks; no cached grant.
    return self.wire.submitGrowing(prepared.signed);
}
pub fn prepareCancel(self: *Self, correlation: u64) !g.SignedRequest {
    _ = try self.status(correlation);
    const sequence = (try self.query(.{ .capabilities = {} })).principal_sequence;
    return self.freeze(sequence + 1, try r.cancel(correlation));
}
pub fn submitCancel(self: *Self, signed: g.SignedRequest) !p.Receipt {
    const request = signed.request;
    if (request.realm != self.connection.realm or request.principal != self.connection.principal or request.command != .send or request.command.send.pid != self.connection.requester) return error.InvalidQueryRequest;
    const frame = s.Frame.decode(request.command.send.value) catch return error.InvalidQueryRequest;
    if (frame.kind != .cast) return error.InvalidQueryRequest;
    _ = try self.status(r.cancelled(frame.payload) catch return error.InvalidQueryRequest);
    return self.wire.submitGrowing(signed);
}
pub fn status(self: *Self, correlation: u64) !m.Status {
    for (0..3) |_| return self.statusOnce(correlation) catch |err| {
        if (self.changed(err)) continue;
        return err;
    };
    return error.QueryChanged;
}
fn statusOnce(self: *Self, correlation: u64) !m.Status {
    if (correlation == 0 or correlation > p.max_counter) return error.InvalidQueryIdentity;
    var source = try self.reader(self.connection.resource, self.connection.source);
    _ = try self.policy(&source, null);
    var request = try self.requests();
    // A supplied correlation alone proves neither a submitted input nor admission.
    const value = (try request.read(r.statusKey(correlation))) orelse return .{ .correlation = correlation, .phase = .unobserved };
    const phase = std.meta.stringToEnum(m.Phase, value.slice()) orelse return error.InvalidQueryStatus;
    var result: m.Status = .{ .correlation = correlation, .phase = phase };
    if (phase == .complete) {
        const manifest = try s.GrowingQuery.completed(&request, correlation);
        try self.checkManifest(&source, manifest);
        result.manifest = manifest;
        result.result = manifest.result;
        result.received_segments = manifest.segments;
        result.received_rows = manifest.rows;
    } else if (phase == .admitted) {
        // A requester-scoped caller may read an explicitly associated source
        // resource without being allowed to inspect that foreign process. Keep
        // optional process diagnostics separate from required data authority.
        const caller_identity = (try self.query(.identity)).body.identity;
        if (caller_identity.pid == null or caller_identity.pid == self.connection.source) {
            const process = (try self.query(.{ .process = self.connection.source })).body.process.process;
            if (process.lifecycle != .running) {
                result.phase = .expired;
                return result;
            }
            if (process.failure != null) {
                result.phase = .failed;
                return result;
            }
        }
        if (try source.read(s.GrowingQuery.records.key('i', self.connection.requester, correlation, 0))) |index| {
            const identity = try r.readIdentity(index);
            const job = try s.GrowingQuery.Job.decode((try source.read(s.GrowingQuery.records.key('j', identity, 0, 0))) orelse return error.MissingResult);
            if (job.destination != self.connection.requester or job.correlation != correlation or job.table != self.connection.table) return error.InvalidQueryJob;
            _ = try self.policy(&source, job.policy_revision);
            result.result = identity;
            result.phase = switch (job.phase) {
                .denied => .denied,
                .cancelled => .cancelled,
                else => .capturing,
            };
        }
        if (try request.read(s.GrowingQuery.records.key('r', correlation, 0, 0))) |transfer_value| {
            const transfer = try s.GrowingQuery.records.Transfer.decode(transfer_value);
            if (transfer.source != self.connection.source or result.result != transfer.result) return error.InvalidResultTransfer;
            if (result.phase == .capturing) result.phase = .delivering;
            result.received_segments = transfer.segments;
            result.received_rows = transfer.rows;
        }
    }
    return result;
}
fn checkManifest(self: *Self, source: *Reader, manifest: s.GrowingQuery.Manifest) !void {
    if (manifest.destination != self.connection.requester or manifest.table != self.connection.table or manifest.basis.resource != self.connection.resource) return error.InvalidResultManifest;
    _ = try self.policy(source, manifest.policy_revision);
}
/// The caller supplies a request-scoped allocator. At most 32x2 bounded cells
/// escape, never a complete growing result. Each page rechecks current grants.
pub fn page(self: *Self, correlation: u64, ordinal: u64, allocator: std.mem.Allocator) !m.Page {
    for (0..3) |_| return self.pageOnce(correlation, ordinal, allocator) catch |err| {
        if (self.changed(err)) continue;
        return err;
    };
    return error.QueryChanged;
}
fn pageOnce(self: *Self, correlation: u64, ordinal: u64, allocator: std.mem.Allocator) !m.Page {
    var source = try self.reader(self.connection.resource, self.connection.source);
    var request = try self.requests();
    const manifest = try s.GrowingQuery.completed(&request, correlation);
    try self.checkManifest(&source, manifest);
    var output: [s.GrowingQuery.records.segment_bytes]u8 = undefined;
    const captured = try s.GrowingQuery.completedSegment(&request, correlation, ordinal, &output);
    const workspace = try allocator.alloc(u8, f.execution.working_bytes);
    defer allocator.free(workspace);
    if (!std.mem.eql(u8, &(try f.Inspect.segment(captured.bytes, captured.manifest.rows, workspace)), &manifest.schema)) return error.InvalidResultSchema;
    var arena = std.heap.FixedBufferAllocator.init(workspace);
    var input: std.Io.Reader = .fixed(captured.bytes);
    var ipc = f.arrow.IpcStreamReader(*std.Io.Reader).init(arena.allocator(), &input);
    defer ipc.deinit();
    const schema = try ipc.readSchema();
    var batch = (try ipc.nextRecordBatch()) orelse return error.InvalidArrowResult;
    defer batch.deinit();
    var page_value: m.Page = .{ .manifest = manifest, .ordinal = ordinal, .count = captured.manifest.rows, .next = if (ordinal + 1 < manifest.segments) ordinal + 1 else null };
    for (schema.fields, 0..) |field, column| {
        const kind: f.model.Type = switch (field.data_type.*) {
            .int64 => .int64,
            .bool => .boolean,
            .string => .utf8,
            .binary => .binary,
            else => return error.InvalidArrowResult,
        };
        page_value.columns[column] = .{ .name = try allocator.dupe(u8, field.name), .type = kind, .nullable = field.nullable };
        const data = batch.column(column).data();
        for (0..page_value.count) |row| {
            if (page_value.rows[row] == null) page_value.rows[row] = @splat(null);
            page_value.rows[row].?[column] = if (data.isNull(row)) .null else switch (kind) {
                .int64 => .{ .int64 = try std.fmt.allocPrint(allocator, "{d}", .{try (f.arrow.Int64Array{ .data = data }).value(row)}) },
                .boolean => .{ .boolean = try (f.arrow.BooleanArray{ .data = data }).value(row) },
                .utf8 => .{ .utf8 = try allocator.dupe(u8, try (f.arrow.StringArray{ .data = data }).value(row)) },
                .binary => blk: {
                    const bytes = try (f.arrow.BinaryArray{ .data = data }).value(row);
                    const hex = try allocator.alloc(u8, bytes.len * 2);
                    for (bytes, 0..) |byte, i| {
                        const pair = std.fmt.bytesToHex([_]u8{byte}, .lower);
                        @memcpy(hex[i * 2 ..][0..2], &pair);
                    }
                    break :blk .{ .binary = hex };
                },
            };
        }
    }
    // Authorize once more after fragment/Arrow work. This is an observation cut,
    // not a guarantee about revocations accepted after this request finishes.
    var current = try self.reader(self.connection.resource, self.connection.source);
    try self.checkManifest(&current, manifest);
    _ = try request.read(r.principalKey());
    return page_value;
}

test "explicit query sequence reconstructs exact canonical admission without I/O" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(63));
    var client: Self = .{ .wire = undefined, .key = key, .connection = .{ .realm = 49, .principal = 65536, .source = 3, .resource = 9, .table = 1, .name = "counter", .requester = 7, .requests = 11 } };
    const schema: f.model.Schema = .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 };
    const sql = "SELECT * FROM counter WHERE id >= -9223372036854775808";
    const first = try client.prepareSequence(sql, schema, 9007199254740991);
    const retry = try client.prepareSequence(sql, schema, 9007199254740991);
    try t.expectEqualDeep(first, retry);
    const another = try client.prepareSequence(sql, schema, 2);
    try t.expect(!std.mem.eql(u8, &first.signature, &another.signature));
    const different = try client.prepareSequence("SELECT count(*) FROM counter", schema, 9007199254740991);
    try t.expect(!std.mem.eql(u8, &first.signature, &different.signature));
    try t.expectError(error.InvalidQueryIdentity, client.prepareSequence(sql, schema, 0));
    var foreign = first;
    foreign.request.command.send.pid += 1;
    try t.expectError(error.InvalidQueryRequest, client.submitSequence(foreign));
    var tampered = first;
    tampered.request.sequence = 1;
    try t.expectError(error.SignatureVerificationFailed, client.submitSequence(tampered));
}
