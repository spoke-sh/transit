//! Linux terminal presentation. SQL and assistance remain native query owners.
const std = @import("std");
const q = @import("transit_query");
const Console = @import("Console.zig");
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const History = @import("History.zig");
const ExternalEditor = @import("ExternalEditor.zig");
const Style = @import("Style.zig");
const Undo = @import("Undo.zig");
const AssistanceRequest = @import("AssistanceRequest.zig");
const input = q.fuze.SqlInput;
const max_bytes = q.fuze.Sql.max_statement_bytes;
const prompt = "transit> ";
const continuation_prompt = "    ...> ";
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
    raw.cc[@backingInt(std.c.V.SUSP)] = 0; // Ctrl-Z belongs to draft undo.
    raw.cc[@backingInt(std.c.V.QUIT)] = 0;
    if (std.c.tcsetattr(0, .NOW, &raw) != 0) return error.TerminalSetupFailed;
    defer _ = std.c.tcsetattr(0, .NOW, &original);
    var output_buffer: [2048]u8 = undefined;
    var output = std.Io.File.stderr().writerStreaming(console.init.io, &output_buffer);
    var editor: Editor = .{ .console = console, .out = &output.interface, .arena = .init(console.init.gpa), .history = .{ .io = console.init.io, .allocator = console.init.gpa }, .cooked = original, .acquisition = .{ .client = console.client, .io = console.init.io } };
    defer {
        editor.erasePrivate();
        editor.history.close();
        editor.arena.deinit();
    }
    editor.history.open(console.init.environ_map.get("HOME")) catch |err| try editor.historyFailure(err);
    try output.interface.writeAll("Transit\nEnd SQL with a semicolon. .help lists commands.\nTab completes; Ctrl-R searches history; Esc clears; Ctrl-Z undoes.\n\x1b[?2004h");
    try Output.write(console.init, &output.interface, "");
    defer {
        Signals.clear(); // Restore display modes even after the handled signal.
        editor.clearDisplay() catch {};
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
    journal: Undo = .{},
    undo_chord: bool = false,
    vertical_column: ?usize = null,
    paste_cr: bool = false,
    queued_before_prompt: usize = 0,
    input_was_queued: bool = false,
    history: History,
    cooked: std.c.termios,
    history_position: ?u64 = null,
    draft: [max_bytes]u8 = undefined,
    draft_length: usize = 0,
    draft_cursor: usize = 0,
    searching: bool = false,
    search: [max_bytes]u8 = undefined,
    search_length: usize = 0,
    search_failed: bool = false,
    arena: std.heap.ArenaAllocator,
    acquisition: AssistanceRequest,
    assistance: ?q.Assistance.Response = null,
    completing: bool = false,
    local_completion: bool = false,
    unavailable: bool = false,
    accepting: bool = false,
    auto_unique: bool = false,
    refresh_at: i64 = 0,
    started_at: i64 = 0,
    selected: usize = 0,
    detail_page: usize = 0,
    expires: i64 = 0,
    pasting: bool = false,
    columns: usize = 80,
    rows: usize = 24,
    display_cursor_row: usize = 0,
    fn text(self: *Editor) []const u8 {
        return self.bytes[0..self.length];
    }
    fn now(self: *Editor) i64 {
        return std.Io.Clock.boot.now(self.console.init.io).toMilliseconds();
    }
    fn invalidate(self: *Editor) void {
        self.assistance = null;
        _ = self.arena.reset(.free_all);
        self.selected = 0;
        self.detail_page = 0;
        self.accepting = false;
        self.unavailable = false;
    }
    fn dismiss(self: *Editor) void {
        self.acquisition.cancel();
        self.invalidate();
        self.completing = false;
        self.auto_unique = false;
        self.journal.boundary();
    }
    fn changed(self: *Editor) void {
        self.invalidate();
        self.generation +%= 1;
        self.auto_unique = false;
        if (self.completing) self.refresh_at = self.now() + 75;
    }
    fn erasePrivate(self: *Editor) void {
        self.dismiss();
        std.crypto.secureZero(u8, &self.bytes);
        self.journal.clear();
        std.crypto.secureZero(u8, &self.draft);
        std.crypto.secureZero(u8, &self.search);
        self.history.clear();
        self.length = 0;
        self.cursor = 0;
        self.history_position = null;
        self.draft_length = 0;
        self.searching = false;
        self.search_length = 0;
        self.generation +%= 1;
    }
    fn checkpoint(self: *Editor, group: Undo.Group) void {
        if (self.pasting) return;
        if (self.searching) {
            self.journal.save(self.search[0..self.search_length], self.search_length, .search, group);
            return;
        }
        self.installPreview();
        self.journal.save(self.text(), self.cursor, .draft, group);
    }
    fn installPreview(self: *Editor) void {
        if (self.history_position != null and !self.searching) {
            self.journal.save(self.draft[0..self.draft_length], self.draft_cursor, .draft, .atomic);
            self.history_position = null;
        }
    }
    fn undoEdit(self: *Editor) !void {
        self.dismiss();
        self.vertical_column = null;
        if (self.searching) {
            if (self.journal.restore(.search, &self.search)) |value| {
                self.search_length = value.length;
                try self.searchHistory(false);
            }
        } else {
            self.installPreview();
            if (self.journal.restore(.draft, &self.bytes)) |value| {
                self.length = value.length;
                self.cursor = value.cursor;
                self.changed();
            }
        }
    }
    fn insert(self: *Editor, bytes: []const u8) !void {
        if (self.length + bytes.len > max_bytes) return error.StatementTooLarge;
        self.checkpoint(if (word(bytes)) .typing else .atomic);
        self.vertical_column = null;
        std.mem.copyBackwards(u8, self.bytes[self.cursor + bytes.len .. self.length + bytes.len], self.bytes[self.cursor..self.length]);
        @memcpy(self.bytes[self.cursor..][0..bytes.len], bytes);
        self.cursor += bytes.len;
        self.length += bytes.len;
        self.changed();
    }
    fn remove(self: *Editor, start: usize, end: usize) void {
        if (start == end) return;
        self.checkpoint(if (word(self.bytes[start..end])) (if (start < self.cursor) .backspace else .delete) else .atomic);
        self.vertical_column = null;
        std.mem.copyForwards(u8, self.bytes[start..], self.bytes[end..self.length]);
        self.length -= end - start;
        self.cursor = start;
        self.changed();
    }
    fn historyFailure(self: *Editor, err: anyerror) !void {
        self.history.close();
        self.history_position = null;
        try self.clearDisplay();
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
        self.dismiss();
        self.journal.boundary();
        self.vertical_column = null;
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
        self.changed();
    }
    fn searchHistory(self: *Editor, older: bool) !void {
        var before = if (older) self.history_position orelse try self.history.end() else try self.history.end();
        var candidate: [max_bytes]u8 = undefined;
        defer std.crypto.secureZero(u8, &candidate);
        while (try self.history.previous(before, &candidate)) |entry| {
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            if (History.matches(candidate[0..entry.length], self.search[0..self.search_length]) and try self.history.newestOccurrence(entry.position, candidate[0..entry.length])) {
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
    fn searchNewer(self: *Editor) !void {
        var after = self.history_position orelse return;
        var candidate: [max_bytes]u8 = undefined;
        defer std.crypto.secureZero(u8, &candidate);
        while (try self.history.next(after, &candidate)) |entry| {
            if (History.matches(candidate[0..entry.length], self.search[0..self.search_length]) and try self.history.newestOccurrence(entry.position, candidate[0..entry.length])) {
                @memcpy(self.bytes[0..entry.length], candidate[0..entry.length]);
                self.length = entry.length;
                self.cursor = self.length;
                self.history_position = entry.position;
                self.search_failed = false;
                self.changed();
                return;
            }
            after = entry.position;
        }
    }
    fn beginSearch(self: *Editor) !void {
        if (!self.searching) {
            self.dismiss();
            self.installPreview();
            self.journal.boundary();
            self.saveDraft();
            self.searching = true;
            self.search_length = 0;
            self.search_failed = false;
            self.history_position = null;
            self.changed();
            return;
        }
        try self.searchHistory(true);
    }
    fn finishSearch(self: *Editor, accept_match: bool) void {
        if (accept_match and (self.search_failed or self.history_position == null)) return;
        self.journal.discardSearch();
        if (accept_match) {
            self.journal.save(self.draft[0..self.draft_length], self.draft_cursor, .draft, .atomic);
        } else self.restoreDraft();
        self.history_position = null;
        self.searching = false;
        self.search_length = 0;
        self.search_failed = false;
        self.changed();
    }
    fn clearDraft(self: *Editor) void {
        self.dismiss();
        if (self.searching) self.finishSearch(false);
        if (self.length > 0) self.checkpoint(.atomic);
        self.length = 0;
        self.cursor = 0;
        self.searching = false;
        self.search_length = 0;
        self.search_failed = false;
        self.history_position = null;
        self.pasting = false;
        self.undo_chord = false;
        self.queued_before_prompt = 0;
        self.vertical_column = null;
        self.journal.boundary();
        self.changed();
    }
    fn request(self: *Editor) q.Assistance.Request {
        return .{ .sql = self.text(), .cursor = @intCast(self.cursor), .generation = self.generation, .mode = .console };
    }
    fn complete(self: *Editor, unique: bool) !void {
        if (self.acquisition.future != null) return;
        self.dismiss();
        self.completing = true;
        self.auto_unique = unique;
        self.refresh_at = self.now();
        try self.acquire();
    }
    fn acquire(self: *Editor) !void {
        self.started_at = self.now();
        if (try q.Assistance.local(self.arena.allocator(), self.request())) |value| {
            self.local_completion = true;
            self.assistance = .{ .generation = self.generation, .coverage = value.coverage, .status = value.status, .resource = 0, .contract = @splat(0), .resource_revision = 0, .policy_revision = "", .range = value.range, .items = value.items };
            self.expires = self.now() + 5000;
            if (self.auto_unique and value.coverage == .complete and value.items.len == 1) try self.apply();
            return;
        }
        self.local_completion = false;
        try self.acquisition.start(self.request());
    }
    fn assistanceFailure(self: *Editor, err: anyerror) void {
        self.auto_unique = false;
        if (self.console.access_lost or Console.denied(err) or err == error.SqlInstanceChanged or err == error.SqlSessionExpired) {
            self.console.access_lost = false;
            self.erasePrivate();
        } else {
            self.invalidate();
            self.unavailable = true;
        }
    }
    fn tick(self: *Editor) !bool {
        if (!self.completing) return false;
        if (self.acquisition.future != null) {
            const reply = self.acquisition.ready() catch |err| {
                if (self.acquisition.generation == self.generation) self.assistanceFailure(err);
                return true;
            } orelse return self.now() - self.started_at >= 150;
            defer reply.deinit();
            // Do not disclose or insert a response while a newer key is queued.
            if (reply.value.result == .err) {
                _ = self.console.decodeAssistance(self.arena.allocator(), reply.value, self.request()) catch |err| {
                    if (self.console.access_lost or self.acquisition.generation == self.generation) self.assistanceFailure(err);
                    return true;
                };
            }
            if (Signals.pending() or self.acquisition.generation != self.generation) {
                self.invalidate();
                self.auto_unique = false;
                self.refresh_at = self.now() + 75;
                return true;
            }
            var fresh: std.heap.ArenaAllocator = .init(self.console.init.gpa);
            defer fresh.deinit();
            const current = self.console.decodeAssistance(fresh.allocator(), reply.value, self.request()) catch |err| {
                self.assistanceFailure(err);
                return true;
            };
            if (self.accepting) {
                const prior = self.assistance orelse return false;
                const same = current.generation == prior.generation and current.profile == prior.profile and current.resource == prior.resource and current.resource_revision == prior.resource_revision and std.meta.eql(current.range, prior.range) and std.mem.eql(u8, &current.contract, &prior.contract) and std.mem.eql(u8, current.policy_revision, prior.policy_revision);
                const selected = prior.items[self.selected];
                const found = for (current.items) |candidate| {
                    if (std.mem.eql(u8, candidate.text, selected.text) and candidate.kind == selected.kind) break true;
                } else false;
                if (same and found) {
                    try self.apply();
                    return true;
                }
                self.auto_unique = false;
            }
            self.invalidate();
            // Move the whole owned arena only after the old selection is gone.
            self.arena.deinit();
            self.arena = fresh;
            fresh = .init(self.console.init.gpa);
            self.assistance = current;
            self.expires = self.now() + 5000;
            if (self.auto_unique and current.status == .ready and current.coverage == .complete and current.items.len == 1) {
                self.auto_unique = false;
                try self.accept();
            }
            return true;
        }
        if (self.assistance != null and self.now() >= self.expires) {
            self.invalidate();
            self.auto_unique = false;
            self.refresh_at = self.now();
        }
        if (self.assistance == null and !self.unavailable and self.now() >= self.refresh_at) {
            try self.acquire();
            return true;
        }
        return false;
    }
    fn accept(self: *Editor) !void {
        if (!self.completing) return self.complete(true);
        if (self.unavailable) return self.complete(false);
        if (self.acquisition.future != null or self.accepting) return;
        const prior = self.assistance orelse return;
        if (prior.items.len == 0 or prior.range == null) {
            self.dismiss();
            return;
        }
        self.journal.boundary();
        if (self.local_completion) return self.apply();
        self.accepting = true;
        try self.acquisition.start(self.request());
    }
    fn apply(self: *Editor) !void {
        const prior = self.assistance orelse return;
        const range = prior.range orelse return;
        const selected = prior.items[self.selected];
        if (range.start > range.end or range.end > self.length or !std.unicode.utf8ValidateSlice(self.text()[0..range.start]) or !std.unicode.utf8ValidateSlice(self.text()[0..range.end]) or !std.unicode.utf8ValidateSlice(selected.text)) return error.InvalidSqlResponse;
        const length = self.length - (range.end - range.start) + selected.text.len;
        if (length > max_bytes) return error.StatementTooLarge;
        if (self.cursor == range.end and std.mem.eql(u8, self.bytes[range.start..range.end], selected.text)) {
            self.dismiss();
            return;
        }
        self.checkpoint(.atomic);
        var original: [max_bytes]u8 = undefined;
        defer std.crypto.secureZero(u8, &original);
        @memcpy(original[0..self.length], self.text());
        const suffix = original[range.end..self.length];
        @memcpy(self.bytes[range.start..][0..selected.text.len], selected.text);
        @memcpy(self.bytes[range.start + selected.text.len ..][0..suffix.len], suffix);
        self.length = length;
        self.cursor = range.start + selected.text.len;
        self.dismiss();
        self.changed();
    }
    fn submit(self: *Editor) !bool {
        self.dismiss();
        if (!Console.isMeta(std.mem.trimStart(u8, self.text(), " \t\r\n")) and try input.terminator(self.text()) == null) {
            if (self.length > 0) try self.insert("\n");
            return true;
        }
        self.installPreview();
        self.journal.clear();
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
            const more = if (std.mem.eql(u8, std.mem.trim(u8, statement, " \t\r\n"), ".edit")) try self.editExternal() else try self.console.execute(statement);
            if (!more) return false;
            // A bare Esc typed during execution must not clear the next draft.
            // Count queued bytes instead of draining typeahead or interpreting
            // keys inside SQL settlement. All input decoding decrements this cut.
            var queued: c_int = 0;
            if (std.os.linux.ioctl(0, std.os.linux.T.FIONREAD, @intFromPtr(&queued)) == 0) self.queued_before_prompt = @intCast(@max(0, queued));
            if (self.console.query_interrupted) {
                // Ctrl-C cancels the submitted draft, including any remaining
                // pasted statements. They must not become a background queue.
                if (self.console.access_lost) {
                    self.console.access_lost = false;
                    self.erasePrivate();
                } else {
                    self.clearDraft();
                    self.journal.clear();
                }
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
        if (consumed > 0) {
            std.mem.copyForwards(u8, &self.bytes, self.bytes[consumed..self.length]);
            self.length -= consumed;
            self.cursor = self.length;
            self.changed();
        }
        self.journal.clear();
        if (self.length > 0) try self.insert("\n");
        return true;
    }
    fn editExternal(self: *Editor) !bool {
        // A failed editor must not leave an already submitted pasted prefix in
        // the draft, where the next Enter could repeat accepted work.
        errdefer {
            self.clearDraft();
            self.journal.clear();
        }
        self.console.query_interrupted = false;
        var bytes: [max_bytes]u8 = undefined;
        defer std.crypto.secureZero(u8, &bytes);
        const initial = self.history.latestSql(&bytes) catch |err| blk: {
            if (err == error.ConsoleInterrupted) {
                if (Signals.terminating()) return err;
                Signals.clear();
                self.console.query_interrupted = true;
                return true;
            }
            try self.historyFailure(err);
            break :blk try self.history.latestSql(&bytes);
        };
        const edited = ExternalEditor.edit(self.console, self.cooked, self.out, initial, &bytes) catch |err| {
            if (self.console.access_lost) {
                self.console.access_lost = false;
                self.erasePrivate();
            }
            if (err == error.ConsoleInterrupted and !Signals.terminating()) {
                Signals.clear();
                self.console.query_interrupted = true;
                return true;
            }
            return err;
        } orelse return true;
        try self.echo(edited);
        self.history.remember(edited) catch |err| try self.historyFailure(err);
        return self.console.execute(edited);
    }
    fn echo(self: *Editor, statement: []const u8) !void {
        // Commit the full submitted draft to terminal scrollback before output.
        // Keep stdout exclusively for results, including when it is redirected.
        // Bound escaped code points plus token colors and continuation prompts,
        // including an alternating token or newline at every input byte.
        var storage: [max_bytes * 20 + 64]u8 = undefined;
        var transcript: std.Io.Writer = .fixed(&storage);
        const style = self.console.diagnostic.style;
        try self.clearDisplay();
        try transcript.writeAll("\r\x1b[2K");
        try transcript.writeAll(style.code(.plain));
        try transcript.writeAll(prompt);
        var syntax = Style.Syntax.init(statement);
        var active: Style.Color = .plain;
        var offset: usize = 0;
        var buffer: [16]u8 = undefined;
        while (offset < statement.len) {
            const length = try std.unicode.utf8ByteSequenceLength(statement[offset]);
            if (statement[offset] == '\n') {
                try transcript.writeAll(style.code(.plain));
                try transcript.writeByte('\n');
                try transcript.writeAll(continuation_prompt);
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
            const event = self.pollByte(25) catch |err| {
                if (err != error.ConsoleInterrupted or Signals.terminating()) return err;
                Signals.clear();
                self.clearDraft();
                try self.draw();
                continue;
            };
            if (event == .timeout) {
                const redraw = self.tick() catch |err| blk: {
                    self.assistanceFailure(err);
                    break :blk true;
                };
                if (self.acquisition.future == null) self.console.keepalive() catch |err| {
                    self.erasePrivate();
                    return err;
                };
                const size = dimensions();
                if (redraw or size.columns != self.columns or size.rows != self.rows) try self.draw();
                continue;
            }
            if (event == .eof) {
                if (self.length > 0) return error.IncompleteSqlStatement;
                return;
            }
            self.key(event.byte) catch |err| {
                if (err == error.ConsoleQuit) return;
                if (err == error.ConsoleInterrupted and !Signals.terminating()) {
                    Signals.clear();
                    self.clearDraft();
                    try self.draw();
                    continue;
                }
                if (err == error.ConsoleInterrupted or err == error.InteractiveQueryCancelled or err == error.ConsoleOutputTimeout or err == error.WriteFailed) return err;
                self.dismiss();
                try self.clearDisplay();
                try self.console.diagnostic.style.text(self.out, .failure, "error:");
                try self.out.writeByte(' ');
                try self.console.diagnostic.style.text(self.out, .failure, ExternalEditor.message(err) orelse @errorName(err));
                try self.out.writeByte('\n');
            };
            if (!Signals.pending()) try self.draw();
        }
    }
    fn pollByte(self: *Editor, timeout: c_int) !Signals.Input {
        const event = try Signals.pollByte(timeout, .raw_terminal);
        if (event == .byte) {
            self.input_was_queued = self.queued_before_prompt > 0;
            self.queued_before_prompt -|= 1;
        }
        return event;
    }
    fn readByte(self: *Editor) !?u8 {
        while (true) switch (try self.pollByte(100)) {
            .byte => |byte| return byte,
            .eof => return null,
            .timeout => {},
        };
    }
    fn key(self: *Editor, byte: u8) !void {
        if (byte == 27) return self.escape();
        if (self.pasting) {
            if (byte == '\n' and self.paste_cr) {
                self.paste_cr = false;
                return;
            }
            self.paste_cr = byte == '\r';
            if (byte == '\r') return self.character('\n');
            if (byte < 32 and byte != '\n' and byte != '\t') return error.InvalidSqlEncoding;
            return self.character(byte);
        }
        const chord = self.undo_chord;
        self.undo_chord = false;
        if (chord and byte == 21) return self.undoEdit();
        if (byte == 24) {
            self.undo_chord = true;
            self.journal.boundary();
            return;
        }
        if (byte == 26 or byte == 31) return self.undoEdit();
        if (self.searching) switch (byte) {
            18, 16 => return self.beginSearch(),
            14 => return self.searchNewer(),
            9, 10, 13 => return self.finishSearch(true),
            7 => return self.finishSearch(false),
            21 => {
                self.checkpoint(.atomic);
                self.search_length = 0;
                return self.searchHistory(false);
            },
            8, 127 => {
                if (self.search_length == 0) return;
                self.checkpoint(.backspace);
                self.search_length = previous(self.search[0..self.search_length], self.search_length);
                return self.searchHistory(false);
            },
            else => {
                if (byte < 32) return;
                return self.character(byte);
            },
        };
        switch (byte) {
            0 => try self.complete(true),
            18 => try self.beginSearch(),
            16 => try self.recall(true),
            14 => try self.recall(false),
            7 => {
                self.dismiss();
                self.journal.boundary();
            },
            4 => {
                if (self.length == 0) return error.ConsoleQuit;
                return error.IncompleteSqlStatement;
            },
            9 => try self.accept(),
            10, 13 => {
                if (self.completing) {
                    if (self.assistance != null and self.acquisition.future == null) try self.accept() else self.dismiss();
                } else if (!try self.submit()) return error.ConsoleQuit;
            },
            1 => self.move(0),
            5 => self.move(self.length),
            21 => {
                self.journal.boundary();
                self.remove(0, self.cursor);
                self.journal.boundary();
            },
            8, 127 => if (self.cursor > 0) self.remove(previous(self.text(), self.cursor), self.cursor),
            else => {
                if (byte < 32) return error.InvalidSqlEncoding;
                try self.character(byte);
            },
        }
    }
    fn move(self: *Editor, cursor: usize) void {
        self.cursor = cursor;
        self.vertical_column = null;
        self.journal.boundary();
        self.changed();
    }
    fn character(self: *Editor, byte: u8) !void {
        const length = std.unicode.utf8ByteSequenceLength(byte) catch return error.InvalidSqlEncoding;
        var bytes: [4]u8 = undefined;
        bytes[0] = byte;
        for (bytes[1..length]) |*next| next.* = try self.readByte() orelse return error.InvalidSqlEncoding;
        if (!std.unicode.utf8ValidateSlice(bytes[0..length])) return error.InvalidSqlEncoding;
        if (self.searching) {
            if (self.search_length + length > max_bytes) return error.StatementTooLarge;
            self.checkpoint(if (word(bytes[0..length])) .typing else .atomic);
            @memcpy(self.search[self.search_length..][0..length], bytes[0..length]);
            self.search_length += length;
            return self.searchHistory(false);
        }
        try self.insert(bytes[0..length]);
    }
    fn escape(self: *Editor) !void {
        const queued_during_execution = self.input_was_queued;
        self.undo_chord = false;
        self.journal.boundary();
        var sequence: [32]u8 = undefined;
        var length: usize = 0;
        while (length < sequence.len) {
            const event = try self.pollByte(if (length == 0) 50 else 250);
            if (event != .byte) break;
            sequence[length] = event.byte;
            length += 1;
            if (length == 1 and event.byte != '[' and event.byte != 'O') return;
            if (length > 1 and event.byte >= 0x40 and event.byte <= 0x7e) break;
        }
        const code = sequence[0..length];
        if (std.mem.eql(u8, code, "[201~")) {
            self.pasting = false;
            self.paste_cr = false;
            self.journal.boundary();
            return;
        }
        if (self.pasting) return error.InvalidSqlEncoding;
        if (std.mem.eql(u8, code, "[200~")) {
            self.checkpoint(.atomic);
            self.pasting = true;
            self.paste_cr = false;
            self.dismiss();
            return;
        }
        if (length == 0) {
            if (queued_during_execution) return;
            self.clearDraft();
            return;
        }
        const up = std.mem.eql(u8, code, "[A") or std.mem.eql(u8, code, "OA");
        const down = std.mem.eql(u8, code, "[B") or std.mem.eql(u8, code, "OB");
        if (self.searching) {
            if (up) try self.searchHistory(true) else if (down) try self.searchNewer();
            return;
        }
        if (self.completing and (std.mem.eql(u8, code, "[5~") or std.mem.eql(u8, code, "[6~"))) {
            self.detail_page = if (code[1] == '5') self.detail_page -| 1 else @min(2048, self.detail_page + 1);
        } else if (std.mem.eql(u8, code, "[Z")) {
            if (!self.completing) try self.complete(false) else self.select(true);
        } else if (up or down) {
            if (self.completing) self.select(up) else try self.vertical(up);
        } else if (std.mem.eql(u8, code, "[D") or std.mem.eql(u8, code, "OD")) {
            self.move(previous(self.text(), self.cursor));
        } else if (std.mem.eql(u8, code, "[C") or std.mem.eql(u8, code, "OC")) {
            if (self.cursor < self.length) self.move(self.cursor + try std.unicode.utf8ByteSequenceLength(self.bytes[self.cursor]));
        } else if (std.mem.eql(u8, code, "[H") or std.mem.eql(u8, code, "OH") or std.mem.eql(u8, code, "[1~")) {
            self.move(0);
        } else if (std.mem.eql(u8, code, "[F") or std.mem.eql(u8, code, "OF") or std.mem.eql(u8, code, "[4~")) {
            self.move(self.length);
        } else if (std.mem.eql(u8, code, "[3~")) {
            if (self.cursor < self.length) self.remove(self.cursor, self.cursor + try std.unicode.utf8ByteSequenceLength(self.bytes[self.cursor]));
        }
        // Unknown/truncated escape sequences never become a clear action.
    }
    fn select(self: *Editor, up: bool) void {
        self.detail_page = 0;
        if (self.accepting) return;
        const assistance = self.assistance orelse return;
        if (assistance.items.len > 0) self.selected = if (up) (self.selected + assistance.items.len - 1) % assistance.items.len else (self.selected + 1) % assistance.items.len;
    }
    fn vertical(self: *Editor, up: bool) !void {
        const size = dimensions();
        const available = size.columns - @min(prompt.len, size.columns / 2) - 1;
        var positions: [max_bytes + 1]struct { row: usize, column: usize } = undefined;
        var row: usize = 0;
        var column: usize = 0;
        var offset: usize = 0;
        var buffer: [16]u8 = undefined;
        while (offset < self.length) {
            const length = try std.unicode.utf8ByteSequenceLength(self.bytes[offset]);
            const visible = try displayCharacter(self.bytes[offset..][0..length], &buffer, available);
            const newline = self.bytes[offset] == '\n';
            if (!newline and column + visible.len > available) {
                row += 1;
                column = 0;
            }
            positions[offset] = .{ .row = row, .column = column };
            if (newline) {
                row += 1;
                column = 0;
            } else column += visible.len;
            offset += length;
        }
        positions[self.length] = .{ .row = row, .column = column };
        const at = positions[self.cursor];
        if (up and at.row == 0 or !up and at.row == row) return self.recall(up);
        const target = if (up) at.row - 1 else at.row + 1;
        const goal = self.vertical_column orelse at.column;
        var chosen = self.cursor;
        offset = 0;
        while (offset <= self.length) {
            const position = positions[offset];
            if (position.row == target and position.column <= goal) chosen = offset;
            if (offset == self.length) break;
            offset += try std.unicode.utf8ByteSequenceLength(self.bytes[offset]);
        }
        self.move(chosen);
        self.vertical_column = goal;
    }
    fn dimensions() struct { columns: usize, rows: usize } {
        var size: std.c.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
        if (std.os.linux.ioctl(2, std.os.linux.T.IOCGWINSZ, @intFromPtr(&size)) != 0) return .{ .columns = 80, .rows = 24 };
        return .{ .columns = if (size.col == 0) 80 else @max(8, @min(160, size.col)), .rows = if (size.row == 0) 24 else size.row };
    }
    fn clearDisplay(self: *Editor) !void {
        try self.out.writeByte('\r');
        if (self.display_cursor_row > 0) try self.out.print("\x1b[{d}A", .{self.display_cursor_row});
        try self.out.writeAll("\x1b[J");
        self.display_cursor_row = 0;
    }
    fn draw(self: *Editor) !void {
        const size = dimensions();
        self.columns = size.columns;
        self.rows = size.rows;
        try self.clearDisplay();
        // A tall draft must not flush stderr outside the output deadline.
        var storage: [2048]u8 = undefined;
        var frame = Output.Stream.init(self.console.init.io, self.out, &storage);
        const result = if (self.searching) self.drawSearch(&frame.interface) else self.drawDraft(&frame.interface);
        result catch |err| return frame.failure orelse err;
        try frame.flush();
    }
    fn drawDraft(self: *Editor, out: *std.Io.Writer) !void {
        const prefix = prompt;
        const prefix_length = @min(prefix.len, self.columns / 2);
        // Explicit row breaks avoid terminal autowrap and leave a cursor cell
        // at the right edge. Layout is bounded by the existing statement limit.
        const available = self.columns - prefix_length - 1;
        var lines: [max_bytes + 1]struct { start: usize, end: usize } = undefined;
        var count: usize = 0;
        var start: usize = 0;
        var used: usize = 0;
        var offset: usize = 0;
        var cursor_row: usize = 0;
        var cursor_column: usize = 0;
        var buffer: [16]u8 = undefined;
        while (offset < self.length) {
            const length = try std.unicode.utf8ByteSequenceLength(self.bytes[offset]);
            const newline = self.bytes[offset] == '\n';
            const visible = try displayCharacter(self.bytes[offset..][0..length], &buffer, available);
            if (!newline and used + visible.len > available) {
                lines[count] = .{ .start = start, .end = offset };
                count += 1;
                start = offset;
                used = 0;
            }
            if (offset == self.cursor) {
                cursor_row = count;
                cursor_column = used;
            }
            if (newline) {
                lines[count] = .{ .start = start, .end = offset };
                count += 1;
                start = offset + length;
                used = 0;
            } else used += visible.len;
            offset += length;
        }
        lines[count] = .{ .start = start, .end = self.length };
        if (self.cursor == self.length) {
            cursor_row = count;
            cursor_column = used;
        }
        count += 1;
        // Keep the cursor visible even when the draft exceeds the screen.
        // One spare terminal row lets redraws scroll without losing the origin.
        const menu_rows = self.menuRows();
        const visible_rows = @min(count, @max(1, self.rows -| (1 + menu_rows)));
        const first = @min(cursor_row -| (visible_rows / 2), count - visible_rows);
        var syntax = Style.Syntax.init(self.text());
        var active: Style.Color = .plain;
        const style = self.console.diagnostic.style;
        for (lines[first..][0..visible_rows], first..) |line, row| {
            if (row > first) try out.writeAll("\r\n");
            try out.writeAll(style.code(.plain));
            active = .plain;
            if (row == 0) {
                // Suggestions are grammar/catalog identifiers; still escape controls.
                for (prefix[0..prefix_length]) |byte| try out.writeByte(if (byte >= 32 and byte < 127) byte else '?');
            } else {
                const continuation = continuation_prompt;
                if (prefix_length > continuation.len) try out.splatByteAll(' ', prefix_length - continuation.len);
                try out.writeAll(continuation[continuation.len - @min(prefix_length, continuation.len) ..]);
            }
            offset = line.start;
            while (offset < line.end) {
                const length = try std.unicode.utf8ByteSequenceLength(self.bytes[offset]);
                const color = syntax.at(offset);
                if (color != active) try out.writeAll(style.code(color));
                active = color;
                try out.writeAll(try displayCharacter(self.bytes[offset..][0..length], &buffer, available));
                offset += length;
            }
        }
        try out.writeAll(style.code(.plain));
        self.display_cursor_row = cursor_row - first;
        const below = try self.drawMenu(out, menu_rows);
        const up = visible_rows - 1 + below - self.display_cursor_row;
        if (up > 0) try out.print("\x1b[{d}A", .{up});
        try out.print("\r\x1b[{d}C", .{prefix_length + cursor_column});
    }
    fn menuRows(self: *Editor) usize {
        if (!self.completing or self.rows < 3) return 0;
        const count = if (self.assistance) |value| value.items.len else 0;
        return @min(@max(1, count + 2), @max(1, self.rows / 2));
    }
    fn clipped(out: *std.Io.Writer, text_value: []const u8, width: usize) !void {
        var used: usize = 0;
        var offset: usize = 0;
        var buffer: [16]u8 = undefined;
        while (offset < text_value.len) {
            const size = try std.unicode.utf8ByteSequenceLength(text_value[offset]);
            const visible = try displayCharacter(text_value[offset..][0..size], &buffer, width);
            if (used + visible.len > width) break;
            try out.writeAll(visible);
            used += visible.len;
            offset += size;
        }
    }
    fn drawMenu(self: *Editor, out: *std.Io.Writer, rows: usize) !usize {
        if (rows == 0) return 0;
        const assistance = self.assistance;
        const message: ?[]const u8 = if (self.unavailable) "Completion unavailable; Tab retries" else if (self.accepting) "Checking suggestion..." else if (assistance == null) (if (self.now() - self.started_at >= 150) "Loading suggestions..." else "Suggestions") else if (assistance.?.status == .inside_text) "No completion inside this text" else if (assistance.?.status == .unsupported) "No suggestions for this SQL context" else if (assistance.?.items.len == 0) (if (assistance.?.coverage == .limited) "Limited search; type more to narrow" else "No matching suggestions") else null;
        if (message) |value| {
            try out.writeAll("\r\n");
            try clipped(out, value, self.columns - 1);
            return 1;
        }
        const value = assistance.?;
        var detail_storage: [8192]u8 = undefined;
        var detail: std.Io.Writer = .fixed(&detail_storage);
        const selected = value.items[self.selected];
        try clipped(&detail, selected.text, detail_storage.len);
        try detail.print("  [{s}] ", .{@tagName(selected.kind)});
        try clipped(&detail, selected.detail, detail_storage.len - detail.end);
        const width = self.columns - 1;
        const pages = (detail.end + width - 1) / width;
        self.detail_page = @min(self.detail_page, pages -| 1);
        const part = detail.buffered()[@min(detail.end, self.detail_page * width)..];
        const count = @min(value.items.len, @max(1, rows -| 2));
        const first = @min(self.selected -| (count / 2), value.items.len - count);
        var used: usize = 0;
        for (value.items[first..][0..count], first..) |item, index| {
            try out.writeAll(if (index == self.selected) "\r\n> " else "\r\n  ");
            if (rows == 1 and self.detail_page > 0 and index == self.selected) try out.writeAll(part[0..@min(part.len, self.columns - 3)]) else try clipped(out, item.text, self.columns - 3);
            used += 1;
        }
        if (used < rows) {
            try out.writeAll("\r\n");
            try out.writeAll(part[0..@min(part.len, width)]);
            used += 1;
        }
        if (used < rows) {
            try out.writeAll("\r\n");
            try clipped(out, if (value.coverage == .limited) "Limited list; type more to narrow" else if (pages > 1) "PgUp/PgDn details; Tab/Enter accepts" else "Tab/Enter accepts; Ctrl-G dismisses", width);
            used += 1;
        }
        return used;
    }
    fn drawSearch(self: *Editor, out: *std.Io.Writer) !void {
        const label = if (self.columns < 24) "/" else "search ";
        try out.writeAll(self.console.diagnostic.style.code(.plain));
        try out.writeAll(label);
        const used: usize = label.len;
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
            try out.writeAll(try printable(query[offset..][0..size], &buffer));
            offset += size;
        }
        const caret = used + query_width;
        const result = if (self.search_failed) "(no match)" else if (self.history_position == null) "(type to search)" else self.text();
        if (self.rows >= 3) {
            try out.writeAll(" >");
            try out.writeAll("\r\n");
            var preview_rows: usize = 1;
            var width: usize = 0;
            offset = 0;
            while (offset < result.len) {
                const size = try std.unicode.utf8ByteSequenceLength(result[offset]);
                const visible = try displayCharacter(result[offset..][0..size], &buffer, self.columns - 1);
                const newline = result[offset] == '\n';
                if (newline or width + visible.len >= self.columns) {
                    if (preview_rows >= self.rows - 2) break;
                    try out.writeAll("\r\n");
                    preview_rows += 1;
                    width = 0;
                }
                if (!newline) {
                    try out.writeAll(visible);
                    width += visible.len;
                }
                offset += size;
            }
            try out.print("\x1b[{d}A", .{preview_rows});
        }
        try out.print("\r\x1b[{d}C", .{caret});
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
fn displayCharacter(bytes: []const u8, buffer: []u8, available: usize) ![]const u8 {
    const visible = try printable(bytes, buffer);
    // Very narrow terminals may not fit one escaped Unicode scalar. Preserve
    // its input bytes and cursor boundary while displaying a single safe cell.
    return if (visible.len > available) "?" else visible;
}

fn word(bytes: []const u8) bool {
    for (bytes) |byte| if (byte < 128 and !std.ascii.isAlphanumeric(byte) and byte != '_') return false;
    return bytes.len > 0;
}
