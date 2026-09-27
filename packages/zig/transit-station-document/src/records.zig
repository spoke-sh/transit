//! Compact private resource records; even a maximum index root fits one KV value.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;
const Index = station.ImmutableIndex;
const Pub = station.Publication;
const Document = @import("Document.zig");
const c = @import("codec.zig");
pub fn writeSpec(w: *c.Writer, spec: Pub.Spec) !void {
    try spec.validate();
    try w.int(u32, spec.format);
    try w.int(u32, spec.length);
    try w.write(&spec.digest);
}
pub fn readSpec(r: *c.Reader) !Pub.Spec {
    return .{ .format = try r.int(u32), .length = try r.int(u32), .digest = (try r.read(32))[0..32].* };
}
fn writeDocument(w: *c.Writer, doc: Document) !void {
    try doc.validate();
    try w.int(u64, doc.document);
    try w.int(u64, doc.epoch);
    try w.int(u32, doc.type_revision);
    try w.int(u64, doc.revision);
    try w.int(u8, @intFromBool(doc.index.root != null));
    if (doc.index.root) |root| {
        try w.int(u64, root.id);
        try writeSpec(w, root.spec);
        try w.int(u8, root.level);
        try w.string(root.minimum.slice());
        try w.int(u64, root.entries);
    }
}
fn readDocument(r: *c.Reader) !Document {
    var doc: Document = .{ .document = try r.int(u64), .epoch = try r.int(u64), .type_revision = try r.int(u32), .revision = try r.int(u64) };
    switch (try r.int(u8)) {
        0 => {},
        1 => doc.index.root = .{ .id = try r.int(u64), .spec = try readSpec(r), .level = try r.int(u8), .minimum = try Index.Key.init(try r.string()), .entries = try r.int(u64) },
        else => return error.InvalidDocumentEncoding,
    }
    try doc.validate();
    return doc;
}
pub const Snapshot = struct { state: Document, request: u64 = 0 };
pub fn snapshot(doc: Document) !p.Value {
    return snapshotChange(doc, 0);
}
pub fn snapshotChange(doc: Document, request: u64) !p.Value {
    var bytes: [256]u8 = undefined;
    var w: c.Writer = .{ .bytes = &bytes };
    try w.write("SDS2");
    try writeDocument(&w, doc);
    try w.int(u64, request);
    return p.Value.init(bytes[0..w.offset]);
}
pub fn snapshotRecord(value: p.Value) !Snapshot {
    try value.validate();
    var r: c.Reader = .{ .bytes = value.slice() };
    const magic = try r.read(4);
    const legacy = std.mem.eql(u8, magic, "SDS1");
    if (!legacy and !std.mem.eql(u8, magic, "SDS2")) return error.InvalidDocumentEncoding;
    const out: Snapshot = .{ .state = try readDocument(&r), .request = if (legacy) 0 else try r.int(u64) };
    try r.finish();
    return out;
}
pub fn openSnapshot(value: p.Value) !Document {
    return (try snapshotRecord(value)).state;
}
pub const Head = struct {
    state: Document,
    next_record: u64 = 1,
    active_job: u64 = 0,
    floor: u64 = 0,
    merge_window: u64 = 0,
    retired: bool = false,
    pub fn encode(self: Head) !p.Value {
        if (self.next_record == 0 or self.floor > self.state.revision) return error.InvalidDocumentState;
        var bytes: [256]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDH1");
        try writeDocument(&w, self.state);
        try w.int(u64, self.next_record);
        try w.int(u64, self.active_job);
        try w.int(u64, self.floor);
        try w.int(u64, self.merge_window);
        try w.int(u8, @intFromBool(self.retired));
        return p.Value.init(bytes[0..w.offset]);
    }
    pub fn decode(value: p.Value) !Head {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDH1")) return error.InvalidDocumentEncoding;
        const out: Head = .{ .state = try readDocument(&r), .next_record = try r.int(u64), .active_job = try r.int(u64), .floor = try r.int(u64), .merge_window = try r.int(u64), .retired = switch (try r.int(u8)) {
            0 => false,
            1 => true,
            else => return error.InvalidDocumentEncoding,
        } };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
pub const Job = struct {
    id: u64,
    phase: enum(u8) { preparing = 1, building = 2, accepted = 3, rejected = 4 },
    request: u64,
    spec: Pub.Spec,
    base_revision: u64,
    first_node: u64,
    end_node: u64,
    used_end: u64 = 0,
    accepted_revision: u64 = 0,
    cleanup: u64 = 0,
    pub fn encode(self: Job) !p.Value {
        if (self.id == 0 or self.request == 0 or self.request == std.math.maxInt(u64) or self.first_node != self.request + 1 or self.end_node <= self.first_node or self.spec.format != 0x53444301 or self.spec.length > 4096) return error.InvalidDocumentJob;
        if (self.used_end != 0 and (self.used_end < self.first_node or self.used_end > self.end_node)) return error.InvalidDocumentJob;
        if (self.phase == .accepted and self.accepted_revision == 0) return error.InvalidDocumentJob;
        if (self.cleanup != 0 and (self.cleanup < self.request or self.cleanup > self.end_node)) return error.InvalidDocumentJob;
        var bytes: [256]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDJ1");
        try w.int(u64, self.id);
        try w.int(u8, @backingInt(self.phase));
        try w.int(u64, self.request);
        try writeSpec(&w, self.spec);
        try w.int(u64, self.base_revision);
        try w.int(u64, self.first_node);
        try w.int(u64, self.end_node);
        try w.int(u64, self.used_end);
        try w.int(u64, self.accepted_revision);
        try w.int(u64, self.cleanup);
        return p.Value.init(bytes[0..w.offset]);
    }
    pub fn decode(value: p.Value) !Job {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDJ1")) return error.InvalidDocumentEncoding;
        const out: Job = .{ .id = try r.int(u64), .phase = std.enums.fromInt(@FieldType(Job, "phase"), try r.int(u8)) orelse return error.InvalidDocumentJob, .request = try r.int(u64), .spec = try readSpec(&r), .base_revision = try r.int(u64), .first_node = try r.int(u64), .end_node = try r.int(u64), .used_end = try r.int(u64), .accepted_revision = try r.int(u64), .cleanup = try r.int(u64) };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
test "maximum root head fits unchanged kernel value and rejects malformed framing" {
    const t = std.testing;
    const head: Head = .{ .state = .{ .document = 1, .index = .{ .root = .{ .id = 1, .spec = .{ .format = Index.format, .length = 4096, .digest = @splat(1) }, .level = 31, .minimum = try Index.Key.init(&@as([128]u8, @splat(255))), .entries = std.math.maxInt(u64) } } } };
    const encoded = try head.encode();
    try t.expectEqual(@as(u16, 252), encoded.len);
    try t.expectEqualDeep(head, try Head.decode(encoded));
    for (0..encoded.len) |i| if (Head.decode(try p.Value.init(encoded.slice()[0..i]))) |_| return error.TruncatedHeadAccepted else |_| {};
}
