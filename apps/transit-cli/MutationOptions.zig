//! Explicit file-based mutation commands; validate every argument before I/O.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Mode = enum { capabilities, describe, compile, next, prepare, submit, observe, rejection, status };
pub const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, output: ?[]const u8 = null, name: ?[]const u8 = null, namespace: ?[]const u8 = null, input: ?[]const u8 = null, control: ?[]const u8 = null };
pub const Options = struct { mode: Mode, flags: Flags = .{}, namespace: u64 = 0, input: u64 = 0, control: enum { apply, cancel } = .apply, help: bool = false };
fn allowed(mode: Mode, field: []const u8) bool {
    if (std.mem.eql(u8, field, "config")) return mode != .capabilities;
    if (std.mem.eql(u8, field, "file")) return mode != .capabilities and mode != .describe;
    if (std.mem.eql(u8, field, "output")) return mode == .compile or mode == .next or mode == .prepare;
    if (std.mem.eql(u8, field, "name") or std.mem.eql(u8, field, "namespace")) return mode == .compile;
    if (std.mem.eql(u8, field, "input")) return mode == .observe or mode == .rejection;
    if (std.mem.eql(u8, field, "control")) return mode == .prepare;
    return false;
}
pub fn usage(mode: Mode) []const u8 {
    return switch (mode) {
        .capabilities => "transit mutate capabilities",
        .describe => "transit mutate describe --config PATH",
        .compile => "transit mutate compile --config PATH --name NAME --namespace ID --file SQL --output COMPILED",
        .next => "transit mutate next --config PATH --file COMPILED --output PREPARED",
        .prepare => "transit mutate prepare --config PATH --file COMPILED --control apply|cancel --output PREPARED",
        .submit => "transit mutate submit --config PATH --file PREPARED",
        .observe => "transit mutate observe --config PATH --file PREPARED --input POSITION",
        .rejection => "transit mutate rejection --config PATH --file PREPARED --input POSITION",
        .status => "transit mutate status --config PATH --file COMPILED",
    };
}
pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "transit mutate";
    diagnostic.help = "transit mutate --help";
    diagnostic.atArgument(2, null);
    if (args.len == 0) return diagnostic.invalidInvocation("a mutation subcommand is required");
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return diagnostic.invalidArgument("unknown mutation subcommand");
    switch (mode) {
        inline else => |value| {
            diagnostic.command = "transit mutate " ++ @tagName(value);
            diagnostic.help = "transit mutate " ++ @tagName(value) ++ " --help";
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
        if (std.mem.eql(u8, args[i], "--namespace")) {
            result.namespace = std.fmt.parseInt(u64, args[i + 1], 10) catch return diagnostic.invalidOption("must be a positive uint64 integer");
            if (result.namespace == 0) return diagnostic.invalidOption("must be a positive uint64 integer");
        } else if (std.mem.eql(u8, args[i], "--input")) {
            result.input = std.fmt.parseInt(u64, args[i + 1], 10) catch return diagnostic.invalidOption("must be a positive native position");
            if (result.input == 0 or result.input > @import("transit_query").protocol.max_counter) return diagnostic.invalidOption("must be a positive native position");
        } else if (std.mem.eql(u8, args[i], "--control")) {
            result.control = std.meta.stringToEnum(@FieldType(Options, "control"), args[i + 1]) orelse return diagnostic.invalidOption("must be apply or cancel");
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
        if (allowed(mode, field)) try out.writeAll("  --" ++ field ++ " " ++ (if (comptime std.mem.eql(u8, field, "config")) "PATH  Explicit writer connection" else if (comptime std.mem.eql(u8, field, "file")) "PATH  Input SQL or saved JSON artifact" else if (comptime std.mem.eql(u8, field, "output")) "PATH  New private artifact; existing paths are refused" else if (comptime std.mem.eql(u8, field, "name")) "NAME  Declared SQL table name" else if (comptime std.mem.eql(u8, field, "namespace")) "ID  Positive uint64 request namespace" else if (comptime std.mem.eql(u8, field, "input")) "POSITION  Receipt position for this exact saved command" else "apply|cancel  Prepare the selected control") ++ "\n");
    }
    try out.writeAll("\nOnly submit sends a command. Save each prepared artifact before submitting.\nA receipt is admission; observe input processing and inspect durable status.\nConfiguration and recovery: apps/transit-cli/docs/mutations.md\n");
    try out.flush();
}
