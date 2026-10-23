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
    execution: enum { interactive, captured } = .interactive,
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
pub fn run(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !void {
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
    var console: Console = .{ .init = init, .session = &display, .client = &client, .control = &control, .config = config, .out = &output.interface, .batch = !terminal, .preferences = preferences, .diagnostic = diagnostic };
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
    out: *std.Io.Writer,
    batch: bool,
    preferences: Preferences,
    diagnostic: *Diagnostic,
    next_connection: ?[]const u8 = null,
    had_error: bool = false,
    access_lost: bool = false,
    query_interrupted: bool = false,
    last_token: ?api.Token = null,
    last_operation: ?api.OperationId = null,
    pub fn keepalive(self: *Console) !void {
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
    fn checked(self: *Console, reply: api.Response) !void {
        if (reply.result != .err) return;
        const failure = reply.result.err;
        self.diagnostic.envelope = failure.diagnostic;
        self.access_lost = std.mem.eql(u8, &failure.sqlstate, "42501") or std.mem.eql(u8, &failure.sqlstate, "28000");
        const summary = try std.fmt.allocPrint(self.init.arena.allocator(), "SQL service: {s} ({s})", .{ failure.code, failure.sqlstate });
        self.diagnostic.summary = summary;
        self.diagnostic.next = if (failure.retry == .control or failure.retry == .same_token) "Use .status to inspect the original operation. Repeating SQL submits new work." else null;
        return error.SqlServiceError;
    }
    pub fn assist(self: *Console, allocator: std.mem.Allocator, request: q.Assistance.Request) !q.Assistance.Response {
        const reply = try self.client.call(.{ .assist = .{ .text = request.sql, .cursor = request.cursor } });
        defer reply.deinit();
        try self.checked(reply.value);
        if (reply.value.result != .assistance) return error.InvalidSqlResponse;
        const value = reply.value.result.assistance;
        const items = try allocator.alloc(q.Assistance.Item, value.items.len);
        for (value.items, items) |item, *out| out.* = .{ .text = try allocator.dupe(u8, item.text), .kind = @fromBackingInt(@intCast(@backingInt(item.kind))), .detail = try allocator.dupe(u8, item.detail) };
        return .{ .generation = request.generation, .profile = @fromBackingInt(@intCast(@backingInt(value.profile))), .resource = value.resource, .contract = value.contract, .resource_revision = value.resource_revision, .policy_revision = try allocator.dupe(u8, value.policy_revision), .range = value.range, .items = items };
    }
    pub fn execute(self: *Console, raw: []const u8) !bool {
        return self.executeWithParameters(raw, null);
    }
    pub fn executeWithParameters(self: *Console, raw: []const u8, parameters: ?Input.Parameters) !bool {
        const text = std.mem.trim(u8, raw, " \t\r\n");
        if (text.len == 0) return true;
        if (std.mem.eql(u8, text, ".quit")) return false;
        self.query_interrupted = false;
        self.diagnostic.summary = null;
        self.diagnostic.next = null;
        self.diagnostic.sql = null;
        self.diagnostic.envelope = null;
        self.perform(text, parameters) catch |err| {
            self.had_error = true;
            if (self.diagnostic.summary == null) {
                self.diagnostic.summary = "SQL request could not complete";
                if (self.last_token) |token| self.diagnostic.next = try std.fmt.allocPrint(self.init.arena.allocator(), "Original request token: {s}. Use .status token:{s} after reconnecting. Repeating SQL submits new work.", .{ std.fmt.bytesToHex(token, .lower), std.fmt.bytesToHex(token, .lower) });
            }
            if (self.batch or Signals.terminating()) return err;
            self.diagnostic.emit(self.init.io, err);
        };
        try @import("Output.zig").write(self.init, self.out, "");
        self.diagnostic.reportTiming();
        return self.next_connection == null;
    }
    fn perform(self: *Console, text: []const u8, parameters: ?Input.Parameters) !void {
        var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
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
    fn call(self: *Console, action: api.Action) !std.json.Parsed(api.Response) {
        const Event = union(enum) { reply: anyerror!std.json.Parsed(api.Response), signal: anyerror!void };
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
                if (self.control.call(.{ .cancel = .{ .query = @splat(0) } })) |reply| reply.deinit() else |_| {}
                return error.ConsoleInterrupted;
            },
        }
    }
    fn query(self: *Console, text: []const u8, parameters: ?Input.Parameters) !void {
        var timing = @import("Timing.zig").start(self.init, self.preferences.timing);
        timing.interactive = self.config.execution == .interactive;
        defer {
            if (timing.finish()) |report| self.diagnostic.timing = report;
        }
        var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        var values: []const []const u8 = &.{};
        if (parameters) |bindings| {
            const metadata = try self.call(.{ .prepare = .{ .sql = text } });
            defer metadata.deinit();
            try self.checked(metadata.value);
            if (metadata.value.result != .described) return error.InvalidSqlResponse;
            const described = metadata.value.result.described;
            defer {
                if (self.client.call(.{ .release = described.statement })) |reply| reply.deinit() else |_| {}
            }
            if (described.parameters.len != bindings.len) return error.ParameterCountMismatch;
            const encoded = try a.alloc([]const u8, bindings.len);
            for (bindings, described.parameters, encoded) |binding, descriptor, *out| {
                const kind = try api.Codec.decodeSchema(a, descriptor);
                out.* = try api.Codec.parameter(a, try q.Values.scalar(a, binding, kind), kind);
            }
            values = encoded;
        }
        var token: api.Token = undefined;
        try self.init.io.randomSecure(&token);
        self.last_token = token;
        self.last_operation = null;
        timing.enter(.submit);
        var reply = try self.call(.{ .execute = .{ .sql = text, .parameters = values, .token = token, .captured = self.config.execution == .captured } });
        defer reply.deinit();
        try self.checked(reply.value);
        if (reply.value.result == .operation) {
            var operation = reply.value.result.operation;
            self.last_operation = operation.identity;
            timing.enter(.wait);
            const started = std.Io.Clock.awake.now(self.init.io);
            while (operation.phase != .terminal and operation.phase != .abandoned and !operation.blocked) {
                if (started.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 270000) {
                    try self.showOperation(operation);
                    return error.SqlOperationWaitEnded;
                }
                if (Signals.interrupted()) {
                    self.query_interrupted = true;
                    return error.ConsoleInterrupted;
                }
                try self.init.io.sleep(.fromMilliseconds(25), .awake);
                const status = try self.control.call(.{ .status = .{ .operation = operation.identity } });
                defer status.deinit();
                try self.checked(status.value);
                if (status.value.result != .operation) return error.InvalidSqlResponse;
                operation = status.value.result.operation;
            }
            try self.showOperation(operation);
            if (operation.phase != .terminal) return error.SqlOperationIncomplete;
            if (operation.outcome == .rejected or operation.outcome == .cancelled or operation.outcome == .partial) return error.SqlOperationRejected;
            if (operation.identity.kind != .captured or operation.outcome != .applied) return;
            const result = try self.call(.{ .result = operation.identity });
            reply.deinit();
            reply = result;
            try self.checked(reply.value);
        }
        if (reply.value.result == .completion) {
            self.last_token = null;
            if (self.session.format == .json) return self.json(reply.value.result);
            return self.out.print("{s}\n", .{@tagName(reply.value.result.completion.kind)});
        }
        return self.consume(&reply, &timing);
    }
    fn consume(self: *Console, reply: *std.json.Parsed(api.Response), timing: *@import("Timing.zig")) !void {
        if (reply.value.result != .batch) return error.InvalidSqlResponse;
        self.last_token = null;
        const cursor = reply.value.result.batch.cursor;
        if (self.session.format == .json) {
            var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
            defer arena.deinit();
            const schema = try api.Codec.decodeSchema(arena.allocator(), reply.value.result.batch.schema);
            try self.json(.{ .profile = "sql_session_v1", .schema = q.fuze.LogicalJson.TypeEnvelope{ .definition = q.fuze.Types.definition, .type = schema }, .complete_coverage = false });
        }
        defer {
            if (self.control.call(.{ .close_result = cursor })) |closed| closed.deinit() else |_| {}
        }
        var rows: u64 = 0;
        while (true) {
            const batch = reply.value.result.batch;
            timing.enter(.render);
            try self.render(batch);
            rows += batch.rows.len;
            if (batch.complete) break;
            timing.enter(.fetch);
            const next = try self.call(.{ .fetch = .{ .cursor = cursor, .batch = batch.batch + 1 } });
            reply.deinit();
            reply.* = next;
            try self.checked(reply.value);
            if (reply.value.result != .batch) return error.InvalidSqlResponse;
        }
        if (self.session.format == .json) try self.json(.{ .complete_coverage = true, .rows = rows, .basis = reply.value.result.batch.basis }) else try self.out.print("{d} rows; complete coverage\n", .{rows});
    }
    fn render(self: *Console, batch: api.Batch) !void {
        var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
        defer arena.deinit();
        const a = arena.allocator();
        const schema = try api.Codec.decodeSchema(a, batch.schema);
        if (schema != .structure or batch.rows.len > api.max_rows) return error.InvalidSqlResponse;
        const rows = try a.alloc([]const q.fuze.Types.Values.Cell, batch.rows.len);
        for (batch.rows, rows) |encoded, *row| {
            if (encoded.len != schema.structure.len) return error.InvalidSqlResponse;
            const cells = try a.alloc(q.fuze.Types.Values.Cell, encoded.len);
            for (encoded, schema.structure, cells) |value, field, *cell| cell.* = try api.Codec.decodeCell(a, field, value);
            row.* = cells;
            if (self.session.format == .json) try @import("Results.zig").logicalRow(a, self.out, schema, cells);
        }
        if (self.session.format == .table) {
            if (rows.len == 0) try @import("Results.zig").logicalTable(a, self.out, schema, &.{});
            var offset: usize = 0;
            while (offset < rows.len) : (offset += 8) try @import("Results.zig").logicalTable(a, self.out, schema, rows[offset..@min(offset + 8, rows.len)]);
        }
        try @import("Output.zig").write(self.init, self.out, "");
    }
    fn showOperation(self: *Console, value: api.Operation) !void {
        self.last_token = value.token;
        self.last_operation = value.identity;
        self.diagnostic.envelope = value.diagnostic;
        if (self.session.format == .json) try self.json(.{ .operation = value }) else try self.out.print("Operation {s}:{d}: {s}/{s}; matched {d}, changed {d}; token {s}\n", .{ @tagName(value.identity.kind), value.identity.id, @tagName(value.phase), if (value.outcome) |outcome| @tagName(outcome) else "pending", value.matched, value.changed, std.fmt.bytesToHex(value.token, .lower) });
        try self.out.flush();
    }
    fn target(self: *Console, text: []const u8) !api.Target {
        if (text.len == 0) {
            if (self.last_operation) |id| return .{ .operation = id };
            if (self.last_token) |token| return .{ .token = token };
            return error.NoQuery;
        }
        if (std.mem.startsWith(u8, text, "token:")) {
            var token: api.Token = undefined;
            if (text.len != 38) return error.InvalidSqlToken;
            _ = std.fmt.hexToBytes(&token, text[6..]) catch return error.InvalidSqlToken;
            return .{ .token = token };
        }
        var kind: @FieldType(api.OperationId, "kind") = .table;
        var identifier = text;
        if (std.mem.indexOfScalar(u8, text, ':')) |colon| {
            kind = std.meta.stringToEnum(@FieldType(api.OperationId, "kind"), text[0..colon]) orelse return error.InvalidSqlOperationReference;
            identifier = text[colon + 1 ..];
        }
        return .{ .operation = .{ .account = self.client.account.?, .kind = kind, .id = try std.fmt.parseInt(u64, identifier, 10) } };
    }
    fn dispatch(self: *Console, text: []const u8, a: std.mem.Allocator) !void {
        if (@import("ExternalEditor.zig").isCommand(text)) {
            const err = if (!std.mem.eql(u8, text, ".edit")) error.InvalidEditCommand else error.EditRequiresTerminal;
            self.diagnostic.summary = @import("ExternalEditor.zig").message(err);
            return err;
        }
        if (std.mem.eql(u8, text, ".help") or std.mem.startsWith(u8, text, ".help ")) return @import("ConsoleHelp.zig").write(self, std.mem.trim(u8, text[5..], " \t"));
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
        inline for (.{ "status", "resume", "cancel" }) |command| {
            const prefix = "." ++ command;
            if (std.mem.eql(u8, text, prefix) or std.mem.startsWith(u8, text, prefix ++ " ")) {
                const argument = std.mem.trim(u8, text[prefix.len..], " \t");
                if (comptime std.mem.eql(u8, command, "status")) {
                    if (std.mem.eql(u8, argument, "all") or (argument.len == 0 and self.last_operation == null and self.last_token == null)) {
                        var after: u64 = 0;
                        while (true) {
                            const reply = try self.control.call(.{ .operations = .{ .after = after } });
                            defer reply.deinit();
                            try self.checked(reply.value);
                            if (reply.value.result != .operations) return error.InvalidSqlResponse;
                            for (reply.value.result.operations.entries) |item| try self.showOperation(item);
                            after = reply.value.result.operations.next orelse break;
                        }
                        return;
                    }
                }
                const selected = try self.target(argument);
                const action: api.Action = if (comptime std.mem.eql(u8, command, "status")) .{ .status = selected } else if (comptime std.mem.eql(u8, command, "cancel")) .{ .cancel = selected } else blk: {
                    if (selected == .operation) break :blk .{ .@"resume" = selected.operation };
                    const status = try self.control.call(.{ .status = selected });
                    defer status.deinit();
                    try self.checked(status.value);
                    if (status.value.result != .operation) return error.InvalidSqlResponse;
                    break :blk .{ .@"resume" = status.value.result.operation.identity };
                };
                const reply = try self.control.call(action);
                defer reply.deinit();
                try self.checked(reply.value);
                if (reply.value.result != .operation) return error.InvalidSqlResponse;
                try self.showOperation(reply.value.result.operation);
                if (comptime std.mem.eql(u8, command, "resume")) {
                    const operation = reply.value.result.operation;
                    if (operation.identity.kind == .captured and operation.outcome == .applied) {
                        var result = try self.call(.{ .result = operation.identity });
                        defer result.deinit();
                        try self.checked(result.value);
                        var timing = @import("Timing.zig").start(self.init, self.preferences.timing);
                        try self.consume(&result, &timing);
                    }
                }
                return;
            }
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
    return err == error.AccessDenied or err == error.AuthenticationFailed or err == error.SqlServiceError;
}
