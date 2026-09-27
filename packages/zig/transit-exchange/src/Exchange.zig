const std = @import("std");
const root = @import("root.zig");
const p = root.p;
const Pub = root.Publication;
const Turn = root.station.GrowingTurn;
const Self = @This();
resource: u64,
id: u64,
pub fn key(id: u64, tag: u8, ordinal: u32) p.Value {
    var bytes: [15]u8 = undefined;
    bytes[0..2].* = "\x00E".*;
    std.mem.writeInt(u64, bytes[2..10], id, .big);
    bytes[10] = tag;
    std.mem.writeInt(u32, bytes[11..15], ordinal, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn publication(self: Self) Pub {
    return .{ .resource = self.resource, .namespace = self.id };
}
pub fn create(turn: *Turn, id: u64, origin: root.Origin, limits: root.Limits, reconcile_before_ms: u64) !Self {
    if (origin.parent != 0) return error.UseExchangeFollowup;
    return createRecord(turn, id, origin, limits, reconcile_before_ms);
}
fn createRecord(turn: *Turn, id: u64, origin: root.Origin, limits: root.Limits, reconcile_before_ms: u64) !Self {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (id == 0 or origin.parent == id) return error.InvalidExchangeIdentity;
    const self: Self = .{ .resource = turn.view.resource, .id = id };
    const initial: root.Descriptor = .{ .protocol = origin.protocol, .caller = origin.caller, .input = origin.input, .parent = origin.parent, .owner = turn.delivery.pid, .reconcile_before_ms = reconcile_before_ms, .segment_bytes = limits.segment_bytes, .capture_bytes = limits.capture_bytes, .max_segments = limits.segments };
    try initial.validate();
    if (try turn.read(key(id, 'd', 0))) |value| {
        const old = try root.Descriptor.decode(value);
        if (old.phase == .retired) return error.ExchangeUnavailable;
        if (old.protocol != initial.protocol or old.caller != initial.caller or old.input != initial.input or old.parent != initial.parent or old.owner != initial.owner or old.reconcile_before_ms != reconcile_before_ms or old.segment_bytes != limits.segment_bytes or old.capture_bytes != limits.capture_bytes or old.max_segments != limits.segments) return error.ExchangeIdentityConflict;
        return self;
    }
    // A namespace belongs exclusively to one exchange; never adopt unrelated bodies.
    if (try turn.read(Pub.key(id, 'b', 0, 0)) != null) return error.ExchangeIdentityConflict;
    _ = try Pub.create(turn, id, .{ .record_bytes = limits.segment_bytes, .staging_bytes = limits.segment_bytes, .staging_records = 1 });
    try turn.write(key(id, 'd', 0), try initial.encode());
    return self;
}
pub const FollowupReason = enum(u8) { retry = 1, redirect = 2, reconcile = 3, cancel = 4 };
pub const AttemptBudget = struct {
    pub const magic = "EXB1";
    limit: u32,
    used: u32 = 1,
    pub fn validate(self: AttemptBudget) !void {
        if (self.limit == 0 or self.used == 0 or self.used > self.limit) return error.InvalidExchangeBudget;
    }
};
pub const Lineage = struct {
    pub const magic = "EXL1";
    root: u64,
    parent: u64,
    ordinal: u32,
    reason: FollowupReason,
    /// Opaque versioned adapter policy decision, not kernel authority.
    policy: u64,
    policy_revision: u64,
    pub fn validate(self: Lineage) !void {
        if (self.root == 0 or self.parent == 0 or self.ordinal < 2 or self.policy == 0 or self.policy_revision == 0) return error.InvalidExchangeLineage;
    }
};
/// Immutable bounded adapter metadata stored atomically with child allocation.
/// The common layer neither interprets it nor treats it as authority.
pub const Link = struct {
    pub const maximum_context_bytes = 214;
    lineage: Lineage,
    context: p.Value = .{},
    pub fn encode(self: Link) !p.Value {
        try self.context.validate();
        if (self.context.len > maximum_context_bytes) return error.ExchangeContextTooLarge;
        const base = try root.codec.encode(self.lineage);
        if (self.context.len == 0) return base;
        var bytes: [256]u8 = undefined;
        @memcpy(bytes[0..base.len], base.slice());
        bytes[0..4].* = "EXL2".*;
        bytes[base.len] = @intCast(self.context.len);
        const end = @as(usize, base.len) + 1 + self.context.len;
        @memcpy(bytes[base.len + 1 .. end], self.context.slice());
        return p.Value.init(bytes[0..end]);
    }
    pub fn decode(value: p.Value) !Link {
        try value.validate();
        if (value.len >= 4 and std.mem.eql(u8, value.data[0..4], Lineage.magic)) return .{ .lineage = try root.codec.decode(Lineage, value) };
        const header = root.codec.size(Lineage);
        if (value.len <= header + 1 or !std.mem.eql(u8, value.data[0..4], "EXL2") or value.data[header] == 0 or value.len != header + 1 + @as(usize, value.data[header])) return error.InvalidExchangeRecord;
        var base = try p.Value.init(value.data[0..header]);
        base.data[0..4].* = Lineage.magic.*;
        return .{ .lineage = try root.codec.decode(Lineage, base), .context = try p.Value.init(value.slice()[header + 1 ..]) };
    }
};
pub fn lineage(self: Self, source: anytype) !?Link {
    if (self.id == 0 or self.resource != source.view.resource) return error.InvalidExchangeIdentity;
    return if (try source.read(key(self.id, 'l', 0))) |value| try Link.decode(value) else null;
}
/// Root policy is fixed before its effect intent. No policy means one attempt.
pub fn configureAttempts(self: Self, turn: *Turn, limit: u32) !void {
    const d = try self.writable(turn);
    if (d.parent != 0) return error.NotRootExchange;
    const budget: AttemptBudget = .{ .limit = limit };
    try budget.validate();
    if (try turn.read(key(self.id, 'b', 0))) |value| {
        if ((try root.codec.decode(AttemptBudget, value)).limit != limit) return error.ExchangePolicyChanged;
        return;
    }
    if (d.phase != .preparing) return error.ExchangePolicyChanged;
    try turn.write(key(self.id, 'b', 0), try root.codec.encode(budget));
}
/// One explicit new effect/capture under the original lineage and deadline.
/// The adapter must validate its endpoint-specific retry/redirect policy first.
pub fn followup(self: Self, turn: *Turn, id: u64, reason: FollowupReason, policy: u64, policy_revision: u64, limits: root.Limits) !Self {
    return self.followupWithContext(turn, id, reason, policy, policy_revision, limits, .{});
}
pub fn followupWithContext(self: Self, turn: *Turn, id: u64, reason: FollowupReason, policy: u64, policy_revision: u64, limits: root.Limits, context: p.Value) !Self {
    const before = turn.decision;
    errdefer turn.decision = before;
    try context.validate();
    if (context.len > Link.maximum_context_bytes) return error.ExchangeContextTooLarge;
    const parent = try self.writable(turn);
    if (parent.phase != .complete and parent.phase != .unknown) return error.ExchangeStillOpen;
    var root_id = self.id;
    if (parent.parent != 0) {
        const ancestor = (try self.lineage(turn)) orelse return error.InvalidExchangeLineage;
        root_id = ancestor.lineage.root;
    }
    const root_exchange: Self = .{ .resource = self.resource, .id = root_id };
    const origin = try root_exchange.writable(turn);
    if (origin.parent != 0 or origin.caller != parent.caller or origin.input != parent.input or origin.reconcile_before_ms != parent.reconcile_before_ms) return error.InvalidExchangeLineage;
    if (origin.phase == .retired) return error.ExchangeUnavailable;
    const budget_key = key(root_id, 'b', 0);
    var budget = try root.codec.decode(AttemptBudget, (try turn.read(budget_key)) orelse return error.ExchangeAttemptBudgetExceeded);
    if (try turn.read(key(id, 'l', 0))) |value| {
        const linked = try Link.decode(value);
        const existing = linked.lineage;
        if (!linked.context.eql(context)) return error.ExchangeIdentityConflict;
        if (existing.root != root_id or existing.parent != self.id or existing.reason != reason or existing.policy != policy or existing.policy_revision != policy_revision) return error.ExchangeIdentityConflict;
        return createRecord(turn, id, .{ .caller = parent.caller, .input = parent.input, .parent = self.id, .protocol = parent.protocol }, limits, parent.reconcile_before_ms);
    }
    if (budget.used == budget.limit) return error.ExchangeAttemptBudgetExceeded;
    // A pre-existing unrelated ID cannot be adopted as an attempted child.
    if (try turn.read(key(id, 'd', 0)) != null) return error.ExchangeIdentityConflict;
    budget.used += 1;
    const linked: Link = .{ .lineage = .{ .root = root_id, .parent = self.id, .ordinal = budget.used, .reason = reason, .policy = policy, .policy_revision = policy_revision }, .context = context };
    const encoded = try linked.encode();
    const child = try createRecord(turn, id, .{ .caller = parent.caller, .input = parent.input, .parent = self.id, .protocol = parent.protocol }, limits, parent.reconcile_before_ms);
    try turn.write(key(id, 'l', 0), encoded);
    try turn.write(budget_key, try root.codec.encode(budget));
    return child;
}
pub fn inspect(self: Self, source: anytype) !root.Descriptor {
    if (self.id == 0 or self.resource != source.view.resource) return error.InvalidExchangeIdentity;
    return root.Descriptor.decode((try source.read(key(self.id, 'd', 0))) orelse return error.ExchangeNotFound);
}
fn writable(self: Self, turn: *Turn) !root.Descriptor {
    const d = try self.inspect(turn);
    if (d.owner != turn.delivery.pid) return error.WrongExchangeWriter;
    return d;
}
fn save(self: Self, turn: *Turn, d: root.Descriptor) !void {
    try turn.write(key(self.id, 'd', 0), try d.encode());
}
pub const Control = struct {
    pub const magic = "EXC1";
    dependents: u64 = 0,
    disposition: enum(u8) { no_intent = 1, pending = 2, observed = 3, cancelled = 4, closed_unknown = 5 } = .no_intent,
    caller: enum(u8) { none = 1, held = 2, released = 3 } = .none,
    effect: u64 = 0,
    pub fn validate(self: Control) !void {
        if ((self.disposition == .no_intent or self.disposition == .pending) != (self.effect == 0)) return error.InvalidExchangeRecord;
        if ((self.disposition == .no_intent) != (self.caller == .none)) return error.InvalidExchangeRecord;
    }
};
pub const Dependency = struct {
    pub const magic = "EXH1";
    holder: u64,
    phase: enum(u8) { held = 1, released = 2 } = .held,
    pub fn validate(self: Dependency) !void {
        if (self.holder == 0) return error.InvalidExchangeRecord;
    }
};
pub fn dependencyKey(id: u64, token: u64) p.Value {
    var bytes: [19]u8 = undefined;
    bytes[0..2].* = "\x00E".*;
    std.mem.writeInt(u64, bytes[2..10], id, .big);
    bytes[10] = 'h';
    std.mem.writeInt(u64, bytes[11..19], token, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn control(self: Self, source: anytype) !Control {
    return if (try source.read(key(self.id, 'c', 0))) |value| try root.codec.decode(Control, value) else .{};
}
/// A trusted admission handler validates the holder's resource/lifetime grant
/// first. Tokens are permanent identities, not bearer grants or expiring leases.
pub fn retain(self: Self, turn: *Turn, token: u64, holder: u64) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    const d = try self.writable(turn);
    if (d.phase == .retired) return error.ExchangeUnavailable;
    if (token == 0 or holder == 0) return error.InvalidExchangeIdentity;
    const k = dependencyKey(self.id, token);
    if (try turn.read(k)) |value| {
        const previous = try root.codec.decode(Dependency, value);
        if (previous.holder != holder) return error.ExchangeIdentityConflict;
        if (previous.phase == .released) return error.ExchangeDependencyReleased;
        return .duplicate;
    }
    var c = try self.control(turn);
    c.dependents = try std.math.add(u64, c.dependents, 1);
    try turn.write(k, try root.codec.encode(Dependency{ .holder = holder }));
    try turn.write(key(self.id, 'c', 0), try root.codec.encode(c));
    return .changed;
}
/// Invoke only for an authenticated holder acknowledgement or explicit authorized
/// disposal of that dependency; caller termination alone is not acknowledgement.
pub fn release(self: Self, turn: *Turn, token: u64, holder: u64) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    _ = try self.writable(turn);
    if (token == 0) return error.InvalidExchangeIdentity;
    const k = dependencyKey(self.id, token);
    var dependency = try root.codec.decode(Dependency, (try turn.read(k)) orelse return error.UnknownExchangeDependency);
    if (dependency.holder != holder) return error.WrongExchangeHolder;
    if (dependency.phase == .released) return .duplicate;
    var c = try self.control(turn);
    if (c.dependents == 0) return error.InvalidExchangeRecord;
    c.dependents -= 1;
    dependency.phase = .released;
    try turn.write(k, try root.codec.encode(dependency));
    try turn.write(key(self.id, 'c', 0), try root.codec.encode(c));
    return .changed;
}
pub fn releaseCaller(self: Self, turn: *Turn, caller: u64) !Pub.Outcome {
    const d = try self.writable(turn);
    if (d.caller != caller) return error.WrongExchangeHolder;
    var c = try self.control(turn);
    if (c.disposition == .no_intent or c.disposition == .pending) return error.UnsettledExchange;
    if (c.caller == .released) return .duplicate;
    c.caller = .released;
    try turn.write(key(self.id, 'c', 0), try root.codec.encode(c));
    return .changed;
}
/// Record a terminal kernel decision obtained through an authenticated read.
/// Terminal capture by itself cannot discharge an outstanding effect obligation.
pub fn settle(self: Self, turn: *Turn, effect: p.Growth.Effect) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .complete and d.phase != .unknown) return error.ExchangeStillOpen;
    if (effect.pid != d.owner or effect.id == 0 or !(try turn.read(key(self.id, 'i', 0)) orelse return error.UnsettledExchange).eql(effect.payload)) return error.InvalidExchangeAttempt;
    if (d.effect != 0 and (d.effect != effect.id or d.attempt != effect.attempt or d.executor != effect.executor)) return error.InvalidExchangeAttempt;
    var c = try self.control(turn);
    const disposition: @FieldType(Control, "disposition") = switch (effect.phase) {
        .observed => if (d.phase == .complete and effect.result != null) .observed else return error.InvalidExchangeAttempt,
        .cancelled => .cancelled,
        .closed_unknown => .closed_unknown,
        else => return error.UnsettledExchange,
    };
    if (c.disposition != .pending) {
        if (c.disposition != disposition or c.effect != effect.id) return error.ExchangeIdentityConflict;
        return .duplicate;
    }
    if (effect.phase != .cancelled) {
        if (effect.attempt == null or effect.executor == null or effect.attempt.? == 0 or effect.executor.? == 0 or effect.reconcile_before_ms != d.reconcile_before_ms) return error.InvalidExchangeAttempt;
        // A worker can disappear after dispatch but before binding capture.
        // Preserve that recovered identity even when no response bytes exist.
        if (d.effect == 0) {
            d.effect = effect.id;
            d.attempt = effect.attempt.?;
            d.executor = effect.executor.?;
            try self.save(turn, d);
        }
    }
    c.disposition = disposition;
    c.effect = effect.id;
    try turn.write(key(self.id, 'c', 0), try root.codec.encode(c));
    return .changed;
}
/// Freeze exact request coverage and its effect intent in the same turn. The
/// ready state prevents recovery from creating a second effect for this group.
pub fn commitIntent(self: Self, turn: *Turn) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase == .ready) return .duplicate;
    if (d.phase != .preparing) return error.ExchangeClosed;
    if (d.pending_kind != 0 or d.segments == 0) return error.ExchangeNotPrepared;
    if (turn.decision.effect != null) return error.EffectBudgetExceeded;
    turn.decision.effect = try (root.Intent{ .resource = self.resource, .exchange = self.id, .segments = d.segments, .bytes = d.bytes, .chain = d.chain }).encode();
    var c = try self.control(turn);
    if (c.disposition != .no_intent) return error.ExchangeIdentityConflict;
    c.disposition = .pending;
    c.caller = .held;
    try turn.write(key(self.id, 'i', 0), turn.decision.effect.?);
    try turn.write(key(self.id, 'c', 0), try root.codec.encode(c));
    d.phase = .ready;
    try self.save(turn, d);
    return .changed;
}
pub fn bind(self: Self, turn: *Turn, effect: p.Growth.Effect) !Pub.Outcome {
    var d = try self.writable(turn);
    if (effect.pid != d.owner or effect.id == 0 or effect.phase != .authorized or effect.attempt == null or effect.executor == null or effect.reconcile_before_ms != d.reconcile_before_ms) return error.InvalidExchangeAttempt;
    if (d.effect != 0) {
        if (d.effect != effect.id or d.attempt != effect.attempt.? or d.executor != effect.executor.?) return error.ExchangeIdentityConflict;
        if (d.phase != .capturing) return error.ExchangeClosed;
        return .duplicate;
    }
    if (d.phase != .ready or d.pending_kind != 0) return error.ExchangeNotPrepared;
    const intent = try root.Intent.decode(effect.payload);
    if (intent.resource != self.resource or intent.exchange != self.id or intent.segments != d.segments or intent.bytes != d.bytes or !std.mem.eql(u8, &intent.chain, &d.chain)) return error.ExchangeIdentityConflict;
    d.effect = effect.id;
    d.attempt = effect.attempt.?;
    d.executor = effect.executor.?;
    d.phase = .capturing;
    try self.save(turn, d);
    return .changed;
}
pub fn member(self: Self, source: anytype, ordinal: u32) !root.Member {
    const d = try self.inspect(source);
    if (ordinal >= d.segments) return error.ExchangeGap;
    const result = try root.Member.decode((try source.read(key(self.id, 'm', ordinal))) orelse return error.ExchangeGap);
    if (result.ordinal != ordinal) return error.InvalidExchangeRecord;
    return result;
}
pub fn beginSegment(self: Self, turn: *Turn, ordinal: u32, kind: u32, spec: Pub.Spec) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (kind == 0) return error.InvalidExchangeRecord;
    if (ordinal < d.segments) {
        const old = try self.member(turn, ordinal);
        if (old.kind != kind or !std.meta.eql(old.spec(), spec)) return error.ExchangeIdentityConflict;
        return .duplicate;
    }
    if (ordinal != d.segments) return error.ExchangeGap;
    if (d.segments == d.max_segments or spec.length > d.capture_bytes - d.bytes) return error.ExchangeCapacity;
    if (d.pending_kind != 0 and d.pending_kind != kind) return error.ExchangeIdentityConflict;
    const outcome = try self.publication().begin(turn, @as(u64, ordinal) + 1, spec);
    d.pending_kind = kind;
    try self.save(turn, d);
    return outcome;
}
pub fn append(self: Self, turn: *Turn, ordinal: u32, chunk: u32, bytes: []const u8) !Pub.Outcome {
    const d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (ordinal != d.segments or d.pending_kind == 0) return error.ExchangeGap;
    return self.publication().append(turn, @as(u64, ordinal) + 1, chunk, bytes);
}
pub fn sealSegment(self: Self, turn: *Turn, ordinal: u32) !Pub.Outcome {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .preparing and d.phase != .capturing) return error.ExchangeClosed;
    if (ordinal < d.segments) {
        _ = try self.member(turn, ordinal);
        return .duplicate;
    }
    if (ordinal != d.segments or d.pending_kind == 0) return error.ExchangeGap;
    const pubn = self.publication();
    const record = try pubn.inspect(turn, @as(u64, ordinal) + 1);
    if (record.spec.length > d.capture_bytes - d.bytes) return error.ExchangeCapacity;
    const chain = root.Coverage.next(d.chain, ordinal, d.pending_kind, record.spec);
    const entry: root.Member = .{ .ordinal = ordinal, .kind = d.pending_kind, .format = record.spec.format, .length = record.spec.length, .digest = record.spec.digest, .chain = chain };
    _ = try pubn.publish(turn, @as(u64, ordinal) + 1);
    d.segments += 1;
    d.bytes += record.spec.length;
    d.chain = chain;
    d.pending_kind = 0;
    try turn.write(key(self.id, 'm', ordinal), try entry.encode());
    try self.save(turn, d);
    return .changed;
}
pub fn finish(self: Self, turn: *Turn, code: u32) !Pub.Outcome {
    var d = try self.writable(turn);
    if (code == 0) return error.InvalidExchangeRecord;
    if (d.phase == .complete) {
        if (d.terminal_code != code) return error.ExchangeIdentityConflict;
        return .duplicate;
    }
    if (d.phase != .capturing) return error.ExchangeClosed;
    if (d.pending_kind != 0) return error.IncompleteExchange;
    d.phase = .complete;
    d.terminal_code = code;
    try self.save(turn, d);
    return .changed;
}
pub fn reference(self: Self, source: anytype) !root.Client.Reference {
    const d = try self.inspect(source);
    if (d.phase == .retired) return error.ExchangeUnavailable;
    if (d.phase != .complete) return error.IncompleteExchange;
    return .{ .resource = self.resource, .exchange = self.id, .chain = d.chain };
}
pub fn closeUnknown(self: Self, turn: *Turn) !Pub.Outcome {
    var d = try self.writable(turn);
    if (d.phase == .unknown) return .duplicate;
    if (d.phase != .preparing and d.phase != .ready and d.phase != .capturing) return error.ExchangeClosed;
    d.phase = .unknown;
    try self.save(turn, d);
    return .changed;
}
/// Retirement is serialized with dependency admission in the writer's turn.
pub fn retire(self: Self, turn: *Turn) !Pub.Outcome {
    var d = try self.writable(turn);
    if (d.phase == .retired) return .duplicate;
    if (d.phase != .complete and d.phase != .unknown) return error.ExchangeStillOpen;
    const c = try self.control(turn);
    if (c.disposition == .pending or (d.effect != 0 and c.disposition == .no_intent)) return error.UnsettledExchange;
    if (c.caller == .held or c.dependents != 0) return error.ExchangeHasDependents;
    d.phase = .retired;
    try self.save(turn, d);
    return .changed;
}
/// Each call either closes one member, cleans <=2 chunks, or advances the floor.
pub fn collect(self: Self, turn: *Turn) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var d = try self.writable(turn);
    if (d.phase != .retired) return error.ExchangeStillOpen;
    const total = @as(u64, d.segments) + @intFromBool(d.pending_kind != 0);
    if (d.collected == total) return true;
    const id = @as(u64, d.collected) + 1;
    const pubn = self.publication();
    const record = try pubn.inspect(turn, id);
    switch (record.state) {
        .staging => {
            _ = try pubn.abandon(turn, id);
            return false;
        },
        .published => {
            _ = try pubn.retire(turn, id);
            return false;
        },
        else => {},
    }
    if (record.reserved or record.collected != record.written) {
        _ = try pubn.collect(turn, id);
        return false;
    }
    d.collected += 1;
    try self.save(turn, d);
    return d.collected == total;
}
pub const Cursor = struct {
    descriptor: root.Descriptor,
    next_member: u32 = 0,
    chain: [32]u8 = root.Coverage.initial,
    bytes: u64 = 0,
    member_cursor: ?Pub.Cursor = null,
};
pub const Part = struct { kind: u32, bytes: p.Value, next: ?Cursor };
fn available(self: Self, current: anytype) !root.Descriptor {
    const d = try self.inspect(current);
    if (d.phase == .retired) return error.ExchangeUnavailable;
    return d;
}
/// `current` must resolve fresh authority at every step, even for old sources.
pub fn open(self: Self, current: anytype, source: anytype) !Cursor {
    const now = try self.available(current);
    const d = try self.inspect(source);
    if (d.phase != .complete or now.phase != .complete) return error.IncompleteExchange;
    if (!std.meta.eql(d, now)) return error.StaleExchangeSource;
    return .{ .descriptor = d };
}
pub fn read(self: Self, current: anytype, source: anytype, cursor: Cursor) !Part {
    const now = try self.available(current);
    if (!std.meta.eql(now, cursor.descriptor) or !std.meta.eql(try self.inspect(source), cursor.descriptor)) return error.StaleExchangeSource;
    if (now.phase != .complete or cursor.next_member > now.segments) return error.IncompleteExchange;
    var next = cursor;
    if (cursor.next_member == now.segments) {
        if (cursor.member_cursor != null or cursor.bytes != now.bytes or !std.mem.eql(u8, &cursor.chain, &now.chain)) return error.InvalidExchangeCoverage;
        return .{ .kind = 0, .bytes = .{}, .next = null };
    }
    const entry = try self.member(source, cursor.next_member);
    const pubn = self.publication();
    const chunk = cursor.member_cursor orelse try pubn.open(source, @as(u64, cursor.next_member) + 1);
    if (!std.meta.eql(chunk.spec, entry.spec()) or chunk.id != @as(u64, cursor.next_member) + 1) return error.InvalidExchangeCoverage;
    const part = try pubn.read(source, chunk);
    next.member_cursor = part.next;
    if (part.next == null) {
        next.chain = root.Coverage.next(cursor.chain, entry.ordinal, entry.kind, entry.spec());
        if (!std.mem.eql(u8, &next.chain, &entry.chain)) return error.InvalidExchangeCoverage;
        if (entry.length > now.bytes -| next.bytes) return error.InvalidExchangeCoverage;
        next.bytes += entry.length;
        next.next_member += 1;
        if (next.next_member == now.segments) {
            if (next.bytes != now.bytes or !std.mem.eql(u8, &next.chain, &now.chain)) return error.InvalidExchangeCoverage;
            return .{ .kind = entry.kind, .bytes = part.bytes, .next = null };
        }
    }
    return .{ .kind = entry.kind, .bytes = part.bytes, .next = next };
}
