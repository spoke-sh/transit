//! Installed Table/KV composition through the shared signed transaction owner.
const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const KV = c.DirectKVClient;
const Tx = c.DirectTransactionClient;
const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .binary, .nullable = false };
const payload: [1024]u8 = @splat(0x75);
const Saved = struct {
    definition: p.Growth.Definition,
    key: c.DirectClientToken.Key,
    object: d.Object,
    table_statement: c.DirectTransactionWorkspace.Request,
    kv_statement: c.DirectTransactionWorkspace.Request,
    commit: d.Operation,
};
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(Saved, init.gpa, bytes);
    defer parsed.deinit();
    try parsed.value.key.validate();
    try parsed.value.table_statement.validate();
    try parsed.value.kv_statement.validate();
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return parsed.value;
}
fn operation(client: c.DirectTableClient, id: u64) d.Operation {
    return .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = id };
}
fn visible(client: c.DirectTableClient, output: *std.heap.ArenaAllocator, object: d.Object, expected: bool) !void {
    const value = (try KV.apply(output, client, .{ .get = .{ .object = object, .key = "six" } })).value;
    try t.expectEqual(expected, value.value != null);
    try t.expect(value.workspace == null);
    if (value.value) |cell| try t.expectEqualSlices(u8, &payload, cell.value.atom.bytes);
    const table = try client.call(.{ .lookup = .{ .namespace = 1, .name = "atomic_rows" } });
    defer table.deinit();
    try t.expectEqual(@as(u64, @intFromBool(expected)), table.value.result.lookup.?.row_count);
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    var ddl = try c.DirectTablePreparedDdl.prepare(init.gpa, client, 1, "CREATE TABLE atomic_rows (id BIGINT PRIMARY KEY)", .transit, null);
    defer ddl.deinit();
    var table = try ddl.bind(init.gpa, client, 642001, 642010);
    defer table.deinit();
    (try table.table.admit(client)).deinit();
    const created = try table.table.operation(client, .execute, 64);
    defer created.deinit();
    try t.expect(created.value.result.ddl == .committed);
    const declaration = try KV.prepareDeclaration(init.gpa, .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = operation(client, 642002), .target = .{ .scope = client.connection.scope, .branch = 1, .object = 642000 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = undefined },
        .namespace = 1,
        .name = try .init("atomic_state"),
        .action = .{ .create = .{ .owner = role, .spec = spec } },
    });
    _ = try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .admit, .steps = 1 } });
    const kv_created = try KV.apply(&output, client, .{ .declaration = .{ .declaration = declaration, .command = .execute, .steps = 64 } });
    try t.expect(kv_created.declaration.operation == .committed);
    const metadata = (try KV.apply(&output, client, .{ .observe = declaration.binding.target })).definition;
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(9), .token = @splat(6) };
    const tx: Tx = .{ .catalog = client };
    _ = try tx.begin(.{ .key = key, .fingerprint = @splat(7), .operation = operation(client, 642100), .namespace = 1, .mode = .serializable, .selection = .{ .explicit_objects = &.{
        .{ .object = declaration.binding.target, .kind = .kv, .partition = null },
        .{ .object = created.value.result.ddl.committed.binding.target, .kind = .table, .partition = null },
    } }, .limits = c.DirectTransaction.default_limits, .budget = .{} });
    _ = try tx.acquire(key);
    var insert = try c.DirectTablePreparedDml.prepare(init.gpa, client, 1, "INSERT INTO atomic_rows (id) VALUES ($1)", .transit, null);
    defer insert.deinit();
    var work = try insert.bind(init.gpa, client, 642011, &.{.{ .signed = 42 }}, .bulk, null);
    defer work.deinit();
    const table_statement = try tx.stage(key, (try tx.inspect(key)).revision, 1, work.parsed.value.work);
    try t.expectEqual(@as(u64, 1), (try tx.execute(key, table_statement)).provisional.affected);
    var binding = declaration.binding;
    binding.identity = operation(client, 642012);
    binding.action = .insert;
    binding.expected_definition = metadata.interpretation.interpretation;
    const keys = [_][]const u8{ "one", "two", "three", "four", "five", "six" };
    var changes: [6]c.storage.KVPartition.Change = undefined;
    for (&changes, keys) |*change, name| change.* = .{ .put = .{ .key = name, .value = .{ .value = .{ .atom = .{ .bytes = &payload } } }, .expect = .absent } };
    const mutation = try KV.prepareMutation(&output, binding, spec, &changes);
    const kv_statement = try tx.stageKV(key, (try tx.inspect(key)).revision, 2, mutation);
    const saved: Saved = .{ .definition = p.Growth.current_definition, .key = key, .object = declaration.binding.target, .table_statement = table_statement, .kv_statement = kv_statement, .commit = operation(client, 642101) };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    try t.expectError(error.InvalidTableResponse, tx.execute(key, kv_statement));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const original = (try tx.statementOutcome(saved.key, saved.kv_statement)).?;
    try t.expectEqual(@as(u64, 6), original.provisional.affected);
    try t.expectEqualDeep(original, try tx.execute(saved.key, saved.kv_statement));
    try t.expectEqual(@as(u64, 1), (try tx.statementOutcome(saved.key, saved.table_statement)).?.provisional.affected);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved.object, false);
    var private = client;
    private.transaction = .{ .key = saved.key, .revision = (try tx.inspect(saved.key)).revision };
    const value = (try KV.apply(&output, private, .{ .get = .{ .object = saved.object, .key = "six" } })).value;
    try t.expect(value.workspace != null);
    try t.expectEqualSlices(u8, &payload, value.value.?.value.atom.bytes);
    try t.expectError(error.InvalidTableResponse, tx.settle(saved.key, saved.commit, .commit, 8));
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    const tx: Tx = .{ .catalog = client };
    const known = try tx.inspect(saved.key);
    try t.expect(known.observation == .decided and known.observation.decided.outcome == .committed);
    const result = try tx.settle(saved.key, saved.commit, .commit, 8);
    try t.expectEqualDeep(known.observation, result.observation);
    try t.expect(result.cleanup_complete);
    try t.expectEqual(@as(u64, 6), (try tx.statementOutcome(saved.key, saved.kv_statement)).?.provisional.affected);
    var output: std.heap.ArenaAllocator = .init(init.gpa);
    defer output.deinit();
    try visible(client, &output, saved.object, true);
}
