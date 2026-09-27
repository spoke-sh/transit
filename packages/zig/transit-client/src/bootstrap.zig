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
/// and record `own`. This is distinct from v2 provider-bound activation below.
pub fn awaitGrowingOwnership(client: *wire.Client, registration: GrowingRegistration, key: wire.protocol.Ed25519.KeyPair, timeout_ms: u32) !void {
    if (registration.version != 1 or registration.realm == 0 or registration.realm > wire.protocol.max_counter or registration.pid == 0 or registration.pid > wire.protocol.max_counter or registration.principal == 0 or registration.principal > wire.protocol.max_counter or registration.generation == 0 or registration.generation > wire.protocol.max_counter or timeout_ms == 0 or timeout_ms > 300000 or !std.mem.eql(u8, &registration.public_key, &key.public_key.toBytes())) return error.InvalidGrowingBootstrap;
    const io = client.http.io;
    const observer = client.observer;
    client.observer = null;
    defer client.observer = observer;
    const request_timeout = client.timeout_ms;
    defer client.timeout_ms = request_timeout;
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try std.json.Stringify.value(.{ .growing_bootstrap = registration }, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
    const started = std.Io.Clock.awake.now(io);
    while (true) {
        const elapsed = started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds();
        if (elapsed >= timeout_ms) return error.BootstrapTimeout;
        client.timeout_ms = @min(request_timeout, timeout_ms - @as(u32, @intCast(@max(0, elapsed))));
        const response = client.queryGrowing(.{ .realm = registration.realm, .principal = registration.principal, .kind = .{ .process = registration.pid } }, key) catch |err| switch (err) {
            error.AccessDenied, error.AuthorityTimeout => {
                try io.sleep(.fromMilliseconds(100), .awake);
                continue;
            },
            else => return err,
        };
        if (try growingOwned(response.body.process.process, registration.principal, registration.generation)) return;
        try io.sleep(.fromMilliseconds(100), .awake);
    }
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

pub fn awaitActivation(client: *wire.Client, realm: u64, pid: u64, principal: u8, key: wire.protocol.Ed25519.KeyPair) !u64 {
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
        const view = client.view(.{ .realm = realm, .principal = principal, .sequence = 0, .command = .{ .inspect = pid } }, key) catch {
            try io.sleep(.fromMilliseconds(200), .awake);
            continue;
        };
        if (view.process.lifecycle != .running) return error.StaleActivation;
        if (view.process.owner == principal and view.process.binding != null and view.process.binding.?.activation != null) {
            // Pin exactly once. A later ownership change must fence this host,
            // never cause it to silently adopt another generation.
            return view.process.generation;
        }
        try io.sleep(.fromMilliseconds(200), .awake);
    }
}
