//! Runnable counter example. Has a PID-scoped signing key and protocol access;
//! never imports Ursula, dispatches effects, or acquires its own ownership.
const std = @import("std");
const protocol = wire.protocol;
const handler = @import("handler.zig");
const state = @import("state.zig");
const wire = @import("transit_client");
const observations = wire.observability;
const telemetry = observations.telemetry;
const Config = struct { url: []const u8, realm: u64, principal: u8, pid: u64, generation: u64 = 0, seed_file: ?[]const u8 = null, publish_to: ?u64 = null, state_association: ?[]const u8 = null };

fn run(client: *wire.Client, config: Config, key: protocol.Ed25519.KeyPair, io: std.Io, once: bool) !void {
    var session: wire.Session = .{ .client = client, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key };
    while (true) {
        const delivery = session.receive() catch |err| switch (err) {
            error.AccessDenied, error.Rejected, error.StaleActivation, error.BlockedProcess => return err,
            // Unusable responses grant no progress; refetch from the authority.
            else => {
                try io.sleep(.fromMilliseconds(200), .awake);
                continue;
            },
        };
        if (delivery) |input| {
            var failed = false;
            var computation = observations.begin(client.observer, .caller_turn, if (input.needs_permit) "begin_turn.prepare" else "turn.prepare", null);
            computation.event.realm = config.realm;
            computation.event.pid = config.pid;
            computation.event.generation = config.generation;
            computation.event.position = input.input.position;
            computation.event.outcome = .failed;
            const pending = prepared: {
                defer computation.finish();
                const value = if (input.needs_permit) try session.prepareBegin(input) else if (config.state_association) |name| resource: {
                    const proposal = try state.prepare(&session, input, name, config.publish_to, io);
                    failed = proposal.signed.request.command.state.turn.turn.failed;
                    break :resource proposal;
                } else commit: {
                    const result = handler.apply(input.state, input.input.value) catch null;
                    failed = result == null;
                    var outputs: [protocol.max_turn_outputs]?protocol.Output = @splat(null);
                    if (result) |value| if (config.publish_to) |pid| {
                        outputs[0] = .{ .pid = pid, .value = value };
                    };
                    break :commit try session.prepareCommit(input, .{
                        .state = result orelse input.state,
                        .failed = failed,
                        .outputs = outputs,
                    });
                };
                computation.event.outcome = if (failed) .failed else .ok;
                computation.event.error_type = if (failed) "HandlerFailed" else null;
                if (failed) computation.event.level = .warn;
                break :prepared value;
            };
            client.parent_context = computation.span.context;
            defer client.parent_context = null;
            while (true) {
                const receipt = pending.submit(client) catch |err| switch (err) {
                    error.AccessDenied, error.Rejected => return err,
                    // Lost or malformed acknowledgements leave the outcome
                    // uncertain. Retry the exact signed operation.
                    else => {
                        try io.sleep(.fromMilliseconds(200), .awake);
                        continue;
                    },
                };
                if (failed) return error.HandlerFailed;
                if (once and !input.needs_permit) {
                    var buffer: [128]u8 = undefined;
                    var out = std.Io.File.stdout().writerStreaming(io, &buffer);
                    try std.json.Stringify.value(receipt, .{}, &out.interface);
                    try out.interface.writeByte('\n');
                    try out.interface.flush();
                    return;
                }
                break;
            }
        } else if (once) return error.NoPendingInput else try io.sleep(.fromMilliseconds(100), .awake);
    }
}

pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "example-counter", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped", .level = .info });
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    runMain(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn runMain(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const inline_config = args.len == 3 and std.mem.eql(u8, args[1], "--bootstrap-json");
    const once = args.len == 3 and std.mem.eql(u8, args[1], "--once");
    if (args.len != 2 and !inline_config and !once) return error.ExpectedConfig;
    const bytes = if (inline_config) args[2] else try std.Io.Dir.cwd().readFileAlloc(init.io, args[if (once) 2 else 1], init.gpa, .limited(wire.max_body));
    defer if (!inline_config) init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    var config = parsed.value;
    if (inline_config and (config.seed_file != null or config.generation != 0)) return error.InvalidBootstrap;
    const key = if (config.seed_file) |path| try wire.readKey(init.gpa, init.io, path) else key: {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        break :key try protocol.Ed25519.KeyPair.generateDeterministic(seed);
    };
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
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
    var activation = observations.begin(diagnostics, .caller_activation, "configured", null);
    activation.event.realm = config.realm;
    activation.event.pid = config.pid;
    activation.event.generation = config.generation;
    activation.finish();
    try run(&client, config, key, init.io, once);
}
