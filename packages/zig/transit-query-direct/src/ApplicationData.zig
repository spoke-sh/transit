//! Ordered-program values at the native database boundary. Logical values use
//! the shared codecs and constraints; no protected material is a storage atom.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const a = f.ApplicationProgram;
const p = q.protocol;
const Value = a.Values.Value;
const Cell = f.Types.Values.Cell;

pub fn bindField(output: std.mem.Allocator, field: f.Types.Field) !a.Types.Value {
    try field.type.validate(.{});
    try requireType(field.type, 0);
    return bindType(output, field, 0);
}
fn requireType(type_: f.Types.Type, depth: usize) anyerror!void {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    switch (type_) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .boolean, .utf8, .binary, .uuid, .json, .capability => {},
        .timestamp => |zone| if (zone != .utc) return error.ProgramTypeMismatch,
        .structure => |fields| {
            if (fields.len > a.max_arguments) return error.ProgramTooComplex;
            for (fields) |field| try requireType(field.type, depth + 1);
        },
        else => return error.ProgramTypeMismatch,
    }
}
fn bindType(output: std.mem.Allocator, field: f.Types.Field, depth: usize) anyerror!a.Types.Value {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    var value: a.Types.Value = .{ .kind = undefined, .nullable = field.nullable };
    value.kind = switch (field.type) {
        .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32 => .integer,
        .boolean => .boolean,
        .utf8 => .text,
        .binary => .binary,
        .uuid => .uuid,
        .capability => .capability,
        .timestamp => |zone| if (zone == .utc) .timestamp else return error.ProgramTypeMismatch,
        .json => .json,
        .structure => |fields| blk: {
            if (fields.len > a.max_arguments) return error.ProgramTooComplex;
            const bound = try output.alloc(a.Types.Field, fields.len);
            for (fields, bound) |source, *target| target.* = .{ .name = try output.dupe(u8, source.name), .value = try bindType(output, source, depth + 1) };
            value.fields = bound;
            break :blk .record;
        },
        else => return error.ProgramTypeMismatch,
    };
    return value;
}
/// Returns owned values in output, including nested fields and strings. Invalid
/// native provenance (missing/type-error/conflict) never becomes SQL NULL.
pub fn fromCell(output: std.mem.Allocator, field: f.Types.Field, cell: Cell) !Value {
    try cell.validate(field, .{});
    try requireType(field.type, 0);
    return fromValidated(output, field.type, cell);
}
fn fromValidated(output: std.mem.Allocator, type_: f.Types.Type, cell: Cell) anyerror!Value {
    if (cell == .null) return .null;
    if (cell != .value) return error.ProgramTypeMismatch;
    const value = cell.value;
    return switch (type_) {
        .int8, .int16, .int32, .int64 => .{ .integer = std.math.cast(i64, value.atom.signed) orelse return error.Overflow },
        .uint8, .uint16, .uint32 => .{ .integer = std.math.cast(i64, value.atom.unsigned) orelse return error.Overflow },
        .boolean => .{ .boolean = value.atom.boolean },
        .utf8 => .{ .text = try output.dupe(u8, value.atom.bytes) },
        .binary => .{ .binary = try output.dupe(u8, value.atom.bytes) },
        .uuid => .{ .uuid = value.atom.uuid },
        .capability => .{ .capability = .{ .id = value.atom.capability.* } },
        .timestamp => .{ .timestamp = value.atom.timestamp },
        .json => .{ .json = try output.dupe(u8, value.json) },
        .structure => |fields| blk: {
            const result = try output.alloc(a.Values.Field, fields.len);
            for (fields, value.structure, result) |source, member, *target| target.* = .{ .name = try output.dupe(u8, source.name), .value = try fromValidated(output, source.type, member) };
            break :blk .{ .record = result };
        },
        else => return error.ProgramTypeMismatch,
    };
}
/// Cells borrow public byte strings from value. Their container arrays belong
/// to scratch; encoding/retaining the native intent precedes resetting it.
pub fn intoCell(scratch: std.mem.Allocator, field: f.Types.Field, value: Value) !Cell {
    try field.type.validate(.{});
    try requireType(field.type, 0);
    const cell = try intoType(scratch, field.type, value, 0);
    try cell.validate(field, .{});
    return cell;
}
fn intoType(scratch: std.mem.Allocator, type_: f.Types.Type, value: Value, depth: usize) anyerror!Cell {
    if (depth > a.max_depth) return error.ProgramTooDeep;
    if (value.protected() or value == .failure or (value == .capability and type_ != .capability)) return error.ProtectedProgramValue;
    if (value == .null) return .null;
    const result: f.Types.Values.Value = switch (type_) {
        .int8, .int16, .int32, .int64 => if (value == .integer) .{ .atom = .{ .signed = value.integer } } else return error.ProgramTypeMismatch,
        .uint8, .uint16, .uint32 => if (value == .integer and value.integer >= 0) .{ .atom = .{ .unsigned = @intCast(value.integer) } } else return error.ProgramTypeMismatch,
        .boolean => if (value == .boolean) .{ .atom = .{ .boolean = value.boolean } } else return error.ProgramTypeMismatch,
        .utf8 => if (value == .text) .{ .atom = .{ .bytes = value.text } } else return error.ProgramTypeMismatch,
        .binary => if (value == .binary) .{ .atom = .{ .bytes = value.binary } } else return error.ProgramTypeMismatch,
        .uuid => if (value == .uuid) .{ .atom = .{ .uuid = value.uuid } } else return error.ProgramTypeMismatch,
        .capability => blk: {
            if (value != .capability) return error.ProgramTypeMismatch;
            const handle = try scratch.create([32]u8);
            handle.* = value.capability.id;
            break :blk .{ .atom = .{ .capability = handle } };
        },
        .timestamp => if (value == .timestamp) .{ .atom = .{ .timestamp = value.timestamp } } else return error.ProgramTypeMismatch,
        .json => if (value == .json) .{ .json = value.json } else return error.ProgramTypeMismatch,
        .structure => |fields| blk: {
            if (value != .record or fields.len != value.record.len) return error.ProgramTypeMismatch;
            const cells = try scratch.alloc(Cell, fields.len);
            for (fields, value.record, cells) |field, member, *cell| {
                // ROW constructors are positional; reads carry exact names.
                if (member.name.len != 0 and !std.mem.eql(u8, member.name, field.name)) return error.ProgramTypeMismatch;
                cell.* = try intoType(scratch, field.type, member.value, depth + 1);
            }
            break :blk .{ .structure = cells };
        },
        else => return error.ProgramTypeMismatch,
    };
    return .{ .value = result };
}
pub fn kvValue(output: std.mem.Allocator, read: c.DirectKVClient.Read) !Value {
    const cell = read.value orelse {
        if (read.revision != null) return error.InvalidTableResponse;
        return .null;
    };
    const revision = read.revision orelse return error.InvalidTableResponse;
    const value = try fromCell(output, .{ .name = "value", .type = read.spec.typeOf(), .nullable = read.spec.nullable }, cell);
    if (value != .record) return error.ProgramTypeMismatch;
    const fields = try output.alloc(a.Values.Field, value.record.len + 1);
    @memcpy(fields[0..value.record.len], value.record);
    fields[fields.len - 1] = .{ .name = "_revision", .value = .{ .binary = try output.dupe(u8, &try revision.encode()) } };
    return .{ .record = fields };
}
pub fn get(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, expected: c.DirectKV.Definition, key: Value) !Value {
    if (key != .binary) return error.ProgramTypeMismatch;
    const read = (try c.DirectKVClient.apply(output, client, .{ .get = .{ .object = expected.interpretation.interpretation.object, .key = key.binary } })).value;
    if (!std.meta.eql(read.interpretation, expected.interpretation)) return error.TableDefinitionChanged;
    return kvValue(output.allocator(), read);
}

/// Evaluate a single-record SELECT over the invocation's existing retained cut.
/// The caller owns the pin and must retain/release its original handle even if
/// this call fails. Row scratch is distinct from the retained environment and
/// output; neither a budget limit nor a second matching row produces a value.
pub const SelectLimits = struct { requests: u64, scan_rows: u64, result_bytes: u64 };
pub fn select(output: std.mem.Allocator, scratch: *std.heap.ArenaAllocator, driver: *a.Step, client: c.DirectTableClient, expected: c.DirectTableProtocol.Definition, snapshot: c.DirectTableProtocol.Snapshot, query: a.Select, limits: SelectLimits) !Value {
    if (limits.requests < 4 or limits.scan_rows == 0 or limits.result_bytes == 0) return error.InvalidQueryBudget;
    if (!std.mem.eql(u8, query.target, expected.name.slice())) return error.TableDefinitionChanged;
    var scan = try @import("DirectTableScan.zig").open(client.allocator, client, snapshot, limits.requests, null);
    defer scan.deinit();
    if (!std.meta.eql(expected.interpretation, scan.reader.basis.interpretation)) return error.TableDefinitionChanged;
    const schema = scan.reader.schema.schema;
    if (schema.columns.len > a.max_arguments) return error.ProgramTooComplex;
    const original_native = driver.native;
    const original_scratch = driver.scratch;
    defer {
        driver.native = original_native;
        driver.scratch = original_scratch;
    }
    var context: RowContext = .{ .parent = original_native, .row = &.{} };
    driver.native = .{ .context = &context, .lookup = RowContext.lookup, .evaluate = RowContext.evaluate, .condition = RowContext.condition };
    var result: Value = .null;
    var scanned: u64 = 0;
    while (try scan.nextBorrowed()) |cells| {
        if (scanned == limits.scan_rows) return error.QueryResultBudget;
        scanned += 1;
        _ = scratch.reset(.retain_capacity);
        driver.scratch = scratch.allocator();
        const row = try rowValue(scratch.allocator(), schema, cells, null, null);
        context.row = row.record;
        const evaluation = driver.evaluator();
        if (query.predicate) |predicate| if (!try evaluation.condition(try evaluation.evaluate(predicate))) continue;
        if (result != .null) return error.ProgramCardinalityMismatch;
        const revision = if (expected.document) |policy|
            try (try documentRevision(scan.reader.basis, policy)).stateFingerprint()
        else
            try scan.reader.basis.fingerprint();
        // Bound the actual selected representation before retaining it. The
        // public encoding contains only ordinary data and observation evidence.
        const selected = try rowValue(scratch.allocator(), schema, cells, query.columns, &revision);
        _ = p.Json.valueAllocBounded(scratch.allocator(), selected, @intCast(@min(limits.result_bytes, a.Codec.max_bytes))) catch |err| switch (err) {
            error.WriteFailed => return error.QueryResultBudget,
            else => return err,
        };
        result = try rowValue(output, schema, cells, query.columns, &revision);
    }
    try scan.validateCurrent();
    return result;
}
fn documentRevision(basis: c.DirectTableReader.Basis, policy: c.DirectDocument.Policy) !c.DirectDocument.Revision {
    const guard: p.Transaction.StateGuard = if (basis.workspace) |view| blk: {
        if (view.cut.begin.mode != .serializable) return error.InvalidTransactionGuard;
        break :blk view.source;
    } else .{ .source = .{ .interpretation = basis.interpretation.interpretation, .accepted = basis.accepted }, .changed_lsn = basis.changed_lsn };
    return .{ .definition = p.Growth.current_definition, .policy = policy, .guard = guard };
}

/// Point lookup over the bound Document's one-column primary key. Inside an
/// atomic block this observes the same serializable workspace and read guard
/// as SELECT. Outside a block, a changed basis is a refusal, never a new cut
/// silently substituted for the key read. Absence has no revision.
pub fn currentRevision(output: std.mem.Allocator, client: c.DirectTableClient, binding: q.ApplicationBinding, key: Value) !Value {
    return currentRevisionObserved(output, client, binding, key, null);
}
pub fn currentRevisionObserved(output: std.mem.Allocator, client: c.DirectTableClient, binding: q.ApplicationBinding, key: Value, reads: ?*q.ApplicationReadSet) !Value {
    if (binding.kind() != .document) return error.ProgramResourceKindMismatch;
    if (reads != null and client.transaction != null) return error.InvalidTransactionGuard;
    try key.public();
    const response = try client.call(.{ .document_lookup = .{ .namespace = binding.namespace(), .name = binding.name().slice() } });
    defer response.deinit();
    const metadata = try q.ApplicationTransaction.tableMetadata(response.value.result);
    if (!std.meta.eql(metadata.interpretation.interpretation, binding.interpretation())) return error.TableDefinitionChanged;
    const policy = metadata.document orelse return error.ProgramResourceKindMismatch;
    var schema = try f.TableSchema.decode(output, try metadata.schema.decode(output, f.TableSchema.max_bytes));
    defer schema.deinit();
    if (schema.schema.primary_key.len != 1) return error.ProgramTypeMismatch;
    const column = schema.schema.columns[try schema.schema.index(schema.schema.primary_key[0])];
    const cell = try intoCell(output, column.field(), key);
    const key_buffer = try output.alloc(u8, f.Collation.max_sort_key_bytes);
    const encoded_key = try f.Collation.encodePrimaryKeySortKey(schema.schema, &.{cell}, false, key_buffer);
    const revision: c.DirectDocument.Revision = if (client.transaction != null) blk: {
        var reader = try c.DirectTableReader.open(client.allocator, client, try q.ApplicationTransaction.snapshot(metadata));
        defer reader.deinit();
        if (!std.meta.eql(reader.basis.interpretation, metadata.interpretation)) return error.TableDefinitionChanged;
        var row = try reader.readKey(client, encoded_key);
        defer if (row) |*found| found.deinit();
        try reader.check(client);
        if (row == null) return .null;
        break :blk try documentRevision(reader.basis, policy);
    } else blk: {
        const read = try client.call(.{ .read_current = .{
            .namespace = binding.namespace(),
            .interpretation = binding.interpretation(),
            .expected = metadata.position,
            .selection = .{ .key = try c.DirectTableProtocol.Binary.encode(output, encoded_key) },
        } });
        defer read.deinit();
        const actual = try c.DirectDocument.Revision.fromRead(read.value.result.current_read.definition);
        if (reads) |set| try set.add(.{ .current_state = .{ .namespace = binding.namespace(), .kind = .table, .guard = actual.guard } }, read.value.policy_revision);
        if (read.value.result.current_read.selection.key == null) return .null;
        break :blk actual;
    };
    return .{ .binary = try output.dupe(u8, &try revision.stateFingerprint()) };
}
const RowContext = struct {
    parent: a.Evaluation.Host,
    row: []const a.Values.Field,
    fn lookup(context: *anyopaque, name: []const u8) anyerror!Value {
        const self: *RowContext = @ptrCast(@alignCast(context));
        for (self.row) |field| if (std.mem.eql(u8, field.name, name)) return field.value;
        return self.parent.lookup(self.parent.context, name);
    }
    fn evaluate(context: *anyopaque, node: a.Id, operation: a.Evaluation.Operation, arguments: []const Value) anyerror!Value {
        const self: *RowContext = @ptrCast(@alignCast(context));
        return self.parent.evaluate(self.parent.context, node, operation, arguments);
    }
    fn condition(context: *anyopaque, value: Value) anyerror!bool {
        const self: *RowContext = @ptrCast(@alignCast(context));
        return self.parent.condition(self.parent.context, value);
    }
};
pub fn rowValue(output: std.mem.Allocator, schema: f.TableSchema.Schema, cells: []const Cell, projection: ?[]const []const u8, revision: ?[]const u8) !Value {
    try schema.validateRow(cells);
    const count = if (projection) |columns| columns.len else schema.columns.len;
    const append_revision = projection == null and revision != null;
    const fields = try output.alloc(a.Values.Field, count + @as(usize, @intFromBool(append_revision)));
    for (fields[0..count], 0..) |*field, ordinal| {
        const index = if (projection) |columns| blk: {
            for (schema.columns, 0..) |column, index| if (std.mem.eql(u8, column.name, columns[ordinal])) break :blk index;
            return error.UnknownProgramField;
        } else ordinal;
        const column = schema.columns[index];
        field.* = .{ .name = try output.dupe(u8, column.name), .value = try fromCell(output, column.field(), cells[index]) };
    }
    if (append_revision) fields[count] = .{ .name = "_revision", .value = .{ .binary = try output.dupe(u8, revision.?) } };
    return .{ .record = fields };
}

pub fn rowCells(scratch: std.mem.Allocator, schema: f.TableSchema.Schema, values: []const Value) ![]const Cell {
    if (values.len != schema.columns.len or values.len > a.max_arguments) return error.ProgramTypeMismatch;
    const cells = try scratch.alloc(Cell, values.len);
    for (schema.columns, values, cells) |column, value, *cell| cell.* = try intoCell(scratch, column.field(), value);
    try schema.validateRow(cells);
    return cells;
}
/// A successful existing-row assertion is a serializable read participant. It
/// is not an unconditional ON CONFLICT ignore, and never opens a second cut.
/// null means that the original transaction must retain its guarded assertion.
pub fn prepareInsert(scratch: std.mem.Allocator, client: c.DirectTableClient, expected: c.DirectTableProtocol.Definition, snapshot: c.DirectTableProtocol.Snapshot, operation: u64, insert: @FieldType(a.Step.Action, "insert")) !?c.DirectTableIntent {
    if (client.transaction == null) return error.InvalidTransactionGuard;
    if (!std.mem.eql(u8, expected.name.slice(), insert.target)) return error.TableDefinitionChanged;
    var reader = try c.DirectTableReader.open(client.allocator, client, snapshot);
    defer reader.deinit();
    const view = reader.basis.workspace orelse return error.InvalidTransactionGuard;
    if (view.cut.begin.mode != .serializable or !std.meta.eql(expected.interpretation, reader.basis.interpretation)) return error.InvalidTransactionGuard;
    const schema = reader.schema.schema;
    if (schema.primary_key.len == 0 or schema.primary_key.len != insert.conflict_columns.len) return error.ProgramTypeMismatch;
    for (schema.primary_key, insert.conflict_columns) |id, name| if (!std.mem.eql(u8, schema.columns[try schema.index(id)].name, name)) return error.ProgramTypeMismatch;
    const cells = try rowCells(scratch, schema, insert.values);
    const proposed: f.TableRow.Row = .{ .identity = try c.DirectTableProtocol.Rows.insertIdentity(.{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation }, 0), .cells = cells };
    const key = try scratch.alloc(u8, f.Collation.max_sort_key_bytes);
    if (try reader.readKey(client, try proposed.storageKey(schema, key))) |found| {
        var existing = found;
        defer existing.deinit();
        try assertSameRow(scratch, schema, existing.row(), cells);
        try reader.check(client);
        return null;
    }
    try reader.check(client);
    return try c.DirectTableIntent.fromDml(client.allocator, client.connection, expected, operation, .{ .name = insert.target, .schema = schema, .action = .{ .insert = &.{cells} } }, .bulk);
}
fn assertSameRow(scratch: std.mem.Allocator, schema: f.TableSchema.Schema, existing: f.TableRow.Row, cells: []const Cell) !void {
    const expected: f.TableRow.Row = .{ .identity = existing.identity, .cells = cells };
    const old_size = try existing.encodedSize(schema);
    const new_size = try expected.encodedSize(schema);
    if (old_size != new_size) return error.ProgramRowAssertionFailed;
    const old = try scratch.alloc(u8, old_size);
    const new = try scratch.alloc(u8, new_size);
    if (!std.mem.eql(u8, try existing.encode(schema, old), try expected.encode(schema, new))) return error.ProgramRowAssertionFailed;
}
pub const Append = struct { work: c.DirectTransactionLogWork.Work, payload: c.DirectTableProtocol.Binary };
/// Freeze one schema-bound log append under its original operation. The common
/// transaction stages these exact bytes and validates the selected partition.
pub fn prepareAppend(scratch: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, expected: c.DirectLogClient.Metadata, operation: u64, append: @FieldType(a.Step.Action, "append")) !Append {
    const definition = expected.declaration;
    try definition.validate();
    try connection.object(definition.stored.declaration.interpretation.object);
    if (!std.mem.eql(u8, definition.properties.name.slice(), append.target) or (definition.kind() == .stream) != (append.kind == .stream)) return error.ProgramResourceKindMismatch;
    const schema = expected.schema;
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    if (!std.meta.eql(c.storage.LogBatch.content(try schema.encode(&schema_buffer)), definition.stored.declaration.schema)) return error.TableDefinitionChanged;
    const cells = try rowCells(scratch, schema, append.values);
    const identity: p.DataLifecycle.Operation = .{ .scope = connection.scope, .principal = connection.principal, .operation = operation };
    const maximum = @min(definition.stored.declaration.limits.append_bytes, c.DirectTableProtocol.max_work_bytes);
    const buffer = try scratch.alloc(u8, @intCast(maximum));
    const bytes = try c.storage.LogBatch.encode(schema, identity, definition.kind(), &.{.{ .cells = cells }}, buffer);
    const partitioning = definition.stored.declaration.configuration.partitioning;
    const partition: u32 = if (partitioning.key_column) |id| blk: {
        const index = try schema.index(id);
        const column = schema.columns[index];
        const key_buffer = try scratch.alloc(u8, f.Collation.max_sort_key_bytes);
        break :blk try partitioning.select(try f.Collation.encodeSortKey(cells[index], column.type, column.collation, key_buffer));
    } else 0;
    const work: c.DirectTransactionLogWork.Work = .{ .append = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = partition }, .operation = identity, .kind = if (append.kind == .stream) .stream else .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(bytes) } };
    try work.validate();
    return .{ .work = work, .payload = try c.DirectTableProtocol.Binary.encode(scratch, bytes) };
}
/// Pure native mutation preparation. Save the exact request before submission;
/// the transaction owner, not this function, checks current rights and commits.
pub fn preparePut(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, expected: c.DirectKV.Definition, operation: u64, put: @FieldType(a.Step.Action, "put")) !c.DirectKV.Mutation {
    if (put.key != .binary or put.value != .record or !std.mem.eql(u8, expected.name.slice(), put.target)) return error.ProgramTypeMismatch;
    const field: f.Types.Field = .{ .name = "value", .type = expected.spec.typeOf(), .nullable = expected.spec.nullable };
    if (field.type != .structure) return error.ProgramTypeMismatch;
    const definition_fields = field.type.structure;
    var value = put.value;
    if (put.fields.len != 0) {
        if (value.record.len != definition_fields.len + 1 or !std.mem.eql(u8, value.record[value.record.len - 1].name, "_revision")) return error.ProgramTypeMismatch;
        const fields = try output.allocator().dupe(a.Values.Field, value.record[0..definition_fields.len]);
        for (put.fields, 0..) |change, i| {
            for (put.fields[0..i]) |prior| if (std.mem.eql(u8, prior.name, change.name)) return error.DuplicateProgramField;
            var found = false;
            for (fields) |*target| if (std.mem.eql(u8, target.name, change.name)) {
                target.value = change.value;
                found = true;
                break;
            };
            if (!found) return error.UnknownProgramField;
        }
        value = .{ .record = fields };
    }
    const revision: ?f.TableRow.Identity = switch (put.expected) {
        .absent => null,
        .revision => |bytes| blk: {
            if (bytes != .binary or bytes.binary.len != f.TableRow.Identity.encoded_bytes) return error.InvalidRowIdentity;
            break :blk try f.TableRow.Identity.decode(bytes.binary[0..f.TableRow.Identity.encoded_bytes]);
        },
    };
    return c.DirectKVClient.prepareMutation(output, .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = operation },
        .target = expected.interpretation.interpretation.object,
        .action = .insert,
        .expected_definition = expected.interpretation.interpretation,
        .expected_data = null,
        .intent = @splat(0),
    }, expected.spec, &.{.{ .put = .{ .key = put.key.binary, .value = try intoCell(output.allocator(), field, value), .expect = if (revision != null) .present else .absent, .expected_revision = revision } }});
}

test "application native values preserve timestamp units, constraints and owned nested strings" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const field: f.Types.Field = .{ .name = "value", .type = .{ .structure = &.{ .{ .name = "label", .type = .utf8, .max_characters = 3 }, .{ .name = "created", .type = .{ .timestamp = .utc } } } } };
    var text = "abc".*;
    const input: Value = .{ .record = &.{ .{ .name = "label", .value = .{ .text = &text } }, .{ .name = "created", .value = .{ .timestamp = 1_000_001 } } } };
    const cell = try intoCell(arena.allocator(), field, input);
    const copy = try fromCell(arena.allocator(), field, cell);
    @memset(&text, 'x');
    try t.expectEqualStrings("abc", (try copy.field("label")).text);
    try t.expectEqual(@as(i64, 1_000_001), (try copy.field("created")).timestamp);
    try t.expectError(error.CharacterLimitExceeded, intoCell(arena.allocator(), field.type.structure[0], .{ .text = "long" }));
    try t.expectError(error.ProtectedProgramValue, intoCell(arena.allocator(), .{ .name = "value", .type = .binary }, .{ .capability = .{ .id = @splat(1) } }));
    try t.expectError(error.ProgramTypeMismatch, fromCell(arena.allocator(), .{ .name = "value", .type = .utf8 }, .{ .type_error = .int64 }));
}

test "application native Queue records retain typed capability handles without binary coercion" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const field: f.Types.Field = .{ .name = "row", .type = .{ .structure = &.{
        .{ .name = "request", .type = .capability },
        .{ .name = "id", .type = .uuid },
    } } };
    const value: Value = .{ .record = &.{
        .{ .name = "request", .value = .{ .capability = .{ .id = @splat(7) } } },
        .{ .name = "id", .value = .{ .uuid = @splat(8) } },
    } };
    try value.validate(try bindField(arena.allocator(), field));
    const cell = try intoCell(arena.allocator(), field, value);
    var buffer: [128]u8 = undefined;
    const wire = try f.Types.Codec.encodeBound(cell, field, &buffer);
    const copy = try fromCell(arena.allocator(), field, try f.Types.Codec.decodeBound(&arena, field, wire));
    try t.expectEqualDeep(value, copy);
    try t.expectError(error.ProtectedProgramValue, copy.public());
    const untyped: [32]u8 = @splat(7);
    try t.expectError(error.ProgramTypeMismatch, intoCell(arena.allocator(), field.type.structure[0], .{ .binary = &untyped }));
    try t.expectError(error.ProtectedProgramValue, intoCell(arena.allocator(), field.type.structure[0], .{ .sealed = .{ .kind = .binary, .reference = .{ .id = @splat(7) } } }));
}

test "application native KV update preserves exact revision and saved original mutation" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = null };
    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = undefined, .service = undefined, .connection = connection, .key = undefined };
    const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .row, .nullable = false, .fields = &.{ .{ .name = "state", .type = .utf8 }, .{ .name = "at", .type = .{ .timestamp = .utc } } } };
    var columns: [2]f.TableSchema.Column = undefined;
    const object: p.DataLifecycle.Object = .{ .scope = connection.scope, .branch = 1, .object = 7 };
    var definition = try c.storage.TableDeclaration.prepare(t.allocator, .{ .kind = .kv, .object = object, .revision = 1, .schema = spec.schema(7, &columns), .properties = "" });
    defer definition.deinit();
    const metadata: c.DirectKV.Definition = .{ .interpretation = try definition.stored(), .namespace = 1, .name = try .init("states"), .authorization = 11, .spec = spec, .retired = false, .position = .{ .partition = 8, .next_lsn = 10 }, .changed_lsn = 10 };
    const revision: f.TableRow.Identity = .{ .origin = 11, .operation = 12, .ordinal = 0 };
    const value = try kvValue(arena.allocator(), .{ .interpretation = metadata.interpretation, .position = metadata.position, .changed_lsn = 10, .spec = spec, .source = null, .workspace = null, .value = .{ .value = .{ .structure = &.{ .{ .value = .{ .atom = .{ .bytes = "issued" } } }, .{ .value = .{ .atom = .{ .timestamp = 1_000_001 } } } } } }, .revision = revision });
    const put: @FieldType(a.Step.Action, "put") = .{ .target = "states", .key = .{ .binary = "key" }, .value = value, .fields = &.{.{ .name = "state", .value = .{ .text = "claimed" } }}, .expected = .{ .revision = try value.field("_revision") } };
    const prepared = try preparePut(&arena, client, metadata, 17, put);
    const saved = try c.DirectKVClient.save(t.allocator, connection, prepared);
    defer t.allocator.free(saved);
    var restored = try c.DirectKVClient.load(t.allocator, saved);
    defer restored.deinit();
    try t.expectEqual(@as(u64, 17), restored.value.mutation.binding.identity.operation);
    const changes = try restored.value.mutation.decodeChanges(arena.allocator(), spec);
    try t.expectEqual(revision, changes[0].put.expected_revision.?);
    try t.expectEqual(.present, changes[0].put.expect);
    try t.expectEqualStrings("claimed", changes[0].put.value.value.structure[0].value.atom.bytes);
    try t.expectEqual(@as(i64, 1_000_001), changes[0].put.value.value.structure[1].value.atom.timestamp);
    var invalid = put;
    invalid.fields = &.{.{ .name = "_revision", .value = .{ .binary = "forged" } }};
    try t.expectError(error.UnknownProgramField, preparePut(&arena, client, metadata, 18, invalid));
    invalid = put;
    invalid.expected = .{ .revision = .{ .binary = "short" } };
    try t.expectError(error.InvalidRowIdentity, preparePut(&arena, client, metadata, 18, invalid));
    try t.expectError(error.ProgramTypeMismatch, get(&arena, client, metadata, .{ .text = "key" }));
    var driver: a.Step = undefined;
    try t.expectError(error.InvalidQueryBudget, select(arena.allocator(), &arena, &driver, client, undefined, undefined, undefined, .{ .requests = 0, .scan_rows = 0, .result_bytes = 0 }));
    try t.expectError(error.InvalidTransactionGuard, prepareInsert(arena.allocator(), client, undefined, undefined, 1, undefined));
}

test "application native row assertion compares all values without replacing identity" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .utf8, .nullable = false } }, .primary_key = &.{1} };
    const old_cells = try rowCells(arena.allocator(), schema, &.{ .{ .integer = 1 }, .{ .text = "accepted" } });
    const old: f.TableRow.Row = .{ .identity = .{ .origin = 8, .operation = 9, .ordinal = 0 }, .cells = old_cells };
    const same = try rowCells(arena.allocator(), schema, &.{ .{ .integer = 1 }, .{ .text = "accepted" } });
    try assertSameRow(arena.allocator(), schema, old, same);
    const changed = try rowCells(arena.allocator(), schema, &.{ .{ .integer = 1 }, .{ .text = "modified" } });
    try t.expectError(error.ProgramRowAssertionFailed, assertSameRow(arena.allocator(), schema, old, changed));
    const projected = try rowValue(arena.allocator(), schema, old_cells, &.{"value"}, "revision");
    try t.expectEqual(@as(usize, 1), projected.record.len);
    try t.expectEqualStrings("accepted", (try projected.field("value")).text);
    try t.expectError(error.UnknownProgramField, projected.field("_revision"));
}

test "application native append freezes schema values and original log identity" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = null };
    const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64, .nullable = false }, .{ .id = 2, .name = "value", .type = .utf8, .nullable = false } }, .primary_key = &.{} };
    const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .authorization = 11, .name = try .init("events") };
    var properties_buffer: [4096]u8 = undefined;
    var declaration = try c.storage.LogDeclaration.prepare(t.allocator, .{
        .object = .{ .scope = connection.scope, .branch = 1, .object = 7 },
        .revision = 1,
        .schema = schema,
        .configuration = .{ .partitioning = .{ .count = 1, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } },
        .limits = .{ .append_rows = 16, .append_bytes = 8192, .claim_rows = 1, .read_rows = 16, .read_bytes = 8192, .active_leases = 16, .waiters = 16, .timer_steps = 16 },
        .properties = try properties.encode(&properties_buffer),
    });
    defer declaration.deinit();
    const stored = try declaration.stored();
    const metadata: c.DirectLogClient.Metadata = .{ .declaration = .{ .stored = stored, .properties = properties, .seed = stored, .initialization = .{ .scope = connection.scope, .principal = 4, .operation = 12 }, .first_partition = 1 }, .schema = schema };
    var text = "accepted".*;
    const append = try prepareAppend(arena.allocator(), connection, metadata, 42, .{ .kind = .stream, .target = "events", .values = &.{ .{ .integer = 17 }, .{ .text = &text } } });
    @memset(&text, 'x');
    try t.expectEqual(@as(u64, 42), append.work.append.operation.operation);
    try t.expectEqual(@as(u32, 0), append.work.append.target.partition);
    const bytes = try append.payload.decode(arena.allocator(), 8192);
    var rows = try c.storage.LogBatch.Iterator.init(bytes, schema, .stream, 1);
    const row = try (try rows.next()).?.decode(arena.allocator(), schema, append.work.append.operation);
    try t.expectEqual(@as(i128, 17), row.cells[0].value.atom.signed);
    try t.expectEqualStrings("accepted", row.cells[1].value.atom.bytes);
    try t.expect(try rows.next() == null);
    try t.expectError(error.ProgramResourceKindMismatch, prepareAppend(arena.allocator(), connection, metadata, 43, .{ .kind = .queue, .target = "events", .values = &.{} }));
}
