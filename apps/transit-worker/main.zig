//! Fixed M1 counter worker. Has a PID-scoped signing key and protocol access;
//! never imports Ursula, dispatches effects, or acquires its own ownership.
const std = @import("std");
const transit = @import("transit");
const wire = @import("transit_client");
const Config = struct { url: []const u8, realm: u64, principal: u8, pid: u64, generation: u64, seed_file: []const u8 };

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
        if (view.input) |input| {
            const command: transit.Command = if (p.work_before_ms != null and p.turn_permit == null)
                .{ .begin_turn = .{ .pid = p.pid, .generation = p.generation, .input = input.position } }
            else
                .{ .turn = .{
                    .pid = p.pid,
                    .generation = p.generation,
                    .input = input.position,
                    .permit = if (p.turn_permit) |permit| permit.id else null,
                    .result = (try @import("counter").reduce(p.state, input.value)).state,
                } };
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
    if (args.len != 2) return error.ExpectedConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const key = try wire.readKey(init.gpa, init.io, config.seed_file);
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    try run(&client, config, key, init.io);
}
