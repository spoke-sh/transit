//! Reassemble one immutable 256-byte publication chunk from ordinary envelopes.
//! The composing owner supplies a scoped scratch key and checks current authority.
const std = @import("std");
const p = @import("transit_client").protocol;
const Turn = @import("Turn.zig").Growing;
const Pub = @import("Publication.zig");
const Ref = @import("PublicationReference.zig");
pub const part_bytes = Pub.chunk_bytes / 2;
pub const Part = struct { ordinal: u32, second: bool, bytes: []const u8 };
pub fn append(turn: *Turn, reference: Ref, scratch: p.Value, part: Part) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try reference.validate();
    const publication = reference.publication();
    const descriptor = try publication.inspect(turn, reference.record);
    if (!std.meta.eql(descriptor.spec, reference.spec)) return error.PublicationReferenceChanged;
    if (descriptor.state != .staging and descriptor.state != .published) return error.PublicationClosed;
    const length = try reference.spec.size(part.ordinal);
    const offset: usize = if (part.second) part_bytes else 0;
    if (offset >= length or part.bytes.len != @min(part_bytes, length - offset)) return error.InvalidPublicationPart;
    if (part.ordinal < descriptor.written) {
        const existing = (try turn.read(Pub.key(reference.namespace, 'c', reference.record, part.ordinal))) orelse return error.MissingPublicationChunk;
        if (existing.len != length or !std.mem.eql(u8, existing.slice()[offset..][0..part.bytes.len], part.bytes)) return error.PublicationPartConflict;
        return;
    }
    if (part.ordinal != descriptor.written) return error.PublicationGap;
    if (length <= part_bytes) {
        _ = try publication.append(turn, reference.record, part.ordinal, part.bytes);
    } else if (!part.second) {
        if (try turn.read(scratch)) |existing| {
            if (existing.len != part.bytes.len or !std.mem.eql(u8, existing.slice(), part.bytes)) return error.PublicationPartConflict;
        } else try turn.write(scratch, try p.Value.init(part.bytes));
    } else {
        const first = (try turn.read(scratch)) orelse return error.PublicationGap;
        if (first.len != part_bytes) return error.InvalidPublicationPart;
        var bytes: [Pub.chunk_bytes]u8 = undefined;
        @memcpy(bytes[0..first.len], first.slice());
        @memcpy(bytes[first.len..][0..part.bytes.len], part.bytes);
        _ = try publication.append(turn, reference.record, part.ordinal, bytes[0..length]);
        try turn.write(scratch, null);
    }
}
