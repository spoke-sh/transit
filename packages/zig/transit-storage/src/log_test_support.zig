const p = @import("transit_protocol");
const f = @import("transit_fuze");
const Declaration = @import("LogDeclaration.zig");

pub fn definition(kind: p.StreamQueueDeclaration.Kind) Declaration.Definition {
    return .{
        .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 },
        .revision = 1,
        .schema = .{ .object = 4, .revision = 1, .next_column = 3, .columns = &[_]f.TableSchema.Column{
            .{ .id = 1, .name = "key", .type = .utf8, .nullable = false, .collation = .ascii_ci },
            .{ .id = 2, .name = "value", .type = .binary, .nullable = false },
        } },
        .configuration = .{
            .partitioning = .{ .count = 2, .key_column = 1, .hash = .sha256_64 },
            .retention = .{ .max_age_ms = null },
            .policy = switch (kind) {
                .stream => .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } },
                .queue => .{ .queue = .{ .ordering = .key_fifo, .key_column = 1, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 1, .maximum_ms = 100, .multiplier = 2 }, .dead_letter = null } },
            },
        },
        .limits = .{ .append_rows = 256, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 256, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
        .properties = "catalog-owned-properties",
    };
}
