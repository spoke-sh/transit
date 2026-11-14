//! Native authority composition for provider-placed applications. Placement
//! remains external; server-owned services use the same signed native owners.
const std = @import("std");
const Installation = @import("Installation.zig");
const Files = @import("Files.zig");
const Table = @typeInfo(@FieldType(@import("transit_node_role").LocalConfiguration, "table")).optional.child;

pub fn node(installation: *Installation, allocator: std.mem.Allocator, path: []const u8) !void {
    const config = installation.config;
    const external = config.external.?;
    const init = installation.init;
    const genesis = .{
        .realm = config.realm,
        .root_key = installation.record.root_public,
        .max_clock_error_ms = 10000,
        .allow_history_trim = external.allow_history_trim,
        .admission_ceiling = config.admission_ceiling,
        .control_reserve = config.control_reserve,
    };
    const maintenance = .{ .principal = Installation.maintenance, .seed_file = try installation.path("maintenance.seed"), .interval_ms = external.maintenance.interval_ms, .checkpoint_every_records = external.maintenance.checkpoint_every_records, .operation_timeout_ms = external.request_timeout_ms };
    var storage = config.storage;
    const table: ?Table = if (external.table_file) |file| try Files.read(Table, init.io, allocator, file) else null;
    if (table) |value| {
        // Accept the original declared catalog once. Missing/replaced table
        // configuration can never silently open an empty or different catalog.
        const bytes = try std.json.Stringify.valueAlloc(allocator, value, .{});
        var identity: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &identity, .{});
        if (installation.record.external_table) |retained| {
            if (!std.mem.eql(u8, &identity, &retained)) return error.InstallationIdentityMismatch;
        } else {
            installation.record.external_table = identity;
            try installation.save();
        }
    } else if (installation.record.external_table != null) return error.ConfigurationUnavailable;
    if (table == null) {
        storage.maintenance.flush.enabled = false;
        storage.maintenance.archive.enabled = false;
        storage.maintenance.compact = false;
    }
    if (external.ursula) |provider| {
        _ = try Files.jsonIfChanged(init.io, allocator, path, .{
            .profile = "native_v1",
            .genesis = genesis,
            .ursula_url = provider.url,
            .bucket = provider.bucket,
            .journal = provider.journal,
            .listen = external.listen,
            .port = config.ports.node,
            .resident_pages = 512,
            .request_timeout_ms = external.request_timeout_ms,
            .readiness_file = try installation.path("server-ready"),
            .storage = storage,
            .maintenance = maintenance,
        });
    } else {
        _ = try Files.jsonIfChanged(init.io, allocator, path, .{
            .profile = "native_v1",
            .genesis = genesis,
            .local_directory = try installation.path("data/native"),
            .listen = external.listen,
            .port = config.ports.node,
            .resident_pages = 512,
            .request_timeout_ms = external.request_timeout_ms,
            .readiness_file = try installation.path("server-ready"),
            .storage = storage,
            .table = table,
            .maintenance = maintenance,
        });
    }
}
