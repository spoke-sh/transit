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
    var descriptor = try t.decode(allocator, type_bytes);
    errdefer descriptor.deinit();
    source.row_type = descriptor.type;
    try source.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, try source.encode(&canonical), bytes)) return error.InvalidSourceEncoding;
    return .{ .descriptor = descriptor, .source = source };
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
    _ = try catalog.authorize(current, who, .inspect);
    _ = try catalog.authorize(current, who, .read);
    return catalog;
}
fn resolve(self: Self, allocator: std.mem.Allocator, data: anytype, who: u64) !c.TableCatalog.Definition {
    const catalog = try self.checkCurrent(data, who);
    var definition = try catalog.readDefinition(allocator, data, who, self.object, self.metadata);
    errdefer definition.deinit();
    var fields: [f.TableSchema.max_columns]t.Field = undefined;
    if (!try self.row_type.eql(try definition.schema.schema.rowType(&fields))) return error.TableSchemaChanged;
    return definition;
}
pub const Basis = struct {
    declaration: [32]u8,
    revision: u64,
    head: s.TableHead,
    pub fn fingerprint(self: Basis) ![32]u8 {
        if (self.revision == 0 or self.head.retired) return error.SourceChanged;
        var digest: std.crypto.hash.sha2.Sha256 = .init(.{});
        digest.update("transit.table.query.capture.v1\x00");
        digest.update(&self.declaration);
        var revision: [8]u8 = undefined;
        std.mem.writeInt(u64, &revision, self.revision, .little);
        digest.update(&revision);
        digest.update((try self.head.encode()).slice());
        return digest.finalResult();
    }
};
/// Admission resolves the live object at exactly the cut the host will retain.
/// The host must publish its request/retention decision atomically afterwards.
pub fn capture(self: Self, allocator: std.mem.Allocator, data: anytype, current: anytype, who: u64) !Basis {
    // New admissions require the declared live object. Continuations use page,
    // which deliberately does not reinterpret their retained cut through it.
    var live = try self.resolve(allocator, current, who);
    defer live.deinit();
    var definition = try self.resolve(allocator, data, who);
    defer definition.deinit();
    const basis: Basis = .{ .declaration = try self.fingerprint(), .revision = data.view.revision, .head = definition.head };
    _ = try basis.fingerprint();
    _ = try self.checkCurrent(current, who);
    return basis;
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
    if (data.view.revision != basis.revision or !std.mem.eql(u8, &basis.declaration, &try self.fingerprint()) or
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
    var result: Page = .{ .basis = basis, .ordinal = cursor.ordinal, .next = cursor };
    errdefer result.deinit();
    result.next.ordinal = try std.math.add(u64, cursor.ordinal, 1);
    var key_storage: [f.TableSchema.max_columns]t.Values.Cell = undefined;
    const key = if (plan.predicate == .program) try (f.TableDml.Plan{ .name = definition.metadata.name.slice(), .schema = definition.schema.schema, .action = .delete, .predicate = plan.predicate.program }).primaryKeyEquality(&key_storage) else null;
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
        for (&result.owned) |*slot| {
            slot.* = try table.next(allocator, &pages, result.next.after);
            if (slot.*) |row| {
                result.next.scanned = try std.math.add(u64, result.next.scanned, 1);
                if (result.next.scanned > basis.head.rows) return error.InvalidTableIndex;
                result.next.after = row.identity;
                result.count += 1;
            } else {
                if (result.next.scanned != basis.head.rows) return error.InvalidTableIndex;
                result.next.done = true;
                break;
            }
        }
    }
    _ = try self.checkCurrent(current, who);
    return result;
}
