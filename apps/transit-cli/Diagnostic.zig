//! CLI diagnostics. Never capture unknown argv or configuration values.
const std = @import("std");
const Self = @This();
command: []const u8 = "transit",
emitted: bool = false,
style: @import("Style.zig") = .{},
envelope: ?@import("transit_query").protocol.Diagnostic = null,
input: ?@import("InputPosition.zig") = null,
sql: ?@import("transit_query").fuze.SqlDiagnostic = null,
timing: ?@import("Timing.zig").Report = null,
argument: ?usize = null,
option: ?[]const u8 = null,
file: ?[]const u8 = null,
field: ?[]const u8 = null,
offset: ?u64 = null,
line: ?u64 = null,
column: ?u64 = null,
role: ?[]const u8 = null,
port: ?u16 = null,
summary: ?[]const u8 = null,
summary_storage: [512]u8 = undefined,
next: ?[]const u8 = null,
cause: ?anyerror = null,
usage: ?[]const u8 = null,
help: []const u8 = "transit --help",
show_help: bool = false,
presentation: enum { general, invocation, option, argument, configuration, json, field } = .general,

/// The diagnostic owner outlives the connection, response and formatting slot.
pub fn sqlServiceSummary(self: *Self, code: []const u8, sqlstate: [5]u8) void {
    self.summary = std.fmt.bufPrint(&self.summary_storage, "SQL service: {s} ({s})", .{ code, sqlstate }) catch "SQL service returned an error";
}

test "SQL summary owns response bytes after connection cleanup" {
    var self: Self = .{};
    var code = "Denied".*;
    self.sqlServiceSummary(&code, "42501".*);
    @memset(&code, 0);
    try std.testing.expectEqualStrings("SQL service: Denied (42501)", self.summary.?);
}

pub fn fail(self: *Self, err: anyerror, summary: []const u8, next: ?[]const u8) anyerror {
    self.setFailure(err, summary, next);
    return err;
}
pub fn setFailure(self: *Self, err: anyerror, summary: []const u8, next: ?[]const u8) void {
    self.envelope = null;
    self.sql = null;
    self.presentation = .general;
    self.summary = summary;
    self.next = next;
    self.cause = err;
}
pub fn invalidInvocation(self: *Self, summary: []const u8) anyerror {
    self.setFailure(error.InvalidInvocation, summary, null);
    self.presentation = .invocation;
    return error.InvalidInvocation;
}
pub fn invalidOption(self: *Self, summary: []const u8) anyerror {
    self.setFailure(error.InvalidInvocation, summary, null);
    self.presentation = .option;
    return error.InvalidInvocation;
}
pub fn invalidArgument(self: *Self, summary: []const u8) anyerror {
    self.setFailure(error.InvalidInvocation, summary, null);
    self.presentation = .argument;
    self.show_help = true;
    return error.InvalidInvocation;
}
pub fn configurationFailure(self: *Self, cause: anyerror) void {
    self.setFailure(cause, "cannot read configuration file", null);
    self.presentation = .configuration;
}
pub fn atArgument(self: *Self, index: ?usize, option: ?[]const u8) void {
    self.argument = index;
    self.option = option;
}
pub fn atFile(self: *Self, file: []const u8) void {
    self.input = null;
    self.envelope = null;
    self.sql = null;
    self.argument = null;
    self.option = null;
    self.file = file;
    self.field = null;
    self.offset = null;
    self.line = null;
    self.column = null;
    self.usage = null;
    self.role = null;
    self.port = null;
    self.summary = null;
    self.next = null;
    self.cause = null;
    self.show_help = false;
    self.presentation = .general;
}
pub fn invalidField(self: *Self, field: []const u8, summary: []const u8, next: ?[]const u8) anyerror {
    return self.invalidFieldCause(error.InvalidConfiguration, field, summary, next);
}
pub fn invalidFieldCause(self: *Self, cause: anyerror, field: []const u8, summary: []const u8, next: ?[]const u8) anyerror {
    self.field = field;
    self.setFailure(cause, summary, next);
    self.presentation = .field;
    return error.InvalidConfiguration;
}
pub fn readJson(self: *Self, comptime T: type, init: std.process.Init, path: []const u8, limit: usize) !T {
    self.atFile(path);
    const allocator = init.arena.allocator();
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(limit)) catch |err| {
        self.configurationFailure(err);
        return error.InvalidConfiguration;
    };
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    return self.parseJson(T, init, bytes, limit);
}
pub fn parseJson(self: *Self, comptime T: type, init: std.process.Init, bytes: []const u8, limit: usize) !T {
    const allocator = init.arena.allocator();
    const query = @import("transit_query");
    query.fuze.Types.Json.preflight(bytes, .{ .bytes = limit, .depth = query.Values.json_limits.depth, .tokens = limit + 1 }) catch |err| switch (err) {
        // Preserve the normal scanner's exact syntax coordinates. Its recursion
        // is reached only after the independent depth/size guard has passed.
        error.InvalidJson => {},
        else => return self.invalidFieldCause(err, "configuration", "does not satisfy the JSON decoding bounds or UTF-8 encoding", null),
    };
    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();
    var location: std.json.Scanner.Diagnostics = .{};
    scanner.enableDiagnostics(&location);
    return std.json.parseFromTokenSourceLeaky(T, allocator, &scanner, .{ .allocate = .alloc_always }) catch |err| {
        if (err == error.MissingField) {
            // Only static schema names are displayed; never echo JSON keys/values.
            const value = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch null;
            if (value) |parsed| {
                defer parsed.deinit();
                self.field = missingField(T, parsed.value, "", 0);
            }
        }
        self.offset = location.getByteOffset();
        self.line = location.getLine();
        self.column = location.getColumn();
        self.cause = err;
        self.presentation = .json;
        return error.InvalidConfiguration;
    };
}
fn missingField(comptime T: type, value: std.json.Value, comptime prefix: []const u8, comptime depth: usize) ?[]const u8 {
    if (T == std.json.Value) return null;
    if (depth == 16) return null;
    switch (@typeInfo(T)) {
        .optional => |info| return missingField(info.child, value, prefix, depth + 1),
        .@"struct" => |info| {
            if (value != .object) return null;
            inline for (info.field_names, info.field_types, info.field_attrs) |name, field_type, attrs| {
                const coordinate = if (prefix.len == 0) name else prefix ++ "." ++ name;
                if (value.object.get(name)) |child| {
                    if (missingField(field_type, child, coordinate, depth + 1)) |field| return field;
                } else if (attrs.defaultValue(field_type) == null) return coordinate;
            }
        },
        .@"union" => |info| {
            if (value != .object) return null;
            inline for (info.field_names, info.field_types) |name, field_type| {
                if (value.object.get(name)) |child| return missingField(field_type, child, prefix ++ "." ++ name, depth + 1);
            }
        },
        else => {},
    }
    return null;
}
// Escape all non-ASCII bytes as well as controls. Invalid UTF-8 and terminal
// escape sequences remain inert; each coordinate consumes at most 256 bytes.
fn quoted(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeByte('"');
    for (value[0..@min(value.len, 256)]) |byte| switch (byte) {
        '"', '\\' => {
            try out.writeByte('\\');
            try out.writeByte(byte);
        },
        0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try out.writeByte(byte),
        else => try out.print("\\x{x:0>2}", .{byte}),
    };
    if (value.len > 256) try out.writeAll("...");
    try out.writeByte('"');
}
pub fn render(self: Self, out: *std.Io.Writer, err: anyerror) !void {
    try self.renderFailure(out, err);
    if (self.input) |input| try input.render(out);
}
fn renderFailure(self: Self, out: *std.Io.Writer, err: anyerror) !void {
    if (self.envelope) |value| {
        if (value.validate()) |_| {
            if (std.mem.eql(u8, self.command, "transit console")) {
                // Typed SQL detail must not hide partial completion or a
                // warning about an already displayed, incomplete result.
                switch (err) {
                    error.SqlOperationPartial, error.SqlOperationRejected, error.ConsoleInterrupted => if (self.summary) |summary| try out.print("{s}.\n", .{summary}),
                    else => {},
                }
                try @import("EnvelopeDiagnostic.zig").renderConsole(value, out);
                if (self.next) |next| try out.print("\n{s}\n", .{next});
                return;
            }
            return @import("EnvelopeDiagnostic.zig").render(value, out);
        } else |_| {}
    }
    if (self.sql) |original| {
        var diagnostic = original;
        if (self.input) |input| if (input.sql) {
            if (diagnostic.line == 1) diagnostic.column += @intCast(input.start.column - 1);
            diagnostic.line += @intCast(input.start.line - 1);
        };
        try self.style.text(out, .failure, "error:");
        try out.writeByte(' ');
        try diagnostic.renderStyled(out, self.style);
        if (std.mem.indexOf(u8, diagnostic.hint, ".help") == null) switch (diagnostic.route) {
            .declaration => try self.style.hint(out, "Use .help CREATE TABLE, .help ALTER TABLE or .help DROP TABLE for syntax.\n"),
            .mutation => try self.style.hint(out, "Use .help INSERT, .help UPDATE or .help DELETE for syntax.\n"),
            else => {},
        };
        return;
    }
    if (err == error.InvalidTimingCommand) return self.style.hint(out, "Usage: .timer on|off\n");
    const advice = adviceFor(err);
    const cause = self.cause orelse err;
    try self.style.text(out, .failure, "error:");
    try out.writeByte(' ');
    switch (self.presentation) {
        .invocation => try out.writeAll(self.summary.?),
        .option => try out.print("{s} {s}", .{ self.option.?, self.summary.? }),
        .argument => try out.print("{s} at argument {d}", .{ self.summary.?, self.argument.? }),
        .configuration => {
            if (cause != error.FileNotFound) try out.writeAll("cannot read ");
            try out.writeAll("configuration file ");
            try quoted(out, self.file.?);
            if (cause == error.FileNotFound) try out.writeAll(" was not found") else try out.print(": {s}", .{reason(cause)});
        },
        .json => {
            switch (cause) {
                error.MissingField => {
                    try out.writeAll("missing required field");
                    if (self.field) |field| try out.print(" {s}", .{field});
                },
                error.UnknownField => try out.writeAll("unknown field"),
                error.DuplicateField => try out.writeAll("duplicate field"),
                error.SyntaxError, error.UnexpectedEndOfInput => try out.writeAll("invalid JSON"),
                else => try out.print("invalid configuration ({s})", .{@errorName(cause)}),
            }
            try out.writeAll(" in ");
            try quoted(out, self.file.?);
            try out.print(":{d}:{d}", .{ self.line.?, self.column.? });
        },
        .field => {
            if (self.file) |file| {
                try quoted(out, file);
                try out.writeAll(": ");
            }
            try out.print("{s} {s}", .{ self.field.?, self.summary.? });
        },
        .general => {
            if (err == error.RestartBudgetExhausted) {
                // The final exhaustion must not inherit an earlier retry summary.
                try out.writeAll(advice.?[0]);
                if (cause != err) try out.print(": {s}", .{reason(cause)});
            } else if (self.port) |port| {
                try out.print("cannot bind 127.0.0.1:{d}: {s}", .{ port, reason(cause) });
            } else if (self.summary) |summary| {
                try out.print("{s}: ", .{summary});
                try self.style.text(out, .failure, reason(cause));
                if (cause != err and advice == null and err != error.InvalidConfiguration and err != error.InvalidConfigurationPath and err != error.InvalidCredentialFile) try out.print(" ({s})", .{@errorName(err)});
            } else if (advice) |known| {
                try out.writeAll(known[0]);
                if (cause != err) try out.print(": {s}", .{reason(cause)});
            } else {
                try out.print("{s} failed: ", .{self.command});
                try self.style.text(out, .failure, reason(cause));
                if (cause != err) try out.print(" ({s})", .{@errorName(err)});
            }
            const exhausted_listener = self.port != null and err == error.RestartBudgetExhausted;
            if (self.file != null or self.field != null or self.role != null or exhausted_listener) {
                try out.writeAll("\n  ");
                if (self.file) |file| try quoted(out, file);
                if (self.field) |field| try out.print("{s}{s}", .{ if (self.file != null) ": " else "", field });
                if (self.role) |role| try out.print("{s}role {s}", .{ if (self.file != null or self.field != null) "; " else "", role });
                if (exhausted_listener) try out.print("{s}listener 127.0.0.1:{d}", .{ if (self.file != null or self.field != null or self.role != null) "; " else "", self.port.? });
            }
        },
    }
    try out.writeByte('\n');
    const next = if (err == error.RestartBudgetExhausted) advice.?[1] else self.next orelse if (self.presentation == .general and advice != null) advice.?[1] else null;
    if (next) |hint| {
        try out.writeByte('\n');
        try self.style.hint(out, hint);
        try out.writeByte('\n');
    }
    if (self.usage) |usage| try out.print("\nUsage: {s}\n", .{usage}) else if (self.show_help) try out.print("\nRun {s} for options.\n", .{self.help});
}
fn reason(err: anyerror) []const u8 {
    return switch (err) {
        error.FileNotFound => "file not found",
        error.AccessDenied => "permission denied",
        error.AddressInUse => "address already in use",
        error.NameTooLong => "path is too long",
        error.StreamTooLong => "file exceeds the command's size limit",
        error.IsDir => "expected a file, found a directory",
        error.NotDir => "a path component is not a directory",
        error.ChildExited => "child process exited",
        error.RoleReadinessTimeout => "role readiness timed out",
        error.NoSpaceLeft => "no space left on the filesystem",
        else => @errorName(err),
    };
}
pub fn reportTiming(self: *Self, io: std.Io) void {
    const timing = self.timing orelse return;
    self.timing = null;
    timing.emit(io);
}
pub fn emit(self: *Self, io: std.Io, err: anyerror) void {
    defer self.reportTiming(io);
    if (self.emitted) return;
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    self.render(&writer.interface, err) catch return;
    writer.interface.flush() catch {};
}

const Advice = struct { []const u8, ?[]const u8 };
fn adviceFor(err: anyerror) ?Advice {
    return switch (err) {
        error.InstallationInUse => .{ "another server manages this installation", "Stop the existing manager before starting another server for this installation." },
        error.InstallationIdentityMismatch => .{ "the configuration or executable differs from the recorded installation", "Restore the recorded configuration and matching executables. Do not initialize or delete the installation to bypass this check." },
        error.ExistingInstallationRequired => .{ "startup requires an existing installation", "startup.require_existing is enabled. Verify the installation path and storage mount; restore the intended installation before starting." },
        error.InvalidInstallationDirectory => .{ "the installation path must be a directory, not a file or symbolic link", "Select the actual installation directory. Existing paths are never replaced to initialize a server." },
        error.StorageIdentityMismatch => .{ "retained storage does not match the installation's recovery evidence", "Restore the matching storage and recorded configuration using the server recovery guide. Do not delete identity or recovery records to bypass this check." },
        error.AuthorityRollback => .{ "retained authority is older than the recorded recovery position", "Restore the matching storage and recorded configuration using the server recovery guide. Do not delete identity or recovery records to bypass this check." },
        error.NoSpaceLeft => .{ "the filesystem has no space for this operation", "Free space outside retained Transit data or expand the filesystem, then recover the same installation or saved operation." },
        error.RestartBudgetExhausted => .{ "server restart budget exhausted", "Check the named role's executable, port and storage permissions, then restart with the same configuration." },
        error.RoleReadinessTimeout => .{ "a required server role did not become ready in time", "Check the named role's executable, port and storage permissions, then restart with the same configuration." },
        error.ChildExited => .{ "a required server role exited", "Check the named role's executable, port and storage permissions, then restart with the same configuration." },
        error.ConsoleRecoveryInUse, error.ManagementClientInUse => .{ "another client holds the recovery lock", "Close the other client using this recovery location, then reconnect with the same configuration." },
        error.ConsoleRecoveryIdentityMismatch, error.RecoveryIdentityMismatch => .{ "saved intent belongs to a different configured identity", "Use the original configuration and recovery file together; do not resubmit the operation under a new identity." },
        error.ConsoleRecoveryWriteFailed, error.ConsoleRecoverySyncFailed, error.InstallationSyncFailed => .{ "recovery state could not be persisted", "Check disk space and write permissions. Preserve the recovery files and reconcile the same saved operation after restoring storage." },
        error.ApplicationOutcomeUnknown => .{ "the application operation's outcome is unknown", "Resubmit the original saved signed request through the application client. Preserve its operation ID and configuration." },
        error.InteractiveQueryCancelled => .{ "query cancelled", "Run the statement again to start a fresh snapshot." },
        error.ConsoleInterrupted => .{ "statement interrupted", null },
        error.ConsoleCommandFailed => .{ "one or more console commands failed", "Inspect the preceding statement result." },
        else => null,
    };
}
/// Runtime failures use the same bounded sink as lifecycle records. Command/input
/// failures before the runtime starts retain their detailed CLI diagnostic contract.
pub fn log(self: Self, runtime: *@import("transit_query").wire.observability.telemetry.Runtime, name: []const u8, err: anyerror) void {
    runtime.event(self.event(name, err));
}
pub fn event(self: Self, name: []const u8, err: anyerror) @import("transit_query").wire.observability.telemetry.Event {
    const advice = adviceFor(err);
    const exhausted = err == error.RestartBudgetExhausted;
    return .{ .name = name, .level = .err, .outcome = .failed, .message = if (exhausted) advice.?[0] else self.summary orelse if (advice) |known| known[0] else "Server operation failed", .hint = if (exhausted) advice.?[1] else self.next orelse if (advice) |known| known[1] else null, .operation = @errorName(err), .error_type = @errorName(self.cause orelse err), .location = self.file, .field = self.field, .role = self.role, .port = self.port };
}

test "server failure events preserve terminal cause and recovery advice" {
    const event_value = (Self{ .summary = "retrying", .next = "wait", .cause = error.ChildExited, .role = "board" }).event("server.failed", error.RestartBudgetExhausted);
    try std.testing.expectEqualStrings("server restart budget exhausted", event_value.message.?);
    try std.testing.expectEqualStrings("ChildExited", event_value.error_type.?);
    try std.testing.expectEqualStrings("RestartBudgetExhausted", event_value.operation.?);
    try std.testing.expectEqualStrings("board", event_value.role.?);
    try std.testing.expect(std.mem.indexOf(u8, event_value.hint.?, "same configuration") != null);
}

test "unknown failures retain identifiers and recovery advice retains exact identity" {
    const cases = .{
        .{ Self{ .command = "transit server", .cause = error.UnmappedCause }, error.UnmappedFailure, &.{ "UnmappedCause", "UnmappedFailure" } },
        .{ Self{ .summary = "cannot complete this step", .cause = error.UnmappedCause }, error.UnmappedFailure, &.{ "UnmappedCause", "UnmappedFailure" } },
        .{ Self{}, error.ApplicationOutcomeUnknown, &.{ "outcome is unknown", "saved signed request", "operation ID", "configuration" } },
        .{ Self{ .command = "transit console" }, error.ConsoleInterrupted, &.{"statement interrupted"} },
        .{ Self{ .command = "transit console" }, error.InteractiveQueryCancelled, &.{ "query cancelled", "fresh snapshot" } },
        // Exhaustion must replace a transient retry message and retain the cause.
        .{ Self{ .summary = "server role failed; retrying the same installation", .next = "Wait for readiness.", .cause = error.ChildExited, .role = "courier" }, error.RestartBudgetExhausted, &.{ "restart budget exhausted", "child process exited", "role courier", "same configuration" } },
        .{ Self{ .cause = error.AddressInUse, .port = 8080, .field = "ports.gateway" }, error.RestartBudgetExhausted, &.{ "restart budget exhausted", "address already in use", "ports.gateway", "listener 127.0.0.1:8080" } },
    };
    inline for (cases) |case| {
        var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer out.deinit();
        try case[0].render(&out.writer, case[1]);
        inline for (case[2]) |fragment| try std.testing.expect(std.mem.indexOf(u8, out.written(), fragment) != null);
        try std.testing.expect(std.mem.indexOf(u8, out.written(), "retrying the same installation") == null);
        try std.testing.expect(std.mem.indexOf(u8, out.written(), "Wait for readiness.") == null);
    }
}

test "console keeps partial outcome and result warnings alongside typed SQL evidence" {
    const d = @import("transit_query").protocol.Diagnostic;
    var detail = try d.init("sql.limit", .limit, .execute, .failed, .domain_status, "The result exceeded its limit.");
    try detail.text(.column, .schema, "amount");
    try detail.action(.inspect_status);
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try (Self{ .command = "transit console", .envelope = detail, .summary = "Statement completed only partially", .next = "The rows already displayed are only a partial result." }).render(&out.writer, error.SqlOperationPartial);
    for ([_][]const u8{ "Statement completed only partially", "sql.limit", "Column: amount", "only a partial result" }) |fragment| try std.testing.expect(std.mem.indexOf(u8, out.written(), fragment) != null);
    for ([_][]const u8{ "stage:", "owning interface", ".status" }) |fragment| try std.testing.expect(std.mem.indexOf(u8, out.written(), fragment) == null);
}
