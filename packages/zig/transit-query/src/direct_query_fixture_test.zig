//! Offline codec/authorization inputs. These declarations and lease records do
//! not assert catalog admission or storage durability; HTTP proofs cover those.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const p = q.protocol;
const Self = @This();
arena: std.heap.ArenaAllocator,
bundle: q.RelationalBundle,
vector: q.RelationalHistory.Vector,
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.* = undefined;
}
pub fn init(allocator: std.mem.Allocator, lifetime: f.Relational.Lifetime, independent: bool) !Self {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    const sources = try alloc.alloc(q.TableSource, 2);
    const declarations = try alloc.alloc(f.Relational.Source, 2);
    const grants = try alloc.alloc(c.DirectReadDelegation, 2);
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 1, .resource = 17, .catalog = 9 }, .branch = 1, .audience = 19, .principal = 17, .role = 17 };
    for (sources, declarations, 0..) |*source, *declared, i| {
        const object: u64 = if (i == 1 and independent) 200 else 100;
        const schema: f.TableSchema.Schema = .{ .object = object, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "k", .type = .int64 }, .{ .id = 2, .name = "v", .type = .int64 } } };
        var prepared = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = object }, .revision = 1, .schema = schema, .properties = "" });
        defer prepared.deinit();
        source.* = .{ .scope = connection.scope, .owner = connection.audience, .branch = 1, .namespace = 1, .object = object, .interpretation = try prepared.stored(), .row_type = try schema.rowType(try alloc.create([f.TableSchema.max_columns]f.Types.Field)) };
        declared.* = .{ .alias = if (i == 0) "l" else "r", .realm = 1, .resource = connection.scope.resource, .catalog = 9, .owner = connection.audience, .schema = schema };
    }
    var bundle: q.RelationalBundle = .{ .sources = sources, .plan = .{ .sources = declarations, .join = .{ .kind = .left, .left = .{ .source = 0, .id = 1 }, .right = .{ .source = 1, .id = 1 } }, .outputs = &.{.{ .name = "n", .expression = .count_all }}, .lifetime = lifetime, .budgets = .{ .resident_bytes = 32 * 1024 * 1024, .spill_bytes = 32 * 1024 * 1024, .result_bytes = 1048576, .output_rows = 1000, .work_steps = 10000, .source_pins = if (independent) 2 else 1 } } };
    const purpose = try bundle.retentionPurpose(3, 7, 9, 10);
    for (grants, sources, 0..) |*grant, source, i| {
        const ordinal: u64 = if (independent) i else 0;
        const binding: c.DirectReadDelegation.Binding = .{ .definition = p.Growth.current_definition, .connection = connection, .executor = 31, .interpretation = source.interpretation.interpretation, .expected = .{ .partition = ordinal + 1, .next_lsn = 10 }, .owner = .{ .scope = connection.scope, .principal = 17, .operation = ordinal + 1000 }, .retention = if (lifetime == .maintained) .history else .snapshot, .purpose = purpose };
        grant.* = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 1, .role = 17, .audience = connection.audience, .context = try binding.context(alloc) }, try c.testing.Authority.key(17)) };
    }
    bundle.retention = grants;
    bundle = try q.testing.Store.signQuery(bundle, 17, 3, 9, 10);
    var vector: q.RelationalHistory.Vector = .{ .request = try bundle.fingerprint(), .count = 2 };
    for (vector.entries[0..2], sources, grants, 0..) |*entry, source, grant, i| entry.* = .{ .position = 10, .record = .{ .basis = .{
        .snapshot = .{ .object = grant.binding.interpretation.object, .handle = .{ .owner = grant.binding.owner, .content = .{ .bytes = 128, .sha256 = @splat(13) } } },
        .interpretation = source.interpretation,
        .accepted = grant.binding.expected,
        .changed_lsn = 8,
        .row_count = 3,
        .authority = .{ .database = 11, .schema = 12, .table = if (independent) 13 + i else 13 },
    }, .record = if (lifetime == .maintained) @splat(41) else null } };
    try vector.validate(bundle);
    return .{ .arena = arena, .bundle = bundle, .vector = vector };
}
