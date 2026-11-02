//! Real signed managed computation over disk-backed catalog/Table/KV owners.
const std = @import("std");
const t = std.testing;
const q = @import("transit_query").direct;
const c = q.catalog;
const M = q.ManagedTable;
const options: q.DirectRelationalQuery.Options = .{
    .consistency = .independent_table_snapshots,
    .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 100000, .source_pins = 1 },
    .requests = 10000,
    .spill_work = 10000,
};
fn ddl(client: c.DirectTableClient, text: []const u8, operation: u64, object: u64) !void {
    var prepared = try c.DirectTablePreparedDdl.prepare(client.allocator, client, 1, text, .transit, null);
    defer prepared.deinit();
    var work = try prepared.bind(client.allocator, client, operation, object);
    defer work.deinit();
    (try work.table.admit(client)).deinit();
    const result = try work.table.operation(client, .execute, 64);
    defer result.deinit();
    try t.expect(result.value.result.ddl == .committed);
}
fn dml(client: c.DirectTableClient, text: []const u8, operation: u64) !void {
    var prepared = try c.DirectTablePreparedDml.prepare(client.allocator, client, 1, text, .transit, null);
    defer prepared.deinit();
    var work = try prepared.bind(client.allocator, client, operation, &.{}, .bulk, null);
    defer work.deinit();
    (try work.admit(client)).deinit();
    const result = try work.operation(client, .execute, 64);
    defer result.deinit();
    try t.expect(result.value.result.rows == .committed);
}
fn control(manager: M, declaration: M.Declaration, command: c.protocol.Dataflow.Command, identity: u64) !void {
    const previous = try manager.inspect(declaration);
    const saved = try manager.prepareControl(declaration, .{ .definition = c.protocol.Growth.current_definition, .operation = .{ .scope = manager.client.connection.scope, .principal = manager.client.connection.principal, .operation = identity }, .target = try declaration.interpretation(manager.client.allocator), .expected = previous.head.control, .command = command });
    defer manager.client.allocator.free(saved);
    const first = try manager.applyControl(saved);
    try t.expectEqualDeep(first, try manager.applyControl(saved));
}
fn pendingWork(manager: M, declaration: M.Declaration) !?c.DirectClientToken.Key {
    var after: ?u64 = null;
    while (true) {
        const page = try c.DirectClientToken.list(manager.client, M.workAccount(), after, true);
        for (page.entries) |slot| if (slot) |entry| {
            const work = try manager.load(M.Work, entry.record orelse entry.receipt.binding.intent.external.record, M.work_format);
            defer work.deinit();
            if (std.meta.eql(work.value.lease.target, try declaration.interpretation(manager.client.allocator))) return entry.receipt.binding.key;
        };
        after = page.next orelse return null;
    }
}
fn drain(manager: M, declaration: M.Declaration, io: std.Io, directory: std.Io.Dir) !void {
    const pending = (try pendingWork(manager, declaration)) orelse (try manager.start(declaration)) orelse return;
    for (0..1000) |_| if (!try manager.step(pending, io, directory, null)) return;
    return error.ManagedTableDidNotSettle;
}
fn count(client: c.DirectTableClient, expected: u64) !void {
    const result = try client.call(.{ .lookup = .{ .namespace = 1, .name = "managed_output" } });
    defer result.deinit();
    const metadata = result.value.result.lookup.?;
    try t.expectEqual(expected, metadata.row_count);
    var random: [8]u8 = undefined;
    try client.service.http.io.randomSecure(&random);
    const owner: c.protocol.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = (std.mem.readInt(u64, &random, .little) % c.protocol.max_counter) + 1 };
    const handle = if (client.call(.{ .pin = .{ .object = metadata.interpretation.interpretation.object, .owner = owner, .expected = metadata.position } })) |pinned| blk: {
        defer pinned.deinit();
        break :blk pinned.value.result.pin;
    } else |err| blk: {
        // The shared proxy deliberately loses the first pin reply. Observe its
        // original owner; never acquire a replacement cut to hide uncertainty.
        if (err != error.InvalidTableResponse) return err;
        const recovered = try client.call(.{ .pin_status = .{ .object = metadata.interpretation.interpretation.object, .owner = owner } });
        defer recovered.deinit();
        try t.expect(!recovered.value.result.pin_state.released);
        break :blk recovered.value.result.pin_state.handle orelse return error.MissingOriginalPin;
    };
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = metadata.interpretation.interpretation.object, .handle = handle };
    defer (client.call(.{ .release = snapshot }) catch unreachable).deinit();
    var query = try q.DirectTableQuery.openRetained(client.allocator, client, snapshot, "managed_output", "SELECT id FROM managed_output", .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer query.deinit();
    var batch = try query.nextBatch(8);
    defer batch.deinit();
    try t.expect(batch.complete);
    try t.expectEqual(expected, batch.len);
    var values: [4]i64 = undefined;
    for (batch.rows[0..batch.len], values[0..batch.len]) |row, *value| value.* = @intCast(row.?.cells[0].value.atom.signed);
    std.mem.sort(i64, values[0..batch.len], {}, std.sort.asc(i64));
    for (values[0..batch.len], 1..) |value, want| try t.expectEqual(@as(i64, @intCast(want)), value);
}
fn retained(manager: M, declaration: M.Declaration, revision: u64, expected: []const i64) !void {
    var reader = try q.ManagedRevision.open(manager, declaration, revision, .{});
    defer reader.deinit();
    try t.expectEqual(expected.len, reader.manifest.value.metadata.rows);
    try t.expectEqual(revision, reader.manifest.value.metadata.revision);
    try t.expectEqual(.committed, reader.decision.outcome);
    try t.expect(!reader.complete);
    var output: std.heap.ArenaAllocator = .init(manager.client.allocator);
    defer output.deinit();
    var values: [4]i64 = undefined;
    var count_: usize = 0;
    var first: ?q.fuze.TableRow.Row = null;
    while (try reader.next(&output)) |row| {
        try t.expect(count_ < values.len);
        values[count_] = @intCast(row.cells[0].value.atom.signed);
        if (first == null) first = row;
        count_ += 1;
        // Rows in caller output survive subsequent internal scratch resets.
        try t.expectEqual(values[0], first.?.cells[0].value.atom.signed);
    }
    try t.expect(reader.complete);
    try t.expect(try reader.next(&output) == null);
    std.mem.sort(i64, values[0..count_], {}, std.sort.asc(i64));
    try t.expectEqualSlices(i64, expected, values[0..count_]);
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    try ddl(client, "CREATE TABLE managed_input (id BIGINT PRIMARY KEY)", 652001, 652010);
    try ddl(client, "CREATE TABLE managed_output (id BIGINT PRIMARY KEY)", 652002, 652020);
    try dml(client, "INSERT INTO managed_input (id) VALUES (1), (2), (3)", 652003);
    const manager: M = .{ .client = client };
    const declaration = try manager.prepare(1, "managed_projection", 650000, 652004, "managed_output", "SELECT id FROM managed_input", options);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try c.protocol.Json.valueAlloc(init.arena.allocator(), declaration) });
    const published = try manager.publish(declaration);
    try t.expectEqual(.published, published.head.control.state);
    try t.expectEqual(@as(u64, 0), published.head.revision);
    const inspection = try client.call(.{ .managed_inspection = .{ .namespace = 1, .name = declaration.name, .expected = null, .revision = null } });
    defer inspection.deinit();
    try t.expect(inspection.value.result.managed_inspection.completed == null);
    try t.expectEqualDeep(published, inspection.value.result.managed_inspection.observation.?);
    _ = try manager.publish(declaration);
    var conflict = declaration;
    conflict.operation.operation = 652020;
    try t.expectError(error.ManagedTableNameConflict, manager.publish(conflict));
    var invalid = declaration;
    invalid.name = try .init("invalid_budget");
    invalid.object.object = 650002;
    invalid.operation.operation = 652021;
    invalid.options.requests = 0;
    try t.expectError(error.InvalidQueryBudget, manager.publish(invalid));
    invalid.options.requests = options.requests;
    invalid.options.budgets.output_rows = std.math.maxInt(u64);
    try t.expectError(error.InvalidQueryBudget, manager.publish(invalid));
    try t.expect(try c.DirectClientToken.lookup(client, manager.nameKey(invalid.namespace, invalid.name)) == null);
    try control(manager, declaration, .authorize, 652005);
    try control(manager, declaration, .activate, 652006);
    try count(client, 0);
    try t.expectError(error.DataflowRevisionNotFound, q.ManagedRevision.open(manager, declaration, 1, .{}));
    const pending = (try manager.start(declaration)).?;
    try t.expect(try manager.step(pending, init.io, .cwd(), null)); // Acquire.
    try t.expectError(error.AuthorityUnavailable, manager.step(pending, init.io, .cwd(), null));
    try t.expectEqualDeep(pending, (try pendingWork(manager, declaration)).?);
    try count(client, 0);
    // Leave a real accepted common transaction and private staged rows for the
    // replacement process, while fresh readers still see the old complete output.
    for (0..5) |_| try t.expect(try manager.step(pending, init.io, .cwd(), null));
    try count(client, 0);
    // Advance one participant per unit until preparation blocks ordinary head
    // reads. Replacement must discover the saved work independently of that head.
    for (0..40) |_| {
        try t.expect(try manager.step(pending, init.io, .cwd(), null));
        _ = manager.inspect(declaration) catch |err| {
            try t.expectEqual(error.Conflict, err);
            try t.expectEqualDeep(pending, (try pendingWork(manager, declaration)).?);
            return;
        };
    }
    return error.PreparedHeadWasNotBlocked;
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(M.max_definition_bytes));
    const parsed = try c.protocol.Json.parseFromSlice(M.Declaration, init.gpa, bytes);
    defer parsed.deinit();
    const declaration = parsed.value;
    const manager: M = .{ .client = client };
    try drain(manager, declaration, init.io, .cwd());
    try count(client, 3);
    try t.expectEqual(@as(u64, 1), (try manager.inspect(declaration)).head.revision);
    try t.expect(try manager.start(declaration) == null);
    try dml(client, "INSERT INTO managed_input (id) VALUES (4)", 652007);
    const pending = (try manager.start(declaration)).?;
    try t.expect(try manager.step(pending, init.io, .cwd(), null));
    try control(manager, declaration, .suspend_computation, 652008);
    try control(manager, declaration, .resume_computation, 652009);
    for (0..20) |_| {
        if (!try manager.step(pending, init.io, .cwd(), null)) break;
    }
    try count(client, 3);
    const resumed = try manager.inspect(declaration);
    try t.expectEqual(.active, resumed.head.control.state);
    try t.expectEqual(.none, resumed.head.blocked);
    try drain(manager, declaration, init.io, .cwd());
    try count(client, 4);
    try t.expectEqual(@as(u64, 2), (try manager.inspect(declaration)).head.revision);
    try retained(manager, declaration, 1, &.{ 1, 2, 3 });
    try retained(manager, declaration, 2, &.{ 1, 2, 3, 4 });
    const before_race = try manager.inspect(declaration);
    const stale = try manager.prepareControl(declaration, .{ .definition = c.protocol.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 652013 }, .target = try declaration.interpretation(client.allocator), .expected = before_race.head.control, .command = .refresh });
    defer client.allocator.free(stale);
    try control(manager, declaration, .suspend_computation, 652014);
    // A frozen control cannot be silently rebound to a newer head. The caller
    // settles it only after newer-head and original-receipt observations.
    try t.expectError(error.ManagedTableConflict, manager.applyControl(stale));
    try control(manager, declaration, .resume_computation, 652015);
    try control(manager, declaration, .refresh, 652011);
    try drain(manager, declaration, init.io, .cwd());
    try t.expectEqual(@as(u64, 3), (try manager.inspect(declaration)).head.revision);
    try dml(client, "DELETE FROM managed_input", 652026);
    try drain(manager, declaration, init.io, .cwd());
    try retained(manager, declaration, 4, &.{});
    try dml(client, "INSERT INTO managed_input (id) VALUES (1),(2),(3),(4)", 652027);
    try drain(manager, declaration, init.io, .cwd());
    try retained(manager, declaration, 1, &.{ 1, 2, 3 });
    const cycle = try manager.prepare(1, "managed_cycle", 650001, 652016, "managed_input", "SELECT id FROM managed_output", options);
    try t.expectError(error.DataflowSourceChanged, manager.publish(cycle));
    try t.expectEqual(.source_changed, (try manager.inspect(cycle)).head.blocked);
    try t.expectError(error.DataflowSourceChanged, manager.publish(cycle));
    try control(manager, cycle, .retire, 652017);
    try t.expect(try manager.start(cycle) == null);
    try control(manager, declaration, .retire, 652012);
    try t.expect(try manager.start(declaration) == null);
    try count(client, 4);
    // Executor refusal must close the original attempt without publishing an
    // incomplete prefix or replacing the previous complete output.
    var bounded = options;
    bounded.budgets.output_rows = 2;
    const limited = try manager.prepare(1, "managed_budget", 650003, 652022, "managed_output", "SELECT id FROM managed_input", bounded);
    _ = try manager.publish(limited);
    try control(manager, limited, .authorize, 652023);
    try control(manager, limited, .activate, 652024);
    try drain(manager, limited, init.io, .cwd());
    try t.expect(try manager.start(limited) == null);
    const refusal = try manager.inspect(limited);
    try t.expectEqual(.budget, refusal.head.blocked);
    try t.expectEqual(@as(u64, 0), refusal.head.revision);
    try t.expect(refusal.head.pending == null);
    try count(client, 4);
    try control(manager, limited, .retire, 652025);
    try t.expect(try manager.start(limited) == null);
    try dml(client, "DELETE FROM managed_output", 652028);
    try retained(manager, declaration, 1, &.{ 1, 2, 3 });
    try retained(manager, declaration, 2, &.{ 1, 2, 3, 4 });
    try retained(manager, declaration, 4, &.{});
}

pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8, admin: anytype, role: u64) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(M.max_definition_bytes));
    const declaration = try c.protocol.Json.parseFromSlice(M.Declaration, init.gpa, bytes);
    defer declaration.deinit();
    const manager: M = .{ .client = client };
    // No scheduler or source snapshot is needed after another node replacement.
    try count(client, 0);
    try retained(manager, declaration.value, 1, &.{ 1, 2, 3 });
    try retained(manager, declaration.value, 2, &.{ 1, 2, 3, 4 });
    try retained(manager, declaration.value, 4, &.{});
    try t.expectError(error.DataflowRevisionNotFound, q.ManagedRevision.open(manager, declaration.value, 6, .{}));
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    {
        var limited = try q.ManagedRevision.open(manager, declaration.value, 1, .{ .rows = 1 });
        defer limited.deinit();
        _ = (try limited.next(&output)).?;
        try t.expect(!limited.complete);
        try t.expectError(error.ManagedTableResultBudget, limited.next(&output));
        try t.expectError(error.FailedManagedRevision, limited.next(&output));
        try t.expect(!limited.complete);
    }
    {
        var early = try q.ManagedRevision.open(manager, declaration.value, 2, .{});
        defer early.deinit();
        _ = (try early.next(&output)).?;
        try t.expect(!early.complete); // Close is local, not retirement or expiry.
    }
    {
        var probe = try q.ManagedRevision.open(manager, declaration.value, 1, .{});
        defer probe.deinit();
        try t.expectError(error.ManagedTableResultBudget, q.ManagedRevision.open(manager, declaration.value, 1, .{ .bytes = probe.root.content.bytes - 1 }));
        var limited = try q.ManagedRevision.open(manager, declaration.value, 1, .{ .bytes = probe.root.content.bytes + probe.next_page.?.content.bytes - 1 });
        defer limited.deinit();
        try t.expectError(error.ManagedTableResultBudget, limited.next(&output));
        try t.expect(!limited.complete);
    }
    var authorities: [3]u64 = undefined;
    for ([_]c.DirectTableBinding{ declaration.value.source, declaration.value.output }, 0..) |binding, i| {
        const metadata = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
        defer metadata.deinit();
        authorities[i] = metadata.value.result.lookup.?.authorization;
    }
    authorities[2] = (try c.DirectKVClient.apply(&output, client, .{ .observe = declaration.value.object })).definition.authorization;
    // Read through the public owner with another signed principal. The publisher
    // keeps its original token, record and transaction authority.
    const reader_key = try c.protocol.Ed25519.KeyPair.generateDeterministic(@splat(31));
    const reader_role = (try client.authority.query(.{ .realm = 42, .principal = 102, .kind = .{ .authorization = .{ .kind = .identity } } }, reader_key)).body.authorization.body.identity.login_role;
    const config = try client.call(.describe);
    defer config.deinit();
    const authority = config.value.result.description.authority;
    for ([_]struct { id: u64, rights: u64 }{
        .{ .id = authority.database, .rights = c.TableAuthority.connect },
        .{ .id = authority.initial_schema_authority, .rights = c.TableAuthority.usage },
        .{ .id = authorities[0], .rights = c.TableAuthority.select },
        .{ .id = authorities[1], .rights = c.TableAuthority.select },
        .{ .id = authorities[2], .rights = c.KVAuthority.inspect | c.KVAuthority.read },
    }) |grant| _ = try admin.change(.{ .grant = .{ .object = c.TableAuthority.reference(grant.id), .grantee = reader_role, .privileges = grant.rights } });
    var viewer = client;
    viewer.connection.principal = 102;
    viewer.connection.role = null;
    viewer.key = reader_key;
    var request: c.ManagedInspection.Request = .{ .namespace = declaration.value.namespace, .name = declaration.value.name, .expected = try declaration.value.interpretation(output.allocator()), .revision = null };
    const observed = try viewer.call(.{ .managed_inspection = request });
    defer observed.deinit();
    try t.expectEqualDeep(declaration.value.connection, observed.value.result.managed_inspection.declaration.connection);
    try t.expectEqual(@as(u64, 4), observed.value.result.managed_inspection.completed.?.revision.metadata.revision);
    try t.expectEqual(@as(u64, 0), observed.value.result.managed_inspection.completed.?.revision.metadata.rows);
    try t.expectEqual(c.protocol.Dataflow.State.retired, observed.value.result.managed_inspection.observation.?.head.control.state);
    const projected = try q.ManagedInspection.apply(output.allocator(), viewer, .{ .definition = c.protocol.Growth.current_definition, .namespace = request.namespace, .name = request.name.slice(), .expected = null, .revision = "1" });
    try t.expectEqualStrings("1", projected.completed.?.revision);
    try t.expectEqualStrings("3", projected.completed.?.rows);
    try t.expect(projected.current == null);
    var forged = observed.value.result.managed_inspection;
    forged.completed.?.revision.metadata.rows = 1;
    try t.expectError(error.InvalidManagedTableRecord, forged.validate(output.allocator(), request));
    forged = observed.value.result.managed_inspection;
    forged.completed.?.revision.metadata.schema.sha256[0] ^= 1;
    try t.expectError(error.InvalidManagedTableRecord, forged.validate(output.allocator(), request));

    for ([_]u64{ 1, 2, 4 }, [_]u64{ 3, 4, 0 }) |number, rows| {
        request.revision = number;
        const revision = try viewer.call(.{ .managed_inspection = request });
        defer revision.deinit();
        try t.expect(revision.value.result.managed_inspection.observation == null);
        try t.expectEqual(rows, revision.value.result.managed_inspection.completed.?.revision.metadata.rows);
        try t.expectError(error.AccessDenied, c.DirectRecord.read(init.gpa, viewer, revision.value.result.managed_inspection.completed.?.manifest));
    }
    request.revision = 6;
    try t.expectError(error.NotFound, viewer.call(.{ .managed_inspection = request }));
    request.revision = null;
    request.expected.?.digest[0] ^= 1;
    try t.expectError(error.Conflict, viewer.call(.{ .managed_inspection = request }));
    request.expected.?.digest[0] ^= 1;
    for (authorities, 0..) |authorization, i| {
        const rights = if (i == 2) c.KVAuthority.read else c.TableAuthority.select;
        _ = try admin.change(.{ .revoke_privileges = .{ .object = c.TableAuthority.reference(authorization), .grantee = reader_role, .privileges = rights } });
        // Buffered metadata is not a new disclosure grant, including empty
        // completions and an explicitly selected older nonempty revision.
        for ([_]?u64{ null, 1, 4 }) |number| {
            request.revision = number;
            try t.expectError(error.AccessDenied, viewer.call(.{ .managed_inspection = request }));
        }
        _ = try admin.change(.{ .grant = .{ .object = c.TableAuthority.reference(authorization), .grantee = reader_role, .privileges = rights } });
    }
    for (authorities) |authorization| {
        var nonempty = try q.ManagedRevision.open(manager, declaration.value, 1, .{});
        defer nonempty.deinit();
        var empty = try q.ManagedRevision.open(manager, declaration.value, 4, .{});
        defer empty.deinit();
        _ = (try nonempty.next(&output)).?;
        try t.expect(try empty.next(&output) == null);
        const object = c.TableAuthority.reference(authorization);
        _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = 0 } });
        // Bypassing the high-level reader still reaches the storage owner's
        // current read checks for the manifest and every immutable row page.
        try t.expectError(error.AccessDenied, c.DirectRecord.read(init.gpa, client, nonempty.root));
        try t.expectError(error.AccessDenied, c.DirectRecord.read(init.gpa, client, nonempty.next_page.?));
        try t.expectError(error.AccessDenied, nonempty.validateDisclosure());
        try t.expectError(error.AccessDenied, nonempty.next(&output));
        try t.expectError(error.AccessDenied, empty.next(&output));
        try t.expect(!empty.complete);
        try t.expectError(error.AccessDenied, q.ManagedRevision.open(manager, declaration.value, 4, .{}));
        _ = try admin.change(.{ .transfer_object = .{ .object = object, .owner = role } });
    }
    try retained(manager, declaration.value, 1, &.{ 1, 2, 3 });
}

pub fn incomplete(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(M.max_definition_bytes));
    const declaration = try c.protocol.Json.parseFromSlice(M.Declaration, init.gpa, bytes);
    defer declaration.deinit();
    const manager: M = .{ .client = client };
    var reader = try q.ManagedRevision.open(manager, declaration.value, 1, .{});
    defer reader.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    _ = (try reader.next(&output)).?;
    // The real HTTP proxy refuses the second immutable page. A delivered
    // prefix cannot become complete or silently restart at another basis.
    try t.expectError(error.AuthorityUnavailable, reader.next(&output));
    try t.expect(!reader.complete);
    try t.expectError(error.FailedManagedRevision, reader.next(&output));
    try retained(manager, declaration.value, 1, &.{ 1, 2, 3 });
}
