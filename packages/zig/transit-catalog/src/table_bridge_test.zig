const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const b = c.TableBridge;
const v = c.TableValues;
const connection: c.TableClient.Connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .principal = 17 };
const compile: b.Action = .{ .compile = .{ .identity = .{ .operation = "1", .namespace = "1000" }, .create_object = "100", .sql = "CREATE TABLE people (id INTEGER, name UTF8)" } };
fn client() !c.TableClient {
    return .{ .transport = undefined, .connection = connection, .key = try c.protocol.Ed25519.KeyPair.generateDeterministic(@splat(1)) };
}
test "neutral session loads one immutable intent and small references never rebind a replacement" {
    var caller = try client();
    var session: b.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const first = (try session.apply(&arena, &caller, compile)).compiled;
    try t.expectEqualStrings("100", first.intent.object);
    try t.expectEqualStrings("1000", first.intent.namespace);
    var changed = compile;
    changed.compile.identity.namespace = "1001";
    const second = (try session.apply(&arena, &caller, changed)).compiled;
    try t.expect(!std.mem.eql(u8, first.intent.reference.digest, second.intent.reference.digest));
    try t.expectError(error.CatalogIdentityConflict, session.apply(&arena, &caller, .{ .next = first.intent.reference }));
    _ = try session.get(second.intent.reference, connection);
    const loaded = (try session.apply(&arena, &caller, .{ .load = first.saved })).loaded;
    try t.expectEqualDeep(first.intent, loaded);
    try t.expectEqualStrings(first.saved.bytes, try v.hex(arena.allocator(), (try session.get(first.intent.reference, connection)).bytes));
    _ = try session.apply(&arena, &caller, .{ .forget = first.intent.reference });
    try t.expectError(error.TableIntentNotLoaded, session.apply(&arena, &caller, .{ .status = first.intent.reference }));
    _ = try session.apply(&arena, &caller, .{ .load = first.saved });
    var other = connection;
    other.owner += 1;
    try t.expectError(error.CatalogIdentityConflict, session.get(first.intent.reference, other));
    // Results own their strings separately from the handle's single intent.
    _ = try session.apply(&arena, &caller, .{ .forget = first.intent.reference });
    try t.expectEqualStrings("100", loaded.object);
}
test "neutral saved recovery rejects missing foreign tampered and cross-scope inputs before network" {
    var caller = try client();
    var session: b.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const first = (try session.apply(&arena, &caller, compile)).compiled;
    const encoded = try c.protocol.Json.valueAlloc(arena.allocator(), b.Action{ .load = first.saved });
    const decoded = try b.parse(arena.allocator(), encoded);
    try t.expectEqualDeep(first.saved, decoded.value.load);
    try t.expectError(error.MissingField, b.parse(arena.allocator(), "{\"load\":{\"bytes\":\"\"}}"));
    try t.expectError(error.InvalidJsonShape, b.parse(arena.allocator(), "{\"load\":{\"definition\":\"foreign-v1\",\"bytes\":\"\"}}"));
    const changed = try arena.allocator().dupe(u8, first.saved.bytes);
    changed[8] = if (changed[8] == '0') '1' else '0';
    try t.expectError(error.IncompatibleDefinition, session.apply(&arena, &caller, .{ .load = .{ .definition = c.protocol.Growth.current_definition, .bytes = changed } }));
    caller.connection.scope.resource += 1;
    try t.expectError(error.CatalogIdentityConflict, session.apply(&arena, &caller, .{ .load = first.saved }));
    caller.connection = connection;
    _ = try session.get(first.intent.reference, connection);
    try t.expectError(error.InvalidTableIntent, v.unhex(arena.allocator(), "0A", 1));
    try t.expectError(error.InvalidTableIntent, v.unhex(arena.allocator(), "00", 0));
    const oversized = try arena.allocator().alloc(u8, b.max_input_bytes + 1);
    try t.expectError(error.JsonByteBudgetExceeded, b.parse(arena.allocator(), oversized));
}
test "neutral session failed compilation and allocation leave original intent loaded" {
    var caller = try client();
    var session: b.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const first = (try session.apply(&arena, &caller, compile)).compiled;
    var invalid = compile;
    invalid.compile.sql = "CREATE people";
    var location: c.fuze.Sql.Location = .{ .offset = 999 };
    try t.expectError(error.InvalidSqlSyntax, session.applyDiagnostic(&arena, &caller, invalid, &location));
    try t.expectEqual(@as(usize, 7), location.offset);
    _ = try session.get(first.intent.reference, connection);
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var output: std.heap.ArenaAllocator = .init(failing.allocator());
    defer output.deinit();
    // Compilation itself uses the session allocator. Only exporting the new
    // saved result fails; the old original remains available for recovery.
    try t.expectError(error.OutOfMemory, session.apply(&output, &caller, compile));
    _ = try session.get(first.intent.reference, connection);
}
test "neutral status retains original applied counts and input diagnostics without any read" {
    var caller = try client();
    var intent = try caller.compile(t.allocator, "CREATE TABLE people (id INTEGER)", .{ .operation = 1, .namespace = 1000, .create_object = 100 }, null);
    defer intent.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const outcome: c.TableClient.Outcome = .{ .ddl = .{ .operation = .{ .scope = connection.scope, .principal = 17, .operation = 1, .object = 100, .digest = intent.identity.ddl.digest, .kind = .create, .state = .rejected, .reason = .name_conflict, .admitted_input = 12, .completed_input = 13 } } };
    const projected = try v.Outcome.foreign(arena.allocator(), &intent, outcome);
    try t.expectEqual(.rejected, projected.phase);
    try t.expect(projected.terminal);
    try t.expectEqual(@as(?u64, 13), projected.completed_input);
    try t.expectEqual(null, projected.counts);
    try t.expectEqualStrings("table.name_conflict", projected.diagnostic.code.slice());
    var tampered = outcome;
    tampered.ddl.operation.operation += 1;
    try t.expectError(error.CatalogIdentityConflict, v.Outcome.foreign(arena.allocator(), &intent, tampered));
    const control = try v.Disposition.foreign(.{ .scope = connection.scope, .origin = .external, .principal = 17, .input = 12, .payload = @splat(0), .outcome = .denied });
    try t.expectEqual(.input_rejected, control.diagnostic.outcome);
    const serialized = try c.protocol.Json.valueAlloc(arena.allocator(), b.Result{ .state = .{ .outcome = projected, .upload = null } });
    const parsed = try c.protocol.Json.parseFromSlice(b.Result, arena.allocator(), serialized);
    try t.expectEqualDeep(projected, parsed.value.state.outcome.?);
}
fn failures(allocator: std.mem.Allocator) !void {
    var caller = try client();
    var session: b.Session = .{ .allocator = allocator };
    defer session.deinit();
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const result = (try session.apply(&arena, &caller, compile)).compiled;
    _ = try session.apply(&arena, &caller, .{ .load = result.saved });
    _ = try session.get(result.intent.reference, connection);
}
test "neutral session releases allocations across compilation export and reload failures" {
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), failures, .{});
}
