//! Pure bounded upload continuation for all hosts. Observations guide a proposal;
//! only the durable owner and current native authority can admit it.
const std = @import("std");
const root = @import("root.zig");
pub const Cleanup = struct { proposal: root.Publication.Proposal, state: root.Native.State };
/// Close only the caller's exact reviewed upload, then reclaim its staging
/// reservation in bounded turns. Published revisions and permanent receipts stay.
pub fn nextCleanup(input: Cleanup) !?root.Request.Command {
    try root.Publication.validateProposal(input.proposal);
    const receipt = input.state.receipt orelse return error.ApplicationOperationNotFound;
    if (!std.meta.eql(receipt.proposal, input.proposal)) return error.ApplicationOperationConflict;
    switch (receipt.phase) {
        .applied => return error.ApplicationAlreadyApplied,
        .staging, .conflict => return .{ .abandon = input.proposal.operation },
        .abandoned => {},
    }
    if (!receipt.owns_record) return null;
    const upload = input.state.upload orelse return error.ApplicationUploadUnavailable;
    if (upload.state != .abandoned or upload.first_half or upload.collected > upload.written or upload.written > input.proposal.spec.chunks()) return error.ApplicationUploadUnavailable;
    if (!upload.reserved) {
        if (upload.collected != upload.written) return error.ApplicationUploadUnavailable;
        return null;
    }
    return .{ .collect = input.proposal.operation };
}
pub const Input = struct {
    proposal: root.Publication.Proposal,
    canonical: []const u8,
    state: root.Native.State,
    pub const json_schema_fields = .{ .canonical = .{ .type = "string", .maxLength = root.Model.max_program_bytes } };
};
pub fn next(allocator: std.mem.Allocator, input: Input) !?root.Request.Command {
    return nextDiagnostic(allocator, input, null);
}
pub fn nextDiagnostic(allocator: std.mem.Allocator, input: Input, diagnostic: ?*?root.protocol.Diagnostic) !?root.Request.Command {
    try root.Publication.validateProposal(input.proposal);
    var compiled = try root.Host.compileDiagnostic(allocator, input.canonical, diagnostic);
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
