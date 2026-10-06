//! Atomic finite Table statements. Private candidate roots advance in bounded
//! captured turns; readers keep the original head until the final outcome.
//! Current policy, exact request persistence and native commit remain the owner’s
//! responsibility. Reconstructing a request from a newer schema is forbidden.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Write = @import("TableWrite.zig");
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
const Data = @import("TableData.zig");
const Candidate = @import("TableCandidate.zig");
const Index = @import("ImmutableIndex.zig");

pub const Request = struct {
    resource: u64,
    principal: u64,
    operation: u64,
    plan: f.TableDml.Plan,
    /// Exact enclosing catalog/source intent; a digest is not authorization.
    owner_binding: [32]u8 = @splat(0),
    pub fn reference(self: Request, allocator: std.mem.Allocator) !Write.Reference {
        if (self.resource == 0 or self.resource > p.max_counter or self.principal > p.max_counter or self.operation == 0) return error.InvalidTableWrite;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.statement.v1\x00");
        hash.update(&definition());
        var ids: [24]u8 = undefined;
        std.mem.writeInt(u64, ids[0..8], self.resource, .little);
        std.mem.writeInt(u64, ids[8..16], self.principal, .little);
        std.mem.writeInt(u64, ids[16..24], self.operation, .little);
        hash.update(&ids);
        hash.update(&self.owner_binding);
        hash.update(&try self.plan.fingerprint(allocator));
        return .{ .resource = self.resource, .object = self.plan.schema.object, .principal = self.principal, .operation = self.operation, .digest = hash.finalResult() };
    }
};
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
fn add(left: u64, right: u64) !u64 {
    return std.math.add(u64, left, right) catch return error.TableCapacity;
}
fn writeCount(turn: *const Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn record(turn: *Turn, result: Write.Status) !void {
    try turn.write(result.reference.key(), try result.encode());
}
pub const Progress = struct {
    digest: [32]u8,
    head_revision: u64,
    index: Index,
    cursor: ?f.TableRow.Identity = null,
    ordinal: u32 = 0,
    matched: u64 = 0,
    changed: u64 = 0,
    pub fn key(reference: Write.Reference) p.Value {
        var result = reference.key();
        result.data[1] = 'G';
        return result;
    }
    fn validate(self: Progress) !void {
        if (self.head_revision == 0 or self.changed > self.matched or self.ordinal > f.TableDml.max_rows) return error.InvalidTableStatementProgress;
        if (self.cursor) |cursor| try cursor.validate();
        if (self.index.root) |root| {
            try root.validate();
            if (!((root.minimum.len == 21 and root.minimum.data[0] == 'R') or (root.minimum.len == 53 and root.minimum.data[0] == 'K'))) return error.InvalidTableStatementProgress;
        }
    }
    pub fn encode(self: Progress) !p.Value {
        try self.validate();
        var bytes: [256]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("STG1");
        try out.writeAll(&definition());
        try out.writeAll(&self.digest);
        try out.writeInt(u64, self.head_revision, .little);
        try out.writeByte(@intFromBool(self.index.root != null));
        if (self.index.root) |root| {
            try out.writeInt(u64, root.id, .little);
            try out.writeInt(u32, root.spec.format, .little);
            try out.writeInt(u32, root.spec.length, .little);
            try out.writeAll(&root.spec.digest);
            try out.writeByte(root.level);
            try out.writeByte(@intCast(root.minimum.len));
            try out.writeAll(root.minimum.slice());
            try out.writeInt(u64, root.entries, .little);
        }
        try out.writeByte(@intFromBool(self.cursor != null));
        if (self.cursor) |cursor| try out.writeAll(&try cursor.encode());
        try out.writeInt(u32, self.ordinal, .little);
        try out.writeInt(u64, self.matched, .little);
        try out.writeInt(u64, self.changed, .little);
        return p.Value.init(out.buffered());
    }
    fn parse(bytes: []const u8) !Progress {
        var in: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try in.take(4), "STG1")) return error.InvalidTableStatementProgress;
        if (!std.mem.eql(u8, try in.take(32), &definition())) return error.IncompatibleTableStorage;
        var result: Progress = .{ .digest = (try in.take(32))[0..32].*, .head_revision = try in.takeInt(u64, .little), .index = .{} };
        switch (try in.takeByte()) {
            0 => {},
            1 => {
                const id = try in.takeInt(u64, .little);
                const format = try in.takeInt(u32, .little);
                const length = try in.takeInt(u32, .little);
                const digest = (try in.take(32))[0..32].*;
                const level = try in.takeByte();
                const minimum = try Index.Key.init(try in.take(try in.takeByte()));
                result.index.root = .{ .id = id, .spec = .{ .format = format, .length = length, .digest = digest }, .level = level, .minimum = minimum, .entries = try in.takeInt(u64, .little) };
            },
            else => return error.InvalidTableStatementProgress,
        }
        result.cursor = switch (try in.takeByte()) {
            0 => null,
            1 => try f.TableRow.Identity.decode(try in.takeArray(f.TableRow.Identity.encoded_bytes)),
            else => return error.InvalidTableStatementProgress,
        };
        result.ordinal = try in.takeInt(u32, .little);
        result.matched = try in.takeInt(u64, .little);
        result.changed = try in.takeInt(u64, .little);
        if (in.bufferedLen() != 0) return error.InvalidTableStatementProgress;
        try result.validate();
        return result;
    }
    pub fn decode(value: p.Value) !Progress {
        try value.validate();
        return parse(value.slice()) catch |err| switch (err) {
            error.EndOfStream => error.InvalidTableStatementProgress,
            else => err,
        };
    }
    pub fn save(self: Progress, turn: *Turn, reference: Write.Reference) !void {
        try turn.write(key(reference), try self.encode());
    }
    pub fn load(turn: *Turn, result: Write.Status, head: Head) !Progress {
        const progress = try decode((try turn.read(key(result.reference))) orelse return error.InvalidTableStatementProgress);
        if (!std.mem.eql(u8, &progress.digest, &result.reference.digest) or head.retired or head.pending != result.first_record or
            head.revision != progress.head_revision or head.next_record != result.end_record or result.end_record - result.first_record < Candidate.max_records) return error.TableWriteBasisChanged;
        if (progress.index.root) |root| if (root.id >= head.next_record - Candidate.max_records) return error.InvalidTableStatementProgress;
        return progress;
    }
};
fn rows(head: Head, progress: Progress, action: f.TableDml.Action) !u64 {
    return switch (action) {
        .insert => add(head.rows, progress.changed),
        .update => head.rows,
        .delete => std.math.sub(u64, head.rows, progress.changed) catch return error.InvalidTableStatementProgress,
    };
}
fn validateCandidate(head: Head, progress: Progress, plan: f.TableDml.Plan) !void {
    const count = try rows(head, progress, plan.action);
    const entries = std.math.mul(u64, count, if (plan.schema.primary_key.len == 0) 1 else 2) catch return error.TableCapacity;
    if (entries != if (progress.index.root) |root| root.entries else 0) return error.InvalidTableStatementProgress;
    switch (plan.action) {
        .insert => |input| if (progress.cursor != null or progress.ordinal > input.len or progress.matched != progress.ordinal or progress.changed != progress.ordinal) return error.InvalidTableStatementProgress,
        .update, .delete => if (progress.ordinal != 0 or progress.matched > head.rows) return error.InvalidTableStatementProgress,
    }
}
fn finish(turn: *Turn, head: Head, result: Write.Status, progress: Progress, action: f.TableDml.Action) !Write.Status {
    var after = head;
    after.revision = try add(head.revision, 1);
    after.pending = 0;
    after.index = progress.index;
    after.rows = try rows(head, progress, action);
    return publish(turn, head, after, result, progress.matched, progress.changed);
}
/// Shared final decision for a fully staged finite statement or schema rewrite.
/// Its owner validates the complete successor before calling this composition.
pub fn publish(turn: *Turn, head: Head, after: Head, result: Write.Status, matched: u64, changed: u64) !Write.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (after.pending != 0) return error.InvalidTableHead;
    var accepted = result;
    accepted.state = .applied;
    accepted.completed_input = turn.delivery.input.position;
    accepted.matched = matched;
    accepted.changed = changed;
    try head.replace(turn, after);
    try record(turn, accepted);
    try turn.write(Progress.key(result.reference), null);
    return accepted;
}
pub fn close(turn: *Turn, head: Head, previous: Write.Status, rejection: @FieldType(Write.Status, "rejection")) !Write.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    var after = head;
    after.revision = try add(head.revision, 1);
    after.pending = 0;
    var result = previous;
    result.state = if (rejection == .none) .cancelled else .rejected;
    result.completed_input = turn.delivery.input.position;
    result.matched = 0;
    result.changed = 0;
    result.rejection = rejection;
    try head.replace(turn, after);
    try record(turn, result);
    try turn.write(Progress.key(result.reference), null);
    return result;
}
/// Process at most one frozen source row and one bounded publication phase.
/// Returned outcomes describe PRIVATE proposals until the native commit accepts.
pub fn step(allocator: std.mem.Allocator, turn: *Turn, request: Request) !Write.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    const reference = try request.reference(allocator);
    const prior = try Write.status(turn, reference);
    if (prior) |result| if (result.route != .statement) return error.InvalidTableWriteStatus;
    if (prior) |result| if (result.state != .building) return result;
    const head = try Head.load(turn, reference.object);
    if (head.retired) return error.TableRetired;
    if (prior == null and head.pending != 0) return error.TableBusy;
    var schema = try head.readSchema(allocator, turn);
    defer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &try request.plan.schema.fingerprint())) return error.TableSchemaChanged;
    var result = prior orelse blk: {
        var reserved = head;
        reserved.revision = try add(head.revision, 1);
        reserved.pending = head.next_record;
        reserved.next_record = try add(head.next_record, Candidate.max_records);
        const admitted: Write.Status = .{ .reference = reference, .route = .statement, .admitted_input = turn.delivery.input.position, .basis_revision = head.revision, .first_record = head.next_record, .end_record = reserved.next_record, .state = .building };
        const progress: Progress = .{ .digest = reference.digest, .head_revision = reserved.revision, .index = head.index };
        try head.replace(turn, reserved);
        try record(turn, admitted);
        try progress.save(turn, reference);
        break :blk admitted;
    };
    if (prior == null) return result;
    var progress = try Progress.load(turn, result, head);
    try validateCandidate(head, progress, request.plan);
    const pages: Pages = .{ .resource = reference.resource, .object = reference.object };
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = turn };
    const original: Data = .{ .schema = schema.schema, .index = head.index };
    const candidate: Data = .{ .schema = schema.schema, .index = progress.index };
    var source_row: ?f.TableRow.Owned = null;
    defer if (source_row) |*owned| owned.deinit();
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const change: Write.Change = switch (request.plan.action) {
        .insert => |input| if (progress.ordinal < input.len) .{ .insert = .{ .identity = .{ .origin = reference.principal + 1, .operation = reference.operation, .ordinal = progress.ordinal }, .cells = input[progress.ordinal] } } else return finish(turn, head, result, progress, request.plan.action),
        .update, .delete => blk: {
            source_row = (try original.next(allocator, &reader, progress.cursor)) orelse return finish(turn, head, result, progress, request.plan.action);
            const row = source_row.?.row();
            progress.cursor = row.identity;
            if (!try request.plan.matches(row.cells)) {
                try progress.save(turn, reference);
                return result;
            }
            break :blk switch (request.plan.action) {
                .update => |assignments| .{ .update = .{ .identity = row.identity, .cells = try schema.schema.update(row.cells, assignments, &cells) } },
                .delete => .{ .delete = row.identity },
                .insert => unreachable,
            };
        },
    };
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(allocator, &reader, result.end_record - Candidate.max_records, result.end_record);
    defer overlay.deinit();
    const changed = apply(candidate, allocator, &overlay, change) catch |err| switch (err) {
        error.RowExists => return close(turn, head, result, .row_exists),
        error.RowIdentityExists => return close(turn, head, result, .row_identity_exists),
        else => return err,
    };
    if (changed.matched != 1 or changed.changed > 1) return error.InvalidTableStatementProgress;
    _ = try overlay.finish(changed.data.index);
    progress.index = changed.data.index;
    progress.matched = try add(progress.matched, changed.matched);
    progress.changed = try add(progress.changed, changed.changed);
    if (request.plan.action == .insert) progress.ordinal += 1;
    try validateCandidate(head, progress, request.plan);
    if (changed.changed == 0) {
        try progress.save(turn, reference);
        return result;
    }
    const count_before = writeCount(turn);
    const ready = stageAll(turn, pages, &overlay) catch |err| {
        if (err != error.MutationBudgetExceeded or writeCount(turn) == count_before) return err;
        return result;
    };
    if (!ready) return result;
    // Advancing the durable cursor consumes this interval. A fresh interval is
    // fenced before any next row can be staged; IDs are never recycled.
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
fn advance(turn: *Turn, head: Head, reserved: Head, result: Write.Status, progress: Progress) !void {
    try head.replace(turn, reserved);
    try record(turn, result);
    try progress.save(turn, result.reference);
}
fn apply(data: Data, allocator: std.mem.Allocator, overlay: anytype, change: Write.Change) !Data.Candidate {
    return switch (change) {
        .insert => |row| data.insert(allocator, overlay, row),
        .update => |row| data.update(allocator, overlay, row),
        .delete => |identity| data.delete(allocator, overlay, identity),
        .patch, .delete_key => unreachable,
    };
}
fn stageAll(turn: *Turn, pages: Pages, overlay: anytype) !bool {
    for (overlay.records.items) |item| if (item.reachable) {
        if (try pages.stage(turn, .{ .id = item.id, .spec = item.spec }, item.bytes) == .progress) return false;
    };
    return true;
}
pub fn cancel(turn: *Turn, reference: Write.Reference) !Write.Status {
    return cancelRoute(turn, reference, .statement);
}
pub fn cancelAlter(turn: *Turn, reference: Write.Reference) !Write.Status {
    return cancelRoute(turn, reference, .alter);
}
fn cancelRoute(turn: *Turn, reference: Write.Reference, route: Write.Status.Route) !Write.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    const result = (try Write.status(turn, reference)) orelse return error.TableWriteNotFound;
    if (result.route != route) return error.InvalidTableWriteStatus;
    if (result.state != .building) return result;
    const head = try Head.load(turn, reference.object);
    _ = try Progress.load(turn, result, head);
    return close(turn, head, result, .none);
}
