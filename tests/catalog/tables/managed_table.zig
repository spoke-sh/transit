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
        try t.expectEqual(count_, row.identity.ordinal);
        values[count_] = @intCast(row.cells[0].value.atom.signed);
        if (first == null) first = row;
        count_ += 1;
        // Rows in caller output survive subsequent internal scratch resets.
        try t.expectEqual(values[0], first.?.cells[0].value.atom.signed);
    }
    try t.expect(reader.complete);
    try t.expect(try reader.next(&output) == null);
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
    try t.expectError(error.AuthorityUnavailable, manager.start(declaration));
    const unclaimed = (try pendingWork(manager, declaration)).?;
    try t.expectEqualDeep(unclaimed, (try manager.start(declaration)).?);
    _ = try manager.closeOriginal((try c.DirectClientToken.inspect(client, unclaimed)).?);
    try t.expect(try manager.start(declaration) == null); // Skip the closed attempt.
    try t.expectError(error.AuthorityUnavailable, manager.start(declaration));
    const abandoned = (try pendingWork(manager, declaration)).?;
    try t.expect(!std.meta.eql(unclaimed, abandoned));
    try t.expect((try manager.inspect(declaration)).head.pending == null);
    try control(manager, declaration, .suspend_computation, 652030);
    try control(manager, declaration, .resume_computation, 652031);
    // Independent token discovery resumes the saved original after controls
    // advance the attempt. Its exact stale attachment closes permanently.
    try t.expectEqualDeep(abandoned, (try pendingWork(manager, declaration)).?);
    try t.expect(!try manager.step(abandoned, init.io, .cwd(), null));
    try t.expectEqual(.closed, (try c.DirectClientToken.inspect(client, abandoned)).?.original.?.phase);
    const pending = (try manager.start(declaration)).?;
    try t.expect(!std.meta.eql(abandoned, pending));
    try t.expect(try manager.step(pending, init.io, .cwd(), null)); // Acquire.
    const progress = (try c.DirectClientToken.inspect(client, pending)).?;
    try t.expect(progress.pending and progress.staged == null);
    try t.expectEqual(c.DirectProgressRecord.format, progress.record.?.format);
    try t.expectEqual(c.DirectOwnedRecord.format, progress.receipt.binding.intent.external.record.format);
    try t.expectEqual(.attached, progress.original.?.phase);
    const original_work = try manager.load(M.Work, progress.receipt.binding.intent.external.record, M.work_format);
    defer original_work.deinit();
    try t.expectEqual(.acquiring, original_work.value.phase);
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
    try control(manager, declaration, .refresh, 652029);
    _ = (try manager.start(declaration)).?;
    const successor = try client.call(.{ .managed_inspection = .{ .namespace = declaration.namespace, .name = declaration.name, .expected = null, .revision = null } });
    defer successor.deinit();
    try t.expect(successor.value.result.managed_inspection.observation.?.head.pending != null);
    try t.expectEqual(@as(u64, 5), successor.value.result.managed_inspection.completed.?.revision.metadata.revision);
    try t.expectEqual(@as(u64, 4), successor.value.result.managed_inspection.completed.?.revision.metadata.rows);
    try control(manager, declaration, .retire, 652012);
    try drain(manager, declaration, init.io, .cwd());
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
    // Keep this refusal observable across replacement for the independent
    // reader. Retirement (covered above) clears the current blocked reason.
    try dml(client, "DELETE FROM managed_output", 652028);
    try retained(manager, declaration, 1, &.{ 1, 2, 3 });
    try retained(manager, declaration, 2, &.{ 1, 2, 3, 4 });
    try retained(manager, declaration, 4, &.{});
    try prepareOrderedPages(init, client);
}

fn prepareOrderedPages(init: std.process.Init, client: c.DirectTableClient) !void {
    try ddl(client, "CREATE TABLE managed_order_input (id BIGINT PRIMARY KEY)", 652050, 652050);
    try ddl(client, "CREATE TABLE managed_order_output (id BIGINT PRIMARY KEY)", 652051, 652051);
    var storage: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&storage);
    try writer.writeAll("INSERT INTO managed_order_input (id) VALUES ");
    for (0..130) |i| {
        if (i != 0) try writer.writeByte(',');
        try writer.print("({d})", .{i});
    }
    try dml(client, writer.buffered(), 652052);
    const manager: M = .{ .client = client };
    const declaration = try manager.prepare(1, "managed_order_pages", 650005, 652053, "managed_order_output", "SELECT id FROM managed_order_input ORDER BY id DESC", options);
    _ = try manager.publish(declaration);
    try control(manager, declaration, .authorize, 652054);
    try control(manager, declaration, .activate, 652055);
    try drain(manager, declaration, init.io, .cwd());
    try verifyOrderedPages(init, client);
}

fn verifyOrderedPages(init: std.process.Init, client: c.DirectTableClient) !void {
    const manager: M = .{ .client = client };
    const declaration = (try manager.find(1, try .init("managed_order_pages"))).?;
    defer declaration.deinit();
    var reader = try q.ManagedRevision.open(manager, declaration.value, 1, .{});
    defer reader.deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    var count_: usize = 0;
    while (try reader.next(&output)) |row| {
        try t.expectEqual(count_, row.identity.ordinal);
        try t.expectEqual(@as(i128, @intCast(129 - count_)), row.cells[0].value.atom.signed);
        count_ += 1;
        _ = output.reset(.retain_capacity);
    }
    try t.expectEqual(@as(usize, 130), count_);
    try t.expectEqual(@as(u64, 3), reader.sequence);
    try t.expect(reader.complete);
}

pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8, admin: anytype, role: u64) !void {
    try verifyOrderedPages(init, client);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(M.max_definition_bytes));
    const declaration = try c.protocol.Json.parseFromSlice(M.Declaration, init.gpa, bytes);
    defer declaration.deinit();
    const manager: M = .{ .client = client };
    var after: ?u64 = null;
    var closed_count: usize = 0;
    var abandoned_count: usize = 0;
    while (true) {
        const page = try c.DirectClientToken.list(client, M.workAccount(), after, false);
        for (page.entries) |slot| if (slot) |entry| {
            try t.expect(!entry.pending and entry.original.?.phase == .closed);
            if (entry.record) |record| {
                try t.expectEqual(c.DirectProgressRecord.format, record.format);
                closed_count += 1;
            } else {
                try t.expect(entry.cancel);
                abandoned_count += 1;
            }
            try t.expect(!try manager.step(entry.receipt.binding.key, init.io, .cwd(), null));
        };
        after = page.next orelse break;
    }
    try t.expect(closed_count >= 5);
    try t.expectEqual(@as(usize, 2), abandoned_count);
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
    const budget_control = (try c.DirectKVClient.apply(&output, client, .{ .lookup = .{ .namespace = 1, .name = "managed_budget" } })).lookup.?;
    _ = try admin.change(.{ .grant = .{ .object = c.TableAuthority.reference(budget_control.authorization), .grantee = reader_role, .privileges = c.KVAuthority.inspect | c.KVAuthority.read } });
    var viewer = client;
    viewer.connection.principal = 102;
    viewer.connection.role = null;
    viewer.key = reader_key;
    const blocked = try viewer.call(.{ .managed_inspection = .{ .namespace = 1, .name = try .init("managed_budget"), .expected = null, .revision = null } });
    defer blocked.deinit();
    try t.expect(blocked.value.result.managed_inspection.completed == null);
    try t.expectEqual(c.protocol.Dataflow.Blocked.budget, blocked.value.result.managed_inspection.observation.?.head.blocked);
    var request: c.ManagedInspection.Request = .{ .namespace = declaration.value.namespace, .name = declaration.value.name, .expected = try declaration.value.interpretation(output.allocator()), .revision = null };
    const observed = try viewer.call(.{ .managed_inspection = request });
    defer observed.deinit();
    try t.expectEqualDeep(declaration.value.connection, observed.value.result.managed_inspection.declaration.connection);
    try t.expectEqual(@as(u64, 5), observed.value.result.managed_inspection.completed.?.revision.metadata.revision);
    try t.expectEqual(@as(u64, 4), observed.value.result.managed_inspection.completed.?.revision.metadata.rows);
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
        try t.expectError(error.CatalogIdentityConflict, c.DirectRecord.read(init.gpa, viewer, revision.value.result.managed_inspection.completed.?.manifest));
    }
    try t.expectError(error.CatalogIdentityConflict, c.DirectClientToken.lookup(viewer, manager.nameKey(request.namespace, request.name)));
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
    try ddl(client, "CREATE TABLE managed_grouped_output (id BIGINT PRIMARY KEY)", 652039, 652049);
    const grouped = try manager.prepare(1, "managed_grouped_order", 650004, 652040, "managed_grouped_output", "SELECT id FROM managed_input GROUP BY id HAVING COUNT(*) >= 1 ORDER BY id DESC LIMIT 2", options);
    _ = try manager.publish(grouped);
    try control(manager, grouped, .authorize, 652041);
    try control(manager, grouped, .activate, 652042);
    try drain(manager, grouped, init.io, .cwd());
    try retained(manager, grouped, 1, &.{ 4, 3 });
    try control(manager, grouped, .retire, 652043);
    try applicationPublication(init, client, admin, role);
}

fn applicationPublication(init: std.process.Init, client: c.DirectTableClient, admin: anytype, role: u64) !void {
    const A = q.ManagedApplication;
    const p = c.protocol;
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var queue = try q.fuze.LogDdl.compile(client.allocator, "CREATE QUEUE application_input (id BIGINT NOT NULL)", .transit, null);
    defer queue.deinit();
    const schema = try queue.statement.action.create.bind(730010);
    const configured = try queue.statement.configure(null, schema);
    const intent: c.DirectLog.Intent = .{ .kind = .queue, .namespace = 1, .name = try .init("application_input"), .action = .{ .create = .{
        .owner = role,
        .schema = schema,
        .configuration = configured.configuration,
        .limits = configured.limits,
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 730001 },
        .target = .{ .scope = client.connection.scope, .branch = client.connection.branch, .object = 730010 },
        .action = .create,
        .expected_definition = null,
        .expected_data = null,
        .intent = try intent.digest(client.allocator),
    } };
    _ = try c.DirectLogClient.apply(&output, client, .{ .admit = request });
    const created = (try c.DirectLogClient.apply(&output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } })).operation.operation;
    try t.expectEqual(.complete, created.phase);
    const metadata = try client.call(.{ .log_lookup = .{ .namespace = 1, .name = "application_input" } });
    defer metadata.deinit();
    const resources = [_]q.ApplicationBinding{.{ .value = .{ .log = metadata.value.result.log_lookup.? } }};
    const source = "CREATE DATAFLOW application_example FROM QUEUE application_input AS event AS BEGIN REQUIRE event.id > 0 ELSE 'InvalidInput'; END;";
    var program = try q.fuze.ApplicationProgram.parse(client.allocator, source, null);
    defer program.deinit();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const value: A.Declaration = .{
        .definition = p.Growth.current_definition,
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .name = try .init("application_example"),
        .object = .{ .scope = client.connection.scope, .branch = client.connection.branch, .object = 730020 },
        .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 730002 },
        .source_digest = digest,
        .program = program.program,
        .resources = &resources,
        .limits = .{ .requests = 1000, .scan_rows = 1000, .result_bytes = 65536, .continuation_bytes = 65536, .retained_bytes = 64 * 1024 * 1024, .transaction = c.DirectTransaction.default_limits },
    };
    try applicationFences(client, try value.inputClaim(client.allocator, 0, .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 731003 }));
    const manager: A = .{ .client = client };
    const original = try manager.publish(value);
    try t.expectEqual(.published, original.head.control.state);
    try t.expectEqualDeep(original, try manager.publish(value));
    const restored = (try manager.find(1, value.name)).?;
    defer restored.deinit();
    try t.expectEqualDeep(try value.interpretation(client.allocator), try restored.value.interpretation(client.allocator));
    var conflicting = value;
    conflicting.limits.scan_rows += 1;
    try t.expectError(error.DataflowIdentityConflict, manager.publish(conflicting));
    var attempt: p.Dataflow.ControlAttempt = .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 730003 }, .target = try value.interpretation(client.allocator), .expected = original.head.control, .command = .authorize };
    try t.expectError(error.InvalidDataflowTransition, manager.prepareControl(value, attempt, null));
    const authorized = try manager.prepareControl(value, attempt, role);
    defer client.allocator.free(authorized);
    const accepted = try manager.applyControl(authorized);
    try t.expectEqualDeep(accepted, try manager.applyControl(authorized));
    const observed = try manager.inspect(value);
    try t.expectEqual(.authorized, observed.head.control.state);
    try t.expectEqual(role, observed.head.executor_role.?);
    try manager.requireDependencies(value, observed);
    const authority = c.TableAuthority.reference(created.resulting.?.properties.authorization);
    _ = try admin.change(.{ .grant = .{ .object = authority, .grantee = role, .privileges = c.LogAuthority.inspect | c.LogAuthority.read } });
    _ = try admin.change(.{ .transfer_object = .{ .object = authority, .owner = 0 } });
    // Metadata/read grants are insufficient to acquire and settle program input.
    try t.expectError(error.AccessDenied, manager.requireDependencies(value, observed));
    attempt.operation.operation = 730004;
    attempt.expected = observed.head.control;
    attempt.command = .activate;
    try t.expectError(error.AccessDenied, manager.prepareControl(value, attempt, null));
    try t.expectEqual(.authorized, (try manager.inspect(value)).head.control.state);
    _ = try admin.change(.{ .transfer_object = .{ .object = authority, .owner = role } });
    const activated = try manager.prepareControl(value, attempt, null);
    defer client.allocator.free(activated);
    _ = try manager.applyControl(activated);
    try t.expectEqualDeep(accepted, try manager.applyControl(authorized));
    try t.expectEqual(.active, (try manager.inspect(value)).head.control.state);
    try t.expect(!try manager.cleanup(value));
    attempt.operation.operation = 730005;
    attempt.expected = (try manager.inspect(value)).head.control;
    attempt.command = .retire;
    const retired = try manager.prepareControl(value, attempt, null);
    defer client.allocator.free(retired);
    _ = try manager.applyControl(retired);
    try t.expect(try manager.cleanup(value));
    try t.expect(try manager.cleanup(value));
    try t.expectError(error.Conflict, manager.requireDependencies(value, try manager.inspect(value)));
    _ = try manager.applyControl(activated);
    try t.expectEqual(.retired, (try manager.inspect(value)).head.control.state);
    try applicationScheduled(init, client, value, role);
    try applicationAttachment(client, value, role);
    try applicationAcquisition(client, value, admin, role);
    try applicationExecution(client, value, role);
}

fn applicationAttachment(client: c.DirectTableClient, published: q.ManagedApplication.Declaration, role: u64) !void {
    const p = c.protocol;
    const T = c.DirectClientToken;
    const I = q.ApplicationInvocation;
    const declared = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .object = 735020,
        .operation = 735002,
        .source = "CREATE DATAFLOW application_attachment FROM QUEUE application_input AS event AS BEGIN REQUIRE event.id > 0 ELSE 'InvalidInput'; END;",
        .resources = published.resources,
        .limits = published.limits,
    });
    defer declared.deinit();
    const value = declared.value;
    const manager: q.ManagedApplication = .{ .client = client };
    const owner: I = .{ .manager = manager };
    var observed = try manager.publish(value);
    for ([_]p.Dataflow.Command{ .authorize, .activate }, 0..) |command, index| {
        const saved = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 735003 + @as(u64, index) }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = command }, if (command == .authorize) role else null);
        defer client.allocator.free(saved);
        _ = try manager.applyControl(saved);
        observed = try manager.inspect(value);
    }
    const token = owner.key(value, 1, "transit.application.invocation.v1\x00");
    var head = observed.head;
    head.attempt = 1;
    head.pending = token;
    var arena: std.heap.ArenaAllocator = .init(client.allocator);
    defer arena.deinit();
    const publication = (try T.inspect(client, manager.nameKey(value.namespace, value.name))).?;
    const work: I.Work = .{
        .definition = p.Growth.current_definition,
        .declaration = publication.receipt.binding.intent.external.record,
        .lease = .{ .target = try value.interpretation(client.allocator), .control = head.control, .owner = manager.operation(value, "worker", 1), .epoch = 1 },
        .attachment = try manager.mutation(&arena, value, observed.storage, observed.position, head, manager.operation(value, "claim", 1), .present),
        .claim = try value.inputClaim(client.allocator, 0, manager.operation(value, "queue-claim", 1)),
        .receipt = null,
        .input_lease = null,
        .environment = null,
        .phase = .claiming,
        .execution = .initial(),
    };
    const bytes = try p.Json.valueAllocBounded(arena.allocator(), work, 64 * 1024);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    _ = try c.DirectOwnedRecord.stage(client, token, 1, work.lease.owner.operation, digest, .{ .bytes = 128 * 1024 }, I.work_format, bytes);
    // A control publication defeats the frozen attachment before it can claim
    // input. Recovery must close the serialized original, with no fresh CAS.
    const retire = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 735005 }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = .retire }, null);
    defer client.allocator.free(retire);
    _ = try manager.applyControl(retire);
    var host: ApplicationHost = .{};
    try t.expectEqual(.complete, try q.ApplicationRecovery.step(manager, token, .{ .context = &host, .bind = ApplicationHost.bind }));
    const closed = (try T.inspect(client, token)).?;
    try t.expectEqual(.closed, closed.original.?.phase);
    try t.expect(!closed.pending);
    // The public service maps a closed original to Conflict. Inspect its
    // unchanged closed receipt as the authoritative rejection evidence.
    try t.expectError(error.Conflict, owner.attach(closed, work));
    try t.expectEqualDeep(closed, (try T.inspect(client, token)).?);
    try t.expectEqual(@as(u32, 0), host.evaluations);
    observed = try manager.inspect(value);
    try t.expect(observed.head.pending == null);
    try t.expectEqual(@as(u64, 0), observed.head.attempt);
    try t.expect(try manager.cleanup(value));
}

fn applicationScheduled(init: std.process.Init, client: c.DirectTableClient, published: q.ManagedApplication.Declaration, role: u64) !void {
    const g = @import("transit_sql_service").database;
    const p = c.protocol;
    const T = c.DirectClientToken;
    try ddl(client, "CREATE TABLE application_scheduled_rows (id BIGINT PRIMARY KEY)", 734001, 734010);
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = "application_scheduled_rows" } });
    defer table.deinit();
    const resources = [_]q.ApplicationBinding{ published.resources[0], .table(table.value.result.lookup.?) };
    const declared = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .object = 734020,
        .operation = 734002,
        .source =
        \\CREATE DATAFLOW application_scheduled FROM QUEUE application_input AS event AS BEGIN
        \\  LET key = DIGEST(CAST(event.id AS TEXT));
        \\  REQUIRE key IS NOT NULL ELSE 'MissingDigest';
        \\  BEGIN ATOMIC
        \\    INSERT INTO application_scheduled_rows VALUES (event.id) ON CONFLICT (id) DO ASSERT SAME ROW;
        \\  END;
        \\END;
        ,
        .resources = &resources,
        .limits = published.limits,
    });
    defer declared.deinit();
    const value = declared.value;
    const manager: q.ManagedApplication = .{ .client = client };
    var observed = try manager.publish(value);
    for ([_]p.Dataflow.Command{ .authorize, .activate }, 0..) |command, index| {
        const saved = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 734003 + @as(u64, index) }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = command }, if (command == .authorize) role else null);
        defer client.allocator.free(saved);
        _ = try manager.applyControl(saved);
        observed = try manager.inspect(value);
    }
    const bindings = [_]g.DatabaseAccount.Binding{.{ .resource = client.connection.scope.resource, .catalog = client.connection.scope.catalog, .owner = client.connection.audience, .namespace = 1, .role = client.connection.role }};
    const account: g.DatabaseAccount = .{ .configuration = .{ .realm = client.connection.scope.realm, .table_principal = client.connection.principal, .account = @splat(73), .bindings = &bindings, .operation_quota = 10000, .byte_quota = 64 * 1024 * 1024 } };
    const first = try g.DatabaseRuntime.init(init.gpa, init.io, client.service.url, account, 1, .{ .table = client.key }, 30000);
    defer first.deinit();
    // No invocation start/tick call: the database service discovers the
    // declaration and retains one original while its input is empty.
    var idle = false;
    for (0..256) |_| if (!try first.tick()) {
        idle = true;
        break;
    };
    try t.expect(idle);
    observed = try manager.inspect(value);
    const token = observed.head.pending.?;
    const original = (try T.inspect(client, token)).?;
    try t.expectEqual(.attached, original.original.?.phase);
    try t.expectEqual(@as(u64, 1), observed.head.attempt);
    first.notify();
    for (0..256) |_| if (!try first.tick()) break;
    try t.expectEqualDeep(original, (try T.inspect(client, token)).?);

    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var metadata = try c.DirectLogProtocol.decodeMetadata(client.allocator, client.connection, resources[0].value.log);
    defer metadata.deinit();
    const append = try q.ApplicationData.prepareAppend(output.allocator(), client.connection, .{ .declaration = resources[0].value.log.declaration, .schema = metadata.definition.schema }, 734100, .{ .kind = .queue, .target = "application_input", .values = &.{.{ .integer = 71 }} });
    const payload = try append.payload.decode(output.allocator(), c.DirectTableProtocol.max_work_bytes);
    _ = try c.DirectQueueClient.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = append.work.append }, .payload = payload } });
    // A pending acquisition supplies retry debt even without a volatile hint.
    var acquired = false;
    const owner: q.ApplicationInvocation = .{ .manager = manager };
    for (0..256) |_| {
        _ = try first.tick();
        const progress = (try T.inspect(client, token)).?;
        const work = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
        defer work.deinit();
        if (work.value.execution.phase == .execute) {
            acquired = true;
            break;
        }
    }
    try t.expect(acquired);
    const replacement = try g.DatabaseRuntime.init(init.gpa, init.io, client.service.url, account, 2, .{ .table = client.key }, 30000);
    defer replacement.deinit();
    try t.expectError(error.StaleGatewayCoordinator, first.tick());
    var complete = false;
    for (0..512) |_| {
        _ = try replacement.tick();
        const progress = (try T.inspect(client, token)).?;
        if (progress.original.?.phase == .closed) {
            complete = true;
            break;
        }
    }
    try t.expect(complete);
    observed = try manager.inspect(value);
    try t.expectEqual(@as(u64, 1), observed.head.completed);
    try t.expectEqual(@as(u64, 0), observed.head.refused);
    const rows = try client.call(.{ .lookup = .{ .namespace = 1, .name = "application_scheduled_rows" } });
    defer rows.deinit();
    try t.expectEqual(@as(u64, 1), rows.value.result.lookup.?.row_count);
    const retire = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 734200 }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = .retire }, null);
    defer client.allocator.free(retire);
    _ = try manager.applyControl(retire);
    replacement.notify();
    for (0..512) |_| {
        _ = try replacement.tick();
        if ((try manager.inspect(value)).head.retirement_complete) return;
    }
    return error.ApplicationCleanupIncomplete;
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

fn applicationFences(client: c.DirectTableClient, claim: c.protocol.StreamQueue.Claim) !void {
    const T = c.DirectClientToken;
    const account: [32]u8 = @splat(73);
    const record = try c.DirectRecord.stage(client, account, 7, "application fence proof");
    var fences: [2]T.Fence = undefined;
    for (&fences, 0..) |*fence, index| {
        const key: T.Key = .{ .definition = c.protocol.Growth.current_definition, .connection = client.connection, .account = account, .token = @splat(@intCast(index + 1)) };
        const receipt = try T.bind(client, .{ .key = key, .fingerprint = @splat(@intCast(index + 1)), .intent = .{ .external = .{ .connection = client.connection, .namespace = 1, .operation = 731001 + @as(u64, index), .record = record } } });
        fence.* = .{ .key = key, .revision = receipt.position };
    }
    var caller = client;
    caller.lease = try T.Lease.combine(try T.Lease.combine(null, fences[0]), fences[1]);
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    _ = try c.DirectQueueClient.apply(&output, caller, .{ .observe = claim.target });
    for (&fences, 0..) |*fence, index| {
        const changed = try T.update(client, .{ .key = fence.key, .expected = fence.revision, .pending = true, .cancel = true, .record = null });
        fence.revision = changed.revision;
        // Rejection occurs before an original Queue claim can be admitted.
        try t.expectError(error.Conflict, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = .{ .claim = claim } } }));
        try t.expect((try c.DirectQueueClient.apply(&output, client, .{ .operation = .{ .claim = claim } })).operation == null);
        if (index == 0) caller.lease.?.revision = changed.revision else caller.lease.?.additional.?.revision = changed.revision;
        _ = try c.DirectQueueClient.apply(&output, caller, .{ .observe = claim.target });
    }
    for (fences) |fence| _ = try T.update(client, .{ .key = fence.key, .expected = fence.revision, .pending = false, .cancel = true, .record = null });
    try t.expectError(error.Conflict, c.DirectQueueClient.apply(&output, caller, .{ .mutate = .{ .work = .{ .claim = claim } } }));
    try t.expect((try c.DirectQueueClient.apply(&output, client, .{ .operation = .{ .claim = claim } })).operation == null);
}

fn applicationAcquisition(client: c.DirectTableClient, published: q.ManagedApplication.Declaration, admin: anytype, role: u64) !void {
    const p = c.protocol;
    const I = q.ApplicationInvocation;
    const T = c.DirectClientToken;
    const declaration = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .object = 732020,
        .operation = 732001,
        .source = "CREATE DATAFLOW application_acquisition FROM QUEUE application_input AS event AS BEGIN REQUIRE event.id > 0 ELSE 'InvalidInput'; END;",
        .resources = published.resources,
        .limits = published.limits,
    });
    defer declaration.deinit();
    const value = declaration.value;
    const manager: q.ManagedApplication = .{ .client = client };
    const owner: I = .{ .manager = manager };
    var observed = try manager.publish(value);
    for ([_]p.Dataflow.Command{ .authorize, .activate }, 0..) |command, index| {
        const saved = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 732002 + @as(u64, index) }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = command }, if (command == .authorize) role else null);
        defer client.allocator.free(saved);
        _ = try manager.applyControl(saved);
        observed = try manager.inspect(value);
    }
    const token = (try owner.start(value, 0)).?;
    try t.expectEqualDeep(token, (try owner.start(value, 0)).?);
    var progress = (try T.inspect(client, token)).?;
    const initial = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
    defer initial.deinit();
    try t.expectEqualDeep(progress, try owner.acquire(value, progress, initial.value));
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var metadata = try c.DirectLogProtocol.decodeMetadata(client.allocator, client.connection, value.resources[0].value.log);
    defer metadata.deinit();
    try t.expect((try c.DirectQueueClient.apply(&output, client, .{ .operation = .{ .claim = initial.value.claim } })).operation == null);
    const append = try q.ApplicationData.prepareAppend(output.allocator(), client.connection, .{ .declaration = value.resources[0].value.log.declaration, .schema = metadata.definition.schema }, 732004, .{ .kind = .queue, .target = "application_input", .values = &.{.{ .integer = 42 }} });
    const payload = try append.payload.decode(output.allocator(), c.DirectTableProtocol.max_work_bytes);
    _ = try c.DirectQueueClient.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = append.work.append }, .payload = payload } });
    progress = try owner.acquire(value, progress, initial.value);
    const claimed = try owner.load(progress.record.?);
    defer claimed.deinit();
    try t.expectEqual(.reading, claimed.value.phase);
    try t.expect(claimed.value.environment == null);
    progress = try owner.acquire(value, progress, claimed.value);
    const ready = try owner.load(progress.record.?);
    defer ready.deinit();
    try t.expectEqual(.ready, ready.value.phase);
    const executor = try owner.executor(value, progress, ready.value);
    const input = try owner.loadInput(executor, value, ready.value, ready.value.environment.?);
    defer input.deinit();
    try t.expectEqual(@as(i64, 42), (try input.value.environment.values[0].value.field("id")).integer);
    // Owning the input has not ACKed it. The original receipt still observes
    // the same acquisition, and a fresh host reads the exact protected value.
    const page = (try c.DirectQueueClient.apply(&output, executor, .{ .page = .{ .cursor = .{ .receipt = ready.value.receipt.?, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = 65536 } } })).page;
    try t.expectEqual(.acquired, page.rows[0].lease.state);
    try t.expectEqualDeep(progress, try owner.acquire(value, progress, ready.value));
    const authority = c.TableAuthority.reference(value.resources[0].value.log.declaration.properties.authorization);
    _ = try admin.change(.{ .grant = .{ .object = authority, .grantee = role, .privileges = c.LogAuthority.inspect } });
    _ = try admin.change(.{ .transfer_object = .{ .object = authority, .owner = 0 } });
    try t.expectError(error.AccessDenied, owner.loadInput(executor, value, ready.value, ready.value.environment.?));
    const safe = try owner.load(progress.record.?);
    safe.deinit();
    _ = try admin.change(.{ .transfer_object = .{ .object = authority, .owner = role } });
    observed = try manager.inspect(value);
    const suspend_request = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 732005 }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = .suspend_computation }, null);
    defer client.allocator.free(suspend_request);
    const control_metadata = (try c.DirectKVClient.apply(&output, client, .{ .observe = value.object })).definition;
    const control_authority = c.TableAuthority.reference(control_metadata.authorization);
    _ = try admin.change(.{ .grant = .{ .object = control_authority, .grantee = role, .privileges = c.KVAuthority.inspect | c.KVAuthority.read } });
    _ = try admin.change(.{ .transfer_object = .{ .object = control_authority, .owner = 0 } });
    try t.expectError(error.AccessDenied, manager.applyControl(suspend_request));
    try t.expect(!(try T.inspect(client, token)).?.cancel);
    _ = try admin.change(.{ .transfer_object = .{ .object = control_authority, .owner = role } });
    _ = try manager.applyControl(suspend_request);
    _ = try manager.applyControl(suspend_request);
    try t.expect((try T.inspect(client, token)).?.cancel);
    try t.expectError(error.Conflict, c.DirectQueueClient.apply(&output, executor, .{ .observe = ready.value.claim.target }));
    try t.expectError(error.DataflowLeaseFenced, owner.acquire(value, progress, ready.value));
    try t.expectEqualDeep(token, (try manager.inspect(value)).head.pending.?);
    try applicationCancelled(owner, value, token);
    try applicationCancelAcquisition(client, published, role, false);
    try applicationCancelAcquisition(client, published, role, true);
}

fn applicationCancelled(owner: q.ApplicationInvocation, value: q.ManagedApplication.Declaration, token: c.DirectClientToken.Key) !void {
    const T = c.DirectClientToken;
    const client = owner.manager.client;
    var host: ApplicationHost = .{};
    for (0..16) |_| {
        const progress = (try T.inspect(client, token)).?;
        const saved = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
        defer saved.deinit();
        // Input ownership remains attached until its read has been released.
        if (saved.value.execution.phase != .complete) try t.expectEqualDeep(token, (try owner.manager.inspect(value)).head.pending.?);
        const runner: q.ApplicationExecution = .{ .owner = owner, .native = .{ .context = &host, .bind = ApplicationHost.bind } };
        const next = try runner.tick(value, progress, saved.value);
        if (!next.pending) {
            try t.expectEqual(.closed, next.original.?.phase);
            const final = try owner.load(next.record.?);
            defer final.deinit();
            try t.expectEqual(.complete, final.value.execution.phase);
            try t.expect(final.value.execution.cancelled);
            try t.expect(!final.value.execution.acknowledged);
            const head = (try owner.manager.inspect(value)).head;
            try t.expect(head.pending == null);
            try t.expectEqual(@as(u64, 0), head.completed);
            try t.expectEqual(@as(u64, 1), head.refused);
            // Replaying the terminal owner only closes the same original.
            try t.expectEqualDeep(next, try runner.tick(value, next, final.value));
            return;
        }
    }
    return error.ApplicationCleanupIncomplete;
}

fn applicationCancelAcquisition(client: c.DirectTableClient, published: q.ManagedApplication.Declaration, role: u64, claimed: bool) !void {
    const p = c.protocol;
    const operation: u64 = if (claimed) 732200 else 732100;
    const declared = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .object = operation + 20,
        .operation = operation,
        .source = if (claimed) "CREATE DATAFLOW application_cancel_read FROM QUEUE application_input AS event WHERE id = 43 AS BEGIN REQUIRE TRUE ELSE 'Unused'; END;" else "CREATE DATAFLOW application_cancel_empty FROM QUEUE application_input AS event WHERE id < 0 AS BEGIN REQUIRE TRUE ELSE 'Unused'; END;",
        .resources = published.resources,
        .limits = published.limits,
    });
    defer declared.deinit();
    const value = declared.value;
    const manager: q.ManagedApplication = .{ .client = client };
    const owner: q.ApplicationInvocation = .{ .manager = manager };
    var observed = try manager.publish(value);
    for ([_]p.Dataflow.Command{ .authorize, .activate }, 0..) |command, index| {
        const saved = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation + 1 + index }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = command }, if (command == .authorize) role else null);
        defer client.allocator.free(saved);
        _ = try manager.applyControl(saved);
        observed = try manager.inspect(value);
    }
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    if (claimed) {
        var metadata = try c.DirectLogProtocol.decodeMetadata(client.allocator, client.connection, value.resources[0].value.log);
        defer metadata.deinit();
        const append = try q.ApplicationData.prepareAppend(output.allocator(), client.connection, .{ .declaration = value.resources[0].value.log.declaration, .schema = metadata.definition.schema }, operation + 3, .{ .kind = .queue, .target = "application_input", .values = &.{.{ .integer = 43 }} });
        const payload = try append.payload.decode(output.allocator(), c.DirectTableProtocol.max_work_bytes);
        _ = try c.DirectQueueClient.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = append.work.append }, .payload = payload } });
    }
    const token = (try owner.start(value, 0)).?;
    const progress = (try c.DirectClientToken.inspect(client, token)).?;
    const initial = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
    defer initial.deinit();
    const acquired = try owner.acquire(value, progress, initial.value);
    if (claimed) {
        const saved = try owner.load(acquired.record.?);
        defer saved.deinit();
        try t.expectEqual(.reading, saved.value.phase);
        try t.expect(saved.value.environment == null);
    } else try t.expectEqualDeep(progress, acquired);
    observed = try manager.inspect(value);
    const suspend_request = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation + 4 }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = .suspend_computation }, null);
    defer client.allocator.free(suspend_request);
    _ = try manager.applyControl(suspend_request);
    try applicationCancelled(owner, value, token);
}

const ApplicationHost = struct {
    digest: [32]u8 = undefined,
    evaluations: u32 = 0,
    native: ?q.ApplicationHost = null,
    bindings: usize = 0,
    finishes: usize = 0,
    authority_checked: [2]bool = .{ false, false },
    const a = q.fuze.ApplicationProgram;
    fn lookup(_: *anyopaque, _: []const u8) anyerror!a.Values.Value {
        return error.UnknownProgramVariable;
    }
    fn evaluate(context: *anyopaque, _: a.Id, operation: a.Evaluation.Operation, arguments: []const a.Values.Value) anyerror!a.Values.Value {
        const self: *ApplicationHost = @ptrCast(@alignCast(context));
        if (operation == .function and operation.function != .digest) {
            const host_ = (if (self.native) |*native| native else return error.UnexpectedHostOperation).host();
            return host_.evaluate(host_.context, 1, operation, arguments);
        }
        if (operation != .function or operation.function != .digest or arguments.len != 1 or arguments[0] != .text) return error.UnexpectedHostOperation;
        self.evaluations += 1;
        std.crypto.hash.sha2.Sha256.hash(arguments[0].text, &self.digest, .{});
        return .{ .binary = &self.digest };
    }
    fn condition(_: *anyopaque, _: a.Values.Value) anyerror!bool {
        return error.UnexpectedProtectedCondition;
    }
    fn host(self: *ApplicationHost) a.Evaluation.Host {
        return .{ .context = self, .lookup = lookup, .evaluate = evaluate, .condition = condition };
    }
    fn bind(context: *anyopaque, scope: q.ApplicationExecution.Context) !q.ApplicationExecution.BoundHost {
        const self: *ApplicationHost = @ptrCast(@alignCast(context));
        try t.expectEqual(self.bindings, self.finishes);
        try t.expect(self.native == null);
        try scope.input.source.validate();
        try t.expectEqualDeep(scope.work.claim.target, scope.input.source.target);
        try t.expectEqualDeep(scope.client.transaction != null, scope.work.execution.transaction != null);
        try scope.requireCurrent();
        var invalid = scope;
        invalid.client.lease = null;
        try t.expectError(error.DataflowLeaseFenced, invalid.requireCurrent());
        invalid = scope;
        invalid.invocation.token[0] ^= 1;
        try t.expectError(error.DataflowLeaseFenced, invalid.requireCurrent());
        const authority_index: usize = if (scope.client.transaction == null) 0 else 1;
        if (!self.authority_checked[authority_index]) {
            const http = @import("transit_serving_http");
            const Reservation = http.ApplicationReservation;
            var authority: http.ApplicationAuthority = .{ .scope = scope, .secrets = null };
            var memory: [1024]u8 = undefined;
            var slots: [2]Reservation.Slot = undefined;
            var reservation = try Reservation.init(scope.client.service.http.io, &memory, &slots, @splat(1), scope.input.source, 1, 100, authority.authority());
            defer reservation.deinit();
            const access: Reservation.Access = .{ .owner = scope.invocation, .input = scope.input.source, .now_ms = 2 };
            try reservation.request(access, .{ .capability = reservation.reference });
            const material = try reservation.retain(scope.client.service.http.io, access, .{ .step = scope.step, .node = 1, .arguments = @splat(1) }, .{ .secret = .{ .bytes = "private-proof-value", .revision = "original-observation", .origin = .random, .revision_kind = .transient } });
            try t.expectEqualStrings("private-proof-value", (try reservation.read(access, material, .cookie)).secret.bytes);
            var copied = access;
            copied.input.ordinal += 1;
            try t.expectError(error.ApplicationRequestOwnerMismatch, reservation.request(copied, .{ .capability = reservation.reference }));
            const native_secret = try reservation.retain(scope.client.service.http.io, access, .{ .step = scope.step, .node = 2, .arguments = @splat(2) }, .{ .secret = .{ .bytes = "unbound-proof-value", .revision = "unbound-native-revision", .origin = .named, .revision_kind = .native } });
            try t.expectError(error.MissingProgramNativeBinding, reservation.read(access, native_secret, .commitment));
            // Compose the request factory against this signed claim and both
            // native transaction modes. The capability fixture is transient;
            // the retained invocation remains the authority for every read.
            var requests = try http.ApplicationRequests.init(scope.scratch, scope.client.service.http.io, .{ .active_requests = 1, .request_bytes = 1024, .protected_bytes = 4096, .protected_values = 8, .scratch_bytes = 8192, .resident_bytes = 64 * 1024 });
            defer requests.deinit();
            const ticket = try requests.open(scope.input.source, @splat(2), .{ .query = "state=public-state&code=protected-code", .headers = &.{} }, 60_000);
            var request_factory = try http.ApplicationRequestHost.init(&requests, &.{});
            const factory = request_factory.host();
            var request_scope = scope;
            request_scope.input.environment.values = &.{.{ .instruction = 0, .value = .{ .record = &.{.{ .name = "request", .value = .{ .capability = ticket.reference } }} } }};
            var request_bound = try factory.bind(factory.context, request_scope);
            defer request_bound.deinit();
            const expressions = request_bound.expressions;
            const public_state = try expressions.evaluate(expressions.context, 1, .{ .function = .http_query_unique }, &.{ .{ .capability = ticket.reference }, .{ .text = "state" } });
            try t.expectEqualStrings("public-state", public_state.text);
            const protected_code = try expressions.evaluate(expressions.context, 2, .{ .function = .http_secret_query_unique }, &.{ .{ .capability = ticket.reference }, .{ .text = "code" } });
            try t.expect(protected_code == .secret);
            try t.expectEqualDeep(protected_code, try expressions.evaluate(expressions.context, 2, .{ .function = .http_secret_query_unique }, &.{ .{ .capability = ticket.reference }, .{ .text = "code" } }));
            const commitment = try expressions.evaluate(expressions.context, 3, .{ .function = .commitment }, &.{protected_code});
            var expected: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash("protected-code", &expected, .{});
            try t.expectEqualSlices(u8, &expected, commitment.binary);
            try t.expectError(error.ProtectedProgramValue, expressions.evaluate(expressions.context, 4, .{ .function = .http_query_unique }, &.{ .{ .capability = ticket.reference }, .{ .text = "code" } }));
            try t.expectError(error.MissingProgramNativeBinding, expressions.evaluate(expressions.context, 5, .{ .function = .secret }, &.{.{ .text = "cookie-key" }}));
            var wrong_input = request_scope;
            wrong_input.input.source.ordinal += 1;
            try t.expectError(error.ApplicationRequestOwnerMismatch, factory.bind(factory.context, wrong_input));
            self.authority_checked[authority_index] = true;
        }
        self.native = .{ .scratch = scope.scratch, .io = scope.client.service.http.io, .scope = scope };
        self.bindings += 1;
        return .{ .expressions = self.host(), .release = finish };
    }
    fn finish(context: *anyopaque) void {
        const self: *ApplicationHost = @ptrCast(@alignCast(context));
        self.native = null;
        self.finishes += 1;
    }
};

fn applicationExecution(client: c.DirectTableClient, published: q.ManagedApplication.Declaration, role: u64) !void {
    const p = c.protocol;
    const T = c.DirectClientToken;
    try ddl(client, "CREATE TABLE application_rows (id BIGINT PRIMARY KEY)", 733001, 733010);
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = "application_rows" } });
    defer table.deinit();
    var output: std.heap.ArenaAllocator = .init(client.allocator);
    defer output.deinit();
    var document_ddl = try c.DirectDocumentPreparedDdl.prepare(client.allocator, client, 1, "CREATE DOCUMENT application_policy (id BIGINT PRIMARY KEY, enabled BOOLEAN NOT NULL) WITH (profile = 'versioned')", .transit, null);
    defer document_ddl.deinit();
    var document_work = try document_ddl.bind(client.allocator, client, 733013, 733014);
    defer document_work.deinit();
    const document_reference = try document_work.document.stage(client, @splat(3));
    (try document_reference.admit(client)).deinit();
    const document_result = try document_reference.operation(client, .execute, 64);
    defer document_result.deinit();
    try t.expect(document_result.value.result.document_declaration.operation == .committed);
    try dml(client, "INSERT INTO application_policy VALUES (1, TRUE)", 733015);
    const policy = try client.call(.{ .document_lookup = .{ .namespace = 1, .name = "application_policy" } });
    defer policy.deinit();
    const policy_binding: q.ApplicationBinding = .table(policy.value.result.document_lookup.?.definition);
    const revision = try q.ApplicationData.currentRevision(output.allocator(), client, policy_binding, .{ .integer = 1 });
    try t.expect(revision == .binary);
    try t.expectEqualSlices(u8, &try (try c.DirectDocument.Revision.fromRead(policy.value.result.document_lookup.?.definition)).stateFingerprint(), revision.binary);
    try t.expectEqual(.null, try q.ApplicationData.currentRevision(output.allocator(), client, policy_binding, .{ .integer = 999 }));
    try t.expectError(error.ProgramTypeMismatch, q.ApplicationData.currentRevision(output.allocator(), client, policy_binding, .{ .text = "1" }));
    const kv = try c.DirectKVClient.prepareDeclaration(client.allocator, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733011 }, .target = .{ .scope = client.connection.scope, .branch = client.connection.branch, .object = 733011 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(0) },
        .namespace = 1,
        .name = try .init("application_state"),
        .action = .{ .create = .{ .owner = role, .spec = .{ .value_type = .row, .nullable = false, .fields = &.{.{ .name = "id", .type = .int64, .nullable = false }} } } },
    });
    _ = try c.DirectKVClient.apply(&output, client, .{ .declaration = .{ .declaration = kv, .command = .admit, .steps = 1 } });
    _ = try c.DirectKVClient.apply(&output, client, .{ .declaration = .{ .declaration = kv, .command = .execute, .steps = 16 } });
    const kv_metadata = try client.call(.{ .kv_lookup = .{ .namespace = 1, .name = "application_state" } });
    defer kv_metadata.deinit();
    var stream = try q.fuze.LogDdl.compile(client.allocator, "CREATE STREAM application_events (id BIGINT NOT NULL)", .transit, null);
    defer stream.deinit();
    const schema = try stream.statement.action.create.bind(733012);
    const configured = try stream.statement.configure(null, schema);
    const intent: c.DirectLog.Intent = .{ .kind = .stream, .namespace = 1, .name = try .init("application_events"), .action = .{ .create = .{ .owner = role, .schema = schema, .configuration = configured.configuration, .limits = configured.limits } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733012 }, .target = .{ .scope = client.connection.scope, .branch = client.connection.branch, .object = 733012 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(client.allocator) } };
    _ = try c.DirectLogClient.apply(&output, client, .{ .admit = request });
    _ = try c.DirectLogClient.apply(&output, client, .{ .operation = .{ .binding = request.binding, .command = .execute, .steps = 16 } });
    const stream_metadata = try client.call(.{ .log_lookup = .{ .namespace = 1, .name = "application_events" } });
    defer stream_metadata.deinit();
    const resources = [_]q.ApplicationBinding{ published.resources[0], .table(table.value.result.lookup.?), .kv(kv_metadata.value.result.kv_lookup.?), .{ .value = .{ .log = stream_metadata.value.result.log_lookup.? } }, policy_binding };
    const declared = try q.ApplicationDeclaration.prepare(client.allocator, .{
        .connection = client.connection,
        .executor_role = role,
        .namespace = 1,
        .object = 733020,
        .operation = 733002,
        .source =
        \\CREATE DATAFLOW application_execution FROM QUEUE application_input AS event WHERE id < 10 AS BEGIN
        \\  LET key = DIGEST(CAST(event.id AS TEXT));
        \\  LET policy = SELECT * FROM application_policy WHERE id = 1;
        \\  BEGIN ATOMIC
        \\    REQUIRE CURRENT_REVISION(application_policy, 1) = policy._revision
        \\      AND CURRENT_REVISION(application_policy, 999) IS NULL ELSE 'PolicyChanged';
        \\    PUT INTO application_state KEY key VALUE ROW(event.id) IF ABSENT;
        \\    INSERT INTO application_rows VALUES (event.id) ON CONFLICT (id) DO ASSERT SAME ROW;
        \\    PRODUCE INTO application_events VALUES (event.id);
        \\    REQUIRE event.id = 7 ELSE 'AbortBody';
        \\  END;
        \\  LET observed = SELECT * FROM application_rows WHERE id = event.id;
        \\  REQUIRE observed.id = event.id ELSE 'MissingCommittedRow';
        \\  LET state = GET FROM application_state KEY key;
        \\  REQUIRE state.id = event.id ELSE 'MissingCommittedKV';
        \\ON FAILURE failure
        \\  LET failure_key = DIGEST(CAST(event.id AS TEXT));
        \\  BEGIN ATOMIC
        \\    PUT INTO application_state KEY failure_key VALUE ROW(-event.id) IF ABSENT;
        \\    INSERT INTO application_rows VALUES (-event.id) ON CONFLICT (id) DO ASSERT SAME ROW;
        \\    PRODUCE INTO application_events VALUES (-event.id);
        \\    REQUIRE event.id = 8 ELSE 'AbortFailureHandler';
        \\  END;
        \\END;
        ,
        .resources = &resources,
        .limits = published.limits,
    });
    defer declared.deinit();
    const value = declared.value;
    const manager: q.ManagedApplication = .{ .client = client };
    const owner: q.ApplicationInvocation = .{ .manager = manager };
    var observed = try manager.publish(value);
    for ([_]p.Dataflow.Command{ .authorize, .activate }, 0..) |command, index| {
        const saved = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733003 + @as(u64, index) }, .target = try value.interpretation(client.allocator), .expected = observed.head.control, .command = command }, if (command == .authorize) role else null);
        defer client.allocator.free(saved);
        _ = try manager.applyControl(saved);
        observed = try manager.inspect(value);
    }

    var metadata = try c.DirectLogProtocol.decodeMetadata(client.allocator, client.connection, value.resources[0].value.log);
    defer metadata.deinit();
    var host: ApplicationHost = .{};
    for ([_]i64{ 7, 8, 9 }, 0..) |id, ordinal| {
        _ = output.reset(.retain_capacity);
        const append = try q.ApplicationData.prepareAppend(output.allocator(), client.connection, .{ .declaration = value.resources[0].value.log.declaration, .schema = metadata.definition.schema }, 733100 + ordinal, .{ .kind = .queue, .target = "application_input", .values = &.{.{ .integer = id }} });
        const payload = try append.payload.decode(output.allocator(), c.DirectTableProtocol.max_work_bytes);
        _ = try c.DirectQueueClient.apply(&output, client, .{ .mutate = .{ .work = .{ .enqueue = append.work.append }, .payload = payload } });
        const token = blk: {
            for (0..8) |_| {
                if (owner.start(value, 0)) |started| break :blk started.? else |err| {
                    if (err != error.InvalidTableResponse) return err;
                }
            }
            return error.ApplicationAttachmentIncomplete;
        };
        var complete = false;
        var cancellation: ?[]u8 = null;
        defer if (cancellation) |bytes| client.allocator.free(bytes);
        var cancelled_after_commit = false;
        for (0..200) |_| {
            // A fresh owner and decoded progress on every iteration must resume
            // the same instruction/native operation, with no host cursor cache.
            const progress = (try T.inspect(client, token)).?;
            const saved = try owner.load(progress.record orelse progress.receipt.binding.intent.external.record);
            defer saved.deinit();
            const execution = saved.value.execution;
            errdefer std.debug.print("Application input {d}, phase {s}, transaction {s}\n", .{ id, @tagName(execution.phase), if (execution.transaction) |transaction| @tagName(transaction.kind) else "none" });
            if (id == 7 and execution.transaction != null and execution.transaction.?.kind == .final) {
                if (execution.phase == .checkpoint and execution.checkpoint != null and cancellation == null) {
                    const head = try manager.inspect(value);
                    cancellation = try manager.prepareControl(value, .{ .definition = p.Growth.current_definition, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733200 }, .target = try value.interpretation(client.allocator), .expected = head.head.control, .command = .suspend_computation }, null);
                }
                if (execution.phase == .settle and !cancelled_after_commit) {
                    var executor = client;
                    executor.connection.role = role;
                    const transaction: c.DirectTransactionClient = .{ .catalog = executor };
                    const status = try transaction.inspect(execution.transaction.?.key);
                    if (status.observation == .decided and status.observation.decided.outcome == .committed) {
                        // Finish native participant cleanup before the control
                        // authority check; the invocation has not observed the
                        // original commit or retained its terminal evidence yet.
                        const settled = try transaction.settle(execution.transaction.?.key, status.attempt.?.operation, .commit, 64);
                        try t.expect(settled.cleanup_complete);
                        // The saved control cancels the invocation before its
                        // stale head mutation refuses. The original commit wins.
                        try t.expectError(error.Conflict, manager.applyControl(cancellation.?));
                        try t.expect((try T.inspect(client, token)).?.cancel);
                        cancelled_after_commit = true;
                        continue;
                    }
                }
            }
            const recovered = q.ApplicationRecovery.step(manager, token, .{ .context = &host, .bind = ApplicationHost.bind }) catch |err| {
                // The proxy loses accepted replies at native and continuation
                // boundaries. Reload the same token on the next iteration.
                if (err == error.InvalidTableResponse) continue;
                std.debug.print("Application phase {s}, input phase {s}, native rejection {any}: {s}\n", .{ @tagName(saved.value.execution.phase), @tagName(saved.value.phase), client.service.last_rejection, @errorName(err) });
                return err;
            };
            if (recovered == .complete) {
                const next = (try T.inspect(client, token)).?;
                try t.expect(!next.pending);
                try t.expectEqual(.closed, next.original.?.phase);
                const final = try owner.load(next.record.?);
                defer final.deinit();
                try t.expectEqual(.complete, final.value.execution.phase);
                try t.expect(final.value.execution.acknowledged);
                errdefer std.debug.print("Application terminal failure: {any}\n", .{final.value.execution.failure});
                try t.expectEqual(id != 7, final.value.execution.failure != null);
                complete = true;
                break;
            }
        }
        try t.expect(complete);
        if (id == 7) try t.expect(cancelled_after_commit);
        observed = try manager.inspect(value);
        try t.expect(observed.head.pending == null);
        try t.expectEqual(@as(u64, 1), observed.head.completed);
        try t.expectEqual(@as(u64, ordinal), observed.head.refused);
        const reference = observed.head.checkpoint.?;
        try t.expectEqual(c.DirectTransactionRecord.format, reference.format);
        var executor = client;
        executor.connection.role = role;
        const bytes = try c.DirectRecord.read(client.allocator, executor, reference);
        defer client.allocator.free(bytes);
        const checkpoint = try p.Json.parseFromSlice(c.DirectTransactionRecord.Envelope, client.allocator, bytes);
        defer checkpoint.deinit();
        try checkpoint.value.validate(reference);
        const tx: c.DirectTransactionClient = .{ .catalog = executor };
        const status = try tx.inspect(checkpoint.value.transaction);
        try t.expectEqual(.committed, status.observation.decided.outcome);
        try t.expect(status.cleanup_complete);
    }
    // One body observation per input, plus the two failure-handler observations.
    // An accepted candidate with a lost reply must never rerun its host helper.
    try t.expectEqual(@as(u32, 5), host.evaluations);
    try t.expect(host.bindings > 0);
    try t.expectEqual(host.bindings, host.finishes);
    try t.expect(host.native == null);
    try t.expectEqualDeep([_]bool{ true, true }, host.authority_checked);
    const result = try client.call(.{ .lookup = .{ .namespace = 1, .name = "application_rows" } });
    defer result.deinit();
    const rows = result.value.result.lookup.?;
    try t.expectEqual(@as(u64, 2), rows.row_count);
    const pinned = try client.call(.{ .pin = .{ .object = rows.interpretation.interpretation.object, .owner = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733302 }, .expected = rows.position } });
    defer pinned.deinit();
    const snapshot: c.DirectTableProtocol.Snapshot = .{ .object = rows.interpretation.interpretation.object, .handle = pinned.value.result.pin };
    var query = try q.DirectTableQuery.openRetained(client.allocator, client, snapshot, "application_rows", "SELECT id FROM application_rows", .{ .requests = 100, .rows = 8, .result_bytes = 8192 }, null, null, .{});
    defer query.deinit();
    var batch = try query.nextBatch(8);
    defer batch.deinit();
    try t.expect(batch.complete);
    try t.expectEqual(@as(usize, 2), batch.len);
    var ids: [2]i64 = undefined;
    for (batch.rows[0..batch.len], &ids) |row, *id| id.* = @intCast(row.?.cells[0].value.atom.signed);
    std.mem.sort(i64, &ids, {}, std.sort.asc(i64));
    try t.expectEqualSlices(i64, &.{ -8, 7 }, &ids);
    (try client.call(.{ .release = snapshot })).deinit();
    for ([_][]const u8{ "7", "8", "9" }, [_]?i64{ 7, -8, null }) |key_text, expected| {
        var key: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(key_text, &key, .{});
        const read = (try c.DirectKVClient.apply(&output, client, .{ .get = .{ .object = kv.binding.target, .key = &key } })).value;
        const row = try q.ApplicationData.kvValue(output.allocator(), read);
        if (expected) |id| try t.expectEqual(id, (try row.field("id")).integer) else try t.expect(row == .null);
    }
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = resources[3].interpretation(), .partition = 0 };
    const consumed = (try c.DirectStreamClient.apply(&output, client, .{ .mutate = .{ .work = .{ .consume = .{ .target = target, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733300 }, .group = null, .from = 0, .until = null, .timestamp = null } } } })).operation.?.consume;
    const cursor = (try c.DirectStreamClient.apply(&output, client, .{ .cursor = .{ .target = target, .read = consumed.handle() } })).cursor;
    const page = (try c.DirectStreamClient.apply(&output, client, .{ .page = .{ .cursor = cursor, .limits = .{ .rows = 8, .encoded_bytes = 8192, .scanned_rows = 8 } } })).page;
    try t.expect(page.cursor.coverage.complete);
    try t.expectEqual(@as(usize, 2), page.rows.len);
    for (page.rows, [_]i64{ 7, -8 }) |row, expected| try t.expectEqual(expected, row.value.cells[0].value.atom.signed);
    _ = try c.DirectStreamClient.apply(&output, client, .{ .mutate = .{ .work = .{ .release = .{ .target = target, .operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 733301 }, .read = consumed.handle() } } } });
}
