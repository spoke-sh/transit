//! Standalone caller handle: no PID ownership, activation or handler capability.
const std = @import("std");
const base = @import("Abi.zig");
const q = @import("transit_query");
pub const bridge = q.TableMutationBridge;
const allocator = std.heap.page_allocator;
pub const Client = opaque {};
pub const Config = struct { connection: q.TableMutationClient.Connection, timeout_ms: u32 = 5000 };
const Impl = struct {
    threaded: std.Io.Threaded,
    wire: q.wire.Client,
    client: q.TableMutationClient,
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
    c.connection.validate() catch return .invalid_argument;
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
    if (len == 0 or len > q.protocol.max_body) return invalidEnvelope(error.InvalidMutationCommand, out);
    const client = cast(pointer);
    if (client.busy.swap(true, .acquire)) return .busy;
    defer client.busy.store(false, .release);
    client.wire.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = std.json.parseFromSlice(bridge.Action, alloc, json[0..len], .{}) catch |err| return invalidEnvelope(err, out);
    // Local envelope validation happens before the dispatch boundary. Any
    // later unconfirmed transport/result failure retains the exact token.
    var identity: ?q.protocol.Diagnostic.Identity = null;
    if (action.value == .submit) {
        const signed = bridge.prepared(alloc, action.value.submit) catch |err| return localFailure(action.value, err, out);
        client.client.validate(signed) catch |err| return localFailure(action.value, err, out);
        identity = .{ .domain = .transport, .id = .init(signed.signed.request.sequence), .sequence = .init(signed.signed.request.sequence), .realm = .init(signed.signed.request.realm) };
    }
    var binding: q.fuze.Sql.Binding = .{};
    const result = bridge.applyDiagnostic(alloc, &client.client, action.value, &binding) catch |err| {
        const diagnostic = q.MutationDiagnostic.attempt(action.value, err, binding, action.value == .submit, identity) catch null;
        base.output(.{ .err = @errorName(err), .protocol_error = client.wire.last_rejection, .diagnostic = diagnostic }, out) catch {};
        if (action.value == .submit and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
        if (err == error.MutationDenied) return .denied;
        if (err == error.MutationWriterUnavailable) return .unavailable;
        if (err == error.MutationBusy) return .busy;
        if (err == error.MutationIdentityConflict or err == error.StaleMutationPolicy or err == error.MutationSourceChanged) return .conflict;
        if (err == error.OutOfMemory) return .out_of_memory;
        switch (q.MutationDiagnostic.category(action.value, err)) {
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
fn invalidEnvelope(err: anyerror, out: *?*base.Buffer) base.Status {
    const diagnostic = q.MutationDiagnostic.invalidEnvelope(err) catch null;
    base.output(.{ .err = @errorName(err), .diagnostic = diagnostic }, out) catch {};
    return if (err == error.OutOfMemory) .out_of_memory else .invalid_argument;
}
fn localFailure(action: bridge.Action, err: anyerror, out: *?*base.Buffer) base.Status {
    const diagnostic = q.MutationDiagnostic.attempt(action, err, .{}, false, null) catch null;
    base.output(.{ .err = @errorName(err), .diagnostic = diagnostic }, out) catch {};
    return base.status(err);
}

test "mutation ABI owns results, separates caller profiles and preserves dispatch uncertainty" {
    const t = std.testing;
    const endpoint = "http://127.0.0.1:1";
    const config = "{\"connection\":{\"realm\":46,\"principal\":1234,\"writer\":65536,\"resource\":7,\"table\":1},\"timeout_ms\":100}";
    const seed: [32]u8 = @splat(10);
    var pointer: ?*Client = null;
    try t.expectEqual(.incompatible_version, create(2, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    try t.expect(pointer == null);
    try t.expectEqual(.ok, create(1, endpoint.ptr, endpoint.len, &seed, config.ptr, config.len, &pointer));
    defer destroy(pointer);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const caps = "{\"capabilities\":{}}";
    var buffer: ?*base.Buffer = null;
    try t.expectEqual(.ok, call(pointer.?, caps.ptr, caps.len, &buffer));
    defer base.Api.station_buffer_destroy(buffer);
    const result = try std.json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
    try t.expectEqual(@as(u8, 3), result.value.capabilities.max_rows);
    cast(pointer.?).busy.store(true, .release);
    var overlapping: ?*base.Buffer = null;
    try t.expectEqual(.busy, call(pointer.?, caps.ptr, caps.len, &overlapping));
    try t.expect(overlapping == null);
    cast(pointer.?).busy.store(false, .release);
    const invalid = "{\"submit\":\"{}\"}";
    var rejected: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, invalid.ptr, invalid.len, &rejected));
    defer base.Api.station_buffer_destroy(rejected);
    const local = try std.json.parseFromSlice(struct { err: []const u8, diagnostic: q.protocol.Diagnostic }, alloc, base.Api.station_buffer_data(rejected.?)[0..base.Api.station_buffer_size(rejected.?)], .{});
    try t.expectEqual(.not_submitted, local.value.diagnostic.outcome);
    try t.expectEqual(.local_before_dispatch, local.value.diagnostic.evidence);
    const table: q.station.Table = .{ .resource = 7, .id = 1, .schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 } };
    const request = try q.TableMutationRequest.fromSql(46, 65536, table, try .init("items"), "DELETE FROM items WHERE id=1");
    const signed: q.TableMutationClient.Prepared = .{ .version = 1, .definition = q.protocol.Growth.current_definition, .connection = .{ .realm = 46, .principal = 1234, .writer = 65536, .resource = 7, .table = 1 }, .signed = try q.protocol.Growth.sign(.{ .realm = 46, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = 65536, .value = try (q.station.Frame{ .kind = .cast, .payload = try (q.TableMutationRecords.Command{ .apply = try request.reference(99) }).encode() }).encode() } } }, try q.protocol.Ed25519.KeyPair.generateDeterministic(seed)) };
    const token = try signed.save(alloc);
    const action = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = token }, .{});
    var failure: ?*base.Buffer = null;
    try t.expectEqual(.uncertain, call(pointer.?, action.ptr, action.len, &failure));
    defer base.Api.station_buffer_destroy(failure);
    const remote = try std.json.parseFromSlice(struct { err: []const u8, protocol_error: ?[]const u8, diagnostic: q.protocol.Diagnostic }, alloc, base.Api.station_buffer_data(failure.?)[0..base.Api.station_buffer_size(failure.?)], .{});
    try t.expectEqual(.unknown, remote.value.diagnostic.outcome);
    try t.expectEqual(.resume_exact, remote.value.diagnostic.actions[1].?.kind);
    try t.expectEqual(@as(u64, 1), try remote.value.diagnostic.identity.?.sequence.?.value());
    try t.expect(std.meta.eql(signed, try bridge.prepared(alloc, token)));
    var foreign = signed;
    foreign.connection.table += 1;
    const wrong = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = try foreign.save(alloc) }, .{});
    var conflict: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, wrong.ptr, wrong.len, &conflict));
    defer base.Api.station_buffer_destroy(conflict);
    var forged = signed;
    forged.signed.signature[0] ^= 1;
    const tampered = try std.json.Stringify.valueAlloc(alloc, bridge.Action{ .submit = try forged.save(alloc) }, .{});
    var signature: ?*base.Buffer = null;
    try t.expectEqual(.invalid_argument, call(pointer.?, tampered.ptr, tampered.len, &signature));
    defer base.Api.station_buffer_destroy(signature);
    destroy(pointer);
    pointer = null;
    // Returned bytes outlive the native caller and its I/O state.
    const retained = try std.json.parseFromSlice(bridge.Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
    try t.expectEqualDeep(result.value, retained.value);
}
