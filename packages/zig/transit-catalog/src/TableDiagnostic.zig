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
            try witnessDetails(&result, intent, value);
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

fn witnessDetails(result: *d, intent: *const c.TableIntent, value: c.station.TableWrite.Status) !void {
    const witness = value.witness;
    if (witness.source == .none) {
        try result.absent(.column, .execution, .unrecorded);
        try result.absent(.source_row, .execution, .unrecorded);
        if (value.rejection == .row_exists) {
            try result.text(.constraint, .schema, "primary key");
            try result.absent(.key, .execution, .unrecorded);
        }
        return;
    }
    if (value.rejection == .row_exists) try result.text(.constraint, .schema, "primary key");
    var original = try intent.command(intent.allocator);
    defer original.deinit();
    if (original.body.request == .dml and original.body.request.dml.plan.action == .insert and witness.source != .input) return error.InvalidCatalogReceipt;
    var fields: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
    const schema: c.fuze.TableSchema.Schema = switch (original.body.request) {
        .dml => |request| request.plan.schema,
        .ddl => |request| if (request.action == .alter) (try c.fuze.TableEvolution.apply(request.action.alter.schema, request.action.alter.change, &fields)).after else return error.InvalidCatalogReceipt,
    };
    const name = switch (original.body.request) {
        .dml => |request| request.plan.name,
        .ddl => |request| request.name.slice(),
    };
    try result.text(.table, .schema, name);
    if (witness.column != 0) {
        const column = schema.columns[schema.index(witness.column) catch return error.InvalidCatalogReceipt];
        try result.text(.column, .schema, column.name);
        var buffer: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&buffer);
        var truncated = false;
        c.fuze.LogicalDisplay.typeName(&out, column.type) catch |err| {
            if (err != error.WriteFailed) return err;
            truncated = true;
        };
        try result.add(.{ .field = .expected_type, .origin = .schema, .availability = if (truncated) .truncated else .provided, .value = .{ .text = try d.Text.init(out.buffered()) } });
        if (value.rejection == .character_limit_exceeded) {
            const limit = column.max_characters orelse return error.InvalidCatalogReceipt;
            try result.fact(.limit, .schema, .{ .unsigned = .init(limit) });
            try result.text(.unit, .schema, "Unicode scalars");
        }
    } else if (value.rejection == .row_exists) {
        if (schema.primary_key.len == 0) return error.InvalidCatalogReceipt;
        var names: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&names);
        var truncated = false;
        primaryColumns(&out, schema) catch |err| {
            if (err != error.WriteFailed) return err;
            truncated = true;
        };
        const text = try d.Text.truncate(out.buffered());
        try result.add(.{ .field = .column, .origin = .schema, .availability = if (truncated) .truncated else .provided, .value = .{ .text = text } });
    }
    const field: d.Field = if (value.rejection == .row_exists) .key else .supplied_value;
    if (witness.source == .withheld) {
        try result.absent(.source_row, .execution, .withheld);
        try result.absent(field, .execution, .withheld);
        return;
    }
    if (witness.source == .input) {
        if (original.body.request != .dml or original.body.request.dml.plan.action != .insert) return error.InvalidCatalogReceipt;
        const rows = original.body.request.dml.plan.action.insert;
        if (witness.row.origin != value.reference.principal + 1 or witness.row.operation != value.reference.operation or witness.row.ordinal >= rows.len) return error.InvalidCatalogReceipt;
        const expected = if (value.rejection == .row_exists) try c.fuze.TableWitness.key(.input, schema, .{ .identity = witness.row, .cells = rows[witness.row.ordinal] }) else if (value.rejection == .row_identity_exists) try c.fuze.TableWitness.identity(.input, witness.row) else return error.InvalidCatalogReceipt;
        if (!std.meta.eql(expected, witness)) return error.InvalidCatalogReceipt;
        try result.fact(.input_row, .execution, .{ .unsigned = .init(@as(u64, witness.row.ordinal) + 1) });
    } else {
        const id = std.fmt.bytesToHex(try witness.row.encode(), .lower);
        try result.text(.source_row, .execution, &id);
    }
    if (witness.length != 0 or witness.truncated) try result.add(.{ .field = field, .origin = .execution, .availability = if (witness.truncated) .truncated else .provided, .value = .{ .text = try d.Text.init(witness.text()) } });
}
fn primaryColumns(out: *std.Io.Writer, schema: c.fuze.TableSchema.Schema) !void {
    for (schema.primary_key, 0..) |id, i| {
        if (i != 0) try out.writeAll(", ");
        const name = schema.columns[try schema.index(id)].name;
        // Single columns retain their literal name in the structured fact.
        // Composite keys use an unambiguous quoted list in declaration order.
        if (schema.primary_key.len == 1) try out.writeAll(name) else try std.json.Stringify.value(name, .{ .escape_unicode = true }, out);
    }
}
