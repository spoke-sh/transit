//! Validate all application arguments before reading files or creating intent.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Mode = enum { install, replace, retry, status, connect };
pub const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, operation: ?[]const u8 = null, application: ?[]const u8 = null, caller: ?[]const u8 = null, output: ?[]const u8 = null, after: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags, after: u32 = 0, help: bool = false };
pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "transit app";
    diagnostic.help = "transit app --help";
    diagnostic.atArgument(2, null);
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return diagnostic.invalidArgument("unknown application subcommand");
    switch (mode) {
        inline else => |value| {
            diagnostic.command = "transit app " ++ @tagName(value);
            diagnostic.help = "transit app " ++ @tagName(value) ++ " --help";
        },
    }
    var result: Options = .{ .mode = mode, .flags = .{} };
    var i: usize = 1;
    while (i < args.len) {
        diagnostic.atArgument(i + 2, null);
        if (std.mem.eql(u8, args[i], "--help")) {
            diagnostic.option = "--help";
            if (result.help) return diagnostic.invalidOption("can only be specified once");
            result.help = true;
            i += 1;
            continue;
        }
        var found = false;
        inline for (@typeInfo(Flags).@"struct".field_names) |field| {
            if (std.mem.eql(u8, args[i], "--" ++ field)) {
                diagnostic.option = "--" ++ field;
                if (!allowed(mode, field)) {
                    diagnostic.show_help = true;
                    return diagnostic.invalidOption("is not supported by this command");
                }
                if (@field(result.flags, field) != null) return diagnostic.invalidOption("can only be specified once");
                if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--")) return diagnostic.invalidOption(if (comptime std.mem.eql(u8, field, "config") or std.mem.eql(u8, field, "file") or std.mem.eql(u8, field, "output")) "requires a file path" else "requires a value");
                @field(result.flags, field) = args[i + 1];
                found = true;
            }
        }
        if (!found) return diagnostic.invalidArgument("unexpected input");
        if (std.mem.eql(u8, args[i], "--after")) {
            diagnostic.atArgument(i + 3, "--after");
            result.after = std.fmt.parseInt(u32, args[i + 1], 10) catch return diagnostic.invalidOption("must be an integer from 0 through 4294967295");
        }
        i += 2;
    }
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        const required = std.mem.eql(u8, field, "config") or
            (std.mem.eql(u8, field, "file") and (mode == .install or mode == .replace)) or
            (std.mem.eql(u8, field, "operation") and (mode == .install or mode == .replace or mode == .retry)) or
            (std.mem.eql(u8, field, "application") and (mode == .status or mode == .connect)) or
            (std.mem.eql(u8, field, "caller") and mode == .connect);
        if (!result.help and required and @field(result.flags, field) == null) {
            diagnostic.atArgument(null, "--" ++ field);
            diagnostic.usage = usage(mode);
            return diagnostic.invalidOption("is required");
        }
    }
    diagnostic.atArgument(null, null);
    return result;
}
pub fn usage(mode: Mode) []const u8 {
    return switch (mode) {
        .install => "transit app install --config PATH --file DECLARATION --operation ID",
        .replace => "transit app replace --config PATH --file REPLACEMENT --operation ID",
        .retry => "transit app retry --config PATH --operation ID",
        .status => "transit app status --config PATH --application NAME",
        .connect => "transit app connect --config PATH --application NAME --caller NAME",
    };
}
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "file")) return mode == .install or mode == .replace;
    if (std.mem.eql(u8, field, "application")) return mode == .status or mode == .connect;
    if (std.mem.eql(u8, field, "output") or std.mem.eql(u8, field, "caller")) return mode == .connect;
    if (std.mem.eql(u8, field, "after")) return mode == .status;
    // Retain the existing optional operation identity on reads.
    return true;
}
