//! Console presentation around the existing native v1 query session.
const std = @import("std");
const q = @import("transit_query");
const u = @import("Unified.zig");
const Options = @import("Options.zig");
const Diagnostic = @import("Diagnostic.zig");
const Recovery = @import("Recovery.zig");
const Preferences = @import("Preferences.zig");
const Signals = @import("Signals.zig");
const sql_input = q.fuze.SqlInput;
pub const Config = struct {
    version: u8,
    profile: enum { unified_v1 },
    url: []const u8,
    transport: enum { loopback, tls_system, tls_ca },
    ca_file: ?[]const u8 = null,
    seed_file: []const u8,
    connection: q.UnifiedClient.Connection,
    workspace: q.Workspace.Config,
    request_timeout_ms: u32 = 5000,
    format: Options.Format = .table,
    recovery_file: ?[]const u8 = null,
    execution: enum { interactive, durable } = .interactive,
};
fn localConfig(init: std.process.Init, topology: @import("server/Config.zig"), diagnostic: *Diagnostic) !Config {
    const Installation = @import("server/Installation.zig");
    const allocator = init.arena.allocator();
    const record_path = try std.fs.path.join(allocator, &.{ topology.installation, "installation.json" });
    diagnostic.atFile(record_path);
    const record = @import("server/Files.zig").read(Installation.Record, init.io, allocator, record_path) catch |err| {
        return diagnostic.fail(error.InvalidConfiguration, "cannot read the local installation", if (err == error.FileNotFound)
            "Start transit server --initialize for a new installation, or use --config with a connection YAML file."
        else
            "Check the retained installation record; the console never creates or repairs server state.");
    };
    if (record.version != 1 or !record.complete or !record.genesis_observed) return diagnostic.invalidField("installation", "is not initialized", "Wait for transit server to finish starting.");
    inline for (.{ 0, 1, 4, 5 }) |index| if (record.provision[index] == null or record.provision[index].? == 0) return diagnostic.invalidField("installation", "has incomplete resource identities", null);
    const c = Installation.connectionFrom(record, topology.realm);
    return .{
        .version = 1,
        .profile = .unified_v1,
        .url = try @import("server/Provider.zig").url(allocator, topology.ports.gateway),
        .transport = .loopback,
        .seed_file = "caller.seed",
        .connection = c,
        .workspace = .{ .name = "items", .source = try q.Values.Source.fromNative(allocator, try Installation.tableFor(c).definition(c.resource)), .limits = try q.Values.Limits.fromNative(allocator, Installation.limits) },
        .recovery_file = "console-recovery.json",
    };
}
fn path(allocator: std.mem.Allocator, base: []const u8, relative: []const u8) ![]const u8 {
    if (relative.len == 0 or std.mem.indexOfScalar(u8, relative, 0) != null) return error.InvalidConfiguration;
    return std.fs.path.resolve(allocator, &.{ base, relative });
}
fn validate(config: Config, allocator: std.mem.Allocator, diagnostic: *Diagnostic) !void {
    diagnostic.field = "version";
    if (config.version != 1) return error.UnsupportedConsoleVersion;
    diagnostic.field = "request_timeout_ms";
    if (config.request_timeout_ms == 0 or config.request_timeout_ms > 60000) return error.InvalidRequestTimeout;
    diagnostic.field = "url / transport / ca_file";
    const uri = std.Uri.parse(config.url) catch return error.InvalidEndpoint;
    if (uri.user != null or uri.password != null or uri.query != null or uri.fragment != null or uri.host == null or uri.port == 0) return error.InvalidEndpoint;
    const host = try uri.host.?.toRawMaybeAlloc(allocator);
    const uri_path = try uri.path.toRawMaybeAlloc(allocator);
    if (uri_path.len != 0 and !std.mem.eql(u8, uri_path, "/")) return error.InvalidEndpoint;
    switch (config.transport) {
        .loopback => if (!std.mem.eql(u8, uri.scheme, "http") or !(std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "[::1]")) or config.ca_file != null) return error.InvalidEndpoint,
        .tls_system => if (!std.mem.eql(u8, uri.scheme, "https") or config.ca_file != null) return error.InvalidEndpoint,
        .tls_ca => if (!std.mem.eql(u8, uri.scheme, "https") or config.ca_file == null) return error.InvalidEndpoint,
    }
    inline for (@typeInfo(q.UnifiedClient.Connection).@"struct".field_names) |field| if (@field(config.connection, field) == 0) {
        diagnostic.field = "connection." ++ field;
        return error.InvalidConfiguration;
    };
    diagnostic.field = "workspace.source / connection.resource";
    const source = try config.workspace.source.native(allocator);
    if (source.resource != config.connection.resource) return error.InvalidConfiguration;
    diagnostic.field = "workspace.limits";
    _ = try config.workspace.limits.native();
    diagnostic.field = "workspace.name";
    _ = try q.fuze.Unified.Name.init(config.workspace.name);
    diagnostic.field = null;
}
pub fn run(init: std.process.Init, options: Options.Options, diagnostic: *Diagnostic) !void {
    var preferences = try Preferences.load(init, options, diagnostic);
    while (try connection(init, options, preferences, diagnostic)) |next| preferences = next;
}
fn connection(init: std.process.Init, options: Options.Options, preferences: Preferences, diagnostic: *Diagnostic) !?Preferences {
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    var base: []const u8 = undefined;
    const config = if (preferences.connection) |selected| explicit: {
        diagnostic.atFile(selected);
        const config_path = std.Io.Dir.cwd().realPathFileAlloc(init.io, selected, allocator) catch |err| {
            diagnostic.configurationFailure(err);
            return error.InvalidConfigurationPath;
        };
        base = std.fs.path.dirname(config_path).?;
        break :explicit try @import("Settings.zig").readTyped(Config, init, config_path, diagnostic);
    } else local: {
        const topology = try @import("server/Config.zig").forConsole(init, diagnostic);
        base = topology.installation;
        break :local try localConfig(init, topology, diagnostic);
    };
    validate(config, allocator, diagnostic) catch |err| {
        return switch (err) {
            error.UnsupportedConsoleVersion => diagnostic.invalidField("version", "must be 1", null),
            error.InvalidRequestTimeout => diagnostic.invalidField("request_timeout_ms", "must be an integer from 1 through 60000", null),
            error.InvalidEndpoint => diagnostic.invalidField("url / transport / ca_file", "must select a matching endpoint and trust profile", "Loopback uses http://127.0.0.1 or http://[::1]; TLS uses https. Omit userinfo, query and fragment; tls_ca requires ca_file."),
            else => failure: {
                diagnostic.setFailure(err, "invalid console configuration", "Correct the named field using apps/transit-cli/docs/console.md; connection identities must be nonzero and match the workspace source.");
                break :failure error.InvalidConfiguration;
            },
        };
    };
    var wire = q.wire.Client.init(init.gpa, init.io, std.mem.trimEnd(u8, config.url, "/"));
    defer wire.deinit();
    wire.timeout_ms = config.request_timeout_ms;
    if (config.ca_file) |file| {
        diagnostic.field = "ca_file";
        const now = std.Io.Clock.real.now(init.io);
        wire.http.ca_bundle.addCertsFromFilePathAbsolute(init.gpa, init.io, now, try path(allocator, base, file)) catch |err| {
            diagnostic.setFailure(err, "cannot load the configured CA certificates", "Check ca_file relative to the configuration file, its read permissions and PEM certificates.");
            return error.InvalidConfiguration;
        };
        wire.http.now = now;
    }
    diagnostic.field = "seed_file";
    var client: q.UnifiedClient = .{ .wire = &wire, .connection = config.connection, .key = q.wire.readKey(init.gpa, init.io, try path(allocator, base, config.seed_file)) catch |err| {
        diagnostic.setFailure(err, "cannot load the console signing credential", "Check seed_file relative to the configuration file and its permissions; do not print or paste the seed.");
        return error.InvalidCredentialFile;
    } };
    diagnostic.field = "recovery_file";
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client.key));
    var session: u.Session = .{ .format = if ((preferences.format orelse config.format) == .json) .json else .table, .interrupted = Signals.interrupted };
    defer session.clear();
    var recovery: ?Recovery = if (config.execution == .durable and config.recovery_file != null) try Recovery.open(init, try path(allocator, base, config.recovery_file.?), &client, &session) else null;
    defer if (recovery) |*file| file.close();
    if (recovery) |*file| {
        session.checkpoint_context = file;
        session.checkpoint_fn = Recovery.checkpoint;
        try session.checkpoint();
    }
    // One local signing owner per credential file, even across recovery paths.
    const caller_lock: ?std.Io.File = if (config.execution == .durable) lock: {
        const caller_lock_path = try std.fmt.allocPrint(allocator, "{s}.console.lock", .{try path(allocator, base, config.seed_file)});
        const file = try std.Io.Dir.cwd().createFile(init.io, caller_lock_path, .{ .truncate = false, .permissions = .fromMode(0o600) });
        errdefer file.close(init.io);
        if (!try file.tryLock(init.io, .exclusive)) return error.ConsoleRecoveryInUse;
        break :lock file;
    } else null;
    defer if (caller_lock) |file| file.close(init.io);
    diagnostic.field = null;
    const signals = try Signals.install();
    defer signals.close();
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    const terminal = options.sql == null and options.script == null and try std.Io.File.stdin().isTty(init.io) and try std.Io.File.stderr().isTty(init.io);
    var console: Console = .{ .init = init, .session = &session, .client = &client, .config = config.workspace, .out = &output.interface, .recovery = if (recovery) |*file| file else null, .batch = !terminal, .preferences = preferences, .diagnostic = diagnostic, .interactive = config.execution == .interactive };
    if (options.sql) |sql| {
        if (isMeta(std.mem.trimStart(u8, sql, " \t\r\n"))) return diagnostic.invalidInvocation("-c requires a SQL statement");
        _ = try console.execute(sql);
    } else if (options.script) |file_name| {
        const file = std.Io.Dir.cwd().openFile(init.io, file_name, .{}) catch |err| {
            diagnostic.atFile(file_name);
            diagnostic.configurationFailure(err);
            return error.InvalidConfiguration;
        };
        defer file.close(init.io);
        var buffer: [8192]u8 = undefined;
        var reader = file.reader(init.io, &buffer);
        try console.pipe(&reader.interface);
    } else if (terminal) try @import("Terminal.zig").run(&console) else try console.pipe(null);
    if (console.next_connection) |next| {
        var result = console.preferences;
        result.connection = next;
        result.connection_source = ".connect";
        result.format = if (session.format == .json) .json else .table;
        return result;
    }
    return null;
}
pub fn isMeta(text: []const u8) bool {
    return std.mem.startsWith(u8, text, ".");
}

pub const Console = struct {
    init: std.process.Init,
    session: *u.Session,
    client: *q.UnifiedClient,
    config: q.Workspace.Config,
    out: *std.Io.Writer,
    recovery: ?*Recovery,
    batch: bool,
    preferences: Preferences,
    diagnostic: *Diagnostic,
    next_connection: ?[]const u8 = null,
    had_error: bool = false,
    access_lost: bool = false,
    interactive: bool = false,
    query_running: bool = false,
    active_query: ?u64 = null,
    query_interrupted: bool = false,
    pub fn execute(self: *Console, raw: []const u8) !bool {
        const text = std.mem.trim(u8, raw, " \t\r\n");
        if (text.len == 0) return true;
        if (std.mem.eql(u8, text, ".quit")) return false;
        self.query_interrupted = false;
        defer {
            self.query_running = false;
            self.active_query = null;
        }
        const result: ?anyerror = result: {
            self.perform(text) catch |err| break :result err;
            break :result null;
        };
        if (result) |err| if (denied(err)) {
            self.access_lost = true;
            self.session.cursor = null;
            self.session.complete = false;
        };
        if (self.query_running and Signals.interrupted() and !Signals.terminating() and !(self.recovery != null and self.recovery.?.failed)) {
            self.query_interrupted = true;
            @import("Cancel.zig").interrupt(self) catch |err| {
                const failure = self.queryFailure(if (self.recovery != null and self.recovery.?.failed) error.ConsoleRecoveryWriteFailed else err);
                self.diagnostic.summary = "query cancellation could not be confirmed";
                if (self.batch or Signals.terminating() or failure == error.ConsoleRecoveryWriteFailed) return failure;
                self.diagnostic.emit(self.init.io, failure);
            };
            if (self.batch) return if (self.interactive) self.queryFailure(error.ConsoleInterrupted) else self.diagnostic.fail(error.ConsoleQueryInterrupted, "console query interrupted", null);
            return true;
        }
        if (result) |err| {
            const failure = self.queryFailure(if (self.recovery != null and self.recovery.?.failed) error.ConsoleRecoveryWriteFailed else err);
            if (self.batch or err == error.ConsoleInterrupted or failure == error.ConsoleRecoveryWriteFailed or err == error.ConsoleOutputTimeout) return failure;
            self.diagnostic.emit(self.init.io, failure);
        }
        return self.next_connection == null;
    }
    fn perform(self: *Console, text: []const u8) !void {
        const execution = @import("Execute.zig");
        if (!isMeta(text) and try q.fuze.Sql.parseInspection(text) == null) return if (self.interactive) @import("Interactive.zig").sql(self, text) else execution.sql(self, text);
        if (self.interactive and (std.mem.eql(u8, text, ".resume") or std.mem.startsWith(u8, text, ".resume ") or std.mem.eql(u8, text, ".cancel") or std.mem.eql(u8, text, ".status"))) return error.NoQuery;
        if (std.mem.eql(u8, text, ".resume") or std.mem.startsWith(u8, text, ".resume ")) {
            const id: ?u64 = if (text.len == 7) null else try q.Values.unsigned(std.mem.trim(u8, text[8..], " \t"));
            return execution.recover(self, id);
        }
        var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
        defer arena.deinit();
        const bytes = try self.init.gpa.alloc(u8, 1048576);
        defer {
            std.crypto.secureZero(u8, bytes);
            self.init.gpa.free(bytes);
        }
        var buffered: std.Io.Writer = .fixed(bytes);
        const destination = self.out;
        self.out = &buffered;
        defer self.out = destination;
        if (isMeta(text)) {
            try self.dispatch(text, arena.allocator());
        } else {
            const result = (try q.Workspace.apply(arena.allocator(), self.client, self.config, .{ .inspect = .{ .sql = text } })).inspection;
            if (self.session.format == .json) try self.json(.{ .inspection = result }) else try self.inspection(result);
        }
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try @import("Output.zig").write(self.init, destination, buffered.buffered());
    }
    fn json(self: *Console, value: anytype) !void {
        try std.json.Stringify.value(value, .{ .escape_unicode = true }, self.out);
        try self.out.writeByte('\n');
    }
    fn inspection(self: *Console, result: q.SqlInspection.Result) !void {
        try self.out.print("Configured source: {s} ({s})\nMetadata revision: {d}; policy: {s}\n", .{ result.name, @tagName(result.source_kind), result.resource_revision, result.policy_revision });
        switch (result.details) {
            .description => |value| for (value.columns) |column| try self.out.print("{s}: {s}\n", .{ column.name, @tagName(column.type) }),
            .tables => |names| {
                for (names) |name| try self.out.print("{s}\n", .{name});
                try self.out.print("{d} tables in configured scope\n", .{names.len});
            },
            .explanation => |value| {
                try self.out.writeAll("Proposed plan: ");
                for (value.operators, 0..) |operator, index| {
                    if (index != 0) try self.out.writeAll(" -> ");
                    try self.out.writeAll(@tagName(operator));
                }
                try self.out.writeByte('\n');
                if (value.limit) |limit| try self.out.print("Input limit: {s}\n", .{limit});
                for (value.columns) |column| try self.out.print("{s}: {s}\n", .{ column.name, @tagName(column.type) });
                try self.out.print("Budgets: {s} pages, {s} segments, {s} result bytes\n", .{ value.budgets.pages, value.budgets.segments, value.budgets.result_bytes });
            },
        }
    }
    fn queryFailure(self: *Console, err: anyerror) anyerror {
        self.had_error = true;
        if (err == error.InvalidTimingCommand) return err;
        if (denied(err)) {
            self.access_lost = true;
            self.session.cursor = null;
            self.session.complete = false;
        }
        self.diagnostic.atArgument(null, null);
        self.diagnostic.file = null;
        self.diagnostic.field = null;
        if (self.interactive and err == error.ConsoleInterrupted) {
            self.diagnostic.summary = null;
            self.diagnostic.cause = null;
            self.diagnostic.next = null;
            return error.InteractiveQueryCancelled;
        }
        if (err == error.ConsoleRecoveryRequired) return self.diagnostic.fail(err, "automatic queries require a recovery_file in the console configuration", "This private file retains the query and exact signed intent for recovery.");
        const hint = if (self.session.namespace != null and !self.session.complete) std.fmt.allocPrint(self.init.arena.allocator(), "Query {d} remains saved. Reconnect with the same configuration; use .resume to recover its result or .cancel to request cancellation. Disconnecting does not cancel it.", .{self.session.namespace.?}) catch null else null;
        return self.diagnostic.fail(err, "query could not complete", hint);
    }
    fn dispatch(self: *Console, text: []const u8, allocator: std.mem.Allocator) !void {
        if (self.interactive and std.mem.eql(u8, text, ".help")) {
            if (self.session.format == .table) return self.out.writeAll("SQL: enter a finite SELECT followed by a semicolon.\n.help .tables .schema .mode table|json .timing on|off .connect PATH .show .info .quit\nEach statement gets a fresh snapshot. Ctrl-C or exit cancels active execution.\n");
            return self.json(.{ .commands = [_][]const u8{ "help", "tables", "schema", "mode", "timing", "connect", "show", "info", "quit" }, .sql = "Finite SELECT over a fresh leased snapshot. Exit cancels active execution." });
        }
        if (std.mem.eql(u8, text, ".help") and self.session.format == .table) return self.out.writeAll("SQL: enter a finite SELECT followed by a semicolon.\n.help .tables .schema .mode table|json .timing on|off .connect PATH .show .info .quit\nRecovery: .status .resume [ID] .cancel\nDisconnecting does not cancel accepted work.\n");
        if (std.mem.eql(u8, text, ".help")) return self.json(.{ .commands = @typeInfo(q.Assistance.Meta).@"enum".field_names, .sql = "Finite read-only SELECT; DESCRIBE, SHOW TABLES and EXPLAIN inspect the configured source. SELECT prints verified results; .resume recovers the saved query." });
        if (std.mem.startsWith(u8, text, ".connect ")) {
            if (self.batch) return error.ConnectionSwitchRequiresTerminal;
            if (self.session.pending != null or self.session.input != null or (self.session.namespace != null and !self.session.complete)) return error.UnresolvedSubmission;
            const file = try Preferences.argument(allocator, text[9..]);
            self.next_connection = try self.init.arena.allocator().dupe(u8, file);
            return;
        }
        if (std.mem.eql(u8, text, ".show")) return @import("Show.zig").write(self.out, .{ .connection = self.preferences.connection, .connection_source = self.preferences.connection_source, .url = self.client.wire.url, .format = self.session.format, .format_source = self.preferences.format_source, .timing = self.preferences.timing, .timing_source = self.preferences.timing_source });
        if (std.mem.eql(u8, text, ".timing")) return error.InvalidTimingCommand;
        if (std.mem.startsWith(u8, text, ".timing ") or std.mem.startsWith(u8, text, ".timing\t")) {
            self.preferences.timing = Preferences.onOff(text[8..]) catch return error.InvalidTimingCommand;
            self.preferences.timing_source = ".timing";
            return;
        }
        if (std.mem.eql(u8, text, ".tables")) {
            const description = try q.Workspace.apply(allocator, self.client, self.config, .describe);
            if (self.session.format == .json) return self.json(description);
            return self.out.print("{s}\n", .{self.config.name});
        }
        if (std.mem.startsWith(u8, text, ".mode ")) {
            const format = std.meta.stringToEnum(Options.Format, std.mem.trim(u8, text[6..], " \t")) orelse return error.UnsupportedFormat;
            self.session.format = if (format == .json) .json else .table;
            self.preferences.format_source = ".mode";
            return;
        }
        if (std.mem.eql(u8, text, ".cancel")) {
            if (self.recovery == null) return error.ConsoleRecoveryRequired;
            const id = self.session.namespace orelse return error.NoQuery;
            try u.settle(self.init, self.session, self.client);
            self.session.pending = try self.client.prepare(.{ .cancel = id });
            self.session.length = 0;
            try u.settle(self.init, self.session, self.client);
            const status = (try self.client.status(id)) orelse return error.QueryUploadNotFound;
            if (self.session.format == .json) return self.json(.{ .query = id, .cancellation_requested = true, .phase = status.phase });
            return self.out.print("Query {d}: cancellation requested (status: {s}).\n", .{ id, @tagName(status.phase) });
        }
        if (std.mem.eql(u8, text, ".info")) {
            const id = self.session.namespace;
            const status = if (id) |value| try self.client.status(value) else null;
            if (status != null and status.?.phase == .complete) {
                const page = (try q.Workspace.apply(allocator, self.client, self.config, .{ .page = .{ .namespace = try q.document.JsonValues.decimal(allocator, id.?), .cursor = null } })).page;
                return self.json(.{ .namespace = id, .uncertain = self.session.pending != null, .manifest = page.evidence.manifest });
            }
            return u.command(self.init, self.session, self.client, self.config, text, allocator, self.out);
        }
        if (std.mem.eql(u8, text, ".schema") or std.mem.eql(u8, text, ".sources") or std.mem.eql(u8, text, ".status")) return u.command(self.init, self.session, self.client, self.config, text, allocator, self.out);
        return error.UnknownConsoleCommand;
    }

    fn pipe(self: *Console, source: ?*std.Io.Reader) !void {
        var buffer: [65536]u8 = undefined;
        defer std.crypto.secureZero(u8, &buffer);
        var length: usize = 0;
        while (if (source) |reader| reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => null,
            else => return err,
        } else try Signals.readByte()) |byte| {
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            if (length == buffer.len) return error.ConsoleInputTooLarge;
            buffer[length] = byte;
            length += 1;
            const text = std.mem.trimStart(u8, buffer[0..length], " \t\r\n");
            const meta = isMeta(text);
            if (!meta and text.len > q.fuze.Sql.max_statement_bytes) return error.StatementTooLarge;
            if ((meta and byte == '\n') or (!meta and byte == ';' and try sql_input.terminator(text) != null)) {
                const more = try self.execute(text);
                length = 0;
                if (!more) break;
            } else if (byte == '\n' and !meta and !try sql_input.significant(text)) {
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
            var scan = try sql_input.Scan.init(rest);
            while (try scan.next()) |token| if (!token.closed) return error.IncompleteSqlStatement;
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
    return err == error.AccessDenied or err == error.QueryDenied or err == error.QuerySourceUnavailable or err == error.ResourceUnavailable or err == error.DocumentRetired or err == error.DocumentHistoryGap or err == error.DocumentResyncRequired;
}
