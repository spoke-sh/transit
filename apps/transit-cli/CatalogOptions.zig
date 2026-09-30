//! Catalog invocation validation precedes configuration, credentials and I/O.
const std = @import("std");
const c = @import("transit_catalog");
const Diagnostic = @import("Diagnostic.zig");
pub const Mode = enum { capabilities, describe, compile, @"prepare-initialize", @"prepare-create", @"prepare-policy", submit, observe, disposition, status };
pub const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, output: ?[]const u8 = null, operation: ?[]const u8 = null, object: ?[]const u8 = null, table: ?[]const u8 = null, input: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags = .{}, table: u32 = 0, input: u64 = 0, help: bool = false };
fn preparation(mode: Mode) bool {
    return mode == .@"prepare-initialize" or mode == .@"prepare-create" or mode == .@"prepare-policy";
}
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "config")) return mode != .capabilities;
    if (std.mem.eql(u8, field, "file")) return mode != .capabilities and mode != .describe;
    if (std.mem.eql(u8, field, "output")) return mode == .compile or preparation(mode);
    if (std.mem.eql(u8, field, "operation") or std.mem.eql(u8, field, "object") or std.mem.eql(u8, field, "table")) return mode == .compile;
    if (std.mem.eql(u8, field, "input")) return mode == .observe or mode == .disposition;
    return false;
}
pub fn usage(mode: Mode) []const u8 {
    return switch (mode) {
        .capabilities => "transit catalog capabilities",
        .describe => "transit catalog describe --config PATH",
        .compile => "transit catalog compile --config PATH --operation ID --object ID --table ID --file SQL --output COMPILED",
        .@"prepare-initialize" => "transit catalog prepare-initialize --config PATH --file CONFIGURATION --output PREPARED",
        .@"prepare-create" => "transit catalog prepare-create --config PATH --file COMPILED --output PREPARED",
        .@"prepare-policy" => "transit catalog prepare-policy --config PATH --file POLICY_CHANGE --output PREPARED",
        .submit => "transit catalog submit --config PATH --file PREPARED",
        .observe => "transit catalog observe --config PATH --file PREPARED --input POSITION",
        .disposition => "transit catalog disposition --config PATH --file PREPARED --input POSITION",
        .status => "transit catalog status --config PATH --file COMPILED",
    };
}
pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "transit catalog";
    diagnostic.help = "transit catalog --help";
    diagnostic.atArgument(2, null);
    if (args.len == 0) return diagnostic.invalidInvocation("a catalog subcommand is required");
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return diagnostic.invalidArgument("unknown catalog subcommand");
    switch (mode) {
        inline else => |value| {
            diagnostic.command = "transit catalog " ++ @tagName(value);
            diagnostic.help = "transit catalog " ++ @tagName(value) ++ " --help";
        },
    }
    var result: Options = .{ .mode = mode };
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
        if (std.mem.eql(u8, args[i], "--operation") or std.mem.eql(u8, args[i], "--object")) {
            const value = c.Bridge.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical positive uint64 integer");
            if (value == 0) return diagnostic.invalidOption("must be a canonical positive uint64 integer");
        } else if (std.mem.eql(u8, args[i], "--table")) {
            const value = c.Bridge.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical integer from 1 through 4294967295");
            if (value == 0 or value > std.math.maxInt(u32)) return diagnostic.invalidOption("must be a canonical integer from 1 through 4294967295");
            result.table = @intCast(value);
        } else if (std.mem.eql(u8, args[i], "--input")) {
            result.input = c.Bridge.unsigned(args[i + 1]) catch return diagnostic.invalidOption("must be a canonical positive native position");
            c.Model.nativeId(result.input) catch return diagnostic.invalidOption("must be a canonical positive native position");
        }
        i += 2;
    }
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        if (!result.help and allowed(mode, field) and @field(result.flags, field) == null) {
            diagnostic.atArgument(null, "--" ++ field);
            diagnostic.usage = usage(mode);
            return diagnostic.invalidOption("is required");
        }
    }
    diagnostic.atArgument(null, null);
    return result;
}
pub fn help(io: std.Io, mode: Mode) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(io, &buffer);
    const out = &writer.interface;
    try out.print("Usage: {s}\n\nOptions:\n  --help  Show this help\n", .{usage(mode)});
    inline for (@typeInfo(Flags).@"struct".field_names) |field| {
        if (allowed(mode, field)) try out.writeAll("  --" ++ field ++ " " ++ (if (comptime std.mem.eql(u8, field, "config")) "PATH  Explicit catalog connection" else if (comptime std.mem.eql(u8, field, "file")) "PATH  Input SQL, typed control or saved JSON artifact" else if (comptime std.mem.eql(u8, field, "output")) "PATH  New private artifact; existing paths are refused" else if (comptime std.mem.eql(u8, field, "operation")) "ID  Positive uint64 application operation" else if (comptime std.mem.eql(u8, field, "object")) "ID  Positive uint64 catalog object" else if (comptime std.mem.eql(u8, field, "table")) "ID  Positive uint32 physical Table" else "POSITION  Receipt position for this exact saved command") ++ "\n");
    }
    try out.writeAll("\nOnly submit sends a command. Save each prepared artifact before submitting.\nA receipt is admission; observe processing and read status or disposition.\nConfiguration and recovery: apps/transit-cli/docs/catalog.md\n");
    try out.flush();
}
