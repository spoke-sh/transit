//! Local placement owns its settings and their application classifications.
const config = @import("transit_query").settings;
const R = config.Registry;
const D = R.Descriptor;
pub const registry: R = .{ .descriptors = &descriptors };
pub const descriptors = [_]D{
    .{ .name = "version", .default_json = "1", .description = "Configuration definition version", .owner = "server", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 1 },
    .{ .name = "installation", .description = "Retained installation directory", .owner = "server", .kind = .string, .scope = .installation, .change = .initialization },
    .{ .name = "realm", .default_json = "1", .description = "Native security realm", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "admission_ceiling", .default_json = "65536", .description = "Immutable ordinary admission quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 128, .maximum = 65536 },
    .{ .name = "control_reserve", .default_json = "4096", .description = "Immutable reserved control quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .maximum = 65536 },
    .{ .name = "query.statement_timeout", .default_json = "0", .session_mutable = true, .description = "Default statement deadline; zero is unlimited", .owner = "query", .kind = .duration, .scope = .session, .change = .new_session, .maximum = 86400000 },
    .{ .name = "query.statement_timeout_ceiling", .default_json = "0", .description = "Maximum session deadline; zero is unlimited", .owner = "query", .kind = .duration, .scope = .session, .change = .new_session, .maximum = 86400000 },
    port("ports.cold", "cold"),
    port("ports.cold_console", "cold"),
    port("ports.store", "store"),
    port("ports.node", "node"),
    port("ports.gateway", "gateway"),
    executable("executables.minio", "cold", false),
    executable("executables.ursula", "store", false),
    executable("executables.node", "node", false),
    executable("executables.query_host", "query", false),
    executable("executables.board", "board", true),
    .{ .name = "applications", .default_json = "{}", .description = "Application management configuration; null disables admission", .owner = "applications", .kind = .object, .change = .restart, .nullable = true },
    port("applications.port", "applications"),
    .{ .name = "applications.max_applications", .default_json = "8", .description = "Application deployment quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 64 },
    .{ .name = "applications.max_roles", .default_json = "32", .description = "Roles per application quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 256 },
    .{ .name = "gateway_allowed_hosts", .default_json = "[]", .description = "Additional exact native gateway Host authorities", .owner = "gateway", .kind = .strings, .change = .reload },
    .{ .name = "board", .default_json = "{}", .description = "Board listener configuration", .owner = "board", .kind = .object, .change = .restart, .nullable = true },
    port("board.port", "board"),
    .{ .name = "board.public_origin", .default_json = "null", .description = "Exact Board browser origin", .owner = "board", .kind = .string, .change = .restart, .nullable = true },
};
fn port(comptime name: []const u8, comptime owner: []const u8) D {
    return .{ .name = name, .default_json = comptime blk: {
        const std = @import("std");
        for (.{ .{ "ports.cold", "19101" }, .{ "ports.cold_console", "19102" }, .{ "ports.store", "19103" }, .{ "ports.node", "19104" }, .{ "ports.gateway", "19105" }, .{ "applications.port", "19106" }, .{ "board.port", "19107" } }) |pair| if (std.mem.eql(u8, name, pair[0])) break :blk pair[1];
        @compileError("Port default is required");
    }, .description = "Loopback TCP port", .owner = owner, .kind = .unsigned, .change = .restart, .minimum = 1024, .maximum = 65535 };
}
fn executable(comptime name: []const u8, comptime owner: []const u8, comptime nullable: bool) D {
    return .{ .name = name, .description = "Matching executable path", .owner = owner, .kind = .string, .change = .restart, .nullable = nullable };
}

test "local settings descriptors have unique canonical names" {
    try registry.validate();
}
