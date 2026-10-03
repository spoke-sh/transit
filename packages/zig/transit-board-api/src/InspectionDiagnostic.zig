//! Failed read attempts describe inspection evidence, never a write outcome.
const std = @import("std");
const p = @import("transit_protocol");
const q = @import("transit_query");
const d = p.Diagnostic;
pub const codes = @import("InspectionCodes.zig");
const Class = codes.Class;

fn classification(cause: anyerror, native: ?p.ErrorCode) Class {
    if (cause == error.AccessDenied or cause == error.QueryAccessDenied or cause == error.QueryDenied or native == .AccessDenied)
        return codes.fromError(error.AccessDenied).?;
    if (cause == error.UnsafePrincipal)
        return codes.fromError(error.UnsafePrincipal).?;
    if (cause == error.QueryChanged or cause == error.QueryReadConflict or native == .StaleStateResource or native == .QueryExpired)
        return codes.fromError(error.QueryChanged).?;
    if (cause == error.DocumentHistoryGap or cause == error.DocumentResyncRequired or native == .HistoryReclaimed)
        return codes.fromError(error.DocumentHistoryGap).?;
    if (cause == error.QuerySourceUnavailable or cause == error.ExchangeUnavailable or cause == error.ResourceUnavailable or cause == error.DocumentRetired or native == .StateResourceExpired)
        return codes.fromError(error.QuerySourceUnavailable).?;
    if (cause == error.ExchangeNotFound or cause == error.DocumentNotFound or native == .UnknownStateResource or native == .UnknownProcess)
        return codes.fromError(error.ExchangeNotFound).?;
    if (native == .InvalidRead)
        return .{ .code = "inspection.invalid_selector", .category = .binding, .message = "The authority rejected the read selector. Check the object identity, page cursor and original observation cut before reading again.", .action = .correct_input };
    return codes.fromError(cause) orelse .{ .code = "inspection.internal_failure", .category = .internal, .message = "Inspection failed before a complete observation could be returned. Preserve the original cause for operator inspection; this failure does not establish an empty result or change accepted work.", .action = .contact_operator };
}

pub fn project(cause: anyerror, native: ?p.ErrorCode) !d {
    const info = classification(cause, native);
    if (info.category == .internal and q.ApiDiagnostic.category(.capabilities, cause) != .internal) {
        var result = try q.ApiDiagnostic.attempt("Board inspection", .read, null, cause, .{}, false, null);
        try result.fact(.completion, .execution, .{ .boolean = false });
        if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
        try result.validate();
        return result;
    }
    var result = try d.init(info.code, info.category, .read, .not_applicable, .none, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    try result.text(.operation, .caller, "Board inspection");
    try result.fact(.completion, .execution, .{ .boolean = false });
    if (cause == error.EndOfStream and native == null) try result.absent(.source_kind, .owner, .unrecorded);
    if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
    try result.action(info.action);
    try result.validate();
    return result;
}

test "every inspection cause preserves read evidence and native denial priority" {
    const t = std.testing;
    for (codes.entries) |entry| {
        const detail = try project(entry.cause, null);
        try t.expectEqualStrings(entry.code, detail.code.slice());
        try t.expectEqual(entry.category, detail.category);
        try t.expectEqual(.not_applicable, detail.outcome);
        try t.expectEqual(.none, detail.evidence);
        try t.expect(detail.identity == null);
        try t.expectEqual(entry.action, detail.actions[0].?.kind);
        const denied = try project(entry.cause, .AccessDenied);
        try t.expectEqualStrings("inspection.denied", denied.code.slice());
        try t.expectEqualStrings("AccessDenied", denied.facts[2].?.value.?.text.slice());
        try t.expect(denied.facts[3] == null);
    }
    for (q.ApiDiagnostic.entries) |entry| {
        if (codes.fromError(entry.cause) != null) continue;
        const detail = try project(entry.cause, null);
        try t.expectEqualStrings(entry.code, detail.code.slice());
        try t.expectEqual(.not_applicable, detail.outcome);
        try t.expect(detail.identity == null);
        for (detail.actions) |slot| if (slot) |action| try t.expect(action.kind != .resume_exact and action.kind != .cancel_mutation);
    }
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
