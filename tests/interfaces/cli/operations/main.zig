//! Uninstalled test driver for native library recovery and file-query proofs.
//! This binary is never part of the Transit runtime bundle.
const std = @import("std");
const Diagnostic = @import("cli_support").Diagnostic;

pub fn main(init: std.process.Init) void {
    var diagnostic: Diagnostic = .{};
    var structured = false;
    var source: ?@import("fixture_operations_file_diagnostic") = null;
    run(init, &diagnostic, &structured, &source) catch |err| {
        if (structured) if (diagnostic.argument) |*argument| {
            argument.* += 1;
        };
        @import("fixture_operations_diagnostic").emit(diagnostic, init.io, err, structured, source);
        std.process.exit(switch (err) {
            error.ConsoleInterrupted, error.FileQueryInterrupted => 130,
            error.InvalidInvocation, error.InvalidConfiguration, error.InvalidConfigurationPath, error.InvalidCredentialFile, error.InvalidQueryInput, error.QueryInputTooLarge => 2,
            else => 1,
        });
    };
}

fn run(init: std.process.Init, diagnostic: *Diagnostic, structured: *bool, source: *?@import("fixture_operations_file_diagnostic")) !void {
    var args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1 and std.mem.eql(u8, args[1], "--structured")) {
        structured.* = true;
        args = args[1..];
    }
    if (args.len < 2) return error.InvalidInvocation;
    if (std.mem.eql(u8, args[1], "app")) return @import("fixture_operations_application").run(init, args[2..], diagnostic);
    if (std.mem.eql(u8, args[1], "auth")) return @import("fixture_operations_authorization").run(init, args[2..], diagnostic);
    if (std.mem.eql(u8, args[1], "direct-catalog")) return @import("fixture_operations_direct_authorization").run(init, args[2..], diagnostic);
    if (std.mem.eql(u8, args[1], "file-query")) return @import("fixture_operations_file_query").run(init, args[2..], diagnostic, source);
    if (args.len == 3 and std.mem.eql(u8, args[1], "query")) {
        diagnostic.command = "query fixture";
        diagnostic.atFile(args[2]);
        return @import("fixture_operations_unified").run(init, args[2], diagnostic, structured.*);
    }
    return error.InvalidInvocation;
}

test {
    _ = @import("fixture_operations_recovery_tests");
}
