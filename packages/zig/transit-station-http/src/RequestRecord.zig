//! A caller publishes request metadata/body before sending this finite reference.
//! The reference is a commitment, never a bearer grant or an execution permit.
const std = @import("std");
const http = @import("root.zig");
const x = http.exchange;
const Pub = x.Publication;
pub const metadata_id: u64 = 1;
pub const body_id: u64 = 2;
pub const maximum_body_bytes = 65536;
pub const Reference = struct {
    pub const magic = "HTQ1";
    resource: u64,
    namespace: u64,
    metadata_bytes: u32,
    metadata_digest: [32]u8,
    body_bytes: u32,
    body_digest: [32]u8,
    endpoint_revision: u64,
    reconcile_before_ms: u64,
    max_attempts: u32 = 1,
    pub fn validate(self: Reference) !void {
        if (self.resource == 0 or self.resource > x.p.max_counter or self.namespace == 0 or self.metadata_bytes == 0 or self.metadata_bytes > http.Request.maximum_head_bytes or self.body_bytes > maximum_body_bytes or self.endpoint_revision == 0 or self.reconcile_before_ms == 0 or self.max_attempts == 0) return error.InvalidHttpRequestReference;
    }
    pub fn encode(self: Reference) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Reference {
        return x.codec.decode(Reference, value);
    }
    pub fn metadataSpec(self: Reference) Pub.Spec {
        return .{ .format = http.protocol_format, .length = self.metadata_bytes, .digest = self.metadata_digest };
    }
    pub fn bodySpec(self: Reference) Pub.Spec {
        return .{ .format = http.protocol_format, .length = self.body_bytes, .digest = self.body_digest };
    }
};
pub const Prepared = struct { reference: Reference, metadata: []const u8 };
/// Caller-side upload identity, separate from Publication's generic key space.
pub fn key(namespace: u64) x.p.Value {
    var bytes: [10]u8 = undefined;
    bytes[0..2].* = "\x00H".*;
    std.mem.writeInt(u64, bytes[2..10], namespace, .big);
    return x.p.Value.init(&bytes) catch unreachable;
}
/// Advance at most one durable upload step. False means the caller must schedule
/// another turn with the same owned source bytes. True means both records were
/// published before this turn, so call admission may share this turn safely.
pub fn stage(turn: *x.station.GrowingTurn, reference: Reference, metadata: []const u8, body: []const u8) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    try reference.validate();
    if (reference.resource != turn.view.resource or metadata.len != reference.metadata_bytes or body.len != reference.body_bytes) return error.InvalidHttpRequestReference;
    if (!std.meta.eql(try Pub.Digest.of(http.protocol_format, metadata), reference.metadataSpec()) or !std.meta.eql(try Pub.Digest.of(http.protocol_format, body), reference.bodySpec())) return error.InvalidHttpRequestReference;
    const frozen = try reference.encode();
    const publication: Pub = .{ .resource = reference.resource, .namespace = reference.namespace };
    if (try turn.read(key(reference.namespace))) |previous| {
        if (!previous.eql(frozen)) return error.HttpRequestIdentityConflict;
    } else {
        if (try turn.read(Pub.key(reference.namespace, 'b', 0, 0)) != null) return error.HttpNamespaceInUse;
        _ = try Pub.create(turn, reference.namespace, .{ .record_bytes = maximum_body_bytes, .staging_bytes = maximum_body_bytes + http.Request.maximum_head_bytes, .staging_records = 2 });
        try turn.write(key(reference.namespace), frozen);
        return false;
    }
    const Record = struct { id: u64, bytes: []const u8, spec: Pub.Spec };
    for ([_]Record{ .{ .id = metadata_id, .bytes = metadata, .spec = reference.metadataSpec() }, .{ .id = body_id, .bytes = body, .spec = reference.bodySpec() } }) |record| {
        const descriptor = publication.inspect(turn, record.id) catch |err| switch (err) {
            error.PublicationNotFound => {
                _ = try publication.begin(turn, record.id, record.spec);
                return false;
            },
            else => return err,
        };
        if (!std.meta.eql(descriptor.spec, record.spec)) return error.HttpRequestIdentityConflict;
        switch (descriptor.state) {
            .published => continue,
            .retired, .abandoned => return error.PublicationNotPublished,
            .staging => if (descriptor.written < record.spec.chunks()) {
                const index = descriptor.written;
                _ = try publication.append(turn, record.id, index, record.bytes[@as(usize, index) * Pub.chunk_bytes ..][0..try record.spec.size(index)]);
            } else {
                _ = try publication.publish(turn, record.id);
            },
        }
        return false;
    }
    return true;
}
/// Caller-owned buffers stay local. Publication owns durable staging and sealing.
pub fn prepare(resource: u64, namespace: u64, request: http.Request, body: []const u8, endpoint_revision: u64, deadline: u64, attempts: u32, metadata_buffer: []u8) !Prepared {
    if (body.len > maximum_body_bytes or request.body_bytes != body.len or metadata_buffer.len > http.Request.maximum_head_bytes) return error.InvalidHttpBodyLength;
    var head: [http.Request.maximum_head_bytes]u8 = undefined;
    _ = try request.render("scope.invalid", 443, &head, null, false);
    var writer: std.Io.Writer = .fixed(metadata_buffer);
    try request.provenance(&writer);
    const metadata = writer.buffered();
    const meta_spec = try Pub.Digest.of(http.protocol_format, metadata);
    const body_spec = try Pub.Digest.of(http.protocol_format, body);
    const reference: Reference = .{ .resource = resource, .namespace = namespace, .metadata_bytes = meta_spec.length, .metadata_digest = meta_spec.digest, .body_bytes = body_spec.length, .body_digest = body_spec.digest, .endpoint_revision = endpoint_revision, .reconcile_before_ms = deadline, .max_attempts = attempts };
    try reference.validate();
    return .{ .reference = reference, .metadata = metadata };
}
/// Every chunk rechecks current permissions and logical publication availability.
/// Rebind only the identical immutable spec when unrelated resource state grows.
pub fn read(client: *x.Client, reference: Reference, id: u64, buffer: []u8) ![]const u8 {
    try reference.validate();
    const spec = switch (id) {
        metadata_id => reference.metadataSpec(),
        body_id => reference.bodySpec(),
        else => return error.InvalidHttpRequestReference,
    };
    if (buffer.len < spec.length) return error.HttpRequestTooLarge;
    const publication: Pub = .{ .resource = reference.resource, .namespace = reference.namespace };
    var previous: ?Pub.Cursor = null;
    var count: usize = 0;
    while (true) {
        var source = try client.reader(reference.resource);
        var cursor = try publication.open(&source, id);
        if (!std.meta.eql(cursor.spec, spec)) return error.InvalidHttpRequestReference;
        if (previous) |old| {
            cursor.index = old.index;
            cursor.chain = old.chain;
        }
        const part = try publication.read(&source, cursor);
        @memcpy(buffer[count..][0..part.bytes.len], part.bytes.slice());
        count += part.bytes.len;
        previous = part.next;
        if (previous == null) return buffer[0..count];
    }
}
