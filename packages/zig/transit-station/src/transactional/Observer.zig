//! Trusted timer observer over a declared Timer Queue (`visible_ms = deadline_ms`).
//! Eliminates 100 ms O(keys) KV page scans across idle actors and supervisors while
//! verifying authoritative Queue clock bounds and native process liveness.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const g = p.Growth;
const Actor = @import("Actor.zig");
const Runner = @import("Runner.zig");
const Envelope = @import("Envelope.zig");
const Timer = @import("Timer.zig");
const Self = @This();

pub const resident_bytes = 16 * 1024 * 1024;

pub const ProcessState = struct {
    pid: u64,
    lifecycle: @FieldType(g.Process, "lifecycle"),
    generation: u64,
    failure: ?u64 = null,
    position: u64 = 0,
};

pub const ProcessView = struct {
    context: *anyopaque,
    inspect: *const fn (*anyopaque, u64) anyerror!ProcessState,
};

pub const NativeInspector = struct {
    client: *c.client.Client,
    realm: u64,
    principal: u64,
    key: p.Ed25519.KeyPair,

    pub fn view(self: *NativeInspector) ProcessView {
        return .{ .context = self, .inspect = inspectProcess };
    }

    fn inspectProcess(raw: *anyopaque, pid: u64) !ProcessState {
        const self: *NativeInspector = @ptrCast(@alignCast(raw));
        const response = try self.client.query(.{
            .realm = self.realm,
            .principal = self.principal,
            .kind = .{ .process = pid },
        }, self.key);
        const proc = response.body.process.process;
        if (proc.pid != pid) return error.InvalidAuthorityResponse;
        return .{
            .pid = proc.pid,
            .lifecycle = proc.lifecycle,
            .generation = proc.generation,
            .failure = proc.failure,
            .position = response.position,
        };
    }
};

pub const BackoffBuilder = struct {
    context: *anyopaque,
    build: *const fn (*anyopaque, std.mem.Allocator, Timer.Ticket, ProcessState, u64) anyerror!?[]const u8,
};

pub const Result = enum { idle, delivered, settled_obsolete };
pub const Point = enum { claimed, verified_clock, enqueued, acked };
pub const Hook = struct {
    context: *anyopaque,
    hit: *const fn (*anyopaque, Point) anyerror!void,
};

parent: std.mem.Allocator,
memory: *c.fuze.MemoryBudget,
output: std.heap.ArenaAllocator,
scratch: std.heap.ArenaAllocator,
client: c.DirectTableClient,
observed_epoch: ?u64 = null,
timers: p.StreamQueue.Partition,
predicate: ?p.QueuePredicate,
lease_ms: u64,
process_view: ProcessView,
backoff_builder: ?BackoffBuilder = null,
hook: ?Hook = null,
seed: [32]u8,
next_claim_seq: u64 = 1,

pub fn init(
    parent: std.mem.Allocator,
    client: c.DirectTableClient,
    timers: p.StreamQueue.Partition,
    predicate: ?p.QueuePredicate,
    lease_ms: u64,
    instance: u64,
    process_view: ProcessView,
) !Self {
    try client.connection.validate();
    try timers.validate();
    try client.connection.object(timers.interpretation.object);
    if (predicate) |pred| try pred.validate();
    if (lease_ms == 0 or instance == 0 or client.execution != null or client.delegation != null or
        client.borrow != null or client.closure != null or client.transaction != null)
        return error.InvalidTimerObserver;
    const memory = try parent.create(c.fuze.MemoryBudget);
    errdefer parent.destroy(memory);
    memory.* = .{ .parent = parent, .limit = resident_bytes };
    var guarded = client;
    guarded.allocator = memory.allocator();
    const seed = try p.Json.hashBounded("transit.station.private.observer.v1\x00", .{
        .principal = client.connection.principal,
        .timers = timers,
        .lease_ms = lease_ms,
        .instance = instance,
    }, 4096);
    return .{
        .parent = parent,
        .memory = memory,
        .output = .init(memory.allocator()),
        .scratch = .init(memory.allocator()),
        .client = guarded,
        .observed_epoch = client.credential_epoch,
        .timers = timers,
        .predicate = predicate,
        .lease_ms = lease_ms,
        .process_view = process_view,
        .seed = seed,
    };
}

pub fn deinit(self: *Self) void {
    self.output.deinit();
    self.scratch.deinit();
    self.parent.destroy(self.memory);
    self.* = undefined;
}

fn tableClient(self: *Self) c.DirectTableClient {
    var caller = self.client;
    if (caller.credential_epoch == null) caller.observed_epoch = &self.observed_epoch;
    return caller;
}

fn reset(self: *Self) void {
    _ = self.output.reset(.retain_capacity);
    _ = self.scratch.reset(.retain_capacity);
}

fn point(self: *Self, value: Point) !void {
    if (self.hook) |hook| try hook.hit(hook.context, value);
}

pub fn ticketDeliverOperation(connection: c.DirectTableProtocol.Connection, source: p.StreamQueue.RecordIdentity, generation: u64, cut: u64) !d.Operation {
    const digest = try p.Json.hashBounded("transit.station.private.observer.deliver.v1\x00", .{
        .source = source,
        .generation = generation,
        .cut = cut,
    }, 4096);
    return Actor.operation(connection, digest, 1, "deliver", source.ordinal);
}

pub fn ticketAckOperation(connection: c.DirectTableProtocol.Connection, source: p.StreamQueue.RecordIdentity, lease_epoch: u64) !d.Operation {
    const digest = try p.Json.hashBounded("transit.station.private.observer.ack.v1\x00", source, 4096);
    return Actor.operation(connection, digest, lease_epoch, "ack", source.ordinal);
}

fn applyQueue(output: *std.heap.ArenaAllocator, caller: c.DirectTableClient, action: c.DirectQueueClient.Action) !c.DirectQueueClient.Result {
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return c.DirectQueueClient.apply(output, caller, action) catch |err| {
            if (err != error.AuthorityUnavailable) return err;
            last_err = err;
            continue;
        };
    }
    return last_err;
}

pub fn step(self: *Self, wait_ms: ?u32) !Result {
    self.reset();
    if (wait_ms) |ms| if (ms == 0 or ms > c.client.WaitHint.max_ms) return error.InvalidQueueWait;
    const claim_seq = self.next_claim_seq;
    self.next_claim_seq = try std.math.add(u64, self.next_claim_seq, 1);
    const claim_req: p.StreamQueue.Claim = .{
        .target = self.timers,
        .operation = Actor.operation(self.client.connection, self.seed, claim_seq, "timer-claim", 0),
        .maximum = 1,
        .lease_ms = self.lease_ms,
        .predicate = self.predicate,
    };
    const caller = self.tableClient();
    const claim_receipt = blk: {
        if (wait_ms) |ms| {
            const waited = try applyQueue(&self.output, caller, .{ .wait = .{ .claim = claim_req, .milliseconds = ms } });
            switch (waited) {
                .timed_out => return .idle,
                .operation => |maybe_op| {
                    const found = maybe_op orelse return error.ObserverProgressUnresolved;
                    if (found != .claim) return error.ObserverProgressUnresolved;
                    if (found.claim.rows == 0) return .idle;
                    break :blk found.claim;
                },
                else => return error.ObserverProgressUnresolved,
            }
        } else {
            const found = (try applyQueue(&self.output, caller, .{ .mutate = .{ .work = .{ .claim = claim_req } } })).operation orelse return error.ObserverProgressUnresolved;
            if (found != .claim) return error.ObserverProgressUnresolved;
            if (found.claim.rows == 0) return .idle;
            break :blk found.claim;
        }
    };
    try self.point(.claimed);

    const page = (try applyQueue(&self.output, caller, .{
        .page = .{ .cursor = .{ .receipt = claim_receipt, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = Timer.max_ticket_bytes + 4096 } },
    })).page;
    if (page.rows.len != 1 or !page.cursor.complete() or page.rows[0].lease.liveness != .live)
        return error.ObserverTicketUnavailable;
    const row = page.rows[0];
    if (row.value.cells.len != 2) return error.InvalidTimerTicket;
    const raw_ticket = if (row.value.cells[1] == .value and row.value.cells[1].value == .atom and row.value.cells[1].value.atom == .bytes)
        row.value.cells[1].value.atom.bytes
    else
        return error.InvalidTimerTicket;

    const ticket = try Timer.Ticket.decode(self.output.allocator(), raw_ticket);
    if (ticket.observer != self.client.connection.principal) return error.UnexpectedObserverTicket;
    try self.client.connection.object(ticket.target_inbox.interpretation.object);

    const time_obs = (try applyQueue(&self.output, caller, .{ .current_time = self.timers })).current_time;
    try time_obs.validate();
    if (time_obs.time.earliest_ms < ticket.deadline_ms) return error.TimerNotYetDue;
    // Anchor the emitted evidence to the proven deadline milestone so crash
    // replay after lease expiry produces byte-identical LogBatch deduplication.
    const proven_ms = ticket.deadline_ms;
    try self.point(.verified_clock);

    const source: p.StreamQueue.RecordIdentity = .{
        .target = self.timers,
        .operation = row.operation,
        .ordinal = row.ordinal,
    };
    const proc = try self.process_view.inspect(self.process_view.context, ticket.target_pid);
    if (proc.pid != ticket.target_pid) return error.InvalidAuthorityResponse;
    if (proc.lifecycle == .terminated or proc.lifecycle == .expired) {
        try self.ackTicket(caller, source, row.lease.original);
        try self.point(.acked);
        return .settled_obsolete;
    }

    var tmo_buf: [Timer.observation_bytes]u8 = undefined;
    var deliver_gen: u64 = 0;
    var deliver_cut: u64 = 0;
    const maybe_env: ?Envelope = switch (ticket.kind) {
        .wait_timeout => blk: {
            tmo_buf = try (Timer.Observation{ .observed_ms = proven_ms }).encode();
            break :blk .{ .kind = .timeout, .correlation = ticket.correlation, .payload = &tmo_buf };
        },
        .supervisor_backoff => blk: {
            const builder = self.backoff_builder orelse return error.SupervisorBackoffHandlerMissing;
            deliver_gen = proc.generation;
            deliver_cut = proc.position;
            const sup_payload = (try builder.build(builder.context, self.output.allocator(), ticket, proc, proven_ms)) orelse break :blk null;
            break :blk .{ .kind = .cast, .correlation = 0, .payload = sup_payload };
        },
    };
    if (maybe_env == null) {
        try self.ackTicket(caller, source, row.lease.original);
        try self.point(.acked);
        return .settled_obsolete;
    }

    const encoded_env = try maybe_env.?.encodeAlloc(self.output.allocator());
    const deliver_op = try ticketDeliverOperation(self.client.connection, source, deliver_gen, deliver_cut);
    const cells = [_]c.fuze.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = @intCast(ticket.target_pid) } } },
        .{ .value = .{ .atom = .{ .bytes = encoded_env } } },
    };
    const batch_buf = try self.scratch.allocator().alloc(u8, encoded_env.len + 4096);
    defer _ = self.scratch.reset(.retain_capacity);
    const payload = try c.storage.LogBatch.encode(Runner.logSchema(ticket.target_inbox.interpretation.object.object), deliver_op, .queue, &.{.{ .cells = &cells }}, batch_buf);
    const append: p.StreamQueue.Append = .{
        .target = ticket.target_inbox,
        .operation = deliver_op,
        .kind = .queue,
        .producer = null,
        .rows = 1,
        .payload = c.storage.LogBatch.content(payload),
    };
    const appended = (try applyQueue(&self.output, caller, .{
        .mutate = .{ .work = .{ .enqueue = append }, .payload = payload },
    })).operation orelse return error.ObserverProgressUnresolved;
    if (appended != .enqueue) return error.ObserverProgressUnresolved;
    try self.point(.enqueued);

    try self.ackTicket(caller, source, row.lease.original);
    try self.point(.acked);
    return .delivered;
}

fn ackTicket(self: *Self, caller: c.DirectTableClient, source: p.StreamQueue.RecordIdentity, lease: p.StreamQueue.Lease) !void {
    const ack_op = try ticketAckOperation(self.client.connection, source, lease.epoch);
    const settled = (try applyQueue(&self.output, caller, .{
        .mutate = .{ .work = .{ .settle = .{ .operation = ack_op, .lease = lease, .action = .ack } } },
    })).operation orelse return error.ObserverProgressUnresolved;
    if (settled != .settle) return error.ObserverProgressUnresolved;
}

test "private transactional observer deterministic ticket operations bind record identity and lease epoch" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const conn: c.DirectTableProtocol.Connection = .{
        .scope = scope,
        .branch = 1,
        .audience = 4,
        .principal = 109,
        .role = null,
    };
    const part: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 12 }, .revision = 1, .digest = @splat(4) },
        .partition = 0,
    };
    const src_a: p.StreamQueue.RecordIdentity = .{
        .target = part,
        .operation = .{ .scope = scope, .principal = 101, .operation = 500 },
        .ordinal = 0,
    };
    const src_b: p.StreamQueue.RecordIdentity = .{
        .target = part,
        .operation = .{ .scope = scope, .principal = 101, .operation = 501 },
        .ordinal = 0,
    };
    try t.expectEqualDeep(try ticketDeliverOperation(conn, src_a, 0, 0), try ticketDeliverOperation(conn, src_a, 0, 0));
    try t.expect(!std.meta.eql(try ticketDeliverOperation(conn, src_a, 0, 0), try ticketDeliverOperation(conn, src_b, 0, 0)));
    try t.expectEqualDeep(try ticketAckOperation(conn, src_a, 1), try ticketAckOperation(conn, src_a, 1));
    try t.expect(!std.meta.eql(try ticketAckOperation(conn, src_a, 1), try ticketAckOperation(conn, src_a, 2)));
}
