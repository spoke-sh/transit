//! Bounded independent file barriers. All started work joins on every outcome;
//! callers publish names and sync directories only after successful completion.
const std = @import("std");
pub const concurrency = 8;

pub fn sync(io: std.Io, files: []const std.Io.File) !void {
    return run(io, files, std.Io.File.sync);
}

fn run(io: std.Io, items: anytype, comptime operation: anytype) !void {
    const Result = @typeInfo(@TypeOf(operation)).@"fn".return_type.?;
    var offset: usize = 0;
    while (offset < items.len) {
        const count = @min(concurrency, items.len - offset);
        var futures: [concurrency]std.Io.Future(Result) = undefined;
        // async may execute inline when the supplied I/O owner cannot schedule
        // more work. Correctness never depends on additional worker admission.
        for (items[offset..][0..count], futures[0..count]) |item, *future|
            future.* = std.Io.async(io, operation, .{ item, io });
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
    for ([_]usize{ 0, concurrency - 1 }) |failed| {
        var finished: std.atomic.Value(usize) = .init(0);
        var tasks: [concurrency]Task = undefined;
        for (&tasks, 0..) |*task, i| task.* = .{ .finished = &finished, .fail = i == failed };
        try std.testing.expectError(error.InputOutput, run(std.testing.io, &tasks, Task.execute));
        try std.testing.expectEqual(concurrency - 1, finished.load(.monotonic));
    }
}
