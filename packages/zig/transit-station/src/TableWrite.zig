//! Recoverable single-row publication over the general Table representation.
//! The caller authenticates and authorizes each step. Native turns own commit/fencing.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Data = @import("TableData.zig");
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
const Candidate = @import("TableCandidate.zig");

const Cell = f.Types.Values.Cell;
pub const Patch = struct { key: []const Cell, assignments: []const f.TableSchema.Assignment };
pub const Change = union(enum(u8)) {
    insert: f.TableRow.Row = 1,
    update: f.TableRow.Row = 2,
    delete: f.TableRow.Identity = 3,
    patch: Patch = 4,
    delete_key: []const Cell = 5,
};
pub const Request = struct {
    resource: u64,
    principal: u64,
    operation: u64,
    schema: f.TableSchema.Schema,
    change: Change,
    /// Exact enclosing catalog/source intent; a digest is not authorization.
    owner_binding: [32]u8 = @splat(0),
    /// Canonical intent is recomputed, never accepted as a caller-provided hash.
    pub fn reference(self: Request, allocator: std.mem.Allocator) !Reference {
        if (self.resource == 0 or self.resource > p.max_counter or self.principal > p.max_counter or self.operation == 0) return error.InvalidTableWrite;
        if (self.change == .insert and !std.meta.eql(self.change.insert.identity, try self.insertIdentity())) return error.InvalidTableWrite;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.write.v1\x00");
        hash.update(&definition());
        var ids: [24]u8 = undefined;
        std.mem.writeInt(u64, ids[0..8], self.resource, .little);
        std.mem.writeInt(u64, ids[8..16], self.principal, .little);
        std.mem.writeInt(u64, ids[16..24], self.operation, .little);
        hash.update(&ids);
        hash.update(&self.owner_binding);
        hash.update(&try self.schema.fingerprint());
        hash.update(&.{@backingInt(std.meta.activeTag(self.change))});
        switch (self.change) {
            .delete => |id| hash.update(&try id.encode()),
            .delete_key => |key| try self.hashKey(allocator, &hash, key),
            .patch => |patch| {
                if (patch.assignments.len == 0) return error.InvalidMutationColumns;
                try self.schema.validateAssignments(patch.assignments);
                try self.hashKey(allocator, &hash, patch.key);
                var count: [2]u8 = undefined;
                std.mem.writeInt(u16, &count, @intCast(patch.assignments.len), .little);
                hash.update(&count);
                for (patch.assignments) |assignment| {
                    var column: [8]u8 = undefined;
                    std.mem.writeInt(u64, &column, assignment.column, .little);
                    hash.update(&column);
                    switch (assignment.value) {
                        .default => hash.update(&.{0}),
                        .cell => |cell| {
                            hash.update(&.{1});
                            try hashCell(allocator, &hash, self.schema.columns[try self.schema.index(assignment.column)].field(), cell);
                        },
                    }
                }
            },
            .insert, .update => |row| {
                var small: [4096]u8 = undefined;
                var large: ?[]u8 = null;
                defer if (large) |bytes| allocator.free(bytes);
                const bytes = row.encode(self.schema, &small) catch |err| blk: {
                    if (err != error.WriteFailed) return err;
                    large = try allocator.alloc(u8, f.TableRow.max_bytes);
                    break :blk try row.encode(self.schema, large.?);
                };
                hash.update(bytes);
            },
        }
        return .{ .resource = self.resource, .object = self.schema.object, .principal = self.principal, .operation = self.operation, .digest = hash.finalResult() };
    }
    pub fn insertIdentity(self: Request) !f.TableRow.Identity {
        if (self.principal > p.max_counter or self.operation == 0) return error.InvalidTableWrite;
        return .{ .origin = self.principal + 1, .operation = self.operation, .ordinal = 0 };
    }
    fn hashKey(self: Request, allocator: std.mem.Allocator, hash: *std.crypto.hash.sha2.Sha256, values: []const Cell) !void {
        var small: [4096]u8 = undefined;
        var large: ?[]u8 = null;
        defer if (large) |bytes| allocator.free(bytes);
        const bytes = f.TableRow.encodeKeyValues(self.schema, values, &small) catch |err| blk: {
            if (err != error.WriteFailed) return err;
            large = try allocator.alloc(u8, f.TableRow.max_key_bytes);
            break :blk try f.TableRow.encodeKeyValues(self.schema, values, large.?);
        };
        hashPart(hash, bytes);
    }
};
fn hashPart(hash: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    var length: [4]u8 = undefined;
    std.mem.writeInt(u32, &length, @intCast(bytes.len), .little);
    hash.update(&length);
    hash.update(bytes);
}
fn hashCell(allocator: std.mem.Allocator, hash: *std.crypto.hash.sha2.Sha256, field: f.Types.Field, cell: Cell) !void {
    var small: [4096]u8 = undefined;
    var large: ?[]u8 = null;
    defer if (large) |bytes| allocator.free(bytes);
    const bytes = f.Types.Codec.encode(cell, field, &small) catch |err| blk: {
        if (err != error.WriteFailed) return err;
        large = try allocator.alloc(u8, f.Types.Codec.max_bytes);
        break :blk try f.Types.Codec.encode(cell, field, large.?);
    };
    hashPart(hash, bytes);
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
pub const Reference = struct {
    resource: u64,
    object: u64,
    principal: u64,
    operation: u64,
    digest: [32]u8,
    pub fn validate(self: Reference) !void {
        if (self.resource == 0 or self.resource > p.max_counter or self.object == 0 or self.principal > p.max_counter or self.operation == 0) return error.InvalidTableWrite;
    }
    pub fn key(self: Reference) p.Value {
        var bytes: [26]u8 = undefined;
        bytes[0..2].* = "\x00W".*;
        std.mem.writeInt(u64, bytes[2..10], self.object, .big);
        std.mem.writeInt(u64, bytes[10..18], self.principal, .big);
        std.mem.writeInt(u64, bytes[18..26], self.operation, .big);
        return p.Value.init(&bytes) catch unreachable;
    }
};
pub const Status = struct {
    pub const Route = enum(u8) { point = 1, statement = 2, alter = 3 };
    reference: Reference,
    admitted_input: u64,
    completed_input: u64 = 0,
    basis_revision: u64,
    first_record: u64,
    end_record: u64,
    matched: u64 = 0,
    changed: u64 = 0,
    route: Route = .point,
    state: enum(u8) { building = 1, applied = 2, rejected = 3, cancelled = 4 },
    rejection: enum(u8) { none = 0, row_exists = 1, row_identity_exists = 2, null_not_allowed = 3, missing_required_field = 4, character_limit_exceeded = 5, overflow = 6, inexact = 7 } = .none,
    pub fn validate(self: Status) !void {
        try self.reference.validate();
        if (self.admitted_input == 0 or self.admitted_input > p.max_counter or self.completed_input > p.max_counter or self.basis_revision == 0 or
            self.first_record == 0 or self.end_record < self.first_record or self.changed > self.matched) return error.InvalidTableWriteStatus;
        if ((self.state == .building) != (self.completed_input == 0)) return error.InvalidTableWriteStatus;
        if (self.completed_input != 0 and self.completed_input < self.admitted_input) return error.InvalidTableWriteStatus;
        if ((self.state == .rejected) != (self.rejection != .none)) return error.InvalidTableWriteStatus;
        if (self.state == .building and self.end_record == self.first_record) return error.InvalidTableWriteStatus;
        if ((self.state == .rejected or self.state == .cancelled) and (self.matched != 0 or self.changed != 0)) return error.InvalidTableWriteStatus;
        if (self.route == .point and self.matched > 1) return error.InvalidTableWriteStatus;
        if (self.route == .alter and (self.matched != 0 or self.changed != 0)) return error.InvalidTableWriteStatus;
    }
    pub fn encode(self: Status) !p.Value {
        try self.validate();
        var bytes: [159]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("STW1");
        try out.writeAll(&definition());
        inline for (.{ "resource", "object", "principal", "operation" }) |name| try out.writeInt(u64, @field(self.reference, name), .little);
        try out.writeAll(&self.reference.digest);
        inline for (.{ "admitted_input", "completed_input", "basis_revision", "first_record", "end_record", "matched", "changed" }) |name| try out.writeInt(u64, @field(self, name), .little);
        try out.writeAll(&.{ @backingInt(self.state), @backingInt(self.rejection), @backingInt(self.route) });
        return p.Value.init(out.buffered());
    }
    pub fn decode(value: p.Value) !Status {
        try value.validate();
        if (value.len != 159 or !std.mem.eql(u8, value.data[0..4], "STW1")) return error.InvalidTableWriteStatus;
        if (!std.mem.eql(u8, value.data[4..36], &definition())) return error.IncompatibleTableStorage;
        var in: std.Io.Reader = .fixed(value.data[36..value.len]);
        var result: Status = undefined;
        inline for (.{ "resource", "object", "principal", "operation" }) |name| @field(result.reference, name) = try in.takeInt(u64, .little);
        result.reference.digest = (try in.take(32))[0..32].*;
        inline for (.{ "admitted_input", "completed_input", "basis_revision", "first_record", "end_record", "matched", "changed" }) |name| @field(result, name) = try in.takeInt(u64, .little);
        result.state = std.enums.fromInt(@FieldType(Status, "state"), try in.takeByte()) orelse return error.InvalidTableWriteStatus;
        result.rejection = std.enums.fromInt(@FieldType(Status, "rejection"), try in.takeByte()) orelse return error.InvalidTableWriteStatus;
        result.route = std.enums.fromInt(Status.Route, try in.takeByte()) orelse return error.InvalidTableWriteStatus;
        try result.validate();
        return result;
    }
};
/// Call only after the current owner policy permits this receipt disclosure.
pub fn status(source: anytype, reference: Reference) !?Status {
    try reference.validate();
    if (source.view.resource != reference.resource) return error.CrossResourceTransaction;
    const result = try Status.decode((try source.read(reference.key())) orelse return null);
    if (!std.meta.eql(result.reference, reference)) return error.TableWriteIdentityConflict;
    return result;
}
fn record(turn: *Turn, result: Status) !void {
    try turn.write(result.reference.key(), try result.encode());
}
fn increment(value: u64) !u64 {
    return std.math.add(u64, value, 1) catch return error.TableCapacity;
}
fn writeCount(turn: *const Turn) usize {
    var count: usize = 0;
    for (turn.decision.mutations) |slot| count += @intFromBool(slot != null);
    return count;
}
fn completion(turn: *Turn, head: Head, result: Status, data: Data.Candidate, request: Request) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    var after = head;
    after.revision = try increment(head.revision);
    after.index = data.data.index;
    after.pending = 0;
    after.next_record = result.end_record;
    after.rows = switch (request.change) {
        .insert => try increment(head.rows),
        .update, .patch => head.rows,
        .delete, .delete_key => std.math.sub(u64, head.rows, data.changed) catch return error.InvalidTableHead,
    };
    var accepted = result;
    accepted.state = .applied;
    accepted.completed_input = turn.delivery.input.position;
    try head.replace(turn, after);
    try record(turn, accepted);
    return accepted;
}
fn checkPending(head: Head, result: Status) !void {
    if (head.pending != result.first_record or head.next_record != result.end_record or head.revision != try increment(result.basis_revision) or head.retired) return error.TableWriteBasisChanged;
}
/// A returned state describes this PRIVATE proposal. Commit it before reporting
/// it as durable. Re-run exact intent after acquiring a new captured turn; a
/// terminal receipt never re-reads or rebinds the current Table/schema.
pub fn step(allocator: std.mem.Allocator, turn: *Turn, request: Request) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    const reference = try request.reference(allocator);
    const previous = try status(turn, reference);
    if (previous) |result| if (result.route != .point) return error.InvalidTableWriteStatus;
    if (previous) |result| if (result.state != .building) return result;
    const head = try Head.load(turn, request.schema.object);
    if (head.retired) return error.TableRetired;
    if (previous) |result| try checkPending(head, result) else if (head.pending != 0) return error.TableBusy;
    var schema = try head.readSchema(allocator, turn);
    defer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &try request.schema.fingerprint())) return error.TableSchemaChanged;
    const pages: Pages = .{ .resource = request.resource, .object = request.schema.object };
    var reader: Pages.Reader(*Turn) = .{ .pages = pages, .source = turn };
    const first = if (previous) |result| result.first_record else head.next_record;
    const end = if (previous) |result| result.end_record else std.math.add(u64, first, Candidate.max_records) catch return error.TableCapacity;
    var overlay = try Candidate.Overlay(*@TypeOf(reader)).init(allocator, &reader, first, end);
    defer overlay.deinit();
    const data: Data = .{ .schema = schema.schema, .index = head.index };
    var result = previous orelse Status{
        .reference = reference,
        .admitted_input = turn.delivery.input.position,
        .basis_revision = head.revision,
        .first_record = first,
        .end_record = first,
        .state = .building,
    };
    const changed = apply(data, allocator, &overlay, request.change) catch |err| {
        if (previous != null or (err != error.RowExists and err != error.RowIdentityExists)) return err;
        result.state = .rejected;
        result.completed_input = turn.delivery.input.position;
        result.rejection = if (err == error.RowExists) .row_exists else .row_identity_exists;
        try record(turn, result);
        return result;
    };
    _ = try overlay.finish(changed.data.index);
    if (previous != null and (overlay.nextId() != result.end_record or changed.matched != result.matched or changed.changed != result.changed)) return error.TableWriteBasisChanged;
    result.end_record = overlay.nextId();
    result.matched = changed.matched;
    result.changed = changed.changed;

    if (previous == null) {
        const fast_before = turn.decision;
        const ready = stageAll(turn, pages, &overlay) catch |err| blk: {
            if (err != error.MutationBudgetExceeded) return err;
            break :blk false;
        };
        if (ready) {
            if (completion(turn, head, result, changed, request)) |accepted| return accepted else |err| if (err != error.MutationBudgetExceeded) return err;
        }
        // No accepted input/head exists yet. Roll back the attempted private
        // fast path before reserving the immutable interval durably.
        turn.decision = fast_before;
        if (result.end_record == result.first_record) return error.MutationBudgetExceeded;
        var reserved = head;
        reserved.revision = try increment(head.revision);
        reserved.next_record = result.end_record;
        reserved.pending = result.first_record;
        try head.replace(turn, reserved);
        try record(turn, result);
        return result;
    }

    const prior_writes = writeCount(turn);
    const ready = stageAll(turn, pages, &overlay) catch |err| {
        if (err != error.MutationBudgetExceeded or writeCount(turn) == prior_writes) return err;
        return result;
    };
    if (!ready) return result;
    return completion(turn, head, result, changed, request) catch |err| {
        if (err != error.MutationBudgetExceeded or writeCount(turn) == prior_writes) return err;
        return result;
    };
}
fn apply(data: Data, allocator: std.mem.Allocator, overlay: anytype, change: Change) !Data.Candidate {
    return switch (change) {
        .insert => |row| data.insert(allocator, overlay, row),
        .update => |row| data.update(allocator, overlay, row),
        .delete => |id| data.delete(allocator, overlay, id),
        .delete_key => |key| if (try data.findKey(allocator, overlay, key)) |id| data.delete(allocator, overlay, id) else .{ .data = data, .matched = 0, .changed = 0 },
        .patch => |patch| blk: {
            const id = try data.findKey(allocator, overlay, patch.key) orelse break :blk .{ .data = data, .matched = 0, .changed = 0 };
            var previous = (try data.get(allocator, overlay, id)) orelse return error.InvalidTableIndex;
            defer previous.deinit();
            var cells: [f.TableSchema.max_columns]Cell = undefined;
            const row = try data.schema.update(previous.row().cells, patch.assignments, &cells);
            break :blk data.update(allocator, overlay, .{ .identity = id, .cells = row });
        },
    };
}
fn stageAll(turn: *Turn, pages: Pages, overlay: anytype) !bool {
    for (overlay.records.items) |item| if (item.reachable) {
        if (try pages.stage(turn, .{ .id = item.id, .spec = item.spec }, item.bytes) == .progress) return false;
    };
    return true;
}
/// Cancellation closes only this reserved Table candidate. It retains immutable
/// IDs/pages and exact evidence; physical cleanup is a separate owner operation.
pub fn cancel(turn: *Turn, reference: Reference) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    var result = (try status(turn, reference)) orelse return error.TableWriteNotFound;
    if (result.route != .point) return error.InvalidTableWriteStatus;
    if (result.state != .building) return result;
    const head = try Head.load(turn, reference.object);
    try checkPending(head, result);
    var after = head;
    after.revision = try increment(head.revision);
    after.pending = 0;
    result.state = .cancelled;
    result.completed_input = turn.delivery.input.position;
    result.matched = 0;
    result.changed = 0;
    try head.replace(turn, after);
    try record(turn, result);
    return result;
}
