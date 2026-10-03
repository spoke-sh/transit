//! Projections use retained owner records; no head lookup can rewrite a conflict.
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;

pub fn receipt(scope: root.Native.Scope, value: root.Publication.Receipt) !d {
    try scope.validate();
    try root.Publication.validateReceipt(value);
    const message: []const u8 = switch (value.phase) {
        .staging => "The reviewed interface body is staging. It is not the active revision. Continue only this exact proposal after reading its current upload progress; abandoning it cannot undo an already published revision.",
        .applied => "The reviewed interface revision was published atomically. Its body, head and receipt committed together. Cleanup cannot roll back this activation; a lost reply or later inspection failure does not change it.",
        .conflict => "The active interface revision or body digest differed from this proposal's reviewed base. This proposal did not activate. The recorded expected and observed bases belong to the original rejecting turn. Inspect them before reviewing a new proposal; staged bytes require explicit cleanup.",
        .abandoned => "This interface upload was explicitly abandoned without activation. Any original base conflict remains recorded. Abandonment does not roll back active revisions or prove that staging bytes have been collected.",
    };
    var result = try d.init(switch (value.phase) {
        .staging => "publication.staging",
        .applied => "publication.applied",
        .conflict => "publication.base_conflict",
        .abandoned => "publication.abandoned",
    }, if (value.phase == .conflict) .conflict else .lifecycle, .execute, switch (value.phase) {
        .staging => .pending,
        .applied => .applied,
        .conflict => .rejected,
        .abandoned => .cancelled,
    }, .domain_status, message);
    result.identity = .{ .domain = .publication, .id = .init(value.proposal.operation.value), .realm = .init(scope.realm), .resource = .init(scope.resource) };
    try result.fact(.object, .owner, .{ .unsigned = .init(scope.application) });
    try result.fact(.proposal, .owner, .{ .unsigned = .init(value.proposal.record.value) });
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.expected_revision, .owner, .{ .unsigned = .init(value.proposal.expected.value) });
    try result.fact(.expected_schema, .owner, .{ .digest = value.proposal.expected_digest });
    try result.fact(.required, .owner, .{ .unsigned = .init(value.proposal.revision.value) });
    try result.fact(.source_basis, .owner, .{ .digest = value.proposal.spec.digest });
    try result.text(.operation, .owner, @tagName(value.phase));
    switch (value.conflict_basis) {
        .none => {},
        .absent => {
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(0) });
            try result.fact(.actual_schema, .owner, .{ .digest = @splat(0) });
        },
        .head => |basis| {
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(basis.revision.value) });
            try result.fact(.actual_schema, .owner, .{ .digest = basis.digest });
        },
    }
    try result.action(.inspect_status);
    if (value.phase == .staging) try result.action(.resume_exact);
    if (value.phase == .conflict) try result.action(.refresh);
    try result.validate();
    return result;
}
