//! Direct catalog and partition transitions with injected policy. Network/native
//! authentication and complete query capture are separate integration proofs.
const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const f = q.fuze;
const s = c.storage;
const p = root.protocol;
const D = c.DirectCatalog;
const P = s.TablePartition;
const w = c.DirectTableProtocol;
pub const principal = 65536;
pub const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 7, .catalog = 9 };
pub const profile: c.TableAuthority.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
pub const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 13, .principal = principal, .role = null };
const Access = struct {
    fn make(context: *anyopaque, _: std.mem.Allocator, guard: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try guard.validate();
        if (guard.subject.principal() != principal) return error.CatalogDenied;
        return .{ .context = context, .acquire = acquire, .release = release };
    }
    fn acquire(_: *anyopaque) !P.Guard.Fence {
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(_: *anyopaque, kind: c.TableAuthority.Kind, id: u64) !?p.Authorization.Object {
        return .{ .reference = c.TableAuthority.reference(switch (kind) {
            .database => 4,
            .schema => 5,
            .table => 1000 + id,
        }), .owner = 0, .registrar = principal, .actions = c.TableAuthority.actions(kind), .domain = profile.domain(kind), .binding = try c.TableAuthority.binding(scope, kind, id), .parent = switch (kind) {
            .database => null,
            .schema => c.TableAuthority.reference(4),
            .table => c.TableAuthority.reference(5),
        }, .revision = 1 };
    }
};
pub const Store = struct {
    wal: s.LocalWal.LocalWal = s.LocalWal.LocalWal.initMemory(t.allocator),
    objects: s.LocalSegmentStore.LocalSegmentStore = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator),
    catalog: D = undefined,
    initialized: bool = false,
    operation: u64 = 1,
    denied: bool = false,
    deny_at: usize = std.math.maxInt(usize),
    checks: usize = 0,
    pub fn policy(self: *Store) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = connection.audience, .input = 1, .principal = principal } }, .make_guard = Access.make, .registered = Access.registered };
    }
    pub fn init(self: *Store) !void {
        self.catalog = try D.init(t.allocator, .{ .scope = scope, .branch = 1, .partition = 1, .audience = connection.audience, .authority = profile, .database_name = try .init("main"), .initial_schema_name = try .init("public") }, self.wal.log(), self.objects.objectStore(), self.wal.log(), self.objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
        self.initialized = true;
        try self.catalog.recover();
        try self.catalog.initialize(self.policy());
    }
    pub fn deinit(self: *Store) void {
        if (self.initialized) self.catalog.deinit();
        self.objects.deinit();
        self.wal.deinit();
    }
    pub fn resolve(self: *Store) !D.View {
        return (try self.catalog.resolve(t.allocator, 1, try .init("items"), self.policy())).?;
    }
    pub fn next(self: *Store) u64 {
        defer self.operation += 1;
        return self.operation;
    }
};
pub fn metadata(allocator: std.mem.Allocator, view: *const D.View) !w.Definition {
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    return .{ .interpretation = view.table.root.declared(), .namespace = view.properties.namespace, .authorization = view.properties.authorization, .name = view.properties.name, .position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .changed_lsn = view.table.root.changed_lsn, .row_count = view.table.root.live_rows, .schema = try .encode(allocator, try view.table.declaration.schema.schema.encode(&bytes)) };
}
pub fn ddl(store: *Store, request: D.Request) !void {
    _ = try store.catalog.admit(request, store.policy());
    try t.expect((try store.catalog.perform(request.binding, store.policy())) == .committed);
    _ = try store.catalog.settle(request.binding, store.policy());
}
pub fn create(store: *Store, sql: []const u8) !root.ReactiveModel.Source {
    try store.init();
    var compiled = try f.TableDdl.compile(t.allocator, sql, null, null);
    defer compiled.deinit();
    const command = compiled.statement.create;
    const intent: D.Intent = .{ .namespace = 1, .name = try .init(command.name), .action = .{ .create = .{ .owner = 0, .schema = try command.bind(100) } } };
    try ddl(store, .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = principal, .operation = store.next() }, .target = .{ .scope = scope, .branch = 1, .object = 100 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) }, .intent = intent });
    var source = try declaration(store);
    defer source.deinit();
    return root.ReactiveModel.Source.from(1, source.source);
}
pub fn declaration(store: *Store) !q.TableSource.Owned {
    var view = try store.resolve();
    defer view.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    return q.TableSource.from(t.allocator, connection, try metadata(arena.allocator(), &view));
}
pub fn prepare(store: *Store, sql: []const u8) !c.DirectTableIntent {
    var view = try store.resolve();
    defer view.deinit();
    var compiled = try f.TableDml.compile(t.allocator, sql, "items", view.table.declaration.schema.schema, null);
    defer compiled.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    return c.DirectTableIntent.fromDml(t.allocator, connection, try metadata(arena.allocator(), &view), store.next(), compiled.plan, .point);
}
pub fn admit(store: *Store, intent: c.DirectTableIntent) !p.DataLifecycle.Binding {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const request = switch (intent.parsed.value.work) {
        .rows => |value| try value.native(arena.allocator()),
        .statement => |value| try value.native(arena.allocator()),
        else => unreachable,
    };
    _ = try store.catalog.admitRows(request, store.policy());
    return request.binding;
}
pub fn mutate(store: *Store, sql: []const u8) !void {
    var intent = try prepare(store, sql);
    defer intent.deinit();
    const binding = try admit(store, intent);
    try t.expect((try store.catalog.performRows(binding, store.policy())) == .committed);
}
pub fn alter(store: *Store, action: @FieldType(D.Intent, "action")) !void {
    var view = try store.resolve();
    defer view.deinit();
    const intent: D.Intent = .{ .namespace = 1, .name = view.properties.name, .action = action };
    try ddl(store, .{ .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = principal, .operation = store.next() }, .target = view.table.root.interpretation.object, .action = switch (action) {
        .alter => .alter,
        .rename => .rename,
        .drop => .drop,
        .create => unreachable,
    }, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = try intent.digest(t.allocator) }, .intent = intent });
}
pub const Reader = struct {
    store: *Store,
    caller: ?u64 = null,
    pub fn open(store: *Store) !Reader {
        return .{ .store = store };
    }
    pub fn requirements(self: *Reader, source: root.ReactiveModel.Source) !c.DirectReadAuthority {
        return self.store.catalog.currentReadAuthority(source.interpretation().object, self.store.policy());
    }
    pub fn check(self: *Reader, who: u64, authority: c.DirectReadAuthority) !void {
        try authority.validate();
        self.store.checks += 1;
        if (self.store.denied or self.store.checks >= self.store.deny_at or (who != principal and who != 17)) return error.CatalogDenied;
        self.caller = who;
    }
    pub fn finish(self: *Reader) !void {
        try self.check(self.caller orelse return error.CatalogDenied, .{ .database = 4, .schema = 5, .table = 1100 });
    }
    pub fn observe(self: *Reader, source: root.ReactiveModel.Source, limits: ?P.ReadLimits) !std.json.Parsed(w.Response) {
        var current = self.store.catalog.observe(t.allocator, source.namespace, source.interpretation(), limits, self.store.policy()) catch |err| return if (err == error.TableDefinitionChanged) error.ReactiveResetRequired else err;
        defer current.deinit();
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const page: ?w.CurrentPage = if (current.page) |*found| blk: {
            const rows = try allocator.alloc(w.Binary, found.count);
            const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
            for (rows, 0..) |*row, i| row.* = try .encode(allocator, try found.rows[i].?.row().encode(current.view.table.declaration.schema.schema, scratch));
            break :blk .{ .rows = rows, .encoded_bytes = found.encoded_bytes, .more = found.more };
        } else null;
        const response: w.Response = .{ .definition = p.Growth.current_definition, .context = @splat(1), .policy_revision = 1, .subject = .{ .principal = principal, .login_role = principal, .role = principal, .credential_epoch = 1, .audience = connection.audience, .context = @splat(1) }, .result = .{ .observation = .{ .definition = try metadata(allocator, &current.view), .authority = current.authority, .page = page } } };
        return p.Json.parseFromSliceOwned(w.Response, t.allocator, try p.Json.valueAlloc(allocator, response));
    }
};
