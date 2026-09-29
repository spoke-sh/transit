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
        return diagnostic.invalidArgument("unknown command or misplaced global option");
    } };
    const server = result.command == .server;
    diagnostic.command = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve" else "transit server") else "transit console";
    diagnostic.help = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve --help" else "transit server --help") else "transit console --help";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const known = for ([_][]const u8{ "--help", "--initialize", "--no-ui", "--config", "--format" }) |name| {
            if (std.mem.eql(u8, arg, name)) break name;
        } else null;
        diagnostic.atArgument(i + 1, known);
        const option = known orelse return diagnostic.invalidArgument("unexpected input");
        if ((!server and (std.mem.eql(u8, option, "--initialize") or std.mem.eql(u8, option, "--no-ui"))) or (server and std.mem.eql(u8, option, "--format"))) {
            diagnostic.show_help = true;
            return diagnostic.invalidOption("is not supported by this command");
        }
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
                return diagnostic.invalidOption(if (config) "requires a file path" else "must be table or json");
            i += 1;
            if (config) result.path = args[i] else {
                diagnostic.atArgument(i + 1, "--format");
                result.format = std.meta.stringToEnum(Format, args[i]) orelse return diagnostic.invalidOption("must be table or json");
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
        diagnostic.usage = if (server) (if (std.mem.eql(u8, args[0], "serve")) "transit serve --config PATH" else "transit server --config PATH") else "transit console --config PATH";
        return if (server) diagnostic.invalidOption("is required") else diagnostic.invalidInvocation("--config or TRANSIT_CONSOLE_CONFIG is required");
    }
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
