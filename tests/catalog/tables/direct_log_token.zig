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

/// Exercise account selection, bounded native recovery and terminal settlement
/// separately. The proxy saves signed requests and withholds one Queue reply at
/// each boundary; every following phase uses the retained original bindings.
pub fn prepareWorkloads(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var bindings: [2]c.DirectClientToken.Binding = undefined;
    for ([_]c.DirectLog.Kind{ .stream, .queue }, 0..) |kind, i| {
        const ddl = try declaration(init, client, role, kind, i);
        (try ddl.intent.admit(client)).deinit();
        const completed = try ddl.intent.operation(client, .execute, 16);
        defer completed.deinit();
        const definition = completed.value.result.log_operation.operation.resulting.?;
        try t.expectEqual(.complete, completed.value.result.log_operation.operation.phase);
        const metadata = try client.call(.{ .log_lookup = .{ .namespace = 1, .name = definition.properties.name.slice() } });
        defer metadata.deinit();
        const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = 0 };
        const identity: p.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 644101 + i };
        const work: c.DirectWorkloadIntent.Work = if (kind == .stream)
            .{ .stream = .{ .work = .{ .consume = .{ .target = target, .operation = identity, .group = null, .from = 0, .until = null, .timestamp = null } }, .payload = null } }
        else
            .{ .queue = .{ .work = .{ .claim = .{ .target = target, .operation = identity, .maximum = 1, .lease_ms = 30000 } }, .payload = null } };
        var frozen = try c.DirectWorkloadIntent.create(init.gpa, client.connection, metadata.value.result.log_lookup.?, work);
        defer frozen.deinit();
        const reference: c.DirectIntent.Reference = .{ .workload = try frozen.stage(client, @splat(0x56)) };
        bindings[i] = .{ .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x56), .token = @splat(@intCast(0x57 + i)) }, .fingerprint = try reference.digest(), .intent = reference, .budget = .{ .bytes = try reference.workload.reservationBytes() } };
        // More than the native owner's 256-frame replay step. These closures
        // retain no payload, lease or read pin and have distinct saved identities.
        for (0..257) |step| {
            const action: c.DirectTableProtocol.Action = switch (work) {
                .stream => |value| blk: {
                    var original = value.work;
                    original.consume.operation.operation = 645000 + step;
                    break :blk .{ .stream = .{ .cancel = original } };
                },
                .queue => |value| blk: {
                    var original = value.work;
                    original.claim.operation.operation = 646000 + step;
                    break :blk .{ .queue = .{ .cancel = original } };
                },
            };
            const closed = try client.call(action);
            defer closed.deinit();
            if (kind == .stream) try t.expect(closed.value.result.stream.operation.? == .closed) else try t.expect(closed.value.result.queue.operation.? == .closed);
        }
    }
    const saved: Saved = .{ .definition = p.Growth.current_definition, .bindings = bindings };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    _ = try c.DirectClientToken.bind(client, saved.bindings[0]);
    try t.expectError(error.InvalidTableResponse, c.DirectClientToken.bind(client, saved.bindings[1]));
}

fn workloadOperation(reference: c.DirectIntent.Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(c.DirectTableProtocol.Action, "operation"), "command")) !std.json.Parsed(c.DirectTableProtocol.Response) {
    // A recovering response accepts no new work. The same frozen request is
    // retained across every bounded owner step, never regenerated from a name.
    for (0..4) |_| {
        const result = try reference.operation(client, command, 1);
        errdefer result.deinit();
        const recovering = switch (result.value.result) {
            .stream => |value| value == .recovering,
            .queue => |value| value == .recovering,
            else => return error.InvalidTableResponse,
        };
        if (!recovering) return result;
        result.deinit();
    }
    return error.FixtureBudget;
}

pub fn executeWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expectEqualDeep(binding, state.receipt.binding);
        try t.expect(state.pending);
        try t.expectError(error.Conflict, c.DirectClientToken.update(client, .{ .key = binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = null }));
        if (i == 0) {
            const result = try workloadOperation(binding.intent, client, .execute);
            defer result.deinit();
            try t.expectEqual(@as(u64, 0), result.value.result.stream.operation.?.consume.cut.next);
        } else try t.expectError(error.InvalidTableResponse, workloadOperation(binding.intent, client, .execute));
    }
}

fn settleWorkload(client: c.DirectTableClient, binding: c.DirectClientToken.Binding, revision: p.DataLifecycle.Position) !struct { state: c.DirectClientToken.Progress, recovering: usize } {
    for (0..4) |step| {
        const state = c.DirectClientToken.update(client, .{ .key = binding.key, .expected = revision, .pending = false, .cancel = false, .record = null }) catch |err| {
            if (err == error.Conflict) continue;
            return err;
        };
        return .{ .state = state, .recovering = step };
    }
    return error.FixtureBudget;
}

pub fn settleWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(state.pending);
        if (i == 0) {
            const settled = try settleWorkload(client, binding, state.revision);
            try t.expect(!settled.state.pending);
            try t.expectEqual(@as(usize, 1), settled.recovering);
        } else try t.expectError(error.InvalidTableResponse, settleWorkload(client, binding, state.revision));
    }
}

pub fn verifyWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(!state.pending);
        try t.expectEqualDeep(binding, state.receipt.binding);
        try t.expectEqualDeep(state, try c.DirectClientToken.update(client, .{ .key = binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = null }));
        const original = try workloadOperation(binding.intent, client, .inspect);
        defer original.deinit();
        const late_cancel = try workloadOperation(binding.intent, client, .cancel);
        defer late_cancel.deinit();
        if (i == 0) {
            try t.expectEqualDeep(original.value.result.stream, late_cancel.value.result.stream);
            try t.expectEqual(@as(u64, 0), original.value.result.stream.operation.?.consume.cut.next);
        } else {
            try t.expectEqualDeep(original.value.result.queue, late_cancel.value.result.queue);
            try t.expectEqual(@as(u32, 0), original.value.result.queue.operation.?.claim.rows);
        }
    }
}
