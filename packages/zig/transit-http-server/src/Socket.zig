//! Buffered plain HTTP carriage. The listener owns the socket and sets one
//! absolute deadline per phase; partial reads/writes never renew that deadline.
const std = @import("std");
const Io = std.Io;
const Self = @This();

io: Io,
stream: Io.net.Stream,
input: Io.Reader,
output: Io.Writer,
until: Io.Timeout = .none,
read_error: ?anyerror = null,

pub fn init(self: *Self, io: Io, stream: Io.net.Stream, input: []u8, output: []u8) void {
    self.* = .{
        .io = io,
        .stream = stream,
        .input = .{ .buffer = input, .seek = 0, .end = 0, .vtable = &.{ .stream = read, .readVec = readVec } },
        .output = .{ .buffer = output, .end = 0, .vtable = &.{ .drain = write } },
    };
}

pub fn setDeadline(self: *Self, until: Io.Clock.Timestamp) void {
    self.until = .{ .deadline = until };
    self.read_error = null;
}

pub fn readError(self: *const Self) ?anyerror {
    return self.read_error;
}

pub fn reader(self: *Self) *Io.Reader {
    return &self.input;
}

pub fn writer(self: *Self) *Io.Writer {
    return &self.output;
}

pub fn deinit(_: *Self) void {}

fn read(input: *Io.Reader, output: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
    var data = [_][]u8{limit.slice(try output.writableSliceGreedy(1))};
    const count = try readVec(input, &data);
    output.advance(count);
    return count;
}

fn readVec(input: *Io.Reader, data: [][]u8) Io.Reader.Error!usize {
    const self: *Self = @alignCast(@fieldParentPtr("input", input));
    if (self.expired()) {
        self.read_error = error.Timeout;
        return error.ReadFailed;
    }
    var vectors: [8][]u8 = undefined;
    const vector_count, const data_bytes = try input.writableVector(&vectors, data);
    const result = self.io.operateTimeout(.{ .net_read = .{
        .socket_handle = self.stream.socket.handle,
        .data = vectors[0..vector_count],
    } }, self.until) catch |err| {
        self.read_error = err;
        return error.ReadFailed;
    };
    const count = result.net_read catch |err| {
        self.read_error = err;
        return error.ReadFailed;
    };
    if (count == 0) return error.EndOfStream;
    if (count > data_bytes) {
        input.end += count - data_bytes;
        return data_bytes;
    }
    return count;
}

fn write(output: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
    const self: *Self = @alignCast(@fieldParentPtr("output", output));
    if (self.expired()) return error.WriteFailed;
    const result = self.io.operateTimeout(.{ .net_write = .{
        .socket_handle = self.stream.socket.handle,
        .header = output.buffered(),
        .data = data,
        .splat = splat,
    } }, self.until) catch return error.WriteFailed;
    return output.consume(result.net_write catch return error.WriteFailed);
}

fn expired(self: *const Self) bool {
    // A readiness backend may complete a ready operation even at timeout zero.
    // Enforce the phase boundary before submitting any new socket operation.
    return if (self.until.toDurationFromNow(self.io)) |remaining| remaining.raw.nanoseconds <= 0 else false;
}

test "expired HTTP socket operations leave ready bytes untouched" {
    const io = std.testing.io;
    var listener = try (try Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    const client = try listener.socket.address.connect(io, .{ .mode = .stream });
    defer client.close(io);
    const server = try listener.accept(io);
    defer server.close(io);
    var client_output = client.writer(io, &.{});
    try client_output.interface.writeAll("ready");
    // Prove readiness without consuming the bytes. Timeout-only polling would
    // otherwise be allowed to read them after the absolute deadline expires.
    var descriptors = [_]std.posix.pollfd{.{ .fd = server.socket.handle, .events = std.posix.POLL.IN, .revents = 0 }};
    try std.testing.expectEqual(1, std.posix.system.poll(&descriptors, 1, 1000));
    var socket: Self = undefined;
    socket.init(io, server, &.{}, &.{});
    socket.setDeadline(.{ .clock = .awake, .raw = Io.Clock.awake.now(io).addDuration(.fromSeconds(-1)) });
    var bytes: [5]u8 = undefined;
    try std.testing.expectError(error.ReadFailed, socket.reader().readSliceAll(&bytes));
    try std.testing.expectEqual(error.Timeout, socket.readError().?);
    try std.testing.expectError(error.WriteFailed, socket.writer().writeAll("expired"));
    socket.setDeadline(.fromNow(io, .{ .clock = .awake, .raw = .fromSeconds(5) }));
    try socket.reader().readSliceAll(&bytes);
    try std.testing.expectEqualStrings("ready", &bytes);
    try socket.writer().writeAll("fresh");
    var reply: Self = undefined;
    reply.init(io, client, &.{}, &.{});
    reply.setDeadline(.fromNow(io, .{ .clock = .awake, .raw = .fromSeconds(5) }));
    try reply.reader().readSliceAll(&bytes);
    try std.testing.expectEqualStrings("fresh", &bytes);
}
