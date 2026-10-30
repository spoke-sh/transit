//! Immutable columnar representation of one accepted append. The original
//! receipt and row identities survive physical placement. Metadata is separate
//! from user columns; neither object publishes a locator by itself.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Objects = @import("TransitObjectStore.zig");
const Batch = @import("LogBatch.zig");
const Evidence = @import("LogEvidence.zig");
const Declaration = @import("LogDeclaration.zig");
const pages = @import("TreeStore.zig").pages;
const metadata_header = 76;
const metadata_row = 9;
pub const max_metadata_bytes = metadata_header + @import("TransitLog.zig").max_payload_bytes;
pub const Descriptor = struct {
    evidence: d.Content,
    segment: d.Content,
    metadata: d.Content,
    pub fn validate(self: Descriptor) !void {
        _ = try Evidence.reference(self.evidence);
        try self.segment.validate();
        try self.metadata.validate();
        if (self.segment.bytes > f.TSeg.max_segment_bytes or self.metadata.bytes <= metadata_header or self.metadata.bytes > max_metadata_bytes or
            (self.metadata.bytes - metadata_header) % metadata_row != 0) return error.InvalidLogSegment;
    }
    pub fn encode(self: Descriptor) !pages.Value {
        try self.validate();
        var bytes: [120]u8 = undefined;
        for ([_]d.Content{ self.evidence, self.segment, self.metadata }, 0..) |content, i| {
            std.mem.writeInt(u64, bytes[i * 40 ..][0..8], content.bytes, .big);
            bytes[i * 40 + 8 ..][0..32].* = content.sha256;
        }
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Descriptor {
        if (value.len != 120) return error.InvalidLogSegment;
        var contents: [3]d.Content = undefined;
        for (&contents, 0..) |*content, i| content.* = .{ .bytes = std.mem.readInt(u64, value.data[i * 40 ..][0..8], .big), .sha256 = value.data[i * 40 + 8 ..][0..32].* };
        const result: Descriptor = .{ .evidence = contents[0], .segment = contents[1], .metadata = contents[2] };
        try result.validate();
        return result;
    }
};
pub fn segmentKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "log-segments/{x}.tseg", .{&content.sha256});
}
pub fn metadataKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "log-segment-metadata/{x}.data", .{&content.sha256});
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
    var iterator = try Batch.Iterator.init(payload, schema, kind, append.rows);
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const rows = try a.alloc(f.TableRow.Row, iterator.count);
    const metadata_size = metadata_header + @as(usize, iterator.count) * metadata_row;
    if (metadata_size > max_metadata_bytes) return error.InvalidLogSegment;
    const metadata = try a.alloc(u8, metadata_size);
    const evidence_content = try Evidence.decodeReference(try Evidence.expectedReference(evidence));
    metadata[0..8].* = "LBMETA01".*;
    metadata[8..40].* = p.Growth.definition_bytes;
    metadata[40..72].* = evidence_content.sha256;
    std.mem.writeInt(u32, metadata[72..76], iterator.count, .big);
    while (try iterator.next()) |encoded| {
        const decoded = try encoded.decode(a, schema, append.operation);
        rows[encoded.ordinal] = .{ .identity = .{ .origin = append.operation.principal + 1, .operation = append.operation.operation, .ordinal = encoded.ordinal }, .cells = decoded.cells };
        const at = metadata_header + @as(usize, encoded.ordinal) * metadata_row;
        std.mem.writeInt(u64, metadata[at..][0..8], encoded.visible_ms, .big);
        metadata[at + 8] = @intFromBool(encoded.tombstone);
    }
    var output = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(output);
    const encoded = while (true) {
        const bytes = f.TSeg.writeSegment(allocator, schema, rows, .{ .segment_id = receipt.accepted.next_lsn, .rows_per_group = rows_per_group }, output) catch |err| switch (err) {
            error.BufferTooSmall, error.WriteFailed => {
                if (output.len == f.TSeg.max_segment_bytes) return err;
                output = try allocator.realloc(output, @min(output.len * 2, f.TSeg.max_segment_bytes));
                continue;
            },
            else => return err,
        };
        break bytes;
    };
    const result: Descriptor = .{ .evidence = evidence_content, .segment = try put(objects, encoded, segmentKey), .metadata = try put(objects, metadata, metadataKey) };
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

/// Reconstruct the exact original batch into caller-owned bounded output. Each
/// columnar group has a separate bounded lifetime; tail admission can then share
/// verified borrowed bytes with the normal WAL path.
pub fn materialize(allocator: std.mem.Allocator, objects: Objects.ObjectStore, descriptor: Descriptor, declaration: *const Declaration.Owned, evidence: Evidence.Record, output: []u8) ![]const u8 {
    try descriptor.validate();
    try evidence.validate();
    if (evidence.outcome != .append or !std.meta.eql(evidence.declared, try declaration.stored()) or !std.meta.eql(descriptor.evidence, try Evidence.decodeReference(try Evidence.expectedReference(evidence)))) return error.InvalidLogSegment;
    const receipt = evidence.outcome.append;
    const append = receipt.append;
    if (append.rows > (max_metadata_bytes - metadata_header) / metadata_row or append.payload.bytes > @import("TransitLog.zig").max_payload_bytes) return error.InvalidLogSegment;
    if (descriptor.metadata.bytes != metadata_header + @as(u64, append.rows) * metadata_row) return error.InvalidLogSegment;
    var name: [96]u8 = undefined;
    const key = try metadataKey(descriptor.metadata, &name);
    try verifyHead(objects, key, descriptor.metadata);
    const metadata = try allocator.alloc(u8, @intCast(descriptor.metadata.bytes));
    defer allocator.free(metadata);
    const bytes = try objects.getRange(key, 0, @intCast(metadata.len), metadata);
    if (bytes.len != metadata.len or !std.mem.eql(u8, &Evidence.hash(bytes), &descriptor.metadata.sha256) or !std.mem.eql(u8, bytes[0..8], "LBMETA01") or !std.mem.eql(u8, bytes[40..72], &descriptor.evidence.sha256) or std.mem.readInt(u32, bytes[72..76], .big) != append.rows) return error.InvalidLogSegment;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var source: Source = .{ .objects = objects, .content = descriptor.segment };
    try source.verify();
    var reader = try f.TSegReader.open(allocator, source.source(), descriptor.segment.bytes, f.TSeg.max_segment_bytes);
    defer reader.deinit();
    if (reader.footer.segment_id != receipt.accepted.next_lsn or reader.footer.total_rows != append.rows or reader.footer.pk_index.len != append.rows) return error.InvalidLogSegment;
    const schema = declaration.definition.schema;
    var projection: [f.TableSchema.max_columns]usize = undefined;
    for (projection[0..schema.columns.len], 0..) |*column, i| column.* = i;
    var encoder = try Batch.Encoder.init(schema, append.operation, if (append.kind == .stream) .stream else .queue, @intCast(append.rows), output);
    for (reader.footer.row_groups, 0..) |group, gi| {
        var decoded = try reader.group(allocator, source.source(), schema, gi, projection[0..schema.columns.len], .{});
        defer decoded.deinit();
        var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
        for (0..group.row_count) |ri| {
            const ordinal = group.start_row_offset + ri;
            const identity: f.TableRow.Identity = .{ .origin = append.operation.principal + 1, .operation = append.operation.operation, .ordinal = @intCast(ordinal) };
            const entry = reader.footer.pk_index[ordinal];
            if (!std.meta.eql(entry.identity, identity) or entry.row_group != gi or entry.row_in_group != ri or entry.global_row_offset != ordinal) return error.InvalidLogSegment;
            for (decoded.columns, cells[0..schema.columns.len]) |column, *cell| cell.* = column.cell(ri);
            const at = metadata_header + ordinal * metadata_row;
            if (bytes[at + 8] > 1) return error.InvalidLogSegment;
            try encoder.append(.{ .cells = cells[0..schema.columns.len], .visible_ms = std.mem.readInt(u64, bytes[at..][0..8], .big), .tombstone = bytes[at + 8] != 0 });
        }
    }
    const original = try encoder.finish();
    if (!std.meta.eql(append.payload, Batch.content(original))) return error.LogPayloadConflict;
    return original;
}
