//! Bounded public Table observation. Data progress is an entry revision written
//! atomically by the application owner, not every commit to the shared resource.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const r = root.ReactiveModel;
const p = root.protocol;
const Table = root.station.Table;
const f = root.ServingFailure;
pub const Observation = struct {
    data_revision: u64,
    basis: q.fuze.Unified.Basis,
    schema: q.fuze.model.Schema,
};
pub const Snapshot = struct {
    observation: Observation,
    rows: [p.Growth.page_size]?struct { key: r.Integer, value: ?r.Integer } = @splat(null),
    more: bool = false,
};
pub fn observe(reader: anytype, source: r.Source) !Observation {
    return observeDiagnostic(reader, source, null);
}
pub fn observeDiagnostic(reader: anytype, source: r.Source, context: ?*f.Context) !Observation {
    try source.validate();
    if (!source.published) {
        f.remember(context, f.sourceWitness(source, source.revision));
        return error.ReactiveResetRequired;
    }
    if (reader.view.resource != source.resource) {
        f.remember(context, .{ .target = .{ .expected = source.resource, .actual = reader.view.resource, .kind = .resource } });
        return error.ReactiveResetRequired;
    }
    const table = Table.open(reader, source.table) catch |err| {
        if (err == error.TableNotFound) f.remember(context, .{ .table = source.table });
        return err;
    };
    const schema = try table.schema.fingerprint();
    if (!std.mem.eql(u8, &source.schema, &schema)) {
        f.remember(context, .{ .basis = .{ .kind = .schema, .expected = source.schema, .actual = schema } });
        return error.ReactiveResetRequired;
    }
    if (table.schema.value_type != .int64) {
        f.remember(context, .{ .watch_type = .{ .expected = .int64, .actual = table.schema.value_type } });
        return error.UnsupportedReactiveSource;
    }
    const progress = (try reader.entry(source.progress_key)) orelse {
        f.remember(context, try f.progressWitness(source.progress_key, null, reader.view.revision));
        return error.ReactiveResetRequired;
    };
    if (progress.revision == 0 or progress.revision > reader.view.revision) {
        f.remember(context, try f.progressWitness(source.progress_key, progress.revision, reader.view.revision));
        return error.InvalidReactiveProgress;
    }
    const definition: q.SourceDefinition = .{ .resource = source.resource, .source = .{ .table = .{ .id = source.table, .schema = table.schema } } };
    return .{ .data_revision = progress.revision, .basis = try q.UnifiedSource.basis(definition, reader.view.revision), .schema = table.schema };
}
pub fn snapshot(reader: anytype, source: r.Source) !Snapshot {
    const observation = try observe(reader, source);
    const table = try Table.open(reader, source.table);
    const page = try table.page(reader, null);
    if (page.basis.resource != observation.basis.resource or page.basis.revision != observation.basis.revision or !std.mem.eql(u8, &page.basis.schema, &source.schema)) return error.ReactiveResetRequired;
    var result: Snapshot = .{ .observation = observation, .more = page.next != null };
    for (page.rows[0..page.len], 0..) |row, i| result.rows[i] = .{ .key = .{ .value = row.key }, .value = if (row.value == .null) null else .{ .value = row.value.int64 } };
    return result;
}
/// Finite-query capture coverage compares only the identical source contract and
/// schema. A larger number in another resource or schema carries no meaning.
pub fn covered(observation: Observation, captured: q.fuze.Unified.Basis) bool {
    return captured.kind == .table and captured.resource == observation.basis.resource and
        std.mem.eql(u8, &captured.contract, &observation.basis.contract) and
        std.mem.eql(u8, &captured.schema, &observation.basis.schema) and
        captured.revision >= observation.data_revision;
}
pub fn validateResume(previous: r.Position, scope: r.Scope, source: r.Source, current: Observation, outcome_position: u64) !void {
    try previous.validate();
    if (!std.meta.eql(previous.scope, scope)) return error.InvalidReactiveCursor;
    if (previous.watch_revision != source.revision or previous.resource != source.resource or !std.mem.eql(u8, &previous.schema, &source.schema)) return error.ReactiveResetRequired;
    if (previous.data_revision > current.data_revision or previous.outcome_position > outcome_position) return error.InvalidReactiveCursor;
}
