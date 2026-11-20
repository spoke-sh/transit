//! Bounded multiplexed runner pool over a shared `key_fifo` inbox partition.
//! Idle durable actors hold zero resident `Runner` allocations, zero open
//! transactions and zero OS timers, waking via `QueueWait` (`1..1000 ms`).
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Actor = @import("Actor.zig");
const Runner = @import("Runner.zig");
const Self = @This();

pub const max_slots = 16;
pub const resident_bytes = 8 * 1024 * 1024;

pub const Binding = struct {
    actor: Actor.Declaration,
    activation: p.Transaction.Execution,
    handler: Runner.Handler,
};

pub const Resolver = struct {
    context: *anyopaque,
    resolve: *const fn (*anyopaque, std.mem.Allocator, u64) anyerror!?Binding,
};

pub const StepResult = enum { idle, progressed, committed, blocked };

const ActiveSlot = struct {
    pid: u64,
    handler: Runner.Handler,
    arena: std.heap.ArenaAllocator,
    runner: Runner,

    fn deinit(self: *ActiveSlot) void {
        self.runner.deinit();
        self.arena.deinit();
        self.* = undefined;
    }
};

parent: std.mem.Allocator,
memory: *c.fuze.MemoryBudget,
output: std.heap.ArenaAllocator,
client: c.DirectTableClient,
observed_epoch: ?u64 = null,
inbox: p.StreamQueue.Partition,
lease_ms: u64,
max_record_bytes: u32,
max_active_runners: usize,
resolver: Resolver,
slots: [max_slots]?ActiveSlot = @splat(null),
active_runners: usize = 0,
peak_active_runners: usize = 0,
completed_turns: u64 = 0,
seed: [32]u8,
next_claim_seq: u64 = 1,
cursor_slot: usize = 0,
stopped: bool = false,

pub fn init(
    parent: std.mem.Allocator,
    client: c.DirectTableClient,
    inbox: p.StreamQueue.Partition,
    lease_ms: u64,
    max_record_bytes: u32,
    max_active_runners: usize,
    instance: u64,
    resolver: Resolver,
) !Self {
    try client.connection.validate();
    try inbox.validate();
    try client.connection.object(inbox.interpretation.object);
    if (lease_ms == 0 or instance == 0 or max_record_bytes == 0 or max_active_runners == 0 or max_active_runners > max_slots or
        client.execution != null or client.delegation != null or client.borrow != null or
        client.closure != null or client.transaction != null)
        return error.InvalidActorPool;
    const memory = try parent.create(c.fuze.MemoryBudget);
    errdefer parent.destroy(memory);
    memory.* = .{ .parent = parent, .limit = resident_bytes };
    var guarded = client;
    guarded.allocator = memory.allocator();
    const seed = try p.Json.hashBounded("transit.station.private.pool.v1\x00", .{
        .principal = client.connection.principal,
        .inbox = inbox,
        .lease_ms = lease_ms,
        .instance = instance,
    }, 4096);
    return .{
        .parent = parent,
        .memory = memory,
        .output = .init(memory.allocator()),
        .client = guarded,
        .observed_epoch = client.credential_epoch,
        .inbox = inbox,
        .lease_ms = lease_ms,
        .max_record_bytes = max_record_bytes,
        .max_active_runners = max_active_runners,
        .resolver = resolver,
        .seed = seed,
    };
}

pub fn deinit(self: *Self) void {
    self.shutdown();
    self.output.deinit();
    self.parent.destroy(self.memory);
    self.* = undefined;
}

pub fn shutdown(self: *Self) void {
    for (&self.slots) |*maybe_slot| {
        if (maybe_slot.*) |*slot| {
            slot.deinit();
            maybe_slot.* = null;
        }
    }
    self.active_runners = 0;
    self.stopped = true;
}

pub fn activeCount(self: *const Self) usize {
    return self.active_runners;
}

fn tableClient(self: *Self) c.DirectTableClient {
    var caller = self.client;
    if (caller.credential_epoch == null) caller.observed_epoch = &self.observed_epoch;
    return caller;
}

fn findActorSlot(self: *const Self, pid: u64) ?usize {
    for (self.slots[0..self.max_active_runners], 0..) |maybe_slot, idx| {
        if (maybe_slot) |slot| if (slot.pid == pid) return idx;
    }
    return null;
}

fn findFreeSlot(self: *const Self) ?usize {
    for (self.slots[0..self.max_active_runners], 0..) |maybe_slot, idx| {
        if (maybe_slot == null) return idx;
    }
    return null;
}

fn releaseSlot(self: *Self, idx: usize) void {
    if (self.slots[idx]) |*slot| {
        slot.deinit();
        self.slots[idx] = null;
        self.active_runners -= 1;
    }
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

/// Claim at most one visible inbox item and bind an active `Runner` slot without
/// stepping the turn yet. Returns `false` if all slots are busy or no item is ready.
pub fn claimIntoSlot(self: *Self, wait_ms: ?u32) !bool {
    if (self.stopped) return error.PoolStopped;
    if (self.findFreeSlot() == null) return false;
    _ = self.output.reset(.retain_capacity);
    if (wait_ms) |ms| if (ms == 0 or ms > c.client.WaitHint.max_ms) return error.InvalidQueueWait;

    const claim_seq = self.next_claim_seq;
    self.next_claim_seq = try std.math.add(u64, self.next_claim_seq, 1);
    const claim_req: p.StreamQueue.Claim = .{
        .target = self.inbox,
        .operation = Actor.operation(self.client.connection, self.seed, claim_seq, "pool-claim", 0),
        .maximum = 1,
        .lease_ms = self.lease_ms,
        .predicate = null,
    };
    const caller = self.tableClient();
    const claim_receipt = blk: {
        if (wait_ms) |ms| {
            const waited = try applyQueue(&self.output, caller, .{ .wait = .{ .claim = claim_req, .milliseconds = ms } });
            switch (waited) {
                .timed_out => return false,
                .operation => |maybe_op| {
                    const found = maybe_op orelse return error.ActorProgressUnresolved;
                    if (found != .claim) return error.ActorProgressUnresolved;
                    if (found.claim.rows == 0) return false;
                    break :blk found.claim;
                },
                else => return error.ActorProgressUnresolved,
            }
        } else {
            const found = (try applyQueue(&self.output, caller, .{ .mutate = .{ .work = .{ .claim = claim_req } } })).operation orelse return error.ActorProgressUnresolved;
            if (found != .claim) return error.ActorProgressUnresolved;
            if (found.claim.rows == 0) return false;
            break :blk found.claim;
        }
    };

    const page = (try applyQueue(&self.output, caller, .{
        .page = .{ .cursor = .{ .receipt = claim_receipt, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = self.max_record_bytes } },
    })).page;
    if (page.rows.len != 1 or !page.cursor.complete() or page.rows[0].lease.liveness != .live)
        return error.ActorInputUnavailable;
    const row = page.rows[0];
    if (row.value.cells.len != 2 or row.value.cells[0] != .value or row.value.cells[0].value != .atom or
        row.value.cells[0].value.atom != .signed or row.value.cells[0].value.atom.signed <= 0)
        return error.ActorIdentityConflict;
    const pid: u64 = @intCast(row.value.cells[0].value.atom.signed);

    // If an earlier slot for this PID is still recovering, finish it before attaching the new claim.
    if (self.findActorSlot(pid)) |existing_idx| {
        for (0..16) |_| {
            if (self.slots[existing_idx] == null) break;
            _ = try self.advanceSlotAt(existing_idx);
        }
        if (self.slots[existing_idx] != null) return false;
    }

    const target_idx = self.findFreeSlot() orelse return false;
    var slot_arena: std.heap.ArenaAllocator = .init(self.parent);
    errdefer slot_arena.deinit();
    const binding = (try self.resolver.resolve(self.resolver.context, slot_arena.allocator(), pid)) orelse return error.UnknownActorPid;
    if (binding.actor.pid != pid or !std.meta.eql(binding.actor.inbox, self.inbox))
        return error.ActorIdentityConflict;

    var runner = try Runner.init(self.parent, caller, binding.actor, binding.activation);
    errdefer runner.deinit();
    if (!try runner.acceptPoolInput(claim_receipt, row)) {
        runner.deinit();
        slot_arena.deinit();
        return false;
    }
    self.slots[target_idx] = .{
        .pid = pid,
        .handler = binding.handler,
        .arena = slot_arena,
        .runner = runner,
    };
    self.active_runners += 1;
    if (self.active_runners > self.peak_active_runners) self.peak_active_runners = self.active_runners;
    return true;
}

fn advanceSlotAt(self: *Self, idx: usize) !StepResult {
    const slot = &(self.slots[idx] orelse return .idle);
    const res = try slot.runner.advance(slot.handler);
    switch (res) {
        .recovering => return .progressed,
        .committed => {
            self.completed_turns += 1;
            self.releaseSlot(idx);
            return .committed;
        },
        .blocked => {
            self.releaseSlot(idx);
            return .blocked;
        },
        .idle => {
            self.releaseSlot(idx);
            return .idle;
        },
    }
}

/// Advance one occupied slot in round-robin order and release it if terminal.
pub fn stepOneSlot(self: *Self) !StepResult {
    if (self.stopped) return error.PoolStopped;
    if (self.active_runners == 0) return .idle;
    for (0..self.max_active_runners) |offset| {
        const idx = (self.cursor_slot + offset) % self.max_active_runners;
        if (self.slots[idx] != null) {
            self.cursor_slot = (idx + 1) % self.max_active_runners;
            return self.advanceSlotAt(idx);
        }
    }
    return .idle;
}

/// Multiplexed step: claims work when capacity permits (parking up to `wait_ms`
/// only when all slots are idle) and advances an active slot, releasing resident
/// `Runner` memory as soon as the turn settles.
pub fn step(self: *Self, wait_ms: ?u32) !StepResult {
    if (self.stopped) return error.PoolStopped;
    if (self.active_runners < self.max_active_runners) {
        const effective_wait = if (self.active_runners == 0) wait_ms else null;
        _ = try self.claimIntoSlot(effective_wait);
    }
    return self.stepOneSlot();
}

test "private transactional pool enforces slot bounds and clean shutdown invariants" {
    std.testing.refAllDecls(Self);
}
