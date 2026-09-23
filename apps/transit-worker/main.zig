//! Fixed M1 counter worker. Has a PID-scoped signing key and protocol access;
//! never imports Ursula, dispatches effects, or acquires its own ownership.
const std = @import("std");
const transit = wire.protocol;
const wire = @import("transit_client");
const Config = struct { url: []const u8, realm: u64, principal: u8, pid: u64, generation: u64 = 0, seed_file: ?[]const u8 = null };

fn run(client: *wire.Client, config: Config, key: transit.Ed25519.KeyPair, io: std.Io) !void {
    var session: wire.Session = .{ .client = client, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key };
    while (true) {
        const delivery = session.receive() catch |err| switch (err) {
            error.AccessDenied, error.Rejected, error.StaleActivation, error.BlockedProcess, error.InvalidAuthorityResponse => return err,
            else => {
                try io.sleep(.fromMilliseconds(200), .awake);
                continue;
            },
        };
        if (delivery) |input| {
            const pending = if (input.needs_permit) try session.prepareBegin(input) else commit: {
                const decision = compute: {
                    const state = input.state.asInteger() catch break :compute null;
                    const value = input.input.value.asInteger() catch break :compute null;
                    break :compute @import("counter").reduce(state, value) catch null;
                };
                break :commit try session.prepareCommit(input, .{
                    .state = if (decision) |d| transit.Value.integer(d.state) else input.state,
                    .failed = decision == null,
                });
            };
            while (true) {
                _ = pending.submit(client) catch |err| switch (err) {
                    error.AccessDenied, error.Rejected, error.InvalidAuthorityResponse => return err,
                    else => {
                        try io.sleep(.fromMilliseconds(200), .awake);
                        continue;
                    },
                };
                break;
            }
        } else try io.sleep(.fromMilliseconds(100), .awake);
    }
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const inline_config = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    if (args.len != 2 and !inline_config) return error.ExpectedConfig;
    const bytes = if (inline_config) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer if (!inline_config) init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    var config = parsed.value;
    if (inline_config and (config.seed_file != null or config.generation != 0)) return error.InvalidBootstrap;
    const key = if (config.seed_file) |path| try wire.readKey(init.gpa, init.io, path) else key: {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try transit.Ed25519.KeyPair.generateDeterministic(seed);
    };
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    if (config.seed_file == null) {
        // Public evidence only. The controller must read this from the current
        // provider worker and verify its incarnation before granting authority.
        var buffer: [1024]u8 = undefined;
        var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try std.json.Stringify.value(.{ .bootstrap = .{ .realm = config.realm, .pid = config.pid, .public_key = key.public_key.toBytes() } }, .{}, &writer.interface);
        try writer.interface.writeByte('\n');
        try writer.interface.flush();
        while (true) {
            const view = client.view(.{ .realm = config.realm, .principal = config.principal, .sequence = 0, .command = .{ .inspect = config.pid } }, key) catch {
                try init.io.sleep(.fromMilliseconds(200), .awake);
                continue;
            };
            if (view.process.lifecycle != .running) return error.StaleActivation;
            if (view.process.owner == config.principal and view.process.binding != null and view.process.binding.?.activation != null) {
                config.generation = view.process.generation;
                break;
            }
            try init.io.sleep(.fromMilliseconds(200), .awake);
        }
    }
    try run(&client, config, key, init.io);
}
