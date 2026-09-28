const std = @import("std");
const flight = @import("transit_flight");
const q = flight.query;
const gateway = flight.Gateway;
const telemetry = q.wire.observability.telemetry;
const Config = struct {
    url: []const u8,
    inspector: u64,
    inspector_seed_file: []const u8,
    ticket_seed_file: []const u8,
    listen: []const u8 = "127.0.0.1",
    port: u16,
    options: flight.grpc.Server.Options = .{},
    ticket_ttl_ms: u32 = 60000,
    clock_error_ms: u32 = 1000,
    native_timeout_ms: u32 = 5000,
    callers: []const struct {
        credential_file: []const u8,
        seed_file: []const u8,
        connection: q.Model.Connection,
        service: u64,
        binding_revision: u64,
        columns: [2][]const u8,
    },
};
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-flight-gateway", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedPrivateConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16384));
    defer init.gpa.free(bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    try config.options.validate();
    if (config.callers.len == 0 or config.callers.len > gateway.max_callers or config.port == 0) return error.InvalidFlightConfiguration;
    var callers: [gateway.max_callers]gateway.Caller = undefined;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&callers));
    for (config.callers, 0..) |caller, index| {
        const token = try std.Io.Dir.cwd().readFileAlloc(init.io, caller.credential_file, init.gpa, .limited(128));
        defer init.gpa.free(token);
        defer std.crypto.secureZero(u8, token);
        callers[index] = .{ .credential = try gateway.credentialHash(token), .key = try q.wire.readKey(init.gpa, init.io, caller.seed_file), .connection = caller.connection, .service = caller.service, .ingress_resource = caller.connection.requests, .binding_revision = caller.binding_revision, .schema = .{ .names = .{ try .init(caller.columns[0]), try .init(caller.columns[1]) }, .value_type = .int64 } };
    }
    var inspector_key = try q.wire.readKey(init.gpa, init.io, config.inspector_seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&inspector_key));
    var ticket_key = try q.wire.readKey(init.gpa, init.io, config.ticket_seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&ticket_key));
    var context: gateway = .{ .diagnostics = diagnostics, .config = .{ .url = config.url, .inspector = config.inspector, .inspector_key = inspector_key, .ticket_key = ticket_key, .callers = callers[0..config.callers.len], .ticket_ttl_ms = config.ticket_ttl_ms, .clock_error_ms = config.clock_error_ms, .native_timeout_ms = config.native_timeout_ms } };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&context));
    try context.config.validate();
    var listener = try (try std.Io.net.IpAddress.parseIp4(config.listen, config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    diagnostics.event(.{ .name = "service.ready", .operation = "flight" });
    try flight.grpc.Server.serve(init.io, init.gpa, &listener, config.options, &context);
}
