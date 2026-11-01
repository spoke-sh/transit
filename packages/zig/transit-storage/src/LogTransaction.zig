//! Retained log transaction cuts and immutable preparation references. A staged
//! source is private until its partition WAL publishes a live pin. Neither its
//! content address nor its original transaction identity grants access.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const x = p.Transaction;
const r = @import("LogPartitionRecord.zig");
const Objects = @import("TransitObjectStore.zig");
const pages = @import("TreeStore.zig").pages;
pub const max_bytes = 64 * 1024;
pub const Reference = struct {
    content: d.Content,
    pub fn validate(self: Reference) !void {
        try self.content.validate();
        if (self.content.bytes <= 40 or self.content.bytes > max_bytes) return error.InvalidLogTransaction;
    }
};
pub const Source = struct {
    definition: p.Growth.Definition,
    identity: x.Identity,
    root: r.Root,
    pub fn validate(self: Source) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        try self.root.validate();
        try self.identity.requireObject(self.root.declared.declaration.interpretation.object);
        if (self.root.declared.retired or self.root.transaction != null or self.root.transaction_pins != null) return error.InvalidLogTransaction;
    }
    pub fn guard(self: Source) !x.LogGuard {
        try self.validate();
        return logGuard(self.root);
    }
};
pub const Pin = struct {
    source: d.Content,
    released: bool,
    pub fn encode(self: Pin) !pages.Value {
        try (Reference{ .content = self.source }).validate();
        var bytes: [41]u8 = undefined;
        bytes[0] = @intFromBool(self.released);
        std.mem.writeInt(u64, bytes[1..9], self.source.bytes, .big);
        bytes[9..41].* = self.source.sha256;
        return pages.Value.init(&bytes);
    }
    pub fn decode(value: pages.Value) !Pin {
        if (value.len != 41 or value.data[0] > 1) return error.InvalidLogTransaction;
        const result: Pin = .{ .source = .{ .bytes = std.mem.readInt(u64, value.data[1..9], .big), .sha256 = value.data[9..41].* }, .released = value.data[0] == 1 };
        try (Reference{ .content = result.source }).validate();
        return result;
    }
};
pub const PinState = struct { handle: ?x.Pin, released: bool, position: d.Position };

pub fn logGuard(root: r.Root) !x.LogGuard {
    try root.validate();
    return .{ .kind = if (root.declared.declaration.configuration.policy == .stream) .stream else .queue, .source = try root.retainedCut(root.declared), .changed_lsn = root.changed_lsn };
}
pub fn sourceKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try (Reference{ .content = content }).validate();
    return std.fmt.bufPrint(output, "log-tx-sources/{x}.data", .{&content.sha256});
}
fn encodeSource(value: Source, output: *[max_bytes]u8) ![]const u8 {
    try value.validate();
    output[0..8].* = "TXLSRC1\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return output[0 .. 40 + writer.end];
}
pub fn stageSource(objects: Objects.ObjectStore, source: Source) !x.Pin {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encodeSource(source, &buffer);
    const content = @import("LogBatch.zig").content(bytes);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try sourceKey(content, &name), bytes, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidLogTransaction;
    return .{ .owner = source.identity.begin, .content = content };
}
pub fn loadSource(objects: Objects.ObjectStore, handle: x.Pin) !Source {
    try handle.owner.validate();
    var name: [96]u8 = undefined;
    const path = try sourceKey(handle.content, &name);
    const metadata = try objects.head(path) orelse return error.LogTransactionSourceMissing;
    if (metadata.size != handle.content.bytes or !std.mem.eql(u8, &metadata.sha256, &handle.content.sha256)) return error.InvalidLogTransaction;
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try objects.getRange(path, 0, @intCast(handle.content.bytes), &buffer);
    if (!std.meta.eql(@import("LogBatch.zig").content(bytes), handle.content) or !std.mem.eql(u8, bytes[0..8], "TXLSRC1\x00")) return error.InvalidLogTransaction;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const source = std.json.parseFromSliceLeaky(Source, fixed.allocator(), bytes[40..], .{}) catch |err| return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    try source.validate();
    if (!std.meta.eql(source.identity.begin, handle.owner)) return error.TransactionIdentityConflict;
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encodeSource(source, &canonical))) return error.InvalidLogTransaction;
    return source;
}
