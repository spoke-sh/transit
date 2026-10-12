//! Complete Table transaction headers and bounded paired row changes. The
//! caller owns current authorization, source retention and durable progress.
const std = @import("std");
const f = @import("transit_fuze");
const History = @import("TableHistory.zig");
const Data = @import("TableData.zig");
const Pages = @import("TablePages.zig");
pub const Transaction = struct {
    before: History.Record,
    after: History.Record,
    pub fn validate(self: Transaction) !void {
        try self.before.validate();
        try self.after.validate();
        if (self.before.head.resource != self.after.head.resource or self.before.head.object != self.after.head.object or
            self.before.head.retired or self.after.head.revision != (std.math.add(u64, self.before.head.revision, 1) catch return error.InvalidTableHistory) or
            self.before.committed >= self.after.committed) return error.InvalidTableHistory;
    }
};
/// The initial snapshot is History.current at a frozen authorized resource cut.
/// Resume from its exact record; only acknowledge this successor after all its
/// paired changes and the consumer's progress have committed together.
pub fn next(source: anytype, previous: History.Record) !?Transaction {
    try previous.validate();
    const upper = try History.current(source, previous.head.object);
    const original = try History.revision(source, upper, previous.head.revision);
    if (!(try original.encode()).eql(try previous.encode())) return error.TableHistoryConflict;
    if (previous.head.revision == upper.head.revision) return null;
    const result: Transaction = .{ .before = previous, .after = try History.revision(source, upper, previous.head.revision + 1) };
    try result.validate();
    return result;
}
pub const Change = struct {
    identity: f.TableRow.Identity,
    before: ?f.TableRow.Owned = null,
    after: ?f.TableRow.Owned = null,
    pub fn deinit(self: *Change) void {
        if (self.before) |*row| row.deinit();
        if (self.after) |*row| row.deinit();
        self.* = undefined;
    }
};
pub const Step = union(enum) { progress, change: Change, complete };
pub const Cursor = struct {
    after: ?f.TableRow.Identity = null,
    examined: u64 = 0,
    changes: u64 = 0,
    complete: bool = false,
};
pub const Diff = struct {
    allocator: std.mem.Allocator,
    transaction: Transaction,
    before: f.TableSchema.Owned,
    after: f.TableSchema.Owned,
    pub fn open(allocator: std.mem.Allocator, source: anytype, transaction: Transaction) !Diff {
        try transaction.validate();
        if (source.view.resource != transaction.after.head.resource or source.view.revision < transaction.after.committed) return error.InvalidTableHistory;
        var before = try transaction.before.head.readSchema(allocator, source);
        errdefer before.deinit();
        const after = try transaction.after.head.readSchema(allocator, source);
        return .{ .allocator = allocator, .transaction = transaction, .before = before, .after = after };
    }
    pub fn deinit(self: *Diff) void {
        self.before.deinit();
        self.after.deinit();
        self.* = undefined;
    }
    /// One merge step acquires at most two references and two owned row values.
    /// Unchanged rows return progress; an arbitrarily large no-op transaction
    /// cannot monopolize a handler. Paired updates never split into two steps.
    /// Cursors are trusted owner state, not an unauthenticated public token.
    pub fn step(self: *const Diff, source: anytype, cursor: *Cursor) !Step {
        if (source.view.resource != self.transaction.after.head.resource or source.view.revision < self.transaction.after.committed) return error.InvalidTableHistory;
        if (cursor.changes > cursor.examined) return error.InvalidTableHistoryCursor;
        if (cursor.complete) return .complete;
        const same_schema = std.meta.eql(self.transaction.before.head.schema.spec, self.transaction.after.head.schema.spec);
        // Reservations, no-op writes and retirement can advance progress without
        // traversing an arbitrarily large unchanged relation.
        if (same_schema and std.meta.eql(self.transaction.before.head.index, self.transaction.after.head.index)) {
            cursor.complete = true;
            return .complete;
        }
        const old: Data = .{ .schema = self.before.schema, .index = self.transaction.before.head.index };
        const new: Data = .{ .schema = self.after.schema, .index = self.transaction.after.head.index };
        var reader: Pages.Reader(@TypeOf(source)) = .{ .pages = .{ .resource = source.view.resource, .object = self.transaction.after.head.object }, .source = source };
        var left: [1]Data.RowReference = undefined;
        var right: [1]Data.RowReference = undefined;
        const old_count = try old.references(&reader, cursor.after, &left);
        const new_count = try new.references(&reader, cursor.after, &right);
        if (old_count == 0 and new_count == 0) {
            cursor.complete = true;
            return .complete;
        }
        const order: std.math.Order = if (old_count == 0) .gt else if (new_count == 0) .lt else std.mem.order(u8, &try left[0].identity.encode(), &try right[0].identity.encode());
        const identity = if (order == .gt) right[0].identity else left[0].identity;
        const examined = std.math.add(u64, cursor.examined, 1) catch return error.TableCapacity;
        if (same_schema and order == .eq and std.meta.eql(left[0].blob.spec, right[0].blob.spec)) {
            cursor.after = identity;
            cursor.examined = examined;
            return .progress;
        }
        const changes = std.math.add(u64, cursor.changes, 1) catch return error.TableCapacity;
        var change: Change = .{ .identity = identity };
        errdefer change.deinit();
        if (order != .gt) change.before = try old.loadReference(self.allocator, &reader, left[0]);
        if (order != .lt) change.after = try new.loadReference(self.allocator, &reader, right[0]);
        cursor.* = .{ .after = identity, .examined = examined, .changes = changes };
        return .{ .change = change };
    }
};
