//! Offline direct declarations and injected read-only authority responses for
//! named publication/activation tests. This is not a Table storage owner.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const p = root.protocol;
const f = q.fuze;
const t = std.testing;
const w = c.DirectTableProtocol;

pub const connection: w.Connection = .{ .scope = .{ .realm = 1, .resource = 17, .catalog = 9 }, .branch = 1, .audience = 19, .principal = 2, .role = null };

pub fn bundle(allocator: std.mem.Allocator, lifetime: f.Relational.Lifetime) !q.RelationalBundle {
    const schema: f.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "k", .type = .int64 }, .{ .id = 2, .name = "v", .type = .int64 } } };
    var prepared = try c.storage.TableDeclaration.prepare(allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = 100 }, .revision = 1, .schema = schema, .properties = "" });
    defer prepared.deinit();
    const sources = try allocator.alloc(q.TableSource, 1);
    sources[0] = .{ .scope = connection.scope, .owner = connection.audience, .branch = 1, .namespace = 1, .object = 100, .interpretation = try prepared.stored(), .row_type = try schema.rowType(try allocator.create([f.TableSchema.max_columns]f.Types.Field)) };
    const declarations = try allocator.alloc(f.Relational.Source, 1);
    declarations[0] = .{ .alias = "i", .realm = 1, .resource = connection.scope.resource, .catalog = 9, .owner = connection.audience, .schema = schema };
    var description: q.RelationalBundle = .{ .sources = sources, .plan = .{ .sources = declarations, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = lifetime, .budgets = .{ .resident_bytes = q.RelationalMaintenance.resident_base + 8 * 1024 * 1024, .spill_bytes = 32 * 1024 * 1024, .result_bytes = 1024 * 1024, .output_rows = 1000, .work_steps = 10000, .source_pins = 1 } } };
    var original = connection;
    original.principal = 17;
    original.role = 17;
    const binding: c.DirectReadDelegation.Binding = .{ .definition = p.Growth.current_definition, .connection = original, .executor = connection.principal, .interpretation = sources[0].interpretation.interpretation, .expected = .{ .partition = 1, .next_lsn = 10 }, .owner = .{ .scope = connection.scope, .principal = 17, .operation = if (lifetime == .captured) 1000 else 1001 }, .retention = if (lifetime == .maintained) .history else .snapshot, .purpose = try description.retentionPurpose(3, 7, 3, 7) };
    const grants = try allocator.alloc(c.DirectReadDelegation, 1);
    grants[0] = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 1, .role = 17, .audience = connection.audience, .context = try binding.context(allocator) }, try c.testing.Authority.key(17)) };
    description.retention = grants;
    return q.testing.Store.signQuery(description, 17, 3, 3, 7);
}

/// Exactly two admissions, each with one executor identity query and one status
/// read. An unexpected acquisition/mutation fails this fixture.
pub fn serve(io: std.Io, listener: *std.Io.net.Server) !void {
    for (0..4) |ordinal| {
        var stream = try listener.accept(io);
        defer stream.close(io);
        var input: [4096]u8 = undefined;
        var output: [4096]u8 = undefined;
        var reader = stream.reader(io, &input);
        var writer = stream.writer(io, &output);
        var server = std.http.Server.init(&reader.interface, &writer.interface);
        var request = try server.receiveHead();
        request.head.keep_alive = false;
        try t.expectEqualStrings(if (ordinal % 2 == 0) "/v1/query" else "/table/v1", request.head.target);
        const bytes = try request.readerExpectNone(&.{}).allocRemaining(t.allocator, .limited(32768));
        defer t.allocator.free(bytes);
        const reply = if (ordinal % 2 == 0) native: {
            const parsed = try p.Json.parseFromSlice(p.Growth.SignedQuery, t.allocator, bytes);
            defer parsed.deinit();
            const query = parsed.value.query;
            try t.expectEqual(@as(u64, 2), query.principal);
            try t.expectEqual(@as(u64, 1), query.realm);
            try t.expect(query.kind == .authorization and query.kind.authorization.kind == .identity);
            const key = try c.testing.Authority.key(2);
            try p.Ed25519.Signature.fromBytes(parsed.value.signature).verify(&try p.Growth.queryDigest(query), key.public_key);
            const response: p.Growth.Response = .{ .definition = p.Growth.current_definition, .realm = 1, .position = 1, .principal_sequence = 0, .body = .{ .authorization = .{ .revision = 1, .role = 2, .body = .{ .identity = .{ .principal = 2, .login_role = 2, .credential_epoch = 1 } } } } };
            break :native try p.Json.valueAlloc(t.allocator, response);
        } else direct: {
            const parsed = try p.Json.parseFromSlice(w.Request, t.allocator, bytes);
            defer parsed.deinit();
            const value = parsed.value;
            try value.validate(t.allocator);
            try t.expect(value.action == .pin_status);
            const grant = value.delegation orelse return error.MissingDelegation;
            try value.proof.verify((try c.testing.Authority.key(2)).public_key.toBytes());
            try grant.proof.verify((try c.testing.Authority.key(17)).public_key.toBytes());
            try t.expectEqual(@as(u64, 2), grant.binding.executor);
            try t.expectEqual(@as(u64, if (ordinal == 1) 1000 else 1001), grant.binding.owner.operation);
            const claim = grant.proof.claim;
            const response: w.Response = .{ .definition = p.Growth.current_definition, .context = try w.Request.context(value.input(), t.allocator), .policy_revision = 1, .subject = .{ .principal = claim.principal, .login_role = 17, .role = 17, .credential_epoch = claim.credential_epoch, .audience = claim.audience, .context = claim.context }, .result = .{ .pin_state = .{ .interpretation = grant.binding.interpretation, .position = grant.binding.expected, .retired = false, .handle = null, .released = false, .authority = .{ .database = 4, .schema = 5, .table = 23 } } } };
            break :direct try p.Json.valueAlloc(t.allocator, response);
        };
        defer t.allocator.free(reply);
        try request.respond(reply, .{ .status = .ok, .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }} });
    }
}
