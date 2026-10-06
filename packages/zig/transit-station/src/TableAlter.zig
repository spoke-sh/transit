//! Frozen-source schema evolution. No schema or row prefix becomes live before
//! the full successor passes. Catalog names/dependencies remain catalog-owned.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Write = @import("TableWrite.zig");
const Statement = @import("TableStatement.zig");
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
const Pub = @import("Publication.zig");
const Data = @import("TableData.zig");
const Candidate = @import("TableCandidate.zig");
pub const Request = struct {
    resource: u64,
    principal: u64,
    operation: u64,
    schema: f.TableSchema.Schema,
    change: f.TableEvolution.Change,
    pub fn reference(self: Request) !Write.Reference {
        if (self.resource == 0 or self.resource > p.max_counter or self.principal > p.max_counter or self.operation == 0) return error.InvalidTableWrite;
        var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
        const transition = try f.TableEvolution.apply(self.schema, self.change, &columns);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.alter.v1\x00");
        var definition: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&definition, @tagName(p.Growth.current_definition)) catch unreachable;
        hash.update(&definition);
        var ids: [24]u8 = undefined;
        std.mem.writeInt(u64, ids[0..8], self.resource, .little);
        std.mem.writeInt(u64, ids[8..16], self.principal, .little);
        std.mem.writeInt(u64, ids[16..24], self.operation, .little);
        hash.update(&ids);
        hash.update(&try self.schema.fingerprint());
        hash.update(&try transition.after.fingerprint());
        return .{ .resource = self.resource, .object = self.schema.object, .principal = self.principal, .operation = self.operation, .digest = hash.finalResult() };
    }
};
fn add(left: u64, right: u64) !u64 {
    return std.math.add(u64, left, right) catch return error.TableCapacity;
}
fn writeCount(turn: *const Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn schemaReference(result: Write.Status, bytes: []const u8) !Pages.Reference {
    return .{ .id = result.first_record, .spec = try Pub.Digest.of(Pages.schema_format, bytes) };
}
fn finish(turn: *Turn, head: Head, result: Write.Status, progress: Statement.Progress, ref: Pages.Reference) !Write.Status {
    var after = head;
    after.revision = try add(head.revision, 1);
    after.schema = ref;
    after.index = progress.index;
    after.pending = 0;
    // DDL does not report a DML affected-row count. Progress separately records
    // every validated/rewritten row until the final schema decision.
    return Statement.publish(turn, head, after, result, 0, 0);
}
fn constraint(err: anyerror) ?@FieldType(Write.Status, "rejection") {
    return switch (err) {
        error.NullNotAllowed => .null_not_allowed,
        error.MissingRequiredField => .missing_required_field,
        error.CharacterLimitExceeded => .character_limit_exceeded,
        error.Overflow => .overflow,
        error.Inexact => .inexact,
        error.RowExists => .row_exists,
        error.RowIdentityExists => .row_identity_exists,
        else => null,
    };
}
pub fn step(allocator: std.mem.Allocator, turn: *Turn, request: Request) !Write.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    const reference = try request.reference();
    const prior = try Write.status(turn, reference);
    if (prior) |result| if (result.route != .alter) return error.InvalidTableWriteStatus;
    if (prior) |result| if (result.state != .building) return result;
    const head = try Head.load(turn, reference.object);
    if (head.retired) return error.TableRetired;
    if (prior == null and head.pending != 0) return error.TableBusy;
    var original_schema = try head.readSchema(allocator, turn);
    defer original_schema.deinit();
    if (!std.mem.eql(u8, &try original_schema.schema.fingerprint(), &try request.schema.fingerprint())) return error.TableSchemaChanged;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const transition = try f.TableEvolution.apply(original_schema.schema, request.change, &columns);
    var result = prior orelse blk: {
        var reserved = head;
        reserved.revision = try add(head.revision, 1);
        reserved.pending = head.next_record;
        // The schema owns the first ID; row overlays have a complete interval.
        reserved.next_record = try add(head.next_record, 1 + Candidate.max_records);
        const admitted: Write.Status = .{ .reference = reference, .route = .alter, .admitted_input = turn.delivery.input.position, .basis_revision = head.revision, .first_record = head.next_record, .end_record = reserved.next_record, .state = .building };
        const progress: Statement.Progress = .{ .digest = reference.digest, .head_revision = reserved.revision, .index = if (transition.work == .rewrite_rows) .{} else head.index };
        try head.replace(turn, reserved);
        try turn.write(reference.key(), try admitted.encode());
        try progress.save(turn, reference);
        break :blk admitted;
    };
    if (prior == null) return result;
    if (result.end_record - result.first_record < 1 + Candidate.max_records) return error.InvalidTableStatementProgress;
    var progress = try Statement.Progress.load(turn, result, head);
    if (progress.ordinal != 0 or progress.matched > head.rows or progress.changed > head.rows) return error.InvalidTableStatementProgress;
    const expected_rows = if (transition.work == .rewrite_rows) progress.matched else head.rows;
    const entries = std.math.mul(u64, expected_rows, if (transition.after.primary_key.len == 0) 1 else 2) catch return error.TableCapacity;
    if (entries != if (progress.index.root) |root| root.entries else 0) return error.InvalidTableStatementProgress;
    if (transition.work == .rewrite_rows) {
        if (progress.changed != progress.matched) return error.InvalidTableStatementProgress;
    } else if (progress.changed != 0 or !std.meta.eql(progress.index, head.index)) return error.InvalidTableStatementProgress;
    if (transition.work == .metadata and (progress.cursor != null or progress.matched != 0)) return error.InvalidTableStatementProgress;
    const pages: Pages = .{ .resource = reference.resource, .object = reference.object };
    var schema_buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const schema_bytes = try transition.after.encode(&schema_buffer);
    const schema_ref = try schemaReference(result, schema_bytes);
    const before_schema = writeCount(turn);
    if (try pages.stage(turn, schema_ref, schema_bytes) == .progress) return result;
    // Publication readers require a committed cut. Finish schema staging before
    // reading source rows; do not weaken that boundary to combine more work.
    if (writeCount(turn) != before_schema) return result;
    if (transition.work == .metadata) return finish(turn, head, result, progress, schema_ref);
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = turn };
    const original: Data = .{ .schema = transition.before, .index = head.index };
    var row = (try original.next(allocator, &reader, progress.cursor)) orelse {
        if (progress.matched != head.rows) return error.InvalidTableStatementProgress;
        return finish(turn, head, result, progress, schema_ref);
    };
    defer row.deinit();
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const rewritten = transition.row(row.row().cells, &cells) catch |err| {
        if (constraint(err)) |reason| return Statement.close(turn, head, result, reason);
        return err;
    };
    progress.cursor = row.identity;
    progress.matched = try add(progress.matched, 1);
    if (transition.work == .validate_rows) {
        try progress.save(turn, reference);
        return result;
    }
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(allocator, &reader, result.end_record - Candidate.max_records, result.end_record);
    defer overlay.deinit();
    const candidate: Data = .{ .schema = transition.after, .index = progress.index };
    const changed = candidate.insert(allocator, &overlay, .{ .identity = row.identity, .cells = rewritten }) catch |err| {
        if (constraint(err)) |reason| return Statement.close(turn, head, result, reason);
        return err;
    };
    _ = try overlay.finish(changed.data.index);
    progress.index = changed.data.index;
    progress.changed = try add(progress.changed, 1);
    const count_before = writeCount(turn);
    const ready = stageAll(turn, pages, &overlay) catch |err| {
        if (err != error.MutationBudgetExceeded or writeCount(turn) == count_before) return err;
        return result;
    };
    if (!ready) return result;
    const staged = turn.decision;
    var reserved = head;
    reserved.revision = try add(head.revision, 1);
    reserved.next_record = try add(head.next_record, Candidate.max_records);
    progress.head_revision = reserved.revision;
    result.end_record = reserved.next_record;
    advance(turn, head, reserved, result, progress) catch |err| {
        turn.decision = staged;
        if (err != error.MutationBudgetExceeded or writeCount(turn) == count_before) return err;
        return prior.?;
    };
    return result;
}
fn advance(turn: *Turn, head: Head, reserved: Head, result: Write.Status, progress: Statement.Progress) !void {
    try head.replace(turn, reserved);
    try turn.write(result.reference.key(), try result.encode());
    try progress.save(turn, result.reference);
}
fn stageAll(turn: *Turn, pages: Pages, overlay: anytype) !bool {
    for (overlay.records.items) |item| if (item.reachable) {
        if (try pages.stage(turn, .{ .id = item.id, .spec = item.spec }, item.bytes) == .progress) return false;
    };
    return true;
}
pub const cancel = Statement.cancelAlter;
