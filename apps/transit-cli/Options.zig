//! Explicit command options with an optional console configuration default.
const std = @import("std");
const Diagnostic = @import("Diagnostic.zig");
const sdk = @import("transit_sql_client");
pub const Format = enum { table, json };
pub const MigrateAction = sdk.protocol.Migration.ActionKind;
pub const max_migrate_files = 16;
pub const Options = struct {
    command: enum { help, version, console, server, migrate },
    path: ?[]const u8 = null,
    path_from_environment: bool = false,
    format: ?Format = null,
    sql: ?[]const u8 = null,
    parameters: ?[]const u8 = null,
    script: ?[]const u8 = null,
    rc: ?[]const u8 = null,
    no_rc: bool = false,
    no_ui: bool = false,
    help: bool = false,
    migrate_action: ?MigrateAction = null,
    migrate_dir: ?[]const u8 = null,
    migrate_files: [max_migrate_files][]const u8 = undefined,
    migrate_files_len: usize = 0,
    migrate_plan: ?[]const u8 = null,
    migrate_out: ?[]const u8 = null,
    migrate_database: ?[]const u8 = null,
    migrate_schema: ?[]const u8 = null,
    migrate_branch: ?u64 = null,
    migrate_account: ?[]const u8 = null,
    migrate_attempt: ?[16]u8 = null,
    allow_grants: bool = false,
};
pub fn parse(args: []const []const u8) !Options {
    return parseWithConsoleConfig(args, null);
}
pub fn parseWithConsoleConfig(args: []const []const u8, console_config: ?[]const u8) !Options {
    var diagnostic: Diagnostic = .{};
    return parseDiagnosed(args, console_config, &diagnostic);
}
pub fn parseDiagnosed(args: []const []const u8, console_config: ?[]const u8, diagnostic: *Diagnostic) !Options {
    if (args.len == 0) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--help")) return .{ .command = .help };
    if (args.len == 1 and std.mem.eql(u8, args[0], "--version")) return .{ .command = .version };
    var result: Options = .{ .command = if (std.mem.eql(u8, args[0], "console")) .console else if (std.mem.eql(u8, args[0], "server")) .server else if (std.mem.eql(u8, args[0], "migrate")) .migrate else {
        diagnostic.atArgument(1, null);
        return diagnostic.invalidArgument("unknown command or misplaced global option");
    } };
    if (result.command == .migrate) return parseMigrate(args, console_config, &result, diagnostic);
    const server = result.command == .server;
    diagnostic.command = if (server) "transit server" else "transit console";
    diagnostic.help = if (server) "transit server --help" else "transit console --help";
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const known = for ([_][]const u8{ "--help", "--no-ui", "--config", "--format", "-c", "-f", "--parameters", "--init", "--no-rc", "--dir", "--plan", "--out", "--database", "--schema", "--branch", "--account", "--attempt", "--allow-grants" }) |name| {
            if (std.mem.eql(u8, arg, name)) break name;
        } else null;
        diagnostic.atArgument(i + 1, known);
        const option = known orelse return diagnostic.invalidArgument("unexpected input");
        if (std.mem.eql(u8, option, "--dir") or std.mem.eql(u8, option, "--plan") or std.mem.eql(u8, option, "--out") or std.mem.eql(u8, option, "--database") or std.mem.eql(u8, option, "--schema") or std.mem.eql(u8, option, "--branch") or std.mem.eql(u8, option, "--account") or std.mem.eql(u8, option, "--attempt") or std.mem.eql(u8, option, "--allow-grants")) {
            diagnostic.show_help = true;
            return diagnostic.invalidOption("is not supported by this command");
        }
        if ((!server and std.mem.eql(u8, option, "--no-ui")) or (server and (std.mem.eql(u8, option, "--format") or std.mem.eql(u8, option, "-c") or std.mem.eql(u8, option, "-f") or std.mem.eql(u8, option, "--parameters") or std.mem.eql(u8, option, "--init") or std.mem.eql(u8, option, "--no-rc")))) {
            diagnostic.show_help = true;
            return diagnostic.invalidOption("is not supported by this command");
        }
        if (std.mem.eql(u8, option, "--help")) {
            if (result.help) return duplicate(diagnostic);
            result.help = true;
        } else if (std.mem.eql(u8, option, "--no-ui")) {
            if (result.no_ui) return duplicate(diagnostic);
            result.no_ui = true;
        } else if (std.mem.eql(u8, option, "--no-rc")) {
            if (result.no_rc) return duplicate(diagnostic);
            result.no_rc = true;
        } else {
            const target: ?*?[]const u8 = if (std.mem.eql(u8, option, "--config")) &result.path else if (std.mem.eql(u8, option, "-c")) &result.sql else if (std.mem.eql(u8, option, "-f")) &result.script else if (std.mem.eql(u8, option, "--parameters")) &result.parameters else if (std.mem.eql(u8, option, "--init")) &result.rc else blk: {
                if (result.format != null) return duplicate(diagnostic);
                if (i + 1 == args.len) return diagnostic.invalidOption("must be table or json");
                i += 1;
                result.format = std.meta.stringToEnum(Format, args[i]) orelse return diagnostic.invalidOption("must be table or json");
                break :blk null;
            };
            if (target) |slot| {
                if (slot.* != null) return duplicate(diagnostic);
                if (i + 1 == args.len or args[i + 1].len == 0 or (std.mem.startsWith(u8, args[i + 1], "--") and !std.mem.eql(u8, option, "-c")) or std.mem.eql(u8, args[i + 1], "-f") or std.mem.eql(u8, args[i + 1], "-c")) return diagnostic.invalidOption(if (std.mem.eql(u8, option, "-c")) "requires a SQL statement" else "requires a file path");
                i += 1;
                slot.* = args[i];
            }
        }
    }
    if (result.sql != null and result.script != null) return diagnostic.invalidInvocation("-c and -f cannot be combined");
    if (result.parameters != null and result.sql == null) return diagnostic.invalidInvocation("--parameters requires -c SQL");
    if (result.rc != null and result.no_rc) return diagnostic.invalidInvocation("--init and --no-rc cannot be combined");
    if (!server and result.path == null) if (console_config) |path| {
        if (path.len > 0) {
            result.path = path;
            result.path_from_environment = true;
        }
    };
    diagnostic.atArgument(null, null);
    diagnostic.usage = null;
    return result;
}

fn parseMigrate(args: []const []const u8, console_config: ?[]const u8, result: *Options, diagnostic: *Diagnostic) !Options {
    diagnostic.command = "transit migrate";
    diagnostic.help = "transit migrate --help";
    var i: usize = 1;
    if (i < args.len and !std.mem.startsWith(u8, args[i], "-")) {
        diagnostic.atArgument(i + 1, null);
        result.migrate_action = std.meta.stringToEnum(MigrateAction, args[i]) orelse return diagnostic.invalidArgument("unknown migrate action (expected plan, inspect, apply, status, resume or verify)");
        i += 1;
    }
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const known = for ([_][]const u8{ "--help", "--dir", "-f", "--plan", "--out", "--config", "--database", "--schema", "--branch", "--account", "--attempt", "--allow-grants", "--format", "--no-ui", "-c", "--parameters", "--init", "--no-rc" }) |name| {
            if (std.mem.eql(u8, arg, name)) break name;
        } else null;
        diagnostic.atArgument(i + 1, known);
        const option = known orelse return diagnostic.invalidArgument("unexpected input");
        if (std.mem.eql(u8, option, "--no-ui") or std.mem.eql(u8, option, "-c") or std.mem.eql(u8, option, "--parameters") or std.mem.eql(u8, option, "--init") or std.mem.eql(u8, option, "--no-rc")) {
            diagnostic.show_help = true;
            return diagnostic.invalidOption("is not supported by this command");
        }
        if (std.mem.eql(u8, option, "--help")) {
            if (result.help) return duplicate(diagnostic);
            result.help = true;
        } else if (std.mem.eql(u8, option, "--allow-grants")) {
            if (result.allow_grants) return duplicate(diagnostic);
            result.allow_grants = true;
        } else if (std.mem.eql(u8, option, "--format")) {
            if (result.format != null) return duplicate(diagnostic);
            if (i + 1 == args.len) return diagnostic.invalidOption("must be table or json");
            i += 1;
            result.format = std.meta.stringToEnum(Format, args[i]) orelse return diagnostic.invalidOption("must be table or json");
        } else if (std.mem.eql(u8, option, "-f")) {
            if (result.migrate_files_len >= max_migrate_files) return diagnostic.invalidOption("exceeds the 16-file limit");
            if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "-")) return diagnostic.invalidOption("requires a file path");
            i += 1;
            result.migrate_files[result.migrate_files_len] = args[i];
            result.migrate_files_len += 1;
        } else if (std.mem.eql(u8, option, "--branch")) {
            if (result.migrate_branch != null) return duplicate(diagnostic);
            if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "-")) return diagnostic.invalidOption("requires a positive branch ID");
            i += 1;
            const branch = std.fmt.parseInt(u64, args[i], 10) catch return diagnostic.invalidOption("requires a positive branch ID");
            if (branch == 0) return diagnostic.invalidOption("requires a positive branch ID");
            result.migrate_branch = branch;
        } else if (std.mem.eql(u8, option, "--attempt")) {
            if (result.migrate_attempt != null) return duplicate(diagnostic);
            if (i + 1 == args.len or args[i + 1].len != 32) return diagnostic.invalidOption("requires a 32-character hexadecimal attempt ID");
            i += 1;
            var attempt: [16]u8 = undefined;
            _ = std.fmt.hexToBytes(&attempt, args[i]) catch return diagnostic.invalidOption("requires a 32-character hexadecimal attempt ID");
            result.migrate_attempt = attempt;
        } else {
            const target: *?[]const u8 = if (std.mem.eql(u8, option, "--config"))
                &result.path
            else if (std.mem.eql(u8, option, "--dir"))
                &result.migrate_dir
            else if (std.mem.eql(u8, option, "--plan"))
                &result.migrate_plan
            else if (std.mem.eql(u8, option, "--out"))
                &result.migrate_out
            else if (std.mem.eql(u8, option, "--database"))
                &result.migrate_database
            else if (std.mem.eql(u8, option, "--schema"))
                &result.migrate_schema
            else
                &result.migrate_account;
            if (target.* != null) return duplicate(diagnostic);
            if (i + 1 == args.len or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "-")) {
                return diagnostic.invalidOption(if (std.mem.eql(u8, option, "--database") or std.mem.eql(u8, option, "--schema") or std.mem.eql(u8, option, "--account")) "requires a name" else "requires a file path");
            }
            i += 1;
            target.* = args[i];
        }
    }
    if (!result.help) {
        const action = result.migrate_action orelse {
            diagnostic.show_help = true;
            return diagnostic.invalidInvocation("requires a migration action (plan, inspect, apply, status, resume or verify)");
        };
        if (result.migrate_dir != null and result.migrate_plan != null) return diagnostic.invalidInvocation("--dir and --plan cannot be combined");
        if (result.migrate_files_len > 0 and result.migrate_plan != null) return diagnostic.invalidInvocation("-f and --plan cannot be combined");
        if (result.migrate_out != null and action != .plan) return diagnostic.invalidInvocation("--out is only supported with migrate plan");
        if (result.migrate_plan != null and action == .plan) return diagnostic.invalidInvocation("--plan cannot be used with migrate plan; use --out to write a plan file");
        const has_sources = result.migrate_dir != null or result.migrate_files_len > 0 or result.migrate_plan != null;
        switch (action) {
            .plan, .inspect, .apply => if (!has_sources) return diagnostic.invalidInvocation("requires migration sources (--dir, -f or --plan)"),
            .status, .@"resume", .verify => {},
        }
    }
    if (result.path == null) if (console_config) |path| {
        if (path.len > 0) {
            result.path = path;
            result.path_from_environment = true;
        }
    };
    diagnostic.atArgument(null, null);
    diagnostic.usage = null;
    return result.*;
}

fn duplicate(diagnostic: *Diagnostic) anyerror {
    return diagnostic.invalidOption("can only be specified once");
}
pub fn writeHelp(io: std.Io, options: Options) !void {
    return std.Io.File.stdout().writeStreamingAll(io, switch (options.command) {
        .server => @import("Help.zig").server,
        .console => @import("Help.zig").console,
        .migrate => @import("Help.zig").migrate,
        else => @import("Help.zig").root,
    });
}

test "connection options override the environment and server discovery is independent" {
    try std.testing.expect((try parse(&.{"console"})).path == null);
    try std.testing.expect((try parseWithConsoleConfig(&.{"console"}, "")).path == null);
    const fallback = try parseWithConsoleConfig(&.{"console"}, "/local/console.json");
    try std.testing.expectEqualStrings("/local/console.json", fallback.path.?);
    const explicit = try parseWithConsoleConfig(&.{ "console", "--config", "other.json" }, "/local/console.json");
    try std.testing.expectEqualStrings("other.json", explicit.path.?);
    try std.testing.expectError(error.InvalidInvocation, parseWithConsoleConfig(&.{ "console", "--config", "one", "--config", "two" }, "/local/console.json"));
    try std.testing.expect((try parseWithConsoleConfig(&.{"server"}, "/local/console.json")).path == null);
    const server = try parse(&.{ "server", "--config", "server.json" });
    try std.testing.expectEqual(.server, server.command);
    try std.testing.expect((try parseWithConsoleConfig(&.{ "console", "--help" }, null)).help);
}

test "server defaults to UI and accepts only one opt-out" {
    try std.testing.expect(!(try parse(&.{ "server", "--config", "server.json" })).no_ui);
    try std.testing.expect((try parse(&.{ "server", "--config", "server.json", "--no-ui" })).no_ui);
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "server", "--initialize" }));
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "server", "--config", "server.json", "--no-ui", "--no-ui" }));
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "server", "--config", "server.json", "--ui" }));
    try std.testing.expectError(error.InvalidInvocation, parse(&.{ "console", "--config", "console.json", "--no-ui" }));
}

test "parameter files are explicit one-statement console inputs" {
    const options = try parse(&.{ "console", "--parameters", "bindings.json", "-c", "SELECT * FROM items LIMIT $1" });
    try std.testing.expectEqualStrings("bindings.json", options.parameters.?);
    for ([_][]const []const u8{
        &.{ "console", "--parameters", "bindings.json" },
        &.{ "console", "--parameters", "bindings.json", "-f", "queries.sql" },
        &.{ "server", "--parameters", "bindings.json" },
        &.{ "console", "--parameters", "one", "--parameters", "two", "-c", "SELECT * FROM items" },
    }) |args| try std.testing.expectError(error.InvalidInvocation, parse(args));
}

test "migrate parses actions, target assertions and rejects console/server flags" {
    const t = std.testing;
    const plan_opts = try parse(&.{ "migrate", "plan", "--dir", "migrations", "--out", "plan.json", "--database", "transit", "--schema", "public", "--branch", "1", "--format", "json" });
    try t.expectEqual(.migrate, plan_opts.command);
    try t.expectEqual(MigrateAction.plan, plan_opts.migrate_action.?);
    try t.expectEqualStrings("migrations", plan_opts.migrate_dir.?);
    try t.expectEqualStrings("plan.json", plan_opts.migrate_out.?);
    try t.expectEqualStrings("transit", plan_opts.migrate_database.?);
    try t.expectEqualStrings("public", plan_opts.migrate_schema.?);
    try t.expectEqual(1, plan_opts.migrate_branch.?);
    try t.expectEqual(Format.json, plan_opts.format.?);

    try t.expect((try parse(&.{ "migrate", "--help" })).help);
    for ([_][]const []const u8{
        &.{"migrate"},
        &.{ "migrate", "plan" },
        &.{ "migrate", "apply" },
        &.{ "migrate", "status", "--out", "plan.json" },
        &.{ "migrate", "plan", "--dir", "m", "--plan", "p.json" },
        &.{ "migrate", "status", "--no-rc" },
        &.{ "console", "--dir", "migrations" },
    }) |args| try t.expectError(error.InvalidInvocation, parse(args));
}
