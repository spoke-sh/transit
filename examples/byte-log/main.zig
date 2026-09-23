//! Runnable byte-log example. Has a PID-scoped signing key and protocol access;
//! never imports Ursula, dispatches effects, or acquires its own ownership.
const std = @import("std");
const protocol = wire.protocol;
const handler = @import("handler.zig");
const wire = @import("transit_client");
const Config = struct { url: []const u8, realm: u64, principal: u8, pid: u64, generation: u64, seed_file: []const u8, publish_to: ?u64 = null };

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
            const pending = if (input.needs_permit) try session.prepareBegin(input) else commit: {
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
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const once = args.len == 3 and std.mem.eql(u8, args[1], "--once");
    if (args.len != 2 and !once) return error.ExpectedConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[if (once) 2 else 1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const key = try wire.readKey(init.gpa, init.io, config.seed_file);
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    try run(&client, config, key, init.io, once);
}
