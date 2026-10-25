//! Frozen multi-Table request. Explicit catalog metadata and schemas travel with
//! the typed plan; neither source text nor a later live name supplies a binding.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const Pub = q.station.Publication;
const Ref = q.station.PublicationReference;
const Self = @This();
const Grant = q.catalog.DirectReadDelegation;
pub const format: u32 = 0x31425152;
pub const max_bytes = 44 + q.QueryAuthorization.encoded_bytes + f.RelationalCodec.max_bytes + r.max_sources * (4 + q.TableSource.max_bytes + Grant.encoded_bytes);
consistency: q.DirectRelationalQuery.Consistency = .independent_table_snapshots,
plan: r.Plan,
sources: []const q.TableSource,
authorization: ?q.QueryAuthorization = null,
retention: []const Grant = &.{},
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    bundle: Self,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn validate(self: Self) !void {
    if (self.authorization) |value| try value.validate();
    try self.plan.validate();
    if (self.consistency != .independent_table_snapshots) return error.UnsupportedRelationalConsistency;
    if (self.plan.lifetime == .interactive or self.sources.len != self.plan.sources.len) return error.InvalidRelationalSources;
    if (self.retention.len != 0 and self.retention.len != self.sources.len) return error.InvalidRelationalSources;
    if (self.authorization != null and self.retention.len != self.sources.len) return error.QueryCaptureRequired;
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var pins: u8 = 0;
    for (self.sources, self.plan.sources, 0..) |source, declared, i| {
        try source.validate();
        if (source.scope.realm != declared.realm or source.scope.resource != declared.resource or source.scope.catalog != declared.catalog or source.owner != declared.owner or source.object != declared.schema.object or !try source.row_type.eql(try declared.schema.rowType(&fields)) or
            !std.mem.eql(u8, &source.interpretation.schema_fingerprint, &try declared.schema.fingerprint())) return error.RelationalSourceChanged;
        const original = try self.sourceOrdinal(i);
        if (original == i) pins += 1;
        if (self.retention.len != 0) {
            const grant = self.retention[i];
            if ((grant.binding.retention == .history) != (self.plan.lifetime == .maintained)) return error.InvalidQueryBundle;
            var storage: [4096]u8 = undefined;
            var fixed: std.heap.FixedBufferAllocator = .init(&storage);
            try source.requireGrant(fixed.allocator(), grant);
            if (original != i and !std.meta.eql(self.retention[original], grant)) return error.InconsistentRelationalCut;
            for (self.retention[0..i], 0..) |earlier, j| {
                if (grant.binding.executor != earlier.binding.executor) return error.QueryDenied;
                if (try self.sourceOrdinal(j) != original and std.meta.eql(grant.binding.owner, earlier.binding.owner)) return error.QueryNamespaceInUse;
            }
            if (self.authorization) |authorization| {
                const claim = authorization.proof.claim;
                const retained = grant.proof.claim;
                if (claim.realm != retained.realm or claim.principal != retained.principal or claim.role != retained.role or claim.credential_epoch != retained.credential_epoch) return error.QueryDenied;
            }
        }
    }
    if (self.plan.budgets.source_pins < pins) return error.InvalidRelationalBudgets;
}
/// Aliases of one exact Table share a pin, independently of catalog resource.
pub fn sourceOrdinal(self: Self, index: usize) !u32 {
    if (index >= self.sources.len) return error.InvalidRelationalSources;
    const source = self.sources[index];
    for (self.sources[0..index], 0..) |earlier, i| {
        if (!std.meta.eql(source.interpretation.interpretation.object, earlier.interpretation.interpretation.object)) continue;
        if (!std.mem.eql(u8, &try source.fingerprint(), &try earlier.fingerprint())) return error.InconsistentRelationalCut;
        return @intCast(i);
    }
    return @intCast(index);
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("RQB1");
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    try writer.writeByte(2); // independent Table cuts, never catalog-wide atomic
    try writer.writeByte(@intCast(self.sources.len));
    var plan_bytes: [f.RelationalCodec.max_bytes]u8 = undefined;
    const encoded = try f.RelationalCodec.encode(self.plan, &plan_bytes);
    try writer.writeInt(u32, @intCast(encoded.len), .little);
    try writer.writeAll(encoded);
    try q.QueryAuthorization.write(self.authorization, &writer);
    try writer.writeByte(@intCast(self.retention.len));
    for (self.retention) |grant| {
        var storage: [4096]u8 = undefined;
        var fixed: std.heap.FixedBufferAllocator = .init(&storage);
        try writer.writeAll(&try grant.encode(fixed.allocator()));
    }
    var source_bytes: [q.TableSource.max_bytes]u8 = undefined;
    for (self.sources) |source| {
        const bytes = try source.encode(&source_bytes);
        try writer.writeInt(u32, @intCast(bytes.len), .little);
        try writer.writeAll(bytes);
    }
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    return .{ .bundle = try decodeInto(arena.allocator(), bytes), .arena = arena };
}
/// The supplied arena owns all nested schemas and source descriptors.
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.QueryBundleTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "RQB1")) return error.InvalidQueryBundle;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    if (try reader.takeByte() != 2) return error.UnsupportedRelationalConsistency;
    const count = try reader.takeByte();
    if (count == 0 or count > r.max_sources) return error.InvalidRelationalSources;
    const plan = try f.RelationalCodec.decodeInto(arena, try reader.take(try reader.takeInt(u32, .little)));
    const authorization = try q.QueryAuthorization.read(&reader);
    const retained = try reader.takeByte();
    if (retained != 0 and retained != count) return error.InvalidRelationalSources;
    const retention = try arena.alloc(Grant, retained);
    for (retention) |*grant| grant.* = try Grant.decode(arena, try reader.take(Grant.encoded_bytes));
    const sources = try arena.alloc(q.TableSource, count);
    for (sources) |*source| source.* = try q.TableSource.decodeInto(arena, try reader.take(try reader.takeInt(u32, .little)));
    if (reader.bufferedLen() != 0) return error.InvalidQueryBundle;
    const result: Self = .{ .plan = plan, .sources = sources, .authorization = authorization, .retention = retention };
    try result.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try result.encode(&canonical))) return error.InvalidQueryBundle;
    return result;
}
fn unsigned(self: Self, output: []u8) ![]const u8 {
    var description = self;
    description.authorization = null;
    return description.encode(output);
}
pub fn retentionPurpose(self: Self, worker: u64, resource: u64, requester: u64, requests: u64) ![32]u8 {
    var description = self;
    description.authorization = null;
    description.retention = &.{};
    var bytes: [max_bytes]u8 = undefined;
    var route: [32]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&route);
    for ([_]u64{ worker, resource, requester, requests }) |id| {
        try q.UnifiedRecords.identity(id);
        try writer.writeInt(u64, id, .little);
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.relational.direct-retention.v1\x00");
    hash.update(&route);
    hash.update(try description.encode(&bytes));
    return hash.finalResult();
}
/// The arena owns the immutable grants. Callers supply one route/capture per
/// source alias; aliases must repeat the same operation and expected frontier.
pub fn authorizeCapture(self: Self, allocator: std.mem.Allocator, client: q.wire.AuthorizationClient, tables: []const q.catalog.DirectTableClient, worker: u64, resource: u64, requester: u64, requests: u64, captures: []const q.Bundle.Capture) !Self {
    if (self.authorization != null or self.retention.len != 0) return error.QueryAlreadyAuthorized;
    try self.validate();
    if (tables.len != self.sources.len or captures.len != self.sources.len) return error.InvalidRelationalSources;
    const grants = try allocator.alloc(Grant, self.sources.len);
    errdefer allocator.free(grants);
    const purpose = try self.retentionPurpose(worker, resource, requester, requests);
    for (self.sources, tables, captures, 0..) |source, table, capture, i| {
        if (client.principal != table.connection.principal or client.role != table.connection.role or client.realm != table.connection.scope.realm) return error.QueryDenied;
        try source.requireConnection(table);
        const original = try self.sourceOrdinal(i);
        if (original != i) {
            if (!std.meta.eql(capture, captures[original]) or !std.meta.eql(table.connection, tables[original].connection)) return error.InconsistentRelationalCut;
            grants[i] = grants[original];
        } else grants[i] = try Grant.prepare(table, .{
            .definition = q.protocol.Growth.current_definition,
            .connection = table.connection,
            .executor = capture.executor,
            .interpretation = source.interpretation.interpretation,
            .expected = capture.expected,
            .selection = capture.selection,
            .owner = .{ .scope = table.connection.scope, .principal = table.connection.principal, .operation = capture.operation },
            .retention = if (self.plan.lifetime == .maintained) .history else .snapshot,
            .purpose = purpose,
        });
    }
    var result = self;
    result.retention = grants;
    return result.authorize(client, worker, requester, requests);
}
pub fn authorize(self: Self, client: q.wire.AuthorizationClient, audience: u64, requester: u64, requests: u64) !Self {
    if (self.authorization != null) return error.QueryAlreadyAuthorized;
    var bytes: [max_bytes]u8 = undefined;
    var result = self;
    result.authorization = try q.QueryAuthorization.prepare(client, audience, requester, requests, try self.unsigned(&bytes));
    try result.validate();
    return result;
}
pub fn subject(self: Self, audience: u64, requester: u64, requests: u64) !q.protocol.Authorization.Subject {
    const authorization = self.authorization orelse return error.QueryDenied;
    var bytes: [max_bytes]u8 = undefined;
    return authorization.subject(audience, requester, requests, try self.unsigned(&bytes));
}
pub fn bindSubject(self: Self, turn: *q.station.Turn, requester: u64, requests: u64, expected: u64) !void {
    const original = try self.subject(turn.delivery.pid, requester, requests);
    if (original.principal() != expected) return error.QueryDenied;
    const purpose = try self.retentionPurpose(turn.delivery.pid, turn.view.resource, requester, requests);
    for (self.retention) |grant| if (grant.binding.executor != turn.delivery.principal or !std.mem.eql(u8, &grant.binding.purpose, &purpose)) return error.QueryDenied;
    try turn.bindAuthorizationSubject(original);
}
pub fn fingerprint(self: Self) ![32]u8 {
    var bytes: [max_bytes]u8 = undefined;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.relational.request.v1\x00");
    hash.update(try self.encode(&bytes));
    return hash.finalResult();
}
pub fn reference(self: Self, resource: u64, namespace: u64) !Ref {
    var bytes: [max_bytes]u8 = undefined;
    const result: Ref = .{ .resource = resource, .domain = .query_request, .namespace = namespace, .record = 1, .spec = try Pub.Digest.of(format, try self.encode(&bytes)) };
    try checkReference(result);
    return result;
}
pub fn checkReference(ref: Ref) !void {
    try ref.validate();
    if (ref.domain != .query_request or ref.record != 1 or ref.spec.format != format or ref.spec.length < 44 or ref.spec.length > max_bytes) return error.InvalidQueryBundle;
}
pub fn checkPublisher(ref: Ref, source: anytype, peer: u64) !void {
    try checkReference(ref);
    var reader = try source.open(ref.resource);
    const descriptor = try ref.publication().inspect(&reader, ref.record);
    if (descriptor.state != .published or !std.meta.eql(descriptor.spec, ref.spec) or descriptor.publisher != peer) return error.UnexpectedQueryPublisher;
}

test "direct relational bundles bind exact schemas, alias pins and independent cuts" {
    const t = std.testing;
    const p = q.protocol;
    const connection: q.catalog.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .branch = 1, .audience = 19, .principal = 17, .role = null };
    const schema: f.TableSchema.Schema = .{ .object = 11, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "k", .type = .int64 }} };
    var definition = try q.catalog.storage.TableDeclaration.prepare(t.allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = schema.object }, .revision = 1, .schema = schema, .properties = "" });
    defer definition.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const source: q.TableSource = .{ .scope = connection.scope, .owner = connection.audience, .branch = 1, .namespace = 1, .object = schema.object, .interpretation = try definition.stored(), .row_type = try schema.rowType(&fields) };
    const sources = [_]q.TableSource{ source, source };
    var declarations = [_]r.Source{
        .{ .alias = "a", .realm = 1, .resource = 7, .catalog = 9, .owner = 19, .schema = schema },
        .{ .alias = "b", .realm = 1, .resource = 7, .catalog = 9, .owner = 19, .schema = schema },
    };
    var bundle: Self = .{ .plan = .{
        .sources = &declarations,
        .join = .{ .kind = .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } },
        .outputs = &.{.{ .name = "n", .expression = .count_all }},
        .lifetime = .captured,
        .budgets = .{ .resident_bytes = 8 * 1024 * 1024, .spill_bytes = 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 100, .source_pins = 1 },
    }, .sources = &sources };
    try bundle.validate();
    try t.expectEqual(@as(u32, 0), try bundle.sourceOrdinal(1));
    const purpose = try bundle.retentionPurpose(23, 29, 31, 37);
    const binding: Grant.Binding = .{ .definition = p.Growth.current_definition, .connection = connection, .executor = 41, .interpretation = source.interpretation.interpretation, .expected = .{ .partition = std.math.maxInt(u64), .next_lsn = std.math.maxInt(u64) }, .owner = .{ .scope = connection.scope, .principal = 17, .operation = std.math.maxInt(u64) }, .retention = .snapshot, .purpose = purpose };
    const key_pair = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const grant: Grant = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 3, .role = null, .audience = 19, .context = try binding.context(t.allocator) }, key_pair) };
    var grants = [_]Grant{ grant, grant };
    bundle.retention = &grants;
    var bytes: [max_bytes]u8 = undefined;
    const unsigned_bytes = try bundle.encode(&bytes);
    bundle.authorization = .{ .requester = 31, .requests = 37, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 3, .role = null, .audience = 23, .context = try q.QueryAuthorization.context(31, 37, unsigned_bytes) }, key_pair) };
    var decoded = try decode(t.allocator, try bundle.encode(&bytes));
    defer decoded.deinit();
    try t.expectEqualSlices(u8, &try bundle.fingerprint(), &try decoded.bundle.fingerprint());
    const encoded = try bundle.encode(&bytes);
    for (0..encoded.len) |size| {
        if (decode(t.allocator, encoded[0..size])) |value| {
            var incomplete = value;
            incomplete.deinit();
            return error.AcceptedIncompleteBundle;
        } else |_| {}
    }
    bytes[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(t.allocator, encoded));
    bytes[4] ^= 1;
    try (try decoded.bundle.subject(23, 31, 37)).signed.verify(key_pair.public_key.toBytes());
    try t.expectError(error.QueryDenied, decoded.bundle.subject(23, 31, 38));
    try t.expectEqualSlices(u8, &purpose, &try bundle.retentionPurpose(23, 29, 31, 37));
    try t.expect(!std.mem.eql(u8, &purpose, &try bundle.retentionPurpose(23, 30, 31, 37)));
    var vector: q.RelationalCaptured.Vector = .{ .request = try bundle.fingerprint(), .count = 2, .entries = @splat(.{ .partition = binding.expected.partition, .position = binding.expected.next_lsn, .commitment = @splat(11) }) };
    try t.expectEqualDeep(vector, try q.RelationalCaptured.Vector.decode(bundle, try vector.encode(bundle)));
    var cuts: [r.max_sources]r.Cut = undefined;
    try vector.boundCuts(bundle, &cuts);
    try t.expectEqualDeep(cuts[0], cuts[1]);
    vector.entries[1].position -= 1;
    try t.expectError(error.InconsistentRelationalCut, vector.encode(bundle));
    declarations[1].schema.revision += 1;
    try t.expectError(error.RelationalSourceChanged, bundle.validate());
    declarations[1].schema.revision -= 1;
    grants[1].binding.owner.operation -= 1;
    grants[1].proof.claim.context = try grants[1].binding.context(t.allocator);
    try t.expectError(error.InconsistentRelationalCut, bundle.validate());
    grants[1] = grant;
    bundle.authorization.?.proof.claim.credential_epoch += 1;
    try t.expectError(error.QueryDenied, bundle.validate());
    bundle.authorization.?.proof.claim.credential_epoch -= 1;
    bundle.retention = &.{};
    try t.expectError(error.QueryCaptureRequired, bundle.validate());
}

test "direct relational cuts in one catalog require distinct pins and bounded source budgets" {
    const t = std.testing;
    const connection: q.catalog.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .branch = 1, .audience = 19, .principal = 17, .role = null };
    var schemas = [_]f.TableSchema.Schema{
        .{ .object = 11, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "k", .type = .int64 }} },
        .{ .object = 12, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "k", .type = .int64 }} },
    };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var declarations: [2]r.Source = undefined;
    var sources: [2]q.TableSource = undefined;
    var fields: [2][f.TableSchema.max_columns]f.Types.Field = undefined;
    for (&schemas, 0..) |schema, i| {
        var definition = try q.catalog.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = schema.object }, .revision = 1, .schema = schema, .properties = "" });
        defer definition.deinit();
        sources[i] = .{ .scope = connection.scope, .owner = connection.audience, .branch = 1, .namespace = 1, .object = schema.object, .interpretation = try definition.stored(), .row_type = try schema.rowType(&fields[i]) };
        declarations[i] = .{ .alias = if (i == 0) "a" else "b", .realm = 1, .resource = 7, .catalog = 9, .owner = 19, .schema = schema };
    }
    var bundle: Self = .{ .sources = &sources, .plan = .{ .sources = &declarations, .join = .{ .kind = .inner, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = .captured, .budgets = .{ .resident_bytes = 8 * 1024 * 1024, .spill_bytes = 1024, .result_bytes = 1024, .output_rows = 10, .work_steps = 100, .source_pins = 1 } } };
    try t.expectError(error.InvalidRelationalBudgets, bundle.validate());
    bundle.plan.budgets.source_pins = 2;
    try bundle.validate();
    const vector: q.RelationalCaptured.Vector = .{ .request = try bundle.fingerprint(), .count = 2, .entries = .{
        .{ .partition = 100, .position = std.math.maxInt(u64), .commitment = @splat(11) },
        .{ .partition = 200, .position = 17, .commitment = @splat(12) },
    } };
    var cuts: [r.max_sources]r.Cut = undefined;
    try vector.boundCuts(bundle, &cuts);
    try t.expectEqual(cuts[0].resource, cuts[1].resource);
    try t.expect(cuts[0].domain.table_partition.object != cuts[1].domain.table_partition.object);
    try t.expect(cuts[0].revision != cuts[1].revision);
    var grants: [2]Grant = undefined;
    const key_pair = try q.protocol.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const purpose = try bundle.retentionPurpose(23, 29, 31, 37);
    for (&grants, sources, vector.entries) |*grant, source, cut| {
        const binding: Grant.Binding = .{ .definition = q.protocol.Growth.current_definition, .connection = connection, .executor = 41, .interpretation = source.interpretation.interpretation, .expected = .{ .partition = cut.partition, .next_lsn = cut.position }, .owner = .{ .scope = connection.scope, .principal = 17, .operation = 43 }, .retention = .snapshot, .purpose = purpose };
        grant.* = .{ .binding = binding, .proof = try q.protocol.Authorization.Proof.sign(.{ .definition = q.protocol.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 3, .role = null, .audience = 19, .context = try binding.context(alloc) }, key_pair) };
    }
    bundle.retention = &grants;
    try t.expectError(error.QueryNamespaceInUse, bundle.validate());
    grants[1].binding.owner.operation += 1;
    grants[1].proof.claim.context = try grants[1].binding.context(alloc);
    grants[1].proof = try q.protocol.Authorization.Proof.sign(grants[1].proof.claim, key_pair);
    try bundle.validate();
}
