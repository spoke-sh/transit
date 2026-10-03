//! Signed query shell. SQL/authorization/result semantics live in transit-query.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
pub fn main(init: std.process.Init) !void {
    var diagnostic: Diagnostic = .{};
    dispatch(init, &diagnostic) catch |err| {
        diagnostic.emit(init.io, err);
        std.process.exit(switch (err) {
            error.ConsoleInterrupted, error.InteractiveQueryCancelled, error.ConsoleQueryInterrupted, error.FileQueryInterrupted => 130,
            error.InvalidInvocation, error.InvalidConfiguration, error.InvalidConfigurationPath, error.InvalidCredentialFile, error.InvalidQueryInput, error.QueryInputTooLarge => 2,
            else => 1,
        });
    };
}
fn dispatch(init: std.process.Init, diagnostic: *Diagnostic) !void {
    var args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "--diagnostics=json")) {
        diagnostic.format = .json;
        diagnostic.argument_offset = 1;
        args = args[1..];
    }
    if (args.len > 1 and std.mem.eql(u8, args[1], "file-query")) return @import("FileQuery.zig").run(init, args[2..], diagnostic);
    if (args.len > 1 and std.mem.eql(u8, args[1], "app")) return @import("Application.zig").run(init, args[2..], diagnostic);
    if (args.len > 1 and std.mem.eql(u8, args[1], "mutate")) return @import("Mutations.zig").run(init, args[2..], diagnostic);
    if (args.len > 1 and std.mem.eql(u8, args[1], "catalog")) return @import("Catalog.zig").run(init, args[2..], diagnostic);
    if (args.len > 1 and std.mem.eql(u8, args[1], "__transit_child_v1")) return @import("server/Process.zig").trampoline(init, args);
    if (args.len == 3 and std.mem.eql(u8, args[1], "__transit_gateway_v1")) return @import("server/Gateway.zig").run(init, args[2]);
    if (args.len > 1 and std.mem.eql(u8, args[1], "query")) {
        diagnostic.command = "transit query";
        diagnostic.help = "transit query --help";
        if (args.len == 3 and std.mem.eql(u8, args[2], "--help")) return std.Io.File.stdout().writeStreamingAll(init.io, @import("Help.zig").query());
        if (args.len < 3 or args[2].len == 0) {
            diagnostic.usage = "transit query CONFIG";
            return diagnostic.invalidInvocation("a configuration file is required");
        }
        if (std.mem.startsWith(u8, args[2], "--")) {
            diagnostic.atArgument(2, null);
            return diagnostic.invalidArgument("unexpected input");
        }
        if (args.len > 3) {
            diagnostic.atArgument(3, null);
            return diagnostic.invalidArgument("unexpected input");
        }
        diagnostic.atFile(args[2]);
        return @import("Unified.zig").run(init, args[2], diagnostic);
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
