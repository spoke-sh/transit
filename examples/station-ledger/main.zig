//! Reference Station caller. Credentials and provider placement stay outside
//! handlers; all state and messages use the public Transit protocol.
const std = @import("std");
const station = @import("transit_station");
const handler = @import("handler.zig");
const wire = station.client;
const telemetry = wire.observability.telemetry;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u8,
    pid: u64,
    generation: u64,
    seed_file: []const u8,
    association: []const u8 = "data",
    role: @FieldType(handler.Application, "role") = .ledger,
    destination: ?u64 = null,
    observer: ?u8 = null,
    registry: ?u64 = null,
};

pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "example-station-ledger", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    defer diagnostics.event(.{ .name = "service.stopped", .level = .info });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const once = args.len == 3 and std.mem.eql(u8, args[1], "--once");
    if (args.len != 2 and !once) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[if (once) 2 else 1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var key = try wire.readKey(init.gpa, init.io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    var behavior = try station.GenServer.init(.{
        .client = &client,
        .realm = config.realm,
        .principal = config.principal,
        .pid = config.pid,
        .generation = config.generation,
        .key = key,
    }, config.association);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&behavior.session.key));
    var application: handler.Application = .{ .role = config.role, .destination = config.destination, .observer = config.observer, .registry = config.registry };
    while (true) {
        const proposed_deadline: u64 = @intCast(std.Io.Clock.real.now(init.io).toMilliseconds() + 30_000);
        const result = behavior.step(application.behavior(), proposed_deadline) catch |err| switch (err) {
            error.AccessDenied, error.Rejected, error.Conflict, error.StaleActivation, error.BlockedProcess, error.MissingStateAssociation, error.RequiredStateAssociation, error.InvalidStateAssociation, error.MissingStateResource => return err,
            else => {
                diagnostics.event(.{ .name = "station.retry", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
                try init.io.sleep(.fromMilliseconds(100), .awake);
                continue;
            },
        };
        switch (result) {
            .idle => if (once) return error.NoPendingInput else try init.io.sleep(.fromMilliseconds(50), .awake),
            .progress => {},
            .blocked => return behavior.handler_error orelse error.BlockedProcess,
            .committed => {
                diagnostics.event(.{ .name = "station.turn", .level = .info, .outcome = .ok });
                if (once) return;
            },
        }
    }
}
