//! Bounded protocol HTTP client. No storage or provider credentials.
const std = @import("std");
pub const observability = @import("transit_observability");
const telemetry = observability.telemetry;
pub const Session = @import("Session.zig");
pub const GrowingSession = @import("GrowingSession.zig");
pub const bootstrap = @import("bootstrap.zig");
pub const Value = protocol.Value;
pub const protocol = @import("transit_protocol");
const transit = protocol;
pub const max_body = protocol.max_body;
pub const Input = protocol.Input;
pub const View = protocol.View;
pub const Receipt = protocol.Receipt;

pub const Client = struct {
    http: std.http.Client,
    url: []const u8,
    timeout_ms: u32 = 5000,
    observer: ?*telemetry.Runtime = null,
    parent_context: ?telemetry.Context = null,
    call_context: ?telemetry.Context = null,
    last_status: ?std.http.Status = null,
    /// Last validated wire rejection; reset on every call. One caller per Client.
    last_rejection: ?protocol.ErrorCode = null,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, url: []const u8) Client {
        return .{ .http = .{ .allocator = allocator, .io = io }, .url = std.mem.trimEnd(u8, url, "/") };
    }
    pub fn deinit(self: *Client) void {
        self.http.deinit();
    }

    /// The caller owns deadlines and retry policy. Never follow redirects with
    /// signed requests; the configured endpoint is the trusted authority.
    pub fn call(self: *Client, comptime T: type, path: []const u8, signed: anytype) !T {
        const command = if (@hasField(@TypeOf(signed), "request")) @tagName(signed.request.command) else "inspect";
        var observation = observability.begin(self.observer, .client_request, command, self.parent_context);
        observation.event.route = route: {
            inline for (.{ "/v2/view", "/v2/inspect", "/v2/state", "/v2/delivery", "/v2/command", "/v3/command", "/v3/query" }) |known| if (std.mem.eql(u8, path, known)) break :route known;
            break :route "unmatched";
        };
        observation.event.method = "POST";
        const mutation = std.mem.eql(u8, path, "/v2/command") or std.mem.eql(u8, path, "/v3/command");
        if (mutation) observation.event.protocol_outcome = .uncertain;
        defer observation.finish();
        self.call_context = observation.span.context;
        defer self.call_context = null;
        self.last_status = null;
        const value = self.boundedCall(T, path, signed) catch |err| {
            observation.fail(err);
            if (self.last_status) |status| observation.event.status = @backingInt(status);
            if (self.last_rejection) |rejection| observation.event.error_type = @tagName(rejection);
            if (err == error.AccessDenied or err == error.Rejected or err == error.Conflict) observation.event.protocol_outcome = .rejected;
            return err;
        };
        if (self.last_status) |status| observation.event.status = @backingInt(status);
        observation.event.protocol_outcome = if (mutation) .receipt else .read;
        if (@hasField(@TypeOf(signed), "request")) {
            observation.event.realm = signed.request.realm;
            observation.event.sequence = signed.request.sequence;
            observation.event.pid = if (@TypeOf(signed.request.command) == protocol.Growth.Command) protocol.Growth.commandPid(signed.request.command) else observability.pid(signed.request.command);
        } else if (@hasField(@TypeOf(signed), "query")) {
            observation.event.realm = signed.query.realm;
            if (@hasField(@TypeOf(signed.query), "pid")) observation.event.pid = signed.query.pid;
        }
        if (T == Receipt) observation.event.position = value.position;
        return value;
    }

    fn boundedCall(self: *Client, comptime T: type, path: []const u8, signed: anytype) !T {
        self.last_rejection = null;
        const io = self.http.io;
        const deadline = std.Io.Clock.Timestamp.fromNow(io, .{
            .raw = .fromMilliseconds(self.timeout_ms),
            .clock = .awake,
        });
        const Result = union(enum) { response: anyerror!T, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(io, &results);
        defer select.cancelDiscard();
        try concurrentBefore(&select, .timeout, timeout, .{ io, deadline }, deadline);
        const Task = struct {
            fn run(client: *Client, route: []const u8, command: @TypeOf(signed), until: std.Io.Clock.Timestamp) anyerror!T {
                if (until.durationFromNow(client.http.io).raw.nanoseconds <= 0) return error.AuthorityTimeout;
                return client.perform(T, route, command);
            }
        };
        // async permits inline execution, which would defeat the timeout when
        // no async worker is available. Admission waits for real concurrency;
        // the transport itself is invoked at most once, with the same deadline.
        try concurrentBefore(&select, .response, Task.run, .{ self, path, signed, deadline }, deadline);
        return switch (try select.await()) {
            .response => |result| result,
            .timeout => error.AuthorityTimeout,
        };
    }

    fn concurrentBefore(select: anytype, comptime field: anytype, function: anytype, args: std.meta.ArgsTuple(@TypeOf(function)), deadline: std.Io.Clock.Timestamp) !void {
        while (true) {
            const remaining = deadline.durationFromNow(select.io).raw.nanoseconds;
            if (remaining <= 0) return error.AuthorityTimeout;
            select.concurrent(field, function, args) catch |err| switch (err) {
                error.ConcurrencyUnavailable => {
                    // Threaded may publish group completion before decrementing
                    // its busy count. A sequential call can briefly exhaust a
                    // bounded pool while the previous workers are retiring.
                    // Retry only scheduling, yielding without growing the pool
                    // or extending the call's absolute deadline.
                    try select.io.sleep(.fromNanoseconds(@min(remaining, std.time.ns_per_ms)), .awake);
                    continue;
                },
            };
            return;
        }
    }

    fn timeout(io: std.Io, deadline: std.Io.Clock.Timestamp) anyerror!void {
        try deadline.wait(io);
    }

    fn perform(self: *Client, comptime T: type, path: []const u8, signed: anytype) anyerror!T {
        const allocator = self.http.allocator;
        const url = try allocator.print("{s}{s}", .{ self.url, path });
        defer allocator.free(url);
        const body = try std.json.Stringify.valueAlloc(allocator, signed, .{});
        defer allocator.free(body);
        var buffer: [max_body]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        const parent_header = if (self.call_context) |context| context.header() else @as([55]u8, @splat(0));
        const trace_headers = [_]std.http.Header{.{ .name = "traceparent", .value = &parent_header }};
        const response = try self.http.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .headers = .{ .content_type = .{ .override = "application/json" } },
            .redirect_behavior = .not_allowed,
            .extra_headers = if (self.call_context != null) &trace_headers else &.{},
            .keep_alive = false,
            .response_writer = &writer,
        });
        self.last_status = response.status;
        if (response.status != .ok) {
            var failure = std.json.parseFromSlice(protocol.ErrorResponse, allocator, writer.buffered(), .{}) catch return error.InvalidAuthorityResponse;
            defer failure.deinit();
            self.last_rejection = failure.value.err;
        }
        switch (response.status) {
            .ok => {},
            .forbidden => return error.AccessDenied,
            .conflict => return error.Conflict,
            .bad_request, .unprocessable_entity => return error.Rejected,
            else => return error.AuthorityUnavailable,
        }
        var parsed = std.json.parseFromSlice(T, allocator, writer.buffered(), .{}) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAuthorityResponse,
        };
        defer parsed.deinit();
        if (T == Receipt) {
            if (parsed.value.position == 0 or parsed.value.position > protocol.max_counter) return error.InvalidAuthorityResponse;
        }
        if (T == protocol.Growth.Response) protocol.Growth.validateResponse(parsed.value, signed.query) catch return error.InvalidAuthorityResponse;
        return parsed.value;
    }

    pub fn view(self: *Client, request: transit.Request, key: transit.Ed25519.KeyPair) !View {
        if (request.command != .inspect or request.sequence != 0) return error.InvalidRead;
        return self.call(View, "/v2/view", try transit.sign(request, key));
    }
    pub fn inspect(self: *Client, query: protocol.Inspection.Query, key: protocol.Ed25519.KeyPair) !protocol.Inspection.Page {
        return self.call(protocol.Inspection.Page, "/v2/inspect", try protocol.Inspection.sign(query, key));
    }
    pub fn state(self: *Client, query: protocol.State.Query, key: protocol.Ed25519.KeyPair) !protocol.State.Page {
        return self.call(protocol.State.Page, "/v2/state", try protocol.State.sign(query, key));
    }
    pub fn delivery(self: *Client, query: protocol.Delivery.Query, key: protocol.Ed25519.KeyPair) !protocol.Delivery.Status {
        return self.call(protocol.Delivery.Status, "/v2/delivery", try protocol.Delivery.sign(query, key));
    }

    pub fn submit(self: *Client, signed: transit.SignedRequest) !Receipt {
        return self.call(Receipt, "/v2/command", signed);
    }

    /// Explicit v3 development profile; never falls back to a legacy route.
    pub fn submitGrowing(self: *Client, signed: protocol.Growth.SignedRequest) !Receipt {
        try protocol.Growth.validate(signed.request);
        return self.call(Receipt, "/v3/command", signed);
    }
    pub fn queryGrowing(self: *Client, query: protocol.Growth.Query, key: protocol.Ed25519.KeyPair) !protocol.Growth.Response {
        return self.call(protocol.Growth.Response, "/v3/query", try protocol.Growth.signQuery(query, key));
    }
};

/// Private seeds are read from an explicitly supplied file, never argv or logs.
pub fn readKey(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !transit.Ed25519.KeyPair {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(256));
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    var seed: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &seed);
    const hex = std.mem.trim(u8, bytes, " \r\n\t");
    if (hex.len != 64) return error.InvalidSeed;
    _ = try std.fmt.hexToBytes(&seed, hex);
    return transit.Ed25519.KeyPair.generateDeterministic(seed);
}

fn largestFields(comptime T: type) T {
    if (T == protocol.Value) return protocol.Value.init(&(@as([protocol.Value.max_bytes]u8, @splat(255)))) catch unreachable;
    return switch (@typeInfo(T)) {
        .int => |info| if (info.signedness == .signed) std.math.minInt(T) else std.math.maxInt(T),
        .bool => false,
        .void => {},
        .@"union" => |info| blk: {
            var largest: T = undefined;
            var length: usize = 0;
            inline for (info.field_names, info.field_types) |name, Field| {
                const candidate: T = @unionInit(T, name, largestFields(Field));
                const bytes = std.json.Stringify.valueAlloc(std.testing.allocator, candidate, .{}) catch unreachable;
                defer std.testing.allocator.free(bytes);
                if (bytes.len > length) {
                    largest = candidate;
                    length = bytes.len;
                }
            }
            break :blk largest;
        },
        .optional => |info| largestFields(info.child),
        .array => |info| @splat(largestFields(info.child)),
        .@"struct" => |info| blk: {
            var value: T = undefined;
            inline for (info.field_names, info.field_types) |name, Field| @field(value, name) = largestFields(Field);
            break :blk value;
        },
        .@"enum" => |info| blk: {
            comptime var longest: usize = 0;
            inline for (info.field_names, 0..) |name, index| {
                if (comptime name.len > info.field_names[longest].len) longest = index;
            }
            break :blk @fromBackingInt(@intCast(info.field_values[longest]));
        },
        else => @compileError("Extend the wire-bound fixture for this type"),
    };
}

test "a full metadata view fits the bounded HTTP response" {
    // All optional metadata is present, all slots filled, every enum uses its
    // longest tag and integers use their widest decimal form (even wider than
    // legal protocol counters). Leave slack for shorter optional scalars/nulls.
    const value = largestFields(View);
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len + 1024 <= max_body);
}

test {
    _ = @import("ConcurrencyTests.zig");
    _ = Session;
    _ = GrowingSession;
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, largestFields(protocol.Inspection.Page), .{});
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len + 1024 <= max_body);
}
