//! Pure general Table outcome projections. The caller authorizes current
//! receipt disclosure before calling; no reads, retries or name rebinding occur.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.Diagnostic;
pub fn status(intent: *const c.TableIntent, outcome: c.TableClient.Outcome) !d {
    const table: ?c.station.TableWrite.Status = switch (outcome) {
        .dml => |value| blk: {
            try value.validate();
            if (intent.identity != .dml or !std.meta.eql(intent.identity.dml.reference, value.reference) or intent.identity.dml.route != value.route) return error.CatalogIdentityConflict;
            break :blk value;
        },
        .ddl => |value| blk: {
            try value.operation.validate();
            if (intent.identity != .ddl) return error.CatalogIdentityConflict;
            const original = intent.identity.ddl;
            const actual = value.operation;
            if (!std.meta.eql(original.scope, actual.scope) or original.principal != actual.principal or original.operation != actual.operation or !std.mem.eql(u8, &original.digest, &actual.digest)) return error.CatalogIdentityConflict;
            if (@backingInt(actual.kind) != @backingInt(intent.header.kind) or actual.object != intent.header.object) return error.CatalogIdentityConflict;
            if (value.table) |entry| {
                try entry.validate();
                if (actual.state != .delegated or !std.meta.eql(try actual.tableReference(), entry.reference)) return error.InvalidCatalogReceipt;
            } else if (actual.state == .delegated) return error.InvalidCatalogReceipt;
            break :blk value.table;
        },
    };
    const rejected = if (table) |value| value.state == .rejected else outcome.ddl.operation.state == .rejected;
    const cancelled = if (table) |value| value.state == .cancelled else outcome.ddl.operation.state == .cancelled;
    const complete = outcome.terminal();
    const code = if (rejected) if (table) |value| switch (value.rejection) {
        .row_exists => "table.primary_key_conflict",
        .row_identity_exists => "table.row_identity_conflict",
        .null_not_allowed => "table.not_null_violation",
        .missing_required_field => "table.required_value_missing",
        .character_limit_exceeded => "table.character_limit",
        .overflow => "table.conversion_overflow",
        .inexact => "table.inexact_conversion",
        .none => unreachable,
    } else switch (outcome.ddl.operation.reason) {
        .name_conflict => "table.name_conflict",
        .object_conflict => "table.object_conflict",
        .not_found => "table.not_found",
        .dependency => "table.drop_restricted",
        .schema_changed => "table.schema_changed",
        .none => unreachable,
    } else if (cancelled) "table.cancelled" else if (complete) "table.applied" else "table.pending";
    const message = if (rejected) if (table) |value| switch (value.rejection) {
        .row_exists => "A primary key conflicts with an existing row or another row in this statement. The statement published no row changes.",
        .row_identity_exists => "The immutable row identity is already occupied. Preserve the original operation; no row changes were published.",
        .null_not_allowed => "A NULL value violates NOT NULL in the proposed schema. The statement published no changes.",
        .missing_required_field => "A required column has no supplied value or default. The statement published no changes.",
        .character_limit_exceeded => "A text value exceeds its column's declared Unicode scalar limit. The statement published no changes.",
        .overflow => "An existing value is outside the target type's range. The schema and rows remain unchanged.",
        .inexact => "A value cannot be converted exactly to the target type. The schema and rows remain unchanged.",
        .none => unreachable,
    } else switch (outcome.ddl.operation.reason) {
        .name_conflict => "The requested Table name is already bound. This statement did not replace that Table.",
        .object_conflict => "The requested object identity is already occupied. This statement created no Table.",
        .not_found => "The originally selected Table does not exist. This statement did not affect a replacement object.",
        .dependency => "A registered dependency restricts dropping this Table. The live Table remains available.",
        .schema_changed => "The original Table definition changed before this statement could publish. Recompile only after reconciling this outcome.",
        .none => unreachable,
    } else if (cancelled) "The original Table operation was cancelled before publication. It published no changes." else if (complete) "The original Table operation completed. Later inspection or output failures cannot undo its outcome." else "The original Table operation is still pending. Preserve its saved intent and reconcile exact work.";
    var result = try d.init(code, if (rejected) if (table) |value| if (value.rejection == .row_identity_exists) .conflict else .constraint else .conflict else .lifecycle, if (cancelled) .control else .execute, if (rejected) .rejected else if (cancelled) .cancelled else if (complete) .applied else .pending, .domain_status, message);
    result.identity = .{ .domain = if (intent.identity == .ddl) .catalog else .mutation, .id = .init(intent.header.operation), .realm = .init(intent.header.scope.realm), .resource = .init(intent.header.scope.resource) };
    try result.fact(.object, .owner, .{ .unsigned = .init(intent.header.object) });
    try result.text(.operation, .caller, @tagName(intent.header.kind));
    if (table) |value| {
        try result.fact(.native_input, .owner, .{ .unsigned = .init(value.admitted_input) });
        if (complete) try result.fact(.affected_rows, .execution, .{ .unsigned = .init(value.changed) });
        if (rejected) {
            try result.absent(.column, .execution, .unrecorded);
            try result.absent(.source_row, .execution, .unrecorded);
            if (value.rejection == .row_exists) {
                try result.text(.constraint, .schema, "primary key");
                try result.absent(.key, .execution, .unrecorded);
            }
        }
    }
    try result.action(.inspect_status);
    if (!complete) {
        try result.action(.resume_exact);
        try result.action(.cancel_mutation);
    } else if (rejected) try result.action(if (table != null and table.?.rejection != .row_identity_exists) .correct_input else .inspect_scope);
    try result.validate();
    return result;
}
pub fn input(value: c.TableControl.Disposition) !d {
    try value.validate();
    const success = switch (value.outcome) {
        .initialized, .policy_applied, .dependency_applied => true,
        else => false,
    };
    const code = switch (value.outcome) {
        inline else => |kind| "table.input." ++ @tagName(kind),
    };
    var result = try d.init(code, switch (value.outcome) {
        .initialized, .policy_applied, .dependency_applied => .lifecycle,
        .invalid_command => .binding,
        .denied => .access,
        .identity_conflict, .stale_policy, .blocked => .conflict,
    }, .admission, if (success) .applied else .input_rejected, .domain_status, switch (value.outcome) {
        .initialized => "The catalog initialization input applied. This is not a SQL operation outcome.",
        .policy_applied => "The catalog policy input applied. Later work requires current authorization.",
        .dependency_applied => "The catalog dependency input applied. This is not a DROP outcome.",
        .invalid_command => "The catalog rejected this command's encoding or binding. Inspect the original saved operation independently.",
        .denied => "Current catalog authorization rejected this input. An already accepted operation may remain pending.",
        .identity_conflict => "This input conflicts with the original recorded identity. Preserve the original saved work.",
        .stale_policy => "The policy revision changed before this control input could apply. Inspect current policy and the original input.",
        .blocked => "This input cannot advance the current Table or upload phase. Inspect its original saved status before requesting another step.",
    });
    result.identity = .{ .domain = .transport, .id = .init(value.input), .realm = .init(value.scope.realm), .resource = .init(value.scope.resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(value.input) });
    try result.fact(.source_basis, .owner, .{ .digest = value.payload });
    try result.action(.inspect_status);
    try result.validate();
    return result;
}
