//! Incremental checkpoint materialization. Durable progress contains one bounded
//! cursor/root, never the whole Document or a list of all nodes.
const std = @import("std");
const station = @import("transit_station");
const p = station.protocol;
const Turn = station.GrowingTurn;
const Index = station.ImmutableIndex;
const Service = @import("Service.zig");
const Document = @import("Document.zig");
const records = @import("records.zig");
const c = @import("codec.zig");
pub const nodes_per_entry: u64 = 2 * (Index.max_level + 1) + 1;
pub const Progress = struct {
    id: u64,
    phase: enum(u8) { building = 1, complete = 2, rejected = 3 },
    base_revision: u64,
    epoch: u64,
    floor: u64,
    allocation_start: u64,
    first_node: u64,
    end_node: u64,
    cleanup: u64 = 0,
    after: ?Index.Key = null,
    pub fn encode(self: Progress) !p.Value {
        if (self.id == 0 or self.epoch == 0 or self.base_revision == std.math.maxInt(u64) or self.floor > self.base_revision + 1 or self.allocation_start == 0 or self.first_node < self.allocation_start or self.end_node <= self.first_node or self.end_node - self.first_node != nodes_per_entry or (self.first_node - self.allocation_start) % nodes_per_entry != 0) return error.InvalidDocumentCheckpoint;
        if (self.cleanup != 0 and (self.cleanup < self.allocation_start or self.cleanup > self.end_node)) return error.InvalidDocumentCheckpoint;
        var bytes: [256]u8 = undefined;
        var w: c.Writer = .{ .bytes = &bytes };
        try w.write("SDP1");
        try w.int(u64, self.id);
        try w.int(u8, @backingInt(self.phase));
        try w.int(u64, self.base_revision);
        try w.int(u64, self.epoch);
        try w.int(u64, self.floor);
        try w.int(u64, self.allocation_start);
        try w.int(u64, self.first_node);
        try w.int(u64, self.end_node);
        try w.int(u64, self.cleanup);
        try w.int(u8, @intFromBool(self.after != null));
        if (self.after) |after| {
            try after.validate(true);
            try w.string(after.slice());
        }
        return p.Value.init(bytes[0..w.offset]);
    }
    pub fn decode(value: p.Value) !Progress {
        try value.validate();
        var r: c.Reader = .{ .bytes = value.slice() };
        if (!std.mem.eql(u8, try r.read(4), "SDP1")) return error.InvalidDocumentCheckpoint;
        var out: Progress = .{ .id = try r.int(u64), .phase = std.enums.fromInt(@FieldType(Progress, "phase"), try r.int(u8)) orelse return error.InvalidDocumentCheckpoint, .base_revision = try r.int(u64), .epoch = try r.int(u64), .floor = try r.int(u64), .allocation_start = try r.int(u64), .first_node = try r.int(u64), .end_node = try r.int(u64), .cleanup = try r.int(u64) };
        out.after = switch (try r.int(u8)) {
            0 => null,
            1 => try Index.Key.init(try r.string()),
            else => return error.InvalidDocumentCheckpoint,
        };
        try r.finish();
        _ = try out.encode();
        return out;
    }
};
pub fn inspect(service: Service, source: anytype, id: u64) !Progress {
    _ = try service.head(source);
    const out = try Progress.decode((try source.read(service.key('c', id))) orelse return error.DocumentCheckpointNotFound);
    if (out.id != id) return error.InvalidDocumentCheckpoint;
    return out;
}
pub fn begin(service: Service, turn: *Turn, id: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try service.head(turn);
    if (h.retired) return error.DocumentRetired;
    if (id == 0) return error.InvalidDocumentCheckpoint;
    if (try turn.read(service.key('c', id))) |value| {
        const existing = try Progress.decode(value);
        if (existing.id != id) return error.InvalidDocumentCheckpoint;
        if (existing.phase == .rejected) return error.DocumentJobClosed;
        return;
    }
    if (h.active_job != 0) return error.DocumentBusy;
    if (try turn.read(service.key('j', id)) != null) return error.DocumentIdentityConflict;
    const revision = std.math.add(u64, h.state.revision, 1) catch return error.DocumentRevisionCapacity;
    const floor = if (h.merge_window == 0 or revision < h.merge_window) h.floor else @max(h.floor, revision - h.merge_window + 1);
    const epoch = if (floor > h.floor) std.math.add(u64, h.state.epoch, 1) catch return error.DocumentRevisionCapacity else h.state.epoch;
    const end = std.math.add(u64, h.next_record, nodes_per_entry) catch return error.DocumentRecordCapacity;
    const progress: Progress = .{ .id = id, .phase = .building, .base_revision = h.state.revision, .epoch = epoch, .floor = floor, .allocation_start = h.next_record, .first_node = h.next_record, .end_node = end };
    const candidate: Document = .{ .document = h.state.document, .epoch = epoch, .type_revision = h.state.type_revision, .revision = revision };
    h.active_job = id;
    h.next_record = end;
    try turn.write(service.key('c', id), try progress.encode());
    try turn.write(service.key('t', id), try records.snapshot(candidate));
    try turn.write(service.key('h', 0), try h.encode());
}
pub const Step = union(enum) { progress, complete: u64 };
pub fn step(service: Service, turn: *Turn, id: u64) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try service.head(turn);
    if (h.retired) return error.DocumentRetired;
    var progress = try inspect(service, turn, id);
    if (progress.phase == .complete) return .{ .complete = progress.base_revision + 1 };
    if (progress.phase != .building or h.active_job != id or h.state.revision != progress.base_revision or h.next_record != progress.end_node) return error.InvalidDocumentCheckpoint;
    var candidate = try records.openSnapshot((try turn.read(service.key('t', id))) orelse return error.InvalidDocumentCheckpoint);
    if (candidate.revision != h.state.revision + 1 or candidate.epoch != progress.epoch or candidate.document != service.document or candidate.type_revision != h.state.type_revision) return error.InvalidDocumentCheckpoint;
    var reader: Index.Reader(*Turn) = .{ .publication = service.publication(), .source = turn };
    const entry = try h.state.index.next(&reader, progress.after) orelse {
        h.state = candidate;
        h.floor = progress.floor;
        h.active_job = 0;
        progress.phase = .complete;
        try turn.write(service.key('h', 0), try h.encode());
        try turn.write(service.key('v', h.state.revision), try records.snapshot(h.state));
        try turn.write(service.key('c', id), try progress.encode());
        return .{ .complete = h.state.revision };
    };
    if (try h.state.keepForCheckpoint(&reader, entry, if (progress.epoch != h.state.epoch) progress.floor else null)) {
        var staging: Index.Staging = .{ .turn = turn, .publication = service.publication(), .next_id = progress.first_node, .end_id = progress.end_node };
        candidate.index = candidate.index.put(&staging, entry.key, entry.value) catch |err| {
            if (err == error.IndexStaging) return .progress;
            return err;
        };
        // Reserve just one new path after committing the prior bounded entry.
        // This allocation grows durably with the Document, not in resident arrays.
        progress.first_node = h.next_record;
        progress.end_node = std.math.add(u64, progress.first_node, nodes_per_entry) catch return error.DocumentRecordCapacity;
        h.next_record = progress.end_node;
        try turn.write(service.key('t', id), try records.snapshot(candidate));
        try turn.write(service.key('h', 0), try h.encode());
    }
    progress.after = entry.key;
    try turn.write(service.key('c', id), try progress.encode());
    return .progress;
}
pub fn reject(service: Service, turn: *Turn, id: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    var h = try service.head(turn);
    var progress = try inspect(service, turn, id);
    if (progress.phase == .rejected) return;
    if (progress.phase == .complete) return error.DocumentAlreadyAccepted;
    if (h.active_job != id) return error.InvalidDocumentCheckpoint;
    h.active_job = 0;
    progress.phase = .rejected;
    progress.cleanup = progress.allocation_start;
    try turn.write(service.key('h', 0), try h.encode());
    try turn.write(service.key('c', id), try progress.encode());
}
/// Only rejected checkpoints are reclaimed here. Accepted roots may share nodes
/// with retained snapshots; their reachability is not guessed from record age.
pub fn collectRejected(service: Service, turn: *Turn, id: u64) !bool {
    return collectClosed(service, turn, id, false);
}
pub fn collectRetired(service: Service, turn: *Turn, id: u64) !bool {
    return collectClosed(service, turn, id, true);
}
fn collectClosed(service: Service, turn: *Turn, id: u64, retired: bool) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var progress = try inspect(service, turn, id);
    if (retired) {
        if (!(try service.head(turn)).retired) return error.DocumentStillLive;
        if (progress.phase != .complete and progress.phase != .rejected) return error.DocumentJobStillRetained;
        if (progress.cleanup == 0) {
            progress.cleanup = progress.allocation_start;
            try turn.write(service.key('c', id), try progress.encode());
            return false;
        }
    } else if (progress.phase != .rejected) return error.DocumentJobStillRetained;
    if (progress.cleanup == progress.end_node) return true;
    if (progress.cleanup == 0) return error.InvalidDocumentCheckpoint;
    const pubn = service.publication();
    const descriptor = pubn.inspect(turn, progress.cleanup) catch |err| switch (err) {
        error.PublicationNotFound => {
            // Each entry reserves a fixed path interval, with an unused suffix.
            progress.cleanup = @min(progress.end_node, progress.allocation_start + ((progress.cleanup - progress.allocation_start) / nodes_per_entry + 1) * nodes_per_entry);
            try turn.write(service.key('c', id), try progress.encode());
            return progress.cleanup == progress.end_node;
        },
        else => return err,
    };
    switch (descriptor.state) {
        .staging => {
            _ = try pubn.abandon(turn, progress.cleanup);
            return false;
        },
        .published => {
            _ = try pubn.retire(turn, progress.cleanup);
            return false;
        },
        .abandoned, .retired => {
            if (descriptor.collected < descriptor.written or descriptor.reserved) {
                _ = try pubn.collect(turn, progress.cleanup);
                return false;
            }
            progress.cleanup += 1;
            try turn.write(service.key('c', id), try progress.encode());
            return progress.cleanup == progress.end_node;
        },
    }
}
