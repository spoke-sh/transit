//! Process-wide OpenSSL backing owner. Install before any OpenSSL use and keep
//! it until every context/session and every crypto-using worker has joined.
const std = @import("std");
const memory = @import("transit_memory");
const c = @import("OpenSsl.zig");
const Self = @This();
parent: std.mem.Allocator,
reserve: memory.Slab,
const prefix = memory.Slab.granule;
var owner: ?*Self = null;
var retired = false;

/// One installation per process. OpenSSL's global hooks cannot safely be
/// replaced while its objects exist; a foreign prior initialization rejects.
/// The caller serializes installation with all other OpenSSL access.
pub fn create(parent: std.mem.Allocator, capacity: usize) !*Self {
    if (owner != null or retired) return error.TlsMemoryAlreadyInitialized;
    const self = try parent.create(Self);
    errdefer parent.destroy(self);
    self.* = .{ .parent = parent, .reserve = try .init(parent, capacity) };
    errdefer self.reserve.deinit();
    owner = self;
    errdefer owner = null;
    if (c.CRYPTO_set_mem_functions(allocate, reallocate, release) != 1) return error.TlsMemoryAlreadyInitialized;
    return self;
}

/// Permanently shuts down OpenSSL in this process. Join crypto-using workers
/// first so their thread-local state is released through the live owner.
pub fn destroy(self: *Self) void {
    std.debug.assert(owner == self);
    c.OPENSSL_cleanup();
    owner = null;
    retired = true;
    self.reserve.deinit();
    self.parent.destroy(self);
}
pub fn reservedBytes(self: *const Self) usize {
    return @sizeOf(Self) + self.reserve.buffer.len;
}
/// End this worker's OpenSSL state before a detached runtime signals worker
/// completion. The host must prevent subsequent crypto work on this thread.
pub fn stopThread() void {
    c.OPENSSL_thread_stop();
}

fn bytes(pointer: *anyopaque) []align(prefix) u8 {
    const start: [*]align(prefix) u8 = @ptrFromInt(@intFromPtr(pointer) - prefix);
    const size: *const usize = @ptrCast(start);
    return start[0 .. prefix + size.*];
}
fn allocate(size: usize, _: ?[*:0]const u8, _: c_int) callconv(.c) ?*anyopaque {
    const self = owner orelse return null;
    const total = std.math.add(usize, prefix, @max(size, 1)) catch return null;
    const buffer = self.reserve.allocator().alignedAlloc(u8, .fromByteUnits(prefix), total) catch return null;
    @as(*usize, @ptrCast(buffer.ptr)).* = total - prefix;
    return buffer.ptr + prefix;
}
fn release(pointer: ?*anyopaque, _: ?[*:0]const u8, _: c_int) callconv(.c) void {
    const value = pointer orelse return;
    const self = owner orelse unreachable;
    const buffer = bytes(value);
    // OpenSSL frees public and private material through the same API. Erase
    // the old payload before its block can be admitted to another connection.
    std.crypto.secureZero(u8, buffer);
    // Avoid Allocator.free's debug poison overwriting the explicit erasure.
    self.reserve.allocator().rawFree(buffer, .fromByteUnits(prefix), @returnAddress());
}
fn reallocate(pointer: ?*anyopaque, size: usize, file: ?[*:0]const u8, line: c_int) callconv(.c) ?*anyopaque {
    const value = pointer orelse return allocate(size, file, line);
    if (size == 0) {
        release(value, file, line);
        return null;
    }
    const self = owner orelse return null;
    const old = bytes(value);
    const total = std.math.add(usize, prefix, size) catch return null;
    if (total <= old.len) {
        std.crypto.secureZero(u8, old[total..]);
        // A shrink keeps charged capacity until free; metadata retains its
        // allocation extent so no allocator receives a fabricated free length.
        return value;
    }
    if (self.reserve.allocator().resize(old, total)) {
        @as(*usize, @ptrCast(old.ptr)).* = size;
        return value;
    }
    const next = allocate(size, file, line) orelse return null;
    @memcpy(@as([*]u8, @ptrCast(next))[0 .. old.len - prefix], old[prefix..]);
    release(value, file, line);
    return next;
}

test "C allocation callbacks preserve failed reallocations and erase retired bytes" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var self: Self = .{ .parent = t.allocator, .reserve = try .init(probe.allocator(), 4096) };
    defer self.reserve.deinit();
    // Exercise callbacks without installing global OpenSSL hooks in the shared
    // unit process. The separate TLS probe qualifies real library allocations.
    std.debug.assert(owner == null);
    owner = &self;
    defer owner = null;
    probe.begin(true);
    for (0..100) |_| {
        const first = allocate(128, null, 0) orelse return error.OutOfMemory;
        @memset(@as([*]u8, @ptrCast(first))[0..128], 0x71);
        const held = allocate(128, null, 0) orelse return error.OutOfMemory;
        defer release(held, null, 0);
        try t.expect(reallocate(first, std.math.maxInt(usize), null, 0) == null);
        try t.expect(reallocate(first, 4096, null, 0) == null);
        try t.expect(std.mem.allEqual(u8, @as([*]u8, @ptrCast(first))[0..128], 0x71));
        const grown = reallocate(first, 512, null, 0) orelse return error.OutOfMemory;
        try t.expect(std.mem.allEqual(u8, @as([*]u8, @ptrCast(grown))[0..128], 0x71));
        const shrunk = reallocate(grown, 32, null, 0) orelse return error.OutOfMemory;
        try t.expect(std.mem.allEqual(u8, bytes(shrunk)[prefix + 32 ..], 0));
        const old = bytes(shrunk);
        release(shrunk, null, 0);
        try t.expect(std.mem.allEqual(u8, old, 0));
    }
    try probe.verify();
}

fn concurrentBorrower(id: usize) void {
    for (0..1000) |iteration| {
        const count = 1 + (iteration * 37 + id * 17) % 2048;
        const value = allocate(count, null, 0) orelse @panic("missing admitted crypto capacity");
        const payload: [*]u8 = @ptrCast(value);
        @memset(payload[0..count], @truncate(iteration));
        const next = reallocate(value, count + 513, null, 0) orelse @panic("missing admitted crypto growth capacity");
        std.debug.assert(std.mem.allEqual(u8, @as([*]u8, @ptrCast(next))[0..count], @truncate(iteration)));
        release(next, null, 0);
    }
}
test "concurrent crypto borrowers share one fixed reserve" {
    const t = std.testing;
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var self: Self = .{ .parent = t.allocator, .reserve = try .init(probe.allocator(), 128 * 1024) };
    defer self.reserve.deinit();
    std.debug.assert(owner == null);
    owner = &self;
    defer owner = null;
    probe.begin(true);
    var workers: [4]std.Thread = undefined;
    var started: usize = 0;
    {
        defer for (workers[0..started]) |worker| worker.join();
        for (&workers, 0..) |*worker, id| {
            worker.* = try std.Thread.spawn(.{}, concurrentBorrower, .{id});
            started += 1;
        }
    }
    try t.expectEqual(0, self.reserve.live_bytes);
    try probe.verify();
}

fn rejectedInstallation(allocator: std.mem.Allocator) !void {
    const unexpected = create(allocator, 4096) catch |err| switch (err) {
        error.TlsMemoryAlreadyInitialized => return,
        else => return err,
    };
    unexpected.destroy();
    return error.ExpectedForeignTlsMemoryRefusal;
}
test "foreign crypto initialization refuses hooks and releases partial admission" {
    const context = c.SSL_CTX_new(c.TLS_server_method()) orelse return error.TlsAllocationFailed;
    defer c.SSL_CTX_free(context);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, rejectedInstallation, .{});
    try std.testing.expect(owner == null);
}
