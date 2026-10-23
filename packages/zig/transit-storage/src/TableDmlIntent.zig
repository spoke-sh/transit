//! Immutable frozen row work. Staging is not operation admission or acceptance.
//! Row bytes use the typed binary codec, preserving floating-point bit patterns.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Declaration = @import("TableDeclaration.zig");
const Changes = @import("TableChanges.zig");
const Objects = @import("TransitObjectStore.zig");
pub const max_bytes = @import("TransitLog.zig").max_payload_bytes;
const max_metadata_bytes = 4096;
const header_bytes = 44;

pub const Request = struct {
    binding: d.Binding,
    interpretation: Declaration.Stored,
    changes: []const Changes.Change,
    ingestion: Changes.Ingestion,

    pub fn validate(self: Request) !void {
        try self.binding.validate();
        try self.interpretation.validate();
        if (self.interpretation.retired or !std.meta.eql(self.binding.expected_definition, @as(?d.Definition, self.interpretation.interpretation))) return error.InvalidTableMutationIntent;
        if (self.changes.len > Changes.max_changes) return error.TableBatchTooLarge;
        switch (self.binding.action) {
            .insert, .update, .delete => {},
            else => return error.UnsupportedTableAction,
        }
        for (self.changes) |change| switch (self.binding.action) {
            .insert => if (change != .put or change.put.expect != .absent) return error.UnsupportedTableMutationShape,
            .update => if (change != .replace and (change != .put or change.put.expect != .present)) return error.UnsupportedTableMutationShape,
            .delete => if (change != .remove) return error.UnsupportedTableMutationShape,
            else => unreachable,
        };
    }
};
const Metadata = struct { binding: d.Binding, interpretation: Declaration.Stored, ingestion: Changes.Ingestion, count: u16 };
pub const Owned = struct {
    allocator: std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    declaration: Declaration.Owned,
    decoded: []f.TableRow.Owned,
    count: usize = 0,
    request: Request,

    pub fn deinit(self: *Owned) void {
        for (self.decoded[0..self.count]) |*row| row.deinit();
        self.declaration.deinit();
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.* = undefined;
    }
};
fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "table-intents/{x}.data", .{&content.sha256});
}

pub fn stage(allocator: std.mem.Allocator, objects: Objects.ObjectStore, request: Request) !d.Content {
    try request.validate();
    var declaration = try Declaration.load(allocator, objects, request.interpretation);
    defer declaration.deinit();
    const bytes = try allocator.alloc(u8, max_bytes);
    defer allocator.free(bytes);
    var metadata: [max_metadata_bytes]u8 = undefined;
    var metadata_writer: std.Io.Writer = .fixed(&metadata);
    try std.json.Stringify.value(Metadata{ .binding = request.binding, .interpretation = request.interpretation, .ingestion = request.ingestion, .count = @intCast(request.changes.len) }, .{}, &metadata_writer);
    bytes[0..8].* = "TDMLREQ1".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    std.mem.writeInt(u32, bytes[40..44], @intCast(metadata_writer.end), .little);
    var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
    try writer.writeAll(metadata_writer.buffered());
    for (request.changes) |change| switch (change) {
        .put => |value| {
            try writer.writeByte(1);
            try writer.writeByte(@backingInt(value.expect));
            const length_at = header_bytes + writer.end;
            try writer.writeInt(u32, 0, .little);
            const row = try value.row.encode(declaration.schema.schema, bytes[header_bytes + writer.end ..]);
            writer.end += row.len;
            std.mem.writeInt(u32, bytes[length_at..][0..4], @intCast(row.len), .little);
        },
        .replace => |value| {
            if (value.key.len == 0 or value.key.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
            try writer.writeByte(3);
            try writer.writeInt(u32, @intCast(value.key.len), .little);
            try writer.writeAll(value.key);
            const length_at = header_bytes + writer.end;
            try writer.writeInt(u32, 0, .little);
            const row = try value.row.encode(declaration.schema.schema, bytes[header_bytes + writer.end ..]);
            writer.end += row.len;
            std.mem.writeInt(u32, bytes[length_at..][0..4], @intCast(row.len), .little);
        },
        .remove => |value| {
            if (value.len == 0 or value.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
            try writer.writeByte(2);
            try writer.writeInt(u32, @intCast(value.len), .little);
            try writer.writeAll(value);
        },
    };
    const encoded = bytes[0 .. header_bytes + writer.end];
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidTableMutationIntent;
    return content;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !Owned {
    if (content.bytes < header_bytes or content.bytes > max_bytes) return error.InvalidTableMutationIntent;
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const stored = try objects.head(object_key) orelse return error.TableMutationIntentMissing;
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidTableMutationIntent;
    const bytes = try alloc.alloc(u8, @intCast(content.bytes));
    if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len or !std.mem.eql(u8, &hash(bytes), &content.sha256)) return error.InvalidTableMutationIntent;
    if (!std.mem.eql(u8, bytes[0..8], "TDMLREQ1")) return error.InvalidTableMutationIntent;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const metadata_length = std.mem.readInt(u32, bytes[40..44], .little);
    if (metadata_length > max_metadata_bytes or metadata_length > bytes.len - header_bytes) return error.InvalidTableMutationIntent;
    const parsed = try std.json.parseFromSlice(Metadata, alloc, bytes[header_bytes..][0..metadata_length], .{});
    defer parsed.deinit();
    const meta = parsed.value;
    if (meta.count > Changes.max_changes) return error.InvalidTableMutationIntent;
    var declaration = try Declaration.load(alloc, objects, meta.interpretation);
    errdefer declaration.deinit();
    const changes = try alloc.alloc(Changes.Change, meta.count);
    const decoded = try alloc.alloc(f.TableRow.Owned, meta.count);
    var count: usize = 0;
    errdefer for (decoded[0..count]) |*row| row.deinit();
    var reader: std.Io.Reader = .fixed(bytes[header_bytes + metadata_length ..]);
    for (changes) |*change| switch (try reader.takeByte()) {
        1 => {
            const expected = std.enums.fromInt(Changes.Expect, try reader.takeByte()) orelse return error.InvalidTableMutationIntent;
            const length = try reader.takeInt(u32, .little);
            decoded[count] = try f.TableRow.decode(alloc, declaration.schema.schema, try reader.take(length));
            change.* = .{ .put = .{ .row = decoded[count].row(), .expect = expected } };
            count += 1;
        },
        2 => {
            const length = try reader.takeInt(u32, .little);
            if (length == 0 or length > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
            change.* = .{ .remove = try reader.take(length) };
        },
        3 => {
            const key_length = try reader.takeInt(u32, .little);
            if (key_length == 0 or key_length > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
            const old_key = try reader.take(key_length);
            const row_length = try reader.takeInt(u32, .little);
            decoded[count] = try f.TableRow.decode(alloc, declaration.schema.schema, try reader.take(row_length));
            change.* = .{ .replace = .{ .key = old_key, .row = decoded[count].row() } };
            count += 1;
        },
        else => return error.InvalidTableMutationIntent,
    };
    if (reader.bufferedLen() != 0) return error.InvalidTableMutationIntent;
    const request: Request = .{ .binding = meta.binding, .interpretation = meta.interpretation, .changes = changes, .ingestion = meta.ingestion };
    try request.validate();
    return .{ .allocator = allocator, .arena = arena, .declaration = declaration, .decoded = decoded, .count = count, .request = request };
}
