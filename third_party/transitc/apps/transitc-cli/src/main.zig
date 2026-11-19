const std = @import("std");
const workspace = @import("transitc_workspace");
const version = @import("build_options");
const help =
    \\transitc — the Transit language compiler
    \\
    \\Usage: transitc build [options]
    \\       transitc test [options]
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
    \\  --runtime FILE          Transit test host executable (test only)
    \\
    \\Ordinary builds resolve dependencies offline. Only --fetch accesses repositories.
    \\Tests compile the complete suite, then run isolated cases through the Transit host.
    \\Test options exclude --out, --check and --fetch; the default test target is tests.
    \\
;
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 1 or (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h")))) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) return std.Io.File.stdout().writeStreamingAll(init.io, "transitc " ++ version.version ++ " (" ++ version.revision ++ ")\n");
    var diagnostic: workspace.Diagnostic = .{};
    const testing = args.len >= 2 and std.mem.eql(u8, args[1], "test");
    if (args.len < 2 or (!testing and !std.mem.eql(u8, args[1], "build"))) {
        try std.Io.File.stderr().writeStreamingAll(init.io, "transitc: unsupported command; use transitc --help\n");
        std.process.exit(2);
    }
    const options = workspace.Options.parseCommand(args[2..], &diagnostic, testing, "transitc") catch |err| return fail(init.io, &diagnostic, err);
    if (options.help) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    if (testing) {
        var host: workspace.TestProcessHost = .{ .executable = options.runtime orelse init.environ_map.get("TRANSIT_TEST_RUNTIME") orelse version.test_runtime };
        workspace.Test.run(init, options, &diagnostic, version.revision, &host) catch |err| return fail(init.io, &diagnostic, err);
    } else workspace.Build.run(init, options, &diagnostic, version.revision) catch |err| return fail(init.io, &diagnostic, err);
}
fn fail(io: std.Io, diagnostic: *workspace.Diagnostic, err: anyerror) void {
    if (err == error.TestSuiteFailed) std.process.exit(1);
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
