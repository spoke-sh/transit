//! Effectful hosts own this runtime; deterministic memory primitives stay below
//! it. Tasks reserve records from fixed storage and workers are created at admission.
const std = @import("std");
const memory = @import("transit_memory");
pub const Threaded = struct {
    parent: std.mem.Allocator,
    records: memory.Slab,
    runtime: std.Io.Threaded,
    workers: usize,
    stack_bytes: usize,
    pub const Options = struct {
        workers: usize,
        task_bytes: usize,
        stack_bytes: usize = std.Thread.SpawnConfig.default_stack_size,
        environ: std.process.Environ = .empty,
        argv0: std.Io.Threaded.Argv0 = .empty,
    };
    pub fn create(parent: std.mem.Allocator, options: Options) !*Threaded {
        if (options.workers == 0 or options.stack_bytes == 0) return error.InvalidIoCapacity;
        _ = try std.math.mul(usize, options.workers, options.stack_bytes);
        const self = try parent.create(Threaded);
        errdefer parent.destroy(self);
        self.* = .{ .parent = parent, .records = try .init(parent, options.task_bytes), .runtime = undefined, .workers = options.workers, .stack_bytes = options.stack_bytes };
        errdefer self.records.deinit();
        self.runtime = .init(self.records.allocator(), .{
            .async_limit = .limited(options.workers),
            .concurrent_limit = .limited(options.workers),
            .stack_size = options.stack_bytes,
            .environ = options.environ,
            .argv0 = options.argv0,
        });
        errdefer self.runtime.deinit();
        try self.warmWorkers();
        return self;
    }
    pub fn io(self: *Threaded) std.Io {
        return self.runtime.io();
    }
    /// Backing records plus explicitly requested stacks. OS guard pages/TLS and
    /// pthread bookkeeping are reported by the host's separate mapping observer.
    pub fn reservedBytes(self: *const Threaded) usize {
        return @sizeOf(Threaded) + self.records.buffer.len + self.workers * self.stack_bytes;
    }
    fn warmWorkers(self: *Threaded) !void {
        const io_ = self.io();
        const futures = try self.parent.alloc(std.Io.Future(void), self.workers);
        defer self.parent.free(futures);
        var gate: std.Io.Event = .unset;
        var started: usize = 0;
        defer {
            gate.set(io_);
            for (futures[0..started]) |*future| future.await(io_);
        }
        // Every worker is simultaneously occupied before releasing the gate.
        // This warms a finite concurrency envelope, not data or query shapes.
        for (futures) |*future| {
            future.* = try io_.concurrent(wait, .{ io_, &gate });
            started += 1;
        }
    }
    fn wait(io_: std.Io, gate: *std.Io.Event) void {
        gate.waitUncancelable(io_);
    }
    /// All host futures and groups must be joined first. Threaded teardown joins
    /// workers before their task allocator or borrowed host state can disappear.
    pub fn destroy(self: *Threaded) void {
        self.runtime.deinit();
        self.records.deinit();
        self.parent.destroy(self);
    }
};

fn answer(value: u32) u32 {
    return value + 1;
}
test "warmed I/O futures and cancellation reuse bounded records and workers" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const runtime = try Threaded.create(probe.allocator(), .{ .workers = 4, .task_bytes = 64 * 1024 });
    defer runtime.destroy();
    const io_ = runtime.io();
    probe.begin(true);
    for (0..1000) |i| {
        var future = try io_.concurrent(answer, .{@as(u32, @intCast(i))});
        try t.expectEqual(i + 1, future.await(io_));
        var timer = try io_.concurrent(std.Io.sleep, .{ io_, std.Io.Duration.fromSeconds(60), std.Io.Clock.awake });
        if (timer.cancel(io_)) |_| {} else |err| try t.expectEqual(error.Canceled, err);
    }
    try probe.verify();
    try t.expectEqual(runtime.reservedBytes(), probe.live_bytes + runtime.workers * runtime.stack_bytes);
}
