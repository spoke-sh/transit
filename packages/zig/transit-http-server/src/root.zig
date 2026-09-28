//! Neutral bounded HTTP mechanics. No Transit identity, grant or durable state.
const std = @import("std");
const Io = std.Io;
pub const WebSocket = @import("WebSocket.zig");
test {
    _ = WebSocket;
}
pub const Options = struct {
    connections: u8 = 16,
    requests: u8 = 8,
    control_requests: u8 = 2,
    header_timeout_ms: u32 = 1000,
    request_timeout_ms: u32 = 5000,

    pub fn validate(self: Options) !void {
        if (self.connections < 2 or self.connections > 64 or self.requests == 0 or self.control_requests == 0 or
            @as(u16, self.requests) + self.control_requests > self.connections or self.header_timeout_ms == 0 or
            self.header_timeout_ms > self.request_timeout_ms or self.request_timeout_ms > 300000) return error.InvalidHttpLimits;
    }
};

pub const Admission = struct {
    data: std.atomic.Value(usize) = .init(0),
    control: std.atomic.Value(usize) = .init(0),
    pub fn acquire(self: *Admission, control: bool, limit: usize) bool {
        const count = if (control) &self.control else &self.data;
        var old = count.load(.monotonic);
        while (old < limit) old = count.cmpxchgWeak(old, old + 1, .acquire, .monotonic) orelse return true;
        return false;
    }
    pub fn release(self: *Admission, control: bool) void {
        const count = if (control) &self.control else &self.data;
        std.debug.assert(count.fetchSub(1, .release) > 0);
    }
};

/// Single-valued security/framing headers never use first/last-wins parsing.
pub fn header(request: *std.http.Server.Request, name: []const u8) !?[]const u8 {
    var headers = request.iterateHeaders();
    var value: ?[]const u8 = null;
    while (headers.next()) |entry| if (std.ascii.eqlIgnoreCase(entry.name, name)) {
        if (value != null) return error.DuplicateHeader;
        value = entry.value;
    };
    return value;
}

pub fn validateHead(request: *std.http.Server.Request) !void {
    if (request.head.version != .@"HTTP/1.1") return error.UnsupportedHttpVersion;
    const host = (try header(request, "host")) orelse return error.MissingHost;
    if (host.len == 0 or host.len > 200 or std.mem.indexOfAny(u8, host, "/@?#\\\r\n\t ,") != null) return error.InvalidHost;
    if (request.head.target.len == 0 or request.head.target.len > 1024 or request.head.target[0] != '/' or
        std.mem.indexOfAny(u8, request.head.target, "#\\\r\n\t ") != null) return error.InvalidTarget;
    const length = try header(request, "content-length");
    const transfer = try header(request, "transfer-encoding");
    if (length != null and transfer != null) return error.AmbiguousFraming;
    if (transfer) |value| if (!std.ascii.eqlIgnoreCase(value, "chunked")) return error.UnsupportedTransferEncoding;
    if (try header(request, "content-encoding")) |value| if (!std.ascii.eqlIgnoreCase(value, "identity")) return error.UnsupportedContentEncoding;
    if (try header(request, "expect") != null) return error.UnsupportedExpectation;
    for ([_][]const u8{ "origin", "authorization", "content-type", "upgrade" }) |name| _ = try header(request, name);
}

pub fn respond(request: *std.http.Server.Request, status: std.http.Status, body: []const u8) !void {
    try request.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = &.{
        .{ .name = "content-type", .value = "application/json" },
        .{ .name = "cache-control", .value = "no-store" },
        .{ .name = "x-content-type-options", .value = "nosniff" },
    } });
}

fn timeout(io: Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}

/// Joins both branches before returning, including scheduling failure. The
/// function owns no retry policy; a deadline never changes durable outcomes.
pub fn deadline(io: Io, milliseconds: u32, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !void {
    const Result = union(enum) { completed: anyerror!void, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var select: Io.Select(Result) = .init(io, &results);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{ io, milliseconds });
    try select.concurrent(.completed, function, args);
    switch (try select.await()) {
        .completed => |result| try result,
        .timeout => |result| {
            try result;
            return error.HttpDeadline;
        },
    }
}

fn receive(server: *std.http.Server, request: *?std.http.Server.Request) anyerror!void {
    request.* = try server.receiveHead();
}

/// Context.handle(io, allocator, request) is called concurrently. It must own
/// per-request state and coordinate shared mutations. The optional
/// Context.isControl(request) classifies additional bounded control routes.
/// Application authorization remains mandatory on every such route.
/// Context.connectionError(error, handler_started) observes failed transports, without payloads.
pub fn serve(io: Io, allocator: std.mem.Allocator, listener: *Io.net.Server, options: Options, context: anytype) !void {
    try options.validate();
    const Worker = struct {
        done: std.atomic.Value(bool) = .init(true),
        future: ?Io.Future(void) = null,

        fn run(slot: *@This(), worker_io: Io, alloc: std.mem.Allocator, stream: Io.net.Stream, limits: Options, admission: *Admission, ctx: @TypeOf(context)) void {
            defer slot.done.store(true, .release);
            defer stream.close(worker_io);
            var handler_started = false;
            connection(worker_io, alloc, stream, limits, admission, ctx, &handler_started) catch |err| ctx.connectionError(err, handler_started);
        }
        fn connection(worker_io: Io, alloc: std.mem.Allocator, stream: Io.net.Stream, limits: Options, admission: *Admission, ctx: @TypeOf(context), handler_started: *bool) !void {
            const started = Io.Clock.awake.now(worker_io);
            var input: [8192]u8 = undefined;
            var output: [4096]u8 = undefined;
            var reader = stream.reader(worker_io, &input);
            var writer = stream.writer(worker_io, &output);
            var server = std.http.Server.init(&reader.interface, &writer.interface);
            var request: ?std.http.Server.Request = null;
            try deadline(worker_io, limits.header_timeout_ms, receive, .{ &server, &request });
            const elapsed = started.durationTo(Io.Clock.awake.now(worker_io)).toMilliseconds();
            const remaining: u32 = @intCast(@max(1, @as(i64, limits.request_timeout_ms) - elapsed));
            try deadline(worker_io, remaining, dispatch, .{ worker_io, alloc, &request.?, limits, admission, ctx, handler_started });
        }
        fn dispatch(worker_io: Io, alloc: std.mem.Allocator, request: *std.http.Server.Request, limits: Options, admission: *Admission, ctx: @TypeOf(context), handler_started: *bool) anyerror!void {
            validateHead(request) catch return respond(request, .bad_request, "{\"err\":\"InvalidHttpRequest\"}");
            const control = (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) or
                (if (@hasDecl(@typeInfo(@TypeOf(ctx)).pointer.child, "isControl")) ctx.isControl(request) else false);
            if (!admission.acquire(control, if (control) limits.control_requests else limits.requests))
                return respond(request, .service_unavailable, "{\"err\":\"HttpCapacity\"}");
            defer admission.release(control);
            // Each consumer enforces its own parse/output/compute allocation
            // budget; the neutral server allocates no request-body collection.
            handler_started.* = true;
            try ctx.handle(worker_io, alloc, request);
        }
    };
    const slots = try allocator.alloc(Worker, options.connections);
    defer allocator.free(slots);
    for (slots) |*slot| slot.* = .{};
    defer for (slots) |*slot| if (slot.future) |*future| future.cancel(io);
    var admission: Admission = .{};
    while (true) {
        const stream = try listener.accept(io);
        const slot = for (slots) |*candidate| {
            if (candidate.done.load(.acquire)) break candidate;
        } else {
            // No task/queue allocation on exhaustion. The peer observes a
            // closed transport, never an acceptance or a fabricated rejection.
            stream.close(io);
            context.connectionError(error.HttpCapacity, false);
            continue;
        };
        if (slot.future) |*future| future.await(io);
        slot.done.store(false, .release);
        slot.future = Io.concurrent(io, Worker.run, .{ slot, io, allocator, stream, options, &admission, context }) catch |err| {
            slot.done.store(true, .release);
            slot.future = null;
            stream.close(io);
            context.connectionError(err, false);
            continue;
        };
    }
}

test "data exhaustion preserves the separately bounded control reserve" {
    var admission: Admission = .{};
    try std.testing.expect(admission.acquire(false, 1));
    try std.testing.expect(!admission.acquire(false, 1));
    try std.testing.expect(admission.acquire(true, 1));
    try std.testing.expect(!admission.acquire(true, 1));
    admission.release(false);
    try std.testing.expect(admission.acquire(false, 1));
    admission.release(false);
    admission.release(true);
    try (Options{}).validate();
    try std.testing.expectError(error.InvalidHttpLimits, (Options{ .connections = 8 }).validate());
}

test "framing validates host, duplicate identity headers and unambiguous bodies" {
    const cases = [_]struct { headers: []const u8, valid: bool }{
        .{ .headers = "Host: example.test\r\nContent-Length: 0\r\n", .valid = true },
        .{ .headers = "Host: example.test\r\nTransfer-Encoding: chunked\r\n", .valid = true },
        .{ .headers = "Host: example.test\r\nHost: other.test\r\n", .valid = false },
        .{ .headers = "Host: example.test\r\nAuthorization: a\r\nauthorization: b\r\n", .valid = false },
        .{ .headers = "Host: example.test\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n", .valid = false },
        .{ .headers = "Host: example.test\r\nContent-Encoding: gzip\r\n", .valid = false },
        .{ .headers = "Content-Length: 0\r\n", .valid = false },
    };
    for (cases) |case| {
        var bytes: [1024]u8 = undefined;
        var output: [1024]u8 = undefined;
        var reader: Io.Reader = .fixed(try std.fmt.bufPrint(&bytes, "POST /api HTTP/1.1\r\n{s}\r\n", .{case.headers}));
        var writer: Io.Writer = .fixed(&output);
        var server = std.http.Server.init(&reader, &writer);
        var request = server.receiveHead() catch {
            try std.testing.expect(!case.valid);
            continue;
        };
        validateHead(&request) catch {
            try std.testing.expect(!case.valid);
            continue;
        };
        try std.testing.expect(case.valid);
    }
}

test "deadline joins its already scheduled timer when handler scheduling fails" {
    const Injection = struct {
        var scheduled: usize = 0;
        var timer_exited: std.atomic.Value(bool) = .init(false);
        fn schedule(userdata: ?*anyopaque, group: *Io.Group, context: []const u8, alignment: std.mem.Alignment, start: *const fn (*const anyopaque) void) Io.ConcurrentError!void {
            scheduled += 1;
            if (scheduled == 2) return error.ConcurrencyUnavailable;
            try std.testing.io.vtable.groupConcurrent(userdata, group, context, alignment, start);
        }
        fn sleep(userdata: ?*anyopaque, duration: Io.Timeout) Io.Cancelable!void {
            defer timer_exited.store(true, .release);
            return std.testing.io.vtable.sleep(userdata, duration);
        }
        fn work() anyerror!void {
            return error.UnexpectedHandler;
        }
    };
    Injection.scheduled = 0;
    Injection.timer_exited.store(false, .monotonic);
    var vtable = std.testing.io.vtable.*;
    vtable.groupConcurrent = Injection.schedule;
    vtable.sleep = Injection.sleep;
    const io: Io = .{ .userdata = std.testing.io.userdata, .vtable = &vtable };
    try std.testing.expectError(error.ConcurrencyUnavailable, deadline(io, 60000, Injection.work, .{}));
    try std.testing.expectEqual(@as(usize, 2), Injection.scheduled);
    try std.testing.expect(Injection.timer_exited.load(.acquire));
}
