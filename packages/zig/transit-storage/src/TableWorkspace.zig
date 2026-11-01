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
    matched: u64,
    affected: u64,

    pub fn validate(self: State) !void {
        try self.begin.validate();
        try self.begin.identity.requireObject(self.root.interpretation.object);
        try self.source.owner.validate();
        try self.source.content.validate();
        try self.root.validate();
        if (!std.meta.eql(self.source.owner, self.begin.identity.begin) or self.root.retired or self.root.next_lsn == 0 or
            self.last_statement > self.begin.limits.statements or (self.changed and self.last_statement == 0) or
            self.root.pins != null or self.root.history_pins != null or self.root.recovery != null or self.root.pending != null or self.root.transaction != null or
            self.affected > self.matched or self.changed != (self.affected != 0))
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
matched: u64,
affected: u64,

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
    return .{ .table = table, .memory = memory, .owner = owner, .begin = begin, .source = source, .last_statement = last, .changed = if (previous) |prior| prior.changed else false, .matched = if (previous) |prior| prior.matched else 0, .affected = if (previous) |prior| prior.affected else 0 };
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
    return .{ .definition = p.Growth.current_definition, .begin = self.begin, .source = self.source, .root = self.table.root, .last_statement = self.last_statement, .changed = self.changed, .matched = self.matched, .affected = self.affected };
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

/// A KV statement uses the same private workspace, operation receipts and
/// savepoint frontier. It cannot publish a KV WAL record before the decision.
pub fn executeKV(self: *Self, statement: x.Statement, binding: d.Binding, changes: []const @import("KVPartition.zig").Change, guard: P.Guard) !Outcome {
    if (self.table.root.kind != .kv) return error.DataKindMismatch;
    self.memory.exhausted = false;
    return self.executeKVBounded(statement, binding, changes, guard) catch |err| return self.memoryFailure(err);
}

fn executeKVBounded(self: *Self, statement: x.Statement, binding: d.Binding, changes: []const @import("KVPartition.zig").Change, guard: P.Guard) !Outcome {
    var scratch: std.heap.ArenaAllocator = .init(self.memory.allocator());
    defer scratch.deinit();
    const lowered = try @import("KVPartition.zig").lower(scratch.allocator(), self.table.declaration.schema.schema, binding, changes);
    return self.executeBounded(statement, .{ .binding = binding, .interpretation = self.table.root.declared(), .changes = lowered, .ingestion = .bulk }, guard);
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
            self.matched = try std.math.add(u64, self.matched, value.outcome.matched);
            self.affected = try std.math.add(u64, self.affected, value.outcome.affected);
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
/// Restore data while preserving every consumed operation, statement and segment
/// frontier. This pure transition also serves paged catalog-owned rollback.
pub fn restore(current: State, saved: State) !State {
    try current.validate();
    try saved.validate();
    if (!std.meta.eql(saved.begin, current.begin) or !std.meta.eql(saved.source, current.source) or
        !std.meta.eql(saved.root.declared(), current.root.declared()) or saved.root.partition != current.root.partition or
        saved.root.next_lsn > current.root.next_lsn or saved.last_statement > current.last_statement)
        return error.TransactionIdentityConflict;
    var restored = saved;
    restored.last_statement = current.last_statement;
    restored.root.next_lsn = try std.math.add(u64, current.root.next_lsn, 1);
    restored.root.changed_lsn = restored.root.next_lsn;
    restored.root.next_segment = current.root.next_segment;
    restored.root.receipts = current.root.receipts;
    restored.root.operations = current.root.operations;
    restored.root.pending = current.root.pending;
    try restored.validate();
    return restored;
}
pub fn rollback(self: *Self, saved: State) !void {
    const restored = try restore(self.state(), saved);
    self.table.root = restored.root;
    self.changed = restored.changed;
    self.matched = restored.matched;
    self.affected = restored.affected;
    self.table.index.clearCache();
}
