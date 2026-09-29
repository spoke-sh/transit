//! Explicit command options with an optional console configuration default.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Format = enum { table, json };
pub const Options = struct {
    command: enum { help, version, console, server },
    path: ?[]const u8 = null,
    format: ?Format = null,
    initialize: bool = false,
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
        return diagnostic.fail(error.InvalidInvocation, "unknown command or misplaced global option", "Choose server, serve, console, app, query or query-v2; use transit --help to list commands.");
    } };
    const server = result.command == .server;
    diagnostic.command = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve" else "transit server") else "transit console";
    diagnostic.help = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve --help" else "transit server --help") else "transit console --help";
    diagnostic.usage = if (server) "transit server --config PATH [--initialize] [--no-ui]" else "transit console [--config PATH] [--format table|json]";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const known = for ([_][]const u8{ "--help", "--initialize", "--no-ui", "--config", "--format" }) |name| {
            if (std.mem.eql(u8, arg, name)) break name;
        } else null;
        diagnostic.atArgument(i + 1, known);
        const option = known orelse return diagnostic.fail(error.InvalidInvocation, "unexpected argument", "Remove this argument or choose an option listed by the command's help.");
        if ((!server and (std.mem.eql(u8, option, "--initialize") or std.mem.eql(u8, option, "--no-ui"))) or (server and std.mem.eql(u8, option, "--format")))
            return diagnostic.fail(error.InvalidInvocation, "option is not supported by this command", "Remove this option; see the command's help for supported options.");
        if (std.mem.eql(u8, option, "--help")) {
            if (result.help) return duplicate(diagnostic);
            result.help = true;
        } else if (std.mem.eql(u8, option, "--initialize")) {
            if (result.initialize) return duplicate(diagnostic);
            result.initialize = true;
        } else if (std.mem.eql(u8, option, "--no-ui")) {
            if (result.no_ui) return duplicate(diagnostic);
            result.no_ui = true;
        } else {
            const config = std.mem.eql(u8, option, "--config");
            if ((config and result.path != null) or (!config and result.format != null)) return duplicate(diagnostic);
            if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--"))
                return diagnostic.fail(error.InvalidInvocation, "option requires a value", if (config) "Provide the configuration file path after --config." else "Provide table or json after --format.");
            i += 1;
            if (config) result.path = args[i] else {
                diagnostic.atArgument(i + 1, "--format");
                result.format = std.meta.stringToEnum(Format, args[i]) orelse return diagnostic.fail(error.InvalidInvocation, "unsupported output format", "Use --format table or --format json.");
            }
        }
    }
    if (!server and result.path == null) if (console_config) |path| {
        if (path.len > 0) {
            result.path = path;
        }
    };
    if (!result.help and result.path == null) {
        diagnostic.atArgument(null, "--config");
        return diagnostic.fail(error.InvalidInvocation, "missing required configuration", if (server) "Run transit server --config PATH with an existing server configuration. Add --initialize only when deliberately creating a new installation." else "Pass --config PATH or set TRANSIT_CONSOLE_CONFIG to a console configuration file.");
    }
    diagnostic.atArgument(null, null);
    diagnostic.usage = null;
    return result;
}
fn duplicate(diagnostic: *Diagnostic) anyerror {
    return diagnostic.fail(error.InvalidInvocation, "option was supplied more than once", "Keep one occurrence of this option.");
}
pub fn writeHelp(io: std.Io, options: Options) !void {
    return std.Io.File.stdout().writeStreamingAll(io, switch (options.command) {
        .server => server_help,
        .console => console_help,
        else => help,
    });
}
const server_help =
    \\Usage: transit server|serve --config PATH [--initialize] [--no-ui]
    \\Run a configured local installation in the foreground. --config is required.
    \\Paths in the JSON file resolve relative to that file.
    \\--initialize creates a new installation; ordinary restarts omit it.
    \\--no-ui skips Board for this invocation, preserving retained state.
    \\Configuration: docs/reference/cli.md and apps/transit-cli/docs/server.md
    \\Next: transit server --config PATH
    \\
;
const console_help =
    \\Usage: transit console [--config PATH] [--format table|json]
    \\--config overrides TRANSIT_CONSOLE_CONFIG; one must select a configuration.
    \\Submit SQL with a semicolon; /help lists session commands.
    \\Configuration: apps/transit-cli/docs/console.md
    \\Next: transit console --config PATH
    \\
;

pub const help =
    \\Transit — explicit local services and signed SQL
    \\  transit console [--config PATH] [--format table|json]
    \\  transit server|serve --config PATH [--initialize] [--no-ui]
    \\  transit app --help (local application installation and replacement)
    \\  transit --help | --version
    \\  transit query CONFIG | query-v2 CONFIG (existing single-line shells)
    \\Configuration is explicit versioned JSON; paths are relative to its file.
    \\Console defaults to TRANSIT_CONSOLE_CONFIG when --config is omitted.
    \\Console SQL submits on a semicolon; /help lists local commands.
    \\Server runs in the foreground with Board by default (Linux, configuration v3).
    \\--no-ui disables Board for this invocation without changing retained state.
    \\
;

test "console defaults are explicit, overridable and never select server configuration" {
    try std.testing.expectError(error.InvalidInvocation, parse(&.{"console"}));
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{"console"}, ""));
    const fallback = try parseWithConsoleConfig(&.{"console"}, "/local/console.json");
    try std.testing.expectEqualStrings("/local/console.json", fallback.path.?);
    const explicit = try parseWithConsoleConfig(&.{ "console", "--config", "other.json" }, "/local/console.json");
    try std.testing.expectEqualStrings("other.json", explicit.path.?);
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{ "console", "--config", "one", "--config", "two" }, "/local/console.json"));
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{"server"}, "/local/console.json"));
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{"serve"}, "/local/console.json"));
    const server = try parse(&.{ "serve", "--config", "server.json", "--initialize" });
    try std.testing.expectEqual(.server, server.command);
    try std.testing.expect(server.initialize);
    try std.testing.expect((try parseWithConsoleConfig(&.{ "console", "--help" }, null)).help);
}

test "both server aliases default to UI and accept only one opt-out" {
    for ([_][]const u8{ "server", "serve" }) |alias| {
        try std.testing.expect(!(try parse(&.{ alias, "--config", "server.json" })).no_ui);
        try std.testing.expect((try parse(&.{ alias, "--config", "server.json", "--no-ui", "--initialize" })).no_ui);
        try std.testing.expectError(error.InvalidInvocation, parse(&.{ alias, "--config", "server.json", "--no-ui", "--no-ui" }));
        try std.testing.expectError(error.InvalidInvocation, parse(&.{ alias, "--config", "server.json", "--ui" }));
    }
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "console", "--config", "console.json", "--no-ui" }));
}
