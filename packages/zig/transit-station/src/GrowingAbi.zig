//! Explicit growing-profile foreign handles. Preparation never submits; hosts
//! persist the canonical pending envelope before one explicit dispatch attempt.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
const base = @import("Abi.zig");
pub const actions = @import("GrowingActions.zig");
const allocator = std.heap.page_allocator;
pub const Server = opaque {};
pub const Config = struct {
    profile: enum { growing_v3 },
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64,
    association: []const u8 = "data",
    timeout_ms: u32 = 5000,
    failure_policy: @FieldType(s.GrowingGenServer, "failure_policy"),
};
pub const Capabilities = struct {
    version: u32 = 1,
    profile: []const u8 = "growing_v3",
    gated_dispatch: bool = true,
    scoped_turns: bool = true,
    paged_state: bool = true,
    tables: bool = true,
    retained_sources: bool = true,
    query_results: bool = false,
};
pub const Event = struct {
    event: enum { idle, progress, ready, pending, committed, blocked },
    pid: u64,
    generation: u64,
    scope: ?u64 = null,
    initializing: bool = false,
    input: ?struct { position: u64, origin: p.Growth.Origin, kind: s.Frame.Kind, correlation: []const u8, payload: p.Value } = null,
    resource: ?u64 = null,
    resource_revision: ?u64 = null,
    pending_kind: ?s.GrowingGenServer.PendingKind = null,
    confirmation: ?s.GrowingGenServer.Confirmation = null,
};
const Impl = struct {
    threaded: std.Io.Threaded,
    client: s.client.Client,
    url: []u8,
    behavior: s.GrowingGenServer,
    busy: std.atomic.Value(bool) = .init(false),
    cached: ?s.GrowingGenServer.Poll = null,
    cached_dispatch: bool = false,
    scope: ?u64 = null,
    scope_counter: u64 = 0,
};
fn cast(pointer: *Server) *Impl {
    return @ptrCast(@alignCast(pointer));
}
fn lock(server: *Impl) bool {
    return !server.busy.swap(true, .acquire);
}
pub fn observe(pointer: *Server, observer: *s.client.observability.telemetry.Runtime) void {
    cast(pointer).client.observer = observer;
}
pub fn capabilities(out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    base.output(Capabilities{}, out) catch |err| return base.status(err);
    return .ok;
}
pub fn create(abi_version: u32, url: [*]const u8, url_len: usize, seed: *const [32]u8, config: [*]const u8, config_len: usize, out: *?*Server) callconv(.c) base.Status {
    out.* = null;
    if (abi_version != 1) return .incompatible_version;
    if (url_len == 0 or url_len > 2048 or config_len == 0 or config_len > 8192) return .invalid_argument;
    const uri = std.Uri.parse(url[0..url_len]) catch return .invalid_argument;
    if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return .invalid_argument;
    const parsed = std.json.parseFromSlice(Config, allocator, config[0..config_len], .{}) catch |err| return base.status(err);
    defer parsed.deinit();
    const c = parsed.value;
    if (c.realm == 0 or c.realm > p.max_counter or c.principal == 0 or c.principal > p.max_counter or c.pid == 0 or c.pid > p.max_counter or c.generation == 0 or c.generation > p.max_counter or c.timeout_ms == 0 or c.timeout_ms > 60000) return .invalid_argument;
    const server = allocator.create(Impl) catch return .out_of_memory;
    const endpoint = allocator.dupe(u8, url[0..url_len]) catch {
        allocator.destroy(server);
        return .out_of_memory;
    };
    server.* = .{ .url = endpoint, .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }), .client = undefined, .behavior = undefined };
    server.client = s.client.Client.init(allocator, server.threaded.io(), endpoint);
    server.client.timeout_ms = c.timeout_ms;
    var key = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    server.behavior = s.GrowingGenServer.init(.{ .client = &server.client, .realm = c.realm, .principal = c.principal, .pid = c.pid, .generation = c.generation, .key = key }, c.association) catch |err| {
        server.client.deinit();
        server.threaded.deinit();
        allocator.free(endpoint);
        allocator.destroy(server);
        return base.status(err);
    };
    server.behavior.failure_policy = c.failure_policy;
    out.* = @ptrCast(server);
    return .ok;
}
pub fn destroy(pointer: ?*Server) callconv(.c) void {
    const server = cast(pointer orelse return);
    std.crypto.secureZero(u8, std.mem.asBytes(&server.behavior.session.key));
    server.client.deinit();
    server.threaded.deinit();
    allocator.free(server.url);
    allocator.destroy(server);
}
fn failure(server: *Impl, err: anyerror, dispatching: bool, out: *?*base.Buffer) base.Status {
    base.output(.{ .err = @errorName(err), .protocol_error = server.client.last_rejection }, out) catch {};
    if (dispatching and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
    const result = base.status(err);
    return if (result == .invalid_argument and (server.behavior.ready == null or server.behavior.ready.?.read_error != null)) .unavailable else result;
}
fn event(server: *Impl, out: *?*base.Buffer) base.Status {
    return eventWithAllocator(allocator, server, out);
}
fn eventWithAllocator(alloc: std.mem.Allocator, server: *Impl, out: *?*base.Buffer) base.Status {
    const observed = server.cached.?;
    var result: Event = .{ .event = switch (observed) {
        .idle => .idle,
        .progress => if (server.behavior.pending != null) .pending else .progress,
        .ready => .ready,
        .committed => .committed,
        .blocked => .blocked,
    }, .pid = server.behavior.session.pid, .generation = server.behavior.session.generation };
    if (server.behavior.pending != null) result.pending_kind = server.behavior.pending_kind;
    if (server.cached_dispatch) result.confirmation = server.behavior.confirmation;
    var correlation: [20]u8 = undefined;
    if (server.behavior.ready) |turn| {
        const frame = s.Frame.decode(turn.delivery.input.value) catch |err| return base.failure(err, out);
        result.scope = server.scope;
        result.initializing = server.behavior.initializing;
        result.input = .{ .position = turn.delivery.input.position, .origin = turn.delivery.input.origin, .kind = frame.kind, .correlation = std.fmt.bufPrint(&correlation, "{d}", .{frame.correlation}) catch unreachable, .payload = frame.payload };
        result.resource = turn.view.resource;
        result.resource_revision = turn.view.revision;
    }
    base.outputWithAllocator(alloc, result, out) catch |err| return if (server.cached_dispatch) .uncertain else base.status(err);
    server.cached = null;
    server.cached_dispatch = false;
    return .ok;
}
pub fn prepare(pointer: *Server, deadline_ms: u64, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    server.client.last_rejection = null;
    if (server.cached == null) {
        if (server.scope_counter == p.max_counter) return .budget_exceeded;
        server.cached = server.behavior.prepare(deadline_ms) catch |err| return failure(server, err, false, out);
        if (server.cached == .ready and server.scope == null) {
            server.scope_counter += 1;
            server.scope = server.scope_counter;
        }
    }
    return event(server, out);
}
pub fn dispatch(pointer: *Server, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    server.client.last_rejection = null;
    if (server.cached == null) {
        if (server.behavior.pending == null) return .not_ready;
        server.cached = server.behavior.dispatchPending() catch |err| return failure(server, err, true, out);
        server.cached_dispatch = true;
    } else if (!server.cached_dispatch) return .not_ready;
    return event(server, out);
}
pub fn apply(pointer: *Server, scope: u64, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > p.max_body) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.scope == null or server.scope.? != scope) return .not_ready;
    const turn = if (server.behavior.ready) |*value| value else return .not_ready;
    const parsed = std.json.parseFromSlice(actions.Action, allocator, json[0..len], .{}) catch |err| return base.failure(err, out);
    defer parsed.deinit();
    server.client.last_rejection = null;
    const before = turn.decision;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const result = actions.apply(arena.allocator(), turn, parsed.value) catch |err| {
        turn.decision = before; // Sticky read_error deliberately survives rollback.
        return failure(server, err, false, out);
    };
    base.output(result, out) catch |err| {
        turn.decision = before;
        return base.status(err);
    };
    return .ok;
}
pub fn finish(pointer: *Server, scope: u64, failed: u32) callconv(.c) base.Status {
    if (failed > 1) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.scope == null or server.scope.? != scope) return .not_ready;
    defer if (server.behavior.ready == null) {
        server.scope = null;
        server.cached = null;
    };
    server.behavior.finish(if (failed == 1) error.ForeignHandlerFailure else null) catch |err| return base.status(err);
    return .ok;
}
pub fn discard(pointer: *Server, scope: u64) callconv(.c) base.Status {
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.scope == null or server.scope.? != scope) return .not_ready;
    server.behavior.discard() catch |err| return base.status(err);
    server.scope = null;
    server.cached = null;
    return .ok;
}
pub fn pending(pointer: *Server, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    const frozen = server.behavior.pending orelse return .not_ready;
    base.output(.{ .version = @as(u32, 1), .operation = .{ .growing_command = frozen.signed } }, out) catch |err| return base.status(err);
    return .ok;
}

test "growing dispatch response allocation preserves uncertainty and the owned confirmation" {
    const t = std.testing;
    var wire: s.client.Client = undefined;
    var host = try s.GrowingGenServer.init(.{ .client = &wire, .realm = 72, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "data");
    // This is the exact state after dispatch has accepted a commit, before the
    // foreign response is allocated. Transport/disk loss has a separate proof.
    host.confirmation = .{ .kind = .commit, .input = 7, .receipt = .{ .position = 37 } };
    var failures: usize = 0;
    var completed = false;
    for (0..32) |index| {
        var server: Impl = .{ .threaded = undefined, .client = undefined, .url = undefined, .behavior = host, .cached = .committed, .cached_dispatch = true };
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        var out: ?*base.Buffer = null;
        const result = eventWithAllocator(failing.allocator(), &server, &out);
        defer base.destroyBufferWithAllocator(failing.allocator(), out);
        if (failing.has_induced_failure) {
            failures += 1;
            try t.expectEqual(.uncertain, result);
            try t.expect(server.cached == .committed and server.cached_dispatch);
            try t.expect(std.meta.eql(host.confirmation, server.behavior.confirmation));
            var retried: ?*base.Buffer = null;
            try t.expectEqual(.ok, eventWithAllocator(t.allocator, &server, &retried));
            defer base.destroyBufferWithAllocator(t.allocator, retried);
            const parsed = try std.json.parseFromSlice(Event, t.allocator, base.Api.station_buffer_data(retried.?)[0..base.Api.station_buffer_size(retried.?)], .{});
            defer parsed.deinit();
            try t.expectEqual(@as(u64, 37), parsed.value.confirmation.?.receipt.position);
            try t.expectEqual(@as(u64, 7), parsed.value.confirmation.?.input);
            try t.expect(server.cached == null and !server.cached_dispatch);
        } else {
            try t.expectEqual(.ok, result);
            try t.expect(failures >= 2);
            completed = true;
            break;
        }
    }
    try t.expect(completed);
}
