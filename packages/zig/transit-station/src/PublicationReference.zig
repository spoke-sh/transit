//! Immutable identity, never an access capability. The supplied public resource
//! reader reopens current authority and publication disposition for each bounded
//! chunk group, with a final current check before successful materialization.
const std = @import("std");
const p = @import("transit_client").protocol;
const Pub = @import("Publication.zig");
const Reference = @This();
pub const encoded_bytes = 72;
resource: u64,
domain: Pub.Domain,
namespace: u64,
record: u64,
spec: Pub.Spec,

pub fn validate(self: Reference) !void {
    if (self.resource == 0 or self.resource > p.max_counter or @backingInt(self.domain) == 0 or self.namespace == 0 or self.record == 0) return error.InvalidPublicationReference;
    try self.spec.validate();
}
pub fn encode(self: Reference) !p.Value {
    try self.validate();
    var bytes: [encoded_bytes]u8 = undefined;
    bytes[0..4].* = "SPF1".*;
    std.mem.writeInt(u64, bytes[4..12], self.resource, .little);
    std.mem.writeInt(u32, bytes[12..16], @backingInt(self.domain), .little);
    std.mem.writeInt(u64, bytes[16..24], self.namespace, .little);
    std.mem.writeInt(u64, bytes[24..32], self.record, .little);
    std.mem.writeInt(u32, bytes[32..36], self.spec.format, .little);
    std.mem.writeInt(u32, bytes[36..40], self.spec.length, .little);
    bytes[40..72].* = self.spec.digest;
    return p.Value.init(&bytes);
}
pub fn decode(value: p.Value) !Reference {
    try value.validate();
    if (value.len != encoded_bytes or !std.mem.eql(u8, value.data[0..4], "SPF1")) return error.InvalidPublicationReference;
    const out: Reference = .{
        .resource = std.mem.readInt(u64, value.data[4..12], .little),
        .domain = @fromBackingInt(std.mem.readInt(u32, value.data[12..16], .little)),
        .namespace = std.mem.readInt(u64, value.data[16..24], .little),
        .record = std.mem.readInt(u64, value.data[24..32], .little),
        .spec = .{ .format = std.mem.readInt(u32, value.data[32..36], .little), .length = std.mem.readInt(u32, value.data[36..40], .little), .digest = value.data[40..72].* },
    };
    try out.validate();
    return out;
}
pub fn publication(self: Reference) Pub {
    return .{ .resource = self.resource, .domain = self.domain, .namespace = self.namespace };
}
fn open(self: Reference, reader: anytype) !Pub.Cursor {
    try self.validate();
    const cursor = try self.publication().open(reader, self.record);
    if (!std.meta.eql(cursor.spec, self.spec)) return error.PublicationReferenceChanged;
    return cursor;
}
pub fn check(self: Reference, source: anytype) !void {
    try self.validate();
    var reader = try source.open(self.resource);
    _ = try self.open(&reader);
}
/// Finite materialization into caller-owned storage. Each bounded chunk group
/// and final completion recheck current access. An error invalidates the entire output.
/// A caller must enforce its own smaller format-specific size/authority policy.
pub fn read(self: Reference, source: anytype, output: []u8) ![]const u8 {
    try self.validate();
    if (self.spec.length > output.len) return error.PublicationBufferTooSmall;
    const Source = switch (@typeInfo(@TypeOf(source))) {
        .pointer => |info| info.child,
        else => @TypeOf(source),
    };
    if (@hasDecl(Source, "readBatch")) return self.readBatched(source, output) catch |err| {
        // Older public hosts retain the original authorized point-read path.
        if (err == error.ResourceReadBatchUnavailable) return self.readSingle(source, output);
        return err;
    };
    return self.readSingle(source, output);
}
fn readBatched(self: Reference, source: anytype, output: []u8) ![]const u8 {
    var previous: ?Pub.Cursor = null;
    var used: usize = 0;
    while (true) {
        const index = if (previous) |cursor| cursor.index else 0;
        const remaining: u32 = try std.math.sub(u32, self.spec.chunks(), index);
        const count: usize = @min(@as(u32, p.Growth.page_size - 1), remaining);
        var keys: [p.Growth.page_size]p.Value = undefined;
        keys[0] = Pub.key(self.domain, self.namespace, 'r', self.record, 0);
        for (0..count) |i| keys[i + 1] = Pub.key(self.domain, self.namespace, 'c', self.record, index + @as(u32, @intCast(i)));
        var reader = try source.readBatch(self.resource, null, keys[0 .. count + 1]);
        var cursor = try self.open(&reader);
        if (previous) |old| {
            cursor.index = old.index;
            cursor.chain = old.chain;
        }
        // The descriptor and at most seven chunks share one authorized native
        // read cut. No retained version, result-sized cache or new write bound.
        for (0..@max(1, count)) |_| {
            const part = try self.publication().read(&reader, cursor);
            if (part.bytes.len > self.spec.length - used) return error.InvalidPublicationChunk;
            @memcpy(output[used..][0..part.bytes.len], part.bytes.slice());
            used += part.bytes.len;
            previous = part.next;
            if (previous) |next| cursor = next else break;
        }
        if (previous == null) break;
    }
    if (used != self.spec.length) return error.InvalidPublicationChunk;
    try self.check(source);
    return output[0..used];
}
fn readSingle(self: Reference, source: anytype, output: []u8) ![]const u8 {
    var previous: ?Pub.Cursor = null;
    var used: usize = 0;
    while (true) {
        var reader = try source.open(self.resource);
        var cursor = try self.open(&reader);
        if (previous) |old| {
            cursor.index = old.index;
            cursor.chain = old.chain;
        }
        const part = try self.publication().read(&reader, cursor);
        if (part.bytes.len > self.spec.length - used) return error.InvalidPublicationChunk;
        @memcpy(output[used..][0..part.bytes.len], part.bytes.slice());
        used += part.bytes.len;
        previous = part.next;
        if (previous == null) break;
    }
    if (used != self.spec.length) return error.InvalidPublicationChunk;
    try self.check(source);
    return output[0..used];
}
