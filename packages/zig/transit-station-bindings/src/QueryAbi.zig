//! Standalone caller handle: no PID ownership, activation or handler capability.
const std = @import("std");
const base = @import("Abi.zig");
pub const bridge = @import("QueryBridge.zig");
const q = bridge.q;
const allocator = std.heap.page_allocator;
pub const Client = opaque {};
pub const Config = struct { connection: q.UnifiedClient.Connection, timeout_ms: u32 = 5000 };
const Impl = struct {
    threaded: std.Io.Threaded,
    wire: q.wire.Client,
    client: q.UnifiedClient,
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
    const parsed = std.json.parseFromSlice(Config, allocator, config[0..config_len], .{}) catch |err| return base.status(err);
    defer parsed.deinit();
    const c = parsed.value;
    inline for (.{ "realm", "principal", "source", "resource", "requester", "requests" }) |field| q.UnifiedRecords.identity(@field(c.connection, field)) catch return .invalid_argument;
    if (c.timeout_ms == 0 or c.timeout_ms > 60000) return .invalid_argument;
    const client = allocator.create(Impl) catch return .out_of_memory;
    const endpoint = allocator.dupe(u8, url[0..url_len]) catch {
        allocator.destroy(client);
        return .out_of_memory;
    };
    client.* = .{ .url = endpoint, .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }), .wire = undefined, .client = undefined };
    client.wire = q.wire.Client.init(allocator, client.threaded.io(), endpoint);
    client.wire.timeout_ms = c.timeout_ms;
    client.client = .{ .wire = &client.wire, .connection = c.connection, .key = q.protocol.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable };
    out.* = @ptrCast(client);
    return .ok;
}
pub fn destroy(pointer: ?*Client) callconv(.c) void {
    const client = cast(pointer orelse return);
    std.crypto.secureZero(u8, std.mem.asBytes(&client.client.key));
    client.wire.deinit();
    client.threaded.deinit();
    allocator.free(client.url);
    allocator.destroy(client);
}
pub fn observe(pointer: *Client, observer: *q.wire.observability.telemetry.Runtime) void {
    cast(pointer).wire.observer = observer;
}
pub fn call(pointer: *Client, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > q.protocol.max_body) return .invalid_argument;
    const client = cast(pointer);
    if (client.busy.swap(true, .acquire)) return .busy;
    defer client.busy.store(false, .release);
    client.wire.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = std.json.parseFromSlice(bridge.Action, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    // Local envelope validation happens before the dispatch boundary. Any
    // later unconfirmed transport/result failure retains the exact token.
    if (action.value == .submit) {
        const signed = bridge.prepared(alloc, action.value.submit) catch |err| return base.failure(err, out);
        client.client.validate(signed) catch |err| return base.failure(err, out);
    }
    const result = bridge.apply(alloc, &client.client, action.value) catch |err| {
        base.output(.{ .err = @errorName(err), .protocol_error = client.wire.last_rejection }, out) catch {};
        if (action.value == .submit and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
        if (err == error.QueryReadConflict) return .conflict;
        if (err == error.QueryDenied) return .denied;
        return base.status(err);
    };
    base.output(result, out) catch |err| return if (action.value == .submit) .uncertain else base.status(err);
    return .ok;
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
    // A rejected local envelope cannot be confused with a dispatched timeout.
    var foreign = signed;
    foreign.signed.request.realm = 99;
    const wrong = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = try std.json.Stringify.valueAlloc(alloc, foreign, .{}) }, .{});
    var rejection: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, wrong.ptr, wrong.len, &rejection));
    defer base.Api.station_buffer_destroy(rejection);
}
