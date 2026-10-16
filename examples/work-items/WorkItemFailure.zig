//! Application-specific witnesses augment the shared migration decision evidence.
const std = @import("std");
const W = @import("WorkItems.zig");
const p = W.app.protocol;
const d = p.Diagnostic;
const M = W.app.MigrationFailure;
const Wide = W.app.Model.Wide;
pub const Witness = union(enum(u8)) {
    ledger: M.Witness = 0,
    epoch: struct { expected: Wide, actual: Wide, active: Wide, actual_contract: [32]u8, expected_contract: [32]u8, contract_known: bool } = 1,
    cursor: struct { expected: [32]u8, actual: [32]u8, expected_bytes: u16, actual_bytes: u16 } = 2,
    verification: struct { phase: @FieldType(W.Cursor, "phase"), copied: u64, verified: u64 } = 3,
    state: struct { epoch: Wide, key: i64, value: i64 } = 4,
    target: u32 = 5,
};
pub const Context = struct { ledger: M.Witness = .none, domain: ?Witness = null };
pub const Disposition = struct { record: M.Record, witness: Witness, diagnostic: d };
pub fn classification(cause: []const u8) ?M.Class {
    if (M.classification(cause)) |value| return value;
    const Mapping = struct { name: []const u8, value: M.Class };
    const mappings = [_]Mapping{
        .{ .name = "WorkItemWritesPending", .value = .{ .code = "work_items.writes_pending", .category = .lifecycle, .message = "Previously accepted work-item writes have not finished Table publication. This input did not begin a migration. Inspect those exact operations and wait for their completion before reviewing a migration." } },
        .{ .name = "WorkItemDenied", .value = .{ .code = "work_items.denied", .category = .access, .message = "This input lacked the application's required external operator or writer authority. It did not change work items or migration state. Inspect the caller and exact resource scope before continuing." } },
        .{ .name = "WorkItemMigrationPaused", .value = .{ .code = "work_items.migration_paused", .category = .lifecycle, .message = "Work-item writes are paused by the recorded active migration. This input did not change a row. Inspect that plan and its step receipts; restart, timeout or a rejected write cannot release the pause." } },
        .{ .name = "WorkItemPublicationPaused", .value = .{ .code = "work_items.publication_paused", .category = .lifecycle, .message = "The target data epoch is active, but writes await explicit administrator release after interface publication. This input did not change a row. Verify the compatible published interface and inspect the reviewed release operation." } },
        .{ .name = "WorkItemEpochChanged", .value = .{ .code = "work_items.epoch_changed", .category = .conflict, .message = "The command's data epoch or complete contract differs from the active data owner. This input did not change rows or release writes. Compare the original expected and observed epoch and inspect the active contract." } },
        .{ .name = "InvalidWorkItemState", .value = .{ .code = "work_items.invalid_state", .category = .constraint, .message = "The submitted state is outside this data epoch's encoding: epoch 1 accepts 0 (open) or 1 (done); epoch 2 accepts 10 (open) or 20 (done). This input did not change a row." } },
        .{ .name = "InvalidWorkItemPlan", .value = .{ .code = "work_items.invalid_plan", .category = .binding, .message = "This application supports transform 1 from epoch 1 to epoch 2 with its complete source and target contracts. The fresh target Table/plan identity must fit uint32 and exceed 1. This input did not begin a migration." } },
        .{ .name = "InvalidWorkItemStep", .value = .{ .code = "work_items.invalid_step", .category = .binding, .message = "Work-item migration operation 1 copies or verifies the next row; operation 2 activates a completely verified target. The supplied operation is incompatible with the retained phase. This input did not advance the plan." } },
        .{ .name = "WorkItemCursorChanged", .value = .{ .code = "work_items.cursor_changed", .category = .conflict, .message = "This step's arguments differ from the exact retained migration cursor. This input did not run the transform. Compare the original cursor commitments and inspect the plan's next ordinal before continuing." } },
        .{ .name = "WorkItemVerificationIncomplete", .value = .{ .code = "work_items.verification_incomplete", .category = .conflict, .message = "Activation requires the ready phase and equal copied and verified row counts. This input did not activate the target epoch. Inspect the retained phase and counts, then continue only the original plan's required steps." } },
        .{ .name = "TableExists", .value = .{ .code = "work_items.target_exists", .category = .conflict, .message = "The prepared migration target is nonempty, busy or retired. This input did not begin a plan or replace that Table. Inspect its original identity and pending operation; a migration requires an empty live target with no pending Table work." } },
        .{ .name = "InvalidWorkItemFrame", .value = .{ .code = "work_items.invalid_frame", .category = .syntax, .stage = .input, .message = "The data owner rejected a malformed Station frame. Use the current signed application command encoder. This input did not change work items or migration state." } },
        .{ .name = "InvalidWorkItemCommand", .value = .{ .code = "work_items.invalid_command", .category = .syntax, .stage = .input, .message = "The input is not a valid current work-item command. Check its command variant, encoding and bounds. This input did not change work items or migration state." } },
        .{ .name = "WorkItemInitializationRequired", .value = .{ .code = "work_items.initialization_required", .category = .lifecycle, .message = "The requested work-item Table or owner state has not finished initialization. Inspect the separately authorized ledger/catalog initialization and exact Table preparation operation." } },
        .{ .name = "InvalidWorkItemQueryPolicy", .value = .{ .code = "work_items.invalid_query_policy", .category = .binding, .stage = .input, .message = "The query policy is malformed or names a different capture peer. This input did not replace the source policy. Inspect the configured query peer and current data contract." } },
        .{ .name = "StaleQueryPolicy", .value = .{ .code = "work_items.stale_query_policy", .category = .conflict, .message = "The query policy revision is stale. This input did not replace source policy. Inspect the current source policy before reviewing another update; migration and publication remain separate operations." } },
    };
    for (mappings) |mapping| if (std.mem.eql(u8, cause, mapping.name)) return mapping.value;
    return null;
}
pub fn cursor(expected: p.Value, actual: p.Value) Witness {
    return .{ .cursor = .{ .expected = cursorDigest(expected), .actual = cursorDigest(actual), .expected_bytes = expected.len, .actual_bytes = actual.len } };
}
fn cursorDigest(value: p.Value) [32]u8 {
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.work_items.cursor.v1\x00");
    digest.update(value.slice());
    return digest.finalResult();
}
pub fn project(config: W.Configuration, record: M.Record, witness: Witness) !d {
    const info = classification(record.cause.slice()) orelse return error.InvalidMigrationFailure;
    var result = try M.project(config.application, config.realm, config.resource, record, if (witness == .ledger) witness.ledger else .none, info);
    switch (witness) {
        .ledger => {},
        .epoch => |epoch| {
            if (epoch.actual.value == 0) return error.InvalidMigrationFailure;
            try result.text(.schema_origin, .owner, "work-item data epoch and active contract");
            try result.fact(.expected_revision, .owner, .{ .unsigned = .init(epoch.expected.value) });
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(epoch.actual.value) });
            try result.fact(.actual_schema, .owner, .{ .digest = epoch.actual_contract });
            if (epoch.contract_known) try result.fact(.expected_schema, .owner, .{ .digest = epoch.expected_contract }) else try result.absent(.expected_schema, .owner, .inapplicable);
            try result.fact(.proposal, .owner, .{ .unsigned = .init(epoch.active.value) });
        },
        .cursor => |value| {
            if (value.expected_bytes > 128 or value.actual_bytes > 128) return error.InvalidMigrationFailure;
            try result.text(.schema_origin, .owner, "retained and submitted migration cursor commitments");
            try result.fact(.expected_schema, .owner, .{ .digest = value.expected });
            try result.fact(.actual_schema, .owner, .{ .digest = value.actual });
            try result.fact(.expected_count, .owner, .{ .unsigned = .init(value.expected_bytes) });
            try result.fact(.actual_count, .owner, .{ .unsigned = .init(value.actual_bytes) });
            try result.text(.unit, .owner, "cursor bytes");
        },
        .verification => |value| {
            try result.text(.operation, .owner, @tagName(value.phase));
            try result.fact(.expected_count, .owner, .{ .unsigned = .init(value.copied) });
            try result.fact(.actual_count, .owner, .{ .unsigned = .init(value.verified) });
            try result.text(.unit, .owner, "copied versus verified rows");
        },
        .state => |value| {
            if (value.epoch.value != 1 and value.epoch.value != 2) return error.InvalidMigrationFailure;
            try result.fact(.actual_revision, .owner, .{ .unsigned = .init(value.epoch.value) });
            try result.fact(.source_key, .owner, .{ .signed = .init(value.key) });
            try result.fact(.supplied_value, .owner, .{ .signed = .init(value.value) });
            try result.text(.expected_type, .owner, if (value.epoch.value == 1) "int64 state 0 or 1" else "int64 state 10 or 20");
        },
        .target => |value| try result.fact(.table, .owner, .{ .unsigned = .init(value) }),
    }
    try result.validate();
    return result;
}
pub fn read(config: W.Configuration, reader: anytype, principal: u64, input: u64) !?Disposition {
    const encoded = (try reader.read(W.dispositionKey(config.application, principal, input))) orelse return null;
    const record = try W.app.Records.decode(M.Record, 'e', encoded);
    if (record.input != input) return error.InvalidMigrationFailure;
    const witness = try W.app.Records.decode(Witness, 'f', (try reader.read(W.witnessKey(config.application, principal, input))) orelse return error.InvalidMigrationFailure);
    return .{ .record = record, .witness = witness, .diagnostic = try project(config, record, witness) };
}
