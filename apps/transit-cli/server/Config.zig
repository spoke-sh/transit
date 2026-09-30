const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
const Diagnostic = @import("../Diagnostic.zig");
const Settings = @import("../Settings.zig");
version: u8,
installation: []const u8,
realm: u64,
admission_ceiling: u64 = 65536,
control_reserve: u64 = 4096,
ports: Ports,
executables: Executables,
applications: ?Applications = null,
gateway_allowed_hosts: []const []const u8 = &.{},
board: ?Board = null,
pub const Board = struct { port: u16 = 19107, public_origin: ?[]const u8 = null };
pub const Applications = struct { port: u16, max_applications: u16 = 8, max_roles: u16 = 32 };
pub const Ports = struct { cold: u16, cold_console: u16, store: u16, node: u16, gateway: u16 };
pub const Executables = struct { minio: []const u8, ursula: []const u8, node: []const u8, query_host: []const u8, board: ?[]const u8 = null };
pub const Identity = struct { config: [32]u8, cli: [32]u8, minio: [32]u8, ursula: [32]u8, node: [32]u8, query_host: [32]u8, board: ?[32]u8 = null };
pub fn load(init: std.process.Init, requested: ?[]const u8, diagnostic: *Diagnostic) !Self {
    return loadWithExecutables(init, requested, diagnostic, true);
}
/// Console defaults need topology only, without installed server executables.
pub fn forConsole(init: std.process.Init, diagnostic: *Diagnostic) !Self {
    return loadWithExecutables(init, null, diagnostic, false);
}
fn loadWithExecutables(init: std.process.Init, requested: ?[]const u8, diagnostic: *Diagnostic, resolve_executables: bool) !Self {
    const allocator = init.arena.allocator();
    const selected = requested orelse (Settings.discover(init, "transit.yaml", "transit.yaml", "/etc/transit/transit.yaml", diagnostic) catch |err| {
        diagnostic.configurationFailure(err);
        return error.InvalidConfiguration;
    });
    const cwd = try std.Io.Dir.cwd().realPathFileAlloc(init.io, ".", allocator);
    const absolute = if (selected) |name| std.Io.Dir.cwd().realPathFileAlloc(init.io, name, allocator) catch |err| {
        diagnostic.atFile(name);
        diagnostic.configurationFailure(err);
        return error.InvalidConfigurationPath;
    } else null;
    const base = if (absolute) |name| std.fs.path.dirname(name).? else cwd;
    var overlay = if (absolute) |name| try Settings.read(init, name, diagnostic) else Settings.object(allocator);
    if (overlay != .object) return diagnostic.invalidField("configuration", "must be an object", null);
    try Settings.shape(Self, allocator, overlay, "", diagnostic);
    try Settings.environment(Self, init, &overlay, diagnostic);
    errdefer Settings.environmentOrigin(init, diagnostic);
    try Settings.shape(Self, allocator, overlay, "", diagnostic);
    const version = if (overlay.object.get("version")) |v| (std.json.parseFromValueLeaky(u8, allocator, v, .{}) catch return diagnostic.invalidField("version", "must be 1", null)) else 1;
    if (version != 1) return diagnostic.invalidField("version", "must be 1", null);
    var defaults = (try std.json.parseFromSlice(std.json.Value, allocator,
        \\{"version":1,"realm":1,"ports":{"cold":19101,"cold_console":19102,"store":19103,"node":19104,"gateway":19105},"executables":{}}
    , .{})).value;
    try defaults.object.put(allocator, "installation", .{ .string = try std.fs.path.join(allocator, &.{ cwd, ".transit" }) });
    try defaults.object.put(allocator, "applications", (try std.json.parseFromSlice(std.json.Value, allocator, "{\"port\":19106}", .{})).value);
    try Settings.merge(allocator, &defaults, overlay);
    const exe_value = defaults.object.getPtr("executables").?;
    if (exe_value.* != .object) return diagnostic.invalidField("executables", "must be an object", null);
    inline for (.{ .{ "minio", "minio" }, .{ "ursula", "ursula" }, .{ "node", "transit-node" }, .{ "query_host", "transit-query-host" }, .{ "board", "transit-board" } }) |entry| {
        if (!exe_value.object.contains(entry[0])) {
            diagnostic.field = "executables." ++ entry[0];
            const found = if (!resolve_executables) entry[1] else defaultExecutable(init, entry[1]) catch |err| {
                return diagnostic.invalidFieldCause(err, "executables." ++ entry[0], "cannot find " ++ entry[1] ++ " beside transit or on PATH", null);
            };
            try exe_value.object.put(allocator, entry[0], .{ .string = found });
        }
    }
    if (absolute) |name| diagnostic.atFile(name) else diagnostic.atFile("built-in server defaults");
    var self = std.json.parseFromValueLeaky(Self, allocator, defaults, .{}) catch |err| {
        return diagnostic.invalidFieldCause(err, "configuration", "contains an unknown field or invalid value", null);
    };
    if (self.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    if (@import("builtin").os.tag != .linux) return diagnostic.invalidField("platform", "must be Linux x86_64", null);
    if (self.realm == 0 or self.realm > @import("transit_query").protocol.max_counter) return diagnostic.invalidField("realm", "must be an integer from 1 through 9007199254740991", null);
    {
        if (self.executables.board == null) return diagnostic.invalidFieldCause(error.BoardExecutableRequired, "executables.board", "is required", "Select the matching transit-board executable, including for --no-ui.");
        var board = self.board orelse Board{};
        if (board.port < 1024) return diagnostic.invalidField("board.port", "must be a port from 1024 through 65535", null);
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (board.port == @field(self.ports, name)) return diagnostic.invalidField("board.port and ports." ++ name, "must be different", null);
        if (self.applications) |apps| if (apps.port == board.port) return diagnostic.invalidField("board.port and applications.port", "must be different", null);
        const origin = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{board.port});
        if (board.public_origin) |configured| if (!std.mem.eql(u8, configured, origin)) return diagnostic.invalidFieldCause(error.InvalidBoardOrigin, "board.public_origin", "must match the Board loopback listener", "Omit public_origin to derive it from board.port, or use exactly http://127.0.0.1:PORT.");
        board.public_origin = origin;
        self.board = board;
    }
    if (self.applications) |apps| {
        if (apps.port < 1024) return diagnostic.invalidField("applications.port", "must be a port from 1024 through 65535", null);
        if (apps.max_applications == 0 or apps.max_applications > 64) return diagnostic.invalidField("applications.max_applications", "must be an integer from 1 through 64", null);
        if (apps.max_roles == 0 or apps.max_roles > 256) return diagnostic.invalidField("applications.max_roles", "must be an integer from 1 through 256", null);
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (apps.port == @field(self.ports, name)) return diagnostic.invalidField("applications.port and ports." ++ name, "must be different", null);
    }
    if (self.admission_ceiling < 128 or self.admission_ceiling > 65536) return diagnostic.invalidField("admission_ceiling", "must be an integer from 128 through 65536", null);
    if (self.control_reserve > 65536) return diagnostic.invalidField("control_reserve", "must be an integer from 0 through 65536", null);
    @import("Hosts.zig").validate(self.gateway_allowed_hosts) catch |err| {
        return diagnostic.invalidFieldCause(err, "gateway_allowed_hosts", "must contain at most eight exact host:port authorities", "Each authority is limited to 200 bytes; omit schemes, paths and wildcards.");
    };
    const fields = @typeInfo(Ports).@"struct".field_names;
    inline for (fields, 0..) |name, i| {
        if (@field(self.ports, name) < 1024) return diagnostic.invalidField("ports." ++ name, "must be a port from 1024 through 65535", null);
        inline for (fields[0..i]) |previous| if (@field(self.ports, name) == @field(self.ports, previous)) return diagnostic.invalidField("ports." ++ name ++ " and ports." ++ previous, "must be different", null);
    }
    self.installation = try std.fs.path.resolve(allocator, &.{ base, self.installation });
    if (std.mem.indexOfAny(u8, self.installation, "\x00\n\r\"\\") != null or std.mem.eql(u8, self.installation, "/")) return diagnostic.invalidField("installation", "must be a non-root directory without NUL, newline, quote or backslash characters", null);
    if (resolve_executables) inline for (.{ "minio", "ursula", "node", "query_host" }) |name| {
        diagnostic.field = "executables." ++ name;
        @field(self.executables, name) = resolveExecutable(init, base, @field(self.executables, name)) catch |err| {
            diagnostic.setFailure(err, "cannot locate a configured executable", "Correct this executable path relative to the configuration file; use the matching local bundle.");
            return error.InvalidConfiguration;
        };
    };
    if (resolve_executables) if (self.executables.board) |board_path| {
        diagnostic.field = "executables.board";
        self.executables.board = resolveExecutable(init, base, board_path) catch |err| {
            diagnostic.setFailure(err, "cannot locate the Board executable", "Set executables.board to the matching transit-board file, relative to the configuration file.");
            return error.InvalidConfiguration;
        };
    };
    diagnostic.field = null;
    return self;
}
pub fn identities(self: Self, init: std.process.Init, executable: []const u8, diagnostic: *Diagnostic) !Identity {
    var result: Identity = undefined;
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, self, .{});
    defer init.gpa.free(bytes);
    std.crypto.hash.sha2.Sha256.hash(bytes, &result.config, .{});
    diagnostic.field = "transit executable";
    result.cli = try checkedDigest(init, executable, diagnostic);
    inline for (@typeInfo(Executables).@"struct".field_names) |name| {
        diagnostic.field = "executables." ++ name;
        if (comptime std.mem.eql(u8, name, "board")) {
            result.board = if (self.executables.board) |path| try checkedDigest(init, path, diagnostic) else null;
        } else @field(result, name) = try checkedDigest(init, @field(self.executables, name), diagnostic);
    }
    diagnostic.field = null;
    return result;
}
fn checkedDigest(init: std.process.Init, file: []const u8, diagnostic: *Diagnostic) ![32]u8 {
    return digest(init, file) catch |err| {
        diagnostic.setFailure(err, "cannot validate the configured executable", "Use a readable, nonempty regular executable file at most 256 MiB, without setuid/setgid bits, from the matching build.");
        return error.InvalidConfiguration;
    };
}
pub fn digest(init: std.process.Init, path: []const u8) ![32]u8 {
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    if (stat.kind != .file or stat.size == 0 or stat.size > 256 * 1024 * 1024 or stat.permissions.toMode() & 0o6000 != 0 or stat.permissions.toMode() & 0o111 == 0) return error.InvalidExecutable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var storage: [65536]u8 = undefined;
    var reader = file.reader(init.io, &storage);
    while (true) {
        const bytes = reader.interface.peekGreedy(1) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        hash.update(bytes);
        reader.interface.toss(bytes.len);
    }
    return hash.finalResult();
}
pub fn preflight(self: Self, io: std.Io, ui: bool, diagnostic: *Diagnostic) !void {
    var listeners: [7]?std.Io.net.Server = @splat(null);
    defer for (&listeners) |*listener| if (listener.*) |*server| server.deinit(io);
    inline for (@typeInfo(Ports).@"struct".field_names, 0..) |name, i| listeners[i] = try listen(io, @field(self.ports, name), "ports." ++ name, diagnostic);
    if (ui) if (self.board) |board| {
        listeners[6] = try listen(io, board.port, "board.port", diagnostic);
    };
    if (self.applications) |apps| listeners[5] = try listen(io, apps.port, "applications.port", diagnostic);
}

/// Resolve defaults as if the executable directory were prepended to PATH.
/// Freeze absolute paths before dependency validation and child activation.
fn defaultExecutable(init: std.process.Init, name: []const u8) ![]const u8 {
    const allocator = init.arena.allocator();
    const binary = try std.process.executablePathAlloc(init.io, allocator);
    if (try candidate(init, std.fs.path.dirname(binary).?, name)) |found| return found;
    const search = init.environ_map.get("PATH") orelse return error.ExecutableNotFound;
    if (search.len > 65536) return error.ExecutableSearchTooLarge;
    var paths = std.mem.splitScalar(u8, search, ':');
    var count: usize = 0;
    while (paths.next()) |directory| {
        count += 1;
        if (count > 256) return error.ExecutableSearchTooLarge;
        if (try candidate(init, if (directory.len == 0) "." else directory, name)) |found| return found;
    }
    return error.ExecutableNotFound;
}
fn candidate(init: std.process.Init, directory: []const u8, name: []const u8) !?[]const u8 {
    const allocator = init.arena.allocator();
    const proposed = try std.fs.path.resolve(allocator, &.{ directory, name });
    const file = std.Io.Dir.cwd().openFile(init.io, proposed, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir, error.AccessDenied => return null,
        else => return err,
    };
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    if (stat.kind != .file or stat.permissions.toMode() & 0o111 == 0) return null;
    return try std.Io.Dir.cwd().realPathFileAlloc(init.io, proposed, allocator);
}
fn resolveExecutable(init: std.process.Init, base: []const u8, path: []const u8) ![]const u8 {
    if (path.len == 0) return error.InvalidConfiguration;
    return std.Io.Dir.cwd().realPathFileAlloc(init.io, try std.fs.path.resolve(init.arena.allocator(), &.{ base, path }), init.arena.allocator());
}

fn listen(io: std.Io, port: u16, field: []const u8, diagnostic: *Diagnostic) !std.Io.net.Server {
    return (try std.Io.net.IpAddress.parseIp4("127.0.0.1", port)).listen(io, .{ .reuse_address = true }) catch |err| {
        diagnostic.field = field;
        diagnostic.port = port;
        return diagnostic.fail(err, "cannot bind the configured listener", "Check for another running server. Retained installations require their recorded ports.");
    };
}
