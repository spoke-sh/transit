//! Public registration for a provider-verified worker. The caller supplies a
//! fresh in-memory key; only an external trusted controller grants activation.
const std = @import("std");
const wire = @import("root.zig");

/// Finite operator-placed growing worker registration. The expected generation
/// is fixed before launch; this helper never adopts an arbitrary later owner.
pub const GrowingRegistration = struct {
    version: u32 = 1,
    realm: u64,
    pid: u64,
    principal: u64,
    generation: u64,
    public_key: [32]u8,
};
fn growingOwned(process: wire.protocol.Growth.Process, principal: u64, generation: u64) !bool {
    switch (process.lifecycle) {
        .terminated => return error.ProcessTerminated,
        .expired => return error.ProcessExpired,
        .running => {},
    }
    if (process.failure != null) return error.BlockedProcess;
    if (process.generation > generation) return error.StaleActivation;
    if (process.generation < generation) return false;
    if (process.owner != principal) return error.StaleActivation;
    return true;
}
/// No provider calls, key persistence or authority mutation. A trusted operator
/// must authenticate the physical registration, grant this key/resource access
/// and record `own`. This is distinct from v1 provider-bound activation below.
pub fn awaitGrowingOwnership(client: *wire.Client, registration: GrowingRegistration, key: wire.protocol.Ed25519.KeyPair, timeout_ms: u32) !void {
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(client.http.io, &buffer);
    return growingOwnership(client, registration, key, timeout_ms, &writer.interface);
}

fn growingOwnership(client: *wire.Client, registration: GrowingRegistration, key: wire.protocol.Ed25519.KeyPair, timeout_ms: u32, output: *std.Io.Writer) !void {
    if (registration.version != 1 or registration.realm == 0 or registration.realm > wire.protocol.max_counter or registration.pid == 0 or registration.pid > wire.protocol.max_counter or registration.principal == 0 or registration.principal > wire.protocol.max_counter or registration.generation == 0 or registration.generation > wire.protocol.max_counter or timeout_ms == 0 or timeout_ms > 300000 or !std.mem.eql(u8, &registration.public_key, &key.public_key.toBytes())) return error.InvalidGrowingBootstrap;
    const io = client.http.io;
    const observer = client.observer;
    client.observer = null;
    defer client.observer = observer;
    const request_timeout = client.timeout_ms;
    defer client.timeout_ms = request_timeout;
    try std.json.Stringify.value(.{ .growing_bootstrap = registration }, .{}, output);
    try output.writeByte('\n');
    try output.flush();
    const started = std.Io.Clock.awake.now(io);
    while (true) {
        const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
        if (elapsed >= timeout_ms) return error.BootstrapTimeout;
        client.timeout_ms = @min(request_timeout, timeout_ms - @as(u32, @intCast(@max(0, elapsed))));
        const response = client.query(.{ .realm = registration.realm, .principal = registration.principal, .kind = .{ .process = registration.pid } }, key) catch |err| {
            if (err == error.AccessDenied or wire.Client.unavailable(err)) {
                try io.sleep(.fromMilliseconds(100), .awake);
                continue;
            }
            return err;
        };
        if (try growingOwned(response.body.process.process, registration.principal, registration.generation)) return;
        try io.sleep(.fromMilliseconds(100), .awake);
    }
}

test "growing bootstrap polls unavailable transport within one budget and emits one identity" {
    const t = std.testing;
    const Polls = struct {
        threaded: std.Io.Threaded,
        connections: std.atomic.Value(usize) = .init(0),

        fn connect(context: ?*anyopaque, _: *const std.Io.net.IpAddress, _: std.Io.net.IpAddress.ConnectOptions) std.Io.net.IpAddress.ConnectError!std.Io.net.Socket {
            const threaded: *std.Io.Threaded = @ptrCast(@alignCast(context));
            const self: *@This() = @fieldParentPtr("threaded", threaded);
            _ = self.connections.fetchAdd(1, .monotonic);
            return error.ConnectionRefused;
        }
    };
    var polls: Polls = .{ .threaded = .init(t.allocator, .{}) };
    defer polls.threaded.deinit();
    var io = polls.threaded.io();
    var vtable = io.vtable.*;
    vtable.netConnectIp = Polls.connect;
    io.vtable = &vtable;
    var client = wire.Client.init(t.allocator, io, "http://127.0.0.1:1");
    defer client.deinit();
    client.timeout_ms = 1000;
    const key = try wire.protocol.Ed25519.KeyPair.generateDeterministic(@splat(17));
    const registration: GrowingRegistration = .{ .realm = 42, .pid = 9, .principal = 65536, .generation = 5, .public_key = key.public_key.toBytes() };
    var output: std.Io.Writer.Allocating = .init(t.allocator);
    defer output.deinit();
    const started = std.Io.Clock.awake.now(io);
    try t.expectError(error.BootstrapTimeout, growingOwnership(&client, registration, key, 300, &output.writer));
    try t.expect(started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() < 2000);
    try t.expect(polls.connections.load(.monotonic) >= 2);
    try t.expectEqual(@as(u32, 1000), client.timeout_ms);
    try t.expectEqual(@as(usize, 1), std.mem.count(u8, output.written(), "\n"));
    const parsed = try std.json.parseFromSlice(struct { growing_bootstrap: GrowingRegistration }, t.allocator, output.written(), .{});
    defer parsed.deinit();
    try t.expectEqualDeep(registration, parsed.value.growing_bootstrap);
}

test "growing registration pins expected ownership without adopting successors" {
    const t = std.testing;
    var process: wire.protocol.Growth.Process = .{ .pid = 9, .code = 1, .generation = 4, .owner = 65536 };
    try t.expect(!try growingOwned(process, 65536, 5));
    process.generation = 5;
    try t.expect(try growingOwned(process, 65536, 5));
    try t.expectError(error.StaleActivation, growingOwned(process, 65537, 5));
    process.generation = 6;
    try t.expectError(error.StaleActivation, growingOwned(process, 65536, 5));
    process.lifecycle = .terminated;
    try t.expectError(error.ProcessTerminated, growingOwned(process, 65536, 6));
    process.lifecycle = .expired;
    try t.expectError(error.ProcessExpired, growingOwned(process, 65536, 6));
    process.lifecycle = .running;
    process.failure = 17;
    try t.expectError(error.BlockedProcess, growingOwned(process, 65536, 6));
}

pub fn awaitActivation(client: *wire.Client, realm: u64, pid: u64, principal: u64, key: wire.protocol.Ed25519.KeyPair) !u64 {
    const io = client.http.io;
    // Bootstrap logs have a bounded provider transport. Expected authentication
    // denials must not push the sole public registration out of that window.
    const observer = client.observer;
    client.observer = null;
    defer client.observer = observer;
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try std.json.Stringify.value(.{ .bootstrap = .{ .realm = realm, .pid = pid, .public_key = key.public_key.toBytes() } }, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
    while (true) {
        const response = client.query(.{ .realm = realm, .principal = principal, .kind = .{ .process = pid } }, key) catch {
            try io.sleep(.fromMilliseconds(200), .awake);
            continue;
        };
        const view = response.body.process;
        if (view.process.lifecycle != .running) return error.StaleActivation;
        if (view.process.owner == principal and view.process.binding != null and view.process.binding.?.activation != null) {
            // Pin exactly once. A later ownership change must fence this host,
            // never cause it to silently adopt another generation.
            return view.process.generation;
        }
        try io.sleep(.fromMilliseconds(200), .awake);
    }
}
