//! Canonical finite request bytes; borrowed plan/source arrays die with their
//! input and bounded arena. Publication is immutable transport, not admission.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const t = f.Types;
const logical = f.LogicalQuery;
const codec = f.LogicalPlanCodec;
const Self = @This();
pub const header_bytes = 66;
pub const max_bytes = header_bytes + q.QueryAuthorization.encoded_bytes + q.catalog.DirectReadDelegation.encoded_bytes + q.SourceDefinition.max_bytes + codec.max_bytes;
pub const format: u32 = 0x31425155; // UQB1
source: q.SourceDefinition,
plan: logical.Plan,
limits: Limits,
/// Null is an unsigned description. Table execution requires a bound proof.
authorization: ?q.QueryAuthorization = null,
/// Explicit activation freezes one exact Table cut and original pin owner.
/// Descriptions may omit it; executable Table submissions may not.
retention: ?q.catalog.DirectReadDelegation = null,
/// The SQL name is a caller-owned alias for this explicit source definition.
/// Returned plan slices belong to allocator; source slices retain their owner.
pub fn fromSql(allocator: std.mem.Allocator, source: q.SourceDefinition, name: []const u8, text: []const u8, limits: Limits) !Self {
    return fromSqlDiagnostic(allocator, source, name, text, limits, null);
}
pub fn fromSqlDiagnostic(allocator: std.mem.Allocator, source: q.SourceDefinition, name: []const u8, text: []const u8, limits: Limits, diagnostic: ?*q.fuze.Sql.Binding) !Self {
    if (diagnostic) |detail| detail.* = .{};
    return fromSqlInner(allocator, source, name, text, limits, diagnostic) catch |err| {
        if (diagnostic) |detail| if (detail.location) |at| f.Sql.Binding.nameFailure(detail, text, name, err, at);
        return err;
    };
}
fn fromSqlInner(allocator: std.mem.Allocator, source: q.SourceDefinition, name: []const u8, text: []const u8, limits: Limits, diagnostic: ?*q.fuze.Sql.Binding) !Self {
    var fields: [q.SourceDefinition.max_columns]t.Field = undefined;
    const schema = try (try source.schema(&fields)).cloneInto(allocator);
    var plan = try f.TableSelect.planDiagnostic(allocator, text, name, schema, try source.fingerprint(), diagnostic);
    plan.collations = source.collations();
    const result: Self = .{ .source = source, .plan = plan, .limits = limits };
    try result.validate();
    return result;
}
pub const Limits = struct {
    pages: u64,
    segments: u64,
    result_bytes: u64,
    pub fn validate(self: Limits) !void {
        if (self.pages == 0 or self.segments == 0 or self.result_bytes == 0) return error.InvalidQueryBudget;
    }
    pub fn permits(self: Limits, requested: Limits) bool {
        return requested.pages <= self.pages and requested.segments <= self.segments and requested.result_bytes <= self.result_bytes;
    }
};
pub fn validate(self: Self) !void {
    if (self.source.source != .table and (self.authorization != null or self.retention != null)) return error.UnsupportedQueryAuthorization;
    if (self.authorization) |value| try value.validate();
    if (self.retention) |grant| {
        if (grant.binding.retention != .snapshot) return error.InvalidQueryBundle;
        var storage: [4096]u8 = undefined;
        var fixed: std.heap.FixedBufferAllocator = .init(&storage);
        try self.source.source.table.requireGrant(fixed.allocator(), grant);
        if (self.authorization) |value| {
            const execution = value.proof.claim;
            const original = grant.proof.claim;
            if (execution.realm != original.realm or execution.principal != original.principal or execution.role != original.role or execution.credential_epoch != original.credential_epoch) return error.QueryDenied;
        }
    }
    try self.limits.validate();
    var fields: [q.SourceDefinition.max_columns]t.Field = undefined;
    const schema = try self.source.schema(&fields);
    try self.plan.validate();
    if (!std.meta.eql(self.plan.collations, self.source.collations()) or !try self.plan.schema.eql(schema) or !std.mem.eql(u8, &self.plan.source_basis, &try self.source.fingerprint())) return error.SourceChanged;
}
/// The source owner derives this binding from its captured, authorized cut.
/// Rebinding changes execution identity, never the immutable submitted bundle.
pub fn bind(self: Self, captured: [32]u8) !logical.Plan {
    try self.validate();
    var plan = self.plan;
    plan.source_basis = captured;
    return plan;
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var source_bytes: [q.SourceDefinition.max_bytes]u8 = undefined;
    var plan_bytes: [codec.max_bytes]u8 = undefined;
    const source = try self.source.encode(&source_bytes);
    const plan = try codec.encode(self.plan, &plan_bytes);
    if (header_bytes + source.len + plan.len > max_bytes) return error.QueryBundleTooLarge;
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("UQB1");
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    try writer.writeInt(u16, @intCast(source.len), .little);
    try writer.writeInt(u16, @intCast(plan.len), .little);
    inline for (.{ "pages", "segments", "result_bytes" }) |name| try writer.writeInt(u64, @field(self.limits, name), .little);
    try q.QueryAuthorization.write(self.authorization, &writer);
    try writer.writeByte(@intFromBool(self.retention != null));
    if (self.retention) |grant| {
        var storage: [4096]u8 = undefined;
        var fixed: std.heap.FixedBufferAllocator = .init(&storage);
        try writer.writeAll(&try grant.encode(fixed.allocator()));
    }
    try writer.writeAll(source);
    try writer.writeAll(plan);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.QueryBundleTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "UQB1")) return error.InvalidQueryBundle;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    const source_length = try reader.takeInt(u16, .little);
    const plan_length = try reader.takeInt(u16, .little);
    const limits: Limits = .{ .pages = try reader.takeInt(u64, .little), .segments = try reader.takeInt(u64, .little), .result_bytes = try reader.takeInt(u64, .little) };
    const authorization = try q.QueryAuthorization.read(&reader);
    const retention: ?q.catalog.DirectReadDelegation = switch (try reader.takeByte()) {
        0 => null,
        1 => try q.catalog.DirectReadDelegation.decode(allocator, try reader.take(q.catalog.DirectReadDelegation.encoded_bytes)),
        else => return error.InvalidQueryBundle,
    };
    const source = try q.SourceDefinition.decode(allocator, try reader.take(source_length));
    var fields: [q.SourceDefinition.max_columns]t.Field = undefined;
    const result: Self = .{
        .limits = limits,
        .authorization = authorization,
        .retention = retention,
        .source = source,
        .plan = try codec.decodeInto(allocator, try source.schema(&fields), try source.fingerprint(), try reader.take(plan_length)),
    };
    if (reader.bufferedLen() != 0) return error.InvalidQueryBundle;
    try result.validate();
    return result;
}
fn unsigned(self: Self, output: []u8) ![]const u8 {
    var description = self;
    description.authorization = null;
    return description.encode(output);
}
/// Bind the direct grant to the unsigned declaration and native execution route.
/// The native execution proof subsequently covers the complete signed grant.
pub fn retentionPurpose(self: Self, worker: u64, resource: u64, requester: u64, requests: u64) ![32]u8 {
    var description = self;
    description.authorization = null;
    description.retention = null;
    var bytes: [max_bytes]u8 = undefined;
    var route: [32]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&route);
    for ([_]u64{ worker, resource, requester, requests }) |id| {
        try q.UnifiedRecords.identity(id);
        try writer.writeInt(u64, id, .little);
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.direct-retention.v1\x00");
    hash.update(&route);
    hash.update(try description.encode(&bytes));
    return hash.finalResult();
}
pub const Capture = struct { executor: u64, operation: u64, expected: q.protocol.DataLifecycle.Position, selection: q.catalog.DirectTableProtocol.CaptureSelection = .exact };
pub fn authorizeCapture(self: Self, client: q.wire.AuthorizationClient, tables: q.catalog.DirectTableClient, worker: u64, resource: u64, requester: u64, requests: u64, capture: Capture) !Self {
    if (self.source.source != .table or self.authorization != null or self.retention != null) return error.QueryAlreadyAuthorized;
    if (client.principal != tables.connection.principal or client.role != tables.connection.role or client.realm != tables.connection.scope.realm) return error.QueryDenied;
    try self.source.source.table.requireConnection(tables);
    var result = self;
    result.retention = try q.catalog.DirectReadDelegation.prepare(tables, .{
        .definition = q.protocol.Growth.current_definition,
        .connection = tables.connection,
        .executor = capture.executor,
        .interpretation = self.source.source.table.interpretation.interpretation,
        .expected = capture.expected,
        .selection = capture.selection,
        .owner = .{ .scope = tables.connection.scope, .principal = tables.connection.principal, .operation = capture.operation },
        .retention = .snapshot,
        .purpose = try self.retentionPurpose(worker, resource, requester, requests),
    });
    return result.authorize(client, worker, requester, requests);
}
pub fn authorize(self: Self, client: q.wire.AuthorizationClient, audience: u64, requester: u64, requests: u64) !Self {
    if (self.authorization != null) return error.QueryAlreadyAuthorized;
    var bytes: [max_bytes]u8 = undefined;
    var result = self;
    result.authorization = try q.QueryAuthorization.prepare(client, audience, requester, requests, try self.unsigned(&bytes));
    try result.validate();
    return result;
}
pub fn subject(self: Self, audience: u64, requester: u64, requests: u64) !?q.protocol.Authorization.Subject {
    const authorization = self.authorization orelse return if (self.source.source == .table) error.QueryDenied else null;
    var bytes: [max_bytes]u8 = undefined;
    return try authorization.subject(audience, requester, requests, try self.unsigned(&bytes));
}
pub fn bindSubject(self: Self, turn: *q.station.Turn, requester: u64, requests: u64, expected: ?u64) !void {
    if (try self.subject(turn.delivery.pid, requester, requests)) |original| {
        if (expected) |who| if (original.principal() != who) return error.QueryDenied;
        if (self.source.source == .table) {
            const grant = self.retention orelse return error.QueryDenied;
            if (grant.binding.executor != turn.delivery.principal or !std.mem.eql(u8, &grant.binding.purpose, &try self.retentionPurpose(turn.delivery.pid, turn.view.resource, requester, requests))) return error.QueryDenied;
        }
        try turn.bindAuthorizationSubject(original);
    } else if (expected != null) return error.QueryDenied;
}
pub fn reference(self: Self, resource: u64, namespace: u64) !q.station.PublicationReference {
    var buffer: [max_bytes]u8 = undefined;
    const result: q.station.PublicationReference = .{ .domain = .query_request, .resource = resource, .namespace = namespace, .record = 1, .spec = try q.station.Publication.Digest.of(format, try self.encode(&buffer)) };
    try checkReference(result);
    return result;
}
pub fn checkReference(ref: q.station.PublicationReference) !void {
    try ref.validate();
    if (ref.domain != .query_request or ref.record != 1 or ref.spec.format != format or ref.spec.length < header_bytes or ref.spec.length > max_bytes) return error.InvalidQueryBundle;
}
/// A policy-bound request resource is still not a substitute for its publisher.
pub fn checkPublisher(ref: q.station.PublicationReference, source: anytype, peer: u64) !void {
    try checkReference(ref);
    var reader = try source.open(ref.resource);
    const descriptor = try ref.publication().inspect(&reader, ref.record);
    if (descriptor.state != .published or !std.meta.eql(descriptor.spec, ref.spec) or descriptor.publisher != peer) return error.UnexpectedQueryPublisher;
}
/// The declaration permits changing only the accepted Document revision. Epoch,
/// type, format, paths and decoders remain fenced by the durable source policy.
pub fn declaration(source: q.SourceDefinition) ![32]u8 {
    var normalized = source;
    if (normalized.source == .document) normalized.source.document.reference.revision = 1;
    return normalized.fingerprint();
}
