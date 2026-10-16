const std = @import("std");
const t = std.testing;
const core = @import("root.zig");
const a = core.protocol.Authorization;
const PageStore = @import("pages_test.zig").Store;
const Store = core.authorization_store.Store(PageStore);

test "policy pages reopen without resident role arrays and preserve object kind isolation" {
    var pages: PageStore = .{};
    defer pages.deinit();
    var store = try Store.open(&pages, .{ .catalog = .{}, .revision = 1, .next_id = 1 });
    try store.putRole(.{ .id = 0, .name = try core.Value.init("root"), .owner = 0, .revision = 1, .login = true });
    for (1..20) |id| {
        var buffer: [32]u8 = undefined;
        const name = try core.Value.init(try std.fmt.bufPrint(&buffer, "role-{d}", .{id}));
        try store.putRole(.{ .id = try store.allocate(), .name = name, .owner = 0, .revision = 1, .login = true });
        try store.putMembership(.{ .id = id, .member = 1, .role = id + 1, .grantor = 0, .revision = 1 });
    }
    const resource: a.ObjectRef = .{ .kind = .resource, .id = 42 };
    const table: a.ObjectRef = .{ .kind = .domain, .id = 42 };
    try store.putDomain(.{ .id = 1, .registrar = 7, .actions = 3, .revision = 1 });
    try store.putObject(.{ .reference = resource, .owner = 0, .registrar = 0, .actions = 3, .revision = 1 });
    try store.putObject(.{ .reference = table, .owner = 0, .registrar = 7, .domain = 1, .actions = 3, .revision = 1 });
    for (1..20) |id| try store.putGrant(.{ .id = id, .object = table, .grantee = 1, .grantor = 0, .privileges = 1, .revision = 1 });
    try store.putGrant(.{ .id = 20, .object = resource, .grantee = 1, .grantor = 0, .privileges = 2, .revision = 1 });
    const snapshot = store.snapshot();
    store = try Store.open(&pages, snapshot);
    try t.expectEqual(@as(u64, 19), (try store.named(try core.Value.init("role-19"))).?.id);
    var count: usize = 0;
    var after: ?u64 = null;
    while (true) {
        const page = try store.memberships(1, after);
        for (page.records) |slot| if (slot) |edge| {
            count += 1;
            try t.expectEqual(@as(u64, count), edge.id);
        };
        after = page.next;
        if (after == null) break;
    }
    try t.expectEqual(@as(usize, 19), count);
    var evaluator = try core.authorization.Evaluator(Store).init(&store, 1, .{});
    try t.expectEqual(@as(u64, 1), (try evaluator.evaluate(1, table, 3)).allowed);
    evaluator = try core.authorization.Evaluator(Store).init(&store, 1, .{});
    try t.expectEqual(@as(u64, 2), (try evaluator.evaluate(1, resource, 3)).allowed);
}

test "role rename preserves identity and retirement never revives an old ID" {
    var pages: PageStore = .{};
    defer pages.deinit();
    var store = try Store.open(&pages, .{ .catalog = .{}, .revision = 1, .next_id = 1 });
    var role: a.Role = .{ .id = try store.allocate(), .name = try core.Value.init("reader"), .owner = 0, .revision = 1 };
    try store.putRole(role);
    const original = store.snapshot();
    role.name = try core.Value.init("analyst");
    store.revision = 2;
    role.revision = 2;
    try store.putRole(role);
    try t.expectEqual(@as(?a.Role, null), try store.named(try core.Value.init("reader")));
    try t.expectEqual(@as(u64, 1), (try store.named(role.name)).?.id);
    var old = try Store.open(&pages, original);
    try t.expectEqual(@as(u64, 1), (try old.named(try core.Value.init("reader"))).?.id);
    role.retired = true;
    try store.putRole(role);
    try t.expectEqual(@as(?a.Role, null), try store.named(role.name));
    role.retired = false;
    try t.expectError(error.RetiredAuthorizationRole, store.putRole(role));
    role.id = try store.allocate();
    try store.putRole(role);
    try t.expectEqual(@as(u64, 2), (try store.named(role.name)).?.id);
}

test "failed policy staging leaves the previously selected revision readable" {
    var pages: PageStore = .{};
    defer pages.deinit();
    var published = try Store.open(&pages, .{ .catalog = .{}, .revision = 1, .next_id = 1 });
    try published.putRole(.{ .id = 0, .name = try core.Value.init("root"), .owner = 0, .revision = 1 });
    const before = published.snapshot();
    var candidate = try Store.open(&pages, before);
    candidate.revision = 2;
    pages.fail_at = pages.writes + 1;
    try t.expectError(error.StagingFailed, candidate.putRole(.{ .id = 1, .name = try core.Value.init("reader"), .owner = 0, .revision = 2 }));
    try t.expectEqual(@as(?a.Role, null), try published.role(1));
    try t.expect(std.meta.eql(before, published.snapshot()));
    pages.fail_at = null;
    published = try Store.open(&pages, before);
    try t.expectEqual(@as(?a.Role, null), try published.named(try core.Value.init("reader")));
}

test "retained revoked grants do not consume the active decision budget" {
    var pages: PageStore = .{};
    defer pages.deinit();
    var store = try Store.open(&pages, .{ .catalog = .{}, .revision = 1, .next_id = 2 });
    try store.putRole(.{ .id = 0, .name = try core.Value.init("root"), .owner = 0, .revision = 1 });
    try store.putRole(.{ .id = 1, .name = try core.Value.init("reader"), .owner = 0, .revision = 1 });
    const reference: a.ObjectRef = .{ .kind = .resource, .id = 3 };
    try store.putObject(.{ .reference = reference, .owner = 0, .registrar = 0, .actions = 1, .revision = 1 });
    for (1..101) |id| {
        try store.putGrant(.{ .id = id, .object = reference, .grantee = 1, .grantor = 0, .privileges = 1, .revision = 1 });
        try store.putGrant(.{ .id = id, .object = reference, .grantee = 1, .grantor = 0, .privileges = 0, .revision = 1 });
    }
    try store.putGrant(.{ .id = 101, .object = reference, .grantee = 1, .grantor = 0, .privileges = 1, .revision = 1 });
    var check = try core.authorization.Evaluator(Store).init(&store, 1, .{ .records = 32 });
    try t.expect((try check.evaluate(1, reference, 1)).permits());
    try t.expectEqual(@as(u64, 0), (try store.grant(1)).?.privileges);
    const active = try store.grants(reference, 1, null);
    try t.expectEqual(@as(u64, 101), active.records[0].?.id);
    try t.expect(active.records[1] == null and active.next == null);
}
