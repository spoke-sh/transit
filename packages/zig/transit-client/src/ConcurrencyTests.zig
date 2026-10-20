//! Exercise admission independently of host CPU count and scheduler luck.
const std = @import("std");
const client = @import("root.zig");
const Io = std.Io;

test "availability classification cannot turn authority or content failures into retries" {
    const t = std.testing;
    try t.expect(client.Client.unavailable(error.NameServerFailure));
    try t.expect(client.Client.unavailable(error.ReadFailed));
    for ([_]anyerror{ error.AccessDenied, error.StaleActivation, error.Rejected, error.Conflict, error.InvalidAuthorityResponse, error.OutOfMemory, error.Canceled }) |err|
        try t.expect(!client.Client.unavailable(err));
}

const Admission = struct {
    threaded: Io.Threaded,
    vtable: Io.VTable = undefined,
    attempts: usize = 0,
    reject_from: usize,
    reject_count: usize,
    connections: std.atomic.Value(usize) = .init(0),
    connect_error: Io.net.IpAddress.ConnectError = error.ConnectionRefused,

    fn init(reject_from: usize, reject_count: usize) Admission {
        return .{
            .threaded = .init(std.testing.allocator, .{
                .async_limit = .limited(2),
                .concurrent_limit = .limited(2),
            }),
            .reject_from = reject_from,
            .reject_count = reject_count,
        };
    }

    fn io(self: *Admission) Io {
        const underlying = self.threaded.io();
        self.vtable = underlying.vtable.*;
        self.vtable.groupConcurrent = groupConcurrent;
        self.vtable.netConnectIp = connect;
        return .{ .userdata = underlying.userdata, .vtable = &self.vtable };
    }

    fn fromContext(context: ?*anyopaque) *Admission {
        const threaded: *Io.Threaded = @ptrCast(@alignCast(context));
        return @fieldParentPtr("threaded", threaded);
    }

    fn groupConcurrent(
        context: ?*anyopaque,
        group: *Io.Group,
        bytes: []const u8,
        alignment: std.mem.Alignment,
        start: *const fn (*const anyopaque) void,
    ) Io.ConcurrentError!void {
        const self = fromContext(context);
        self.attempts += 1;
        if (self.attempts >= self.reject_from and
            self.attempts - self.reject_from < self.reject_count)
            return error.ConcurrencyUnavailable;
        const underlying = self.threaded.io();
        return underlying.vtable.groupConcurrent(context, group, bytes, alignment, start);
    }

    fn connect(context: ?*anyopaque, _: *const Io.net.IpAddress, _: Io.net.IpAddress.ConnectOptions) Io.net.IpAddress.ConnectError!Io.net.Socket {
        const self = fromContext(context);
        _ = self.connections.fetchAdd(1, .monotonic);
        // A real transport failure must return to the caller, never trigger
        // another request as part of retrying worker-slot acquisition.
        return self.connect_error;
    }
};

test "transient admission failure in either slot never retries the transport" {
    for ([_]usize{ 1, 2 }) |slot| {
        var admission: Admission = .init(slot, 2);
        defer admission.threaded.deinit();
        var caller = client.Client.init(std.testing.allocator, admission.io(), "http://127.0.0.1:1");
        defer caller.deinit();
        caller.timeout_ms = 1000;
        try std.testing.expectError(error.ConnectionRefused, caller.call(client.Receipt, "/v1/command", .{}));
        try std.testing.expect(client.Client.unavailable(error.ConnectionRefused));
        try std.testing.expect(admission.attempts >= 4);
        try std.testing.expectEqual(@as(usize, 1), admission.connections.load(.monotonic));
    }
}

test "persistent admission failure has one deadline and leaves the client reusable" {
    for ([_]usize{ 1, 2 }) |slot| {
        var admission: Admission = .init(slot, std.math.maxInt(usize));
        defer admission.threaded.deinit();
        const io = admission.io();
        var caller = client.Client.init(std.testing.allocator, io, "http://127.0.0.1:1");
        defer caller.deinit();
        caller.timeout_ms = 20;
        const started = Io.Clock.awake.now(io);
        try std.testing.expectError(error.AuthorityTimeout, caller.call(client.Receipt, "/v1/command", .{}));
        try std.testing.expect(started.durationTo(Io.Clock.awake.now(io)).toMilliseconds() < 1000);
        try std.testing.expectEqual(@as(usize, 0), admission.connections.load(.monotonic));

        admission.reject_count = 0;
        caller.timeout_ms = 1000;
        try std.testing.expectError(error.ConnectionRefused, caller.call(client.Receipt, "/v1/command", .{}));
        try std.testing.expectEqual(@as(usize, 1), admission.connections.load(.monotonic));
    }
}

test "local connection denial cannot masquerade as an authority rejection" {
    const t = std.testing;
    for ([_][]const u8{ "/v1/command", "/v1/query" }) |route| {
        var admission: Admission = .init(0, 0);
        defer admission.threaded.deinit();
        admission.connect_error = error.AccessDenied;
        var caller = client.Client.init(t.allocator, admission.io(), "http://127.0.0.1:1");
        defer caller.deinit();
        caller.timeout_ms = 1000;
        try t.expectError(error.AuthorityTransportDenied, caller.call(client.Receipt, route, .{}));
        try t.expect(caller.last_rejection == null and caller.last_status == null);
        try t.expectEqual(@as(usize, 1), admission.connections.load(.monotonic));
        try t.expect(client.Client.unavailable(error.AuthorityTransportDenied));
        try t.expect(!client.Client.unavailable(error.AccessDenied));
    }
}

test "local allocation and budget failures cannot retain an earlier wire rejection" {
    const t = std.testing;
    var admission: Admission = .init(0, 0);
    defer admission.threaded.deinit();
    var caller = client.Client.init(t.failing_allocator, admission.io(), "http://127.0.0.1:1");
    defer caller.deinit();
    inline for (.{ false, true }) |owned| {
        caller.last_status = .conflict;
        caller.last_rejection = .Conflict;
        if (owned) {
            try t.expectError(error.OutOfMemory, caller.callOwned(client.Receipt, "/table/v1", .{}, .{}));
        } else {
            try t.expectError(error.OutOfMemory, caller.call(client.Receipt, "/v1/command", .{}));
        }
        try t.expect(caller.last_status == null and caller.last_rejection == null);
    }
    caller.last_status = .conflict;
    caller.last_rejection = .Conflict;
    try t.expectError(error.InvalidHttpBudget, caller.callOwned(client.Receipt, "/table/v1", .{}, .{ .response_bytes = 0 }));
    try t.expect(caller.last_status == null and caller.last_rejection == null);
    try t.expectEqual(@as(usize, 0), admission.connections.load(.monotonic));
}
