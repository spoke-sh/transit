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
detail: Detail = .{},
pub const Failure = t.Failure;
pub const Detail = t.Detail;
pub const Outcome = struct { passed: bool, actions: usize, failure: ?Failure = null };

pub fn run(self: *Self, case: anytype) !Outcome {
    const buffer = try self.allocator.alloc(u8, g.fuze.Types.Codec.max_bytes);
    defer self.allocator.free(buffer);
    for (case.actions, 0..) |action, index| {
        self.action = index;
        const failure = if (action.expectation == .workflow) blk: {
            if (action.step != null) return error.TestInvalidExpectation;
            break :blk try self.workflow(action.expectation.workflow);
        } else try self.execute(case.steps[action.step orelse return error.TestInvalidExpectation].sql, action.expectation, buffer);
        if (failure) |reason| return .{ .passed = false, .actions = index + 1, .failure = reason };
    }
    return .{ .passed = true, .actions = case.actions.len };
}
fn execute(self: *Self, sql: []const u8, expectation: t.Expectation, buffer: []u8) !?Failure {
    const session = self.session;
    try session.begin();
    defer session.end();
    const prepared = try session.prepare(sql);
    defer session.destroy(prepared);
    if (prepared.* != .native and prepared.* != .managed) return error.TestUnexpectedStatementOwner;
    if (prepared.fields().len != 0) {
        if (expectation != .complete and expectation != .rows) return error.TestInvalidExpectation;
        const expected = if (expectation == .rows) expectation.rows else null;
        const schema: g.fuze.Types.Type = .{ .structure = prepared.fields() };
        if (expected) |value| if (!std.mem.eql(u8, &try value.schema.fingerprint(), &try schema.fingerprint())) {
            self.detail = .{ .expected_primary = value.values.len, .schema_mismatch = true };
            return .rows;
        };
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
        if (expected) |value| if (!equal or bag.remaining != 0) {
            self.detail = .{ .expected_primary = value.values.len, .observed_primary = observed };
            return .rows;
        };
        return null;
    }
    const completion = (if (prepared.* == .managed) self.managed(sql, prepared) else session.write(prepared, &.{})) catch |err| {
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
        if (!matched) {
            self.detail = .{};
            self.detail.setExpectedReason(@tagName(expectation.refusal));
            self.detail.setObservedReason(@tagName(reason));
            return .refusal_reason;
        }
        return null;
    };
    try completion.validate();
    if (prepared.* != .managed) try session.validateWireCompletion(prepared, completion);
    return switch (expectation) {
        .complete => null,
        .refusal => |expected_refusal| blk: {
            self.detail = .{};
            self.detail.setExpectedReason(@tagName(expected_refusal));
            break :blk .expected_refusal;
        },
        .command => |expected| blk: {
            const counts = completion.counts orelse return error.TestMissingCounts;
            if (counts.matched != expected.matched or counts.changed != expected.changed) {
                self.detail = .{
                    .expected_primary = expected.matched,
                    .expected_secondary = expected.changed,
                    .observed_primary = counts.matched,
                    .observed_secondary = counts.changed,
                };
                break :blk .counts;
            }
            break :blk null;
        },
        .rows, .workflow => error.TestInvalidExpectation,
    };
}

fn managed(self: *Self, sql: []const u8, prepared: *g.Session.Prepared) !g.results.CommandCompletion {
    const session = self.session;
    var token: g.session_protocol.Token = undefined;
    try session.io.randomSecure(&token);
    var fingerprint: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql, &fingerprint, .{});
    var acceptance_possible = false;
    const admitted = try g.StatementOperations.admit(session, prepared, &.{}, token, fingerprint, &acceptance_possible);
    session.operation = admitted.identity.id;
    const reference: g.SessionOperations.Reference = .{ .id = admitted.identity.id, .kind = .dataflow, .nonce = token };
    // Submit once. Settlement advances only the retained operation, exactly as
    // the native SQL service does; an uncertain admission fails this case.
    var interval_ms: u32 = 10;
    while (true) {
        try session.deadline.check(session.io);
        try session.current();
        const observed = try g.StatementOperations.resumeOperation(session, reference);
        if (!std.meta.eql(observed.identity, admitted.identity) or !std.meta.eql(observed.token, token)) return error.TestInvalidTerminal;
        if (observed.phase == .terminal) {
            if (observed.outcome != .applied and observed.outcome != .unchanged) return error.TestProgramStatementFailed;
            const completion = try observed.completion();
            try session.current();
            const verified = try g.StatementOperations.status(session, reference);
            if (!std.meta.eql(completion, try verified.completion())) return error.TestInvalidTerminal;
            return completion;
        }
        try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
        interval_ms = @min(interval_ms * 2, 50);
    }
}

fn workflow(self: *Self, expected: @FieldType(t.Expectation, "workflow")) !?Failure {
    if (expected.observations == 0 or expected.observations > t.max_observations) return error.TestObservationLimit;
    const session = self.session;
    try session.begin();
    defer session.end();
    try g.ManagedOperations.requireProfile(session);
    try session.current();
    const dot = std.mem.indexOfScalar(u8, expected.name, '.');
    const wf_schema = if (dot) |idx| expected.name[0..idx] else null;
    const wf_name = if (dot) |idx| expected.name[idx + 1 ..] else expected.name;
    const declaration = try session.fresh(g.ManagedOperations.programInSchema, .{ session, wf_schema, try g.catalog.TableAuthority.Name.init(wf_name) }) orelse return error.TestMissingProgram;
    defer declaration.deinit();
    var remaining = expected.observations;
    var interval_ms: u32 = 10;
    var last_completed: u64 = 0;
    var last_refused: u64 = 0;
    while (remaining > 0) : (remaining -= 1) {
        try session.deadline.check(session.io);
        session.current() catch |err| if (workflowObservationContended(session.wire.last_rejection, err)) {
            try session.deadline.check(session.io);
            if (remaining > 1) {
                try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
                interval_ms = @min(interval_ms * 2, 50);
            }
            continue;
        } else return err;
        const observed = session.fresh(observeWorkflow, .{ session, declaration.value }) catch |err| if (workflowObservationContended(session.wire.last_rejection, err)) {
            try session.deadline.check(session.io);
            if (remaining > 1) {
                try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
                interval_ms = @min(interval_ms * 2, 50);
            }
            continue;
        } else return err;
        try observed.head.validate();
        last_completed = observed.head.completed;
        last_refused = observed.head.refused;
        if (observed.head.completed > expected.completed or observed.head.refused > expected.refused) {
            self.detail = .{
                .expected_primary = expected.completed,
                .expected_secondary = expected.refused,
                .observed_primary = observed.head.completed,
                .observed_secondary = observed.head.refused,
                .observations = expected.observations,
            };
            return .workflow_counts;
        }
        if (observed.head.completed == expected.completed and observed.head.refused == expected.refused) {
            // Recheck disclosure against the same frozen declaration. A new
            // definition or a namespace permission alone cannot stand in for it.
            session.current() catch |err| if (workflowObservationContended(session.wire.last_rejection, err)) {
                try session.deadline.check(session.io);
                if (remaining > 1) {
                    try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
                    interval_ms = @min(interval_ms * 2, 50);
                }
                continue;
            } else return err;
            const disclosed = session.fresh(observeWorkflow, .{ session, declaration.value }) catch |err| if (workflowObservationContended(session.wire.last_rejection, err)) {
                try session.deadline.check(session.io);
                if (remaining > 1) {
                    try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
                    interval_ms = @min(interval_ms * 2, 50);
                }
                continue;
            } else return err;
            last_completed = disclosed.head.completed;
            last_refused = disclosed.head.refused;
            if (disclosed.head.completed == expected.completed and disclosed.head.refused == expected.refused) return null;
        }
        if (remaining > 1) {
            try session.io.sleep(.fromMilliseconds(interval_ms), .awake);
            interval_ms = @min(interval_ms * 2, 50);
        }
    }
    self.detail = .{
        .expected_primary = expected.completed,
        .expected_secondary = expected.refused,
        .observed_primary = last_completed,
        .observed_secondary = last_refused,
        .observations = expected.observations,
    };
    return .workflow_progress;
}

pub fn workflowObservationContended(rejection: ?g.catalog.protocol.ErrorCode, err: anyerror) bool {
    return g.wire.Client.unavailable(err) or (err == error.Conflict and rejection == .Conflict);
}

fn observeWorkflow(session: *g.Session, declaration: g.direct.ApplicationDeclaration) !g.direct.ManagedApplication.Observation {
    // Match SHOW DATAFLOW's exact definition and metadata-disclosure checks.
    // Permission on the control row alone cannot disclose stale dependencies.
    for (declaration.resources) |resource| try resource.requireCurrent(session.table);
    const manager: g.direct.ManagedApplication = .{ .client = session.table };
    return manager.inspect(declaration);
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
test "workflow observation retry classifies only transient contention" {
    try std.testing.expect(workflowObservationContended(.Conflict, error.Conflict));
    try std.testing.expect(workflowObservationContended(null, error.AuthorityTimeout));
    try std.testing.expect(!workflowObservationContended(null, error.GatewayOwnerUnavailable));
    try std.testing.expect(!workflowObservationContended(.TableDefinitionChanged, error.Conflict));
    try std.testing.expect(!workflowObservationContended(.StaleAuthorizationCredential, error.Conflict));
    try std.testing.expect(!workflowObservationContended(null, error.Conflict));
    try std.testing.expect(!workflowObservationContended(.AuthorizationSubjectDenied, error.AccessDenied));
    try std.testing.expect(!workflowObservationContended(null, error.Canceled));
}
