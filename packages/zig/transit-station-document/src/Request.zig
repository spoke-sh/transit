//! Immutable caller publication. References commit bytes; current grants still
//! gate every read. No local buffer or publication step accepts a Document edit.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const Pub = s.Publication;
const m = @import("Model.zig");
const c = @import("codec.zig");
const records = @import("records.zig");
const Service = @import("Service.zig");
pub const record: u64 = 1;
pub const Reference = struct {
    resource: u64,
    namespace: u64,
    document: u64,
    epoch: u64,
    type_revision: u32,
    replica: u64,
    policy_revision: u64,
    spec: Pub.Spec,
    pub fn validate(self: Reference) !void {
        if (self.resource == 0 or self.resource > p.max_counter or self.namespace == 0 or self.document == 0 or self.epoch == 0 or self.type_revision == 0 or self.replica == 0 or self.policy_revision == 0 or self.spec.format != Service.change_format or self.spec.length == 0 or self.spec.length > m.max_change_bytes) return error.InvalidDocumentRequest;
        try self.spec.validate();
    }
    pub fn encode(self: Reference) !p.Value {
        try self.validate();
        var bytes: [96]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDQ1");
        try w.int(u64, self.resource);
        try w.int(u64, self.namespace);
        try w.int(u64, self.document);
        try w.int(u64, self.epoch);
        try w.int(u32, self.type_revision);
        try w.int(u64, self.replica);
        try w.int(u64, self.policy_revision);
        try records.writeSpec(&w, self.spec);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Reference {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDQ1")) return error.InvalidDocumentRequest;
        const out: Reference = .{ .resource = try r.int(u64), .namespace = try r.int(u64), .document = try r.int(u64), .epoch = try r.int(u64), .type_revision = try r.int(u32), .replica = try r.int(u64), .policy_revision = try r.int(u64), .spec = try records.readSpec(&r) };
        try r.finish();
        try out.validate();
        return out;
    }
    pub fn publication(self: Reference) Pub {
        return .{ .domain = .application, .resource = self.resource, .namespace = self.namespace };
    }
    fn matches(self: Reference, change: m.Change, bytes: []const u8) !void {
        try self.validate();
        if (self.document != change.document or self.epoch != change.epoch or self.type_revision != change.type_revision or self.replica != change.replica or !std.meta.eql(self.spec, try Pub.Digest.of(Service.change_format, bytes))) return error.InvalidDocumentRequest;
    }
};
pub fn prepare(resource: u64, namespace: u64, policy_revision: u64, change: m.Change) !Reference {
    var bytes: [m.max_change_bytes]u8 = undefined;
    const out: Reference = .{ .resource = resource, .namespace = namespace, .document = change.document, .epoch = change.epoch, .type_revision = change.type_revision, .replica = change.replica, .policy_revision = policy_revision, .spec = try Pub.Digest.of(Service.change_format, try c.encode(change, &bytes)) };
    try out.validate();
    return out;
}
pub fn key(namespace: u64) p.Value {
    var bytes: [10]u8 = undefined;
    bytes[0..2].* = "\x00Q".*;
    std.mem.writeInt(u64, bytes[2..10], namespace, .big);
    return p.Value.init(&bytes) catch unreachable;
}
/// One Publication step; true means the exact request was already published
/// before this turn. The caller may now commit a call and its durable identity.
pub fn stage(turn: *s.Turn, reference: Reference, change: m.Change) !bool {
    var buffer: [m.max_change_bytes]u8 = undefined;
    const bytes = try c.encode(change, &buffer);
    try reference.matches(change, bytes);
    if (reference.resource != turn.view.resource) return error.InvalidDocumentRequest;
    return s.PublicationUpload.step(turn, .{
        .domain = .application,
        .namespace = reference.namespace,
        .identity_key = key(reference.namespace),
        .identity = try reference.encode(),
        .limits = .{ .record_bytes = m.max_change_bytes, .staging_bytes = m.max_change_bytes, .staging_records = 1 },
        .records = &.{.{ .id = record, .bytes = bytes, .spec = reference.spec }},
    });
}
/// Reopen current authority and availability even when request bytes have already
/// been copied to the writer's job. Immutable specs do not extend lifetimes.
pub fn check(source: anytype, reference: Reference) !void {
    try reference.validate();
    var reader = try source.open(reference.resource);
    const cursor = try reference.publication().open(&reader, record);
    if (!std.meta.eql(cursor.spec, reference.spec)) return error.InvalidDocumentRequest;
}
/// Reopen at each bounded chunk. An unrelated resource update may advance the
/// cut; only the identical published spec may continue the verified digest chain.
pub fn read(source: anytype, reference: Reference) !m.Change {
    try reference.validate();
    const publication = reference.publication();
    var previous: ?Pub.Cursor = null;
    var buffer: [m.max_change_bytes]u8 = undefined;
    var used: usize = 0;
    while (true) {
        var reader = try source.open(reference.resource);
        var cursor = try publication.open(&reader, record);
        if (!std.meta.eql(cursor.spec, reference.spec)) return error.InvalidDocumentRequest;
        if (previous) |old| {
            cursor.index = old.index;
            cursor.chain = old.chain;
        }
        const part = try publication.read(&reader, cursor);
        if (part.bytes.len > buffer.len - used) return error.InvalidDocumentRequest;
        @memcpy(buffer[used..][0..part.bytes.len], part.bytes.slice());
        used += part.bytes.len;
        previous = part.next;
        if (previous == null) break;
    }
    const change = try c.decode(buffer[0..used]);
    try reference.matches(change, buffer[0..used]);
    return change;
}
