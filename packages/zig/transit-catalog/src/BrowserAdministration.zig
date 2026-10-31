//! Public typed declaration lifecycle. This is the executable administrative
//! interface until corresponding SQL declarations have an execution owner.
const std = @import("std");
const c = @import("root.zig");
const b = c.BrowserDeclarations;
const f = c.fuze;
pub const Request = struct {
    definition: []const u8,
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    development: bool = false,
    action: union(enum) {
        inspect: struct { kind: b.Store.Kind, key: b.Digest },
        list: struct { kind: b.Store.Kind, after: ?u64 },
        change: b.Change,
        prepare_publication: Prepare,
    },
};
pub const Prepare = struct {
    mutation: b.Mutation,
    expected: ?b.Store.Revision,
    name: []const u8,
    title: []const u8,
    meaning: []const u8,
    source_name: []const u8,
    sql: []const u8,
    resource_object: u64,
    definition_id: u64,
    revision: u64,
    audience: @FieldType(b.Publication, "audience"),
    publisher: b.Credential,
    max_rows: u32 = 1000,
    max_bytes: u32 = 1024 * 1024,
};
pub const View = struct { revision: b.Store.Revision, reference: c.DirectRecord.Reference, record: b.Store.Record };
pub const Response = union(enum) { inspected: ?View, page: struct { entries: []const View, next: ?u64 }, accepted: b.Store.Accepted, proposed: b.Change };
/// All returned slices belong to caller-owned output storage. Use a bounded
/// request arena; no result borrows a released native transport response.
pub fn execute(store: b.Store, request: Request) !Response {
    const allocator = store.client.allocator;
    if (!std.mem.eql(u8, request.definition, b.definition)) return error.IncompatibleDefinition;
    if (request.namespace != store.namespace or !std.meta.eql(request.connection, store.client.connection)) return error.BrowserNamespaceMismatch;
    switch (request.action) {
        .change => |change| return .{ .accepted = try change.apply(store, request.development) },
        .prepare_publication => |spec| return .{ .proposed = try prepare(store, spec) },
        .inspect => |selection| {
            var value = try store.read(selection.kind, selection.key) orelse return .{ .inspected = null };
            defer value.deinit();
            return .{ .inspected = .{ .revision = value.revision, .reference = value.reference, .record = try c.client.LocalEndpoint.clone(allocator, value.value()) } };
        },
        .list => |selection| {
            const page = try store.page(selection.kind, selection.after);
            var entries: std.ArrayList(View) = .empty;
            for (page.entries) |slot| if (slot) |progress| {
                if (progress.receipt.binding.intent != .external) return error.InvalidBrowserRecord;
                const reference = progress.record orelse progress.receipt.binding.intent.external.record;
                const value = try store.load(reference);
                defer value.deinit();
                try entries.append(allocator, .{ .revision = progress.revision, .reference = reference, .record = try c.client.LocalEndpoint.clone(allocator, value.value) });
            };
            return .{ .page = .{ .entries = try entries.toOwnedSlice(allocator), .next = page.next } };
        },
    }
}
pub fn prepare(store: b.Store, spec: Prepare) !b.Change {
    const allocator = store.client.allocator;
    const response = try store.client.call(.{ .lookup = .{ .namespace = store.namespace, .name = spec.source_name } });
    defer response.deinit();
    const source = response.value.result.lookup orelse return error.TableNotFound;
    const bytes = try source.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(bytes);
    var schema = try f.TableSchema.decode(allocator, bytes);
    defer schema.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    var compiled = try f.TableSelect.compile(allocator, spec.sql, spec.source_name, try schema.schema.rowType(&fields), source.interpretation.interpretation.digest, null);
    defer compiled.deinit();
    compiled.plan.collations = .fromTable(schema.schema);
    try compiled.plan.validate();
    if (compiled.plan.aggregate != .rows) return error.UnsupportedBrowserPublication;
    const output = try compiled.plan.outputSchema(&fields);
    const columns = try allocator.alloc(f.TableSchema.Column, output.structure.len);
    for (output.structure, columns, 0..) |field, *column, index| column.* = .{ .id = @intCast(index + 1), .name = try allocator.dupe(u8, field.name), .type = try field.type.cloneInto(allocator), .nullable = field.nullable };
    const dependencies = try allocator.alloc(c.HistoricalCatalog.DependencyColumnBinding, 1);
    const input_columns = try allocator.alloc(f.TableSchema.ColumnId, schema.schema.columns.len);
    for (schema.schema.columns, input_columns) |column, *id| id.* = column.id;
    dependencies[0] = .{ .source_object = source.interpretation.interpretation.object.object, .source_revision = source.interpretation.interpretation.revision, .columns = input_columns };
    const publication: b.Publication = .{
        .descriptor = .{ .namespace_id = store.namespace, .resource_object = spec.resource_object, .definition_id = spec.definition_id, .publication_revision = spec.revision, .previous_revision = if (spec.revision > 1) spec.revision - 1 else null, .branch_id = store.client.connection.branch, .created_at_lsn = source.position.next_lsn, .canonical_name = spec.name, .business_title = spec.title, .business_meaning = spec.meaning, .tzdb_version = try f.DecimalArithmetic.TzdbVersion.init("2025b"), .canonical_plan_or_sql = spec.sql, .dependencies = dependencies, .result_schema = .{ .object = spec.resource_object, .revision = spec.revision, .next_column = @intCast(columns.len + 1), .columns = columns }, .freshness_requirement = .{ .max_staleness_ms = 1000 }, .work_bound = .{ .max_rows = spec.max_rows, .max_bytes = spec.max_bytes, .max_cpu_micros = 1_000_000, .max_iops = 10_000, .execution_timeout_ms = 5000 } },
        .audience = spec.audience,
        .source = source.interpretation.interpretation,
        .source_name = spec.source_name,
        .publisher = spec.publisher,
        .max_rows = spec.max_rows,
        .max_bytes = spec.max_bytes,
    };
    try publication.validate();
    return .{ .definition = b.definition, .namespace = store.namespace, .mutation = spec.mutation, .expected = spec.expected, .declaration = .{ .publication = publication } };
}
