const std = @import("std");
const t = std.testing;
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const s = root.station;
const f = q.fuze;
const r = root.NamedRelationalRecords;
const Store = q.testing.Store;
const DirectFixture = @import("named_relational_fixture_test.zig");
const owner: root.NamedRelational = .{ .configuration = .{ .scope = .{ .realm = 1, .resource = 7, .owner = 3, .namespace = 55 }, .administrator = 17, .records = 4096, .bytes = 32 * 1024 * 1024 } };
fn turn(store: *Store) !s.Turn {
    var result = try store.capture();
    result.delivery.input.origin = .{ .external = .{ .principal = 17, .policy_revision = 1 } };
    return result;
}
fn setup(store: *Store) !void {
    var input = try turn(store);
    try owner.initialize(&input);
    try store.commit(input);
}
fn upload(store: *Store, bundle: q.RelationalBundle) !s.PublicationReference {
    const ref = try bundle.reference(store.resource, store.input);
    var buffer: [q.RelationalBundle.max_bytes]u8 = undefined;
    const body = try bundle.encode(&buffer);
    for (0..1000) |_| {
        var input = try turn(store);
        const ready = try s.PublicationUpload.step(&input, .{ .domain = .query_request, .namespace = ref.namespace, .identity_key = q.RelationalRecords.key('u', ref.namespace, 0), .identity = try ref.encode(), .limits = .{ .record_bytes = q.RelationalBundle.max_bytes, .staging_bytes = q.RelationalBundle.max_bytes, .staging_records = 1 }, .records = &.{.{ .id = 1, .spec = ref.spec, .bytes = body }} });
        try store.commit(input);
        if (ready) return ref;
    }
    return error.UnfinishedFixture;
}
fn empty(input: s.Turn) !void {
    for (input.decision.mutations) |slot| try t.expect(slot == null);
    for (input.decision.retain) |slot| try t.expect(slot == null);
    for (input.decision.outputs) |slot| try t.expect(slot == null);
}
test "named references require current definition, canonical names and exact bounded identity" {
    const name = try r.Name.init("abcdefghijklmnopqrstu");
    try t.expectEqual(@as(usize, 32), (try r.nameKey(std.math.maxInt(u64), name)).len);
    for ([_][]const u8{ "", "1name", "has space", "utf8_é", "abcdefghijklmnopqrstuvwxyz" }) |text| try t.expectError(error.InvalidNamedQuery, r.Name.init(text));
    const ref: r.Reference = .{ .definition = root.protocol.Growth.current_definition, .identity = .{ .scope = owner.configuration.scope, .name = name, .object = std.math.maxInt(u64), .revision = 1 }, .digest = @splat(0xab) };
    const encoded = try ref.encode();
    try t.expectEqual(@as(usize, 138), encoded.len);
    try t.expectEqualDeep(ref, try r.Reference.decode(encoded));
    const json = try root.protocol.Json.valueAlloc(t.allocator, ref);
    defer t.allocator.free(json);
    const comma = std.mem.indexOfScalar(u8, json, ',').?;
    const missing = try std.mem.concat(t.allocator, u8, &.{ "{", json[comma + 1 ..] });
    defer t.allocator.free(missing);
    try t.expectError(error.MissingField, root.protocol.Json.parseFromSlice(r.Reference, t.allocator, missing));
    var corrupt = encoded;
    corrupt.data[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, r.Reference.decode(corrupt));
    corrupt = encoded;
    corrupt.data[corrupt.len] = 0;
    corrupt.len += 1;
    try t.expectError(error.InvalidNamedQuery, r.Reference.decode(corrupt));
}
test "publication and conditional authorization retain original names without starting work" {
    var store: Store = .{};
    defer store.deinit();
    try setup(&store);
    var input = try turn(&store);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var threaded: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4) });
    defer threaded.deinit();
    const io = threaded.io();
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", 0)).listen(io, .{ .reuse_address = true });
    defer listener.deinit(io);
    const url = try std.fmt.allocPrint(arena.allocator(), "http://127.0.0.1:{d}", .{listener.socket.address.getPort()});
    var task = try io.concurrent(DirectFixture.serve, .{ io, &listener });
    defer _ = task.cancel(io) catch {};
    var wire = q.wire.Client.init(t.allocator, io, url);
    defer wire.deinit();
    wire.timeout_ms = 3000;
    const clients = [_]c.DirectTableClient{.{ .allocator = t.allocator, .authority = &wire, .service = &wire, .connection = DirectFixture.connection, .key = try c.testing.Authority.key(2) }};
    const workspace = try t.allocator.alloc(u8, 4 * 1024 * 1024);
    defer t.allocator.free(workspace);
    const bundle = try DirectFixture.bundle(arena.allocator(), .captured);
    const request = try upload(&store, bundle);
    const proposal: root.NamedRelational.Proposal = .{ .name = try r.Name.init("totals"), .object = 1001, .expected = 0, .peer = 3, .request = request };
    // Allocation and quota failure discard pins and every partial write.
    input = try turn(&store);
    try t.expectError(error.OutOfMemory, owner.publish(&input, proposal, &.{}));
    try empty(input);
    var tight = owner;
    tight.configuration.scope.namespace = 56;
    tight.configuration.records = 2;
    tight.configuration.bytes = 144;
    try tight.initialize(&input);
    try store.commit(input);
    input = try turn(&store);
    try t.expectError(error.NamedQueryQuota, tight.publish(&input, proposal, workspace));
    try empty(input);
    try t.expectEqualDeep(r.Budget{ .records = 2, .bytes = 144 }, try tight.budget(&input));
    input = try turn(&store);
    input.delivery.input.origin.external.principal = 18;
    try t.expectError(error.NamedQueryDenied, owner.publish(&input, proposal, workspace));
    try empty(input);
    input = try turn(&store);
    const first = try owner.publish(&input, proposal, workspace);
    for (input.decision.outputs) |slot| try t.expect(slot == null);
    try t.expect(try q.RelationalCapture.policy(&input, 3) == null);
    try store.commit(input);
    const original_pins = store.versions.count();
    input = try turn(&store);
    const original_budget = try owner.budget(&input);
    try t.expectEqualDeep(first, try owner.publish(&input, proposal, workspace));
    try empty(input);
    try t.expectEqual(original_pins, store.versions.count());
    // No policy was installed by publication: activation still fails closed.
    const activation: r.Activation = .{ .reference = first, .policy_revision = 1 };
    input.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    input.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 700, .payload = try activation.encode() }).encode();
    try t.expectError(error.NamedQueryNotFound, owner.activate(&input, activation, &clients, workspace));
    try empty(input);
    input = try turn(&store);
    const permitted = try owner.authorize(&input, first, 0, 17, true);
    try store.commit(input);
    input = try turn(&store);
    try t.expectEqualDeep(permitted, try owner.authorize(&input, first, 0, 17, true));
    try empty(input);
    try t.expectError(error.NamedQueryConflict, owner.authorize(&input, first, 0, 18, true));
    try empty(input);
    // A second definition changes lifetime; the original permission/attribution
    // remains attached to the original immutable revision.
    const next_bundle = try DirectFixture.bundle(arena.allocator(), .maintained);
    const next_request = try upload(&store, next_bundle);
    var replacement = proposal;
    replacement.expected = 1;
    replacement.request = next_request;
    input = try turn(&store);
    const second = try owner.publish(&input, replacement, workspace);
    try store.commit(input);
    input = try turn(&store);
    try t.expectEqualDeep(second, (try owner.lookup(&input, proposal.name)).?);
    try t.expectEqualDeep(first, try owner.publish(&input, proposal, workspace));
    try empty(input);
    try t.expectEqualDeep(first, try owner.attribution(&input, 3, 1));
    try t.expectEqual(.captured, (try owner.definition(&input, first)).lifetime);
    try t.expectEqual(.maintained, (try owner.definition(&input, second)).lifetime);
    var collision = proposal;
    collision.name = try r.Name.init("other_name");
    try t.expectError(error.NamedQueryConflict, owner.publish(&input, collision, workspace));
    try empty(input);
    input.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    input.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 700, .payload = try permitted.encode() }).encode();
    const started = try owner.activate(&input, permitted, &clients, workspace);
    try t.expectEqual(first.identity.revision, started.captured.policy_revision);
    try t.expectEqualDeep(request, started.captured.request);
    try store.commit(input);
    // Explicit policy replacement denies old work without rewriting its name.
    input = try turn(&store);
    const next = try owner.authorize(&input, second, 1, 17, true);
    try store.commit(input);
    input = try turn(&store);
    input.delivery.input.origin = .{ .process = .{ .pid = 3, .turn = 1, .output = 0 } };
    input.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 701, .payload = try permitted.encode() }).encode();
    try t.expectError(error.QueryDenied, owner.activate(&input, permitted, &clients, workspace));
    try empty(input);
    input.delivery.input.value = try (s.Frame{ .kind = .call, .correlation = 701, .payload = try next.encode() }).encode();
    const maintained = try owner.activate(&input, next, &clients, workspace);
    try t.expectEqualDeep(next_request, maintained.maintained.request);
    try store.commit(input);
    input = try turn(&store);
    try t.expectEqualDeep(first, try owner.attribution(&input, 3, started.captured.policy_revision));
    try t.expect((try owner.budget(&input)).bytes > original_budget.bytes);
    // Histories grow beyond native read/cache pages without an in-memory list.
    // Every revision remains addressable and only three mutations publish it.
    var next_proposal = replacement;
    for (2..67) |expected| {
        next_proposal.expected = expected;
        input = try turn(&store);
        const revision = try owner.publish(&input, next_proposal, workspace);
        try t.expectEqual(expected + 1, revision.identity.revision);
        var writes: usize = 0;
        for (input.decision.mutations) |slot| if (slot != null) {
            writes += 1;
        };
        try t.expectEqual(@as(usize, 3), writes);
        try store.commit(input);
    }
    input = try turn(&store);
    try t.expectEqualDeep(first, try owner.publish(&input, proposal, workspace));
    try empty(input);
    try t.expectEqualDeep(first, try owner.attribution(&input, 3, 1));
    try t.expectEqualDeep(permitted, try owner.authorize(&input, first, 0, 17, true));
    try empty(input);
    try t.expectEqual(@as(u64, 2), (try q.RelationalCapture.policy(&input, 3)).?.revision);
    store.denied = true;
    input = try turn(&store);
    try t.expectError(error.AccessDenied, owner.lookup(&input, proposal.name));
    try task.await(io);
}

test "independent named relational records preserve uint64 identities and reject malformed saved work" {
    const Fixture = struct { definition: root.protocol.Growth.Definition, record: root.protocol.Value, reference: root.protocol.Value, digest: root.protocol.Value, archive: root.protocol.Value, activation: root.protocol.Value, configuration: root.protocol.Value, budget: root.protocol.Value, initialize: root.protocol.Value, publish: root.protocol.Value, authorize: root.protocol.Value, name_key: root.protocol.Value, definition_key: root.protocol.Value, authorization_key: root.protocol.Value };
    const fixture = try root.protocol.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/named-relational-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    const definition = try r.decodeRecord(r.Definition, "NRD1", value.record);
    try definition.validate();
    const reference = try definition.reference();
    try t.expectEqual(@as(u64, std.math.maxInt(u64) - 1), reference.identity.object);
    try t.expect(value.reference.eql(try reference.encode()));
    try t.expectEqualSlices(u8, value.digest.slice(), &reference.digest);
    try t.expect(value.name_key.eql(try r.nameKey(reference.identity.scope.namespace, reference.identity.name)));
    try t.expect(value.definition_key.eql(r.definitionKey(reference.identity)));
    try t.expect(value.authorization_key.eql(r.authorizationKey(3, 19)));
    inline for (.{ .{ "NRD1", "record", r.Definition }, .{ "NRP1", "archive", r.Authorization }, .{ "NRC1", "configuration", r.Configuration }, .{ "NRB1", "budget", r.Budget } }) |item| {
        const bytes = @field(value, item[1]);
        const decoded = try r.decodeRecord(item[2], item[0], bytes);
        try t.expect(bytes.eql(try r.encodeRecord(item[0], decoded)));
        for (0..bytes.len) |cut| {
            const truncated = try root.protocol.Value.init(bytes.slice()[0..cut]);
            if (r.decodeRecord(item[2], item[0], truncated)) |_| return error.AcceptedIncompleteRecord else |_| {}
        }
        var incompatible = bytes;
        incompatible.data[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, r.decodeRecord(item[2], item[0], incompatible));
    }
    const activation = try r.Activation.decode(value.activation);
    try t.expectEqualDeep(reference, activation.reference);
    try t.expectEqual(@as(u64, 19), activation.policy_revision);
    try t.expect(value.activation.eql(try activation.encode()));
    for ([_]root.protocol.Value{ value.initialize, value.publish, value.authorize }) |bytes| {
        try t.expect(bytes.eql(try (try r.Control.decode(bytes)).encode()));
        _ = try (s.Frame{ .kind = .cast, .payload = bytes }).encode();
    }
}
