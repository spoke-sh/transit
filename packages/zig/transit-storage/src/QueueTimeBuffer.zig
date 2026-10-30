//! Small reusable scheduling delta buffer before time-bucketed run sealing.
//! Cardinality here bounds one buffer, never the Queue's durable population.
const std = @import("std");
const p = @import("transit_protocol");
const Run = @import("QueueTimeRun.zig");
const Objects = @import("TransitObjectStore.zig");
const Batch = @import("LogBatch.zig");
pub const Event = Run.Event;
pub const Kind = Run.Kind;
pub const max_rows = 256;
pub const header_bytes = 128;
pub const max_bytes = header_bytes + max_rows * 24;
const Self = @This();

seed: p.StreamQueue.Partition,
kind: Kind,
entries: []Event,
len: usize = 0,

pub fn init(seed: p.StreamQueue.Partition, kind: Kind, entries: []Event) !Self {
    try seed.validate();
    if (seed.interpretation.revision != 1 or entries.len == 0 or entries.len > max_rows) return error.InvalidQueueTimeBuffer;
    return .{ .seed = seed, .kind = kind, .entries = entries };
}
pub fn rows(self: *const Self) []const Event {
    return self.entries[0..self.len];
}
pub fn clear(self: *Self) void {
    self.len = 0;
}

/// In-place insertion into a bounded operation buffer. A full buffer requires
/// explicit sealing; no existing event is evicted or implicitly acknowledged.
pub fn append(self: *Self, event: Event) !void {
    try event.validate(self.kind);
    if (self.len > self.entries.len) return error.InvalidQueueTimeBuffer;
    var lower: usize = 0;
    var upper = self.len;
    while (lower < upper) {
        const middle = lower + (upper - lower) / 2;
        if (Event.less(self.entries[middle], event)) lower = middle + 1 else upper = middle;
    }
    if (lower < self.len and std.meta.eql(self.entries[lower], event)) return error.InvalidQueueTimeBuffer;
    if (self.len == self.entries.len) return error.QueueTimeBufferFull;
    std.mem.copyBackwards(Event, self.entries[lower + 1 .. self.len + 1], self.entries[lower..self.len]);
    self.entries[lower] = event;
    self.len += 1;
}

fn header(seed: p.StreamQueue.Partition, kind: Kind, count: u16, output: *[header_bytes]u8) !void {
    output[0..8].* = "QTBUF001".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    const object = seed.interpretation.object;
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, seed.interpretation.revision }) |value| try writer.writeInt(u64, value, .big);
    try writer.writeAll(&seed.interpretation.digest);
    try writer.writeInt(u32, seed.partition, .big);
    try writer.writeByte(@backingInt(kind));
    try writer.writeInt(u16, count, .big);
    try writer.writeByte(0);
}
pub fn encode(self: *const Self, output: []u8) ![]const u8 {
    _ = try init(self.seed, self.kind, self.entries);
    if (self.len == 0 or self.len > self.entries.len) return error.InvalidQueueTimeBuffer;
    const size = header_bytes + self.len * 24;
    if (output.len < size) return error.QueueTimeBufferBudget;
    try header(self.seed, self.kind, @intCast(self.len), output[0..header_bytes]);
    var writer: std.Io.Writer = .fixed(output[header_bytes..size]);
    for (self.rows(), 0..) |event, i| {
        try event.validate(self.kind);
        if (i != 0 and !Event.less(self.entries[i - 1], event)) return error.InvalidQueueTimeBuffer;
        for ([_]u64{ event.at_ms, event.offset, event.epoch }) |value| try writer.writeInt(u64, value, .big);
    }
    return output[0..size];
}

/// Exact owner/kind checks precede interpreting events. Returned scalar entries
/// belong to output; no slice into encoded input escapes this decoder.
pub fn decode(seed: p.StreamQueue.Partition, kind: Kind, bytes: []const u8, output: []Event) !Self {
    var result = try init(seed, kind, output);
    if (bytes.len < header_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], "QTBUF001")) return error.InvalidQueueTimeBuffer;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const count = std.mem.readInt(u16, bytes[125..127], .big);
    if (count == 0 or count > max_rows or header_bytes + @as(usize, count) * 24 != bytes.len) return error.InvalidQueueTimeBuffer;
    if (count > output.len) return error.QueueTimeBufferBudget;
    var expected: [header_bytes]u8 = undefined;
    try header(seed, kind, count, &expected);
    if (!std.mem.eql(u8, &expected, bytes[0..header_bytes])) return error.InvalidQueueTimeBuffer;
    var reader: std.Io.Reader = .fixed(bytes[header_bytes..]);
    for (output[0..count], 0..) |*event, i| {
        event.* = .{ .at_ms = try reader.takeInt(u64, .big), .offset = try reader.takeInt(u64, .big), .epoch = try reader.takeInt(u64, .big) };
        try event.validate(kind);
        if (i != 0 and !Event.less(output[i - 1], event.*)) return error.InvalidQueueTimeBuffer;
    }
    result.len = count;
    return result;
}
pub fn key(content: p.DataLifecycle.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "queue-time-buffers/{x}.data", .{&content.sha256});
}
pub fn stage(self: *const Self, objects: Objects.ObjectStore, encoded: []u8) !p.DataLifecycle.Content {
    const bytes = try self.encode(encoded);
    const content = Batch.content(bytes);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidQueueTimeBuffer;
    return content;
}
pub fn load(seed: p.StreamQueue.Partition, kind: Kind, objects: Objects.ObjectStore, content: p.DataLifecycle.Content, encoded: []u8, output: []Event) !Self {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidQueueTimeBuffer;
    if (content.bytes > encoded.len) return error.QueueTimeBufferBudget;
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const meta = try objects.head(object_key) orelse return error.QueueTimeBufferMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidQueueTimeBuffer;
    const bytes = try objects.getRange(object_key, 0, @intCast(content.bytes), encoded);
    if (bytes.len != content.bytes or !std.meta.eql(content, Batch.content(bytes))) return error.InvalidQueueTimeBuffer;
    return decode(seed, kind, bytes, output);
}
