//! Linux terminal presentation. SQL and assistance remain native query owners.
const std = @import("std");
const q = @import("transit_query");
const Console = @import("Console.zig");
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const History = @import("History.zig");
const Style = @import("Style.zig");
const input = q.fuze.SqlInput;
const max_bytes = q.fuze.Sql.max_statement_bytes;
pub fn run(console: *Console.Console) !void {
    var original: std.c.termios = undefined;
    if (std.c.tcgetattr(0, &original) != 0) return error.TerminalSetupFailed;
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.IEXTEN = false;
    raw.iflag.IXON = false;
    raw.iflag.ICRNL = false;
    // poll owns the wait. A signal may flush its ready byte before read runs;
    // an empty read must return so normal code can handle the signal.
    raw.cc[@backingInt(std.c.V.MIN)] = 0;
    raw.cc[@backingInt(std.c.V.TIME)] = 0;
    raw.cc[@backingInt(std.c.V.SUSP)] = 0; // Ctrl-Z belongs to completion undo.
    raw.cc[@backingInt(std.c.V.QUIT)] = 0;
    if (std.c.tcsetattr(0, .NOW, &raw) != 0) return error.TerminalSetupFailed;
    defer _ = std.c.tcsetattr(0, .NOW, &original);
    var output_buffer: [2048]u8 = undefined;
    var output = std.Io.File.stderr().writerStreaming(console.init.io, &output_buffer);
    var editor: Editor = .{ .console = console, .out = &output.interface, .arena = .init(console.init.gpa), .history = .{ .io = console.init.io, .allocator = console.init.gpa } };
    defer {
        editor.erasePrivate();
        editor.history.close();
        editor.arena.deinit();
    }
    editor.history.open(console.init.environ_map.get("HOME")) catch |err| try editor.historyFailure(err);
    try output.interface.writeAll("Transit\nEnd SQL with a semicolon. .help lists commands.\nCtrl-R searches history; Ctrl-Space completes; Tab accepts; Ctrl-Z undoes.\n\x1b[?2004h");
    try Output.write(console.init, &output.interface, "");
    defer {
        Signals.clear(); // Restore display modes even after the handled signal.
        output.interface.writeAll(console.diagnostic.style.code(.plain)) catch {};
        Output.write(console.init, &output.interface, "\x1b[?2004l\r\x1b[2K\n") catch {};
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
    history: History,
    history_position: ?u64 = null,
    draft: [max_bytes]u8 = undefined,
    draft_length: usize = 0,
    draft_cursor: usize = 0,
    searching: bool = false,
    search: [max_bytes]u8 = undefined,
    search_length: usize = 0,
    search_failed: bool = false,
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
        std.crypto.secureZero(u8, &self.draft);
        std.crypto.secureZero(u8, &self.search);
        self.history.clear();
        self.length = 0;
        self.cursor = 0;
        self.undo_length = null;
        self.history_position = null;
        self.draft_length = 0;
        self.searching = false;
        self.search_length = 0;
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
    fn historyFailure(self: *Editor, err: anyerror) !void {
        self.history.close();
        self.history_position = null;
        try self.out.print("\r\x1b[2Kwarning: history file unavailable ({s}); using session history only.\n", .{@errorName(err)});
    }
    fn saveDraft(self: *Editor) void {
        @memcpy(self.draft[0..self.length], self.text());
        self.draft_length = self.length;
        self.draft_cursor = self.cursor;
    }
    fn restoreDraft(self: *Editor) void {
        @memcpy(self.bytes[0..self.draft_length], self.draft[0..self.draft_length]);
        self.length = self.draft_length;
        self.cursor = self.draft_cursor;
        self.history_position = null;
        self.changed();
    }
    fn recall(self: *Editor, up: bool) !void {
        if (self.history_position == null) {
            if (!up) return;
            self.saveDraft();
        }
        const entry = if (up)
            try self.history.previous(self.history_position orelse try self.history.end(), &self.bytes)
        else
            try self.history.next(self.history_position.?, &self.bytes);
        if (entry) |value| {
            self.history_position = value.position;
            self.length = value.length;
        } else if (!up) {
            self.restoreDraft();
            return;
        }
        self.cursor = self.length;
        self.undo_length = null;
        self.changed();
    }
    fn searchHistory(self: *Editor, older: bool) !void {
        var before = if (older) self.history_position orelse try self.history.end() else try self.history.end();
        var candidate: [max_bytes]u8 = undefined;
        defer std.crypto.secureZero(u8, &candidate);
        while (try self.history.previous(before, &candidate)) |entry| {
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            if (std.mem.indexOf(u8, candidate[0..entry.length], self.search[0..self.search_length]) != null) {
                @memcpy(self.bytes[0..entry.length], candidate[0..entry.length]);
                self.length = entry.length;
                self.cursor = self.length;
                self.history_position = entry.position;
                self.search_failed = false;
                self.changed();
                return;
            }
            before = entry.position;
        }
        self.search_failed = true;
    }
    fn beginSearch(self: *Editor) !void {
        if (!self.searching) {
            self.saveDraft();
            self.searching = true;
            self.search_length = 0;
            self.search_failed = false;
            self.history_position = null;
            self.undo_length = null;
            self.changed();
            return;
        }
        try self.searchHistory(true);
    }
    fn finishSearch(self: *Editor, accept_match: bool) void {
        if (!accept_match or self.search_failed or self.history_position == null) self.restoreDraft();
        self.searching = false;
        self.search_length = 0;
        self.search_failed = false;
        self.changed();
    }
    fn clearDraft(self: *Editor) void {
        self.length = 0;
        self.cursor = 0;
        self.undo_length = null;
        self.searching = false;
        self.search_length = 0;
        self.search_failed = false;
        self.history_position = null;
        self.pasting = false;
        self.changed();
    }
    fn complete(self: *Editor) !void {
        self.dismiss();
        var response = (self.console.assist(self.arena.allocator(), .{ .sql = self.text(), .cursor = @intCast(self.cursor), .generation = self.generation, .mode = .console }) catch |err| {
            if (Console.denied(err)) self.erasePrivate();
            return err;
        });
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        // Input accumulated while a metadata read waited is a newer generation.
        // Process it before ever presenting/accepting the old response.
        if (Signals.pending()) {
            self.dismiss();
            return;
        }
        if (self.console.interactive and self.console.writes == null) {
            const items = try self.arena.allocator().alloc(@TypeOf(response.items[0]), response.items.len);
            var count: usize = 0;
            for (response.items) |item| {
                if (std.mem.startsWith(u8, item.text, ".resume") or std.mem.eql(u8, item.text, ".cancel") or std.mem.eql(u8, item.text, ".status")) continue;
                items[count] = item;
                count += 1;
            }
            response.items = items[0..count];
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
        const current = (self.console.assist(arena.allocator(), .{ .sql = self.text(), .cursor = @intCast(self.cursor), .generation = self.generation, .mode = .console }) catch |err| {
            if (Console.denied(err)) self.erasePrivate() else self.dismiss();
            return err;
        });
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
            const meta = Console.isMeta(rest);
            const count = if (meta) (std.mem.indexOfScalar(u8, rest, '\n') orelse rest.len) else (try input.terminator(rest) orelse break);
            const statement = rest[0..count];
            try self.echo(statement);
            self.history.remember(statement) catch |err| try self.historyFailure(err);
            self.history_position = null;
            if (!try self.console.execute(statement)) return false;
            if (self.console.query_interrupted) {
                // Ctrl-C cancels the submitted draft, including any remaining
                // pasted statements. They must not become a background queue.
                if (self.console.access_lost) {
                    self.console.access_lost = false;
                    self.erasePrivate();
                } else self.remove(0, self.length);
                self.pasting = false;
                return true;
            }
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
    fn echo(self: *Editor, statement: []const u8) !void {
        // Commit the full submitted draft to terminal scrollback before output.
        // Keep stdout exclusively for results, including when it is redirected.
        // Bound escaped code points plus token colors and continuation prompts,
        // including an alternating token or newline at every input byte.
        var storage: [max_bytes * 20 + 64]u8 = undefined;
        var transcript: std.Io.Writer = .fixed(&storage);
        const style = self.console.diagnostic.style;
        try transcript.writeAll("\r\x1b[2K");
        try transcript.writeAll(style.code(.plain));
        try transcript.writeAll("transit> ");
        var syntax = Style.Syntax.init(statement);
        var active: Style.Color = .plain;
        var offset: usize = 0;
        var buffer: [16]u8 = undefined;
        while (offset < statement.len) {
            const length = try std.unicode.utf8ByteSequenceLength(statement[offset]);
            if (statement[offset] == '\n') {
                try transcript.writeAll(style.code(.plain));
                try transcript.writeAll("\n   ...> ");
                active = .plain;
            } else {
                const color = syntax.at(offset);
                if (color != active) try transcript.writeAll(style.code(color));
                active = color;
                try transcript.writeAll(try printable(statement[offset..][0..length], &buffer));
            }
            offset += length;
        }
        try transcript.writeAll(style.code(.plain));
        try transcript.writeByte('\n');
        try Output.write(self.console.init, self.out, transcript.buffered());
    }
    fn loop(self: *Editor) !void {
        try self.draw();
        while (true) {
            const event = Signals.pollByte(100, .raw_terminal) catch |err| {
                if (err != error.ConsoleInterrupted or Signals.terminating()) return err;
                Signals.clear();
                self.clearDraft();
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
                if (err == error.ConsoleInterrupted and self.searching and !Signals.terminating()) {
                    Signals.clear();
                    self.clearDraft();
                    try self.draw();
                    continue;
                }
                if (err == error.ConsoleInterrupted or err == error.InteractiveQueryCancelled or err == error.ConsoleOutputTimeout or err == error.WriteFailed) return err;
                if (self.console.recovery) |file| if (file.failed) return err;
                self.dismiss();
                try self.out.writeAll("\r\x1b[2K");
                try self.console.diagnostic.style.text(self.out, .failure, "error:");
                try self.out.writeByte(' ');
                try self.console.diagnostic.style.text(self.out, .failure, @errorName(err));
                try self.out.writeByte('\n');
            };
            if (!Signals.pending()) try self.draw();
        }
    }
    fn key(self: *Editor, byte: u8) !void {
        if (byte == 27) return self.escape();
        if (self.pasting) {
            if (byte == '\r') return if (self.searching) self.character('\n') else self.insert("\n");
            if (byte < 32 and byte != '\n' and byte != '\t') return error.InvalidSqlEncoding;
            return self.character(byte);
        }
        if (self.searching) switch (byte) {
            18 => return self.beginSearch(),
            9, 10, 13 => return self.finishSearch(true),
            7 => return self.finishSearch(false),
            21 => {
                self.search_length = 0;
                return self.searchHistory(false);
            },
            8, 127 => {
                self.search_length = previous(self.search[0..self.search_length], self.search_length);
                return self.searchHistory(false);
            },
            else => {
                if (byte < 32) return;
                return self.character(byte);
            },
        };
        switch (byte) {
            0 => try self.complete(), // Ctrl-Space
            18 => try self.beginSearch(), // Ctrl-R
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
        for (bytes[1..length]) |*next| next.* = try Signals.readByte(.raw_terminal) orelse return error.InvalidSqlEncoding;
        if (!std.unicode.utf8ValidateSlice(bytes[0..length])) return error.InvalidSqlEncoding;
        if (self.searching) {
            if (self.search_length + length > max_bytes) return error.StatementTooLarge;
            @memcpy(self.search[self.search_length..][0..length], bytes[0..length]);
            self.search_length += length;
            return self.searchHistory(false);
        }
        try self.insert(bytes[0..length]);
    }
    fn escape(self: *Editor) !void {
        var sequence: [12]u8 = undefined;
        var length: usize = 0;
        while (length < sequence.len) {
            const event = try Signals.pollByte(25, .raw_terminal);
            if (event != .byte) break;
            sequence[length] = event.byte;
            length += 1;
            if (length == 1 and event.byte != '[' and event.byte != 'O') {
                if (self.searching) self.finishSearch(false);
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
        if (self.searching) {
            self.finishSearch(length != 0);
            if (length == 0) return;
        }
        if (std.mem.eql(u8, code, "[A") or std.mem.eql(u8, code, "[B")) {
            const up = code[1] == 'A';
            if (self.assistance) |assistance| {
                if (assistance.items.len > 0) self.selected = if (up) (self.selected + assistance.items.len - 1) % assistance.items.len else (self.selected + 1) % assistance.items.len;
            } else self.recall(up) catch |err| {
                if (err != error.ConsoleInterrupted or Signals.terminating()) return err;
                Signals.clear();
                self.clearDraft();
            };
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
        if (self.searching) return self.drawSearch();
        var prefix_buffer: [160]u8 = undefined;
        const prefix = if (self.assistance) |assistance| if (assistance.items.len == 0) "[no completion] > " else try std.fmt.bufPrint(&prefix_buffer, "[{d}/{d} {s}] > ", .{ self.selected + 1, assistance.items.len, assistance.items[self.selected].text }) else if (std.mem.indexOfScalar(u8, self.text(), '\n') != null) "   ...> " else "transit> ";
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
        var syntax = Style.Syntax.init(self.text());
        var active: Style.Color = .plain;
        const style = self.console.diagnostic.style;
        while (i < self.length) {
            const length = try std.unicode.utf8ByteSequenceLength(self.bytes[i]);
            const visible = try printable(self.bytes[i..][0..length], &buffer);
            if (used + visible.len > available) break;
            const color = syntax.at(i);
            if (color != active) try self.out.writeAll(style.code(color));
            active = color;
            try self.out.writeAll(visible);
            i += length;
            used += visible.len;
        }
        try self.out.writeAll(style.code(.plain));
        try self.out.print("\r\x1b[{d}C", .{prefix_length + left_width});
        try Output.write(self.console.init, self.out, "");
    }
    fn drawSearch(self: *Editor) !void {
        const label = if (self.columns < 24) "/" else "search ";
        try self.out.writeAll(self.console.diagnostic.style.code(.plain));
        try self.out.writeAll(label);
        var used: usize = label.len;
        var buffer: [16]u8 = undefined;
        var offset: usize = 0;
        // Show the end of a long search term, keeping all display bytes safe.
        const query = self.search[0..self.search_length];
        var query_start = query.len;
        var query_width: usize = 0;
        while (query_start > 0) {
            const before = previous(query, query_start);
            const visible = try printable(query[before..query_start], &buffer);
            if (query_width + visible.len > self.columns / 3) break;
            query_width += visible.len;
            query_start = before;
        }
        offset = query_start;
        while (offset < query.len) {
            const size = try std.unicode.utf8ByteSequenceLength(query[offset]);
            try self.out.writeAll(try printable(query[offset..][0..size], &buffer));
            offset += size;
        }
        used += query_width;
        const caret = used;
        try self.out.writeAll(" > ");
        used += 3;
        const result = if (self.search_failed) "(no match)" else if (self.history_position == null) "(type to search)" else self.text();
        offset = 0;
        while (offset < result.len) {
            const size = try std.unicode.utf8ByteSequenceLength(result[offset]);
            const visible = try printable(result[offset..][0..size], &buffer);
            if (used + visible.len >= self.columns) break;
            try self.out.writeAll(visible);
            used += visible.len;
            offset += size;
        }
        try self.out.print("\r\x1b[{d}C", .{caret});
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
