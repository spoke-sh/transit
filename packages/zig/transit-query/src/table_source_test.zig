const std = @import("std");
const e = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const c = q.catalog;
const s = q.station;
const Source = q.TableSource;
const Store = q.testing.Store;
const Cell = f.Types.Values.Cell;
const config: c.TableCatalogRecords.Configuration = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .administrator = 17, .table_limits = .{ .record_bytes = f.TableRow.max_bytes, .staging_bytes = f.TableRow.max_bytes * 2, .staging_records = 2 } };
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
    var original_cut = try altered.openVersion(retained);
    try e.expectError(error.CatalogDefinitionChanged, source.source.capture(e.allocator, &original_cut, &altered, 17));
    _ = try ddl(&store, .{ .principal = 17, .operation = 4, .object = 100, .expected_revision = 2, .name = try c.TableMetadata.Name.init("people"), .action = .{ .drop = .{} } });
    var replacement = old.schema.schema;
    replacement.object = 101;
    const created = try ddl(&store, .{ .principal = 17, .operation = 5, .object = 101, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = replacement } } });
    try e.expectEqual(.applied, created.operation.state);
    var current = try turn(&store);
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
    var denied = try c.TableCatalogRecords.Policy.administrator(config.scope, 17);
    denied.read = false;
    denied.revision = 2;
    try catalog.setPolicy(&current, 1, denied);
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
        var revoked = try c.TableCatalogRecords.Policy.administrator(config.scope, 17);
        revoked.read = false;
        const Live = struct {
            source: *s.Turn,
            view: q.protocol.Growth.View,
            denied: q.protocol.Value,
            policy_reads: usize = 0,
            pub fn read(self: *@This(), key: q.protocol.Value) !?q.protocol.Value {
                if (key.eql(catalog.key('p', 17, 0))) {
                    self.policy_reads += 1;
                    if (self.policy_reads > 2) return self.denied;
                }
                return self.source.read(key);
            }
        };
        var live: Live = .{ .source = &current, .view = current.view, .denied = try c.Records.encode('P', revoked) };
        // Permission disappears after the initial gate. Both a populated page
        // and empty point completion must fail before exposing owned output.
        try e.expectError(error.CatalogDenied, source.source.page(e.allocator, basis, try Source.Cursor.start(basis), compiled.plan, &current, &live, 17));
        try e.expectEqual(@as(usize, 4), live.policy_reads);
    }
}
