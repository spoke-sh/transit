//! Public-client inspection plus a separately configured Table query capability.
const std = @import("std");
const telemetry = @import("telemetry");
const http_server = @import("transit_http_server");
const hosting = @import("transit_serving_http");
const application = @import("transit_station_app");
const client = @import("transit_client");
const api = @import("transit_board_api");
const assets = @import("assets");
const growing = @import("Growing.zig");
const i = client.protocol.Growth.Inspection;
const Config = struct {
    upstream: []const u8,
    realm: u64,
    principal: u64,
    profile: enum { native_v1 } = .native_v1,
    query: ?growing.UnifiedQueryConfig = null,
    reactive: ?struct { principal: u64, seed_file: []const u8, gateway: hosting.Gateway } = null,
    application: ?application.Host.Config = null,
    interface: ?application.Native.Scope = null,
    seed_file: []const u8,
    public_origin: []const u8,
    development_allow_insecure_http: bool = false,
    listen: []const u8 = "127.0.0.1",
    port: u16 = 8090,
    request_timeout_ms: u32 = 1500,
    upstream_timeout_ms: u32 = 800,
    read_interval_ms: u32 = 100,
    http_connections: u8 = 16,
    http_requests: u8 = 4,
};
const Server = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    config: Config,
    host: []const u8,
    observation: telemetry.Http = .{},
    next_read_ms: *std.atomic.Value(i64),
    query_lock: *std.Io.Mutex,

    fn now(self: *Server) i64 {
        return std.Io.Clock.boot.now(self.io).toMilliseconds();
    }
    fn admitRead(self: *Server) bool {
        const current = self.now();
        var next = self.next_read_ms.load(.monotonic);
        while (current >= next) next = self.next_read_ms.cmpxchgWeak(next, current + self.config.read_interval_ms, .monotonic, .monotonic) orelse return true;
        return false;
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
        if (err == error.AccessDenied or err == error.QueryAccessDenied or err == error.QueryDenied) return self.failure(req, .forbidden, .Forbidden);
        if (err == error.UnsafePrincipal) return self.failure(req, .forbidden, .UnsafePrincipal);
        if (err == error.InvalidDocumentCursor) return self.failure(req, .bad_request, .InvalidQuery);
        if (err == error.DocumentHistoryGap or err == error.DocumentResyncRequired) return self.failure(req, .conflict, .HistoryReclaimed);
        if (err == error.QueryChanged or err == error.QueryReadConflict or upstream.last_rejection == .StaleStateResource or upstream.last_rejection == .QueryExpired) return self.failure(req, .conflict, .QueryExpired);
        if (err == error.QuerySourceUnavailable or err == error.ExchangeUnavailable or err == error.ResourceUnavailable or err == error.DocumentRetired or upstream.last_rejection == .StateResourceExpired) return self.failure(req, .gone, .StateResourceExpired);
        if (err == error.ExchangeNotFound or err == error.DocumentNotFound or upstream.last_rejection == .UnknownStateResource) return self.failure(req, .not_found, .NotFound);
        if (err == error.QueryBusy) return self.failure(req, .conflict, .QueryBusy);
        if ((err == error.Rejected or err == error.Conflict) and
            (upstream.last_rejection == .ConflictingRetry or upstream.last_rejection == .SequenceGap or upstream.last_rejection == .RetryHorizonExceeded))
            return self.failure(req, .conflict, .QueryConflict);
        if (err == error.IncompleteResult or err == error.HttpReplayGap or err == error.InvalidExchangeCoverage or err == error.GrpcReplayGap or err == error.GrpcInspectionCapacity or err == error.InvalidGrpcCapture or err == error.HttpInspectionCapacity or err == error.WrongExchangeProtocol) return self.failure(req, .conflict, .IncompleteResult);
        if (err == error.InvalidQueryOrdinal) return self.failure(req, .bad_request, .InvalidQueryOrdinal);
        if (err == error.QueryRequestTooLarge) return self.failure(req, .bad_request, .QueryRequestTooLarge);
        if (upstream.last_rejection == .HistoryReclaimed) return self.failure(req, .conflict, .HistoryReclaimed);
        if (upstream.last_rejection == .UnknownProcess) return self.failure(req, .not_found, .NotFound);
        if (upstream.last_rejection == .InvalidRead) return self.failure(req, .bad_request, .InvalidQuery);
        if (err == error.Conflict) return self.failure(req, .conflict, .QueryConflict);
        return self.failure(req, .service_unavailable, .Unavailable);
    }
    fn applicationRequest(self: *Server, req: *std.http.Server.Request, body: []const u8) !void {
        const config = self.config.application orelse return self.failure(req, .not_found, .NotFound);
        if (req.head.method != .POST) return self.failure(req, .not_found, .NotFound);
        if (!self.admitRead()) return self.failure(req, .too_many_requests, .RateLimited);
        const parsed = application.protocol.Json.parseFromSlice(application.Host.Request, self.allocator, body) catch return self.failure(req, .bad_request, .InvalidQuery);
        defer parsed.deinit();
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var result = application.Host.run(self.allocator, &upstream, config, parsed.value) catch |err| {
            if (err == error.ApplicationOperatorDenied or err == error.ApplicationOperationDenied) return self.failure(req, .forbidden, .Forbidden);
            if (err == error.ApplicationOperationConflict or err == error.ApplicationAlreadyApplied) return self.failure(req, .conflict, .QueryConflict);
            if (err == error.InvalidApplicationProgram) return self.failure(req, .bad_request, .UnsupportedQuery);
            if (err == error.ApplicationScopeChanged or err == error.ApplicationDigestMismatch or err == error.InvalidApplicationSelection or err == error.InvalidApplicationScope or err == error.InvalidApplicationOperation or err == error.InvalidApplicationPart or err == error.InvalidApplicationPolicy or err == error.InvalidApplicationProposal or err == error.InvalidSequence) return self.failure(req, .bad_request, .InvalidQuery);
            return self.queryFailure(req, &upstream, err);
        };
        defer result.deinit();
        return self.json(req, .ok, result.value);
    }
    fn builtinInterface(self: *Server) !application.Host.Owned {
        var original = try application.Host.compile(self.allocator, @embedFile("board.sql"));
        defer original.deinit();
        var definition = original.value.compiled.definition;
        definition.realm = self.config.realm;
        var buffer: [application.Model.max_program_bytes]u8 = undefined;
        var compiled = try application.Host.compile(self.allocator, try application.Api.canonical(definition, &buffer));
        const value = compiled.value.compiled;
        compiled.value = .{ .builtin = value };
        return compiled;
    }
    fn interfaceRequest(self: *Server, req: *std.http.Server.Request) !void {
        const scope = self.config.interface orelse {
            var result = try self.builtinInterface();
            defer result.deinit();
            return self.json(req, .ok, result.value);
        };
        if (!self.admitRead()) return self.failure(req, .too_many_requests, .RateLimited);
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var key = client.readKey(self.allocator, self.io, self.config.seed_file) catch return self.failure(req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        _ = growing.identity(&upstream, self.config.realm, self.config.principal, key) catch |err| return self.queryFailure(req, &upstream, err);
        var result = application.Host.published(self.allocator, .{ .wire = &upstream, .realm = self.config.realm, .principal = self.config.principal, .key = key }, scope) catch |err| {
            if (err == error.ApplicationNotPublished) {
                var builtin = try self.builtinInterface();
                defer builtin.deinit();
                return self.json(req, .ok, builtin.value);
            }
            if (err == error.ApplicationPublicationChanged) return self.failure(req, .conflict, .QueryConflict);
            return self.queryFailure(req, &upstream, err);
        };
        defer result.deinit();
        return self.json(req, .ok, result.value);
    }
    fn unifiedQueryRequest(self: *Server, req: *std.http.Server.Request, body: []const u8) !void {
        const config = self.config.query orelse return self.failure(req, .not_found, .QueryDisabled);
        if (req.head.method != .POST) return self.failure(req, .not_found, .NotFound);
        if (!self.query_lock.tryLock()) return self.failure(req, .too_many_requests, .RateLimited);
        defer self.query_lock.unlock(self.io);
        if (!self.admitRead()) return self.failure(req, .too_many_requests, .RateLimited);
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const parsed = std.json.parseFromSlice(api.UnifiedQueryRequest, arena.allocator(), body, .{}) catch return self.failure(req, .bad_request, .InvalidQuery);
        var upstream = client.Client.init(arena.allocator(), self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        const result = growing.unifiedQuery(&upstream, self.io, config, parsed.value, arena.allocator()) catch |err| {
            // Compiler diagnostics are finite errors, never SQL/payload text.
            switch (err) {
                error.StatementTooLarge, error.InvalidSqlEncoding, error.UnsupportedStatement, error.InvalidSqlSyntax, error.UnsupportedConstruct, error.CommentTooDeep, error.LiteralTooLarge, error.LiteralOutOfRange, error.InvalidColumnName, error.UnknownSource, error.UnknownColumn, error.UnknownQualifier, error.DuplicateProjection, error.InvalidProjection, error.UnsupportedAggregate, error.UnsupportedAggregateLimit, error.UnsupportedNullComparison, error.TypeMismatch, error.CellTooLarge, error.InvalidBinaryLiteral => return self.failure(req, .bad_request, .UnsupportedQuery),
                else => {},
            }
            if (err == error.QueryDraftConflict or err == error.QueryDraftActive or err == error.QueryDraftClosed or err == error.QueryDraftExhausted) return self.failure(req, .conflict, .QueryConflict);
            if (err == error.InvalidSqlCursor or err == error.InvalidQuerySearch or err == error.InvalidQueryDraft or err == error.QueryDraftNotFound or err == error.InvalidQueryRequest or err == error.InvalidQueryUpload or err == error.InvalidFrame or err == error.InvalidQueryIdentity or err == error.QueryIdentityMismatch or err == error.QueryBudgetExceeded or err == error.InvalidQueryCursor or err == error.InvalidDocumentInteger or err == error.DocumentEncodingCapacity) return self.failure(req, .bad_request, .InvalidQuery);
            return self.queryFailure(req, &upstream, err);
        };
        return self.json(req, .ok, result);
    }
    fn growingRequest(self: *Server, req: *std.http.Server.Request, target: []const u8) !void {
        const capabilities = std.mem.eql(u8, target, "/api/v1/capabilities");
        const participation = parseParticipation(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        const records = parseRecords(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        const http_metadata = parseMetadata(target, "http") catch return self.failure(req, .bad_request, .InvalidQuery);
        const grpc_metadata = parseMetadata(target, "grpc") catch return self.failure(req, .bad_request, .InvalidQuery);
        const document_metadata = parseDocument(target) catch return self.failure(req, .bad_request, .InvalidQuery);
        const special = capabilities or participation != null or records != null or http_metadata != null or grpc_metadata != null or document_metadata != null;
        const atlas = std.mem.eql(u8, target, "/api/v1/atlas") or std.mem.startsWith(u8, target, "/api/v1/atlas?");
        const state_query = if (special or atlas) null else parseStateQuery(target, self.config.realm, self.config.principal) catch return self.failure(req, .bad_request, .InvalidQuery);
        const inspection_query = if (special or atlas or state_query != null) null else parseQuery(target, self.config.realm, self.config.principal) catch return self.failure(req, .bad_request, .InvalidQuery);
        const cursor = if (atlas) parseAtlas(target) catch return self.failure(req, .bad_request, .InvalidQuery) else growing.Cursor{};
        if (!self.admitRead()) return self.failure(req, .too_many_requests, .RateLimited);
        var upstream = client.Client.init(self.allocator, self.io, self.config.upstream);
        defer upstream.deinit();
        upstream.timeout_ms = self.config.upstream_timeout_ms;
        upstream.observer = self.observation.span.runtime;
        upstream.parent_context = self.observation.span.context;
        var key = client.readKey(self.allocator, self.io, self.config.seed_file) catch return self.failure(req, .service_unavailable, .Unavailable);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        if (capabilities) {
            const reader = growing.identity(&upstream, self.config.realm, self.config.principal, key) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, api.Capabilities{ .profile = .native_v1, .query_enabled = self.config.query != null, .realm = self.config.realm, .scope_pid = reader.body.identity.pid, .page_size = client.protocol.Growth.page_size, .max_request_bytes = 49152, .http_connector = true, .grpc_connector = true, .documents = true, .reactive_table = self.config.reactive != null });
        }
        if (participation) |selection| {
            const result = growing.participation(&upstream, self.config.realm, self.config.principal, key, selection) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
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
        if (inspection_query) |selector| {
            const result = growing.inspect(&upstream, self.config.realm, self.config.principal, key, selector) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        if (state_query) |selector| {
            const result = growing.state(&upstream, self.config.realm, self.config.principal, key, selector) catch |err| return self.queryFailure(req, &upstream, err);
            return self.json(req, .ok, result);
        }
        const query_resource = if (self.config.query) |config| config.connection.resource else null;
        var result = growing.atlas(&upstream, self.config.realm, self.config.principal, key, cursor, query_resource) catch |err| return self.queryFailure(req, &upstream, err);
        result.query_version = if (result.query_resource == null) null else 1;
        return self.json(req, .ok, result);
    }
    fn handle(self: *Server, request: *std.http.Server.Request) anyerror!void {
        var req = request.*;
        self.observation.received(&req, logRoute(req.head.target), false);
        const host = (try header(&req, "host")) orelse return self.failure(&req, .forbidden, .InvalidOrigin);
        if (!std.mem.eql(u8, host, self.host)) return self.failure(&req, .forbidden, .InvalidOrigin);
        if (try header(&req, "origin")) |origin| if (!std.mem.eql(u8, origin, self.config.public_origin)) return self.failure(&req, .forbidden, .InvalidOrigin);
        for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-for" }) |name| if (try header(&req, name) != null) return self.failure(&req, .forbidden, .InvalidOrigin);
        const target = try self.allocator.dupe(u8, req.head.target);
        defer self.allocator.free(target);
        if (target.len > 1024) return self.failure(&req, .bad_request, .InvalidQuery);
        const application_route = std.mem.eql(u8, target, "/api/v1/application");
        const query_route = std.mem.eql(u8, target, "/api/v1/query");
        if (query_route or application_route) {
            const origin = (try header(&req, "origin")) orelse return self.failure(&req, .forbidden, .InvalidOrigin);
            if (!std.mem.eql(u8, origin, self.config.public_origin)) return self.failure(&req, .forbidden, .InvalidOrigin);
            if (!std.mem.eql(u8, (try header(&req, "content-type")) orelse "", "application/json")) return self.failure(&req, .bad_request, .InvalidQuery);
        }
        const body = req.readerExpectNone(&.{}).allocRemaining(self.allocator, .limited(if (application_route) application.Host.max_body_bytes else if (query_route) 49152 else 4096)) catch return self.failure(&req, .bad_request, .InvalidQuery);
        defer self.allocator.free(body);
        if (application_route) return self.applicationRequest(&req, body);
        if (query_route) return self.unifiedQueryRequest(&req, body);
        if (body.len != 0) return self.failure(&req, .bad_request, .InvalidQuery);
        if (std.mem.eql(u8, target, "/api/v1/interface") and req.head.method == .GET) return self.interfaceRequest(&req);
        if (std.mem.eql(u8, target, "/health") and req.head.method == .GET) return self.json(&req, .ok, .{ .ready = true });
        if (std.mem.eql(u8, target, "/openapi/v1.json") and req.head.method == .GET) return self.respond(&req, .ok, assets.openapi, "application/json");
        if (!std.mem.startsWith(u8, target, "/api/")) {
            if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
            if (assets.get(target)) |asset| return self.respond(&req, .ok, asset.bytes, asset.mime);
            const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
            if (browserRoute(path)) return self.respond(&req, .ok, assets.index, "text/html; charset=utf-8");
            // This is only the public static artifact. The client resolves a
            // custom path from a current authorized definition, including absence.
            // Native-read throttling must not strand a browser document navigation.
            if (self.config.profile == .native_v1 and !reservedBrowserPath(path)) return self.respond(&req, .ok, assets.index, "text/html; charset=utf-8");
            return self.failure(&req, .not_found, .NotFound);
        }
        // The deployment boundary admits viewers. Transit still authenticates
        // this instance's read-only principal and authorizes every data read.
        if (req.head.method != .GET) return self.failure(&req, .not_found, .NotFound);
        return self.growingRequest(&req, target);
    }
};
// Route vocabulary is finite; never log a raw path, query or user-provided PID.
fn logRoute(target: []const u8) []const u8 {
    if (std.mem.eql(u8, target, "/api/v1/interface")) return "/api/v1/interface";
    if (std.mem.eql(u8, target, "/api/v1/application")) return "/api/v1/application";
    if (std.mem.eql(u8, target, "/api/v1/query")) return "/api/v1/query";
    if (std.mem.startsWith(u8, target, "/api/v1/atlas")) return "/api/v1/atlas";
    const path = target[0 .. std.mem.indexOfScalar(u8, target, '?') orelse target.len];
    inline for (.{ "/", "/health", "/openapi/v1.json", "/api/v1/capabilities", "/api/v1/processes", "/atlas", "/activity", "/definition", "/operations", "/recovery/definition" }) |known| if (std.mem.eql(u8, path, known)) return known;
    if (assets.get(path) != null) return "/assets/{asset}";
    if ((parseParticipation(path) catch null) != null) return "/api/v1/resources/{resource}/participation";
    if ((parseRecords(path) catch null) != null) return "/api/v1/resources/{resource}/records";
    if ((parseMetadata(path, "http") catch null) != null) return "/api/v1/resources/{resource}/http/{exchange}";
    if ((parseDocument(path) catch null) != null) return "/api/v1/resources/{resource}/documents/{document}";
    if ((parseMetadata(path, "grpc") catch null) != null) return "/api/v1/resources/{resource}/grpc/{exchange}";
    if (parseStateQuery(path, 1, 1) catch null) |q| return switch (q.kind) {
        .resources => if (q.resource == null) "/api/v1/resources" else "/api/v1/resources/{resource}",
        .associations => "/api/v1/processes/{pid}/associations",
        .entries => "/api/v1/resources/{resource}/entries",
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
fn parseQuery(target: []const u8, realm: u64, principal: u64) !i.Query {
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..sep];
    const base = "/api/v1/processes";
    _ = realm;
    _ = principal;
    var q: i.Query = .{ .resource = .processes };
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
fn parseStateQuery(target: []const u8, realm: u64, principal: u64) !?api.StateQuery {
    _ = realm;
    _ = principal;
    const sep = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..sep];
    const resources = "/api/v1/resources";
    const processes = "/api/v1/processes/";
    var q: api.StateQuery = .{ .kind = .resources };
    if (std.mem.eql(u8, path, resources)) {} else if (std.mem.startsWith(u8, path, resources ++ "/")) {
        var parts = std.mem.splitScalar(u8, path[resources.len + 1 ..], '/');
        q.resource = try number(parts.next() orelse return error.InvalidQuery);
        if (q.resource == 0) return error.InvalidQuery;
        if (parts.next()) |part| {
            if (!std.mem.eql(u8, part, "entries")) return error.InvalidQuery;
            q.kind = .entries;
        }
        if (parts.next() != null) return error.InvalidQuery;
    } else if (std.mem.startsWith(u8, path, processes) and std.mem.endsWith(u8, path, "/associations")) {
        q.pid = try number(path[processes.len .. path.len - "/associations".len]);
        if (q.pid == 0) return error.InvalidQuery;
        q.kind = .associations;
    } else return null;
    if (sep < target.len) {
        var fields = std.mem.splitScalar(u8, target[sep + 1 ..], '&');
        var seen: u8 = 0;
        var cut: i.Cut = .{ .position = 0, .policy_revision = 0, .retained_from = 0 };
        while (fields.next()) |field| {
            const eq = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..eq];
            const value = field[eq + 1 ..];
            const bit: u8 = if (std.mem.eql(u8, name, "position")) 1 else if (std.mem.eql(u8, name, "policy_revision")) 2 else if (std.mem.eql(u8, name, "retained_from")) 4 else if (std.mem.eql(u8, name, "after")) 8 else if (std.mem.eql(u8, name, "after_key")) 16 else if (std.mem.eql(u8, name, "revision")) 32 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            switch (bit) {
                1 => cut.position = try number(value),
                2 => cut.policy_revision = try number(value),
                4 => cut.retained_from = try number(value),
                8 => q.after = try number(value),
                16 => {
                    var key: [client.protocol.Growth.key_bytes]u8 = undefined;
                    q.after_key = try client.Value.init(std.fmt.hexToBytes(&key, value) catch return error.InvalidQuery);
                    try client.protocol.Growth.validateKey(q.after_key.?);
                },
                32 => q.revision = try number(value),
                else => unreachable,
            }
        }
        if (seen & 7 != 0 and seen & 7 != 7) return error.InvalidQuery;
        if (seen & 7 == 7) q.cut = cut;
        if (q.after != 0 and q.cut == null) return error.InvalidQuery;
        if (q.after_key != null and (q.revision == null or q.cut == null)) return error.InvalidQuery;
        if (q.kind != .entries and seen & 48 != 0) return error.InvalidQuery;
        if (q.kind == .entries and q.after != 0) return error.InvalidQuery;
    }
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
fn parseParticipation(target: []const u8) !?growing.ParticipationCursor {
    const end = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    const path = target[0..end];
    const prefix = "/api/v1/resources/";
    const suffix = "/participation";
    if (!std.mem.startsWith(u8, path, prefix) or !std.mem.endsWith(u8, path, suffix)) return null;
    if (path.len <= prefix.len + suffix.len) return error.InvalidQuery;
    const id = try number(path[prefix.len .. path.len - suffix.len]);
    if (id == 0) return error.InvalidQuery;
    var result: growing.ParticipationCursor = .{ .resource = id };
    if (end != target.len) {
        var fields = std.mem.splitScalar(u8, target[end + 1 ..], '&');
        var seen: u8 = 0;
        while (fields.next()) |field| {
            const split = std.mem.indexOfScalar(u8, field, '=') orelse return error.InvalidQuery;
            const name = field[0..split];
            const value = try number(field[split + 1 ..]);
            if (value == 0) return error.InvalidQuery;
            const bit: u8 = if (std.mem.eql(u8, name, "after")) 1 else if (std.mem.eql(u8, name, "pid")) 2 else if (std.mem.eql(u8, name, "association_after")) 4 else if (std.mem.eql(u8, name, "position")) 8 else return error.InvalidQuery;
            if (seen & bit != 0) return error.InvalidQuery;
            seen |= bit;
            switch (bit) {
                1 => result.after = value,
                2 => result.pid = value,
                4 => result.association_after = value,
                8 => result.position = value,
                else => unreachable,
            }
        }
        if ((seen & 5 != 0) != (seen & 8 != 0)) return error.InvalidQuery;
        if ((seen & 1 != 0 and seen & 6 != 0) or (seen & 4 != 0 and seen & 2 == 0)) return error.InvalidQuery;
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
fn reservedBrowserPath(path: []const u8) bool {
    application.Model.path(path) catch return true;
    return false;
}
fn browserRoute(path: []const u8) bool {
    if (std.mem.eql(u8, path, "/recovery/definition")) return true;
    if (std.mem.eql(u8, path, "/definition") or std.mem.eql(u8, path, "/operations") or std.mem.eql(u8, path, "/activity") or std.mem.eql(u8, path, "/atlas") or std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/resources")) return true;
    if (!std.mem.startsWith(u8, path, "/processes/")) return false;
    var parts = std.mem.splitScalar(u8, path[11..], '/');
    const pid = number(parts.next() orelse return false) catch return false;
    if (pid == 0) return false;
    if (parts.next()) |part| if (!std.mem.eql(u8, part, "journey")) return false;
    return parts.next() == null;
}
const Shared = struct {
    config: Config,
    host: []const u8,
    diagnostics: *telemetry.Runtime,
    next_read_ms: std.atomic.Value(i64) = .init(0),
    query_lock: std.Io.Mutex = .init,
    reactive: ?*hosting.Context = null,

    pub fn isControl(self: *@This(), request: *std.http.Server.Request) bool {
        return if (self.reactive) |context| context.isControl(request) else false;
    }

    pub fn handle(self: *@This(), io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
        if (self.reactive) |context| if (std.mem.startsWith(u8, request.head.target, "/reactive/v1/")) return context.handle(io, allocator, request);
        var server: Server = .{
            .io = io,
            .allocator = allocator,
            .config = self.config,
            .host = self.host,
            .next_read_ms = &self.next_read_ms,
            .query_lock = &self.query_lock,
            .observation = .{ .span = self.diagnostics.begin(.server, null) },
        };
        var failure: ?anyerror = null;
        defer server.observation.finish("board.http.request", failure, if (failure) |err| err == error.Cancelled else false, std.mem.eql(u8, server.observation.route, "/health"));
        http_server.deadline(io, self.config.request_timeout_ms, Server.handle, .{ &server, request }) catch |err| {
            failure = err;
            return err;
        };
    }
    pub fn connectionError(self: *@This(), err: anyerror, handler_started: bool) void {
        if (handler_started) return; // The request-local observation already finished.
        var observation: telemetry.Http = .{ .span = self.diagnostics.begin(.server, null) };
        observation.finish("board.http.request", err, err == error.HttpDeadline, false);
    }
};
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
    if (config.principal == 0 or config.principal > client.protocol.max_counter or config.realm == 0 or config.realm > client.protocol.max_counter or config.request_timeout_ms < 100 or config.request_timeout_ms > 5000 or config.upstream_timeout_ms == 0 or config.upstream_timeout_ms >= config.request_timeout_ms or config.read_interval_ms < 100 or config.read_interval_ms > 5000) return error.InvalidConfig;
    if (config.query) |query| {
        if (config.profile != .native_v1 or query.connection.realm != config.realm or query.connection.principal == config.principal or query.connection.principal == 0 or query.workspace.source.resource != query.connection.resource) return error.InvalidQueryConfiguration;
    }
    if (config.application) |app| {
        try app.validate();
        if (config.profile != .native_v1 or app.scope.realm != config.realm) return error.InvalidApplicationConfiguration;
        for (app.operators) |slot| if (slot) |principal| {
            if (principal == config.principal or (config.query != null and principal == config.query.?.connection.principal) or (config.reactive != null and principal == config.reactive.?.principal)) return error.InvalidApplicationOperators;
        };
    }
    if (config.interface) |scope| {
        try scope.validate();
        if (config.profile != .native_v1 or scope.realm != config.realm) return error.InvalidApplicationConfiguration;
    }
    const host = try originHost(config.public_origin, config.development_allow_insecure_http);
    const limits: http_server.Options = .{
        .connections = config.http_connections,
        .requests = config.http_requests,
        .header_timeout_ms = @min(1000, config.request_timeout_ms),
        .request_timeout_ms = if (config.reactive) |reactive| reactive.gateway.options.request_timeout_ms else config.request_timeout_ms,
    };
    try limits.validate();
    var reactive_context: ?hosting.Context = null;
    defer if (reactive_context) |*context| {
        context.deinit();
        std.crypto.secureZero(u8, std.mem.asBytes(&context.key));
    };
    if (config.reactive) |reactive| {
        const gateway = reactive.gateway;
        try gateway.validate();
        const viewer = gateway.viewer orelse return error.InvalidReactiveConfiguration;
        if (config.profile != .native_v1 or !gateway.reactive or viewer.snapshot_values or
            viewer.principal == config.principal or reactive.principal == 0 or
            !std.mem.eql(u8, gateway.host, host) or !std.mem.eql(u8, gateway.public_origin, config.public_origin) or
            gateway.options.requests > config.http_requests or gateway.options.request_timeout_ms > 30000)
            return error.InvalidReactiveConfiguration;
        if (viewer.refresh) {
            const query = config.query orelse return error.InvalidReactiveConfiguration;
            if (query.connection.principal != viewer.principal or query.connection.requester != gateway.ingress or query.connection.requests != gateway.resource)
                return error.InvalidReactiveConfiguration;
        }
        reactive_context = .{ .config = .{ .url = config.upstream, .realm = config.realm, .principal = reactive.principal, .request_timeout_ms = config.upstream_timeout_ms, .gateway = gateway }, .key = try client.readKey(init.gpa, init.io, reactive.seed_file), .diagnostics = diagnostics };
        try reactive_context.?.loadViewer(init.gpa, init.io);
    }
    var shared: Shared = .{ .config = config, .host = host, .diagnostics = diagnostics, .reactive = if (reactive_context) |*context| context else null };
    const address = try std.Io.net.IpAddress.parseIp4(config.listen, config.port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    diagnostics.event(.{ .name = "service.ready" });
    try http_server.serve(init.io, init.gpa, &listener, limits, &shared);
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

test "participation cursors separate process and association coverage" {
    const t = std.testing;
    const process = (try parseParticipation("/api/v1/resources/7/participation?after=3&position=10")).?;
    try t.expectEqual(@as(?u64, 3), process.after);
    const member = (try parseParticipation("/api/v1/resources/7/participation?pid=2&association_after=9&position=10")).?;
    try t.expectEqual(@as(?u64, 2), member.pid);
    try t.expectEqual(@as(?u64, 9), member.association_after);
    try t.expectEqualStrings("/api/v1/resources/{resource}/participation", logRoute("/api/v1/resources/7/participation?pid=2"));
    for ([_][]const u8{ "/api/v1/resources/participation", "/api/v1/resources/0/participation", "/api/v1/resources/7/participation?association_after=1", "/api/v1/resources/7/participation?after=1&pid=2", "/api/v1/resources/7/participation?pid=1&pid=2", "/api/v1/resources/7/participation?pid=2&association_after=0" }) |target| try t.expectError(error.InvalidQuery, parseParticipation(target));
}
