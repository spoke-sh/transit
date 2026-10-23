//! One borrower per client. HTTP connections are reusable, while the logical
//! session remains bound to the observed instance across transport replacement.
const std = @import("std");
const api = @import("root.zig").protocol;
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
http: std.http.Client,
endpoint: []const u8,
timeout_ms: u32 = 30000,
lease_ms: u32 = 30000,
last_call: ?std.Io.Timestamp = null,
instance: ?api.Instance = null,
session: ?api.Id = null,
account: ?api.Account = null,
unix: ?std.Io.net.Stream = null,
unix_reader: std.Io.net.Stream.Reader = undefined,
unix_writer: std.Io.net.Stream.Writer = undefined,
input_buffer: [8192]u8 = undefined,
output_buffer: [4096]u8 = undefined,
pub const Config = struct {
    version: u8 = 1,
    endpoint: []const u8,
    account: []const u8 = "local",
    database: []const u8 = "transit",
    source: ?[]const u8 = null,
    authentication: enum { peer, trust, scram } = .peer,
    ca_file: ?[]const u8 = null,
    password_file: ?[]const u8 = null,
    instance: ?api.Instance = null,
    request_timeout_ms: u32 = 30000,
};
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Self {
    if (config.version != 1 or config.request_timeout_ms == 0 or config.request_timeout_ms > 270000) return error.InvalidSqlClientConfiguration;
    if (std.mem.startsWith(u8, config.endpoint, "unix:")) {
        if (!std.fs.path.isAbsolute(config.endpoint[5..]) or config.authentication != .peer or config.ca_file != null or config.password_file != null) return error.InvalidSqlEndpoint;
        _ = try std.Io.net.UnixAddress.init(config.endpoint[5..]);
    } else {
        const uri = try std.Uri.parse(config.endpoint);
        if (uri.user != null or uri.password != null or uri.query != null or uri.fragment != null or uri.host == null or uri.port == 0) return error.InvalidSqlEndpoint;
        var validation: std.heap.ArenaAllocator = .init(allocator);
        defer validation.deinit();
        const host = try uri.host.?.toRawMaybeAlloc(validation.allocator());
        const path = try uri.path.toRawMaybeAlloc(validation.allocator());
        if (path.len != 0 and !std.mem.eql(u8, path, "/")) return error.InvalidSqlEndpoint;
        if (std.mem.eql(u8, uri.scheme, "http")) {
            if (config.authentication != .trust or config.ca_file != null or config.password_file != null or !(std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "[::1]"))) return error.InvalidSqlEndpoint;
        } else if (!std.mem.eql(u8, uri.scheme, "https") or config.authentication == .peer) return error.InvalidSqlEndpoint;
    }
    var self: Self = .{ .allocator = allocator, .io = io, .http = .{ .allocator = allocator, .io = io, .connection_pool = .{ .free_size = 1 } }, .endpoint = std.mem.trimEnd(u8, config.endpoint, "/"), .timeout_ms = config.request_timeout_ms, .instance = config.instance };
    errdefer self.http.deinit();
    if (config.ca_file) |file| {
        const now = std.Io.Clock.real.now(io);
        try self.http.ca_bundle.addCertsFromFilePathAbsolute(allocator, io, now, file);
        self.http.now = now;
    }
    return self;
}
pub fn deinit(self: *Self) void {
    if (self.unix) |stream| stream.close(self.io);
    self.http.deinit();
    std.crypto.secureZero(u8, std.mem.asBytes(self));
}
pub fn open(self: *Self, config: Config, password: ?[]const u8) !void {
    var hello = try self.call(.hello);
    defer hello.deinit();
    if (hello.value.result != .hello or !std.mem.eql(u8, hello.value.result.hello.encoding, api.encoding)) return error.InvalidSqlResponse;
    self.lease_ms = hello.value.result.hello.session_lease_ms;
    var nonce: [18]u8 = undefined;
    try self.io.randomSecure(&nonce);
    var first_buffer: [128]u8 = undefined;
    var encoded: [24]u8 = undefined;
    const first = if (config.authentication == .scram) try std.fmt.bufPrint(&first_buffer, "n,,n=,r={s}", .{std.base64.standard.Encoder.encode(&encoded, &nonce)}) else "";
    var response = try self.call(.{ .open = .{ .account = config.account, .database = config.database, .source = config.source, .authentication = switch (config.authentication) {
        .peer => .peer,
        .trust => .trust,
        .scram => .scram,
    }, .first = first } });
    defer response.deinit();
    if (config.authentication == .scram) {
        if (response.value.result != .challenge or password == null) return error.AuthenticationFailed;
        const binding = try api.authenticationBinding(self.allocator, self.instance.?, config.account, config.database, config.source);
        var proof = try api.Authentication.ClientProof.create(password.?, first, response.value.result.challenge.message, binding);
        defer proof.deinit();
        var authenticated = try self.call(.{ .authenticate = .{ .challenge = response.value.result.challenge.id, .final = proof.message() } });
        defer authenticated.deinit();
        if (authenticated.value.result != .opened) return error.AuthenticationFailed;
        try proof.verify(authenticated.value.result.opened.proof);
        self.session = authenticated.value.result.opened.session;
        self.account = authenticated.value.result.opened.account;
    } else {
        if (response.value.result != .opened) return error.AuthenticationFailed;
        self.session = response.value.result.opened.session;
        self.account = response.value.result.opened.account;
    }
}
/// No request is automatically replayed, including after a pooled socket dies.
/// Mutation uncertainty remains attached to the caller's original token.
pub fn call(self: *Self, action: api.Action) !std.json.Parsed(api.Response) {
    // The host gives idle HTTP headers one second. Replace a quiescent
    // transport before dispatch, without replaying any request or new session.
    if (self.last_call) |last| if (last.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= 500) {
        if (self.unix) |stream| {
            stream.close(self.io);
            self.unix = null;
        }
        try self.http.connection_pool.resize(self.io, 0);
        try self.http.connection_pool.resize(self.io, 1);
    };
    // Idle age starts when the response is received, before parsing/rendering.
    // A failed exchange must replace its transport before a later explicit call.
    errdefer self.last_call = .{ .nanoseconds = 0 };
    const input: api.Request = .{ .version = 1, .definition = api.native.current_definition, .instance = self.instance, .session = self.session, .action = action };
    try input.validate();
    const body = try api.Json.valueAlloc(self.allocator, input);
    defer {
        std.crypto.secureZero(u8, body);
        self.allocator.free(body);
    }
    if (body.len > api.max_message_bytes) return error.SqlMessageTooLarge;
    const buffer = try self.allocator.alloc(u8, api.max_message_bytes);
    defer self.allocator.free(buffer);
    var output: std.Io.Writer = .fixed(buffer);
    const Result = union(enum) { result: anyerror!void, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var selected: std.Io.Select(Result) = .init(self.io, &results);
    defer selected.cancelDiscard();
    try selected.concurrent(.timeout, sleep, .{ self.io, self.timeout_ms });
    try selected.concurrent(.result, perform, .{ self, if (input.control()) api.control_path else api.data_path, body, &output });
    switch (try selected.await()) {
        .result => |result| try result,
        .timeout => |result| {
            try result;
            return error.SqlRequestTimeout;
        },
    }
    selected.cancelDiscard();
    self.last_call = std.Io.Clock.awake.now(self.io);
    const response = try api.parse(api.Response, self.allocator, output.buffered());
    errdefer response.deinit();
    if (self.instance) |instance| {
        if (!std.mem.eql(u8, &instance, &response.value.instance)) return error.SqlInstanceChanged;
    } else if (action == .hello) self.instance = response.value.instance else return error.SqlInstanceRequired;
    return response;
}
fn sleep(io: std.Io, milliseconds: u32) !void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
fn perform(self: *Self, path: []const u8, body: []const u8, output: *std.Io.Writer) anyerror!void {
    if (std.mem.startsWith(u8, self.endpoint, "unix:")) return self.local(path, body, output);
    const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.endpoint, path });
    defer self.allocator.free(url);
    var request = try self.http.request(.POST, try std.Uri.parse(url), .{ .headers = .{ .content_type = .{ .override = "application/json" }, .accept_encoding = .{ .override = "identity" } }, .redirect_behavior = .not_allowed, .keep_alive = true });
    defer request.deinit();
    request.transfer_encoding = .{ .content_length = body.len };
    var writer = try request.sendBodyUnflushed(&.{});
    try writer.writer.writeAll(body);
    try writer.end();
    try request.connection.?.flush();
    var headers: [8192]u8 = undefined;
    var response = try request.receiveHead(&headers);
    if (response.head.status != .ok or response.head.content_encoding != .identity) return error.InvalidSqlHttpResponse;
    // The pinned std.http.fetch assumes every ReadFailed has a body error.
    // Cancellation of its underlying reader can leave that optional unset.
    _ = response.reader(&.{}).streamRemaining(output) catch |err| switch (err) {
        error.ReadFailed => return response.bodyErr() orelse error.Canceled,
        else => return err,
    };
}
fn local(self: *Self, path: []const u8, body: []const u8, output: *std.Io.Writer) !void {
    if (self.unix == null) {
        self.unix = try (try std.Io.net.UnixAddress.init(self.endpoint[5..])).connect(self.io);
        self.unix_reader = self.unix.?.reader(self.io, &self.input_buffer);
        self.unix_writer = self.unix.?.writer(self.io, &self.output_buffer);
    }
    errdefer {
        self.unix.?.close(self.io);
        self.unix = null;
    }
    const writer = &self.unix_writer.interface;
    try writer.print("POST {s} HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: keep-alive\r\n\r\n", .{ path, body.len });
    try writer.writeAll(body);
    try writer.flush();
    var reader: std.http.Reader = .{ .in = &self.unix_reader.interface, .interface = undefined, .state = .ready, .max_head_len = 8192 };
    const head = try std.http.Client.Response.Head.parse(try reader.receiveHead());
    if (head.status != .ok or head.content_encoding != .identity or head.content_length == null or head.content_length.? > api.max_message_bytes) return error.InvalidSqlHttpResponse;
    const keep_alive = head.keep_alive;
    _ = try reader.bodyReader(&.{}, head.transfer_encoding, head.content_length).streamRemaining(output);
    if (!keep_alive) {
        self.unix.?.close(self.io);
        self.unix = null;
    }
}
test "native SQL endpoints reject unsafe trust and credential-bearing URLs" {
    const t = std.testing;
    for ([_][]const u8{ "http://example.com:1", "http://user:password@127.0.0.1:1", "http://127.0.0.1:1/redirect", "https://localhost:443?token=secret" }) |endpoint| try t.expectError(error.InvalidSqlEndpoint, init(t.allocator, t.io, .{ .endpoint = endpoint, .authentication = .trust }));
    try t.expectError(error.InvalidSqlEndpoint, init(t.allocator, t.io, .{ .endpoint = "unix:relative" }));
}
