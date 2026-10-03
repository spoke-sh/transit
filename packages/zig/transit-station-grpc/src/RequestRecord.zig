//! A caller publishes request metadata/batch before sending this finite reference.
//! The reference is a commitment, never a bearer grant or an execution permit.
const std = @import("std");
const rpc = @import("root.zig");
const x = rpc.exchange;
const Pub = x.Publication;
pub const metadata_id: u64 = 1;
pub const batch_id: u64 = 2;
pub const maximum_batch_bytes = rpc.Batch.maximum_bytes;
fn fail(context: ?*?rpc.Service.Rejection, check: x.AdmissionRejection.Check, field: []const u8, expected: x.AdmissionRejection.Scalar, actual: x.AdmissionRejection.Scalar) anyerror {
    if (context) |slot| if (slot.* == null) {
        slot.* = rpc.Service.Rejection.detail(.invalid_request, check, field, expected, actual, error.InvalidGrpcRequestReference);
    };
    return error.InvalidGrpcRequestReference;
}
pub const Reference = struct {
    pub const magic = "GRQ1";
    resource: u64,
    namespace: u64,
    metadata_bytes: u32,
    metadata_digest: [32]u8,
    batch_bytes: u32,
    batch_digest: [32]u8,
    endpoint_revision: u64,
    reconcile_before_ms: u64,
    max_attempts: u32 = 1,
    shape: rpc.Shape,
    descriptor_digest: [32]u8,
    pub fn validate(self: Reference) !void {
        return self.validateDiagnostic(null);
    }
    pub fn validateDiagnostic(self: Reference, context: ?*?rpc.Service.Rejection) !void {
        if (self.resource == 0) return fail(context, .different, "request.resource", .{ .unsigned = 0 }, .{ .unsigned = 0 });
        if (self.resource > x.p.max_counter) return fail(context, .maximum, "request.resource", .{ .unsigned = x.p.max_counter }, .{ .unsigned = self.resource });
        if (self.namespace == 0) return fail(context, .different, "request.namespace", .{ .unsigned = 0 }, .{ .unsigned = 0 });
        if (self.metadata_bytes == 0) return fail(context, .different, "request.metadata.bytes", .{ .unsigned = 0 }, .{ .unsigned = 0 });
        if (self.metadata_bytes > rpc.Request.maximum_bytes) return fail(context, .maximum, "request.metadata.bytes", .{ .unsigned = rpc.Request.maximum_bytes }, .{ .unsigned = self.metadata_bytes });
        if (self.batch_bytes < 8) return fail(context, .policy, "request.batch.bytes", .{ .text = "at least 8 bytes" }, .{ .unsigned = self.batch_bytes });
        if (self.batch_bytes > maximum_batch_bytes) return fail(context, .maximum, "request.batch.bytes", .{ .unsigned = maximum_batch_bytes }, .{ .unsigned = self.batch_bytes });
        inline for (.{ "endpoint_revision", "reconcile_before_ms", "max_attempts" }) |field| if (@field(self, field) == 0) return fail(context, .different, "request." ++ field, .{ .unsigned = 0 }, .{ .unsigned = 0 });
    }
    pub fn encode(self: Reference) !x.p.Value {
        return x.codec.encode(self);
    }
    pub fn decode(value: x.p.Value) !Reference {
        return x.codec.decode(Reference, value);
    }
    pub fn metadataSpec(self: Reference) Pub.Spec {
        return .{ .format = rpc.protocol_format, .length = self.metadata_bytes, .digest = self.metadata_digest };
    }
    pub fn batchSpec(self: Reference) Pub.Spec {
        return .{ .format = rpc.protocol_format, .length = self.batch_bytes, .digest = self.batch_digest };
    }
};
pub const Prepared = struct { reference: Reference, metadata: []const u8, batch: []const u8 };
/// Caller-side upload identity, separate from Publication's generic key space.
pub fn key(namespace: u64) x.p.Value {
    var bytes: [10]u8 = undefined;
    bytes[0..2].* = "\x00G".*;
    std.mem.writeInt(u64, bytes[2..10], namespace, .big);
    return x.p.Value.init(&bytes) catch unreachable;
}
/// Advance at most one durable upload step. False means the caller must schedule
/// another turn with the same owned source bytes. True means both records were
/// published before this turn, so call admission may share this turn safely.
pub fn stage(turn: *x.station.Turn, reference: Reference, metadata: []const u8, batch: []const u8) !bool {
    try reference.validate();
    if (reference.resource != turn.view.resource or metadata.len != reference.metadata_bytes or batch.len != reference.batch_bytes) return error.InvalidGrpcRequestReference;
    return x.station.PublicationUpload.step(turn, .{
        .domain = .application,
        .namespace = reference.namespace,
        .identity_key = key(reference.namespace),
        .identity = try reference.encode(),
        .limits = .{ .record_bytes = maximum_batch_bytes, .staging_bytes = maximum_batch_bytes + rpc.Request.maximum_bytes, .staging_records = 2 },
        .records = &.{
            .{ .id = metadata_id, .bytes = metadata, .spec = reference.metadataSpec() },
            .{ .id = batch_id, .bytes = batch, .spec = reference.batchSpec() },
        },
    }) catch |err| return switch (err) {
        error.InvalidPublicationUpload => error.InvalidGrpcRequestReference,
        error.PublicationUploadIdentityConflict => error.GrpcRequestIdentityConflict,
        error.PublicationUploadNamespaceInUse => error.GrpcNamespaceInUse,
        else => err,
    };
}
/// Caller-owned buffers stay local. Publication owns durable staging and sealing.
pub fn prepare(resource: u64, namespace: u64, request: rpc.Request, messages: []const []const u8, endpoint_revision: u64, deadline: u64, attempts: u32, metadata_buffer: []u8, batch_buffer: []u8) !Prepared {
    const batch = try rpc.Batch.encode(messages, request.shape, .{}, batch_buffer);
    const metadata = try request.provenance(metadata_buffer);
    const meta_spec = try Pub.Digest.of(rpc.protocol_format, metadata);
    const batch_spec = try Pub.Digest.of(rpc.protocol_format, batch);
    const reference: Reference = .{ .resource = resource, .namespace = namespace, .metadata_bytes = meta_spec.length, .metadata_digest = meta_spec.digest, .batch_bytes = batch_spec.length, .batch_digest = batch_spec.digest, .endpoint_revision = endpoint_revision, .reconcile_before_ms = deadline, .max_attempts = attempts, .shape = request.shape, .descriptor_digest = request.descriptor_digest };
    try reference.validate();
    return .{ .reference = reference, .metadata = metadata, .batch = batch };
}
/// Every chunk rechecks current permissions and logical publication availability.
/// Rebind only the identical immutable spec when unrelated resource state grows.
pub fn read(client: *x.Client, reference: Reference, id: u64, buffer: []u8) ![]const u8 {
    try reference.validate();
    const spec = switch (id) {
        metadata_id => reference.metadataSpec(),
        batch_id => reference.batchSpec(),
        else => return error.InvalidGrpcRequestReference,
    };
    if (buffer.len < spec.length) return error.GrpcRequestTooLarge;
    const publication: Pub = .{ .domain = .application, .resource = reference.resource, .namespace = reference.namespace };
    var previous: ?Pub.Cursor = null;
    var count: usize = 0;
    while (true) {
        var source = try client.reader(reference.resource);
        var cursor = try publication.open(&source, id);
        if (!std.meta.eql(cursor.spec, spec)) return error.InvalidGrpcRequestReference;
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
/// Admission reads both records under current grants, then validates the exact
/// reference against content before committing an independently owned intent.
pub fn validateContent(gpa: std.mem.Allocator, reference: Reference, metadata: []const u8, batch: []const u8) !rpc.Request.Owned {
    return validateContentDiagnostic(gpa, reference, metadata, batch, null);
}
pub fn validateContentDiagnostic(gpa: std.mem.Allocator, reference: Reference, metadata: []const u8, batch: []const u8, context: ?*?rpc.Service.Rejection) !rpc.Request.Owned {
    try reference.validateDiagnostic(context);
    if (metadata.len != reference.metadata_bytes) return fail(context, .equal, "request.metadata.bytes", .{ .unsigned = reference.metadata_bytes }, .{ .unsigned = metadata.len });
    const metadata_spec = try Pub.Digest.of(rpc.protocol_format, metadata);
    if (!std.mem.eql(u8, &reference.metadata_digest, &metadata_spec.digest)) return fail(context, .equal, "request.metadata.digest", .{ .digest = reference.metadata_digest }, .{ .digest = metadata_spec.digest });
    if (batch.len != reference.batch_bytes) return fail(context, .equal, "request.batch.bytes", .{ .unsigned = reference.batch_bytes }, .{ .unsigned = batch.len });
    const batch_spec = try Pub.Digest.of(rpc.protocol_format, batch);
    if (!std.mem.eql(u8, &reference.batch_digest, &batch_spec.digest)) return fail(context, .equal, "request.batch.digest", .{ .digest = reference.batch_digest }, .{ .digest = batch_spec.digest });
    var owned = try rpc.Request.parseDiagnostic(gpa, metadata, context);
    errdefer owned.deinit();
    if (owned.request.shape != reference.shape) return fail(context, .equal, "request.shape", .{ .text = @tagName(reference.shape) }, .{ .text = @tagName(owned.request.shape) });
    if (!std.mem.eql(u8, &owned.request.descriptor_digest, &reference.descriptor_digest)) return fail(context, .equal, "request.descriptor_digest", .{ .digest = reference.descriptor_digest }, .{ .digest = owned.request.descriptor_digest });
    _ = try rpc.Batch.decodeDiagnostic(batch, reference.shape, .{}, context);
    return owned;
}
