//! Complete direct source evidence in one native metadata value. The source
//! declaration and signed grant supply repeated object/owner identities; this
//! record preserves the actual lease, interpretation and selected WAL point.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const Grant = c.DirectReadDelegation;
const P = c.storage.TablePartition;
const Self = @This();
basis: c.DirectTableReader.Basis,
/// Null denotes a captured snapshot. A history cut also binds the exact WAL
/// record, including an accepted no-op whose changed_lsn did not advance.
record: ?[32]u8,
pub const encoded_bytes = 246;

pub fn from(source: c.DirectTableProtocol.HistorySource) !Self {
    if (!std.meta.eql(source.point.lease, source.source.snapshot.handle) or !std.meta.eql(source.point.position, source.source.accepted)) return error.InvalidRelationalHistory;
    _ = try source.point.cursorSource();
    return .{ .basis = .{
        .snapshot = source.source.snapshot,
        .interpretation = source.source.interpretation,
        .accepted = source.source.accepted,
        .changed_lsn = source.source.changed_lsn,
        .row_count = source.source.row_count,
        .authority = source.source.authority,
    }, .record = source.point.commitment };
}
pub fn point(self: Self) ?P.HistoryPoint {
    return if (self.record) |commitment| .{ .lease = self.basis.snapshot.handle, .position = self.basis.accepted, .commitment = commitment } else null;
}
pub fn validate(self: Self, source: q.TableSource, grant: Grant) !void {
    var scratch: [4096]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&scratch);
    try source.requireGrant(fixed.allocator(), grant);
    const basis = self.basis;
    try basis.interpretation.validate();
    try basis.snapshot.handle.content.validate();
    try basis.authority.validate();
    try basis.accepted.validate();
    if (!std.meta.eql(basis.snapshot.object, source.interpretation.interpretation.object) or
        !std.meta.eql(basis.interpretation.interpretation.object, basis.snapshot.object) or
        basis.accepted.next_lsn == 0 or basis.changed_lsn > basis.accepted.next_lsn or
        (self.record != null) != (grant.binding.retention == .history)) return error.InvalidRelationalHistory;
    try grant.requirePin(basis.snapshot.object, basis.snapshot.handle.owner);
    if (self.point()) |selected| {
        _ = try selected.cursorSource();
        try grant.requireHistory(basis.interpretation.interpretation, basis.accepted);
    } else try grant.requireSource(basis.interpretation.interpretation, basis.accepted);
}
pub fn encode(self: Self, source: q.TableSource, grant: Grant) !p.Value {
    try self.validate(source, grant);
    const basis = self.basis;
    var bytes: [encoded_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("QHB1");
    try writer.writeAll(&p.Growth.definition_bytes);
    try writer.writeByte(@intFromBool(self.record != null));
    try writer.writeInt(u64, basis.snapshot.handle.content.bytes, .little);
    try writer.writeAll(&basis.snapshot.handle.content.sha256);
    try writer.writeInt(u64, basis.accepted.partition, .little);
    try writer.writeInt(u64, basis.accepted.next_lsn, .little);
    try writer.writeAll(&(self.record orelse @as([32]u8, @splat(0))));
    try writer.writeInt(u64, basis.interpretation.interpretation.revision, .little);
    try writer.writeAll(&basis.interpretation.interpretation.digest);
    try writer.writeInt(u64, basis.interpretation.content.bytes, .little);
    try writer.writeAll(&basis.interpretation.schema_fingerprint);
    try writer.writeByte(@intFromBool(basis.interpretation.retired));
    try writer.writeInt(u64, basis.changed_lsn, .little);
    try writer.writeInt(u64, basis.row_count, .little);
    inline for (.{ "database", "schema", "table" }) |field| try writer.writeInt(u64, @field(basis.authority, field), .little);
    std.debug.assert(writer.end == encoded_bytes);
    return p.Value.init(&bytes);
}
pub fn decode(source: q.TableSource, grant: Grant, value: p.Value) !Self {
    try value.validate();
    if (value.len != encoded_bytes) return error.InvalidRelationalHistory;
    var reader: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(4), "QHB1")) return error.InvalidRelationalHistory;
    if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const history = try reader.takeByte();
    if (history > 1) return error.InvalidRelationalHistory;
    const content: p.DataLifecycle.Content = .{ .bytes = try reader.takeInt(u64, .little), .sha256 = (try reader.takeArray(32)).* };
    const accepted: p.DataLifecycle.Position = .{ .partition = try reader.takeInt(u64, .little), .next_lsn = try reader.takeInt(u64, .little) };
    const commitment = (try reader.takeArray(32)).*;
    if (history == 0 and !std.mem.allEqual(u8, &commitment, 0)) return error.InvalidRelationalHistory;
    const interpretation: p.DataLifecycle.Definition = .{ .object = source.interpretation.interpretation.object, .revision = try reader.takeInt(u64, .little), .digest = (try reader.takeArray(32)).* };
    const declaration_bytes = try reader.takeInt(u64, .little);
    const schema = (try reader.takeArray(32)).*;
    const retired = try reader.takeByte();
    if (retired > 1) return error.InvalidRelationalHistory;
    const result: Self = .{ .basis = .{
        .snapshot = .{ .object = interpretation.object, .handle = .{ .owner = grant.binding.owner, .content = content } },
        .interpretation = .{ .interpretation = interpretation, .content = .{ .bytes = declaration_bytes, .sha256 = interpretation.digest }, .schema_fingerprint = schema, .retired = retired == 1 },
        .accepted = accepted,
        .changed_lsn = try reader.takeInt(u64, .little),
        .row_count = try reader.takeInt(u64, .little),
        .authority = .{ .database = try reader.takeInt(u64, .little), .schema = try reader.takeInt(u64, .little), .table = try reader.takeInt(u64, .little) },
    }, .record = if (history == 1) commitment else null };
    if (!(try result.encode(source, grant)).eql(value)) return error.InvalidRelationalHistory;
    return result;
}
/// This includes full source/lease coordinates and interpretation independently
/// of the native resource holding computation progress.
pub fn fingerprint(self: Self) ![32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.retained-history-source.v1\x00");
    hash.update(&try self.basis.fingerprint());
    hash.update(&.{@intFromBool(self.record != null)});
    if (self.record) |commitment| hash.update(&commitment);
    return hash.finalResult();
}

test "direct history records retain full-width cuts and no-op commitments in one native value" {
    const t = std.testing;
    const full = std.math.maxInt(u64);
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = p.max_counter, .resource = p.max_counter, .catalog = full }, .branch = 1, .audience = p.max_counter, .principal = p.max_counter, .role = null };
    const schema: q.fuze.TableSchema.Schema = .{ .object = full, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "value", .type = .int64 }} };
    var declaration = try c.storage.TableDeclaration.prepare(t.allocator, .{ .object = .{ .scope = connection.scope, .branch = 1, .object = full }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const source: q.TableSource = .{ .scope = connection.scope, .owner = connection.audience, .branch = 1, .namespace = 1, .object = full, .interpretation = try declaration.stored(), .row_type = try schema.rowType(&fields) };
    var binding: Grant.Binding = .{ .definition = p.Growth.current_definition, .connection = connection, .executor = p.max_counter, .interpretation = source.interpretation.interpretation, .expected = .{ .partition = full, .next_lsn = full - 1 }, .owner = .{ .scope = connection.scope, .principal = connection.principal, .operation = full }, .retention = .history, .purpose = @splat(3) };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(17));
    const grant: Grant = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = connection.scope.realm, .principal = connection.principal, .credential_epoch = 1, .role = null, .audience = connection.audience, .context = try binding.context(t.allocator) }, key) };
    const record: Self = .{ .basis = .{
        .snapshot = .{ .object = binding.interpretation.object, .handle = .{ .owner = binding.owner, .content = .{ .bytes = full, .sha256 = @splat(7) } } },
        .interpretation = source.interpretation,
        .accepted = .{ .partition = full, .next_lsn = full },
        .changed_lsn = full - 1,
        .row_count = full,
        .authority = .{ .database = p.max_counter, .schema = p.max_counter - 1, .table = p.max_counter - 2 },
    }, .record = @splat(9) };
    const bytes = try record.encode(source, grant);
    try t.expectEqual(@as(u16, encoded_bytes), bytes.len);
    try t.expectEqualDeep(record, try decode(source, grant, bytes));
    for (0..bytes.len) |length| {
        _ = decode(source, grant, try p.Value.init(bytes.slice()[0..length])) catch continue;
        return error.ExpectedTruncationRejection;
    }
    var corrupt = bytes;
    corrupt.data[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, decode(source, grant, corrupt));
    corrupt = bytes;
    corrupt.data[36] = 2;
    try t.expectError(error.InvalidRelationalHistory, decode(source, grant, corrupt));
    var no_op = record;
    no_op.basis.accepted.next_lsn -= 1;
    no_op.record.?[0] ^= 1;
    try no_op.validate(source, grant);
    try t.expectEqual(record.basis.changed_lsn, no_op.basis.changed_lsn);
    try t.expect(!std.mem.eql(u8, &try record.fingerprint(), &try no_op.fingerprint()));
    binding.retention = .snapshot;
    const snapshot_grant: Grant = .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = connection.scope.realm, .principal = connection.principal, .credential_epoch = 1, .role = null, .audience = connection.audience, .context = try binding.context(t.allocator) }, key) };
    try t.expectError(error.InvalidRelationalHistory, record.validate(source, snapshot_grant));
    no_op.record = null;
    try t.expectEqualDeep(no_op, try decode(source, snapshot_grant, try no_op.encode(source, snapshot_grant)));
    no_op.record = @splat(9);
    try t.expectError(error.InvalidRelationalHistory, no_op.encode(source, snapshot_grant));
}
