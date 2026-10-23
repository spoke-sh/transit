//! Thin CLI over the shared language-neutral management client.
const std = @import("std");
const wire = @import("transit_query").wire;
const A = wire.Application;
const Files = @import("cli_support").Files;
const Config = @import("cli_support").Config;
const Diagnostic = @import("cli_support").Diagnostic;
pub fn run(init: std.process.Init, args: []const []const u8, report: *Diagnostic) !void {
    const options = try @import("AppOptions.zig").parse(args, report);
    const mode = options.mode;
    const flags = options.flags;
    const allocator = init.arena.allocator();
    const mutation = mode == .install or mode == .replace;
    report.atFile(flags.config.?);
    const absolute = std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.config.?, allocator) catch |err| {
        report.configurationFailure(err);
        return error.InvalidConfigurationPath;
    };
    var config = try @import("cli_support").Settings.readTyped(A.Management, init, absolute, report);
    if (config.version != 1) return report.invalidField("version", "must be 1", "Use the management configuration emitted by the server.");
    config.seed_file = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, config.seed_file });
    config.recovery_directory = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, config.recovery_directory });
    var client = try A.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    report.field = "seed_file";
    var key = wire.readKey(init.gpa, init.io, config.seed_file) catch |err| {
        report.setFailure(err, "cannot load the management signing credential", "Check seed_file relative to the configuration file and its permissions; do not print or paste the seed.");
        return error.InvalidCredentialFile;
    };
    report.field = null;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const operation = flags.operation orelse "read";
    try A.name(operation);
    const recovery = try std.fs.path.join(allocator, &.{ config.recovery_directory, try std.fmt.allocPrint(allocator, "{s}.json", .{operation}) });
    var lock: ?std.Io.File = null;
    defer if (lock) |file| file.close(init.io);
    if (mutation or mode == .retry) {
        report.atFile(config.recovery_directory);
        lock = try std.Io.Dir.cwd().createFile(init.io, try std.fs.path.join(allocator, &.{ config.recovery_directory, "client.lock" }), .{ .truncate = false, .permissions = .fromMode(0o600) });
        if (!try lock.?.tryLock(init.io, .exclusive)) return error.ManagementClientInUse;
    }
    var signed: A.Signed = undefined;
    if (mode == .retry) {
        report.atFile(recovery);
        signed = try Files.read(A.Signed, init.io, allocator, recovery);
        if (signed.request.realm != config.realm or signed.request.principal != config.principal or !std.mem.eql(u8, &signed.request.installation, &config.installation) or !std.mem.eql(u8, signed.request.operation, operation)) return error.RecoveryIdentityMismatch;
        try A.verify(allocator, signed);
    } else {
        var request: A.Request = .{ .installation = config.installation, .realm = config.realm, .principal = config.principal, .operation = operation, .command = undefined };
        switch (mode) {
            .install => {
                report.atFile(flags.file.?);
                const path = try std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.file.?, allocator);
                var declaration = try @import("cli_support").Settings.readTyped(A.Declaration, init, path, report);
                const roles = try allocator.dupe(A.Role, declaration.roles);
                for (roles) |*role| try resolveArtifact(init, &role.artifact, std.fs.path.dirname(path).?);
                declaration.roles = roles;
                try declaration.validate();
                request.command = .{ .install = declaration };
            },
            .replace => {
                report.atFile(flags.file.?);
                const path = try std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.file.?, allocator);
                var replacement = try @import("cli_support").Settings.readTyped(A.Replacement, init, path, report);
                try resolveArtifact(init, &replacement.artifact, std.fs.path.dirname(path).?);
                request.command = .{ .replace = replacement };
            },
            .status => request.command = .{ .status = .{ .application = flags.application.?, .after = options.after } },
            .connect => request.command = .{ .connect = .{ .application = flags.application.?, .caller = flags.caller.? } },
            .retry => unreachable,
        }
        signed = try A.sign(allocator, request, key);
        if (mutation) {
            report.atFile(recovery);
            const previous = Files.read(A.Signed, init.io, allocator, recovery) catch |err| value: {
                if (err != error.FileNotFound) return err;
                break :value null;
            };
            if (previous) |old| {
                if (!std.mem.eql(u8, &try A.digest(allocator, old.request), &try A.digest(allocator, request))) return error.ConflictingApplicationOperation;
                signed = old;
            } else try Files.json(init.io, allocator, recovery, signed);
        }
    }
    report.atFile(absolute);
    if (signed.request.command == .connect) {
        const response = client.call(A.Connection, signed) catch |err| {
            diagnostic(&client);
            return err;
        };
        defer response.deinit();
        if (flags.output) |destination| {
            report.atFile(destination);
            return @import("cli_support").Settings.write(init, destination, response.value);
        }
        try output(init, response.value);
    } else {
        const response = client.call(A.Status, signed) catch |err| {
            diagnostic(&client);
            return err;
        };
        defer response.deinit();
        try output(init, response.value);
    }
}
fn resolveArtifact(init: std.process.Init, artifact: *A.Artifact, base: []const u8) !void {
    artifact.path = try std.Io.Dir.cwd().realPathFileAlloc(init.io, try std.fs.path.resolve(init.arena.allocator(), &.{ base, artifact.path }), init.arena.allocator());
    const digest = try Config.digest(init, artifact.path);
    if (!std.mem.allEqual(u8, &artifact.sha256, 0) and !std.mem.eql(u8, &artifact.sha256, &digest)) return error.ApplicationArtifactChanged;
    artifact.sha256 = digest;
}
fn diagnostic(client: *A.Client) void {
    if (client.last_error_length > 0) std.debug.print("application: {s}\n", .{client.last_error[0..client.last_error_length]});
}
fn output(init: std.process.Init, value: anytype) !void {
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const text = try wire.protocol.Json.valueAlloc(init.arena.allocator(), value);
    try @import("cli_support").Output.write(init, &writer.interface, try std.fmt.allocPrint(init.arena.allocator(), "{s}\n", .{text}));
}
