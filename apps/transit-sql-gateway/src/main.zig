const std = @import("std");
const host = @import("transit_sql_host");
const g = @import("transit_sql_service");
const telemetry = g.wire.observability.telemetry;
const Control = @import("Control.zig");
const Stop = @import("Stop.zig");
pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-sql-gateway", .info, run);
    if (status != 0) std.process.exit(status);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and std.mem.eql(u8, args[1], "--help")) {
        return std.Io.File.stdout().writeStreamingAll(init.io, "transit-sql-gateway CONFIG.json\n" ++
            "transit-sql-gateway control CONTROL.json list|status|cancel|credential [arguments]\n" ++
            "Database access and signed account recovery; see the configuration guide.\n");
    }
    if (args.len >= 2 and std.mem.eql(u8, args[1], "control")) return Control.run(init, args[2..], diagnostics);
    const stop = try Stop.init();
    defer stop.deinit();
    if (args.len != 2) return error.ExpectedPrivateConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(65536));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(g.Configuration, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = &parsed.value;
    try config.validate();
    const capacity = host.cryptoCapacity(config);
    const crypto = if (capacity != 0) try host.Crypto.create(init.gpa, capacity) else null;
    defer if (crypto) |owner| owner.destroy();
    var shutdown: host.Shutdown = .{};
    var relay = try init.io.concurrent(signal, .{ init.io, &shutdown });
    defer relay.cancel(init.io) catch {};
    return host.run(init, diagnostics, config, null, &shutdown, capacity);
}
fn signal(io: std.Io, shutdown: *host.Shutdown) !void {
    try Stop.wait(io);
    shutdown.request(io);
}
