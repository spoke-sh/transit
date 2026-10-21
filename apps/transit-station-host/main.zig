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
    const status = telemetry.runService(init, "transit-station-host", .info, run);
    if (status != 0) std.process.exit(status);
}
const readSeed = raw.host.readSeed;
const respond = raw.host.respond;
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedHostConfiguration;
    const config_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(raw.host.max_config_bytes));
    defer init.gpa.free(config_bytes);
    const parsed = try std.json.parseFromSlice(host.Config, init.gpa, config_bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    try config.validateProfiles();
    var catalog_client: ?*abi.catalog_client.Client = null;
    defer abi.Api.station_catalog_destroy(catalog_client);
    if (config.catalog_client) |options| {
        // This new profile enforces its reflected schema at both JSON inputs.
        const checked = try s.protocol.Json.parseFromSlice(host.Config, init.gpa, config_bytes);
        defer checked.deinit();
        var seed = try readSeed(init, config.seed_file orelse return error.MissingSeedFile);
        defer std.crypto.secureZero(u8, &seed);
        const json = try s.protocol.Json.valueAlloc(init.gpa, options);
        defer init.gpa.free(json);
        const url = config.url.?;
        if (abi.Api.station_catalog_create(1, url.ptr, url.len, &seed, json.ptr, json.len, &catalog_client) != .ok) return error.InvalidHostConfiguration;
        abi.catalog_client.observe(catalog_client.?, diagnostics);
    }
    var query_client: ?*abi.query_client.Client = null;
    defer abi.Api.station_unified_query_destroy(query_client);
    if (config.query_client) |options| {
        var seed = try readSeed(init, config.seed_file orelse return error.MissingSeedFile);
        defer std.crypto.secureZero(u8, &seed);
        const json = try std.json.Stringify.valueAlloc(init.gpa, options, .{});
        defer init.gpa.free(json);
        const url = config.url.?;
        if (abi.Api.station_unified_query_create(1, url.ptr, url.len, &seed, json.ptr, json.len, &query_client) != .ok) return error.InvalidHostConfiguration;
        abi.query_client.observe(query_client.?, diagnostics);
    }
    var growing: ?*abi.growing.Server = null;
    defer abi.Api.station_growing_destroy(growing);
    if (config.growing_server) |options| {
        var seed = try readSeed(init, config.seed_file orelse return error.MissingSeedFile);
        defer std.crypto.secureZero(u8, &seed);
        const json = try std.json.Stringify.valueAlloc(init.gpa, options, .{});
        defer init.gpa.free(json);
        const url = config.url.?;
        if (abi.Api.station_growing_create(1, url.ptr, url.len, &seed, json.ptr, json.len, &growing) != .ok) return error.InvalidHostConfiguration;
        abi.growing.observe(growing.?, diagnostics);
    }
    var client: ?*raw.Client = null;
    defer raw.Api.transit_client_destroy(client);
    if (config.url) |url| {
        if (raw.Api.transit_client_create(1, url.ptr, url.len, config.timeout_ms, &client) != .ok) return error.InvalidHostConfiguration;
        raw.observe(client.?, diagnostics);
    }
    var input_buffer: [16384]u8 = undefined;
    var input = std.Io.File.stdin().reader(init.io, &input_buffer);
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    while (try host.readLine(init.gpa, &input.interface, host.lineBytes(catalog_client != null))) |line| {
        defer init.gpa.free(line);
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        if (catalog_client != null) s.fuze.Types.Json.preflight(line, .{ .bytes = host.catalog_line_bytes, .depth = 97, .tokens = 1024 * 1024, .fields = 256 }) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
            continue;
        };
        const request = (if (catalog_client != null) s.protocol.Json.parseFromSlice(host.Request, arena.allocator(), line) else std.json.parseFromSlice(host.Request, arena.allocator(), line, .{})) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
            continue;
        };
        defer request.deinit();
        if (request.value == .shutdown) {
            abi.Api.station_growing_destroy(growing);
            growing = null;
            abi.Api.station_unified_query_destroy(query_client);
            query_client = null;
            abi.Api.station_catalog_destroy(catalog_client);
            catalog_client = null;
            raw.Api.transit_client_destroy(client);
            client = null;
            try respond(&output.interface, 0, "{\"closed\":true}");
            return;
        }
        process(init, growing, query_client, catalog_client, client, request.value, arena.allocator(), &output.interface) catch |err| {
            try respond(&output.interface, 1, try std.json.Stringify.valueAlloc(arena.allocator(), .{ .err = @errorName(err) }, .{}));
        };
    }
}
fn process(init: std.process.Init, growing: ?*abi.growing.Server, query_client: ?*abi.query_client.Client, catalog_client: ?*abi.catalog_client.Client, client: ?*raw.Client, request: host.Request, allocator: std.mem.Allocator, out: *std.Io.Writer) !void {
    var buffer: ?*abi.Buffer = null;
    defer abi.Api.station_buffer_destroy(buffer);
    const status: abi.Status = switch (request) {
        .shutdown => return error.ShutdownRequiresOwner,
        .hello => return respond(out, 0, "{\"host_version\":1,\"station_version\":1,\"transit_version\":1}"),
        .growing_capabilities => abi.Api.station_growing_capabilities(&buffer),
        .http_codec => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk abi.Api.station_http_codec(json.ptr, json.len, &buffer);
        },
        .growing_http_read => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk if (growing) |pointer| abi.Api.station_growing_http_read(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .growing_document_read => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            defer allocator.free(json);
            break :blk if (growing) |pointer| abi.Api.station_growing_document_read(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .unified_query_codec => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk abi.Api.station_unified_query_codec(json.ptr, json.len, &buffer);
        },
        .logical_codec => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk abi.Api.station_logical_codec(json.ptr, json.len, &buffer);
        },
        .unified_query => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk if (query_client) |pointer| abi.Api.station_unified_query_call(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .catalog => |action| blk: {
            const json = try s.protocol.Json.valueAlloc(allocator, action);
            break :blk if (catalog_client) |pointer| abi.Api.station_catalog_call(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .document_codec => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk abi.Api.station_document_codec(json.ptr, json.len, &buffer);
        },
        .grpc_codec => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk abi.Api.station_grpc_codec(json.ptr, json.len, &buffer);
        },
        .growing_grpc_read => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action, .{});
            break :blk if (growing) |pointer| abi.Api.station_growing_grpc_read(pointer, json.ptr, json.len, &buffer) else .not_ready;
        },
        .growing_prepare => |deadline| if (growing) |pointer| abi.Api.station_growing_prepare(pointer, deadline, &buffer) else .not_ready,
        .growing_dispatch => if (growing) |pointer| abi.Api.station_growing_dispatch(pointer, &buffer) else .not_ready,
        .growing_confirmation => if (growing) |pointer| abi.Api.station_growing_confirmation(pointer, &buffer) else .not_ready,
        .growing_apply => |action| blk: {
            const json = try std.json.Stringify.valueAlloc(allocator, action.action, .{});
            break :blk if (growing) |pointer| abi.Api.station_growing_apply(pointer, action.scope, json.ptr, json.len, &buffer) else .not_ready;
        },
        .growing_finish => |action| if (growing) |pointer| abi.Api.station_growing_finish(pointer, action.scope, @intFromBool(action.failed)) else .not_ready,
        .growing_finish_result => |action| if (growing) |pointer| abi.Api.station_growing_finish_result(pointer, action.scope, @intFromBool(action.failed), &buffer) else .not_ready,
        .growing_discard => |scope| if (growing) |pointer| abi.Api.station_growing_discard(pointer, scope) else .not_ready,
        .growing_pending => if (growing) |pointer| abi.Api.station_growing_pending(pointer, &buffer) else .not_ready,
        .growing_arrow_cell => |arrow| blk: {
            if (arrow.ipc.len > s.Query.records.segment_bytes * 2) return error.InvalidArrowResult;
            var bytes: [s.Query.records.segment_bytes]u8 = undefined;
            const decoded = try std.fmt.hexToBytes(&bytes, arrow.ipc);
            break :blk abi.Api.station_growing_arrow_cell(decoded.ptr, decoded.len, arrow.row, arrow.column, &buffer);
        },
        .frame => |frame| abi.Api.station_frame_encode(frame.kind, try std.fmt.parseInt(u64, frame.correlation, 10), frame.payload.slice().ptr, frame.payload.len, &buffer),
        .prepare => |prepare| if (client) |pointer| return raw.host.process(init, pointer, .{ .prepare = prepare }, allocator, out) else .not_ready,
        .call => |frozen| if (client) |pointer| return raw.host.process(init, pointer, .{ .call = frozen }, allocator, out) else .not_ready,
        .metadata => |frozen| if (client) |pointer| return raw.host.process(init, pointer, .{ .metadata = frozen }, allocator, out) else .not_ready,
        .client_capabilities => if (client) |pointer| return raw.host.process(init, pointer, .{ .capabilities = {} }, allocator, out) else .not_ready,
    };
    if (request == .growing_pending and buffer != null) {
        const value = try std.json.Stringify.valueAlloc(allocator, abi.Api.station_buffer_data(buffer.?)[0..abi.Api.station_buffer_size(buffer.?)], .{});
        return respond(out, @backingInt(status), value);
    }
    try respond(out, @backingInt(status), if (buffer) |ptr| abi.Api.station_buffer_data(ptr)[0..abi.Api.station_buffer_size(ptr)] else "null");
}
