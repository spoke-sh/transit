//! Public current-policy Document reads, independent of writer ownership.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;
const Service = @import("Service.zig");
const Document = @import("Document.zig");
const m = @import("Model.zig");
const c = @import("codec.zig");
const Self = @This();
source: station.client.ResourceReader,
pub const Identity = struct {
    resource: u64,
    document: u64,
    pub fn service(self: Identity) !Service {
        if (self.resource == 0 or self.resource > p.max_counter or self.document == 0) return error.InvalidDocumentIdentity;
        return .{ .resource = self.resource, .document = self.document };
    }
};
pub const Reference = struct {
    resource: u64,
    document: u64,
    epoch: u64,
    type_revision: u32,
    revision: u64,
    pub fn identity(self: Reference) Identity {
        return .{ .resource = self.resource, .document = self.document };
    }
    pub fn encode(self: Reference) !p.Value {
        _ = try self.identity().service();
        if (self.epoch == 0 or self.type_revision == 0) return error.InvalidDocumentIdentity;
        var bytes: [40]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDR1");
        try w.int(u64, self.resource);
        try w.int(u64, self.document);
        try w.int(u64, self.epoch);
        try w.int(u32, self.type_revision);
        try w.int(u64, self.revision);
        return p.Value.init(&bytes);
    }
    pub fn decode(value: p.Value) !Reference {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDR1")) return error.InvalidDocumentEncoding;
        const out: Reference = .{ .resource = try r.int(u64), .document = try r.int(u64), .epoch = try r.int(u64), .type_revision = try r.int(u32), .revision = try r.int(u64) };
        try r.finish();
        _ = try out.encode();
        return out;
    }
    fn check(self: Reference, state: Document) !void {
        _ = try self.encode();
        if (self.document != state.document or self.epoch != state.epoch or self.type_revision != state.type_revision or self.revision != state.revision) return error.DocumentIdentityMismatch;
    }
};
pub const Description = struct { reference: Reference, source_revision: u64, floor: u64, merge_window: u64, retired: bool, active_job: u64, change_format: u32 = m.format };
pub fn describe(self: Self, identity: Identity) !Description {
    const service = try identity.service();
    var source = try self.source.open(identity.resource);
    const head = try service.head(&source);
    return .{ .reference = .{ .resource = identity.resource, .document = identity.document, .epoch = head.state.epoch, .type_revision = head.state.type_revision, .revision = head.state.revision }, .source_revision = source.view.revision, .floor = head.floor, .merge_window = head.merge_window, .retired = head.retired, .active_job = head.active_job };
}
pub const Field = struct { reference: Reference, source_revision: u64, value: Document.Register };
pub fn readPath(self: Self, reference: Reference, names: []const m.Name) !Field {
    const service = try reference.identity().service();
    var source = try self.source.open(reference.resource);
    try reference.check(try service.open(&source, reference.revision));
    return .{ .reference = reference, .source_revision = source.view.revision, .value = try service.readPath(&source, reference.revision, names) };
}
pub const Page = struct { reference: Reference, source_revision: u64, value: Service.SequencePage };
pub const RegisterMetadata = struct { reference: Reference, source_revision: u64, value: Document.RegisterMetadata };
pub fn readRegisterMetadata(self: Self, reference: Reference, after: ?station.ImmutableIndex.Key) !RegisterMetadata {
    const service = try reference.identity().service();
    var source = try self.source.open(reference.resource);
    try reference.check(try service.open(&source, reference.revision));
    return .{ .reference = reference, .source_revision = source.view.revision, .value = try service.readRegisterMetadata(&source, reference.revision, after) };
}
pub fn readSequence(self: Self, reference: Reference, cursor: Service.PageCursor) !Page {
    if (cursor.revision != reference.revision) return error.InvalidDocumentCursor;
    const service = try reference.identity().service();
    var source = try self.source.open(reference.resource);
    try reference.check(try service.open(&source, reference.revision));
    return .{ .reference = reference, .source_revision = source.view.revision, .value = try service.readSequence(&source, cursor) };
}
pub fn resynchronize(self: Self, identity: Identity, replica: u64) !Service.Resynchronization {
    const service = try identity.service();
    var source = try self.source.open(identity.resource);
    return service.resynchronize(&source, replica);
}
pub fn acceptedChange(self: Self, reference: Reference) !m.Change {
    const service = try reference.identity().service();
    var source = try self.source.open(reference.resource);
    try reference.check(try service.open(&source, reference.revision));
    return service.acceptedChange(&source, reference.revision);
}
test "Document references preserve full identities and reject wrong framing" {
    const t = std.testing;
    const reference: Reference = .{ .resource = 8, .document = std.math.maxInt(u64), .epoch = 7, .type_revision = 3, .revision = std.math.maxInt(u64) };
    try t.expectEqualDeep(reference, try Reference.decode(try reference.encode()));
    const bytes = try reference.encode();
    for (0..bytes.len) |i| if (Reference.decode(try p.Value.init(bytes.slice()[0..i]))) |_| return error.TruncatedReferenceAccepted else |_| {};
}
