//! Typed pages over public authorized readers. data is an exact captured or
//! retained source; current supplies live Document lifecycle checks. No I/O or
//! capability is introduced beyond the supplied readers.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const m = q.fuze.Unified;
const doc = q.document;
const Def = q.SourceDefinition;
pub const Cursor = struct {
    ordinal: u64 = 0,
    after: ?p.Value = null,
    table_after: ?i64 = null,
    traversal: doc.Document.SequenceCursor = .{},
    done: bool = false,
};
pub const Batch = struct {
    columns: [m.max_columns]m.Column = undefined,
    column_count: u8 = 0,
    cells: [m.max_rows][m.max_columns]m.Cell = undefined,
    rows: [m.max_rows]m.Row = undefined,
    count: u8 = 0,
    next: Cursor = .{},
    basis: m.Basis = undefined,
    ordinal: u64 = 0,
    pub fn schema(self: *const Batch) m.Schema {
        return .{ .columns = self.columns[0..self.column_count] };
    }
    pub fn engine(self: *Batch) m.Page {
        for (self.rows[0..self.count], self.cells[0..self.count]) |*row, *cells| row.* = .{ .cells = cells[0..self.column_count] };
        return .{ .basis = self.basis, .ordinal = self.ordinal, .rows = self.rows[0..self.count], .end = self.next.done };
    }
};
pub fn basis(definition: Def, revision: u64) !m.Basis {
    var columns: [m.max_columns]m.Column = undefined;
    return .{ .kind = std.meta.activeTag(definition.source), .resource = definition.resource, .revision = revision, .contract = try definition.fingerprint(), .schema = try (try definition.schema(&columns)).fingerprint() };
}
/// Current declaration/lifecycle evidence, including after capture releases its
/// source pin. A retained source must never be passed as the current reader.
pub fn checkCurrent(definition: Def, current: anytype) !void {
    if (current.view.resource != definition.resource) return error.SourceChanged;
    switch (definition.source) {
        .kv => {},
        .table => |table| {
            if (!std.meta.eql((try q.station.Table.open(current, table.id)).schema, table.schema)) return error.TableSchemaChanged;
        },
        .document => |document| {
            const service = try document.reference.identity().service();
            try checkReference(document.reference, try service.open(current, document.reference.revision));
        },
    }
}
/// Every pointer in output borrows the caller's bounded arena or output itself.
/// An error invalidates the whole page. Never publish a partially filled batch.
pub fn page(definition: Def, expected: m.Basis, cursor: Cursor, data: anytype, current: anytype, allocator: std.mem.Allocator, output: *Batch) !void {
    if (cursor.done) return error.QueryComplete;
    if (data.view.resource != definition.resource or !std.meta.eql(expected, try basis(definition, data.view.revision))) return error.SourceChanged;
    output.* = .{ .basis = expected, .ordinal = cursor.ordinal, .next = cursor };
    output.column_count = @intCast((try definition.schema(&output.columns)).columns.len);
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
                output.cells[output.count][0] = try q.Decoder.decode(kv.key, allocator, entry.key.slice());
                output.cells[output.count][1] = try q.Decoder.decode(kv.value, allocator, entry.value.slice());
                output.count += 1;
            };
            if (entries.next == null) output.next.done = true;
        },
        .table => |table_definition| {
            // page() validates this declaration against the captured descriptor.
            // Reuse the compiled schema instead of fetching it twice per page.
            const table: q.station.Table = .{ .resource = definition.resource, .id = table_definition.id, .schema = table_definition.schema };
            const continuation: ?q.station.Table.Cursor = if (cursor.table_after) |after| .{
                .source = if (@TypeOf(data.view.id) == u64) .{ .view = data.view.id } else .{ .version = data.view.id },
                .resource = definition.resource,
                .revision = expected.revision,
                .table = table.id,
                .schema = try table.schema.fingerprint(),
                .after = after,
            } else null;
            const rows = try table.page(data, continuation);
            for (rows.rows[0..rows.len]) |row| {
                output.cells[output.count][0] = .{ .value = .{ .int64 = row.key } };
                output.cells[output.count][1] = switch (row.value) {
                    .null => .null,
                    .int64 => |value| .{ .value = .{ .int64 = value } },
                    .boolean => |value| .{ .value = .{ .boolean = value } },
                    .utf8 => |value| .{ .value = .{ .utf8 = try allocator.dupe(u8, value.slice()) } },
                    .binary => |value| .{ .value = .{ .binary = try allocator.dupe(u8, value.slice()) } },
                };
                output.count += 1;
            }
            output.next.table_after = if (rows.next) |next| next.after else null;
            output.next.done = rows.next == null;
        },
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
                            for (document.projections, 0..) |projection, index| output.cells[output.count][index] = try project(state, &reader, projection, item, allocator, &work);
                            output.count += 1;
                            if (output.count == m.max_rows) break;
                        },
                    }
                }
            } else {
                if (cursor.ordinal != 0) return error.InvalidQueryOrdinal;
                for (document.projections, 0..) |projection, index| output.cells[0][index] = try project(state, &reader, projection, null, allocator, &work);
                output.count = 1;
                output.next.done = true;
            }
            // A supplied current reader must still permit the same accepted
            // snapshot after the retained bytes and nested values were read.
            try checkReference(document.reference, try service.open(current, document.reference.revision));
        },
    }
    try output.engine().validate(output.schema());
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
