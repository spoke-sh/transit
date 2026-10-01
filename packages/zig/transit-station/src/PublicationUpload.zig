//! Finite caller publication, independent of any connector or query format.
//! The adapter must bind every record spec and policy field in its frozen marker.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig");
const Publication = @import("Publication.zig");
pub const Record = struct { id: u64, bytes: []const u8, spec: Publication.Spec };
pub const Input = struct {
    domain: Publication.Domain,
    namespace: u64,
    identity_key: p.Value,
    identity: p.Value,
    limits: Publication.Limits,
    records: []const Record,
};
/// Encode the frozen upload identity for comparison with an authorized read of
/// the stored marker. This neither stages records nor grants access to them.
pub fn marker(domain: Publication.Domain, namespace: u64, frozen: p.Value) !p.Value {
    try frozen.validate();
    if (@backingInt(domain) == 0 or namespace == 0 or frozen.len == 0) return error.InvalidPublicationUpload;
    var bytes: [48]u8 = undefined;
    bytes[0..4].* = "SPU1".*;
    std.mem.writeInt(u32, bytes[4..8], @backingInt(domain), .little);
    std.mem.writeInt(u64, bytes[8..16], namespace, .little);
    std.crypto.hash.sha2.Sha256.hash(frozen.slice(), bytes[16..48], .{});
    return p.Value.init(&bytes);
}
/// Stage at most one operation per turn. True means every record was already
/// published before this turn, so admission can share the remaining turn budget.
/// This is not atomic multi-record visibility: the adapter publishes its reference
/// only when true. Private failure restores every mutation in this helper.
pub fn step(turn: *Turn, input: Input) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    try input.limits.validate();
    try input.identity.validate();
    try input.identity_key.validate();
    if (@backingInt(input.domain) == 0 or input.namespace == 0 or input.records.len == 0 or input.records.len > 2 or input.identity_key.len == 0 or input.identity.len == 0) return error.InvalidPublicationUpload;
    var total: u64 = 0;
    for (input.records, 0..) |record, index| {
        try record.spec.validate();
        if (record.id == 0 or record.bytes.len > input.limits.record_bytes or !std.meta.eql(try Publication.Digest.of(record.spec.format, record.bytes), record.spec)) return error.InvalidPublicationUpload;
        for (input.records[0..index]) |prior| if (prior.id == record.id) return error.InvalidPublicationUpload;
        total += record.bytes.len;
    }
    if (total > input.limits.staging_bytes or input.records.len > input.limits.staging_records) return error.InvalidPublicationUpload;
    const publication: Publication = .{ .resource = turn.view.resource, .domain = input.domain, .namespace = input.namespace };
    const frozen = try marker(input.domain, input.namespace, input.identity);
    if (try turn.read(input.identity_key)) |previous| {
        if (!previous.eql(frozen)) return error.PublicationUploadIdentityConflict;
    } else {
        if (try turn.read(Publication.key(input.domain, input.namespace, 'b', 0, 0)) != null) return error.PublicationUploadNamespaceInUse;
        _ = try Publication.create(turn, input.domain, input.namespace, input.limits);
        try turn.write(input.identity_key, frozen);
        return false;
    }
    for (input.records) |record| {
        const descriptor = publication.inspect(turn, record.id) catch |err| switch (err) {
            error.PublicationNotFound => {
                _ = try publication.begin(turn, record.id, record.spec);
                return false;
            },
            else => return err,
        };
        if (!std.meta.eql(descriptor.spec, record.spec)) return error.PublicationUploadIdentityConflict;
        switch (descriptor.state) {
            .published => continue,
            .retired, .abandoned => return error.PublicationNotPublished,
            .staging => if (descriptor.written < record.spec.chunks()) {
                const index = descriptor.written;
                _ = try publication.append(turn, record.id, index, record.bytes[@as(usize, index) * Publication.chunk_bytes ..][0..try record.spec.size(index)]);
            } else {
                _ = try publication.publish(turn, record.id);
            },
        }
        return false;
    }
    return true;
}
