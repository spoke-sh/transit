const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
const Diagnostic = @import("../Diagnostic.zig");
const Settings = @import("../Settings.zig");
const RuntimeRole = @import("../RuntimeRole.zig");
pub const settings = @import("SettingsSchema.zig").registry;
version: u8,
installation: []const u8,
startup: Startup = .{},
logging: @import("Logging.zig") = .{},
realm: u64,
admission_ceiling: u64 = 65536,
control_reserve: u64 = 4096,
storage: @import("transit_query").protocol.Storage.Settings = .{ .maintenance = .{ .compact = true, .archive = .{ .enabled = true }, .flush = .{ .enabled = true } } },
ports: Ports,
executables: Executables = .{},
applications: ?Applications = null,
gateway_allowed_hosts: []const []const u8 = &.{},
board: ?Board = null,
browser: ?@import("transit_serving_http").BrowserRuntime.Config = null,
query: Query = .{},
sql: @import("SqlSettings.zig") = .{},
pub const Query = struct { statement_timeout: u64 = 0, statement_timeout_ceiling: u64 = 0 };
pub const Startup = struct { require_existing: bool = false };
pub const Board = struct { port: u16 = 19107, public_origin: ?[]const u8 = null, workbench_file: ?[]const u8 = null };
pub const Applications = struct { port: u16, max_applications: u16 = 8, max_roles: u16 = 32 };
pub const Ports = struct { node: u16, gateway: u16 };
/// Null selects the role compiled into `transit`. Explicit paths select the
/// matching standalone role, never an ambient PATH or adjacent-file fallback.
pub const Executables = struct { sql_gateway: ?[]const u8 = null, node: ?[]const u8 = null, query_host: ?[]const u8 = null, board: ?[]const u8 = null };
pub const Identity = struct { sql_gateway: [32]u8, config: [32]u8, cli: [32]u8, node: [32]u8, query_host: [32]u8, board: [32]u8 };
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
    return resolve(init, inputs, diagnostic, resolve_executables);
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
    diagnostic.atFile(inputs.path);
    var self = std.json.parseFromValueLeaky(Self, allocator, defaults, .{}) catch |err| {
        return diagnostic.invalidFieldCause(err, "configuration", "contains an unknown field or invalid value", null);
    };
    if (self.query.statement_timeout_ceiling != 0 and (self.query.statement_timeout == 0 or self.query.statement_timeout > self.query.statement_timeout_ceiling)) return diagnostic.invalidField("query.statement_timeout", "must not exceed the configured ceiling", null);
    self.storage.requests.validate() catch return diagnostic.invalidField("storage.requests", "request_bytes must fit data_bytes; all budgets must fit the documented bounds", null);
    if (self.version != 1) return diagnostic.invalidField("version", "must be 1", null);
    if (@import("builtin").os.tag != .linux) return diagnostic.invalidField("platform", "must be Linux", null);
    {
        var board = self.board orelse Board{};
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (board.port == @field(self.ports, name)) return diagnostic.invalidField("board.port and ports." ++ name, "must be different", null);
        if (self.applications) |apps| if (apps.port == board.port) return diagnostic.invalidField("board.port and applications.port", "must be different", null);
        const origin = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{board.port});
        if (board.public_origin) |configured| if (!std.mem.eql(u8, configured, origin)) return diagnostic.invalidFieldCause(error.InvalidBoardOrigin, "board.public_origin", "must match the Board loopback listener", "Omit public_origin to derive it from board.port, or use exactly http://127.0.0.1:PORT.");
        board.public_origin = origin;
        if (board.workbench_file) |path| board.workbench_file = try std.fs.path.resolve(allocator, &.{ base, path });
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
    if (resolve_executables) inline for (@typeInfo(Executables).@"struct".field_names) |name| {
        if (@field(self.executables, name)) |path| {
            diagnostic.field = "executables." ++ name;
            @field(self.executables, name) = resolveExecutable(init, base, path) catch |err| {
                diagnostic.setFailure(err, "cannot locate a configured executable", "Correct this explicit standalone role path relative to the configuration file, or remove the override to use transit's built-in role.");
                return error.InvalidConfiguration;
            };
        }
    };
    if (self.browser) |*browser| {
        inline for (.{ "catalog_seed_file", "cookie_seed_file", "secret_directory" }) |field_name| @field(browser, field_name) = try std.fs.path.resolve(allocator, &.{ base, @field(browser, field_name) });
        if (browser.provider_ca_file) |path| browser.provider_ca_file = try std.fs.path.resolve(allocator, &.{ base, path });
        browser.validate() catch |err| return diagnostic.invalidFieldCause(err, "browser", "requires a valid listener and scoped deployment trust", null);
        if (browser.connection.scope.realm != self.realm) return diagnostic.invalidField("browser.connection.scope.realm", "must match realm", null);
        inline for (@typeInfo(Ports).@"struct".field_names) |field_name| if (browser.port == @field(self.ports, field_name)) return diagnostic.invalidField("browser.port", "must differ from native ports", null);
        if (self.board) |board| if (browser.port == board.port) return diagnostic.invalidField("browser.port", "must differ from board.port", null);
        if (self.applications) |apps| if (browser.port == apps.port) return diagnostic.invalidField("browser.port", "must differ from applications.port", null);
    }
    try self.sql.resolve(allocator, base, diagnostic);
    const sql_ports = [_]?u16{ if (self.sql.postgres) |listener| listener.port else null, if (self.sql.mysql) |listener| listener.port else null, if (self.sql.listening()) self.sql.health_port else null, if (self.sql.native.http) |http| http.port else null };
    const sql_fields = [_][]const u8{ "sql.postgres.port", "sql.mysql.port", "sql.health_port", "sql.native.http.port" };
    for (sql_ports, 0..) |maybe, i| if (maybe) |port| {
        for (sql_ports[0..i]) |previous| if (previous == port) return diagnostic.invalidField(sql_fields[i], "requires distinct SQL listener and health ports", null);
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (port == @field(self.ports, name)) return diagnostic.invalidField(sql_fields[i], "must differ from ports." ++ name, null);
        if (self.browser) |browser| if (port == browser.port) return diagnostic.invalidField(sql_fields[i], "must differ from browser.port", null);
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
        @field(result, name) = self.roleDigest(init, result.cli, @field(RuntimeRole.Role, name)) catch |err| {
            diagnostic.setFailure(err, "cannot validate the configured executable", "Use the matching transit executable or an explicit matching standalone role.");
            return error.InvalidConfiguration;
        };
    }
    diagnostic.field = null;
    return result;
}

pub fn command(self: Self, allocator: std.mem.Allocator, executable: []const u8, comptime role: RuntimeRole.Role, args: []const []const u8) ![]const []const u8 {
    return RuntimeRole.arguments(allocator, executable, @field(self.executables, @tagName(role)), role, args);
}

/// The retained artifact identity binds role and invocation mode as well as the
/// shared definition and actual executable bytes. Equal files in different roles
/// or a changed external/embedded selection cannot silently reuse installation.
pub fn roleDigest(self: Self, init: std.process.Init, executable_digest: [32]u8, comptime role: RuntimeRole.Role) ![32]u8 {
    const external = @field(self.executables, @tagName(role));
    // All embedded roles share the exact CLI bytes already validated during
    // this observation. Hash that file once, then bind each role separately.
    const bytes = if (external) |path| try digest(init, path) else executable_digest;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.local.role.v1\x00");
    hash.update(&@import("transit_query").protocol.Growth.definition_bytes);
    hash.update(@tagName(role));
    hash.update(if (external != null) "\x00external\x00" else "\x00embedded\x00");
    hash.update(&bytes);
    return hash.finalResult();
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
    var listeners: [12]?std.Io.net.Server = @splat(null);
    defer for (&listeners) |*listener| if (listener.*) |*server| server.deinit(io);
    inline for (@typeInfo(Ports).@"struct".field_names, 0..) |name, i| listeners[i] = try listen(io, @field(self.ports, name), "ports." ++ name, diagnostic);
    if (self.browser) |browser| listeners[11] = try (try std.Io.net.IpAddress.parseIp4(browser.listen, browser.port)).listen(io, .{ .reuse_address = true });
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
    try t.expectEqual(.text, missing.config.logging.format);
    try t.expectEqual(.info, missing.config.logging.level);
    try t.expectEqual(@as(u64, 0), missing.config.query.statement_timeout);
    try Files.write(t.io, source, "query:\n  statement_timeout: 5s\nlogging:\n  format: json\n  level: warn\n");
    const present = try resolve(init, missing.inputs, &diagnostic, false);
    try t.expect(!present.inputs.optional);
    try t.expectEqual(.json, present.config.logging.format);
    try t.expectEqual(.warn, present.config.logging.level);
    try t.expectEqual(.restart, (try settings.lookup("logging.format")).change);
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
