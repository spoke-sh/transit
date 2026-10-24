//! Private-turn semantics. Native durability and current-authority enforcement
//! require the separate caller/host integration proof.
const std = @import("std");
const t = std.testing;
const app = @import("root.zig");
const p = app.protocol;
const s = app.station;
const Resource = app.query.catalog.DirectResource;
const Owner = app.NamedResource;
const Store = app.query.testing.Store;

fn definition(kind: Resource.Kind) !Resource.Definition {
    const name = try app.query.catalog.TableAuthority.Name.init("named");
    return .{ .object = .{ .scope = .{ .realm = 1, .resource = 6, .catalog = std.math.maxInt(u64) }, .branch = 1, .object = 99 }, .revision = 1, .namespace = 1, .name = name, .authorization = 100, .resource = 7, .allocating_principal = 0, .allocation = .{ .sequence = 10 }, .creation = .{
        .namespace = 1,
        .name = name,
        .owner = 17,
        .writer = 3,
        .owned = false,
        .deadline_ms = null,
        .history_ms = null,
        .spec = switch (kind) {
            .kv => .{ .kv = .{ .value_type = .utf8, .nullable = true, .key_encoding = .native_bytes, .value_encoding = .fvl1 } },
            .document => .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } },
        },
    } };
}

fn clean(turn: s.Turn) !void {
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    for (turn.decision.outputs) |slot| try t.expectEqual(null, slot);
}

test "named resource initialization survives every discarded proposal and exact retry" {
    inline for (.{ Resource.Kind.kv, Resource.Kind.document }) |kind| {
        var store: Store = .{};
        defer store.deinit();
        const owner: Owner = .{ .initial = try definition(kind) };
        const phases: []const Owner.Step = if (kind == .kv) &.{.complete} else &.{ .reserved, .initialized, .complete };
        for (phases, 0..) |phase, index| {
            var observation = try store.capture();
            const before = try owner.inspect(t.allocator, &observation, 0);
            try t.expectEqual(if (index == 0) null else @as(?Owner.Step, phases[index - 1]), before);
            try clean(observation);
            var discarded = try store.capture();
            try t.expectEqual(phase, try owner.initialize(t.allocator, &discarded, 0));
            observation = try store.capture();
            try t.expectEqual(before, try owner.inspect(t.allocator, &observation, 0));
            var restarted = try store.capture();
            try t.expectEqual(phase, try owner.initialize(t.allocator, &restarted, 0));
            try t.expectEqualDeep(discarded.decision, restarted.decision);
            try store.commit(restarted);
        }
        var turn = try store.capture();
        try t.expectEqual(Owner.Step.complete, try owner.initialize(t.allocator, &turn, 0));
        try clean(turn);
        const marker = try p.DataLifecycle.ResourceInitialization.decode((try turn.read(p.DataLifecycle.ResourceInitialization.key())).?);
        try t.expectEqualDeep(try owner.initial.initialization(t.allocator), marker);
        var other = owner;
        other.initial.object.object += 1;
        try t.expectError(error.NamedResourceIdentityConflict, other.initialize(t.allocator, &turn, 0));
        try clean(turn);
        other = owner;
        other.initial.resource += 1;
        try t.expectError(error.NamedResourceIdentityConflict, other.initialize(t.allocator, &turn, 0));
        try clean(turn);
        other = owner;
        other.initial.revision += 1;
        try t.expectError(error.InvalidNamedResource, other.initialize(t.allocator, &turn, 0));
        try clean(turn);
    }
}

test "named resource KV uses owned canonical values and enforces explicit type, key and value bounds" {
    var store: Store = .{};
    defer store.deinit();
    const owner: Owner = .{ .initial = try definition(.kv) };
    var turn = try store.capture();
    try t.expectError(error.NamedResourceNotInitialized, owner.put(t.allocator, &turn, 0, "one", .null));
    try clean(turn);
    _ = try owner.initialize(t.allocator, &turn, 0);
    try store.commit(turn);
    const text = "a canonical owned value";
    turn = try store.capture();
    try owner.put(t.allocator, &turn, 0, "one", .{ .value = .{ .atom = .{ .bytes = text } } });
    try store.commit(turn);
    turn = try store.capture();
    var found = (try owner.get(t.allocator, &turn, 0, "one")).?;
    defer found.deinit();
    try t.expectEqualStrings(text, found.cell.value.atom.bytes);
    try clean(turn);
    // A later mutation cannot overwrite the caller's decoded arena.
    try owner.put(t.allocator, &turn, 0, "one", .null);
    try store.commit(turn);
    try t.expectEqualStrings(text, found.cell.value.atom.bytes);
    turn = try store.capture();
    var null_value = (try owner.get(t.allocator, &turn, 0, "one")).?;
    defer null_value.deinit();
    try t.expectEqual(.null, null_value.cell);
    try owner.remove(t.allocator, &turn, 0, "one");
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(null, try owner.get(t.allocator, &turn, 0, "one"));
    try t.expectError(error.InvalidNamedResourceKey, Owner.key(""));
    try t.expectError(error.InvalidNamedResourceKey, Owner.key(&@as([32]u8, @splat(1))));
    try t.expectEqual(@as(usize, 32), (try Owner.key(&@as([31]u8, @splat(1)))).len);
    try t.expectError(error.InvalidNamedResourceValue, owner.put(t.allocator, &turn, 0, "one", .missing));
    try clean(turn);
    try t.expectError(error.WriteFailed, owner.put(t.allocator, &turn, 0, "one", .{ .value = .{ .atom = .{ .bytes = &@as([256]u8, @splat('x')) } } }));
    try clean(turn);
    // Raw native bytes cannot be silently interpreted under another schema.
    var encoded: [256]u8 = undefined;
    const foreign = try app.query.fuze.Types.Codec.encode(.{ .value = .{ .atom = .{ .boolean = true } } }, .{ .name = "value", .type = .boolean }, &encoded);
    try turn.write(try Owner.key("one"), try p.Value.init(foreign));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.InvalidNamedResourceValue, owner.get(t.allocator, &turn, 0, "one"));
    try clean(turn);
}

test "named resources reject adoption, conflicting initialization and current permission loss" {
    inline for (.{ Resource.Kind.kv, Resource.Kind.document }) |kind| {
        var store: Store = .{};
        defer store.deinit();
        const owner: Owner = .{ .initial = try definition(kind) };
        var turn = try store.capture();
        try turn.write(try p.Value.init("unowned"), try p.Value.init("data"));
        try store.commit(turn);
        turn = try store.capture();
        try t.expectError(error.NamedResourceNotEmpty, owner.initialize(t.allocator, &turn, 0));
        try clean(turn);
        try turn.write(try p.Value.init("unowned"), null);
        try store.commit(turn);
        try store.grantObject(0, 7, p.State.permission(.inspect) | p.State.permission(.read));
        turn = try store.capture();
        try t.expectError(error.AccessDenied, owner.initialize(t.allocator, &turn, 0));
        try clean(turn);
        turn = try store.capture();
        try t.expectEqual(null, try owner.inspect(t.allocator, &turn, 0));
        try clean(turn);
        try store.grantObject(0, 7, p.State.all_permissions);
        turn = try store.capture();
        _ = try owner.initialize(t.allocator, &turn, 0);
        try store.commit(turn);
        var other = owner;
        other.initial.creation.history_ms = 0;
        turn = try store.capture();
        try t.expectError(error.NamedResourceIdentityConflict, other.initialize(t.allocator, &turn, 0));
        try clean(turn);
        try store.grantObject(0, 7, p.State.permission(.inspect));
        turn = try store.capture();
        try t.expectError(error.AccessDenied, owner.inspect(t.allocator, &turn, 0));
        try clean(turn);
    }
}

test "named resource Document creation uses the service and cannot adopt an existing anonymous Document" {
    var store: Store = .{};
    defer store.deinit();
    const owner: Owner = .{ .initial = try definition(.document) };
    const service = try owner.document();
    var turn = try store.capture();
    const spec = owner.initial.creation.spec.document;
    try service.create(&turn, spec.type_revision, spec.limits);
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.NamedResourceNotEmpty, owner.initialize(t.allocator, &turn, 0));
    try clean(turn);
}

test "named resource KV rejects a partial marker that no atomic initialization can create" {
    var store: Store = .{};
    defer store.deinit();
    const owner: Owner = .{ .initial = try definition(.kv) };
    var turn = try store.capture();
    try turn.write(Owner.reservationKey(), try (try owner.initial.initialization(t.allocator)).encode());
    try store.commit(turn);
    turn = try store.capture();
    try t.expectError(error.NamedResourceIdentityConflict, owner.initialize(t.allocator, &turn, 0));
    try clean(turn);
}

test "named resource emptiness separates framework proposals from private user writes" {
    var store: Store = .{};
    defer store.deinit();
    const owner: Owner = .{ .initial = try definition(.kv) };
    var turn = try store.capture();
    try turn.write(try p.Value.init("user"), null);
    const before = turn.decision;
    try t.expectError(error.NamedResourceNotEmpty, owner.initialize(t.allocator, &turn, 0));
    try t.expectEqualDeep(before, turn.decision);
    turn = try store.capture();
    try turn.write(try p.Value.init("\x00behavior"), try p.Value.init("framework"));
    try t.expectEqual(Owner.Step.complete, try owner.initialize(t.allocator, &turn, 0));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(Owner.Step.complete, (try owner.inspect(t.allocator, &turn, 0)).?);
}
