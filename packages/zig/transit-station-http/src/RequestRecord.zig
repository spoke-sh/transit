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
