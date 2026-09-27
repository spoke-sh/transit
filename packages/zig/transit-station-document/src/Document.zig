//! Pure candidate construction and bounded accepted-state reads. Callers own the
//! fenced acceptance decision, current authority and retained root availability.
const std = @import("std");
const Index = @import("transit_station").ImmutableIndex;
const m = @import("Model.zig");
const codec = @import("codec.zig");
const Self = @This();
document: u64,
epoch: u64 = 1,
type_revision: u32 = 1,
revision: u64 = 0,
index: Index = .{},
pub const Candidate = struct { state: Self, duplicate: bool, accepted_revision: u64 };
pub const Assignment = struct { id: m.Dot, value: m.Scalar };
pub const Register = struct {
    len: u8 = 0,
    assignments: [m.max_conflicts]Assignment = undefined,
    pub const Status = enum { missing, null_value, scalar, object, conflict };
    pub fn status(self: Register) Status {
        if (self.len == 0) return .missing;
        if (self.len > 1) return .conflict;
        return switch (self.assignments[0].value) {
            .null_value => .null_value,
            .map, .list, .text => .object,
            else => .scalar,
        };
    }
    pub fn observed(self: Register) m.Observed {
        var out: m.Observed = .{ .len = self.len };
        for (self.assignments[0..self.len], 0..) |a, i| out.dots[i] = a.id;
        return out;
    }
};
pub fn validate(self: Self) !void {
    if (self.document == 0 or self.epoch == 0 or self.type_revision == 0) return error.InvalidDocumentIdentity;
    if (self.index.root) |root| try root.validate();
}
fn key(tag: u8, dot: m.Dot) !Index.Key {
    var bytes: [17]u8 = undefined;
    bytes[0] = tag;
    writeDot(bytes[1..17], dot, false);
    return Index.Key.init(&bytes);
}
fn writeDot(bytes: *[16]u8, dot: m.Dot, reverse: bool) void {
    std.mem.writeInt(u64, bytes[0..8], if (reverse) ~dot.counter else dot.counter, .big);
    std.mem.writeInt(u64, bytes[8..16], if (reverse) ~dot.replica else dot.replica, .big);
}
fn mapSlot(object: m.Dot, field_name: m.Name) !Index.Key {
    try field_name.validate(true);
    var bytes: [82]u8 = undefined;
    bytes[0] = 'R';
    bytes[1] = 'M';
    writeDot(bytes[2..18], object, false);
    @memcpy(bytes[18..][0..field_name.len], field_name.slice());
    return Index.Key.init(bytes[0 .. 18 + field_name.len]);
}
fn listSlot(element_id: m.Dot) !Index.Key {
    return key('R', element_id);
}
fn edgePrefix(object: m.Dot, after: m.Dot) !Index.Key {
    var bytes: [33]u8 = undefined;
    bytes[0] = 'C';
    writeDot(bytes[1..17], object, false);
    writeDot(bytes[17..33], after, false);
    return Index.Key.init(&bytes);
}
fn edgeKey(object: m.Dot, after: m.Dot, id: m.Dot) !Index.Key {
    const prefix = try edgePrefix(object, after);
    var bytes: [49]u8 = undefined;
    @memcpy(bytes[0..33], prefix.slice());
    writeDot(bytes[33..49], id, true);
    return Index.Key.init(&bytes);
}
fn frontierKey(replica: u64) !Index.Key {
    return key('P', .{ .replica = replica });
}
fn put(self: *Self, store: anytype, k: Index.Key, bytes: []const u8) !void {
    self.index = try self.index.put(store, k, try Index.Value.init(bytes));
}
fn require(self: Self, source: anytype, k: Index.Key) !Index.Value {
    return try self.index.get(source, k) orelse error.DocumentDependencyMissing;
}
pub fn objectKind(self: Self, source: anytype, object: m.Dot) !m.Kind {
    try object.validate(true);
    if (object.eql(.root)) return .map;
    const v = try self.require(source, try key('O', object));
    if (v.len != 1) return error.InvalidDocumentState;
    return std.enums.fromInt(m.Kind, v.data[0]) orelse error.InvalidDocumentState;
}
const StoredAssignment = struct { slot: Index.Key, value: m.Scalar };
fn assignment(self: Self, source: anytype, id: m.Dot) !StoredAssignment {
    const v = try self.require(source, try key('A', id));
    var r: codec.Reader = .{ .bytes = v.slice() };
    const a: StoredAssignment = .{ .slot = try Index.Key.init(try r.string()), .value = try r.scalar() };
    try r.finish();
    return a;
}
fn dots(self: Self, source: anytype, slot: Index.Key) !m.Observed {
    const v = try self.index.get(source, slot) orelse return .{};
    var r: codec.Reader = .{ .bytes = v.slice() };
    const out = try r.observed();
    try r.finish();
    var previous: ?m.Dot = null;
    for (out.slice()) |dot| {
        try dot.validate(false);
        if (previous) |p| if (p.order(dot) != .lt) return error.InvalidDocumentState;
        previous = dot;
    }
    return out;
}
fn register(self: Self, source: anytype, slot: Index.Key) !Register {
    const ids = try self.dots(source, slot);
    var out: Register = .{ .len = ids.len };
    for (ids.slice(), 0..) |id, i| {
        const a = try self.assignment(source, id);
        if (!Index.Key.eql(a.slot, slot)) return error.InvalidDocumentState;
        out.assignments[i] = .{ .id = id, .value = a.value };
    }
    return out;
}
pub fn field(self: Self, source: anytype, object: m.Dot, name: m.Name) !Register {
    if (try self.objectKind(source, object) != .map) return error.DocumentTypeError;
    return self.register(source, try mapSlot(object, name));
}
/// Traverses only visible map assignments. Detached objects never reappear;
/// missing, explicit null, scalar type mismatch and unresolved conflict differ.
pub fn path(self: Self, source: anytype, names: []const m.Name) !Register {
    if (names.len == 0 or names.len > 16) return error.DocumentPathCapacity;
    var object: m.Dot = .root;
    for (names, 0..) |name, i| {
        const out = try self.field(source, object, name);
        if (i + 1 == names.len or out.status() == .missing or out.status() == .conflict) return out;
        if (out.status() != .object or out.assignments[0].value != .map) return error.DocumentTypeError;
        object = out.assignments[0].id;
    }
    unreachable;
}
fn updateRegister(self: *Self, store: anytype, slot: Index.Key, observed: m.Observed, id: m.Dot, scalar: ?m.Scalar) !void {
    for (observed.slice()) |dot| {
        const a = try self.assignment(store, dot);
        if (!Index.Key.eql(a.slot, slot)) return error.DocumentWrongDependency;
    }
    const current = try self.dots(store, slot);
    var next: m.Observed = .{};
    for (current.slice()) |dot| if (!observed.contains(dot)) {
        next.dots[next.len] = dot;
        next.len += 1;
    };
    if (scalar) |v| {
        if (next.len == m.max_conflicts) return error.DocumentConflictCapacity;
        var at: usize = next.len;
        while (at > 0 and next.dots[at - 1].order(id) == .gt) : (at -= 1) next.dots[at] = next.dots[at - 1];
        next.dots[at] = id;
        next.len += 1;
        var bytes: [256]u8 = undefined;
        var w: codec.Writer = .{ .bytes = &bytes };
        try w.string(slot.slice());
        try w.scalar(v);
        try self.put(store, try key('A', id), bytes[0..w.offset]);
        if (v.kind()) |kind| try self.put(store, try key('O', id), &.{@backingInt(kind)});
    }
    var bytes: [129]u8 = undefined;
    var w: codec.Writer = .{ .bytes = &bytes };
    try w.observed(next);
    try self.put(store, slot, bytes[0..w.offset]);
}
const Element = struct { object: m.Dot, after: m.Dot, deleted: bool };
fn element(self: Self, source: anytype, id: m.Dot) !Element {
    const v = try self.require(source, try key('E', id));
    var r: codec.Reader = .{ .bytes = v.slice() };
    const out: Element = .{ .object = try r.dot(), .after = try r.dot(), .deleted = switch (try r.int(u8)) {
        0 => false,
        1 => true,
        else => return error.InvalidDocumentState,
    } };
    try r.finish();
    return out;
}
fn putElement(self: *Self, store: anytype, id: m.Dot, e: Element) !void {
    var bytes: [33]u8 = undefined;
    var w: codec.Writer = .{ .bytes = &bytes };
    try w.dot(e.object);
    try w.dot(e.after);
    try w.int(u8, @intFromBool(e.deleted));
    try self.put(store, try key('E', id), &bytes);
}
fn applyOperation(self: *Self, store: anytype, id: m.Dot, operation: m.Operation) !void {
    switch (operation) {
        .assign => |op| {
            if (try self.objectKind(store, op.object) != .map or op.value == .character) return error.DocumentTypeError;
            try self.updateRegister(store, try mapSlot(op.object, op.field), op.observed, id, op.value);
        },
        .remove => |op| {
            if (try self.objectKind(store, op.object) != .map) return error.DocumentTypeError;
            try self.updateRegister(store, try mapSlot(op.object, op.field), op.observed, id, null);
        },
        .insert => |op| {
            const kind = try self.objectKind(store, op.object);
            if (kind == .map or (kind == .text) != (op.value == .character)) return error.DocumentTypeError;
            if (!op.after.eql(.root)) {
                const anchor = try self.element(store, op.after);
                if (!anchor.object.eql(op.object)) return error.DocumentWrongDependency;
            }
            try self.putElement(store, id, .{ .object = op.object, .after = op.after, .deleted = false });
            var bytes: [16]u8 = undefined;
            var w: codec.Writer = .{ .bytes = &bytes };
            try w.dot(id);
            try self.put(store, try edgeKey(op.object, op.after, id), &bytes);
            try self.updateRegister(store, try listSlot(id), .{}, id, op.value);
        },
        .set_element => |op| {
            if (try self.objectKind(store, op.object) != .list or op.value == .character) return error.DocumentTypeError;
            if (!(try self.element(store, op.element)).object.eql(op.object)) return error.DocumentWrongDependency;
            try self.updateRegister(store, try listSlot(op.element), op.observed, id, op.value);
        },
        .delete_element => |op| {
            if (try self.objectKind(store, op.object) == .map) return error.DocumentTypeError;
            var e = try self.element(store, op.element);
            if (!e.object.eql(op.object)) return error.DocumentWrongDependency;
            e.deleted = true;
            try self.putElement(store, op.element, e);
        },
    }
}
pub fn replicaCounter(self: Self, source: anytype, replica: u64) !u64 {
    if (replica == 0) return error.InvalidDocumentIdentity;
    return self.counter(source, try frontierKey(replica));
}
pub fn clock(self: Self, source: anytype) !u64 {
    return self.counter(source, try key('L', .root));
}
fn counter(self: Self, source: anytype, address: Index.Key) !u64 {
    const value = try self.index.get(source, address) orelse return 0;
    if (value.len != 8) return error.InvalidDocumentState;
    return std.mem.readInt(u64, value.data[0..8], .little);
}
/// Returns a candidate. Even if the store staged nodes, the input snapshot is
/// unchanged. The owner atomically binds candidate.state to accept this change.
pub fn apply(self: Self, store: anytype, change: m.Change) !Candidate {
    try self.validate();
    try change.validate();
    if (change.document != self.document or change.type_revision != self.type_revision) return error.DocumentIdentityMismatch;
    if (change.epoch != self.epoch) return error.DocumentResyncRequired;
    var encoded: [m.max_change_bytes]u8 = undefined;
    const bytes = try codec.encode(change, &encoded);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const history_key = try key('H', change.id(0));
    if (try self.index.get(store, history_key)) |v| {
        if (v.len != 48 or !std.mem.eql(u8, v.data[0..32], &digest) or std.mem.readInt(u64, v.data[32..40], .little) != change.last()) return error.DocumentIdentityConflict;
        return .{ .state = self, .duplicate = true, .accepted_revision = std.mem.readInt(u64, v.data[40..48], .little) };
    }
    const previous = try self.replicaCounter(store, change.replica);
    if (change.first <= previous or change.previous < previous) return error.DocumentIdentityConflict;
    if (change.previous != previous) return error.DocumentDependencyMissing;
    var candidate = self;
    candidate.revision = std.math.add(u64, self.revision, 1) catch return error.DocumentRevisionCapacity;
    for (change.operations[0..change.len], 0..) |op, i| try candidate.applyOperation(store, change.id(i), op);
    var history: [48]u8 = undefined;
    @memcpy(history[0..32], &digest);
    std.mem.writeInt(u64, history[32..40], change.last(), .little);
    std.mem.writeInt(u64, history[40..48], candidate.revision, .little);
    try candidate.put(store, history_key, &history);
    var frontier: [8]u8 = undefined;
    std.mem.writeInt(u64, &frontier, change.last(), .little);
    try candidate.put(store, try frontierKey(change.replica), &frontier);
    std.mem.writeInt(u64, &frontier, @max(change.last(), try self.clock(store)), .little);
    try candidate.put(store, try key('L', .root), &frontier);
    return .{ .state = candidate, .duplicate = false, .accepted_revision = candidate.revision };
}
/// Epoch-changing compaction drops only obsolete register assignments and
/// duplicate-change records below the explicit floor. Sequence anchors, deletion
/// evidence, object identities, replica frontiers and clocks remain preserved.
pub fn keepForCheckpoint(self: Self, source: anytype, entry: Index.Entry, floor: ?u64) !bool {
    const cutoff = floor orelse return true;
    if (entry.key.data[0] == 'H') {
        if (entry.value.len != 48) return error.InvalidDocumentState;
        return std.mem.readInt(u64, entry.value.data[40..48], .little) >= cutoff;
    }
    if (entry.key.data[0] == 'A') {
        if (entry.key.len != 17) return error.InvalidDocumentState;
        const id: m.Dot = .{ .counter = std.mem.readInt(u64, entry.key.data[1..9], .big), .replica = std.mem.readInt(u64, entry.key.data[9..17], .big) };
        const a = try self.assignment(source, id);
        return (try self.dots(source, a.slot)).contains(id);
    }
    if (entry.key.data[0] == 'R') return (try self.dots(source, entry.key)).len != 0;
    return true;
}
pub const SequenceCursor = struct {
    current: m.Dot = .root,
    phase: enum(u8) { children, siblings, done } = .children,
};
pub const SequenceItem = struct { id: m.Dot, values: Register };
pub const SequenceStep = union(enum) { item: SequenceItem, more, end };
fn edge(self: Self, source: anytype, object: m.Dot, anchor: m.Dot, after: ?m.Dot) !?m.Dot {
    const prefix = try edgePrefix(object, anchor);
    const entry = try self.index.next(source, if (after) |a| try edgeKey(object, anchor, a) else prefix) orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return null;
    if (entry.key.len != 49 or entry.value.len != 16) return error.InvalidDocumentState;
    var r: codec.Reader = .{ .bytes = entry.value.slice() };
    const id = try r.dot();
    try id.validate(false);
    if (!Index.Key.eql(entry.key, try edgeKey(object, anchor, id))) return error.InvalidDocumentState;
    return id;
}
/// One bounded traversal transition, including deleted anchors. 'more' is not
/// EOF. Preserve the exact snapshot and cursor and bound steps per output page.
pub fn sequenceStep(self: Self, source: anytype, object: m.Dot, cursor: *SequenceCursor) !SequenceStep {
    if (try self.objectKind(source, object) == .map) return error.DocumentTypeError;
    if (cursor.phase == .done) return .end;
    try cursor.current.validate(true);
    if (cursor.phase == .siblings and cursor.current.eql(.root)) return error.InvalidDocumentCursor;
    if (!cursor.current.eql(.root) and !(try self.element(source, cursor.current)).object.eql(object)) return error.InvalidDocumentCursor;
    const next = if (cursor.phase == .children) try self.edge(source, object, cursor.current, null) else blk: {
        const current = try self.element(source, cursor.current);
        if (!current.object.eql(object)) return error.InvalidDocumentCursor;
        break :blk try self.edge(source, object, current.after, cursor.current);
    };
    if (next) |id| {
        const e = try self.element(source, id);
        if (!e.object.eql(object)) return error.InvalidDocumentState;
        const values = try self.register(source, try listSlot(id));
        cursor.* = .{ .current = id, .phase = .children };
        return if (e.deleted) .more else .{ .item = .{ .id = id, .values = values } };
    }
    if (cursor.phase == .siblings) cursor.current = (try self.element(source, cursor.current)).after;
    cursor.phase = if (cursor.current.eql(.root)) .done else .siblings;
    return if (cursor.phase == .done) .end else .more;
}
