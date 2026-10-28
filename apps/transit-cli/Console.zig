//! Console presentation over the server-owned SQL session API.
const std = @import("std");
const q = @import("transit_query");
const sdk = @import("transit_sql_client");
const api = sdk.protocol;
const Options = @import("Options.zig");
const Diagnostic = @import("Diagnostic.zig");
const Preferences = @import("Preferences.zig");
const Signals = @import("Signals.zig");
const Input = @import("SqlInput.zig");
const sql_input = q.fuze.SqlInput;
pub const Config = struct {
    version: u8,
    endpoint: []const u8,
    account: []const u8 = "local",
    database: []const u8 = "transit",
    source: ?[]const u8 = null,
    authentication: @FieldType(sdk.Client.Config, "authentication") = .peer,
    ca_file: ?[]const u8 = null,
    password_file: ?[]const u8 = null,
    instance: ?api.Instance = null,
    request_timeout_ms: u32 = 30000,
    format: Options.Format = .table,
    display_rows: ?u32 = null,
    fn native(self: Config) sdk.Client.Config {
        var result: sdk.Client.Config = undefined;
        inline for (@typeInfo(sdk.Client.Config).@"struct".field_names) |field| @field(result, field) = @field(self, field);
        return result;
    }
};
fn localConfig(init: std.process.Init, allocator: std.mem.Allocator, diagnostic: *Diagnostic) !Config {
    const installation = (try @import("server/Config.zig").forConsole(init, diagnostic)).installation;
    diagnostic.file = null;
    diagnostic.field = null;
    const location = sdk.Discovery.locate(allocator, init.io, init.environ_map.get("XDG_RUNTIME_DIR"), installation, false) catch |err| return diagnostic.fail(err, "local SQL discovery is unavailable", "Start transit server, or select a remote connection YAML file with --config.");
    const record = sdk.Discovery.read(allocator, init.io, location) catch |err| return diagnostic.fail(err, "cannot discover the local SQL service", "Wait for transit server to be ready, or select a connection YAML file with --config.");
    defer record.deinit();
    return .{ .version = 1, .endpoint = try std.fmt.allocPrint(allocator, "unix:{s}", .{record.value.socket}), .account = try allocator.dupe(u8, record.value.account), .database = try allocator.dupe(u8, record.value.database), .instance = record.value.instance };
}
pub fn run(original: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !void {
    // Cancellation, settlement and the transport deadline nest at most six
    // tasks. Two additional slots cover workers finishing already joined tasks.
    const runtime = try @import("transit_io").Threaded.create(original.gpa, .{
        .workers = 8,
        .task_bytes = 1024 * 1024,
        .environ = original.minimal.environ,
        .argv0 = .init(original.minimal.args),
    });
    defer runtime.destroy();
    var init = original;
    init.io = runtime.io();
    diagnostic.style = @import("Style.zig").detect(init);
    var preferences = try Preferences.load(init, options, diagnostic);
    while (try connection(init, options, preferences, diagnostic)) |next| preferences = next;
}
fn connection(init: std.process.Init, options: Options.Options, preferences: Preferences, diagnostic: *Diagnostic) !?Preferences {
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const parameters = if (options.parameters) |file| Input.read(Input.Parameters, init, a, file) catch |err| {
        diagnostic.atFile(file);
        return diagnostic.invalidFieldCause(err, "parameters", "cannot read SQL parameter input", null);
    } else null;
    var config = if (preferences.connection) |file| blk: {
        diagnostic.atFile(file);
        var value = try @import("Settings.zig").readTyped(Config, init, file, diagnostic);
        const absolute = try std.fs.path.resolve(a, &.{file});
        inline for (.{ "ca_file", "password_file" }) |field| if (@field(value, field)) |path| {
            @field(value, field) = try std.fs.path.resolve(a, &.{ std.fs.path.dirname(absolute).?, path });
        };
        break :blk value;
    } else try localConfig(init, a, diagnostic);
    if (config.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    if (config.display_rows == 0) return diagnostic.invalidField("display_rows", "must be positive or null", null);
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 270000) return diagnostic.invalidField("request_timeout_ms", "must be between 1 and 270000", null);
    var client = sdk.Client.init(init.gpa, init.io, config.native()) catch |err| return diagnostic.invalidFieldCause(err, if (err == error.InvalidSqlEndpoint) "endpoint / authentication" else "ca_file", if (err == error.InvalidSqlEndpoint) "invalid SQL endpoint or authentication policy" else if (err == error.FileNotFound) "cannot load CA certificates: file not found" else "cannot load CA certificates", null);
    defer client.deinit();
    const password = if (config.password_file) |file| std.Io.Dir.cwd().readFileAlloc(init.io, file, init.gpa, .limited(129)) catch |err| return diagnostic.invalidFieldCause(err, "password_file", "cannot read SQL password", null) else null;
    defer if (password) |bytes| {
        std.crypto.secureZero(u8, bytes);
        init.gpa.free(bytes);
    };
    try client.open(config.native(), if (password) |bytes| std.mem.trimEnd(u8, bytes, "\r\n") else null);
    defer {
        client.timeout_ms = @min(client.timeout_ms, 1000);
        if (client.call(.close)) |reply| reply.deinit() else |_| {}
    }
    config.instance = client.instance;
    var control = try sdk.Client.init(init.gpa, init.io, config.native());
    defer control.deinit();
    control.session = client.session;
    control.account = client.account;
    diagnostic.field = null;
    diagnostic.file = null;
    const signals = try Signals.install();
    defer signals.close();
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    const terminal = options.sql == null and options.script == null and try std.Io.File.stdin().isTty(init.io) and try std.Io.File.stderr().isTty(init.io);
    var display: Console.Display = .{ .format = preferences.format orelse config.format };
    var render = try @import("Results.zig").Storage.init(init.gpa);
    defer render.deinit();
    var console: Console = .{ .init = init, .session = &display, .client = &client, .control = &control, .config = config, .password = if (password) |bytes| std.mem.trimEnd(u8, bytes, "\r\n") else null, .out = &output.interface, .batch = !terminal, .preferences = preferences, .diagnostic = diagnostic, .render = &render };
    if (options.sql) |sql| {
        if (isMeta(std.mem.trimStart(u8, sql, " \t\r\n"))) return diagnostic.invalidInvocation("-c requires a SQL statement");
        _ = try console.executeWithParameters(sql, parameters);
    } else if (options.script) |file_name| {
        const file = try std.Io.Dir.cwd().openFile(init.io, file_name, .{});
        defer file.close(init.io);
        var buffer: [8192]u8 = undefined;
        var reader = file.reader(init.io, &buffer);
        try console.pipe(&reader.interface, file_name);
    } else if (terminal) try @import("Terminal.zig").run(&console) else try console.pipe(null, "<stdin>");
    if (console.next_connection) |next| {
        var result = console.preferences;
        result.connection = next;
        result.connection_source = ".connect";
        result.format = display.format;
        return result;
    }
    return null;
}
pub fn isMeta(text: []const u8) bool {
    return std.mem.startsWith(u8, text, ".");
}
pub const Console = struct {
    pub const Display = struct { format: Options.Format };
    init: std.process.Init,
    session: *Display,
    client: *sdk.Client,
    control: *sdk.Client,
    config: Config,
    password: ?[]const u8 = null,
    session_lost: bool = false,
    out: *std.Io.Writer,
    batch: bool,
    preferences: Preferences,
    diagnostic: *Diagnostic,
    render: *@import("Results.zig").Storage,
    next_connection: ?[]const u8 = null,
    had_error: bool = false,
    access_lost: bool = false,
    query_interrupted: bool = false,
    pub fn keepalive(self: *Console) !void {
        if (self.session_lost) return;
        const last = self.client.last_call orelse return;
        if (last.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() < @max(1, self.client.lease_ms / 3)) return;
        const reply = try self.client.call(.touch);
        defer reply.deinit();
        try self.checked(reply.value);
    }
    fn readByte(self: *Console) !?u8 {
        while (true) switch (try Signals.pollByte(100, .stream)) {
            .byte => |value| return value,
            .eof => return null,
            .timeout => try self.keepalive(),
        };
    }
    pub fn json(self: *Console, value: anytype) !void {
        var encoder: std.json.Stringify = .{ .writer = self.out, .options = .{ .escape_unicode = true } };
        try api.Json.write(value, &encoder);
        try self.out.writeByte('\n');
    }
    fn resultJson(self: *Console, value: anytype) !void {
        var buffer: [4096]u8 = undefined;
        var stream = @import("Output.zig").Stream.init(self.init.io, self.out, &buffer);
        var encoder: std.json.Stringify = .{ .writer = &stream.interface, .options = .{ .escape_unicode = true } };
        try @import("ResultJson.zig").write(value, &encoder);
        try stream.interface.writeByte('\n');
        try stream.flush();
    }
    fn checked(self: *Console, reply: api.Response) !void {
        if (reply.result != .err) return;
        const failure = reply.result.err;
        self.diagnostic.envelope = failure.diagnostic;
        self.access_lost = std.mem.eql(u8, &failure.sqlstate, "42501") or std.mem.eql(u8, &failure.sqlstate, "28000");
        self.diagnostic.sqlServiceSummary(failure.code, failure.sqlstate);
        self.diagnostic.next = null;
        return error.SqlServiceError;
    }
    pub fn assist(self: *Console, allocator: std.mem.Allocator, request: q.Assistance.Request) !q.Assistance.Response {
        const reply = try self.client.call(.{ .assist = .{ .text = request.sql, .cursor = request.cursor } });
        defer reply.deinit();
        return self.decodeAssistance(allocator, reply.value, request);
    }
    pub fn decodeAssistance(self: *Console, allocator: std.mem.Allocator, reply: api.Response, request: q.Assistance.Request) !q.Assistance.Response {
        self.checked(reply) catch |err| {
            if (reply.result == .err and std.mem.eql(u8, reply.result.err.code, "SqlSessionExpired")) {
                self.session_lost = true;
                return error.SqlSessionExpired;
            }
            return err;
        };
        if (reply.result != .assistance) return error.InvalidSqlResponse;
        const value = reply.result.assistance;
        if (value.items.len > q.Assistance.max_items or (value.status != .ready and value.items.len != 0)) return error.InvalidSqlResponse;
        if (value.range) |range| {
            if (range.start > range.end or range.end > request.sql.len or !std.unicode.utf8ValidateSlice(request.sql[0..range.start]) or !std.unicode.utf8ValidateSlice(request.sql[0..range.end])) return error.InvalidSqlResponse;
        } else if (value.items.len != 0) return error.InvalidSqlResponse;
        for (value.items) |item| if (item.text.len == 0 or item.text.len > 1030 or item.detail.len > 256 or !std.unicode.utf8ValidateSlice(item.text) or !std.unicode.utf8ValidateSlice(item.detail)) return error.InvalidSqlResponse;
        const items = try allocator.alloc(q.Assistance.Item, value.items.len);
        for (value.items, items) |item, *out| out.* = .{ .text = try allocator.dupe(u8, item.text), .kind = @fromBackingInt(@intCast(@backingInt(item.kind))), .detail = try allocator.dupe(u8, item.detail) };
        return .{ .generation = request.generation, .coverage = @fromBackingInt(@intCast(@backingInt(value.coverage))), .status = @fromBackingInt(@intCast(@backingInt(value.status))), .profile = @fromBackingInt(@intCast(@backingInt(value.profile))), .resource = value.resource, .contract = value.contract, .resource_revision = value.resource_revision, .policy_revision = try allocator.dupe(u8, value.policy_revision), .range = value.range, .items = items };
    }
    pub fn execute(self: *Console, raw: []const u8) !bool {
        return self.executeWithParameters(raw, null);
    }
    pub fn executeWithParameters(self: *Console, raw: []const u8, parameters: ?Input.Parameters) !bool {
        const text = std.mem.trim(u8, raw, " \t\r\n");
        if (text.len == 0) return true;
        if (std.mem.eql(u8, text, ".quit")) return false;
        if (self.session_lost and !isMeta(text)) return self.diagnostic.fail(error.SqlSessionExpired, "SQL session was lost; reconnect before running another statement", "Start a new console or use .connect FILE. Session settings must be selected again.");
        self.query_interrupted = false;
        self.diagnostic.summary = null;
        self.diagnostic.cause = null;
        self.diagnostic.next = null;
        self.diagnostic.sql = null;
        self.diagnostic.envelope = null;
        self.perform(text, parameters) catch |err| {
            self.had_error = true;
            if (self.diagnostic.summary == null) {
                self.diagnostic.summary = "SQL request could not complete";
            }
            if (self.batch or Signals.terminating()) return err;
            self.diagnostic.emit(self.init.io, err);
        };
        try @import("Output.zig").write(self.init, self.out, "");
        self.diagnostic.reportTiming(self.init.io);
        return self.next_connection == null;
    }
    fn perform(self: *Console, text: []const u8, parameters: ?Input.Parameters) !void {
        var arena: std.heap.ArenaAllocator = .init(self.render.scratch.allocator());
        defer arena.deinit();
        const a = arena.allocator();
        if (try Input.commandPath(a, text)) |file| {
            const request = Input.read(Input.Request, self.init, a, file) catch |err| {
                self.diagnostic.atFile(file);
                return self.diagnostic.invalidFieldCause(err, "request", "cannot read SQL request input", null);
            };
            return self.query(request.sql, request.parameters);
        }
        if (isMeta(text)) return self.dispatch(text, a);
        return self.query(text, parameters);
    }
    fn poll(io: std.Io) !void {
        while (!Signals.interrupted()) try io.sleep(.fromMilliseconds(20), .awake);
    }
    fn call(self: *Console, action: api.Action) !sdk.Response {
        const Event = union(enum) { reply: anyerror!sdk.Response, signal: anyerror!void };
        var events: [2]Event = undefined;
        var selection: std.Io.Select(Event) = .init(self.init.io, &events);
        defer while (selection.cancel()) |pending| switch (pending) {
            .reply => |result| {
                if (result) |reply| reply.deinit() else |_| {}
            },
            .signal => {},
        };
        try selection.concurrent(.signal, poll, .{self.init.io});
        try selection.concurrent(.reply, sdk.Client.call, .{ self.client, action });
        switch (try selection.await()) {
            .reply => |reply| return reply,
            .signal => |result| {
                try result;
                self.query_interrupted = true;
                if (!Signals.terminating()) Signals.clear();
                if (action != .execute) self.stopRead();
                return error.ConsoleInterrupted;
            },
        }
    }
    fn cancellationRequested(_: *anyopaque) sdk.Executor.Cancellation.Request {
        return if (Signals.terminating()) .terminate else if (Signals.interrupted()) .cancel else .none;
    }
    fn cancellationAcknowledged(_: *anyopaque) void {
        if (!Signals.terminating()) Signals.clear();
    }
    fn phaseChanged(context: *anyopaque, phase: sdk.Executor.Phase) void {
        const timing: *@import("Timing.zig") = @ptrCast(@alignCast(context));
        timing.enter(switch (phase) {
            .prepare => .prepare,
            .submit => .submit,
            .wait => .wait,
            .fetch => .fetch,
        });
    }
    fn query(self: *Console, text: []const u8, parameters: ?Input.Parameters) !void {
        var timing = @import("Timing.zig").start(self.init, self.preferences.timing);
        timing.interactive = false;
        defer if (timing.finish()) |report| {
            self.diagnostic.timing = report;
        };
        var executor: sdk.Executor = .{
            .client = self.client,
            .control = self.control,
            .config = self.config.native(),
            .password = self.password,
            .cancellation = .{ .context = self, .requested = cancellationRequested, .acknowledge = cancellationAcknowledged },
            .observer = .{ .context = &timing, .changed = phaseChanged },
        };
        defer {
            self.query_interrupted = self.query_interrupted or executor.interrupted;
            self.session_lost = self.session_lost or executor.session_lost;
            self.access_lost = self.access_lost or executor.access_lost;
        }
        const outcome = executor.execute(text, parameters, .{}) catch |err| return if (err == error.ResultCancelled) error.ConsoleInterrupted else err;
        defer outcome.deinit();
        switch (outcome.value) {
            .command => |completion| {
                timing.enter(.render);
                try self.command(completion);
                if (executor.interrupted and self.batch) return self.diagnostic.fail(error.ConsoleInterrupted, "Statement completed before interruption; remaining input was not executed", null);
            },
            .rows => |*result| self.consume(result, &timing) catch |err| return if (err == error.ResultCancelled) error.ConsoleInterrupted else err,
            .unresolved => |unknown| {
                self.diagnostic.summary = if (unknown.reason == .denied) "Permissions prevented confirming the statement outcome" else "Could not confirm whether the statement completed";
                self.diagnostic.next = "Running it again may apply changes twice.";
                if (self.session.format == .json) try self.resultJson(.{ .unresolved = unknown });
                return if (executor.interrupted) error.ConsoleInterrupted else error.SqlOutcomeUnknown;
            },
            .failure => |failure| {
                self.diagnostic.envelope = failure.diagnostic;
                self.diagnostic.sqlServiceSummary(failure.code, failure.sqlstate);
                return error.SqlServiceError;
            },
        }
    }
    fn command(self: *Console, completion: sdk.results.CommandCompletion) !void {
        self.diagnostic.envelope = completion.diagnostic;
        if (self.session.format == .json) try self.resultJson(.{ .completion = completion });
        switch (completion.outcome) {
            .rejected => return self.diagnostic.fail(error.SqlOperationRejected, "Statement was rejected", null),
            .cancelled => return self.diagnostic.fail(error.ConsoleInterrupted, "Statement was cancelled", null),
            .partial => return self.diagnostic.fail(error.SqlOperationPartial, "Statement completed only partially", "Inspect the affected data or settings before making further changes."),
            .applied, .unchanged => {},
        }
        if (self.session.format == .table) {
            try self.out.writeAll("Statement completed.");
            if (completion.counts) |counts| try self.out.print(" Matched {d}; changed {d}.", .{ counts.matched, counts.changed });
            if (completion.pending_restart) try self.out.writeAll(" Some settings require a server restart.");
            try self.out.writeByte('\n');
        }
    }
    fn consume(self: *Console, result: *sdk.results.ResultSet, timing: *@import("Timing.zig")) !void {
        var displayed: u64 = 0;
        const limit: u64 = if (self.config.display_rows) |rows| rows else std.math.maxInt(u64);
        var buffer: [8192]u8 = undefined;
        var stream = @import("Output.zig").Stream.init(self.init.io, self.out, &buffer);
        const out = &stream.interface;
        errdefer {
            if (result.failure()) |failure| self.diagnostic.envelope = failure.diagnostic;
            if (self.diagnostic.summary == null) self.diagnostic.summary = "Query result is incomplete";
            self.diagnostic.next = "The rows already displayed are only a partial result.";
            if (self.session.format == .json) self.resultJson(.{ .complete_coverage = false, .displayed_rows = displayed, .completion = result.completion() }) catch {};
        }
        var arena: std.heap.ArenaAllocator = .init(self.render.scratch.allocator());
        defer arena.deinit();
        var table: ?@import("Results.zig").Table = null;
        defer if (table) |*value| value.deinit();
        if (self.session.format == .json) {
            try self.resultJson(.{ .profile = "sql_result_v1", .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = result.schema }, .observation = result.observation, .complete_coverage = false });
        } else {
            timing.enter(.fetch);
            const window = try sdk.results.Window.readInto(&self.render.window, result, @intCast(@min(32, limit)));
            defer window.deinit();
            timing.enter(.render);
            table = try @import("Results.zig").Table.init(self.render.scratch.allocator(), result.schema, window.rows);
            try table.?.begin(out);
            for (window.rows) |row| {
                try table.?.write(out, row);
                displayed += 1;
            }
            try stream.flush();
        }
        while (displayed < limit) {
            timing.enter(.fetch);
            const row = try result.nextRow() orelse break;
            timing.enter(.render);
            if (table) |*value| try value.write(out, row) else {
                _ = arena.reset(.retain_capacity);
                try @import("Results.zig").logicalRow(arena.allocator(), out, result.schema, row);
            }
            displayed += 1;
            try stream.flush();
        }
        if (displayed == limit and result.progress.consumption != .exhausted) {
            try result.close();
            if (table) |*value| {
                try value.end(out);
                try out.print("{d} rows displayed; display limit reached; incomplete coverage\n", .{displayed});
                if (result.completion()) |complete| try out.print("Verified result count: {d} rows\n", .{complete.rows});
                try stream.flush();
            } else try self.resultJson(.{ .complete_coverage = false, .displayed_rows = displayed, .display_limit = true, .completion = result.completion() });
            return;
        }
        timing.enter(.render);
        const complete = result.completion() orelse return error.SqlResultIncomplete;
        if (table) |*value| {
            try value.end(out);
            try out.print("{d} rows; complete coverage\n", .{complete.rows});
            try stream.flush();
        } else try self.resultJson(.{ .complete_coverage = true, .rows = complete.rows, .displayed_rows = displayed, .observation = result.observation });
    }
    fn stopRead(self: *Console) void {
        const prior = self.control.timeout_ms;
        self.control.timeout_ms = @min(prior, 250);
        defer self.control.timeout_ms = prior;
        if (self.control.call(.{ .cancel = .{ .query = @splat(0) } })) |reply| reply.deinit() else |_| {}
    }
    fn dispatch(self: *Console, text: []const u8, a: std.mem.Allocator) !void {
        if (@import("ExternalEditor.zig").isCommand(text)) {
            const err = if (!std.mem.eql(u8, text, ".edit")) error.InvalidEditCommand else error.EditRequiresTerminal;
            self.diagnostic.summary = @import("ExternalEditor.zig").message(err);
            return err;
        }
        if (std.mem.eql(u8, text, ".help") or std.mem.startsWith(u8, text, ".help ") or std.mem.startsWith(u8, text, ".help\t")) {
            @import("ConsoleHelp.zig").write(self.out, text[5..]) catch |err| {
                if (err == error.UnknownHelpTopic) self.diagnostic.summary = "Unknown help topic. Use .help, .help --all or .help COMMAND.";
                return err;
            };
            return;
        }
        if (std.mem.startsWith(u8, text, ".connect ")) {
            if (self.batch) return error.ConnectionSwitchRequiresTerminal;
            self.next_connection = try self.init.arena.allocator().dupe(u8, try Preferences.argument(a, text[9..]));
            return;
        }
        if (std.mem.eql(u8, text, ".show")) return @import("Show.zig").write(self.out, .{ .connection = self.preferences.connection, .connection_source = self.preferences.connection_source, .endpoint = self.client.endpoint, .format = self.session.format, .format_source = self.preferences.format_source, .timing = self.preferences.timing, .timing_source = self.preferences.timing_source });
        if (std.mem.eql(u8, text, ".timer")) return error.InvalidTimingCommand;
        if (std.mem.startsWith(u8, text, ".timer ") or std.mem.startsWith(u8, text, ".timer\t")) {
            self.preferences.timing = Preferences.onOff(text[7..]) catch return error.InvalidTimingCommand;
            self.preferences.timing_source = ".timer";
            return;
        }
        if (std.mem.startsWith(u8, text, ".mode ")) {
            self.session.format = std.meta.stringToEnum(Options.Format, std.mem.trim(u8, text[6..], " \t")) orelse return error.UnsupportedFormat;
            self.preferences.format_source = ".mode";
            return;
        }
        if (std.mem.eql(u8, text, ".tables")) return self.query("SHOW TABLES", null);
        if (std.mem.startsWith(u8, text, ".schema ")) return self.query(try std.fmt.allocPrint(a, "DESCRIBE {s}", .{text[8..]}), null);
        if (std.mem.eql(u8, text, ".schema")) return self.query("SHOW TABLES", null);
        if (std.mem.eql(u8, text, ".info") or std.mem.eql(u8, text, ".sources")) {
            const reply = try self.call(.context);
            defer reply.deinit();
            try self.checked(reply.value);
            if (reply.value.result != .context) return error.InvalidSqlResponse;
            return self.json(reply.value.result.context);
        }
        return error.UnknownConsoleCommand;
    }
    pub fn sqlFailure(self: *Console, text: []const u8, err: anyerror) anyerror {
        self.diagnostic.sql = q.fuze.SqlDiagnostic.query(text, err, true);
        return err;
    }
    fn pipe(self: *Console, source: ?*std.Io.Reader, source_name: []const u8) !void {
        const Position = @import("InputPosition.zig");
        var position = try Position.init(source_name);
        var cursor: Position.Cursor = .{};
        var buffer: [65536]u8 = undefined;
        defer std.crypto.secureZero(u8, &buffer);
        var length: usize = 0;
        while (if (source) |reader| reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        } else try self.readByte()) |byte| {
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            const byte_position = cursor;
            cursor.advance(byte);
            if (length == buffer.len) return error.ConsoleInputTooLarge;
            buffer[length] = byte;
            length += 1;
            const text = std.mem.trimStart(u8, buffer[0..length], " \t\r\n");
            const meta = isMeta(text);
            if (text.len == 1) position.start = byte_position;
            position.sql = !meta;
            self.diagnostic.input = position;
            if (!meta and text.len > q.fuze.Sql.max_statement_bytes) return self.sqlFailure(text, error.StatementTooLarge);
            if ((meta and byte == '\n') or (!meta and byte == ';' and (sql_input.terminator(text) catch |err| return self.sqlFailure(text, err)) != null)) {
                const more = try self.execute(text);
                position.statement += 1;
                position.completed += 1;
                length = 0;
                if (!more) break;
            } else if (byte == '\n' and !meta and !(sql_input.significant(text) catch |err| return self.sqlFailure(text, err))) {
                var scan = try sql_input.Scan.init(text);
                var closed = true;
                while (try scan.next()) |token| if (!token.closed) {
                    closed = false;
                };
                if (closed) length = 0;
            }
        }
        const rest = std.mem.trim(u8, buffer[0..length], " \t\r\n");
        if (!isMeta(rest)) {
            var scan = sql_input.Scan.init(rest) catch |err| return self.sqlFailure(rest, err);
            while (scan.next() catch |err| return self.sqlFailure(rest, err)) |token| if (!token.closed) return self.sqlFailure(rest, error.InvalidSqlSyntax);
        }
        if (isMeta(rest)) {
            _ = try self.execute(rest);
        } else if (rest.len > 0 and try sql_input.significant(rest)) {
            _ = try self.execute(rest);
        }
        if (self.had_error) return error.ConsoleCommandFailed;
    }
};
pub fn denied(err: anyerror) bool {
    return err == error.AccessDenied or err == error.AuthenticationFailed;
}
