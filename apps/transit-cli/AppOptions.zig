//! Validate all application arguments before reading files or creating intent.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Mode = enum { install, replace, retry, status, connect };
pub const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, operation: ?[]const u8 = null, application: ?[]const u8 = null, caller: ?[]const u8 = null, output: ?[]const u8 = null, after: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags, after: u32 = 0 };
pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "transit app";
    diagnostic.help = "transit app --help";
    diagnostic.atArgument(2, null);
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return diagnostic.fail(error.InvalidInvocation, "unknown application subcommand", "Choose install, replace, retry, status or connect.");
    switch (mode) {
        inline else => |value| diagnostic.command = "transit app " ++ @tagName(value),
    }
    var result: Options = .{ .mode = mode, .flags = .{} };
    var i: usize = 1;
    while (i < args.len) : (i += 2) {
        diagnostic.atArgument(i + 2, null);
        var found = false;
        inline for (@typeInfo(Flags).@"struct".field_names) |field| {
            if (std.mem.eql(u8, args[i], "--" ++ field)) {
                diagnostic.option = "--" ++ field;
                if (!allowed(mode, field)) return diagnostic.fail(error.InvalidInvocation, "option is not supported by this application subcommand", "Remove this option; transit app --help lists the options for each subcommand.");
                if (@field(result.flags, field) != null) return diagnostic.fail(error.InvalidInvocation, "option was supplied more than once", "Keep one occurrence of this option.");
                if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--")) return diagnostic.fail(error.InvalidInvocation, "option requires a value", "Supply a nonempty value immediately after this option.");
                @field(result.flags, field) = args[i + 1];
                found = true;
            }
        }
        if (!found) return diagnostic.fail(error.InvalidInvocation, "unexpected application argument", "Remove this argument; transit app --help lists the supported options.");
        if (std.mem.eql(u8, args[i], "--after")) {
            diagnostic.atArgument(i + 3, "--after");
            result.after = std.fmt.parseInt(u32, args[i + 1], 10) catch return diagnostic.fail(error.InvalidInvocation, "invalid receipt page index", "Use --after with an integer from 0 through 4294967295, normally the prior status page's next index.");
        }
    }
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        const required = std.mem.eql(u8, field, "config") or
            (std.mem.eql(u8, field, "file") and (mode == .install or mode == .replace)) or
            (std.mem.eql(u8, field, "operation") and (mode == .install or mode == .replace or mode == .retry)) or
            (std.mem.eql(u8, field, "application") and (mode == .status or mode == .connect)) or
            (std.mem.eql(u8, field, "caller") and mode == .connect);
        if (required and @field(result.flags, field) == null) {
            diagnostic.atArgument(null, "--" ++ field);
            return diagnostic.fail(error.InvalidInvocation, "missing required application option", "Supply " ++ "--" ++ field ++ " with a value; transit app --help shows the complete invocation.");
        }
    }
    diagnostic.atArgument(null, null);
    return result;
}
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "file")) return mode == .install or mode == .replace;
    if (std.mem.eql(u8, field, "application")) return mode == .status or mode == .connect;
    if (std.mem.eql(u8, field, "output") or std.mem.eql(u8, field, "caller")) return mode == .connect;
    if (std.mem.eql(u8, field, "after")) return mode == .status;
    // Retain the existing optional operation identity on reads.
    return true;
}
