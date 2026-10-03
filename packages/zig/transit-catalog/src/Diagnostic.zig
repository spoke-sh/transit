//! Authorized catalog evidence, independent of presentation or transport. A
//! historical receipt is never replaced by an observation of today's catalog.
const c = @import("root.zig");
const d = c.protocol.Diagnostic;
const m = c.Model;

pub fn receipt(value: m.Receipt) !d {
    try value.validate();
    var result = try d.init(switch (value.outcome) {
        .applied => "catalog.applied",
        .name_conflict => "catalog.name_conflict",
        .object_conflict => "catalog.object_conflict",
        .table_conflict => "catalog.table_conflict",
    }, if (value.outcome == .applied) .lifecycle else .constraint, .execute, if (value.outcome == .applied) .applied else .rejected, .domain_status, switch (value.outcome) {
        .applied => "This CREATE TABLE applied. Its receipt records the original declaration; inspect the current catalog separately if its present binding is needed.",
        .name_conflict => "The requested name was already bound in this catalog. This CREATE TABLE created no Table.",
        .object_conflict => "The requested object identity was already occupied in this catalog. This CREATE TABLE created no Table.",
        .table_conflict => "The requested Table identity was already occupied in the target resource. This CREATE TABLE created no Table.",
    });
    result.identity = .{ .domain = .catalog, .id = .init(value.request.operation), .realm = .init(value.request.scope.realm), .resource = .init(value.request.scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.scope, .owner, .{ .unsigned = .init(value.request.scope.catalog) });
    try result.fact(.object, .caller, .{ .unsigned = .init(value.request.object) });
    try result.fact(.table, .caller, .{ .unsigned = .init(value.request.table) });
    try result.text(.name, .caller, value.request.name.slice());
    try result.action(.inspect_status);
    if (value.outcome != .applied) {
        try result.action(.inspect_scope);
        try result.action(.correct_input);
    }
    try result.validate();
    return result;
}

pub fn input(value: m.Disposition) !d {
    try value.validate();
    const applied = value.outcome == .initialized or value.outcome == .policy_applied;
    const code = switch (value.outcome) {
        inline else => |outcome| "catalog.input." ++ @tagName(outcome),
    };
    var result = try d.init(code, switch (value.outcome) {
        .initialized, .policy_applied => .lifecycle,
        .invalid_command => .binding,
        .denied => .access,
        .identity_conflict, .stale_policy => .conflict,
    }, .admission, if (applied) .applied else .input_rejected, .domain_status, switch (value.outcome) {
        .initialized => "The catalog initialization command applied. This disposition does not describe a CREATE TABLE outcome.",
        .policy_applied => "The catalog policy command applied. Later commands still require current authorization.",
        .invalid_command => "The catalog could not decode this creation or control command. Inspect the recorded input and any original operation receipt.",
        .denied => "The current principal or catalog policy did not permit this command. Preserve its original operation identity and inspect current permissions.",
        .identity_conflict => "This command conflicts with the recorded catalog operation identity. Preserve the original command and inspect its receipt.",
        .stale_policy => "The catalog command's expected policy revision is stale. Inspect its recorded input and the current policy before preparing any new command.",
    });
    // A native input position is not a catalog operation ID. The disposition
    // intentionally does not invent a namespace or promise CREATE cancellation.
    result.identity = .{ .domain = .transport, .id = .init(value.input), .realm = .init(value.scope.realm), .resource = .init(value.scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.scope, .owner, .{ .unsigned = .init(value.scope.catalog) });
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    try result.text(.operation, .owner, "catalog input");
    try result.action(.inspect_status);
    if (value.outcome == .denied or value.outcome == .stale_policy) try result.action(.inspect_scope);
    try result.validate();
    return result;
}

// Caller attempt evidence is independent of a saved domain outcome.
pub const codes = @import("CallerCodes.zig");
fn attemptInfo(cause: anyerror) codes.Entry {
    return codes.fromError(cause) orelse .{ .cause = cause, .code = "catalog.internal_failure", .category = .internal, .message = "The caller could not complete this operation. Preserve saved work and inspect its original status; this failure does not establish its outcome." };
}
pub fn category(action: c.Bridge.Action, cause: anyerror) d.Category {
    if (action == .compile) if (c.fuze.SqlDiagnostic.category(cause)) |value| return value;
    return attemptInfo(cause).category;
}
/// CREATE status uses its original request scope and operation, never the
/// catalog ID or today's connection as a replacement operation identity.
fn selected(action: c.Bridge.Action) ?d.Identity {
    const value = switch (action) {
        inline .status, .prepare_create => |request| request.native() catch return null,
        inline .observe, .input_disposition => |request| {
            if (request.input == 0 or request.input > c.protocol.max_counter) return null;
            return .{ .domain = .transport, .id = .init(request.input) };
        },
        else => return null,
    };
    return .{ .domain = .catalog, .id = .init(value.operation), .realm = .init(value.scope.realm), .resource = .init(value.scope.resource) };
}

pub fn qualify(out: *?d, connection: c.Client.Connection, native: ?c.protocol.ErrorCode) void {
    if (out.*) |*detail| {
        if (detail.identity) |*identity| {
            if (identity.realm == null) identity.realm = .init(connection.scope.realm);
            for (&detail.actions) |*slot| if (slot.*) |*action| {
                action.target = identity.*;
            };
        }
        if (native) |cause| detail.text(.native_cause, .authority, @tagName(cause)) catch {};
    }
}
pub fn attempt(action: c.Bridge.Action, cause: anyerror, binding: c.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (action == .compile) if (c.fuze.SqlDiagnostic.writeCompiler(action.compile.sql, cause, .declaration, binding)) |detail| return detail.structured();
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .prepare_initialize, .prepare_create, .prepare_policy => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    const info = attemptInfo(cause);
    const sending = dispatched and action == .submit;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    var result = if (sending and !rejected)
        try d.init("catalog.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("catalog.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the original operation outcome; inspect its saved status.")
    else
        try d.init(info.code, info.category, stage, if (stage == .read) .not_applicable else .not_submitted, if (stage == .read) .none else .local_before_dispatch, info.message);
    result.cause = try d.Code.init(@errorName(cause));
    result.identity = identity orelse selected(action);
    if (!sending and cause == error.EndOfStream) try result.absent(.source_kind, .owner, .unrecorded);
    try result.text(.operation, .caller, @tagName(action));
    if (sending) {
        try result.action(.inspect_status);
        if (!rejected and identity != null) try result.action(.resume_exact);
        if (rejected) try result.action(.inspect_scope);
    } else switch (info.category) {
        .access, .conflict => try result.action(.inspect_scope),
        .lifecycle => try result.action(.inspect_status),
        .unavailable => try result.action(if (stage == .read) .retry_read else .inspect_status),
        .binding, .syntax, .unsupported, .limit, .constraint => try result.action(.correct_input),
        .internal, .integrity => try result.action(.contact_operator),
    }
    try result.validate();
    return result;
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
    const info = attemptInfo(cause);
    var value = try d.init(info.code, info.category, .input, .not_submitted, .local_before_dispatch, info.message);
    value.cause = try d.Code.init(@errorName(cause));
    try value.text(.operation, .caller, operation);
    try value.action(switch (info.category) {
        .internal, .integrity => .contact_operator,
        .conflict, .lifecycle, .unavailable => .inspect_status,
        .access => .inspect_scope,
        else => .correct_input,
    });
    try value.validate();
    return value;
}

test "every catalog caller cause preserves failed-read and dispatch evidence" {
    const std = @import("std");
    const t = std.testing;
    const request: c.Bridge.CreateTable = .{ .scope = .{ .realm = 46, .resource = 7, .catalog = "2" }, .operation = "18446744073709551615", .object = "19", .table = 1, .name = "items", .schema = .{ .names = .{ "id", "value" }, .value_type = .int64 } };
    for (codes.entries) |entry| {
        var read: ?d = try attempt(.{ .status = request }, entry.cause, .{}, false, null);
        // A different current connection must not rewrite the original scope.
        qualify(&read, .{ .scope = .{ .realm = 47, .resource = 8, .catalog = 3 }, .owner = 65536, .principal = 1234 }, null);
        try read.?.validate();
        try t.expectEqualStrings(entry.code, read.?.code.slice());
        try t.expectEqual(entry.category, read.?.category);
        try t.expectEqual(.not_applicable, read.?.outcome);
        try t.expectEqual(.none, read.?.evidence);
        try t.expectEqual(std.math.maxInt(u64), try read.?.identity.?.id.value());
        try t.expectEqual(@as(u64, 7), try read.?.identity.?.resource.?.value());
        try t.expectEqual(@as(u64, 46), try read.?.identity.?.realm.?.value());
        for (read.?.actions) |slot| if (slot) |action| {
            try t.expectEqualDeep(read.?.identity, action.target);
            try t.expect(action.kind != .resume_exact and action.kind != .cancel_mutation);
        };
        const send = try attempt(.{ .submit = "original" }, entry.cause, .{}, true, .{ .domain = .transport, .id = .init(12), .sequence = .init(12) });
        const rejected = entry.cause == error.AccessDenied or entry.cause == error.Conflict or entry.cause == error.Rejected;
        try t.expectEqual(if (rejected) d.Outcome.not_applicable else .unknown, send.outcome);
        try t.expectEqual(if (rejected) d.Evidence.none else .saved_intent, send.evidence);
        try t.expectEqual(if (rejected) d.ActionKind.inspect_scope else .resume_exact, send.actions[1].?.kind);
    }
    var invalid = request;
    invalid.operation = "019";
    try t.expect((try attempt(.{ .status = invalid }, error.InvalidCatalogInteger, .{}, false, null)).identity == null);
    try t.expect((try attempt(.{ .lookup = "items" }, error.CatalogDenied, .{}, false, null)).identity == null);
    var native: ?d = try attempt(.{ .status = request }, error.Conflict, .{}, false, null);
    qualify(&native, .{ .scope = .{ .realm = 46, .resource = 7, .catalog = 2 }, .owner = 65536, .principal = 1234 }, .ConflictingRetry);
    try t.expectEqualStrings("catalog.authority_conflict", native.?.code.slice());
    try t.expectEqualStrings("ConflictingRetry", native.?.facts[1].?.value.?.text.slice());
}
