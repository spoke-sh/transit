//! Bounded sorted scheduling chunks using the shared columnar segment engine.
//! Publication, stale-entry filtering and multi-chunk merge belong to the Queue
//! owner. A staged run neither schedules work nor proves current eligibility.
const std = @import("std");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const d = p.DataLifecycle;
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
const Batch = @import("LogBatch.zig");

pub const max_rows = 1024;
pub const max_bytes = 512 * 1024;
pub const bucket_bits = 20;
pub const Kind = enum(u8) { visible = 1, lease = 2 };
pub const Event = struct {
    at_ms: u64,
    offset: u64,
    epoch: u64,
    pub fn less(a: Event, b: Event) bool {
        if (a.at_ms != b.at_ms) return a.at_ms < b.at_ms;
        if (a.offset != b.offset) return a.offset < b.offset;
        return a.epoch < b.epoch;
    }
    pub fn validate(self: Event, kind: Kind) !void {
        if (self.offset == std.math.maxInt(u64) or (kind == .lease and (self.epoch == 0 or self.at_ms == 0))) return error.InvalidQueueTimeRun;
    }
    pub fn bucket(self: Event) u64 {
        return self.at_ms >> bucket_bits;
    }
};

pub const Descriptor = struct {
    /// The partition's immutable genesis interpretation, not a current policy.
    seed: p.StreamQueue.Partition,
    kind: Kind,
    bucket: u64,
    serial: u64,
    rows: u32,
    first: Event,
    last: Event,
    content: d.Content,

    pub fn validate(self: Descriptor) !void {
        try self.seed.validate();
        try self.content.validate();
        try self.first.validate(self.kind);
        try self.last.validate(self.kind);
        if (self.seed.interpretation.revision != 1 or self.serial == 0 or self.rows == 0 or self.rows > max_rows or self.content.bytes > max_bytes or
            self.first.bucket() != self.bucket or self.last.bucket() != self.bucket or
            (self.rows == 1 and !std.meta.eql(self.first, self.last)) or (self.rows > 1 and !Event.less(self.first, self.last))) return error.InvalidQueueTimeRun;
    }
    pub fn encode(self: Descriptor) !pages.Value {
        try self.validate();
        var bytes: [240]u8 = @splat(0);
        bytes[0..8].* = "QTIMRUN1".*;
        bytes[8..40].* = p.Growth.definition_bytes;
        var writer: std.Io.Writer = .fixed(bytes[40..]);
        const object = self.seed.interpretation.object;
        for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, self.seed.interpretation.revision }) |value| try writer.writeInt(u64, value, .big);
        try writer.writeAll(&self.seed.interpretation.digest);
        try writer.writeInt(u32, self.seed.partition, .big);
        try writer.writeByte(@backingInt(self.kind));
        try writer.writeInt(u64, self.bucket, .big);
        try writer.writeInt(u64, self.serial, .big);
        try writer.writeInt(u32, self.rows, .big);
        for ([_]Event{ self.first, self.last }) |event| {
            for ([_]u64{ event.at_ms, event.offset, event.epoch }) |value| try writer.writeInt(u64, value, .big);
        }
        try writer.writeInt(u64, self.content.bytes, .big);
        try writer.writeAll(&self.content.sha256);
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Descriptor {
        const bytes = value.slice();
        if (bytes.len != 240 or !std.mem.eql(u8, bytes[0..8], "QTIMRUN1") or !std.mem.allEqual(u8, bytes[233..], 0)) return error.InvalidQueueTimeRun;
        if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var reader: std.Io.Reader = .fixed(bytes[40..233]);
        const object: d.Object = .{ .scope = .{ .realm = try reader.takeInt(u64, .big), .resource = try reader.takeInt(u64, .big), .catalog = try reader.takeInt(u64, .big) }, .branch = try reader.takeInt(u64, .big), .object = try reader.takeInt(u64, .big) };
        const revision = try reader.takeInt(u64, .big);
        const digest = (try reader.takeArray(32)).*;
        const partition = try reader.takeInt(u32, .big);
        const kind = std.enums.fromInt(Kind, try reader.takeByte()) orelse return error.InvalidQueueTimeRun;
        const bucket = try reader.takeInt(u64, .big);
        const serial = try reader.takeInt(u64, .big);
        const rows = try reader.takeInt(u32, .big);
        var bounds: [2]Event = undefined;
        for (&bounds) |*event| event.* = .{ .at_ms = try reader.takeInt(u64, .big), .offset = try reader.takeInt(u64, .big), .epoch = try reader.takeInt(u64, .big) };
        const content: d.Content = .{ .bytes = try reader.takeInt(u64, .big), .sha256 = (try reader.takeArray(32)).* };
        const result: Descriptor = .{ .seed = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = object, .revision = revision, .digest = digest }, .partition = partition }, .kind = kind, .bucket = bucket, .serial = serial, .rows = rows, .first = bounds[0], .last = bounds[1], .content = content };
        try result.validate();
        return result;
    }
};

fn schema(seed: p.StreamQueue.Partition) f.TableSchema.Schema {
    return .{ .object = seed.interpretation.object.object, .revision = 1, .next_column = 5, .columns = &.{
        .{ .id = 1, .name = "kind", .type = .uint8, .nullable = false },
        .{ .id = 2, .name = "at_ms", .type = .uint64, .nullable = false },
        .{ .id = 3, .name = "offset", .type = .uint64, .nullable = false },
        .{ .id = 4, .name = "epoch", .type = .uint64, .nullable = false },
    } };
}
fn identity(seed: p.StreamQueue.Partition, serial: u64, ordinal: u32) f.TableRow.Identity {
    return .{ .origin = @as(u64, seed.partition) + 1, .operation = serial, .ordinal = ordinal };
}
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "queue-time-runs/{x}.tseg", .{&content.sha256});
}

/// Scratch and encoded output have separate caller-owned lifetimes. This creates
/// one immutable chunk; a caller must publish its descriptor in accepted state.
pub fn stage(scratch: std.mem.Allocator, objects: Objects.ObjectStore, seed: p.StreamQueue.Partition, kind: Kind, serial: u64, events: []const Event, encoded: []u8) !Descriptor {
    try seed.validate();
    if (seed.interpretation.revision != 1 or serial == 0 or events.len == 0 or events.len > max_rows or encoded.len > max_bytes) return error.InvalidQueueTimeRun;
    for (events, 0..) |event, i| {
        try event.validate(kind);
        if (event.bucket() != events[0].bucket() or (i != 0 and !Event.less(events[i - 1], event))) return error.InvalidQueueTimeRun;
    }
    const rows = try scratch.alloc(f.TableRow.Row, events.len);
    defer scratch.free(rows);
    const cells = try scratch.alloc([4]f.Types.Values.Cell, events.len);
    defer scratch.free(cells);
    for (events, rows, cells, 0..) |event, *row, *values, i| {
        for ([_]u64{ @backingInt(kind), event.at_ms, event.offset, event.epoch }, values) |value, *cell| cell.* = .{ .value = .{ .atom = .{ .unsigned = value } } };
        row.* = .{ .identity = identity(seed, serial, @intCast(i)), .cells = values };
    }
    const bytes = try f.TSeg.writeSegment(scratch, schema(seed), rows, .{ .segment_id = serial, .rows_per_group = 64 }, encoded);
    const descriptor: Descriptor = .{ .seed = seed, .kind = kind, .bucket = events[0].bucket(), .serial = serial, .rows = @intCast(events.len), .first = events[0], .last = events[events.len - 1], .content = Batch.content(bytes) };
    try descriptor.validate();
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(descriptor.content, &name), bytes, descriptor.content.sha256);
    if (stored.size != descriptor.content.bytes or !std.mem.eql(u8, &stored.sha256, &descriptor.content.sha256)) return error.InvalidQueueTimeRun;
    return descriptor;
}

const MemorySource = struct {
    bytes: []const u8,
    fn source(self: *MemorySource) f.TSegReader.Source {
        return .{ .context = self, .read = read };
    }
    fn read(raw: *anyopaque, offset: u64, output: []u8) !void {
        const self: *MemorySource = @ptrCast(@alignCast(raw));
        if (offset > self.bytes.len or output.len > self.bytes.len - offset) return error.InvalidQueueTimeRun;
        @memcpy(output, self.bytes[@intCast(offset)..][0..output.len]);
    }
};
fn unsigned(cell: f.Types.Values.Cell) !u64 {
    if (cell != .value or cell.value != .atom or cell.value.atom != .unsigned or cell.value.atom.unsigned > std.math.maxInt(u64)) return error.InvalidQueueTimeRun;
    return @intCast(cell.value.atom.unsigned);
}

/// Verify a complete bounded chunk and copy scalar events into retained output.
/// Scratch never escapes. Callers can cache verified chunks at their own bound.
pub fn load(scratch: std.mem.Allocator, objects: Objects.ObjectStore, descriptor: Descriptor, output: []Event) ![]Event {
    try descriptor.validate();
    if (output.len < descriptor.rows) return error.QueueTimeRunBudget;
    var name: [96]u8 = undefined;
    const object_key = try key(descriptor.content, &name);
    const meta = try objects.head(object_key) orelse return error.QueueTimeRunMissing;
    if (meta.size != descriptor.content.bytes or !std.mem.eql(u8, &meta.sha256, &descriptor.content.sha256)) return error.InvalidQueueTimeRun;
    const bytes = try scratch.alloc(u8, @intCast(descriptor.content.bytes));
    defer scratch.free(bytes);
    const loaded = try objects.getRange(object_key, 0, @intCast(bytes.len), bytes);
    if (loaded.len != bytes.len or !std.meta.eql(descriptor.content, Batch.content(loaded))) return error.InvalidQueueTimeRun;
    if (loaded.ptr != bytes.ptr) @memcpy(bytes, loaded);
    var source: MemorySource = .{ .bytes = bytes };
    var reader = try f.TSegReader.open(scratch, source.source(), loaded.len, max_bytes);
    defer reader.deinit();
    const logical = schema(descriptor.seed);
    const footer = reader.footer;
    if (footer.segment_id != descriptor.serial or footer.total_rows != descriptor.rows or footer.pk_index.len != descriptor.rows or
        footer.object_id != logical.object or footer.schema_revision != logical.revision or
        !std.mem.eql(u8, &footer.layout_fingerprint, &try logical.layoutFingerprint())) return error.InvalidQueueTimeRun;
    var next: usize = 0;
    for (footer.row_groups, 0..) |group, gi| {
        if (group.start_row_offset != next or group.row_count == 0 or group.row_count > 64 or group.row_count > descriptor.rows - next) return error.InvalidQueueTimeRun;
        var decoded = try reader.group(scratch, source.source(), logical, gi, &.{ 0, 1, 2, 3 }, .{ .page_bytes = max_bytes, .decoded_bytes = 2 * 1024 * 1024 });
        defer decoded.deinit();
        for (0..group.row_count) |ri| {
            const pk = footer.pk_index[next];
            if (!std.meta.eql(pk.identity, identity(descriptor.seed, descriptor.serial, @intCast(next))) or pk.row_group != gi or pk.row_in_group != ri or pk.global_row_offset != next or
                try unsigned(decoded.columns[0].cell(ri)) != @backingInt(descriptor.kind)) return error.InvalidQueueTimeRun;
            const event: Event = .{ .at_ms = try unsigned(decoded.columns[1].cell(ri)), .offset = try unsigned(decoded.columns[2].cell(ri)), .epoch = try unsigned(decoded.columns[3].cell(ri)) };
            try event.validate(descriptor.kind);
            if (event.bucket() != descriptor.bucket or (next != 0 and !Event.less(output[next - 1], event))) return error.InvalidQueueTimeRun;
            output[next] = event;
            next += 1;
        }
    }
    if (next != descriptor.rows or !std.meta.eql(output[0], descriptor.first) or !std.meta.eql(output[next - 1], descriptor.last)) return error.InvalidQueueTimeRun;
    return output[0..next];
}
