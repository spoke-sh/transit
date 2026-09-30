//! Seeded contract checks over an atomic private-turn fixture, not disk evidence.
const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const m = c.Model;
const Store = @import("TestStore.zig");
const owner: c.Catalog = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = std.math.maxInt(u64) }, .owner = 3, .administrator = 17 } };
const caller = 19;

fn writes(turn: *const c.station.Turn) usize {
    var result: usize = 0;
    for (turn.decision.mutations) |slot| if (slot != null) {
        result += 1;
    };
    return result;
}

fn rights(store: *Store, revision: *u64, allowed: bool) !void {
    var turn = try store.capture(17);
    try owner.setPolicy(&turn, revision.*, .{ .scope = owner.configuration.scope, .principal = caller, .revision = revision.* + 1, .inspect = allowed, .create = allowed });
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

// The oracle retains only accepted requests and their original input positions.
// It does not reproduce the production record codec or conflict resolution.
fn inspect(store: *Store, accepted: []const m.Receipt) !void {
    var turn = try store.capture(caller);
    var created: usize = 0;
    for (accepted) |receipt| {
        try t.expectEqualDeep(receipt, (try owner.receipt(&turn, receipt.request.operation)).?);
        if (receipt.outcome != .applied) continue;
        created += 1;
        const definition = (try owner.lookup(&turn, receipt.request.name)).?;
        try t.expectEqual(receipt.request.object, definition.object);
        try t.expectEqual(receipt.input, definition.input);
        try t.expectEqual(caller, definition.principal);
        try t.expectEqual(receipt.request.table, definition.source.table.id);
        try t.expectEqualDeep(receipt.request.schema, definition.source.table.schema);
        try t.expectEqualDeep(definition, (try owner.definition(&turn, receipt.request.object, 1)).?);
    }
    // Initialization + caller policy, one receipt per decision, three other
    // records per accepted creation. Discards and retries add no durable keys.
    try t.expectEqual(3 + accepted.len + 3 * created, store.state.count());
    var cursor: ?c.Catalog.Cursor = null;
    var previous: ?c.fuze.model.Name = null;
    var listed: usize = 0;
    while (true) {
        const page = try owner.list(&turn, cursor);
        try t.expectEqual(store.revision, page.resource_revision);
        for (page.entries) |slot| if (slot) |definition| {
            if (previous) |name| try t.expect(std.mem.order(u8, name.slice(), definition.name.slice()) == .lt);
            previous = definition.name;
            var matches: usize = 0;
            for (accepted) |receipt| {
                if (receipt.outcome == .applied and receipt.request.object == definition.object) matches += 1;
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

test "simulation: catalog publication, exact receipts and current policy survive interrupted turns" {
    var random = std.Random.DefaultPrng.init(t.random_seed);
    const rng = random.random();
    var store: Store = .{};
    defer store.deinit();
    var turn = try store.capture(17);
    try owner.initialize(&turn);
    try store.commit(turn);
    var policy_revision: u64 = 0;
    try rights(&store, &policy_revision, true);
    var accepted: std.ArrayList(m.Receipt) = .empty;
    defer accepted.deinit(t.allocator);
    for (0..64) |round| {
        var name: [16]u8 = undefined;
        var sql: [128]u8 = undefined;
        const fresh = try m.CreateTable.compile(owner.configuration.scope, std.math.maxInt(u64) - round, 1000 + round, @intCast(1000 + round), try std.fmt.bufPrint(&sql, "CREATE TABLE {s} (id INT64 NOT NULL, value UTF8 NULL)", .{try std.fmt.bufPrint(&name, "item{d:0>3}", .{round})}));
        var request = fresh;
        const outcome: m.Outcome = switch (round % 4) {
            0 => .applied,
            1 => .name_conflict,
            2 => .object_conflict,
            else => .table_conflict,
        };
        if (outcome != .applied) {
            // The selected source always denotes an accepted creation. Which
            // established object conflicts is independently seed-controlled.
            const original = accepted.items[4 * rng.uintLessThan(usize, (round + 3) / 4)].request;
            switch (outcome) {
                .name_conflict => request.name = original.name,
                .object_conflict => request.object = original.object,
                .table_conflict => request.table = original.table,
                else => unreachable,
            }
        }
        const denied = rng.boolean();
        if (denied) {
            try rights(&store, &policy_revision, false);
            turn = try store.capture(caller);
            try t.expectError(error.CatalogDenied, owner.createTable(&turn, request));
            try t.expectError(error.CatalogDenied, owner.list(&turn, null));
            if (accepted.items.len != 0) {
                const old = accepted.items[rng.uintLessThan(usize, accepted.items.len)];
                try t.expectError(error.CatalogDenied, owner.createTable(&turn, old.request));
                try t.expectError(error.CatalogDenied, owner.receipt(&turn, old.request.operation));
            }
            try t.expectEqual(0, writes(&turn));
            try rights(&store, &policy_revision, true);
        }
        var before = try store.clone();
        defer before.deinit();
        // Fail an actual common point read, or the Table emptiness page.
        const page_fault = outcome == .applied and rng.boolean();
        store.fail_page = page_fault;
        store.reads = 0;
        store.fail_at = if (page_fault) null else 1 + rng.uintLessThan(usize, 3);
        const failed_read = store.fail_at orelse 0;
        turn = try store.capture(caller);
        try t.expectError(error.Unavailable, owner.createTable(&turn, request));
        try t.expectError(error.Unavailable, store.commit(turn));
        try t.expectEqual(0, writes(&turn));
        try sameState(&before, &store);
        store.fail_at = null;
        store.fail_page = false;

        var candidate = try store.capture(caller);
        const expected: m.Receipt = .{ .request = request, .principal = caller, .input = store.input, .outcome = outcome };
        try t.expectEqualDeep(expected, try owner.createTable(&candidate, request));
        try t.expectEqual(@as(usize, if (outcome == .applied) 4 else 1), writes(&candidate));
        try sameState(&before, &store);
        try inspect(&store, accepted.items);
        const discard = rng.boolean();
        if (discard) {
            var replacement = try store.capture(caller);
            try t.expectEqualDeep(expected, try owner.createTable(&replacement, request));
            try t.expectEqualDeep(candidate.decision.mutations, replacement.decision.mutations);
            candidate = replacement;
        }
        try store.commit(candidate);
        try accepted.append(t.allocator, expected);
        const lost_reply = rng.boolean();
        if (lost_reply) {
            // Only committed fixture state survives caller/owner replacement.
            const replacement = try store.clone();
            store.deinit();
            store = replacement;
        }
        turn = try store.capture(caller);
        try t.expectEqualDeep(expected, try owner.createTable(&turn, request));
        try t.expectEqual(0, writes(&turn));
        request.schema.value_type = .binary;
        try t.expectError(error.CatalogIdentityConflict, owner.createTable(&turn, request));
        try t.expectEqual(0, writes(&turn));
        try inspect(&store, accepted.items);
        // A changed committed cut cannot be mixed into an earlier page walk.
        const page = try owner.list(&turn, null);
        if (page.next) |cursor| {
            try rights(&store, &policy_revision, true);
            turn = try store.capture(caller);
            try t.expectError(error.CatalogCursorChanged, owner.list(&turn, cursor));
        }
        if (t.environ.containsConstant("TRANSIT_SIMULATION_TRACE")) std.debug.print("SIMULATION {{\"domain\":\"catalog\",\"round\":{d},\"outcome\":\"{s}\",\"denied\":{},\"page_fault\":{},\"failed_read\":{d},\"discard\":{},\"lost_reply\":{},\"input\":{d},\"keys\":{d}}}\n", .{ round, @tagName(outcome), denied, page_fault, failed_read, discard, lost_reply, expected.input, store.state.count() });
    }
    try t.expectEqual(64, accepted.items.len);
    try t.expectEqual(115, store.state.count());
}
