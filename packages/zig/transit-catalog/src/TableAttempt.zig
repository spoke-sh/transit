//! Failed caller attempts never overwrite the retained Table operation outcome.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.Diagnostic;
const b = c.TableBridge;
pub const codes = @import("CallerCodes.zig");

fn info(cause: anyerror) codes.Entry {
    if (codes.fromError(cause)) |value| return value;
    if (c.fuze.SqlDiagnostic.category(cause)) |category_value| return .{ .cause = cause, .code = "table.invalid_typed_input", .category = category_value, .message = "The typed Table request violates its schema or operation limits. Check stable column identities, logical types, constraints and bounded mutation inputs." };
    return .{ .cause = cause, .code = "catalog.internal_failure", .category = .internal, .message = "The caller could not complete this operation. Preserve saved work and inspect its original status; this failure does not establish its outcome." };
}
fn detailFor(action: b.Action, cause: anyerror) codes.Entry {
    if (action == .definition and cause == error.CatalogDefinitionChanged) return .{ .cause = cause, .code = "catalog.invalid_record", .category = .integrity, .message = "The retained definition does not match its exact object, revision or original acceptance evidence. Preserve those identities for operator inspection; a current schema change cannot explain inconsistent immutable history." };
    return info(cause);
}
pub fn category(action: b.Action, cause: anyerror) d.Category {
    if (action == .compile) if (c.fuze.SqlDiagnostic.category(cause)) |value| return value;
    return detailFor(action, cause).category;
}
fn selected(session: *b.Session, connection: c.TableClient.Connection, action: b.Action) ?d.Identity {
    const reference = switch (action) {
        .next, .status, .prepare_resume, .forget => |value| value,
        inline .prepare_control, .progress, .wait_progress => |value| value.intent,
        .observe, .wait_observe, .input_disposition => |value| {
            if (value.input == 0 or value.input > c.protocol.max_counter) return null;
            return .{ .domain = .transport, .id = .init(value.input), .realm = .init(connection.scope.realm), .resource = .init(connection.scope.resource) };
        },
        else => return null,
    };
    const intent = session.get(reference, connection) catch return null;
    return .{ .domain = if (intent.identity == .ddl) .catalog else .mutation, .id = .init(intent.header.operation), .realm = .init(intent.header.scope.realm), .resource = .init(intent.header.scope.resource) };
}
pub fn attempt(session: *b.Session, connection: c.TableClient.Connection, action: b.Action, cause: anyerror, location: c.fuze.Sql.Location, dispatched: bool, identity: ?d.Identity, native: ?c.protocol.ErrorCode) !d {
    if (action == .compile) {
        const text = action.compile.sql;
        var lexer: c.fuze.Sql.Lexer = .{ .text = text };
        const first = lexer.next() catch null;
        const ddl = if (first) |token| std.ascii.eqlIgnoreCase(token.text, "CREATE") or std.ascii.eqlIgnoreCase(token.text, "ALTER") or std.ascii.eqlIgnoreCase(token.text, "DROP") else false;
        const diagnostic = if (ddl) c.fuze.SqlDiagnostic.tableDdl(text, cause, location) else c.fuze.SqlDiagnostic.tableDml(text, cause, location);
        if (diagnostic) |value| return value.structured();
    }
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .prepare, .load, .forget, .next, .prepare_resume, .prepare_control, .prepare_initialize, .prepare_dependency => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    const detail = detailFor(action, cause);
    const sending = dispatched and action == .submit;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    var result = if (sending and !rejected)
        try d.init("catalog.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("catalog.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the original Table operation outcome; inspect its saved status.")
    else
        try d.init(detail.code, detail.category, stage, if (stage == .read) .not_applicable else .not_submitted, if (stage == .read) .none else .local_before_dispatch, detail.message);
    result.cause = try d.Code.init(@errorName(cause));
    result.identity = identity orelse selected(session, connection, action);
    try result.text(.operation, .caller, @tagName(action));
    if (native) |value| try result.text(.native_cause, .authority, @tagName(value));
    if (sending) {
        try result.action(.inspect_status);
        if (!rejected and identity != null) try result.action(.resume_exact);
        if (rejected) try result.action(.inspect_scope);
    } else switch (detail.category) {
        .access, .conflict => try result.action(.inspect_scope),
        .lifecycle => try result.action(.inspect_status),
        .unavailable => try result.action(if (stage == .read) .retry_read else .inspect_status),
        .binding, .syntax, .unsupported, .limit, .constraint => try result.action(.correct_input),
        .internal, .integrity => try result.action(.contact_operator),
    }
    try result.validate();
    return result;
}

test "general caller failures retain read and dispatch evidence" {
    const t = std.testing;
    var session: b.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    const connection: c.TableClient.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 2 }, .owner = 3, .principal = 17 };
    for (codes.entries) |entry| {
        const read = try attempt(&session, connection, .{ .lookup = "people" }, entry.cause, .{}, false, null, null);
        try t.expectEqualStrings(entry.code, read.code.slice());
        try t.expectEqual(entry.category, read.category);
        try t.expectEqual(.not_applicable, read.outcome);
        try t.expectEqual(.none, read.evidence);
        try t.expect(read.identity == null);
        const sent = try attempt(&session, connection, .{ .submit = "original" }, entry.cause, .{}, true, .{ .domain = .transport, .id = .init(12), .sequence = .init(12) }, null);
        const rejected = entry.cause == error.AccessDenied or entry.cause == error.Conflict or entry.cause == error.Rejected;
        try t.expectEqual(if (rejected) d.Outcome.not_applicable else .unknown, sent.outcome);
        try t.expectEqual(if (rejected) d.ActionKind.inspect_scope else .resume_exact, sent.actions[1].?.kind);
    }
}

test "exact historical inconsistencies require integrity inspection without new declaration advice" {
    const t = std.testing;
    var session: b.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    const connection: c.TableClient.Connection = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 2 }, .owner = 3, .principal = 17 };
    const action: b.Action = .{ .definition = .{ .object = "10", .revision = "1" } };
    try t.expectEqual(.integrity, category(action, error.CatalogDefinitionChanged));
    const result = try attempt(&session, connection, action, error.CatalogDefinitionChanged, .{}, false, null, null);
    try t.expectEqualStrings("catalog.invalid_record", result.code.slice());
    try t.expectEqual(.not_applicable, result.outcome);
    try t.expectEqual(.none, result.evidence);
    try t.expectEqual(.contact_operator, result.actions[0].?.kind);
}

pub fn invalidEnvelope(cause: anyerror) !d {
    var result = if (cause == error.OutOfMemory)
        try d.init("catalog.memory_unavailable", .unavailable, .input, .not_submitted, .local_before_dispatch, "The caller could not allocate memory to read this request. No command was sent.")
    else
        try d.init("catalog.invalid_envelope", .syntax, .input, .not_submitted, .local_before_dispatch, "The action is not a valid bounded request object. No command was sent.");
    result.cause = try d.Code.init(@errorName(cause));
    return result;
}

/// Validation of a local artifact precedes credential loading and dispatch.
/// The operation name comes from the invoked command, never a dummy send.
pub fn artifact(operation: []const u8, cause: anyerror) !d {
    const detail = info(cause);
    var value = try d.init(detail.code, detail.category, .input, .not_submitted, .local_before_dispatch, detail.message);
    value.cause = try d.Code.init(@errorName(cause));
    try value.text(.operation, .caller, operation);
    try value.action(switch (detail.category) {
        .internal, .integrity => .contact_operator,
        .conflict, .lifecycle, .unavailable => .inspect_status,
        .access => .inspect_scope,
        else => .correct_input,
    });
    try value.validate();
    return value;
}
