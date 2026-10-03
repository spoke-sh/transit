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
    const category: d.Category = switch (value.reason) {
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
    var result = try d.init(code, category, if (value.phase == .cancelled) .control else if (!value.terminal()) .admission else .execute, outcome, .domain_status, message);
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
