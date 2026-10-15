//! Versioned, synchronous C boundary. Host adapters schedule blocking calls.
//! Every owned object has one explicit release operation; no borrowed Zig data.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const allocator = std.heap.page_allocator;
pub const version: u32 = 1;
pub const minimum_stack_bytes = 8 * 1024 * 1024;
pub const host = @import("Host.zig");

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
pub const Kind = enum(u32) {
    growing_command = 6,
    growing_query = 7,
};
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
    growing_command: p.Growth.SignedRequest,
    growing_query: p.Growth.SignedQuery,
};
const OperationImpl = struct { signed: Signed };
/// Shared saved-operation representation, also emitted by Station handles.
pub const Frozen = struct { version: u32 = version, definition: p.Growth.Definition, operation: Signed };
/// Descriptive local metadata, not evidence of authenticity or admission.
pub const Metadata = struct {
    version: u32 = 1,
    identity: []const u8,
    kind: Kind,
    profile: enum { native_v1 },
    realm: u64,
    principal: u64,
    sequence: ?[]const u8 = null,
    command: ?[]const u8 = null,
    destination: ?u64 = null,
};
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
    return bufferWithAllocator(allocator, value, out);
}
fn bufferWithAllocator(alloc: std.mem.Allocator, value: anytype, out: *?*Buffer) !void {
    const result = try alloc.create(BufferImpl);
    errdefer alloc.destroy(result);
    result.bytes = try std.json.Stringify.valueAlloc(alloc, value, .{});
    out.* = @ptrCast(result);
}
/// Bounded JSON access shared by foreign SDK implementation layers. This does
/// not interpret an operation or substitute for protocol validation.
pub fn extractJson(alloc: std.mem.Allocator, bytes: []const u8, path: []const u8, format: u32) ![]u8 {
    if (bytes.len == 0 or bytes.len > p.max_body or path.len > 128 or format > 1) return error.InvalidArgument;
    const parsed = try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{});
    defer parsed.deinit();
    var value = parsed.value;
    if (path.len != 0) {
        if (path[0] != '/') return error.InvalidArgument;
        var parts = std.mem.splitScalar(u8, path[1..], '/');
        while (parts.next()) |part| value = switch (value) {
            .object => |object| object.get(part) orelse return error.InvalidArgument,
            .array => |array| blk: {
                const index = std.fmt.parseInt(usize, part, 10) catch return error.InvalidArgument;
                if (index >= array.items.len) return error.InvalidArgument;
                break :blk array.items[index];
            },
            else => return error.InvalidArgument,
        };
    }
    if (format == 0) return std.json.Stringify.valueAlloc(alloc, value, .{});
    if (value != .string) return error.InvalidArgument;
    return alloc.dupe(u8, value.string);
}
fn validate(signed: Signed) !void {
    switch (signed) {
        .growing_command => |s| try p.Growth.validate(s.request),
        .growing_query => |s| try p.Growth.validateQuery(s.query),
    }
}

/// This declaration is also the source of generated C prototypes. All integer
/// tags enter as integers so malformed foreign enum values are checked safely.
pub const Api = struct {
    /// Shared explicit administration lifecycle. The returned JSON buffer owns
    /// all strings. Only action.submit dispatches; failures include a bounded
    /// diagnostic and never replace an uncertain saved record.
    pub fn transit_authorization_apply(client: *Client, seed: *const [32]u8, connection: [*]const u8, connection_len: usize, action: [*]const u8, action_len: usize, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        if (connection_len == 0 or connection_len > 4096 or action_len == 0 or action_len > wire.AuthorizationBridge.max_input_bytes) return .invalid_argument;
        const handle = cast(ClientImpl, client);
        if (handle.busy.swap(true, .acquire)) return .busy;
        defer handle.busy.store(false, .release);
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const config = p.Json.parseFromSlice(wire.AuthorizationBridge.Connection, arena.allocator(), connection[0..connection_len]) catch |err| return fail(err);
        defer config.deinit();
        const input = wire.AuthorizationBridge.parse(arena.allocator(), action[0..action_len]) catch |err| return fail(err);
        defer input.deinit();
        var key = p.Ed25519.KeyPair.generateDeterministic(seed.*) catch |err| return fail(err);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        return authorizationExchange(allocator, arena.allocator(), &handle.client, key, config.value, input.value, out);
    }
    /// Validate owned diagnostic JSON using the shared contract, including
    /// cross-field outcome/action rules. No handle, authority read or dispatch.
    pub fn transit_diagnostic_validate(json: [*]const u8, len: usize) callconv(.c) u32 {
        if (len == 0 or len > p.Diagnostic.max_json_bytes) return 0;
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const value = std.json.parseFromSlice(p.Diagnostic, arena.allocator(), json[0..len], .{}) catch return 0;
        value.value.validate() catch return 0;
        return 1;
    }

    /// Compare the complete contract definition before constructing handles.
    pub fn transit_client_abi_definition_matches(definition: [*]const u8, len: usize) callconv(.c) u32 {
        const expected = @tagName(p.Growth.current_definition);
        return @intFromBool(len == expected.len and std.mem.eql(u8, definition[0..len], expected));
    }
    pub fn transit_client_abi_version() callconv(.c) u32 {
        return version;
    }
    /// Local library support only; authority capabilities still require a read.
    pub fn transit_client_supports_kind(kind_number: u32) callconv(.c) u32 {
        return @intFromBool(std.enums.fromInt(Kind, kind_number) != null);
    }
    /// Implementation helper for independent C/C++ SDKs. Format 0 owns selected
    /// JSON; format 1 owns raw string bytes. Callers release the returned buffer.
    pub fn transit_json_extract(json: [*]const u8, len: usize, path: [*]const u8, path_len: usize, format: u32, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const bytes = extractJson(allocator, json[0..len], path[0..path_len], format) catch |err| return fail(err);
        const result = allocator.create(BufferImpl) catch {
            allocator.free(bytes);
            return .out_of_memory;
        };
        result.* = .{ .bytes = bytes };
        out.* = @ptrCast(result);
        return .ok;
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
            .growing_command => .{ .growing_command = p.Growth.sign(parse(p.Growth.Request, bytes) catch |err| return fail(err), pair) catch |err| return fail(err) },
            .growing_query => .{ .growing_query = p.Growth.signQuery(parse(p.Growth.Query, bytes) catch |err| return fail(err), pair) catch |err| return fail(err) },
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
        buffer(Frozen{ .definition = p.Growth.current_definition, .operation = handle.signed }, out) catch |err| return fail(err);
        return .ok;
    }
    /// The shared implementation classifies imported requests. Identity is the
    /// SHA-256 of exact canonical exported bytes, not an authority capability.
    pub fn transit_operation_metadata(operation: *const Operation, out: *?*Buffer) callconv(.c) Status {
        out.* = null;
        const handle: *const OperationImpl = @ptrCast(@alignCast(operation));
        const bytes = std.json.Stringify.valueAlloc(allocator, Frozen{ .definition = p.Growth.current_definition, .operation = handle.signed }, .{}) catch return .out_of_memory;
        defer allocator.free(bytes);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        const identity = std.fmt.bytesToHex(digest, .lower);
        var sequence: [20]u8 = undefined;
        var info: Metadata = .{ .identity = &identity, .kind = handle.signed, .profile = .native_v1, .realm = 0, .principal = 0 };
        switch (handle.signed) {
            .growing_command => |signed| {
                const request = signed.request;
                info.realm = request.realm;
                info.principal = request.principal;
                info.sequence = std.fmt.bufPrint(&sequence, "{d}", .{request.sequence}) catch unreachable;
                info.command = @tagName(request.command);
                if (request.command == .send) info.destination = request.command.send.pid;
            },
            inline else => |signed| {
                info.realm = signed.query.realm;
                info.principal = signed.query.principal;
            },
        }
        buffer(info, out) catch |err| return fail(err);
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
        return exchange(allocator, &handle.client, pending.signed, out);
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

fn authorizationBuffer(alloc: std.mem.Allocator, value: anytype, out: *?*Buffer) !void {
    const result = try alloc.create(BufferImpl);
    errdefer alloc.destroy(result);
    result.bytes = try p.Json.valueAlloc(alloc, value);
    out.* = @ptrCast(result);
}
fn authorizationExchange(alloc: std.mem.Allocator, scratch: std.mem.Allocator, client: anytype, key: p.Ed25519.KeyPair, connection: wire.AuthorizationBridge.Connection, action: wire.AuthorizationBridge.Action, out: *?*Buffer) Status {
    const bridge = wire.AuthorizationBridge;
    client.last_rejection = null;
    const identity = bridge.identity(scratch, connection, action) catch null;
    var dispatched = false;
    const result = bridge.apply(scratch, client, key, connection, action, &dispatched) catch |err| {
        const detail = bridge.diagnostic(action, err, dispatched, identity, client.last_rejection) catch return if (dispatched) .uncertain else fail(err);
        authorizationBuffer(alloc, .{ .diagnostic = detail }, out) catch {};
        if (err == error.AccessDenied) return .denied;
        if (err == error.Rejected) return .rejected;
        if (err == error.Conflict or err == error.StaleAuthorizationRevision) return .conflict;
        if (dispatched) return .uncertain;
        if (wire.Client.unavailable(err)) return .unavailable;
        return fail(err);
    };
    authorizationBuffer(alloc, result, out) catch |err| {
        // A receipt can be lost while allocating its foreign representation.
        // Retrying uses the same saved command; no new step was prepared here.
        if (dispatched) {
            const detail = bridge.diagnostic(action, err, true, identity, null) catch return .uncertain;
            authorizationBuffer(alloc, .{ .diagnostic = detail }, out) catch {};
            return .uncertain;
        }
        return fail(err);
    };
    return .ok;
}

fn exchange(alloc: std.mem.Allocator, client: anytype, signed: Signed, out: *?*Buffer) Status {
    call(alloc, client, signed, out) catch |err| {
        // Allocation failure while exposing an accepted receipt cannot turn
        // that durable mutation into rejection. No transport retry occurs here.
        bufferWithAllocator(alloc, .{ .err = if (client.last_rejection) |rejection| @tagName(rejection) else @errorName(err) }, out) catch {};
        return switch (err) {
            error.AccessDenied => .denied,
            error.Rejected => .rejected,
            error.Conflict => .conflict,
            else => if (signed == .growing_command) .uncertain else if (err == error.InvalidAuthorityResponse) .invalid_response else .unavailable,
        };
    };
    return .ok;
}

fn call(alloc: std.mem.Allocator, client: anytype, signed: Signed, out: *?*Buffer) !void {
    switch (signed) {
        .growing_command => |s| try bufferWithAllocator(alloc, try client.submit(s), out),
        .growing_query => |s| try bufferWithAllocator(alloc, try client.call(p.Growth.Response, "/v1/query", s), out),
    }
}

test "independent JSON access bounds and owned string bytes" {
    const document = "{\"items\":[{\"value\":\"a\\u0000b\"}],\"wide\":18446744073709551615}";
    const bytes = try extractJson(std.testing.allocator, document, "/items/0/value", 1);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, "a\x00b", bytes);
    const wide = try extractJson(std.testing.allocator, document, "/wide", 0);
    defer std.testing.allocator.free(wide);
    try std.testing.expectEqualSlices(u8, "18446744073709551615", wide);
    try std.testing.expectError(error.InvalidArgument, extractJson(std.testing.allocator, document, "/items/1", 0));
    try std.testing.expectError(error.InvalidArgument, extractJson(std.testing.allocator, document, "/wide", 1));
    try std.testing.expectError(error.InvalidArgument, extractJson(std.testing.allocator, document, "missing-slash", 0));
    try std.testing.expectError(error.InvalidArgument, extractJson(std.testing.allocator, document, "", 2));
    try std.testing.checkAllAllocationFailures(std.testing.allocator, struct {
        fn run(alloc: std.mem.Allocator) !void {
            const result = try extractJson(alloc, document, "/items/0/value", 1);
            defer alloc.free(result);
        }
    }.run, .{});
}

test "saved v1 requests reject missing or foreign definitions without changing retry bytes" {
    const t = std.testing;
    const signed: Signed = .{ .growing_command = try p.Growth.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, try p.Ed25519.KeyPair.generateDeterministic(@splat(7))) };
    const canonical = try std.json.Stringify.valueAlloc(t.allocator, Frozen{ .definition = p.Growth.current_definition, .operation = signed }, .{});
    defer t.allocator.free(canonical);
    var out: ?*Operation = null;
    try t.expectEqual(.ok, Api.transit_operation_import(canonical.ptr, canonical.len, &out));
    Api.transit_operation_destroy(out);
    const parsed = try std.json.parseFromSlice(std.json.Value, t.allocator, canonical, .{});
    defer parsed.deinit();
    var frozen = parsed.value;
    frozen.object.getPtr("definition").?.* = .{ .string = "previous-v1-definition" };
    const foreign = try std.json.Stringify.valueAlloc(t.allocator, frozen, .{});
    defer t.allocator.free(foreign);
    const preserved = try t.allocator.dupe(u8, foreign);
    defer t.allocator.free(preserved);
    try t.expectEqual(.invalid_argument, Api.transit_operation_import(foreign.ptr, foreign.len, &out));
    try t.expectEqual(@as(?*Operation, null), out);
    try t.expectEqualSlices(u8, preserved, foreign);
    _ = frozen.object.swapRemove("definition");
    const missing = try std.json.Stringify.valueAlloc(t.allocator, frozen, .{});
    defer t.allocator.free(missing);
    try t.expectEqual(.invalid_argument, Api.transit_operation_import(missing.ptr, missing.len, &out));
    try t.expectEqual(@as(?*Operation, null), out);
}

test "every post-commit response allocation failure remains uncertain and releases buffers" {
    const t = std.testing;
    const Accepted = struct {
        last_rejection: ?p.ErrorCode = null,
        calls: usize = 0,
        fn submit(self: *@This(), _: p.Growth.SignedRequest) anyerror!p.Receipt {
            self.calls += 1;
            return .{ .position = 37 };
        }
        fn call(_: *@This(), comptime T: type, _: []const u8, _: anytype) anyerror!T {
            return error.UnexpectedRead;
        }
    };
    const cases = [_]Signed{
        .{ .growing_command = .{
            .request = .{ .realm = 42, .principal = 65536, .sequence = 1, .command = .{ .spawn = .{} } },
            .signature = @splat(0),
        } },
    };
    for (cases) |signed| {
        var failures: usize = 0;
        var completed = false;
        for (0..32) |index| {
            var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
            var accepted: Accepted = .{};
            var out: ?*Buffer = null;
            const result = exchange(failing.allocator(), &accepted, signed, &out);
            defer if (out) |pointer| {
                const owned = cast(BufferImpl, pointer);
                failing.allocator().free(owned.bytes);
                failing.allocator().destroy(owned);
            };
            try t.expectEqual(@as(usize, 1), accepted.calls);
            if (failing.has_induced_failure) {
                failures += 1;
                try t.expectEqual(.uncertain, result);
            } else {
                try t.expectEqual(.ok, result);
                try t.expectEqualStrings("{\"position\":37}", cast(BufferImpl, out.?).bytes);
                try t.expect(failures >= 2);
                completed = true;
                break;
            }
        }
        try t.expect(completed);
    }
}

test "administration receipt allocation failures preserve uncertain saved identity" {
    const t = std.testing;
    const Accepted = struct {
        last_rejection: ?p.ErrorCode = null,
        calls: usize = 0,
        pub fn submit(self: *@This(), _: p.Growth.SignedRequest) !p.Receipt {
            self.calls += 1;
            return .{ .position = 37 };
        }
        pub fn query(_: *@This(), _: p.Growth.Query, _: p.Ed25519.KeyPair) !p.Growth.Response {
            return error.UnexpectedRead;
        }
    };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const envelope: wire.AuthorizationChange.Envelope = .{ .public_key = key.public_key.toBytes(), .signed = try p.Growth.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .authorization = .{ .begin = .{ .expected_revision = 0, .role = null, .action = .{ .create_role = .{ .name = try p.Value.init("reader") } } } } } }, key) };
    const saved = try (wire.AuthorizationChange.Record{ .definition = p.Growth.current_definition, .begin = envelope, .change = null, .pending = envelope }).save(t.allocator);
    defer t.allocator.free(saved);
    const connection: wire.AuthorizationBridge.Connection = .{ .definition = p.Growth.current_definition, .realm = 42, .principal = 0 };
    var failures: usize = 0;
    var complete = false;
    for (0..64) |index| {
        var scratch = std.heap.ArenaAllocator.init(t.allocator);
        defer scratch.deinit();
        var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = index });
        var accepted: Accepted = .{};
        var out: ?*Buffer = null;
        const status = authorizationExchange(failing.allocator(), scratch.allocator(), &accepted, key, connection, .{ .submit = saved }, &out);
        defer if (out) |pointer| {
            const owned = cast(BufferImpl, pointer);
            failing.allocator().free(owned.bytes);
            failing.allocator().destroy(owned);
        };
        try t.expectEqual(@as(usize, 1), accepted.calls);
        if (failing.has_induced_failure) {
            failures += 1;
            try t.expectEqual(.uncertain, status);
        } else {
            try t.expectEqual(.ok, status);
            try t.expect(out != null);
            complete = true;
            break;
        }
        try t.expect(std.meta.eql(envelope, (try wire.AuthorizationChange.Record.restore(scratch.allocator(), saved)).pending.?));
    }
    try t.expect(complete and failures > 0);
}

test "diagnostic validation is bounded and rejects unsafe outcome substitutions" {
    const t = std.testing;
    var diagnostic = try p.Diagnostic.init("sql.example", .binding, .bind, .not_submitted, .local_before_dispatch, "Caller input cannot be bound.");
    try diagnostic.action(.correct_input);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, diagnostic, .{});
    defer t.allocator.free(bytes);
    try t.expectEqual(@as(u32, 1), Api.transit_diagnostic_validate(bytes.ptr, bytes.len));
    const unknown = try std.mem.replaceOwned(u8, t.allocator, bytes, "not_submitted", "unknown");
    defer t.allocator.free(unknown);
    try t.expectEqual(@as(u32, 0), Api.transit_diagnostic_validate(unknown.ptr, unknown.len));
    const foreign = try std.mem.replaceOwned(u8, t.allocator, bytes, @tagName(p.Growth.current_definition), "foreign");
    defer t.allocator.free(foreign);
    try t.expectEqual(@as(u32, 0), Api.transit_diagnostic_validate(foreign.ptr, foreign.len));
    try t.expectEqual(@as(u32, 0), Api.transit_diagnostic_validate(bytes.ptr, p.Diagnostic.max_json_bytes + 1));
}

test "transport denial remains uncertain for commands and unavailable for reads" {
    const t = std.testing;
    const Denied = struct {
        last_rejection: ?p.ErrorCode = null,
        fn submit(_: *@This(), _: p.Growth.SignedRequest) anyerror!p.Receipt {
            return error.AuthorityTransportDenied;
        }
        fn call(_: *@This(), comptime T: type, _: []const u8, _: anytype) anyerror!T {
            return error.AuthorityTransportDenied;
        }
    };
    const cases = [_]Signed{
        .{ .growing_command = .{ .request = .{ .realm = 42, .principal = 65536, .sequence = 1, .command = .{ .spawn = .{} } }, .signature = @splat(0) } },
        .{ .growing_query = .{ .query = .{ .realm = 42, .principal = 65536, .kind = .capabilities }, .signature = @splat(0) } },
    };
    for (cases) |signed| {
        var denied: Denied = .{};
        var out: ?*Buffer = null;
        const status = exchange(t.allocator, &denied, signed, &out);
        defer if (out) |pointer| {
            const owned = cast(BufferImpl, pointer);
            t.allocator.free(owned.bytes);
            t.allocator.destroy(owned);
        };
        try t.expectEqual(if (signed == .growing_command) Status.uncertain else Status.unavailable, status);
        try t.expectEqualStrings("{\"err\":\"AuthorityTransportDenied\"}", cast(BufferImpl, out.?).bytes);
    }
}
