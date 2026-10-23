//! Error projection for private native callers and file-source proofs.
const std = @import("std");
const Cli = @import("cli_support").Diagnostic;
const Source = @import("FileDiagnostic.zig");
const Structured = @import("StructuredDiagnostic.zig");

pub fn render(diagnostic: Cli, out: *std.Io.Writer, err: anyerror, structured: bool, source: ?Source) !void {
    if (structured) {
        var context = diagnostic;
        if (source) |value| context.envelope = value.structured(err) catch Structured.fallback(context, err);
        const value = Structured.project(context, err) catch Structured.fallback(context, err);
        try std.json.Stringify.value(value, .{ .escape_unicode = true }, out);
        return out.writeByte('\n');
    }
    if (source) |value| return value.render(out, err, diagnostic.style);
    try diagnostic.render(out, err);
}

pub fn emit(diagnostic: Cli, io: std.Io, err: anyerror, structured: bool, source: ?Source) void {
    if (diagnostic.emitted) return;
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
    render(diagnostic, &writer.interface, err, structured, source) catch return;
    writer.interface.flush() catch {};
}
