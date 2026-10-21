//! Explicit command options with an optional console configuration default.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Format = enum { table, json };
pub const Options = struct {
    command: enum { help, version, console, server },
    path: ?[]const u8 = null,
    path_from_environment: bool = false,
    format: ?Format = null,
    sql: ?[]const u8 = null,
    parameters: ?[]const u8 = null,
    script: ?[]const u8 = null,
    rc: ?[]const u8 = null,
    no_rc: bool = false,
    no_ui: bool = false,
    help: bool = false,
};
pub fn parse(args: []const []const u8) !Options {
    return parseWithConsoleConfig(args, null);
}
pub fn parseWithConsoleConfig(args: []const []const u8, console_config: ?[]const u8) !Options {
    var diagnostic: Diagnostic = .{};
    return parseDiagnosed(args, console_config, &diagnostic);
}
pub fn parseDiagnosed(args: []const []const u8, console_config: ?[]const u8, diagnostic: *Diagnostic) !Options {
    if (args.len == 0) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--help")) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--version")) return .{ .command = .version };
    var result: Options = .{ .command = if (std.mem.eql(u8, args[0], "console")) .console else if (std.mem.eql(u8, args[0], "server") or std.mem.eql(u8, args[0], "serve")) .server else {
        diagnostic.atArgument(1, null);
        return diagnostic.invalidArgument("unknown command or misplaced global option");
    } };
    const server = result.command == .server;
    diagnostic.command = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve" else "transit server") else "transit console";
    diagnostic.help = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve --help" else "transit server --help") else "transit console --help";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const known = for ([_][]const u8{ "--help", "--no-ui", "--config", "--format", "-c", "-f", "--parameters", "--init", "--no-rc" }) |name| {
            if (std.mem.eql(u8, arg, name)) break name;
        } else null;
        diagnostic.atArgument(i + 1, known);
        const option = known orelse return diagnostic.invalidArgument("unexpected input");
        if ((!server and std.mem.eql(u8, option, "--no-ui")) or (server and (std.mem.eql(u8, option, "--format") or std.mem.eql(u8, option, "-c") or std.mem.eql(u8, option, "-f") or std.mem.eql(u8, option, "--parameters") or std.mem.eql(u8, option, "--init") or std.mem.eql(u8, option, "--no-rc")))) {
            diagnostic.show_help = true;
            return diagnostic.invalidOption("is not supported by this command");
        }
        if (std.mem.eql(u8, option, "--help")) {
            if (result.help) return duplicate(diagnostic);
            result.help = true;
        } else if (std.mem.eql(u8, option, "--no-ui")) {
            if (result.no_ui) return duplicate(diagnostic);
            result.no_ui = true;
        } else if (std.mem.eql(u8, option, "--no-rc")) {
            if (result.no_rc) return duplicate(diagnostic);
            result.no_rc = true;
        } else {
            const target: ?*?[]const u8 = if (std.mem.eql(u8, option, "--config")) &result.path else if (std.mem.eql(u8, option, "-c")) &result.sql else if (std.mem.eql(u8, option, "-f")) &result.script else if (std.mem.eql(u8, option, "--parameters")) &result.parameters else if (std.mem.eql(u8, option, "--init")) &result.rc else blk: {
                if (result.format != null) return duplicate(diagnostic);
                if (i + 1 == args.len) return diagnostic.invalidOption("must be table or json");
                i += 1;
                result.format = std.meta.stringToEnum(Format, args[i]) orelse return diagnostic.invalidOption("must be table or json");
                break :blk null;
            };
            if (target) |slot| {
                if (slot.* != null) return duplicate(diagnostic);
                if (i + 1 == args.len or args[i + 1].len == 0 or (std.mem.startsWith(u8, args[i + 1], "--") and !std.mem.eql(u8, option, "-c")) or std.mem.eql(u8, args[i + 1], "-f") or std.mem.eql(u8, args[i + 1], "-c")) return diagnostic.invalidOption(if (std.mem.eql(u8, option, "-c")) "requires a SQL statement" else "requires a file path");
                i += 1;
                slot.* = args[i];
            }
        }
    }
    if (result.sql != null and result.script != null) return diagnostic.invalidInvocation("-c and -f cannot be combined");
    if (result.parameters != null and result.sql == null) return diagnostic.invalidInvocation("--parameters requires -c SQL");
    if (result.rc != null and result.no_rc) return diagnostic.invalidInvocation("--init and --no-rc cannot be combined");
    if (!server and result.path == null) if (console_config) |path| {
        if (path.len > 0) {
            result.path = path;
            result.path_from_environment = true;
        }
    };
    diagnostic.atArgument(null, null);
    diagnostic.usage = null;
    return result;
}
fn duplicate(diagnostic: *Diagnostic) anyerror {
    return diagnostic.invalidOption("can only be specified once");
}
pub fn writeHelp(io: std.Io, options: Options) !void {
    return std.Io.File.stdout().writeStreamingAll(io, switch (options.command) {
        .server => @import("Help.zig").server,
        .console => @import("Help.zig").console,
        else => @import("Help.zig").root,
    });
}

test "connection options override the environment and server discovery is independent" {
    try std.testing.expect((try parse(&.{"console"})).path == null);
    try std.testing.expect((try parseWithConsoleConfig(&.{"console"}, "")).path == null);
    const fallback = try parseWithConsoleConfig(&.{"console"}, "/local/console.json");
    try std.testing.expectEqualStrings("/local/console.json", fallback.path.?);
    const explicit = try parseWithConsoleConfig(&.{ "console", "--config", "other.json" }, "/local/console.json");
    try std.testing.expectEqualStrings("other.json", explicit.path.?);
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{ "console", "--config", "one", "--config", "two" }, "/local/console.json"));
    try std.testing.expect((try parseWithConsoleConfig(&.{"server"}, "/local/console.json")).path == null);
    try std.testing.expect((try parseWithConsoleConfig(&.{"serve"}, "/local/console.json")).path == null);
    const server = try parse(&.{ "serve", "--config", "server.json" });
    try std.testing.expectEqual(.server, server.command);
    try std.testing.expect((try parseWithConsoleConfig(&.{ "console", "--help" }, null)).help);
}

test "both server aliases default to UI and accept only one opt-out" {
    for ([_][]const u8{ "server", "serve" }) |alias| {
        try std.testing.expect(!(try parse(&.{ alias, "--config", "server.json" })).no_ui);
        try std.testing.expect((try parse(&.{ alias, "--config", "server.json", "--no-ui" })).no_ui);
        try std.testing.expectError(error.InvalidInvocation, parse(&.{ alias, "--initialize" }));
        try std.testing.expectError(error.InvalidInvocation, parse(&.{ alias, "--config", "server.json", "--no-ui", "--no-ui" }));
        try std.testing.expectError(error.InvalidInvocation, parse(&.{ alias, "--config", "server.json", "--ui" }));
    }
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "console", "--config", "console.json", "--no-ui" }));
}

test "parameter files are explicit one-statement console inputs" {
    const options = try parse(&.{ "console", "--parameters", "bindings.json", "-c", "SELECT * FROM items LIMIT $1" });
    try std.testing.expectEqualStrings("bindings.json", options.parameters.?);
    for ([_][]const []const u8{
        &.{ "console", "--parameters", "bindings.json" },
        &.{ "console", "--parameters", "bindings.json", "-f", "queries.sql" },
        &.{ "server", "--parameters", "bindings.json" },
        &.{ "console", "--parameters", "one", "--parameters", "two", "-c", "SELECT * FROM items" },
    }) |args| try std.testing.expectError(error.InvalidInvocation, parse(args));
}
