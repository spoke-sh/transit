//! Local placement owns its settings and their application classifications.
const config = @import("transit_query").settings;
const R = config.Registry;
const D = R.Descriptor;
pub const registry: R = .{ .descriptors = &descriptors };
pub const descriptors = [_]D{
    .{ .name = "version", .description = "Configuration definition version", .owner = "server", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 1 },
    .{ .name = "installation", .description = "Retained installation directory", .owner = "server", .kind = .string, .scope = .installation, .change = .initialization },
    .{ .name = "realm", .description = "Native security realm", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 1, .maximum = 9007199254740991 },
    .{ .name = "admission_ceiling", .description = "Immutable ordinary admission quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .minimum = 128, .maximum = 65536 },
    .{ .name = "control_reserve", .description = "Immutable reserved control quota", .owner = "node", .kind = .unsigned, .scope = .installation, .change = .initialization, .maximum = 65536 },
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
    .{ .name = "applications", .description = "Application management configuration; null disables admission", .owner = "applications", .kind = .object, .change = .restart, .nullable = true },
    port("applications.port", "applications"),
    .{ .name = "applications.max_applications", .description = "Application deployment quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 64 },
    .{ .name = "applications.max_roles", .description = "Roles per application quota", .owner = "applications", .kind = .unsigned, .change = .restart, .minimum = 1, .maximum = 256 },
    .{ .name = "gateway_allowed_hosts", .description = "Additional exact native gateway Host authorities", .owner = "gateway", .kind = .strings, .change = .reload },
    .{ .name = "board", .description = "Board listener configuration", .owner = "board", .kind = .object, .change = .restart, .nullable = true },
    port("board.port", "board"),
    .{ .name = "board.public_origin", .description = "Exact Board browser origin", .owner = "board", .kind = .string, .change = .restart, .nullable = true },
};
fn port(comptime name: []const u8, comptime owner: []const u8) D {
    return .{ .name = name, .description = "Loopback TCP port", .owner = owner, .kind = .unsigned, .change = .restart, .minimum = 1024, .maximum = 65535 };
}
fn executable(comptime name: []const u8, comptime owner: []const u8, comptime nullable: bool) D {
    return .{ .name = name, .description = "Matching executable path", .owner = owner, .kind = .string, .change = .restart, .nullable = nullable };
}

test "local settings descriptors have unique canonical names" {
    try registry.validate();
}
