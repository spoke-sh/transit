const std = @import("std");
const workspace = @import("transitc_workspace");
const version = @import("build_options");
const help =
    \\transitc — the Transit language compiler
    \\
    \\Usage: transitc build [options]
    \\       transitc --help | --version
    \\
    \\Compile .transit source into verified SQL without connecting to a database.
    \\
    \\Options:
    \\  -f FILE                 Build entry (default: build.transit)
    \\  --target NAME           Select a declared target
    \\  --out DIRECTORY         Publish to a new explicit directory
    \\  --check                 Check without publishing artifacts
    \\  --fetch                 Fetch pinned dependencies and publish transit.lock
    \\  --override NAME=DIR     Explicit local dependency override
    \\  --format text|json      Diagnostic and result format (default: text)
    \\  --color auto|off|on     Human diagnostic color (default: auto)
    \\  --help                  Show this help
    \\
    \\Ordinary builds resolve dependencies offline. Only --fetch accesses repositories.
    \\SQL execution and runtime test hosting remain in Transit.
    \\
;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 1 or (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")))) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) return std.Io.File.stdout().writeStreamingAll(init.io, "transitc " ++ version.version ++ " (" ++ version.revision ++ ")\n");
    var diagnostic: workspace.Diagnostic = .{};
    if (args.len < 2 or !std.mem.eql(u8, args[1], "build")) {
        try std.Io.File.stderr().writeStreamingAll(init.io, "transitc: unsupported command; use transitc --help\n");
        std.process.exit(2);
    }
    const options = workspace.Options.parse(args[2..], &diagnostic) catch |err| return fail(init.io, &diagnostic, err);
    if (options.help) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    workspace.Build.run(init, options, &diagnostic, version.revision) catch |err| return fail(init.io, &diagnostic, err);
}
fn fail(io: std.Io, diagnostic: *workspace.Diagnostic, err: anyerror) void {
    if (diagnostic.machine) {
        workspace.Build.emitFailure(io, diagnostic, err) catch {};
    } else if (!diagnostic.emitted) {
        var buffer: [8192]u8 = undefined;
        var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
        diagnostic.render(&writer.interface, err) catch {};
        writer.interface.flush() catch {};
    }
    std.process.exit(if (err == error.InvalidInvocation) 2 else 1);
}
