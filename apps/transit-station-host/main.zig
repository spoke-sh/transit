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
fn readSeed(init: std.process.Init, path: []const u8) ![32]u8 {
    const text = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128));
    defer {
        std.crypto.secureZero(u8, text);
        init.gpa.free(text);
    }
    const trimmed = std.mem.trim(u8, text, " \r\n\t");
    if (trimmed.len != 64) return error.InvalidSeed;
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, trimmed);
    return seed;
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedHostConfiguration;
    const config_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(8192));
    defer init.gpa.free(config_bytes);
    const parsed = try std.json.parseFromSlice(host.Config, init.gpa, config_bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var server: ?*abi.Server = null;
    defer abi.Api.station_server_destroy(server);
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
        process(init, server, client.?, request.value, arena.allocator(), &output.interface) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
        };
    }
}
fn respond(out: *std.Io.Writer, status: u32, value: []const u8) !void {
    try out.print("{{\"status\":{d},\"value\":", .{status});
    try out.writeAll(value);
    try out.writeAll("}\n");
    try out.flush();
}
fn process(init: std.process.Init, server: ?*abi.Server, client: *raw.Client, request: host.Request, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
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
        .arrow_cell => |arrow| blk: {
            if (arrow.ipc.len > s.Query.max_bytes * 2) return error.InvalidArrowResult;
            var bytes: [s.Query.max_bytes]u8 = undefined;
            const decoded = try std.fmt.hexToBytes(&bytes, arrow.ipc);
            break :blk abi.Api.station_arrow_cell(decoded.ptr, decoded.len, arrow.row, arrow.column, &buffer);
        },
        .frame => |frame| abi.Api.station_frame_encode(frame.kind, try std.fmt.parseInt(u64, frame.correlation, 10), frame.payload.slice().ptr, frame.payload.len, &buffer),
        .prepare => |prepare| {
            var seed = try readSeed(init, prepare.seed_file);
            defer std.crypto.secureZero(u8, &seed);
            var operation: ?*raw.Operation = null;
            defer raw.Api.transit_operation_destroy(operation);
            var result = raw.Api.transit_operation_prepare(prepare.kind, &seed, prepare.document.ptr, prepare.document.len, &operation);
            var frozen: ?*raw.Buffer = null;
            defer raw.Api.transit_buffer_destroy(frozen);
            if (result == .ok) result = raw.Api.transit_operation_export(operation.?, &frozen);
            const value = if (frozen) |ptr| try std.json.Stringify.valueAlloc(allocator, raw.Api.transit_buffer_data(ptr)[0..raw.Api.transit_buffer_size(ptr)], .{}) else "null";
            return respond(out, @backingInt(result), value);
        },
        .call => |frozen| {
            var operation: ?*raw.Operation = null;
            defer raw.Api.transit_operation_destroy(operation);
            var result = raw.Api.transit_operation_import(frozen.ptr, frozen.len, &operation);
            var response: ?*raw.Buffer = null;
            defer raw.Api.transit_buffer_destroy(response);
            if (result == .ok) result = raw.Api.transit_client_call(client, operation.?, &response);
            return respond(out, @backingInt(result), if (response) |ptr| raw.Api.transit_buffer_data(ptr)[0..raw.Api.transit_buffer_size(ptr)] else "null");
        },
    };
    if (request == .pending and buffer != null) {
        const value = try std.json.Stringify.valueAlloc(allocator, abi.Api.station_buffer_data(buffer.?)[0..abi.Api.station_buffer_size(buffer.?)], .{});
        return respond(out, @backingInt(status), value);
    }
    try respond(out, @backingInt(status), if (buffer) |ptr| abi.Api.station_buffer_data(ptr)[0..abi.Api.station_buffer_size(ptr)] else "null");
}
