const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
const Diagnostic = @import("../Diagnostic.zig");
const Settings = @import("../Settings.zig");
pub const settings = @import("SettingsSchema.zig").registry;
version: u8,
installation: []const u8,
startup: Startup = .{},
realm: u64,
admission_ceiling: u64 = 65536,
control_reserve: u64 = 4096,
storage: @import("transit_query").protocol.Storage.Settings = .{},
ports: Ports,
executables: Executables,
applications: ?Applications = null,
gateway_allowed_hosts: []const []const u8 = &.{},
board: ?Board = null,
query: Query = .{},
sql: @import("SqlSettings.zig") = .{},
pub const Query = struct { statement_timeout: u64 = 0, statement_timeout_ceiling: u64 = 0 };
pub const Startup = struct { require_existing: bool = false };
pub const Board = struct { port: u16 = 19107, public_origin: ?[]const u8 = null };
pub const Applications = struct { port: u16, max_applications: u16 = 8, max_roles: u16 = 32 };
pub const Ports = struct { cold: u16, cold_console: u16, store: u16, node: u16, gateway: u16 };
pub const Executables = struct { sql_gateway: []const u8, minio: []const u8, ursula: []const u8, node: []const u8, query_host: []const u8, board: ?[]const u8 = null };
pub const Identity = struct { sql_gateway: [32]u8, config: [32]u8, cli: [32]u8, minio: [32]u8, ursula: [32]u8, node: [32]u8, query_host: [32]u8, board: ?[32]u8 = null };
pub const Inputs = struct {
    path: []const u8,
    optional: bool,
    defaults: std.json.Value,
    environment: std.json.Value,
    environment_names: []const []const u8,
};
pub const Loaded = struct { config: Self, inputs: Inputs, file: std.json.Value, locations: []const @import("transit_query").settings.Input.Location };
pub fn load(init: std.process.Init, requested: ?[]const u8, diagnostic: *Diagnostic) !Self {
    return (try capture(init, requested, diagnostic, true)).config;
}
/// Console defaults need topology only, without installed server executables.
pub fn forConsole(init: std.process.Init, diagnostic: *Diagnostic) !Self {
    return (try capture(init, null, diagnostic, false)).config;
}
pub fn capture(init: std.process.Init, requested: ?[]const u8, diagnostic: *Diagnostic, resolve_executables: bool) !Loaded {
    const allocator = init.arena.allocator();
    const selected = Settings.discoverServer(init, requested, diagnostic) catch |err| {
        diagnostic.configurationFailure(err);
        return error.InvalidConfiguration;
    };
    const cwd = try std.Io.Dir.cwd().realPathFileAlloc(init.io, ".", allocator);
    // Pin the filename, not a symlink target or an open inode. Atomic replacement
    // is observed by reload; discovery and process environment are never repeated.
    const absolute = try std.fs.path.resolve(allocator, &.{ cwd, selected orelse "transit.yaml" });
    var defaults = try settings.defaults(allocator);
    try defaults.object.put(allocator, "executables", Settings.object(allocator));
    try defaults.object.put(allocator, "installation", .{ .string = try std.fs.path.join(allocator, &.{ cwd, ".transit" }) });
    var environment = Settings.object(allocator);
    try settings.environment(init, &environment, diagnostic);
    var names: std.array_list.Managed([]const u8) = .init(allocator);
    var iterator = init.environ_map.iterator();
    while (iterator.next()) |entry| {
        const name = entry.key_ptr.*;
        if (std.mem.startsWith(u8, name, "TRANSIT_") and !Settings.reservedEnvironment(name)) try names.append(try allocator.dupe(u8, name));
    }
    const inputs: Inputs = .{ .path = absolute, .optional = selected == null, .defaults = defaults, .environment = environment, .environment_names = names.items };
    var loaded = try resolve(init, inputs, diagnostic, resolve_executables);
    // Resolve fallback executable discovery once, even when a file currently
    // overrides it. A later deletion must not search a changed child PATH.
    const fallbacks = loaded.inputs.defaults.object.getPtr("executables").?;
    inline for (.{ .{ "minio", "minio" }, .{ "ursula", "ursula" }, .{ "node", "transit-node" }, .{ "query_host", "transit-query-host" }, .{ "board", "transit-board" }, .{ "sql_gateway", "transit-sql-gateway" } }) |entry| {
        const found = if (resolve_executables) defaultExecutable(init, entry[1]) catch "" else entry[1];
        try fallbacks.object.put(allocator, entry[0], .{ .string = found });
    }
    return loaded;
}
pub fn resolve(init: std.process.Init, inputs: Inputs, diagnostic: *Diagnostic, resolve_executables: bool) !Loaded {
    const allocator = init.arena.allocator();
    const base = std.fs.path.dirname(inputs.path).?;
    var locations: []const @import("transit_query").settings.Input.Location = &.{};
    var present = true;
    var file = file: {
        if (inputs.optional) {
            const handle = std.Io.Dir.cwd().openFile(init.io, inputs.path, .{}) catch |err| {
                if (err == error.FileNotFound) {
                    present = false;
                    break :file Settings.object(allocator);
                }
                diagnostic.atFile(inputs.path);
                diagnostic.configurationFailure(err);
                return error.InvalidConfigurationPath;
            };
            handle.close(init.io);
        }
        const document = try Settings.readDetailed(init, inputs.path, diagnostic);
        locations = document.locations;
        break :file document.value;
    };
    if (file != .object) return diagnostic.invalidField("configuration", "must be an object", null);
    errdefer if (diagnostic.line == null) {
        if (diagnostic.field) |name| {
            for (locations) |location| if (std.mem.eql(u8, name, location.name)) {
                diagnostic.line = location.line;
                diagnostic.column = location.column;
                break;
            };
        }
    };
    var field: ?[]const u8 = null;
    settings.normalizeInput(allocator, &file, &field) catch |err| {
        if (err == error.InvalidSettingType) {
            const descriptor = settings.lookup(field orelse "") catch null;
            if (descriptor == null or descriptor.?.kind == .object) return diagnostic.invalidField(field orelse "configuration", "must be an object", null);
        }
        return diagnostic.invalidFieldCause(err, field orelse "configuration", "contains an unknown field or invalid value", null);
    };
    var overlay = try clone(allocator, file);
    try Settings.merge(allocator, &overlay, inputs.environment);
    errdefer environmentDiagnostic(init, inputs, diagnostic);
    try Settings.shape(Self, allocator, overlay, "", diagnostic);
    const version = if (overlay.object.get("version")) |v| (std.json.parseFromValueLeaky(u8, allocator, v, .{}) catch return diagnostic.invalidField("version", "must be 1", null)) else 1;
    if (version != 1) return diagnostic.invalidField("version", "must be 1", null);
    var defaults = try clone(allocator, inputs.defaults);
    try Settings.merge(allocator, &defaults, overlay);
    settings.normalize(allocator, &defaults, &field) catch |err| {
        const descriptor = settings.lookup(field orelse "") catch return diagnostic.invalidFieldCause(err, "configuration", "contains an unknown field or invalid value", null);
        if (err == error.SettingOutOfRange) {
            const noun = if (std.mem.startsWith(u8, descriptor.name, "ports.") or std.mem.endsWith(u8, descriptor.name, ".port")) "a port" else "an integer";
            return diagnostic.invalidField(descriptor.name, try std.fmt.allocPrint(allocator, "must be {s} from {d} through {d}", .{ noun, descriptor.minimum, descriptor.maximum }), null);
        }
        return diagnostic.invalidFieldCause(err, descriptor.name, "contains an invalid value", null);
    };
    const exe_value = defaults.object.getPtr("executables").?;
    if (exe_value.* != .object) return diagnostic.invalidField("executables", "must be an object", null);
    inline for (.{ .{ "minio", "minio" }, .{ "ursula", "ursula" }, .{ "node", "transit-node" }, .{ "query_host", "transit-query-host" }, .{ "board", "transit-board" }, .{ "sql_gateway", "transit-sql-gateway" } }) |entry| {
        if (!exe_value.object.contains(entry[0])) {
            diagnostic.field = "executables." ++ entry[0];
            const found = if (!resolve_executables) entry[1] else defaultExecutable(init, entry[1]) catch |err| {
                return diagnostic.invalidFieldCause(err, "executables." ++ entry[0], "cannot find " ++ entry[1] ++ " beside transit or on PATH", null);
            };
            try exe_value.object.put(allocator, entry[0], .{ .string = found });
        }
    }
    diagnostic.atFile(inputs.path);
    var self = std.json.parseFromValueLeaky(Self, allocator, defaults, .{}) catch |err| {
        return diagnostic.invalidFieldCause(err, "configuration", "contains an unknown field or invalid value", null);
    };
    if (self.query.statement_timeout_ceiling != 0 and (self.query.statement_timeout == 0 or self.query.statement_timeout > self.query.statement_timeout_ceiling)) return diagnostic.invalidField("query.statement_timeout", "must not exceed the configured ceiling", null);
    if (self.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    if (@import("builtin").os.tag != .linux) return diagnostic.invalidField("platform", "must be Linux x86_64", null);
    {
        if (self.executables.board == null) return diagnostic.invalidFieldCause(error.BoardExecutableRequired, "executables.board", "is required", "Select the matching transit-board executable, including for --no-ui.");
        var board = self.board orelse Board{};
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (board.port == @field(self.ports, name)) return diagnostic.invalidField("board.port and ports." ++ name, "must be different", null);
        if (self.applications) |apps| if (apps.port == board.port) return diagnostic.invalidField("board.port and applications.port", "must be different", null);
        const origin = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{board.port});
        if (board.public_origin) |configured| if (!std.mem.eql(u8, configured, origin)) return diagnostic.invalidFieldCause(error.InvalidBoardOrigin, "board.public_origin", "must match the Board loopback listener", "Omit public_origin to derive it from board.port, or use exactly http://127.0.0.1:PORT.");
        board.public_origin = origin;
        self.board = board;
    }
    if (self.applications) |apps| {
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (apps.port == @field(self.ports, name)) return diagnostic.invalidField("applications.port and ports." ++ name, "must be different", null);
    }
    @import("Hosts.zig").validate(self.gateway_allowed_hosts) catch |err| {
        return diagnostic.invalidFieldCause(err, "gateway_allowed_hosts", "must contain at most eight exact host:port authorities", "Each authority is limited to 200 bytes; omit schemes, paths and wildcards.");
    };
    const fields = @typeInfo(Ports).@"struct".field_names;
    inline for (fields, 0..) |name, i| {
        inline for (fields[0..i]) |previous| if (@field(self.ports, name) == @field(self.ports, previous)) return diagnostic.invalidField("ports." ++ name ++ " and ports." ++ previous, "must be different", null);
    }
    self.installation = try std.fs.path.resolve(allocator, &.{ base, self.installation });
    if (std.mem.indexOfAny(u8, self.installation, "\x00\n\r\"\\") != null or std.mem.eql(u8, self.installation, "/")) return diagnostic.invalidField("installation", "must be a non-root directory without NUL, newline, quote or backslash characters", null);
    if (resolve_executables) inline for (.{ "minio", "ursula", "node", "query_host", "sql_gateway" }) |name| {
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
    try self.sql.resolve(allocator, base, diagnostic);
    const sql_ports = [_]?u16{ if (self.sql.postgres) |listener| listener.port else null, if (self.sql.mysql) |listener| listener.port else null, if (self.sql.listening()) self.sql.health_port else null, if (self.sql.native.http) |http| http.port else null };
    const sql_fields = [_][]const u8{ "sql.postgres.port", "sql.mysql.port", "sql.health_port", "sql.native.http.port" };
    for (sql_ports, 0..) |maybe, i| if (maybe) |port| {
        for (sql_ports[0..i]) |previous| if (previous == port) return diagnostic.invalidField(sql_fields[i], "requires distinct SQL listener and health ports", null);
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (port == @field(self.ports, name)) return diagnostic.invalidField(sql_fields[i], "must differ from ports." ++ name, null);
        if (self.board) |board| if (port == board.port) return diagnostic.invalidField(sql_fields[i], "must differ from board.port", null);
        if (self.applications) |apps| if (port == apps.port) return diagnostic.invalidField(sql_fields[i], "must differ from applications.port", null);
    };
    diagnostic.field = null;
    var pinned = inputs;
    if (present) pinned.optional = false;
    return .{ .config = self, .inputs = pinned, .file = file, .locations = locations };
}
pub fn identities(self: Self, init: std.process.Init, executable: []const u8, diagnostic: *Diagnostic) !Identity {
    var result: Identity = undefined;
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, .{ self.version, self.installation, self.realm, self.admission_ceiling, self.control_reserve }, .{});
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
    var listeners: [11]?std.Io.net.Server = @splat(null);
    defer for (&listeners) |*listener| if (listener.*) |*server| server.deinit(io);
    inline for (@typeInfo(Ports).@"struct".field_names, 0..) |name, i| listeners[i] = try listen(io, @field(self.ports, name), "ports." ++ name, diagnostic);
    if (ui) if (self.board) |board| {
        listeners[6] = try listen(io, board.port, "board.port", diagnostic);
    };
    if (self.applications) |apps| listeners[5] = try listen(io, apps.port, "applications.port", diagnostic);
    if (self.sql.postgres) |listener| listeners[7] = try listen(io, listener.port, "sql.postgres.port", diagnostic);
    if (self.sql.mysql) |listener| listeners[8] = try listen(io, listener.port, "sql.mysql.port", diagnostic);
    const sql_directory = try std.fs.path.join(std.heap.page_allocator, &.{ self.installation, "sql" });
    defer std.heap.page_allocator.free(sql_directory);
    const retained_sql = if (std.Io.Dir.cwd().access(io, sql_directory, .{})) |_| true else |err| if (err == error.FileNotFound) false else return err;
    if (self.sql.native.http) |http| listeners[10] = try listen(io, http.port, "sql.native.http.port", diagnostic);
    if (self.sql.listening() or retained_sql) listeners[9] = try listen(io, self.sql.health_port, "sql.health_port", diagnostic);
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

pub fn clone(allocator: std.mem.Allocator, input: std.json.Value) !std.json.Value {
    const bytes = try std.json.Stringify.valueAlloc(allocator, input, .{});
    defer allocator.free(bytes);
    return std.json.parseFromSliceLeaky(std.json.Value, allocator, bytes, .{ .allocate = .alloc_always });
}
pub fn value(allocator: std.mem.Allocator, config: Self) !std.json.Value {
    const bytes = try std.json.Stringify.valueAlloc(allocator, config, .{});
    defer allocator.free(bytes);
    return std.json.parseFromSliceLeaky(std.json.Value, allocator, bytes, .{ .allocate = .alloc_always });
}
fn environmentDiagnostic(init: std.process.Init, inputs: Inputs, diagnostic: *Diagnostic) void {
    const field = diagnostic.field orelse return;
    const R = @import("transit_query").settings.Registry;
    if (R.get(inputs.environment, field) != null) {
        const canonical = R.environmentName(init.arena.allocator(), field) catch return;
        const name = R.environmentSource(inputs.environment_names, canonical) orelse return;
        diagnostic.field = std.fmt.allocPrint(init.arena.allocator(), "{s} ({s})", .{ name, field }) catch return;
        diagnostic.file = null;
        diagnostic.line = null;
        diagnostic.column = null;
    }
}

test "pinned optional source can appear once and never falls back after acceptance" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    const directory = try temporary.dir.realPathFileAlloc(t.io, ".", a);
    const source = try std.fs.path.join(a, &.{ directory, "transit.yaml" });
    const init: std.process.Init = .{ .io = t.io, .gpa = t.allocator, .arena = &arena, .minimal = undefined, .environ_map = undefined, .preopens = undefined };
    var defaults = try settings.defaults(a);
    try defaults.object.put(a, "installation", .{ .string = try std.fs.path.join(a, &.{ directory, "installation" }) });
    try defaults.object.put(a, "executables", Settings.object(a));
    var diagnostic: Diagnostic = .{};
    const inputs: Inputs = .{ .path = source, .optional = true, .defaults = defaults, .environment = Settings.object(a), .environment_names = &.{} };
    const missing = try resolve(init, inputs, &diagnostic, false);
    try t.expect(missing.inputs.optional);
    try t.expectEqual(@as(u64, 0), missing.config.query.statement_timeout);
    try Files.write(t.io, source, "query:\n  statement_timeout: 5s\n");
    const present = try resolve(init, missing.inputs, &diagnostic, false);
    try t.expect(!present.inputs.optional);
    try t.expectEqual(@as(u64, 5000), present.config.query.statement_timeout);
    var pinned = present.inputs;
    try @import("transit_query").settings.Registry.set(a, &pinned.environment, "query.statement_timeout", .{ .integer = 7000 });
    try Files.write(t.io, source, "query:\n  statement_timeout: 9s\n");
    try t.expectEqual(@as(u64, 7000), (try resolve(init, pinned, &diagnostic, false)).config.query.statement_timeout);
    try Files.write(t.io, source, "{}\n");
    try t.expectEqual(@as(u64, 7000), (try resolve(init, pinned, &diagnostic, false)).config.query.statement_timeout);
    try t.expectEqual(@as(u64, 0), (try resolve(init, present.inputs, &diagnostic, false)).config.query.statement_timeout);
    var invalid = pinned;
    invalid.environment = try clone(a, pinned.environment);
    invalid.environment_names = &.{"TRANSIT_QUERY"};
    try @import("transit_query").settings.Registry.set(a, &invalid.environment, "query.statement_timeout", .{ .integer = 86400001 });
    diagnostic = .{};
    try t.expectError(error.InvalidConfiguration, resolve(init, invalid, &diagnostic, false));
    try t.expectEqualStrings("TRANSIT_QUERY (query.statement_timeout)", diagnostic.field.?);
    try t.expect(diagnostic.file == null and diagnostic.line == null and diagnostic.column == null);
    try temporary.dir.deleteFile(t.io, "transit.yaml");
    try t.expectError(error.InvalidConfiguration, resolve(init, pinned, &diagnostic, false));
}
