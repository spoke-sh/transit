//! Interactive SQL editing. A save selects a new submission, never a retry of
//! accepted work. Linux directory events distinguish an unchanged write from
//! quitting and cover editors that replace the file with an atomic rename.
const std = @import("std");
const Console = @import("Console.zig");
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const linux = std.os.linux;
const filename = "query.sql";

pub fn isCommand(text: []const u8) bool {
    return std.mem.eql(u8, text, ".edit") or std.mem.startsWith(u8, text, ".edit ") or std.mem.startsWith(u8, text, ".edit\t");
}

pub fn message(err: anyerror) ?[]const u8 {
    return switch (err) {
        error.EditorNotConfigured => "set EDITOR to an editor command, such as vi or code --wait",
        error.InvalidEditorCommand => "EDITOR must contain a program and optional quoted arguments (at most 4096 bytes and 64 arguments)",
        error.EditorLaunchFailed => "could not start EDITOR; check its program and arguments",
        error.EditorFailed => "editor did not exit successfully; SQL was not submitted",
        error.EditorStopped => "editor was suspended; SQL was not submitted",
        error.EditorWatchFailed => "could not observe editor saves; SQL was not submitted",
        error.InvalidEditedFile => "editor output must be a regular SQL file",
        error.EditRequiresTerminal => ".edit requires an interactive terminal",
        error.InvalidEditCommand => ".edit does not accept arguments",
        error.EditRequiresSql => ".edit accepts SQL, not dot commands",
        else => null,
    };
}

// Parse argv without a shell. In particular, the temporary path and SQL never
// become shell syntax. Quotes and escaped characters allow paths with spaces.
const Command = struct {
    bytes: [4096]u8 = undefined,
    argv: [65][]const u8 = undefined,
    count: usize = 0,

    fn parse(self: *Command, text: []const u8) !void {
        if (text.len > self.bytes.len or std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidEditorCommand;
        var read: usize = 0;
        var write: usize = 0;
        while (read < text.len) {
            while (read < text.len and std.ascii.isWhitespace(text[read])) : (read += 1) {}
            if (read == text.len) break;
            if (self.count == self.argv.len - 1) return error.InvalidEditorCommand;
            const start = write;
            var quote: ?u8 = null;
            while (read < text.len) : (read += 1) {
                const byte = text[read];
                if (quote == null and std.ascii.isWhitespace(byte)) break;
                if (byte == '\\' and quote != '\'') {
                    read += 1;
                    if (read == text.len) return error.InvalidEditorCommand;
                } else if (byte == '"' or byte == '\'') {
                    if (quote == null) {
                        quote = byte;
                        continue;
                    } else if (quote == byte) {
                        quote = null;
                        continue;
                    }
                }
                self.bytes[write] = text[read];
                write += 1;
            }
            if (quote != null) return error.InvalidEditorCommand;
            self.argv[self.count] = self.bytes[start..write];
            self.count += 1;
        }
        if (self.count == 0 or self.argv[0].len == 0) return error.EditorNotConfigured;
    }
};

const Watch = struct {
    fd: std.c.fd_t,
    saved: bool = false,

    fn open(path: [:0]const u8) !Watch {
        const fd = std.c.inotify_init1(linux.IN.CLOEXEC | linux.IN.NONBLOCK);
        if (fd < 0) return error.EditorWatchFailed;
        errdefer _ = std.c.close(fd);
        if (std.c.inotify_add_watch(fd, path, linux.IN.CLOSE_WRITE | linux.IN.MOVED_TO | linux.IN.ONLYDIR) < 0) return error.EditorWatchFailed;
        return .{ .fd = fd };
    }

    fn drain(self: *Watch) !void {
        var bytes: [4096]u8 align(@alignOf(linux.inotify_event)) = undefined;
        // Bound a poll even if an editor continuously writes swap/backup files.
        for (0..16) |_| {
            const count = std.c.read(self.fd, &bytes, bytes.len);
            if (count < 0) {
                const err = std.c._errno().*;
                if (err == @backingInt(std.c.E.AGAIN)) return;
                if (err == @backingInt(std.c.E.INTR)) continue;
                return error.EditorWatchFailed;
            }
            if (count == 0) return error.EditorWatchFailed;
            var offset: usize = 0;
            while (offset < count) {
                const event: *const linux.inotify_event = @ptrCast(@alignCast(&bytes[offset]));
                if (event.mask & (linux.IN.Q_OVERFLOW | linux.IN.IGNORED | linux.IN.UNMOUNT) != 0) return error.EditorWatchFailed;
                if (event.getName()) |name| {
                    if (std.mem.eql(u8, name, filename) and event.mask & (linux.IN.CLOSE_WRITE | linux.IN.MOVED_TO) != 0) self.saved = true;
                }
                offset += @sizeOf(linux.inotify_event) + event.len;
            }
        }
        return error.EditorWatchFailed;
    }
};

fn foreground(group: std.posix.pid_t) !void {
    // Reclaiming the terminal from a child group must not stop the console.
    var mask = std.posix.sigemptyset();
    std.posix.sigaddset(&mask, .TTOU);
    var previous: std.posix.sigset_t = undefined;
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &mask, &previous);
    defer std.posix.sigprocmask(std.posix.SIG.SETMASK, &previous, null);
    while (std.c.ioctl(0, linux.T.IOCSPGRP, &group) != 0) {
        if (std.c._errno().* != @backingInt(std.c.E.INTR)) return error.TerminalSetupFailed;
    }
}

fn wait(console: *Console.Console, child: *std.process.Child, watch: *Watch) !void {
    while (true) {
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try watch.drain();
        var status: c_int = 0;
        const pid = child.id.?;
        const result = std.c.waitpid(pid, &status, linux.W.NOHANG | linux.W.UNTRACED);
        if (result < 0) {
            if (std.c._errno().* == @backingInt(std.c.E.INTR)) continue;
            return error.EditorFailed;
        }
        if (result != 0) {
            const value: u32 = @bitCast(status);
            if (linux.W.IFSTOPPED(value)) {
                const signal = linux.W.STOPSIG(value);
                // An editor can try to use the TTY before the foreground handoff.
                if (signal == .TTIN or signal == .TTOU) {
                    _ = std.c.kill(-pid, .CONT);
                    continue;
                }
                return error.EditorStopped;
            }
            child.id = null; // This loop is the sole reaper.
            if (!linux.W.IFEXITED(value) or linux.W.EXITSTATUS(value) != 0) return error.EditorFailed;
            try watch.drain();
            return;
        }
        try console.keepalive();
        try console.init.io.sleep(.fromMilliseconds(50), .awake);
    }
}

pub fn edit(console: *Console.Console, cooked: std.c.termios, display: *std.Io.Writer, initial: []const u8, buffer: []u8) !?[]const u8 {
    const init = console.init;
    var command: Command = .{};
    try command.parse(init.environ_map.get("EDITOR") orelse return error.EditorNotConfigured);
    var parent = try std.Io.Dir.cwd().openDir(init.io, init.environ_map.get("TMPDIR") orelse "/tmp", .{});
    defer parent.close(init.io);
    var random: [16]u8 = undefined;
    try init.io.randomSecure(&random);
    var name_buffer: [64]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buffer, "transit-edit-{x}", .{random});
    try parent.createDir(init.io, name, .fromMode(0o700));
    defer parent.deleteTree(init.io, name) catch {};
    var directory = try parent.openDir(init.io, name, .{ .follow_symlinks = false });
    defer directory.close(init.io);
    const file = try directory.createFile(init.io, filename, .{ .exclusive = true, .permissions = .fromMode(0o600) });
    {
        defer file.close(init.io);
        try file.writeStreamingAll(init.io, initial);
    }
    const path = try parent.realPathFileAlloc(init.io, name, init.gpa);
    defer init.gpa.free(path);
    const file_path = try std.fs.path.join(init.gpa, &.{ path, filename });
    defer init.gpa.free(file_path);
    var watch = try Watch.open(path);
    defer _ = std.c.close(watch.fd);
    command.argv[command.count] = file_path;

    var raw: std.c.termios = undefined;
    if (std.c.tcgetattr(0, &raw) != 0) return error.TerminalSetupFailed;
    var group: std.posix.pid_t = undefined;
    if (std.c.ioctl(0, linux.T.IOCGPGRP, &group) != 0) return error.TerminalSetupFailed;
    try Output.write(init, display, "\x1b[?2004l");
    if (std.c.tcsetattr(0, .NOW, &cooked) != 0) return error.TerminalSetupFailed;
    defer {
        foreground(group) catch {};
        _ = std.c.tcsetattr(0, .NOW, &raw);
        Output.write(init, display, "\x1b[?2004h") catch {};
    }
    var child = std.process.spawn(init.io, .{ .argv = command.argv[0 .. command.count + 1], .environ_map = init.environ_map, .stdout = .{ .file = .stderr() }, .pgid = 0 }) catch return error.EditorLaunchFailed;
    defer if (child.id) |pid| {
        _ = std.c.kill(-pid, .KILL);
        child.kill(init.io);
    };
    try foreground(child.id.?);
    _ = std.c.kill(-child.id.?, .CONT);
    try wait(console, &child, &watch);
    if (!watch.saved) return null;

    // Reopen after an atomic replacement, without following links or blocking
    // on a FIFO. The output must fit the ordinary terminal statement budget.
    const fd = std.c.openat(directory.handle, filename, .{ .ACCMODE = .RDONLY, .CLOEXEC = true, .NONBLOCK = true, .NOFOLLOW = true });
    if (fd < 0) return error.InvalidEditedFile;
    const edited: std.Io.File = .{ .handle = fd, .flags = .{ .nonblocking = true } };
    defer edited.close(init.io);
    if ((try edited.stat(init.io)).kind != .file) return error.InvalidEditedFile;
    const length = try edited.readPositionalAll(init.io, buffer, 0);
    var extra: [1]u8 = undefined;
    if (try edited.readPositionalAll(init.io, &extra, length) != 0) return error.StatementTooLarge;
    const sql = std.mem.trim(u8, buffer[0..length], " \t\r\n");
    if (sql.len == 0) return null;
    if (!std.unicode.utf8ValidateSlice(sql)) return error.InvalidSqlEncoding;
    for (sql) |byte| if ((byte < 32 and byte != '\n' and byte != '\r' and byte != '\t') or byte == 127) return error.InvalidSqlEncoding;
    if (Console.isMeta(sql)) return error.EditRequiresSql;
    return sql;
}
