//! Thin CLI over the shared language-neutral management client.
const std = @import("std");
const wire = @import("transit_query").wire;
const A = wire.Application;
const Files = @import("server/Files.zig");
const Config = @import("server/Config.zig");
const help =
    \\transit app install --config MANAGEMENT --file DECLARATION --operation ID
    \\transit app replace --config MANAGEMENT --file REPLACEMENT --operation ID
    \\transit app retry --config MANAGEMENT --operation ID
    \\transit app status --config MANAGEMENT --application NAME [--after INDEX]
    \\transit app connect --config MANAGEMENT --application NAME --caller NAME [--output FILE]
    \\Install/replace freeze exact signed requests; a returned status is not completion.
    \\Artifact paths resolve relative to --file; omitted hashes are computed locally.
    \\
;
pub fn run(init: std.process.Init, args: []const []const u8) !void {
    if (args.len == 0 or (args.len == 1 and std.mem.eql(u8, args[0], "--help"))) return std.Io.File.stdout().writeStreamingAll(init.io, help);
    const Mode = enum { install, replace, retry, status, connect };
    const mode = std.meta.stringToEnum(Mode, args[0]) orelse return error.InvalidInvocation;
    const allocator = init.arena.allocator();
    const Flags = struct { config: ?[]const u8 = null, file: ?[]const u8 = null, operation: ?[]const u8 = null, application: ?[]const u8 = null, caller: ?[]const u8 = null, output: ?[]const u8 = null, after: ?[]const u8 = null };
    var flags: Flags = .{};
    var i: usize = 1;
    while (i < args.len) : (i += 2) {
        if (i + 1 >= args.len or !std.mem.startsWith(u8, args[i], "--") or args[i + 1].len == 0 or std.mem.startsWith(u8, args[i + 1], "--")) return error.InvalidInvocation;
        var found = false;
        inline for (@typeInfo(Flags).@"struct".field_names) |field| if (std.mem.eql(u8, args[i][2..], field)) {
            if (@field(flags, field) != null) return error.InvalidInvocation;
            @field(flags, field) = args[i + 1];
            found = true;
        };
        if (!found) return error.InvalidInvocation;
    }
    const mutation = mode == .install or mode == .replace;
    if ((mutation and (flags.file == null or flags.operation == null)) or (mode == .retry and flags.operation == null) or
        ((mode == .status or mode == .connect) and flags.application == null) or (mode == .connect and flags.caller == null) or
        (!mutation and flags.file != null) or (mode != .connect and (flags.output != null or flags.caller != null)) or
        (mode != .status and flags.after != null) or ((mutation or mode == .retry) and flags.application != null)) return error.InvalidInvocation;
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.config orelse return error.InvalidInvocation, allocator);
    var config = try Files.read(A.Management, init.io, allocator, absolute);
    if (config.version != 1) return error.InvalidConfiguration;
    config.seed_file = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, config.seed_file });
    config.recovery_directory = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, config.recovery_directory });
    var client = try A.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    var key = try wire.readKey(init.gpa, init.io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    const operation = flags.operation orelse "read";
    try A.name(operation);
    const recovery = try std.fs.path.join(allocator, &.{ config.recovery_directory, try std.fmt.allocPrint(allocator, "{s}.json", .{operation}) });
    var lock: ?std.Io.File = null;
    defer if (lock) |file| file.close(init.io);
    if (mutation or mode == .retry) {
        lock = try std.Io.Dir.cwd().createFile(init.io, try std.fs.path.join(allocator, &.{ config.recovery_directory, "client.lock" }), .{ .truncate = false, .permissions = .fromMode(0o600) });
        if (!try lock.?.tryLock(init.io, .exclusive)) return error.ManagementClientInUse;
    }
    var signed: A.Signed = undefined;
    if (mode == .retry) {
        signed = try Files.read(A.Signed, init.io, allocator, recovery);
        if (signed.request.realm != config.realm or signed.request.principal != config.principal or !std.mem.eql(u8, &signed.request.installation, &config.installation) or !std.mem.eql(u8, signed.request.operation, operation)) return error.RecoveryIdentityMismatch;
        try A.verify(allocator, signed);
    } else {
        var request: A.Request = .{ .installation = config.installation, .realm = config.realm, .principal = config.principal, .operation = operation, .command = undefined };
        switch (mode) {
            .install => {
                const path = try std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.file.?, allocator);
                var declaration = try Files.read(A.Declaration, init.io, allocator, path);
                const roles = try allocator.dupe(A.Role, declaration.roles);
                for (roles) |*role| try resolveArtifact(init, &role.artifact, std.fs.path.dirname(path).?);
                declaration.roles = roles;
                try declaration.validate();
                request.command = .{ .install = declaration };
            },
            .replace => {
                const path = try std.Io.Dir.cwd().realPathFileAlloc(init.io, flags.file.?, allocator);
                var replacement = try Files.read(A.Replacement, init.io, allocator, path);
                try resolveArtifact(init, &replacement.artifact, std.fs.path.dirname(path).?);
                request.command = .{ .replace = replacement };
            },
            .status => request.command = .{ .status = .{ .application = flags.application.?, .after = if (flags.after) |after| try std.fmt.parseInt(u32, after, 10) else 0 } },
            .connect => request.command = .{ .connect = .{ .application = flags.application.?, .caller = flags.caller.? } },
            .retry => unreachable,
        }
        signed = try A.sign(allocator, request, key);
        if (mutation) {
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
    if (signed.request.command == .connect) {
        const response = client.call(A.Connection, signed) catch |err| {
            diagnostic(&client);
            return err;
        };
        defer response.deinit();
        if (flags.output) |destination| return Files.json(init.io, allocator, destination, response.value);
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
    try @import("Output.zig").write(init, &writer.interface, try std.fmt.allocPrint(init.arena.allocator(), "{s}\n", .{text}));
}
