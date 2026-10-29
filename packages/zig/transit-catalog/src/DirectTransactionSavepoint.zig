//! Durable named private-root checkpoints. Rollback keeps every accepted
//! statement/operation claim and publishes restored data only when complete.
const std = @import("std");
const c = @import("root.zig");
const s = c.storage;
const p = c.protocol;
const d = p.DataLifecycle;
const W = c.DirectTransactionWorkspace;
const R = c.DirectRecord;
const pages = s.TreeStore.pages;
pub const saved_format: u32 = 0x54585331;
pub const result_format: u32 = 0x54584331;
pub const Request = struct {
    transaction: p.Transaction.Identity,
    operation: d.Operation,
    sequence: u64,
    basis: d.Position,
    action: union(enum) { create: c.TableAuthority.Name, rollback: c.TableAuthority.Name, release: c.TableAuthority.Name },
    pub fn validate(self: Request) !void {
        try self.transaction.validate();
        try self.operation.validate();
        try self.basis.validate();
        switch (self.action) {
            inline else => |value| try value.validate(),
        }
        if (self.sequence == 0 or self.basis.next_lsn == 0 or
            !std.meta.eql(self.transaction.begin.scope, self.operation.scope) or self.transaction.begin.principal != self.operation.principal or
            self.transaction.begin.operation == self.operation.operation) return error.InvalidTransactionSavepoint;
    }
    pub fn name(self: Request) c.TableAuthority.Name {
        return switch (self.action) {
            inline else => |value| value,
        };
    }
};
pub const Saved = struct {
    definition: p.Growth.Definition,
    transaction: p.Transaction.Identity,
    sequence: u64,
    name: c.TableAuthority.Name,
    depth: u64,
    tables: ?pages.Reference,
    last_statement: u64,
    previous: ?R.Reference,
    pub fn validate(self: Saved, head: W.Head) !void {
        try self.name.validate();
        if (!std.meta.eql(self.transaction, head.acquired.cut.begin.identity) or self.sequence == 0 or self.sequence > head.last_control or
            self.depth == 0 or self.depth > head.acquired.cut.begin.limits.savepoints or self.last_statement > head.last_statement or
            (self.previous == null) != (self.depth == 1)) return error.InvalidTransactionSavepoint;
    }
};
pub const Result = struct {
    request: Request,
    accepted: d.Position,
    completed: ?d.Position,
    pub fn validate(self: Result) !void {
        try self.request.validate();
        try self.accepted.validate();
        if (self.accepted.partition != self.request.basis.partition or self.accepted.next_lsn <= self.request.basis.next_lsn) return error.InvalidTransactionSavepoint;
        if (self.completed) |position| {
            try position.validate();
            if (position.partition != self.accepted.partition or position.next_lsn < self.accepted.next_lsn) return error.InvalidTransactionSavepoint;
        }
    }
};
pub const Pending = struct { result: Result, target: R.Reference, after: ?pages.Key, tables: ?pages.Reference };

pub fn load(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, scope: R.Scope, reference: R.Reference, head: W.Head) !Saved {
    const saved = try W.load(Saved, allocator, objects, reference, scope, saved_format);
    try saved.validate(head);
    return saved;
}
const Found = struct { reference: R.Reference, saved: Saved };
fn find(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, scope: R.Scope, head: W.Head, name: c.TableAuthority.Name) !Found {
    var next = head.savepoints;
    var depth = head.savepoint_count;
    while (next) |reference| {
        const saved = try load(allocator, objects, scope, reference, head);
        if (saved.depth != depth) return error.InvalidTransactionSavepoint;
        if (std.meta.eql(saved.name, name)) return .{ .reference = reference, .saved = saved };
        next = saved.previous;
        depth -= 1;
    }
    return error.TransactionSavepointMissing;
}

/// The catalog wrapper owns publication exclusion, current policy and the
/// temporary resident budget. At most steps Table roots are restored per call.
pub fn apply(catalog: *c.DirectCatalog, progress: c.DirectClientToken.Progress, request: Request, steps: u16, policy: c.DirectCatalog.Policy, guard: s.TablePartition.Guard) !Result {
    try request.validate();
    var head = try W.recover(catalog.allocator, catalog.data_objects, progress);
    const begin = head.acquired.cut.begin;
    if (!std.meta.eql(request.transaction, begin.identity)) return error.TransactionIdentityConflict;
    const scope = progress.receipt.binding.key.scope();
    var staging: W.Staging = .{ .underlying = catalog.data_objects, .used = head.charged_bytes, .limit = begin.limits.workspace_bytes };
    var index = try s.TreeStore.init(catalog.allocator, staging.objects(), catalog.options.resident_pages);
    defer index.deinit();
    if (try W.get(Result, catalog.allocator, &index, head.controls, request.sequence, scope, result_format)) |result| {
        try result.validate();
        if (!std.meta.eql(result.request, request)) return error.TransactionControlConflict;
        return result;
    }
    if (head.pending != null) return error.TransactionStatementPending;
    if (head.pending_control) |*pending| {
        if (!std.meta.eql(pending.result.request, request)) return error.TransactionControlPending;
        const target = try load(catalog.allocator, catalog.data_objects, scope, pending.target, head);
        var tree: pages.Tree(s.TreeStore) = .{ .store = &index };
        var complete = false;
        for (0..steps) |_| {
            const page = try tree.scan(head.tables, pending.after);
            const entry = page.entries[0] orelse {
                complete = true;
                break;
            };
            const current = try W.load(s.TableWorkspace.State, catalog.allocator, catalog.data_objects, try W.referenceOf(entry.value, scope, W.table_format), scope, W.table_format);
            try current.validate();
            const object = current.root.interpretation.object;
            if (!std.meta.eql(entry.key, try W.idKey(object.object))) return error.InvalidTransactionWorkspace;
            // Recheck current source rights and the original live pin. This
            // reads the unchanged active directory, never partial restoration.
            const checked = try catalog.transactionTableState(progress.receipt.binding.key, object, policy);
            if (!std.meta.eql(checked, current)) return error.InvalidTransactionWorkspace;
            const saved = try W.get(s.TableWorkspace.State, catalog.allocator, &index, target.tables, object.object, scope, W.table_format) orelse original: {
                var frozen = try s.TableSnapshot.load(catalog.allocator, catalog.data_objects, current.source);
                defer frozen.deinit();
                break :original s.TableWorkspace.State{ .definition = p.Growth.current_definition, .begin = current.begin, .source = current.source, .root = frozen.root, .last_statement = 0, .changed = false, .matched = 0, .affected = 0 };
            };
            const restored = try s.TableWorkspace.restore(current, saved);
            const record = try W.stage(staging.objects(), scope, W.table_format, restored);
            pending.tables = try W.put(&index, pending.tables, object.object, record, catalog.options.index_work_bytes);
            pending.after = entry.key;
            if (page.entries[1] == null and page.next == null) {
                complete = true;
                break;
            }
        }
        var result = pending.result;
        if (complete) {
            head.tables = pending.tables;
            head.savepoints = pending.target;
            head.savepoint_count = target.depth;
            head.pending_control = null;
            result.completed = try nextPosition(catalog);
            head.controls = try W.put(&index, head.controls, request.sequence, try W.stage(staging.objects(), scope, result_format, result), catalog.options.index_work_bytes);
        }
        try catalog.publishTransactionWorkspace(progress, &head, &staging, guard);
        return result;
    }
    if (request.sequence != head.last_control + 1) return error.TransactionControlConflict;
    if (request.sequence > begin.limits.statements) return error.TransactionControlLimit;
    if (!std.meta.eql(request.basis, head.revision)) return error.TransactionReadChanged;
    var result: Result = .{ .request = request, .accepted = try nextPosition(catalog), .completed = null };
    const target: ?Found = if (request.action == .create) null else try find(catalog.allocator, catalog.data_objects, scope, head, request.name());
    if (request.action == .create and head.savepoint_count >= begin.limits.savepoints) return error.TransactionSavepointLimit;
    try c.OperationBinding.claimTransactionSavepoint(catalog.allocator, catalog.data_objects, request);
    head.last_control = request.sequence;
    switch (request.action) {
        .create => |name| {
            const saved: Saved = .{ .definition = p.Growth.current_definition, .transaction = begin.identity, .sequence = request.sequence, .name = name, .depth = head.savepoint_count + 1, .tables = head.tables, .last_statement = head.last_statement, .previous = head.savepoints };
            try saved.validate(head);
            head.savepoints = try W.stage(staging.objects(), scope, saved_format, saved);
            head.savepoint_count = saved.depth;
            result.completed = result.accepted;
        },
        .release => {
            head.savepoints = target.?.saved.previous;
            head.savepoint_count = target.?.saved.depth - 1;
            result.completed = result.accepted;
        },
        .rollback => head.pending_control = .{ .result = result, .target = target.?.reference, .after = null, .tables = null },
    }
    if (result.completed != null) head.controls = try W.put(&index, head.controls, request.sequence, try W.stage(staging.objects(), scope, result_format, result), catalog.options.index_work_bytes);
    try catalog.publishTransactionWorkspace(progress, &head, &staging, guard);
    return result;
}
fn nextPosition(catalog: *c.DirectCatalog) !d.Position {
    return .{ .partition = catalog.store.root.configuration.partition, .next_lsn = try std.math.add(u64, catalog.store.root.next_lsn, 1) };
}
