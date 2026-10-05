//! Immutable typed Table records in captured/retained growing KV. Small records
//! cost one private write. Large records use resumable bounded Publication work.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Index = @import("ImmutableIndex.zig");
const Data = @import("TableData.zig");
const Self = @This();

resource: u64,
object: u64,
pub const schema_format: u32 = 0x54534301;
pub const inline_bytes = 246;
pub const Reference = struct { id: u64, spec: Pub.Spec };
pub const Step = enum { ready, progress };

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub fn key(object: u64, tag: u8, id: u64) p.Value {
    return Pub.key(.table, object, tag, id, 0);
}
fn manifest(record_bytes: u32) p.Value {
    var bytes: [40]u8 = undefined;
    bytes[0..4].* = "STM1".*;
    bytes[4..36].* = definition();
    std.mem.writeInt(u32, bytes[36..40], record_bytes, .little);
    return p.Value.init(&bytes) catch unreachable;
}
fn checkManifest(value: p.Value) !u32 {
    try value.validate();
    if (value.len != 40 or !std.mem.eql(u8, value.data[0..4], "STM1")) return error.InvalidTableStorage;
    if (!std.mem.eql(u8, value.data[4..36], &definition())) return error.IncompatibleTableStorage;
    const limit = std.mem.readInt(u32, value.data[36..40], .little);
    if (limit == 0) return error.InvalidTableStorage;
    return limit;
}
fn publication(self: Self) Pub {
    return .{ .resource = self.resource, .domain = .table, .namespace = self.object };
}
fn check(self: Self, source: anytype) !u32 {
    if (self.object == 0 or self.resource == 0 or self.resource > p.max_counter) return error.InvalidTableStorage;
    if (source.view.resource != self.resource) return error.CrossResourceTransaction;
    return checkManifest((try source.read(key(self.object, 'd', 0))) orelse return error.TableStorageNotFound);
}
fn validate(ref: Reference) !void {
    if (ref.id == 0) return error.InvalidTablePage;
    const limit: usize = switch (ref.spec.format) {
        Index.format => Index.node_bytes,
        Data.row_format => f.TableRow.max_bytes,
        schema_format => f.TableSchema.max_bytes,
        else => return error.InvalidTablePage,
    };
    if (ref.spec.length == 0 or ref.spec.length > limit) return error.InvalidTablePage;
}
/// Initialization does not publish a Table head or make an existing namespace
/// compatible. Missing/foreign manifests with prior records are never adopted.
pub fn create(turn: *Turn, object: u64, limits: Pub.Limits) !Self {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (object == 0) return error.InvalidTableStorage;
    const self: Self = .{ .resource = turn.view.resource, .object = object };
    if (try turn.read(key(object, 'd', 0))) |value| {
        const limit = try checkManifest(value);
        const quota = try self.publication().budget(turn);
        if (!std.meta.eql(quota.limits, limits) or limit != limits.record_bytes) return error.PublicationLimitsChanged;
    } else {
        if (try turn.read(key(object, 'b', 0)) != null) return error.IncompatibleTableStorage;
        _ = try Pub.create(turn, .table, object, limits);
        try turn.write(key(object, 'd', 0), manifest(limits.record_bytes));
    }
    return self;
}
fn encode(spec: Pub.Spec, bytes: []const u8) !p.Value {
    if (bytes.len > inline_bytes) return error.InvalidTablePage;
    var buffer: [256]u8 = undefined;
    buffer[0..4].* = "STP1".*;
    std.mem.writeInt(u32, buffer[4..8], spec.format, .little);
    std.mem.writeInt(u16, buffer[8..10], @intCast(bytes.len), .little);
    @memcpy(buffer[10..][0..bytes.len], bytes);
    return p.Value.init(buffer[0 .. 10 + bytes.len]);
}
fn validateInline(value: p.Value, spec: Pub.Spec) !void {
    try value.validate();
    if (value.len < 10 or !std.mem.eql(u8, value.data[0..4], "STP1") or
        std.mem.readInt(u32, value.data[4..8], .little) != spec.format or
        std.mem.readInt(u16, value.data[8..10], .little) != spec.length or value.len != spec.length + 10) return error.InvalidTablePage;
}
/// Each call either makes the record readable or prepares one resumable staging
/// step. Ready small writes still belong to this private turn. The owner must
/// reserve IDs, keep input/source identity and publish its head/outcome atomically.
pub fn stage(self: Self, turn: *Turn, ref: Reference, bytes: []const u8) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    const limit = try self.check(turn);
    try validate(ref);
    if (ref.spec.length > limit) return error.PublicationTooLarge;
    if (!std.meta.eql(try Pub.Digest.of(ref.spec.format, bytes), ref.spec)) return error.InvalidTablePage;
    const inline_key = key(self.object, 'i', ref.id);
    const small = try turn.read(inline_key);
    const large = try turn.read(key(self.object, 'r', ref.id));
    if (ref.spec.length <= inline_bytes) {
        if (large != null) return error.TablePageIdentityConflict;
        const expected = try encode(ref.spec, bytes);
        if (small) |value| {
            if (!value.eql(expected)) return error.TablePageIdentityConflict;
        } else try turn.write(inline_key, expected);
        return .ready;
    }
    if (small != null) return error.TablePageIdentityConflict;
    const pubn = self.publication();
    const descriptor = if (large) |value| try Pub.Descriptor.decode(value) else {
        _ = try pubn.begin(turn, ref.id, ref.spec);
        return .progress;
    };
    if (!std.meta.eql(descriptor.spec, ref.spec)) return error.TablePageIdentityConflict;
    switch (descriptor.state) {
        .abandoned, .retired => return error.TablePageClosed,
        .published => return .ready,
        .staging => {
            if (descriptor.written < ref.spec.chunks()) {
                const offset = @as(usize, descriptor.written) * Pub.chunk_bytes;
                _ = try pubn.append(turn, ref.id, descriptor.written, bytes[offset..][0..try ref.spec.size(descriptor.written)]);
            } else {
                _ = try pubn.publish(turn, ref.id);
                return .ready;
            }
            return .progress;
        },
    }
}
pub fn read(self: Self, source: anytype, ref: Reference, output: []u8) ![]const u8 {
    const limit = try self.check(source);
    try validate(ref);
    if (ref.spec.length > limit) return error.InvalidTablePage;
    if (ref.spec.length > output.len) return error.TablePageBufferTooSmall;
    const pubn = self.publication();
    if (ref.spec.length <= inline_bytes) {
        const value = (try source.read(key(self.object, 'i', ref.id))) orelse return error.TablePageNotFound;
        // Decode validates the header; copy directly from the owned local value.
        try validateInline(value, ref.spec);
        @memcpy(output[0..ref.spec.length], value.data[10..value.len]);
    } else {
        var cursor = try pubn.open(source, ref.id);
        if (!std.meta.eql(cursor.spec, ref.spec)) return error.InvalidTablePage;
        var offset: usize = 0;
        while (true) {
            const part = try pubn.read(source, cursor);
            if (part.bytes.len > ref.spec.length - offset) return error.InvalidTablePage;
            @memcpy(output[offset..][0..part.bytes.len], part.bytes.slice());
            offset += part.bytes.len;
            cursor = part.next orelse break;
        }
        if (offset != ref.spec.length) return error.InvalidTablePage;
    }
    const bytes = output[0..ref.spec.length];
    if (!std.meta.eql(try Pub.Digest.of(ref.spec.format, bytes), ref.spec)) return error.InvalidTablePage;
    return bytes;
}
pub fn Reader(comptime Source: type) type {
    return struct {
        pages: Self,
        source: Source,
        pub fn load(self: *@This(), ref: Index.Reference, output: []u8) ![]const u8 {
            try ref.validate();
            return self.pages.read(self.source, .{ .id = ref.id, .spec = ref.spec }, output);
        }
        pub fn loadBlob(self: *@This(), ref: Data.Blob, output: []u8) ![]const u8 {
            try ref.validate();
            return self.pages.read(self.source, .{ .id = ref.id, .spec = ref.spec }, output);
        }
    };
}
