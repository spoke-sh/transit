//! Descriptor/policy tests use unpublished definitions and a reference store.
//! Public retained traversal, key seeks and ALTER/DROP/name reuse are exercised
//! by tests/query/execution/direct_captured_query.zig against the signed direct service.
const std = @import("std");
const e = std.testing;
const q = @import("root.zig");
const f = q.fuze;
const c = q.catalog;
const Source = q.TableSource;
const Store = q.testing.Store;
const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 17, .catalog = 9 }, .branch = 1, .audience = 13, .principal = 17, .role = null };

/// Creates owned descriptor bytes without implying catalog admission or rights.
fn makeDeclaration(allocator: std.mem.Allocator, object: u64) !Source.Owned {
    var ddl = try f.TableDdl.compile(allocator, "CREATE TABLE people (id INTEGER PRIMARY KEY, names LIST(UTF8))", null, null);
    defer ddl.deinit();
    const schema = try ddl.statement.create.bind(object);
    return declarationFromSchema(allocator, schema);
}
fn declarationFromSchema(allocator: std.mem.Allocator, schema: f.TableSchema.Schema) !Source.Owned {
    const object = schema.object;
    var prepared = try c.storage.TableDeclaration.prepare(allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = object }, .revision = 1, .schema = schema, .properties = "" });
    defer prepared.deinit();
    var buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&buffer));
    defer allocator.free(encoded.base64);
    return Source.from(allocator, connection, .{ .interpretation = try prepared.stored(), .namespace = 1, .authorization = 23, .name = try .init("people"), .position = .{ .partition = 1, .next_lsn = 2 }, .changed_lsn = 2, .row_count = 0, .schema = encoded });
}

test "captured Table declarations own exact numeric and metric semantics across neutral and binary boundaries" {
    const schema: f.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 4, .primary_key = &.{1}, .columns = &.{
        .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
        .{ .id = 2, .name = "amount", .type = .{ .decimal = .{ .precision = 12, .scale = 4 } }, .semantics = .{ .rounding = .half_even } },
        .{ .id = 3, .name = "embedding", .type = .{ .vector = .{ .dimensions = 2, .element = .float32 } }, .semantics = .{ .metric = .cosine } },
    } };
    var source = try declarationFromSchema(e.allocator, schema);
    defer source.deinit();
    var bytes: [Source.max_bytes]u8 = undefined;
    var restored = try Source.decode(e.allocator, try source.source.encode(&bytes));
    defer restored.deinit();
    @memset(&bytes, 0);
    try e.expectEqualDeep(source.source, restored.source);
    try e.expectEqual(.half_even, restored.source.semantics[1].rounding.?);
    try e.expectEqual(.cosine, restored.source.semantics[2].metric.?);
    const fingerprint = try restored.source.fingerprint();
    var short: [32]u8 = undefined;
    try e.expectError(error.SourceDefinitionTooLarge, restored.source.encode(&short));
    var changed = restored.source;
    changed.semantics = &.{ .{}, .{ .rounding = .toward_zero }, .{ .metric = .cosine } };
    try e.expect(!std.mem.eql(u8, &fingerprint, &try changed.fingerprint()));
    changed.semantics = &.{};
    try e.expect(!std.mem.eql(u8, &fingerprint, &try changed.fingerprint()));
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const declaration: q.SourceDefinition = .{ .resource = connection.scope.resource, .source = .{ .table = restored.source } };
    const foreign = try q.Values.Source.fromNative(arena.allocator(), declaration);
    const native = try foreign.native(arena.allocator());
    try e.expectEqual(try declaration.fingerprint(), try native.fingerprint());
}
fn ownDeclaration(allocator: std.mem.Allocator) !void {
    var owned = try makeDeclaration(allocator, 100);
    defer owned.deinit();
    try e.expectEqualStrings("names", owned.source.row_type.structure[1].name);
}
fn restore(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var owned = try Source.decode(allocator, bytes);
    defer owned.deinit();
    var buffer: [Source.max_bytes]u8 = undefined;
    try e.expectEqualSlices(u8, bytes, try owned.source.encode(&buffer));
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
    var owned = try makeDeclaration(e.allocator, 100);
    defer owned.deinit();
    // Enumerate every arena growth allocation independently of backing-page placement.
    var no_resize = e.FailingAllocator.init(e.allocator, .{ .resize_fail_index = 0 });
    try e.checkAllAllocationFailures(no_resize.allocator(), ownDeclaration, .{});
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
test "general Table requester policy covers multiple direct Tables in independent progress storage" {
    var store: Store = .{};
    defer store.deinit();
    var people = try makeDeclaration(e.allocator, 100);
    defer people.deinit();
    var places = try makeDeclaration(e.allocator, 200);
    defer places.deinit();
    const grant: q.UnifiedRecords.Policy = .{ .peer = 9, .requests = 8, .revision = 1, .target = .{ .catalog = .{ .scope = connection.scope, .owner = connection.audience, .principal = 17 } }, .allow = true, .limits = .{ .pages = 100, .segments = 200, .result_bytes = 1048576 } };
    var current = try store.capture();
    try e.expect(current.view.resource != connection.scope.resource);
    var foreign = grant;
    foreign.target.catalog.scope.realm += 1;
    try e.expectError(error.InvalidQueryPolicy, q.UnifiedCapture.setPolicy(&current, foreign));
    try q.UnifiedCapture.setPolicy(&current, grant);
    try store.commit(current);
    current = try store.capture();
    const admitted = (try q.UnifiedCapture.policy(&current, 9)).?;
    try e.expectEqualDeep(grant, admitted);
    try e.expectEqual(@as(u64, 17), try admitted.tablePrincipal(people.source));
    try e.expectEqual(@as(u64, 17), try admitted.tablePrincipal(places.source));
    inline for (.{ "realm", "resource", "catalog" }) |field| {
        var changed = places.source;
        @field(changed.scope, field) += 1;
        changed.interpretation.interpretation.object.scope = changed.scope;
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
    var remapped = admitted;
    remapped.target.catalog.principal = 18;
    try e.expectError(error.StaleQueryPolicy, q.UnifiedCapture.setPolicy(&current, remapped));
    try e.expectEqualDeep(grant, (try q.UnifiedCapture.policy(&current, 9)).?);
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
test "general Table embedded source plan and literal decoding share one request arena with exact failure cleanup" {
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

test "general Table interactive metadata cannot authenticate a configured principal as its caller" {
    var owned = try makeDeclaration(e.allocator, 100);
    defer owned.deinit();
    const source: q.SourceDefinition = .{ .resource = connection.scope.resource, .source = .{ .table = owned.source } };
    var client: q.UnifiedClient = .{ .wire = undefined, .key = undefined, .connection = .{ .realm = 1, .principal = 23, .source = 3, .resource = 7, .requester = 8, .requests = 10 } };
    const g = q.protocol.Growth;
    const p = q.protocol;
    const requests = try client.interactiveMetadata(source);
    try e.expectEqual(@as(u64, 7), requests[0].?.resource);
    try e.expect(requests[0].?.keys[1] == null);
    var grant: q.UnifiedRecords.Policy = .{ .peer = 8, .requests = 10, .revision = 1, .allow = true, .limits = .{ .pages = 8, .segments = 8, .result_bytes = 65536 }, .target = .{ .catalog = .{ .scope = connection.scope, .owner = connection.audience, .principal = 17 } } };
    var result: g.SnapshotRead.Result = .{ .snapshot = undefined, .current = .{ .{ .resource = .{ .id = 7, .writer = 3, .owner = null, .revision = 1, .deadline_ms = null }, .entries = @splat(null) }, .{ .resource = .{ .id = 10, .writer = 8, .owner = null, .revision = 1, .deadline_ms = null }, .entries = @splat(null) } } };
    result.current[0].?.entries[0] = .{ .key = requests[0].?.keys[0].?, .value = try grant.encode(), .revision = 1 };
    var requester: [20]u8 = undefined;
    requester[0..4].* = "UQH1".*;
    std.mem.writeInt(u64, requester[4..12], 23, .little);
    std.mem.writeInt(u64, requester[12..20], 3, .little);
    result.current[1].?.entries[0] = .{ .key = requests[1].?.keys[0].?, .value = try p.Value.init(&requester), .revision = 1 };
    // A requester policy cannot substitute its configured Table principal for
    // the actual caller. This rejection occurs before credentials or I/O.
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
    grant.target.catalog.principal = 42;
    result.current[0].?.entries[0].?.value = try grant.encode();
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
    grant.target.catalog.principal = 23;
    grant.allow = false;
    result.current[0].?.entries[0].?.value = try grant.encode();
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
    grant.allow = true;
    result.current[0].?.entries[0].?.value = try grant.encode();
    var direct = connection;
    direct.principal = 23;
    direct.role = 24;
    client.tables = .{ .allocator = e.allocator, .authority = undefined, .service = undefined, .key = undefined, .connection = direct };
    try e.expectError(error.QueryDenied, client.interactiveDescription(source, requests, result));
}
