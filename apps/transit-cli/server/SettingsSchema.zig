//! Local placement owns its settings and their application classifications.
const config = @import("transit_query").settings;
const R = config.Registry;
const D = R.Descriptor;
pub const registry: R = .{ .descriptors = &descriptors };
pub const descriptors = [_]D{
    .{ .name = "version", .default_json = "1", .description = "Configuration definition version", .owner = "server", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 1 },
    .{ .name = "installation", .description = "Retained installation directory", .owner = "server", .kind = .string, .scope = .installation, .change = .initialization },
    .{ .name = "startup.require_existing", .default_json = "false", .description = "Refuse missing or empty installations instead of creating one at startup", .owner = "server", .kind = .boolean, .change = .restart },
    .{ .name = "logging.format", .default_json = "\"text\"", .description = "Operational log rendering on stderr", .owner = "server", .kind = .enumeration, .change = .restart, .values = &.{ "text", "json" } },
    .{ .name = "logging.level", .default_json = "\"info\"", .description = "Minimum operational log severity", .owner = "server", .kind = .enumeration, .change = .restart, .values = &.{ "debug", "info", "warn", "error", "off" } },
    .{ .name = "realm", .default_json = "1", .description = "Native security realm", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "admission_ceiling", .default_json = "65536", .description = "Immutable ordinary admission quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 128, .maximum = 65536 },
    .{ .name = "control_reserve", .default_json = "4096", .description = "Immutable reserved control quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .maximum = 65536 },
    .{ .name = "storage.limits.bytes", .default_json = "8589934592", .description = "Reserved encoded immutable data bytes, including unpublished candidates", .owner = "node", .kind = .bytes, .change = .restart, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "storage.limits.control_bytes", .default_json = "67108864", .description = "Separate immutable allocation reserve for control and collection marks", .owner = "node", .kind = .bytes, .change = .restart, .minimum = 1048576, .maximum = 9007199254740991 },
    .{ .name = "storage.limits.candidate_bytes", .default_json = "8388608", .description = "Maximum encoded private candidate buffer per admitted operation", .owner = "node", .kind = .bytes, .change = .restart, .minimum = 1, .maximum = 8388608 },
    .{ .name = "storage.maintenance.collection_every_records", .default_json = "1024", .description = "Allocation ledger progress before beginning another physical collection", .owner = "node", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "storage.maintenance.compact", .default_json = "false", .description = "Relocate current state before collection; retained history still owns old roots", .owner = "node", .kind = .boolean, .change = .restart },
    .{ .name = "storage.maintenance.flush.enabled", .default_json = "true", .description = "Schedule bounded relocation of current Table WAL rows to immutable segments", .owner = "node", .kind = .boolean, .change = .restart },
    .{ .name = "storage.maintenance.flush.rows", .default_json = "256", .description = "Pending current WAL rows that make a Table eligible for flushing", .owner = "node", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 1024 },
    .{ .name = "storage.maintenance.flush.work_rows", .default_json = "32", .description = "Maximum current WAL rows relocated in one maintenance turn", .owner = "node", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 1024 },
    .{ .name = "storage.maintenance.flush.bytes", .default_json = "262144", .description = "Pending encoded current WAL row bytes that make a Table eligible for flushing", .owner = "node", .kind = .bytes, .change = .restart, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "storage.maintenance.flush.age_ms", .default_json = "5000", .description = "Maximum known pending age before eligibility; unknown ages are immediately eligible", .owner = "node", .kind = .duration, .change = .restart, .minimum = 1, .maximum = 60000 },
    .{ .name = "storage.maintenance.flush.resident_bytes", .default_json = "134217728", .description = "Aggregate private Table maintenance workspace including catalog, indexes, caches and encoder", .owner = "node", .kind = .bytes, .change = .restart, .minimum = 33554432, .maximum = 536870912 },
    .{ .name = "query.statement_timeout", .default_json = "0", .session_mutable = true, .description = "Default statement deadline; zero is unlimited", .owner = "query", .kind = .duration, .scope = .session, .change = .new_session, .maximum = 86400000 },
    .{ .name = "query.statement_timeout_ceiling", .default_json = "0", .description = "Maximum session deadline; zero is unlimited", .owner = "query", .kind = .duration, .scope = .session, .change = .new_session, .maximum = 86400000 },
    port("ports.node", "node"),
    port("ports.gateway", "gateway"),
    executable("executables.node", "node", false),
    executable("executables.query_host", "query", false),
    executable("executables.board", "board", true),
    executable("executables.sql_gateway", "sql", false),
    .{ .name = "sql.native.local", .default_json = "true", .description = "Private Unix SQL listener and once-enrolled local peer account", .owner = "sql", .kind = .boolean, .change = .restart },
    .{ .name = "sql.native.http", .default_json = "null", .description = "Native SQL HTTP listener; independent of database wire listeners", .owner = "sql", .kind = .object, .change = .restart, .nullable = true },
    .{ .name = "sql.native.http.address", .default_json = "\"127.0.0.1\"", .description = "Native SQL HTTP bind address", .owner = "sql", .kind = .string, .change = .restart },
    sqlNumber("native.http.port", "Native SQL HTTP port", "19109", .unsigned, 1024, 65535),
    .{ .name = "sql.native.http.tls", .default_json = "true", .description = "Require TLS on the native HTTP listener", .owner = "sql", .kind = .boolean, .change = .restart },
    .{ .name = "sql.native.http.certificate_file", .default_json = "null", .description = "Native HTTPS certificate reference", .owner = "sql", .kind = .string, .change = .restart, .nullable = true, .sensitive = true },
    .{ .name = "sql.native.http.key_file", .default_json = "null", .description = "Native HTTPS private key reference", .owner = "sql", .kind = .string, .change = .restart, .nullable = true, .sensitive = true },
    .{ .name = "sql.postgres", .default_json = "null", .description = "PostgreSQL listener; null disables admission", .owner = "sql", .kind = .object, .change = .restart, .nullable = true },
    sqlNumber("postgres.port", "PostgreSQL loopback port", "15432", .unsigned, 1024, 65535),
    .{ .name = "sql.mysql", .default_json = "null", .description = "MySQL listener; null disables admission", .owner = "sql", .kind = .object, .change = .restart, .nullable = true },
    sqlNumber("mysql.port", "MySQL loopback port", "13306", .unsigned, 1024, 65535),
    .{ .name = "sql.accounts", .default_json = "[]", .description = "SQL logins, authentication and explicit one-time owner bootstrap", .owner = "sql", .kind = .records, .change = .restart, .sensitive = true, .maximum = 32, .items_schema = accountSchema() },
    .{ .name = "sql.native.sources_file", .default_json = "null", .description = "Explicit source bindings for the local peer account", .owner = "sql", .kind = .string, .change = .restart, .nullable = true, .sensitive = true },
    .{ .name = "sql.tls.mode", .default_json = "\"required\"", .description = "SQL transport encryption policy, independent of login authentication", .owner = "sql", .kind = .enumeration, .change = .restart, .values = &.{ "disabled", "optional", "required" } },
    sqlPath("certificate_file"),
    sqlPath("key_file"),
    sqlPath("ca_file"),
    sqlNumber("health_port", "Private loopback SQL recovery and readiness port", "19108", .unsigned, 1024, 65535),
    sqlNumber("drain_ms", "Connection drain deadline", "30000", .duration, 1, 270000),
    sqlNumber("request_timeout_ms", "Native request deadline", "5000", .duration, 1, 60000),
    sqlNumber("command_ms", "Maximum SQL statement duration", "30000", .duration, 1, 270000),
    sqlNumber("idle_ms", "PostgreSQL/MySQL idle timeout; zero keeps idle connections open", "0", .duration, 0, 4294967295),
    sqlNumber("native.session_lease_ms", "Native HTTP SQL session lease, renewed by touch", "30000", .duration, 1, 270000),
    sqlNumber("connections", "Simultaneous SQL connection quota", "64", .unsigned, 1, 256),
    sqlNumber("connections_per_account", "Simultaneous connections per account", "8", .unsigned, 1, 255),
    sqlNumber("authentications", "Simultaneous SQL authentication work", "4", .unsigned, 1, 16),
    sqlNumber("operation_quota", "Initial retained operation quota per account", "1000000", .unsigned, 1, 9007199254740991),
    sqlNumber("byte_quota", "Initial retained logical byte quota per account", "1073741824", .bytes, 1048576, 9007199254740991),
    sqlNumber("pending_quota", "Initial simultaneous unsettled operations per account", "16", .unsigned, 1, 1024),
    .{ .name = "applications", .default_json = "{}", .description = "Application management configuration; null disables admission", .owner = "applications", .kind = .object, .change = .restart, .nullable = true },
    port("applications.port", "applications"),
    .{ .name = "applications.max_applications", .default_json = "8", .description = "Application deployment quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 64 },
    .{ .name = "applications.max_roles", .default_json = "32", .description = "Roles per application quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 256 },
    .{ .name = "gateway_allowed_hosts", .default_json = "[]", .description = "Additional exact native gateway Host authorities", .owner = "gateway", .kind = .strings, .change = .reload },
    .{ .name = "board", .default_json = "{}", .description = "Board listener configuration", .owner = "board", .kind = .object, .change = .restart, .nullable = true },
    port("board.port", "board"),
    .{ .name = "board.public_origin", .default_json = "null", .description = "Exact Board browser origin", .owner = "board", .kind = .string, .change = .restart, .nullable = true },
};
fn sqlNumber(comptime name: []const u8, comptime description: []const u8, comptime default: []const u8, comptime kind: R.Kind, comptime minimum: u64, comptime maximum: u64) D {
    return .{ .name = "sql." ++ name, .description = description, .default_json = default, .owner = "sql", .kind = kind, .change = .restart, .minimum = minimum, .maximum = maximum };
}
fn sqlPath(comptime name: []const u8) D {
    return .{ .name = "sql.tls." ++ name, .description = "PEM file reference; omit all TLS references for managed local trust", .default_json = "null", .owner = "sql", .kind = .string, .change = .restart, .nullable = true, .sensitive = true };
}
fn accountSchema() []const u8 {
    return comptime blk: {
        @setEvalBranchQuota(100000);
        const std = @import("std");
        var buffer: [8192]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        var output: std.json.Stringify = .{ .writer = &writer };
        @import("transit_query").protocol.Schema.schema(@import("SqlSettings.zig").Account, &output) catch @compileError("Account schema exceeds its bounded buffer");
        const result = writer.buffered().*;
        break :blk &result;
    };
}
fn port(comptime name: []const u8, comptime owner: []const u8) D {
    return .{ .name = name, .default_json = comptime blk: {
        const std = @import("std");
        for (.{ .{ "ports.node", "19104" }, .{ "ports.gateway", "19105" }, .{ "applications.port", "19106" }, .{ "board.port", "19107" } }) |pair| if (std.mem.eql(u8, name, pair[0])) break :blk pair[1];
        @compileError("Port default is required");
    }, .description = "Loopback TCP port", .owner = owner, .kind = .unsigned, .change = .restart, .minimum = 1024, .maximum = 65535 };
}
fn executable(comptime name: []const u8, comptime owner: []const u8, comptime nullable: bool) D {
    return .{ .name = name, .description = "Matching executable path", .owner = owner, .kind = .string, .change = .restart, .nullable = nullable };
}

test "local settings descriptors have unique canonical names" {
    try registry.validate();
}
test "SQL defaults leave both protocols disabled without account or TLS inputs" {
    const std = @import("std");
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const defaults = try registry.defaults(arena.allocator());
    try std.testing.expect(R.get(defaults, "sql.postgres").? == .null);
    try std.testing.expect(R.get(defaults, "sql.mysql").? == .null);
    try std.testing.expectEqual(@as(usize, 0), R.get(defaults, "sql.accounts").?.array.items.len);
    const accounts = try registry.lookup("sql.accounts");
    const value = try config.Input.jsonValue(arena.allocator(), "[{\"name\":\"reader\",\"role\":\"reader\",\"password_file\":\"private\"}]");
    _ = try accounts.normalize(arena.allocator(), value);
    try std.testing.expectEqual(@as(?[]const u8, null), try accounts.display(arena.allocator(), value));
    try std.testing.expectError(error.InvalidSettingType, accounts.normalize(arena.allocator(), .{ .string = "private" }));
}
