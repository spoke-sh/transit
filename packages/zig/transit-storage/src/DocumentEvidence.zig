//! Immutable Document operation outcome receipts (`DEVID001`) in
//! `document-evidence/{sha256}.data`.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;
const Objects = @import("TransitObjectStore.zig");

pub const magic = "DEVID001";
const header_bytes = 40;
pub const max_bytes = 16384;

pub const Outcome = union(enum) {
    mutation: doc.MutationReceipt,
    checkpoint: doc.CheckpointReceipt,
    read: doc.Read.Receipt,
    read_release: doc.Read.ReleaseReceipt,

    pub fn validate(self: Outcome) !void {
        switch (self) {
            .mutation => |v| try v.validate(),
            .checkpoint => |v| try v.validate(),
            .read => |v| try v.validate(),
            .read_release => |v| try v.validate(),
        }
    }

    pub fn operation(self: Outcome) d.Operation {
        return switch (self) {
            .mutation => |v| v.mutation.operation,
            .checkpoint => |v| v.checkpoint.operation,
            .read => |v| v.request.operation,
            .read_release => |v| v.release.operation,
        };
    }
};

pub fn hash(bytes: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidDocumentEvidence;
    return std.fmt.bufPrint(output, "document-evidence/{x}.data", .{&content.sha256});
}

pub fn encode(outcome: Outcome, output: *[max_bytes]u8) ![]const u8 {
    try outcome.validate();
    output[0..8].* = magic.*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(outcome, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn stage(objects: Objects.ObjectStore, outcome: Outcome) !d.Content {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(outcome, &buffer);
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = hash(bytes) };
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) {
        return error.InvalidDocumentEvidence;
    }
    return content;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !Outcome {
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const meta = (try objects.head(object_key)) orelse return error.DocumentEvidenceMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) {
        return error.InvalidDocumentEvidence;
    }
    var buffer: [max_bytes]u8 = undefined;
    const slice = buffer[0..@intCast(content.bytes)];
    if ((try objects.getRange(object_key, 0, @intCast(slice.len), slice)).len != slice.len) {
        return error.InvalidDocumentEvidence;
    }
    if (!std.mem.eql(u8, &hash(slice), &content.sha256) or !std.mem.eql(u8, slice[0..8], magic)) {
        return error.InvalidDocumentEvidence;
    }
    if (!std.mem.eql(u8, slice[8..40], &p.Growth.definition_bytes)) {
        return error.IncompatibleDefinition;
    }
    const parsed = try p.Json.parseFromSlice(Outcome, allocator, slice[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, slice, try encode(parsed.value, &canonical))) {
        return error.InvalidDocumentEvidence;
    }
    return parsed.value;
}
