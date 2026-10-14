//! General Table source adapter over public captured/retained state readers.
//! A declaration identifies data; its caller supplies authenticated authority,
//! retains the source cut and commits progress. This module grants none of them.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const s = q.station;
const f = q.fuze;
const t = f.Types;
const Self = @This();
pub const max_bytes = 126 + t.max_encoding_bytes;
scope: c.TableCatalogRecords.Scope,
owner: u64,
object: u64,
metadata: s.TablePages.Reference,
row_type: t.Type,

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
    if (self.object == 0) return error.InvalidQuerySource;
    try c.TableCatalogRecords.metadataReference(self.metadata);
    try self.row_type.validate(.{});
    if (self.row_type != .structure or self.row_type.structure.len == 0 or self.row_type.structure.len > f.TableSchema.max_columns) return error.InvalidQuerySource;
}
/// Copy the schema admitted by the catalog. The metadata commitment also binds
/// stable column identities, defaults, keys and the complete Table schema.
pub fn from(allocator: std.mem.Allocator, configuration: c.TableCatalogRecords.Configuration, definition: c.TableCatalog.Definition) !Owned {
    try configuration.validate();
    if (!std.meta.eql(configuration.scope, definition.metadata.scope)) return error.CatalogScopeChanged;
    var fields: [f.TableSchema.max_columns]t.Field = undefined;
    var descriptor = try (try definition.schema.schema.rowType(&fields)).clone(allocator);
    errdefer descriptor.deinit();
    const source: Self = .{ .scope = configuration.scope, .owner = configuration.owner, .object = definition.metadata.object, .metadata = .{ .id = definition.metadata.revision, .spec = try definition.metadata.spec() }, .row_type = descriptor.type };
    try source.validate();
    return .{ .descriptor = descriptor, .source = source };
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var type_bytes: [t.max_encoding_bytes]u8 = undefined;
    const encoded = try self.row_type.encode(&type_bytes);
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("TQS1");
    try writer.writeAll(&c.TableMetadata.definition());
    try c.TableMetadata.scopeWrite(&writer, self.scope);
    try writer.writeInt(u64, self.owner, .little);
    try writer.writeInt(u64, self.object, .little);
    try writer.writeInt(u64, self.metadata.id, .little);
    try writer.writeInt(u32, self.metadata.spec.format, .little);
    try writer.writeInt(u32, self.metadata.spec.length, .little);
    try writer.writeAll(&self.metadata.spec.digest);
    try writer.writeInt(u16, @intCast(encoded.len), .little);
    try writer.writeAll(encoded);
    return writer.buffered();
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Owned {
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const source = try decodeInto(arena.allocator(), bytes);
    return .{ .descriptor = .{ .arena = arena, .type = source.row_type }, .source = source };
}
/// Embedded declarations share their enclosing request arena. It owns every
/// decoded name/child and partial allocation, including when decoding fails.
pub fn decodeInto(arena: std.mem.Allocator, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.SourceDefinitionTooLarge;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "TQS1")) return error.InvalidSourceEncoding;
    if (!std.mem.eql(u8, try reader.take(32), &c.TableMetadata.definition())) return error.IncompatibleDefinition;
    var source: Self = .{
        .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) },
        .owner = try reader.takeInt(u64, .little),
        .object = try reader.takeInt(u64, .little),
        .metadata = .{ .id = try reader.takeInt(u64, .little), .spec = .{ .format = try reader.takeInt(u32, .little), .length = try reader.takeInt(u32, .little), .digest = (try reader.takeArray(32)).* } },
        .row_type = undefined,
    };
    const type_bytes = try reader.take(try reader.takeInt(u16, .little));
    if (reader.bufferedLen() != 0) return error.InvalidSourceEncoding;
    source.row_type = try t.decodeInto(arena, type_bytes);
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
/// `who` comes from the authenticated caller or an explicit committed query
/// policy mapping. A submitted declaration must never choose this principal.
/// `current` must be a live authorized reader, never the retained data reader.
pub fn checkCurrent(self: Self, current: anytype, who: u64) !c.TableCatalog {
    try self.validate();
    if (current.view.resource != self.scope.resource) return error.SourceChanged;
    const config = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try current.read(c.Records.key(self.scope.catalog, 'c', 0, 0))) orelse return error.CatalogNotInitialized);
    if (!std.meta.eql(config.scope, self.scope)) return error.CatalogScopeChanged;
    if (config.owner != self.owner) return error.CatalogOwnerChanged;
    const catalog: c.TableCatalog = .{ .configuration = config };
    _ = try catalog.authorizeObject(current, who, self.object, .read);
    return catalog;
}
fn resolve(self: Self, allocator: std.mem.Allocator, data: anytype, who: u64) !c.TableCatalog.Definition {
    return self.resolveDiagnostic(allocator, data, who, null);
}
/// Current metadata inspection for new work. Retained-page authorization uses
/// checkCurrent instead, so ALTER does not reinterpret already captured data.
pub fn checkDefinition(self: Self, allocator: std.mem.Allocator, current: anytype, who: u64) !void {
    var definition = try self.resolve(allocator, current, who);
    defer definition.deinit();
}
fn resolveDiagnostic(self: Self, allocator: std.mem.Allocator, data: anytype, who: u64, diagnostic: ?*?q.SourceWitness) !c.TableCatalog.Definition {
    const catalog = try self.checkCurrent(data, who);
    var mismatch: ?c.TableCatalog.DefinitionMismatch = null;
    var definition = catalog.readDefinitionDiagnostic(allocator, data, who, self.object, self.metadata, &mismatch) catch |err| {
        if (diagnostic) |detail| if (mismatch) |value| {
            detail.* = .{ .reason = .table_metadata, .resource = self.scope.resource, .object = self.object, .expected = value.expected.id, .actual = value.actual.id, .expected_hash = value.expected.spec.digest, .actual_hash = value.actual.spec.digest };
        };
        return err;
    };
    errdefer definition.deinit();
    var fields: [f.TableSchema.max_columns]t.Field = undefined;
    if (!try self.row_type.eql(try definition.schema.schema.rowType(&fields))) return error.TableSchemaChanged;
    return definition;
}
pub const Basis = struct {
    declaration: [32]u8,
    resource: u64,
    schema: [32]u8,
    revision: u64,
    head: s.TableHead,
    pub fn record(self: Basis) !q.Basis {
        return .{ .cut = .{ .kind = .table, .resource = self.resource, .revision = self.revision, .head = try q.Basis.tableHead(self.head) }, .contract = self.declaration, .schema = self.schema };
    }
    pub fn fingerprint(self: Basis) ![32]u8 {
        if (self.revision == 0 or self.head.retired) return error.SourceChanged;
        return (try self.record()).fingerprint();
    }
};
/// Admission resolves the live object at exactly the cut the host will retain.
/// The host must publish its request/retention decision atomically afterwards.
pub fn capture(self: Self, allocator: std.mem.Allocator, data: anytype, current: anytype, who: u64) !Basis {
    return self.captureDiagnostic(allocator, data, current, who, null);
}
pub fn captureDiagnostic(self: Self, allocator: std.mem.Allocator, data: anytype, current: anytype, who: u64, diagnostic: ?*?q.SourceWitness) !Basis {
    if (diagnostic) |detail| detail.* = null;
    // New admissions require the declared live object. Continuations use page,
    // which deliberately does not reinterpret their retained cut through it.
    var live = try self.resolveDiagnostic(allocator, current, who, diagnostic);
    defer live.deinit();
    var definition = try self.resolveDiagnostic(allocator, data, who, diagnostic);
    defer definition.deinit();
    const basis: Basis = .{ .declaration = try self.fingerprint(), .resource = self.scope.resource, .schema = try self.row_type.fingerprint(), .revision = data.view.revision, .head = definition.head };
    _ = try basis.fingerprint();
    _ = try self.checkCurrent(current, who);
    return basis;
}
/// Restore the original schema and head from a retained cut. Current rights
/// remain mandatory; a later ALTER or DROP never substitutes its current head.
pub fn restore(self: Self, allocator: std.mem.Allocator, data: anytype, current: anytype, who: u64, expected: q.Basis) !Basis {
    _ = try self.checkCurrent(current, who);
    var definition = try self.resolve(allocator, data, who);
    defer definition.deinit();
    const result: Basis = .{ .declaration = try self.fingerprint(), .resource = self.scope.resource, .schema = try self.row_type.fingerprint(), .revision = data.view.revision, .head = definition.head };
    if (!std.meta.eql(try result.record(), expected)) return error.SourceChanged;
    _ = try self.checkCurrent(current, who);
    return result;
}
pub const Cursor = struct {
    binding: [32]u8,
    ordinal: u64 = 0,
    scanned: u64 = 0,
    after: ?f.TableRow.Identity = null,
    done: bool = false,
    pub fn start(basis: Basis) !Cursor {
        return .{ .binding = try basis.fingerprint() };
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
    /// Call at the page's final address; rows borrow this page's owned values.
    pub fn engine(self: *Page) f.LogicalStream.Page {
        for (self.owned[0..self.count], self.rows[0..self.count]) |row, *out| out.* = .{ .cells = row.?.row().cells };
        return .{ .binding = self.next.binding, .ordinal = self.ordinal, .end = self.next.done, .rows = self.rows[0..self.count] };
    }
};
/// One bounded page, using the original captured head/schema and current rights.
/// A complete primary-key equality predicate may use the collision-safe index;
/// Fuze still evaluates the original predicate. Other predicates scan by row ID.
pub fn page(self: Self, allocator: std.mem.Allocator, basis: Basis, cursor: Cursor, plan: f.LogicalQuery.Plan, data: anytype, current: anytype, who: u64) !Page {
    _ = try self.checkCurrent(current, who);
    const binding = try basis.fingerprint();
    if (data.view.revision != basis.revision or basis.resource != self.scope.resource or !std.mem.eql(u8, &basis.schema, &try self.row_type.fingerprint()) or !std.mem.eql(u8, &basis.declaration, &try self.fingerprint()) or
        !std.mem.eql(u8, &binding, &cursor.binding) or !std.mem.eql(u8, &binding, &plan.source_basis) or !try self.row_type.eql(plan.schema)) return error.SourceChanged;
    if (cursor.done) return error.QueryComplete;
    if (cursor.scanned > basis.head.rows or (cursor.scanned == 0) != (cursor.after == null) or
        cursor.scanned != (std.math.mul(u64, cursor.ordinal, f.LogicalArrow.max_rows) catch return error.InvalidQueryCursor)) return error.InvalidQueryCursor;
    try plan.validate();
    var definition = try self.resolve(allocator, data, who);
    defer definition.deinit();
    if (!std.meta.eql(definition.head, basis.head)) return error.SourceChanged;
    const table: s.TableData = .{ .schema = definition.schema.schema, .index = basis.head.index };
    var pages: s.TablePages.Reader(@TypeOf(data)) = .{ .pages = .{ .resource = self.scope.resource, .object = self.object }, .source = data };
    if (comptime @hasDecl(@typeInfo(@TypeOf(data)).pointer.child, "tableIndexCache")) pages.cache = data.tableIndexCache();
    var result: Page = .{ .basis = basis, .ordinal = cursor.ordinal, .next = cursor };
    errdefer result.deinit();
    result.next.ordinal = try std.math.add(u64, cursor.ordinal, 1);
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
    const key = if (program) |predicate| try (f.TableDml.Plan{ .name = definition.metadata.name.slice(), .schema = definition.schema.schema, .action = .delete, .predicate = predicate }).primaryKeyEquality(&key_storage) else null;
    if (key) |values| {
        if (cursor.ordinal != 0) return error.InvalidQueryCursor;
        if (try table.findKey(allocator, &pages, values)) |id| {
            result.owned[0] = (try table.get(allocator, &pages, id)) orelse return error.InvalidTableIndex;
            result.count = 1;
            result.next.scanned = 1;
            result.next.after = id;
        }
        result.next.done = true;
    } else {
        result.count = @intCast(try table.page(allocator, &pages, result.next.after, &result.owned));
        result.next.scanned = try std.math.add(u64, result.next.scanned, result.count);
        if (result.next.scanned > basis.head.rows) return error.InvalidTableIndex;
        if (result.count != 0) result.next.after = result.owned[result.count - 1].?.identity;
        if (result.count < result.owned.len) {
            if (result.next.scanned != basis.head.rows) return error.InvalidTableIndex;
            result.next.done = true;
        }
    }
    _ = try self.checkCurrent(current, who);
    return result;
}
