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
    profile: enum { native_v1 },
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64,
    association: []const u8 = "data",
    timeout_ms: u32 = 5000,
    failure_policy: @FieldType(s.GenServer, "failure_policy"),
    query_results: bool = false,
};
pub const Capabilities = struct {
    version: u32 = 1,
    definition: p.Growth.Definition = p.Growth.current_definition,
    profile: []const u8 = "native_v1",
    gated_dispatch: bool = true,
    retained_confirmation: bool = true,
    scoped_turns: bool = true,
    paged_state: bool = true,
    tables: bool = true,
    retained_sources: bool = true,
    publications: bool = true,
    document_codecs: bool = true,
    document_owner: bool = true,
    document_reads: bool = true,
    document_change_bytes: u32 = 4096,
    document_page_items: u32 = 8,
    unified_query_codecs: bool = true,
    unified_query_version: u8 = 1,
    grpc_requests: bool = true,
    grpc_descriptors: bool = true,
    grpc_release: bool = true,
    grpc_followup: bool = true,
    grpc_replay: bool = true,
    grpc_active_readers: u32 = 1,
    grpc_request_bytes: u32 = @import("GrpcCodec.zig").grpc.Batch.maximum_bytes,
    http_requests: bool = true,
    http_release: bool = true,
    http_followup: bool = true,
    http_replay: bool = true,
    http_active_readers: u32 = 1,
    http_request_bytes: u32 = @import("HttpCodec.zig").http.RequestRecord.maximum_body_bytes,
    publication_chunk_bytes: u32 = s.Publication.chunk_bytes,
    query_results: bool = true,
    ipc_cells: bool = true,
    query_segment_bytes: u32 = s.Query.records.segment_bytes,
    query_workspace_bytes: u32 = s.fuze.execution.working_bytes,
    value_bytes: u32 = p.Value.max_bytes,
    message_bytes: u32 = s.Frame.max_payload,
    key_bytes: u32 = p.Growth.key_bytes,
    table_columns: u32 = s.fuze.TableSchema.max_columns,
    table_row_bytes: u32 = s.fuze.TableRow.max_bytes,
    table_page_rows: u32 = s.TableReader.max_page_rows,
    table_action_bytes: u32 = p.max_body,
    table_result_bytes: u32 = @import("TableBridge.zig").max_result_bytes,
    table_resumable_mutations: bool = true,
    page_entries: u32 = p.Growth.page_size,
    turn_mutations: u32 = p.Growth.turn_mutations,
    turn_outputs: u32 = p.Growth.turn_outputs,
    max_counter: u64 = p.max_counter,
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
    pending_kind: ?s.GenServer.PendingKind = null,
    pending_input: ?u64 = null,
    confirmation: ?s.GenServer.Confirmation = null,
};
const Impl = struct {
    threaded: std.Io.Threaded,
    client: s.client.Client,
    url: []u8,
    behavior: s.GenServer,
    busy: std.atomic.Value(bool) = .init(false),
    cached: ?s.GenServer.Poll = null,
    cached_dispatch: bool = false,
    scope: ?u64 = null,
    scope_counter: u64 = 0,
    workspace: ?[]u8 = null,
    cancellation: s.fuze.execution.Cancellation = .init(false),
    http_client: @import("HttpCodec.zig").http.exchange.Client = undefined,
    http_reader: ?@import("HttpCodec.zig").http.Replay = null,
    http_reader_id: u64 = 0,
    grpc_client: @import("GrpcCodec.zig").grpc.exchange.Client = undefined,
    grpc_reader: ?@import("GrpcCodec.zig").grpc.Replay = null,
    grpc_reader_id: u64 = 0,
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
    server.behavior = s.GenServer.init(.{ .client = &server.client, .realm = c.realm, .principal = c.principal, .pid = c.pid, .generation = c.generation, .key = key }, c.association) catch |err| {
        server.client.deinit();
        server.threaded.deinit();
        allocator.free(endpoint);
        allocator.destroy(server);
        return base.status(err);
    };
    server.behavior.failure_policy = c.failure_policy;
    if (c.query_results) {
        server.workspace = allocator.alloc(u8, s.fuze.execution.working_bytes) catch {
            destroy(@ptrCast(server));
            return .out_of_memory;
        };
        server.behavior.query = .{ .allocator = allocator, .workspace = server.workspace.?, .cancellation = &server.cancellation };
    }
    out.* = @ptrCast(server);
    return .ok;
}
pub fn destroy(pointer: ?*Server) callconv(.c) void {
    const server = cast(pointer orelse return);
    std.crypto.secureZero(u8, std.mem.asBytes(&server.http_client.key));
    std.crypto.secureZero(u8, std.mem.asBytes(&server.grpc_client.key));
    std.crypto.secureZero(u8, std.mem.asBytes(&server.behavior.session.key));
    server.client.deinit();
    server.threaded.deinit();
    allocator.free(server.url);
    if (server.workspace) |workspace| allocator.free(workspace);
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
    if (server.behavior.pending != null) {
        result.pending_kind = server.behavior.pending_kind;
        result.pending_input = server.behavior.delivery.?.input.position;
    }
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
/// Re-observe native acceptance after foreign response decoding/allocation fails.
/// The host must match purpose/input to its saved operation before advancing.
pub fn confirmation(pointer: *Server, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    const confirmed = server.behavior.confirmation orelse return .not_ready;
    if (server.cached_dispatch) return event(server, out);
    const result: Event = .{
        .event = if (confirmed.kind == .commit) (if (server.behavior.blocked) .blocked else .committed) else .progress,
        .pid = server.behavior.session.pid,
        .generation = server.behavior.session.generation,
        .confirmation = confirmed,
    };
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}
pub fn apply(pointer: *Server, scope: u64, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > p.max_body) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.scope == null or server.scope.? != scope) return .not_ready;
    const turn = if (server.behavior.ready) |*value| value else return .not_ready;
    s.fuze.Types.Json.preflight(json[0..len], .{ .bytes = p.max_body, .depth = 96, .tokens = p.max_body + 1 }) catch |err| return base.failure(err, out);
    const parsed = std.json.parseFromSlice(actions.Action, allocator, json[0..len], .{}) catch |err| return base.failure(err, out);
    defer parsed.deinit();
    if (parsed.value.requiresQuery() and server.behavior.query == null) return base.failure(error.UnsupportedQuery, out);
    server.client.last_rejection = null;
    const before = turn.decision;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const result = actions.apply(&arena, turn, parsed.value) catch |err| {
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
    return finishInner(pointer, scope, failed, null);
}
/// The additive detailed form preserves read/validation causes at freeze time.
pub fn finishResult(pointer: *Server, scope: u64, failed: u32, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    return finishInner(pointer, scope, failed, out);
}
fn finishInner(pointer: *Server, scope: u64, failed: u32, out: ?*?*base.Buffer) base.Status {
    if (failed > 1) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.scope == null or server.scope.? != scope) return .not_ready;
    defer if (server.behavior.ready == null) {
        server.scope = null;
        server.cached = null;
    };
    const poisoned = if (server.behavior.ready) |turn| turn.read_error != null else false;
    server.behavior.finish(if (failed == 1) error.ForeignHandlerFailure else null) catch |err| {
        if (out) |output| base.output(.{ .err = @errorName(err), .protocol_error = server.client.last_rejection }, output) catch {};
        const result = base.status(err);
        return if (poisoned and result == .invalid_argument) .unavailable else result;
    };
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
    base.output(@import("client_abi").Frozen{ .definition = p.Growth.current_definition, .operation = .{ .growing_command = frozen.signed } }, out) catch |err| return base.status(err);
    return .ok;
}

/// Stateless bounded accepted-state reads. No ownership, cursor or result bytes
/// are retained by the native handle; host destruction must still join this call.
pub fn documentRead(pointer: *Server, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > 4096) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.behavior.ready != null or server.behavior.pending != null) return .busy;
    server.client.last_rejection = null;
    const bridge = @import("DocumentBridge.zig");
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = std.json.parseFromSlice(bridge.ReadAction, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    const session = server.behavior.session;
    const client: @import("DocumentCodec.zig").document.Client = .{ .source = .{ .wire = &server.client, .realm = session.realm, .principal = session.principal, .key = session.key } };
    const result = bridge.read(alloc, client, parsed.value) catch |err| return failure(server, err, false, out);
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}

/// One bounded reader per native handle, outside an active handler or mutation.
/// Returned bytes are owned; a cursor never crosses the foreign boundary.
pub fn httpRead(pointer: *Server, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    return replayRead(@import("HttpCodec.zig"), "http", pointer, json, len, out);
}
pub fn grpcRead(pointer: *Server, json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    return replayRead(@import("GrpcCodec.zig"), "grpc", pointer, json, len, out);
}
fn replayRead(comptime Codec: type, comptime prefix: []const u8, pointer: *Server, json: [*]const u8, len: usize, out: *?*base.Buffer) base.Status {
    out.* = null;
    if (len == 0 or len > 2048) return .invalid_argument;
    const server = cast(pointer);
    if (!lock(server)) return .busy;
    defer server.busy.store(false, .release);
    if (server.behavior.ready != null or server.behavior.pending != null) return .busy;
    // A poisoned replay can reject locally without issuing another query. Do
    // not attach an earlier request's authority rejection to this operation.
    server.client.last_rejection = null;
    const h = Codec;
    const adapter = @field(Codec, prefix);
    const parsed = std.json.parseFromSlice(h.ReadAction, allocator, json[0..len], .{}) catch |err| return base.failure(err, out);
    defer parsed.deinit();
    switch (parsed.value) {
        .diagnostic => |value| {
            const identity = value.identity.native() catch |err| return base.failure(err, out);
            const session = server.behavior.session;
            var client: adapter.exchange.Client = .{ .wire = &server.client, .realm = session.realm, .principal = session.principal, .key = session.key };
            const detail = client.diagnostic(identity.resource, identity.exchange, adapter.protocol_format, value.kind) catch |err| return failure(server, err, false, out);
            base.output(h.ReadResult{ .diagnostic = detail }, out) catch |err| return base.status(err);
        },
        .open => |value| {
            if (@field(server, prefix ++ "_reader") != null) return .busy;
            if (@field(server, prefix ++ "_reader_id") == p.max_counter) return .budget_exceeded;
            const session = server.behavior.session;
            @field(server, prefix ++ "_client") = .{ .wire = &server.client, .realm = session.realm, .principal = session.principal, .key = session.key };
            const reference = adapter.exchange.Client.Reference.decode(value.reference) catch |err| return base.failure(err, out);
            const reader = adapter.Replay.open(&@field(server, prefix ++ "_client"), reference, value.policy) catch |err| return failure(server, err, false, out);
            const id = @field(server, prefix ++ "_reader_id") + 1;
            base.output(h.ReadResult{ .opened = id }, out) catch |err| return base.status(err);
            @field(server, prefix ++ "_reader") = reader;
            @field(server, prefix ++ "_reader_id") = id;
        },
        .next => |id| {
            if (id == 0 or id != @field(server, prefix ++ "_reader_id") or @field(server, prefix ++ "_reader") == null) return .not_ready;
            // Allocation failure cannot silently consume a verified body part.
            const before = @field(server, prefix ++ "_reader").?;
            const part = @field(server, prefix ++ "_reader").?.read() catch |err| return failure(server, err, false, out);
            return replayPartOutput(Codec, prefix, allocator, server, before, part, out);
        },
        .close => |id| {
            if (id == 0 or id != @field(server, prefix ++ "_reader_id")) return .not_ready;
            base.output(h.ReadResult{ .closed = true }, out) catch |err| return base.status(err);
            @field(server, prefix ++ "_reader") = null;
            std.crypto.secureZero(u8, std.mem.asBytes(&@field(server, prefix ++ "_client").key));
        },
    }
    return .ok;
}
fn replayPartOutput(comptime Codec: type, comptime prefix: []const u8, alloc: std.mem.Allocator, server: *Impl, before: @field(Codec, prefix).Replay, part: ?@field(Codec, prefix).Replay.Part, out: *?*base.Buffer) base.Status {
    base.outputWithAllocator(alloc, Codec.ReadResult{ .part = part }, out) catch |err| {
        @field(server, prefix ++ "_reader") = before;
        return base.status(err);
    };
    return .ok;
}

test "HTTP body response allocation cannot advance a cursor past undisclosed bytes" {
    const t = std.testing;
    const h = @import("HttpCodec.zig");
    const before: h.http.Replay = .{ .client = undefined, .reference = undefined, .cursor = undefined, .validator = .{ .terminal_status = 200 } };
    var completed = before;
    completed.done = true;
    var failures: usize = 0;
    for (0..32) |index| {
        var server: Impl = .{ .threaded = undefined, .client = undefined, .url = undefined, .behavior = undefined, .http_reader = completed };
        var alloc = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        var out: ?*base.Buffer = null;
        const status = replayPartOutput(h, "http", alloc.allocator(), &server, before, .{ .kind = .response_body, .bytes = try p.Value.init(&.{ 0, 255, 1 }), .complete = true }, &out);
        defer base.destroyBufferWithAllocator(alloc.allocator(), out);
        if (status == .out_of_memory) {
            failures += 1;
            try t.expectEqual(null, out);
            try t.expect(!server.http_reader.?.done);
        } else {
            try t.expectEqual(.ok, status);
            try t.expect(server.http_reader.?.done);
            try t.expect(failures > 0);
            return;
        }
    }
    return error.NoSuccessfulAllocation;
}
test "RPC body response allocation cannot advance a cursor past undisclosed bytes" {
    const t = std.testing;
    const h = @import("GrpcCodec.zig");
    const before: h.grpc.Replay = .{ .client = undefined, .reference = undefined, .cursor = undefined, .validator = .{ .terminal_code = 1 } };
    var completed = before;
    completed.done = true;
    var failures: usize = 0;
    for (0..32) |index| {
        var server: Impl = .{ .threaded = undefined, .client = undefined, .url = undefined, .behavior = undefined, .grpc_reader = completed };
        var alloc = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        var out: ?*base.Buffer = null;
        const status = replayPartOutput(h, "grpc", alloc.allocator(), &server, before, .{ .kind = .response_body, .bytes = try p.Value.init(&.{ 0, 255, 1 }), .complete = true }, &out);
        defer base.destroyBufferWithAllocator(alloc.allocator(), out);
        if (status == .out_of_memory) {
            failures += 1;
            try t.expectEqual(null, out);
            try t.expect(!server.grpc_reader.?.done);
        } else {
            try t.expectEqual(.ok, status);
            try t.expect(server.grpc_reader.?.done);
            try t.expect(failures > 0);
            return;
        }
    }
    return error.NoSuccessfulAllocation;
}

test "growing dispatch response allocation preserves uncertainty and the owned confirmation" {
    const t = std.testing;
    var wire: s.client.Client = undefined;
    var host = try s.GenServer.init(.{ .client = &wire, .realm = 72, .principal = 65536, .pid = 2, .generation = 3, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8)) }, "data");
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
