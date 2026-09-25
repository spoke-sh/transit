//! Station v1 C exports. A handle owns the same GenServer as native Zig callers.
const std = @import("std");
const s = @import("transit_station");
const p = s.protocol;
pub const actions = @import("Actions.zig");
pub const host = @import("HostProtocol.zig");
pub const version: u32 = 1;
pub const Status = enum(u32) { ok = 0, invalid_argument = 1, out_of_memory = 2, rejected = 3, denied = 4, conflict = 5, uncertain = 6, unavailable = 7, invalid_response = 8, busy = 9, incompatible_version = 10, stale_activation = 11, blocked = 12, not_ready = 13, budget_exceeded = 14 };
pub const Server = opaque {};
pub const Buffer = opaque {};
pub const Config = struct { realm: u64, principal: u8, pid: u64, generation: u64, association: []const u8 = "data", timeout_ms: u32 = 5000 };
pub const Event = struct {
    event: s.GenServer.Poll,
    pid: u64,
    generation: u64,
    initializing: bool = false,
    input: ?struct { position: u64, origin: p.Origin, kind: s.Frame.Kind, correlation: []const u8, payload: p.Value } = null,
    resource: ?u64 = null,
    resource_revision: ?u64 = null,
};
const allocator = std.heap.page_allocator;
const ServerImpl = struct { threaded: std.Io.Threaded, client: s.client.Client, url: []u8, behavior: s.GenServer, busy: std.atomic.Value(bool) = .init(false), event: ?s.GenServer.Poll = null };
const BufferImpl = struct { bytes: []u8 };
fn cast(comptime T: type, pointer: anytype) *T {
    return @ptrCast(@alignCast(@constCast(pointer)));
}
fn output(value: anytype, out: *?*Buffer) !void {
    const buffer = try allocator.create(BufferImpl);
    errdefer allocator.destroy(buffer);
    buffer.bytes = try std.json.Stringify.valueAlloc(allocator, value, .{});
    out.* = @ptrCast(buffer);
}
fn status(err: anyerror) Status {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        error.AccessDenied => .denied,
        error.Rejected => .rejected,
        error.Conflict => .conflict,
        error.StaleActivation => .stale_activation,
        error.BlockedProcess => .blocked,
        error.NoPreparedTurn => .not_ready,
        error.InvalidAuthorityResponse => .invalid_response,
        error.MutationBudgetExceeded, error.OutputBudgetExceeded, error.StateCapacityExceeded, error.ChildBudgetExceeded, error.QueryBudgetExceeded, error.WriteFailed => .budget_exceeded,
        else => .invalid_argument,
    };
}
fn failure(err: anyerror, out: *?*Buffer) Status {
    output(.{ .err = @errorName(err) }, out) catch {};
    return status(err);
}
fn lock(server: *ServerImpl) bool {
    return !server.busy.swap(true, .acquire);
}
pub fn observe(pointer: *Server, observer: *s.client.observability.telemetry.Runtime) void {
    cast(ServerImpl, pointer).client.observer = observer;
}

pub const Api = struct {
    pub fn station_abi_version() callconv(.c) u32 {
        return version;
    }
    /// Shared JSON access for C/C++ hosts without another parser dependency.
    /// format 0 returns JSON; format 1 returns the selected string's raw bytes.
    pub fn station_json_extract(json: [*]const u8, len: usize, path: [*]const u8, path_len: usize, format: u32, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        if (len == 0 or len > p.max_body or path_len > 128 or format > 1) return .invalid_argument;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json[0..len], .{}) catch |err| return failure(err, out);
        defer parsed.deinit();
        var value = parsed.value;
        if (path_len != 0) {
            if (path[0] != '/') return .invalid_argument;
            var parts = std.mem.splitScalar(u8, path[1..path_len], '/');
            while (parts.next()) |part| value = switch (value) {
                .object => |object| object.get(part) orelse return .invalid_argument,
                .array => |array| blk: {
                    const index = std.fmt.parseInt(usize, part, 10) catch return .invalid_argument;
                    if (index >= array.items.len) return .invalid_argument;
                    break :blk array.items[index];
                },
                else => return .invalid_argument,
            };
        }
        if (format == 0) {
            output(value, out) catch |err| return status(err);
        } else {
            if (value != .string) return .invalid_argument;
            const buffer = allocator.create(BufferImpl) catch return .out_of_memory;
            buffer.bytes = allocator.dupe(u8, value.string) catch {
                allocator.destroy(buffer);
                return .out_of_memory;
            };
            out.* = @ptrCast(buffer);
        }
        return .ok;
    }
    pub fn station_frame_encode(kind: u32, correlation: u64, payload: [*]const u8, len: usize, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const frame: s.Frame = .{ .kind = std.enums.fromInt(s.Frame.Kind, kind) orelse return .invalid_argument, .correlation = correlation, .payload = p.Value.init(payload[0..len]) catch |err| return failure(err, out) };
        const value = frame.encode() catch |err| return failure(err, out);
        output(value, out) catch |err| return status(err);
        return .ok;
    }
    pub fn station_server_create(abi_version: u32, url: [*]const u8, url_len: usize, seed: *const [32]u8, config: [*]const u8, config_len: usize, out: *?*Server) callconv(.c) Status {
        out.* = null;
        if (abi_version != version) return .incompatible_version;
        if (url_len == 0 or url_len > 2048 or config_len == 0 or config_len > 8192) return .invalid_argument;
        const uri = std.Uri.parse(url[0..url_len]) catch return .invalid_argument;
        if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return .invalid_argument;
        const parsed = std.json.parseFromSlice(Config, allocator, config[0..config_len], .{}) catch |err| return status(err);
        defer parsed.deinit();
        const c = parsed.value;
        if (c.realm == 0 or c.realm > p.max_counter or c.principal == 0 or c.principal >= p.max_principals or c.pid == 0 or c.pid > p.max_counter or c.generation == 0 or c.generation > p.max_counter or c.timeout_ms == 0 or c.timeout_ms > 60000) return .invalid_argument;
        const server = allocator.create(ServerImpl) catch return .out_of_memory;
        server.url = allocator.dupe(u8, url[0..url_len]) catch {
            allocator.destroy(server);
            return .out_of_memory;
        };
        server.threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) });
        server.client = s.client.Client.init(allocator, server.threaded.io(), server.url);
        server.client.timeout_ms = c.timeout_ms;
        server.busy = .init(false);
        server.event = null;
        var key = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch unreachable;
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        server.behavior = s.GenServer.init(.{ .client = &server.client, .realm = c.realm, .principal = c.principal, .pid = c.pid, .generation = c.generation, .key = key }, c.association) catch |err| {
            server.client.deinit();
            server.threaded.deinit();
            allocator.free(server.url);
            allocator.destroy(server);
            return status(err);
        };
        out.* = @ptrCast(server);
        return .ok;
    }
    pub fn station_server_destroy(pointer: ?*Server) callconv(.c) void {
        const server = cast(ServerImpl, pointer orelse return);
        std.crypto.secureZero(u8, std.mem.asBytes(&server.behavior.session.key));
        server.client.deinit();
        server.threaded.deinit();
        allocator.free(server.url);
        allocator.destroy(server);
    }
    pub fn station_server_next(pointer: *Server, deadline_ms: u64, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const server = cast(ServerImpl, pointer);
        if (!lock(server)) return .busy;
        defer server.busy.store(false, .release);
        if (server.event == null) server.event = server.behavior.poll(deadline_ms) catch |err| {
            output(.{ .err = @errorName(err), .protocol_error = server.client.last_rejection }, out) catch {};
            if (server.behavior.pending != null and err != error.AccessDenied and err != error.Rejected and err != error.Conflict) return .uncertain;
            const result = status(err);
            return if (result == .invalid_argument) .unavailable else result;
        };
        var event: Event = .{ .event = server.event.?, .pid = server.behavior.session.pid, .generation = server.behavior.session.generation };
        var correlation: [20]u8 = undefined;
        if (server.behavior.ready) |turn| {
            const frame = s.Frame.decode(turn.delivery.input.value) catch |err| return failure(err, out);
            event.initializing = server.behavior.initializing;
            event.input = .{ .position = turn.delivery.input.position, .origin = turn.delivery.input.origin, .kind = frame.kind, .correlation = std.fmt.bufPrint(&correlation, "{d}", .{frame.correlation}) catch unreachable, .payload = frame.payload };
            event.resource = turn.view.resource;
            event.resource_revision = turn.view.revision;
        }
        output(event, out) catch |err| return status(err); // keep event until copied
        server.event = null;
        return .ok;
    }
    pub fn station_server_apply(pointer: *Server, json: [*]const u8, len: usize, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        if (len == 0 or len > p.max_body) return .invalid_argument;
        const server = cast(ServerImpl, pointer);
        if (!lock(server)) return .busy;
        defer server.busy.store(false, .release);
        const turn = if (server.behavior.ready) |*value| value else return .not_ready;
        const parsed = std.json.parseFromSlice(actions.Action, allocator, json[0..len], .{}) catch |err| return failure(err, out);
        defer parsed.deinit();
        const before = turn.decision;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const result = actions.apply(arena.allocator(), turn, parsed.value) catch |err| {
            turn.decision = before;
            return failure(err, out);
        };
        output(result, out) catch |err| {
            turn.decision = before;
            return status(err);
        };
        return .ok;
    }
    pub fn station_server_finish(pointer: *Server, failed: u32) callconv(.c) Status {
        if (failed > 1) return .invalid_argument;
        const server = cast(ServerImpl, pointer);
        if (!lock(server)) return .busy;
        defer server.busy.store(false, .release);
        server.behavior.finish(if (failed == 1) error.ForeignHandlerFailure else null) catch |err| return status(err);
        server.event = null;
        return .ok;
    }
    pub fn station_server_pending(pointer: *Server, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const server = cast(ServerImpl, pointer);
        if (!lock(server)) return .busy;
        defer server.busy.store(false, .release);
        const pending = server.behavior.pending orelse return .not_ready;
        // Exactly the raw client ABI's frozen command envelope; no private seed.
        output(.{ .version = @as(u32, 1), .operation = .{ .command = pending.signed } }, out) catch |err| return status(err);
        return .ok;
    }
    pub fn station_buffer_data(pointer: *const Buffer) callconv(.c) [*]const u8 {
        return cast(BufferImpl, pointer).bytes.ptr;
    }
    pub fn station_arrow_cell(bytes: [*]const u8, len: usize, row: u32, column: u32, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const result = actions.arrowCell(arena.allocator(), bytes[0..len], row, column) catch |err| return failure(err, out);
        output(result, out) catch |err| return status(err);
        return .ok;
    }
    pub fn station_buffer_size(pointer: *const Buffer) callconv(.c) usize {
        return cast(BufferImpl, pointer).bytes.len;
    }
    pub fn station_buffer_destroy(pointer: ?*Buffer) callconv(.c) void {
        const buffer = cast(BufferImpl, pointer orelse return);
        allocator.free(buffer.bytes);
        allocator.destroy(buffer);
    }
};
