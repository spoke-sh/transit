//! Direct catalog caller. A handle owns transports and immutable local work;
//! durable acceptance and recovery belong to the public catalog/data owners.
const std = @import("std");
const base = @import("Abi.zig");
const catalog = @import("transit_catalog");
const p = catalog.protocol;
const wire = catalog.station.client;
pub const bridge = catalog.DirectTableBridge;
pub const max_intent_bytes = catalog.DirectTableIntent.max_bytes;
const allocator = std.heap.page_allocator;
pub const Client = opaque {};
pub const Config = struct {
    definition: p.Growth.Definition,
    connection: catalog.DirectTableValues.Connection,
    timeout_ms: u32 = 5000,
    service_url: ?[]const u8 = null,
};
const Impl = struct {
    threaded: std.Io.Threaded,
    authority: wire.Client,
    service: wire.Client,
    client: catalog.DirectTableClient,
    session: bridge.Session,
    authority_url: []u8,
    service_url: []u8,
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
    if (!validEndpoint(url[0..url_len]) or config_len == 0 or config_len > 8192) return .invalid_argument;
    const parsed = p.Json.parseFromSlice(Config, allocator, config[0..config_len]) catch |err| return base.status(err);
    defer parsed.deinit();
    const options = parsed.value;
    if (options.definition != p.Growth.current_definition) return .incompatible_version;
    const connection = options.connection.native() catch return .invalid_argument;
    if (options.timeout_ms == 0 or options.timeout_ms > 60000) return .invalid_argument;
    const target = options.service_url orelse url[0..url_len];
    if (!validEndpoint(target)) return .invalid_argument;
    const client = allocator.create(Impl) catch return .out_of_memory;
    const authority_url = allocator.dupe(u8, url[0..url_len]) catch {
        allocator.destroy(client);
        return .out_of_memory;
    };
    const service_url = allocator.dupe(u8, target) catch {
        allocator.free(authority_url);
        allocator.destroy(client);
        return .out_of_memory;
    };
    client.* = .{ .authority_url = authority_url, .service_url = service_url, .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }), .authority = undefined, .service = undefined, .client = undefined, .session = .{ .allocator = allocator } };
    client.authority = wire.Client.init(allocator, client.threaded.io(), authority_url);
    client.service = wire.Client.init(allocator, client.threaded.io(), service_url);
    client.authority.timeout_ms = options.timeout_ms;
    client.service.timeout_ms = options.timeout_ms;
    client.client = .{ .allocator = allocator, .authority = &client.authority, .service = &client.service, .connection = connection, .key = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable };
    out.* = @ptrCast(client);
    return .ok;
}
pub fn destroy(pointer: ?*Client) callconv(.c) void {
    const client = cast(pointer orelse return);
    client.session.deinit();
    std.crypto.secureZero(u8, std.mem.asBytes(&client.client.key));
    client.authority.deinit();
    client.service.deinit();
    client.threaded.deinit();
    allocator.free(client.authority_url);
    allocator.free(client.service_url);
    allocator.destroy(client);
}
pub fn observe(pointer: *Client, observer: *wire.observability.telemetry.Runtime) void {
    cast(pointer).authority.observer = observer;
    cast(pointer).service.observer = observer;
}
pub fn call(pointer: *Client, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > bridge.max_input_bytes) return invalidEnvelope(error.InvalidCatalogPrepared, out);
    const client = cast(pointer);
    if (client.busy.swap(true, .acquire)) return .busy;
    defer client.busy.store(false, .release);
    client.authority.last_rejection = null;
    client.service.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const action = bridge.parse(arena.allocator(), json[0..len]) catch |err| return invalidEnvelope(err, out);
    defer action.deinit();
    var attempt: catalog.DirectTableClient.Attempt = .{};
    var caller = client.client;
    caller.attempt = &attempt;
    var location: catalog.fuze.Sql.Location = .{};
    var results: std.heap.ArenaAllocator = .init(allocator);
    defer results.deinit();
    const result = client.session.apply(&results, caller, action.value, &location) catch |err| {
        const native = client.service.last_rejection orelse client.authority.last_rejection;
        const diagnostic = catalog.DirectTableDiagnostic.failure(action.value, err, location, attempt, native) catch null;
        base.output(.{ .err = @errorName(err), .protocol_error = native, .diagnostic = diagnostic }, out) catch {};
        if (attempt.mutation != null) return .uncertain;
        return failureStatus(err, if (diagnostic) |value| value.category else .internal);
    };
    base.output(result, out) catch |err| return if (attempt.mutation != null) .uncertain else base.status(err);
    return .ok;
}
fn failureStatus(cause: anyerror, category: p.Diagnostic.Category) base.Status {
    if (cause == error.OutOfMemory) return .out_of_memory;
    if (cause == error.IncompatibleDefinition) return .incompatible_version;
    return switch (category) {
        .access => .denied,
        .conflict => .conflict,
        .limit => .budget_exceeded,
        .unavailable => .unavailable,
        .lifecycle => .not_ready,
        .integrity, .internal => .invalid_response,
        else => .invalid_argument,
    };
}
pub fn invalidEnvelope(cause: anyerror, out: *?*base.Buffer) base.Status {
    const diagnostic = catalog.DirectTableDiagnostic.invalidEnvelope(cause) catch null;
    base.output(.{ .err = @errorName(cause), .diagnostic = diagnostic }, out) catch {};
    return if (cause == error.OutOfMemory) .out_of_memory else .invalid_argument;
}

test "direct catalog ABI rejects old configuration and owns local saved work" {
    const t = std.testing;
    const endpoint = "http://127.0.0.1:1";
    const seed: [32]u8 = @splat(10);
    var pointer: ?*Client = null;
    const old = "{}";
    try t.expectEqual(.invalid_argument, create(1, endpoint.ptr, endpoint.len, &seed, old.ptr, old.len, &pointer));
    try t.expect(pointer == null);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: catalog.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) }, .branch = 1, .audience = 3, .principal = 17, .role = null };
    const legacy = try p.Json.valueAlloc(alloc, .{ .definition = p.Growth.current_definition, .connection = .{ .scope = try catalog.DirectTableValues.Scope.foreign(alloc, connection.scope), .owner = 3, .principal = 17, .namespace = 1, .role = @as(?u64, null) } });
    try t.expectEqual(.invalid_argument, create(1, endpoint.ptr, endpoint.len, &seed, legacy.ptr, legacy.len, &pointer));
    try t.expect(pointer == null);
    const foreign = try p.Json.valueAlloc(alloc, .{ .definition = "0000000000000000000000000000000000000000000000000000000000000000", .connection = try catalog.DirectTableValues.Connection.foreign(alloc, connection) });
    try t.expectEqual(.invalid_argument, create(1, endpoint.ptr, endpoint.len, &seed, foreign.ptr, foreign.len, &pointer));
    try t.expect(pointer == null);
    const config = try p.Json.valueAlloc(alloc, Config{ .definition = p.Growth.current_definition, .connection = try catalog.DirectTableValues.Connection.foreign(alloc, connection), .timeout_ms = 100 });
    try t.expectEqual(.incompatible_version, create(2, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    try t.expect(pointer == null);
    try t.expectEqual(.ok, create(1, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    defer destroy(pointer);
    const binding: catalog.NameAssertion.Binding = .{ .definition = p.Growth.current_definition, .connection = connection, .operation = std.math.maxInt(u64), .namespace = 1, .name = try .init("absent"), .action = .drop_if_exists, .expected = null, .intent = @splat(9) };
    const recovery: bridge.Recovery = .{ .name_assertion = try catalog.DirectTableValues.NameAssertion.foreign(alloc, binding) };
    const load = try p.Json.valueAlloc(alloc, bridge.Action{ .load = .{ .name_assertion = recovery.name_assertion } });
    var loaded: ?*base.Buffer = null;
    try t.expectEqual(.ok, call(pointer.?, load.ptr, load.len, &loaded));
    defer base.Api.station_buffer_destroy(loaded);
    const decoded = try p.Json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(loaded.?)[0..base.Api.station_buffer_size(loaded.?)]);
    try t.expectEqualStrings("18446744073709551615", decoded.value.loaded.binding.name_assertion.operation);
    const read = try p.Json.valueAlloc(alloc, bridge.Action{ .operation = .{ .reference = recovery, .command = .inspect, .steps = 1 } });
    var failed: ?*base.Buffer = null;
    try t.expectEqual(.unavailable, call(pointer.?, read.ptr, read.len, &failed));
    defer base.Api.station_buffer_destroy(failed);
    const detail = try p.Json.parseFromSlice(struct { err: []const u8, protocol_error: ?p.ErrorCode, diagnostic: p.Diagnostic }, alloc, base.Api.station_buffer_data(failed.?)[0..base.Api.station_buffer_size(failed.?)]);
    try t.expectEqual(.not_applicable, detail.value.diagnostic.outcome);
    try t.expectEqual(std.math.maxInt(u64), try detail.value.diagnostic.identity.?.id.value());
    const admit = try p.Json.valueAlloc(alloc, bridge.Action{ .admit = recovery });
    var no_dispatch: ?*base.Buffer = null;
    try t.expectEqual(.unavailable, call(pointer.?, admit.ptr, admit.len, &no_dispatch));
    defer base.Api.station_buffer_destroy(no_dispatch);
    const unavailable = try p.Json.parseFromSlice(struct { err: []const u8, protocol_error: ?p.ErrorCode, diagnostic: p.Diagnostic }, alloc, base.Api.station_buffer_data(no_dispatch.?)[0..base.Api.station_buffer_size(no_dispatch.?)]);
    try t.expectEqual(.not_submitted, unavailable.value.diagnostic.outcome);
    cast(pointer.?).busy.store(true, .release);
    var overlap: ?*base.Buffer = null;
    try t.expectEqual(.busy, call(pointer.?, load.ptr, load.len, &overlap));
    try t.expect(overlap == null);
    cast(pointer.?).busy.store(false, .release);
    const hostile = "{\"submit\":\"{}\"}";
    var rejected: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, hostile.ptr, hostile.len, &rejected));
    defer base.Api.station_buffer_destroy(rejected);
    const capabilities = "{\"catalog\":{\"capabilities\":{}}}";
    var retained: ?*base.Buffer = null;
    try t.expectEqual(.ok, call(pointer.?, capabilities.ptr, capabilities.len, &retained));
    defer base.Api.station_buffer_destroy(retained);
    destroy(pointer);
    pointer = null;
    const after_close = try p.Json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(retained.?)[0..base.Api.station_buffer_size(retained.?)]);
    defer after_close.deinit();
    try t.expectEqual(p.Growth.current_definition, after_close.value.catalog.capabilities.definition);
}
