//! Co-hosted declarative browser listener. All durable declarations and browser
//! records use signed public catalog operations; no application schema is known.
const std = @import("std");
pub const catalog = @import("transit_catalog");
const c = catalog;
const b = c.BrowserDeclarations;
const wire = c.client;
const p = c.protocol;
const http = @import("transit_http_server");
const ingress = c.DeclarativeIngress;
const providers = @import("BrowserProviders.zig");
const Request = @import("BrowserRequest.zig");
pub const subprotocol = c.BrowserContract.subprotocol;
pub const Config = struct {
    listen: []const u8 = "127.0.0.1",
    port: u16,
    public_origin: []const u8,
    development_loopback: bool = false,
    /// IPv4 CIDR of the TLS terminator's private listener peers. It grants only
    /// forwarding trust; host/origin/callback checks still apply per request.
    trusted_proxy_cidr: ?[]const u8 = null,
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    catalog_seed_file: []const u8,
    cookie_seed_file: []const u8,
    secret_directory: []const u8,
    provider_ca_file: ?[]const u8 = null,
    session_ttl_ms: u32 = 3_600_000,
    challenge_ttl_ms: u32 = 300_000,
    options: http.Options = .{ .connections = 16, .requests = 4, .control_requests = 2, .wait_requests = 4, .request_timeout_ms = 60_000 },
    pub fn validate(self: Config) !void {
        try self.connection.validate();
        try self.options.validate();
        _ = try self.boundary();
        if (self.namespace == 0 or self.port == 0 or self.session_ttl_ms < 1000 or self.session_ttl_ms > 86_400_000 or self.challenge_ttl_ms < 1000 or self.challenge_ttl_ms > 600_000 or self.options.request_timeout_ms < 10_000) return error.InvalidBrowserConfiguration;
        if (self.development_loopback) {
            if (!std.mem.eql(u8, self.listen, "127.0.0.1") or self.trusted_proxy_cidr != null) return error.InvalidBrowserProxyTrust;
        } else _ = try Cidr.parse(self.trusted_proxy_cidr orelse return error.MissingBrowserProxyTrust);
    }
    pub fn boundary(self: Config) !ingress.InboundBoundaryPolicy {
        return ingress.InboundBoundaryPolicy.init(self.public_origin, self.development_loopback, self.trusted_proxy_cidr != null);
    }
};
pub const Cidr = struct {
    address: u32,
    mask: u32,
    pub fn parse(text: []const u8) !Cidr {
        const slash = std.mem.indexOfScalar(u8, text, '/') orelse return error.InvalidBrowserProxyTrust;
        const ip = try std.Io.net.Ip4Address.parse(text[0..slash], 0);
        const prefix = try std.fmt.parseInt(u6, text[slash + 1 ..], 10);
        if (prefix < 8 or prefix > 32) return error.InvalidBrowserProxyTrust;
        const mask: u32 = @as(u32, std.math.maxInt(u32)) << @as(u5, @intCast(32 - prefix));
        const address = std.mem.readInt(u32, &ip.bytes, .big);
        if (address & mask != address) return error.InvalidBrowserProxyTrust;
        return .{ .address = address, .mask = mask };
    }
    pub fn contains(self: Cidr, ip: std.Io.net.IpAddress) bool {
        return ip == .ip4 and std.mem.readInt(u32, &ip.ip4.bytes, .big) & self.mask == self.address;
    }
};
pub const Host = struct {
    config: Config,
    endpoint: wire.LocalEndpoint,
    key: p.Ed25519.KeyPair,
    cookie_key: [32]u8,
    allocator: std.mem.Allocator,
    jwks: providers.JwksCache = .{},
    pub fn admitPeer(self: *Host, peer: std.Io.net.IpAddress) !void {
        if (self.config.trusted_proxy_cidr) |cidr| {
            if (!(try Cidr.parse(cidr)).contains(peer)) return error.UntrustedBrowserProxy;
        }
    }
    pub fn connectionError(_: *Host, _: anyerror, _: bool) void {} // no URLs/codes/tokens in telemetry
    pub fn isWait(_: *Host, request: *std.http.Server.Request) bool {
        return std.mem.endsWith(u8, request.head.target, "/watch");
    }
    pub fn isControl(_: *Host, request: *std.http.Server.Request) bool {
        return std.mem.eql(u8, request.head.target, "/health") or std.mem.eql(u8, request.head.target, "/auth/logout") or std.mem.eql(u8, request.head.target, "/auth/session");
    }
    pub fn handle(self: *Host, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
        // Deployment probes use the target's private Host, without browser
        // credentials or forwarding headers. admitPeer has already enforced
        // the configured private boundary. No catalog data is disclosed here.
        if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health"))
            return http.respond(request, .ok, "{\"ready\":true}");
        // A finite reservation bounds parsing, provider bodies, declarations and
        // response preparation. Watch iterations reset their own scratch arena.
        const memory = try allocator.alloc(u8, 16 * 1024 * 1024);
        defer {
            std.crypto.secureZero(u8, memory);
            allocator.free(memory);
        }
        var fixed: std.heap.FixedBufferAllocator = .init(memory);
        var transport = wire.Client.init(fixed.allocator(), io, "http://127.0.0.1:1");
        defer transport.deinit();
        transport.local = self.endpoint;
        transport.timeout_ms = 5000;
        var work: Request = .{ .host = self, .io = io, .allocator = fixed.allocator(), .wire = &transport, .request = request };
        work.run() catch |err| {
            if (work.response_started) return err;
            const status: std.http.Status = switch (err) {
                error.BrowserNotFound => .not_found,
                error.CallbackAlreadyClaimed, error.BrowserRevisionConflict => .conflict,
                error.ProviderExchangeRejected, error.ProviderTokenExchangeRejected => .bad_gateway,
                error.OutOfMemory, error.ResourceWorkBoundExceeded, error.AuthorityUnavailable, error.AuthorityTimeout => .service_unavailable,
                else => .forbidden,
            };
            // Only typed error names are disclosed; provider response text and
            // transport URLs never enter error JSON or diagnostic logs.
            var error_buffer: [256]u8 = undefined;
            const bytes = try std.fmt.bufPrint(&error_buffer, "{{\"err\":\"{s}\"}}", .{@errorName(err)});
            try http.respond(request, status, bytes);
        };
    }
};
pub const Running = struct {
    init: std.process.Init,
    host: Host,
    listener: std.Io.net.Server,
    pub fn open(init: std.process.Init, config: Config, endpoint: wire.LocalEndpoint) !Running {
        try config.validate();
        const key = try wire.readKey(init.gpa, init.io, config.catalog_seed_file);
        var cookie_key = try wire.readKey(init.gpa, init.io, config.cookie_seed_file);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&cookie_key));
        var client = wire.Client.init(init.gpa, init.io, "http://127.0.0.1:1");
        defer client.deinit();
        client.local = endpoint;
        const store: b.Store = .{ .client = .{ .allocator = init.gpa, .authority = &client, .service = &client, .connection = config.connection, .key = key }, .namespace = config.namespace };
        for (std.enums.values(b.Store.Kind)) |kind| {
            var after: ?u64 = null;
            while (true) {
                after = try store.reconcilePage(kind, after);
                if (after == null) break;
            }
        }
        const listener = try (try std.Io.net.IpAddress.parseIp4(config.listen, config.port)).listen(init.io, .{ .reuse_address = true });
        return .{ .init = init, .host = .{ .config = config, .endpoint = endpoint, .key = key, .cookie_key = cookie_key.secret_key.seed(), .allocator = init.gpa }, .listener = listener };
    }
    pub fn deinit(self: *Running) void {
        self.listener.deinit(self.init.io);
        self.host.jwks.deinit(self.init.gpa);
        std.crypto.secureZero(u8, std.mem.asBytes(&self.host.key));
        std.crypto.secureZero(u8, &self.host.cookie_key);
    }
    pub fn run(self: *Running) !void {
        try http.serve(self.init.io, self.init.gpa, &self.listener, self.host.config.options, &self.host);
    }
};

test "browser proxy forwarding trust is scoped to an explicit peer subnet" {
    const cidr = try Cidr.parse("10.4.8.0/24");
    try std.testing.expect(cidr.contains(try std.Io.net.IpAddress.parseIp4("10.4.8.17", 1000)));
    try std.testing.expect(!cidr.contains(try std.Io.net.IpAddress.parseIp4("10.4.9.17", 1000)));
    try std.testing.expectError(error.InvalidBrowserProxyTrust, Cidr.parse("0.0.0.0/0"));
}
