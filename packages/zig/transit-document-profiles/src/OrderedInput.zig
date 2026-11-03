//! Convert a completely verified single JSON/XML/MIME part into an ordered storage
//! request. Output is private until success; this module cannot publish it.
const std = @import("std");
const p = @import("transit_protocol");
const document = @import("transit_document");
const ordered = document.OrderedChange;
const Reader = @import("Reader.zig");
const Profile = @import("Profile.zig");
pub const Request = struct {
    document: [16]u8,
    epoch: u64,
    expected_revision: u64,
    path: []const u8 = "",
};
pub const Workspace = struct {
    reader: Reader.Workspace,
    name: []u8,
    /// Output offsets for container span ends; bounded by parser depth.
    ends: []usize,
};
pub const Candidate = struct {
    bytes: []const u8,
    descriptor: Profile.contract.Descriptor,
    verified_part: Profile.contract.Part,
};
/// Input/output/workspace must not overlap. The caller owns their lifetimes and
/// bounds. The retained profile attestation is returned separately: a generic
/// ordered tree does not itself claim a profile grammar or application schema.
pub fn encode(descriptor: Profile.contract.Descriptor, part: Profile.contract.Part, request: Request, input: []const u8, workspace: Workspace, output: []u8) !Candidate {
    if (descriptor.format != .mime and (workspace.name.len < descriptor.limits.token_bytes or workspace.ends.len < descriptor.limits.depth)) return error.DocumentWorkspaceTooSmall;
    if (input.len != part.bytes) return error.DocumentProfilePartConflict;
    var reader = try Reader.init(descriptor, part, workspace.reader);
    if (output.len < 8) return error.DocumentEncodingCapacity;
    errdefer @memset(output[0..8], 0);
    var w: document.codec.Writer = .{ .bytes = output };
    try ordered.writeHeader(&w, .{ .definition = p.Growth.definition_bytes, .document = request.document, .epoch = request.epoch, .expected_revision = request.expected_revision, .path = request.path, .nodes = 1, .parts = 1 });
    const count_offset = w.offset - 8;
    try ordered.writePart(&w, .{ .id = part.id, .bytes = input, .digest = part.sha256 });
    if (descriptor.format == .mime) {
        const nodes = try writeMime(&reader, part, input, &w);
        const verified = try reader.verifiedPart();
        std.mem.writeInt(u32, output[count_offset..][0..4], nodes, .little);
        return .{ .bytes = output[0..w.offset], .descriptor = descriptor, .verified_part = verified };
    }
    const xml = descriptor.format == .xml;
    var nodes: u32 = 0;
    // XML permits comments/PIs before and after its element root. An explicit
    // ordered envelope preserves them without creating multiple tree roots.
    if (xml) {
        try ordered.writeNode(&w, .{ .depth = 0, .kind = .list, .span = .{ .part = part.id, .start = 0, .end = part.bytes } });
        nodes = 1;
    }
    var name_len: usize = 0;
    var offset: usize = 0;
    while (true) {
        const step = try reader.next(input[offset..], true, 256);
        offset += step.consumed;
        switch (step.result) {
            .complete => break,
            .need_input => return error.IncompleteDocumentFrame,
            .yield => {},
            .event => |event| {
                switch (event.kind) {
                    .key => {
                        if (event.value.len > workspace.name.len) return error.DocumentWorkspaceTooSmall;
                        @memcpy(workspace.name[0..event.value.len], event.value);
                        name_len = event.value.len;
                        continue;
                    },
                    .object_end, .array_end, .element_end => {
                        const end = workspace.ends[event.depth];
                        std.mem.writeInt(u64, output[end..][0..8], event.span.byte_end, .little);
                        continue;
                    },
                    else => {},
                }
                var node: ordered.Node = .{ .depth = event.depth + @as(u32, @intFromBool(xml)), .kind = undefined, .name = workspace.name[0..name_len], .span = .{ .part = event.span.part_id, .start = event.span.byte_start, .end = event.span.byte_end } };
                const boolean = [_]u8{@intFromBool(std.mem.eql(u8, event.value, "true"))};
                switch (event.kind) {
                    .object_start => node.kind = .map,
                    .array_start => node.kind = .list,
                    .string, .number, .text, .comment => {
                        node.kind = switch (event.kind) {
                            .string => .string,
                            .number => .number,
                            .text => .text,
                            .comment => .comment,
                            else => unreachable,
                        };
                        node.value = event.value;
                    },
                    .boolean => {
                        node.kind = .boolean;
                        node.value = &boolean;
                    },
                    .null_value => node.kind = .null_value,
                    .element_start => {
                        node.kind = .element;
                        node.name = event.value;
                    },
                    .attribute, .processing_instruction => {
                        node.kind = if (event.kind == .attribute) .attribute else .processing_instruction;
                        node.name = event.value;
                        node.value = event.detail;
                    },
                    else => unreachable,
                }
                try ordered.writeNode(&w, node);
                if (node.kind.container()) workspace.ends[event.depth] = w.offset - 8;
                name_len = 0;
                nodes = std.math.add(u32, nodes, 1) catch return error.DocumentNodeLimitExceeded;
            },
        }
    }
    const verified = try reader.verifiedPart();
    std.mem.writeInt(u32, output[count_offset..][0..4], nodes, .little);
    return .{ .bytes = output[0..w.offset], .descriptor = descriptor, .verified_part = verified };
}

/// An explicit envelope keeps header names (including "body") independent of
/// the body member. Parser fetch windows never become logical body nodes.
fn writeMime(reader: *Reader, part: Profile.contract.Part, input: []const u8, w: *document.codec.Writer) !u32 {
    try ordered.writeNode(w, .{ .depth = 0, .kind = .map, .span = .{ .part = part.id, .start = 0, .end = part.bytes } });
    try ordered.writeNode(w, .{ .depth = 1, .kind = .list, .name = "headers", .span = .{ .part = part.id, .start = 0, .end = 0 } });
    const headers_end_offset = w.offset - 8;
    var body_start: ?usize = null;
    var nodes: u32 = 3; // Envelope, header list and the single (possibly empty) body.
    var offset: usize = 0;
    while (true) {
        const step = try reader.next(input[offset..], true, 256);
        offset += step.consumed;
        switch (step.result) {
            .complete => break,
            .need_input => return error.IncompleteDocumentFrame,
            .yield => {},
            .event => |event| switch (event.kind) {
                .mime_field => {
                    try ordered.writeNode(w, .{ .depth = 2, .kind = .binary, .name = event.value, .value = event.detail, .span = .{ .part = part.id, .start = event.span.byte_start, .end = event.span.byte_end } });
                    nodes = std.math.add(u32, nodes, 1) catch return error.DocumentNodeLimitExceeded;
                },
                .mime_headers_end => {
                    body_start = @intCast(event.span.byte_end);
                    std.mem.writeInt(u64, w.bytes[headers_end_offset..][0..8], event.span.byte_end, .little);
                },
                .mime_body => {}, // Retain the verified input slice once, below.
                else => unreachable,
            },
        }
    }
    _ = try reader.verifiedPart();
    const start = body_start orelse return error.IncompleteDocumentFrame;
    try ordered.writeNode(w, .{ .depth = 1, .kind = .binary, .name = "body", .value = input[start..], .span = .{ .part = part.id, .start = start, .end = part.bytes } });
    return nodes;
}
