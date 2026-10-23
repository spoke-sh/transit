//! Caller failures project the failed attempt, never an inferred domain result.
const std = @import("std");
const q = @import("root.zig");
const d = q.protocol.Diagnostic;
const codes = @import("ApiCodes.zig");
pub const entries = codes.entries;

/// Classification cannot depend on allocating or retaining optional detail.
pub fn category(action: q.Bridge.Action, cause: anyerror) d.Category {
    if (action == .compile or action == .inspect or action == .relational) if (q.fuze.SqlDiagnostic.category(cause)) |value| return value;
    if (codes.fromError(cause)) |entry| return entry.category;
    if (q.wire.Client.unavailable(cause)) return .unavailable;
    if (q.QueryFailure.fromError(cause, .admission)) |failure| return failure.category();
    return .internal;
}

pub fn project(action: q.Bridge.Action, cause: anyerror, binding: q.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (action == .relational) {
        const operation = action.relational;
        return attempt(@tagName(operation), if (operation == .explain or operation == .open) .compile else .read, switch (operation) {
            .explain => |input| input.sql,
            .open => |input| input.statement.sql,
            else => null,
        }, cause, binding, false, null);
    }
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .authorize, .cleanup, .prepare, .next => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    return attempt(@tagName(action), stage, switch (action) {
        .compile => |input| input.sql,
        .inspect => |input| input.sql,
        else => null,
    }, cause, binding, dispatched, identity orelse switch (action) {
        .status => |value| namespace(value),
        .next => |value| namespace(value.namespace),
        .cleanup => |value| namespace(value.namespace),
        .page => |value| namespace(value.namespace),
        else => null,
    });
}

/// A caller-selected namespace is context, never authority or proof of existence.
pub fn namespace(text: []const u8) ?d.Identity {
    const id = q.Values.unsigned(text) catch return null;
    if (id == 0) return null;
    return .{ .domain = .query, .id = .init(id) };
}

/// Bind caller-selected query context to this connection, including every
/// inspection target. This supplies no authority or claim that the query exists.
pub fn qualify(out: *?d, connection: q.UnifiedClient.Connection) void {
    if (out.*) |*detail| if (detail.identity) |*identity| {
        if (identity.domain != .query) return;
        identity.realm = .init(connection.realm);
        identity.resource = .init(connection.requests);
        for (&detail.actions) |*slot| if (slot.*) |*action| {
            action.target = identity.*;
        };
    };
}

/// The caller supplies the original compiler witness and the actual dispatch
/// boundary. A failed inspection never implies a saved domain outcome.
pub fn attempt(operation: []const u8, stage: d.Stage, source: ?[]const u8, cause: anyerror, binding: q.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (source) |sql| if (q.fuze.SqlDiagnostic.bound(sql, cause, true, binding)) |detail| return detail.structured();
    const sending = stage == .submit and dispatched;
    const local_input = stage != .read and (cause == error.InvalidQueryRequest or cause == error.InvalidPredicateProgram or cause == error.InvalidFrame or cause == error.QueryCaptureRequired or cause == error.QueryTableSnapshotRequired);
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    var result = if (sending and !rejected)
        try d.init("query.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command's outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("query.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the saved query's outcome; inspect its status.")
    else if (codes.fromError(cause)) |entry|
        try d.init(entry.code, entry.category, if (cause == error.InvalidSqlCursor or cause == error.InvalidQueryCursor) .read else stage, if (local_input) .not_submitted else .not_applicable, if (local_input) .local_before_dispatch else .none, entry.message)
    else if (q.wire.Client.unavailable(cause))
        try d.init("query.transport_unavailable", .unavailable, stage, .not_applicable, .none, "The authority transport could not complete this attempt. Preserve the exact saved query and any observed receipts. Retry only the applicable read; a failed read never authorizes resubmitting SQL.")
    else if (q.QueryFailure.fromError(cause, .admission)) |failure|
        try d.init(switch (failure.code) {
            inline else => |code| "query." ++ @tagName(code),
        }, failure.category(), stage, if (stage == .read) .not_applicable else .not_submitted, if (stage == .read) .none else .local_before_dispatch, failure.message())
    else
        try d.init("query.internal_failure", .internal, stage, .not_applicable, .none, "The query caller could not complete this operation. Preserve any saved command and inspect its status; this failure does not establish the query's outcome.");
    result.cause = try d.Code.init(@errorName(cause));
    result.identity = identity;
    try result.text(.operation, .caller, operation);
    if (!sending and cause == error.EndOfStream) try result.absent(.source_kind, .owner, .unrecorded);
    if (sending) {
        try result.action(.inspect_status);
        if (!rejected and identity != null) try result.action(.resume_exact);
        if (rejected) try result.action(.inspect_scope);
    } else if (codes.fromError(cause)) |entry| {
        try result.action(entry.action);
    } else switch (result.category) {
        .access => try result.action(.inspect_scope),
        .internal, .integrity => try result.action(.contact_operator),
        .unavailable, .conflict => if (stage == .read) {
            try result.action(.retry_read);
        } else {
            try result.action(.inspect_status);
        },
        .lifecycle => try result.action(.inspect_status),
        else => try result.action(if (result.outcome == .not_submitted) .correct_input else .inspect_status),
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

test "editor and typed predicate failures keep their own meaning without overriding uncertain submission" {
    const t = std.testing;
    const cursor = try attempt("assist", .read, null, error.InvalidSqlCursor, .{}, false, null);
    try t.expectEqualStrings("query.invalid_sql_cursor", cursor.code.slice());
    try t.expectEqual(.not_applicable, cursor.outcome);
    const predicate = try attempt("prepare", .prepare, null, error.InvalidPredicateProgram, .{}, false, null);
    try t.expectEqualStrings("query.invalid_predicate_program", predicate.code.slice());
    try t.expectEqual(.not_submitted, predicate.outcome);
    try t.expectEqual(.integrity, predicate.category);
    const uncertain = try attempt("submit", .submit, null, error.InvalidPredicateProgram, .{}, true, .{ .domain = .transport, .id = .init(42), .sequence = .init(42) });
    try t.expectEqualStrings("query.send_unknown", uncertain.code.slice());
    try t.expectEqual(.unknown, uncertain.outcome);
    try t.expectEqual(.resume_exact, uncertain.actions[1].?.kind);
}

test "every caller code preserves read identity and cannot override an uncertain send" {
    const t = std.testing;
    const target: d.Identity = .{ .domain = .transport, .id = .init(42), .sequence = .init(42) };
    for (codes.entries) |entry| {
        const read = try project(.{ .status = "18446744073709551615" }, entry.cause, .{}, false, null);
        try t.expectEqualStrings(entry.code, read.code.slice());
        try t.expectEqual(entry.category, read.category);
        try t.expectEqual(.not_applicable, read.outcome);
        try t.expectEqual(std.math.maxInt(u64), try read.identity.?.id.value());
        try t.expectEqual(entry.action, read.actions[0].?.kind);
        try t.expectEqualDeep(read.identity, read.actions[0].?.target);
        const sent = try project(.{ .submit = "saved" }, entry.cause, .{}, true, target);
        const rejected = entry.cause == error.Conflict or entry.cause == error.Rejected;
        try t.expectEqualStrings(if (rejected) "query.command_rejected" else "query.send_unknown", sent.code.slice());
        try t.expectEqual(if (rejected) d.Outcome.not_applicable else .unknown, sent.outcome);
        try t.expectEqual(if (rejected) d.ActionKind.inspect_scope else .resume_exact, sent.actions[1].?.kind);
        try t.expectEqualDeep(target, sent.actions[1].?.target.?);
    }
    const unavailable = try project(.{ .status = "19" }, error.AuthorityTimeout, .{}, false, null);
    try t.expectEqualStrings("query.transport_unavailable", unavailable.code.slice());
    try t.expectEqual(.retry_read, unavailable.actions[0].?.kind);
    const truncated = try project(.{ .status = "19" }, error.EndOfStream, .{}, false, null);
    try t.expectEqualStrings("query.read_truncated", truncated.code.slice());
    try t.expectEqual(.unrecorded, truncated.facts[1].?.availability);
    try t.expectEqual(null, namespace("00"));
    try t.expectEqual(null, namespace("0"));
    try t.expectEqual(null, namespace("18446744073709551616"));
}

test "direct Table preparation failures do not settle a dispatched query" {
    const t = std.testing;
    const missing = try attempt("authorize", .prepare, null, error.QueryCaptureRequired, .{}, false, null);
    try t.expectEqualStrings("query.capture_required", missing.code.slice());
    try t.expectEqual(.binding, missing.category);
    try t.expectEqual(.not_submitted, missing.outcome);
    const retained = try attempt("read", .read, null, error.QueryTableSnapshotRequired, .{}, false, null);
    try t.expectEqualStrings("query.table_snapshot_required", retained.code.slice());
    try t.expectEqual(.not_applicable, retained.outcome);
    const unknown = try attempt("submit", .submit, null, error.QueryCaptureRequired, .{}, true, null);
    try t.expectEqualStrings("query.send_unknown", unknown.code.slice());
    try t.expectEqual(.unknown, unknown.outcome);
}
