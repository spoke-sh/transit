//! A stalled local display cannot indefinitely retain a console process.
const std = @import("std");
const Signals = @import("Signals.zig");
pub fn write(init: std.process.Init, out: *std.Io.Writer, bytes: []const u8) !void {
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
    var selection: std.Io.Select(Result) = .init(init.io, &results);
    defer selection.cancelDiscard(); // Join writes before their buffer is released.
    try selection.concurrent(.stopped, Task.stop, .{ init.io, std.Io.Clock.boot.now(init.io).toMilliseconds() + 2000 });
    try selection.concurrent(.written, Task.emit, .{ out, bytes });
    switch (try selection.await()) {
        .written => |result| try result,
        .stopped => |result| try result,
    }
}
