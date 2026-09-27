//! Public-client inspection plus a separately configured Table query capability.
const std = @import("std");
const telemetry = @import("telemetry");
const client = @import("transit_client");
const api = @import("transit_board_api");
const assets = @import("assets");
const growing = @import("Growing.zig");
const i = client.protocol.Inspection;
const Config = struct {
    upstream: []const u8,
    realm: u64,
    principal: u64,
    profile: enum { legacy_v2, growing_v3 } = .legacy_v2,
    query: ?growing.QueryConfig = null,
    seed_file: []const u8,
    public_origin: []const u8,
    development_allow_insecure_http: bool = false,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8090,
    request_timeout_ms: u32 = 1500,
    upstream_timeout_ms: u32 = 800,
    read_interval_ms: u32 = 100,
};
const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    config: Config,
    host: []const u8,
    observation: telemetry.Http = .{},
    next_read_ms: i64 = 0,

    fn now(self: *Server) i64 {
        return std.Io.Clock.boot.now(self.io).toMilliseconds();
    }
    fn respond(self: *Server, req: *std.http.Server.Request, status: std.http.Status, body: []const u8, mime: []const u8) !void {
        self.observation.status = @backingInt(status);
        const headers: [7]std.http.Header = .{
            .{ .name = "content-type", .value = mime },
            .{ .name = "cache-control", .value = "no-store" },
            .{ .name = "x-content-type-options", .value = "nosniff" },
            .{ .name = "content-security-policy", .value = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'" },
            .{ .name = "referrer-policy", .value = "no-referrer" },
            .{ .name = "permissions-policy", .value = "camera=(), microphone=(), geolocation=()" },
            .{ .name = "x-frame-options", .value = "DENY" },
        };
        try req.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = &headers });
        self.observation.written = true;
    }
    fn json(self: *Server, req: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
        var body: std.Io.Writer.Allocating = .init(self.allocator);
        defer body.deinit();
        var out: std.json.Stringify = .{ .writer = &body.writer };
        try api.Json.write(value, &out);
        return self.respond(req, status, body.written(), "application/json");
    }
    fn failure(self: *Server, req: *std.http.Server.Request, status: std.http.Status, code: @FieldType(api.Error, "err")) !void {
        self.observation.error_type = @tagName(code);
        return self.json(req, status, api.Error{ .err = code });
    }
    fn queryFailure(self: *Server, req: *std.http.Server.Request, upstream: *client.Client, err: anyerror) !void {
        if (err == error.AccessDenied or err == error.QueryAccessDenied) return self.failure(req, .forbidden, .Forbidden);
        if (err == error.UnsafePrincipal) return self.failure(req, .forbidden, .UnsafePrincipal);
        if (err == error.InvalidDocumentCursor) return self.failure(req, .bad_request, .InvalidQuery);
        if (err == error.DocumentHistoryGap or err == error.DocumentResyncRequired) return self.failure(req, .conflict, .HistoryReclaimed);
        if (err == error.QueryChanged or upstream.last_rejection == .StaleStateResource or upstream.last_rejection == .QueryExpired) return self.failure(req, .conflict, .QueryExpired);
        if (err == error.QuerySourceUnavailable or err == error.ExchangeUnavailable or err == error.ResourceUnavailable or err == error.DocumentRetired or upstream.last_rejection == .StateResourceExpired) return self.failure(req, .gone, .StateResourceExpired);
        if (err == error.ExchangeNotFound or err == error.DocumentNotFound or upstream.last_rejection == .UnknownStateResource) return self.failure(req, .not_found, .NotFound);
        if (err == error.QueryBusy) return self.failure(req, .conflict, .QueryBusy);
        if (err == error.IncompleteResult or err == error.HttpReplayGap or err == error.InvalidExchangeCoverage or err == error.GrpcReplayGap or err == error.GrpcInspectionCapacity or err == error.InvalidGrpcCapture or err == error.HttpInspectionCapacity or err == error.WrongExchangeProtocol) return self.failure(req, .conflict, .IncompleteResult);
        if (err == error.InvalidQueryOrdinal) return self.failure(req, .bad_request, .InvalidQueryOrdinal);
        if (err == error.QueryRequestTooLarge) return self.failure(req, .bad_request, .QueryRequestTooLarge);
        if (err == error.Conflict) return self.failure(req, .conflict, .QueryConflict);
        return self.failure(req, .service_unavailable, .Unavailable);
    }
    fn queryRequest(self: *Server, req: *std.http.Server.Request, body: []const u8) !void {
        const config = self.config.query orelse return self.failure(req, .not_found, .QueryDisabled);
        if (req.head.method != .POST) return self.failure(req, .not_found, .NotFound);
        if (self.now() < self.next_read_ms) return self.failure(req, .too_many_requests, .RateLimited);
        self.next_read_ms = self.now() + self.config.read_interval_ms;
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const parsed = std.json.parseFromSlice(api.QueryRequest, arena.allocator(), body, .{}) catch return self.failure(req, .bad_request, .InvalidQuery);
        defer parsed.deinit();
        var upstream = client.Client.init(arena.allocator(), self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        const result = growing.query(&upstream, self.io, config, parsed.value, arena.allocator()) catch |err| {
            if (err == error.UnsupportedQuery) return self.failure(req, .bad_request, .UnsupportedQuery);
            if (err == error.InvalidQueryRequest or err == error.InvalidQueryIdentity) return self.failure(req, .bad_request, .InvalidQuery);
            return self.queryFailure(req, &upstream, err);
        };
        return self.json(req, .ok, result);
    }
    fn growingRequest(self: *Server, req: *std.http.Server.Request, target: []const u8) !void {
        const capabilities = std.mem.eql(u8, target, "/api/v1/capabilities");
        const records = parseRecords(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        const http_metadata = parseMetadata(target, "http") catch return self.failure(req, .bad_request, .InvalidQuery);
        const grpc_metadata = parseMetadata(target, "grpc") catch return self.failure(req, .bad_request, .InvalidQuery);
        const document_metadata = parseDocument(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        const cursor = if (capabilities or records != null or http_metadata != null or grpc_metadata != null or document_metadata != null) growing.Cursor{} else parseAtlas(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        if (self.now() < self.next_read_ms) return self.failure(req, .too_many_requests, .RateLimited);
        self.next_read_ms = self.now() + self.config.read_interval_ms;
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var key = client.readKey(self.allocator, self.io, self.config.seed_file) catch return self.failure(req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        if (capabilities) {
            const reader = growing.identity(&upstream, self.config.realm, self.config.principal, key) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, api.Capabilities{ .profile = .growing_v3, .query_enabled = self.config.query != null, .realm = self.config.realm, .scope_pid = reader.body.identity.pid, .page_size = client.protocol.Growth.page_size, .max_request_bytes = 16384, .http_connector = true, .grpc_connector = true, .documents = true });
        }
        if (records) |page| {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const result = growing.records(&upstream, self.config.realm, self.config.principal, key, page, arena.allocator()) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        if (http_metadata) |selection| {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const result = growing.metadata(api.Http, &upstream, self.config.realm, self.config.principal, key, selection, arena.allocator()) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        if (grpc_metadata) |selection| {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const result = growing.metadata(api.Grpc, &upstream, self.config.realm, self.config.principal, key, selection, arena.allocator()) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        if (document_metadata) |selection| {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const result = growing.document(&upstream, self.config.realm, self.config.principal, key, selection, arena.allocator()) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        const result = growing.atlas(&upstream, self.config.realm, self.config.principal, key, cursor, if (self.config.query) |config| config.connection.resource else null) catch |err| return self.queryFailure(req, &upstream, err);
        return self.json(req, .ok, result);
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
        if (target.len > 1024) return self.failure(&req, .bad_request, .InvalidQuery);
        const query_route = std.mem.eql(u8, target, "/api/v1/query");
        if (query_route) {
            const origin = (try header(&req, "origin")) orelse return self.failure(&req, .forbidden, .InvalidOrigin);
            if (!std.mem.eql(u8, origin, self.config.public_origin)) return self.failure(&req, .forbidden, .InvalidOrigin);
            if (!std.mem.eql(u8, (try header(&req, "content-type")) orelse "", "application/json")) return self.failure(&req, .bad_request, .InvalidQuery);
        }
        const body = req.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(if (query_route) 16384 else 4096)) catch return self.failure(&req, .bad_request, .InvalidQuery);
        defer self.allocator.free(body);
        if (query_route) return self.queryRequest(&req, body);
        if (body.len != 0) return self.failure(&req, .bad_request, .InvalidQuery);
        if (std.mem.eql(u8, target, "/health") and req.head.method == .GET) return self.json(&req, .ok, .{ .ready = true });
        if (std.mem.eql(u8, target, "/openapi/v1.json") and req.head.method == .GET) return self.respond(&req, .ok, assets.openapi, "application/json");
        if (!std.mem.startsWith(u8, target, "/api/")) {
            if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
            if (assets.get(target)) |asset| return self.respond(&req, .ok, asset.bytes, asset.mime);
            const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
            if (browserRoute(path)) return self.respond(&req, .ok, assets.index, "text/html; charset=utf-8");
            return self.failure(&req, .not_found, .NotFound);
        }
        // The deployment boundary admits viewers. Transit still authenticates
        // this instance's read-only principal and authorizes every data read.
        if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
        if (self.config.profile == .growing_v3) return self.growingRequest(&req, target);
        const principal: u8 = @intCast(self.config.principal);
        const capabilities = std.mem.eql(u8, target, "/api/v1/capabilities");
        const sq = parseStateQuery(target, self.config.realm, principal) catch return self.failure(&req, .bad_request, .InvalidQuery);
        const q = if (capabilities or sq != null) i.Query{ .realm = self.config.realm, .principal = principal, .resource = .processes } else parseQuery(target, self.config.realm, principal) catch return self.failure(&req, .bad_request, .InvalidQuery);
        if (self.now() < self.next_read_ms) return self.failure(&req, .too_many_requests, .RateLimited);
        self.next_read_ms = self.now() + self.config.read_interval_ms;
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var key = client.readKey(self.allocator, self.io, self.config.seed_file) catch return self.failure(&req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        if (sq) |query| {
            const page = upstream.state(query, key) catch |err| {
                if (err == error.AccessDenied) return self.failure(&req, .forbidden, .Forbidden);
                return switch (upstream.last_rejection orelse .AuthorityUnavailable) {
                    .HistoryReclaimed => self.failure(&req, .conflict, .HistoryReclaimed),
                    .QueryExpired, .Conflict => self.failure(&req, .conflict, .QueryExpired),
                    .StateResourceExpired => self.failure(&req, .gone, .StateResourceExpired),
                    .InvalidRead => self.failure(&req, .bad_request, .InvalidQuery),
                    else => self.failure(&req, .service_unavailable, .Unavailable),
                };
            };
            if (page.reader.permissions != client.protocol.permission(.inspect)) return self.failure(&req, .service_unavailable, .UnsafePrincipal);
            if (page.realm != query.realm or page.kind != query.kind or page.reader.principal != query.principal) return self.failure(&req, .service_unavailable, .Unavailable);
            if (query.resource) |id| for (page.resources) |slot| if (slot) |resource| {
                if (resource.id != id) return self.failure(&req, .service_unavailable, .Unavailable);
            };
            if (query.pid) |pid| for (page.associations) |slot| if (slot) |association| {
                if (association.pid != pid) return self.failure(&req, .service_unavailable, .Unavailable);
            };
            const projection = api.projectState(page) catch return self.failure(&req, .service_unavailable, .Unavailable);
            return self.json(&req, .ok, projection);
        }
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
        if (capabilities) return self.json(&req, .ok, api.Capabilities{ .realm = page.realm, .scope_pid = page.reader.pid });
        const projection = api.project(page) catch return self.failure(&req, .service_unavailable, .Unavailable);
        return self.json(&req, .ok, projection);
    }
};
// Route vocabulary is finite; never log a raw path, query or user-provided PID.
fn logRoute(target: []const u8) []const u8 {
    if (std.mem.eql(u8, target, "/api/v1/query")) return "/api/v1/query";
    if (std.mem.startsWith(u8, target, "/api/v1/atlas")) return "/api/v1/atlas";
    const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
    inline for (.{ "/", "/health", "/openapi/v1.json", "/api/v1/capabilities", "/api/v1/processes" }) |known| if (std.mem.eql(u8, path, known)) return known;
    if (assets.get(path) != null) return "/assets/{asset}";
    if ((parseRecords(path) catch null) != null) return "/api/v1/resources/{resource}/records";
    if ((parseMetadata(path, "http") catch null) != null) return "/api/v1/resources/{resource}/http/{exchange}";
    if ((parseDocument(path) catch null) != null) return "/api/v1/resources/{resource}/documents/{document}";
    if ((parseMetadata(path, "grpc") catch null) != null) return "/api/v1/resources/{resource}/grpc/{exchange}";
    if (parseStateQuery(path, 1, 1) catch null) |q| return switch (q.kind) {
        .resources => if (q.resource == null) "/api/v1/resources" else "/api/v1/resources/{resource}",
        .associations => "/api/v1/processes/{pid}/associations",
        .entries => "/api/v1/resources/{resource}/entries",
        else => "unmatched",
    };
    if (std.mem.eql(u8, path, "/resources")) return "/resources";
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
fn parseStateQuery(target: []const u8, realm: u64, principal: u8) !?client.protocol.State.Query {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..sep];
    const resources = "/api/v1/resources";
    const processes = "/api/v1/processes/";
    var q: client.protocol.State.Query = .{ .realm = realm, .principal = principal, .kind = .resources };
    if (std.mem.eql(u8, path, resources)) {} else if (std.mem.startsWith(u8, path, resources ++ "/")) {
        var parts = std.mem.splitScalar(u8, path[resources.len + 1 ..], '/');
        q.resource = try number(parts.next() orelse return error.InvalidQuery);
        if (parts.next()) |part| {
            if (!std.mem.eql(u8, part, "entries")) return error.InvalidQuery;
            q.kind = .entries;
        }
        if (parts.next() != null) return error.InvalidQuery;
    } else if (std.mem.startsWith(u8, path, processes) and std.mem.endsWith(u8, path, "/associations")) {
        q.pid = try number(path[processes.len .. path.len - "/associations".len]);
        q.kind = .associations;
    } else return null;
    // Reuse the single continuation grammar; no arbitrary URLs or query fields.
    if (sep < target.len) {
        var buffer: [1200]u8 = undefined;
        const parsed = try parseQuery(try std.fmt.bufPrint(&buffer, "/api/v1/processes{s}", .{target[sep..]}), realm, principal);
        q.cut = parsed.cut;
        q.after = std.math.cast(u16, parsed.after) orelse return error.InvalidQuery;
    }
    try client.protocol.State.validateQuery(q);
    return q;
}
fn parseMetadata(target: []const u8, comptime protocol: []const u8) !?growing.ExchangeCursor {
    const prefix = "/api/v1/resources/";
    if (!std.mem.startsWith(u8, target, prefix)) return null;
    const split = std.mem.indexOf(u8, target[prefix.len..], "/" ++ protocol ++ "/") orelse return null;
    const resource = try number(target[prefix.len..][0..split]);
    const value = target[prefix.len + split + protocol.len + 2 ..];
    if (resource == 0 or value.len == 0 or value.len > 20 or value[0] == '0') return error.InvalidQuery;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidQuery;
    return .{ .resource = resource, .exchange = std.fmt.parseInt(u64, value, 10) catch return error.InvalidQuery };
}
fn parseDocument(target: []const u8) !?growing.DocumentCursor {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const selected = (try parseMetadata(target[0..sep], "documents")) orelse return null;
    var result: growing.DocumentCursor = .{ .resource = selected.resource, .document = selected.exchange };
    if (sep < target.len) {
        var fields = std.mem.splitScalar(u8, target[sep + 1 ..], '&');
        var seen: u8 = 0;
        while (fields.next()) |field| {
            const equal = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..equal];
            const value = field[equal + 1 ..];
            const bit: u8 = if (std.mem.eql(u8, name, "revision")) 1 else if (std.mem.eql(u8, name, "after")) 2 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            if (bit == 1) {
                result.revision = try number(value);
            } else {
                if (value.len == 0 or value.len > 128 * 2 or value.len % 2 != 0) return error.InvalidQuery;
                for (value) |byte| if (!(byte >= '0' and byte <= '9') and !(byte >= 'a' and byte <= 'f')) return error.InvalidQuery;
                var bytes: [128]u8 = undefined;
                result.after = try api.Document.adapter.station.ImmutableIndex.Key.init(std.fmt.hexToBytes(&bytes, value) catch return error.InvalidQuery);
            }
        }
        if (result.after != null and result.revision == null) return error.InvalidQuery;
    }
    return result;
}
fn parseRecords(target: []const u8) !?growing.RecordsCursor {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..sep];
    const prefix = "/api/v1/resources/";
    const suffix = "/records";
    if (!std.mem.startsWith(u8, path, prefix) or !std.mem.endsWith(u8, path, suffix)) return null;
    if (path.len <= prefix.len + suffix.len) return error.InvalidQuery;
    var result: growing.RecordsCursor = .{ .resource = try number(path[prefix.len .. path.len - suffix.len]) };
    if (result.resource == 0) return error.InvalidQuery;
    if (sep < target.len) {
        var fields = std.mem.splitScalar(u8, target[sep + 1 ..], '&');
        var seen: u8 = 0;
        while (fields.next()) |field| {
            const equal = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..equal];
            const value = field[equal + 1 ..];
            const bit: u8 = if (std.mem.eql(u8, name, "revision")) 1 else if (std.mem.eql(u8, name, "after")) 2 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            if (bit == 1) {
                result.revision = try number(value);
            } else {
                if (value.len == 0 or value.len > client.protocol.Growth.key_bytes * 2 or value.len % 2 != 0) return error.InvalidQuery;
                for (value) |byte| if (!(byte >= '0' and byte <= '9') and !(byte >= 'a' and byte <= 'f')) return error.InvalidQuery;
                var bytes: [client.protocol.Growth.key_bytes]u8 = undefined;
                result.after = try client.protocol.Value.init(std.fmt.hexToBytes(&bytes, value) catch return error.InvalidQuery);
            }
        }
        if (result.after != null and result.revision == null) return error.InvalidQuery;
    }
    return result;
}
fn parseAtlas(target: []const u8) !growing.Cursor {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    if (!std.mem.eql(u8, target[0..sep], "/api/v1/atlas")) return error.InvalidQuery;
    var result: growing.Cursor = .{};
    if (sep < target.len) {
        var fields = std.mem.splitScalar(u8, target[sep + 1 ..], '&');
        var seen: u8 = 0;
        while (fields.next()) |field| {
            const equal = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..equal];
            const value = try number(field[equal + 1 ..]);
            const bit: u8 = if (std.mem.eql(u8, name, "position")) 1 else if (std.mem.eql(u8, name, "process_after")) 2 else if (std.mem.eql(u8, name, "resource_after")) 4 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            switch (bit) {
                1 => result.position = value,
                2 => result.process_after = value,
                4 => result.resource_after = value,
                else => unreachable,
            }
        }
        if (seen & 6 != 0 and result.position == null) return error.InvalidQuery;
    }
    return result;
}
fn browserRoute(path: []const u8) bool {
    if (std.mem.eql(u8, path, "/atlas") or std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/resources")) return true;
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
    var diagnostics = telemetry.Runtime.init(init.io, "transit-board", try telemetry.Config.environment(init.environ_map));
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
    if (config.principal == 0 or (if (config.profile == .legacy_v2) config.principal >= client.protocol.max_principals else config.principal > client.protocol.max_counter) or config.realm == 0 or config.realm > client.protocol.max_counter or config.request_timeout_ms < 100 or config.request_timeout_ms > 5000 or config.upstream_timeout_ms == 0 or config.upstream_timeout_ms >= config.request_timeout_ms or config.read_interval_ms < 100 or config.read_interval_ms > 5000) return error.InvalidConfig;
    if (config.query) |query| {
        if (config.profile != .growing_v3 or query.connection.realm != config.realm or query.connection.principal == config.principal or query.connection.principal == 0) return error.InvalidQueryConfiguration;
    }
    const host = try originHost(config.public_origin, config.development_allow_insecure_http);
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
}
test "record cursors require an exact bounded key and original revision" {
    const t = std.testing;
    const page = (try parseRecords("/api/v1/resources/7/records?revision=42&after=0045ff")).?;
    try t.expectEqual(@as(u64, 7), page.resource);
    try t.expectEqual(@as(?u64, 42), page.revision);
    try t.expectEqualStrings("\x00E\xff", page.after.?.slice());
    try t.expectEqualStrings("/api/v1/resources/{resource}/records", logRoute("/api/v1/resources/7/records?after=private"));
    try t.expectEqual(null, try parseRecords("/api/v1/atlas"));
    inline for (.{
        "/api/v1/resources/0/records",
        "/api/v1/resources/9007199254740992/records",
        "/api/v1/resources/7/records?after=00",
        "/api/v1/resources/7/records?revision=1&after=",
        "/api/v1/resources/7/records?revision=1&after=0",
        "/api/v1/resources/7/records?revision=1&after=FF",
        "/api/v1/resources/7/records?revision=1&after=%00",
        "/api/v1/resources/7/records?revision=1&revision=2",
        "/api/v1/resources/7/records?view=3",
    }) |invalid| try t.expectError(error.InvalidQuery, parseRecords(invalid));
}
test "HTTP metadata paths preserve full-width exchange identities" {
    const t = std.testing;
    const target = "/api/v1/resources/7/http/18446744073709551615";
    try t.expectEqual(std.math.maxInt(u64), (try parseMetadata(target, "http")).?.exchange);
    try t.expectEqualStrings("/api/v1/resources/{resource}/http/{exchange}", logRoute(target));
    inline for (.{ "0", "01", "+1", "18446744073709551616", "1?view=1", "1/body", "" }) |id| try t.expectError(error.InvalidQuery, parseMetadata("/api/v1/resources/7/http/" ++ id, "http"));
}

test "Document metadata selection binds bounded continuation and hides cursor from logs" {
    const t = std.testing;
    const target = "/api/v1/resources/7/documents/18446744073709551615?revision=9&after=52";
    const cursor = (try parseDocument(target)).?;
    try t.expectEqual(std.math.maxInt(u64), cursor.document);
    try t.expectEqual(@as(?u64, 9), cursor.revision);
    try t.expectEqualStrings("R", cursor.after.?.slice());
    try t.expectEqualStrings("/api/v1/resources/{resource}/documents/{document}", logRoute(target));
    inline for (.{ "?after=52", "?revision=9&after=5g", "?revision=9&revision=10", "?value=secret", "/body" }) |suffix| try t.expectError(error.InvalidQuery, parseDocument("/api/v1/resources/7/documents/1" ++ suffix));
}
