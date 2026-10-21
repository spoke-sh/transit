//! Standalone raw-client port; deliberately has no Station dependency.
const std = @import("std");
const abi = @import("client_abi");
const host = abi.host;
const telemetry = @import("transit_client").observability.telemetry;
pub const std_options: std.Options = .{ .log_level = .err };

pub fn main(init: std.process.Init) !void {
    const status = telemetry.runService(init, "transit-client-host", .info, run);
    if (status != 0) std.process.exit(status);
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedHostConfiguration;
    const config_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(host.max_config_bytes));
    defer init.gpa.free(config_bytes);
    const config = try std.json.parseFromSlice(host.Config, init.gpa, config_bytes, .{});
    defer config.deinit();
    var client: ?*abi.Client = null;
    defer abi.Api.transit_client_destroy(client);
    if (abi.Api.transit_client_create(1, config.value.url.ptr, config.value.url.len, config.value.timeout_ms, &client) != .ok) return error.InvalidHostConfiguration;
    abi.observe(client.?, diagnostics);
    const input_buffer = try init.gpa.alloc(u8, host.max_line_bytes);
    defer init.gpa.free(input_buffer);
    var input = std.Io.File.stdin().reader(init.io, input_buffer);
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    while (try input.interface.takeDelimiter('\n')) |line| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const request = std.json.parseFromSlice(host.Request, arena.allocator(), line, .{}) catch |err| {
            try host.respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
            continue;
        };
        defer request.deinit();
        if (request.value == .shutdown) {
            abi.Api.transit_client_destroy(client);
            client = null;
            try host.respond(&output.interface, 0, "{\"closed\":true}");
            return;
        }
        host.process(init, client.?, request.value, arena.allocator(), &output.interface) catch |err| {
            try host.respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
        };
    }
}
