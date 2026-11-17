//! Bounded independent file barriers. All started work joins on every outcome;
//! callers publish names and sync directories only after successful completion.
const std = @import("std");
pub const concurrency = 24;

pub fn sync(io: std.Io, files: []const std.Io.File) !void {
    return run(io, files, std.Io.File.sync);
}

fn run(io: std.Io, items: anytype, comptime operation: anytype) !void {
    const Result = @typeInfo(@TypeOf(operation)).@"fn".return_type.?;
    var offset: usize = 0;
    while (offset < items.len) {
        const count = @min(concurrency, items.len - offset);
        var futures: [concurrency]std.Io.Future(Result) = undefined;
        // File barriers wait on I/O even with one CPU. Request concurrency
        // explicitly; async alone runs inline when compute parallelism is zero.
        // A runtime without concurrency still executes safely in bounded order.
        for (items[offset..][0..count], futures[0..count]) |item, *future|
            future.* = std.Io.concurrent(io, operation, .{ item, io }) catch
                std.Io.async(io, operation, .{ item, io });
        var failure: ?anyerror = null;
        for (futures[0..count]) |*future| future.await(io) catch |err| {
            if (failure == null) failure = err;
        };
        if (failure) |err| return err;
        offset += count;
    }
}

test "file sync batch joins other work after an early or late barrier failure" {
    const Task = struct {
        finished: *std.atomic.Value(usize),
        fail: bool,
        fn execute(self: @This(), io: std.Io) !void {
            if (self.fail) return error.InputOutput;
            try io.sleep(.fromMilliseconds(10), .awake);
            _ = self.finished.fetchAdd(1, .monotonic);
        }
    };
    var inline_io = std.Io.Threaded.init(std.testing.allocator, .{ .async_limit = .nothing, .concurrent_limit = .nothing });
    defer inline_io.deinit();
    for ([_]std.Io{ std.testing.io, inline_io.io() }) |io| {
        for ([_]usize{ 0, concurrency - 1 }) |failed| {
            var finished: std.atomic.Value(usize) = .init(0);
            var tasks: [concurrency]Task = undefined;
            for (&tasks, 0..) |*task, i| task.* = .{ .finished = &finished, .fail = i == failed };
            try std.testing.expectError(error.InputOutput, run(io, &tasks, Task.execute));
            try std.testing.expectEqual(concurrency - 1, finished.load(.monotonic));
        }
    }
}

test "file sync batches overlap waiting I/O without compute parallelism" {
    var threaded = std.Io.Threaded.init(std.testing.allocator, .{ .async_limit = .nothing, .concurrent_limit = .limited(concurrency) });
    defer threaded.deinit();
    const io = threaded.io();
    var arrived: std.atomic.Value(usize) = .init(0);
    var together: std.Io.Event = .unset;
    const Task = struct {
        arrived: *std.atomic.Value(usize),
        together: *std.Io.Event,
        fn execute(self: @This(), task_io: std.Io) !void {
            if (self.arrived.fetchAdd(1, .monotonic) == 1) self.together.set(task_io);
            const until = std.Io.Clock.Timestamp.fromNow(task_io, .{ .raw = .fromSeconds(5), .clock = .awake });
            while (!self.together.isSet()) {
                if (until.durationFromNow(task_io).raw.nanoseconds <= 0) return error.Timeout;
                self.together.waitTimeout(task_io, .{ .deadline = until }) catch |err| switch (err) {
                    error.Timeout => continue,
                    else => return err,
                };
            }
        }
    };
    const task: Task = .{ .arrived = &arrived, .together = &together };
    try run(io, &[_]Task{ task, task }, Task.execute);
    try std.testing.expectEqual(@as(usize, 2), arrived.load(.monotonic));
}
