//! Bounded catalog Table observations at one exact native resource cut.
//! Head reservations may notify before publication; query/status bookkeeping
//! cannot. A notification promises possible change, never an uncommitted row.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const s = root.station;
const r = root.ReactiveModel;
const p = root.protocol;
const f = root.ServingFailure;
pub const Schema = struct {
    names: [2]c.TableMetadata.Name,
    value_type: enum { int64 } = .int64,
};
pub const Observation = struct {
    data_revision: u64,
    basis: q.Basis,
    schema: Schema,
};
pub const Snapshot = struct {
    observation: Observation,
    rows: [p.Growth.page_size]?struct { key: r.Integer, value: ?r.Integer } = @splat(null),
    more: bool = false,
};
/// Current catalog rights also protect retained refresh diagnostics. This check
/// intentionally does not require the old Table name or metadata to remain live.
pub fn authorize(reader: anytype, principal: u64, source: r.Source) !c.TableCatalog {
    try source.validate();
    if (reader.view.resource != source.resource) return error.ReactiveResetRequired;
    const config = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try reader.read(c.Records.key(source.catalog.value, 'c', 0, 0))) orelse return error.ReactiveResetRequired);
    if (!std.meta.eql(config.scope, source.scope()) or config.owner != source.target) return error.ReactiveResetRequired;
    const catalog: c.TableCatalog = .{ .configuration = config };
    _ = try catalog.authorize(reader, principal, .inspect);
    _ = try catalog.authorizeObject(reader, principal, source.object.value, .read);
    return catalog;
}
fn resolve(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source, context: ?*f.Context) !c.TableCatalog.Definition {
    try source.validate();
    if (!source.published) {
        f.remember(context, f.sourceWitness(source, source.revision));
        return error.ReactiveResetRequired;
    }
    if (reader.view.resource != source.resource) {
        f.remember(context, .{ .target = .{ .expected = source.resource, .actual = reader.view.resource, .kind = .resource } });
        return error.ReactiveResetRequired;
    }
    const catalog = try authorize(reader, principal, source);
    var mismatch: ?c.TableCatalog.DefinitionMismatch = null;
    var definition = catalog.readDefinitionDiagnostic(allocator, reader, principal, source.object.value, source.metadata(), &mismatch) catch |err| {
        if (mismatch) |value| f.remember(context, .{ .basis = .{ .kind = .metadata, .expected = value.expected.spec.digest, .actual = value.actual.spec.digest } });
        if (err == error.TableNotFound) f.remember(context, .{ .table = .{ .value = source.object.value } });
        return if (err == error.CatalogDefinitionChanged or err == error.CatalogSourceChanged or err == error.TableRetired) error.ReactiveResetRequired else err;
    };
    errdefer definition.deinit();
    // The watch transport deliberately exposes a key/int64-value page. General
    // finite queries retain their complete logical schema/value admission.
    const schema = definition.schema.schema;
    if (schema.columns.len != 2 or schema.columns[0].nullable or schema.primary_key.len != 1 or schema.primary_key[0] != schema.columns[0].id) {
        f.remember(context, .{ .watch_shape = .{ .columns = @intCast(schema.columns.len), .first_nullable = schema.columns[0].nullable, .primary_columns = @intCast(schema.primary_key.len), .primary_first = schema.primary_key.len == 1 and schema.primary_key[0] == schema.columns[0].id } });
        return error.UnsupportedReactiveSource;
    }
    for (schema.columns, 0..) |column, i| if (column.type != .int64) {
        f.remember(context, .{ .watch_type = .{ .column = @intCast(i), .expected = .int64, .actual = std.meta.activeTag(column.type) } });
        return error.UnsupportedReactiveSource;
    };
    return definition;
}
fn observation(reader: anytype, source: r.Source, definition: c.TableCatalog.Definition, context: ?*f.Context) !Observation {
    const key = s.TableHead.key(source.object.value);
    const progress = (try reader.entry(key)) orelse {
        f.remember(context, try f.progressWitness(key, null, reader.view.revision));
        return error.ReactiveResetRequired;
    };
    if (progress.revision == 0 or progress.revision > reader.view.revision) {
        f.remember(context, try f.progressWitness(key, progress.revision, reader.view.revision));
        return error.InvalidReactiveProgress;
    }
    if (!progress.value.eql(try definition.head.encode())) return error.ReactiveResetRequired;
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const declaration: q.TableSource = .{ .scope = source.scope(), .owner = source.target, .object = source.object.value, .metadata = source.metadata(), .row_type = try definition.schema.schema.rowType(&fields) };
    const basis: q.TableSource.Basis = .{ .declaration = try declaration.fingerprint(), .resource = source.resource, .revision = reader.view.revision, .schema = try declaration.row_type.fingerprint(), .head = definition.head };
    return .{ .data_revision = progress.revision, .basis = try basis.record(), .schema = .{ .names = .{ try .init(fields[0].name), try .init(fields[1].name) } } };
}
pub fn observe(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source) !Observation {
    return observeDiagnostic(allocator, reader, principal, source, null);
}
pub fn observeDiagnostic(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source, context: ?*f.Context) !Observation {
    var definition = try resolve(allocator, reader, principal, source, context);
    defer definition.deinit();
    return observation(reader, source, definition, context);
}
pub fn snapshot(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source) !Snapshot {
    var definition = try resolve(allocator, reader, principal, source, null);
    defer definition.deinit();
    var result: Snapshot = .{ .observation = try observation(reader, source, definition, null) };
    const table: s.TableData = .{ .schema = definition.schema.schema, .index = definition.head.index };
    var pages: s.TablePages.Reader(@TypeOf(reader)) = .{ .pages = .{ .resource = source.resource, .object = source.object.value }, .source = reader };
    var after: ?q.fuze.TableRow.Identity = null;
    for (&result.rows) |*slot| {
        var row = (try table.next(allocator, &pages, after)) orelse return result;
        defer row.deinit();
        after = row.identity;
        const cells = row.row().cells;
        slot.* = .{ .key = .{ .value = @intCast(cells[0].value.atom.signed) }, .value = if (cells[1] == .null) null else .{ .value = @intCast(cells[1].value.atom.signed) } };
    }
    result.more = definition.head.rows > result.rows.len;
    return result;
}
/// Compare only the identical source contract/schema and native resource.
pub fn covered(observed: Observation, captured: q.Basis) bool {
    return captured.cut.kind == .table and captured.cut.resource == observed.basis.cut.resource and
        std.mem.eql(u8, &captured.contract, &observed.basis.contract) and
        std.mem.eql(u8, &captured.schema, &observed.basis.schema) and
        captured.cut.revision >= observed.data_revision;
}
pub fn validateResume(previous: r.Position, scope: r.Scope, source: r.Source, current: Observation, outcome_position: u64) !void {
    try previous.validate();
    if (!std.meta.eql(previous.scope, scope)) return error.InvalidReactiveCursor;
    if (previous.watch_revision != source.revision or previous.resource != source.resource or !std.mem.eql(u8, &previous.schema, &current.basis.schema)) return error.ReactiveResetRequired;
    if (previous.data_revision > current.data_revision or previous.outcome_position > outcome_position) return error.InvalidReactiveCursor;
}
