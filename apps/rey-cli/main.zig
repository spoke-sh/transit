//! Explicit one-shot operations. Uncertain mutation outcomes require retrying
//! the exact saved request; the CLI never invents a new sequence automatically.
const std = @import("std");
const transit = wire.protocol;
const wire = @import("transit_client");
const observations = wire.observability;
const telemetry = observations.telemetry;
fn print(io: std.Io, value: anytype) !void {
    var buffer: [wire.max_body]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    try std.json.Stringify.value(value, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "rey-cli", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped", .level = .debug });
    diagnostics.event(.{ .name = "service.starting", .level = .debug });
    runMain(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn runMain(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 3 and std.mem.eql(u8, args[1], "public-key")) {
        const key = try wire.readKey(init.gpa, init.io, args[2]);
        return print(init.io, key.public_key.toBytes());
    }
    if (args.len < 4) return error.ExpectedSignSubmitOrViewWithKeyAndRequestFile;
    const command = args[1];
    const key = try wire.readKey(init.gpa, init.io, args[2]);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    if (std.mem.eql(u8, command, "state") or std.mem.eql(u8, command, "sign-state")) {
        var query = try std.json.parseFromSlice(transit.State.Query, init.gpa, bytes, .{});
        defer query.deinit();
        if (std.mem.eql(u8, command, "sign-state") and args.len == 4) return print(init.io, try transit.State.sign(query.value, key));
        if (args.len != 5) return error.ExpectedAuthorityUrl;
        var client = wire.Client.init(init.gpa, init.io, args[4]);
        defer client.deinit();
        client.observer = diagnostics;
        return print(init.io, try client.state(query.value, key));
    }
    if (std.mem.eql(u8, command, "inspect") or std.mem.eql(u8, command, "sign-inspection")) {
        var query = try std.json.parseFromSlice(transit.Inspection.Query, init.gpa, bytes, .{});
        defer query.deinit();
        if (std.mem.eql(u8, command, "sign-inspection") and args.len == 4) return print(init.io, try transit.Inspection.sign(query.value, key));
        if (args.len != 5) return error.ExpectedAuthorityUrl;
        var client = wire.Client.init(init.gpa, init.io, args[4]);
        defer client.deinit();
        client.observer = diagnostics;
        return print(init.io, try client.inspect(query.value, key));
    }
    var request = try std.json.parseFromSlice(transit.Request, init.gpa, bytes, .{});
    defer request.deinit();
    const signed = try transit.sign(request.value, key);
    if (std.mem.eql(u8, command, "sign") and args.len == 4) return print(init.io, signed);
    if (args.len != 5) return error.ExpectedAuthorityUrl;
    var client = wire.Client.init(init.gpa, init.io, args[4]);
    defer client.deinit();
    client.observer = diagnostics;
    if (std.mem.eql(u8, command, "submit")) return print(init.io, try client.submit(signed));
    if (std.mem.eql(u8, command, "view")) return print(init.io, try client.view(request.value, key));
    return error.UnknownCommand;
}
