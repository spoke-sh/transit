//! Fixed M1 counter worker. Has a PID-scoped signing key and protocol access;
//! never imports Ursula, dispatches effects, or acquires its own ownership.
const std = @import("std");
const transit = wire.protocol;
const wire = @import("transit_client");
const Config = struct { url: []const u8, realm: u64, principal: u8, pid: u64, generation: u64 = 0, seed_file: ?[]const u8 = null };

fn run(client: *wire.Client, config: Config, key: transit.Ed25519.KeyPair, io: std.Io) !void {
    const read: transit.Request = .{ .realm = config.realm, .principal = config.principal, .sequence = 0, .command = .{ .inspect = config.pid } };
    while (true) {
        const view = client.view(read, key) catch |err| switch (err) {
            error.AccessDenied, error.Rejected => return err,
            else => {
                try io.sleep(.fromMilliseconds(200), .awake);
                continue;
            },
        };
        const p = view.process;
        if (p.lifecycle != .running or p.owner != config.principal or p.generation != config.generation) return error.StaleActivation;
        if (p.failure != null) return error.BlockedProcess;
        if (view.input) |input| {
            const command: transit.Command = if (p.work_before_ms != null and p.turn_permit == null)
                .{ .begin_turn = .{ .pid = p.pid, .generation = p.generation, .input = input.position } }
            else turn: {
                const decision = @import("counter").reduce(p.state, input.value) catch null;
                break :turn .{ .turn = .{
                    .pid = p.pid,
                    .generation = p.generation,
                    .input = input.position,
                    .permit = if (p.turn_permit) |permit| permit.id else null,
                    .result = if (decision) |d| d.state else p.state,
                    .failed = decision == null,
                } };
            };
            const signed = try transit.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = view.principal_sequence + 1, .command = command }, key);
            // An acknowledgement can be lost after durable acceptance. Hold this
            // exact request until its outcome is known; never redispatch effects.
            while (true) {
                _ = client.submit(signed) catch |err| switch (err) {
                    error.AccessDenied, error.Rejected => return err,
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
