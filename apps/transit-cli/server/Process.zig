//! Linux owned process groups. No shell, ambient environment or surviving activation.
const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
pub const Variable = struct { name: []const u8, value: []const u8 };
pub const Launch = struct { argv: []const []const u8, environment: []const Variable = &.{} };
pub const log_bytes = 65536;
pub const Log = struct {
    bytes: [log_bytes]u8 = undefined,
    length: usize = 0,
    /// Retain a finite prefix, then continue draining. No disk/stdout sink can stall a child.
    fn drain(self: *Log, io: std.Io, file: std.Io.File) void {
        var scratch: [4096]u8 = undefined;
        var reader = file.reader(io, &scratch);
        while (true) {
            const bytes = reader.interface.peekGreedy(1) catch return;
            const n = @min(bytes.len, self.bytes.len - self.length);
            @memcpy(self.bytes[self.length..][0..n], bytes[0..n]);
            self.length += n;
            reader.interface.toss(bytes.len);
        }
    }
};
child: ?std.process.Child = null,
stdout_file: ?std.Io.File = null,
stderr_file: ?std.Io.File = null,
stdout: Log = .{},
stderr: Log = .{},
stdout_task: ?std.Io.Future(void) = null,
stderr_task: ?std.Io.Future(void) = null,
pub fn start(self: *Self, init: std.process.Init, executable: []const u8, launch_path: []const u8, launch: Launch, needs_registration: bool) !void {
    std.debug.assert(self.child == null);
    try Files.json(init.io, init.gpa, launch_path, launch);
    var parent: [32]u8 = undefined;
    var environment: std.process.Environ.Map = .init(init.gpa);
    defer environment.deinit();
    self.stdout = .{};
    self.stderr = .{};
    self.child = try std.process.spawn(init.io, .{ .argv = &.{ executable, "__transit_child_v1", try std.fmt.bufPrint(&parent, "{d}", .{std.c.getpid()}), launch_path }, .environ_map = &environment, .stdin = .ignore, .stdout = .pipe, .stderr = .pipe, .pgid = 0 });
    // Child.kill closes its attached streams. The drain tasks own these handles
    // until joined, so detach them before any shutdown or forced-kill path.
    self.stdout_file = self.child.?.stdout;
    self.stderr_file = self.child.?.stderr;
    self.child.?.stdout = null;
    self.child.?.stderr = null;
    errdefer self.stop(init.io);
    self.stderr_task = try std.Io.concurrent(init.io, Log.drain, .{ &self.stderr, init.io, self.stderr_file.? });
    if (!needs_registration) try self.drainStdout(init.io);
}
pub fn drainStdout(self: *Self, io: std.Io) !void {
    self.stdout_task = try std.Io.concurrent(io, Log.drain, .{ &self.stdout, io, self.stdout_file.? });
}
pub fn registration(self: *Self, io: std.Io, buffer: []u8) ![]const u8 {
    var n: usize = 0;
    const started = std.Io.Clock.awake.now(io);
    while (started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() < 10000) {
        if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
        if (!self.alive()) return error.ChildExited;
        var fd: [1]std.c.pollfd = .{.{ .fd = self.stdout_file.?.handle, .events = std.c.POLL.IN, .revents = 0 }};
        if (std.c.poll(&fd, 1, 100) <= 0) continue;
        if (n == buffer.len) return error.InvalidRegistration;
        if (std.c.read(fd[0].fd, @ptrCast(&buffer[n]), 1) != 1) return error.ChildExited;
        if (buffer[n] == '\n') {
            try self.drainStdout(io);
            return buffer[0..n];
        }
        n += 1;
    }
    return error.RegistrationTimeout;
}
pub fn alive(self: *Self) bool {
    if (self.child) |*child| if (child.id) |id| {
        var status: c_int = 0;
        const result = std.c.waitpid(id, &status, 1); // WNOHANG; this supervisor is the sole reaper.
        if (result == 0) return true;
        if (result < 0 and std.c._errno().* == @backingInt(std.c.E.INTR)) return true;
        child.id = null;
    };
    return false;
}
pub fn stop(self: *Self, io: std.Io) void {
    return self.stopWithTimeout(io, 1000);
}
pub fn stopWithTimeout(self: *Self, io: std.Io, timeout_ms: u32) void {
    if (self.child) |*child| {
        if (child.id) |id| {
            _ = std.c.kill(-id, .TERM);
            const started = std.Io.Clock.awake.now(io);
            while (started.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() < timeout_ms) {
                if (!self.alive()) break;
                std.Io.sleep(io, .fromMilliseconds(50), .awake) catch break;
            }
            if (child.id != null) {
                _ = std.c.kill(-id, .KILL);
                child.kill(io);
            }
        }
        if (self.stdout_task) |*task| task.cancel(io);
        if (self.stderr_task) |*task| task.cancel(io);
        if (self.stdout_file) |file| file.close(io);
        if (self.stderr_file) |file| file.close(io);
    }
    self.child = null;
    self.stdout_file = null;
    self.stderr_file = null;
    self.stdout_task = null;
    self.stderr_task = null;
}
/// Private exec trampoline. Parent death is checked again after arming to close
/// the spawn/prctl race. Exec preserves PDEATHSIG for the selected non-setid binaries.
pub fn trampoline(init: std.process.Init, args: []const []const u8) !void {
    if (@import("builtin").os.tag != .linux or args.len != 4) return error.UnsupportedLocalPlatform;
    const parent = try std.fmt.parseInt(std.c.pid_t, args[2], 10);
    if (parent <= 1 or std.os.linux.prctl(1, @intCast(@backingInt(std.c.SIG.KILL)), 0, 0, 0) != 0 or std.c.getppid() != parent) return error.ManagerGone;
    const launch = try Files.read(Launch, init.io, init.arena.allocator(), args[3]);
    if (launch.argv.len == 0 or launch.argv.len > 12 or !std.fs.path.isAbsolute(launch.argv[0]) or launch.environment.len > 16) return error.InvalidLaunch;
    var environment: std.process.Environ.Map = .init(init.gpa);
    defer environment.deinit();
    for (launch.environment) |entry| try environment.put(entry.name, entry.value);
    return std.process.replace(init.io, .{ .argv = launch.argv, .environ_map = &environment });
}

test "full diagnostic prefix keeps draining a real pipe without retaining backlog" {
    const t = std.testing;
    const io = t.io;
    var descriptors: [2]std.c.fd_t = undefined;
    if (std.c.pipe2(&descriptors, .{ .CLOEXEC = true }) != 0) return error.PipeFailed;
    const input: std.Io.File = .{ .handle = descriptors[0], .flags = .{ .nonblocking = false } };
    defer input.close(io);
    const output: std.Io.File = .{ .handle = descriptors[1], .flags = .{ .nonblocking = false } };
    var output_owned = true;
    defer if (output_owned) output.close(io);
    var log: Log = .{};
    var drain = try std.Io.concurrent(io, Log.drain, .{ &log, io, input });
    defer drain.cancel(io);
    const Task = struct {
        fn write(task_io: std.Io, file: std.Io.File) anyerror!void {
            defer file.close(task_io);
            const block: [8192]u8 = @splat('x');
            for (0..256) |_| try file.writeStreamingAll(task_io, &block);
        }
        fn timeout(task_io: std.Io) anyerror!void {
            try task_io.sleep(.fromSeconds(5), .awake);
        }
    };
    const Result = union(enum) { written: anyerror!void, timeout: anyerror!void };
    var results: [2]Result = undefined;
    var selection: std.Io.Select(Result) = .init(io, &results);
    defer selection.cancelDiscard();
    try selection.concurrent(.timeout, Task.timeout, .{io});
    try selection.concurrent(.written, Task.write, .{ io, output });
    output_owned = false;
    switch (try selection.await()) {
        .written => |result| try result,
        .timeout => return error.LogDrainStalled,
    }
    drain.await(io);
    try t.expectEqual(log_bytes, log.length);
    for (log.bytes) |byte| try t.expectEqual('x', byte);
}
