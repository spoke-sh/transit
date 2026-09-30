//! Explicit catalog caller. This owns transport and signing, never a writer PID.
const std = @import("std");
const base = @import("Abi.zig");
const catalog = @import("transit_catalog");
const p = catalog.protocol;
const wire = catalog.station.client;
pub const bridge = catalog.Bridge;
const allocator = std.heap.page_allocator;
pub const Client = opaque {};
pub const Config = struct { connection: bridge.Connection, timeout_ms: u32 = 5000 };
const Impl = struct {
    threaded: std.Io.Threaded,
    transport: wire.Client,
    client: catalog.Client,
    url: []u8,
    busy: std.atomic.Value(bool) = .init(false),
};
fn cast(pointer: *Client) *Impl {
    return @ptrCast(@alignCast(pointer));
}
pub fn create(version: u32, url: [*]const u8, url_len: usize, seed: *const [32]u8, config: [*]const u8, config_len: usize, out: *?*Client) callconv(.c) base.Status {
    out.* = null;
    if (version != 1) return .incompatible_version;
    if (url_len == 0 or url_len > 2048 or config_len == 0 or config_len > 8192) return .invalid_argument;
    const uri = std.Uri.parse(url[0..url_len]) catch return .invalid_argument;
    if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return .invalid_argument;
    const parsed = p.Json.parseFromSlice(Config, allocator, config[0..config_len]) catch |err| return base.status(err);
    defer parsed.deinit();
    const options = parsed.value;
    const connection = options.connection.native() catch return .invalid_argument;
    if (options.timeout_ms == 0 or options.timeout_ms > 60000) return .invalid_argument;
    const client = allocator.create(Impl) catch return .out_of_memory;
    const endpoint = allocator.dupe(u8, url[0..url_len]) catch {
        allocator.destroy(client);
        return .out_of_memory;
    };
    client.* = .{ .url = endpoint, .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }), .transport = undefined, .client = undefined };
    client.transport = wire.Client.init(allocator, client.threaded.io(), endpoint);
    client.transport.timeout_ms = options.timeout_ms;
    client.client = .{ .transport = &client.transport, .connection = connection, .key = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable };
    out.* = @ptrCast(client);
    return .ok;
}
pub fn destroy(pointer: ?*Client) callconv(.c) void {
    const client = cast(pointer orelse return);
    std.crypto.secureZero(u8, std.mem.asBytes(&client.client.key));
    client.transport.deinit();
    client.threaded.deinit();
    allocator.free(client.url);
    allocator.destroy(client);
}
pub fn observe(pointer: *Client, observer: *wire.observability.telemetry.Runtime) void {
    cast(pointer).transport.observer = observer;
}
pub fn call(pointer: *Client, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > p.max_body) return .invalid_argument;
    const client = cast(pointer);
    if (client.busy.swap(true, .acquire)) return .busy;
    defer client.busy.store(false, .release);
    client.transport.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = p.Json.parseFromSlice(bridge.Action, alloc, json[0..len]) catch |err| return base.failure(err, out);
    // Malformed recovery cannot be dispatched. Once a validated submit starts,
    // unconfirmed transport or result-allocation failures remain uncertain.
    if (action.value == .submit) {
        const command = bridge.prepared(alloc, action.value.submit) catch |err| return base.failure(err, out);
        client.client.validate(command) catch |err| return base.failure(err, out);
    }
    const result = bridge.apply(alloc, &client.client, action.value) catch |err| {
        base.output(.{ .err = @errorName(err), .protocol_error = client.transport.last_rejection }, out) catch {};
        if (action.value == .submit and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
        return switch (err) {
            error.CatalogDenied => .denied,
            error.CatalogOwnerUnavailable, error.ResourceUnavailable => .unavailable,
            error.CatalogNotInitialized => .not_ready,
            error.CatalogIdentityConflict, error.CatalogScopeChanged, error.CatalogOwnerChanged, error.CatalogConfigurationChanged, error.CatalogPolicyConflict, error.CatalogCursorChanged, error.CatalogDefinitionChanged, error.CatalogSourceChanged => .conflict,
            else => base.status(err),
        };
    };
    base.output(result, out) catch |err| return if (action.value == .submit) .uncertain else base.status(err);
    return .ok;
}

test "catalog ABI owns outputs and validates before its uncertain dispatch boundary" {
    const t = std.testing;
    const endpoint = "http://127.0.0.1:1";
    const config = "{\"connection\":{\"scope\":{\"realm\":46,\"resource\":7,\"catalog\":\"18446744073709551615\"},\"owner\":3,\"principal\":17},\"timeout_ms\":100}";
    const seed: [32]u8 = @splat(10);
    var pointer: ?*Client = null;
    try t.expectEqual(.incompatible_version, create(2, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    try t.expect(pointer == null);
    try t.expectEqual(.ok, create(1, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    defer destroy(pointer);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const compile_action = "{\"compile\":{\"operation\":\"18446744073709551615\",\"object\":\"18446744073709551615\",\"table\":9,\"sql\":\"CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)\"}}";
    var buffer: ?*base.Buffer = null;
    try t.expectEqual(.ok, call(pointer.?, compile_action.ptr, compile_action.len, &buffer));
    defer base.Api.station_buffer_destroy(buffer);
    const decoded = try p.Json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)]);
    const request = try decoded.value.compiled.request.native();
    try t.expectEqual(std.math.maxInt(u64), request.operation);
    cast(pointer.?).busy.store(true, .release);
    var overlap: ?*base.Buffer = null;
    try t.expectEqual(.busy, call(pointer.?, compile_action.ptr, compile_action.len, &overlap));
    try t.expect(overlap == null);
    cast(pointer.?).busy.store(false, .release);
    const invalid = "{\"submit\":\"{}\"}";
    var rejected: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, invalid.ptr, invalid.len, &rejected));
    defer base.Api.station_buffer_destroy(rejected);
    const signed: catalog.Client.Prepared = .{ .version = 1, .definition = p.Growth.current_definition, .connection = cast(pointer.?).client.connection, .signed = try p.Growth.sign(.{ .realm = 46, .principal = 17, .sequence = 1, .command = .{ .send = .{ .pid = 3, .value = try (catalog.station.Frame{ .kind = .cast, .payload = try catalog.Records.encode('q', request) }).encode() } } }, try p.Ed25519.KeyPair.generateDeterministic(seed)) };
    const token = try signed.save(alloc);
    const action = try p.Json.valueAlloc(alloc, bridge.Action{ .submit = token });
    var failure: ?*base.Buffer = null;
    try t.expectEqual(.uncertain, call(pointer.?, action.ptr, action.len, &failure));
    defer base.Api.station_buffer_destroy(failure);
    var forged = signed;
    forged.signed.signature[0] ^= 1;
    const tampered = try p.Json.valueAlloc(alloc, bridge.Action{ .submit = try forged.save(alloc) });
    var signature: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, tampered.ptr, tampered.len, &signature));
    defer base.Api.station_buffer_destroy(signature);
    destroy(pointer);
    pointer = null;
    const retained = try p.Json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)]);
    try t.expectEqualDeep(decoded.value, retained.value);
}
