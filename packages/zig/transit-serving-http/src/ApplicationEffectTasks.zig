//! Bounded local tasks for original application effects. Native progress owns
//! the backlog. Slots own only active work and completions awaiting settlement.
const std = @import("std");
const q = @import("transit_query_direct");
const X = q.ApplicationExecution;
const E = q.ApplicationEffect;
const Self = @This();

pub const Limits = struct { active_tasks: usize, scratch_bytes: usize, resident_bytes: usize };
pub const Executor = struct {
    context: *anyopaque,
    /// Reopen the job through native owners. Publish a known completion before
    /// returning, including on cancellation. Join all private subtasks first.
    run: *const fn (*anyopaque, *Task) anyerror!void,
};
const Slot = struct {
    memory: []u8,
    scratch: std.heap.FixedBufferAllocator,
    job: ?X.EffectJob = null,
    io: std.Io = undefined,
    future: ?std.Io.Future(void) = null,
    withdrawal: std.Io.Event = .unset,
    done: bool = false,
    joined: bool = false,
    completion: ?X.EffectCompletion = null,

    fn wipe(self: *Slot) void {
        const memory = self.memory;
        std.crypto.secureZero(u8, memory);
        self.* = .{ .memory = memory, .scratch = .init(memory) };
    }
};
allocator: std.mem.Allocator,
slots: []Slot,
memory: []u8,
executor: Executor,
mutex: std.Io.Mutex = .init,
changed: std.Io.Condition = .init,
stopped: bool = false,

/// Keep this owner at a stable address. Each task's creating I/O runtime must
/// outlive its join; clients and evaluation borrows cannot be shared between tasks.
pub fn init(allocator: std.mem.Allocator, limits: Limits, executor: Executor) !Self {
    if (limits.active_tasks == 0 or limits.scratch_bytes == 0) return error.ApplicationEffectCapacity;
    const bytes = try std.math.mul(usize, limits.active_tasks, limits.scratch_bytes);
    const total = try std.math.add(usize, bytes, try std.math.mul(usize, limits.active_tasks, @sizeOf(Slot)));
    if (total > limits.resident_bytes) return error.ApplicationEffectCapacity;
    const slots = try allocator.alloc(Slot, limits.active_tasks);
    errdefer allocator.free(slots);
    const memory = try allocator.alloc(u8, bytes);
    @memset(memory, 0);
    for (slots, 0..) |*slot, index| {
        const part = memory[index * limits.scratch_bytes ..][0..limits.scratch_bytes];
        slot.* = .{ .memory = part, .scratch = .init(part) };
    }
    return .{ .allocator = allocator, .slots = slots, .memory = memory, .executor = executor };
}
/// Stop admission and join physical work, preserving every known completion.
/// The owner then settles originals and releases slots before deinit. Shutdown
/// alone cannot establish native settlement or discard a received response.
pub fn shutdown(self: *Self, io: std.Io) void {
    self.mutex.lockUncancelable(io);
    self.stopped = true;
    for (self.slots) |*slot| if (slot.job != null) slot.withdrawal.set(slot.io);
    self.mutex.unlock(io);
    // The deployment has stopped callers before shutdown; workers may still
    // publish completions under the mutex until their joined return.
    for (self.slots) |*slot| if (slot.future) |*future| {
        future.await(slot.io);
        slot.joined = true;
    };
}
pub fn deinit(self: *Self) !void {
    if (!self.stopped) return error.ApplicationEffectPending;
    for (self.slots) |slot| if (slot.job != null) return error.ApplicationEffectPending;
    std.crypto.secureZero(u8, self.memory);
    self.allocator.free(self.memory);
    self.allocator.free(self.slots);
    self.* = undefined;
}
fn find(self: *Self, descriptor: E.Descriptor) ?*Slot {
    for (self.slots) |*slot| if (slot.job) |job| {
        if (std.meta.eql(job.descriptor, descriptor)) return slot;
    };
    return null;
}
/// Observe only a matching local slot. Capacity and absent work remain distinct
/// from a running task; callers still inspect the original native completion.
pub fn status(self: *Self, io: std.Io, job: X.EffectJob) !?X.EffectPoll {
    try job.validate();
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    return self.observation(job);
}
fn observation(self: *Self, job: X.EffectJob) !?X.EffectPoll {
    for (self.slots) |slot| if (slot.job) |existing| {
        if (existing.descriptor.step == job.descriptor.step and existing.descriptor.instruction == job.descriptor.instruction and
            std.meta.eql(existing.descriptor.invocation, job.descriptor.invocation) and
            !std.meta.eql(existing.descriptor, job.descriptor)) return error.InvalidApplicationEffect;
    };
    const slot = self.find(job.descriptor) orelse return null;
    if (!std.meta.eql(slot.job.?, job)) return .abandoned;
    if (!slot.done) return .waiting;
    return if (slot.completion) |completion| .{ .completed = completion } else .abandoned;
}
/// Capacity leaves the native original waiting; it creates no in-memory queue
/// and cannot turn pressure into refusal or another dispatch identity.
pub fn poll(self: *Self, io: std.Io, job: X.EffectJob) !X.EffectPoll {
    try job.validate();
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    if (try self.observation(job)) |known| return known;
    if (self.stopped) return .abandoned;
    for (self.slots) |*slot| if (slot.job == null) {
        slot.job = job;
        slot.io = io;
        errdefer slot.wipe();
        slot.future = try io.concurrent(run, .{ self, slot });
        return .waiting;
    };
    return .waiting;
}
/// Nonblocking withdrawal. The background task joins its I/O before setting
/// done. No callback waits for remote work while the coordinator holds a slot.
pub fn join(self: *Self, io: std.Io, descriptor: E.Descriptor) !X.EffectJoin {
    try descriptor.validate();
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    const slot = self.find(descriptor) orelse return .{ .joined = null };
    slot.withdrawal.set(slot.io);
    if (!slot.done) return .waiting;
    if (!slot.joined) {
        slot.future.?.await(slot.io);
        slot.joined = true;
    }
    return .{ .joined = slot.completion };
}
/// The native coordinator calls this only after joined terminal settlement.
/// It must retain this slot across an uncertain completion publication.
pub fn release(self: *Self, io: std.Io, descriptor: E.Descriptor) void {
    self.mutex.lockUncancelable(io);
    defer self.mutex.unlock(io);
    const slot = self.find(descriptor) orelse return;
    std.debug.assert(slot.done and slot.joined);
    slot.wipe();
}
pub const Task = struct {
    pool: *Self,
    slot: *Slot,
    job: X.EffectJob,
    io: std.Io,
    /// One attempt's private scratch, allocated at deployment admission and
    /// erased at release. The executor owns all nested lifetimes within it.
    pub fn allocator(self: *Task) std.mem.Allocator {
        return self.slot.scratch.allocator();
    }
    pub fn complete(self: *Task, completion: X.EffectCompletion) !void {
        try (try self.job.descriptor.key()).requireSame(completion.attempt.key);
        if (!std.mem.eql(u8, &try self.job.descriptor.digest(), &completion.attempt.descriptor) or
            !std.meta.eql(completion.attempt.dispatch.lease, self.job.lease) or
            std.mem.allEqual(u8, &completion.attempt.dispatch.nonce, 0)) return error.InvalidApplicationEffect;
        try completion.attempt.revision.validate();
        try (X.EffectResult{ .descriptor = self.job.descriptor, .outcome = completion.outcome }).validate();
        // A response already received must survive cancellation of this task.
        self.pool.mutex.lockUncancelable(self.io);
        defer self.pool.mutex.unlock(self.io);
        if (self.slot.completion) |known| {
            if (!std.meta.eql(known, completion)) return error.ClientOperationConflict;
        } else self.slot.completion = completion;
    }
};
fn execute(self: *Self, slot: *Slot) !void {
    var task: Task = .{ .pool = self, .slot = slot, .job = slot.job.?, .io = slot.io };
    try self.executor.run(self.executor.context, &task);
}
fn withdrawn(slot: *Slot) !void {
    try slot.withdrawal.wait(slot.io);
}
fn run(self: *Self, slot: *Slot) void {
    const Choice = union(enum) { work: anyerror!void, withdrawal: anyerror!void };
    var choices: [2]Choice = undefined;
    var selection: std.Io.Select(Choice) = .init(slot.io, &choices);
    defer {
        // Includes a partially scheduled pair. Completion publication and all
        // borrowed/private resources finish before the coordinator can release.
        selection.cancelDiscard();
        self.mutex.lockUncancelable(slot.io);
        slot.done = true;
        self.changed.broadcast(slot.io);
        self.mutex.unlock(slot.io);
    }
    selection.concurrent(.withdrawal, withdrawn, .{slot}) catch return;
    selection.concurrent(.work, execute, .{ self, slot }) catch return;
    const result = selection.await() catch return;
    switch (result) {
        inline else => |outcome| outcome catch {},
    }
    // An error supplies no remote outcome. Without complete(), the coordinator
    // withdraws this original and resolves its existing native effect record.
}

fn proofJob() X.EffectJob {
    const c = q.catalog;
    const p = q.protocol;
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .audience = 5, .principal = 7, .role = 9 };
    const program: p.DataLifecycle.Definition = .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 11 }, .revision = 1, .digest = @splat(1) };
    var sink = program;
    sink.object.object = 12;
    const invocation: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(1), .token = @splat(2) };
    const request: c.DirectRecord.Reference = .{ .scope = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(3) }, .format = c.DirectOwnedRecord.format, .content = .{ .bytes = 100, .sha256 = @splat(4) } };
    return .{
        .declaration = request,
        .descriptor = .{ .definition = p.Growth.current_definition, .invocation = invocation, .program = program, .input = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = program, .partition = 0 }, .operation = .{ .scope = connection.scope, .principal = connection.principal, .operation = 13 }, .ordinal = 0 }, .request = request, .namespace = 1, .step = 1, .instruction = 3, .sink = sink, .operation = @splat(8) },
        .revision = .{ .partition = 100, .next_lsn = 1 },
        .lease = .{ .key = invocation, .revision = .{ .partition = 100, .next_lsn = 1 }, .additional = null },
    };
}

test "application effect tasks retain known completion through cancellation and shutdown" {
    const t = std.testing;
    var runtime: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4), .async_limit = .limited(4) });
    defer runtime.deinit();
    const worker_io = runtime.io();
    const Worker = struct {
        entered: std.Io.Event = .unset,
        exited: std.atomic.Value(usize) = .init(0),
        fn run(context: *anyopaque, task: *Task) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            defer _ = self.exited.fetchAdd(1, .monotonic);
            const bytes = try task.allocator().alloc(u8, 32);
            @memset(bytes, 0x53);
            const completion: X.EffectCompletion = .{ .attempt = .{ .key = try task.job.descriptor.key(), .descriptor = try task.job.descriptor.digest(), .dispatch = .{ .nonce = @splat(9), .lease = task.job.lease }, .revision = .{ .partition = 200, .next_lsn = 1 } }, .outcome = .{ .response = .{ .status = 201, .bytes = 2, .sha256 = @splat(10), .body = null } } };
            try task.complete(completion);
            try task.complete(completion);
            var changed = completion;
            changed.outcome.response.status = 200;
            try t.expectError(error.ClientOperationConflict, task.complete(changed));
            self.entered.set(task.io);
            try task.io.sleep(.fromSeconds(60), .awake);
        }
    };
    var worker: Worker = .{};
    const executor: Executor = .{ .context = &worker, .run = Worker.run };
    try t.expectError(error.ApplicationEffectCapacity, Self.init(t.allocator, .{ .active_tasks = 1, .scratch_bytes = 128, .resident_bytes = 0 }, executor));
    var self = try Self.init(t.allocator, .{ .active_tasks = 1, .scratch_bytes = 128, .resident_bytes = 64 * 1024 }, executor);
    defer {
        self.shutdown(t.io);
        for (self.slots) |slot| if (slot.job) |pending| self.release(t.io, pending.descriptor);
        self.deinit() catch unreachable;
    }
    const job = proofJob();
    try t.expect(try self.status(t.io, job) == null);
    try t.expect(self.slots[0].job == null);
    try t.expectEqual(.waiting, try self.poll(worker_io, job));
    try worker.entered.wait(t.io);
    try t.expectEqual(.waiting, (try self.status(t.io, job)).?);
    var other = job;
    other.descriptor.operation[0] ^= 1;
    try t.expectError(error.InvalidApplicationEffect, self.poll(t.io, other));
    try t.expectError(error.InvalidApplicationEffect, self.status(t.io, other));
    other = job;
    other.descriptor.instruction += 1;
    try t.expectEqual(.waiting, try self.poll(t.io, other));
    try t.expect(try self.status(t.io, other) == null);
    try t.expectEqual(@as(usize, 0), worker.exited.load(.acquire));
    var replaced = job;
    replaced.revision.next_lsn += 1;
    replaced.lease.revision = replaced.revision;
    try t.expectEqual(.abandoned, try self.poll(t.io, replaced));
    try t.expectEqual(.abandoned, (try self.status(t.io, replaced)).?);
    const initial = try self.join(t.io, job.descriptor);
    if (initial == .waiting) {
        self.mutex.lockUncancelable(t.io);
        while (!self.slots[0].done) self.changed.waitUncancelable(t.io, &self.mutex);
        self.mutex.unlock(t.io);
    }
    const joined = try self.join(t.io, job.descriptor);
    try t.expectEqual(@as(usize, 1), worker.exited.load(.acquire));
    try t.expectEqual(@as(u16, 201), joined.joined.?.outcome.response.status);
    try t.expectEqualDeep(joined, try self.join(t.io, job.descriptor));
    self.shutdown(t.io);
    try t.expectError(error.ApplicationEffectPending, self.deinit());
    try t.expectEqualDeep(joined.joined.?, (try self.poll(t.io, job)).completed);
    try t.expectEqualDeep(joined.joined.?, (try self.status(t.io, job)).?.completed);
    try t.expectEqual(.abandoned, try self.poll(t.io, other));
    // Simulate the coordinator's verified native settlement only now.
    self.release(t.io, job.descriptor);
    try t.expect(try self.status(t.io, job) == null);
    try t.expect(std.mem.allEqual(u8, self.memory, 0));
    try t.expectEqualDeep(X.EffectJoin{ .joined = null }, try self.join(t.io, job.descriptor));
}

test "application effect tasks preserve abandonment without automatically rescheduling work" {
    const t = std.testing;
    const Worker = struct {
        calls: std.atomic.Value(usize) = .init(0),
        fn run(context: *anyopaque, task: *Task) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            _ = self.calls.fetchAdd(1, .monotonic);
            _ = try task.allocator().alloc(u8, 129);
            return error.UnexpectedSuccess;
        }
    };
    var worker: Worker = .{};
    var self = try Self.init(t.allocator, .{ .active_tasks = 1, .scratch_bytes = 128, .resident_bytes = 64 * 1024 }, .{ .context = &worker, .run = Worker.run });
    defer {
        self.shutdown(t.io);
        for (self.slots) |slot| if (slot.job) |pending| self.release(t.io, pending.descriptor);
        self.deinit() catch unreachable;
    }
    const job = proofJob();
    try t.expectEqual(.waiting, try self.poll(t.io, job));
    self.mutex.lockUncancelable(t.io);
    while (!self.slots[0].done) self.changed.waitUncancelable(t.io, &self.mutex);
    self.mutex.unlock(t.io);
    try t.expectEqual(.abandoned, try self.poll(t.io, job));
    try t.expectEqual(.abandoned, try self.poll(t.io, job));
    try t.expectEqual(@as(usize, 1), worker.calls.load(.acquire));
    try t.expectEqualDeep(X.EffectJoin{ .joined = null }, try self.join(t.io, job.descriptor));
    self.release(t.io, job.descriptor);
}
