//! Explicit catalog transport and local-intent ownership. The embedding caller
//! supplies allocator and I/O; no runner, thread pool or recovery loop is started.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const wire = c.client;
const Self = @This();

allocator: std.mem.Allocator,
authority: wire.Client,
service: wire.Client,
session: c.DirectTableBridge.Session,
connection: c.DirectTableProtocol.Connection,
key: p.Ed25519.KeyPair,
authority_url: []u8,
service_url: []u8,
busy: std.atomic.Value(bool) = .init(false),

pub const Config = struct {
    url: []const u8,
    service_url: ?[]const u8 = null,
    connection: c.DirectTableProtocol.Connection,
    timeout_ms: u32 = 5000,
};

/// Each call retains its own attempt evidence, including after a successful
/// mutation whose response cannot subsequently be copied by a binding.
pub const Outcome = struct {
    value: union(enum) { result: c.DirectTableBridge.Result, failure: Failure },
    attempt: c.DirectTableClient.Attempt,

    pub fn mutationAttempted(self: Outcome) bool {
        return self.attempt.mutation != null;
    }
};
pub const Failure = struct {
    cause: anyerror,
    protocol_error: ?p.ErrorCode,
    diagnostic: ?p.Diagnostic,
};
pub const LogOutcome = struct {
    value: union(enum) { result: c.DirectLogClient.Result, failure: Failure },
    attempt: c.DirectTableClient.Attempt,
    pub fn mutationAttempted(self: LogOutcome) bool {
        return self.attempt.mutation != null;
    }
};

pub fn validEndpoint(url: []const u8) bool {
    if (url.len == 0 or url.len > 2048) return false;
    const uri = std.Uri.parse(url) catch return false;
    return (std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) and uri.host != null and uri.user == null and uri.password == null and uri.query == null and uri.fragment == null;
}

/// Pure local construction; endpoint/key inputs are copied and no capability
/// read or credential discovery occurs. The supplied I/O must outlive this owner.
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config, seed: [32]u8) !Self {
    const target = config.service_url orelse config.url;
    if (!validEndpoint(config.url) or !validEndpoint(target) or config.timeout_ms == 0 or config.timeout_ms > 60000)
        return error.InvalidArgument;
    try config.connection.validate();
    const authority_url = try allocator.dupe(u8, config.url);
    errdefer allocator.free(authority_url);
    const service_url = try allocator.dupe(u8, target);
    errdefer allocator.free(service_url);
    var authority = wire.Client.init(allocator, io, authority_url);
    authority.timeout_ms = config.timeout_ms;
    var service = wire.Client.init(allocator, io, service_url);
    service.timeout_ms = config.timeout_ms;
    return .{
        .allocator = allocator,
        .authority = authority,
        .service = service,
        .session = .{ .allocator = allocator },
        .connection = config.connection,
        .key = try p.Ed25519.KeyPair.generateDeterministic(seed),
        .authority_url = authority_url,
        .service_url = service_url,
    };
}

/// The embedding owner must join calls before destruction. This frees local
/// work/transports only; it neither cancels accepted work nor releases saved pins.
pub fn deinit(self: *Self) void {
    self.session.deinit();
    std.crypto.secureZero(u8, std.mem.asBytes(&self.key));
    self.authority.deinit();
    self.service.deinit();
    self.allocator.free(self.authority_url);
    self.allocator.free(self.service_url);
    self.* = undefined;
}

pub fn observe(self: *Self, observer: *wire.observability.telemetry.Runtime) void {
    self.authority.observer = observer;
    self.service.observer = observer;
}

/// Result values belong to output and survive the next call and client close.
/// Output must be distinct from retained session allocation and cannot be reset
/// until all its result borrows end. One caller owns the handle; overlap refuses.
pub fn call(self: *Self, output: *std.heap.ArenaAllocator, action: c.DirectTableBridge.Action) error{Busy}!Outcome {
    if (self.busy.swap(true, .acquire)) return error.Busy;
    defer self.busy.store(false, .release);
    self.authority.last_rejection = null;
    self.service.last_rejection = null;
    var attempt: c.DirectTableClient.Attempt = .{};
    const caller: c.DirectTableClient = .{
        .allocator = self.allocator,
        .authority = &self.authority,
        .service = &self.service,
        .connection = self.connection,
        .key = self.key,
        .attempt = &attempt,
    };
    var location: c.fuze.Sql.Location = .{};
    const result = self.session.apply(output, caller, action, &location) catch |err| {
        const native = self.service.last_rejection orelse self.authority.last_rejection;
        return .{ .attempt = attempt, .value = .{ .failure = .{
            .cause = err,
            .protocol_error = native,
            .diagnostic = c.DirectTableDiagnostic.failure(action, err, location, attempt, native) catch null,
        } } };
    };
    return .{ .attempt = attempt, .value = .{ .result = result } };
}

/// Stream/Queue lifecycle calls share this handle's signing, concurrency and
/// attempt accounting. Saved requests are explicit DirectLogClient values.
pub fn callLog(self: *Self, output: *std.heap.ArenaAllocator, action: c.DirectLogClient.Action) error{Busy}!LogOutcome {
    if (self.busy.swap(true, .acquire)) return error.Busy;
    defer self.busy.store(false, .release);
    self.authority.last_rejection = null;
    self.service.last_rejection = null;
    var attempt: c.DirectTableClient.Attempt = .{};
    const caller: c.DirectTableClient = .{ .allocator = self.allocator, .authority = &self.authority, .service = &self.service, .connection = self.connection, .key = self.key, .attempt = &attempt };
    const result = c.DirectLogClient.apply(output, caller, action) catch |err| {
        const native = self.service.last_rejection orelse self.authority.last_rejection;
        return .{ .attempt = attempt, .value = .{ .failure = .{ .cause = err, .protocol_error = native, .diagnostic = attempt.failure(err, native) catch null } } };
    };
    return .{ .attempt = attempt, .value = .{ .result = result } };
}
