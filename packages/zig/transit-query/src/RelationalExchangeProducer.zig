//! Recoverable bounded source scanning for explicit query worker placement.
//! Logical channel assignment is immutable; physical ownership stays native.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const s = q.station;
const r = q.RelationalExchangeRecords;
const x = q.RelationalExchange;
const codec = f.RelationalExchange;
pub const scan_rows = 8;
pub const Options = struct { receiver: r.Receiver, partitions: u64, workers: u64, worker: u64, batch: u8, epoch: u64, quota: u64 };
pub const Cursor = struct {
    id: u64,
    binding: [32]u8,
    partitions: u64,
    workers: u64,
    worker: u64,
    channel: u64,
    sequence: u64 = 0,
    epoch: u64,
    record: u64 = 1,
    steps: u64 = 0,
    batch: u8,
    after: ?f.Relational.RowIdentity = null,
    const fields = .{ "id", "partitions", "workers", "worker", "channel", "sequence", "epoch", "record", "steps" };
    pub fn total(self: Cursor, bound: f.Relational.Bound) !u64 {
        return std.math.mul(u64, self.partitions, bound.plan.sources.len) catch error.InvalidRelationalExchange;
    }
    pub fn validate(self: Cursor, bound: f.Relational.Bound) !void {
        try bound.validate();
        if (!std.mem.eql(u8, &self.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
        if (bound.plan.lifetime == .interactive or self.id == 0 or self.partitions == 0 or self.workers == 0 or self.worker >= self.workers or self.epoch == 0 or self.record == 0 or self.sequence == r.none or self.batch == 0 or self.batch > codec.max_rows) return error.InvalidRelationalExchange;
        const count = try self.total(bound);
        if (self.channel > count or (self.channel != count and self.channel % self.workers != self.worker) or
            (self.channel == count and (self.after != null or self.sequence != 0)) or self.steps > bound.plan.budgets.work_steps) return error.InvalidRelationalExchange;
        if (self.after) |identity| try identity.validate();
    }
    pub fn address(self: Cursor) !q.protocol.Value {
        return r.key('w', self.id, 0, 0, 0);
    }
    pub fn encode(self: Cursor, bound: f.Relational.Bound) !q.protocol.Value {
        try self.validate(bound);
        var bytes: [162]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("RXW1");
        try writer.writeAll(&codec.definition());
        try writer.writeAll(&self.binding);
        inline for (fields) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeByte(self.batch);
        try writer.writeByte(@intFromBool(self.after != null));
        var identity: [20]u8 = @splat(0);
        if (self.after) |value| codec.identityBytes(value, &identity);
        try writer.writeAll(&identity);
        return q.protocol.Value.init(writer.buffered());
    }
    pub fn decode(value: q.protocol.Value, bound: f.Relational.Bound) !Cursor {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "RXW1")) return error.InvalidRelationalExchange;
        if (!std.mem.eql(u8, try reader.take(32), &codec.definition())) return error.IncompatibleDefinition;
        var result: Cursor = undefined;
        result.binding = (try reader.takeArray(32)).*;
        inline for (fields) |field| @field(result, field) = try reader.takeInt(u64, .little);
        result.batch = try reader.takeByte();
        const present = try reader.takeByte();
        const identity: f.Relational.RowIdentity = .{ .origin = try reader.takeInt(u64, .big), .operation = try reader.takeInt(u64, .big), .ordinal = try reader.takeInt(u32, .big) };
        if (present > 1 or (present == 0 and (identity.origin != 0 or identity.operation != 0 or identity.ordinal != 0)) or reader.bufferedLen() != 0) return error.InvalidRelationalExchange;
        result.after = if (present == 1) identity else null;
        try result.validate(bound);
        return result;
    }
};
pub fn cursor(reader: anytype, bound: f.Relational.Bound, id: u64) !Cursor {
    const value = try Cursor.decode((try reader.read(try r.key('w', id, 0, 0, 0))) orelse return error.QueryNotFound, bound);
    if (value.id != id) return error.InvalidRelationalExchange;
    return value;
}
pub fn create(turn: *s.Turn, bound: f.Relational.Bound, sources: anytype, id: u64, options: Options) !void {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    const count = std.math.mul(u64, options.partitions, bound.plan.sources.len) catch return error.InvalidRelationalExchange;
    const value: Cursor = .{ .id = id, .binding = try bound.fingerprint(), .partitions = options.partitions, .workers = options.workers, .worker = options.worker, .channel = @min(options.worker, count), .epoch = options.epoch, .batch = options.batch };
    const encoded = try value.encode(bound);
    _ = try x.createProducer(turn, bound, sources, id, options.receiver, options.quota);
    const budget_key = try r.key('b', id, 0, 0, 0);
    var budget = try r.Producer.decode((try turn.read(budget_key)).?);
    const charge = @as(u64, encoded.len) + (try value.address()).len;
    if (charge > budget.limit - budget.charged) return error.RelationalSpillBudget;
    budget.charged += charge;
    try turn.write(budget_key, try budget.encode());
    try turn.write(try value.address(), encoded);
}
/// Each attempt reconstructs at most eight source rows and one <=4-row segment.
/// While publication is private, the accepted scan cursor stays unchanged, so
/// a new worker reconstructs exactly the same body and physical-plan epoch.
/// Assignment is channel % workers; source = channel % source_count.
pub fn step(allocator: std.mem.Allocator, turn: *s.Turn, bound: f.Relational.Bound, sources: anytype, id: u64) !x.Advance {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try sources.validate(bound);
    var stored = try cursor(turn, bound, id);
    const count = try stored.total(bound);
    if (stored.channel == count) return .complete;
    const source: u8 = @intCast(stored.channel % bound.plan.sources.len);
    const partition = stored.channel / bound.plan.sources.len;
    var segment: codec.Segment = .{ .exchange = id, .source = source, .partitions = stored.partitions, .partition = partition, .epoch = stored.epoch, .sequence = stored.sequence, .terminal = false };
    defer segment.deinit();
    for (0..scan_rows) |_| {
        if (stored.steps == bound.plan.budgets.work_steps) return error.RelationalWorkBudget;
        stored.steps += 1;
        var row = (try sources.next(source, stored.after)) orelse {
            segment.terminal = true;
            break;
        };
        defer row.deinit();
        if (stored.after) |after| if (f.RelationalExecution.identityOrder(after, row.identity) != .lt) return error.InvalidRelationalSourceOrder;
        stored.after = row.identity;
        if (try codec.route(bound.plan, source, stored.partitions, row) != partition) continue;
        segment.rows[segment.len] = row;
        segment.len += 1;
        row.buffer = .{};
        if (segment.len == stored.batch) break;
    }
    if (segment.len == 0 and !segment.terminal) {
        try turn.write(try stored.address(), try stored.encode(bound));
        return .progress;
    }
    const publication: s.Publication = .{ .resource = turn.view.resource, .domain = .query_exchange, .namespace = id };
    const outcome = try x.offer(allocator, turn, bound, sources, segment, publication, stored.record);
    if (outcome != .accepted and outcome != .duplicate) return outcome;
    stored.record = std.math.add(u64, stored.record, 1) catch return error.RelationalSpillBudget;
    if (segment.terminal) {
        stored.channel = if (count - stored.channel <= stored.workers) count else stored.channel + stored.workers;
        stored.sequence = 0;
        stored.after = null;
    } else stored.sequence = std.math.add(u64, stored.sequence, 1) catch return error.RelationalWorkBudget;
    try turn.write(try stored.address(), try stored.encode(bound));
    return .accepted;
}
/// Exact retry from the eligibility ledger, without rereading retired producer
/// chunks. The saved producer fixes the destination; placement cannot redirect
/// previously accepted output to another logical PID.
pub fn retry(turn: *s.Turn, bound: f.Relational.Bound, sources: anytype, id: u64, notice: r.Pending) !void {
    try sources.validate(bound);
    _ = try cursor(turn, bound, id);
    if (notice.remote.resource != turn.view.resource or notice.remote.namespace != id) return error.InvalidRelationalExchange;
    const recorded = (try turn.read(try r.key('p', id, notice.source, notice.partition, notice.sequence))) orelse return error.RelationalExchangePending;
    if (!recorded.eql(try notice.encode())) return error.RelationalExchangeConflict;
    try turn.cast((try x.producerState(turn, bound, id)).receiver.owner, try notice.encode());
}
/// Own-resource acknowledgement handling remains possible after source denial.
/// It grants no disclosure right, returns no credit and erases no source bytes.
pub fn acknowledge(turn: *s.Turn, bound: f.Relational.Bound, id: u64, notice: r.Pending) !void {
    _ = try cursor(turn, bound, id);
    if (try s.Frame.source(turn.delivery.input) != (try x.producerState(turn, bound, id)).receiver.owner) return error.UnexpectedQueryPublisher;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast or !frame.payload.eql(try notice.encode())) return error.InvalidRelationalExchange;
    const original = (try turn.read(try r.key('p', id, notice.source, notice.partition, notice.sequence))) orelse return error.RelationalExchangePending;
    if (!original.eql(try notice.encode())) return error.RelationalExchangeConflict;
    const address = try r.key('k', id, notice.source, notice.partition, notice.sequence);
    if (try turn.read(address)) |previous| {
        if (!previous.eql(original)) return error.RelationalExchangeConflict;
        return;
    }
    try turn.write(address, original);
}

test {
    _ = @import("relational_exchange_producer_test.zig");
}
