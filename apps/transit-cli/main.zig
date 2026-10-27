//! Local server and shared SQL console entrypoint.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub fn main(init: std.process.Init) !void {
    var diagnostic: Diagnostic = .{};
    dispatch(init, &diagnostic) catch |err| {
        diagnostic.emit(init.io, err);
        std.process.exit(switch (err) {
            error.ConsoleInterrupted, error.InteractiveQueryCancelled, error.ConsoleQueryInterrupted => 130,
            error.InvalidInvocation, error.InvalidConfiguration, error.InvalidConfigurationPath, error.InvalidCredentialFile, error.InvalidQueryInput, error.QueryInputTooLarge => 2,
            else => 1,
        });
    };
}
fn dispatch(init: std.process.Init, diagnostic: *Diagnostic) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "__transit_child_v1")) return @import("server/Process.zig").trampoline(init, args);
    if (args.len == 3 and std.mem.eql(u8, args[1], "__transit_gateway_v1")) return @import("server/Gateway.zig").run(init, args[2]);
    const runtime = @import("RuntimeRole.zig");
    if (args.len >= 3 and std.mem.eql(u8, args[1], runtime.argument)) {
        return runtime.run(init, std.meta.stringToEnum(runtime.Role, args[2]) orelse return error.InvalidInvocation);
    }
    const options = try @import("Options.zig").parseDiagnosed(args[1..], init.environ_map.get("TRANSIT_CONSOLE_CONFIG"), diagnostic);
    if (options.command == .help or options.help) return @import("Options.zig").writeHelp(init.io, options);
    return switch (options.command) {
        .version => std.Io.File.stdout().writeStreamingAll(init.io, "Transit development; CLI contract 1\n"),
        .console => @import("Console.zig").run(init, options, diagnostic),
        .server => @import("server/Server.zig").run(init, options, diagnostic),
        .help => unreachable,
    };
}
