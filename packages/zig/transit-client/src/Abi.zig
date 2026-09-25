//! Versioned, synchronous C boundary. Host adapters schedule blocking calls.
//! Every owned object has one explicit release operation; no borrowed Zig data.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const allocator = std.heap.page_allocator;
pub const version: u32 = 1;

pub const Status = enum(u32) {
    ok = 0,
    invalid_argument = 1,
    out_of_memory = 2,
    rejected = 3,
    denied = 4,
    conflict = 5,
    uncertain = 6,
    unavailable = 7,
    invalid_response = 8,
    busy = 9,
    incompatible_version = 10,
};
pub const Kind = enum(u32) { command = 1, view = 2, state = 3, inspection = 4, delivery = 5 };
pub const Client = opaque {};
pub const Operation = opaque {};
pub const Buffer = opaque {};

const ClientImpl = struct {
    threaded: std.Io.Threaded,
    client: wire.Client,
    url: []u8,
    busy: std.atomic.Value(bool) = .init(false),
};
const Signed = union(Kind) {
    command: p.SignedRequest,
    view: p.SignedRequest,
    state: p.State.SignedQuery,
    inspection: p.Inspection.SignedQuery,
    delivery: p.Delivery.SignedQuery,
};
const OperationImpl = struct { signed: Signed };
const Frozen = struct { version: u32 = version, operation: Signed };
const BufferImpl = struct { bytes: []u8 };
pub fn observe(pointer: *Client, observer: *wire.observability.telemetry.Runtime) void {
    cast(ClientImpl, pointer).client.observer = observer;
}

fn cast(comptime T: type, pointer: anytype) *T {
    return @ptrCast(@alignCast(pointer));
}
fn parse(comptime T: type, bytes: []const u8) !T {
    if (bytes.len == 0 or bytes.len > p.max_body) return error.InvalidArgument;
    const parsed = try std.json.parseFromSlice(T, allocator, bytes, .{});
    defer parsed.deinit();
    return parsed.value;
}
fn fail(err: anyerror) Status {
    return if (err == error.OutOfMemory) .out_of_memory else .invalid_argument;
}
fn buffer(value: anytype, out: *?*Buffer) !void {
    const result = try allocator.create(BufferImpl);
    errdefer allocator.destroy(result);
    result.bytes = try std.json.Stringify.valueAlloc(allocator, value, .{});
    out.* = @ptrCast(result);
}
fn validate(signed: Signed) !void {
    switch (signed) {
        .command => |s| {
            if (s.request.command == .inspect) return error.InvalidArgument;
            try p.validate(s.request);
        },
        .view => |s| {
            if (s.request.command != .inspect or s.request.sequence != 0) return error.InvalidArgument;
            try p.validate(s.request);
        },
        .state => |s| try p.State.validateQuery(s.query),
        .inspection => |s| try p.Inspection.validate(s.query),
        .delivery => |s| try p.Delivery.validate(s.query),
    }
}

/// This declaration is also the source of generated C prototypes. All integer
/// tags enter as integers so malformed foreign enum values are checked safely.
pub const Api = struct {
    pub fn transit_client_abi_version() callconv(.c) u32 {
        return version;
    }
    pub fn transit_client_create(abi_version: u32, url: [*]const u8, url_len: usize, timeout_ms: u32, out: *?*Client) callconv(.c) Status {
        out.* = null;
        if (abi_version != version) return .incompatible_version;
        if (url_len == 0 or url_len > 2048 or timeout_ms == 0 or timeout_ms > 60_000) return .invalid_argument;
        const text = url[0..url_len];
        const uri = std.Uri.parse(text) catch return .invalid_argument;
        if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return .invalid_argument;
        const owned_url = allocator.dupe(u8, text) catch return .out_of_memory;
        const handle = allocator.create(ClientImpl) catch {
            allocator.free(owned_url);
            return .out_of_memory;
        };
        handle.* = .{
            .url = owned_url,
            .threaded = .init(allocator, .{ .async_limit = .limited(2), .concurrent_limit = .limited(2) }),
            .client = undefined,
        };
        handle.client = wire.Client.init(allocator, handle.threaded.io(), handle.url);
        handle.client.timeout_ms = timeout_ms;
        out.* = @ptrCast(handle);
        return .ok;
    }
    /// The host must join all calls before destroying their client.
    pub fn transit_client_destroy(client: ?*Client) callconv(.c) void {
        const handle = cast(ClientImpl, client orelse return);
        handle.client.deinit();
        handle.threaded.deinit();
        allocator.free(handle.url);
        allocator.destroy(handle);
    }
    pub fn transit_operation_prepare(kind_number: u32, seed: *const [32]u8, json: [*]const u8, json_len: usize, out: *?*Operation) callconv(.c) Status {
        out.* = null;
        const kind = std.enums.fromInt(Kind, kind_number) orelse return .invalid_argument;
        if (json_len == 0 or json_len > p.max_body) return .invalid_argument;
        var pair = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch |err| return fail(err);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&pair));
        const bytes = json[0..json_len];
        const signed: Signed = switch (kind) {
            .command, .view => blk: {
                const request = parse(p.Request, bytes) catch |err| return fail(err);
                const s = p.sign(request, pair) catch |err| return fail(err);
                break :blk if (kind == .command) .{ .command = s } else .{ .view = s };
            },
            .state => .{ .state = p.State.sign(parse(p.State.Query, bytes) catch |err| return fail(err), pair) catch |err| return fail(err) },
            .inspection => .{ .inspection = p.Inspection.sign(parse(p.Inspection.Query, bytes) catch |err| return fail(err), pair) catch |err| return fail(err) },
            .delivery => .{ .delivery = p.Delivery.sign(parse(p.Delivery.Query, bytes) catch |err| return fail(err), pair) catch |err| return fail(err) },
        };
        validate(signed) catch |err| return fail(err);
        const result = allocator.create(OperationImpl) catch return .out_of_memory;
        result.* = .{ .signed = signed };
        out.* = @ptrCast(result);
        return .ok;
    }
    /// Serialized retry material contains a signature, never a private seed.
    pub fn transit_operation_export(operation: *const Operation, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const handle: *const OperationImpl = @ptrCast(@alignCast(operation));
        buffer(Frozen{ .operation = handle.signed }, out) catch |err| return fail(err);
        return .ok;
    }
    /// Import validates shape and canonical encoding. The authority verifies the
    /// signature and current rights; possession of retry bytes confers neither.
    pub fn transit_operation_import(json: [*]const u8, json_len: usize, out: *?*Operation) callconv(.c) Status {
        out.* = null;
        if (json_len == 0 or json_len > p.max_body) return .invalid_argument;
        const frozen = parse(Frozen, json[0..json_len]) catch |err| return fail(err);
        if (frozen.version != version) return .incompatible_version;
        const signed = frozen.operation;
        validate(signed) catch |err| return fail(err);
        const canonical = std.json.Stringify.valueAlloc(allocator, frozen, .{}) catch return .out_of_memory;
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, canonical, json[0..json_len])) return .invalid_argument;
        const result = allocator.create(OperationImpl) catch return .out_of_memory;
        result.* = .{ .signed = signed };
        out.* = @ptrCast(result);
        return .ok;
    }
    pub fn transit_operation_destroy(operation: ?*Operation) callconv(.c) void {
        allocator.destroy(cast(OperationImpl, operation orelse return));
    }
    /// Blocking, deadline-bounded exchange; no automatic mutation retry. A
    /// returned error buffer describes the attempt, not an invented outcome.
    pub fn transit_client_call(client: *Client, operation: *const Operation, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const handle = cast(ClientImpl, client);
        if (handle.busy.swap(true, .acquire)) return .busy;
        defer handle.busy.store(false, .release);
        const pending: *const OperationImpl = @ptrCast(@alignCast(operation));
        call(&handle.client, pending.signed, out) catch |err| {
            // An allocation failure while encoding a successful receipt can
            // still follow a committed mutation. Preserve uncertainty.
            buffer(.{ .err = if (handle.client.last_rejection) |rejection| @tagName(rejection) else @errorName(err) }, out) catch {};
            return switch (err) {
                error.AccessDenied => .denied,
                error.Rejected => .rejected,
                error.Conflict => .conflict,
                else => if (pending.signed == .command) .uncertain else if (err == error.InvalidAuthorityResponse) .invalid_response else .unavailable,
            };
        };
        return .ok;
    }
    /// Borrowed until transit_buffer_destroy; length is authoritative (no NUL).
    pub fn transit_buffer_data(value: *const Buffer) callconv(.c) [*]const u8 {
        const handle: *const BufferImpl = @ptrCast(@alignCast(value));
        return handle.bytes.ptr;
    }
    pub fn transit_buffer_size(value: *const Buffer) callconv(.c) usize {
        const handle: *const BufferImpl = @ptrCast(@alignCast(value));
        return handle.bytes.len;
    }
    pub fn transit_buffer_destroy(value: ?*Buffer) callconv(.c) void {
        const handle = cast(BufferImpl, value orelse return);
        allocator.free(handle.bytes);
        allocator.destroy(handle);
    }
};

fn call(client: *wire.Client, signed: Signed, out: *?*Buffer) !void {
    switch (signed) {
        .command => |s| try buffer(try client.submit(s), out),
        .view => |s| try buffer(try client.call(p.View, "/v2/view", s), out),
        .state => |s| try buffer(try client.call(p.State.Page, "/v2/state", s), out),
        .inspection => |s| try buffer(try client.call(p.Inspection.Page, "/v2/inspect", s), out),
        .delivery => |s| try buffer(try client.call(p.Delivery.Status, "/v2/delivery", s), out),
    }
}
