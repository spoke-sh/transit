//! Offline build invocation; no connection or startup configuration defaults.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub const Override = struct { name: []const u8, directory: []const u8 };
const Self = @This();
entry: []const u8 = "build.transit",
target: []const u8 = "default",
out: ?[]const u8 = null,
check: bool = false,
fetch: bool = false,
json: bool = false,
help: bool = false,
overrides: [255]Override = undefined,
overrides_len: usize = 0,
pub fn parse(args: []const []const u8, diagnostic: *Diagnostic) !Self {
    diagnostic.command = "transit build";
    diagnostic.help = "transit build --help";
    for (args, 0..) |arg, index| if (std.mem.eql(u8, arg, "--format") and index + 1 < args.len and std.mem.eql(u8, args[index + 1], "json")) {
        diagnostic.machine = true;
    };
    var result: Self = .{};
    var seen: u16 = 0;
    var index: usize = 0;
    const names = [_][]const u8{ "-f", "--target", "--out", "--check", "--fetch", "--format", "--help", "--override" };
    while (index < args.len) : (index += 1) {
        const selected = for (names, 0..) |name, n| {
            if (std.mem.eql(u8, name, args[index])) break n;
        } else {
            diagnostic.atArgument(index + 2, null);
            return diagnostic.invalidArgument("unknown build option");
        };
        diagnostic.atArgument(index + 2, names[selected]);
        const mask = @as(u16, 1) << @intCast(selected);
        if (selected != 7 and seen & mask != 0) return diagnostic.invalidOption("can only be specified once");
        seen |= mask;
        switch (selected) {
            3 => result.check = true,
            4 => result.fetch = true,
            6 => result.help = true,
            else => {
                index += 1;
                if (index == args.len or args[index].len == 0 or args[index][0] == '-') return diagnostic.invalidOption("requires a value");
                const value = args[index];
                switch (selected) {
                    0 => result.entry = value,
                    1 => {
                        if (value.len > 63) return diagnostic.invalidOption("requires a source target name");
                        for (value, 0..) |byte, n| if (!(std.ascii.isAlphabetic(byte) or byte == '_' or n > 0 and std.ascii.isDigit(byte))) return diagnostic.invalidOption("requires a source target name");
                        result.target = value;
                    },
                    2 => result.out = value,
                    5 => {
                        if (!std.mem.eql(u8, value, "json") and !std.mem.eql(u8, value, "text")) return diagnostic.invalidOption("must be text or json");
                        result.json = std.mem.eql(u8, value, "json");
                    },
                    7 => {
                        const split = std.mem.indexOfScalar(u8, value, '=') orelse return diagnostic.invalidOption("requires NAME=DIRECTORY");
                        if (split == 0 or split == value.len - 1 or result.overrides_len == result.overrides.len) return diagnostic.invalidOption("requires a bounded NAME=DIRECTORY override");
                        const name = value[0..split];
                        if (name.len > 63) return diagnostic.invalidOption("requires a lowercase package name");
                        for (name, 0..) |byte, n| if (!(std.ascii.isLower(byte) or byte == '_' or n > 0 and std.ascii.isDigit(byte))) return diagnostic.invalidOption("requires a lowercase package name");
                        for (result.overrides[0..result.overrides_len]) |prior| if (std.mem.eql(u8, name, prior.name)) return diagnostic.invalidOption("duplicate package override");
                        result.overrides[result.overrides_len] = .{ .name = name, .directory = value[split + 1 ..] };
                        result.overrides_len += 1;
                    },
                    else => unreachable,
                }
            },
        }
    }
    if (result.fetch and (result.check or result.out != null or result.overrides_len > 0)) return diagnostic.invalidInvocation("--fetch cannot combine with --check, --out or --override");
    if (result.check and result.out != null) return diagnostic.invalidInvocation("--check cannot combine with --out");
    diagnostic.atArgument(null, null);
    return result;
}
test "build options have no connection defaults and reject conflicting actions" {
    var diagnostic: Diagnostic = .{};
    const options = try parse(&.{ "--target", "release", "--override", "common=../common", "--check", "--format", "json" }, &diagnostic);
    try std.testing.expect(options.check and options.json and diagnostic.machine);
    try std.testing.expectEqualStrings("common", options.overrides[0].name);
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "--fetch", "--out", "out" }, &diagnostic));
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "--config", "connection.json" }, &diagnostic));
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "--target", "../escape" }, &diagnostic));
}

test "unknown build options retain a redacted argument location" {
    inline for (.{ &[_][]const u8{"private-value"}, &[_][]const u8{ "--check", "private-value" } }) |args| {
        var diagnostic: Diagnostic = .{};
        try std.testing.expectError(error.InvalidInvocation, parse(args, &diagnostic));
        try std.testing.expectEqual(args.len + 1, diagnostic.argument.?);
        try std.testing.expectEqual(null, diagnostic.option);
        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        try diagnostic.render(&output.writer, error.InvalidInvocation);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), "unknown build option at argument") != null);
        try std.testing.expect(std.mem.indexOf(u8, output.written(), "private-value") == null);
    }
}
