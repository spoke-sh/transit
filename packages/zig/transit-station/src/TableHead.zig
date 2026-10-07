//! Exact typed Table head at a captured resource cut. Publishing this record is
//! an owner operation, composed with its admission/outcome and input progress.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Pages = @import("TablePages.zig");
const Index = @import("ImmutableIndex.zig");
const Turn = @import("Turn.zig");
const Data = @import("TableData.zig");
const Self = @This();

resource: u64,
object: u64,
revision: u64,
schema: Pages.Reference,
index: Index = .{},
rows: u64 = 0,
next_record: u64,
pending: u64 = 0,
retired: bool = false,

fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub fn key(object: u64) p.Value {
    return Pages.key(object, 'h', 0);
}
pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > p.max_counter or self.object == 0 or self.revision == 0 or self.schema.id == 0 or self.schema.id >= self.next_record or
        self.schema.spec.format != Pages.schema_format or self.schema.spec.length == 0 or self.schema.spec.length > f.TableSchema.max_bytes or
        (self.retired and self.pending != 0)) return error.InvalidTableHead;
    if (self.index.root) |root| {
        try root.validate();
        if (root.id >= self.next_record or self.rows == 0 or root.entries < self.rows) return error.InvalidTableHead;
        if (!((root.minimum.len == 21 and root.minimum.data[0] == 'R') or (root.minimum.len == Data.primary_key_bytes and root.minimum.data[0] == 'K'))) return error.InvalidTableHead;
    } else if (self.rows != 0) return error.InvalidTableHead;
}
fn reference(out: *std.Io.Writer, ref: Pages.Reference) !void {
    try out.writeInt(u64, ref.id, .little);
    try out.writeInt(u32, ref.spec.format, .little);
    try out.writeInt(u32, ref.spec.length, .little);
    try out.writeAll(&ref.spec.digest);
}
fn takeReference(in: *std.Io.Reader) !Pages.Reference {
    return .{ .id = try in.takeInt(u64, .little), .spec = .{
        .format = try in.takeInt(u32, .little),
        .length = try in.takeInt(u32, .little),
        .digest = (try in.take(32))[0..32].*,
    } };
}
pub fn encode(self: Self) !p.Value {
    try self.validate();
    var buffer: [256]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try out.writeAll("STH1");
    try out.writeAll(&definition());
    try out.writeInt(u64, self.resource, .little);
    try out.writeInt(u64, self.object, .little);
    try out.writeInt(u64, self.revision, .little);
    try reference(&out, self.schema);
    try out.writeByte(@intFromBool(self.index.root != null));
    if (self.index.root) |root| {
        try reference(&out, .{ .id = root.id, .spec = root.spec });
        try out.writeByte(root.level);
        try out.writeByte(@intCast(root.minimum.len));
        try out.writeAll(root.minimum.slice());
        try out.writeInt(u64, root.entries, .little);
    }
    try out.writeInt(u64, self.rows, .little);
    try out.writeInt(u64, self.next_record, .little);
    try out.writeInt(u64, self.pending, .little);
    try out.writeByte(@intFromBool(self.retired));
    return p.Value.init(out.buffered());
}
fn parse(bytes: []const u8) !Self {
    var in: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try in.take(4), "STH1")) return error.InvalidTableHead;
    if (!std.mem.eql(u8, try in.take(32), &definition())) return error.IncompatibleTableStorage;
    var result: Self = .{
        .resource = try in.takeInt(u64, .little),
        .object = try in.takeInt(u64, .little),
        .revision = try in.takeInt(u64, .little),
        .schema = try takeReference(&in),
        .next_record = undefined,
    };
    switch (try in.takeByte()) {
        0 => {},
        1 => {
            const ref = try takeReference(&in);
            const level = try in.takeByte();
            const minimum = try Index.Key.init(try in.take(try in.takeByte()));
            result.index.root = .{ .id = ref.id, .spec = ref.spec, .level = level, .minimum = minimum, .entries = try in.takeInt(u64, .little) };
        },
        else => return error.InvalidTableHead,
    }
    result.rows = try in.takeInt(u64, .little);
    result.next_record = try in.takeInt(u64, .little);
    result.pending = try in.takeInt(u64, .little);
    result.retired = switch (try in.takeByte()) {
        0 => false,
        1 => true,
        else => return error.InvalidTableHead,
    };
    if (in.bufferedLen() != 0) return error.InvalidTableHead;
    try result.validate();
    return result;
}
pub fn decode(value: p.Value) !Self {
    try value.validate();
    return parse(value.slice()) catch |err| switch (err) {
        error.EndOfStream => error.InvalidTableHead,
        else => err,
    };
}
pub fn load(source: anytype, object: u64) !Self {
    if (object == 0) return error.InvalidTableHead;
    const result = try decode((try source.read(key(object))) orelse return error.TableNotFound);
    if (result.object != object) return error.InvalidTableHead;
    if (result.resource != source.view.resource) return error.CrossResourceTransaction;
    return result;
}
/// Every revision has an immutable schema reference. A retained head must be
/// read under its original source; the current schema never reinterprets it.
pub fn readSchema(self: Self, allocator: std.mem.Allocator, source: anytype) !f.TableSchema.Owned {
    try self.validate();
    const pages: Pages = .{ .resource = self.resource, .object = self.object };
    const buffer = try allocator.alloc(u8, self.schema.spec.length);
    defer allocator.free(buffer);
    var owned = try f.TableSchema.decode(allocator, try pages.read(source, self.schema, buffer));
    errdefer owned.deinit();
    if (owned.schema.object != self.object) return error.InvalidTableHead;
    const count = std.math.mul(u64, self.rows, if (owned.schema.primary_key.len == 0) 1 else 2) catch return error.InvalidTableHead;
    if (count != if (self.index.root) |root| root.entries else 0) return error.InvalidTableHead;
    return owned;
}
/// Install an empty, staged schema. Catalog identity/name/receipt publication
/// belongs in the same enclosing turn. Existing/tombstoned heads never reset.
pub fn create(self: Self, allocator: std.mem.Allocator, turn: *Turn) !void {
    try self.validate();
    if (self.revision != 1 or self.rows != 0 or self.index.root != null or self.pending != 0 or self.retired) return error.InvalidTableHead;
    if (try turn.read(key(self.object)) != null) return error.TableExists;
    var schema = try self.readSchema(allocator, turn);
    defer schema.deinit();
    if (schema.schema.revision != 1) return error.InvalidTableHead;
    try turn.write(key(self.object), try self.encode());
}
/// Conditional replacement is only a private KV write. The owner must first
/// validate/stage all successor references and compose the final outcome.
pub fn replace(self: Self, turn: *Turn, after: Self) !void {
    try self.validate();
    try after.validate();
    if (self.resource != turn.view.resource) return error.CrossResourceTransaction;
    if (self.retired) return error.TableRetired;
    if (after.resource != self.resource or after.object != self.object or after.revision != (std.math.add(u64, self.revision, 1) catch return error.TableCapacity) or after.next_record < self.next_record) return error.InvalidTableHead;
    const current = (try turn.read(key(self.object))) orelse return error.TableNotFound;
    if (!current.eql(try self.encode())) return error.TableHeadChanged;
    try turn.write(key(self.object), try after.encode());
}
