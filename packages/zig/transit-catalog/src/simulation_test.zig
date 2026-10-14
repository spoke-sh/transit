//! Seeded contract checks over atomic private turns, not disk evidence.
const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const m = c.TableCatalogRecords;
const Store = @import("TestStore.zig");
const owner: c.TableCatalog = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17, .authority = @import("TestStore.zig").profile, .table_limits = .{ .record_bytes = 4096, .staging_bytes = 32768, .staging_records = 8 } } };
const caller = 19;
const Accepted = struct { request: c.TableDdlRequest, outcome: c.TableCatalog.Outcome };

fn writes(turn: *const c.station.Turn) usize {
    var result: usize = 0;
    for (turn.decision.mutations) |slot| result += @intFromBool(slot != null);
    return result;
}
fn rights(store: *Store, revision: *u64, inspect_allowed: bool, create_allowed: bool) !void {
    const turn = try store.capture(17);
    var policy = try Store.Rights.administrator(owner.configuration.scope, caller);
    policy.revision = revision.* + 1;
    policy.inspect = inspect_allowed;
    policy.create = create_allowed;
    try store.setRights(policy);
    try store.commit(turn);
    revision.* += 1;
}
fn sameState(before: *const Store, after: *const Store) !void {
    try t.expectEqual(before.revision, after.revision);
    try t.expectEqual(before.input, after.input);
    try t.expectEqual(before.state.count(), after.state.count());
    var entries = before.state.iterator();
    while (entries.next()) |entry| try t.expect(entry.value_ptr.eql(after.state.get(entry.key_ptr.*).?));
}

// The oracle retains accepted intent and original outcomes. It does not
// reproduce the publication representation, index or conflict algorithm.
fn inspect(store: *Store, accepted: []const Accepted) !void {
    var turn = try store.capture(caller);
    var created: usize = 0;
    for (accepted) |record| {
        turn = try store.capture(caller);
        const request = record.request;
        try t.expectEqualDeep(record.outcome, (try owner.status(&turn, caller, request.operation, try request.digest(owner.configuration.scope))).?);
        if (record.outcome.operation.state != .applied) continue;
        created += 1;
        var definition = (try owner.lookup(t.allocator, &turn, caller, request.name)).?;
        defer definition.deinit();
        try t.expectEqual(request.object, definition.metadata.object);
        try t.expectEqual(record.outcome.operation.admitted_input, definition.metadata.admitted_input);
        try t.expectEqual(caller, definition.metadata.principal);
        try t.expectEqualDeep(request.action.create.schema, definition.schema.schema);
        try t.expectEqualDeep(definition.metadata, try owner.historical(&turn, caller, request.object, record.outcome.operation.metadata));
    }
    var cursor: ?c.TableCatalog.Cursor = null;
    var previous: u64 = 0;
    var listed: usize = 0;
    while (true) {
        turn = try store.capture(caller);
        const page = try owner.list(&turn, caller, cursor);
        try t.expectEqual(store.revision, page.resource_revision);
        for (page.entries) |slot| if (slot) |entry| {
            try t.expect(entry.metadata.object > previous);
            previous = entry.metadata.object;
            var matches: usize = 0;
            for (accepted) |record| {
                if (record.outcome.operation.state == .applied and record.request.object == entry.metadata.object) matches += 1;
            }
            try t.expectEqual(1, matches);
            listed += 1;
            try t.expect(listed <= created);
        };
        cursor = page.next;
        if (cursor == null) break;
    }
    try t.expectEqual(created, listed);
    try t.expectEqual(0, writes(&turn));
}
fn fresh(object: u64, operation: u64, name: []const u8) !c.TableDdlRequest {
    return .{ .principal = caller, .operation = operation, .object = object, .expected_revision = 0, .name = try .init(name), .action = .{ .create = .{ .schema = .{
        .object = object,
        .revision = 1,
        .next_column = 4,
        .columns = &.{ .{ .id = 1, .name = "id", .type = .int32 }, .{ .id = 2, .name = "name", .type = .utf8 }, .{ .id = 3, .name = "active", .type = .boolean } },
        .primary_key = &.{},
    } } } };
}

test "simulation: catalog publication, exact receipts and current policy survive interrupted turns" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    const rng = random.random();
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    try store.commit(turn);
    var policy_revision: u64 = 0;
    try rights(&store, &policy_revision, true, true);
    var accepted: std.ArrayList(Accepted) = .empty;
    defer accepted.deinit(t.allocator);
    for (0..64) |round| {
        var name: [16]u8 = undefined;
        var request = try fresh(1000 + round, std.math.maxInt(u64) - round, try std.fmt.bufPrint(&name, "item{d:0>3}", .{round}));
        if (round % 4 != 0) {
            const original = accepted.items[4 * rng.uintLessThan(usize, (round + 3) / 4)].request;
            if (round % 4 == 2) {
                request.object = original.object;
                request.action.create.schema.object = original.object;
            } else {
                request.name = original.name;
                request.action.create.if_not_exists = round % 4 == 3;
            }
        }
        const expected_state: @FieldType(m.Operation, "state") = if (round % 4 == 0) .applied else if (round % 4 == 3) .unchanged else .rejected;
        const expected_reason: @FieldType(m.Operation, "reason") = if (round % 4 == 1) .name_conflict else if (round % 4 == 2) .object_conflict else .none;
        var completed: ?c.TableCatalog.Outcome = null;
        var denied: usize = 0;
        var discards: usize = 0;
        var losses: usize = 0;
        var steps: usize = 0;
        while (steps < 200) : (steps += 1) {
            if (rng.boolean()) {
                denied += 1;
                const deny_inspection = rng.boolean();
                try rights(&store, &policy_revision, !deny_inspection, deny_inspection);
                turn = try store.capture(caller);
                try t.expectError(error.CatalogDenied, owner.step(t.allocator, &turn, request));
                if (deny_inspection) try t.expectError(error.CatalogDenied, owner.list(&turn, caller, null)) else try inspect(&store, accepted.items);
                if (accepted.items.len != 0) {
                    const old = accepted.items[rng.uintLessThan(usize, accepted.items.len)];
                    try t.expectError(error.CatalogDenied, owner.step(t.allocator, &turn, old.request));
                    if (deny_inspection) try t.expectError(error.CatalogDenied, owner.status(&turn, caller, old.request.operation, try old.request.digest(owner.configuration.scope)));
                }
                try t.expectEqual(0, writes(&turn));
                try rights(&store, &policy_revision, true, true);
            }
            var before = try store.clone();
            defer before.deinit();
            store.reads = 0;
            store.fail_at = 1 + rng.uintLessThan(usize, 2);
            turn = try store.capture(caller);
            try t.expectError(error.Unavailable, owner.step(t.allocator, &turn, request));
            try t.expectError(error.Unavailable, store.commit(turn));
            try t.expectEqual(0, writes(&turn));
            try sameState(&before, &store);
            store.fail_at = null;

            var candidate = try store.capture(caller);
            const result = try owner.step(t.allocator, &candidate, request);
            try t.expect(writes(&candidate) <= c.protocol.Growth.turn_mutations);
            try sameState(&before, &store);
            try inspect(&store, accepted.items);
            if (rng.boolean()) {
                discards += 1;
                var replacement = try store.capture(caller);
                try t.expectEqualDeep(result, try owner.step(t.allocator, &replacement, request));
                try t.expectEqualDeep(candidate.decision, replacement.decision);
                candidate = replacement;
            }
            try store.commit(candidate);
            if (rng.boolean()) {
                losses += 1;
                const replacement = try store.clone();
                store.deinit();
                store = replacement;
            }
            if (result.terminal()) {
                completed = result;
                break;
            }
            // No name or schema is visible at a partial publication stage.
            try inspect(&store, accepted.items);
        }
        const result = completed orelse return error.TestUnexpectedResult;
        try t.expectEqual(expected_state, result.operation.state);
        try t.expectEqual(expected_reason, result.operation.reason);
        try accepted.append(t.allocator, .{ .request = request, .outcome = result });
        turn = try store.capture(caller);
        try t.expectEqualDeep(result, try owner.step(t.allocator, &turn, request));
        try t.expectEqual(0, writes(&turn));
        var altered = request;
        altered.name = try .init("changed");
        try t.expectError(error.CatalogIdentityConflict, owner.step(t.allocator, &turn, altered));
        try t.expectEqual(0, writes(&turn));
        try inspect(&store, accepted.items);
        const page = try owner.list(&turn, caller, null);
        if (page.next) |cursor| {
            try rights(&store, &policy_revision, true, true);
            turn = try store.capture(caller);
            try t.expectError(error.CatalogCursorChanged, owner.list(&turn, caller, cursor));
        }
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"catalog\",\"round\":{d},\"outcome\":\"{s}\",\"reason\":\"{s}\",\"denied\":{d},\"discards\":{d},\"lost_replies\":{d},\"steps\":{d},\"input\":{d},\"keys\":{d}}}\n", .{ round, @tagName(result.operation.state), @tagName(result.operation.reason), denied, discards, losses, steps + 1, result.operation.admitted_input, store.state.count() });
    }
    try t.expectEqual(64, accepted.items.len);
}
