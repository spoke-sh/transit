//! Explicit command options; no environment or installation discovery.
const std = @import("std");
pub const Format = enum { table, json };
pub const Options = struct {
    command: enum { help, version, console, server },
    path: ?[]const u8 = null,
    format: ?Format = null,
    initialize: bool = false,
    help: bool = false,
};
pub fn parse(args: []const []const u8) !Options {
    if (args.len == 0) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--help")) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--version")) return .{ .command = .version };
    var result: Options = .{ .command = if (std.mem.eql(u8, args[0], "console")) .console else if (std.mem.eql(u8, args[0], "server")) .server else return error.InvalidInvocation };
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") and !result.help) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "--initialize") and result.command == .server and !result.initialize) {
            result.initialize = true;
        } else if (std.mem.eql(u8, arg, "--config") and result.path == null and i + 1 < args.len) {
            i += 1;
            if (args[i].len == 0 or std.mem.startsWith(u8, args[i], "--")) return error.InvalidInvocation;
            result.path = args[i];
        } else if (std.mem.eql(u8, arg, "--format") and result.command == .console and result.format == null and i + 1 < args.len) {
            i += 1;
            result.format = std.meta.stringToEnum(Format, args[i]) orelse return error.InvalidInvocation;
        } else return error.InvalidInvocation;
    }
    if (!result.help and result.path == null) return error.InvalidInvocation;
    return result;
}
pub const help =
    \\Transit — explicit local services and signed SQL
    \\  transit console --config PATH [--format table|json]
    \\  transit server --config PATH [--initialize]
    \\  transit --help | --version
    \\  transit query CONFIG | query-v2 CONFIG (existing single-line shells)
    \\Configuration is explicit versioned JSON; paths are relative to its file.
    \\Console SQL submits on a semicolon; /help lists local commands.
    \\Server runs the explicit local Table profile in the foreground (Linux).
    \\
;
