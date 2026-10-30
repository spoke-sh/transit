//! Immutable log recovery baselines. Only the exact WAL checkpoint transition
//! publishes one; object presence or a copied reference supplies no authority.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const r = @import("LogPartitionRecord.zig");
const I = @import("LogInitialization.zig");
const Objects = @import("TransitObjectStore.zig");
const Evidence = @import("LogEvidence.zig");
const header_bytes = 40;
pub const max_bytes = header_bytes + r.max_metadata_bytes;
pub const Reference = struct {
    next_lsn: u64,
    content: d.Content,
    pub fn validate(self: Reference, end: u64) !void {
        try self.content.validate();
        if (self.next_lsn == 0 or self.next_lsn >= end or self.content.bytes <= header_bytes or self.content.bytes > max_bytes) return error.InvalidLogRecovery;
    }
};
pub const Basis = struct {
    root: r.Root,
    commitment: [32]u8,
    pub fn validate(self: Basis) !void {
        try self.root.validate();
        if (std.mem.allEqual(u8, &self.commitment, 0)) return error.InvalidLogRecovery;
    }
};
pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "log-checkpoints/{x}.data", .{&content.sha256});
}
pub fn stage(objects: Objects.ObjectStore, basis: Basis) !Reference {
    try basis.validate();
    var bytes: [max_bytes]u8 = undefined;
    bytes[0..8].* = "LCHECK01".*;
    bytes[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(basis, &encoder);
    const encoded = bytes[0 .. header_bytes + writer.end];
    const content: d.Content = .{ .bytes = encoded.len, .sha256 = Evidence.hash(encoded) };
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(content, &name), encoded, content.sha256);
    if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidLogRecovery;
    return .{ .next_lsn = basis.root.next_lsn, .content = content };
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: Reference, end: u64, initialization: I.Request) !Basis {
    try reference.validate(end);
    var name: [96]u8 = undefined;
    const object_key = try key(reference.content, &name);
    const metadata = try objects.head(object_key) orelse return error.LogRecoveryMissing;
    if (metadata.size != reference.content.bytes or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) return error.InvalidLogRecovery;
    var bytes: [max_bytes]u8 = undefined;
    const encoded = try objects.getRange(object_key, 0, @intCast(reference.content.bytes), &bytes);
    if (encoded.len != reference.content.bytes or !std.mem.eql(u8, &Evidence.hash(encoded), &reference.content.sha256) or !std.mem.eql(u8, encoded[0..8], "LCHECK01")) return error.InvalidLogRecovery;
    if (!std.mem.eql(u8, encoded[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Basis, allocator, encoded[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    if (parsed.value.root.next_lsn != reference.next_lsn) return error.InvalidLogRecovery;
    try initialization.requireSame(parsed.value.root.initialization);
    return parsed.value;
}

/// Verify the sole publishing transition. The caller must obtain this record
/// from its accepted WAL at reference.next_lsn, never from an arbitrary object.
pub fn requirePublication(basis: Basis, reference: Reference, record: r.Record) !void {
    try basis.validate();
    try record.validate(reference.next_lsn);
    if (record.action != .checkpoint or basis.root.next_lsn != reference.next_lsn or !std.mem.eql(u8, &record.previous, &basis.commitment)) return error.InvalidLogRecovery;
    var expected = basis.root;
    expected.next_lsn = try std.math.add(u64, expected.next_lsn, 1);
    expected.recovery = reference;
    if (!std.meta.eql(record.root, expected)) return error.InvalidLogRecovery;
}
