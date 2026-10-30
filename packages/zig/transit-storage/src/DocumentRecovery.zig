//! Immutable Document partition recovery checkpoints (`DCHECK01` in
//! `document-checkpoints/{sha256}.data`).
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const Initialization = @import("DocumentInitialization.zig");
const Records = @import("DocumentPartitionRecord.zig");
const Evidence = @import("DocumentEvidence.zig");
const Objects = @import("TransitObjectStore.zig");

pub const magic = "DCHECK01";
const header_bytes = 40;
pub const max_bytes = header_bytes + 32768;

pub const Baseline = struct {
    definition: p.Growth.Definition,
    root: Records.Root,
    commitment: [32]u8,

    pub fn validate(self: Baseline) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.root.validate();
        if (std.mem.allEqual(u8, &self.commitment, 0)) return error.InvalidDocumentRecovery;
    }
};

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidDocumentRecovery;
    return std.fmt.bufPrint(output, "document-checkpoints/{x}.data", .{&content.sha256});
}

pub fn encode(baseline: Baseline, output: *[max_bytes]u8) ![]const u8 {
    try baseline.validate();
    output[0..8].* = magic.*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(baseline, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn stage(objects: Objects.ObjectStore, root: Records.Root, commitment: [32]u8) !Records.RecoveryReference {
    const baseline: Baseline = .{
        .definition = p.Growth.current_definition,
        .root = root,
        .commitment = commitment,
    };
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(baseline, &buffer);
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = Evidence.hash(bytes) };
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) {
        return error.InvalidDocumentRecovery;
    }
    return .{ .next_lsn = root.next_lsn, .content = content };
}

pub fn load(
    allocator: std.mem.Allocator,
    objects: Objects.ObjectStore,
    reference: Records.RecoveryReference,
    current_next_lsn: u64,
    initialization: Initialization.Request,
) !Baseline {
    try reference.validate(current_next_lsn);
    var name: [96]u8 = undefined;
    const object_key = try key(reference.content, &name);
    const metadata = (try objects.head(object_key)) orelse return error.DocumentRecoveryMissing;
    if (metadata.size != reference.content.bytes or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) {
        return error.InvalidDocumentRecovery;
    }
    var buffer: [max_bytes]u8 = undefined;
    const bytes = buffer[0..@intCast(reference.content.bytes)];
    if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len) {
        return error.InvalidDocumentRecovery;
    }
    if (!std.mem.eql(u8, &Evidence.hash(bytes), &reference.content.sha256) or !std.mem.eql(u8, bytes[0..8], magic)) {
        return error.InvalidDocumentRecovery;
    }
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Baseline, allocator, bytes[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed.value, &canonical))) return error.InvalidDocumentRecovery;
    try initialization.requireSame(parsed.value.root.initialization);
    if (parsed.value.root.next_lsn != reference.next_lsn) return error.InvalidDocumentRecovery;
    return parsed.value;
}

pub fn requirePublication(
    baseline: Baseline,
    reference: Records.RecoveryReference,
    publication: Records.Record,
) !void {
    try baseline.validate();
    try publication.validate();
    var expected = baseline.root;
    expected.next_lsn = reference.next_lsn + 1;
    expected.recovery = reference;
    if (publication.action != .recovery_checkpoint or
        !std.meta.eql(publication.action.recovery_checkpoint, reference) or
        !std.mem.eql(u8, &publication.previous_commitment, &baseline.commitment) or
        !std.meta.eql(publication.root, expected))
    {
        return error.InvalidDocumentRecovery;
    }
}
