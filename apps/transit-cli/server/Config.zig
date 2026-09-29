const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
const Diagnostic = @import("../Diagnostic.zig");
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
pub fn load(init: std.process.Init, path: []const u8, diagnostic: *Diagnostic) !Self {
    const allocator = init.arena.allocator();
    diagnostic.atFile(path);
    const absolute = std.Io.Dir.cwd().realPathFileAlloc(init.io, path, allocator) catch |err| {
        diagnostic.setFailure(err, "cannot locate the server configuration file", "Pass --config with an existing readable server JSON file; see transit server --help.");
        return error.InvalidConfigurationPath;
    };
    var self = try diagnostic.readJson(Self, init, absolute, 65536);
    if (self.version < 1 or self.version > 3) return diagnostic.invalidField("version", "unsupported server configuration version", "Use configuration version 1, 2 or 3; Board requires version 3.");
    if (@import("builtin").os.tag != .linux) return diagnostic.invalidField("platform", "local server requires Linux", "Run this local server profile on Linux x86_64.");
    if ((self.version == 1 and self.applications != null) or (self.version == 2 and self.applications == null)) return diagnostic.invalidField("applications", "applications settings do not match the configuration version", "Version 1 omits applications; version 2 requires applications; version 3 accepts it optionally.");
    if (self.realm == 0 or self.realm > @import("transit_query").protocol.max_counter) return diagnostic.invalidField("realm", "realm is outside the supported counter range", "Set realm to an integer from 1 through 9007199254740991.");
    if (self.version < 3 and (self.board != null or self.executables.board != null)) return diagnostic.invalidField("board / executables.board", "Board settings require configuration version 3", "Omit Board fields in older configurations and start with --no-ui. Retained installations require their recorded configuration.");
    if (self.version == 3) {
        if (self.executables.board == null) return diagnostic.invalidFieldCause(error.BoardExecutableRequired, "executables.board", "Board executable is missing", "Set executables.board to the matching transit-board executable, including for --no-ui.");
        var board = self.board orelse Board{};
        if (board.port < 1024) return diagnostic.invalidField("board.port", "Board port is below 1024", "Choose a distinct port from 1024 through 65535.");
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (board.port == @field(self.ports, name)) return diagnostic.invalidField("board.port / ports." ++ name, "two listeners use the same port", "Assign a distinct port to each configured listener.");
        if (self.applications) |apps| if (apps.port == board.port) return diagnostic.invalidField("board.port / applications.port", "two listeners use the same port", "Assign a distinct port to each configured listener.");
        const origin = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{board.port});
        if (board.public_origin) |configured| if (!std.mem.eql(u8, configured, origin)) return diagnostic.invalidFieldCause(error.InvalidBoardOrigin, "board.public_origin", "Board origin does not match its loopback listener", "Omit public_origin to derive it from board.port, or use exactly http://127.0.0.1:PORT.");
        board.public_origin = origin;
        self.board = board;
    }
    if (self.applications) |apps| {
        if (apps.port < 1024) return diagnostic.invalidField("applications.port", "application management port is below 1024", "Choose a distinct port from 1024 through 65535.");
        if (apps.max_applications == 0 or apps.max_applications > 64) return diagnostic.invalidField("applications.max_applications", "application quota is outside the supported range", "Use an integer from 1 through 64.");
        if (apps.max_roles == 0 or apps.max_roles > 256) return diagnostic.invalidField("applications.max_roles", "role quota is outside the supported range", "Use an integer from 1 through 256.");
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (apps.port == @field(self.ports, name)) return diagnostic.invalidField("applications.port / ports." ++ name, "two listeners use the same port", "Assign a distinct port to each configured listener.");
    }
    if (self.admission_ceiling < 128 or self.admission_ceiling > 65536) return diagnostic.invalidField("admission_ceiling", "admission ceiling is outside the supported range", "Use an integer from 128 through 65536.");
    if (self.control_reserve > 65536) return diagnostic.invalidField("control_reserve", "control reserve exceeds the supported range", "Use an integer from 0 through 65536.");
    @import("Hosts.zig").validate(self.gateway_allowed_hosts) catch |err| {
        diagnostic.field = "gateway_allowed_hosts";
        diagnostic.setFailure(err, "invalid gateway host allowlist", "Use at most eight exact host:port authorities, at most 200 bytes each; omit schemes, paths and wildcards.");
        return error.InvalidConfiguration;
    };
    const fields = @typeInfo(Ports).@"struct".field_names;
    inline for (fields, 0..) |name, i| {
        if (@field(self.ports, name) < 1024) return diagnostic.invalidField("ports." ++ name, "listener port is below 1024", "Choose a distinct port from 1024 through 65535.");
        inline for (fields[0..i]) |previous| if (@field(self.ports, name) == @field(self.ports, previous)) return diagnostic.invalidField("ports." ++ name ++ " / ports." ++ previous, "two listeners use the same port", "Assign a distinct port to each configured listener.");
    }
    const base = std.fs.path.dirname(absolute).?;
    self.installation = try std.fs.path.resolve(allocator, &.{ base, self.installation });
    if (std.mem.indexOfAny(u8, self.installation, "\x00\n\r\"\\") != null or std.mem.eql(u8, self.installation, "/")) return diagnostic.invalidField("installation", "invalid installation directory", "Choose a non-root directory without NUL, newline, quote or backslash characters.");
    inline for (.{ "minio", "ursula", "node", "query_host" }) |name| {
        diagnostic.field = "executables." ++ name;
        @field(self.executables, name) = resolveExecutable(init, base, @field(self.executables, name)) catch |err| {
            diagnostic.setFailure(err, "cannot locate a configured executable", "Correct this executable path relative to the configuration file; use the matching local bundle.");
            return error.InvalidConfiguration;
        };
    }
    if (self.executables.board) |board_path| {
        diagnostic.field = "executables.board";
        self.executables.board = resolveExecutable(init, base, board_path) catch |err| {
            diagnostic.setFailure(err, "cannot locate the Board executable", "Set executables.board to the matching transit-board file, relative to the configuration file.");
            return error.InvalidConfiguration;
        };
    }
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

fn resolveExecutable(init: std.process.Init, base: []const u8, path: []const u8) ![]const u8 {
    if (path.len == 0) return error.InvalidConfiguration;
    return std.Io.Dir.cwd().realPathFileAlloc(init.io, try std.fs.path.resolve(init.arena.allocator(), &.{ base, path }), init.arena.allocator());
}

fn listen(io: std.Io, port: u16, field: []const u8, diagnostic: *Diagnostic) !std.Io.net.Server {
    return (try std.Io.net.IpAddress.parseIp4("127.0.0.1", port)).listen(io, .{ .reuse_address = true }) catch |err| {
        diagnostic.field = field;
        diagnostic.port = port;
        return diagnostic.fail(err, "cannot bind the configured listener", "Check which process owns this address and port. Stop the conflicting service if appropriate; retained installations require their recorded ports.");
    };
}
