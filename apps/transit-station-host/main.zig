//! A small native port host. Protocol/behavior logic remains in the shared C
//! exports; host-language adapters only schedule and frame calls to these APIs.
const std = @import("std");
const abi = @import("station_abi");
const raw = @import("client_abi");
const s = @import("transit_station");
const host = abi.host;
const telemetry = s.client.observability.telemetry;
pub const std_options: std.Options = .{ .log_level = .err };

pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-station-host", try telemetry.Config.environment(init.environ_map));
    diagnostics.sink = .stderr();
    diagnostics.start();
    defer diagnostics.stop();
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .error_type = @errorName(err), .outcome = .failed });
        return err;
    };
    diagnostics.event(.{ .name = "service.stopped", .level = .info });
}
const readSeed = raw.host.readSeed;
const respond = raw.host.respond;
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedHostConfiguration;
    const config_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(8192));
    defer init.gpa.free(config_bytes);
    const parsed = try std.json.parseFromSlice(host.Config, init.gpa, config_bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.server != null and config.growing_server != null) return error.ConflictingHostProfiles;
    var server: ?*abi.Server = null;
    defer abi.Api.station_server_destroy(server);
    var growing: ?*abi.growing.Server = null;
    defer abi.Api.station_growing_destroy(growing);
    if (config.growing_server) |options| {
        var seed = try readSeed(init, config.seed_file orelse return error.MissingSeedFile);
        defer std.crypto.secureZero(u8, &seed);
        const json = try std.json.Stringify.valueAlloc(init.gpa, options, .{});
        defer init.gpa.free(json);
        if (abi.Api.station_growing_create(1, config.url.ptr, config.url.len, &seed, json.ptr, json.len, &growing) != .ok) return error.InvalidHostConfiguration;
        abi.growing.observe(growing.?, diagnostics);
    }
    if (config.server) |options| {
        var seed = try readSeed(init, config.seed_file orelse return error.MissingSeedFile);
        defer std.crypto.secureZero(u8, &seed);
        const json = try std.json.Stringify.valueAlloc(init.gpa, options, .{});
        defer init.gpa.free(json);
        if (abi.Api.station_server_create(1, config.url.ptr, config.url.len, &seed, json.ptr, json.len, &server) != .ok) return error.InvalidHostConfiguration;
        abi.observe(server.?, diagnostics);
    }
    var client: ?*raw.Client = null;
    defer raw.Api.transit_client_destroy(client);
    if (raw.Api.transit_client_create(1, config.url.ptr, config.url.len, config.timeout_ms, &client) != .ok) return error.InvalidHostConfiguration;
    raw.observe(client.?, diagnostics);
    const input_buffer = try init.gpa.alloc(u8, s.protocol.max_body * 2 + 16384);
    defer init.gpa.free(input_buffer);
    var input = std.Io.File.stdin().reader(init.io, input_buffer);
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    while (try input.interface.takeDelimiter('\n')) |line| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        const request = std.json.parseFromSlice(host.Request, arena.allocator(), line, .{}) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
            continue;
        };
        defer request.deinit();
        process(init, server, growing, client.?, request.value, arena.allocator(), &output.interface) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
        };
    }
}
fn process(init: std.process.Init, server: ?*abi.Server, growing: ?*abi.growing.Server, client: *raw.Client, request: host.Request, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    var buffer: ?*abi.Buffer = null;
    defer abi.Api.station_buffer_destroy(buffer);
    const status: abi.Status = switch (request) {
        .hello => return respond(out, 0, "{\"host_version\":1,\"station_version\":1,\"transit_version\":1}"),
        .next => |deadline| if (server) |pointer| abi.Api.station_server_next(pointer, deadline, &buffer) else .not_ready,
        .apply => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk if (server) |pointer| abi.Api.station_server_apply(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .finish => |failed| if (server) |pointer| abi.Api.station_server_finish(pointer, @intFromBool(failed)) else .not_ready,
        .pending => if (server) |pointer| abi.Api.station_server_pending(pointer, &buffer) else .not_ready,
        .growing_capabilities => abi.Api.station_growing_capabilities(&buffer),
        .growing_prepare => |deadline| if (growing) |pointer| abi.Api.station_growing_prepare(pointer, deadline, &buffer) else .not_ready,
        .growing_dispatch => if (growing) |pointer| abi.Api.station_growing_dispatch(pointer, &buffer) else .not_ready,
        .growing_apply => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action.action, .{});
            break :blk if (growing) |pointer| abi.Api.station_growing_apply(pointer, action.scope, json.ptr, json.len, &buffer) else .not_ready;
        },
        .growing_finish => |action| if (growing) |pointer| abi.Api.station_growing_finish(pointer, action.scope, @intFromBool(action.failed)) else .not_ready,
        .growing_discard => |scope| if (growing) |pointer| abi.Api.station_growing_discard(pointer, scope) else .not_ready,
        .growing_pending => if (growing) |pointer| abi.Api.station_growing_pending(pointer, &buffer) else .not_ready,
        .arrow_cell => |arrow| blk: {
            if (arrow.ipc.len > s.Query.max_bytes * 2) return error.InvalidArrowResult;
            var bytes: [s.Query.max_bytes]u8 = undefined;
            const decoded = try std.fmt.hexToBytes(&bytes, arrow.ipc);
            break :blk abi.Api.station_arrow_cell(decoded.ptr, decoded.len, arrow.row, arrow.column, &buffer);
        },
        .growing_arrow_cell => |arrow| blk: {
            if (arrow.ipc.len > s.GrowingQuery.records.segment_bytes * 2) return error.InvalidArrowResult;
            var bytes: [s.GrowingQuery.records.segment_bytes]u8 = undefined;
            const decoded = try std.fmt.hexToBytes(&bytes, arrow.ipc);
            break :blk abi.Api.station_growing_arrow_cell(decoded.ptr, decoded.len, arrow.row, arrow.column, &buffer);
        },
        .frame => |frame| abi.Api.station_frame_encode(frame.kind, try std.fmt.parseInt(u64, frame.correlation, 10), frame.payload.slice().ptr, frame.payload.len, &buffer),
        .prepare => |prepare| return raw.host.process(init, client, .{ .prepare = prepare }, allocator, out),
        .call => |frozen| return raw.host.process(init, client, .{ .call = frozen }, allocator, out),
        .metadata => |frozen| return raw.host.process(init, client, .{ .metadata = frozen }, allocator, out),
        .client_capabilities => return raw.host.process(init, client, .{ .capabilities = {} }, allocator, out),
    };
    if ((request == .pending or request == .growing_pending) and buffer != null) {
        const value = try std.json.Stringify.valueAlloc(allocator, abi.Api.station_buffer_data(buffer.?)[0..abi.Api.station_buffer_size(buffer.?)], .{});
        return respond(out, @backingInt(status), value);
    }
    try respond(out, @backingInt(status), if (buffer) |ptr| abi.Api.station_buffer_data(ptr)[0..abi.Api.station_buffer_size(ptr)] else "null");
}
