//! Effectful hosts own this runtime; deterministic memory primitives stay below
//! it. Tasks reserve records from fixed storage and workers are created at admission.
const std = @import("std");
const memory = @import("transit_memory");
pub const Threaded = struct {
    parent: std.mem.Allocator,
    records: memory.Slab,
    runtime: std.Io.Threaded,
    vtable: std.Io.VTable,
    workers: usize,
    stack_bytes: usize,
    barriers: []std.Io.Future(void),
    worker_cleanup: ?*const fn () void,
    pub const Options = struct {
        workers: usize,
        task_bytes: usize,
        stack_bytes: usize = std.Thread.SpawnConfig.default_stack_size,
        environ: std.process.Environ = .empty,
        argv0: std.Io.Threaded.Argv0 = .empty,
        worker_cleanup: ?*const fn () void = null,
    };
    pub fn create(parent: std.mem.Allocator, options: Options) !*Threaded {
        if (options.workers == 0 or options.stack_bytes == 0) return error.InvalidIoCapacity;
        _ = try std.math.mul(usize, options.workers, options.stack_bytes);
        const self = try parent.create(Threaded);
        errdefer parent.destroy(self);
        self.* = .{ .parent = parent, .records = try .init(parent, options.task_bytes), .runtime = undefined, .vtable = undefined, .workers = options.workers, .stack_bytes = options.stack_bytes, .barriers = undefined, .worker_cleanup = options.worker_cleanup };
        errdefer self.records.deinit();
        self.barriers = try parent.alloc(std.Io.Future(void), options.workers);
        errdefer parent.free(self.barriers);
        self.runtime = .init(self.records.allocator(), .{
            .async_limit = .limited(options.workers),
            .concurrent_limit = .limited(options.workers),
            .stack_size = options.stack_bytes,
            .environ = options.environ,
            .argv0 = options.argv0,
        });
        errdefer self.runtime.deinit();
        self.vtable = self.runtime.io().vtable.*;
        self.vtable.netLookup = lookup;
        try self.barrier(null);
        return self;
    }
    pub fn io(self: *Threaded) std.Io {
        var result = self.runtime.io();
        result.vtable = &self.vtable;
        return result;
    }
    /// Numeric endpoints need no name service. The pinned glibc path otherwise
    /// calls allocating getaddrinfo even for an IP literal on every reconnect.
    /// Names retain the platform resolver's policy, cancellation and NSS behavior.
    fn lookup(userdata: ?*anyopaque, host: std.Io.net.HostName, queue: *std.Io.Queue(std.Io.net.HostName.LookupResult), options: std.Io.net.HostName.LookupOptions) std.Io.net.HostName.LookupError!void {
        const threaded: *std.Io.Threaded = @ptrCast(@alignCast(userdata));
        const self: *Threaded = @fieldParentPtr("runtime", threaded);
        const address = std.Io.net.IpAddress.parseIp4(host.bytes, options.port) catch
            std.Io.net.IpAddress.parseIp6(host.bytes, options.port) catch
            return threaded.io().vtable.netLookup(userdata, host, queue, options);
        const io_ = self.io();
        defer queue.close(io_);
        if (options.family) |family| if (family != std.meta.activeTag(address)) return error.UnknownHostName;
        queue.putOne(io_, .{ .address = address }) catch |err| switch (err) {
            error.Closed => unreachable,
            else => |failure| return failure,
        };
        if (options.canonical_name_buffer) |buffer| {
            if (buffer.len >= host.bytes.len) {
                @memcpy(buffer[0..host.bytes.len], host.bytes);
                queue.putOne(io_, .{ .canonical_name = .{ .bytes = buffer[0..host.bytes.len] } }) catch |err| switch (err) {
                    error.Closed => unreachable,
                    else => |failure| return failure,
                };
            }
        }
    }
    /// Backing records plus explicitly requested stacks. OS guard pages/TLS and
    /// pthread bookkeeping are reported by the host's separate mapping observer.
    pub fn reservedBytes(self: *const Threaded) usize {
        return @sizeOf(Threaded) + self.records.buffer.len + self.barriers.len * @sizeOf(std.Io.Future(void)) + self.workers * self.stack_bytes;
    }
    const Gate = struct {
        arrived: std.atomic.Value(usize) = .init(0),
        count: usize,
        ready: std.Io.Event = .unset,
        leave: std.Io.Event = .unset,
    };
    fn barrier(self: *Threaded, cleanup: ?*const fn () void) !void {
        const io_ = self.io();
        self.quiescent();
        var gate: Gate = .{ .count = self.workers };
        var started: usize = 0;
        defer {
            gate.leave.set(io_);
            for (self.barriers[0..started]) |*future| future.await(io_);
            self.quiescent();
        }
        // Every worker is simultaneously occupied before releasing the gate.
        // This warms a finite concurrency envelope, not data or query shapes.
        for (self.barriers) |*future| {
            future.* = try io_.concurrent(wait, .{ io_, &gate, cleanup });
            started += 1;
        }
        gate.ready.waitUncancelable(io_);
    }
    fn quiescent(self: *Threaded) void {
        // In this pinned runtime Future.await observes completion just before
        // the worker releases its busy count. All host futures are already
        // joined; wait for that finite tail under the runtime's own mutex.
        while (true) {
            std.Io.Threaded.mutexLock(&self.runtime.mutex);
            const idle = self.runtime.busy_count == 0;
            std.Io.Threaded.mutexUnlock(&self.runtime.mutex);
            if (idle) return;
            std.Thread.yield() catch {};
        }
    }
    fn wait(io_: std.Io, gate: *Gate, cleanup: ?*const fn () void) void {
        if (cleanup) |function| function();
        if (gate.arrived.fetchAdd(1, .acq_rel) + 1 == gate.count) gate.ready.set(io_);
        gate.leave.waitUncancelable(io_);
    }
    /// All host futures and groups must be joined first. Threaded teardown joins
    /// workers before their task allocator or borrowed host state can disappear.
    pub fn destroy(self: *Threaded) void {
        // Pinned Threaded detaches pthreads and waits for their worker loops,
        // not subsequent pthread TLS destructors. Finish foreign thread state
        // explicitly on each distinct worker while its owner is still alive.
        if (self.worker_cleanup != null) self.barrier(self.worker_cleanup) catch unreachable;
        self.runtime.deinit();
        self.parent.free(self.barriers);
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

test "numeric lookup preserves address family port canonical lifetime and closure" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const runtime = try Threaded.create(probe.allocator(), .{ .workers = 2, .task_bytes = 64 * 1024 });
    defer runtime.destroy();
    const io_ = runtime.io();
    probe.begin(true);
    for ([_][]const u8{ "127.0.0.1", "192.0.2.7", "::1", "2001:db8::7" }) |text| {
        const host: std.Io.net.HostName = .{ .bytes = text };
        var results: [2]std.Io.net.HostName.LookupResult = undefined;
        var queue: std.Io.Queue(std.Io.net.HostName.LookupResult) = .init(&results);
        var canonical: [std.Io.net.HostName.max_len]u8 = undefined;
        try host.lookup(io_, &queue, .{ .port = 5432, .canonical_name_buffer = &canonical });
        const address = (try queue.getOne(io_)).address;
        const expected = std.Io.net.IpAddress.parseIp4(text, 5432) catch try std.Io.net.IpAddress.parseIp6(text, 5432);
        try t.expectEqualDeep(expected, address);
        try t.expectEqualStrings(text, (try queue.getOne(io_)).canonical_name.bytes);
        try t.expectError(error.Closed, queue.getOne(io_));
        queue = .init(&results);
        try t.expectError(error.UnknownHostName, host.lookup(io_, &queue, .{ .port = 1, .family = if (address == .ip4) .ip6 else .ip4 }));
        try t.expectError(error.Closed, queue.getOne(io_));
    }
    try probe.verify();
}

const CleanupTest = struct {
    var calls: std.atomic.Value(usize) = .init(0);
    var ids: [4]std.Thread.Id = undefined;
    fn finish() void {
        const index = calls.fetchAdd(1, .acq_rel);
        std.debug.assert(index < ids.len);
        ids[index] = std.Thread.getCurrentId();
    }
};
test "foreign cleanup runs once on every distinct worker before reserve release" {
    const t = std.testing;
    CleanupTest.calls.store(0, .release);
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    const runtime = try Threaded.create(probe.allocator(), .{ .workers = 4, .task_bytes = 64 * 1024, .worker_cleanup = CleanupTest.finish });
    probe.begin(true);
    runtime.destroy();
    try probe.verify();
    try t.expectEqual(0, probe.live_bytes);
    try t.expectEqual(4, CleanupTest.calls.load(.acquire));
    for (CleanupTest.ids, 0..) |id, index| {
        try t.expect(id != std.Thread.getCurrentId());
        for (CleanupTest.ids[0..index]) |previous| try t.expect(id != previous);
    }
}
