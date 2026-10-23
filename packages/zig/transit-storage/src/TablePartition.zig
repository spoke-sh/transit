//! Single-owner Table acceptance and immutable row indexes. This owner is a
//! storage component: an adapter must provide current authorization and serialize
//! its use. No actor mailbox or native resource-block protocol carries row data.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const TreeStore = @import("TreeStore.zig");
const pages = TreeStore.pages;
const r = @import("TablePartitionRecord.zig");
const Declaration = @import("TableDeclaration.zig");
const Snapshot = @import("TableSnapshot.zig");
const Dml = @import("TableDmlIntent.zig");
const Self = @This();
pub const Root = r.Root;
pub const Outcome = r.Outcome;
pub const Operation = r.Operation;
pub const OperationState = union(enum) { not_observed, admitted: Operation, rejected: Operation, cancelled: Operation, committed: Evidence };
pub const Evidence = struct {
    binding: d.Binding,
    resulting: Declaration.Stored,
    outcome: Outcome,
};
const Changes = @import("TableChanges.zig");
pub const max_changes = Changes.max_changes;
pub const max_row_bytes = Log.max_payload_bytes - r.max_metadata_bytes - r.header_bytes;

/// The service acquires its authorization/retirement fence here and holds it
/// until release. This callback runs for observations and again after staging,
/// immediately before append. A lease supplied by a client is not a Guard.
pub const Guard = struct {
    context: *anyopaque,
    acquire: *const fn (*anyopaque) anyerror!Fence,
    release: *const fn (*anyopaque) void,
    pub const Fence = struct { writer_epoch: u64, policy_epoch: u64 };
};
pub const Options = struct {
    resident_pages: usize = 16,
    index_work_bytes: usize = 64 * 1024 * 1024,
    segment_cache_bytes: usize = f.TSeg.max_segment_bytes,
    /// Total decoded visits across statement passes, independent of Table size.
    statement_scan_rows: u64 = 1_000_000,
    statement_scan_bytes: u64 = 64 * 1024 * 1024,
    /// Same physical namespace, with quota reserved for cancellation/rejection.
    control: ?struct { log: Log.Log, objects: Objects.ObjectStore } = null,
};
pub const Change = Changes.Change;
pub const Ingestion = Changes.Ingestion;
pub const SnapshotHandle = Snapshot.Handle;
pub const PinState = struct {
    position: d.Position,
    retired: bool,
    handle: ?SnapshotHandle,
    released: bool,
};
pub const SnapshotDefinition = Snapshot.Owned;
/// Logical acceptance history is separate from physical flush/pin/control
/// records. A no-op statement still has an accepted operation and source root.
pub const HistoryEntry = struct {
    root: Root,
    receipt: r.Receipt,
    commitment: [32]u8,
};
pub const HistoryPage = struct {
    object: d.Object,
    through: d.Position,
    next: d.Position,
    scanned: u8 = 0,
    entries: [pages.page_entries]?HistoryEntry = @splat(null),
    count: u8 = 0,
};
pub const SnapshotCursor = struct { source: d.Content, after: [f.TableRow.Identity.encoded_bytes]u8 };
pub const ReadLimits = struct {
    rows: u8 = pages.page_entries,
    encoded_bytes: u32 = 4 * 1024 * 1024,
    pub fn validate(self: ReadLimits) !void {
        if (self.rows == 0 or self.rows > pages.page_entries or self.encoded_bytes == 0 or self.encoded_bytes > 16 * 1024 * 1024) return error.InvalidTableReadBudget;
    }
};
pub const SnapshotPage = struct {
    source: SnapshotHandle,
    interpretation: Declaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    rows: [pages.page_entries]?OwnedRow = @splat(null),
    count: u8 = 0,
    encoded_bytes: u32 = 0,
    next: ?SnapshotCursor = null,

    pub fn deinit(self: *SnapshotPage) void {
        for (&self.rows) |*slot| if (slot.*) |*value| value.deinit();
        self.* = undefined;
    }
};
pub const OwnedRow = union(enum) {
    wal: f.TableRow.Owned,
    segment: f.TSeg.OwnedRow,
    pub fn row(self: *const OwnedRow) f.TableRow.Row {
        return switch (self.*) {
            .wal => |*value| value.row(),
            .segment => |*value| value.row(),
        };
    }
    pub fn deinit(self: *OwnedRow) void {
        switch (self.*) {
            inline else => |*value| value.deinit(),
        }
    }
};

allocator: std.mem.Allocator,
log: Log.Log,
objects: Objects.ObjectStore,
index: TreeStore,
declaration: Declaration.Owned,
root: Root,
chain: [32]u8 = @splat(0),
options: Options,
segment_cache: ?CachedSegment = null,
segment_reads: u64 = 0,
row_groups_decoded: u64 = 0,
recovery_required: bool = true,
/// Failure injection at the durable append/reply boundary.
lose_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, partition: u64, definition: Declaration.Definition, log: Log.Log, objects: Objects.ObjectStore, options: Options) !Self {
    try definition.validate();
    if (partition == 0 or options.index_work_bytes == 0 or options.statement_scan_rows == 0 or options.statement_scan_bytes == 0) return error.InvalidTableIdentity;
    var owned = try Declaration.prepare(allocator, definition);
    errdefer owned.deinit();
    var index = try TreeStore.init(allocator, objects, options.resident_pages);
    errdefer index.deinit();
    return .{ .allocator = allocator, .log = log, .objects = objects, .index = index, .declaration = owned, .options = options, .root = emptyRoot(try owned.stored(), partition) };
}

fn emptyRoot(stored: Declaration.Stored, partition: u64) Root {
    return .{ .interpretation = stored.interpretation, .declaration = stored.content, .schema_fingerprint = stored.schema_fingerprint, .retired = stored.retired, .next_segment = 1, .partition = partition, .operations = null, .pending = null, .identities = null };
}

fn requireTransition(before: Root, record: r.Record, operation: ?Operation) !void {
    const after = record.root;
    switch (record.action) {
        inline .mutation, .declaration => |value| {
            const binding = value.binding;
            if (!std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
            if (!std.meta.eql(before.operations, after.operations)) return error.InvalidTableHistory;
            if (record.action == .declaration and before.pending != null) return error.InvalidTableHistory;
            if (operation) |admitted| {
                if (record.action != .mutation or admitted.phase != .admitted) return error.InvalidTableHistory;
                try requireAdmissionBasis(before, admitted);
            } else if (!std.meta.eql(before.pending, after.pending)) return error.InvalidTableHistory;
            if (record.action == .mutation and after.changed_lsn != (if (value.outcome.affected != 0 or binding.action == .create) after.next_lsn else before.changed_lsn)) return error.InvalidTableHistory;
            if (record.action == .mutation and value.outcome.affected == 0 and
                (!std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or
                    before.live_rows != after.live_rows or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
            if (before.next_lsn == 0) {
                if (record.action != .mutation or binding.action != .create or after.interpretation.revision != 1 or after.retired) return error.InvalidTableHistory;
            } else {
                if (before.retired or !std.meta.eql(binding.expected_definition, @as(?d.Definition, before.interpretation))) return error.InvalidTableHistory;
                if (record.action == .mutation) {
                    if (binding.action != .insert and binding.action != .update and binding.action != .delete) return error.InvalidTableHistory;
                    if (!std.meta.eql(before.declared(), after.declared())) return error.InvalidTableHistory;
                } else {
                    if (binding.action != .alter and binding.action != .rename and binding.action != .drop) return error.InvalidTableHistory;
                    if (after.interpretation.revision != try std.math.add(u64, before.interpretation.revision, 1) or after.retired != (binding.action == .drop) or after.live_rows != before.live_rows) return error.InvalidTableHistory;
                    if (binding.action != .alter and (!std.mem.eql(u8, &before.schema_fingerprint, &after.schema_fingerprint) or
                        !std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
                }
            }
            if (operation == null) if (binding.expected_data) |expected| {
                if (!expected.unchangedAt(.{ .partition = before.partition, .next_lsn = before.next_lsn }, before.changed_lsn)) return error.InvalidTableHistory;
            };
        },
        else => {
            if (before.next_lsn == 0 or !std.meta.eql(before.declared(), after.declared()) or before.changed_lsn != after.changed_lsn or
                before.live_rows != after.live_rows or !std.meta.eql(before.receipts, after.receipts)) return error.InvalidTableHistory;
            if (record.action != .checkpoint and (!std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
            if (record.action == .checkpoint and (!std.meta.eql(before.pins, after.pins) or !std.meta.eql(before.identities, after.identities))) return error.InvalidTableHistory;
            if (record.action == .operation) {
                if (!std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
            } else if (!std.meta.eql(before.operations, after.operations) or !std.meta.eql(before.pending, after.pending)) return error.InvalidTableHistory;
            if (before.retired and record.action != .release) return error.InvalidTableHistory;
        },
    }
}

pub fn deinit(self: *Self) void {
    if (self.segment_cache) |*cached| cached.deinit(self.allocator);
    self.index.deinit();
    self.declaration.deinit();
    self.* = undefined;
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.index };
}

/// Replay uses one bounded frame at a time, retaining only the latest roots.
/// This profile retains its complete WAL; no trim authority is exposed here.
pub fn recover(self: *Self) !void {
    self.recovery_required = true;
    self.index.clearCache();
    if (self.segment_cache) |*cached| cached.deinit(self.allocator);
    self.segment_cache = null;
    const end = try self.log.tail(self.root.partition);
    if (end < self.root.next_lsn) return error.TableHistoryMissing;
    var next = emptyRoot(try self.declaration.stored(), self.root.partition);
    var chain: [32]u8 = @splat(0);
    while (next.next_lsn < end) {
        var batch = try self.log.read(self.allocator, next.partition, next.next_lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.TableHistoryMissing;
        const frame = batch.frames[0];
        if (frame.header.lsn != next.next_lsn or frame.header.partition_id != next.partition or
            (frame.header.kind != .row_delta and frame.header.kind != .manifest_checkpoint)) return error.InvalidTableHistory;
        const decoded = try r.decode(self.allocator, frame.payload, frame.header.lsn);
        const record = decoded.record;
        if (!std.mem.eql(u8, &record.previous, &chain) or
            !std.meta.eql(record.root.interpretation.object, next.interpretation.object) or record.root.partition != next.partition or
            record.root.changed_lsn < next.changed_lsn or record.root.next_segment < next.next_segment) return error.InvalidTableHistory;
        if ((record.action == .mutation) != (frame.header.kind == .row_delta)) return error.InvalidTableHistory;
        if (record.action != .mutation and decoded.rows.len != 0) return error.InvalidTableHistory;
        try requireTransition(next, record, try self.operationTransition(next, record));
        chain = r.hash(frame.payload);
        next = record.root;
    }
    // Verify all top-level roots before exposing the recovered state. Descendant
    // pages and row objects remain checked on access, never substituted by empty.
    for ([_]?pages.Reference{ next.rows, next.scan_rows, next.identities, next.receipts, next.pins, next.operations, next.pending }) |reference| if (reference) |ref| {
        _ = try self.index.load(ref);
    };
    if (end != 0) {
        const declaration = try Declaration.load(self.allocator, self.objects, next.declared());
        self.declaration.deinit();
        self.declaration = declaration;
    }
    self.root = next;
    self.chain = chain;
    self.recovery_required = false;
}

fn ready(self: *Self) !void {
    if (self.recovery_required) return error.TableRecoveryRequired;
}

fn scope(self: *Self, operation: d.Operation) !void {
    try operation.validate();
    if (!std.meta.eql(operation.scope, self.root.interpretation.object.scope)) return error.DataIdentityConflict;
}

fn observed(self: *Self, binding: d.Binding) !?r.Record {
    try binding.validate();
    try self.scope(binding.identity);
    const value = try self.tree().get(self.root.receipts, try r.operationKey(binding.identity)) orelse return null;
    if (value.len != 8) return error.InvalidTableReceipt;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= self.root.next_lsn) return error.InvalidTableReceipt;
    var batch = try self.log.read(self.allocator, self.root.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at) return error.TableHistoryMissing;
    const record = (try r.decode(self.allocator, batch.frames[0].payload, at)).record;
    try (try record.receipt()).binding.requireSame(binding);
    return record;
}

/// Inspect a fixed, exclusive WAL interval after validated recovery. At most
/// `frames` physical records are visited, one bounded frame resident at a time.
/// Empty pages can advance over physical maintenance without inventing a data
/// change. This acquires no snapshot: callers must separately establish durable
/// retention before relying on a root for continued computation or collection.
pub fn history(self: *Self, from: d.Position, through: d.Position, frames: u8, guard: Guard) !HistoryPage {
    try self.ready();
    try from.validate();
    try through.validate();
    if (frames == 0 or frames > pages.page_entries) return error.InvalidTableReadBudget;
    if (from.partition != self.root.partition or through.partition != self.root.partition or
        from.next_lsn > through.next_lsn or through.next_lsn > self.root.next_lsn) return error.InvalidTableBasis;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var result: HistoryPage = .{ .object = self.root.interpretation.object, .through = through, .next = from };
    var previous: ?[32]u8 = null;
    while (result.next.next_lsn < through.next_lsn and result.scanned < frames) {
        var batch = try self.log.read(self.allocator, from.partition, result.next.next_lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.TableHistoryMissing;
        const frame = batch.frames[0];
        if (frame.header.partition_id != from.partition or frame.header.lsn != result.next.next_lsn or
            (frame.header.kind != .row_delta and frame.header.kind != .manifest_checkpoint)) return error.InvalidTableHistory;
        const decoded = try r.decode(self.allocator, frame.payload, frame.header.lsn);
        const record = decoded.record;
        if (!std.meta.eql(record.root.interpretation.object, result.object) or record.root.partition != from.partition or
            (record.action == .mutation) != (frame.header.kind == .row_delta) or
            (record.action != .mutation and decoded.rows.len != 0)) return error.InvalidTableHistory;
        if (previous) |digest| if (!std.mem.eql(u8, &record.previous, &digest)) return error.InvalidTableHistory;
        const commitment = r.hash(frame.payload);
        switch (record.action) {
            .mutation, .declaration => {
                result.entries[result.count] = .{ .root = record.root, .receipt = try record.receipt(), .commitment = commitment };
                result.count += 1;
            },
            .operation, .checkpoint, .pin, .release => {},
        }
        previous = commitment;
        result.scanned += 1;
        result.next.next_lsn = record.root.next_lsn;
    }
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}

fn operationAt(self: *Self, basis: Root, binding: d.Binding) !?Operation {
    try binding.validate();
    if (!std.meta.eql(binding.target, basis.interpretation.object)) return error.DataIdentityConflict;
    return self.operationForKey(basis, try r.operationKey(binding.identity), binding);
}

fn operationForKey(self: *Self, basis: Root, key: pages.Key, binding: ?d.Binding) !?Operation {
    const value = try self.tree().get(basis.operations, key) orelse return null;
    if (value.len != 8) return error.InvalidTableOperation;
    const at = std.mem.readInt(u64, value.data[0..8], .little);
    if (at >= basis.next_lsn) return error.InvalidTableOperation;
    var batch = try self.log.read(self.allocator, basis.partition, at, 1);
    defer batch.deinit();
    if (batch.frames.len != 1 or batch.frames[0].header.lsn != at or batch.frames[0].header.partition_id != basis.partition or batch.frames[0].header.kind != .manifest_checkpoint) return error.TableHistoryMissing;
    const record = (try r.decode(self.allocator, batch.frames[0].payload, at)).record;
    if (record.action != .operation or !std.meta.eql(record.root.interpretation.object, basis.interpretation.object)) return error.InvalidTableOperation;
    const operation = record.action.operation;
    if (!std.meta.eql(key, try r.operationKey(operation.binding.identity))) return error.InvalidTableOperation;
    if (binding) |exact| try operation.binding.requireSame(exact);
    return operation;
}

fn requireAdmissionBasis(basis: Root, operation: Operation) !void {
    if (!std.meta.eql(operation.binding.expected_definition, @as(?d.Definition, basis.interpretation))) return error.TableDefinitionChanged;
    if (operation.binding.expected_data) |expected| {
        if (!expected.unchangedAt(operation.basis.position, operation.basis.changed_lsn) or
            operation.basis.position.partition != basis.partition or basis.changed_lsn != operation.basis.changed_lsn) return error.TableDataChanged;
    }
}

fn operationTransition(self: *Self, before: Root, record: r.Record) !?Operation {
    const binding = switch (record.action) {
        inline .mutation, .declaration, .operation => |value| value.binding,
        else => return null,
    };
    const previous = try self.operationAt(before, binding);
    const key = try r.operationKey(binding.identity);
    const after_pending = try self.tree().get(record.root.pending, key);
    if (record.action == .operation) {
        const next = record.action.operation;
        if (try self.tree().get(before.receipts, key) != null) return error.InvalidTableOperation;
        if (previous) |known| {
            if (known.phase != .admitted or next.phase == .admitted or !std.meta.eql(known.intent, next.intent) or !std.meta.eql(known.basis, next.basis)) return error.InvalidTableOperation;
            if (try self.tree().get(before.pending, key) == null) return error.InvalidTableOperation;
        } else {
            if (next.phase == .cancelled or next.basis.position.partition != before.partition or next.basis.position.next_lsn != before.next_lsn or
                next.basis.changed_lsn != before.changed_lsn or !std.meta.eql(next.basis.interpretation, before.interpretation)) return error.InvalidTableOperation;
            if (next.phase == .admitted) try requireAdmissionBasis(before, next);
        }
        const pointer = try self.tree().get(record.root.operations, key) orelse return error.InvalidTableOperation;
        if (pointer.len != 8 or std.mem.readInt(u64, pointer.data[0..8], .little) != before.next_lsn) return error.InvalidTableOperation;
        if (next.phase == .admitted) {
            const pending = after_pending orelse return error.InvalidTableOperation;
            if (!std.meta.eql(pointer, pending)) return error.InvalidTableOperation;
        } else if (after_pending != null) return error.InvalidTableOperation;
    } else if (previous != null) {
        if (record.action != .mutation or try self.tree().get(before.pending, key) == null or after_pending != null) return error.InvalidTableOperation;
    }
    return previous;
}

fn stateOf(operation: Operation) OperationState {
    return switch (operation.phase) {
        .admitted => .{ .admitted = operation },
        .rejected => .{ .rejected = operation },
        .cancelled => .{ .cancelled = operation },
    };
}

/// Inspection is read-only; a pending intent is never executed by observing it.
pub fn operationState(self: *Self, binding: d.Binding, guard: Guard) !OperationState {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (try self.observed(binding)) |record| return .{ .committed = .{ .binding = binding, .resulting = record.root.declared(), .outcome = (try record.receipt()).outcome } };
    return stateOf(try self.operationAt(self.root, binding) orelse return .not_observed);
}

fn writeOperation(self: *Self, operation: Operation, guard: Guard) !OperationState {
    const ordinary_log = self.log;
    const ordinary_store = self.index.store;
    defer {
        self.log = ordinary_log;
        self.index.store = ordinary_store;
    }
    if (operation.phase != .admitted) if (self.options.control) |control| {
        self.log = control.log;
        self.index.store = control.objects;
    };
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    const key = try r.operationKey(operation.binding.identity);
    var pointer: [8]u8 = undefined;
    std.mem.writeInt(u64, &pointer, self.root.next_lsn, .little);
    const value = try pages.Value.init(&pointer);
    next.operations = try self.tree().put(next.operations, key, value);
    next.pending = if (operation.phase == .admitted) try self.tree().put(next.pending, key, value) else try self.tree().remove(next.pending, key);
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .operation = operation } }, &.{}, guard);
    try self.reply();
    return stateOf(operation);
}

/// Freezes concrete work before acknowledging admission. The caller retains the
/// same binding through timeout, recovery, cancellation and terminal inspection.
pub fn admit(self: *Self, request: Dml.Request, guard: Guard) !OperationState {
    try self.ready();
    const state = try self.operationState(request.binding, guard);
    try request.validate();
    const content = try Dml.stage(self.allocator, self.objects, request);
    if (try self.operationAt(self.root, request.binding)) |known| {
        if (!std.meta.eql(known.intent, content)) return error.DataIdentityConflict;
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        return state;
    }
    if (state == .committed) return error.DataIdentityConflict;
    var operation: Operation = .{
        .binding = request.binding,
        .intent = content,
        .basis = .{ .interpretation = self.root.interpretation, .position = .{ .partition = self.root.partition, .next_lsn = self.root.next_lsn }, .changed_lsn = self.root.changed_lsn },
        .phase = .admitted,
        .reason = .none,
    };
    self.expectations(request.binding) catch |err| switch (err) {
        error.TableDefinitionChanged => {
            operation.phase = .rejected;
            operation.reason = .definition_changed;
        },
        error.TableDataChanged => {
            operation.phase = .rejected;
            operation.reason = .data_changed;
        },
        else => return err,
    };
    return self.writeOperation(operation, guard);
}

/// Explicit execution uses only the retained intent; it never resolves a name
/// or recompiles caller SQL against the latest definition.
pub fn perform(self: *Self, binding: d.Binding, guard: Guard) !OperationState {
    const state = try self.operationState(binding, guard);
    if (state != .admitted) return state;
    const operation = state.admitted;
    var intent = try Dml.load(self.allocator, self.objects, operation.intent);
    defer intent.deinit();
    try intent.request.binding.requireSame(binding);
    const outcome = (if (intent.request.statement) |plan| self.applyStatement(operation, plan, guard) else self.apply(binding, intent.request.changes, intent.request.ingestion, guard)) catch |err| {
        var rejected = operation;
        rejected.phase = .rejected;
        rejected.reason = switch (err) {
            error.TableDefinitionChanged => .definition_changed,
            error.TableDataChanged => .data_changed,
            error.DuplicatePrimaryKey, error.DuplicateBatchKey => .duplicate_key,
            error.TableRowMissing => .missing_row,
            error.TableRowIdentityChanged, error.DuplicateTableRowIdentity => .invalid_rows,
            error.StorageCandidateTooLarge, error.TableStatementScanLimit, error.TableBatchTooLarge => .work_limit,
            else => return err,
        };
        return self.writeOperation(rejected, guard);
    };
    return .{ .committed = .{ .binding = binding, .resulting = self.root.declared(), .outcome = outcome } };
}

pub fn cancel(self: *Self, binding: d.Binding, guard: Guard) !OperationState {
    const state = try self.operationState(binding, guard);
    if (state != .admitted) return state;
    var operation = state.admitted;
    operation.phase = .cancelled;
    return self.writeOperation(operation, guard);
}

pub const PendingPage = struct { items: [pages.page_entries]Operation = undefined, len: usize = 0, after: ?pages.Key = null };
pub fn pendingOperations(self: *Self, after: ?pages.Key, guard: Guard) !PendingPage {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const slice = try self.tree().scan(self.root.pending, after);
    var result: PendingPage = .{ .after = slice.next };
    for (slice.entries) |maybe_entry| {
        const entry = maybe_entry orelse break;
        const operation = try self.operationForKey(self.root, entry.key, null) orelse return error.InvalidTableOperation;
        if (operation.phase != .admitted) return error.InvalidTableOperation;
        result.items[result.len] = operation;
        result.len += 1;
    }
    return result;
}

pub fn observe(self: *Self, binding: d.Binding, guard: Guard) !?Outcome {
    const evidence = try self.observeEvidence(binding, guard) orelse return null;
    return evidence.outcome;
}

/// Returns the original resulting definition, even after later DDL. A catalog
/// must not substitute the current head when finishing an earlier operation.
pub fn observeEvidence(self: *Self, binding: d.Binding, guard: Guard) !?Evidence {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const record = try self.observed(binding) orelse return null;
    const receipt = try record.receipt();
    return .{ .binding = receipt.binding, .resulting = record.root.declared(), .outcome = receipt.outcome };
}

fn expectations(self: *Self, binding: d.Binding) !void {
    try binding.validate();
    if (self.root.retired) return error.TableRetired;
    if (self.root.next_lsn == 0 and binding.action != .create) return error.TableNotCreated;
    if (!std.meta.eql(binding.target, self.root.interpretation.object)) return error.DataIdentityConflict;
    if (binding.expected_definition) |expected| {
        if (!std.meta.eql(expected, self.root.interpretation)) return error.TableDefinitionChanged;
    } else if (self.root.next_lsn != 0 or binding.action != .create) return error.TableAlreadyExists;
    if (binding.action == .create and self.root.interpretation.revision != 1) return error.InvalidDataDefinition;
    if (binding.expected_data) |expected| {
        if (!expected.unchangedAt(.{ .partition = self.root.partition, .next_lsn = self.root.next_lsn }, self.root.changed_lsn)) return error.TableDataChanged;
    }
}

/// The adapter lowers an exact frozen intent to these concrete changes. Retry
/// equality checks both that binding and the complete ordered mutation bytes.
pub fn apply(self: *Self, binding: d.Binding, changes: []const Change, ingestion: Ingestion, guard: Guard) !Outcome {
    try self.ready();
    if (changes.len > max_changes) return error.TableBatchTooLarge;
    if (binding.action != .create and binding.action != .insert and binding.action != .update and binding.action != .delete) return error.UnsupportedTableAction;
    var accepted: ?r.Record = null;
    var operation: ?Operation = null;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        accepted = try self.observed(binding);
        operation = try self.operationAt(self.root, binding);
        if (accepted == null) {
            if (operation) |known| {
                if (known.phase != .admitted) return error.TableOperationTerminal;
                if (self.root.retired) return error.TableRetired;
                try requireAdmissionBasis(self.root, known);
            } else try self.expectations(binding);
        }
    }
    var original: ?Declaration.Owned = null;
    defer if (original) |*value| value.deinit();
    if (accepted) |record| original = try Declaration.load(self.allocator, self.objects, record.root.declared());
    if (operation) |known| {
        var frozen = try Dml.load(self.allocator, self.objects, known.intent);
        defer frozen.deinit();
        try frozen.request.binding.requireSame(binding);
        const requested = try Dml.stage(self.allocator, self.objects, .{ .binding = binding, .interpretation = frozen.request.interpretation, .changes = changes, .ingestion = ingestion });
        if (!std.meta.eql(requested, known.intent)) return error.DataIdentityConflict;
    }
    const schema = if (original) |value| value.schema.schema else self.declaration.schema.schema;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const bytes = try a.alloc(u8, max_row_bytes);
    var rows: std.Io.Writer = .fixed(bytes);
    const keys = try a.alloc([]const u8, changes.len);
    const old_keys = try a.alloc([]const u8, changes.len);
    const key_hashes = try a.alloc([32]u8, changes.len);
    const old_hashes = try a.alloc([32]u8, changes.len);
    const locators = try a.alloc(r.Locator, changes.len);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.table.changes.v1\x00");
    for (changes, 0..) |change, i| {
        var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
        const key = switch (change) {
            inline .put, .replace => |value| try value.row.storageKey(schema, &key_bytes),
            .remove => |value| value,
        };
        if (key.len == 0 or key.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
        keys[i] = try a.dupe(u8, key);
        const old_key = if (change == .replace) change.replace.key else key;
        if (old_key.len == 0 or old_key.len > f.Collation.max_sort_key_bytes) return error.InvalidTableKey;
        old_keys[i] = try a.dupe(u8, old_key);
        key_hashes[i] = r.hash(key);
        old_hashes[i] = r.hash(old_key);
        for (old_keys[0..i]) |previous| {
            if (std.mem.eql(u8, previous, old_key)) return error.DuplicateBatchKey;
        }
        for (keys[0..i], changes[0..i]) |previous, earlier| {
            if (change != .remove and earlier != .remove and std.mem.eql(u8, previous, key)) return error.DuplicateBatchKey;
        }
        for (0..i + 1) |j| {
            for ([_][]const u8{ keys[j], old_keys[j] }, [_][32]u8{ key_hashes[j], old_hashes[j] }) |previous, hashed| {
                if ((!std.mem.eql(u8, previous, key) and std.mem.eql(u8, &hashed, &key_hashes[i])) or
                    (!std.mem.eql(u8, previous, old_key) and std.mem.eql(u8, &hashed, &old_hashes[i]))) return error.TableKeyHashCollision;
            }
        }
        const tag: [1]u8 = .{switch (change) {
            .put => |value| @as(u8, @backingInt(value.expect)) + 1,
            .remove => 0,
            .replace => 4,
        }};
        digest.update(&tag);
        var length: [8]u8 = undefined;
        std.mem.writeInt(u64, &length, key.len, .little);
        digest.update(&length);
        digest.update(key);
        if (change == .replace) {
            std.mem.writeInt(u64, &length, old_key.len, .little);
            digest.update(&length);
            digest.update(old_key);
        }
        switch (change) {
            inline .put, .replace => |value| {
                const offset = rows.end;
                const encoded = try value.row.encode(schema, bytes[offset..]);
                rows.end += encoded.len;
                std.mem.writeInt(u64, &length, encoded.len, .little);
                digest.update(&length);
                digest.update(encoded);
                locators[i] = .{ .kind = .wal, .lsn = self.root.next_lsn, .offset = @intCast(offset), .length = @intCast(encoded.len), .digest = r.hash(encoded) };
            },
            .remove => {},
        }
    }
    const changes_digest = digest.finalResult();
    if (accepted) |record| {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        const receipt = try record.receipt();
        if (!std.mem.eql(u8, &changes_digest, &receipt.changes)) return error.DataIdentityConflict;
        return receipt.outcome;
    }
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var matched: u64 = 0;
    var affected: u64 = 0;
    const changed = try a.alloc(bool, changes.len);
    @memset(changed, false);
    const previous_bytes = try a.alloc(u8, f.TableRow.max_bytes);
    const previous_ids = try a.alloc(?f.TableRow.Identity, changes.len);
    @memset(previous_ids, null);
    // Validate every row/key constraint against the accepted root before staging.
    for (changes, old_keys, 0..) |change, key, i| {
        var existing = try self.getAt(self.allocator, self.root, key);
        defer if (existing) |*row| row.deinit();
        if (existing) |*row| previous_ids[i] = row.row().identity;
        switch (change) {
            inline .put, .replace => |value| {
                const expectation = if (change == .put) change.put.expect else Changes.Expect.present;
                if (expectation == .absent and existing != null) return error.DuplicatePrimaryKey;
                if (expectation == .present and existing == null) return error.TableRowMissing;
                matched += 1;
                if (existing) |*row| {
                    if ((change == .replace or (operation != null and binding.action == .update)) and !std.meta.eql(row.row().identity, value.row.identity)) return error.TableRowIdentityChanged;
                    const encoded = try row.row().encode(schema, previous_bytes);
                    const proposed = locators[i];
                    if (std.mem.eql(u8, encoded, bytes[proposed.offset..][0..proposed.length])) continue;
                }
                if (existing == null) next.live_rows = try std.math.add(u64, next.live_rows, 1);
                changed[i] = true;
                affected += 1;
            },
            .remove => if (existing != null) {
                next.live_rows -= 1;
                changed[i] = true;
                matched += 1;
                affected += 1;
            },
        }
    }
    // Remove all old keys before testing destinations. This permits a complete
    // UPDATE to exchange keys while still rejecting collisions with survivors.
    for (old_keys, changed, previous_ids) |key, is_changed, previous_id| {
        if (!is_changed) continue;
        if (previous_id) |identity| next.identities = try self.tree().remove(next.identities, try pages.Key.init(&try identity.encode()));
        const index_key = try r.rowKey(key);
        if (try self.tree().get(next.rows, index_key)) |value| {
            next.scan_rows = try self.tree().remove(next.scan_rows, try (try r.Locator.decode(value)).scanKey());
            next.rows = try self.tree().remove(next.rows, index_key);
        }
    }
    for (changes, keys, changed) |change, key, is_changed| {
        if (is_changed and change != .remove and try self.tree().get(next.rows, try r.rowKey(key)) != null) return error.DuplicatePrimaryKey;
    }
    if (ingestion == .bulk) {
        var bulk: std.ArrayList(f.TableRow.Row) = .empty;
        for (changes, changed) |change, is_changed| if (is_changed) {
            if (change.row()) |row| try bulk.append(a, row);
        };
        if (bulk.items.len != 0) {
            const segment = try self.stageSegment(a, schema, next.next_segment, bulk.items);
            next.next_segment = try std.math.add(u64, next.next_segment, 1);
            for (changes, keys, 0..) |change, key, i| if (changed[i] and change != .remove) {
                const entry = segment.footer.findPrimaryKeySortKey(key) orelse return error.InvalidSegmentIndex;
                locators[i] = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
            };
        }
    } else {
        // The retry digest includes every requested change; accepted row bytes
        // contain only replacements. Unchanged rows retain their old locators.
        var written: usize = 0;
        for (changes, changed, locators) |change, is_changed, *locator| if (is_changed and change != .remove) {
            std.mem.copyForwards(u8, bytes[written..][0..locator.length], bytes[locator.offset..][0..locator.length]);
            locator.offset = @intCast(written);
            written += locator.length;
        };
        rows.end = written;
    }
    for (changes, keys, 0..) |change, key, i| {
        if (!changed[i] or change == .remove) continue;
        const index_key = try r.rowKey(key);
        try self.indexIdentity(&next, change.row().?.identity, index_key);
        next.rows = try self.tree().put(next.rows, index_key, try locators[i].encode());
        next.scan_rows = try self.tree().put(next.scan_rows, try locators[i].scanKey(), try locators[i].scanValue(index_key));
    }
    var receipt: [8]u8 = undefined;
    std.mem.writeInt(u64, &receipt, self.root.next_lsn, .little);
    next.receipts = try self.tree().put(next.receipts, try r.operationKey(binding.identity), try pages.Value.init(&receipt));
    if (operation != null) next.pending = try self.tree().remove(next.pending, try r.operationKey(binding.identity));
    if (affected != 0 or binding.action == .create) next.changed_lsn = next.next_lsn;
    const outcome: Outcome = .{ .position = .{ .partition = next.partition, .next_lsn = next.next_lsn }, .matched = matched, .affected = affected, .live_rows = next.live_rows };
    const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .mutation = .{
        .binding = binding,
        .changes = changes_digest,
        .outcome = outcome,
        .ingestion = if (ingestion == .point) .point else .bulk,
    } } };
    try self.publish(record, if (ingestion == .point) rows.buffered() else &.{}, guard);
    try self.reply();
    return outcome;
}

const StatementBudget = struct {
    rows: u64,
    bytes: u64,
    fn visit(self: *StatementBudget, bytes: usize) !void {
        if (self.rows == 0 or bytes > self.bytes) return error.TableStatementScanLimit;
        self.rows -= 1;
        self.bytes -= bytes;
    }
};

fn statementEncode(row: f.TableRow.Row, schema: f.TableSchema.Schema, buffer: []u8) ![]const u8 {
    return row.encode(schema, buffer) catch |err| return if (err == error.WriteFailed) error.TableBatchTooLarge else err;
}

fn statementReplacement(plan: f.TableDml.Plan, original: f.TableRow.Row, original_bytes: []const u8, cells: []f.Types.Values.Cell, buffer: []u8) !?f.TableRow.Row {
    const row: f.TableRow.Row = .{ .identity = original.identity, .cells = try plan.schema.update(original.cells, plan.action.update, cells) };
    if (std.mem.eql(u8, original_bytes, try statementEncode(row, plan.schema, buffer))) return null;
    return row;
}

/// A retained predicate is evaluated privately under its frozen logical basis.
/// Remove changed keys before adding replacements so collisions with survivors
/// and across groups reject the entire statement. No selected-row collection
/// grows with durable cardinality; each pass uses a page and one bounded group.
fn applyStatement(self: *Self, operation: Operation, plan: f.TableDml.Plan, guard: Guard) !Outcome {
    try self.ready();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if (self.root.retired) return error.TableRetired;
        try requireAdmissionBasis(self.root, operation);
    }
    if (plan.action == .insert or operation.binding.expected_data == null) return error.InvalidTableStatementIntent;
    if (!std.mem.eql(u8, &try plan.schema.fingerprint(), &self.root.schema_fingerprint)) return error.TableSchemaChanged;
    var budget: StatementBudget = .{ .rows = self.options.statement_scan_rows, .bytes = self.options.statement_scan_bytes };
    const before_bytes = try self.allocator.alloc(u8, max_row_bytes);
    defer self.allocator.free(before_bytes);
    const after_bytes = try self.allocator.alloc(u8, max_row_bytes);
    defer self.allocator.free(after_bytes);
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var matched: u64 = 0;
    var affected: u64 = 0;
    var cursor: ?pages.Key = null;
    while (true) {
        const batch = try self.scan(self.root, cursor);
        for (batch.entries) |slot| if (slot) |entry| {
            var owned = try self.readRow(self.allocator, self.root, entry.key, entry.value);
            defer owned.deinit();
            const row = owned.row();
            const encoded = try statementEncode(row, plan.schema, before_bytes);
            try budget.visit(encoded.len);
            if (!try plan.matches(row.cells)) continue;
            matched += 1;
            if (plan.action == .update and try statementReplacement(plan, row, encoded, &cells, after_bytes) == null) continue;
            affected += 1;
            next.identities = try self.tree().remove(next.identities, try pages.Key.init(&try row.identity.encode()));
            next.rows = try self.tree().remove(next.rows, entry.key);
            next.scan_rows = try self.tree().remove(next.scan_rows, try (try r.Locator.decode(entry.value)).scanKey());
        };
        cursor = batch.next orelse break;
    }
    if (plan.action == .delete) {
        next.live_rows -= affected;
    } else if (affected != 0) {
        cursor = null;
        var done = false;
        var written: u64 = 0;
        while (!done) {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const a = arena.allocator();
            var rows: std.ArrayList(f.TableRow.Row) = .empty;
            var bytes: usize = 0;
            group: while (rows.items.len < max_changes) {
                const batch = try self.scan(self.root, cursor);
                for (batch.entries) |slot| if (slot) |entry| {
                    // Unselected rows are freed immediately, even when a group
                    // spans arbitrarily many unselected input pages.
                    var owned = try self.readRow(self.allocator, self.root, entry.key, entry.value);
                    defer owned.deinit();
                    const original = owned.row();
                    const encoded = try statementEncode(original, plan.schema, before_bytes);
                    try budget.visit(encoded.len);
                    if (try plan.matches(original.cells)) {
                        if (try statementReplacement(plan, original, encoded, &cells, after_bytes)) |row| {
                            const length = (try statementEncode(row, plan.schema, after_bytes)).len;
                            if (length > max_row_bytes - bytes or rows.items.len == max_changes) break :group;
                            const copy = try a.alloc(f.Types.Values.Cell, row.cells.len);
                            for (row.cells, copy) |value, *target| target.* = try f.Types.Values.cloneValidated(a, value);
                            try rows.append(a, .{ .identity = row.identity, .cells = copy });
                            bytes += length;
                        }
                    }
                    cursor = try (try r.Locator.decode(entry.value)).scanKey();
                };
                if (batch.next == null) {
                    done = true;
                    break;
                }
            }
            if (rows.items.len == 0) {
                if (!done) return error.TableBatchTooLarge;
                break;
            }
            const segment = try self.stageSegment(a, plan.schema, next.next_segment, rows.items);
            next.next_segment = try std.math.add(u64, next.next_segment, 1);
            for (segment.footer.pk_index) |entry| {
                const key = try r.rowKey(entry.pk_sort_key);
                if (try self.tree().get(next.rows, key) != null) return error.DuplicatePrimaryKey;
                const locator: r.Locator = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
                try self.indexIdentity(&next, entry.identity, key);
                next.rows = try self.tree().put(next.rows, key, try locator.encode());
                next.scan_rows = try self.tree().put(next.scan_rows, try locator.scanKey(), try locator.scanValue(key));
                written += 1;
            }
        }
        if (written != affected) return error.InvalidTableHistory;
    }
    const key = try r.operationKey(operation.binding.identity);
    var pointer: [8]u8 = undefined;
    std.mem.writeInt(u64, &pointer, self.root.next_lsn, .little);
    next.receipts = try self.tree().put(next.receipts, key, try pages.Value.init(&pointer));
    next.pending = try self.tree().remove(next.pending, key);
    if (affected != 0) next.changed_lsn = next.next_lsn;
    const outcome: Outcome = .{ .position = .{ .partition = next.partition, .next_lsn = next.next_lsn }, .matched = matched, .affected = affected, .live_rows = next.live_rows };
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .mutation = .{ .binding = operation.binding, .changes = operation.intent.sha256, .outcome = outcome, .ingestion = .bulk } } }, &.{}, guard);
    try self.reply();
    return outcome;
}

pub const Edit = union(enum) {
    rename: []const u8,
    alter: struct { change: f.TableEvolution.Change, properties: []const u8 },
    drop: []const u8,
};

/// The catalog validates names, dependencies and its canonical properties before
/// calling this owner. All rewritten rows and the resulting definition become
/// visible at one Table log append. No independently writable manifest exists.
pub fn changeDefinition(self: *Self, binding: d.Binding, edit: Edit, guard: Guard) !Outcome {
    try self.ready();
    const action: d.Action = switch (edit) {
        .rename => .rename,
        .alter => .alter,
        .drop => .drop,
    };
    if (binding.action != action) return error.UnsupportedTableAction;
    const properties = switch (edit) {
        .alter => |value| value.properties,
        inline else => |value| value,
    };
    if (properties.len > Declaration.max_properties_bytes) return error.InvalidTableDeclaration;
    var accepted: ?r.Record = null;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        accepted = try self.observed(binding);
        if (accepted == null) {
            try self.expectations(binding);
            if (self.root.pending != null) return error.TableOperationsPending;
            if (try self.operationAt(self.root, binding) != null) return error.DataIdentityConflict;
        }
    }
    const intent = try self.allocator.alloc(u8, Log.max_payload_bytes);
    defer self.allocator.free(intent);
    var writer: std.Io.Writer = .fixed(intent);
    try std.json.Stringify.value(edit, .{}, &writer);
    const digest = r.hash(writer.buffered());
    if (accepted) |record| {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        const receipt = try record.receipt();
        if (!std.mem.eql(u8, &digest, &receipt.changes)) return error.DataIdentityConflict;
        return receipt.outcome;
    }
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    var transition: ?f.TableEvolution.Transition = if (edit == .alter) try f.TableEvolution.apply(self.declaration.schema.schema, edit.alter.change, &columns) else null;
    var replacement = try Declaration.prepare(self.allocator, .{
        .object = self.root.interpretation.object,
        .revision = try std.math.add(u64, self.root.interpretation.revision, 1),
        .schema = if (transition) |value| value.after else self.declaration.schema.schema,
        .properties = properties,
        .retired = edit == .drop,
    });
    var moved = false;
    defer if (!moved) replacement.deinit();
    const stored = try Declaration.stage(self.objects, &replacement);
    var next = self.root;
    next.interpretation = stored.interpretation;
    next.declaration = stored.content;
    next.schema_fingerprint = stored.schema_fingerprint;
    next.retired = stored.retired;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.changed_lsn = next.next_lsn;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    if (transition) |*value| {
        value.after = replacement.schema.schema;
        try self.rewrite(&next, value.*);
    }
    var receipt: [8]u8 = undefined;
    std.mem.writeInt(u64, &receipt, self.root.next_lsn, .little);
    next.receipts = try self.tree().put(next.receipts, try r.operationKey(binding.identity), try pages.Value.init(&receipt));
    const outcome: Outcome = .{ .position = .{ .partition = next.partition, .next_lsn = next.next_lsn }, .matched = 0, .affected = 0, .live_rows = next.live_rows };
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .declaration = .{ .binding = binding, .changes = digest, .outcome = outcome } } }, &.{}, guard);
    // Both allocations were prepared before acceptance. Even a lost reply leaves
    // this live owner using exactly the schema selected by its accepted root.
    self.declaration.deinit();
    self.declaration = replacement;
    moved = true;
    try self.reply();
    return outcome;
}

fn indexIdentity(self: *Self, next: *Root, identity: f.TableRow.Identity, row_key: pages.Key) !void {
    if (row_key.len != 32) return error.InvalidTableKey;
    const key = try pages.Key.init(&try identity.encode());
    if (try self.tree().get(next.identities, key) != null) return error.DuplicateTableRowIdentity;
    next.identities = try self.tree().put(next.identities, key, try pages.Value.init(row_key.data[0..32]));
}

fn rewrite(self: *Self, next: *Root, transition: f.TableEvolution.Transition) !void {
    next.rows = null;
    next.scan_rows = null;
    next.identities = null;
    var cursor: ?pages.Key = null;
    var done = false;
    var count: u64 = 0;
    const encoded = try self.allocator.alloc(u8, max_row_bytes);
    defer self.allocator.free(encoded);
    while (!done) {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var rows: std.ArrayList(f.TableRow.Row) = .empty;
        var bytes: usize = 0;
        group: while (rows.items.len < max_changes) {
            const batch = try self.scan(self.root, cursor);
            for (batch.entries) |slot| if (slot) |entry| {
                const old = try self.readRow(a, self.root, entry.key, entry.value);
                const cells = try a.alloc(f.Types.Values.Cell, transition.after.columns.len);
                const row: f.TableRow.Row = .{ .identity = old.row().identity, .cells = try transition.row(old.row().cells, cells) };
                const length = (try row.encode(transition.after, encoded)).len;
                if (length > max_row_bytes - bytes or rows.items.len == max_changes) break :group;
                try rows.append(a, row);
                bytes += length;
                cursor = try (try r.Locator.decode(entry.value)).scanKey();
            };
            if (batch.next == null) {
                done = true;
                break;
            }
        }
        if (rows.items.len == 0) {
            if (!done) return error.TableBatchTooLarge;
            break;
        }
        const segment = try self.stageSegment(a, transition.after, next.next_segment, rows.items);
        next.next_segment = try std.math.add(u64, next.next_segment, 1);
        for (segment.footer.pk_index) |entry| {
            const index_key = try r.rowKey(entry.pk_sort_key);
            // Includes collisions across different bounded rewrite groups. A
            // hash collision rejects conservatively; it never merges two rows.
            if (try self.tree().get(next.rows, index_key) != null) return error.DuplicatePrimaryKey;
            const locator: r.Locator = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
            try self.indexIdentity(next, entry.identity, index_key);
            next.rows = try self.tree().put(next.rows, index_key, try locator.encode());
            next.scan_rows = try self.tree().put(next.scan_rows, try locator.scanKey(), try locator.scanValue(index_key));
            count = try std.math.add(u64, count, 1);
        }
    }
    if (count != self.root.live_rows) return error.InvalidTableHistory;
}

fn publish(self: *Self, record: r.Record, row_bytes: []const u8, guard: Guard) !void {
    try record.validate(self.root.next_lsn);
    try requireTransition(self.root, record, try self.operationTransition(self.root, record));
    if (self.root.next_lsn == 0) _ = try Declaration.stage(self.objects, &self.declaration);
    const buffer = try self.allocator.alloc(u8, Log.max_payload_bytes);
    defer self.allocator.free(buffer);
    const payload = try r.encode(record, row_bytes, buffer);
    const chain = r.hash(payload);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidPartitionLease;
    _ = self.log.append(self.root.partition, self.root.next_lsn, fence.writer_epoch, fence.policy_epoch, if (record.action == .mutation) .row_delta else .manifest_checkpoint, payload) catch |err| {
        self.recovery_required = true;
        return err;
    };
    // No fallible allocation or publication remains after the acceptance record.
    self.root = record.root;
    self.chain = chain;
}

fn reply(self: *Self) !void {
    if (self.lose_reply) return error.LostAcknowledgement;
}

pub fn get(self: *Self, allocator: std.mem.Allocator, key: []const u8, guard: Guard) !?OwnedRow {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (self.root.retired) return error.TableRetired;
    return self.getAt(allocator, self.root, key);
}

/// Exact frozen roots are internal read bases; the public adapter must acquire
/// and verify a retained pin before allowing a basis to outlive its request.
pub fn getAt(self: *Self, allocator: std.mem.Allocator, basis: Root, key: []const u8) !?OwnedRow {
    try self.ready();
    try self.requireBasis(basis);
    const value = try self.tree().get(basis.rows, try r.rowKey(key)) orelse return null;
    var row = try self.readRow(allocator, basis, try r.rowKey(key), value);
    errdefer row.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.mem.eql(u8, key, try row.row().storageKey(self.declaration.schema.schema, &actual))) return error.TableKeyHashCollision;
    return row;
}

fn requireBasis(self: *Self, basis: Root) !void {
    try basis.validate();
    if (!std.meta.eql(basis.interpretation.object, self.root.interpretation.object) or basis.partition != self.root.partition or
        basis.next_lsn > self.root.next_lsn) return error.InvalidTableBasis;
}

/// The opaque cursor follows physical WAL/segment order for locality. SQL
/// ordering belongs to its plan, never to this directory's traversal order.
pub fn scan(self: *Self, basis: Root, after: ?pages.Key) !pages.Slice {
    try self.ready();
    try self.requireBasis(basis);
    var batch = try self.tree().scan(basis.scan_rows, after);
    for (&batch.entries) |*slot| if (slot.*) |*entry| {
        if (entry.value.len != 81) return error.InvalidTableRowReference;
        const value = entry.value;
        const locator = try r.Locator.decode(try pages.Value.init(value.data[32..81]));
        if (!std.meta.eql(entry.key, try locator.scanKey())) return error.InvalidTableRowReference;
        entry.key = try pages.Key.init(value.data[0..32]);
        entry.value = try locator.encode();
    };
    return batch;
}

pub fn readRow(self: *Self, allocator: std.mem.Allocator, basis: Root, key: pages.Key, value: pages.Value) !OwnedRow {
    return self.readRowWithSchema(allocator, basis, self.declaration.schema.schema, key, value);
}

fn readRowWithSchema(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, key: pages.Key, value: pages.Value) !OwnedRow {
    try self.ready();
    try self.requireBasis(basis);
    if (!std.mem.eql(u8, &try schema.fingerprint(), &basis.schema_fingerprint)) return error.InvalidTableBasis;
    const locator = try r.Locator.decode(value);
    var result: OwnedRow = switch (locator.kind) {
        .wal => blk: {
            if (locator.lsn >= basis.next_lsn or locator.length > f.TableRow.max_bytes) return error.InvalidTableRowReference;
            var batch = try self.log.read(self.allocator, basis.partition, locator.lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1 or batch.frames[0].header.lsn != locator.lsn) return error.TableHistoryMissing;
            const decoded = try r.decode(self.allocator, batch.frames[0].payload, locator.lsn);
            if (decoded.record.action != .mutation or (!std.meta.eql(decoded.record.root.interpretation.object, basis.interpretation.object) or !std.mem.eql(u8, &decoded.record.root.schema_fingerprint, &basis.schema_fingerprint)) or
                locator.offset > decoded.rows.len or locator.length > decoded.rows.len - locator.offset) return error.InvalidTableRowReference;
            const bytes = decoded.rows[locator.offset..][0..locator.length];
            if (!std.mem.eql(u8, &r.hash(bytes), &locator.digest)) return error.InvalidTableRowReference;
            break :blk .{ .wal = try f.TableRow.decode(allocator, schema, bytes) };
        },
        .segment => blk: {
            var temporary: ?CachedSegment = null;
            defer if (temporary) |*segment| segment.deinit(self.allocator);
            const segment = try self.loadSegment(locator, &temporary);
            const footer = &segment.footer;
            if (footer.object_id != schema.object or footer.schema_revision != schema.revision or
                !std.mem.eql(u8, &footer.layout_fingerprint, &try schema.layoutFingerprint())) return error.TableSchemaChanged;
            if (footer.segment_id != locator.lsn or locator.offset >= footer.pk_index.len or footer.pk_index[locator.offset].global_row_offset != locator.offset) return error.InvalidTableRowReference;
            const entry = footer.pk_index[locator.offset];
            if (segment.decoded) |*group| if (group.index != entry.row_group) {
                group.arena.deinit();
                segment.decoded = null;
            };
            if (segment.decoded == null) {
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                errdefer arena.deinit();
                const columns = try arena.allocator().alloc([]f.Types.Values.Cell, schema.columns.len);
                for (columns, 0..) |*column, i| column.* = try f.TSeg.decodeRowGroupColumn(arena.allocator(), schema, footer, segment.bytes, entry.row_group, i);
                segment.decoded = .{ .arena = arena, .index = entry.row_group, .columns = columns };
                self.row_groups_decoded +|= 1;
            }
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            const cells = try arena.allocator().alloc(f.Types.Values.Cell, schema.columns.len);
            for (segment.decoded.?.columns, cells) |column, *cell| {
                if (entry.row_in_group >= column.len) return error.InvalidTableRowReference;
                cell.* = try f.Types.Values.cloneValidated(arena.allocator(), column[entry.row_in_group]);
            }
            break :blk .{ .segment = .{ .arena = arena, .identity = entry.identity, .cells = cells } };
        },
    };
    errdefer result.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.meta.eql(key, try r.rowKey(try result.row().storageKey(schema, &actual)))) return error.InvalidTableRowReference;
    return result;
}

fn segmentKey(digest: [32]u8, buffer: *[96]u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "table-segments/{x}.tseg", .{&digest});
}

const CachedSegment = struct {
    digest: [32]u8,
    bytes: []u8,
    footer: f.TSeg.Footer,
    decoded: ?struct { arena: std.heap.ArenaAllocator, index: u16, columns: [][]f.Types.Values.Cell } = null,
    fn deinit(self: *CachedSegment, allocator: std.mem.Allocator) void {
        if (self.decoded) |*group| group.arena.deinit();
        self.footer.deinit();
        allocator.free(self.bytes);
    }
};

fn loadSegment(self: *Self, locator: r.Locator, temporary: *?CachedSegment) !*CachedSegment {
    if (self.segment_cache) |*cached| {
        if (std.mem.eql(u8, &cached.digest, &locator.digest) and cached.bytes.len == locator.length) return cached;
        cached.deinit(self.allocator);
        self.segment_cache = null;
    }
    const bytes = try self.readSegment(self.allocator, locator);
    errdefer self.allocator.free(bytes);
    var footer = try f.TSeg.readFooter(self.allocator, bytes);
    errdefer footer.deinit();
    if (footer.total_rows > max_changes) return error.InvalidTableSegment;
    const segment: CachedSegment = .{ .digest = locator.digest, .bytes = bytes, .footer = footer };
    self.segment_reads +|= 1;
    if (bytes.len <= self.options.segment_cache_bytes) {
        self.segment_cache = segment;
        return &self.segment_cache.?;
    }
    temporary.* = segment;
    return &temporary.*.?;
}

fn readSegment(self: *Self, allocator: std.mem.Allocator, locator: r.Locator) ![]u8 {
    if (locator.length == 0 or locator.length > f.TSeg.max_segment_bytes) return error.InvalidTableRowReference;
    var name: [96]u8 = undefined;
    const key = try segmentKey(locator.digest, &name);
    const metadata = try self.objects.head(key) orelse return error.TableSegmentMissing;
    if (metadata.size != locator.length or !std.mem.eql(u8, &metadata.sha256, &locator.digest)) return error.InvalidTableRowReference;
    const bytes = try allocator.alloc(u8, locator.length);
    errdefer allocator.free(bytes);
    if ((try self.objects.getRange(key, 0, locator.length, bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &locator.digest)) return error.InvalidTableRowReference;
    return bytes;
}

fn stageSegment(self: *Self, allocator: std.mem.Allocator, schema: f.TableSchema.Schema, segment_id: u64, rows: []const f.TableRow.Row) !struct { content: d.Content, footer: f.TSeg.Footer } {
    const buffer = try allocator.alloc(u8, f.TSeg.max_segment_bytes);
    defer allocator.free(buffer);
    const bytes = try f.TSeg.writeSegment(allocator, schema, rows, .{ .segment_id = segment_id }, buffer);
    const digest = r.hash(bytes);
    var name: [96]u8 = undefined;
    const metadata = try self.objects.putImmutable(try segmentKey(digest, &name), bytes, digest);
    if (metadata.size != bytes.len or !std.mem.eql(u8, &metadata.sha256, &digest)) return error.InvalidTableSegment;
    return .{ .content = .{ .bytes = bytes.len, .sha256 = digest }, .footer = try f.TSeg.readFooter(allocator, bytes) };
}

/// Flush at most one bounded group of accepted WAL rows. The accepted row index
/// itself is the paged manifest; replacing locators publishes no logical change.
pub fn flush(self: *Self, guard: Guard) !usize {
    try self.ready();
    if (self.root.retired) return error.TableRetired;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var rows: std.ArrayList(f.TableRow.Row) = .empty;
    var bytes: usize = 0;
    var after: ?pages.Key = null;
    find: while (rows.items.len < max_changes) {
        const batch = try self.scan(self.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            const locator = try r.Locator.decode(entry.value);
            // WAL locators sort before segment locators. Once this boundary is
            // reached there is no unflushed work later in the durable directory.
            if (locator.kind != .wal) break :find;
            if (locator.length > max_row_bytes - bytes or rows.items.len == max_changes) break :find;
            const row = try self.readRow(a, self.root, entry.key, entry.value);
            try rows.append(a, row.row());
            bytes += locator.length;
        };
        after = batch.next orelse break;
    }
    if (rows.items.len == 0) return 0;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    const segment = try self.stageSegment(a, self.declaration.schema.schema, next.next_segment, rows.items);
    next.next_segment = try std.math.add(u64, next.next_segment, 1);
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    for (segment.footer.pk_index) |entry| {
        const locator: r.Locator = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
        const index_key = try r.rowKey(entry.pk_sort_key);
        const previous = try r.Locator.decode(try self.tree().get(next.rows, index_key) orelse return error.InvalidTableRowReference);
        next.scan_rows = try self.tree().remove(next.scan_rows, try previous.scanKey());
        next.rows = try self.tree().put(next.rows, index_key, try locator.encode());
        next.scan_rows = try self.tree().put(next.scan_rows, try locator.scanKey(), try locator.scanValue(index_key));
    }
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .checkpoint }, &.{}, guard);
    try self.reply();
    return rows.items.len;
}

/// Capture exactly the requested accepted frontier, including unflushed rows.
/// The complete WAL and immutable object history remain retained by this owner;
/// this profile has no physical trim/GC operation. Pin ownership and release are
/// durable, and are a prerequisite for any future retained-root collector.
pub fn pin(self: *Self, owner: d.Operation, expected: d.Position, guard: Guard) !SnapshotHandle {
    try self.ready();
    try self.scope(owner);
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if (try self.tree().get(self.root.pins, try r.operationKey(owner))) |value| {
            const existing = try Snapshot.Pin.decode(value);
            if (existing.released) return error.TableSnapshotReleased;
            const handle: SnapshotHandle = .{ .owner = owner, .content = existing.content };
            var frozen = try Snapshot.load(self.allocator, self.objects, handle);
            defer frozen.deinit();
            if (expected.partition != frozen.root.partition or expected.next_lsn != frozen.root.next_lsn) return error.DataIdentityConflict;
            return handle;
        }
        if (self.root.retired) return error.TableRetired;
        if (self.root.next_lsn == 0) return error.TableNotCreated;
        if (expected.partition != self.root.partition or expected.next_lsn != self.root.next_lsn) return error.TableDataChanged;
    }
    const handle = try Snapshot.stage(self.allocator, self.objects, owner, self.root, self.declaration.schema.schema);
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.pins = try self.tree().put(next.pins, try r.operationKey(owner), try (Snapshot.Pin{ .content = handle.content }).encode());
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .pin = .{ .owner = owner, .basis = handle.content } } }, &.{}, guard);
    try self.reply();
    return handle;
}

fn requirePin(self: *Self, handle: SnapshotHandle) !Snapshot.Pin {
    try self.scope(handle.owner);
    const value = try self.tree().get(self.root.pins, try r.operationKey(handle.owner)) orelse return error.TableSnapshotNotPinned;
    const existing = try Snapshot.Pin.decode(value);
    if (!std.meta.eql(existing.content, handle.content)) return error.DataIdentityConflict;
    return existing;
}

/// Recover the original acquisition without acquiring a pin. An absent pin
/// plus a later physical frontier proves that its old exact-frontier request
/// can no longer succeed. Release remains a separately authorized mutation.
pub fn pinState(self: *Self, owner: d.Operation, guard: Guard) !PinState {
    try self.ready();
    try self.scope(owner);
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const value = try self.tree().get(self.root.pins, try r.operationKey(owner));
    const existing = if (value) |bytes| try Snapshot.Pin.decode(bytes) else null;
    return .{
        .position = .{ .partition = self.root.partition, .next_lsn = self.root.next_lsn },
        .retired = self.root.retired,
        .handle = if (existing) |pin_value| .{ .owner = owner, .content = pin_value.content } else null,
        .released = if (existing) |pin_value| pin_value.released else false,
    };
}

pub fn releaseSnapshot(self: *Self, handle: SnapshotHandle, guard: Guard) !void {
    try self.ready();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if ((try self.requirePin(handle)).released) return;
    }
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    next.pins = try self.tree().put(next.pins, try r.operationKey(handle.owner), try (Snapshot.Pin{ .content = handle.content, .released = true }).encode());
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .{ .release = .{ .owner = handle.owner, .basis = handle.content } } }, &.{}, guard);
    try self.reply();
}

pub fn readSnapshot(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, key: []const u8, guard: Guard) !?OwnedRow {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if ((try self.requirePin(handle)).released) return error.TableSnapshotReleased;
    var frozen = try Snapshot.load(self.allocator, self.objects, handle);
    defer frozen.deinit();
    try self.requireBasis(frozen.root);
    const index_key = try r.rowKey(key);
    const value = try self.tree().get(frozen.root.rows, index_key) orelse return null;
    var row = try self.readRowWithSchema(allocator, frozen.root, frozen.schema.schema, index_key, value);
    errdefer row.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.mem.eql(u8, key, try row.row().storageKey(frozen.schema.schema, &actual))) return error.TableKeyHashCollision;
    return row;
}

/// Returns the original schema and source basis. Inspection never acquires or
/// renews a pin; the existing owner must remain live and currently authorized.
pub fn inspectSnapshot(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, guard: Guard) !SnapshotDefinition {
    try self.ready();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if ((try self.requirePin(handle)).released) return error.TableSnapshotReleased;
    }
    var frozen = try Snapshot.load(allocator, self.objects, handle);
    errdefer frozen.deinit();
    try self.requireBasis(frozen.root);
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return frozen;
}

/// Physical pages are independent of query result batches. Values in the
/// returned page own their storage and remain valid across subsequent reads.
/// Cursor completion means this pinned Table traversal is exhausted, not that
/// a query or an independently captured source vector is complete.
pub fn scanSnapshot(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, after: ?SnapshotCursor, limits: ReadLimits, guard: Guard) !SnapshotPage {
    try limits.validate();
    var frozen = try self.inspectSnapshot(allocator, handle, guard);
    defer frozen.deinit();
    const cursor: ?pages.Key = if (after) |value| blk: {
        if (!std.meta.eql(value.source, handle.content)) return error.InvalidTableSnapshotCursor;
        const key = try pages.Key.init(&value.after);
        if (try self.tree().get(frozen.root.identities, key) == null) return error.InvalidTableSnapshotCursor;
        break :blk key;
    } else null;
    const batch = try self.tree().scan(frozen.root.identities, cursor);
    var result: SnapshotPage = .{
        .source = handle,
        .interpretation = frozen.root.declared(),
        .accepted = .{ .partition = frozen.root.partition, .next_lsn = frozen.root.next_lsn },
        .changed_lsn = frozen.root.changed_lsn,
        .total_rows = frozen.root.live_rows,
    };
    errdefer result.deinit();
    const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
    defer allocator.free(scratch);
    var previous: ?pages.Key = cursor;
    for (batch.entries) |slot| {
        const entry = slot orelse break;
        if (result.count == limits.rows) {
            result.next = .{ .source = handle.content, .after = previous.?.data[0..f.TableRow.Identity.encoded_bytes].* };
            break;
        }
        if (entry.key.len != f.TableRow.Identity.encoded_bytes or entry.value.len != 32) return error.InvalidTableRowReference;
        const row_key = try pages.Key.init(entry.value.data[0..32]);
        const locator = try self.tree().get(frozen.root.rows, row_key) orelse return error.InvalidTableRowReference;
        var row = try self.readRowWithSchema(allocator, frozen.root, frozen.schema.schema, row_key, locator);
        var moved = false;
        defer if (!moved) row.deinit();
        if (!std.mem.eql(u8, entry.key.data[0..entry.key.len], &try row.row().identity.encode())) return error.InvalidTableRowReference;
        const encoded = try row.row().encode(frozen.schema.schema, scratch);
        if (encoded.len > limits.encoded_bytes - result.encoded_bytes) {
            if (result.count == 0) return error.TableReadBudgetTooSmall;
            result.next = .{ .source = handle.content, .after = previous.?.data[0..f.TableRow.Identity.encoded_bytes].* };
            break;
        }
        result.rows[result.count] = row;
        moved = true;
        result.count += 1;
        result.encoded_bytes += @intCast(encoded.len);
        previous = entry.key;
    }
    if (result.next == null) if (batch.next) |key| {
        if (key.len != f.TableRow.Identity.encoded_bytes) return error.InvalidTableRowReference;
        result.next = .{ .source = handle.content, .after = key.data[0..f.TableRow.Identity.encoded_bytes].* };
    };
    // Authorization may change while rows are decoded or copied. Recheck after
    // buffering, including empty output and end-of-source metadata.
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}
