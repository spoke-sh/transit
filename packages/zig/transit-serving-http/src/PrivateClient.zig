//! Explicit private deployment admission for a shared viewer caller. This never
//! accepts a caller-supplied principal or forwards arbitrary native commands.
const std = @import("std");
const host = @import("root.zig");
const serving = @import("transit_serving");
const http = @import("transit_http_server");
const r = serving.ReactiveModel;
pub const Configuration = struct { principal: u64, seed_file: []const u8, snapshot_values: bool = false, refresh: bool = false };
pub fn handle(context: *host.Context, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request, attempt: *serving.ServingDiagnostic.Attempt) !void {
    var observation = context.diagnostics.begin(.service, null);
    var operation_name: ?[]const u8 = null;
    handleObserved(context, io, allocator, request, &operation_name, attempt) catch |err| {
        observation.finish(.{ .name = "serving.reactive.client", .operation = operation_name, .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
    observation.finish(.{ .name = "serving.reactive.client", .operation = operation_name, .level = .debug, .outcome = .ok });
}
fn handleObserved(context: *host.Context, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request, operation_name: *?[]const u8, attempt: *serving.ServingDiagnostic.Attempt) !void {
    const config = context.config.gateway;
    const viewer = config.viewer orelse return host.respond(attempt, request, .not_found, "{}");
    if (request.head.method != .POST or !std.mem.eql(u8, (try http.header(request, "origin")) orelse "", config.public_origin)) return error.ServingDenied;
    if (!std.mem.eql(u8, (try http.header(request, "content-type")) orelse "", "application/json")) return error.InvalidServingCommand;
    const index = try context.callerIndex(viewer.principal);
    // Request-head slices borrow the HTTP reader buffer; classify before reading the body.
    const control = std.mem.eql(u8, request.head.target, "/reactive/v1/client/control");
    const memory = try allocator.alloc(u8, 2 * 1024 * 1024);
    defer allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    const alloc = fixed.allocator();
    const body = try request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(r.max_message_bytes));
    const parsed = try serving.protocol.Json.parseFromSlice(serving.ReactiveClient.Request, alloc, body);
    const operation = parsed.value;
    operation_name.* = @tagName(operation);
    try attempt.label(if (operation == .submit or operation == .prepare or operation == .refresh_prepare) .control else .read, @tagName(operation));
    if (control and !try isControl(operation, attempt)) return error.InvalidServingCommand;
    if (!context.callers[index].acquire(control, if (control) 1 else config.per_caller_requests)) return error.ServingCallerCapacity;
    defer context.callers[index].release(control);
    const key = context.viewer_key orelse return error.ServingDenied;
    var wire = serving.station.client.Client.init(alloc, io, context.config.url);
    defer wire.deinit();
    wire.timeout_ms = context.config.request_timeout_ms;
    wire.observer = context.diagnostics;
    const base: serving.Adapter = .{ .resources = .{ .wire = &wire, .realm = context.config.realm, .principal = context.config.principal, .key = context.key }, .service = config.service, .ingress = config.ingress, .resource = config.resource, .diagnostic = attempt };
    const client: serving.ReactiveClient = .{ .wire = &wire, .connection = .{ .realm = context.config.realm, .principal = viewer.principal, .service = config.service, .ingress = config.ingress }, .key = key, .refresh = viewer.refresh };
    var clock: Clock = .{ .io = io, .error_ms = config.clock_error_ms };
    const reactive: serving.ReactiveAdapter = .{ .base = base, .clock = .{ .context = &clock, .upper = Clock.upper } };
    const result: serving.ReactiveClient.Response = switch (operation) {
        .describe => blk: {
            const signed = try serving.Model.SignedRead.sign(.{ .realm = client.connection.realm, .principal = viewer.principal, .service = config.service, .ingress = config.ingress, .kind = .discovery }, key);
            const discovery = try reactive.discovery(signed, key.public_key.toBytes(), alloc);
            var scoped = try base.readerFor(viewer.principal, &.{serving.Model.key('T', 0, 0)});
            const observed = try serving.ReactiveService.clock(&scoped.data);
            const upper = try Clock.upper(&clock);
            if (observed == 0 or observed > upper or upper - observed > 10000) return error.ClockUnavailable;
            break :blk .{ .description = .{ .connection = client.connection, .discovery = discovery, .observed_ms = observed } };
        },
        .clock => blk: {
            const observed = try client.observedClock(base);
            const upper = try Clock.upper(&clock);
            if (observed == 0 or observed > upper or upper - observed > 10000) return error.ClockUnavailable;
            break :blk .{ .clock = .{ .observed_ms = observed } };
        },
        .inspect => |read| try reactive.inspect(try client.signRead(read), key.public_key.toBytes()),
        .sign_read => |read| blk: {
            if (!viewer.snapshot_values and read.kind == .snapshot) return error.ServingDenied;
            break :blk try client.apply(base, operation);
        },
        .prepare => |command| blk: {
            if (!viewer.snapshot_values and command == .subscribe and command.subscribe.operation != 0) return error.ServingDenied;
            break :blk try client.apply(base, operation);
        },
        else => try client.apply(base, operation),
    };
    return host.respond(attempt, request, .ok, try serving.protocol.Json.valueAlloc(alloc, result));
}
const Clock = struct {
    io: std.Io,
    error_ms: u32,
    fn upper(raw: ?*anyopaque) !u64 {
        const self: *Clock = @ptrCast(@alignCast(raw.?));
        const now = std.Io.Clock.real.now(self.io).toMilliseconds();
        if (now < 0) return error.ClockUnavailable;
        return std.math.add(u64, @intCast(now), self.error_ms);
    }
};

fn isControl(request: serving.ReactiveClient.Request, attempt: *serving.ServingDiagnostic.Attempt) !bool {
    return switch (request) {
        .observe, .clock => true,
        .prepare => |command| serving.ReactiveWire.isControl(.{ .reactive = command.native() }),
        .refresh_prepare => |command| command == .pause,
        .submit => |signed| blk: {
            const frame = try serving.station.Frame.decode(signed.request.command.send.value);
            break :blk serving.ReactiveWire.isControl(try serving.ServingDiagnostic.decodeCommand(frame.payload, attempt));
        },
        else => false,
    };
}
