//! Inspection-only application: all live data crosses the public Transit client.
const std = @import("std");
const telemetry = @import("telemetry");
const client = @import("transit_client");
const api = @import("board_api");
const assets = @import("assets");
const Auth = @import("Auth.zig");
const i = client.protocol.Inspection;
const Config = struct {
    upstream: []const u8,
    realm: u64,
    principal: u8,
    seed_file: []const u8,
    credential_file: []const u8,
    public_origin: []const u8,
    development_allow_insecure_http: bool = false,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8090,
    session_seconds: u32 = 900,
    request_timeout_ms: u32 = 1500,
    upstream_timeout_ms: u32 = 800,
    read_interval_ms: u32 = 100,
    lenses: []const api.Mapping = &.{},
};
const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    config: Config,
    host: []const u8,
    auth: Auth = .{},
    observation: telemetry.Http = .{},
    next_read_ms: i64 = 0,

    fn now(self: *Server) i64 {
        return std.Io.Clock.boot.now(self.io).toMilliseconds();
    }
    fn respond(self: *Server, req: *std.http.Server.Request, status: std.http.Status, body: []const u8, mime: []const u8, cookie: ?[]const u8) !void {
        self.observation.status = @backingInt(status);
        var headers: [9]std.http.Header = .{
            .{ .name = "content-type", .value = mime },
            .{ .name = "cache-control", .value = "no-store" },
            .{ .name = "x-content-type-options", .value = "nosniff" },
            .{ .name = "content-security-policy", .value = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'" },
            .{ .name = "referrer-policy", .value = "no-referrer" },
            .{ .name = "permissions-policy", .value = "camera=(), microphone=(), geolocation=()" },
            .{ .name = "vary", .value = "Cookie, Authorization" },
            .{ .name = "x-frame-options", .value = "DENY" },
            .{ .name = "set-cookie", .value = cookie orelse "" },
        };
        try req.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = headers[0..if (cookie != null) 9 else 8] });
        self.observation.written = true;
    }
    fn json(self: *Server, req: *std.http.Server.Request, status: std.http.Status, value: anytype, cookie: ?[]const u8) !void {
        const body = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(body);
        return self.respond(req, status, body, "application/json", cookie);
    }
    fn failure(self: *Server, req: *std.http.Server.Request, status: std.http.Status, code: @FieldType(api.Error, "err")) !void {
        self.observation.error_type = @tagName(code);
        return self.json(req, status, api.Error{ .err = code }, null);
    }
    fn handle(self: *Server, stream: std.Io.net.Stream) anyerror!void {
        var rb: [8192]u8 = undefined;
        var wb: [4096]u8 = undefined;
        var reader = stream.reader(self.io, &rb);
        var writer = stream.writer(self.io, &wb);
        var http = std.http.Server.init(&reader.interface, &writer.interface);
        var req = try http.receiveHead();
        self.observation.received(&req, logRoute(req.head.target), false);
        const host = (try header(&req, "host")) orelse return self.failure(&req, .forbidden, .InvalidOrigin);
        if (!std.mem.eql(u8, host, self.host)) return self.failure(&req, .forbidden, .InvalidOrigin);
        if (try header(&req, "origin")) |origin| if (!std.mem.eql(u8, origin, self.config.public_origin)) return self.failure(&req, .forbidden, .InvalidOrigin);
        for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-for" }) |name| if (try header(&req, name) != null) return self.failure(&req, .forbidden, .InvalidOrigin);
        const target = try self.allocator.dupe(u8, req.head.target);
        defer self.allocator.free(target);
        // Reading a body changes the HTTP reader state and may reuse its head
        // buffer. Copy/decode everything needed from headers first.
        const token = Auth.cookie(try header(&req, "cookie"));
        const authorization = try header(&req, "authorization");
        const presented = if (authorization) |value| if (std.mem.startsWith(u8, value, "Bearer ")) Auth.decode(value[7..]) else null else null;
        if (target.len > 1024) return self.failure(&req, .bad_request, .InvalidQuery);
        const body = req.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(4096)) catch return self.failure(&req, .bad_request, .InvalidQuery);
        defer self.allocator.free(body);
        if (body.len != 0) return self.failure(&req, .bad_request, .InvalidQuery);
        if (std.mem.eql(u8, target, "/health") and req.head.method == .GET) return self.json(&req, .ok, .{ .ready = true }, null);
        if (std.mem.eql(u8, target, "/openapi/v1.json") and req.head.method == .GET) return self.respond(&req, .ok, assets.openapi, "application/json", null);
        if (!std.mem.startsWith(u8, target, "/api/")) {
            if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
            if (assets.get(target)) |asset| return self.respond(&req, .ok, asset.bytes, asset.mime, null);
            const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
            if (browserRoute(path)) return self.respond(&req, .ok, assets.index, "text/html; charset=utf-8", null);
            return self.failure(&req, .not_found, .NotFound);
        }
        var credential = Auth.credential(self.allocator, self.io, self.config.credential_file) catch return self.failure(&req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, &credential);
        const bearer = if (presented) |value| Auth.equal(value, credential) else false;
        const authorized = self.auth.authorized(token, credential, self.now());
        if (!bearer and !authorized) return self.failure(&req, .unauthorized, .Unauthorized);
        if (req.head.method == .POST and std.mem.eql(u8, target, "/api/v1/session")) {
            // Cookie replay cannot renew a session. Only the current access key can.
            if (!bearer) return self.failure(&req, .unauthorized, .Unauthorized);
            const issued = self.auth.issue(self.io, credential, self.now(), self.config.session_seconds) catch return self.failure(&req, .too_many_requests, .RateLimited);
            var cookie: [256]u8 = undefined;
            const value = try std.fmt.bufPrint(&cookie, "board_session={s}; Path=/api/v1/; HttpOnly; SameSite=Strict; Max-Age={d}{s}", .{ std.fmt.bytesToHex(issued, .lower), self.config.session_seconds, if (std.mem.startsWith(u8, self.config.public_origin, "https://")) "; Secure" else "" });
            return self.json(&req, .ok, api.Session{ .expires_in = self.config.session_seconds }, value);
        }
        if (req.head.method == .POST and std.mem.eql(u8, target, "/api/v1/logout")) {
            self.auth.logout(token);
            return self.json(&req, .ok, api.Session{ .expires_in = 0 }, "board_session=; Path=/api/v1/; HttpOnly; SameSite=Strict; Max-Age=0");
        }
        if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
        const capabilities = std.mem.eql(u8, target, "/api/v1/capabilities");
        const q = if (capabilities) i.Query{ .realm = self.config.realm, .principal = self.config.principal, .resource = .processes } else parseQuery(target, self.config.realm, self.config.principal) catch return self.failure(&req, .bad_request, .InvalidQuery);
        if (self.now() < self.next_read_ms) return self.failure(&req, .too_many_requests, .RateLimited);
        self.next_read_ms = self.now() + self.config.read_interval_ms;
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var key = client.readKey(self.allocator, self.io, self.config.seed_file) catch return self.failure(&req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        const page = upstream.inspect(q, key) catch |err| {
            if (err == error.AccessDenied) return self.failure(&req, .forbidden, .Forbidden);
            return switch (upstream.last_rejection orelse .AuthorityUnavailable) {
                .HistoryReclaimed => self.failure(&req, .conflict, .HistoryReclaimed),
                .QueryExpired, .Conflict => self.failure(&req, .conflict, .QueryExpired),
                .UnknownProcess => self.failure(&req, .not_found, .NotFound),
                .InvalidRead => self.failure(&req, .bad_request, .InvalidQuery),
                else => self.failure(&req, .service_unavailable, .Unavailable),
            };
        };
        if (page.reader.permissions != client.protocol.permission(.inspect)) return self.failure(&req, .service_unavailable, .UnsafePrincipal);
        if (page.realm != q.realm or page.resource != q.resource or page.pid != q.pid or page.reader.principal != q.principal) return self.failure(&req, .service_unavailable, .Unavailable);
        if (capabilities) return self.json(&req, .ok, api.Capabilities{ .realm = page.realm, .scope_pid = page.reader.pid, .session_seconds = self.config.session_seconds }, null);
        const projection = api.project(page, self.config.lenses) catch return self.failure(&req, .service_unavailable, .Unavailable);
        return self.json(&req, .ok, projection, null);
    }
};
// Route vocabulary is finite; never log a raw path, query or user-provided PID.
fn logRoute(target: []const u8) []const u8 {
    const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
    inline for (.{ "/", "/health", "/openapi/v1.json", "/api/v1/session", "/api/v1/logout", "/api/v1/capabilities", "/api/v1/processes" }) |known| if (std.mem.eql(u8, path, known)) return known;
    if (assets.get(path) != null) return "/assets/{asset}";
    if (browserRoute(path)) return if (std.mem.endsWith(u8, path, "/journey")) "/processes/{pid}/journey" else "/processes/{pid}";
    const query = parseQuery(path, 1, 1) catch return "unmatched";
    return switch (query.resource) {
        .process => "/api/v1/processes/{pid}",
        .mailbox => "/api/v1/processes/{pid}/mailbox",
        .outbox => "/api/v1/processes/{pid}/outbox",
        .effects => "/api/v1/processes/{pid}/effects",
        .payloads => "/api/v1/processes/{pid}/payloads",
        .history => if (std.mem.endsWith(u8, path, "/history")) "/api/v1/processes/{pid}/history" else "/api/v1/processes/{pid}/journey",
        .processes => "/api/v1/processes",
    };
}
fn header(req: *std.http.Server.Request, name: []const u8) !?[]const u8 {
    var iter = req.iterateHeaders();
    var found: ?[]const u8 = null;
    while (iter.next()) |h| if (std.ascii.eqlIgnoreCase(h.name, name)) {
        if (found != null) return error.DuplicateHeader;
        found = h.value;
    };
    return found;
}
fn number(value: []const u8) !u64 {
    if (value.len == 0 or value.len > 16) return error.InvalidQuery;
    for (value) |ch| if (ch < '0' or ch > '9') return error.InvalidQuery;
    const n = try std.fmt.parseInt(u64, value, 10);
    if (n > client.protocol.max_counter) return error.InvalidQuery;
    return n;
}
fn parseQuery(target: []const u8, realm: u64, principal: u8) !i.Query {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..sep];
    const base = "/api/v1/processes";
    var q: i.Query = .{ .realm = realm, .principal = principal, .resource = .processes };
    if (!std.mem.eql(u8, path, base)) {
        if (!std.mem.startsWith(u8, path, base ++ "/")) return error.InvalidQuery;
        var parts = std.mem.splitScalar(u8, path[base.len + 1 ..], '/');
        q.pid = try number(parts.next() orelse return error.InvalidQuery);
        q.resource = if (parts.next()) |part| if (std.mem.eql(u8, part, "journey")) .history else std.meta.stringToEnum(i.Resource, part) orelse return error.InvalidQuery else .process;
        if (parts.next() != null or q.resource == .processes) return error.InvalidQuery;
    }
    if (sep < target.len) {
        var fields = std.mem.splitScalar(u8, target[sep + 1 ..], '&');
        var seen: u8 = 0;
        var cut: i.Cut = .{ .position = 0, .policy_revision = 0, .retained_from = 0 };
        while (fields.next()) |field| {
            const eq = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..eq];
            const value = try number(field[eq + 1 ..]);
            const bit: u8 = if (std.mem.eql(u8, name, "after")) 1 else if (std.mem.eql(u8, name, "position")) 2 else if (std.mem.eql(u8, name, "policy_revision")) 4 else if (std.mem.eql(u8, name, "retained_from")) 8 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            switch (bit) {
                1 => q.after = value,
                2 => cut.position = value,
                4 => cut.policy_revision = value,
                8 => cut.retained_from = value,
                else => unreachable,
            }
        }
        if (seen & 14 == 14) q.cut = cut else if (seen & 14 != 0) return error.InvalidQuery;
    }
    try i.validate(q);
    return q;
}
fn browserRoute(path: []const u8) bool {
    if (std.mem.eql(u8, path, "/")) return true;
    if (!std.mem.startsWith(u8, path, "/processes/")) return false;
    var parts = std.mem.splitScalar(u8, path[11..], '/');
    const pid = number(parts.next() orelse return false) catch return false;
    if (pid == 0) return false;
    if (parts.next()) |part| if (!std.mem.eql(u8, part, "journey")) return false;
    return parts.next() == null;
}
fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
    try io.sleep(.fromMilliseconds(milliseconds), .awake);
}
fn originHost(origin: []const u8, development_allow_insecure_http: bool) ![]const u8 {
    const secure = std.mem.startsWith(u8, origin, "https://");
    if (!secure and !std.mem.startsWith(u8, origin, "http://")) return error.InvalidOrigin;
    if (!secure and !development_allow_insecure_http and !std.mem.startsWith(u8, origin, "http://127.0.0.1:")) return error.RemoteOriginRequiresTLS;
    const host = origin[if (secure) 8 else 7..];
    if (host.len == 0 or host.len > 200 or std.mem.indexOfAny(u8, host, "/@?#\\\r\n\t ") != null) return error.InvalidOrigin;
    return host;
}
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "board", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped" });
    diagnostics.event(.{ .name = "service.starting" });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedBoardConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(16384));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.principal == 0 or config.principal >= client.protocol.max_principals or config.realm == 0 or config.realm > client.protocol.max_counter or config.session_seconds == 0 or config.session_seconds > 3600 or config.request_timeout_ms < 100 or config.request_timeout_ms > 5000 or config.upstream_timeout_ms == 0 or config.upstream_timeout_ms >= config.request_timeout_ms or config.read_interval_ms < 100 or config.read_interval_ms > 5000 or config.lenses.len > 64) return error.InvalidConfig;
    const host = try originHost(config.public_origin, config.development_allow_insecure_http);
    for (config.lenses, 0..) |mapping, index| {
        if (mapping.kind.len > 128 or !std.unicode.utf8ValidateSlice(mapping.kind)) return error.InvalidLens;
        for (config.lenses[0..index]) |previous| if (mapping.pid == previous.pid) return error.DuplicateLens;
    }
    var server: Server = .{ .io = init.io, .allocator = init.gpa, .config = config, .host = host };
    const address = try std.Io.net.IpAddress.parseIp4(config.listen, config.port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    diagnostics.event(.{ .name = "service.ready" });
    while (true) {
        const stream = try listener.accept(init.io);
        defer stream.close(init.io);
        server.observation = .{ .span = diagnostics.begin(.server, null) };
        var request_error: ?anyerror = null;
        var timed_out = false;
        defer server.observation.finish("board.http.request", request_error, timed_out, std.mem.eql(u8, server.observation.route, "/health"));
        const Result = union(enum) { handled: anyerror!void, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(init.io, &results);
        defer select.cancelDiscard();
        try select.concurrent(.timeout, timeout, .{ init.io, config.request_timeout_ms });
        try select.concurrent(.handled, Server.handle, .{ &server, stream });
        switch (try select.await()) {
            .handled => |value| value catch |err| {
                request_error = err;
            },
            .timeout => {
                timed_out = true;
            },
        }
    }
}
test "development HTTP requires explicit opt-in and preserves origin validation" {
    const remote = "http://devbox.local:18102";
    try std.testing.expectError(error.RemoteOriginRequiresTLS, originHost(remote, false));
    try std.testing.expectEqualStrings("devbox.local:18102", try originHost(remote, true));
    try std.testing.expectEqualStrings("127.0.0.1:18102", try originHost("http://127.0.0.1:18102", false));
    try std.testing.expectEqualStrings("board.example", try originHost("https://board.example", false));
    for ([_][]const u8{ "ftp://board.example", "http://", "http://user@board.example", "http://board.example/path", "http://board.example?query", "http://board.example\r\nInjected: yes", "http://board.example\\path" }) |invalid| {
        try std.testing.expectError(error.InvalidOrigin, originHost(invalid, true));
    }
}
test "routes and query bounds reject ambiguous or unsafe identity" {
    try std.testing.expect(browserRoute("/processes/3/journey"));
    try std.testing.expect(!browserRoute("/assets/missing.js"));
    try std.testing.expect(!browserRoute("/processes/3/unknown"));
    try std.testing.expectError(error.InvalidQuery, parseQuery("/api/v1/processes/9007199254740992", 1, 1));
    try std.testing.expectError(error.InvalidQuery, parseQuery("/api/v1/processes?position=3", 1, 1));
    try std.testing.expectError(error.InvalidQuery, parseQuery("/api/v1/processes?after=0&after=0", 1, 1));
    try std.testing.expectError(error.InvalidQuery, parseQuery("/api/v1/processes?url=http://evil", 1, 1));
    _ = Auth;
}
