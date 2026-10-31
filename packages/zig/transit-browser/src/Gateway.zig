//! Browser-only HTTP boundary. Operators publish bounded read definitions;
//! browsers select a name and never supply SQL or upstream credentials.
const std = @import("std");
const http = @import("transit_http_server");
const sql = @import("transit_sql_client");
const Security = @import("Security.zig");
const Provider = @import("Provider.zig");
const Sql = @import("Sql.zig");
const Store = @import("Store.zig");
const Self = @This();
pub const Config = struct {
    version: u8 = 1,
    address: []const u8 = "127.0.0.1",
    port: u16 = 19110,
    public_origin: []const u8,
    development: bool = false,
    trusted_tls_termination: bool = false,
    secret_file: []const u8,
    state: sql.Client.Config,
    public_reader: ?sql.Client.Config = null,
    providers: []const Provider.Config = &.{},
    views: []const View = &.{},
    bindings: []const Binding = &.{},
};
pub const View = struct { name: []const u8, sql: []const u8, access: enum { public, bound_identity } = .bound_identity, max_rows: u16 = 128 };
/// A binding selects an existing SQL account. Its current native role/grants
/// still govern every query and final disclosure. No grant is created here.
pub const Binding = struct { subject: []const u8, connection: sql.Client.Config };
config: Config,
boundary: Security.Boundary,
secret: [32]u8,
pub fn init(config: Config, secret: [32]u8) !Self {
    if (config.version != 1 or config.port == 0 or config.providers.len > 3 or config.views.len > 32 or config.bindings.len > 1024 or (!config.development and !config.trusted_tls_termination)) return error.InvalidBrowserConfiguration;
    const boundary = try Security.Boundary.init(config.public_origin, config.development);
    const address = try std.Io.net.IpAddress.parseIp4(config.address, config.port);
    if (config.development and address.ip4.bytes[0] != 127) return error.InvalidBrowserConfiguration;
    for (config.providers, 0..) |provider, i| {
        if (!config.development and provider.test_endpoint != null) return error.InvalidProviderConfiguration;
        for (config.providers[0..i]) |other| if (other.provider == provider.provider) return error.InvalidProviderConfiguration;
    }
    for (config.views, 0..) |view, i| {
        if (!name(view.name) or view.sql.len == 0 or view.sql.len > 4096 or view.max_rows == 0 or view.max_rows > 1024 or (view.access == .public and config.public_reader == null)) return error.InvalidBrowserView;
        for (config.views[0..i]) |other| if (std.mem.eql(u8, view.name, other.name)) return error.InvalidBrowserView;
    }
    for (config.bindings, 0..) |binding, i| {
        if (!Security.validToken(binding.subject) or std.mem.eql(u8, binding.connection.account, "local")) return error.InvalidBrowserBinding;
        for (config.bindings[0..i]) |other| if (std.mem.eql(u8, binding.subject, other.subject)) return error.InvalidBrowserBinding;
    }
    return .{ .config = config, .boundary = boundary, .secret = secret };
}
fn name(value: []const u8) bool {
    if (value.len == 0 or value.len > 64) return false;
    for (value) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
    return true;
}
fn now(io: std.Io) i64 {
    return @intCast(@divFloor(std.Io.Clock.real.now(io).toMilliseconds(), 1000));
}
fn cookieName(self: *Self, login: bool) []const u8 {
    return if (self.config.development) (if (login) "transit-login" else "transit-session") else (if (login) "__Host-transit-login" else "__Host-transit-session");
}
fn credential(self: *Self, request: *std.http.Server.Request, login: bool) !?[]const u8 {
    return Security.cookie(try http.header(request, "cookie"), self.cookieName(login));
}
fn cookie(self: *Self, a: std.mem.Allocator, login: bool, token: []const u8, age: u32) ![]const u8 {
    return std.fmt.allocPrint(a, "{s}={s}; Path=/; HttpOnly; SameSite=Lax; Max-Age={d}{s}", .{ self.cookieName(login), token, age, if (self.config.development) "" else "; Secure" });
}
pub fn isControl(_: *Self, request: *std.http.Server.Request) bool {
    return std.mem.eql(u8, request.head.target, "/auth/session") or std.mem.eql(u8, request.head.target, "/auth/logout") or std.mem.eql(u8, request.head.target, "/health");
}
pub fn isWait(_: *Self, request: *std.http.Server.Request) bool {
    return std.mem.startsWith(u8, request.head.target, "/api/watch/");
}
pub fn connectionError(_: *Self, _: anyerror, _: bool) void {} // No URLs, credentials or provider bodies in diagnostics.
pub fn handle(self: *Self, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    var budget: @import("transit_memory").Budget = .{ .parent = allocator, .limit = 32 * 1024 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(budget.allocator());
    defer arena.deinit();
    self.dispatch(io, arena.allocator(), request) catch |err| {
        const status: std.http.Status = switch (err) {
            error.BrowserHostDenied, error.BrowserOriginDenied, error.BrowserOriginRequired, error.BrowserProxyRequired, error.InvalidCookie, error.DuplicateCookie, error.DuplicateHeader, error.BrowserChallengeRejected, error.InvalidBrowserToken, error.InvalidProvider, error.InvalidQuery, error.InvalidAuthorizationCode => .forbidden,
            error.BrowserSessionRejected, error.BrowserIdentityDisabled, error.BrowserBindingRequired => .unauthorized,
            else => .service_unavailable,
        };
        if (status == .service_unavailable) std.log.err("browser request unavailable: {s}", .{@errorName(err)});
        try http.respond(request, status, "{\"error\":\"browser_request_rejected\"}");
    };
}
fn dispatch(self: *Self, io: std.Io, a: std.mem.Allocator, request: *std.http.Server.Request) !void {
    try http.validateHead(request);
    const target = request.head.target;
    if (std.mem.eql(u8, target, "/health") and request.head.method == .GET) return http.respond(request, .ok, "{\"ready\":true}");
    const host = (try http.header(request, "host")) orelse return error.BrowserHostDenied;
    const origin = try http.header(request, "origin");
    const site = try http.header(request, "sec-fetch-site");
    const callback = std.mem.startsWith(u8, target, "/auth/callback/");
    const websocket = std.mem.startsWith(u8, target, "/api/watch/");
    try self.boundary.check(host, origin, websocket or request.head.method != .GET, if (callback) null else site);
    if (!callback and !websocket and request.head.method == .GET and origin == null and !std.mem.eql(u8, site orelse "", "same-origin")) return error.BrowserOriginRequired;
    if (!self.config.development and !std.mem.eql(u8, (try http.header(request, "x-forwarded-proto")) orelse "", "https")) return error.BrowserProxyRequired;
    if (try http.header(request, "authorization") != null or try http.header(request, "x-transit-principal") != null) return error.InvalidBrowserToken;
    if (std.mem.eql(u8, target, "/auth/providers") and request.head.method == .GET) {
        var providers: std.array_list.Managed(Security.Provider) = .init(a);
        for (self.config.providers) |provider| try providers.append(provider.provider);
        return http.respond(request, .ok, try std.json.Stringify.valueAlloc(a, .{ .providers = providers.items }, .{}));
    }
    if (std.mem.startsWith(u8, target, "/auth/login/") and request.head.method == .POST) return self.startLogin(io, a, request, target[12..]);
    if (callback and request.head.method == .GET) return self.finishLogin(io, a, request, target[15..]);
    if (std.mem.eql(u8, target, "/auth/session") and request.head.method == .GET) {
        const token = (try self.credential(request, false)) orelse return http.respond(request, .ok, "{\"identity\":null}");
        const database = try Sql.init(a, io, self.config.state);
        defer database.deinit();
        const identity = try (Store{ .sql = database }).authenticate(token, now(io));
        return http.respond(request, .ok, try std.json.Stringify.valueAlloc(a, .{ .identity = .{ .id = identity.subject, .provider = identity.provider, .bound = self.findBinding(identity.subject) != null } }, .{}));
    }
    if (std.mem.eql(u8, target, "/auth/logout") and request.head.method == .POST) {
        if (try self.credential(request, false)) |token| {
            const database = try Sql.init(a, io, self.config.state);
            defer database.deinit();
            try (Store{ .sql = database }).revoke(token);
        }
        return self.redirect(a, request, "/", &.{try self.cookie(a, false, "", 0)});
    }
    const read = std.mem.startsWith(u8, target, "/api/views/");
    if ((read or websocket) and request.head.method == .GET) {
        const view_name = target[11..];
        for (self.config.views) |view| if (std.mem.eql(u8, view.name, view_name)) {
            const token = try self.credential(request, false);
            if (websocket) return self.watch(io, a, request, view, token);
            return http.respond(request, .ok, try self.snapshot(io, a, view, token));
        };
    }
    return http.respond(request, .not_found, "{\"error\":\"not_found\"}");
}
fn findProvider(self: *Self, value: []const u8) !Provider.Config {
    const kind = std.meta.stringToEnum(Security.Provider, value) orelse return error.InvalidProvider;
    for (self.config.providers) |item| if (item.provider == kind) return item;
    return error.InvalidProvider;
}
fn findBinding(self: *Self, subject: []const u8) ?sql.Client.Config {
    for (self.config.bindings) |item| if (std.mem.eql(u8, item.subject, subject)) return item.connection;
    return null;
}
fn redirect(_: *Self, _: std.mem.Allocator, request: *std.http.Server.Request, location: []const u8, cookies: []const []const u8) !void {
    var headers: [6]std.http.Header = undefined;
    headers[0] = .{ .name = "location", .value = location };
    headers[1] = .{ .name = "cache-control", .value = "no-store" };
    headers[2] = .{ .name = "referrer-policy", .value = "no-referrer" };
    for (cookies, 0..) |value, i| headers[i + 3] = .{ .name = "set-cookie", .value = value };
    request.head.keep_alive = false;
    try request.respond("", .{ .status = .see_other, .keep_alive = false, .extra_headers = headers[0 .. 3 + cookies.len] });
}
fn startLogin(self: *Self, io: std.Io, a: std.mem.Allocator, request: *std.http.Server.Request, selected: []const u8) !void {
    const config = try self.findProvider(selected);
    const state = try Security.random(io);
    const browser = try Security.random(io);
    const database = try Sql.init(a, io, self.config.state);
    defer database.deinit();
    try (Store{ .sql = database }).issue(config.provider, &state, &browser, now(io));
    const verifier_value = Security.verifier(&self.secret, &state);
    const nonce = Security.digest(&state);
    const url = try Provider.authorization(a, config, try Provider.endpoints(a, config, self.config.development), try std.fmt.allocPrint(a, "{s}/auth/callback/{s}", .{ self.config.public_origin, selected }), &state, &Security.challenge(&verifier_value), &nonce);
    try self.redirect(a, request, url, &.{try self.cookie(a, true, &browser, 300)});
}
fn parameter(a: std.mem.Allocator, query: []const u8, key: []const u8) ![]const u8 {
    var found: ?[]const u8 = null;
    var fields = std.mem.splitScalar(u8, query, '&');
    while (fields.next()) |field| {
        const pos = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
        if (!std.mem.eql(u8, field[0..pos], key)) continue;
        if (found != null) return error.InvalidQuery;
        const bytes = try a.dupe(u8, field[pos + 1 ..]);
        var used: usize = 0;
        var i: usize = 0;
        while (i < bytes.len) : (i += 1) {
            if (bytes[i] == '%') {
                if (i + 2 >= bytes.len) return error.InvalidQuery;
                bytes[used] = std.fmt.parseInt(u8, bytes[i + 1 .. i + 3], 16) catch return error.InvalidQuery;
                i += 2;
            } else bytes[used] = if (bytes[i] == '+') ' ' else bytes[i];
            used += 1;
        }
        found = bytes[0..used];
    }
    return found orelse error.InvalidQuery;
}
fn finishLogin(self: *Self, io: std.Io, a: std.mem.Allocator, request: *std.http.Server.Request, suffix: []const u8) !void {
    const question = std.mem.indexOfScalar(u8, suffix, '?') orelse return error.InvalidQuery;
    const config = try self.findProvider(suffix[0..question]);
    const state = try parameter(a, suffix[question + 1 ..], "state");
    const code = try parameter(a, suffix[question + 1 ..], "code");
    const browser = (try self.credential(request, true)) orelse return error.BrowserChallengeRejected;
    const database = try Sql.init(a, io, self.config.state);
    defer database.deinit();
    const store: Store = .{ .sql = database };
    try store.consume(config.provider, state, browser, now(io));
    const subject = try Provider.exchange(a, io, config, try Provider.endpoints(a, config, self.config.development), try std.fmt.allocPrint(a, "{s}/auth/callback/{s}", .{ self.config.public_origin, @tagName(config.provider) }), code, &Security.verifier(&self.secret, state), &Security.digest(state), now(io));
    const identity = try store.identify(config.provider, &subject);
    const token = try Security.random(io);
    try store.session(identity, &token, now(io));
    try self.redirect(a, request, "/", &.{ try self.cookie(a, true, "", 0), try self.cookie(a, false, &token, 28800) });
}
fn snapshot(self: *Self, io: std.Io, a: std.mem.Allocator, view: View, token: ?[]const u8) ![]const u8 {
    var connection = self.config.public_reader;
    var state: ?*Sql = null;
    defer if (state) |database| database.deinit();
    if (token != null or view.access == .bound_identity) {
        state = try Sql.init(a, io, self.config.state);
        const identity = try (Store{ .sql = state.? }).authenticate(token orelse return error.BrowserSessionRejected, now(io));
        if (view.access == .bound_identity) connection = self.findBinding(identity.subject) orelse return error.BrowserBindingRequired;
    }
    const database = try Sql.init(a, io, connection orelse return error.BrowserBindingRequired);
    defer database.deinit();
    const rows = try database.rows(view.sql, view.max_rows);
    if (state) |auth| _ = try (Store{ .sql = auth }).authenticate(token.?, now(io));
    return std.json.Stringify.valueAlloc(a, .{ .rows = rows }, .{});
}
fn watch(self: *Self, io: std.Io, a: std.mem.Allocator, request: *std.http.Server.Request, view: View, token: ?[]const u8) !void {
    const key = try http.WebSocket.handshake(request, "transit.browser.v1");
    const first = try self.snapshot(io, a, view, token);
    var ws = try request.respondWebSocket(.{ .key = key, .extra_headers = &.{.{ .name = "sec-websocket-protocol", .value = "transit.browser.v1" }} });
    // All errors after upgrade are WS closes; never emit a second HTTP response.
    var socket: Socket = .{ .gateway = self, .io = io, .a = a, .ws = &ws, .view = view, .token = token };
    socket.run(first) catch |err| {
        const code: [2]u8 = if (err == error.BrowserSessionRejected or err == error.BrowserBindingRequired or err == error.BrowserIdentityDisabled) .{ 0x03, 0xf0 } else .{ 0x03, 0xf3 };
        http.deadline(io, 1000, Socket.close, .{ &socket, code }) catch {};
    };
}
const Socket = struct {
    gateway: *Self,
    io: std.Io,
    a: std.mem.Allocator,
    ws: *std.http.Server.WebSocket,
    view: View,
    token: ?[]const u8,
    mutex: std.Io.Mutex = .init,
    fn send(self: *Socket, bytes: []const u8, op: std.http.Server.WebSocket.Opcode) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        try self.ws.writeMessage(bytes, op);
    }
    fn close(self: *Socket, code: [2]u8) !void {
        try self.send(&code, .connection_close);
    }
    fn run(self: *Socket, first: []const u8) !void {
        try http.deadline(self.io, 1000, send, .{ self, first, .text });
        const Result = union(enum) { receive: anyerror!void, publish: anyerror!void };
        var values: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(self.io, &values);
        defer select.cancelDiscard();
        try select.concurrent(.receive, receive, .{self});
        try select.concurrent(.publish, publish, .{self});
        switch (try select.await()) {
            .receive => |result| try result,
            .publish => |result| try result,
        }
        select.cancelDiscard();
        try http.deadline(self.io, 1000, close, .{ self, .{ 0x03, 0xe8 } });
    }
    fn receive(self: *Socket) !void {
        var decoder: http.WebSocket.Decoder = .{};
        while (true) {
            const message = try decoder.next(self.ws.input);
            switch (message.opcode) {
                .close => return,
                .ping => try http.deadline(self.io, 1000, send, .{ self, message.bytes, .pong }),
                .pong => {},
                .text => return error.WebSocketProtocol,
            }
        }
    }
    fn publish(self: *Socket) !void {
        var arena: std.heap.ArenaAllocator = .init(self.a);
        defer arena.deinit();
        const start = std.Io.Clock.awake.now(self.io);
        while (start.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() < 50000) {
            try self.io.sleep(.fromMilliseconds(2000), .awake);
            _ = arena.reset(.retain_capacity);
            const bytes = try self.gateway.snapshot(self.io, arena.allocator(), self.view, self.token);
            try http.deadline(self.io, 1000, send, .{ self, bytes, .text });
        }
    }
};

test "production requires TLS placement and explicit protected account bindings" {
    const t = std.testing;
    var config: Config = .{ .public_origin = "https://www.example.com", .secret_file = "/secret", .state = .{ .endpoint = "unix:/tmp/state.sock" } };
    try t.expectError(error.InvalidBrowserConfiguration, init(config, @splat(0)));
    config.trusted_tls_termination = true;
    _ = try init(config, @splat(0));
    config.providers = &.{.{ .provider = .google, .client_id = "client", .client_secret_file = "/secret", .test_endpoint = "http://127.0.0.1:9000" }};
    try t.expectError(error.InvalidProviderConfiguration, init(config, @splat(0)));
    config.providers = &.{};
    config.views = &.{.{ .name = "public", .sql = "SELECT id FROM catalog", .access = .public }};
    try t.expectError(error.InvalidBrowserView, init(config, @splat(0)));
    config.views = &.{};
    config.bindings = &.{.{ .subject = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .connection = .{ .endpoint = "unix:/tmp/state.sock" } }};
    try t.expectError(error.InvalidBrowserBinding, init(config, @splat(0)));
}
