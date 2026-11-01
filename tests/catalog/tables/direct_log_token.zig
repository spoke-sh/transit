//! Original declaration tokens and immutable bodies survive two process deaths.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const t = std.testing;
const Saved = struct { definition: p.Growth.Definition, bindings: [2]c.DirectClientToken.Binding };
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(Saved, init.arena.allocator(), bytes);
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    for (parsed.value.bindings) |binding| try binding.validate();
    return parsed.value;
}
fn declaration(init: std.process.Init, client: c.DirectTableClient, role: u64, kind: c.DirectLog.Kind, i: u64) !c.DirectClientToken.Binding {
    const object = 644010 + i;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "value", .type = .int64, .nullable = false }};
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(if (kind == .stream) "token_events" else "token_work"), .action = .{ .create = .{
        .owner = role,
        .schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} },
        .configuration = .{ .partitioning = .{ .count = 2, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 30000, .maximum_lease_ms = 30000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 644001 + i }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    var scratch = std.heap.ArenaAllocator.init(init.gpa);
    defer scratch.deinit();
    var frozen = try c.DirectLogIntent.create(init.gpa, client.connection, try c.DirectLogProtocol.Ddl.encode(scratch.allocator(), request));
    defer frozen.deinit();
    const reference: c.DirectIntent.Reference = .{ .log = try frozen.stage(client, @splat(0x46)) };
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x46), .token = @splat(@intCast(0x47 + i)) }, .fingerprint = try reference.digest(), .intent = reference };
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    const saved: Saved = .{ .definition = p.Growth.current_definition, .bindings = .{ try declaration(init, client, role, .stream, 0), try declaration(init, client, role, .queue, 1) } };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    _ = try c.DirectClientToken.bind(client, saved.bindings[0]);
    try t.expectError(error.InvalidTableResponse, c.DirectClientToken.bind(client, saved.bindings[1]));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings) |binding| {
        const receipt = (try c.DirectClientToken.lookup(client, binding.key)).?;
        try t.expectEqualDeep(binding, receipt.binding);
        const observed = try receipt.binding.intent.operation(client, .inspect, 1);
        defer observed.deinit();
        try t.expect(observed.value.result.log_operation == .not_observed);
        try t.expectEqualDeep(receipt, try c.DirectClientToken.bind(client, binding));
    }
    (try saved.bindings[0].intent.admit(client)).deinit();
    try t.expectError(error.InvalidTableResponse, saved.bindings[1].intent.admit(client));
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings) |binding| {
        const initial = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(initial.pending);
        try t.expectEqualDeep(binding, initial.receipt.binding);
        const observed = try binding.intent.operation(client, .inspect, 1);
        defer observed.deinit();
        try t.expect(observed.value.result.log_operation.operation.pending());
        const original_admission = try binding.intent.admit(client);
        defer original_admission.deinit();
        try t.expectEqualDeep(observed.value.result.log_operation.operation, original_admission.value.result.log_admitted);
        const completed = try binding.intent.operation(client, .execute, 16);
        defer completed.deinit();
        const value = completed.value.result.log_operation.operation;
        try t.expectEqual(.complete, value.phase);
        try t.expectEqual(@as(u32, 2), value.initialized);
        try t.expectEqual(binding.intent.log.kind, value.kind);
        try binding.intent.log.binding.requireSame(value.binding);
        const terminal = try c.DirectClientToken.update(client, .{ .key = binding.key, .expected = initial.revision, .pending = false, .cancel = false, .record = null });
        try t.expect(!terminal.pending);
        const repeat = try binding.intent.operation(client, .execute, 16);
        defer repeat.deinit();
        try t.expectEqualDeep(completed.value.result.log_operation, repeat.value.result.log_operation);
        try t.expectEqualDeep(initial.receipt, (try c.DirectClientToken.lookup(client, binding.key)).?);
    }
}
