//! Human diagnostics at the CLI boundary. Never capture argv or configuration values.
const std = @import("std");
const Self = @This();
command: []const u8 = "transit",
argument: ?usize = null,
option: ?[]const u8 = null,
file: ?[]const u8 = null,
field: ?[]const u8 = null,
line: ?u64 = null,
column: ?u64 = null,
role: ?[]const u8 = null,
port: ?u16 = null,
summary: ?[]const u8 = null,
next: ?[]const u8 = null,
cause: ?anyerror = null,
usage: ?[]const u8 = null,
help: []const u8 = "transit --help",

pub fn fail(self: *Self, err: anyerror, summary: []const u8, next: []const u8) anyerror {
    self.setFailure(err, summary, next);
    return err;
}
pub fn setFailure(self: *Self, err: anyerror, summary: []const u8, next: []const u8) void {
    self.summary = summary;
    self.next = next;
    self.cause = err;
}
pub fn atArgument(self: *Self, index: ?usize, option: ?[]const u8) void {
    self.argument = index;
    self.option = option;
}
pub fn atFile(self: *Self, file: []const u8) void {
    self.argument = null;
    self.option = null;
    self.file = file;
    self.field = null;
    self.line = null;
    self.column = null;
    self.usage = null;
    self.role = null;
    self.port = null;
    self.summary = null;
    self.next = null;
    self.cause = null;
}
pub fn invalidField(self: *Self, field: []const u8, summary: []const u8, next: []const u8) anyerror {
    return self.invalidFieldCause(error.InvalidConfiguration, field, summary, next);
}
pub fn invalidFieldCause(self: *Self, cause: anyerror, field: []const u8, summary: []const u8, next: []const u8) anyerror {
    self.field = field;
    self.setFailure(cause, summary, next);
    return error.InvalidConfiguration;
}
pub fn readJson(self: *Self, comptime T: type, init: std.process.Init, path: []const u8, limit: usize) !T {
    self.atFile(path);
    const allocator = init.arena.allocator();
    const bytes = std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(limit)) catch |err| {
        self.setFailure(err, if (err == error.StreamTooLong) "configuration exceeds the command's size limit" else "cannot read the configuration file", "Check the configuration path, file size and read permissions; see the command's configuration guide.");
        return error.InvalidConfiguration;
    };
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
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
        self.line = location.getLine();
        self.column = location.getColumn();
        self.setFailure(err, switch (err) {
            error.UnknownField => "configuration contains an unknown field",
            error.DuplicateField => "configuration repeats a field",
            error.MissingField => "configuration is missing a required field",
            else => "configuration is not valid JSON for this command",
        }, "Correct the JSON at the parser location using the command's configuration guide; values are omitted from diagnostics.");
        return error.InvalidConfiguration;
    };
}
fn missingField(comptime T: type, value: std.json.Value, comptime prefix: []const u8, comptime depth: usize) ?[]const u8 {
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
    const advice = switch (err) {
        error.InstallationInUse => .{ "another server manages this installation", "Stop the existing manager before starting another server for this installation." },
        error.InstallationIdentityMismatch => .{ "the configuration or executable differs from the recorded installation", "Restore the recorded configuration and matching executables. Do not initialize or delete the installation to bypass this check." },
        error.InstallationExists => .{ "this installation is already initialized", "Restart with the same configuration and omit --initialize. Preserve the existing installation directory." },
        error.StorageIdentityMismatch, error.AuthorityRollback => .{ "retained storage does not match the installation's recovery evidence", "Restore the matching storage and recorded configuration using the server recovery guide. Do not delete identity or recovery records to bypass this check." },
        error.NoSpaceLeft => .{ "the filesystem has no space for this operation", "Free space outside retained Transit data or expand the filesystem, then recover the same installation or saved operation." },
        error.RestartBudgetExhausted, error.RoleReadinessTimeout, error.ChildExited => .{ "a required server role failed to become or remain ready", "Check the named role's executable, port and storage permissions in the server configuration, then restart with the same configuration without --initialize." },
        error.ConsoleRecoveryInUse, error.ManagementClientInUse => .{ "another client holds the recovery lock", "Close the other client using this recovery location, then reconnect with the same configuration." },
        error.ConsoleRecoveryIdentityMismatch, error.RecoveryIdentityMismatch => .{ "saved intent belongs to a different configured identity", "Use the original configuration and recovery file together; do not resubmit the operation under a new identity." },
        error.ConsoleRecoveryWriteFailed, error.ConsoleRecoverySyncFailed, error.InstallationSyncFailed => .{ "recovery state could not be persisted", "Check disk space and write permissions. Preserve the recovery files and reconcile the same saved operation after restoring storage." },
        error.ApplicationOutcomeUnknown => .{ "the application operation outcome is uncertain", "Use transit app retry with the same --config and --operation identity to reconcile the saved signed request; do not repeat install/replace under a new ID." },
        error.ConsoleInterrupted => .{ "console wait interrupted; durable work is not cancelled", "Reconnect with the same configuration and inspect /status or reconcile saved intent with /retry." },
        error.ConsoleCommandFailed => .{ "one or more console commands failed", "Inspect the preceding command result. Use /retry for pending signed intent; do not resubmit SQL after an uncertain outcome." },
        else => .{ "the command could not complete", "Inspect the reported cause and coordinates. Preserve saved operation identity when reconciling uncertain work; include this diagnostic and transit --version in a bug report if the cause remains unexplained." },
    };
    try out.print("error: {s}\n  at: {s}", .{ self.summary orelse advice[0], self.command });
    if (self.argument) |index| try out.print(" argv[{d}]", .{index});
    if (self.option) |option| try out.print(" {s}", .{option});
    if (self.file) |file| {
        try out.writeByte(' ');
        try quoted(out, file);
    }
    if (self.line) |line| try out.print(":{d}:{d} (parser location)", .{ line, self.column.? });
    if (self.field) |field| try out.print(" field {s}", .{field});
    if (self.role) |role| try out.print(" role {s}", .{role});
    if (self.port) |port| try out.print(" listener 127.0.0.1:{d}", .{port});
    try out.print("\n  cause: {s}\n  next: {s}\n", .{ @errorName(self.cause orelse err), self.next orelse advice[1] });
    if (self.cause) |cause| if (cause != err) {
        try out.print("  code: {s}\n", .{@errorName(err)});
    };
    if (self.usage) |usage| try out.print("  usage: {s}\n", .{usage});
    try out.print("  help: {s}\n", .{self.help});
}
pub fn emit(self: Self, io: std.Io, err: anyerror) void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    self.render(&writer.interface, err) catch return;
    writer.interface.flush() catch {};
}
