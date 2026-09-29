//! Console presentation around the existing native v2 query session.
const std = @import("std");
const q = @import("transit_query");
const u = @import("Unified.zig");
const Options = @import("Options.zig");
const Diagnostic = @import("Diagnostic.zig");
const Recovery = @import("Recovery.zig");
const Signals = @import("Signals.zig");
const sql_input = q.fuze.SqlInput;
pub const Config = struct {
    version: u8,
    profile: enum { unified_v2 },
    url: []const u8,
    transport: enum { loopback, tls_system, tls_ca },
    ca_file: ?[]const u8 = null,
    seed_file: []const u8,
    connection: q.UnifiedClient.Connection,
    workspace: q.Workspace.Config,
    request_timeout_ms: u32 = 5000,
    format: Options.Format = .table,
    recovery_file: ?[]const u8 = null,
};
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
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    diagnostic.atFile(options.path.?);
    const config_path = std.Io.Dir.cwd().realPathFileAlloc(init.io, options.path.?, init.arena.allocator()) catch |err| {
        diagnostic.setFailure(err, "cannot locate the console configuration file", "Check --config or TRANSIT_CONSOLE_CONFIG; use the console_config path emitted by the ready server.");
        return error.InvalidConfigurationPath;
    };
    const base = std.fs.path.dirname(config_path).?;
    const config = try diagnostic.readJson(Config, init, config_path, 65536);
    validate(config, allocator, diagnostic) catch |err| {
        diagnostic.setFailure(err, "invalid console configuration", switch (err) {
            error.UnsupportedConsoleVersion => "Use console configuration version 1.",
            error.InvalidRequestTimeout => "Set request_timeout_ms to an integer from 1 through 60000.",
            error.InvalidEndpoint => "Match url, transport and ca_file: loopback uses http://127.0.0.1 or http://[::1]; TLS uses https. Omit userinfo, query and fragment; tls_ca requires ca_file.",
            else => "Correct the named field using apps/transit-cli/docs/console.md; connection identities must be nonzero and match the workspace source.",
        });
        return error.InvalidConfiguration;
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
    var session: u.Session = .{ .format = if ((options.format orelse config.format) == .json) .json else .table, .interrupted = Signals.interrupted };
    defer session.clear();
    var recovery: ?Recovery = if (config.recovery_file) |file| try Recovery.open(init, try path(allocator, base, file), &client, &session) else null;
    defer if (recovery) |*file| file.close();
    if (recovery) |*file| {
        session.checkpoint_context = file;
        session.checkpoint_fn = Recovery.checkpoint;
        try session.checkpoint();
    }
    diagnostic.field = null;
    const signals = try Signals.install();
    defer signals.close();
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    var console: Console = .{ .init = init, .session = &session, .client = &client, .config = config.workspace, .out = &output.interface, .recovery = if (recovery) |*file| file else null };
    if (try std.Io.File.stdin().isTty(init.io) and try std.Io.File.stderr().isTty(init.io)) {
        try @import("Terminal.zig").run(&console);
    } else try console.pipe();
}
pub const Console = struct {
    init: std.process.Init,
    session: *u.Session,
    client: *q.UnifiedClient,
    config: q.Workspace.Config,
    out: *std.Io.Writer,
    recovery: ?*Recovery,
    had_error: bool = false,
    access_lost: bool = false,
    pub fn execute(self: *Console, raw: []const u8) !bool {
        const text = std.mem.trim(u8, raw, " \t\r\n");
        if (text.len == 0) return true;
        if (std.mem.eql(u8, text, "/quit")) return false;
        var arena: std.heap.ArenaAllocator = .init(self.init.gpa);
        defer arena.deinit();
        // Keep one command's bounded presentation private until interruption
        // and persistence checks finish. Native receipts are checkpointed at
        // acceptance independently of whether this stdout write succeeds.
        const bytes = try self.init.gpa.alloc(u8, 1048576);
        defer {
            std.crypto.secureZero(u8, bytes);
            self.init.gpa.free(bytes);
        }
        var buffered: std.Io.Writer = .fixed(bytes);
        const destination = self.out;
        self.out = &buffered;
        defer self.out = destination;
        self.dispatch(text, arena.allocator()) catch |err| {
            if (err == error.ConsoleInterrupted) return err;
            if (self.recovery) |file| if (file.failed) return error.ConsoleRecoveryWriteFailed;
            if (Signals.interrupted()) return error.ConsoleInterrupted;
            self.had_error = true;
            // Pending intent is recovery state. It survives denial; rows and
            // metadata are command-local and have no retained offline cache.
            if (denied(err)) {
                self.access_lost = true;
                self.session.cursor = null;
                self.session.complete = false;
            }
            try self.json(.{ .err = @errorName(err), .uncertain = self.session.pending != null });
        };
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try self.session.checkpoint();
        try @import("Output.zig").write(self.init, destination, buffered.buffered());
        return true;
    }
    fn json(self: *Console, value: anytype) !void {
        try std.json.Stringify.value(value, .{}, self.out);
        try self.out.writeByte('\n');
    }
    fn dispatch(self: *Console, text: []const u8, allocator: std.mem.Allocator) !void {
        if (std.mem.eql(u8, text, "/help")) return self.json(.{ .commands = @typeInfo(q.Assistance.Meta).@"enum".field_names, .sql = "Finite read-only SELECT; /new ID then SQL terminated by semicolon. /next reads one verified page. Disconnect never cancels." });
        if (std.mem.startsWith(u8, text, "/format ")) {
            const format = std.meta.stringToEnum(Options.Format, text[8..]) orelse return error.UnsupportedFormat;
            self.session.format = if (format == .json) .json else .table;
            return self.json(.{ .format = format });
        }
        return u.command(self.init, self.session, self.client, self.config, if (std.mem.eql(u8, text, "/tables")) "/sources" else text, allocator, self.out);
    }
    fn pipe(self: *Console) !void {
        var buffer: [65536]u8 = undefined;
        defer std.crypto.secureZero(u8, &buffer);
        var length: usize = 0;
        while (try Signals.readByte()) |byte| {
            if (length == buffer.len) return error.ConsoleInputTooLarge;
            buffer[length] = byte;
            length += 1;
            const text = std.mem.trimStart(u8, buffer[0..length], " \t\r\n");
            const meta = std.mem.startsWith(u8, text, "/") and !std.mem.startsWith(u8, text, "/*");
            if (!meta and text.len > q.fuze.Sql.max_statement_bytes) return error.StatementTooLarge;
            if ((meta and byte == '\n') or (!meta and byte == ';' and try sql_input.terminator(text) != null)) {
                if (!try self.execute(text)) break;
                length = 0;
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
        if (std.mem.startsWith(u8, rest, "/") and !std.mem.startsWith(u8, rest, "/*")) {
            _ = try self.execute(rest);
        } else if (rest.len > 0) {
            var scan = try sql_input.Scan.init(rest);
            while (try scan.next()) |token| if (token.kind != .space and (token.kind != .comment or (!token.closed and std.mem.startsWith(u8, rest[token.start..], "/*")))) return error.IncompleteSqlStatement;
        }
        if (self.had_error) return error.ConsoleCommandFailed;
    }
};
pub fn denied(err: anyerror) bool {
    return err == error.AccessDenied or err == error.QueryDenied or err == error.QuerySourceUnavailable or err == error.ResourceUnavailable or err == error.DocumentRetired or err == error.DocumentHistoryGap or err == error.DocumentResyncRequired;
}
