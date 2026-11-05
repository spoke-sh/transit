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
    const result = self.io.operateTimeout(.{ .net_write = .{
        .socket_handle = self.stream.socket.handle,
        .header = output.buffered(),
        .data = data,
        .splat = splat,
    } }, self.until) catch return error.WriteFailed;
    return output.consume(result.net_write catch return error.WriteFailed);
}
