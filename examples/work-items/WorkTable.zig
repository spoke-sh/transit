//! The application's two reviewed layouts over direct typed Tables. Reads are
//! conditional on an explicit source basis; preparation never admits a write.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const p = q.protocol;
const d = p.DataLifecycle;
const f = q.fuze;
const w = c.DirectTableProtocol;
pub const Data = @import("WorkData.zig");
pub const Identity = f.TableRow.Identity;
pub const Row = struct { identity: Identity, key: i64, state: i64 };
const old_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "status", .type = .int64, .nullable = false },
};
const new_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "state", .type = .int64, .nullable = false },
};
/// Local layout identity for the application contract. Published query sources
/// instead bind schemaAt's explicitly configured global Table object.
pub fn schema(table: u32) f.TableSchema.Schema {
    return .{ .object = table, .revision = 1, .next_column = 3, .columns = if (table == 1) &old_columns else &new_columns, .primary_key = &.{1} };
}
pub fn schemaAt(binding: Data.Binding, table: u32) !f.TableSchema.Schema {
    var value = schema(table);
    value.object = (try binding.object(table)).object;
    return value;
}
pub fn name(table: u32) !c.TableAuthority.Name {
    var bytes: [32]u8 = undefined;
    return .init(try std.fmt.bufPrint(&bytes, "work_items_{d}", .{table}));
}
pub const Definition = struct {
    response: std.json.Parsed(w.Response),
    value: w.Definition,
    authority: c.DirectReadAuthority,
    pub fn deinit(self: *Definition) void {
        self.response.deinit();
        self.* = undefined;
    }
};
pub fn definition(client: Data.Client, binding: Data.Binding, table: u32) !Definition {
    const table_name = try name(table);
    const lookup = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = table_name.slice() } });
    defer lookup.deinit();
    if (lookup.value.result != .lookup) return error.InvalidWorkItemDataResponse;
    const found = lookup.value.result.lookup orelse return error.WorkItemInitializationRequired;
    if (!std.meta.eql(found.interpretation.interpretation.object, try binding.object(table)) or
        !std.mem.eql(u8, &found.interpretation.schema_fingerprint, &try (try schemaAt(binding, table)).fingerprint())) return error.WorkItemEpochChanged;
    // SELECT is required even when a caller only needs metadata for a query.
    const observed = try client.call(.{ .observe = .{ .namespace = binding.namespace, .interpretation = found.interpretation.interpretation, .rows = null } });
    errdefer observed.deinit();
    if (observed.value.result != .observation) return error.InvalidWorkItemDataResponse;
    return .{ .response = observed, .value = observed.value.result.observation.definition, .authority = observed.value.result.observation.authority };
}
fn row(allocator: std.mem.Allocator, metadata: w.Definition, binary: w.Binary) !Row {
    const schema_bytes = try metadata.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(schema_bytes);
    var declared = try f.TableSchema.decode(allocator, schema_bytes);
    defer declared.deinit();
    const bytes = try binary.decode(allocator, f.TableRow.max_bytes);
    defer allocator.free(bytes);
    var owned = try f.TableRow.decode(allocator, declared.schema, bytes);
    defer owned.deinit();
    const value = owned.row();
    if (value.cells.len != 2) return error.WorkItemSourceInvalid;
    for (value.cells) |cell| if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.WorkItemSourceInvalid;
    return .{ .identity = value.identity, .key = std.math.cast(i64, value.cells[0].value.atom.signed) orelse return error.WorkItemSourceInvalid, .state = std.math.cast(i64, value.cells[1].value.atom.signed) orelse return error.WorkItemSourceInvalid };
}
pub fn get(allocator: std.mem.Allocator, client: Data.Client, metadata: w.Definition, expected: d.Position, key: i64) !?Row {
    const schema_bytes = try metadata.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(schema_bytes);
    var declared = try f.TableSchema.decode(allocator, schema_bytes);
    defer declared.deinit();
    var scratch: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try f.Collation.encodePrimaryKeySortKey(declared.schema, &.{.{ .value = .{ .atom = .{ .signed = key } } }}, false, &scratch));
    defer allocator.free(encoded.base64);
    const response = try client.call(.{ .read_current = .{ .namespace = metadata.namespace, .interpretation = metadata.interpretation.interpretation, .expected = expected, .selection = .{ .key = encoded } } });
    defer response.deinit();
    if (response.value.result != .current_read or response.value.result.current_read.selection != .key) return error.InvalidWorkItemDataResponse;
    return if (response.value.result.current_read.selection.key) |binary| try row(allocator, response.value.result.current_read.definition, binary) else null;
}
pub fn next(allocator: std.mem.Allocator, client: Data.Client, metadata: w.Definition, expected: d.Position, after: ?Identity) !?Row {
    const response = try client.call(.{ .read_current = .{ .namespace = metadata.namespace, .interpretation = metadata.interpretation.interpretation, .expected = expected, .selection = .{ .rows = .{ .after = after, .limits = .{ .rows = 1, .encoded_bytes = 4096 } } } } });
    defer response.deinit();
    if (response.value.result != .current_read or response.value.result.current_read.selection != .rows) return error.InvalidWorkItemDataResponse;
    const found = response.value.result.current_read;
    if (found.selection.rows.rows.len > 1) return error.InvalidWorkItemDataResponse;
    return if (found.selection.rows.rows.len == 1) try row(allocator, found.definition, found.selection.rows.rows[0]) else null;
}
pub fn creation(allocator: std.mem.Allocator, client: Data.Client, binding: Data.Binding, table: u32, input: u64, prerequisite: p.Authorization.Guard) !c.DirectTableIntent {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var scratch: [f.TableSchema.max_bytes]u8 = undefined;
    const declared = try schemaAt(binding, table);
    const encoded = try w.Binary.encode(allocator, try declared.encode(&scratch));
    defer allocator.free(encoded.base64);
    const table_name = try name(table);
    var work: w.Ddl = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = binding.scope, .principal = client.connection.principal, .operation = input }, .target = try binding.object(table), .action = .create, .expected_definition = null, .expected_data = null, .prerequisite = prerequisite, .intent = @splat(0) },
        .namespace = binding.namespace,
        .name = table_name.slice(),
        .action = .{ .create = .{ .owner = binding.owner_role, .schema = encoded } },
    };
    work.binding.intent = try work.digest(arena.allocator());
    return c.DirectTableIntent.create(allocator, client.connection, .{ .ddl = work });
}
pub fn mutation(allocator: std.mem.Allocator, client: Data.Client, metadata: w.Definition, expected: d.Position, input: u64, value: Row, insert: bool, prerequisite: p.Authorization.Guard) !c.DirectTableIntent {
    const schema_bytes = try metadata.schema.decode(allocator, f.TableSchema.max_bytes);
    defer allocator.free(schema_bytes);
    var declared = try f.TableSchema.decode(allocator, schema_bytes);
    defer declared.deinit();
    const identity: d.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = input };
    const native_row: f.TableRow.Row = .{ .identity = if (insert) try w.Rows.insertIdentity(identity, 0) else value.identity, .cells = &.{ .{ .value = .{ .atom = .{ .signed = value.key } } }, .{ .value = .{ .atom = .{ .signed = value.state } } } } };
    var row_bytes: [4096]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try native_row.encode(declared.schema, &row_bytes));
    defer allocator.free(encoded.base64);
    var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const key_value = try w.Binary.encode(allocator, try native_row.storageKey(declared.schema, &key_bytes));
    defer allocator.free(key_value.base64);
    var work: w.Rows = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = identity, .target = metadata.interpretation.interpretation.object, .action = if (insert) .insert else .update, .expected_definition = metadata.interpretation.interpretation, .expected_data = expected, .prerequisite = prerequisite, .intent = @splat(0) },
        .interpretation = metadata.interpretation,
        .schema = metadata.schema,
        .changes = &.{if (insert) .{ .insert = encoded } else .{ .update = .{ .key = key_value, .row = encoded } }},
        .ingestion = .point,
    };
    work.binding.intent = try work.digest(allocator);
    return c.DirectTableIntent.create(allocator, client.connection, .{ .rows = work });
}
