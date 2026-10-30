//! Bounded, direct interpretation lookup. Physical schema entries count live
//! row locators; the last removal drops the current mapping. Immutable retained
//! roots keep their own mappings. Column origins pin exactly the ADD-time
//! declaration until DROP or a complete rewrite, never a schema ancestry chain.
const std = @import("std");
const d = @import("transit_protocol").DataLifecycle;
const Declaration = @import("TableDeclaration.zig");
const Store = @import("TreeStore.zig");
const pages = Store.pages;
const stored_bytes = 121;

pub fn key(id: u64) !pages.Key {
    if (id == 0) return error.InvalidTableInterpretation;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, id, .big);
    return pages.Key.init(&bytes);
}

pub fn identity(value: pages.Key) !u64 {
    if (value.len != 8) return error.InvalidTableInterpretation;
    const id = std.mem.readInt(u64, value.data[0..8], .big);
    if (id == 0) return error.InvalidTableInterpretation;
    return id;
}

pub fn encode(stored: Declaration.Stored) !pages.Value {
    try stored.validate();
    if (stored.retired) return error.InvalidTableInterpretation;
    var bytes: [stored_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    const object = stored.interpretation.object;
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, stored.interpretation.revision, stored.content.bytes }) |id| try writer.writeInt(u64, id, .little);
    try writer.writeAll(&stored.content.sha256);
    try writer.writeAll(&stored.schema_fingerprint);
    try writer.writeByte(@backingInt(stored.kind) << 1 | @intFromBool(stored.retired));
    return pages.Value.init(writer.buffered());
}

pub fn decode(value: pages.Value) !Declaration.Stored {
    if (value.len != stored_bytes) return error.InvalidTableInterpretation;
    var reader: std.Io.Reader = .fixed(value.data[0..value.len]);
    const object: d.Object = .{ .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) }, .branch = try reader.takeInt(u64, .little), .object = try reader.takeInt(u64, .little) };
    const revision = try reader.takeInt(u64, .little);
    const length = try reader.takeInt(u64, .little);
    const digest = (try reader.takeArray(32)).*;
    const fingerprint = (try reader.takeArray(32)).*;
    const flags = try reader.takeByte();
    if (flags != 0 and flags != 2) return error.InvalidTableInterpretation;
    const result: Declaration.Stored = .{ .kind = @fromBackingInt(@intCast(flags >> 1)), .interpretation = .{ .object = object, .revision = revision, .digest = digest }, .content = .{ .bytes = length, .sha256 = digest }, .schema_fingerprint = fingerprint, .retired = false };
    try result.validate();
    return result;
}

pub const Physical = struct {
    declaration: Declaration.Stored,
    rows: u64,

    pub fn encode(self: Physical) !pages.Value {
        if (self.rows == 0) return error.InvalidTableInterpretation;
        const stored = try ThisFile.encode(self.declaration);
        var bytes: [stored_bytes + 8]u8 = undefined;
        @memcpy(bytes[0..stored_bytes], stored.data[0..stored_bytes]);
        std.mem.writeInt(u64, bytes[stored_bytes..], self.rows, .little);
        return pages.Value.init(&bytes);
    }

    pub fn decode(value: pages.Value) !Physical {
        if (value.len != stored_bytes + 8) return error.InvalidTableInterpretation;
        const result: Physical = .{ .declaration = try ThisFile.decode(try pages.Value.init(value.data[0..stored_bytes])), .rows = std.mem.readInt(u64, value.data[stored_bytes..][0..8], .little) };
        if (result.rows == 0) return error.InvalidTableInterpretation;
        return result;
    }
};
const ThisFile = @This();

pub fn physical(store: *Store, root: ?pages.Reference, revision: u64) !?Physical {
    const tree: pages.Tree(Store) = .{ .store = store };
    return try Physical.decode(try tree.get(root, try key(revision)) orelse return null);
}

/// Called inside the owning private index candidate. Positive deltas use the
/// exact declaration of the newly encoded rows; negative deltas require an
/// existing mapping. An unsuccessful enclosing publication exposes neither.
pub fn adjust(store: *Store, root: ?pages.Reference, revision: u64, delta: i64, current: Declaration.Stored) !?pages.Reference {
    if (delta == 0) return root;
    const tree: pages.Tree(Store) = .{ .store = store };
    const old = try physical(store, root, revision);
    if (old) |value| {
        if (value.declaration.kind != current.kind or !std.meta.eql(value.declaration.interpretation.object, current.interpretation.object) or
            (delta > 0 and !std.mem.eql(u8, &value.declaration.schema_fingerprint, &current.schema_fingerprint))) return error.InvalidTableInterpretation;
    }
    const count = if (old) |value| value.rows else 0;
    const rows = if (delta > 0) try std.math.add(u64, count, @intCast(delta)) else std.math.sub(u64, count, @abs(delta)) catch return error.InvalidTableInterpretation;
    if (rows == 0) return tree.remove(root, try key(revision));
    return try tree.put(root, try key(revision), try (Physical{ .declaration = if (old) |value| value.declaration else current, .rows = rows }).encode());
}
