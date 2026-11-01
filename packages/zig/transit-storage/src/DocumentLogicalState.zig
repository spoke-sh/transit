//! Definition-bound roots for the integrated causal map-tree storage slice.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Index = @import("DocumentIndex.zig");
const Objects = @import("TransitObjectStore.zig");
const Hash = @import("DocumentEvidence.zig");
pub const magic = "DLOG0001";
pub const max_bytes = 4096;
pub const State = struct {
    definition: p.Growth.Definition,
    target: p.DocumentOperation.Target,
    epoch: u64,
    conflicts: u16,
    index: Index.Root,
    pub fn validate(self: State) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target.validate();
        try self.index.validate();
        if (self.epoch == 0 or self.index.identity.document != self.target.partition.interpretation.object.object or self.index.identity.epoch != self.epoch or self.index.identity.type_revision != self.target.partition.interpretation.revision) return error.InvalidLogicalState;
    }
};
pub fn encode(state: State, output: *[max_bytes]u8) ![]const u8 {
    try state.validate();
    output[0..8].* = magic.*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(state, &encoder);
    return output[0 .. 40 + writer.buffered().len];
}
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !State {
    if (bytes.len <= 40 or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..8], magic)) return error.InvalidLogicalState;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(State, allocator, bytes[40..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidLogicalState;
    return parsed.value;
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !State {
    if (content.bytes > max_bytes) return error.InvalidLogicalState;
    var name: [96]u8 = undefined;
    const key = try std.fmt.bufPrint(&name, "document-states/{x}.data", .{&content.sha256});
    const meta = try objects.head(key) orelse return error.DocumentStateObjectMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidLogicalState;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(key, 0, @intCast(content.bytes), &buffer);
    if (bytes.len != content.bytes or !std.mem.eql(u8, &Hash.hash(bytes), &content.sha256)) return error.InvalidLogicalState;
    return decode(allocator, bytes);
}
/// Verify bounded state bytes before format dispatch. A damaged magic cannot
/// make the collector treat a logical root as an opaque leaf and omit children.
pub fn isLogical(objects: Objects.ObjectStore, content: d.Content) !bool {
    try content.validate();
    // Every logical descriptor is <= max_bytes; larger opaque state has no
    // logical child references in this format.
    if (content.bytes > max_bytes) return false;
    var name: [96]u8 = undefined;
    const key = try std.fmt.bufPrint(&name, "document-states/{x}.data", .{&content.sha256});
    const meta = try objects.head(key) orelse return error.DocumentStateObjectMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidLogicalState;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(key, 0, @intCast(content.bytes), &buffer);
    if (bytes.len != content.bytes or !std.mem.eql(u8, &Hash.hash(bytes), &content.sha256)) return error.InvalidLogicalState;
    return std.mem.startsWith(u8, bytes, magic);
}
