//! No SQL-text classification, evaluator, result protocol or write replay lives
//! here. Session owns preparation, acceptance, settlement, rows and disclosure.
const std = @import("std");
const g = @import("transit_sql_service");
const t = @import("transit_compiler").Test;
const Self = @This();
allocator: std.mem.Allocator,
session: *g.Session,
rows: usize = 0,
bytes: usize = 0,
action: usize = 0,
pub const Failure = enum { rows, counts, expected_refusal, refusal_reason };
pub const Outcome = struct { passed: bool, actions: usize, failure: ?Failure = null };

pub fn run(self: *Self, case: t.Case) !Outcome {
    const buffer = try self.allocator.alloc(u8, g.fuze.Types.Codec.max_bytes);
    defer self.allocator.free(buffer);
    for (case.actions, 0..) |action, index| {
        self.action = index;
        if (try self.execute(case.steps[action.step].sql, action.expectation, buffer)) |failure| return .{ .passed = false, .actions = index + 1, .failure = failure };
    }
    return .{ .passed = true, .actions = case.actions.len };
}
fn execute(self: *Self, sql: []const u8, expectation: t.Expectation, buffer: []u8) !?Failure {
    const session = self.session;
    try session.begin();
    defer session.end();
    const prepared = try session.prepare(sql);
    defer session.destroy(prepared);
    if (prepared.* != .native) return error.TestUnexpectedStatementOwner;
    if (prepared.fields().len != 0) {
        if (expectation != .complete and expectation != .rows) return error.TestInvalidExpectation;
        const expected = if (expectation == .rows) expectation.rows else null;
        const schema = prepared.native.output.?.type;
        if (expected) |value| if (!std.mem.eql(u8, &try value.schema.fingerprint(), &try schema.fingerprint())) return .rows;
        var bag = try Bag.init(self.allocator, if (expected) |value| value.values else &.{});
        defer bag.deinit();
        const read = try session.openRead(prepared, &.{});
        defer session.closeRead(read);
        var observed: u64 = 0;
        var equal = true;
        while (true) {
            read.resumeWire();
            const batch = try read.nextBatch(32);
            try batch.validate(32);
            for (batch.rows[0..batch.len]) |row| {
                if (self.rows == t.max_rows) return error.TestRowsLimit;
                const bytes = try t.rowBytes(row.?, schema, buffer);
                if (bytes.len > t.max_result_bytes - self.bytes) return error.TestResultBytesLimit;
                self.rows += 1;
                self.bytes += bytes.len;
                observed += 1;
                if (expected != null and !bag.take(bytes)) equal = false;
            }
            if (batch.complete) break;
            // Empty physical batches are not terminal evidence. The session
            // retains its cursor and deadline until verified completion.
        }
        const completion = try read.completion(observed);
        if (completion.rows != observed or read.emitted_rows != observed) return error.TestIncompleteResult;
        var observation: std.heap.ArenaAllocator = .init(self.allocator);
        defer observation.deinit();
        try completion.validate(try read.observation(observation.allocator()));
        read.resumeWire();
        try read.validateDisclosure();
        return if (expected != null and (!equal or bag.remaining != 0)) .rows else null;
    }
    const completion = session.write(prepared, &.{}) catch |err| {
        if (err != error.GatewayMutationRejected or expectation != .refusal) return err;
        const terminal = session.terminal orelse return error.TestMissingTerminal;
        try terminal.validate();
        try session.current();
        if (terminal.kind != .dml or terminal.state != .rejected) return error.TestInvalidTerminal;
        const reason = std.enums.fromInt(@FieldType(g.catalog.storage.TablePartition.Operation, "reason"), terminal.reason) orelse return error.TestInvalidTerminal;
        const matched = switch (expectation.refusal) {
            .duplicate_key => reason == .duplicate_key,
            .check_violation => reason == .check_violation,
        };
        return if (matched) null else .refusal_reason;
    };
    try completion.validate();
    try session.validateWireCompletion(prepared, completion);
    return switch (expectation) {
        .complete => null,
        .refusal => .expected_refusal,
        .command => |expected| blk: {
            const counts = completion.counts orelse return error.TestMissingCounts;
            break :blk if (counts.matched == expected.matched and counts.changed == expected.changed) null else .counts;
        },
        .rows => error.TestInvalidExpectation,
    };
}

/// Keys borrow the compiler product. Hash collisions still compare complete
/// canonical bytes; duplicates have independent counts. Observed rows are not
/// retained across the next session batch.
pub const Bag = struct {
    values: std.StringHashMap(usize),
    remaining: usize = 0,
    pub fn init(a: std.mem.Allocator, expected: []const []const u8) !Bag {
        var self: Bag = .{ .values = .init(a) };
        errdefer self.deinit();
        if (expected.len > t.max_rows) return error.TestRowsLimit;
        for (expected) |bytes| {
            const entry = try self.values.getOrPut(bytes);
            if (!entry.found_existing) entry.value_ptr.* = 0;
            entry.value_ptr.* += 1;
            self.remaining += 1;
        }
        return self;
    }
    pub fn take(self: *Bag, bytes: []const u8) bool {
        const count = self.values.getPtr(bytes) orelse return false;
        if (count.* == 0) return false;
        count.* -= 1;
        self.remaining -= 1;
        return true;
    }
    pub fn deinit(self: *Bag) void {
        self.values.deinit();
    }
};
test "row bags retain duplicates and compare exact bytes independent of order" {
    var bag = try Bag.init(std.testing.allocator, &.{ "null", "a", "a", "A" });
    defer bag.deinit();
    try std.testing.expect(bag.take("a"));
    try std.testing.expect(!bag.take("NULL"));
    try std.testing.expect(bag.take("A"));
    try std.testing.expect(bag.take("null"));
    try std.testing.expectEqual(1, bag.remaining);
    try std.testing.expect(bag.take("a"));
    try std.testing.expect(!bag.take("a"));
    try std.testing.expectEqual(0, bag.remaining);
}
test "empty expected rows require zero observed rows" {
    var bag = try Bag.init(std.testing.allocator, &.{});
    defer bag.deinit();
    try std.testing.expectEqual(0, bag.remaining);
    try std.testing.expect(!bag.take("row"));
}
