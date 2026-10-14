//! Frozen multi-Table request. Explicit catalog metadata and schemas travel with
//! the typed plan; neither source text nor a later live name supplies a binding.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const Pub = q.station.Publication;
const Ref = q.station.PublicationReference;
const Self = @This();
pub const format: u32 = 0x31425152;
pub const max_bytes = 43 + q.QueryAuthorization.encoded_bytes + f.RelationalCodec.max_bytes + r.max_sources * (4 + q.TableSource.max_bytes);
consistency: q.RelationalTables.Consistency = .per_resource_snapshot_vector,
plan: r.Plan,
sources: []const q.TableSource,
authorization: ?q.QueryAuthorization = null,
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    bundle: Self,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn validate(self: Self) !void {
    if (self.authorization) |value| try value.validate();
    try self.plan.validate();
    if (self.consistency != .per_resource_snapshot_vector) return error.UnsupportedRelationalConsistency;
    if (self.plan.lifetime == .interactive or self.sources.len != self.plan.sources.len) return error.InvalidRelationalSources;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    for (self.sources, self.plan.sources) |source, declared| {
        try source.validate();
        if (source.scope.realm != declared.realm or source.scope.resource != declared.resource or source.scope.catalog != declared.catalog or source.owner != declared.owner or source.object != declared.schema.object or !try source.row_type.eql(try declared.schema.rowType(&fields))) return error.RelationalSourceChanged;
    }
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("RQB1");
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    try writer.writeByte(1); // explicit per-resource vector, never atomic
    try writer.writeByte(@intCast(self.sources.len));
    var plan_bytes: [f.RelationalCodec.max_bytes]u8 = undefined;
    const encoded = try f.RelationalCodec.encode(self.plan, &plan_bytes);
    try writer.writeInt(u32, @intCast(encoded.len), .little);
    try writer.writeAll(encoded);
    try q.QueryAuthorization.write(self.authorization, &writer);
    var source_bytes: [q.TableSource.max_bytes]u8 = undefined;
    for (self.sources) |source| {
        const bytes = try source.encode(&source_bytes);
        try writer.writeInt(u32, @intCast(bytes.len), .little);
        try writer.writeAll(bytes);
    }
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    return .{ .bundle = try decodeInto(arena.allocator(), bytes), .arena = arena };
}
/// The supplied arena owns all nested schemas and source descriptors.
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.QueryBundleTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "RQB1")) return error.InvalidQueryBundle;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    if (try reader.takeByte() != 1) return error.UnsupportedRelationalConsistency;
    const count = try reader.takeByte();
    if (count == 0 or count > r.max_sources) return error.InvalidRelationalSources;
    const plan = try f.RelationalCodec.decodeInto(arena, try reader.take(try reader.takeInt(u32, .little)));
    const authorization = try q.QueryAuthorization.read(&reader);
    const sources = try arena.alloc(q.TableSource, count);
    for (sources) |*source| source.* = try q.TableSource.decodeInto(arena, try reader.take(try reader.takeInt(u32, .little)));
    if (reader.bufferedLen() != 0) return error.InvalidQueryBundle;
    const result: Self = .{ .plan = plan, .sources = sources, .authorization = authorization };
    try result.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try result.encode(&canonical))) return error.InvalidQueryBundle;
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
pub fn subject(self: Self, audience: u64, requester: u64, requests: u64) !q.protocol.Authorization.Subject {
    const authorization = self.authorization orelse return error.QueryDenied;
    var bytes: [max_bytes]u8 = undefined;
    return authorization.subject(audience, requester, requests, try self.unsigned(&bytes));
}
pub fn bindSubject(self: Self, turn: *q.station.Turn, requester: u64, requests: u64, expected: u64) !void {
    const original = try self.subject(turn.delivery.pid, requester, requests);
    if (original.principal() != expected) return error.QueryDenied;
    try turn.bindAuthorizationSubject(original);
}
pub fn fingerprint(self: Self) ![32]u8 {
    var bytes: [max_bytes]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.relational.request.v1\x00");
    hash.update(try self.encode(&bytes));
    return hash.finalResult();
}
pub fn reference(self: Self, resource: u64, namespace: u64) !Ref {
    var bytes: [max_bytes]u8 = undefined;
    const result: Ref = .{ .resource = resource, .domain = .query_request, .namespace = namespace, .record = 1, .spec = try Pub.Digest.of(format, try self.encode(&bytes)) };
    try checkReference(result);
    return result;
}
pub fn checkReference(ref: Ref) !void {
    try ref.validate();
    if (ref.domain != .query_request or ref.record != 1 or ref.spec.format != format or ref.spec.length < 43 or ref.spec.length > max_bytes) return error.InvalidQueryBundle;
}
pub fn checkPublisher(ref: Ref, source: anytype, peer: u64) !void {
    try checkReference(ref);
    var reader = try source.open(ref.resource);
    const descriptor = try ref.publication().inspect(&reader, ref.record);
    if (descriptor.state != .published or !std.meta.eql(descriptor.spec, ref.spec) or descriptor.publisher != peer) return error.UnexpectedQueryPublisher;
}
