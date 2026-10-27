//! Manual-placement source exchanges under one authority. Admission copies one
//! immutable segment into receiver-owned storage before acknowledging it. A
//! separate cursor consumes rows into an ordered durable index and returns
//! credits. Every entry point requires the bound source adapter's current rights.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const x = f.RelationalExchange;
const r = q.RelationalExchangeRecords;
const s = q.station;
const Pub = s.Publication;
const Ref = s.PublicationReference;
const Turn = s.Turn;
pub const Advance = enum { progress, accepted, duplicate, blocked, complete };
pub const resident_bytes = 3 * x.fixed_bytes + 2 * @sizeOf(x.Segment) + 8 * 256;
fn memory(allocator: std.mem.Allocator, bound: f.Relational.Bound) !q.QueryMemory {
    if (bound.plan.budgets.resident_bytes <= resident_bytes or bound.plan.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
    return .{ .parent = allocator, .limit = @intCast(bound.plan.budgets.resident_bytes - resident_bytes) };
}

// Conservative logical retention accounting includes keys, control records,
// publication descriptors and all four possible row-index entries. Provider
// page/journal amplification has its separate deployment quota.
fn segmentCharge(spec: Pub.Spec) u64 {
    const publication_key = Pub.key(.query_exchange, 1, 'r', 1, 0).len;
    return @as(u64, spec.length) + 180 + 29 + x.max_rows * (109 + 33) + 104 + (@as(u64, spec.chunks()) + 1) * publication_key;
}

pub fn head(reader: anytype, id: u64) !r.Head {
    const value = try r.Head.decode((try reader.read(try r.key('h', id, 0, 0, 0))) orelse return error.QueryNotFound);
    if (value.id != id or value.resource != reader.view.resource) return error.InvalidRelationalExchange;
    return value;
}
fn check(turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64) !r.Head {
    const stored = try head(turn, id);
    if (stored.owner != turn.delivery.pid or stored.closed) return error.RelationalExchangeClosed;
    if (!std.mem.eql(u8, &stored.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
    try sources.validate(bound);
    return stored;
}
pub fn create(turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64, partitions: u64, limits: r.Limits) !r.Head {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try bound.validate();
    try sources.validate(bound);
    if (bound.plan.lifetime == .interactive) return error.InvalidRelationalExchange;
    if (bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (limits.retained_bytes > bound.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
    var stored: r.Head = .{ .id = id, .owner = turn.delivery.pid, .resource = turn.view.resource, .binding = try bound.fingerprint(), .partitions = partitions, .sources = @intCast(bound.plan.sources.len), .limits = limits };
    stored.retained_bytes = (try stored.encode()).len + (try stored.address()).len + 32 + Pub.key(.query_exchange, id, 'b', 0, 0).len + 125 + 29;
    try stored.validate();
    if (try turn.read(try stored.address()) != null or try turn.read(Pub.key(.query_exchange, id, 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    _ = try Pub.create(turn, .query_exchange, id, .{ .record_bytes = x.max_bytes, .staging_bytes = x.max_bytes, .staging_records = 1 });
    try turn.write(try stored.address(), try stored.encode());
    return stored;
}
/// Register exactly the next source/partition pair. A caller can page the
/// registry; the resident API never allocates a total-partition list. Each
/// logical producer PID and resource remains fixed across physical replacement.
pub fn register(turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64, producer: u64, resource: u64) !void {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    var stored = try check(turn, bound, sources, id);
    if (stored.registered == try stored.total()) return error.InvalidRelationalExchange;
    const source: u8 = @intCast(stored.registered % stored.sources);
    const partition = stored.registered / stored.sources;
    const address = try r.key('c', id, source, partition, 0);
    if (try turn.read(address) != null) return error.InvalidRelationalExchange;
    // A shared native resource is valid, but its publication namespace cannot
    // simultaneously be used as producer staging and receiver staging.
    if (resource == stored.resource) return error.InvalidRelationalExchange;
    if (107 + 29 > stored.limits.retained_bytes - stored.retained_bytes) return error.RelationalSpillBudget;
    try turn.write(address, try (r.Channel{ .producer = producer, .resource = resource }).encode());
    stored.registered += 1;
    stored.retained_bytes += 107 + 29;
    try turn.write(try stored.address(), try stored.encode());
}
fn channel(reader: anytype, stored: r.Head, source: u8, partition: u64) !r.Channel {
    if (source >= stored.sources or partition >= stored.partitions) return error.InvalidRelationalExchange;
    return r.Channel.decode((try reader.read(try r.key('c', stored.id, source, partition, 0))) orelse return error.RelationalExchangePending);
}
pub fn createProducer(turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64, receiver: r.Receiver, quota: u64) !Pub {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try bound.validate();
    try sources.validate(bound);
    if (bound.plan.lifetime == .interactive or id == 0) return error.InvalidRelationalExchange;
    if (bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    if (quota > bound.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
    const address = try r.key('b', id, 0, 0, 0);
    if (try turn.read(address) != null or try turn.read(Pub.key(.query_exchange, id, 'b', 0, 0)) != null) return error.QueryNamespaceInUse;
    const stored: r.Producer = .{ .id = id, .owner = turn.delivery.pid, .resource = turn.view.resource, .binding = try bound.fingerprint(), .receiver = receiver, .limit = quota, .charged = r.Producer.base_bytes };
    try turn.write(address, try stored.encode());
    return Pub.create(turn, .query_exchange, id, .{ .record_bytes = x.max_bytes, .staging_bytes = x.max_bytes, .staging_records = 1 });
}
/// Read the original producer and destination even on duplicates and control
/// acknowledgements. A caller cannot redirect an already eligible segment.
pub fn producerState(turn: *Turn, bound: f.Relational.Bound, id: u64) !r.Producer {
    const value = try r.Producer.decode((try turn.read(try r.key('b', id, 0, 0, 0))) orelse return error.InvalidRelationalExchange);
    if (value.owner != turn.delivery.pid or value.resource != turn.view.resource or value.id != id or !std.mem.eql(u8, &value.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
    return value;
}
/// The producer stages exact FXS1 bytes first, then atomically records eligibility
/// and sends the receiver's identified notice. It must keep the publication
/// readable until durable acceptance; retirement after acceptance is safe.
pub fn offer(allocator: std.mem.Allocator, turn: *Turn, bound: f.Relational.Bound, sources: anytype, segment: x.Segment, publication: Pub, record: u64) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try sources.validate(bound);
    if (publication.domain != .query_exchange or publication.namespace != segment.exchange or publication.resource != turn.view.resource) return error.InvalidRelationalExchange;
    const budget_key = try r.key('b', segment.exchange, 0, 0, 0);
    var budget = try producerState(turn, bound, segment.exchange);
    const receiver = budget.receiver.owner;
    var budget_memory = try memory(allocator, bound);
    // Input rows are borrowed from the producer. Account their live payloads
    // alongside this operation's encoded candidate.
    var input_bytes: usize = 0;
    for (segment.rows[0..segment.len]) |row| input_bytes = try std.math.add(usize, input_bytes, try f.RelationalValues.payloadLength(&row.values));
    if (input_bytes > budget_memory.limit) return error.RelationalResidentBudget;
    budget_memory.limit -= input_bytes;
    const owned = budget_memory.allocator();
    const body = try segment.encodeAlloc(owned, bound);
    defer owned.free(body);
    const reference: Ref = .{ .resource = publication.resource, .domain = publication.domain, .namespace = publication.namespace, .record = record, .spec = try Pub.Digest.of(r.segment_format, body) };
    const notice: r.Pending = .{ .source = segment.source, .partition = segment.partition, .sequence = segment.sequence, .remote = reference };
    const address = try r.key('p', segment.exchange, segment.source, segment.partition, segment.sequence);
    if (try turn.read(address)) |old| {
        if (!old.eql(try notice.encode())) return error.RelationalExchangeConflict;
        try turn.cast(receiver, try notice.encode());
        return .duplicate;
    }
    if (budget.pending) |pending| {
        if (!std.meta.eql(pending, reference)) {
            if (pending.record == reference.record) return error.RelationalExchangeConflict;
            return .blocked;
        }
    } else {
        if (reference.record <= budget.last) return error.RelationalExchangeConflict;
        const charge = r.Producer.charge(reference.spec);
        if (charge > budget.limit - budget.charged) return error.RelationalSpillBudget;
        budget.charged += charge;
        budget.pending = reference;
        try turn.write(budget_key, try budget.encode());
        return .progress;
    }
    if (!try publication.stage(turn, record, reference.spec, body)) return .progress;
    // Do not expose a ledger entry/outbox until private staging is fully
    // committed; final publication can already use the turn's mutation budget.
    for (turn.decision.mutations) |mutation| if (mutation != null) return .progress;
    budget.pending = null;
    budget.last = record;
    try turn.write(budget_key, try budget.encode());
    try turn.write(address, try notice.encode());
    try turn.cast(receiver, try notice.encode());
    return .accepted;
}
fn accepted(reader: anytype, stored: r.Head, notice: r.Pending) !?r.Accepted {
    const value = (try reader.read(try r.key('a', stored.id, notice.source, notice.partition, notice.sequence))) orelse return null;
    const result = try r.Accepted.decode(value);
    if (!std.meta.eql(result.remote, notice.remote)) return error.RelationalExchangeConflict;
    if (result.local.resource != stored.resource or result.local.domain != .query_exchange or result.local.namespace != stored.id) return error.InvalidRelationalExchange;
    return result;
}
fn acknowledge(turn: *Turn, producer: u64, notice: r.Pending) !void {
    // Same immutable identity means durable acceptance, never consumption or
    // renewed credit. Credit state is read from the receiver's head separately.
    try turn.cast(producer, try notice.encode());
}
/// Authenticated producer notice only. A duplicate uses the receiver's retained
/// accepted copy even if the producer has since retired its original bytes.
pub fn receive(turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64, notice: r.Pending) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    var stored = try check(turn, bound, sources, id);
    const route = try channel(turn, stored, notice.source, notice.partition);
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (try s.Frame.source(turn.delivery.input) != route.producer or frame.kind != .cast or !frame.payload.eql(try notice.encode())) return error.UnexpectedQueryPublisher;
    if (notice.remote.resource != route.resource or notice.remote.domain != .query_exchange or notice.remote.namespace != id) return error.InvalidRelationalExchange;
    if (try accepted(turn, stored, notice) != null) {
        try acknowledge(turn, route.producer, notice);
        return .duplicate;
    }
    if (stored.pending) {
        const pending = try r.Pending.decode((try turn.read(try r.key('s', id, 0, 0, 0))) orelse return error.InvalidRelationalExchange);
        if (std.meta.eql(pending, notice)) return .progress;
        if (pending.source == notice.source and pending.partition == notice.partition and pending.sequence == notice.sequence) return error.RelationalExchangeConflict;
        return .blocked;
    }
    if (route.complete or (route.terminal != r.none and notice.sequence > route.terminal)) return error.RelationalExchangeConflict;
    // Reordered notices are retryable, not accepted across a gap. Otherwise
    // future packets from several channels could consume all global credit
    // and deadlock the missing earliest packets. Accepted backlog is contiguous.
    if (notice.sequence < route.consumed) return error.RelationalExchangeConflict;
    if (notice.sequence != route.accepted) return .blocked;
    if (segmentCharge(notice.remote.spec) > stored.limits.retained_bytes - stored.retained_bytes) return error.RelationalSpillBudget;
    if (notice.remote.spec.length > stored.limits.credit_bytes) return error.RelationalExchangeCreditBudget;
    if (stored.inflight_segments == stored.limits.credit_segments or notice.remote.spec.length > stored.limits.credit_bytes - stored.inflight_bytes) return .blocked;
    // Reserve the cumulative charge before staging. Concurrent registration
    // must not consume the space promised to this already reserved segment.
    stored.retained_bytes += segmentCharge(notice.remote.spec);
    stored.pending = true;
    try turn.write(try r.key('s', id, 0, 0, 0), try notice.encode());
    try turn.write(try stored.address(), try stored.encode());
    return .progress;
}
/// Continue one reserved segment. The caller supplies a fresh turn with the
/// producer resource registered. Its ledger proves the segment was eligible
/// before any fence; physical epoch changes cannot discard accepted late work.
pub fn advance(allocator: std.mem.Allocator, turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    var stored = try check(turn, bound, sources, id);
    if (!stored.pending) return .blocked;
    const pending_key = try r.key('s', id, 0, 0, 0);
    const notice = try r.Pending.decode((try turn.read(pending_key)) orelse return error.InvalidRelationalExchange);
    var route = try channel(turn, stored, notice.source, notice.partition);
    var producer = try turn.captured(route.resource);
    const sender = try r.Producer.decode((try producer.read(try r.key('b', id, 0, 0, 0))) orelse return error.RelationalExchangePending);
    if (sender.id != id or sender.owner != route.producer or sender.resource != route.resource or sender.receiver.owner != stored.owner or sender.receiver.resource != stored.resource or
        !std.mem.eql(u8, &sender.binding, &stored.binding)) return error.RelationalExchangeConflict;
    const eligible = (try producer.read(try r.key('p', id, notice.source, notice.partition, notice.sequence))) orelse return error.RelationalExchangePending;
    if (!eligible.eql(try notice.encode())) return error.RelationalExchangeConflict;
    const descriptor = try notice.remote.publication().inspect(&producer, notice.remote.record);
    if (descriptor.publisher != route.producer) return error.UnexpectedQueryPublisher;
    var budget_memory = try memory(allocator, bound);
    const owned = budget_memory.allocator();
    const body = try q.RelationalMaintenance.readBodyAlloc(owned, notice.remote, &producer, x.max_bytes);
    defer owned.free(body);
    var segment = try x.Segment.decode(owned, bound, body);
    defer segment.deinit();
    if (segment.exchange != id or segment.source != notice.source or segment.partition != notice.partition or segment.sequence != notice.sequence or segment.partitions != stored.partitions) return error.RelationalExchangeConflict;
    if (route.complete or (route.terminal != r.none and segment.sequence > route.terminal) or (segment.terminal and (route.highest > segment.sequence + 1 or (route.terminal != r.none and route.terminal != segment.sequence)))) return error.RelationalExchangeConflict;
    try producer.requireCurrent();
    if (!try stored.publication().stage(turn, stored.next_record, notice.remote.spec, body)) return .progress;
    for (turn.decision.mutations) |mutation| if (mutation != null) return .progress;
    const local: Ref = .{ .resource = stored.resource, .domain = .query_exchange, .namespace = id, .record = stored.next_record, .spec = notice.remote.spec };
    stored.next_record = std.math.add(u64, stored.next_record, 1) catch return error.RelationalSpillBudget;
    stored.inflight_bytes += local.spec.length;
    stored.inflight_segments += 1;
    stored.pending = false;
    route.accepted += 1;
    route.highest = @max(route.highest, segment.sequence + 1);
    if (segment.terminal) route.terminal = segment.sequence;
    try turn.write(try r.key('a', id, notice.source, notice.partition, notice.sequence), try (r.Accepted{ .remote = notice.remote, .local = local }).encode());
    try turn.write(try r.key('c', id, notice.source, notice.partition, 0), try route.encode());
    try turn.write(pending_key, null);
    try turn.write(try stored.address(), try stored.encode());
    try acknowledge(turn, route.producer, notice);
    return .accepted;
}
/// One stable row, or one empty/finished segment, per native turn. No credit is
/// released until every row of that segment is durably indexed. Output execution
/// is gated by terminal consumption from every explicitly registered partition.
pub fn consume(allocator: std.mem.Allocator, turn: *Turn, bound: f.Relational.Bound, sources: anytype, id: u64, source: u8, partition: u64) !Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    var stored = try check(turn, bound, sources, id);
    var route = try channel(turn, stored, source, partition);
    if (route.complete) return .complete;
    const value = (try turn.read(try r.key('a', id, source, partition, route.consumed))) orelse return .blocked;
    const receipt = try r.Accepted.decode(value);
    var budget_memory = try memory(allocator, bound);
    const owned = budget_memory.allocator();
    const body = try q.RelationalMaintenance.readBodyAlloc(owned, receipt.local, turn, x.max_bytes);
    defer owned.free(body);
    var segment = try x.Segment.decode(owned, bound, body);
    defer segment.deinit();
    if (segment.exchange != id or segment.source != source or segment.partition != partition or segment.sequence != route.consumed or segment.partitions != stored.partitions or route.row > segment.len) return error.InvalidRelationalExchange;
    if (route.row < segment.len) {
        const row = segment.rows[route.row];
        if (route.last) |last| if (f.RelationalExecution.identityOrder(last, row.identity) != .lt) return error.InvalidRelationalSourceOrder;
        const address = try r.rowKey(id, source, row.identity);
        if (try turn.read(address) != null) return error.RelationalExchangeConflict;
        try turn.write(address, try (r.Row{ .segment = receipt.local, .ordinal = route.row }).encode());
        route.row += 1;
        route.last = row.identity;
    }
    if (route.row == segment.len) {
        route.row = 0;
        route.consumed += 1;
        if (segment.terminal) {
            if (route.consumed != route.accepted) return error.InvalidRelationalExchange;
            route.complete = true;
            stored.completed += 1;
        }
        if (stored.inflight_segments == 0 or stored.inflight_bytes < receipt.local.spec.length) return error.InvalidRelationalExchange;
        stored.inflight_segments -= 1;
        stored.inflight_bytes -= receipt.local.spec.length;
        try turn.write(try stored.address(), try stored.encode());
    }
    try turn.write(try r.key('c', id, source, partition, 0), try route.encode());
    return if (route.complete) .complete else .progress;
}
/// Fresh own-resource closure remains available after source revocation and
/// pressure. It retires execution without deleting accepted work or its audit.
pub fn close(turn: *Turn, id: u64) !void {
    var stored = try head(turn, id);
    if (stored.owner != turn.delivery.pid) return error.InvalidRelationalExchange;
    stored.closed = true;
    try turn.write(try stored.address(), try stored.encode());
}
/// The finite executor reads the same stable source order for every physical
/// partition/layout/batch schedule. This adapter uses one native index page and
/// one bounded segment, not an all-partitions merge array or partial SUM.
pub fn Sources(comptime Reader: type, comptime Authority: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        reader: Reader,
        authority: Authority,
        id: u64,
        bound: f.Relational.Bound,
        pub fn validate(self: *Self, expected: f.Relational.Bound) !void {
            if (!std.mem.eql(u8, &try self.bound.fingerprint(), &try expected.fingerprint())) return error.RelationalSourceChanged;
            try self.authority.validate(expected);
            const stored = try head(self.reader, self.id);
            if (stored.closed) return error.RelationalExchangeClosed;
            if (!std.mem.eql(u8, &stored.binding, &try expected.fingerprint())) return error.RelationalSourceChanged;
            if (stored.pending or stored.completed != try stored.total() or stored.inflight_segments != 0) return error.RelationalExchangePending;
        }
        pub fn next(self: *Self, source: u8, after: ?f.Relational.RowIdentity) !?f.RelationalExecution.Row {
            try self.validate(self.bound);
            if (source >= self.bound.plan.sources.len) return error.InvalidRelationalSources;
            const prefix = try r.rowKey(self.id, source, null);
            const page = try self.reader.page(try r.rowKey(self.id, source, after));
            const first = page.entries[0] orelse return null;
            if (first.key.len != 32 or !std.mem.eql(u8, first.key.data[0..12], prefix.data[0..12])) return null;
            const index = try r.Row.decode(first.value);
            if (index.segment.spec.length > x.max_bytes) return error.InvalidRelationalExchange;
            const bytes = try self.allocator.alloc(u8, index.segment.spec.length);
            defer self.allocator.free(bytes);
            var segment = try x.Segment.decode(self.allocator, self.bound, try q.RelationalMaintenance.readBody(index.segment, self.reader, bytes));
            defer segment.deinit();
            if (segment.exchange != self.id or segment.source != source or index.ordinal >= segment.len) return error.InvalidRelationalExchange;
            const row = segment.rows[index.ordinal];
            if (!first.key.eql(try r.rowKey(self.id, source, row.identity))) return error.InvalidRelationalExchange;
            if (after) |id| if (f.RelationalExecution.identityOrder(id, row.identity) != .lt) return error.InvalidRelationalSourceOrder;
            try self.authority.validate(self.bound);
            // Move only the selected row; release the remaining decoded rows.
            segment.rows[index.ordinal].buffer = .{};
            return row;
        }
    };
}

test {
    _ = @import("relational_exchange_test.zig");
}
