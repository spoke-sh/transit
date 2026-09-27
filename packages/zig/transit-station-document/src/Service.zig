//! Recoverable Document publication jobs in one resource. Callers commit private
//! decisions and add framework routing; no local field owns durable progress.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;
const Turn = station.GrowingTurn;
const Pub = station.Publication;
const Index = station.ImmutableIndex;
const Document = @import("Document.zig");
const m = @import("Model.zig");
const codec = @import("codec.zig");
pub const records = @import("records.zig");
pub const Head = records.Head;
pub const Job = records.Job;
const Self = @This();
resource: u64,
document: u64,
pub const change_format = 0x53444301;
pub fn publication(self: Self) Pub {
    return .{ .resource = self.resource, .namespace = self.document };
}
pub fn key(self: Self, tag: u8, id: u64) p.Value {
    var bytes: [19]u8 = undefined;
    bytes[0..2].* = "\x00D".*;
    std.mem.writeInt(u64, bytes[2..10], self.document, .big);
    bytes[10] = tag;
    std.mem.writeInt(u64, bytes[11..19], id, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn check(self: Self, source: anytype) !void {
    if (self.document == 0 or self.resource == 0 or self.resource != source.view.resource) return error.InvalidDocumentIdentity;
}
pub fn head(self: Self, source: anytype) !Head {
    try self.check(source);
    const out = try Head.decode((try source.read(self.key('h', 0))) orelse return error.DocumentNotFound);
    if (out.state.document != self.document) return error.InvalidDocumentState;
    return out;
}
fn live(self: Self, source: anytype) !Head {
    const out = try self.head(source);
    if (out.retired) return error.DocumentRetired;
    return out;
}
pub fn job(self: Self, source: anytype, id: u64) !Job {
    try self.check(source);
    const out = try Job.decode((try source.read(self.key('j', id))) orelse return error.DocumentJobNotFound);
    if (out.id != id) return error.InvalidDocumentJob;
    return out;
}
/// Creation fixes explicit publication quotas and unlimited retention by default.
pub fn create(self: Self, turn: *Turn, type_revision: u32, limits: Pub.Limits) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.check(turn);
    if (type_revision == 0 or limits.record_bytes < Index.node_bytes) return error.InvalidDocumentLimits;
    if (try turn.read(self.key('h', 0))) |value| {
        const existing = try Head.decode(value);
        if (existing.retired) return error.DocumentRetired;
        if (existing.state.type_revision != type_revision) return error.DocumentIdentityMismatch;
        _ = try Pub.create(turn, self.document, limits);
        return;
    }
    if (self.publication().budget(turn)) |_| return error.DocumentNamespaceOccupied else |err| {
        if (err != error.PublicationNamespaceNotFound) return err;
    }
    const out: Head = .{ .state = .{ .document = self.document, .type_revision = type_revision } };
    _ = try Pub.create(turn, self.document, limits);
    try turn.write(self.key('h', 0), try out.encode());
    try turn.write(self.key('v', 0), try records.snapshot(out.state));
}
/// Freeze one active job and permanently reserve its request/node interval. This
/// admits staging work, not the change. Consumers may bind reply identity using
/// the remaining two mutations in this same turn.
pub fn prepare(self: Self, turn: *Turn, id: u64, change: m.Change, node_limit: u32) !Job {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try self.live(turn);
    if (id == 0 or node_limit == 0) return error.InvalidDocumentJob;
    var bytes: [m.max_change_bytes]u8 = undefined;
    const spec = try Pub.Digest.of(change_format, try codec.encode(change, &bytes));
    if (try turn.read(self.key('j', id))) |value| {
        const existing = try Job.decode(value);
        if (!std.meta.eql(existing.spec, spec) or existing.id != id) return error.DocumentIdentityConflict;
        return existing;
    }
    if (change.document != h.state.document or change.type_revision != h.state.type_revision) return error.DocumentIdentityMismatch;
    if (change.epoch != h.state.epoch) return error.DocumentResyncRequired;
    if (h.active_job != 0) return error.DocumentBusy;
    if (try turn.read(self.key('c', id)) != null) return error.DocumentIdentityConflict;
    const first = std.math.add(u64, h.next_record, 1) catch return error.DocumentRecordCapacity;
    const end = std.math.add(u64, first, node_limit) catch return error.DocumentRecordCapacity;
    const out: Job = .{ .id = id, .phase = .preparing, .request = h.next_record, .spec = spec, .base_revision = h.state.revision, .first_node = first, .end_node = end };
    h.next_record = end;
    h.active_job = id;
    try turn.write(self.key('j', id), try out.encode());
    try turn.write(self.key('h', 0), try h.encode());
    return out;
}
/// Idempotently upload the frozen request. The owner must retain its source or
/// recover these same bytes; a replacement cannot invent another request.
pub fn upload(self: Self, turn: *Turn, id: u64, change: m.Change) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const h = try self.live(turn);
    var j = try self.job(turn, id);
    var bytes: [m.max_change_bytes]u8 = undefined;
    const encoded = try codec.encode(change, &bytes);
    if (!std.meta.eql(try Pub.Digest.of(change_format, encoded), j.spec)) return error.DocumentIdentityConflict;
    if (j.phase == .accepted) return true;
    if (j.phase == .rejected) return error.DocumentJobClosed;
    if (h.active_job != id or h.state.revision != j.base_revision) return error.InvalidDocumentJob;
    const pubn = self.publication();
    const descriptor = pubn.inspect(turn, j.request) catch |err| switch (err) {
        error.PublicationNotFound => {
            _ = try pubn.begin(turn, j.request, j.spec);
            return false;
        },
        else => return err,
    };
    if (!std.meta.eql(descriptor.spec, j.spec)) return error.DocumentIdentityConflict;
    switch (descriptor.state) {
        .staging => {
            if (descriptor.written < j.spec.chunks()) {
                const offset = @as(usize, descriptor.written) * Pub.chunk_bytes;
                _ = try pubn.append(turn, j.request, descriptor.written, encoded[offset..][0..try j.spec.size(descriptor.written)]);
            } else _ = try pubn.publish(turn, j.request);
            return false;
        },
        .published => {
            if (j.phase == .preparing) {
                j.phase = .building;
                try turn.write(self.key('j', id), try j.encode());
            }
            return true;
        },
        else => return error.DocumentJobClosed,
    }
}
fn readChange(self: Self, source: anytype, request: u64, spec: Pub.Spec) !m.Change {
    var cursor = try self.publication().open(source, request);
    if (!std.meta.eql(cursor.spec, spec)) return error.InvalidDocumentJob;
    var bytes: [m.max_change_bytes]u8 = undefined;
    var used: usize = 0;
    while (true) {
        const part = try self.publication().read(source, cursor);
        if (part.bytes.len > bytes.len - used) return error.InvalidDocumentJob;
        @memcpy(bytes[used..][0..part.bytes.len], part.bytes.slice());
        used += part.bytes.len;
        cursor = part.next orelse break;
    }
    return codec.decode(bytes[0..used]);
}
pub const Advance = union(enum) { progress, accepted: u64, duplicate: u64 };
/// At most one Publication step, or a final three-mutation acceptance. Add the
/// success output in this same final private turn; commit uncertainty is owned
/// by Station. Failed proposals restore their mutations and never accept a root.
pub fn advance(self: Self, turn: *Turn, id: u64) !Advance {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try self.live(turn);
    var j = try self.job(turn, id);
    if (j.phase == .accepted) return .{ .duplicate = j.accepted_revision };
    if (j.phase != .building) return error.DocumentJobNotReady;
    if (h.active_job != id or h.state.revision != j.base_revision) return error.InvalidDocumentJob;
    const change = try self.readChange(turn, j.request, j.spec);
    var staging: Index.Staging = .{ .turn = turn, .publication = self.publication(), .next_id = j.first_node, .end_id = j.end_node };
    const candidate = h.state.apply(&staging, change) catch |err| {
        if (err == error.IndexStaging) return .progress;
        return err;
    };
    h.state = candidate.state;
    h.active_job = 0;
    j.phase = .accepted;
    j.accepted_revision = candidate.accepted_revision;
    j.used_end = staging.next_id;
    try turn.write(self.key('h', 0), try h.encode());
    if (!candidate.duplicate) try turn.write(self.key('v', h.state.revision), try records.snapshotChange(h.state, j.request));
    try turn.write(self.key('j', id), try j.encode());
    return if (candidate.duplicate) .{ .duplicate = j.accepted_revision } else .{ .accepted = j.accepted_revision };
}
/// Explicitly reject an unfinished candidate; its permanent interval remains
/// closed and separately reclaimable. Accepted work cannot be rejected here.
pub fn reject(self: Self, turn: *Turn, id: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try self.head(turn);
    var j = try self.job(turn, id);
    if (j.phase == .rejected) return;
    if (j.phase == .accepted) return error.DocumentAlreadyAccepted;
    if (h.active_job != id) return error.InvalidDocumentJob;
    h.active_job = 0;
    j.phase = .rejected;
    j.cleanup = j.request;
    try turn.write(self.key('h', 0), try h.encode());
    try turn.write(self.key('j', id), try j.encode());
}
/// Every page reopens a retained Document revision under a fresh current source.
/// A revision is a reference, not a grant; retirement and policy floors are live.
pub fn open(self: Self, source: anytype, revision: u64) !Document {
    comptime requireCurrent(@TypeOf(source));
    const h = try self.live(source);
    if (revision < h.floor) return error.DocumentHistoryGap;
    if (revision > h.state.revision) return error.DocumentRevisionNotAccepted;
    const doc = try records.openSnapshot((try source.read(self.key('v', revision))) orelse return error.DocumentHistoryGap);
    if (doc.document != self.document or doc.revision != revision or doc.type_revision != h.state.type_revision) return error.InvalidDocumentState;
    return doc;
}
/// An explicit finite revision window affects only later checkpoint decisions;
/// zero restores unlimited future retention without recreating any removed history.
pub fn configureMergeWindow(self: Self, turn: *Turn, revisions: u64) !void {
    var h = try self.live(turn);
    if (h.active_job != 0) return error.DocumentBusy;
    if (h.merge_window == revisions) return;
    h.merge_window = revisions;
    try turn.write(self.key('h', 0), try h.encode());
}
pub fn acceptedChange(self: Self, turn: anytype, revision: u64) !m.Change {
    _ = try self.open(turn, revision);
    const snap = try records.snapshotRecord((try turn.read(self.key('v', revision))).?);
    if (snap.request == 0) return error.DocumentCheckpointBoundary;
    const descriptor = try self.publication().inspect(turn, snap.request);
    if (descriptor.spec.format != change_format or descriptor.spec.length > m.max_change_bytes) return error.InvalidDocumentState;
    return self.readChange(turn, snap.request, descriptor.spec);
}
fn requireCurrent(comptime T: type) void {
    if (T != *Turn and T != *station.client.ResourceReader.Reader) @compileError("Document lifecycle reads require a current turn or public ResourceReader, never a retained source");
}
pub const Resynchronization = struct {
    document: u64,
    epoch: u64,
    type_revision: u32,
    revision: u64,
    floor: u64,
    replica: u64,
    previous_counter: u64,
    clock: u64,
};
/// Supplies a fresh accepted basis. Tentative old edits remain unaccepted; the
/// caller chooses new edits/identities after reconciling with this revision.
pub fn resynchronize(self: Self, turn: anytype, replica: u64) !Resynchronization {
    comptime requireCurrent(@TypeOf(turn));
    const h = try self.live(turn);
    var reader: Index.Reader(@TypeOf(turn)) = .{ .publication = self.publication(), .source = turn };
    return .{ .document = self.document, .epoch = h.state.epoch, .type_revision = h.state.type_revision, .revision = h.state.revision, .floor = h.floor, .replica = replica, .previous_counter = try h.state.replicaCounter(&reader, replica), .clock = try h.state.clock(&reader) };
}
pub fn readPath(self: Self, turn: anytype, revision: u64, names: []const m.Name) !Document.Register {
    const doc = try self.open(turn, revision);
    var reader: Index.Reader(@TypeOf(turn)) = .{ .publication = self.publication(), .source = turn };
    return doc.path(&reader, names);
}
pub const PageCursor = struct { revision: u64, object: m.Dot, traversal: Document.SequenceCursor = .{} };
pub const SequencePage = struct {
    len: u8 = 0,
    items: [8]Document.SequenceItem = undefined,
    next: ?PageCursor = null,
};
/// A page bounds both returned elements and traversal work. Deleted anchors may
/// produce an empty page with a continuation; callers must distinguish it from EOF.
pub fn readSequence(self: Self, turn: anytype, start: PageCursor) !SequencePage {
    const doc = try self.open(turn, start.revision);
    var reader: Index.Reader(@TypeOf(turn)) = .{ .publication = self.publication(), .source = turn };
    var cursor = start;
    var out: SequencePage = .{};
    for (0..32) |_| {
        switch (try doc.sequenceStep(&reader, cursor.object, &cursor.traversal)) {
            .end => return out,
            .more => {},
            .item => |item| {
                out.items[out.len] = item;
                out.len += 1;
                if (out.len == out.items.len) break;
            },
        }
    }
    out.next = cursor;
    return out;
}
/// Permanent logical retirement precedes physical collection. Pending work must
/// be explicitly rejected first; a replica or old snapshot cannot reopen it.
pub fn retire(self: Self, turn: *Turn) !void {
    var h = try self.head(turn);
    if (h.retired) return;
    if (h.active_job != 0) return error.DocumentBusy;
    h.retired = true;
    try turn.write(self.key('h', 0), try h.encode());
}
/// Reclaims only a rejected candidate's exclusive interval. Published old roots
/// and accepted changes are never inferred unreachable. One record step per turn.
pub fn collectRejected(self: Self, turn: *Turn, id: u64) !bool {
    return self.collectClosed(turn, id, false);
}
/// Accepted history may be reclaimed only after permanent logical retirement.
pub fn collectRetired(self: Self, turn: *Turn, id: u64) !bool {
    return self.collectClosed(turn, id, true);
}
fn collectClosed(self: Self, turn: *Turn, id: u64, retired: bool) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const h = try self.head(turn);
    var j = try self.job(turn, id);
    if (retired) {
        if (!h.retired) return error.DocumentStillLive;
        if (j.phase != .accepted and j.phase != .rejected) return error.DocumentJobStillRetained;
        if (j.cleanup == 0) {
            j.cleanup = j.request;
            try turn.write(self.key('j', id), try j.encode());
            return false;
        }
    } else if (j.phase != .rejected) return error.DocumentJobStillRetained;
    if (j.cleanup == j.end_node) return true;
    if (j.cleanup == 0) return error.InvalidDocumentJob;
    const pubn = self.publication();
    const descriptor = pubn.inspect(turn, j.cleanup) catch |err| switch (err) {
        error.PublicationNotFound => {
            // Records are allocated sequentially. The first absent node marks
            // the unused suffix; the reservation is permanent even when absent.
            j.cleanup = j.end_node;
            try turn.write(self.key('j', id), try j.encode());
            return true;
        },
        else => return err,
    };
    switch (descriptor.state) {
        .staging => {
            _ = try pubn.abandon(turn, j.cleanup);
            return false;
        },
        .published => {
            _ = try pubn.retire(turn, j.cleanup);
            return false;
        },
        .abandoned, .retired => {
            if (descriptor.collected < descriptor.written or descriptor.reserved) {
                _ = try pubn.collect(turn, j.cleanup);
                return false;
            }
            j.cleanup += 1;
            try turn.write(self.key('j', id), try j.encode());
            return j.cleanup == j.end_node;
        },
    }
}
