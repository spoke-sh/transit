//! Bounded logical pages over exact captured data and independently current
//! authorization. Decoder inputs retain their declared scalar admission profile.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const f = q.fuze;
const t = f.Types;
const m = f.Unified;
const doc = q.document;
const Def = q.SourceDefinition;
pub const Cursor = struct {
    ordinal: u64 = 0,
    after: ?p.Value = null,
    table_after: ?f.TableRow.Identity = null,
    table_scanned: u64 = 0,
    traversal: doc.Document.SequenceCursor = .{},
    done: bool = false,
};
pub const Batch = struct {
    pub const Key = union(enum) { kv: p.Value, table: f.TableRow.Identity, element: doc.Model.Dot };
    columns: [Def.max_columns]t.Field = undefined,
    column_count: u8 = 0,
    cells: [f.LogicalArrow.max_rows][Def.max_columns]t.Values.Cell = undefined,
    rows: [f.LogicalArrow.max_rows]f.LogicalArrow.Row = undefined,
    keys: [f.LogicalArrow.max_rows]?Key = @splat(null),
    decoding: [f.LogicalArrow.max_rows][Def.max_columns]?q.Decoder.Failure = @splat(@splat(null)),
    count: u8 = 0,
    next: Cursor = .{},
    basis: q.Basis = undefined,
    binding: [32]u8 = undefined,
    ordinal: u64 = 0,
    table: ?q.TableSource.Page = null,
    pub fn deinit(self: *Batch) void {
        if (self.table) |*page_| page_.deinit();
        self.* = undefined;
    }
    pub fn schema(self: *const Batch) t.Type {
        return .{ .structure = self.columns[0..self.column_count] };
    }
    pub fn engine(self: *Batch) f.LogicalStream.Page {
        if (self.table) |*page_| return page_.engine();
        for (self.rows[0..self.count], self.cells[0..self.count]) |*row, *cells| row.* = .{ .cells = cells[0..self.column_count] };
        return .{ .binding = self.binding, .ordinal = self.ordinal, .rows = self.rows[0..self.count], .end = self.next.done };
    }
};
/// Decoder sources have no Table head. Table capture must resolve its exact head.
pub fn basis(definition: Def, revision: u64) !q.Basis {
    if (definition.source == .table) return error.TableBasisRequired;
    return q.Basis.from(definition, try q.Basis.Cut.native(std.meta.activeTag(definition.source), definition.resource, revision));
}
pub fn capture(definition: Def, data: anytype, current: anytype, principal: ?u64, allocator: std.mem.Allocator) !q.Basis {
    return captureDiagnostic(definition, data, current, principal, allocator, null);
}
pub fn captureDiagnostic(definition: Def, data: anytype, current: anytype, principal: ?u64, allocator: std.mem.Allocator, diagnostic: ?*?q.SourceWitness) !q.Basis {
    _ = allocator;
    _ = diagnostic;
    if (definition.source == .table) return error.TableBasisRequired;
    try checkCurrent(definition, current, principal);
    if (data.view.resource != definition.resource) return error.SourceChanged;
    return basis(definition, data.view.revision);
}
/// Current rights remain mandatory after the source pin is released. A Table's
/// old metadata is checked only at admission or against its retained data cut.
pub fn checkCurrent(definition: Def, current: anytype, principal: ?u64) !void {
    return checkCurrentDiagnostic(definition, current, principal, null);
}
pub fn checkCurrentDiagnostic(definition: Def, current: anytype, principal: ?u64, diagnostic: ?*?q.SourceWitness) !void {
    _ = principal;
    if (diagnostic) |detail| detail.* = null;
    if (current.view.resource != definition.resource) {
        if (diagnostic) |detail| detail.* = .{ .reason = .resource, .resource = definition.resource, .expected = definition.resource, .actual = current.view.resource };
        return error.SourceChanged;
    }
    switch (definition.source) {
        .kv => {},
        .table => return error.TableBasisRequired,
        .document => |document| {
            const service = try document.reference.identity().service();
            try checkReference(document.reference, try service.open(current, document.reference.revision));
        },
    }
}
fn logicalCell(expected: m.Type, value: m.Cell, allocator: std.mem.Allocator) !t.Values.Cell {
    return t.Values.fromQuery(allocator, expected, value);
}
/// Call deinit on successful output. Other slices borrow the caller's bounded
/// request arena; any error invalidates the whole page.
pub fn page(definition: Def, plan: f.LogicalQuery.Plan, expected: q.Basis, cursor: Cursor, data: anytype, current: anytype, principal: ?u64, allocator: std.mem.Allocator, output: *Batch) !void {
    if (definition.source == .table) return error.TableBasisRequired;
    if (cursor.done) return error.QueryComplete;
    if (data.view.resource != definition.resource or data.view.revision != try expected.cut.nativeRevision() or !std.meta.eql(expected, try q.Basis.from(definition, expected.cut))) return error.SourceChanged;
    try checkCurrent(definition, current, principal);
    const binding = try expected.fingerprint();
    if (!std.mem.eql(u8, &binding, &plan.source_basis)) return error.SourceChanged;
    output.* = .{ .basis = expected, .binding = binding, .ordinal = cursor.ordinal, .next = cursor };
    errdefer output.deinit();
    const schema = try definition.schema(&output.columns);
    output.column_count = @intCast(schema.structure.len);
    if (definition.source == .table) @memcpy(output.columns[0..output.column_count], schema.structure);
    output.next.ordinal = try std.math.add(u64, cursor.ordinal, 1);
    switch (definition.source) {
        .kv => |kv| {
            const entries = try data.page(cursor.after);
            for (entries.entries) |slot| if (slot) |entry| {
                output.next.after = entry.key;
                if (!std.mem.startsWith(u8, entry.key.slice(), kv.prefix.slice())) {
                    if (std.mem.order(u8, entry.key.slice(), kv.prefix.slice()) == .gt) {
                        output.next.done = true;
                        break;
                    }
                    continue;
                }
                output.cells[output.count][0] = try logicalCell(kv.key.type, try q.Decoder.decodeDiagnostic(kv.key, allocator, entry.key.slice(), &output.decoding[output.count][0]), allocator);
                output.cells[output.count][1] = try logicalCell(kv.value.type, try q.Decoder.decodeDiagnostic(kv.value, allocator, entry.value.slice(), &output.decoding[output.count][1]), allocator);
                output.keys[output.count] = .{ .kv = entry.key };
                output.count += 1;
            };
            if (entries.next == null) output.next.done = true;
        },
        .table => unreachable,
        .document => |document| {
            const service = try document.reference.identity().service();
            const live = try service.open(current, document.reference.revision);
            try checkReference(document.reference, live);
            const state = try doc.Service.records.openSnapshot((try data.read(service.key('v', document.reference.revision))) orelse return error.DocumentHistoryGap);
            if (!std.meta.eql(state, live)) return error.SourceChanged;
            var reader: q.station.ImmutableIndex.Reader(@TypeOf(data)) = .{ .publication = service.publication(), .source = data };
            var work: u32 = 4096;
            if (document.expand) |path| {
                const list = try state.path(&reader, path);
                switch (list.status()) {
                    .missing => return error.QueryExpansionMissing,
                    .null_value => return error.QueryExpansionNull,
                    .conflict => return error.QueryExpansionConflict,
                    .scalar => return error.QueryExpansionTypeError,
                    .object => if (list.assignments[0].value != .list) return error.QueryExpansionTypeError,
                }
                for (0..32) |_| {
                    switch (try state.sequenceStep(&reader, list.assignments[0].id, &output.next.traversal)) {
                        .end => {
                            output.next.done = true;
                            break;
                        },
                        .more => {},
                        .item => |item| {
                            for (document.projections, 0..) |projection, index| output.cells[output.count][index] = try logicalCell(projection.column.type, try project(state, &reader, projection, item, allocator, &work), allocator);
                            output.keys[output.count] = .{ .element = item.id };
                            output.count += 1;
                            if (output.count == m.max_rows) break;
                        },
                    }
                }
            } else {
                if (cursor.ordinal != 0) return error.InvalidQueryOrdinal;
                for (document.projections, 0..) |projection, index| output.cells[0][index] = try logicalCell(projection.column.type, try project(state, &reader, projection, null, allocator, &work), allocator);
                output.count = 1;
                output.next.done = true;
            }
            // A supplied current reader must still permit the same accepted
            // snapshot after the retained bytes and nested values were read.
            try checkReference(document.reference, try service.open(current, document.reference.revision));
        },
    }
    try checkCurrent(definition, current, principal);
}
/// Direct pages use the separately retained source proof and direct owner. The
/// enclosing computation attaches its native publication guard independently.
pub fn tablePage(definition: Def, plan: f.LogicalQuery.Plan, expected: q.Basis, retained: q.catalog.DirectTableReader.Basis, cursor: Cursor, client: q.catalog.DirectTableClient, allocator: std.mem.Allocator, output: *Batch) !void {
    if (definition.source != .table) return error.InvalidQuerySource;
    if (cursor.done) return error.QueryComplete;
    const table = definition.source.table;
    const captured: q.TableSource.Basis = .{ .declaration = try table.fingerprint(), .schema = try table.row_type.fingerprint(), .retained = retained };
    if (!std.meta.eql(try captured.record(), expected)) return error.SourceChanged;
    const binding = try expected.fingerprint();
    if (!std.mem.eql(u8, &binding, &plan.source_basis)) return error.SourceChanged;
    output.* = .{ .basis = expected, .binding = binding, .ordinal = cursor.ordinal, .next = cursor };
    errdefer output.deinit();
    const schema = try definition.schema(&output.columns);
    output.column_count = @intCast(schema.structure.len);
    @memcpy(output.columns[0..output.column_count], schema.structure);
    output.next.ordinal = try std.math.add(u64, cursor.ordinal, 1);
    output.table = try table.page(allocator, captured, .{ .binding = binding, .ordinal = cursor.ordinal, .scanned = cursor.table_scanned, .after = cursor.table_after, .done = cursor.done }, plan, client);
    const rows = &output.table.?;
    output.count = rows.count;
    output.next.table_after = rows.next.after;
    output.next.table_scanned = rows.next.scanned;
    output.next.done = rows.next.done;
    for (rows.owned[0..rows.count], 0..) |row, index| output.keys[index] = .{ .table = row.?.identity };
}
fn checkReference(reference: doc.Client.Reference, state: doc.Document) !void {
    if (state.document != reference.document or state.epoch != reference.epoch or state.type_revision != reference.type_revision or state.revision != reference.revision) return error.DocumentIdentityMismatch;
}
fn kind(value: doc.Scalar) m.Kind {
    return switch (value) {
        .null_value => .null_value,
        .boolean => .boolean,
        .signed => .int64,
        .unsigned => .uint64,
        .float => .float64,
        .string => .utf8,
        .binary => .binary,
        .map => .map,
        .list => .list,
        .text => .text,
        .character => .character,
    };
}
fn project(state: doc.Document, reader: anytype, projection: Def.Projection, item: ?doc.Document.SequenceItem, allocator: std.mem.Allocator, work: *u32) !m.Cell {
    if (projection.mode == .element_counter or projection.mode == .element_replica) {
        const element = item orelse return error.InvalidElementProjection;
        return .{ .value = .{ .uint64 = if (projection.mode == .element_counter) element.id.counter else element.id.replica } };
    }
    const register = (if (projection.relative) relativePath(state, reader, item.?.values, projection.path) else state.path(reader, projection.path)) catch |err| switch (err) {
        error.DocumentTypeError => return .{ .type_error = .unknown },
        else => return err,
    };
    if (register.len == 0) return .missing;
    if (register.len == 1) return assignment(state, reader, register.assignments[0], projection, allocator, work);
    const alternatives = try allocator.alloc(m.Alternative, register.len);
    for (register.assignments[0..register.len], alternatives) |value, *alternative| {
        const cell = try assignment(state, reader, value, projection, allocator, work);
        alternative.* = .{ .counter = value.id.counter, .replica = value.id.replica, .value = switch (cell) {
            .null => .null,
            .type_error => |actual| .{ .type_error = actual },
            .value => |scalar| .{ .value = scalar },
            else => return error.InvalidDocumentState,
        } };
    }
    return .{ .conflict = alternatives };
}
fn relativePath(state: doc.Document, reader: anytype, start: doc.Document.Register, path: []const doc.Model.Name) !doc.Document.Register {
    var register = start;
    for (path) |name| {
        if (register.status() == .missing or register.status() == .conflict) return register;
        if (register.status() != .object or register.assignments[0].value != .map) return error.DocumentTypeError;
        register = try state.field(reader, register.assignments[0].id, name);
    }
    return register;
}
fn assignment(state: doc.Document, reader: anytype, value: doc.Document.Assignment, projection: Def.Projection, allocator: std.mem.Allocator, work: *u32) !m.Cell {
    if (value.value == .null_value) return .null;
    if (projection.mode == .text) {
        if (value.value != .text) return .{ .type_error = kind(value.value) };
        var text: [m.max_cell_bytes]u8 = undefined;
        var len: usize = 0;
        var cursor: doc.Document.SequenceCursor = .{};
        for (0..projection.text_steps) |_| {
            if (work.* == 0) return error.QueryProjectionBudget;
            work.* -= 1;
            switch (try state.sequenceStep(reader, value.id, &cursor)) {
                .end => return .{ .value = .{ .utf8 = try allocator.dupe(u8, text[0..len]) } },
                .more => {},
                .item => |element| {
                    if (element.values.len != 1 or element.values.assignments[0].value != .character) return error.InvalidDocumentText;
                    var encoded: [4]u8 = undefined;
                    const length = try std.unicode.utf8Encode(@intCast(element.values.assignments[0].value.character), &encoded);
                    if (len + length > projection.text_bytes) return error.QueryProjectionBudget;
                    @memcpy(text[len..][0..length], encoded[0..length]);
                    len += length;
                },
            }
        }
        return error.QueryProjectionBudget;
    }
    const expected: m.Kind = @fromBackingInt(@intCast(@backingInt(projection.column.type)));
    if (kind(value.value) != expected) return .{ .type_error = kind(value.value) };
    return .{ .value = switch (value.value) {
        .boolean => |scalar| .{ .boolean = scalar },
        .signed => |scalar| .{ .int64 = scalar },
        .unsigned => |scalar| .{ .uint64 = scalar },
        .float => |scalar| .{ .float64 = scalar },
        .string => |scalar| .{ .utf8 = try allocator.dupe(u8, scalar.slice()) },
        .binary => |scalar| .{ .binary = try allocator.dupe(u8, scalar.slice()) },
        else => return error.InvalidDocumentState,
    } };
}
