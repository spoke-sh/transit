//! Accepted recovery baselines. A content-addressed object is only staged until
//! a Table WAL transition publishes its reference and extends its exact chain.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const r = @import("TablePartitionRecord.zig");
const Objects = @import("TransitObjectStore.zig");
const header_bytes = 40;
pub const max_bytes = header_bytes + r.max_metadata_bytes;

pub const Reference = struct {
    next_lsn: u64,
    content: d.Content,

    pub fn validate(self: Reference, next_lsn: u64) !void {
        try self.content.validate();
        if (self.next_lsn == 0 or self.next_lsn >= next_lsn or
            self.content.bytes <= header_bytes or self.content.bytes > max_bytes) return error.InvalidTableRecovery;
    }
};

pub const Basis = struct { root: r.Root, chain: [32]u8 };

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    return std.fmt.bufPrint(output, "table-checkpoints/{x}.tman", .{&content.sha256});
}

pub fn stage(objects: Objects.ObjectStore, basis: Basis) !Reference {
    try basis.root.validate();
    if (basis.root.next_lsn == 0) return error.InvalidTableRecovery;
    var buffer: [max_bytes]u8 = undefined;
    buffer[0..8].* = "TCHECK1\x00".*;
    buffer[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(buffer[header_bytes..]);
    try std.json.Stringify.value(basis, .{}, &writer);
    const bytes = buffer[0 .. header_bytes + writer.end];
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = r.hash(bytes) };
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) return error.InvalidTableRecovery;
    return .{ .next_lsn = basis.root.next_lsn, .content = content };
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: Reference, end: u64, partition: u64, object: d.Object) !Basis {
    try reference.validate(end);
    var name: [96]u8 = undefined;
    const object_key = try key(reference.content, &name);
    const metadata = try objects.head(object_key) orelse return error.TableRecoveryMissing;
    if (metadata.size != reference.content.bytes or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) return error.InvalidTableRecovery;
    const buffer = try allocator.alloc(u8, @intCast(reference.content.bytes));
    defer allocator.free(buffer);
    const bytes = try objects.getRange(object_key, 0, @intCast(buffer.len), buffer);
    if (bytes.len != buffer.len or !std.mem.eql(u8, &r.hash(bytes), &reference.content.sha256) or
        !std.mem.eql(u8, bytes[0..8], "TCHECK1\x00")) return error.InvalidTableRecovery;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try std.json.parseFromSlice(Basis, allocator, bytes[header_bytes..], .{});
    defer parsed.deinit();
    const basis = parsed.value;
    try basis.root.validate();
    if (basis.root.next_lsn != reference.next_lsn or basis.root.partition != partition or
        !std.meta.eql(basis.root.interpretation.object, object)) return error.InvalidTableRecovery;
    return basis;
}
