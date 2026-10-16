//! Real catalog operations on the public query reference store. This is
//! deterministic transition evidence, not a native durability qualification.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const f = q.fuze;
const s = root.station;
const p = root.protocol;
pub const Store = q.testing.Store;
pub const principal = 65536;
pub const configuration: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .authority = c.testing.Authority.profile, .database_name = c.TableAuthority.Name.init("test") catch unreachable, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 8, .staging_records = 8 } };
pub const catalog: c.TableCatalog = .{ .configuration = configuration };
fn turn(store: *Store) !s.Turn {
    var next = try store.capture();
    next.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    return next;
}
pub fn ddl(store: *Store, request: c.TableDdlRequest) !void {
    for (0..4000) |_| {
        var next = try turn(store);
        const result = try catalog.step(std.testing.allocator, &next, request);
        try store.commit(next);
        if (result.terminal()) {
            if (result.operation.state == .delegated) try std.testing.expectEqual(.applied, result.table.?.state) else try std.testing.expectEqual(.applied, result.operation.state);
            return;
        }
    }
    return error.UnfinishedTestDdl;
}
pub fn create(store: *Store, sql: []const u8) !root.ReactiveModel.Source {
    var next = try turn(store);
    try catalog.initialize(&next);
    try store.commit(next);
    try store.setRights(.{ .principal = principal });
    var compiled = try f.TableDdl.compile(std.testing.allocator, sql, null, null);
    defer compiled.deinit();
    const command = compiled.statement.create;
    try ddl(store, .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init(command.name), .action = .{ .create = .{ .schema = try command.bind(100) } } });
    var source = try declaration(store);
    defer source.deinit();
    return root.ReactiveModel.Source.from(1, source.source);
}
pub fn declaration(store: *Store) !q.TableSource.Owned {
    var next = try turn(store);
    var definition = (try catalog.lookup(std.testing.allocator, &next, 17, try .init("items"))).?;
    defer definition.deinit();
    return q.TableSource.from(std.testing.allocator, configuration, definition);
}
pub fn mutate(store: *Store, sql: []const u8) !void {
    var next = try turn(store);
    var definition = (try catalog.lookup(std.testing.allocator, &next, 17, try .init("items"))).?;
    defer definition.deinit();
    var compiled = try f.TableDml.compile(std.testing.allocator, sql, "items", definition.schema.schema, null);
    defer compiled.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = store.input, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .plan = compiled.plan };
    for (0..4000) |_| {
        next = try turn(store);
        const result = try catalog.mutate(std.testing.allocator, &next, request);
        try store.commit(next);
        if (result.state != .building) {
            try std.testing.expectEqual(.applied, result.state);
            return;
        }
    }
    return error.UnfinishedTestDml;
}
pub fn delegate(store: *Store, peer: u64, requests: u64, limits: q.Bundle.Limits) !void {
    var next = try turn(store);
    try q.UnifiedCapture.setPolicy(&next, .{ .peer = peer, .requests = requests, .revision = 1, .allow = true, .limits = limits, .target = .{ .catalog = .{ .scope = configuration.scope, .owner = configuration.owner, .principal = principal } } });
    try store.commit(next);
}
pub const Reader = struct {
    turn: s.Turn,
    store: *Store,
    view: p.Growth.View,
    reads: ?*usize = null,
    mutate_at: ?usize = null,
    pub fn open(store: *Store) !Reader {
        const next = try store.capture();
        return .{ .store = store, .turn = next, .view = next.view };
    }
    pub fn authorizationSubject(self: *Reader, who: u64) !p.Authorization.Subject {
        return self.store.authorizationSubject(who);
    }
    pub fn requireAuthorization(self: *Reader, guard: p.Authorization.Guard) !p.Authorization.Verified {
        try self.check();
        return self.store.requireAuthorization(guard);
    }
    fn check(self: *Reader) !void {
        if (self.reads) |count| {
            count.* += 1;
            if (self.mutate_at == count.*) self.store.revision += 1;
        }
        if (self.store.denied) return error.AccessDenied;
        if (self.store.revision != self.view.revision) return error.StaleStateResource;
    }
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        try self.check();
        return self.turn.read(key);
    }
    pub fn page(self: *Reader, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
        try self.check();
        return self.turn.page(after);
    }
    pub fn entry(self: *Reader, key: p.Value) !?p.Growth.Entry {
        try self.check();
        return if (self.store.state.get(key)) |value| .{ .key = key, .value = value, .revision = self.store.revisions.get(key).? } else null;
    }
};
