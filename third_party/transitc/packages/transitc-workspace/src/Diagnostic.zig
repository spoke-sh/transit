//! Invocation and compiler failure state. Never retain unknown argument values.
const std = @import("std");
const Self = @This();
command: []const u8 = "transitc build",
help: []const u8 = "transitc build --help",
machine: bool = false,
emitted: bool = false,
color_mode: @import("Style.zig").Mode = .auto,
style: @import("Style.zig") = .{},
envelope: ?@import("transit_protocol").Diagnostic = null,
argument: ?usize = null,
option: ?[]const u8 = null,
summary: ?[]const u8 = null,
presentation: enum { invocation, option, argument } = .invocation,
pub fn atArgument(self: *Self, argument: ?usize, option: ?[]const u8) void {
    self.argument = argument;
    self.option = option;
}
pub fn invalidInvocation(self: *Self, summary: []const u8) anyerror {
    self.summary = summary;
    self.presentation = .invocation;
    return error.InvalidInvocation;
}
pub fn invalidOption(self: *Self, summary: []const u8) anyerror {
    self.summary = summary;
    self.presentation = .option;
    return error.InvalidInvocation;
}
pub fn invalidArgument(self: *Self, summary: []const u8) anyerror {
    self.summary = summary;
    self.presentation = .argument;
    return error.InvalidInvocation;
}
pub fn render(self: Self, out: *std.Io.Writer, err: anyerror) !void {
    try out.writeAll("error: ");
    switch (self.presentation) {
        .invocation => try out.writeAll(self.summary orelse @errorName(err)),
        .option => try out.print("{s} {s}", .{ self.option.?, self.summary.? }),
        .argument => try out.print("{s} at argument {d}", .{ self.summary.?, self.argument.? }),
    }
    try out.writeByte('\n');
}
