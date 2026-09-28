//! Pure bounded upload continuation for all hosts. Observations guide a proposal;
//! only the durable owner and current native authority can admit it.
const std = @import("std");
const root = @import("root.zig");
pub const Input = struct {
    proposal: root.Publication.Proposal,
    canonical: []const u8,
    state: root.Native.State,
    pub const json_schema_fields = .{ .canonical = .{ .type = "string", .maxLength = root.Model.max_program_bytes } };
};
pub fn next(allocator: std.mem.Allocator, input: Input) !?root.Request.Command {
    try root.Publication.validateProposal(input.proposal);
    var compiled = try root.Host.compile(allocator, input.canonical);
    defer compiled.deinit();
    const value = compiled.value.compiled;
    if (!std.mem.eql(u8, value.canonical, input.canonical) or !std.meta.eql(value.spec, input.proposal.spec) or value.definition.revision.value != input.proposal.revision.value or value.definition.realm != input.state.configuration.realm or !std.mem.eql(u8, &root.Publication.nameDigest(value.definition.name), &input.state.configuration.name_digest)) return error.InvalidApplicationProgram;
    if (input.state.disposition != null) return error.ApplicationOperationDenied;
    const receipt = input.state.receipt orelse return .{ .begin = input.proposal };
    if (!std.meta.eql(receipt.proposal, input.proposal)) return error.ApplicationOperationConflict;
    switch (receipt.phase) {
        .applied => return null,
        .conflict, .abandoned => return error.ApplicationOperationConflict,
        .staging => {},
    }
    const upload = input.state.upload orelse return error.ApplicationUploadUnavailable;
    if (!receipt.owns_record or upload.state != .staging or upload.written > input.proposal.spec.chunks()) return error.ApplicationUploadUnavailable;
    if (upload.written == input.proposal.spec.chunks()) {
        if (upload.first_half) return error.ApplicationUploadUnavailable;
        return .{ .publish = input.proposal.operation };
    }
    const offset: usize = @as(usize, upload.written) * root.station.Publication.chunk_bytes + @as(usize, if (upload.first_half) root.station.PublicationParts.part_bytes else 0);
    if (offset >= input.canonical.len) return error.ApplicationUploadUnavailable;
    return .{ .part = .{ .operation = input.proposal.operation, .ordinal = upload.written, .second = upload.first_half, .bytes = try root.protocol.Value.init(input.canonical[offset..@min(input.canonical.len, offset + root.station.PublicationParts.part_bytes)]) } };
}
