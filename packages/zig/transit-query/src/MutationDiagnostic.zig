//! Pure projections of currently authorized writer records. Reading or rendering
//! these values never resubmits, cancels, or reconstructs a mutation from rows.
const std = @import("std");
const q = @import("root.zig");
const d = q.protocol.Diagnostic;
const r = q.TableMutationRecords;

pub fn status(value: r.Status) !d {
    try value.validate();
    const outcome: d.Outcome = switch (value.phase) {
        .uploading, .sealed => .pending,
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
    };
    const classification: d.Category = switch (value.reason) {
        .none => .lifecycle,
        .row_exists => .constraint,
        .source_changed => .conflict,
        .invalid_request => .integrity,
        .denied => .access,
        .budget => .limit,
    };
    const code: []const u8 = if (value.reason != .none) switch (value.reason) {
        .row_exists => "mutation.primary_key_conflict",
        .source_changed => "mutation.source_changed",
        .invalid_request => "mutation.invalid_request",
        .denied => "mutation.policy_denied",
        .budget => "mutation.turn_budget_exceeded",
        .none => unreachable,
    } else switch (value.phase) {
        .uploading => "mutation.uploading",
        .sealed => "mutation.sealed",
        .applied => "mutation.applied",
        .cancelled => "mutation.cancelled",
        .rejected => unreachable,
    };
    const message: []const u8 = if (value.reason != .none) switch (value.reason) {
        .row_exists => "The primary key already exists. No rows were inserted; the recorded conflict identifies the first failing input row.",
        .source_changed => "The target Table definition changed before this mutation could apply. No rows were changed.",
        .invalid_request => "The writer rejected the immutable mutation request as invalid. No rows were changed. Preserve its original bytes and contract definition.",
        .denied => "The writer's current mutation policy did not permit this request. No rows were changed. Query read access does not grant writes.",
        .budget => "The mutation and its recorded outcome exceeded the writer's available turn budget. No rows were changed. Splitting an atomic statement changes its semantics.",
        .none => unreachable,
    } else switch (value.phase) {
        .uploading => "The saved mutation is still uploading. Reconcile the original command and request bytes before advancing it.",
        .sealed => "The saved mutation upload is sealed and awaits application. Inspect and reconcile this exact mutation.",
        .applied => "The saved mutation applied atomically. A later output or inspection failure cannot undo that result.",
        .cancelled => "The saved mutation was cancelled before application. No rows were changed by this mutation.",
        .rejected => unreachable,
    };
    var result = try d.init(code, classification, if (value.phase == .cancelled) .control else if (!value.terminal()) .admission else .execute, outcome, .domain_status, message);
    result.identity = .{ .domain = .mutation, .id = .init(value.reference.namespace), .resource = .init(value.reference.resource) };
    try result.fact(.table, .owner, .{ .unsigned = .init(value.table) });
    if (value.input != 0) try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    if (value.terminal()) try result.fact(.affected_rows, .execution, .{ .unsigned = .init(value.affected_rows) });
    try result.fact(.source_basis, .owner, .{ .digest = value.reference.spec.digest });
    try result.fact(.expected_schema, .owner, .{ .digest = value.declaration });
    try result.fact(.expected_policy, .owner, .{ .unsigned = .init(value.policy_revision) });
    if (value.witness) |witness| {
        try result.text(.native_cause, .owner, @tagName(witness.kind));
        switch (witness.kind) {
            .policy_missing => try result.text(.actual_policy, .authority, "missing at rejection"),
            .policy_disabled, .policy_revision, .policy_declaration, .operation_denied => {
                try result.fact(.actual_policy, .authority, .{ .unsigned = .init(witness.policy_revision) });
                try result.fact(.permissions, .authority, .{ .unsigned = .init(witness.permissions) });
                if (witness.kind == .policy_declaration) try result.fact(.actual_schema, .authority, .{ .digest = witness.declaration });
                if (witness.kind == .operation_denied) try result.text(.operation, .caller, switch (witness.operation) {
                    1 => "insert",
                    2 => "update",
                    3 => "delete",
                    else => unreachable,
                });
            },
            .table_missing => try result.text(.actual_schema, .schema, "Table missing at rejection"),
            .table_declaration, .request_declaration => try result.fact(.actual_schema, if (witness.kind == .table_declaration) .schema else .caller, .{ .digest = witness.declaration }),
        }
    }
    if (value.reason == .budget) {
        try result.text(.budget, .owner, "turn mutations");
        try result.absent(.limit, .owner, .unrecorded);
        try result.absent(.required, .owner, .unrecorded);
    }
    if (value.conflict) |conflict| {
        try result.text(.constraint, .schema, "primary key");
        try result.absent(.column, .schema, .unrecorded);
        try result.fact(.key, .execution, .{ .signed = .init(conflict.key) });
        try result.fact(.input_row, .execution, .{ .unsigned = .init(conflict.row) });
    }
    try result.action(.inspect_status);
    if (!value.terminal()) {
        try result.action(.resume_exact);
        try result.action(.cancel_mutation);
    } else switch (value.reason) {
        .row_exists => try result.action(.correct_input),
        .source_changed, .denied => try result.action(.inspect_scope),
        .invalid_request, .budget => try result.action(.contact_operator),
        .none => {},
    }
    try result.validate();
    return result;
}

/// A disposition identifies an admitted native input, not a mutation namespace.
/// It never proves that an existing upload or terminal mutation was replaced.
pub fn input(value: q.TableMutationWriter.Disposition) !d {
    _ = try value.encode();
    const code = switch (value.reason) {
        inline else => |reason| "mutation.input." ++ @tagName(reason),
    };
    var result = try d.init(code, switch (value.reason) {
        .denied => .access,
        .invalid_command, .invalid_part => .binding,
        .identity_conflict, .busy, .source_changed, .stale_policy => .conflict,
        .not_found, .not_active, .upload_closed, .not_sealed, .incomplete_upload => .lifecycle,
    }, .admission, .input_rejected, .domain_status, switch (value.reason) {
        .invalid_command => "The writer could not decode this command. Inspect the saved input and mutation separately; this input rejection does not establish a terminal mutation outcome.",
        .denied => "The principal or current mutation policy does not permit this command. Preserve the original saved mutation and inspect its status under current access.",
        .identity_conflict => "This input conflicts with the recorded mutation identity. Preserve the original immutable request and inspect its status.",
        .busy => "The writer already has an active mutation upload. Inspect and reconcile that upload before preparing different work.",
        .not_found => "The referenced mutation has no recorded upload. Preserve this rejected input and check its original namespace and writer scope.",
        .not_active => "The referenced mutation is not the writer's active upload. Inspect its saved status before attempting another command.",
        .upload_closed => "The mutation upload is closed to additional parts. Inspect its saved status and original immutable request.",
        .not_sealed => "The mutation upload has not been sealed for application. Inspect its recorded progress and reconcile the original upload.",
        .invalid_part => "This upload part conflicts with the immutable request or its bounds. Preserve the original bytes and inspect recorded progress.",
        .incomplete_upload => "The upload is missing required request bytes. Reconcile the original upload's recorded progress before sealing it.",
        .source_changed => "The target Table definition no longer matches this command. Inspect the saved mutation and the current writer declaration separately.",
        .stale_policy => "This command's expected mutation policy revision is stale. Inspect the current writer policy and the original mutation's status.",
    });
    result.identity = .{ .domain = .transport, .id = .init(value.input) };
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    try result.text(.operation, .owner, "mutation input");
    try result.action(.inspect_status);
    if (value.reason == .denied or value.reason == .source_changed or value.reason == .stale_policy) try result.action(.inspect_scope);
    try result.validate();
    return result;
}

/// Enrich only from the immutable request whose fingerprint matches the status.
/// The configured SQL name is caller context, not a newly read catalog binding.
pub fn bound(value: r.Status, request: q.TableMutationRequest, name: ?q.fuze.model.Name) !d {
    if (value.table != request.table or !std.meta.eql(value.reference, try request.reference(value.reference.namespace))) return error.InvalidMutationDiagnostic;
    var result = try status(value);
    if (name) |text| try result.text(.name, .caller, text.slice());
    if (value.conflict) |conflict| {
        if (request.plan.operation != .insert) return error.InvalidMutationDiagnostic;
        const row = request.plan.operation.insert[conflict.row - 1] orelse return error.InvalidMutationDiagnostic;
        if (row.key != conflict.key) return error.InvalidMutationDiagnostic;
        for (&result.facts) |*slot| if (slot.*) |*fact| {
            if (fact.field == .column) {
                fact.availability = .provided;
                fact.value = .{ .text = try .init(request.plan.schema.names[0].slice()) };
            }
        };
    }
    try result.validate();
    return result;
}

// Caller attempt evidence is independent of a saved domain outcome.
pub const codes = @import("MutationCodes.zig");
fn attemptInfo(cause: anyerror) codes.Entry {
    return codes.fromError(cause) orelse .{ .cause = cause, .code = "mutation.internal_failure", .category = .internal, .message = "The caller could not complete this operation. Preserve saved work and inspect its original status; this failure does not establish its outcome." };
}
pub fn category(action: q.TableMutationBridge.Action, cause: anyerror) d.Category {
    if (action == .compile) if (q.fuze.SqlDiagnostic.category(cause)) |value| return value;
    return attemptInfo(cause).category;
}
/// Only the exact caller reference supplies a mutation namespace. In particular,
/// the status string is encoded publication bytes, not a decimal namespace.
fn selected(action: q.TableMutationBridge.Action) ?d.Identity {
    const text = switch (action) {
        .status => |value| value,
        .next => |value| value.reference,
        .prepare => |value| switch (value) {
            .begin => |v| v.reference,
            .part => |v| v.reference,
            inline .seal, .apply, .cancel => |v| v,
        },
        inline .observe, .rejection => |value| {
            if (value.input == 0 or value.input > q.protocol.max_counter) return null;
            return .{ .domain = .transport, .id = .init(value.input) };
        },
        else => return null,
    };
    var buffer: [q.station.PublicationReference.encoded_bytes]u8 = undefined;
    var allocator = std.heap.FixedBufferAllocator.init(&buffer);
    const ref = q.TableMutationBridge.reference(allocator.allocator(), text) catch return null;
    return .{ .domain = .mutation, .id = .init(ref.namespace), .resource = .init(ref.resource) };
}

/// Connection scope qualifies caller context only; it proves no read or outcome.
/// A reference's original resource is retained even when it mismatches this client.
pub fn qualify(out: *?d, connection: q.TableMutationClient.Connection, native: ?q.protocol.ErrorCode) void {
    if (out.*) |*detail| {
        if (detail.identity) |*identity| {
            if (identity.realm == null) identity.realm = .init(connection.realm);
            for (&detail.actions) |*slot| if (slot.*) |*action| {
                action.target = identity.*;
            };
        }
        if (native) |cause| detail.text(.native_cause, .authority, @tagName(cause)) catch {};
    }
}
pub fn attempt(action: q.TableMutationBridge.Action, cause: anyerror, binding: q.fuze.Sql.Binding, dispatched: bool, identity: ?d.Identity) !d {
    if (action == .compile) if (q.fuze.SqlDiagnostic.writeCompiler(action.compile.sql, cause, .mutation, binding)) |detail| return detail.structured();
    const stage: d.Stage = switch (action) {
        .compile => .compile,
        .prepare, .next => .prepare,
        .submit => if (dispatched) .submit else .prepare,
        else => .read,
    };
    const info = attemptInfo(cause);
    const sending = dispatched and action == .submit;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    var result = if (sending and !rejected)
        try d.init("mutation.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The signed command outcome is unknown. Retain its exact saved bytes and reconcile before preparing another command.")
    else if (sending)
        try d.init("mutation.command_rejected", if (cause == error.AccessDenied) .access else .conflict, .submit, .not_applicable, .none, "The authority rejected this signed command. This does not establish the original operation outcome; inspect its saved status.")
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
        try d.init("mutation.memory_unavailable", .unavailable, .input, .not_submitted, .local_before_dispatch, "The caller could not allocate memory to read this request. No command was sent.")
    else
        try d.init("mutation.invalid_envelope", .syntax, .input, .not_submitted, .local_before_dispatch, "The action is not a valid bounded request object. No command was sent.");
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

test "every mutation caller cause preserves failed-read and dispatch evidence" {
    const t = std.testing;
    const table: q.station.Table = .{ .resource = 7, .id = 1, .schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 } };
    const request = try q.TableMutationRequest.fromSql(46, 65536, table, try .init("items"), "DELETE FROM items WHERE id=1");
    const ref = try request.reference(std.math.maxInt(u64));
    const text = try q.document.JsonValues.hex(t.allocator, (try ref.encode()).slice());
    defer t.allocator.free(text);
    for (codes.entries) |entry| {
        var read: ?d = try attempt(.{ .status = text }, entry.cause, .{}, false, null);
        qualify(&read, .{ .realm = 46, .principal = 1234, .writer = 65536, .resource = 8, .table = 1 }, null);
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
    try t.expect((try attempt(.{ .status = "18446744073709551615" }, error.InvalidTableMutationRequest, .{}, false, null)).identity == null);
    try t.expect((try attempt(.{ .status = "00" }, error.InvalidPublicationReference, .{}, false, null)).identity == null);
    var native: ?d = try attempt(.{ .status = text }, error.Conflict, .{}, false, null);
    qualify(&native, .{ .realm = 46, .principal = 1234, .writer = 65536, .resource = 7, .table = 1 }, .ConflictingRetry);
    try t.expectEqualStrings("mutation.authority_conflict", native.?.code.slice());
    try t.expectEqualStrings("ConflictingRetry", native.?.facts[1].?.value.?.text.slice());
    try t.expectError(error.InvalidDocumentInteger, q.document.JsonValues.unsigned("18446744073709551616"));
}
