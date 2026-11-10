//! Immutable columnar representation of one accepted append. The original
//! receipt, row identities and delivery metadata survive physical placement
//! inside native `.tseg` system columns; the object publishes no locator by itself.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Objects = @import("TransitObjectStore.zig");
const Batch = @import("LogBatch.zig");
const Evidence = @import("LogEvidence.zig");
const Declaration = @import("LogDeclaration.zig");
const pages = @import("TreeStore.zig").pages;
pub const offset_column_name = "transit.log._offset";
pub const timestamp_column_name = "transit.log._timestamp";
pub const tombstone_column_name = "transit.log._tombstone";
pub const system_columns = 3;
pub const max_user_columns = f.TableSchema.max_columns - system_columns;
pub const max_rows = @import("TransitLog.zig").max_payload_bytes / (Batch.row_header_bytes + f.TableRow.header_bytes);
pub const Layout = enum(u8) { complete = 1, sparse = 2 };
pub const Descriptor = struct {
    layout: Layout,
    rows: u32,
    evidence: d.Content,
    segment: ?d.Content,
    pub fn validate(self: Descriptor) !void {
        _ = try Evidence.reference(self.evidence);
        if (self.segment) |segment| {
            try segment.validate();
            if (segment.bytes > f.TSeg.max_segment_bytes) return error.InvalidLogSegment;
        }
        if ((self.rows != 0) != (self.segment != null) or (self.layout == .complete and self.rows == 0) or self.rows > max_rows) return error.InvalidLogSegment;
    }
    pub fn encode(self: Descriptor) !pages.Value {
        try self.validate();
        var bytes: [85]u8 = @splat(0);
        bytes[0] = @backingInt(self.layout);
        std.mem.writeInt(u32, bytes[1..5], self.rows, .big);
        for ([_]?d.Content{ self.evidence, self.segment }, 0..) |content, i| if (content) |value| {
            std.mem.writeInt(u64, bytes[5 + i * 40 ..][0..8], value.bytes, .big);
            bytes[13 + i * 40 ..][0..32].* = value.sha256;
        };
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Descriptor {
        if (value.len != 85) return error.InvalidLogSegment;
        const layout = std.enums.fromInt(Layout, value.data[0]) orelse return error.InvalidLogSegment;
        var contents: [2]d.Content = undefined;
        for (&contents, 0..) |*content, i| content.* = .{ .bytes = std.mem.readInt(u64, value.data[5 + i * 40 ..][0..8], .big), .sha256 = value.data[13 + i * 40 ..][0..32].* };
        const segment: ?d.Content = if (std.mem.allEqual(u8, value.data[45..85], 0)) null else contents[1];
        const result: Descriptor = .{ .layout = layout, .rows = std.mem.readInt(u32, value.data[1..5], .big), .evidence = contents[0], .segment = segment };
        try result.validate();
        return result;
    }
    pub fn iterator(self: Descriptor, bytes: []const u8, schema: f.TableSchema.Schema, append: p.StreamQueue.Append) !Batch.Rows {
        try self.validate();
        return switch (self.layout) {
            .complete => blk: {
                if (self.rows != append.rows) return error.InvalidLogSegment;
                if (!std.meta.eql(append.payload, Batch.content(bytes))) return error.LogPayloadConflict;
                break :blk .{ .complete = try Batch.Iterator.init(bytes, schema, if (append.kind == .stream) .stream else .queue, append.rows) };
            },
            .sparse => blk: {
                if (append.kind != .stream or bytes.len > append.payload.bytes) return error.InvalidLogSegment;
                const rows = try Batch.SparseIterator.init(bytes, schema, append.rows);
                if (rows.count != self.rows or self.rows > append.rows / 2) return error.InvalidLogSegment;
                break :blk .{ .sparse = rows };
            },
        };
    }
};

pub fn storageSchema(schema: f.TableSchema.Schema, columns: *[f.TableSchema.max_columns]f.TableSchema.Column) !f.TableSchema.Schema {
    try schema.validate();
    if (schema.columns.len > max_user_columns) return error.InvalidColumnCount;
    const base = schema.columns.len;
    @memcpy(columns[0..base], schema.columns);
    columns[base] = .{ .id = schema.next_column, .name = offset_column_name, .type = .uint64, .nullable = false };
    columns[base + 1] = .{ .id = try std.math.add(u64, schema.next_column, 1), .name = timestamp_column_name, .type = .uint64, .nullable = false };
    columns[base + 2] = .{ .id = try std.math.add(u64, schema.next_column, 2), .name = tombstone_column_name, .type = .boolean, .nullable = false };
    var result = schema;
    result.next_column = try std.math.add(u64, schema.next_column, system_columns);
    result.columns = columns[0 .. base + system_columns];
    try result.validate();
    return result;
}

pub fn segmentKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "log-segments/{x}.tseg", .{&content.sha256});
}
fn verifyHead(objects: Objects.ObjectStore, key: []const u8, content: d.Content) !void {
    const found = try objects.head(key) orelse return error.LogSegmentMissing;
    if (found.size != content.bytes or !std.mem.eql(u8, &found.sha256, &content.sha256)) return error.InvalidLogSegment;
}
fn put(objects: Objects.ObjectStore, bytes: []const u8, comptime key: anytype) !d.Content {
    const content = Batch.content(bytes);
    var name: [96]u8 = undefined;
    const found = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (found.size != content.bytes or !std.mem.eql(u8, &found.sha256, &content.sha256)) return error.InvalidLogSegment;
    return content;
}

/// All decode/encode allocations belong to the caller's finite build budget.
/// One arena retains a batch; there is no per-row heap arena lifecycle.
pub fn stage(allocator: std.mem.Allocator, objects: Objects.ObjectStore, declaration: *const Declaration.Owned, evidence: Evidence.Record, payload: []const u8, rows_per_group: u32) !Descriptor {
    try evidence.validate();
    if (evidence.outcome != .append or !std.meta.eql(evidence.declared, try declaration.stored())) return error.InvalidLogSegment;
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    if (payload.len > @import("TransitLog.zig").max_payload_bytes) return error.InvalidLogSegment;
    if (!std.meta.eql(append.payload, Batch.content(payload))) return error.LogPayloadConflict;
    const kind: p.StreamQueueDeclaration.Kind = if (append.kind == .stream) .stream else .queue;
    const schema = declaration.definition.schema;
    var iterator: Batch.Rows = .{ .complete = try Batch.Iterator.init(payload, schema, kind, append.rows) };
    return stageRows(allocator, objects, schema, evidence, &iterator, iterator.complete.count, rows_per_group, .complete);
}

/// The owner must prove omissions against its exact visibility root and compare
/// surviving bytes to the old placement before publishing this private object.
pub fn stageSparse(allocator: std.mem.Allocator, objects: Objects.ObjectStore, declaration: *const Declaration.Owned, evidence: Evidence.Record, surviving: []const Batch.EncodedRow, rows_per_group: u32) !Descriptor {
    try evidence.validate();
    if (evidence.outcome != .append or !std.meta.eql(evidence.declared, try declaration.stored())) return error.InvalidLogSegment;
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    if (append.kind != .stream or surviving.len > append.rows / 2) return error.InvalidLogSegment;
    var encoded_bytes: u64 = Batch.header_bytes;
    var previous: ?u32 = null;
    for (surviving) |row| {
        if (row.ordinal >= append.rows or (previous != null and row.ordinal <= previous.?) or
            row.bytes.len < f.TableRow.header_bytes or row.bytes.len > f.TableRow.max_bytes or row.visible_ms != 0)
            return error.InvalidLogSegment;
        encoded_bytes = try std.math.add(u64, encoded_bytes, Batch.row_header_bytes + row.bytes.len);
        previous = row.ordinal;
    }
    if (encoded_bytes > append.payload.bytes or encoded_bytes > @import("TransitLog.zig").max_payload_bytes) return error.InvalidLogSegment;
    var slice_cursor: SliceCursor = .{ .rows = surviving };
    return stageRows(allocator, objects, declaration.definition.schema, evidence, &slice_cursor, @intCast(surviving.len), rows_per_group, .sparse);
}

const SliceCursor = struct {
    rows: []const Batch.EncodedRow,
    at: usize = 0,
    fn next(self: *SliceCursor) !?Batch.EncodedRow {
        if (self.at == self.rows.len) return null;
        defer self.at += 1;
        return self.rows[self.at];
    }
};

fn stageRows(allocator: std.mem.Allocator, objects: Objects.ObjectStore, schema: f.TableSchema.Schema, evidence: Evidence.Record, iterator: anytype, count: u32, rows_per_group: u32, layout: Layout) !Descriptor {
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const storage_schema = try storageSchema(schema, &columns);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const rows = try a.alloc(f.TableRow.Row, count);
    const evidence_content = try Evidence.decodeReference(try Evidence.expectedReference(evidence));
    var physical: usize = 0;
    while (try iterator.next()) |encoded| {
        const decoded = try encoded.decode(a, schema, append.operation);
        const cells = try a.alloc(f.Types.Values.Cell, storage_schema.columns.len);
        @memcpy(cells[0..schema.columns.len], decoded.cells);
        cells[schema.columns.len] = .{ .value = .{ .atom = .{ .unsigned = try std.math.add(u64, receipt.first, encoded.ordinal) } } };
        cells[schema.columns.len + 1] = .{ .value = .{ .atom = .{ .unsigned = encoded.visible_ms } } };
        cells[schema.columns.len + 2] = .{ .value = .{ .atom = .{ .boolean = encoded.tombstone } } };
        rows[physical] = .{ .identity = .{ .origin = append.operation.principal + 1, .operation = append.operation.operation, .ordinal = encoded.ordinal }, .cells = cells };
        physical += 1;
    }
    if (count == 0) {
        const empty: Descriptor = .{ .layout = layout, .rows = 0, .evidence = evidence_content, .segment = null };
        try empty.validate();
        return empty;
    }
    var output = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(output);
    const encoded = while (true) {
        const bytes = f.TSeg.writeSegment(allocator, storage_schema, rows, .{ .segment_id = receipt.accepted.next_lsn, .rows_per_group = rows_per_group }, output) catch |err| switch (err) {
            error.BufferTooSmall, error.WriteFailed => {
                if (output.len == f.TSeg.max_segment_bytes) return err;
                output = try allocator.realloc(output, @min(output.len * 2, f.TSeg.max_segment_bytes));
                continue;
            },
            else => return err,
        };
        break bytes;
    };
    const result: Descriptor = .{ .layout = layout, .rows = count, .evidence = evidence_content, .segment = try put(objects, encoded, segmentKey) };
    try result.validate();
    return result;
}

pub const Source = struct {
    objects: Objects.ObjectStore,
    content: d.Content,
    pub fn source(self: *Source) f.TSegReader.Source {
        return .{ .context = self, .read = read };
    }
    pub fn verify(self: Source) !void {
        var name: [96]u8 = undefined;
        try verifyHead(self.objects, try segmentKey(self.content, &name), self.content);
    }
    fn read(raw: *anyopaque, offset: u64, output: []u8) !void {
        const self: *Source = @ptrCast(@alignCast(raw));
        if (offset > self.content.bytes or output.len > self.content.bytes - offset) return error.InvalidLogSegment;
        var name: [96]u8 = undefined;
        const bytes = try self.objects.getRange(try segmentKey(self.content, &name), offset, @intCast(output.len), output);
        if (bytes.len != output.len) return error.InvalidLogSegment;
        if (bytes.ptr != output.ptr) @memcpy(output, bytes);
    }
};

/// Reconstruct the declared complete or sparse batch into bounded output from the
/// single `.tseg` object (user columns plus `_offset`, `_timestamp` and `_tombstone`
/// system columns). Each columnar group has a separate bounded lifetime; tail
/// admission can then share verified borrowed bytes with the normal WAL path.
pub fn materialize(allocator: std.mem.Allocator, objects: Objects.ObjectStore, descriptor: Descriptor, declaration: *const Declaration.Owned, evidence: Evidence.Record, output: []u8) ![]const u8 {
    try descriptor.validate();
    try evidence.validate();
    if (evidence.outcome != .append or !std.meta.eql(evidence.declared, try declaration.stored()) or !std.meta.eql(descriptor.evidence, try Evidence.decodeReference(try Evidence.expectedReference(evidence)))) return error.InvalidLogSegment;
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    if (append.rows > max_rows or append.payload.bytes > @import("TransitLog.zig").max_payload_bytes) return error.InvalidLogSegment;
    if (descriptor.rows > append.rows or (descriptor.layout == .complete and descriptor.rows != append.rows) or (descriptor.layout == .sparse and (append.kind != .stream or descriptor.rows > append.rows / 2))) return error.InvalidLogSegment;
    const schema = declaration.definition.schema;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const storage_schema = try storageSchema(schema, &columns);
    var dense: ?Batch.Encoder = if (descriptor.layout == .complete) try Batch.Encoder.init(schema, append.operation, if (append.kind == .stream) .stream else .queue, @intCast(append.rows), output) else null;
    var sparse: ?Batch.SparseEncoder = if (descriptor.layout == .sparse) try Batch.SparseEncoder.init(schema, @intCast(append.rows), descriptor.rows, output) else null;
    if (descriptor.segment == null) return sparse.?.finish();
    const segment = descriptor.segment.?;
    var source: Source = .{ .objects = objects, .content = segment };
    try source.verify();
    var reader = try f.TSegReader.open(allocator, source.source(), segment.bytes, f.TSeg.max_segment_bytes);
    defer reader.deinit();
    if (reader.footer.segment_id != receipt.accepted.next_lsn or reader.footer.total_rows != descriptor.rows or reader.footer.pk_index.len != descriptor.rows or
        reader.footer.object_id != storage_schema.object or reader.footer.schema_revision != storage_schema.revision or
        !std.mem.eql(u8, &reader.footer.layout_fingerprint, &try storage_schema.layoutFingerprint())) return error.InvalidLogSegment;
    var projection: [f.TableSchema.max_columns]usize = undefined;
    for (projection[0..storage_schema.columns.len], 0..) |*column, i| column.* = i;
    const row_buffer: []u8 = if (descriptor.layout == .sparse) try allocator.alloc(u8, @intCast(@min(append.payload.bytes, f.TableRow.max_bytes))) else &.{};
    defer if (descriptor.layout == .sparse) allocator.free(row_buffer);
    var previous: ?u32 = null;
    for (reader.footer.row_groups, 0..) |group, gi| {
        if (group.zone_maps.len != storage_schema.columns.len) return error.InvalidLogSegment;
        const offset_zone = group.zone_maps[schema.columns.len];
        if (offset_zone.value_count != group.row_count or offset_zone.null_count != 0 or offset_zone.missing_count != 0) return error.InvalidLogSegment;
        var decoded = try reader.group(allocator, source.source(), storage_schema, gi, projection[0..storage_schema.columns.len], .{});
        defer decoded.deinit();
        var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
        for (0..group.row_count) |ri| {
            const physical = group.start_row_offset + ri;
            if (physical >= descriptor.rows) return error.InvalidLogSegment;
            const offset_cell = decoded.columns[schema.columns.len].cell(ri);
            const timestamp_cell = decoded.columns[schema.columns.len + 1].cell(ri);
            const tombstone_cell = decoded.columns[schema.columns.len + 2].cell(ri);
            if (offset_cell != .value or offset_cell.value != .atom or offset_cell.value.atom != .unsigned or
                timestamp_cell != .value or timestamp_cell.value != .atom or timestamp_cell.value.atom != .unsigned or
                tombstone_cell != .value or tombstone_cell.value != .atom or tombstone_cell.value.atom != .boolean) return error.InvalidLogSegment;
            const offset = std.math.cast(u64, offset_cell.value.atom.unsigned) orelse return error.InvalidLogSegment;
            const visible_ms = std.math.cast(u64, timestamp_cell.value.atom.unsigned) orelse return error.InvalidLogSegment;
            if (offset < receipt.first or offset >= receipt.next) return error.InvalidLogSegment;
            const ordinal: u32 = @intCast(offset - receipt.first);
            if (ordinal >= append.rows or (previous != null and ordinal <= previous.?) or (descriptor.layout == .complete and ordinal != physical)) return error.InvalidLogSegment;
            previous = ordinal;
            const identity: f.TableRow.Identity = .{ .origin = append.operation.principal + 1, .operation = append.operation.operation, .ordinal = ordinal };
            const entry = reader.footer.pk_index[physical];
            if (!std.meta.eql(entry.identity, identity) or entry.row_group != gi or entry.row_in_group != ri or entry.global_row_offset != physical) return error.InvalidLogSegment;
            for (decoded.columns[0..schema.columns.len], cells[0..schema.columns.len]) |column, *cell| cell.* = column.cell(ri);
            const row: Batch.Row = .{ .cells = cells[0..schema.columns.len], .visible_ms = visible_ms, .tombstone = tombstone_cell.value.atom.boolean };
            if (dense) |*encoder| try encoder.append(row);
            if (sparse) |*encoder| {
                const original: f.TableRow.Row = .{ .identity = identity, .cells = row.cells };
                try encoder.append(.{ .ordinal = ordinal, .visible_ms = row.visible_ms, .tombstone = row.tombstone, .bytes = try original.encode(schema, row_buffer) });
            }
        }
    }
    const original = if (dense) |encoder| try encoder.finish() else try sparse.?.finish();
    if (descriptor.layout == .complete and !std.meta.eql(append.payload, Batch.content(original))) return error.LogPayloadConflict;
    if (descriptor.layout == .sparse and original.len > append.payload.bytes) return error.InvalidLogSegment;
    return original;
}

/// A verified zone map can exclude a bounded suffix of one physical group.
/// Event times are never assumed to follow offsets. A possible match returns
/// zero so the owner applies the exact row predicate on its normal read path.
pub fn skipTimestamp(allocator: std.mem.Allocator, objects: Objects.ObjectStore, descriptor: Descriptor, declaration: *const Declaration.Owned, evidence: Evidence.Record, range: p.StreamRead.TimestampRange, ordinal: u32, maximum: u32) !u32 {
    try range.validate();
    try descriptor.validate();
    try evidence.validate();
    if (evidence.outcome != .append or evidence.outcome.append.append.kind != .stream or !std.meta.eql(evidence.declared, try declaration.stored()) or !std.meta.eql(descriptor.evidence, try Evidence.decodeReference(try Evidence.expectedReference(evidence)))) return error.InvalidLogSegment;
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    if (ordinal >= append.rows or maximum == 0) return error.InvalidLogSegment;
    if (descriptor.layout == .sparse) return 0;
    if (descriptor.rows != append.rows or append.rows > max_rows) return error.InvalidLogSegment;
    const segment = descriptor.segment orelse return error.InvalidLogSegment;
    var source: Source = .{ .objects = objects, .content = segment };
    try source.verify();
    var reader = try f.TSegReader.open(allocator, source.source(), segment.bytes, f.TSeg.max_segment_bytes);
    defer reader.deinit();
    const footer = reader.footer;
    const schema = declaration.definition.schema;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const storage_schema = try storageSchema(schema, &columns);
    if (footer.segment_id != receipt.accepted.next_lsn or footer.total_rows != append.rows or footer.pk_index.len != append.rows or footer.object_id != storage_schema.object or footer.schema_revision != storage_schema.revision or !std.mem.eql(u8, &footer.layout_fingerprint, &try storage_schema.layoutFingerprint())) return error.InvalidLogSegment;
    const column = declaration.definition.configuration.policy.stream.timestamp_column orelse return error.StreamTimestampNotDeclared;
    const ci = try schema.index(column);
    const entry = footer.pk_index[ordinal];
    if (entry.row_group >= footer.row_groups.len) return error.InvalidLogSegment;
    const group = footer.row_groups[entry.row_group];
    if (group.zone_maps.len != storage_schema.columns.len or ci >= group.zone_maps.len or ordinal < group.start_row_offset or ordinal - group.start_row_offset >= group.row_count) return error.InvalidLogSegment;
    var lower: [32]u8 = undefined;
    var upper: [32]u8 = undefined;
    const lower_key = try f.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .timestamp = range.from_us } } }, .{ .timestamp = .utc }, .none, &lower);
    const upper_key = try f.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .timestamp = range.until_us } } }, .{ .timestamp = .utc }, .none, &upper);
    const zone = group.zone_maps[ci];
    if (range.from_us != range.until_us and zone.mayMatch(.ge, lower_key) and zone.mayMatch(.lt, upper_key)) return 0;
    const count = @min(maximum, group.row_count - (ordinal - group.start_row_offset));
    for (ordinal..ordinal + count) |position| {
        const item = footer.pk_index[position];
        const identity: f.TableRow.Identity = .{ .origin = append.operation.principal + 1, .operation = append.operation.operation, .ordinal = @intCast(position) };
        if (!std.meta.eql(item.identity, identity) or item.global_row_offset != position or item.row_group != entry.row_group or item.row_in_group != position - group.start_row_offset) return error.InvalidLogSegment;
    }
    return count;
}

/// Every physical omission must be hidden in this exact retained basis. A segment
/// digest alone does not prove logical coverage or authorize dropping a row.
pub fn requireVisibility(descriptor: Descriptor, payload: []const u8, schema: f.TableSchema.Schema, receipt: p.StreamQueue.AppendReceipt, store: *@import("TreeStore.zig"), hidden: @import("BitmapDirectory.zig").Root) !void {
    if (descriptor.layout == .complete) return;
    var rows = try descriptor.iterator(payload, schema, receipt.append);
    var visibility: @import("BitmapDirectory.zig") = .{ .store = store, .objects = store.store };
    var through = receipt.first;
    while (try rows.next()) |row| {
        const offset = receipt.first + row.ordinal;
        while (through < offset) : (through += 1) if (!try visibility.contains(hidden, through)) return error.LogHistoryUnavailable;
        through = offset + 1;
    }
    while (through < receipt.next) : (through += 1) if (!try visibility.contains(hidden, through)) return error.LogHistoryUnavailable;
}
