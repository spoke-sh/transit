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
            .document => .{ .document = .{ .document = 91, .type_revision = 1, .limits = .{ .record_bytes = 4096, .staging_bytes = 16384, .staging_records = 4 } } },
        },
    } };
}

fn clean(turn: s.Turn) !void {
    for (turn.decision.mutations) |slot| try t.expectEqual(null, slot);
    for (turn.decision.outputs) |slot| try t.expectEqual(null, slot);
}

test "named resource initialization survives every discarded proposal and exact retry" {
    inline for (.{Resource.Kind.document}) |kind| {
        var store: Store = .{};
        defer store.deinit();
        const owner: Owner = .{ .initial = try definition(kind) };
        const phases: []const Owner.Step = &.{ .reserved, .initialized, .complete };
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

test "named resources reject adoption, conflicting initialization and current permission loss" {
    inline for (.{Resource.Kind.document}) |kind| {
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

test "named resource emptiness separates framework proposals from private user writes" {
    var store: Store = .{};
    defer store.deinit();
    const owner: Owner = .{ .initial = try definition(.document) };
    var turn = try store.capture();
    try turn.write(try p.Value.init("user"), null);
    const before = turn.decision;
    try t.expectError(error.NamedResourceNotEmpty, owner.initialize(t.allocator, &turn, 0));
    try t.expectEqualDeep(before, turn.decision);
    turn = try store.capture();
    try turn.write(try p.Value.init("\x00behavior"), try p.Value.init("framework"));
    try t.expectEqual(Owner.Step.reserved, try owner.initialize(t.allocator, &turn, 0));
    try store.commit(turn);
    turn = try store.capture();
    try t.expectEqual(Owner.Step.reserved, (try owner.inspect(t.allocator, &turn, 0)).?);
}
