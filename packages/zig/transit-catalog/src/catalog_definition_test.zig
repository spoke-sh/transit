const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const f = c.fuze;
const s = c.storage;
const d = c.protocol.DataLifecycle;
const A = c.CatalogDefinition;
const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
fn schemaBytes(allocator: std.mem.Allocator, schema: f.TableSchema.Schema) !c.DirectTableProtocol.Binary {
    var bytes: [f.TableSchema.max_bytes]u8 = undefined;
    return c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&bytes));
}
fn definition(allocator: std.mem.Allocator, object: u64, columns: []const f.TableSchema.Column) !A.Definition {
    return .{ .definition = c.protocol.Growth.current_definition, .object = .{ .scope = scope, .branch = 1, .object = object }, .revision = 1, .properties = .{ .namespace = 1, .authorization = 100 + object, .name = try .init("selected") }, .retired = false, .schema = try schemaBytes(allocator, .{ .object = object, .revision = 1, .next_column = 50, .columns = columns }), .sources = &.{}, .body = undefined };
}
fn source(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore) !A.Source {
    const schema: f.TableSchema.Schema = .{ .object = 30, .revision = 1, .next_column = 9, .columns = &.{ .{ .id = 4, .name = "id", .type = .int64, .nullable = false }, .{ .id = 8, .name = "amount", .type = .int64, .nullable = false } } };
    var prepared = try s.TableDeclaration.prepare(allocator, .{ .object = .{ .scope = scope, .branch = 1, .object = 30 }, .revision = 1, .schema = schema, .properties = "" });
    defer prepared.deinit();
    return .{ .properties = .{ .namespace = 1, .authorization = 130, .name = try .init("source") }, .declaration = try s.TableDeclaration.stage(objects, &prepared), .schema = try schemaBytes(allocator, schema) };
}
test "catalog descriptor retains typed view binding and rejects text-driven or incompatible artifacts" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    const input = try source(allocator, store);
    var input_schema = try A.decodeSchema(allocator, input.schema);
    defer input_schema.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var plan: f.LogicalQuery.Plan = .{ .schema = try input_schema.schema.rowType(&fields), .source_basis = input.declaration.interpretation.digest, .projection = &.{1}, .output_names = &.{"total"}, .predicate = .{ .compare = .{ .column = 1, .op = .gt, .value = .{ .signed = 5 } } } };
    var encoded: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var value = try definition(allocator, 50, &.{.{ .id = 7, .name = "total", .type = .int64, .nullable = false }});
    value.sources = &.{input};
    value.body = .{ .view = .{ .plan = try c.DirectTableProtocol.Binary.encode(allocator, try f.LogicalPlanCodec.encode(plan, &encoded)), .source_text = "SELECT amount AS total FROM source WHERE amount > 5" } };
    const saved = try A.stage(t.allocator, store, value);
    var loaded = try A.load(t.allocator, store, saved);
    defer loaded.deinit();
    try t.expectEqualDeep(saved, try loaded.value.stored(t.allocator));
    try t.expectEqualStrings(value.body.view.source_text, loaded.value.body.view.source_text);
    const exposed = try c.DirectCatalogDefinitions.foreign(allocator, loaded.value);
    try t.expectEqualStrings("50", exposed.stored.interpretation.object.object);
    try t.expectEqualStrings("7", exposed.schema.columns[0].id);
    try t.expectEqualStrings(value.body.view.source_text, exposed.body.view.source_text);
    value.body.view.source_text = "This text is provenance, never executable SQL";
    try value.validate(t.allocator);
    try t.expect(!std.meta.eql(saved, try value.stored(t.allocator)));
    plan.limit = 2;
    value.body.view.plan = try c.DirectTableProtocol.Binary.encode(allocator, try f.LogicalPlanCodec.encode(plan, &encoded));
    try t.expectError(error.UnsupportedCatalogView, value.validate(t.allocator));
    value.sources = &.{.{ .properties = input.properties, .declaration = input.declaration, .schema = value.schema }};
    try t.expectError(error.InvalidCatalogDescriptor, value.validate(t.allocator));
}
test "catalog descriptor foreign layout distinguishes malformed values from unavailable and corrupt retained bytes" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const store = objects.objectStore();
    const captured = try A.stageInput(store, &.{ 0x12, 0x3d, 0x1a, 0x3d });
    const column: f.TableSchema.Column = .{ .id = 3, .name = "amount", .type = .int64, .nullable = false };
    const layout: A.Field = .{ .column = 3, .offset = 0, .bytes = 2, .encoding = .comp_3 };
    var value = try definition(allocator, 60, &.{column});
    value.body = .{ .foreign = .{ .record_bytes = 2, .fields = &.{layout}, .malformed = .type_error, .input = .{ .content = captured, .availability = .retained, .provenance = "file:///mutable/provenance" } } };
    const saved = try A.stage(t.allocator, store, value);
    var loaded = try A.load(t.allocator, store, saved);
    defer loaded.deinit();
    const exposed = try c.DirectCatalogDefinitions.foreign(allocator, loaded.value);
    try t.expectEqualStrings("3", exposed.body.foreign.fields[0].column);
    try t.expectEqualStrings("4", exposed.body.foreign.input.content.bytes);
    const bytes = try A.loadInput(t.allocator, store, loaded.value.body.foreign.input);
    defer t.allocator.free(bytes);
    var utf8: [16]u8 = undefined;
    try t.expectEqual(@as(i128, -123), (try A.decodeField(column, layout, .reject, bytes[0..2], &utf8)).value.atom.signed);
    try t.expectEqual(f.Types.Kind.int64, (try A.decodeField(column, layout, .type_error, bytes[2..4], &utf8)).type_error);
    try t.expectError(error.ForeignValueMalformed, A.decodeField(column, layout, .reject, bytes[2..4], &utf8));
    var absent = loaded.value.body.foreign.input;
    absent.availability = .unavailable;
    try t.expectError(error.HistoricalArtifactUnavailable, A.loadInput(t.allocator, store, absent));
    var wrong = captured;
    wrong.bytes += 1;
    absent.content = wrong;
    absent.availability = .retained;
    try t.expectError(error.InvalidCatalogDescriptor, A.loadInput(t.allocator, store, absent));
    value.body.foreign.fields = &.{.{ .column = 3, .offset = 0, .bytes = 17, .encoding = .comp_3 }};
    try t.expectError(error.InvalidCatalogDescriptor, value.validate(t.allocator));
}
test "catalog descriptor graph keys and endpoints use stable column identities" {
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(t.allocator);
    defer objects.deinit();
    const input = try source(allocator, objects.objectStore());
    var value = try definition(allocator, 70, &.{.{ .id = 2, .name = "amount", .type = .int64, .nullable = false }});
    value.sources = &.{input};
    value.body = .{ .property_graph = .{ .next_mapping = 10, .vertices = &.{.{ .id = 1, .label = try .init("Person"), .key = .{ .source = 0, .column = 4 }, .properties = &.{.{ .id = 2, .name = try .init("amount"), .value = .{ .source = 0, .column = 8 } }} }}, .edges = &.{.{ .id = 3, .label = try .init("Knows"), .key = .{ .source = 0, .column = 4 }, .source_vertex = 1, .source_key = .{ .source = 0, .column = 4 }, .target_vertex = 1, .target_key = .{ .source = 0, .column = 8 }, .properties = &.{} }} } };
    const stored = try A.stage(t.allocator, objects.objectStore(), value);
    var loaded = try A.load(t.allocator, objects.objectStore(), stored);
    defer loaded.deinit();
    try t.expectEqual(@as(u64, 8), loaded.value.body.property_graph.edges[0].target_key.column);
    const exposed = try c.DirectCatalogDefinitions.foreign(allocator, loaded.value);
    try t.expectEqualStrings("8", exposed.body.property_graph.edges[0].target_key.column);
    try t.expectEqualStrings("1", exposed.body.property_graph.edges[0].target_vertex);
    var edge = value.body.property_graph.edges[0];
    edge.target_vertex = 9;
    value.body.property_graph.edges = &.{edge};
    try t.expectError(error.InvalidCatalogDescriptor, value.validate(t.allocator));
    edge.target_vertex = 1;
    edge.target_key.column = 999;
    value.body.property_graph.edges = &.{edge};
    try t.expectError(error.InvalidCatalogDependency, value.validate(t.allocator));
}

test "catalog descriptor independent signed request and canonical artifact preserve full width columns" {
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8, value: A.Definition, artifact_hex: []const u8, digest: [32]u8, schema_digest: [32]u8, input_hex: []const u8 };
    const parsed = try c.protocol.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-catalog-definition-v1.json"));
    defer parsed.deinit();
    const value = parsed.value;
    try value.request.validate(t.allocator);
    try value.request.proof.verify(value.public_key);
    const encoded = try A.encode(t.allocator, value.value);
    defer t.allocator.free(encoded);
    const independent = try t.allocator.alloc(u8, value.artifact_hex.len / 2);
    defer t.allocator.free(independent);
    _ = try std.fmt.hexToBytes(independent, value.artifact_hex);
    try t.expectEqualSlices(u8, independent, encoded);
    const stored = try value.value.stored(t.allocator);
    try t.expectEqualDeep(value.digest, stored.interpretation.digest);
    try t.expectEqualDeep(value.schema_digest, stored.schema);
    var decoded = try A.decodeSchema(t.allocator, value.value.schema);
    defer decoded.deinit();
    try t.expectEqual(std.math.maxInt(u64) - 1, decoded.schema.columns[0].id);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const exposed = try c.DirectCatalogDefinitions.foreign(arena.allocator(), value.value);
    try t.expectEqualStrings("18446744073709551614", exposed.body.foreign.fields[0].column);
    try t.expectEqualStrings("18446744073709551615", exposed.schema.next_column);
    var bytes: [4]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, value.input_hex);
    var utf8: [16]u8 = undefined;
    const layout = value.value.body.foreign;
    try t.expectEqual(@as(i128, -123), (try A.decodeField(decoded.schema.columns[0], layout.fields[0], layout.malformed, bytes[0..2], &utf8)).value.atom.signed);
    try t.expectEqual(.type_error, std.meta.activeTag(try A.decodeField(decoded.schema.columns[0], layout.fields[0], layout.malformed, bytes[2..4], &utf8)));

    // A refusal still discloses a recorded predecessor. A malformed or foreign
    // predecessor must reject even when no successor definition was accepted.
    var binding = value.request.action.descriptor.declaration.request.binding;
    binding.action = .alter;
    binding.expected_definition = stored.interpretation;
    var outcome: c.DirectDefinition.Operation = .{ .binding = binding, .intent = stored.content, .kind = stored.kind, .namespace = stored.properties.namespace, .name = stored.properties.name, .position = .{ .partition = 1, .next_lsn = 1 }, .phase = .rejected, .reason = .stale_definition, .previous = stored, .resulting = null };
    try outcome.validate();
    outcome.previous.?.next_column = 0;
    try t.expectError(error.InvalidCatalogDescriptor, outcome.validate());
    outcome.previous = stored;
    outcome.phase = .cancelled;
    outcome.reason = .none;
    try outcome.validate();
    outcome.previous.?.interpretation.object.object += 1;
    try t.expectError(error.InvalidCatalogDescriptor, outcome.validate());
}
