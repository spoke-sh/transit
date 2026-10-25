//! Bounded read-only observations of one direct Table root. Notifications use
//! its logical-change position; operation, pin and physical progress are not
//! row changes. An observation carries no durable retention or continuation.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const c = q.catalog;
const r = root.ReactiveModel;
const p = root.protocol;
const f = root.ServingFailure;
pub const Reader = @import("TableWatchReader.zig");
pub const Schema = struct {
    names: [2]c.TableMetadata.Name,
    value_type: enum { int64 } = .int64,
};
pub const Observation = struct {
    data_revision: q.TablePosition.Counter,
    basis: q.TablePosition,
    schema: Schema,
};
pub const Snapshot = struct {
    observation: Observation,
    rows: [p.Growth.page_size]?struct { key: r.Integer, value: ?r.Integer } = @splat(null),
    more: bool = false,
};
const Definition = struct {
    response: std.json.Parsed(c.DirectTableProtocol.Response),
    schema: q.fuze.TableSchema.Owned,
    fn deinit(self: *Definition) void {
        self.schema.deinit();
        self.response.deinit();
        self.* = undefined;
    }
};
/// Retained diagnostics require current source rights, even when the old name
/// or interpretation is no longer live. This creates no pin or row observation.
pub fn authorize(reader: anytype, principal: u64, source: r.Source) !c.DirectReadAuthority {
    try source.validate();
    const required = try reader.requirements(source);
    try reader.check(principal, required);
    return required;
}
fn resolve(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source, rows: bool, context: ?*f.Context) !Definition {
    try source.validate();
    // Denial wins over definition drift and no copied row is disclosed through
    // the service identity's grant without this independent original subject.
    const required = try authorize(reader, principal, source);
    if (!source.published) {
        f.remember(context, f.sourceWitness(source, source.revision));
        return error.ReactiveResetRequired;
    }
    const response = reader.observe(source, if (rows) c.storage.TablePartition.ReadLimits{} else null) catch |err| {
        if (err == error.ReactiveResetRequired) f.remember(context, f.sourceWitness(source, source.revision));
        return err;
    };
    errdefer response.deinit();
    const found = response.value.result.observation;
    try reader.check(principal, found.authority);
    if (!std.meta.eql(required, found.authority) or !std.meta.eql(source.interpretation(), found.definition.interpretation.interpretation) or found.definition.namespace != source.namespace) return error.ReactiveResetRequired;
    const bytes = try found.definition.schema.decode(allocator, q.fuze.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var schema = try q.fuze.TableSchema.decode(allocator, bytes);
    errdefer schema.deinit();
    const declared = schema.schema;
    // The watch transport retains its explicit key/int64-value shape. General
    // direct queries keep their complete independently declared logical schema.
    if (declared.columns.len != 2 or declared.columns[0].nullable or declared.primary_key.len != 1 or declared.primary_key[0] != declared.columns[0].id) {
        f.remember(context, .{ .watch_shape = .{ .columns = @intCast(declared.columns.len), .first_nullable = declared.columns[0].nullable, .primary_columns = @intCast(declared.primary_key.len), .primary_first = declared.primary_key.len == 1 and declared.primary_key[0] == declared.columns[0].id } });
        return error.UnsupportedReactiveSource;
    }
    for (declared.columns, 0..) |column, i| if (column.type != .int64) {
        f.remember(context, .{ .watch_type = .{ .column = @intCast(i), .expected = .int64, .actual = std.meta.activeTag(column.type) } });
        return error.UnsupportedReactiveSource;
    };
    return .{ .response = response, .schema = schema };
}
fn observation(source: r.Source, definition: *const Definition) !Observation {
    var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
    const metadata = definition.response.value.result.observation.definition;
    const declaration: q.TableSource = .{ .scope = source.scope(), .owner = source.audience, .branch = source.branch, .namespace = source.namespace, .object = source.object.value, .interpretation = metadata.interpretation, .row_type = try definition.schema.schema.rowType(&fields) };
    return .{ .data_revision = .{ .value = metadata.changed_lsn }, .basis = try q.TablePosition.current(declaration, metadata), .schema = .{ .names = .{ try .init(fields[0].name), try .init(fields[1].name) } } };
}
pub fn observe(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source) !Observation {
    return observeDiagnostic(allocator, reader, principal, source, null);
}
pub fn observeDiagnostic(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source, context: ?*f.Context) !Observation {
    var definition = try resolve(allocator, reader, principal, source, false, context);
    defer definition.deinit();
    const result = try observation(source, &definition);
    try reader.finish();
    return result;
}
pub fn snapshot(allocator: std.mem.Allocator, reader: anytype, principal: u64, source: r.Source) !Snapshot {
    var definition = try resolve(allocator, reader, principal, source, true, null);
    defer definition.deinit();
    var result: Snapshot = .{ .observation = try observation(source, &definition) };
    const page = definition.response.value.result.observation.page orelse return error.InvalidTableResponse;
    if (page.rows.len > result.rows.len) return error.InvalidTableResponse;
    for (page.rows, result.rows[0..page.rows.len]) |encoded, *slot| {
        const bytes = try encoded.decode(allocator, q.fuze.TableRow.max_bytes);
        defer allocator.free(bytes);
        var row = try q.fuze.TableRow.decode(allocator, definition.schema.schema, bytes);
        defer row.deinit();
        const cells = row.row().cells;
        slot.* = .{ .key = .{ .value = @intCast(cells[0].value.atom.signed) }, .value = if (cells[1] == .null) null else .{ .value = @intCast(cells[1].value.atom.signed) } };
    }
    result.more = page.more;
    try reader.finish();
    return result;
}
/// This pure comparison grants no authority or verified-query status. The
/// scheduler obtains captured positions only from the verified result reader.
pub fn covered(observed: Observation, captured: q.TablePosition) bool {
    return captured.covers(observed.basis, observed.data_revision.value);
}
pub fn validateResume(previous: r.Position, scope: r.Scope, source: r.Source, current: Observation, outcome_position: u64) !void {
    try previous.validate();
    if (!std.meta.eql(previous.scope, scope)) return error.InvalidReactiveCursor;
    if (previous.watch_revision != source.revision or previous.resource != source.resource or !std.mem.eql(u8, &previous.schema, &current.basis.schema)) return error.ReactiveResetRequired;
    if (previous.data_revision.value > current.data_revision.value or previous.outcome_position > outcome_position) return error.InvalidReactiveCursor;
}
