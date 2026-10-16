//! Host-owned bounded CPU workers. Sources, ordering and publication stay with
//! the calling query. Workers borrow disjoint decoded lanes, never a native client.
const std = @import("std");
const Batch = @import("root.zig").fuze.Batch;
const Self = @This();
pub const max_workers = 4;
// The pinned runtime uses up to 512 KiB of TLS in Debug (256 KiB in
// ReleaseSafe). pthread includes that in its reservation; leave another
// 512 KiB for the bounded kernel stack. This is charged before thread creation.
pub const stack_bytes = 1024 * 1024;
pub const Options = struct {
    workers: u8 = 1,
    resident_bytes: usize = 4 * 1024 * 1024,
    /// Short/simple batches stay local. This is operator-lanes, not source rows.
    minimum_work: usize = 8192,
};
allocator: std.mem.Allocator,
io: std.Io,
options: Options,
threads: [max_workers - 1]std.Thread = undefined,
started: u8 = 0,
admission: std.Io.Mutex = .init,
mutex: std.Io.Mutex = .init,
ready: std.Io.Condition = .init,
joined: std.Io.Condition = .init,
stopping: bool = false,
generation: u64 = 0,
remaining: u8 = 0,
work: ?*Batch = null,
cancellation: ?*const std.atomic.Value(bool) = null,
active_bytes: std.atomic.Value(usize) = .init(0),

pub fn reservedBytes(workers: u8) usize {
    std.debug.assert(workers >= 1 and workers <= max_workers);
    return @sizeOf(Self) + @as(usize, workers - 1) * (stack_bytes + std.heap.pageSize() + @sizeOf(*Self) + @sizeOf(usize));
}
/// The returned pointer has a stable address until deinit. The host bounds its
/// query concurrency and decoder/output buffers separately from this CPU pool.
pub fn init(a: std.mem.Allocator, io: std.Io, options: Options) !*Self {
    if (options.workers == 0 or options.workers > max_workers) return error.InvalidComputeWorkers;
    if (options.resident_bytes < reservedBytes(options.workers)) return error.ComputeMemoryBudget;
    const self = try a.create(Self);
    errdefer a.destroy(self);
    self.* = .{ .allocator = a, .io = io, .options = options };
    errdefer self.stopAndJoin();
    for (1..options.workers) |slot| {
        self.threads[slot - 1] = try std.Thread.spawn(.{ .stack_size = stack_bytes }, worker, .{ self, slot });
        self.started += 1;
    }
    return self;
}
/// The host stops new calls and joins all query callers before destruction,
/// including callers computing locally. Join every worker before freeing memory.
pub fn deinit(self: *Self) void {
    self.admission.lockUncancelable(self.io);
    self.stopAndJoin();
    self.admission.unlock(self.io);
    const allocator = self.allocator;
    allocator.destroy(self);
}
fn stopAndJoin(self: *Self) void {
    self.mutex.lockUncancelable(self.io);
    self.stopping = true;
    self.ready.broadcast(self.io);
    self.mutex.unlock(self.io);
    for (self.threads[0..self.started]) |thread| thread.join();
}
pub fn runner(self: *Self, cancellation: ?*const std.atomic.Value(bool)) Batch.Runner {
    return .{ .context = self, .evaluate = run, .cancellation = cancellation };
}
fn cancelled(flag: ?*const std.atomic.Value(bool)) bool {
    return if (flag) |value| value.load(.acquire) else false;
}
fn run(context: *anyopaque, batch: *Batch, cancellation: ?*const std.atomic.Value(bool)) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.evaluate(batch, cancellation);
}
pub fn evaluate(self: *Self, batch: *Batch, cancellation: ?*const std.atomic.Value(bool)) !void {
    if (cancelled(cancellation)) return error.Cancelled;
    const available = self.options.resident_bytes - reservedBytes(self.options.workers);
    const bytes = batch.residentBytes();
    var previous = self.active_bytes.load(.acquire);
    while (true) {
        if (bytes > available - previous) return error.ComputeMemoryBudget;
        previous = self.active_bytes.cmpxchgWeak(previous, previous + bytes, .acq_rel, .acquire) orelse break;
    }
    defer _ = self.active_bytes.fetchSub(bytes, .release);
    // One admitted borrowed batch, no backlog or nested pool. Contending short
    // work executes locally instead of waiting behind another query's CPU work.
    if (self.options.workers == 1 or batch.plan.aggregate == .sum or batch.len * batch.kernel.instructions.len < self.options.minimum_work or !self.admission.tryLock()) {
        batch.evaluate();
        if (cancelled(cancellation)) return error.Cancelled;
        return;
    }
    defer self.admission.unlock(self.io);
    batch.prepareViews();
    self.mutex.lockUncancelable(self.io);
    self.work = batch;
    self.cancellation = cancellation;
    self.remaining = self.started;
    self.generation +%= 1;
    self.ready.broadcast(self.io);
    self.mutex.unlock(self.io);
    self.compute(batch, 0, cancellation);
    self.mutex.lockUncancelable(self.io);
    while (self.remaining != 0) self.joined.waitUncancelable(self.io, &self.mutex);
    self.work = null;
    self.cancellation = null;
    self.mutex.unlock(self.io);
    // Cancellation discards the entire private candidate after all writes stop.
    if (cancelled(cancellation)) return error.Cancelled;
}
fn compute(self: *Self, batch: *Batch, slot: usize, cancellation: ?*const std.atomic.Value(bool)) void {
    var start = batch.len * slot / self.options.workers;
    const end = batch.len * (slot + 1) / self.options.workers;
    while (start < end and !cancelled(cancellation)) {
        const next = @min(end, start + 64);
        batch.evaluateRange(start, next);
        start = next;
    }
}
fn worker(self: *Self, slot: usize) void {
    var generation: u64 = 0;
    self.mutex.lockUncancelable(self.io);
    defer self.mutex.unlock(self.io);
    while (true) {
        while (!self.stopping and generation == self.generation) self.ready.waitUncancelable(self.io, &self.mutex);
        if (self.stopping) return;
        generation = self.generation;
        const batch = self.work.?;
        const cancellation = self.cancellation;
        self.mutex.unlock(self.io);
        self.compute(batch, slot, cancellation);
        self.mutex.lockUncancelable(self.io);
        self.remaining -= 1;
        if (self.remaining == 0) self.joined.signal(self.io);
    }
}

test "one two and four workers preserve ordered lane coverage and cancellation" {
    const t = std.testing;
    const f = @import("root.zig").fuze;
    const plan: f.LogicalQuery.Plan = .{ .schema = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true }} }, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    for ([_]u8{ 1, 2, 4 }) |workers| {
        const pool = try init(t.allocator, t.io, .{ .workers = workers, .minimum_work = 0 });
        defer pool.deinit();
        var batch = try Batch.init(t.allocator, plan, .{ .rows = 1024 });
        defer batch.deinit();
        var cancellation: std.atomic.Value(bool) = .init(false);
        for ([_]usize{ 0, 1, 3, 7, 63, 64, 65, 255, 256, 257, 1024 }) |requested| {
            batch.reset();
            const len = @min(requested, batch.capacity);
            for (0..len) |i| try batch.append(&.{if (i % 17 == 0) .{ .type_error = .utf8 } else .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(i)) - 100 } } }}, .{ .row = i + 1, .boundary = i / 8 + 1 });
            for (0..5) |_| {
                try pool.evaluate(&batch, &cancellation);
                for (batch.outcomes[0..len], 0..) |out, i| {
                    if (i % 17 == 0) {
                        try t.expect(out == .type_error);
                        try t.expectEqual(@as(u8, 0), batch.sites[i]);
                    } else try t.expectEqual(i >= 100, out.truth.selects());
                }
            }
        }
        cancellation.store(true, .release);
        try t.expectError(error.Cancelled, pool.evaluate(&batch, &cancellation));
        cancellation.store(false, .release);
        try pool.evaluate(&batch, &cancellation);
    }
    try t.expectError(error.InvalidComputeWorkers, init(t.allocator, t.io, .{ .workers = 5 }));
    try t.expectError(error.ComputeMemoryBudget, init(t.allocator, t.io, .{ .workers = 4, .resident_bytes = 1 }));
}

test "seeded worker partitions preserve all five states with portable and AVX2 kernels" {
    const t = std.testing;
    const f = @import("root.zig").fuze;
    const Cell = f.Types.Values.Cell;
    const alternatives = [_]f.Types.Values.Alternative{ .{ .counter = 1, .replica = 1, .value = .null }, .{ .counter = 2, .replica = 1, .value = .null } };
    const plan: f.LogicalQuery.Plan = .{ .schema = .{ .structure = &.{.{ .name = "n", .type = .int64, .nullable = true, .optional = true }} }, .source_basis = @splat(71), .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .ge, .value = .{ .signed = 0 } } } };
    for ([_]u8{ 1, 2, 4 }) |workers| {
        const pool = try init(t.allocator, t.io, .{ .workers = workers, .minimum_work = 0 });
        defer pool.deinit();
        for ([_]Batch.kernels.cpu.Implementation{ .portable, .avx2 }) |implementation| {
            if (implementation == .avx2 and !Batch.kernels.cpu.hasAvx2()) continue;
            var batch = try Batch.init(t.allocator, plan, .{ .rows = 1024, .implementation = implementation });
            defer batch.deinit();
            var prng = std.Random.DefaultPrng.init(7105);
            const random = prng.random();
            for (0..32) |_| {
                batch.reset();
                const len = random.uintLessThan(usize, batch.capacity + 1);
                var input: [1024]Cell = undefined;
                for (input[0..len], 0..) |*cell, i| {
                    cell.* = switch (random.uintLessThan(u8, 8)) {
                        0 => .null,
                        1 => .missing,
                        2 => .{ .type_error = .utf8 },
                        3 => .{ .conflict = &alternatives },
                        else => .{ .value = .{ .atom = .{ .signed = @as(i64, @intCast(random.uintLessThan(u32, 1001))) - 500 } } },
                    };
                    try batch.append(&.{cell.*}, .{ .row = i + 1, .boundary = i / 8 + 1 });
                }
                try pool.evaluate(&batch, null);
                for (input[0..len], batch.outcomes[0..len], 0..) |cell, outcome, i| switch (cell) {
                    .null, .missing => try t.expectEqual(@import("root.zig").fuze.Batch.Outcome{ .truth = .unknown }, outcome),
                    .type_error, .conflict => {
                        try t.expectEqual(std.meta.activeTag(cell) == .type_error, outcome == .type_error);
                        try t.expect(outcome == .type_error or outcome == .conflict);
                        try t.expectEqual(@as(u8, 0), batch.sites[i]);
                    },
                    .value => |value| try t.expectEqual(value.atom.signed >= 0, outcome.truth.selects()),
                };
            }
        }
    }
}

test "contending short work completes locally while admitted cancellation joins workers" {
    const t = std.testing;
    const f = @import("root.zig").fuze;
    const plan: f.LogicalQuery.Plan = .{ .schema = .{ .structure = &.{.{ .name = "n", .type = .int64 }} }, .source_basis = @splat(71), .projection = &.{0} };
    const pool = try init(t.allocator, t.io, .{ .workers = 4, .minimum_work = 0, .resident_bytes = reservedBytes(4) + 512 * 1024 });
    defer pool.deinit();
    var long = try Batch.init(t.allocator, plan, .{});
    defer long.deinit();
    var short = try Batch.init(t.allocator, plan, .{});
    defer short.deinit();
    try long.append(&.{.{ .value = .{ .atom = .{ .signed = 3 } } }}, .{ .row = 1, .boundary = 1 });
    try short.append(&.{.{ .value = .{ .atom = .{ .signed = 7 } } }}, .{ .row = 1, .boundary = 1 });
    const Call = struct {
        pool: *Self,
        batch: *Batch,
        flag: std.atomic.Value(bool) = .init(false),
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.pool.evaluate(self.batch, &self.flag) catch |err| {
                self.failure = err;
            };
        }
    };
    var call: Call = .{ .pool = pool, .batch = &long };
    // Hold scheduling after admission but before publication to any worker.
    pool.mutex.lockUncancelable(t.io);
    const thread = std.Thread.spawn(.{}, Call.run, .{&call}) catch |err| {
        pool.mutex.unlock(t.io);
        return err;
    };
    var joined = false;
    defer if (!joined) {
        call.flag.store(true, .release);
        pool.mutex.unlock(t.io);
        thread.join();
    };
    const deadline = std.Io.Clock.awake.now(t.io).toMilliseconds() + 5000;
    // Acquiring this lock while polling can divert the caller into its local
    // fallback, after which admission never happens. Observe without competing.
    while (pool.admission.state.load(.acquire) == .unlocked) {
        try t.expect(std.Io.Clock.awake.now(t.io).toMilliseconds() < deadline);
        try std.Thread.yield();
    }
    // Concurrent callers share the reservation even when they compute locally.
    var larger = try Batch.init(t.allocator, plan, .{ .bytes = 512 * 1024 });
    defer larger.deinit();
    try t.expectError(error.ComputeMemoryBudget, pool.evaluate(&larger, null));
    // No queue is formed; this query does not wait for the admitted job.
    try pool.evaluate(&short, null);
    try t.expect(short.outcomes[0].truth.selects());
    call.flag.store(true, .release);
    pool.mutex.unlock(t.io);
    thread.join();
    joined = true;
    try t.expectEqual(error.Cancelled, call.failure.?);
    try t.expect(pool.work == null and pool.remaining == 0);
    try t.expectEqual(@as(usize, 0), pool.active_bytes.load(.acquire));
    try pool.evaluate(&long, null);
    try t.expect(long.outcomes[0].truth.selects());
}

test "held file output releases workers while buffered disclosure rechecks current access" {
    const t = std.testing;
    const f = @import("root.zig").fuze;
    const Memory = struct {
        denied: bool = false,
        const bytes = "n,label\n1,one\n2,two\n3,three\n4,four\n5,five\n6,six\n7,seven\n8,eight\n9,nine\n10,ten\n";
        fn read(_: *anyopaque, offset: u64, output: []u8) !usize {
            const start: usize = @intCast(offset);
            const count = @min(output.len, bytes.len - start);
            @memcpy(output[0..count], bytes[start..][0..count]);
            return count;
        }
        fn check(context: *anyopaque) !void {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (self.denied) return error.AccessDenied;
        }
    };
    var memory: Memory = .{};
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(Memory.bytes, &digest, .{});
    const sources = [_]f.FileSource.Source{.{ .context = &memory, .read = Memory.read, .check = Memory.check, .length = Memory.bytes.len, .digest = digest }};
    var binding = try f.FileSource.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var projected = try f.FileQuery.compile(t.allocator, "SELECT label FROM input WHERE n > 0", "input", &binding);
    defer projected.deinit();
    var counted = try f.FileQuery.compile(t.allocator, "SELECT COUNT(*) FROM input WHERE n > 0", "input", &binding);
    defer counted.deinit();
    const pool = try init(t.allocator, t.io, .{ .workers = 4, .minimum_work = 0 });
    defer pool.deinit();
    var first = try f.FileQuery.executeWith(t.allocator, &binding, &sources, projected.plan, .{ .runner = pool.runner(null) });
    defer first.deinit();
    first.startup_rows = 0;
    var held = (try first.next()).?;
    defer held.deinit();
    try t.expectEqual(@as(usize, 10), first.physical.len);
    try t.expect(pool.work == null and pool.active_bytes.load(.acquire) == 0);
    // The first consumer keeps its row and stops pulling. A second complete
    // query uses the same workers without waiting for that consumer.
    var second = try f.FileQuery.executeWith(t.allocator, &binding, &sources, counted.plan, .{ .runner = pool.runner(null) });
    defer second.deinit();
    var total = (try second.next()).?;
    defer total.deinit();
    try t.expectEqual(@as(u128, 10), total.cells[0].value.atom.unsigned);
    try t.expect(second.complete);
    try t.expectEqualStrings("one", held.cells[0].value.atom.bytes);
    memory.denied = true;
    try t.expectError(error.AccessDenied, first.next());
    try t.expect(!first.complete);
    try t.expect(pool.work == null and pool.active_bytes.load(.acquire) == 0);
}
