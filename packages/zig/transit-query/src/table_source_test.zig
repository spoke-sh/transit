const std = @import("std");
const e = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const c = q.catalog;
const s = q.station;
const Source = q.TableSource;
const Store = q.testing.Store;
const Cell = f.Types.Values.Cell;
const config: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .authority = c.testing.Authority.profile, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 } };
const catalog: c.TableCatalog = .{ .configuration = config };
fn turn(store: *Store) !s.Turn {
    var result = try store.capture();
    result.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    return result;
}
fn ddl(store: *Store, request: c.TableDdlRequest) !c.TableCatalog.Outcome {
    for (0..4000) |_| {
        var next = try turn(store);
        const result = try catalog.step(e.allocator, &next, request);
        try store.commit(next);
        if (result.terminal()) return result;
    }
    return error.UnfinishedTestDdl;
}
fn create(store: *Store, sql: []const u8) !void {
    var next = try turn(store);
    try catalog.initialize(&next);
    try store.commit(next);
    var compiled = try f.TableDdl.compile(e.allocator, sql, null, null);
    defer compiled.deinit();
    const statement = compiled.statement.create;
    const result = try ddl(store, .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init(statement.name), .action = .{ .create = .{ .schema = try statement.bind(100) } } });
    try e.expectEqual(.applied, result.operation.state);
}
fn definition(store: *Store) !c.TableCatalog.Definition {
    var next = try turn(store);
    return (try catalog.lookup(e.allocator, &next, 17, try c.TableMetadata.Name.init("people"))).?;
}
fn insert(store: *Store, schema: f.TableSchema.Schema, metadata: s.TablePages.Reference, rows: []const []const Cell) !void {
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = metadata, .plan = .{ .name = "people", .schema = schema, .action = .{ .insert = rows } } };
    for (0..4000) |_| {
        var next = try turn(store);
        const status = try catalog.mutate(e.allocator, &next, request);
        try store.commit(next);
        if (status.state != .building) {
            try e.expectEqual(.applied, status.state);
            return;
        }
    }
    return error.UnfinishedTestInsert;
}
fn restore(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var owned = try Source.decode(allocator, bytes);
    defer owned.deinit();
    var buffer: [Source.max_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, bytes, try owned.source.encode(&buffer));
}
fn pageFault(allocator: std.mem.Allocator, source: Source, basis: Source.Basis, plan: f.LogicalQuery.Plan, current: *s.Turn) !void {
    var page = try source.page(allocator, basis, try Source.Cursor.start(basis), plan, current, current, 17);
    defer page.deinit();
    try e.expectEqual(@as(u8, 1), page.count);
    try e.expectEqual(@as(i128, 11), page.engine().rows[0].cells[0].value.atom.signed);
}
test "general Table source bytes and fingerprint match an independent recursive fixture" {
    const fixture = try std.json.parseFromSlice(struct { wire_hex: []const u8, fingerprint_hex: []const u8 }, e.allocator, @embedFile("fixtures/table-source.json"), .{});
    defer fixture.deinit();
    var buffer: [Source.max_bytes]u8 = undefined;
    const bytes = try std.fmt.hexToBytes(&buffer, fixture.value.wire_hex);
    var owned = try Source.decode(e.allocator, bytes);
    defer owned.deinit();
    try e.expectEqual(std.math.maxInt(u64), owned.source.object);
    try e.expectEqual(std.math.maxInt(u64), owned.source.scope.catalog);
    try e.expectEqual(.int128, owned.source.row_type.structure[0].type);
    try e.expectEqual(.int32, owned.source.row_type.structure[1].type.map.value.type.list.type.*);
    var fingerprint: [32]u8 = undefined;
    try e.expectEqualSlices(u8, try std.fmt.hexToBytes(&fingerprint, fixture.value.fingerprint_hex), &try owned.source.fingerprint());
    try restore(e.allocator, bytes);
}
test "general Table declaration owns recursive schema and rejects foreign incomplete definitions" {
    var store: Store = .{};
    defer store.deinit();
    try create(&store, "CREATE TABLE people (id INTEGER PRIMARY KEY, names LIST(UTF8))");
    var found = try definition(&store);
    var owned = try Source.from(e.allocator, config, found);
    defer owned.deinit();
    found.deinit();
    try e.expectEqualStrings("names", owned.source.row_type.structure[1].name);
    var buffer: [Source.max_bytes]u8 = undefined;
    const bytes = try owned.source.encode(&buffer);
    try e.checkAllAllocationFailures(e.allocator, restore, .{bytes});
    for (0..bytes.len) |length| {
        if (Source.decode(e.allocator, bytes[0..length])) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.AcceptedTruncatedSource;
        } else |_| {}
    }
    buffer[4] ^= 1;
    try e.expectError(error.IncompatibleDefinition, Source.decode(e.allocator, bytes));
    buffer[4] ^= 1;
    var restored = try Source.decode(e.allocator, bytes);
    defer restored.deinit();
    @memset(&buffer, 0);
    try e.expectEqualDeep(owned.source, restored.source);
}
const wide_sql = "CREATE TABLE people (id INTEGER NOT NULL, tag TEXT NOT NULL, names LIST(UTF8), a INT128, b INT128, c INT128, d INT128, e INT128, f INT128, g INT128, h INT128, i INT128, j INT128, PRIMARY KEY (id, tag))";
fn wide(store: *Store) !Source.Owned {
    try create(store, wide_sql);
    var found = try definition(store);
    defer found.deinit();
    var source = try Source.from(e.allocator, config, found);
    errdefer source.deinit();
    var cells: [19][13]Cell = undefined;
    var rows: [19][]const Cell = undefined;
    for (&cells, &rows, 0..) |*row, *slice, i| {
        row[0] = .{ .value = .{ .atom = .{ .signed = @intCast(i) } } };
        row[1] = .{ .value = .{ .atom = .{ .bytes = "東京" } } };
        row[2] = .{ .value = .{ .list = &.{.{ .value = .{ .atom = .{ .bytes = "Ada" } } }} } };
        for (row[3..]) |*cell| cell.* = .{ .value = .{ .atom = .{ .signed = std.math.maxInt(i128) } } };
        slice.* = row;
    }
    try insert(store, found.schema.schema, source.source.metadata, &rows);
    return source;
}
test "retained general Table pages preserve wide nested rows through ALTER DROP and name reuse" {
    var store: Store = .{};
    defer store.deinit();
    var source = try wide(&store);
    defer source.deinit();
    var captured = try turn(&store);
    const basis = try source.source.capture(e.allocator, &captured, &captured, 17);
    const retained = try captured.retain();
    try store.commit(captured);
    var old = try definition(&store);
    defer old.deinit();
    const rename = try ddl(&store, .{ .principal = 17, .operation = 3, .object = 100, .expected_revision = 1, .name = try c.TableMetadata.Name.init("people"), .action = .{ .alter = .{ .schema = old.schema.schema, .change = .{ .rename = .{ .column = 3, .name = "names_now" } } } } });
    try e.expectEqual(.applied, rename.table.?.state);
    var altered = try turn(&store);
    _ = try source.source.checkCurrent(&altered, 17);
    try e.expectError(error.CatalogDefinitionChanged, source.source.checkDefinition(e.allocator, &altered, 17));
    var original_cut = try altered.openVersion(retained);
    try e.expectError(error.CatalogDefinitionChanged, source.source.capture(e.allocator, &original_cut, &altered, 17));
    _ = try ddl(&store, .{ .principal = 17, .operation = 4, .object = 100, .expected_revision = 2, .name = try c.TableMetadata.Name.init("people"), .action = .{ .drop = .{} } });
    var replacement = old.schema.schema;
    replacement.object = 101;
    const created = try ddl(&store, .{ .principal = 17, .operation = 5, .object = 101, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = replacement } } });
    try e.expectEqual(.applied, created.operation.state);
    var current = try turn(&store);
    _ = try source.source.checkCurrent(&current, 17);
    try e.expectError(error.TableRetired, source.source.checkDefinition(e.allocator, &current, 17));
    try e.expectError(error.TableRetired, source.source.capture(e.allocator, &current, &current, 17));
    var data = try current.openVersion(retained);
    var compiled = try f.TableSelect.compile(e.allocator, "SELECT id, tag, names, j FROM people", "people", source.source.row_type, try basis.fingerprint(), null);
    defer compiled.deinit();
    var cursor = try Source.Cursor.start(basis);
    var progress = try f.LogicalStream.Progress.start(compiled.plan);
    const workspace = try e.allocator.alloc(u8, f.LogicalArrow.working_bytes);
    defer e.allocator.free(workspace);
    var bytes: [f.LogicalArrow.segment_bytes]u8 = undefined;
    const cancel = std.atomic.Value(bool).init(false);
    var observed: i128 = 0;
    while (true) {
        var page = try source.source.page(e.allocator, basis, cursor, compiled.plan, &data, &current, 17);
        defer page.deinit();
        const next = try f.LogicalStream.step(compiled.plan, progress, page.engine(), workspace, &bytes, &cancel, null);
        const part = next.segment.?;
        var fields: [128]f.Types.Field = undefined;
        var output = try f.LogicalInspect.decode(e.allocator, try compiled.plan.outputSchema(&fields), part.bytes, part.rows, workspace);
        defer output.deinit();
        for (output.rows) |row| {
            try e.expectEqual(observed, row.cells[0].value.atom.signed);
            try e.expectEqualStrings("東京", row.cells[1].value.atom.bytes);
            try e.expectEqualStrings("Ada", row.cells[2].value.list[0].value.atom.bytes);
            try e.expectEqual(std.math.maxInt(i128), row.cells[3].value.atom.signed);
            observed += 1;
        }
        cursor = page.next;
        progress = next.progress;
        if (cursor.done) break;
    }
    try e.expectEqual(@as(i128, 19), observed);
    try e.expectEqual(@as(u64, 3), cursor.ordinal);
    try e.expectEqual(.source_end, progress.finished.?);
    var denied = try c.testing.Authority.Rights.administrator(config.scope, 17);
    denied.read = false;
    denied.revision = 2;
    try store.setRights(denied);
    try store.commit(current);
    current = try turn(&store);
    data = try current.openVersion(retained);
    try e.expectError(error.CatalogDenied, source.source.page(e.allocator, basis, try Source.Cursor.start(basis), compiled.plan, &data, &current, 17));
}
test "complete composite key predicates seek one row and still bind the captured plan" {
    var store: Store = .{};
    defer store.deinit();
    var source = try wide(&store);
    defer source.deinit();
    var current = try turn(&store);
    const basis = try source.source.capture(e.allocator, &current, &current, 17);
    for ([_][]const u8{ "SELECT names FROM people WHERE id = 11 AND tag = '東京'", "SELECT names FROM people WHERE id = 99 AND tag = '東京'" }, 0..) |sql, i| {
        var compiled = try f.TableSelect.compile(e.allocator, sql, "people", source.source.row_type, try basis.fingerprint(), null);
        defer compiled.deinit();
        var page = try source.source.page(e.allocator, basis, try Source.Cursor.start(basis), compiled.plan, &current, &current, 17);
        defer page.deinit();
        try e.expectEqual(@as(u8, @intFromBool(i == 0)), page.count);
        try e.expect(page.next.done);
        try e.expectEqual(@as(u64, 1), page.next.ordinal);
        if (i == 0) {
            try e.expectEqual(@as(i128, 11), page.engine().rows[0].cells[0].value.atom.signed);
            try e.checkAllAllocationFailures(e.allocator, pageFault, .{ source.source, basis, compiled.plan, &current });
        }
        var changed = basis;
        changed.revision += 1;
        try e.expectError(error.SourceChanged, source.source.page(e.allocator, changed, try Source.Cursor.start(basis), compiled.plan, &current, &current, 17));
        const Live = struct {
            source: *s.Turn,
            view: q.protocol.Growth.View,
            checks: usize = 0,
            pub fn read(self: *@This(), key: q.protocol.Value) !?q.protocol.Value {
                return self.source.read(key);
            }
            pub fn authorizationSubject(self: *@This(), who: u64) !q.protocol.Authorization.Subject {
                return self.source.authorizationSubject(who);
            }
            pub fn requireAuthorization(self: *@This(), guard: q.protocol.Authorization.Guard) !q.protocol.Authorization.Verified {
                for (guard.requirements) |slot| if (slot) |requirement| {
                    if (requirement.object.id != c.testing.Authority.profile.database and requirement.object.id != c.testing.Authority.profile.initial_schema_authority and requirement.privileges == c.TableAuthority.select) {
                        self.checks += 1;
                        if (self.checks == 2) return error.AccessDenied;
                    }
                };
                return self.source.requireAuthorization(guard);
            }
        };
        var live: Live = .{ .source = &current, .view = current.view };
        // Permission disappears after the initial gate. Both a populated page
        // and empty point completion must fail before exposing owned output.
        try e.expectError(error.CatalogDenied, source.source.page(e.allocator, basis, try Source.Cursor.start(basis), compiled.plan, &current, &live, 17));
        try e.expectEqual(@as(usize, 2), live.checks);
    }
}

test "one committed requester policy delegates multiple Tables and still requires current catalog rights" {
    var store: Store = .{};
    defer store.deinit();
    try create(&store, "CREATE TABLE people (id INTEGER, name UTF8)");
    var found = try definition(&store);
    defer found.deinit();
    var people = try Source.from(e.allocator, config, found);
    defer people.deinit();
    const grant: q.UnifiedRecords.Policy = .{ .peer = 9, .requests = 8, .revision = 1, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } }, .allow = true, .limits = .{ .pages = 100, .segments = 200, .result_bytes = 1048576 } };
    var current = try turn(&store);
    inline for (.{ "realm", "resource" }) |field| {
        var foreign = grant;
        @field(foreign.target.catalog.scope, field) += 1;
        try e.expectError(error.InvalidQueryPolicy, q.UnifiedCapture.setPolicy(&current, foreign));
    }
    var foreign_owner = grant;
    foreign_owner.target.catalog.owner += 1;
    try e.expectError(error.InvalidQueryPolicy, q.UnifiedCapture.setPolicy(&current, foreign_owner));
    try q.UnifiedCapture.setPolicy(&current, grant);
    try store.commit(current);
    current = try turn(&store);
    try e.expect((try q.UnifiedCapture.policy(&current, 17)) == null);
    const admitted = (try q.UnifiedCapture.policy(&current, 9)).?;
    const who = try admitted.tablePrincipal(people.source);
    try e.expectEqual(@as(u64, 17), who);
    try e.expectError(error.CatalogDenied, people.source.checkCurrent(&current, admitted.peer));
    _ = try people.source.capture(e.allocator, &current, &current, who);

    var compiled = try f.TableDdl.compile(e.allocator, "CREATE TABLE places (city UTF8)", null, null);
    defer compiled.deinit();
    const created = try ddl(&store, .{ .principal = 17, .operation = 3, .object = 101, .expected_revision = 0, .name = try c.TableMetadata.Name.init("places"), .action = .{ .create = .{ .schema = try compiled.statement.create.bind(101) } } });
    try e.expectEqual(.applied, created.operation.state);
    current = try turn(&store);
    var next = (try catalog.lookup(e.allocator, &current, who, try c.TableMetadata.Name.init("places"))).?;
    defer next.deinit();
    var places = try Source.from(e.allocator, config, next);
    defer places.deinit();
    try e.expectEqualDeep(admitted, (try q.UnifiedCapture.policy(&current, 9)).?);
    _ = try places.source.capture(e.allocator, &current, &current, try admitted.tablePrincipal(places.source));
    inline for (.{ "realm", "resource", "catalog" }) |field| {
        var changed = places.source;
        @field(changed.scope, field) += 1;
        try e.expectError(error.QueryDenied, admitted.tablePrincipal(changed));
    }
    var changed = places.source;
    changed.owner += 1;
    try e.expectError(error.QueryDenied, admitted.tablePrincipal(changed));
    var disabled = admitted;
    disabled.allow = false;
    try e.expectError(error.QueryDenied, disabled.tablePrincipal(places.source));
    disabled = admitted;
    disabled.target = .{ .declaration = try places.source.fingerprint() };
    try e.expectError(error.QueryDenied, disabled.tablePrincipal(places.source));
    // A changed mapping cannot reuse an admitted policy revision.
    var remapped = admitted;
    remapped.target.catalog.principal = 18;
    try e.expectError(error.StaleQueryPolicy, q.UnifiedCapture.setPolicy(&current, remapped));
    var denied = try c.testing.Authority.Rights.administrator(config.scope, who);
    denied.revision = 2;
    denied.read = false;
    try store.setRights(denied);
    try store.commit(current);
    current = try turn(&store);
    const unchanged = (try q.UnifiedCapture.policy(&current, 9)).?;
    try e.expectEqualDeep(admitted, unchanged);
    try e.expectError(error.CatalogDenied, places.source.checkCurrent(&current, try unchanged.tablePrincipal(places.source)));
}

fn embeddedRequest(allocator: std.mem.Allocator, declaration: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var source_bytes: [Source.max_bytes]u8 = undefined;
    @memcpy(source_bytes[0..declaration.len], declaration);
    const source = try Source.decodeInto(a, source_bytes[0..declaration.len]);
    @memset(&source_bytes, 0);
    const schema = try source.row_type.cloneInto(a);
    const plan: f.LogicalQuery.Plan = .{ .schema = schema, .source_basis = try source.fingerprint(), .projection = &.{ 0, 1 }, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .signed = std.math.minInt(i128) } } } };
    var plan_bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    const restored = try f.LogicalPlanCodec.decodeInto(a, schema, plan.source_basis, try f.LogicalPlanCodec.encode(plan, &plan_bytes));
    @memset(&plan_bytes, 0);
    try e.expectEqualStrings("payload", restored.schema.structure[1].name);
    try e.expectEqual(std.math.minInt(i128), restored.predicate.compare.value.signed);
    try e.expectEqualSlices(u8, &try plan.fingerprint(), &try restored.fingerprint());
    var cell_bytes: [64]u8 = undefined;
    const field: f.Types.Field = .{ .name = "parameter", .type = .utf8 };
    const bytes = try f.Types.Codec.encodeBound(.{ .value = .{ .atom = .{ .bytes = "東京" } } }, field, &cell_bytes);
    const cell = try f.Types.Codec.decodeBoundInto(a, field, bytes);
    @memset(&cell_bytes, 0);
    try e.expectEqualStrings("東京", cell.value.atom.bytes);
}
test "embedded source plan and literal decoding share one request arena with exact failure cleanup" {
    const fixture = try std.json.parseFromSlice(struct { wire_hex: []const u8, fingerprint_hex: []const u8 }, e.allocator, @embedFile("fixtures/table-source.json"), .{});
    defer fixture.deinit();
    var bytes: [Source.max_bytes]u8 = undefined;
    const declaration = try std.fmt.hexToBytes(&bytes, fixture.value.wire_hex);
    try embeddedRequest(e.allocator, declaration);
    try e.checkAllAllocationFailures(e.allocator, embeddedRequest, .{declaration});
    var empty: std.heap.FixedBufferAllocator = .init(&.{});
    bytes[4] ^= 1;
    try e.expectError(error.IncompatibleDefinition, Source.decodeInto(empty.allocator(), declaration));
}

test "interactive metadata cannot authenticate a configured principal as its caller" {
    var store: Store = .{};
    defer store.deinit();
    try create(&store, "CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT)");
    var found = try definition(&store);
    defer found.deinit();
    var owned = try Source.from(e.allocator, config, found);
    defer owned.deinit();
    const source: q.SourceDefinition = .{ .resource = config.scope.resource, .source = .{ .table = owned.source } };
    var client: q.UnifiedClient = .{ .wire = undefined, .key = undefined, .connection = .{ .realm = 1, .principal = 23, .source = config.owner, .resource = config.scope.resource, .requester = 8, .requests = 10 } };
    const g = q.protocol.Growth;
    const p = q.protocol;
    var requests: [g.SnapshotRead.current_resources]?g.SnapshotRead.Current = .{ .{ .resource = 7, .keys = @splat(null) }, .{ .resource = 10, .keys = @splat(null) } };
    requests[0].?.keys[0] = q.UnifiedRecords.key('p', 8, 0);
    requests[0].?.keys[1] = c.Records.key(config.scope.catalog, 'c', 0, 0);
    requests[1].?.keys[0] = q.UnifiedRecords.key('w', 0, 0);
    var current = try turn(&store);
    var grant: q.UnifiedRecords.Policy = .{ .peer = 8, .requests = 10, .revision = 1, .allow = true, .limits = .{ .pages = 8, .segments = 8, .result_bytes = 65536 }, .target = .{ .catalog = .{ .scope = config.scope, .owner = config.owner, .principal = 17 } } };
    var result: g.SnapshotRead.Result = .{ .snapshot = undefined, .current = .{ .{ .resource = .{ .id = 7, .writer = config.owner, .owner = null, .revision = current.view.revision, .deadline_ms = null }, .entries = @splat(null) }, .{ .resource = .{ .id = 10, .writer = 8, .owner = null, .revision = 1, .deadline_ms = null }, .entries = @splat(null) } } };
    for (requests[0].?.keys, 0..) |key, i| if (key) |address| {
        result.current[0].?.entries[i] = .{ .key = address, .value = if (i == 0) try grant.encode() else (try current.read(address)).?, .revision = current.view.revision };
    };
    var requester: [20]u8 = undefined;
    requester[0..4].* = "UQH1".*;
    std.mem.writeInt(u64, requester[4..12], 23, .little);
    std.mem.writeInt(u64, requester[12..20], config.owner, .little);
    result.current[1].?.entries[0] = .{ .key = requests[1].?.keys[0].?, .value = try p.Value.init(&requester), .revision = 1 };
    // Even an allowed native requester policy is not the caller's Table
    // identity. Rejection precedes any credential or network access.
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
    grant.target.catalog.principal = 42;
    result.current[0].?.entries[0].?.value = try grant.encode();
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
    grant.target.catalog.principal = 17;
    grant.allow = false;
    result.current[0].?.entries[0].?.value = try grant.encode();
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
}
