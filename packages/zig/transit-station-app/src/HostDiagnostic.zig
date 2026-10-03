//! Attempt evidence from the actual host dispatch boundary. Caller-supplied
//! observations are not authoritative publication outcomes.
const app = @import("root.zig");
const p = app.protocol;
const d = p.Diagnostic;
const Class = struct { code: []const u8, category: d.Category, message: []const u8 };

pub const entries = [_]struct { cause: anyerror, code: []const u8, category: d.Category, message: []const u8 }{
    .{ .cause = error.AuthorityTransportDenied, .code = "application.transport_denied", .category = .unavailable, .message = "Local network or operating-system policy denied the connection to the authority. No authority rejection was received. Check the connection policy; preserve any exact saved command and reconcile its outcome before preparing new work." },
    .{ .cause = error.InvalidApplicationOperators, .code = "application.invalid_operators", .category = .binding, .message = "Configure one through sixteen distinct nonzero native operator principals without gaps. No host operation can run until this configuration is valid." },
    .{ .cause = error.MessageTooLarge, .code = "application.command_too_large", .category = .limit, .message = "The encoded application command exceeds the native message boundary. Keep the original proposal and use its bounded upload continuation; do not split or change an already signed command." },
    .{ .cause = error.ApplicationPartTooLarge, .code = "application.record_part_too_large", .category = .integrity, .message = "An application record part exceeds its 128-byte record boundary. Preserve the exact record and proposal for inspection; this failure does not establish publication or abandonment." },
    .{ .cause = error.InvalidAuthorityResponse, .code = "application.invalid_authority_response", .category = .integrity, .message = "The authority returned an invalid response. Preserve the original request and operation; no publication outcome can be inferred from this failed response." },
    .{ .cause = error.InvalidResourceRead, .code = "application.invalid_resource_read", .category = .integrity, .message = "The resource read did not provide valid evidence for this application acquisition. Preserve the selected scope and retry only its inspection after the reader is repaired." },
    .{ .cause = error.EndOfStream, .code = "application.read_truncated", .category = .unavailable, .message = "A read ended before the required evidence was available. Its transport or record-decoder origin was not retained. Preserve the selected operation and inspect it; no publication outcome is established." },
    .{ .cause = error.UnsafePrincipal, .code = "application.unsafe_reader", .category = .access, .message = "The configured inspection principal has permissions outside its read-only profile. Configure the published-interface reader separately from the publication operator." },
    .{ .cause = error.ApplicationOperatorDenied, .code = "application.operator_denied", .category = .access, .message = "This principal is not admitted by the application's host configuration. No command was sent. Check the configured operator scope." },
    .{ .cause = error.ApplicationOperationDenied, .code = "application.input_disposition", .category = .access, .message = "The supplied observation contains an input disposition. Read the exact input and publication operation under current rights before selecting another upload step." },
    .{ .cause = error.ApplicationScopeChanged, .code = "application.scope_changed", .category = .conflict, .message = "The prepared or observed application scope does not match this host. Preserve the original signed work and inspect its original realm, application, owner and resource." },
    .{ .cause = error.ApplicationDigestMismatch, .code = "application.digest_mismatch", .category = .integrity, .message = "The prepared digest does not match the exact command or read selection. Retain the original signed artifact; changing a signature or sequence cannot reconcile earlier work." },
    .{ .cause = error.ApplicationOperationConflict, .code = "application.operation_conflict", .category = .conflict, .message = "The supplied publication receipt conflicts with the reviewed proposal, or the operation is closed. Read its exact receipt before reviewing a successor." },
    .{ .cause = error.ApplicationAlreadyApplied, .code = "application.already_applied", .category = .lifecycle, .message = "The supplied receipt says this publication already applied. Cleanup cannot roll back an active definition. Read the original receipt and current head separately." },
    .{ .cause = error.ApplicationOperationNotFound, .code = "application.operation_not_found", .category = .lifecycle, .message = "The supplied state contains no receipt for the selected publication operation. Re-read that exact operation before selecting cleanup." },
    .{ .cause = error.ApplicationUploadUnavailable, .code = "application.upload_unavailable", .category = .integrity, .message = "The supplied upload progress is absent or inconsistent with the reviewed proposal. Re-read its exact operation and record; do not infer that the upload was abandoned." },
    .{ .cause = error.ApplicationNotInitialized, .code = "application.not_initialized", .category = .lifecycle, .message = "The authorized resource read contains no application configuration. Inspect the configured owner and resource; this observation does not resolve an earlier submission." },
    .{ .cause = error.ApplicationPublicationChanged, .code = "application.publication_changed", .category = .conflict, .message = "The publication head or record changed during this acquisition. Retry the complete read under current rights; no partial definition is usable." },
    .{ .cause = error.ApplicationNotPublished, .code = "application.not_published", .category = .lifecycle, .message = "This authorized observation has no active published interface. Staging and native admission do not establish publication." },
    .{ .cause = error.InvalidApplicationProgram, .code = "application.program_mismatch", .category = .binding, .message = "The canonical program does not match the reviewed proposal's realm, name, revision or content commitment. Compile the complete definition and compare its exact reviewed proposal." },
    .{ .cause = error.InvalidApplicationSelection, .code = "application.invalid_selection", .category = .binding, .message = "A selected publication record requires its operation identity and must match that operation's receipt. Input positions must fit a native counter." },
    .{ .cause = error.InvalidApplicationScope, .code = "application.invalid_scope", .category = .binding, .message = "Realm, application, owner and resource must be nonzero native counters; the publication namespace must be a nonzero uint64 identity." },
    .{ .cause = error.InvalidApplicationOperation, .code = "application.invalid_operation", .category = .binding, .message = "A publication control requires a nonzero uint64 operation identity." },
    .{ .cause = error.InvalidApplicationProposal, .code = "application.invalid_proposal", .category = .binding, .message = "The proposal needs nonzero operation and record identities, next revision equal to base plus one, and a supported bounded publication specification." },
    .{ .cause = error.InvalidApplicationPart, .code = "application.invalid_part", .category = .binding, .message = "An upload part needs its nonzero operation, an ordinal below 256, and 1 through 128 bytes. Use the exact continuation returned for the reviewed upload." },
    .{ .cause = error.InvalidApplicationPolicy, .code = "application.invalid_policy", .category = .binding, .message = "A publication policy needs a nonzero principal and a revision exactly one greater than the expected revision." },
    .{ .cause = error.Overflow, .code = "application.revision_exhausted", .category = .limit, .message = "The expected uint64 revision has no representable successor. Keep the original identities and inspect the owner; wrapping or resetting the revision is not supported." },
    .{ .cause = error.InvalidSequence, .code = "application.invalid_sequence", .category = .binding, .message = "The native sequence must be a nonzero safe counter. Reconcile any saved signed command before preparing the next sequence." },
    .{ .cause = error.AccessDenied, .code = "application.read_denied", .category = .access, .message = "Current native access denied this read. Previously accepted publication work keeps its original outcome; retain its exact signed command and operation." },
    .{ .cause = error.Rejected, .code = "application.authority_rejected", .category = .conflict, .message = "The authority rejected this attempt. Inspect its native cause and retain any earlier signed work; this is not a terminal publication receipt." },
    .{ .cause = error.Conflict, .code = "application.authority_rejected", .category = .conflict, .message = "The authority rejected this attempt. Inspect its native cause and retain any earlier signed work; this is not a terminal publication receipt." },
    .{ .cause = error.MissingPublicationChunk, .code = "application.record_unavailable", .category = .integrity, .message = "The authorized publication read is missing required evidence or has an invalid record. No complete definition can be returned; preserve its identities for operator inspection." },
    .{ .cause = error.InvalidApplicationRecord, .code = "application.record_unavailable", .category = .integrity, .message = "The authorized publication read is missing required evidence or has an invalid record. No complete definition can be returned; preserve its identities for operator inspection." },
    .{ .cause = error.InvalidPublicationDescriptor, .code = "application.record_unavailable", .category = .integrity, .message = "The authorized publication read is missing required evidence or has an invalid record. No complete definition can be returned; preserve its identities for operator inspection." },
    .{ .cause = error.AuthorityTimeout, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.ConnectionRefused, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.ConnectionResetByPeer, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.NetworkUnreachable, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.UpstreamUnavailable, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.OutOfMemory, .code = "application.unavailable", .category = .unavailable, .message = "The application attempt could not complete. Preserve previously saved work and observed receipts; this failure does not settle that work." },
    .{ .cause = error.AuthorityUnavailable, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.ConnectionTimedOut, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.HostUnreachable, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.HttpConnectionClosing, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.NameServerFailure, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.ReadFailed, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
    .{ .cause = error.WriteFailed, .code = "application.unavailable", .category = .unavailable, .message = "The authority transport could not complete this attempt. Preserve the original command and operation; retrying a read does not authorize a new publication command." },
};
fn classification(cause: anyerror) Class {
    for (entries) |entry| if (entry.cause == cause) return .{ .code = entry.code, .category = entry.category, .message = entry.message };
    return .{ .code = "application.host_internal_failure", .category = .internal, .message = "The host could not complete this application attempt. Preserve its cause and any saved signed work for inspection." };
}

pub fn attempt(config: app.Host.Config, request: app.Host.Request, cause: anyerror, dispatched: bool, native_cause: ?p.ErrorCode) !d {
    const read = request == .read or request == .prepare_read or request == .info;
    const stage: d.Stage = if (read) .read else if (dispatched) .submit else if (request == .compile or request == .format) .compile else .prepare;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    const info = classification(cause);
    var result = if (dispatched)
        if (rejected)
            try d.init("application.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. Native rejection does not establish a terminal publication outcome. Retain the exact operation and inspect its current receipt.")
        else
            try d.init("application.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command's admission is unknown. Retain its exact bytes and signature; retry only that saved command and inspect its publication receipt before preparing new work.")
    else
        try d.init(info.code, info.category, stage, if (read) .not_applicable else .not_submitted, if (read) .none else .local_before_dispatch, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    try result.text(.operation, .caller, @tagName(request));
    if (!dispatched and cause == error.EndOfStream) try result.absent(.source_kind, .owner, .unrecorded);
    if (native_cause) |value| try result.text(.native_cause, .authority, @tagName(value));
    config.scope.validate() catch {
        try result.action(.contact_operator);
        return result;
    };
    result.identity = .{ .domain = .application, .id = .init(config.scope.application), .realm = .init(config.scope.realm), .resource = .init(config.scope.resource) };
    const command: ?app.Request.Command = switch (request) {
        .prepare => |value| value.command,
        .submit => |value| value.prepared.command,
        else => null,
    };
    if (command) |value| {
        try result.text(.argument, .caller, @tagName(value));
        switch (value) {
            .begin => |proposal| try proposalFacts(&result, proposal),
            .part => |part| {
                try result.fact(.proposal, .caller, .{ .unsigned = .init(part.operation.value) });
                try result.fact(.step, .caller, .{ .unsigned = .init(part.ordinal) });
                try result.fact(.actual_count, .caller, .{ .unsigned = .init(part.bytes.len) });
            },
            .publish, .abandon, .collect => |operation| try result.fact(.proposal, .caller, .{ .unsigned = .init(operation.value) }),
            .policy => |policy| {
                try result.fact(.expected_revision, .caller, .{ .unsigned = .init(policy.expected.value) });
                try result.fact(.actual_revision, .caller, .{ .unsigned = .init(policy.next.revision.value) });
            },
            .initialize => {},
        }
    }
    switch (request) {
        .next_upload => |value| {
            try proposalFacts(&result, value.proposal);
            if (value.state.head) |head| try result.fact(.actual_revision, .caller, .{ .unsigned = .init(head.revision.value) });
        },
        .next_cleanup => |value| try proposalFacts(&result, value.proposal),
        else => {},
    }
    if (request == .submit and dispatched) {
        const prepared = request.submit.prepared;
        result.identity = .{ .domain = .transport, .id = .init(prepared.sequence.value), .realm = .init(config.scope.realm), .resource = .init(config.scope.resource), .sequence = .init(prepared.sequence.value) };
        try result.fact(.source_basis, .caller, .{ .digest = prepared.digest });
    }
    try result.action(.inspect_status);
    if (dispatched) try result.action(if (rejected) .inspect_scope else .resume_exact) else switch (result.category) {
        .access => try result.action(.inspect_scope),
        .internal, .integrity => try result.action(.contact_operator),
        .binding, .syntax, .unsupported => if (!read) try result.action(.correct_input),
        .unavailable, .conflict => if (read) try result.action(.retry_read),
        else => {},
    }
    try result.validate();
    return result;
}

fn proposalFacts(result: *d, proposal: app.Publication.Proposal) !void {
    try result.fact(.proposal, .caller, .{ .unsigned = .init(proposal.operation.value) });
    try result.fact(.object, .caller, .{ .unsigned = .init(proposal.record.value) });
    try result.fact(.expected_revision, .caller, .{ .unsigned = .init(proposal.expected.value) });
    try result.fact(.expected_schema, .caller, .{ .digest = proposal.expected_digest });
    try result.fact(.required, .caller, .{ .unsigned = .init(proposal.revision.value) });
}

pub fn input(cause: anyerror) !d {
    if (cause == error.OutOfMemory) {
        var result = try d.init("application.memory_unavailable", .unavailable, .input, .not_submitted, .local_before_dispatch, "The host could not allocate memory to decode this request. No command was sent.");
        result.cause = try d.Code.init(@errorName(cause));
        try result.action(.contact_operator);
        return result;
    }
    var result = try d.init("application.invalid_request", .syntax, .input, .not_submitted, .local_before_dispatch, "The request does not match the application host contract. Check its required fields, variants, value types and byte bounds. No command was sent.");
    result.cause = try d.Code.init(@errorName(cause));
    try result.action(.correct_input);
    return result;
}

pub fn acquisition(scope: app.Native.Scope, cause: anyerror, native_cause: ?p.ErrorCode) !d {
    var result = try attempt(.{ .scope = scope }, .info, cause, false, native_cause);
    result.facts[0] = .{ .field = .operation, .origin = .caller, .availability = .provided, .value = .{ .text = try d.Text.init("read published interface") } };
    try result.fact(.completion, .execution, .{ .boolean = false });
    try result.validate();
    return result;
}
