//! An exact direct Table declaration and bounded retained-source traversal.
//! The computation owns pin admission/closure and native publication guards.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const t = f.Types;
const w = c.DirectTableProtocol;
const d = q.protocol.DataLifecycle;
const Self = @This();
pub const max_bytes = 178 + t.max_encoding_bytes + f.TableSchema.max_columns + c.DirectHistory.Selector.text_bytes + 56 + 194;
scope: d.Scope,
/// The explicitly configured Table service audience, independent of query PID.
owner: u64,
branch: u64,
namespace: u64,
object: u64,
interpretation: c.storage.TableDeclaration.Stored,
row_type: t.Type,
collations: f.QueryCollations = .{},
semantics: []const f.ColumnSemantics = &.{},
/// Published catalog attribution and the exact original retained source. It is
/// not a pin acquired by this descriptor and does not confer read permission.
historical: ?Historical = null,
projection: ?c.DirectSchemaProjection.Accepted = null,
pub const Historical = struct {
    snapshot: d.Snapshot,
    accepted: d.Position,
    pin: d.Content,
    pub fn handle(self: Historical) c.storage.TablePartition.SnapshotHandle {
        return .{ .owner = self.snapshot.owner, .content = self.pin };
    }
};

pub const Owned = struct {
    descriptor: t.Decoded,
    source: Self,
    pub fn deinit(self: *Owned) void {
        self.descriptor.deinit();
        self.* = undefined;
    }
};
pub fn validate(self: Self) !void {
    try self.scope.validate();
    try c.Model.nativeId(self.owner);
    try c.Model.nativeId(self.namespace);
    try self.interpretation.validate();
    if (self.interpretation.kind != .table) return error.InvalidQuerySource;
    const object: d.Object = .{ .scope = self.scope, .branch = self.branch, .object = self.object };
    if (!std.meta.eql(object, self.interpretation.interpretation.object) or self.interpretation.retired) return error.InvalidQuerySource;
    if (self.historical) |history| {
        try history.snapshot.validate();
        if (history.snapshot.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
        try history.pin.validate();
        try history.snapshot.requireSource(.{ .interpretation = self.interpretation.interpretation, .manifest = null, .checkpoint_lsn = 0, .accepted = history.accepted });
    }
    if (self.projection) |target| {
        _ = try target.encode();
        if (self.historical == null or !std.meta.eql(target.declaration.interpretation.object, self.interpretation.interpretation.object) or target.declaration.interpretation.revision < self.interpretation.interpretation.revision) return error.InvalidSchemaProjection;
    }
    try self.row_type.validate(.{});
    try self.collations.validate(self.row_type);
    if (self.row_type != .structure or (self.semantics.len != 0 and self.semantics.len != self.row_type.structure.len)) return error.InvalidColumnSemantics;
    for (self.semantics, 0..) |value, i| try value.validate(self.row_type.structure[i].type);
    if (self.row_type != .structure or self.row_type.structure.len == 0 or self.row_type.structure.len > f.TableSchema.max_columns) return error.InvalidQuerySource;
}
/// Copy the admitted schema. The interpretation commits physical descriptors,
/// stable column IDs, keys and catalog properties as well as logical types.
pub fn from(allocator: std.mem.Allocator, connection: w.Connection, definition: w.Definition) !Owned {
    try connection.validate();
    try connection.object(definition.interpretation.interpretation.object);
    const bytes = try definition.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var schema = try f.TableSchema.decode(allocator, bytes);
    defer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &definition.interpretation.schema_fingerprint)) return error.TableSchemaChanged;
    try q.direct.DirectTableQuery.qualify(schema.schema);
    var fields: [f.TableSchema.max_columns]t.Field = undefined;
    var descriptor = try (try schema.schema.rowType(&fields)).clone(allocator);
    errdefer descriptor.deinit();
    var present = false;
    for (schema.schema.columns) |column| present = present or !column.semantics.empty();
    const semantics: []const f.ColumnSemantics = if (present) blk: {
        const values = try descriptor.arena.allocator().alloc(f.ColumnSemantics, schema.schema.columns.len);
        for (schema.schema.columns, values) |column, *value| {
            value.* = column.semantics;
            if (value.timezone) |rules| value.timezone = try rules.cloneInto(descriptor.arena.allocator());
        }
        break :blk values;
    } else &.{};
    const source: Self = .{ .semantics = semantics, .scope = connection.scope, .owner = connection.audience, .branch = connection.branch, .namespace = definition.namespace, .object = schema.schema.object, .interpretation = definition.interpretation, .row_type = descriptor.type, .collations = .fromTable(schema.schema) };
    try source.validate();
    return .{ .descriptor = descriptor, .source = source };
}
/// The historical owner has already resolved the name and authenticated this
/// exact source. The returned descriptor owns every schema and semantic byte.
pub fn fromHistorical(allocator: std.mem.Allocator, connection: w.Connection, selected: c.DirectHistory.Source) !Owned {
    return fromHistoricalProjected(allocator, connection, selected, null);
}
pub fn fromHistoricalProjected(allocator: std.mem.Allocator, connection: w.Connection, selected: c.DirectHistory.Source, projected: ?c.DirectSchemaProjection.Prepared) !Owned {
    if (projected) |target| if (!std.meta.eql(target.source, selected.binding.declaration)) return error.InvalidSchemaProjection;
    var result = try from(allocator, connection, .{
        .interpretation = if (projected) |target| target.target.declaration else selected.binding.declaration,
        .namespace = selected.binding.namespace.id,
        .authorization = selected.binding.properties.authorization,
        .name = selected.binding.properties.name,
        .position = selected.binding.source.accepted,
        .changed_lsn = selected.changed_lsn,
        .row_count = selected.rows,
        .schema = if (projected) |target| target.schema else selected.schema,
    });
    errdefer result.deinit();
    result.source.interpretation = selected.binding.declaration;
    result.source.projection = if (projected) |target| target.target else null;
    result.source.historical = .{ .snapshot = selected.snapshot, .accepted = selected.binding.source.accepted, .pin = selected.binding.pin.?.content };
    if (!std.meta.eql(selected.binding.pin.?.owner, selected.snapshot.owner)) return error.HistoricalIdentityConflict;
    try result.source.validate();
    return result;
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    return self.encodeInner(output) catch |err| switch (err) {
        error.WriteFailed => error.SourceDefinitionTooLarge,
        else => err,
    };
}
fn encodeInner(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var type_bytes: [t.max_encoding_bytes]u8 = undefined;
    const encoded = try self.row_type.encode(&type_bytes);
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("TQS1");
    try writer.writeAll(&q.protocol.Growth.definition_bytes);
    inline for (.{ "realm", "resource", "catalog" }) |field| try writer.writeInt(u64, @field(self.scope, field), .little);
    inline for (.{ "owner", "branch", "namespace", "object" }) |field| try writer.writeInt(u64, @field(self, field), .little);
    try writer.writeInt(u64, self.interpretation.interpretation.revision, .little);
    try writer.writeAll(&self.interpretation.interpretation.digest);
    try writer.writeInt(u64, self.interpretation.content.bytes, .little);
    try writer.writeAll(&self.interpretation.schema_fingerprint);
    try writer.writeInt(u16, @intCast(encoded.len), .little);
    try writer.writeAll(encoded);
    try self.collations.write(self.row_type, &writer);
    var present = false;
    for (self.semantics) |value| present = present or !value.empty();
    try writer.writeByte(if (present) @intCast(self.semantics.len) else 0);
    if (present) for (self.semantics) |value| try value.write(&writer);
    try writer.writeByte(@intFromBool(self.historical != null));
    if (self.historical) |history| {
        var selector: [c.DirectHistory.Selector.text_bytes]u8 = undefined;
        try writer.writeAll(try c.DirectHistory.Selector.encode(history.snapshot, &selector));
        try writer.writeInt(u64, history.accepted.partition, .little);
        try writer.writeInt(u64, history.accepted.next_lsn, .little);
        try writer.writeInt(u64, history.pin.bytes, .little);
        try writer.writeAll(&history.pin.sha256);
    }
    try writer.writeByte(@intFromBool(self.projection != null));
    if (self.projection) |target| try writer.writeAll((try target.encode()).slice());
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const source = try decodeInto(arena.allocator(), bytes);
    return .{ .descriptor = .{ .arena = arena, .type = source.row_type }, .source = source };
}
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.SourceDefinitionTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "TQS1")) return error.InvalidSourceEncoding;
    if (!std.mem.eql(u8, try reader.take(32), &q.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var source: Self = .{
        .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) },
        .owner = try reader.takeInt(u64, .little),
        .branch = try reader.takeInt(u64, .little),
        .namespace = try reader.takeInt(u64, .little),
        .object = try reader.takeInt(u64, .little),
        .interpretation = undefined,
        .row_type = undefined,
    };
    const revision = try reader.takeInt(u64, .little);
    const digest = (try reader.takeArray(32)).*;
    source.interpretation = .{
        .kind = .table,
        .interpretation = .{ .object = .{ .scope = source.scope, .branch = source.branch, .object = source.object }, .revision = revision, .digest = digest },
        .content = .{ .bytes = try reader.takeInt(u64, .little), .sha256 = digest },
        .schema_fingerprint = (try reader.takeArray(32)).*,
        .retired = false,
    };
    const type_bytes = try reader.take(try reader.takeInt(u16, .little));
    source.row_type = try t.decodeInto(arena, type_bytes);
    source.collations = try f.QueryCollations.read(source.row_type, &reader);
    const semantic_count = try reader.takeByte();
    if (semantic_count != 0 and semantic_count != source.row_type.structure.len) return error.InvalidColumnSemantics;
    const semantics = try arena.alloc(f.ColumnSemantics, semantic_count);
    for (semantics) |*value| value.* = try f.ColumnSemantics.read(arena, &reader);
    source.semantics = semantics;
    source.historical = switch (try reader.takeByte()) {
        0 => null,
        1 => .{ .snapshot = try c.DirectHistory.Selector.decode(try reader.take(c.DirectHistory.Selector.text_bytes)), .accepted = .{ .partition = try reader.takeInt(u64, .little), .next_lsn = try reader.takeInt(u64, .little) }, .pin = .{ .bytes = try reader.takeInt(u64, .little), .sha256 = (try reader.takeArray(32)).* } },
        else => return error.InvalidSourceEncoding,
    };
    source.projection = switch (try reader.takeByte()) {
        0 => null,
        1 => try c.DirectSchemaProjection.Accepted.decode(try c.storage.TreeStore.pages.Value.init(try reader.take(194))),
        else => return error.InvalidSourceEncoding,
    };
    if (reader.bufferedLen() != 0) return error.InvalidSourceEncoding;
    try source.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, try source.encode(&canonical), bytes)) return error.InvalidSourceEncoding;
    return source;
}
pub fn fingerprint(self: Self) ![32]u8 {
    var buffer: [max_bytes]u8 = undefined;
    var digest: std.crypto.hash.sha2.Sha256 = .init(.{});
    digest.update("transit.table.query.declaration.v1\x00");
    digest.update(try self.encode(&buffer));
    return digest.finalResult();
}
pub fn requireConnection(self: Self, client: c.DirectTableClient) !void {
    try self.validate();
    if (!std.meta.eql(client.connection.scope, self.scope) or client.connection.branch != self.branch or client.connection.audience != self.owner) return error.CatalogScopeChanged;
}
/// New work requires the exact current interpretation. Retained reads instead
/// check the original pin, so ALTER/DROP cannot substitute their newer schema.
pub fn checkDefinition(self: Self, client: c.DirectTableClient) !void {
    try self.requireConnection(client);
    if (self.historical) |history| {
        const response = try c.DirectHistory.call(client, .{ .source = .{ .snapshot = history.snapshot, .object = self.object, .rows = false } });
        defer response.deinit();
        const projected = if (self.projection) |target| try c.DirectSchemaProjection.call(client, .{ .prepare = .{ .source = self.interpretation, .target = target.declaration } }) else null;
        defer if (projected) |value| value.deinit();
        var current = try fromHistoricalProjected(client.allocator, client.connection, response.value.result.historical_catalog.source, if (projected) |value| value.value.result.schema_projection.prepared else null);
        defer current.deinit();
        if (!std.mem.eql(u8, &try current.source.fingerprint(), &try self.fingerprint())) return error.TableSchemaChanged;
        return;
    }
    const response = try client.call(.{ .observe = .{ .namespace = self.namespace, .interpretation = self.interpretation.interpretation, .rows = null } });
    defer response.deinit();
    var current = try Self.from(client.allocator, client.connection, response.value.result.observation.definition);
    defer current.deinit();
    // An exact definition identity alone does not authenticate the separately
    // supplied logical descriptor used by SQL binding and metadata disclosure.
    if (!std.mem.eql(u8, &try current.source.fingerprint(), &try self.fingerprint())) return error.TableSchemaChanged;
}
pub fn requireGrant(self: Self, allocator: std.mem.Allocator, grant: c.DirectReadDelegation) !void {
    try self.validate();
    try grant.validate(allocator);
    if (!std.meta.eql(grant.binding.interpretation, self.interpretation.interpretation) or grant.binding.connection.audience != self.owner) return error.SourceChanged;
    if (self.historical) |history| {
        if (!std.meta.eql(grant.binding.copied_from, history.handle()) or !std.meta.eql(grant.binding.expected, history.accepted)) return error.SourceChanged;
    } else if (grant.binding.copied_from != null) return error.SourceChanged;
    const target: ?d.Definition = if (self.projection) |value| value.declaration.interpretation else null;
    if (!std.meta.eql(grant.binding.projection, target)) return error.SourceChanged;
}
pub const Basis = struct {
    declaration: [32]u8,
    schema: [32]u8,
    retained: c.DirectTableReader.Basis,
    pub fn record(self: Basis) !q.Basis {
        return .{ .cut = .{ .kind = .table, .resource = self.retained.snapshot.object.scope.resource, .position = .{ .table = try self.retained.fingerprint() } }, .contract = self.declaration, .schema = self.schema };
    }
    pub fn fingerprint(self: Basis) ![32]u8 {
        return (try self.record()).fingerprint();
    }
};
pub fn basis(self: Self, retained: c.DirectTableReader.Basis, schema: f.TableSchema.Schema) !Basis {
    try self.validate();
    if (self.historical) |history| if (!std.meta.eql(retained.accepted, history.accepted)) return error.SourceChanged;
    if (!std.meta.eql(retained.interpretation, self.interpretation) or !std.mem.eql(u8, &try schema.fingerprint(), &(if (self.projection) |target| target.declaration.schema_fingerprint else self.interpretation.schema_fingerprint))) return error.SourceChanged;
    try q.direct.DirectTableQuery.qualify(schema);
    if (!std.meta.eql(self.collations, f.QueryCollations.fromTable(schema))) return error.TableSchemaChanged;
    for (schema.columns, 0..) |column, i| {
        const declared: f.ColumnSemantics = if (self.semantics.len == 0) .{} else self.semantics[i];
        if (!declared.eql(column.semantics)) return error.TableSchemaChanged;
    }
    var fields: [f.TableSchema.max_columns]t.Field = undefined;
    if (!try self.row_type.eql(try schema.rowType(&fields))) return error.TableSchemaChanged;
    if (!std.meta.eql(retained.projection, self.projection)) return error.SourceChanged;
    // Native pin evidence describes the original source. The exact projection
    // is already committed by this source descriptor and the query contract.
    var original = retained;
    original.projection = null;
    return .{ .declaration = try self.fingerprint(), .schema = try self.row_type.fingerprint(), .retained = original };
}
fn readerAt(self: Self, allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot) !c.DirectTableReader {
    var reader = if (self.historical != null and std.meta.eql(snapshot.handle, self.historical.?.handle())) history: {
        if (!std.meta.eql(snapshot.object, self.interpretation.interpretation.object)) return error.SourceChanged;
        break :history try c.DirectTableReader.openCatalog(allocator, client, self.historical.?.snapshot, self.object);
    } else try c.DirectTableReader.open(allocator, client, snapshot);
    errdefer reader.deinit();
    if (self.projection) |target| {
        try reader.projectTo(client, target.declaration);
        if (!std.meta.eql(reader.basis.projection, target)) return error.SourceChanged;
    }
    return reader;
}
pub fn capture(self: Self, allocator: std.mem.Allocator, client: c.DirectTableClient, snapshot: w.Snapshot) !Basis {
    try self.requireConnection(client);
    var reader = self.readerAt(allocator, client, snapshot) catch |err| return q.CapturedTablePin.readFailure(client, err);
    defer reader.deinit();
    return self.basis(reader.basis, reader.schema.schema);
}
pub const Cursor = struct {
    binding: [32]u8,
    ordinal: u64 = 0,
    scanned: u64 = 0,
    after: ?f.TableRow.Identity = null,
    done: bool = false,
    pub fn start(captured: Basis) !Cursor {
        return .{ .binding = try captured.fingerprint() };
    }
};
pub const Page = struct {
    basis: Basis,
    ordinal: u64,
    next: Cursor,
    count: u8 = 0,
    owned: [f.LogicalArrow.max_rows]?f.TableRow.Owned = @splat(null),
    rows: [f.LogicalArrow.max_rows]f.LogicalArrow.Row = undefined,
    pub fn deinit(self: *Page) void {
        for (&self.owned) |*row| if (row.*) |*value| value.deinit();
        self.* = undefined;
    }
    pub fn engine(self: *Page) f.LogicalStream.Page {
        for (self.owned[0..self.count], self.rows[0..self.count]) |row, *out| out.* = .{ .cells = row.?.row().cells };
        return .{ .binding = self.next.binding, .ordinal = self.ordinal, .end = self.next.done, .rows = self.rows[0..self.count] };
    }
};
/// Reopen only the durable original pin. The bounded cursor counts consumed
/// rows, since a byte-limited direct page can contain fewer than eight rows.
pub fn page(self: Self, allocator: std.mem.Allocator, captured: Basis, cursor: Cursor, plan: f.LogicalQuery.Plan, client: c.DirectTableClient) !Page {
    try self.requireConnection(client);
    const binding = try captured.fingerprint();
    if (!std.mem.eql(u8, &binding, &cursor.binding) or !std.mem.eql(u8, &binding, &plan.source_basis) or !try self.row_type.eql(plan.schema) or !std.meta.eql(plan.collations, self.collations)) return error.SourceChanged;
    if (cursor.done) return error.QueryComplete;
    if (cursor.scanned > captured.retained.row_count or (cursor.scanned == 0) != (cursor.after == null)) return error.InvalidQueryCursor;
    try plan.validate();
    var reader = self.readerAt(allocator, client, captured.retained.snapshot) catch |err| return q.CapturedTablePin.readFailure(client, err);
    defer reader.deinit();
    if (!std.meta.eql(try self.basis(reader.basis, reader.schema.schema), captured)) return error.SourceChanged;
    // Only a complete conjunction over the declared primary key qualifies.
    // Fuze still evaluates the original predicate on the returned row.
    var key_storage: [f.TableSchema.max_columns]t.Values.Cell = undefined;
    var single: [1]f.LogicalPredicate.Program.Instruction = undefined;
    const program: ?f.LogicalPredicate.Program = switch (plan.predicate) {
        .program => |value| value,
        .compare => |value| blk: {
            single[0] = .{ .atom = .{ .compare = value } };
            break :blk .{ .instructions = &single };
        },
        else => null,
    };
    const schema = reader.schema.schema;
    const key = if (reader.basis.catalog == null and reader.basis.projection == null and program != null) try (f.TableDml.Plan{ .name = "retained", .schema = schema, .action = .delete, .predicate = program.? }).primaryKeyEquality(&key_storage) else null;
    if (key) |values| {
        if (cursor.ordinal != 0 or cursor.scanned != 0) return error.InvalidQueryCursor;
        var encoded: [f.Collation.max_sort_key_bytes]u8 = undefined;
        var result: Page = .{ .basis = captured, .ordinal = 0, .next = cursor };
        errdefer result.deinit();
        result.owned[0] = reader.readKey(client, try f.Collation.encodePrimaryKeySortKey(schema, values, false, &encoded)) catch |err| return q.CapturedTablePin.readFailure(client, err);
        if (result.owned[0]) |row| {
            result.count = 1;
            result.next.scanned = 1;
            result.next.after = row.identity;
        }
        result.next.ordinal = 1;
        result.next.done = true;
        reader.check(client) catch |err| return q.CapturedTablePin.readFailure(client, err);
        return result;
    }
    reader.consumed = cursor.scanned;
    reader.after = if (cursor.after) |after| .{ .source = if (self.projection) |target| try c.storage.TablePartition.projectionCursorSource(captured.retained.snapshot.handle, target) else captured.retained.snapshot.handle.content, .after = try after.encode() } else null;
    var batch = (reader.next(client, .{ .rows = f.LogicalArrow.max_rows }) catch |err| return q.CapturedTablePin.readFailure(client, err)) orelse return error.IncompleteSource;
    defer batch.deinit();
    var result: Page = .{ .basis = captured, .ordinal = cursor.ordinal, .next = cursor, .count = @intCast(batch.count) };
    errdefer result.deinit();
    for (batch.rows[0..batch.count], 0..) |row, i| {
        result.owned[i] = row;
        batch.rows[i] = null;
        result.next.after = row.?.identity;
    }
    result.next.ordinal = try std.math.add(u64, cursor.ordinal, 1);
    result.next.scanned = reader.consumed;
    result.next.done = batch.complete;
    reader.check(client) catch |err| return q.CapturedTablePin.readFailure(client, err);
    return result;
}
