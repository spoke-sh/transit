//! Private copy-on-write evaluation over an exact retained Table root. The host
//! retains published workspace roots and conflict dependencies independently.
const std = @import("std");
const p = @import("transit_protocol");
const x = p.Transaction;
const d = p.DataLifecycle;
const P = @import("TablePartition.zig");
const Dml = @import("TableDmlIntent.zig");
const Declaration = @import("TableDeclaration.zig");
const MemoryBudget = @import("transit_fuze").MemoryBudget;
const Self = @This();

pub const State = struct {
    definition: p.Growth.Definition,
    begin: x.Begin,
    source: P.SnapshotHandle,
    root: P.Root,
    /// A private evaluator position, never a Table acceptance or commit LSN.
    last_statement: u64,
    changed: bool,

    pub fn validate(self: State) !void {
        try self.begin.validate();
        try self.begin.identity.requireObject(self.root.interpretation.object);
        try self.source.owner.validate();
        try self.source.content.validate();
        try self.root.validate();
        if (!std.meta.eql(self.source.owner, self.begin.identity.begin) or self.root.retired or self.root.next_lsn == 0 or
            self.last_statement > self.begin.limits.statements or (self.changed and self.last_statement == 0) or
            self.root.pins != null or self.root.history_pins != null or self.root.recovery != null or self.root.pending != null)
            return error.InvalidTransactionWorkspace;
    }
};

pub const Outcome = union(enum) {
    provisional: struct { statement: x.Statement, matched: u64, affected: u64 },
    rejected: struct { statement: x.Statement, reason: @FieldType(P.Operation, "reason") },
};

table: P,
/// Stable address: Table caches and builders retain this allocator across calls.
memory: *MemoryBudget,
/// The embedding host serializes this borrowed owner's lifetime and refresh.
owner: *P,
begin: x.Begin,
source: P.SnapshotHandle,
last_statement: u64,
changed: bool,

/// The source owner validates the live pin and current disclosure rights before
/// a workspace can read it. Restoration rechecks the same retained source.
pub fn init(allocator: std.mem.Allocator, owner: *P, begin: x.Begin, source: P.SnapshotHandle, previous: ?State, guard: P.Guard) !Self {
    try begin.validate();
    if (begin.limits.resident_bytes <= @sizeOf(MemoryBudget)) return error.TransactionMemoryLimit;
    const memory = try allocator.create(MemoryBudget);
    errdefer allocator.destroy(memory);
    memory.* = .{ .parent = allocator, .limit = @intCast(begin.limits.resident_bytes - @sizeOf(MemoryBudget)) };
    return initBounded(memory, owner, begin, source, previous, guard) catch |err| {
        std.debug.assert(memory.used == 0);
        return if (err == error.OutOfMemory and memory.exhausted) error.TransactionMemoryLimit else err;
    };
}

fn initBounded(memory: *MemoryBudget, owner: *P, begin: x.Begin, source: P.SnapshotHandle, previous: ?State, guard: P.Guard) !Self {
    const allocator = memory.allocator();
    if (!std.meta.eql(source.owner, begin.identity.begin)) return error.TransactionIdentityConflict;
    var snapshot = try owner.inspectSnapshot(allocator, source, guard);
    defer snapshot.deinit();
    try begin.identity.requireObject(snapshot.root.interpretation.object);
    var declaration = try Declaration.load(allocator, owner.objects, snapshot.root.declared());
    defer declaration.deinit();
    var options = owner.options;
    options.control = null;
    options.build_resident_bytes = @intCast(@min(options.build_resident_bytes, begin.limits.resident_bytes));
    options.index_work_bytes = @intCast(@min(options.index_work_bytes, begin.limits.resident_bytes));
    var table = try P.init(allocator, snapshot.root.partition, declaration.definition, owner.log, owner.objects, options);
    errdefer table.deinit();
    table.workspace = true;
    table.root = snapshot.root;
    table.recovery_required = false;
    var last: u64 = 0;
    if (previous) |prior| {
        try prior.validate();
        if (!std.meta.eql(prior.begin, begin) or !std.meta.eql(prior.source, source) or
            !std.meta.eql(prior.root.declared(), snapshot.root.declared()) or prior.root.partition != snapshot.root.partition or
            prior.root.next_lsn < snapshot.root.next_lsn or prior.last_statement > begin.limits.statements)
            return error.TransactionIdentityConflict;
        table.root = prior.root;
        last = prior.last_statement;
    }
    return .{ .table = table, .memory = memory, .owner = owner, .begin = begin, .source = source, .last_statement = last, .changed = if (previous) |prior| prior.changed else false };
}

pub fn deinit(self: *Self) void {
    self.table.deinit();
    std.debug.assert(self.memory.used == 0);
    self.memory.parent.destroy(self.memory);
    self.* = undefined;
}

/// Lifetime heap peak, including the stable budget context. Borrowed owner,
/// provider and caller-owned result allocations have independent owners.
pub fn residentPeak(self: *const Self) usize {
    return self.memory.peak + @sizeOf(MemoryBudget);
}

pub fn state(self: *const Self) State {
    return .{ .definition = p.Growth.current_definition, .begin = self.begin, .source = self.source, .root = self.table.root, .last_statement = self.last_statement, .changed = self.changed };
}

fn requireSource(self: *Self, guard: P.Guard) !void {
    const current = try self.owner.pinState(self.source.owner, guard);
    if (current.released) return error.TableSnapshotReleased;
    if (!std.meta.eql(current.handle, @as(?P.SnapshotHandle, self.source))) return error.TableSnapshotNotPinned;
}

pub fn get(self: *Self, allocator: std.mem.Allocator, key: []const u8, guard: P.Guard) !?P.OwnedRow {
    self.memory.exhausted = false;
    try self.requireSource(guard);
    return self.table.get(allocator, key, guard) catch |err| return self.memoryFailure(err);
}

/// The caller publishes the returned private state through its transaction
/// owner. Even a successful statement result is explicitly provisional.
pub fn execute(self: *Self, statement: x.Statement, request: Dml.Request, guard: P.Guard) !Outcome {
    self.memory.exhausted = false;
    return self.executeBounded(statement, request, guard) catch |err| return self.memoryFailure(err);
}

fn memoryFailure(self: *const Self, err: anyerror) anyerror {
    return if (err == error.OutOfMemory and self.memory.exhausted) error.TransactionMemoryLimit else err;
}

fn executeBounded(self: *Self, statement: x.Statement, request: Dml.Request, guard: P.Guard) !Outcome {
    try self.requireSource(guard);
    try statement.validate();
    try request.validate();
    if (self.begin.mode == .read_only) return error.ReadOnlyTransaction;
    if (!std.meta.eql(statement.transaction, self.begin.identity) or
        !std.meta.eql(request.binding.identity.scope, self.begin.identity.begin.scope) or
        request.binding.identity.principal != self.begin.identity.begin.principal or
        request.binding.identity.operation == self.begin.identity.begin.operation or
        !std.mem.eql(u8, &statement.intent, &request.binding.intent)) return error.TransactionIdentityConflict;
    if (statement.sequence <= self.last_statement) return error.TransactionStatementConflict;
    if (statement.sequence > self.begin.limits.statements) return error.TransactionStatementLimit;
    if (request.ingestion != .bulk) return error.InvalidTransactionWorkspace;
    if (try self.owner.operationState(request.binding, guard) != .not_observed) return error.TransactionStatementConflict;
    if (try self.table.operationState(request.binding, guard) != .not_observed) return error.TransactionStatementConflict;
    // Sequence consumption is independent of data-root rollback. A failed
    // private statement cannot make its sequence available for another request.
    self.last_statement = statement.sequence;
    return switch (try self.table.commit(request, guard)) {
        .committed => |value| blk: {
            self.changed = self.changed or value.outcome.affected != 0;
            break :blk .{ .provisional = .{ .statement = statement, .matched = value.outcome.matched, .affected = value.outcome.affected } };
        },
        .rejected => |value| .{ .rejected = .{ .statement = statement, .reason = value.reason } },
        else => error.InvalidTransactionWorkspace,
    };
}

/// Restore only private data and evaluation roots. The host preserves its
/// monotonic statement counter, read dependencies, savepoint directory and
/// cursor invalidation evidence; this operation cannot decide a transaction.
pub fn rollback(self: *Self, saved: State) !void {
    try saved.validate();
    if (!std.meta.eql(saved.begin, self.begin) or !std.meta.eql(saved.source, self.source) or
        !std.meta.eql(saved.root.declared(), self.table.root.declared()) or saved.root.partition != self.table.root.partition or
        saved.root.next_lsn > self.table.root.next_lsn or saved.last_statement > self.last_statement)
        return error.TransactionIdentityConflict;
    const current = self.table.root;
    var restored = saved.root;
    restored.next_lsn = try std.math.add(u64, current.next_lsn, 1);
    restored.changed_lsn = restored.next_lsn;
    restored.next_segment = current.next_segment;
    restored.receipts = current.receipts;
    restored.operations = current.operations;
    restored.pending = current.pending;
    self.table.root = restored;
    self.changed = saved.changed;
    self.table.index.clearCache();
}
