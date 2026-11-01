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
fn drain(manager: M, declaration: M.Declaration, io: std.Io, directory: std.Io.Dir) !void {
    const pending = try manager.start(declaration) orelse return;
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
    try t.expect(try c.DirectClientToken.lookup(client, manager.nameKey(invalid.namespace, invalid.name)) == null);
    try control(manager, declaration, .authorize, 652005);
    try control(manager, declaration, .activate, 652006);
    try count(client, 0);
    const pending = (try manager.start(declaration)).?;
    // Leave a real accepted common transaction and private staged rows for the
    // replacement process, while fresh readers still see the old complete output.
    for (0..5) |_| try t.expect(try manager.step(pending, init.io, .cwd(), null));
    try count(client, 0);
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
    for (0..20) |_| {
        if (!try manager.step(pending, init.io, .cwd(), null)) break;
    }
    try count(client, 3);
    try t.expect(try manager.start(declaration) == null);
    try control(manager, declaration, .resume_computation, 652009);
    try drain(manager, declaration, init.io, .cwd());
    try count(client, 4);
    try t.expectEqual(@as(u64, 2), (try manager.inspect(declaration)).head.revision);
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
    const cycle = try manager.prepare(1, "managed_cycle", 650001, 652016, "managed_input", "SELECT id FROM managed_output", options);
    try t.expectError(error.DataflowSourceChanged, manager.publish(cycle));
    try t.expectEqual(.source_changed, (try manager.inspect(cycle)).head.blocked);
    try t.expectError(error.DataflowSourceChanged, manager.publish(cycle));
    try control(manager, cycle, .retire, 652017);
    try t.expect(try manager.start(cycle) == null);
    try control(manager, declaration, .retire, 652012);
    try t.expect(try manager.start(declaration) == null);
    try count(client, 4);
}
