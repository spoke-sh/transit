//! Immutable exact Table read basis. Publication/retirement of its pin is a
//! Table log transition; writing these bytes alone never acquires a pin.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const r = @import("TablePartitionRecord.zig");
const Declaration = @import("TableDeclaration.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
const header_bytes = 48;
pub const max_bytes = header_bytes + r.max_metadata_bytes + f.TableSchema.max_bytes;
pub const Handle = struct { owner: d.Operation, content: d.Content };
/// Snapshot retention covers one exact root. History retention additionally
/// preserves logical successors from that root until explicit release.
pub const Retention = enum { snapshot, history };
pub const Owned = struct {
    owner: d.Operation,
    retention: Retention,
    root: r.Root,
    schema: f.TableSchema.Owned,
    pub fn deinit(self: *Owned) void {
        self.schema.deinit();
        self.* = undefined;
    }
};
const Metadata = struct { owner: d.Operation, retention: Retention, root: r.Root };

fn key(content: d.Content, buffer: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(buffer, "table-snapshots/{x}.tman", .{&content.sha256});
}

pub fn stage(allocator: std.mem.Allocator, objects: Objects.ObjectStore, owner: d.Operation, retention: Retention, root: r.Root, schema: f.TableSchema.Schema) !Handle {
    try owner.validate();
    try root.validate();
    if (!std.meta.eql(owner.scope, root.interpretation.object.scope) or !std.mem.eql(u8, &try schema.fingerprint(), &root.schema_fingerprint)) return error.InvalidTableBasis;
    const bytes = try allocator.alloc(u8, max_bytes);
    defer allocator.free(bytes);
    // A data snapshot does not recursively pin earlier pin/receipt directories.
    var basis = root;
    basis.pins = null;
    basis.history_pins = null;
    basis.recovery = null;
    basis.receipts = null;
    basis.operations = null;
    basis.pending = null;
    var writer: std.Io.Writer = .fixed(bytes[header_bytes..][0..r.max_metadata_bytes]);
    try std.json.Stringify.value(Metadata{ .owner = owner, .retention = retention, .root = basis }, .{}, &writer);
    const metadata = writer.buffered();
    const encoded_schema = try schema.encode(bytes[header_bytes + metadata.len ..]);
    bytes[0..8].* = "TPINOBJ1".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u32, bytes[40..44], @intCast(metadata.len), .little);
    std.mem.writeInt(u32, bytes[44..48], @intCast(encoded_schema.len), .little);
    const encoded = bytes[0 .. header_bytes + metadata.len + encoded_schema.len];
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = r.hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidTableSnapshot;
    return .{ .owner = owner, .content = content };
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, handle: Handle) !Owned {
    try handle.owner.validate();
    if (handle.content.bytes > max_bytes or handle.content.bytes < header_bytes) return error.InvalidTableSnapshot;
    var name: [96]u8 = undefined;
    const object_key = try key(handle.content, &name);
    const metadata = try objects.head(object_key) orelse return error.TableSnapshotMissing;
    if (metadata.size != handle.content.bytes or !std.mem.eql(u8, &metadata.sha256, &handle.content.sha256)) return error.InvalidTableSnapshot;
    const bytes = try allocator.alloc(u8, @intCast(handle.content.bytes));
    defer allocator.free(bytes);
    if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &handle.content.sha256)) return error.InvalidTableSnapshot;
    if (!std.mem.eql(u8, bytes[0..8], "TPINOBJ1")) return error.InvalidTableSnapshot;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const metadata_length = std.mem.readInt(u32, bytes[40..44], .little);
    const schema_length = std.mem.readInt(u32, bytes[44..48], .little);
    if (metadata_length > r.max_metadata_bytes or schema_length > f.TableSchema.max_bytes or
        @as(u64, header_bytes) + metadata_length + schema_length != bytes.len) return error.InvalidTableSnapshot;
    const parsed = try std.json.parseFromSlice(Metadata, allocator, bytes[header_bytes..][0..metadata_length], .{});
    defer parsed.deinit();
    try parsed.value.root.validate();
    if (!std.meta.eql(parsed.value.owner, handle.owner) or !std.meta.eql(parsed.value.owner.scope, parsed.value.root.interpretation.object.scope)) return error.InvalidTableSnapshot;
    var schema = try f.TableSchema.decode(allocator, bytes[header_bytes + metadata_length ..]);
    errdefer schema.deinit();
    if (schema.schema.object != parsed.value.root.interpretation.object.object or
        !std.mem.eql(u8, &try schema.schema.fingerprint(), &parsed.value.root.schema_fingerprint)) return error.InvalidTableSnapshot;
    var declaration = try Declaration.load(allocator, objects, parsed.value.root.declared());
    defer declaration.deinit();
    return .{ .owner = handle.owner, .retention = parsed.value.retention, .root = parsed.value.root, .schema = schema };
}

pub const Pin = struct {
    released: bool = false,
    content: d.Content,
    pub fn encode(self: Pin) !pages.Value {
        try self.content.validate();
        var bytes: [41]u8 = undefined;
        bytes[0] = @intFromBool(self.released);
        std.mem.writeInt(u64, bytes[1..9], self.content.bytes, .little);
        bytes[9..41].* = self.content.sha256;
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Pin {
        if (value.len != 41 or value.data[0] > 1) return error.InvalidTablePin;
        const pin: Pin = .{ .released = value.data[0] == 1, .content = .{ .bytes = std.mem.readInt(u64, value.data[1..9], .little), .sha256 = value.data[9..41].* } };
        try pin.content.validate();
        return pin;
    }
};

/// A numeric frontier prefix makes the oldest live history lease a bounded
/// tree lookup. Owner identity distinguishes leases at an identical frontier.
pub fn historyKey(owner: d.Operation, next_lsn: u64) !pages.Key {
    try owner.validate();
    if (next_lsn == 0) return error.InvalidTablePin;
    var bytes: [24]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], next_lsn, .big);
    std.mem.writeInt(u64, bytes[8..16], owner.principal, .big);
    std.mem.writeInt(u64, bytes[16..24], owner.operation, .big);
    return pages.Key.init(&bytes);
}

pub fn historyOwner(scope: d.Scope, entry: pages.Key) !struct { owner: d.Operation, next_lsn: u64 } {
    if (entry.len != 24) return error.InvalidTablePin;
    const owner: d.Operation = .{ .scope = scope, .principal = std.mem.readInt(u64, entry.data[8..16], .big), .operation = std.mem.readInt(u64, entry.data[16..24], .big) };
    const next_lsn = std.mem.readInt(u64, entry.data[0..8], .big);
    if (!std.meta.eql(entry, try historyKey(owner, next_lsn))) return error.InvalidTablePin;
    return .{ .owner = owner, .next_lsn = next_lsn };
}
