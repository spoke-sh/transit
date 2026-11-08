//! Typed, in-process service invocation. The embedding host owns routing,
//! admission and current authority; a function pointer grants no data rights.
//! Request/response type tokens are checked before any erased pointer is used.
const std = @import("std");
const Self = @This();

context: *anyopaque,
invoke: *const fn (*anyopaque, *Invocation) anyerror!void,
/// Optional explicit route selection for a client whose configuration service
/// has a different owner. Unselected routes use its configured remote endpoint;
/// a selected local call never retries through that endpoint after failure.
routes: ?[]const []const u8 = null,
/// Optional cohosted publication hints. The embedding owner outlives every
/// waiter; callers join waits before releasing the endpoint. Hints confer no
/// authority and cannot replace discovery after process replacement.
changes: ?*Changes = null,
/// Optional host-owned backing allocator for owned responses. The returned
/// allocator must outlive every returned Parsed arena, including client close.
/// This admission hint grants no authority; invoke still validates the action.
response_allocator: ?*const fn (*anyopaque, []const u8, bool, std.mem.Allocator) std.mem.Allocator = null,

pub const Changes = struct {
    mutex: std.Io.Mutex = .init,
    condition: std.Io.Condition = .init,
    generation: u64 = 1,
    pub fn notify(self: *Changes, io: std.Io) void {
        self.mutex.lockUncancelable(io);
        defer self.mutex.unlock(io);
        self.generation +%= 1;
        self.condition.broadcast(io);
    }
    pub fn wait(self: *Changes, io: std.Io, previous: u64) !u64 {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        while (self.generation == previous) try self.condition.wait(io, &self.mutex);
        return self.generation;
    }
};
pub fn handles(self: Self, path: []const u8) bool {
    const routes = self.routes orelse return true;
    for (routes) |route| if (std.mem.eql(u8, route, path)) return true;
    return false;
}

pub const Invocation = struct {
    client: *@import("root.zig").Client,
    deadline: @import("Deadline.zig"),
    path: []const u8,
    allocator: std.mem.Allocator,
    input: *const anyopaque,
    input_type: *const u8,
    output: *anyopaque,
    output_type: *const u8,
    completed: bool = false,

    pub fn request(self: *const Invocation, comptime T: type) !T {
        return (try self.requestPtr(T)).*;
    }
    /// Borrows immutable input until invoke returns. The host must join all
    /// work before returning and cannot retain this pointer in a response.
    pub fn requestPtr(self: *const Invocation, comptime T: type) !*const T {
        if (self.input_type != token(T)) return error.InvalidLocalRequestType;
        return @ptrCast(@alignCast(self.input));
    }
    pub fn isRequest(self: *const Invocation, comptime T: type) bool {
        return self.input_type == token(T);
    }
    pub fn respond(self: *Invocation, value: anytype) !void {
        try self.deadline.check(self.client.http.io);
        const T = @TypeOf(value);
        if (self.output_type != token(T) or self.completed) return error.InvalidLocalResponseType;
        @as(*T, @ptrCast(@alignCast(self.output))).* = value;
        self.completed = true;
    }
};

fn token(comptime T: type) *const u8 {
    return &struct {
        const Type = T;
        var identity: u8 = 0;
    }.identity;
}

test "local refusal preserves public conflict evidence without remote fallback" {
    const t = std.testing;
    const Host = struct {
        calls: usize = 0,
        fn run(raw: *anyopaque, invocation: *Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return invocation.client.reject(.conflict, .Conflict);
        }
    };
    var host: Host = .{};
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    client.local = .{ .context = &host, .invoke = Host.run };
    try t.expectError(error.Conflict, client.callOwned(u64, "/local", .{}, .{}));
    try t.expectEqual(1, host.calls);
    try t.expect(client.contended(error.Conflict));
    try t.expectEqual(.Conflict, client.last_rejection.?);
}

test "local deadline joins its producer and frees partial owned output" {
    const t = std.testing;
    const Host = struct {
        joined: std.atomic.Value(bool) = .init(false),
        fn run(raw: *anyopaque, invocation: *Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            defer self.joined.store(true, .release);
            _ = try invocation.allocator.alloc(u8, 4096);
            try invocation.client.http.io.sleep(.fromSeconds(60), .awake);
        }
    };
    var host: Host = .{};
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    client.deadline = .init(t.io, 50, null);
    client.local = .{ .context = &host, .invoke = Host.run };
    try t.expectError(error.AuthorityTimeout, client.callOwned(u64, "/local", .{}, .{}));
    try t.expect(host.joined.load(.acquire));
}

test "hosted response backing remains charged after dispatch and client close" {
    const t = std.testing;
    const m = @import("transit_memory");
    const Host = struct {
        backing: m.Quota.Allocator,
        fail: bool = false,
        fn select(raw: *anyopaque, _: []const u8, _: bool, _: std.mem.Allocator) std.mem.Allocator {
            const self: *@This() = @ptrCast(@alignCast(raw));
            return self.backing.allocator();
        }
        fn run(raw: *anyopaque, invocation: *Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const bytes = try invocation.allocator.dupe(u8, "held response");
            if (self.fail) return error.TestAfterOutput;
            try invocation.respond(@as([]const u8, bytes));
        }
    };
    var quota: m.Quota = .{ .limit = 4096 };
    var host: Host = .{ .backing = .{ .parent = t.allocator, .quota = &quota } };
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    var closed = false;
    defer if (!closed) client.deinit();
    client.local = .{ .context = &host, .invoke = Host.run, .response_allocator = Host.select };
    // Deliberately bypass the host adapter: the same response does not charge
    // the owner. This control detects accidentally falling back to the client.
    client.local.?.response_allocator = null;
    const uncharged = try client.callOwned([]const u8, "/local", .{}, .{});
    try t.expectEqual(0, quota.used.load(.acquire));
    uncharged.deinit();
    client.local.?.response_allocator = Host.select;
    host.fail = true;
    try t.expectError(error.TestAfterOutput, client.callOwned([]const u8, "/local", .{}, .{}));
    try t.expectEqual(0, quota.used.load(.acquire));
    host.fail = false;
    const response = try client.callOwned([]const u8, "/local", .{}, .{});
    const held = quota.used.load(.acquire);
    try t.expect(held > response.value.len);
    client.deinit();
    closed = true;
    try t.expectEqual(held, quota.used.load(.acquire));
    try t.expectEqualStrings("held response", response.value);
    // The descriptor and all backing blocks release through the stable host.
    response.deinit();
    try t.expectEqual(0, quota.used.load(.acquire));
}

test "inherited expiry never dispatches or retains refusal evidence and the client is reusable" {
    const t = std.testing;
    const Host = struct {
        calls: usize = 0,
        expected: @import("Deadline.zig"),
        fn run(raw: *anyopaque, invocation: *Invocation) !void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            try t.expectEqual(self.expected, invocation.deadline);
            try invocation.respond(@as(u64, 7));
        }
    };
    var host: Host = .{ .expected = .init(t.io, 0, null) };
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    client.local = .{ .context = &host, .invoke = Host.run };
    client.deadline = host.expected;
    inline for (.{ false, true }) |owned| {
        client.last_status = .conflict;
        client.last_rejection = .Conflict;
        if (owned) {
            try t.expectError(error.AuthorityTimeout, client.callOwned(u64, "/local", .{}, .{}));
        } else {
            try t.expectError(error.AuthorityTimeout, client.call(u64, "/local", .{}));
        }
        try t.expectEqual(0, host.calls);
        try t.expect(client.last_status == null and client.last_rejection == null);
    }
    host.expected = .init(t.io, 1000, null);
    client.deadline = host.expected;
    try t.expectEqual(7, try client.call(u64, "/local", .{}));
    try t.expectEqual(1, host.calls);
    // Call completion does not replace a parent's cap with a newly started one.
    try t.expectEqual(host.expected, client.deadline.?);
}

/// Returned slices must belong to allocator. Neither the request nor any
/// temporary host workspace may escape through the response. No retry/fallback.
pub fn call(self: Self, client: *@import("root.zig").Client, allocator: std.mem.Allocator, comptime T: type, path: []const u8, input: anytype, deadline: @import("Deadline.zig")) !T {
    var result: T = undefined;
    var invocation: Invocation = .{ .client = client, .deadline = deadline, .allocator = allocator, .path = path, .input = @ptrCast(&input), .input_type = token(@TypeOf(input)), .output = @ptrCast(&result), .output_type = token(T) };
    try deadline.check(client.http.io);
    try self.invoke(self.context, &invocation);
    try deadline.check(client.http.io);
    if (!invocation.completed) return error.InvalidLocalResponseType;
    return result;
}

/// Copy a protocol value into caller-owned storage without encoding it. This
/// deliberately accepts only value trees, not arbitrary runtime object graphs.
/// The caller supplies an arena so partial failure is released as one unit.
pub fn clone(allocator: std.mem.Allocator, value: anytype) !@TypeOf(value) {
    var result = value;
    try ownSlices(allocator, &result);
    return result;
}

// Walk the selected value in place. Returning a whole union from every switch
// arm creates a stack temporary for each variant in Debug builds, even though
// only one variant is live. Large protocol envelopes can exhaust a worker's
// stack before any slice is copied. Scalar storage is already owned by result;
// only borrowed slices need allocation and recursive ownership here.
fn ownSlices(allocator: std.mem.Allocator, value: anytype) std.mem.Allocator.Error!void {
    const T = @typeInfo(@TypeOf(value)).pointer.child;
    switch (@typeInfo(T)) {
        .pointer => |info| {
            if (info.size != .slice or info.sentinel_ptr != null) @compileError("local response must be a value tree");
            const owned = try allocator.dupe(info.child, value.*);
            value.* = owned;
            switch (@typeInfo(info.child)) {
                .bool, .int, .float, .@"enum", .void => {},
                else => for (owned) |*item| try ownSlices(allocator, item),
            }
        },
        .optional => if (value.*) |*item| try ownSlices(allocator, item),
        .array => |info| switch (@typeInfo(info.child)) {
            .bool, .int, .float, .@"enum", .void => {},
            else => for (value) |*item| try ownSlices(allocator, item),
        },
        .@"struct" => |info| inline for (info.field_names) |name| try ownSlices(allocator, &@field(value.*, name)),
        .@"union" => switch (value.*) {
            inline else => |*item| try ownSlices(allocator, item),
        },
        .bool, .int, .float, .@"enum", .void => {},
        else => @compileError("unsupported local response value"),
    }
}

test "local cloning owns selected wide union slices on a bounded worker stack" {
    const t = std.testing;
    const Payload = struct { bytes: [4 * 1024]u8, labels: [2]?[]const u8, rows: []const struct { text: []const u8 } };
    const Value = union(enum) { a: Payload, b: Payload, c: Payload, d: Payload, e: Payload, f: Payload, g: Payload, h: Payload, i: Payload, j: Payload, k: Payload, l: Payload, m: Payload, n: Payload, o: Payload, p: Payload };
    const Worker = struct {
        fn run(input: *const Value, text: []u8, failure: *?anyerror) void {
            check(input, text) catch |err| {
                failure.* = err;
            };
        }
        fn check(input: *const Value, text: []u8) !void {
            var arena: std.heap.ArenaAllocator = .init(t.allocator);
            defer arena.deinit();
            const copied = try clone(arena.allocator(), input.*);
            @memset(text, 'x');
            try t.expectEqual(std.meta.activeTag(input.*), std.meta.activeTag(copied));
            switch (copied) {
                inline else => |*item| {
                    try t.expect(std.mem.allEqual(u8, &item.bytes, 91));
                    try t.expectEqualStrings("retained", item.labels[0].?);
                    try t.expect(item.labels[1] == null);
                    try t.expectEqualStrings("retained", item.rows[0].text);
                },
            }
        }
    };
    const input = try t.allocator.create(Value);
    defer t.allocator.destroy(input);
    inline for (@typeInfo(Value).@"union".field_names) |name| {
        var text = "retained".*;
        const rows = [_]@typeInfo(@FieldType(Payload, "rows")).pointer.child{.{ .text = &text }};
        input.* = @unionInit(Value, name, .{ .bytes = @splat(91), .labels = .{ &text, null }, .rows = &rows });
        var failure: ?anyerror = null;
        const worker = try std.Thread.spawn(.{ .stack_size = 128 * 1024 }, Worker.run, .{ input, &text, &failure });
        worker.join();
        if (failure) |err| return err;
    }
}

test "local invocation refuses mismatched types and owns nested response slices" {
    const t = std.testing;
    const Request = struct { id: u64 };
    const Response = struct { rows: []const struct { text: []const u8 } };
    const Host = struct {
        fn run(_: *anyopaque, invocation: *Invocation) !void {
            try t.expectError(error.InvalidLocalRequestType, invocation.request(u32));
            try t.expectError(error.InvalidLocalRequestType, invocation.requestPtr(u32));
            const input = try invocation.requestPtr(Request);
            try t.expectEqual(invocation.input, @as(*const anyopaque, input));
            try t.expectEqual(7, input.id);
            try t.expectError(error.InvalidLocalResponseType, invocation.respond(@as(u64, 9)));
            var temporary: std.heap.ArenaAllocator = .init(t.allocator);
            defer temporary.deinit();
            const rows = try temporary.allocator().alloc(@typeInfo(@FieldType(Response, "rows")).pointer.child, 1);
            rows[0] = .{ .text = try temporary.allocator().dupe(u8, "retained") };
            try invocation.respond(try clone(invocation.allocator, Response{ .rows = rows }));
        }
    };
    var context: u8 = 0;
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    client.local = .{ .context = &context, .invoke = Host.run };
    const response = try client.callOwned(Response, "/test", Request{ .id = 7 }, .{});
    defer response.deinit();
    try t.expectEqualStrings("retained", response.value.rows[0].text);
}

test "owned local output refuses oversized materialization and releases partial data" {
    const t = std.testing;
    const Host = struct {
        fn run(_: *anyopaque, invocation: *Invocation) !void {
            _ = try invocation.allocator.alloc(u8, 16);
            _ = try invocation.allocator.alloc(u8, 17);
            return error.UnexpectedUnboundedAllocation;
        }
    };
    var context: u8 = 0;
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    client.local = .{ .context = &context, .invoke = Host.run };
    try t.expectError(error.WriteFailed, client.callOwned([]const u8, "/local", .{}, .{ .response_bytes = 32 }));
}

test "publication hints coalesce without losing notification before wait registration" {
    const t = std.testing;
    var changes: Changes = .{};
    const startup = try changes.wait(t.io, 0);
    changes.notify(t.io);
    changes.notify(t.io);
    const after = try changes.wait(t.io, startup);
    try t.expectEqual(startup + 2, after);
    const Worker = struct {
        fn wait(value: *Changes, io: std.Io, previous: u64) !u64 {
            return value.wait(io, previous);
        }
    };
    var waiter = try t.io.concurrent(Worker.wait, .{ &changes, t.io, after });
    changes.notify(t.io);
    try t.expectEqual(after + 1, try waiter.await(t.io));
    var parked = try t.io.concurrent(Worker.wait, .{ &changes, t.io, after + 1 });
    try t.expectError(error.Canceled, parked.cancel(t.io));
}

test "validated local missing selection is distinct from unavailable authority" {
    const t = std.testing;
    var client = @import("root.zig").Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer client.deinit();
    try t.expectEqual(error.NotFound, client.reject(.not_found, .NotFound));
    try t.expectEqual(.NotFound, client.last_rejection.?);
    try t.expectEqual(error.AuthorityUnavailable, client.reject(.service_unavailable, .NotFound));
}
