//! Standalone caller handle: no PID ownership, activation or handler capability.
const std = @import("std");
const base = @import("Abi.zig");
pub const bridge = @import("QueryBridge.zig");
const q = bridge.q;
const allocator = std.heap.page_allocator;
pub const Client = opaque {};
pub const Config = struct {
    connection: ?q.UnifiedClient.Connection = null,
    timeout_ms: u32 = 5000,
    relational: ?q.RelationalBridge.Config = null,
    tables: ?struct { url: []const u8, connection: q.Values.DirectConnection } = null,
};
const Impl = struct {
    threaded: std.Io.Threaded,
    wire: q.wire.Client,
    client: ?q.UnifiedClient = null,
    key: q.protocol.Ed25519.KeyPair,
    url: []u8,
    table_url: ?[]u8 = null,
    table_wire: ?q.wire.Client = null,
    relational: ?*q.RelationalCaller = null,
    busy: std.atomic.Value(bool) = .init(false),
};
fn cast(pointer: *Client) *Impl {
    return @ptrCast(@alignCast(pointer));
}
fn validEndpoint(url: []const u8) bool {
    if (url.len == 0 or url.len > 2048) return false;
    const uri = std.Uri.parse(url) catch return false;
    return (std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) and uri.host != null and uri.user == null and uri.password == null and uri.query == null and uri.fragment == null;
}
pub fn create(version: u32, url: [*]const u8, url_len: usize, seed: *const [32]u8, config: [*]const u8, config_len: usize, out: *?*Client) callconv(.c) base.Status {
    out.* = null;
    if (version != 1) return .incompatible_version;
    if (url_len == 0 or url_len > 2048 or config_len == 0 or config_len > 8192) return .invalid_argument;
    if (!validEndpoint(url[0..url_len])) return .invalid_argument;
    const parsed = q.Values.parse(Config, allocator, config[0..config_len]) catch |err| return base.status(err);
    defer parsed.deinit();
    const c = parsed.value;
    if (c.connection) |connection| {
        inline for (.{ "realm", "principal", "source", "resource", "requester", "requests" }) |field| q.UnifiedRecords.identity(@field(connection, field)) catch return .invalid_argument;
    } else if (c.relational == null) return .invalid_argument;
    if (c.tables) |tables| {
        const connection = c.connection orelse return .invalid_argument;
        const direct = tables.connection.native() catch return .invalid_argument;
        if (!validEndpoint(tables.url) or direct.scope.realm != connection.realm or direct.principal != connection.principal or direct.role != connection.role) return .invalid_argument;
    }
    if (c.timeout_ms == 0 or c.timeout_ms > 60000) return .invalid_argument;
    const client = allocator.create(Impl) catch return .out_of_memory;
    const endpoint = allocator.dupe(u8, url[0..url_len]) catch {
        allocator.destroy(client);
        return .out_of_memory;
    };
    client.* = .{ .url = endpoint, .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }), .wire = undefined, .key = q.protocol.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable };
    client.wire = q.wire.Client.init(allocator, client.threaded.io(), endpoint);
    client.wire.timeout_ms = c.timeout_ms;
    if (c.connection) |connection| client.client = .{ .wire = &client.wire, .connection = connection, .key = client.key };
    if (c.tables) |tables| initializeTables(client, tables.url, tables.connection, c.timeout_ms) catch |err| {
        destroy(@ptrCast(client));
        return base.status(err);
    };
    if (c.relational) |config_relational| initializeRelational(client, config_relational) catch |err| {
        destroy(@ptrCast(client));
        return base.status(err);
    };
    out.* = @ptrCast(client);
    return .ok;
}
fn initializeTables(client: *Impl, url: []const u8, connection: q.Values.DirectConnection, timeout_ms: u32) !void {
    const direct = try connection.native();
    client.table_url = try allocator.dupe(u8, url);
    client.table_wire = q.wire.Client.init(allocator, client.threaded.io(), client.table_url.?);
    client.table_wire.?.timeout_ms = timeout_ms;
    client.client.?.tables = .{ .allocator = allocator, .authority = &client.wire, .service = &client.table_wire.?, .connection = direct, .key = client.key };
}
fn initializeRelational(client: *Impl, config: q.RelationalBridge.Config) !void {
    for (config.catalogs) |connection| {
        const native = try connection.native();
        if (client.client) |unified| if (native.scope.realm != unified.connection.realm or native.principal != unified.connection.principal) return error.RelationalCallerChanged;
    }
    client.relational = try q.RelationalCaller.create(allocator, client.threaded.io(), &client.wire, client.key, config);
}
pub fn destroy(pointer: ?*Client) callconv(.c) void {
    const client = cast(pointer orelse return);
    if (client.relational) |relational| relational.destroy();
    if (client.client) |*unified| {
        if (unified.tables) |*tables| std.crypto.secureZero(u8, std.mem.asBytes(&tables.key));
        std.crypto.secureZero(u8, std.mem.asBytes(&unified.key));
    }
    std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    client.wire.deinit();
    if (client.table_wire) |*wire| wire.deinit();
    client.threaded.deinit();
    allocator.free(client.url);
    if (client.table_url) |url| allocator.free(url);
    allocator.destroy(client);
}
pub fn observe(pointer: *Client, observer: *q.wire.observability.telemetry.Runtime) void {
    const client = cast(pointer);
    client.wire.observer = observer;
    if (client.table_wire) |*wire| wire.observer = observer;
}
pub fn call(pointer: *Client, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > q.protocol.max_body) return invalidEnvelope(error.InvalidQueryRequest, out);
    const client = cast(pointer);
    if (client.busy.swap(true, .acquire)) return .busy;
    defer client.busy.store(false, .release);
    client.wire.last_rejection = null;
    if (client.table_wire) |*wire| wire.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = q.Values.parse(bridge.Action, alloc, json[0..len]) catch |err| return invalidEnvelope(err, out);
    // Local envelope validation happens before the dispatch boundary. Any
    // later unconfirmed transport/result failure retains the exact token.
    var identity: ?q.protocol.Diagnostic.Identity = null;
    if (action.value == .submit) {
        const signed = bridge.prepared(alloc, action.value.submit) catch |err| return localFailure(action.value, err, out);
        const unified = if (client.client) |*value| value else return localFailure(action.value, error.QueryInterfaceUnavailable, out);
        unified.validate(signed) catch |err| return localFailure(action.value, err, out);
        identity = .{ .domain = .transport, .id = .init(signed.signed.request.sequence), .sequence = .init(signed.signed.request.sequence), .realm = .init(signed.signed.request.realm) };
    }
    var detail: q.fuze.Sql.Binding = .{};
    const result = apply(client, alloc, action.value, &detail) catch |err| {
        const original_rejection = if (client.table_wire) |wire| wire.last_rejection orelse client.wire.last_rejection else client.wire.last_rejection;
        var diagnostic = q.ApiDiagnostic.project(action.value, err, detail, action.value == .submit, identity) catch null;
        if (action.value == .relational) if (client.relational) |relational| if (diagnostic) |*value| relational.session.diagnostic(action.value.relational, err, value);
        if (action.value != .relational) if (client.client) |unified| q.ApiDiagnostic.qualify(&diagnostic, unified.connection);
        if (diagnostic) |*value| if (original_rejection) |native| {
            value.text(.native_cause, .authority, @tagName(native)) catch {};
        };
        base.output(.{ .err = @errorName(err), .protocol_error = original_rejection, .diagnostic = diagnostic }, out) catch {};
        if (action.value == .submit and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
        if (err == error.QueryReadConflict) return .conflict;
        if (err == error.QueryDenied) return .denied;
        if (err == error.OutOfMemory) return .out_of_memory;
        switch (q.ApiDiagnostic.category(action.value, err)) {
            .access => return .denied,
            .conflict => return .conflict,
            .limit => return .budget_exceeded,
            .unavailable => return .unavailable,
            .integrity, .internal => return .invalid_response,
            else => {},
        }
        return base.status(err);
    };
    base.output(result, out) catch |err| return if (action.value == .submit) .uncertain else base.status(err);
    return .ok;
}
fn apply(client: *Impl, alloc: std.mem.Allocator, action: bridge.Action, detail: *q.fuze.Sql.Binding) !bridge.Result {
    if (action == .relational) {
        if (action.relational == .capabilities) return .{ .relational = .{ .capabilities = .{} } };
        const relational = client.relational orelse return error.QueryInterfaceUnavailable;
        var location: q.fuze.Sql.Location = .{};
        defer detail.location = location;
        return .{ .relational = try relational.session.apply(alloc, action.relational, &location) };
    }
    const unified = if (client.client) |*value| value else return error.QueryInterfaceUnavailable;
    return bridge.applyDiagnostic(alloc, unified, action, detail);
}
fn invalidEnvelope(err: anyerror, out: *?*base.Buffer) base.Status {
    const diagnostic = if (err == error.OutOfMemory)
        q.protocol.Diagnostic.init("query.memory_unavailable", .unavailable, .input, .not_submitted, .local_before_dispatch, "The caller could not allocate memory to read this request. No command was sent.") catch unreachable
    else
        q.protocol.Diagnostic.init("query.invalid_envelope", .syntax, .input, .not_submitted, .local_before_dispatch, "The query action is not a valid bounded request object. No command was sent.") catch unreachable;
    base.output(.{ .err = @errorName(err), .diagnostic = diagnostic }, out) catch {};
    return base.status(err);
}
fn localFailure(action: bridge.Action, err: anyerror, out: *?*base.Buffer) base.Status {
    const diagnostic = q.ApiDiagnostic.project(action, err, .{}, false, null) catch null;
    base.output(.{ .err = @errorName(err), .diagnostic = diagnostic }, out) catch {};
    return base.status(err);
}
test "query caller handle needs no activation and preserves uncertainty after explicit dispatch" {
    const t = std.testing;
    const endpoint = "http://127.0.0.1:1";
    const config = "{\"connection\":{\"realm\":7,\"principal\":8,\"source\":9,\"resource\":10,\"requester\":11,\"requests\":12},\"timeout_ms\":100}";
    const seed: [32]u8 = @splat(0);
    var pointer: ?*Client = null;
    try t.expectEqual(.incompatible_version, create(2, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    try t.expect(pointer == null);
    try t.expectEqual(.ok, create(1, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    defer destroy(pointer);
    // A hostile submit-shaped envelope is rejected before transport, with no
    // uncertain-send classification. The same handle remains usable afterward.
    var nested: [512]u8 = undefined;
    var encoded: std.Io.Writer = .fixed(&nested);
    try encoded.writeAll("{\"submit\":");
    for (0..q.Values.json_limits.depth) |_| try encoded.writeByte('[');
    for (0..q.Values.json_limits.depth) |_| try encoded.writeByte(']');
    try encoded.writeByte('}');
    var rejected: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, nested[0..].ptr, encoded.buffered().len, &rejected));
    defer base.Api.station_buffer_destroy(rejected);
    const envelope = try std.json.parseFromSlice(struct { err: []const u8, diagnostic: q.protocol.Diagnostic }, t.allocator, base.Api.station_buffer_data(rejected.?)[0..base.Api.station_buffer_size(rejected.?)], .{});
    defer envelope.deinit();
    try t.expectEqualStrings("JsonDepthExceeded", envelope.value.err);
    try t.expectEqual(.not_submitted, envelope.value.diagnostic.outcome);
    try t.expectEqual(.local_before_dispatch, envelope.value.diagnostic.evidence);
    const caps = "{\"capabilities\":{}}";
    var buffer: ?*base.Buffer = null;
    try t.expectEqual(.ok, call(pointer.?, caps.ptr, caps.len, &buffer));
    defer base.Api.station_buffer_destroy(buffer);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const result = try std.json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
    try t.expect(result.value.capabilities.kv and result.value.capabilities.table and result.value.capabilities.document);
    var invalid: ?*base.Buffer = null;
    const broken = "{\"submit\":\"{}\"}";
    try t.expectEqual(.invalid_argument, call(pointer.?, broken.ptr, broken.len, &invalid));
    defer base.Api.station_buffer_destroy(invalid);
    const signed: q.UnifiedClient.Prepared = .{ .signed = try q.protocol.Growth.sign(.{ .realm = 7, .principal = 8, .sequence = 1, .command = .{ .send = .{ .pid = 11, .value = try (q.station.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, try q.protocol.Ed25519.KeyPair.generateDeterministic(seed)) };
    const token = try std.json.Stringify.valueAlloc(alloc, signed, .{});
    const request = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = token }, .{});
    var failure: ?*base.Buffer = null;
    try t.expectEqual(.uncertain, call(pointer.?, request.ptr, request.len, &failure));
    defer base.Api.station_buffer_destroy(failure);
    try t.expectEqualDeep(signed, try bridge.prepared(alloc, token));
    const detail = try std.json.parseFromSlice(struct { err: []const u8, protocol_error: ?[]const u8, diagnostic: q.protocol.Diagnostic }, alloc, base.Api.station_buffer_data(failure.?)[0..base.Api.station_buffer_size(failure.?)], .{});
    try detail.value.diagnostic.validate();
    try t.expectEqual(.unknown, detail.value.diagnostic.outcome);
    try t.expectEqual(.resume_exact, detail.value.diagnostic.actions[1].?.kind);
    try t.expectEqual(@as(u64, 1), try detail.value.diagnostic.identity.?.sequence.?.value());
    // A rejected local envelope cannot be confused with a dispatched timeout.
    var foreign = signed;
    foreign.signed.request.realm = 99;
    const wrong = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = try std.json.Stringify.valueAlloc(alloc, foreign, .{}) }, .{});
    var rejection: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, wrong.ptr, wrong.len, &rejection));
    defer base.Api.station_buffer_destroy(rejection);
    const local = try std.json.parseFromSlice(struct { err: []const u8, diagnostic: q.protocol.Diagnostic }, alloc, base.Api.station_buffer_data(rejection.?)[0..base.Api.station_buffer_size(rejection.?)], .{});
    try t.expectEqual(.not_submitted, local.value.diagnostic.outcome);
    try t.expect(local.value.diagnostic.identity == null);

    const read = "{\"status\":\"19\"}";
    var unavailable: ?*base.Buffer = null;
    try t.expectEqual(.unavailable, call(pointer.?, read.ptr, read.len, &unavailable));
    defer base.Api.station_buffer_destroy(unavailable);
    const failed_read = try std.json.parseFromSlice(struct { err: []const u8, protocol_error: ?[]const u8, diagnostic: q.protocol.Diagnostic }, alloc, base.Api.station_buffer_data(unavailable.?)[0..base.Api.station_buffer_size(unavailable.?)], .{});
    const read_detail = failed_read.value.diagnostic;
    try t.expectEqualStrings("query.transport_unavailable", read_detail.code.slice());
    try t.expectEqual(.not_applicable, read_detail.outcome);
    try t.expectEqual(@as(u64, 19), try read_detail.identity.?.id.value());
    try t.expectEqual(@as(u64, 7), try read_detail.identity.?.realm.?.value());
    try t.expectEqual(@as(u64, 12), try read_detail.identity.?.resource.?.value());
    try t.expectEqualDeep(read_detail.identity, read_detail.actions[0].?.target);
}

test "failure to parse for lack of memory is not a syntax error" {
    const t = std.testing;
    var buffer: ?*base.Buffer = null;
    try t.expectEqual(.out_of_memory, invalidEnvelope(error.OutOfMemory, &buffer));
    defer base.Api.station_buffer_destroy(buffer);
    const parsed = try std.json.parseFromSlice(struct { err: []const u8, diagnostic: q.protocol.Diagnostic }, t.allocator, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
    defer parsed.deinit();
    try t.expectEqual(.unavailable, parsed.value.diagnostic.category);
    try t.expectEqual(.not_submitted, parsed.value.diagnostic.outcome);
}

test "query Table routing owns its endpoint and preserves a separate service audience" {
    const t = std.testing;
    const endpoint = "http://127.0.0.1:1";
    const seed: [32]u8 = @splat(0);
    const config: Config = .{
        .connection = .{ .realm = 7, .principal = 8, .source = 9, .resource = 10, .requester = 11, .requests = 12, .role = 3 },
        .tables = .{ .url = "http://127.0.0.1:2", .connection = .{ .scope = .{ .realm = 7, .resource = 20, .catalog = "18446744073709551615" }, .branch = "1", .audience = 21, .principal = 8, .role = 3 } },
    };
    const encoded = try q.protocol.Json.valueAlloc(t.allocator, config);
    defer t.allocator.free(encoded);
    var pointer: ?*Client = null;
    try t.expectEqual(.ok, create(1, endpoint.ptr, endpoint.len, &seed, encoded.ptr, encoded.len, &pointer));
    defer destroy(pointer);
    const tables = cast(pointer.?).client.?.tables.?;
    try t.expectEqual(@as(u64, 21), tables.connection.audience);
    try t.expectEqual(std.math.maxInt(u64), tables.connection.scope.catalog);
    try t.expect(tables.authority == &cast(pointer.?).wire);
    try t.expect(tables.service == &cast(pointer.?).table_wire.?);
    for (0..5) |case| {
        var foreign = config;
        switch (case) {
            0 => foreign.tables.?.connection.scope.realm += 1,
            1 => foreign.tables.?.connection.principal += 1,
            2 => foreign.tables.?.connection.role = null,
            3 => foreign.tables.?.url = "http://user:password@127.0.0.1",
            4 => foreign.connection = null,
            else => unreachable,
        }
        const bytes = try q.protocol.Json.valueAlloc(t.allocator, foreign);
        defer t.allocator.free(bytes);
        var rejected: ?*Client = null;
        try t.expectEqual(.invalid_argument, create(1, endpoint.ptr, endpoint.len, &seed, bytes.ptr, bytes.len, &rejected));
        try t.expect(rejected == null);
    }
}
