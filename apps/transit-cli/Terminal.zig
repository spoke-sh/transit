//! Linux terminal presentation. SQL and assistance remain native query owners.
const std = @import("std");
const q = @import("transit_query");
const Console = @import("Console.zig");
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const input = q.fuze.SqlInput;
const max_bytes = q.fuze.Sql.max_statement_bytes;
const history_limit = 8;
pub fn run(console: *Console.Console) !void {
    var original: std.c.termios = undefined;
    if (std.c.tcgetattr(0, &original) != 0) return error.TerminalSetupFailed;
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.IEXTEN = false;
    raw.iflag.IXON = false;
    raw.iflag.ICRNL = false;
    raw.cc[@backingInt(std.c.V.MIN)] = 1;
    raw.cc[@backingInt(std.c.V.TIME)] = 0;
    raw.cc[@backingInt(std.c.V.SUSP)] = 0; // Ctrl-Z belongs to completion undo.
    raw.cc[@backingInt(std.c.V.QUIT)] = 0;
    if (std.c.tcsetattr(0, .NOW, &raw) != 0) return error.TerminalSetupFailed;
    defer _ = std.c.tcsetattr(0, .NOW, &original);
    var output_buffer: [2048]u8 = undefined;
    var output = std.Io.File.stderr().writerStreaming(console.init.io, &output_buffer);
    var editor: Editor = .{ .console = console, .out = &output.interface, .arena = .init(console.init.gpa) };
    defer {
        editor.erasePrivate();
        editor.arena.deinit();
    }
    try output.interface.writeAll("Transit console: /new ID then SQL + semicolon + Enter. Ctrl-Space completes; Tab accepts; Ctrl-Z undoes.\n\x1b[?2004h");
    try Output.write(console.init, &output.interface, "");
    defer {
        Signals.clear(); // Restore display modes even after the handled signal.
        Output.write(console.init, &output.interface, "\x1b[0m\x1b[?2004l\r\x1b[2K\n") catch {};
    }
    try editor.loop();
}
const Editor = struct {
    console: *Console.Console,
    out: *std.Io.Writer,
    bytes: [max_bytes]u8 = undefined,
    length: usize = 0,
    cursor: usize = 0,
    generation: u32 = 0,
    undo: [max_bytes]u8 = undefined,
    undo_length: ?usize = null,
    undo_cursor: usize = 0,
    history: [history_limit][max_bytes]u8 = undefined,
    history_lengths: [history_limit]usize = @splat(0),
    history_count: usize = 0,
    history_index: usize = 0,
    arena: std.heap.ArenaAllocator,
    assistance: ?q.Assistance.Response = null,
    selected: usize = 0,
    expires: i64 = 0,
    pasting: bool = false,
    columns: usize = 80,
    fn text(self: *Editor) []const u8 {
        return self.bytes[0..self.length];
    }
    fn now(self: *Editor) i64 {
        return std.Io.Clock.boot.now(self.console.init.io).toMilliseconds();
    }
    fn dismiss(self: *Editor) void {
        self.assistance = null;
        _ = self.arena.reset(.free_all);
        self.selected = 0;
    }
    fn changed(self: *Editor) void {
        self.dismiss();
        self.generation +%= 1;
    }
    fn erasePrivate(self: *Editor) void {
        self.dismiss();
        std.crypto.secureZero(u8, &self.bytes);
        std.crypto.secureZero(u8, &self.undo);
        std.crypto.secureZero(u8, std.mem.asBytes(&self.history));
        self.length = 0;
        self.cursor = 0;
        self.undo_length = null;
        self.history_count = 0;
        self.history_index = 0;
        self.history_lengths = @splat(0);
        self.generation +%= 1;
    }
    fn insert(self: *Editor, bytes: []const u8) !void {
        if (self.length + bytes.len > max_bytes) return error.StatementTooLarge;
        std.mem.copyBackwards(u8, self.bytes[self.cursor + bytes.len .. self.length + bytes.len], self.bytes[self.cursor..self.length]);
        @memcpy(self.bytes[self.cursor..][0..bytes.len], bytes);
        self.cursor += bytes.len;
        self.length += bytes.len;
        self.undo_length = null;
        self.changed();
    }
    fn remove(self: *Editor, start: usize, end: usize) void {
        std.mem.copyForwards(u8, self.bytes[start..], self.bytes[end..self.length]);
        self.length -= end - start;
        self.cursor = start;
        self.undo_length = null;
        self.changed();
    }
    fn remember(self: *Editor, statement: []const u8) void {
        // Recovery exports/imports and all slash arguments stay out of history.
        if (statement.len == 0 or statement[0] == '/' or statement.len > max_bytes) return;
        if (self.history_count == history_limit) {
            for (0..history_limit - 1) |i| {
                self.history[i] = self.history[i + 1];
                self.history_lengths[i] = self.history_lengths[i + 1];
            }
            self.history_count -= 1;
        }
        @memcpy(self.history[self.history_count][0..statement.len], statement);
        self.history_lengths[self.history_count] = statement.len;
        self.history_count += 1;
        self.history_index = self.history_count;
    }
    fn recall(self: *Editor, up: bool) void {
        if (up) {
            self.history_index -|= 1;
        } else self.history_index = @min(self.history_count, self.history_index + 1);
        self.length = if (self.history_index < self.history_count) self.history_lengths[self.history_index] else 0;
        if (self.length > 0) @memcpy(self.bytes[0..self.length], self.history[self.history_index][0..self.length]);
        self.cursor = self.length;
        self.undo_length = null;
        self.changed();
    }
    fn complete(self: *Editor) !void {
        self.dismiss();
        const response = (q.Workspace.apply(self.arena.allocator(), self.console.client, self.console.config, .{ .assist = .{ .sql = self.text(), .cursor = @intCast(self.cursor), .generation = self.generation, .mode = .console } }) catch |err| {
            if (Console.denied(err)) self.erasePrivate();
            return err;
        }).assistance;
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        // Input accumulated while a metadata read waited is a newer generation.
        // Process it before ever presenting/accepting the old response.
        if (Signals.pending()) {
            self.dismiss();
            return;
        }
        self.assistance = response;
        self.expires = self.now() + 5000;
    }
    fn accept(self: *Editor) !void {
        const prior = self.assistance orelse return self.complete();
        if (prior.items.len == 0) return;
        const range = prior.range orelse return;
        const selected = prior.items[self.selected];
        var arena: std.heap.ArenaAllocator = .init(self.console.init.gpa);
        defer arena.deinit();
        const current = (q.Workspace.apply(arena.allocator(), self.console.client, self.console.config, .{ .assist = .{ .sql = self.text(), .cursor = @intCast(self.cursor), .generation = self.generation, .mode = .console } }) catch |err| {
            if (Console.denied(err)) self.erasePrivate() else self.dismiss();
            return err;
        }).assistance;
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        if (Signals.pending() or current.generation != prior.generation or !std.meta.eql(current.range, prior.range) or !std.mem.eql(u8, &current.contract, &prior.contract) or !std.mem.eql(u8, current.policy_revision, prior.policy_revision)) {
            self.dismiss();
            return;
        }
        var found = false;
        for (current.items) |candidate| if (std.mem.eql(u8, candidate.text, selected.text)) {
            found = true;
            break;
        };
        if (!found) {
            self.dismiss();
            return;
        }
        const length = self.length - (range.end - range.start) + selected.text.len;
        if (length > max_bytes) return error.StatementTooLarge;
        @memcpy(self.undo[0..self.length], self.text());
        self.undo_length = self.length;
        self.undo_cursor = self.cursor;
        const suffix = self.undo[range.end..self.length];
        @memcpy(self.bytes[range.start..][0..selected.text.len], selected.text);
        @memcpy(self.bytes[range.start + selected.text.len ..][0..suffix.len], suffix);
        self.length = length;
        self.cursor = range.start + selected.text.len;
        self.changed();
    }
    fn submit(self: *Editor) !bool {
        self.dismiss();
        var consumed: usize = 0;
        while (consumed < self.length) {
            const rest = std.mem.trimStart(u8, self.bytes[consumed..self.length], " \t\r\n");
            if (rest.len == 0) {
                consumed = self.length;
                break;
            }
            const start = self.length - rest.len;
            const meta = std.mem.startsWith(u8, rest, "/") and !std.mem.startsWith(u8, rest, "/*");
            const count = if (meta) (std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len) else (try input.terminator(rest) orelse break);
            const statement = rest[0..count];
            try self.out.writeAll("\r\x1b[2K");
            try Output.write(self.console.init, self.out, "");
            self.remember(statement);
            if (!try self.console.execute(statement)) return false;
            if (self.console.access_lost) {
                self.console.access_lost = false;
                self.erasePrivate();
                return true;
            }
            consumed = start + count;
        }
        if (consumed > 0) self.remove(0, consumed);
        self.cursor = self.length;
        if (self.length > 0) try self.insert("\n");
        return true;
    }
    fn loop(self: *Editor) !void {
        try self.draw();
        while (true) {
            const event = Signals.pollByte(100) catch |err| {
                if (err != error.ConsoleInterrupted or Signals.terminating()) return err;
                Signals.clear();
                self.length = 0;
                self.cursor = 0;
                self.undo_length = null;
                self.changed();
                try self.draw();
                continue;
            };
            if (event == .timeout) {
                if ((self.assistance != null and self.now() >= self.expires) or self.width() != self.columns) {
                    self.dismiss();
                    try self.draw();
                }
                continue;
            }
            if (event == .eof) {
                if (self.length > 0) return error.IncompleteSqlStatement;
                return;
            }
            self.key(event.byte) catch |err| {
                if (err == error.ConsoleQuit) return;
                if (err == error.ConsoleInterrupted or err == error.ConsoleOutputTimeout or err == error.WriteFailed) return err;
                if (self.console.recovery) |file| if (file.failed) return err;
                self.dismiss();
                try self.out.print("\r\x1b[2Kerror: {s}\n", .{@errorName(err)});
            };
            if (!Signals.pending()) try self.draw();
        }
    }
    fn key(self: *Editor, byte: u8) !void {
        if (byte == 27) return self.escape();
        if (self.pasting) {
            if (byte == '\r') return self.insert("\n");
            if (byte < 32 and byte != '\n' and byte != '\t') return error.InvalidSqlEncoding;
            return self.character(byte);
        }
        switch (byte) {
            0 => try self.complete(), // Ctrl-Space
            4 => {
                if (self.length == 0) return error.ConsoleQuit;
                return error.IncompleteSqlStatement;
            },
            9 => try self.accept(),
            10, 13 => {
                if (self.assistance != null) try self.accept() else if (!try self.submit()) return error.ConsoleQuit;
            },
            1 => {
                self.cursor = 0;
                self.changed();
            },
            5 => {
                self.cursor = self.length;
                self.changed();
            },
            21 => self.remove(0, self.cursor),
            26 => if (self.undo_length) |length| {
                @memcpy(self.bytes[0..length], self.undo[0..length]);
                self.length = length;
                self.cursor = self.undo_cursor;
                self.undo_length = null;
                self.changed();
            },
            8, 127 => if (self.cursor > 0) self.remove(previous(self.text(), self.cursor), self.cursor),
            else => {
                if (byte < 32) return error.InvalidSqlEncoding;
                try self.character(byte);
            },
        }
    }
    fn character(self: *Editor, byte: u8) !void {
        const length = std.unicode.utf8ByteSequenceLength(byte) catch return error.InvalidSqlEncoding;
        var bytes: [4]u8 = undefined;
        bytes[0] = byte;
        for (bytes[1..length]) |*next| next.* = try Signals.readByte() orelse return error.InvalidSqlEncoding;
        if (!std.unicode.utf8ValidateSlice(bytes[0..length])) return error.InvalidSqlEncoding;
        try self.insert(bytes[0..length]);
    }
    fn escape(self: *Editor) !void {
        var sequence: [12]u8 = undefined;
        var length: usize = 0;
        while (length < sequence.len) {
            const event = try Signals.pollByte(25);
            if (event != .byte) break;
            sequence[length] = event.byte;
            length += 1;
            if (length == 1 and event.byte != '[' and event.byte != 'O') {
                self.dismiss();
                return self.character(event.byte);
            }
            if (length > 1 and (std.ascii.isAlphabetic(event.byte) or event.byte == '~')) break;
        }
        const code = sequence[0..length];
        if (std.mem.eql(u8, code, "[200~")) {
            self.pasting = true;
            self.dismiss();
            return;
        }
        if (std.mem.eql(u8, code, "[201~")) {
            self.pasting = false;
            return;
        }
        if (self.pasting) return error.InvalidSqlEncoding;
        if (std.mem.eql(u8, code, "[A") or std.mem.eql(u8, code, "[B")) {
            const up = code[1] == 'A';
            if (self.assistance) |assistance| {
                if (assistance.items.len > 0) self.selected = if (up) (self.selected + assistance.items.len - 1) % assistance.items.len else (self.selected + 1) % assistance.items.len;
            } else self.recall(up);
        } else if (std.mem.eql(u8, code, "[D")) {
            self.cursor = previous(self.text(), self.cursor);
            self.changed();
        } else if (std.mem.eql(u8, code, "[C")) {
            if (self.cursor < self.length) self.cursor += try std.unicode.utf8ByteSequenceLength(self.bytes[self.cursor]);
            self.changed();
        } else if (std.mem.eql(u8, code, "[H") or std.mem.eql(u8, code, "OH")) {
            self.cursor = 0;
            self.changed();
        } else if (std.mem.eql(u8, code, "[F") or std.mem.eql(u8, code, "OF")) {
            self.cursor = self.length;
            self.changed();
        } else if (std.mem.eql(u8, code, "[3~")) {
            if (self.cursor < self.length) self.remove(self.cursor, self.cursor + (try std.unicode.utf8ByteSequenceLength(self.bytes[self.cursor])));
        } else self.dismiss();
    }
    fn width(_: *Editor) usize {
        var size: std.c.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
        if (std.os.linux.ioctl(2, std.os.linux.T.IOCGWINSZ, @intFromPtr(&size)) != 0 or size.col == 0) return 80;
        return @max(8, @min(160, size.col));
    }
    fn draw(self: *Editor) !void {
        self.columns = self.width();
        try self.out.writeAll("\r\x1b[2K");
        var prefix_buffer: [160]u8 = undefined;
        const prefix = if (self.assistance) |assistance| if (assistance.items.len == 0) "[no completion] > " else try std.fmt.bufPrint(&prefix_buffer, "[{d}/{d} {s}] > ", .{ self.selected + 1, assistance.items.len, assistance.items[self.selected].text }) else "transit> ";
        const prefix_length = @min(prefix.len, self.columns / 2);
        // Suggestions are grammar/catalog identifiers; still escape any control.
        for (prefix[0..prefix_length]) |byte| try self.out.writeByte(if (byte >= 32 and byte < 127) byte else '?');
        const available = self.columns - prefix_length - 1;
        var start = self.cursor;
        var left_width: usize = 0;
        var buffer: [16]u8 = undefined;
        while (start > 0) {
            const before = previous(self.text(), start);
            const visible = try printable(self.bytes[before..start], &buffer);
            if (left_width + visible.len > available / 2) break;
            left_width += visible.len;
            start = before;
        }
        var used: usize = 0;
        var i = start;
        var scan = input.Scan.init(self.text()) catch null;
        var token: ?input.Token = null;
        while (i < self.length) {
            const length = try std.unicode.utf8ByteSequenceLength(self.bytes[i]);
            const visible = try printable(self.bytes[i..][0..length], &buffer);
            if (used + visible.len > available) break;
            if (scan) |*scanner| while (token == null or token.?.end <= i) {
                token = scanner.next() catch null;
                if (token == null) break;
            };
            const color: []const u8 = if (token) |value| switch (value.kind) {
                .word => "\x1b[36m",
                .string, .quoted => "\x1b[32m",
                .comment => "\x1b[2m",
                .number => "\x1b[35m",
                else => "\x1b[0m",
            } else "\x1b[0m";
            try self.out.writeAll(color);
            try self.out.writeAll(visible);
            i += length;
            used += visible.len;
        }
        try self.out.print("\x1b[0m\r\x1b[{d}C", .{prefix_length + left_width});
        try Output.write(self.console.init, self.out, "");
    }
};
fn previous(text: []const u8, offset: usize) usize {
    if (offset == 0) return 0;
    var result = offset - 1;
    while (result > 0 and text[result] & 0xc0 == 0x80) result -= 1;
    return result;
}
fn printable(bytes: []const u8, buffer: []u8) ![]const u8 {
    if (bytes.len == 1) return switch (bytes[0]) {
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
        32...126 => bytes,
        else => std.fmt.bufPrint(buffer, "\\x{x:0>2}", .{bytes[0]}),
    };
    return std.fmt.bufPrint(buffer, "\\u{{{x}}}", .{try std.unicode.utf8Decode(bytes)});
}
