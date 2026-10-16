//! Canonical finite request bytes; borrowed plan/source arrays die with their
//! input and bounded arena. Publication is immutable transport, not admission.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const t = f.Types;
const logical = f.LogicalQuery;
const codec = f.LogicalPlanCodec;
const Self = @This();
pub const header_bytes = 65;
pub const max_bytes = header_bytes + q.QueryAuthorization.encoded_bytes + q.SourceDefinition.max_bytes + codec.max_bytes;
pub const format: u32 = 0x31425155; // UQB1
source: q.SourceDefinition,
plan: logical.Plan,
limits: Limits,
/// Null is an unsigned description. Table execution requires a bound proof.
authorization: ?q.QueryAuthorization = null,
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
    const plan = try f.TableSelect.planDiagnostic(allocator, text, name, schema, try source.fingerprint(), diagnostic);
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
    if (self.source.source != .table and self.authorization != null) return error.UnsupportedQueryAuthorization;
    if (self.authorization) |value| try value.validate();
    try self.limits.validate();
    var fields: [q.SourceDefinition.max_columns]t.Field = undefined;
    const schema = try self.source.schema(&fields);
    try self.plan.validate();
    if (!try self.plan.schema.eql(schema) or !std.mem.eql(u8, &self.plan.source_basis, &try self.source.fingerprint())) return error.SourceChanged;
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
    const source = try q.SourceDefinition.decode(allocator, try reader.take(source_length));
    var fields: [q.SourceDefinition.max_columns]t.Field = undefined;
    const result: Self = .{
        .limits = limits,
        .authorization = authorization,
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
pub fn authorize(self: Self, client: q.wire.AuthorizationClient, audience: u64, requester: u64, requests: u64) !Self {
    if (self.authorization != null) return error.QueryAlreadyAuthorized;
    var bytes: [max_bytes]u8 = undefined;
    var result = self;
    result.authorization = try q.QueryAuthorization.prepare(client, audience, requester, requests, try self.unsigned(&bytes));
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
