//! One cancellable metadata borrower. Editing never touches the SQL client
//! until this request is joined; cancellation releases every response buffer.
const std = @import("std");
const sdk = @import("transit_sql_client");
const api = sdk.protocol;
const q = @import("transit_query");
const Self = @This();
const Reply = sdk.Response;
client: *sdk.Client,
io: std.Io,
future: ?std.Io.Future(anyerror!Reply) = null,
done: std.atomic.Value(bool) = .init(false),
bytes: [q.fuze.Sql.max_statement_bytes]u8 = undefined,
length: usize = 0,
cursor: u16 = 0,
timeout: u32 = 0,

pub fn start(self: *Self, request: q.Assistance.Request) !void {
    std.debug.assert(self.future == null);
    @memcpy(self.bytes[0..request.sql.len], request.sql);
    self.length = request.sql.len;
    self.cursor = request.cursor;
    self.timeout = self.client.timeout_ms;
    self.client.timeout_ms = @min(1000, self.timeout);
    errdefer self.client.timeout_ms = self.timeout;
    self.done.store(false, .release);
    self.future = try self.io.concurrent(read, .{self});
}
fn read(self: *Self) anyerror!Reply {
    defer self.done.store(true, .release);
    return self.client.call(.{ .assist = .{ .text = self.bytes[0..self.length], .cursor = self.cursor } });
}
pub fn ready(self: *Self) !?Reply {
    if (self.future == null or !self.done.load(.acquire)) return null;
    defer {
        self.future = null;
        self.client.timeout_ms = self.timeout;
        std.crypto.secureZero(u8, &self.bytes);
    }
    return try self.future.?.await(self.io);
}
pub fn cancel(self: *Self) void {
    if (self.future) |*future| {
        if (future.cancel(self.io)) |reply| reply.deinit() else |_| {}
        self.future = null;
        self.client.timeout_ms = self.timeout;
    }
    std.crypto.secureZero(u8, &self.bytes);
}
