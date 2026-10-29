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
pub fn handles(self: Self, path: []const u8) bool {
    const routes = self.routes orelse return true;
    for (routes) |route| if (std.mem.eql(u8, route, path)) return true;
    return false;
}

pub const Invocation = struct {
    client: *@import("root.zig").Client,
    path: []const u8,
    allocator: std.mem.Allocator,
    input: *const anyopaque,
    input_type: *const u8,
    output: *anyopaque,
    output_type: *const u8,
    completed: bool = false,

    pub fn request(self: *const Invocation, comptime T: type) !T {
        if (self.input_type != token(T)) return error.InvalidLocalRequestType;
        return @as(*const T, @ptrCast(@alignCast(self.input))).*;
    }
    pub fn isRequest(self: *const Invocation, comptime T: type) bool {
        return self.input_type == token(T);
    }
    pub fn respond(self: *Invocation, value: anytype) !void {
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
    client.timeout_ms = 50;
    client.local = .{ .context = &host, .invoke = Host.run };
    try t.expectError(error.AuthorityTimeout, client.callOwned(u64, "/local", .{}, .{}));
    try t.expect(host.joined.load(.acquire));
}

/// Returned slices must belong to allocator. Neither the request nor any
/// temporary host workspace may escape through the response. No retry/fallback.
pub fn call(self: Self, client: *@import("root.zig").Client, allocator: std.mem.Allocator, comptime T: type, path: []const u8, input: anytype) !T {
    var result: T = undefined;
    var invocation: Invocation = .{ .client = client, .allocator = allocator, .path = path, .input = &input, .input_type = token(@TypeOf(input)), .output = &result, .output_type = token(T) };
    try self.invoke(self.context, &invocation);
    if (!invocation.completed) return error.InvalidLocalResponseType;
    return result;
}

/// Copy a protocol value into caller-owned storage without encoding it. This
/// deliberately accepts only value trees, not arbitrary runtime object graphs.
/// The caller supplies an arena so partial failure is released as one unit.
pub fn clone(allocator: std.mem.Allocator, value: anytype) !@TypeOf(value) {
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .pointer => |info| blk: {
            if (info.size != .slice or info.sentinel_ptr != null) @compileError("local response must be a value tree");
            const result = try allocator.alloc(info.child, value.len);
            for (value, result) |item, *destination| destination.* = try clone(allocator, item);
            break :blk result;
        },
        .optional => if (value) |item| try clone(allocator, item) else null,
        .array => blk: {
            var result: T = undefined;
            for (value, &result) |item, *destination| destination.* = try clone(allocator, item);
            break :blk result;
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names) |name| @field(result, name) = try clone(allocator, @field(value, name));
            break :blk result;
        },
        .@"union" => switch (value) {
            inline else => |item, tag| @unionInit(T, @tagName(tag), try clone(allocator, item)),
        },
        .bool, .int, .float, .@"enum", .void => value,
        else => @compileError("unsupported local response value"),
    };
}

test "local invocation refuses mismatched types and owns nested response slices" {
    const t = std.testing;
    const Request = struct { id: u64 };
    const Response = struct { rows: []const struct { text: []const u8 } };
    const Host = struct {
        fn run(_: *anyopaque, invocation: *Invocation) !void {
            try t.expectError(error.InvalidLocalRequestType, invocation.request(u32));
            const input = try invocation.request(Request);
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
