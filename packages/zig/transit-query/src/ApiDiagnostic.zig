//! Caller failures project the failed attempt, never an inferred domain result.
const std = @import("std");
const q = @import("root.zig");
const d = q.protocol.Diagnostic;

/// Classification cannot depend on allocating or retaining optional detail.
pub fn category(action: q.Bridge.Action, cause: anyerror) d.Category {
    if (action == .compile or action == .inspect) if (q.fuze.SqlDiagnostic.category(cause)) |value| return value;
    if (q.QueryFailure.fromError(cause, .admission)) |failure| return failure.category();
    return switch (cause) {
        error.QueryReadConflict, error.Conflict, error.Rejected => .conflict,
        error.InvalidQueryRequest, error.QueryIdentityMismatch, error.InvalidQueryCursor => .binding,
        error.IncompleteResult => .lifecycle,
        error.OutOfMemory => .unavailable,
        else => .internal,
    };
}

pub fn project(action: q.Bridge.Action, cause: anyerror, binding: q.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (action == .compile or action == .inspect) {
        const source = if (action == .compile) action.compile.sql else action.inspect.sql;
        if (q.fuze.SqlDiagnostic.bound(source, cause, true, binding)) |sql| return sql.structured();
    }
    const sending = action == .submit and dispatched;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .prepare, .next => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    var result = if (sending and !rejected)
        try d.init("query.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command's outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("query.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the saved query's outcome; inspect its status.")
    else if (q.QueryFailure.fromError(cause, .admission)) |failure|
        try d.init(switch (failure.code) {
            inline else => |code| "query." ++ @tagName(code),
        }, failure.category(), stage, if (stage == .read) .not_applicable else .not_submitted, if (stage == .read) .none else .local_before_dispatch, failure.message())
    else switch (cause) {
        error.QueryReadConflict, error.Conflict => try d.init("query.read_conflict", .conflict, stage, .not_applicable, .none, "The source changed during this read. Retry the read without replacing any saved command."),
        error.InvalidQueryRequest, error.QueryIdentityMismatch => try d.init("query.invalid_command", .binding, stage, .not_submitted, .local_before_dispatch, "The saved command does not match this query connection or has an invalid encoding. No command was sent."),
        error.InvalidQueryCursor => try d.init("query.invalid_cursor", .binding, .read, .not_applicable, .none, "The result cursor is invalid. Use the cursor returned for this exact saved query."),
        error.IncompleteResult => try d.init("query.result_incomplete", .lifecycle, .read, .not_applicable, .none, "The saved query does not have a complete result. Inspect its current status."),
        error.OutOfMemory => try d.init("query.memory_unavailable", .unavailable, stage, .not_applicable, .none, "The caller could not allocate memory for this operation. Preserve any saved command and previously observed outcome."),
        else => try d.init("query.internal_failure", .internal, stage, .not_applicable, .none, "The query caller could not complete this operation. Preserve any saved command and inspect its status; this failure does not establish the query's outcome."),
    };
    result.cause = try d.Code.init(@errorName(cause));
    result.identity = identity;
    try result.text(.operation, .caller, @tagName(action));
    if (sending) {
        try result.action(.inspect_status);
        if (!rejected and identity != null) try result.action(.resume_exact);
        if (rejected) try result.action(.inspect_scope);
    } else switch (result.category) {
        .access => try result.action(.inspect_scope),
        .internal, .integrity => try result.action(.contact_operator),
        .unavailable, .conflict => if (stage == .read) {
            try result.action(.retry_read);
        } else {
            try result.action(.inspect_status);
        },
        .lifecycle => try result.action(.inspect_status),
        else => if (result.outcome == .not_submitted) {
            try result.action(.correct_input);
        },
    }
    try result.validate();
    return result;
}

test "caller diagnostics distinguish local rejection, unknown send and failed status inspection" {
    const t = std.testing;
    const identity: d.Identity = .{ .domain = .transport, .id = .init(42), .sequence = .init(42) };
    const local = try project(.{ .submit = "invalid" }, error.InvalidQueryRequest, .{}, false, null);
    try t.expectEqual(.not_submitted, local.outcome);
    const uncertain = try project(.{ .submit = "saved" }, error.ConnectionRefused, .{}, true, identity);
    try t.expectEqual(.unknown, uncertain.outcome);
    try t.expectEqual(.resume_exact, uncertain.actions[1].?.kind);
    const rejected = try project(.{ .submit = "saved" }, error.Rejected, .{}, true, identity);
    try t.expectEqual(.not_applicable, rejected.outcome);
    try t.expectEqual(.inspect_scope, rejected.actions[1].?.kind);
    const denied = try project(.{ .status = "9" }, error.AccessDenied, .{}, false, null);
    try t.expectEqual(.not_applicable, denied.outcome);
    try t.expectEqual(.read, denied.stage);
    const unexpected = try project(.{ .status = "9" }, error.UnexpectedFixtureFailure, .{}, false, null);
    try t.expectEqual(.internal, unexpected.category);
}
