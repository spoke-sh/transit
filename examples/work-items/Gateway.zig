//! Private application composition over shared native query/publication owners.
//! No business row decoder, raw storage, administrative key or source cache.
const std = @import("std");
const W = @import("work_items");
const app = W.app;
const q = W.query;
const client = app.station.client;
const http = @import("transit_http_server");
const assets = @import("assets");
const telemetry = client.observability.telemetry;
const Self = @This();
pub const Configuration = struct {
    url: []const u8,
    port: u16,
    public_origin: []const u8,
    listen: []const u8 = "127.0.0.1",
    development_allow_insecure_http: bool = false,
    inspection: struct { principal: u64, seed_file: []const u8 },
    application: app.Host.Config,
    data: W.Configuration,
    query: struct { connection: q.UnifiedClient.Connection, seed_file: []const u8, limits: q.Values.Limits },
};
config: Configuration,
host: []const u8,
inspection_key: app.protocol.Ed25519.KeyPair,
query_key: app.protocol.Ed25519.KeyPair,
lock: std.Io.Mutex = .init,
diagnostics: *telemetry.Runtime,
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-work-items-gateway", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(16384));
    const config = (try app.protocol.Json.parseFromSlice(Configuration, init.arena.allocator(), bytes)).value;
    try config.application.validate();
    const secure = std.mem.startsWith(u8, config.public_origin, "https://");
    if (!secure and !(config.development_allow_insecure_http and std.mem.startsWith(u8, config.public_origin, "http://"))) return error.InvalidOrigin;
    const host = config.public_origin[if (secure) 8 else 7..];
    if (host.len == 0 or host.len > 200 or std.mem.indexOfAny(u8, host, "/@?#\\\r\n\t ,") != null) return error.InvalidOrigin;
    if (config.data.realm != config.application.scope.realm or config.data.application != config.application.scope.application or config.query.connection.realm != config.data.realm or config.query.connection.resource != config.data.resource or config.inspection.principal == config.query.connection.principal) return error.InvalidApplicationScope;
    if (config.inspection.principal == 0 or config.query.connection.principal == 0) return error.InvalidApplicationScope;
    for (config.application.operators) |operator| if (operator) |principal| {
        if (principal == config.inspection.principal or principal == config.query.connection.principal) return error.InvalidApplicationScope;
    };
    var self: Self = .{ .config = config, .host = host, .inspection_key = try client.readKey(init.gpa, init.io, config.inspection.seed_file), .query_key = try client.readKey(init.gpa, init.io, config.query.seed_file), .diagnostics = &diagnostics };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&self.inspection_key));
    defer std.crypto.secureZero(u8, std.mem.asBytes(&self.query_key));
    var listener = try (try std.Io.net.IpAddress.parseIp4(config.listen, config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    diagnostics.event(.{ .name = "service.ready", .operation = "http" });
    return http.serve(init.io, init.gpa, &listener, .{ .requests = 4, .control_requests = 2, .request_timeout_ms = 5000 }, &self);
}
pub fn connectionError(self: *Self, err: anyerror, started: bool) void {
    if (!started) self.diagnostics.event(.{ .name = "application.http.connection", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
}
pub fn handle(self: *Self, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) anyerror!void {
    var diagnostic: ?app.protocol.Diagnostic = null;
    self.dispatch(io, allocator, request, &diagnostic) catch |err| {
        self.diagnostics.event(.{ .name = "application.http.request", .operation = "dispatch", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
        const status: std.http.Status = switch (err) {
            error.AccessDenied, error.QueryAccessDenied, error.QueryDenied, error.ApplicationOperatorDenied, error.InvalidOrigin, error.UnsafePrincipal => .forbidden,
            error.QuerySourceUnavailable, error.ResourceUnavailable, error.StateResourceExpired => .gone,
            error.RateLimited => .too_many_requests,
            error.QueryIdentityMismatch, error.ApplicationScopeChanged, error.ApplicationPublicationChanged, error.QueryDraftConflict, error.QueryDraftActive, error.QueryDraftClosed, error.QueryDraftExhausted, error.QueryReadConflict, error.Conflict => .conflict,
            error.InvalidRequest, error.InvalidSqlCursor, error.InvalidQuerySearch, error.InvalidQueryDraft, error.QueryDraftNotFound, error.InvalidQueryRequest, error.InvalidQueryIdentity, error.QueryBudgetExceeded, error.InvalidQueryCursor, error.StatementTooLarge, error.InvalidSqlEncoding, error.UnsupportedStatement, error.InvalidSqlSyntax, error.UnknownSource, error.UnknownColumn, error.InvalidApplicationProgram => .bad_request,
            error.NotFound => .not_found,
            else => if (diagnostic) |detail| switch (detail.category) {
                .syntax, .binding, .unsupported, .limit => .bad_request,
                .access => .forbidden,
                .conflict => .conflict,
                else => .service_unavailable,
            } else .service_unavailable,
        };
        return json(allocator, request, status, .{ .err = @errorName(err), .diagnostic = diagnostic });
    };
}
fn respond(request: *std.http.Server.Request, status: std.http.Status, body: []const u8, mime: []const u8) !void {
    try request.respond(body, .{ .status = status, .keep_alive = false, .extra_headers = &.{
        .{ .name = "content-type", .value = mime },                                                                                                                                                  .{ .name = "cache-control", .value = "no-store" },
        .{ .name = "x-content-type-options", .value = "nosniff" },                                                                                                                                   .{ .name = "referrer-policy", .value = "no-referrer" },
        .{ .name = "content-security-policy", .value = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'" },
    } });
}
fn json(allocator: std.mem.Allocator, request: *std.http.Server.Request, status: std.http.Status, value: anytype) !void {
    // Shared native profiles bound result bodies; cap the serializer as well.
    const bytes = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try app.protocol.Json.write(value, &encoder);
    return respond(request, status, writer.buffered(), "application/json");
}
fn published(self: *Self, allocator: std.mem.Allocator, wire: *client.Client, diagnostic: *?app.protocol.Diagnostic) !app.Host.Owned {
    return self.acquirePublished(allocator, wire) catch |err| {
        diagnostic.* = app.HostDiagnostic.acquisition(self.config.application.scope, err, wire.last_rejection) catch null;
        return err;
    };
}
fn acquirePublished(self: *Self, allocator: std.mem.Allocator, wire: *client.Client) !app.Host.Owned {
    const identity = try wire.query(.{ .realm = self.config.data.realm, .principal = self.config.inspection.principal, .kind = .{ .identity = {} } }, self.inspection_key);
    if (identity.body.identity.permissions != app.protocol.permission(.inspect)) return error.UnsafePrincipal;
    return app.Host.published(allocator, .{ .wire = wire, .realm = self.config.data.realm, .principal = self.config.inspection.principal, .key = self.inspection_key }, self.config.application.scope);
}
fn workspace(self: *Self, allocator: std.mem.Allocator, wire: *client.Client, current: bool, diagnostic: *?app.protocol.Diagnostic) !q.Workspace.Config {
    const owner: W = .{ .configuration = self.config.data };
    var definition = try owner.source(1);
    if (current) {
        var interface = try self.published(allocator, wire, diagnostic);
        defer interface.deinit();
        const declared = interface.value.published.compiled.definition;
        var binding: ?app.Model.Query = null;
        for (declared.bindings) |candidate| if (candidate.source == .query) {
            if (binding != null) return error.InvalidApplicationProgram;
            binding = candidate.source.query;
        };
        const selected = binding orelse return error.InvalidApplicationProgram;
        const resources: client.ResourceReader = .{ .wire = wire, .realm = self.config.data.realm, .principal = self.config.query.connection.principal, .key = self.query_key };
        var reader = try resources.open(self.config.data.resource);
        const head = try (try owner.ledger()).head(&reader);
        definition = try owner.source(try owner.selected(&reader));
        const contract = try definition.fingerprint();
        if (selected.resource != definition.resource or selected.source_kind != .table or selected.profile != .unified_v1 or !std.mem.eql(u8, selected.name, "items") or !std.mem.eql(u8, &selected.schema, &contract) or !std.mem.eql(u8, &head.contract, &contract)) return error.QueryIdentityMismatch;
    }
    return .{ .name = "items", .source = try q.Values.Source.fromNative(allocator, definition), .limits = self.config.query.limits };
}
fn dispatch(self: *Self, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request, diagnostic: *?app.protocol.Diagnostic) !void {
    try http.validateHead(request);
    if (!std.mem.eql(u8, (try http.header(request, "host")).?, self.host)) return error.InvalidOrigin;
    if (try http.header(request, "origin")) |origin| if (!std.mem.eql(u8, origin, self.config.public_origin)) return error.InvalidOrigin;
    for ([_][]const u8{ "forwarded", "x-forwarded-host", "x-forwarded-proto", "x-forwarded-for" }) |name| if (try http.header(request, name) != null) return error.InvalidOrigin;
    const target = request.head.target;
    if (request.head.method == .GET and !std.mem.startsWith(u8, target, "/api/")) {
        if (std.mem.eql(u8, target, "/health")) return json(allocator, request, .ok, .{ .ready = true });
        if (assets.get(target)) |asset| return respond(request, .ok, asset.bytes, asset.mime);
        if (std.mem.startsWith(u8, target, "/assets/")) return error.NotFound;
        return respond(request, .ok, assets.index, "text/html; charset=utf-8");
    }
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var wire = client.Client.init(alloc, io, self.config.url);
    defer wire.deinit();
    wire.timeout_ms = 3500;
    wire.observer = self.diagnostics;
    return self.publicRequest(alloc, &wire, io, request, diagnostic) catch |err| {
        if (err == error.Conflict or err == error.Rejected) {
            if (wire.last_rejection == .StateResourceExpired) return error.StateResourceExpired;
            if (wire.last_rejection == .StaleStateResource or wire.last_rejection == .QueryExpired) return error.QueryReadConflict;
        }
        return err;
    };
}
fn publicRequest(self: *Self, alloc: std.mem.Allocator, wire: *client.Client, io: std.Io, request: *std.http.Server.Request, diagnostic: *?app.protocol.Diagnostic) !void {
    const target = request.head.target;
    if (request.head.method == .GET and std.mem.eql(u8, target, "/api/v1/interface")) {
        var value = try self.published(alloc, wire, diagnostic);
        defer value.deinit();
        return json(alloc, request, .ok, value.value);
    }
    if (request.head.method != .POST or (!std.mem.eql(u8, target, "/api/v1/application") and !std.mem.eql(u8, target, "/api/v1/query"))) return error.NotFound;
    if (!std.mem.eql(u8, (try http.header(request, "origin")) orelse return error.InvalidOrigin, self.config.public_origin)) return error.InvalidOrigin;
    if (!std.mem.eql(u8, (try http.header(request, "content-type")) orelse "", "application/json")) return error.InvalidRequest;
    const application = std.mem.eql(u8, target, "/api/v1/application");
    const body = request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(if (application) app.Host.max_body_bytes else q.Workspace.max_request_bytes)) catch return error.InvalidRequest;
    if (application) {
        const input = app.protocol.Json.parseFromSlice(app.Host.Request, alloc, body) catch |err| {
            diagnostic.* = app.HostDiagnostic.input(err) catch null;
            return error.InvalidRequest;
        };
        var result = try app.Host.runDiagnostic(alloc, wire, self.config.application, input.value, diagnostic);
        defer result.deinit();
        return json(alloc, request, .ok, result.value);
    }
    const input = app.protocol.Json.parseFromSlice(q.Workspace.Request, alloc, body) catch return error.InvalidRequest;
    const signing = switch (input.value) {
        .next, .next_draft, .draft_open, .draft_close, .prepare_control, .submit => true,
        else => false,
    };
    // Reads carry independent current-authority cuts. A slow result read must
    // not occupy the signing lane or exclude recovery controls.
    if (signing and !self.lock.tryLock()) return error.RateLimited;
    defer if (signing) self.lock.unlock(io);
    const current = switch (input.value) {
        .describe, .compile, .suggest, .assist, .next, .next_draft, .draft_open, .page => true,
        else => false,
    };
    const config = self.workspace(alloc, wire, current, diagnostic) catch |err| {
        if (diagnostic.* == null) diagnostic.* = q.Workspace.diagnostic(input.value, err, .{}, false, null) catch null;
        return err;
    };
    var caller: q.UnifiedClient = .{ .wire = wire, .connection = self.config.query.connection, .key = self.query_key };
    const result = try q.Workspace.applyStructured(alloc, &caller, config, input.value, diagnostic);
    return json(alloc, request, .ok, result);
}
