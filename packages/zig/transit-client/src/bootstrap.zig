//! Public registration for a provider-verified worker. The caller supplies a
//! fresh in-memory key; only an external trusted controller grants activation.
const std = @import("std");
const wire = @import("root.zig");

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
