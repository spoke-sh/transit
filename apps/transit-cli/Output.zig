//! A stalled local display cannot indefinitely retain a console process.
const std = @import("std");
const Signals = @import("Signals.zig");
pub fn write(init: std.process.Init, out: *std.Io.Writer, bytes: []const u8) !void {
    return writeIo(init.io, out, bytes);
}
pub fn writeIo(sink_io: std.Io, out: *std.Io.Writer, bytes: []const u8) !void {
    const Result = union(enum) { written: anyerror!void, stopped: anyerror!void };
    const Task = struct {
        fn emit(writer: *std.Io.Writer, value: []const u8) !void {
            try writer.writeAll(value);
            try writer.flush();
        }
        fn stop(io: std.Io, deadline: i64) !void {
            while (true) {
                if (Signals.interrupted()) return error.ConsoleInterrupted;
                if (std.Io.Clock.boot.now(io).toMilliseconds() >= deadline) return error.ConsoleOutputTimeout;
                try io.sleep(.fromMilliseconds(20), .awake);
            }
        }
    };
    var results: [2]Result = undefined;
    var selection: std.Io.Select(Result) = .init(sink_io, &results);
    defer selection.cancelDiscard(); // Join writes before their buffer is released.
    try selection.concurrent(.stopped, Task.stop, .{ sink_io, std.Io.Clock.boot.now(sink_io).toMilliseconds() + 2000 });
    try selection.concurrent(.written, Task.emit, .{ out, bytes });
    switch (try selection.await()) {
        .written => |result| try result,
        .stopped => |result| try result,
    }
}

/// Stream escaped output without imposing a second, accidental row-size limit.
/// Each drain retains the same interruption/timeout and joined-write boundary.
/// Formatting can expose a partial record; only a verified footer is completion.
pub const Stream = struct {
    io: std.Io,
    target: *std.Io.Writer,
    interface: std.Io.Writer,
    failure: ?anyerror = null,
    pub fn init(io: std.Io, target: *std.Io.Writer, buffer: []u8) Stream {
        return .{ .io = io, .target = target, .interface = .{ .vtable = &.{ .drain = drain }, .buffer = buffer } };
    }
    pub fn flush(self: *Stream) !void {
        if (self.failure) |err| return err;
        self.interface.flush() catch |err| return self.failure orelse err;
    }
    fn emit(self: *Stream, bytes: []const u8) std.Io.Writer.Error!void {
        if (self.failure != null) return error.WriteFailed;
        if (bytes.len == 0) return;
        writeIo(self.io, self.target, bytes) catch |err| {
            self.failure = err;
            return error.WriteFailed;
        };
    }
    fn drain(out: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *Stream = @fieldParentPtr("interface", out);
        try self.emit(out.buffered());
        out.end = 0;
        for (data[0 .. data.len - 1]) |bytes| try self.emit(bytes);
        for (0..splat) |_| try self.emit(data[data.len - 1]);
        return std.Io.Writer.countSplat(data, splat);
    }
};

test "streamed output preserves buffered vectors splats and sticky output failure" {
    var target: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer target.deinit();
    var bytes: [7]u8 = undefined;
    var stream = Stream.init(std.testing.io, &target.writer, &bytes);
    try stream.interface.writeAll("prefix:");
    var pieces: [3][]const u8 = .{ "one", "two", "!" };
    try stream.interface.writeSplatAll(&pieces, 4);
    try stream.interface.writeAll("tail");
    try stream.flush();
    try std.testing.expectEqualStrings("prefix:onetwo!!!!tail", target.written());
    var failed = std.Io.Writer.failing;
    stream = Stream.init(std.testing.io, &failed, &bytes);
    try stream.interface.writeAll("pending");
    try std.testing.expectError(error.WriteFailed, stream.flush());
    try std.testing.expectEqual(error.WriteFailed, stream.failure.?);
    stream.target = &target.writer;
    try std.testing.expectError(error.WriteFailed, stream.flush());
    try std.testing.expectEqualStrings("prefix:onetwo!!!!tail", target.written());
    stream = Stream.init(std.testing.io, &failed, &bytes);
    try std.testing.expectError(error.WriteFailed, stream.interface.writeAll("larger than the buffer"));
    try std.testing.expectEqual(@as(usize, 0), stream.interface.end);
    stream.target = &target.writer;
    try std.testing.expectError(error.WriteFailed, stream.flush());
}
