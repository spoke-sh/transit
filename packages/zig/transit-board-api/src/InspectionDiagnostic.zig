//! Failed read attempts describe inspection evidence, never a write outcome.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.Diagnostic;
const Class = struct { code: []const u8, category: d.Category, message: []const u8, action: d.ActionKind };

fn classification(cause: anyerror, native: ?p.ErrorCode) Class {
    if (cause == error.AccessDenied or cause == error.QueryAccessDenied or cause == error.QueryDenied or native == .AccessDenied)
        return .{ .code = "inspection.denied", .category = .access, .message = "Current authority denied this inspection. Check Board's configured read grant and the selected resource. This failure says nothing about whether earlier work applied.", .action = .inspect_scope };
    if (cause == error.UnsafePrincipal)
        return .{ .code = "inspection.unsafe_principal", .category = .access, .message = "Board's upstream principal has permissions outside its read-only inspection profile. Configure a principal with only inspect permission; operator capabilities require their separate boundary.", .action = .contact_operator };
    if (cause == error.QueryChanged or cause == error.QueryReadConflict or native == .StaleStateResource or native == .QueryExpired)
        return .{ .code = "inspection.observation_changed", .category = .conflict, .message = "The source or observation cut changed while reading. Start a fresh observation; pages from the earlier and new cuts cannot be combined.", .action = .refresh };
    if (cause == error.DocumentHistoryGap or cause == error.DocumentResyncRequired or native == .HistoryReclaimed)
        return .{ .code = "inspection.history_reclaimed", .category = .lifecycle, .message = "Required history is no longer retained for this observation. Refresh from the retained boundary. A current checkpoint does not reconstruct missing historical events.", .action = .refresh };
    if (cause == error.QuerySourceUnavailable or cause == error.ExchangeUnavailable or cause == error.ResourceUnavailable or cause == error.DocumentRetired or native == .StateResourceExpired)
        return .{ .code = "inspection.resource_unavailable", .category = .lifecycle, .message = "The required source resource is unavailable or no longer active. Inspect its current lifecycle and retained evidence. This does not establish physical cleanup or change an earlier operation's outcome.", .action = .inspect_scope };
    if (cause == error.ExchangeNotFound or cause == error.DocumentNotFound or native == .UnknownStateResource or native == .UnknownProcess)
        return .{ .code = "inspection.object_not_found", .category = .lifecycle, .message = "The authorized lookup did not return the selected object. Check its exact identity and scope; absence from this lookup does not prove that it never existed.", .action = .inspect_scope };
    if (native == .InvalidRead)
        return .{ .code = "inspection.invalid_selector", .category = .binding, .message = "The authority rejected the read selector. Check the object identity, page cursor and original observation cut before reading again.", .action = .correct_input };
    return switch (cause) {
        error.HttpReplayGap, error.GrpcReplayGap => .{ .code = "inspection.replay_gap", .category = .integrity, .message = "A required captured exchange member is missing. The retained prefix cannot establish the complete remote result. Inspect the original exchange; this read failure does not authorize dispatching the external effect again.", .action = .contact_operator },
        error.InvalidExchangeCoverage => .{ .code = "inspection.coverage_mismatch", .category = .integrity, .message = "The recorded exchange coverage does not match its retained members. The capture cannot establish a complete result. Preserve the original exchange and investigate the mismatch before using replay evidence.", .action = .contact_operator },
        error.GrpcInspectionCapacity, error.HttpInspectionCapacity => .{ .code = "inspection.capture_limit", .category = .limit, .message = "The captured exchange exceeds the bounded metadata inspector's capacity. This read has no complete projection; it does not mean the external request failed or permit repeating it.", .action = .contact_operator },
        error.InvalidGrpcCapture, error.InvalidHttpCapture => .{ .code = "inspection.invalid_capture", .category = .integrity, .message = "A captured exchange member does not match its protocol's current format. Preserve the original exchange and check its stored definition and producer. The remote outcome cannot be inferred from this decoding failure.", .action = .contact_operator },
        error.WrongExchangeProtocol => .{ .code = "inspection.wrong_protocol", .category = .binding, .message = "The selected exchange uses a different protocol from this inspector. Select the inspector matching its recorded protocol; reading metadata must not dispatch another external request.", .action = .correct_input },
        error.IncompleteResult => .{ .code = "inspection.incomplete_result", .category = .integrity, .message = "The retained query evidence does not provide a complete result. Keep any emitted prefix separate from completed results and inspect the original query's status and coverage.", .action = .inspect_scope },
        error.InvalidDocumentCursor, error.InvalidQueryOrdinal => .{ .code = "inspection.invalid_cursor", .category = .binding, .message = "The selected continuation or ordinal is invalid for this observation. Use the cursor returned for this exact object and cut, or start a fresh observation.", .action = .refresh },
        error.QueryRequestTooLarge => .{ .code = "inspection.request_too_large", .category = .limit, .message = "The inspection request exceeds its supported bound. Use a bounded public page or supported selector; reducing a read does not authorize dropping accepted work.", .action = .correct_input },
        error.QueryBusy => .{ .code = "inspection.busy", .category = .conflict, .message = "The query owner is occupied. Inspect its current operation before requesting another query; retrying this inspection does not cancel that work.", .action = .retry_read },
        error.Conflict, error.Rejected => .{ .code = "inspection.authority_rejected", .category = .conflict, .message = "The authority rejected this inspection attempt. Check its native cause and the selected identity/cut. Preserve any saved operation; this read is not a domain outcome.", .action = .inspect_scope },
        error.AuthorityTimeout, error.AuthorityUnavailable, error.ConnectionRefused, error.ConnectionResetByPeer, error.NetworkUnreachable, error.EndOfStream => .{ .code = "inspection.authority_unavailable", .category = .unavailable, .message = "No complete authority observation was received. Retry the read when available; previously observed results remain separate and any earlier operation keeps its original outcome.", .action = .retry_read },
        error.InvalidAuthorityResponse, error.InvalidObservation => .{ .code = "inspection.invalid_authority_response", .category = .integrity, .message = "The authority response did not match the current contract or request. No candidate observation is usable. Inspect the peer definitions and preserved cause before retrying.", .action = .contact_operator },
        error.OutOfMemory => .{ .code = "inspection.memory_unavailable", .category = .unavailable, .message = "Board could not allocate memory to complete this bounded inspection. No complete observation was returned; existing accepted work is unaffected.", .action = .retry_read },
        else => .{ .code = "inspection.internal_failure", .category = .internal, .message = "Inspection failed before a complete observation could be returned. Preserve the original cause for operator inspection; this failure does not establish an empty result or change accepted work.", .action = .contact_operator },
    };
}

pub fn project(cause: anyerror, native: ?p.ErrorCode) !d {
    const info = classification(cause, native);
    var result = try d.init(info.code, info.category, .read, .not_applicable, .none, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    try result.text(.operation, .caller, "Board inspection");
    try result.fact(.completion, .execution, .{ .boolean = false });
    if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
    try result.action(info.action);
    try result.validate();
    return result;
}

test "inspection failure categories retain native cause without inventing outcomes" {
    const t = std.testing;
    const cases = .{
        .{ error.AccessDenied, @as(?p.ErrorCode, .AccessDenied), "inspection.denied", d.Category.access },
        .{ error.UnsafePrincipal, @as(?p.ErrorCode, null), "inspection.unsafe_principal", d.Category.access },
        .{ error.Conflict, @as(?p.ErrorCode, .QueryExpired), "inspection.observation_changed", d.Category.conflict },
        .{ error.Rejected, @as(?p.ErrorCode, .HistoryReclaimed), "inspection.history_reclaimed", d.Category.lifecycle },
        .{ error.Rejected, @as(?p.ErrorCode, .StateResourceExpired), "inspection.resource_unavailable", d.Category.lifecycle },
        .{ error.Rejected, @as(?p.ErrorCode, .UnknownProcess), "inspection.object_not_found", d.Category.lifecycle },
        .{ error.GrpcReplayGap, @as(?p.ErrorCode, null), "inspection.replay_gap", d.Category.integrity },
        .{ error.InvalidExchangeCoverage, @as(?p.ErrorCode, null), "inspection.coverage_mismatch", d.Category.integrity },
        .{ error.HttpInspectionCapacity, @as(?p.ErrorCode, null), "inspection.capture_limit", d.Category.limit },
        .{ error.InvalidHttpCapture, @as(?p.ErrorCode, null), "inspection.invalid_capture", d.Category.integrity },
        .{ error.WrongExchangeProtocol, @as(?p.ErrorCode, null), "inspection.wrong_protocol", d.Category.binding },
        .{ error.Rejected, @as(?p.ErrorCode, .InvalidRead), "inspection.invalid_selector", d.Category.binding },
        .{ error.InvalidDocumentCursor, @as(?p.ErrorCode, null), "inspection.invalid_cursor", d.Category.binding },
        .{ error.AuthorityTimeout, @as(?p.ErrorCode, null), "inspection.authority_unavailable", d.Category.unavailable },
        .{ error.InvalidAuthorityResponse, @as(?p.ErrorCode, null), "inspection.invalid_authority_response", d.Category.integrity },
        .{ error.UnexpectedInspectionFailure, @as(?p.ErrorCode, null), "inspection.internal_failure", d.Category.internal },
    };
    inline for (cases) |case| {
        const result = try project(case[0], case[1]);
        try t.expectEqualStrings(case[2], result.code.slice());
        try t.expectEqual(case[3], result.category);
        try t.expectEqual(.not_applicable, result.outcome);
        try t.expectEqual(.none, result.evidence);
        try t.expectEqual(@as(?d.Identity, null), result.identity);
        try t.expect(!result.facts[1].?.value.?.boolean);
        for (result.actions) |slot| if (slot) |action| {
            try t.expect(action.kind != .resume_exact and action.kind != .cancel_mutation and action.kind != .reconcile_effect);
        };
    }
}
