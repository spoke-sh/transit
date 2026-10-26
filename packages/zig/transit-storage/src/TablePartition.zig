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
const OrderedKeys = @import("OrderedKeyIndex.zig");
const pages = TreeStore.pages;
const r = @import("TablePartitionRecord.zig");
const Declaration = @import("TableDeclaration.zig");
const Snapshot = @import("TableSnapshot.zig");
const Archive = @import("TableArchive.zig");
const Recovery = @import("TableRecovery.zig");
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
pub const default_build_resident_bytes = 64 * 1024 * 1024;
pub const default_predicate_resident_bytes = 4 * 1024 * 1024;

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
    /// Simultaneous private allocations for mutations, rewrites and flushes.
    /// Reader caches, index staging and WAL/provider buffers have separate bounds.
    build_resident_bytes: usize = default_build_resident_bytes,
    segment_cache_bytes: usize = f.TSeg.max_segment_bytes,
    /// Physical build granularity, independent of operation/result row limits.
    segment_rows_per_group: u32 = 256,
    segment_decode_bytes: usize = 64 * 1024 * 1024,
    /// Encoded predicate outcomes and scratch, separate from output decoding.
    segment_predicate_bytes: usize = default_predicate_resident_bytes,
    /// Total decoded visits across statement passes, independent of Table size.
    statement_scan_rows: u64 = 1_000_000,
    statement_scan_bytes: u64 = 64 * 1024 * 1024,
    /// Same physical namespace, with quota reserved for cancellation/rejection.
    control: ?struct { log: Log.Log, objects: Objects.ObjectStore } = null,
};
pub const Change = Changes.Change;
pub const Ingestion = Changes.Ingestion;
pub const SnapshotHandle = Snapshot.Handle;
pub const Retention = Snapshot.Retention;
pub const PinState = struct {
    interpretation: d.Definition,
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
pub const HistoryReceipt = r.Receipt;
pub const HistoryPage = struct {
    object: d.Object,
    through: d.Position,
    next: d.Position,
    scanned: u8 = 0,
    entries: [pages.page_entries]?HistoryEntry = @splat(null),
    count: u8 = 0,
};
/// A point within an explicitly retained history. The commitment is the exact
/// WAL record digest, not the current root or a native resource revision.
pub const HistoryPoint = struct {
    lease: SnapshotHandle,
    position: d.Position,
    commitment: [32]u8,
    pub fn cursorSource(self: HistoryPoint) !d.Content {
        try self.lease.owner.validate();
        try self.lease.content.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or std.mem.allEqual(u8, &self.commitment, 0)) return error.InvalidTableHistory;
        var bytes: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try std.json.Stringify.value(self, .{}, &writer);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.history.cursor.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(writer.buffered());
        return .{ .bytes = writer.end, .sha256 = hash.finalResult() };
    }
};
pub const HistoryDefinition = struct {
    point: HistoryPoint,
    root: Root,
    declaration: Declaration.Owned,
    pub fn deinit(self: *HistoryDefinition) void {
        self.declaration.deinit();
        self.* = undefined;
    }
};
pub const HistoryRows = struct {
    point: HistoryPoint,
    page: SnapshotPage,
    pub fn deinit(self: *HistoryRows) void {
        self.page.deinit();
        self.* = undefined;
    }
};
pub const SnapshotCursor = struct { source: d.Content, after: [f.TableRow.Identity.encoded_bytes]u8 };
pub const KeyRange = @import("TableKeyRange.zig");
pub const KeyRangePage = struct {
    source: SnapshotHandle,
    interpretation: Declaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    rows: [8]?OwnedRow = @splat(null),
    count: u8 = 0,
    encoded_bytes: u32 = 0,
    next: ?KeyRange.Cursor = null,
    pub fn deinit(self: *KeyRangePage) void {
        for (&self.rows) |*slot| if (slot.*) |*row| row.deinit();
        self.* = undefined;
    }
};
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
pub const FilteredPage = struct {
    page: SnapshotPage,
    /// Successfully consumed identity-index entries, including filtered rows.
    examined: u8 = 0,
    /// One-based source positions within this page, for each returned row.
    offsets: [pages.page_entries]u8 = @splat(0),
    /// The next identity failed semantically. Earlier rows remain available so
    /// their aggregate errors can win. No continuation or completion is implied.
    failure: ?struct { identity: f.TableRow.Identity, column: u8, instruction: u8, outcome: f.ColumnPredicate.Outcome } = null,
    pub fn deinit(self: *FilteredPage) void {
        self.page.deinit();
        self.* = undefined;
    }
};
/// One bounded observation of the current root. There is no continuation or
/// retention owner: `more` requires a separately acquired durable snapshot if
/// the caller needs complete traversal. Returned cells own their memory.
pub const CurrentPage = struct {
    interpretation: Declaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    rows: [pages.page_entries]?OwnedRow = @splat(null),
    count: u8 = 0,
    encoded_bytes: u32 = 0,
    more: bool = false,
    pub fn deinit(self: *CurrentPage) void {
        for (&self.rows) |*slot| if (slot.*) |*value| value.deinit();
        self.* = undefined;
    }
};
pub const RowPage = struct {
    rows: [pages.page_entries]?OwnedRow = @splat(null),
    count: u8 = 0,
    encoded_bytes: u32 = 0,
    next: ?[f.TableRow.Identity.encoded_bytes]u8 = null,
    pub fn deinit(self: *RowPage) void {
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

/// Last successful recovery work; diagnostic counts confer no authority.
pub const RecoveryWork = struct { checkpoint_lsn: u64 = 0, replayed_frames: u64 = 0 };

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
segment_range_reads: u64 = 0,
segment_bytes_read: u64 = 0,
row_groups_decoded: u64 = 0,
row_groups_filtered: u64 = 0,
/// Last mutation/rewrite/flush workspace peak, including arena backing slack.
build_resident_peak: usize = 0,
recovery_required: bool = true,
recovery_archive: ?Archive.Coverage = null,
recovery_work: RecoveryWork = .{},
/// Failure injection at the durable append/reply boundary.
lose_reply: bool = false,

pub fn init(allocator: std.mem.Allocator, partition: u64, definition: Declaration.Definition, log: Log.Log, objects: Objects.ObjectStore, options: Options) !Self {
    try definition.validate();
    if (partition == 0 or options.index_work_bytes == 0 or options.build_resident_bytes == 0 or options.statement_scan_rows == 0 or options.statement_scan_bytes == 0 or
        options.segment_rows_per_group == 0 or options.segment_rows_per_group > max_changes or options.segment_decode_bytes == 0 or options.segment_predicate_bytes == 0) return error.InvalidTableIdentity;
    var owned = try Declaration.prepare(allocator, definition);
    errdefer owned.deinit();
    var index = try TreeStore.init(allocator, objects, options.resident_pages);
    errdefer index.deinit();
    return .{ .allocator = allocator, .log = log, .objects = objects, .index = index, .declaration = owned, .options = options, .root = emptyRoot(try owned.stored(), partition) };
}

fn emptyRoot(stored: Declaration.Stored, partition: u64) Root {
    return .{ .interpretation = stored.interpretation, .declaration = stored.content, .schema_fingerprint = stored.schema_fingerprint, .retired = stored.retired, .next_segment = 1, .partition = partition, .operations = null, .pending = null, .identities = null, .ordered_rows = null, .archive = .empty, .recovery = null };
}

fn requireTransition(before: Root, record: r.Record, operation: ?Operation) !void {
    const after = record.root;
    if (record.action == .archive) {
        if (after.archive.through <= before.archive.through or after.archive.through > before.next_lsn or
            after.archive.through - before.archive.through > Archive.max_frames or
            std.meta.eql(before.archive.directory, after.archive.directory) or !std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
    } else if (!std.meta.eql(before.archive, after.archive)) return error.InvalidTableHistory;
    if (record.action == .recovery) {
        const reference = after.recovery orelse return error.InvalidTableHistory;
        if (reference.next_lsn != before.next_lsn or !std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
        if (before.recovery) |previous| if (reference.next_lsn <= previous.next_lsn) return error.InvalidTableHistory;
    } else if (!std.meta.eql(before.recovery, after.recovery)) return error.InvalidTableHistory;
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
                (!std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.ordered_rows, after.ordered_rows) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or
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
                        !std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.ordered_rows, after.ordered_rows) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
                }
            }
            if (operation == null) if (binding.expected_data) |expected| {
                if (!expected.unchangedAt(.{ .partition = before.partition, .next_lsn = before.next_lsn }, before.changed_lsn)) return error.InvalidTableHistory;
            };
        },
        else => {
            if (before.next_lsn == 0 or !std.meta.eql(before.declared(), after.declared()) or before.changed_lsn != after.changed_lsn or
                before.live_rows != after.live_rows or !std.meta.eql(before.receipts, after.receipts)) return error.InvalidTableHistory;
            if (!std.meta.eql(before.ordered_rows, after.ordered_rows)) return error.InvalidTableHistory;
            if (record.action != .checkpoint and (!std.meta.eql(before.identities, after.identities) or !std.meta.eql(before.rows, after.rows) or !std.meta.eql(before.scan_rows, after.scan_rows) or before.next_segment != after.next_segment)) return error.InvalidTableHistory;
            if (record.action == .checkpoint and (!std.meta.eql(before.pins, after.pins) or !std.meta.eql(before.identities, after.identities))) return error.InvalidTableHistory;
            if (record.action == .operation) {
                if (!std.meta.eql(before.pins, after.pins)) return error.InvalidTableHistory;
            } else if (!std.meta.eql(before.operations, after.operations) or !std.meta.eql(before.pending, after.pending)) return error.InvalidTableHistory;
            if (before.retired and record.action != .release and record.action != .archive and record.action != .recovery) return error.InvalidTableHistory;
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
/// The latest accepted WAL record locates an optional recovery baseline and the
/// archive. Replay verifies its publishing transition and the complete later
/// chain. Without a checkpoint the chain starts at creation.
pub fn recover(self: *Self) !void {
    self.recovery_required = true;
    self.index.clearCache();
    if (self.segment_cache) |*cached| cached.deinit(self.allocator);
    self.segment_cache = null;
    const end = try self.log.tail(self.root.partition);
    if (end < self.root.next_lsn) return error.TableHistoryMissing;
    var next = emptyRoot(try self.declaration.stored(), self.root.partition);
    var chain: [32]u8 = @splat(0);
    var work: RecoveryWork = .{};
    var selected: ?Recovery.Reference = null;
    self.recovery_archive = .empty;
    defer self.recovery_archive = null;
    if (end != 0) {
        var latest = try self.log.read(self.allocator, next.partition, end - 1, 1);
        defer latest.deinit();
        if (latest.frames.len != 1 or latest.frames[0].header.partition_id != next.partition or
            latest.frames[0].header.lsn != end - 1) return error.TableHistoryMissing;
        const record = (try decodeFrame(self.allocator, latest.frames[0], next.partition, end - 1)).record;
        if (!std.meta.eql(record.root.interpretation.object, next.interpretation.object) or
            record.root.partition != next.partition) return error.InvalidTableHistory;
        self.recovery_archive = record.root.archive;
        selected = record.root.recovery;
    }
    if (selected) |reference| {
        const basis = try Recovery.load(self.allocator, self.objects, reference, end, next.partition, next.interpretation.object);
        next = basis.root;
        chain = basis.chain;
        work.checkpoint_lsn = next.next_lsn;
    }
    while (next.next_lsn < end) {
        var batch = try self.readHistoryFrame(next.next_lsn);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.TableHistoryMissing;
        const frame = batch.frames[0];
        const decoded = try decodeFrame(self.allocator, frame, next.partition, next.next_lsn);
        const record = decoded.record;
        if (!std.mem.eql(u8, &record.previous, &chain) or
            !std.meta.eql(record.root.interpretation.object, next.interpretation.object) or record.root.partition != next.partition or
            record.root.changed_lsn < next.changed_lsn or record.root.next_segment < next.next_segment) return error.InvalidTableHistory;
        // The baseline is authorized only by this first replayed transition.
        // A staged object or a copied reference in an unrelated record is not a
        // checkpoint. Every later record must retain the selected reference.
        if (selected != null and (!std.meta.eql(record.root.recovery, selected) or
            (work.replayed_frames == 0 and record.action != .recovery))) return error.InvalidTableHistory;
        try requireTransition(next, record, try self.operationTransition(next, record));
        chain = r.hash(frame.payload);
        next = record.root;
        work.replayed_frames += 1;
    }
    // Verify all top-level roots before exposing the recovered state. Descendant
    // pages and row objects remain checked on access, never substituted by empty.
    for ([_]?pages.Reference{ next.rows, next.scan_rows, next.identities, next.ordered_rows, next.receipts, next.pins, next.operations, next.pending, next.archive.directory }) |reference| if (reference) |ref| {
        _ = try self.index.load(ref);
    };
    if (end != 0) {
        const declaration = try Declaration.load(self.allocator, self.objects, next.declared());
        self.declaration.deinit();
        self.declaration = declaration;
    }
    self.root = next;
    self.chain = chain;
    self.recovery_work = work;
    self.recovery_required = false;
}

fn readHistoryFrame(self: *Self, lsn: u64) !Log.Log.OwnedBatch {
    const coverage = self.recovery_archive orelse self.root.archive;
    if (lsn < coverage.through) return Archive.read(self.allocator, &self.index, coverage, self.root.partition, lsn);
    return self.log.read(self.allocator, self.root.partition, lsn, 1);
}

/// Physical adapters use only coverage published by this partition's accepted
/// record. This does not permit logical expiry or collection of archive objects.
pub fn archivedThrough(allocator: std.mem.Allocator, frame: Log.Frame) !u64 {
    return (try decodeFrame(allocator, frame, frame.header.partition_id, frame.header.lsn)).record.root.archive.through;
}

fn decodeFrame(allocator: std.mem.Allocator, frame: Log.Frame, partition: u64, lsn: u64) !r.Decoded {
    const decoded = try r.decode(allocator, frame.payload, lsn);
    if (frame.header.partition_id != partition or frame.header.lsn != lsn or
        frame.header.partition_id != decoded.record.root.partition or
        (frame.header.kind != .row_delta and frame.header.kind != .manifest_checkpoint) or
        (decoded.record.action == .mutation) != (frame.header.kind == .row_delta) or
        (decoded.record.action != .mutation and decoded.rows.len != 0)) return error.InvalidTableHistory;
    return decoded;
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
    var batch = try self.readHistoryFrame(at);
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
        var batch = try self.readHistoryFrame(result.next.next_lsn);
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
            .operation, .checkpoint, .archive, .recovery, .pin, .release => {},
        }
        previous = commitment;
        result.scanned += 1;
        result.next.next_lsn = record.root.next_lsn;
    }
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}

/// Traverse accepted logical transactions under a durable history lease. The
/// fixed upper bound is supplied by the caller; empty pages can advance past
/// physical records. No-op acceptances remain visible as individual entries.
pub fn retainedHistory(self: *Self, lease: SnapshotHandle, from: d.Position, through: d.Position, frames: u8, guard: Guard) !HistoryPage {
    var original = try self.inspectHistoryLease(self.allocator, lease, guard);
    defer original.deinit();
    if (from.partition != original.root.partition or from.next_lsn < original.root.next_lsn) return error.InvalidTableBasis;
    return self.history(from, through, frames, guard);
}

fn inspectHistoryLease(self: *Self, allocator: std.mem.Allocator, lease: SnapshotHandle, guard: Guard) !SnapshotDefinition {
    var original = try self.inspectSnapshot(allocator, lease, guard);
    errdefer original.deinit();
    if (original.retention != .history) return error.TableHistoryRetentionRequired;
    return original;
}

/// Initial inspection always resolves the lease's original point. It never
/// substitutes the latest Table frontier when work is admitted or resumed.
pub fn historyStart(self: *Self, allocator: std.mem.Allocator, lease: SnapshotHandle, guard: Guard) !HistoryDefinition {
    return self.openHistoryPoint(allocator, lease, null, guard);
}

/// Reopen exactly the saved historical root and interpretation, under current
/// authority and the original still-live history lease.
pub fn historyAt(self: *Self, allocator: std.mem.Allocator, point: HistoryPoint, guard: Guard) !HistoryDefinition {
    _ = try point.cursorSource();
    return self.openHistoryPoint(allocator, point.lease, point, guard);
}

fn openHistoryPoint(self: *Self, allocator: std.mem.Allocator, lease: SnapshotHandle, requested: ?HistoryPoint, guard: Guard) !HistoryDefinition {
    var original = try self.inspectHistoryLease(allocator, lease, guard);
    defer original.deinit();
    const position: d.Position = if (requested) |point| point.position else .{ .partition = original.root.partition, .next_lsn = original.root.next_lsn };
    if (position.partition != original.root.partition or position.next_lsn < original.root.next_lsn or position.next_lsn > self.root.next_lsn or position.next_lsn == 0) return error.InvalidTableBasis;
    var frame = try self.readHistoryFrame(position.next_lsn - 1);
    defer frame.deinit();
    if (frame.frames.len != 1) return error.TableHistoryMissing;
    const value = frame.frames[0];
    if (value.header.partition_id != position.partition or value.header.lsn != position.next_lsn - 1 or
        (value.header.kind != .row_delta and value.header.kind != .manifest_checkpoint)) return error.InvalidTableHistory;
    const digest = r.hash(value.payload);
    if (requested) |point| if (!std.mem.eql(u8, &digest, &point.commitment)) return error.TableHistoryConflict;
    const decoded = try r.decode(self.allocator, value.payload, value.header.lsn);
    const record = decoded.record;
    if ((record.action == .mutation) != (value.header.kind == .row_delta) or (record.action != .mutation and decoded.rows.len != 0)) return error.InvalidTableHistory;
    try self.requireBasis(record.root);
    var declaration = try Declaration.load(allocator, self.objects, record.root.declared());
    errdefer declaration.deinit();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return .{ .point = .{ .lease = lease, .position = position, .commitment = digest }, .root = record.root, .declaration = declaration };
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
    var batch = try self.readHistoryFrame(at);
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
    var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.build_resident_bytes };
    defer self.build_resident_peak = memory.peak;
    const outcome = self.performWithinBudget(memory.allocator(), operation, guard) catch |cause| {
        const err = buildFailure(&memory, cause);
        var rejected = operation;
        rejected.phase = .rejected;
        rejected.reason = switch (err) {
            error.TableDefinitionChanged => .definition_changed,
            error.TableDataChanged => .data_changed,
            error.DuplicatePrimaryKey, error.DuplicateBatchKey => .duplicate_key,
            error.TableRowMissing => .missing_row,
            error.TableRowIdentityChanged, error.DuplicateTableRowIdentity => .invalid_rows,
            error.StorageCandidateTooLarge, error.TableStatementScanLimit, error.TableBatchTooLarge, error.TableBuildBudget => .work_limit,
            else => return err,
        };
        return self.writeOperation(rejected, guard);
    };
    return .{ .committed = .{ .binding = binding, .resulting = self.root.declared(), .outcome = outcome } };
}

fn performWithinBudget(self: *Self, allocator: std.mem.Allocator, operation: Operation, guard: Guard) !Outcome {
    var intent = try Dml.load(allocator, self.objects, operation.intent);
    defer intent.deinit();
    try intent.request.binding.requireSame(operation.binding);
    return if (intent.request.statement) |plan|
        self.applyStatement(allocator, operation, plan, guard)
    else
        self.applyWithinBudget(allocator, operation.binding, intent.request.changes, intent.request.ingestion, guard);
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

/// Read-only expectation check under the current caller's authority fence.
/// This neither claims an identity nor admits or evaluates row work.
pub fn checkExpectations(self: *Self, binding: d.Binding, guard: Guard) !void {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    try self.expectations(binding);
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

fn buildFailure(memory: *const f.MemoryBudget, err: anyerror) anyerror {
    return if (err == error.OutOfMemory and memory.exhausted) error.TableBuildBudget else err;
}

/// The adapter lowers an exact frozen intent to these concrete changes. Retry
/// equality checks both that binding and the complete ordered mutation bytes.
pub fn apply(self: *Self, binding: d.Binding, changes: []const Change, ingestion: Ingestion, guard: Guard) !Outcome {
    var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.build_resident_bytes };
    defer self.build_resident_peak = memory.peak;
    return self.applyWithinBudget(memory.allocator(), binding, changes, ingestion, guard) catch |err| return buildFailure(&memory, err);
}

fn applyWithinBudget(self: *Self, allocator: std.mem.Allocator, binding: d.Binding, changes: []const Change, ingestion: Ingestion, guard: Guard) !Outcome {
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
    if (accepted) |record| original = try Declaration.load(allocator, self.objects, record.root.declared());
    if (operation) |known| {
        var frozen = try Dml.load(allocator, self.objects, known.intent);
        defer frozen.deinit();
        try frozen.request.binding.requireSame(binding);
        const requested = try Dml.stage(allocator, self.objects, .{ .binding = binding, .interpretation = frozen.request.interpretation, .changes = changes, .ingestion = ingestion });
        if (!std.meta.eql(requested, known.intent)) return error.DataIdentityConflict;
    }
    const schema = if (original) |value| value.schema.schema else self.declaration.schema.schema;
    var arena = std.heap.ArenaAllocator.init(allocator);
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
        var existing = try self.getAt(allocator, self.root, key);
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
    var index_batch: RowIndexBatch = .{ .table = self, .root = &next };
    for (old_keys, changed, previous_ids) |key, is_changed, previous_id| {
        if (!is_changed) continue;
        const index_key = try r.rowKey(key);
        if (try self.tree().get(next.rows, index_key)) |value| {
            try index_batch.remove(key, index_key, previous_id orelse return error.InvalidTableRowReference, try r.Locator.decode(value));
        }
    }
    try index_batch.flush();
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
        try index_batch.insert(key, index_key, change.row().?.identity, locators[i]);
    }
    try index_batch.flush();
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
fn applyStatement(self: *Self, allocator: std.mem.Allocator, operation: Operation, plan: f.TableDml.Plan, guard: Guard) !Outcome {
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
    const before_bytes = try allocator.alloc(u8, max_row_bytes);
    defer allocator.free(before_bytes);
    const after_bytes = try allocator.alloc(u8, max_row_bytes);
    defer allocator.free(after_bytes);
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    var index_batch: RowIndexBatch = .{ .table = self, .root = &next };
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var matched: u64 = 0;
    var affected: u64 = 0;
    var cursor: ?pages.Key = null;
    while (true) {
        const batch = try self.scan(self.root, cursor);
        for (batch.entries) |slot| if (slot) |entry| {
            var owned = try self.readRow(allocator, self.root, entry.key, entry.value);
            defer owned.deinit();
            const row = owned.row();
            const encoded = try statementEncode(row, plan.schema, before_bytes);
            try budget.visit(encoded.len);
            if (!try plan.matches(row.cells)) continue;
            matched += 1;
            if (plan.action == .update and try statementReplacement(plan, row, encoded, &cells, after_bytes) == null) continue;
            affected += 1;
            var ordered_key: [f.Collation.max_sort_key_bytes]u8 = undefined;
            try index_batch.remove(try row.storageKey(plan.schema, &ordered_key), entry.key, row.identity, try r.Locator.decode(entry.value));
        };
        cursor = batch.next orelse break;
    }
    try index_batch.flush();
    if (plan.action == .delete) {
        next.live_rows -= affected;
    } else if (affected != 0) {
        cursor = null;
        var done = false;
        var written: u64 = 0;
        while (!done) {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const a = arena.allocator();
            var rows: std.ArrayList(f.TableRow.Row) = .empty;
            var bytes: usize = 0;
            group: while (rows.items.len < max_changes) {
                const batch = try self.scan(self.root, cursor);
                for (batch.entries) |slot| if (slot) |entry| {
                    // Unselected rows are freed immediately, even when a group
                    // spans arbitrarily many unselected input pages.
                    var owned = try self.readRow(allocator, self.root, entry.key, entry.value);
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
                try index_batch.insert(entry.pk_sort_key, key, entry.identity, locator);
                written += 1;
            }
            try index_batch.flush();
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
    var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.build_resident_bytes };
    defer self.build_resident_peak = memory.peak;
    return self.changeDefinitionWithinBudget(memory.allocator(), binding, edit, guard) catch |err| return buildFailure(&memory, err);
}

fn changeDefinitionWithinBudget(self: *Self, allocator: std.mem.Allocator, binding: d.Binding, edit: Edit, guard: Guard) !Outcome {
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
    const intent = try allocator.alloc(u8, Log.max_payload_bytes);
    defer allocator.free(intent);
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
        try self.rewrite(allocator, &next, value.*);
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

/// One bounded write set for all row indexes. The roots remain private until
/// their enclosing acceptance is published; no batch is an acceptance boundary.
const RowIndexBatch = struct {
    const Entry = struct { key: OrderedKeys.Key, hash: pages.Key, identity: f.TableRow.Identity, locator: r.Locator, remove: bool };
    table: *Self,
    root: *Root,
    entries: [pages.mutation_batch]Entry = undefined,
    count: usize = 0,

    fn remove(self: *@This(), key: []const u8, hash: pages.Key, identity: f.TableRow.Identity, locator: r.Locator) !void {
        if (self.count != 0 and !self.entries[0].remove) try self.flush();
        try self.append(.{ .key = try OrderedKeys.Key.init(key), .hash = hash, .identity = identity, .locator = locator, .remove = true });
    }
    fn insert(self: *@This(), key: []const u8, hash: pages.Key, identity: f.TableRow.Identity, locator: r.Locator) !void {
        if (self.count != 0 and self.entries[0].remove) try self.flush();
        if (hash.len != 32) return error.InvalidTableKey;
        // Pending entries are part of the private candidate even before flush.
        for (self.entries[0..self.count]) |entry| {
            if (std.meta.eql(entry.hash, hash)) return error.DuplicatePrimaryKey;
            if (std.meta.eql(entry.identity, identity)) return error.DuplicateTableRowIdentity;
        }
        if (try self.table.tree().get(self.root.rows, hash) != null) return error.DuplicatePrimaryKey;
        if (try self.table.tree().get(self.root.identities, try pages.Key.init(&try identity.encode())) != null) return error.DuplicateTableRowIdentity;
        try self.append(.{ .key = try OrderedKeys.Key.init(key), .hash = hash, .identity = identity, .locator = locator, .remove = false });
    }
    fn append(self: *@This(), entry: Entry) !void {
        if (self.count == self.entries.len) try self.flush();
        self.entries[self.count] = entry;
        self.count += 1;
    }
    fn flush(self: *@This()) !void {
        if (self.count == 0) return;
        var changes: [pages.mutation_batch]pages.Mutation = undefined;
        const entries = self.entries[0..self.count];
        for (entries, changes[0..self.count]) |entry, *change| change.* = .{ .key = entry.hash, .value = if (entry.remove) null else try entry.locator.encode() };
        self.root.rows = try self.table.tree().mutate(self.root.rows, changes[0..self.count]);
        for (entries, changes[0..self.count]) |entry, *change| change.* = .{ .key = try pages.Key.init(&try entry.identity.encode()), .value = if (entry.remove) null else try pages.Value.init(entry.hash.data[0..32]) };
        self.root.identities = try self.table.tree().mutate(self.root.identities, changes[0..self.count]);
        for (entries, changes[0..self.count]) |entry, *change| change.* = .{ .key = try entry.locator.scanKey(), .value = if (entry.remove) null else try entry.locator.scanValue(entry.hash) };
        self.root.scan_rows = try self.table.tree().mutate(self.root.scan_rows, changes[0..self.count]);
        var ordered: [pages.mutation_batch]OrderedKeys.Mutation = undefined;
        for (entries, ordered[0..self.count]) |*entry, *change| change.* = .{ .key = entry.key.slice(), .value = if (entry.remove) null else entry.hash.data[0..32].* };
        self.root.ordered_rows = try self.table.orderedKeys().mutate(self.root.ordered_rows, ordered[0..self.count]);
        self.count = 0;
    }
};

fn orderedKeys(self: *Self) OrderedKeys {
    return .{ .store = &self.index };
}

fn rewrite(self: *Self, allocator: std.mem.Allocator, next: *Root, transition: f.TableEvolution.Transition) !void {
    next.rows = null;
    next.scan_rows = null;
    next.identities = null;
    next.ordered_rows = null;
    var index_batch: RowIndexBatch = .{ .table = self, .root = next };
    var cursor: ?pages.Key = null;
    var done = false;
    var count: u64 = 0;
    const encoded = try allocator.alloc(u8, max_row_bytes);
    defer allocator.free(encoded);
    while (!done) {
        var arena = std.heap.ArenaAllocator.init(allocator);
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
            try index_batch.insert(entry.pk_sort_key, index_key, entry.identity, locator);
            count = try std.math.add(u64, count, 1);
        }
        try index_batch.flush();
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
    var row = try self.readRowWithSchema(allocator, basis, self.declaration.schema.schema, try r.rowKey(key), value, .point);
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
    return self.readRowWithSchema(allocator, basis, self.declaration.schema.schema, key, value, .group);
}

const ReadMode = enum { point, group };

fn readRowWithSchema(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, key: pages.Key, value: pages.Value, mode: ReadMode) !OwnedRow {
    var selected: f.TableProjection = .{ .len = @intCast(schema.columns.len) };
    for (selected.indices[0..selected.len], 0..) |*column, i| column.* = @intCast(i);
    return self.readRowWithColumns(allocator, basis, schema, key, value, mode, selected);
}

fn readRowWithColumns(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, key: pages.Key, value: pages.Value, mode: ReadMode, selected: f.TableProjection) !OwnedRow {
    try self.ready();
    try self.requireBasis(basis);
    if (!std.mem.eql(u8, &try schema.fingerprint(), &basis.schema_fingerprint)) return error.InvalidTableBasis;
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const projected_schema = if (selected.len == schema.columns.len) schema else try selected.projectedSchema(schema, &columns);
    const locator = try r.Locator.decode(value);
    var result: OwnedRow = switch (locator.kind) {
        .wal => blk: {
            if (locator.lsn >= basis.next_lsn or locator.length > f.TableRow.max_bytes) return error.InvalidTableRowReference;
            var batch = try self.readHistoryFrame(locator.lsn);
            defer batch.deinit();
            if (batch.frames.len != 1 or batch.frames[0].header.lsn != locator.lsn) return error.TableHistoryMissing;
            const decoded = try r.decode(self.allocator, batch.frames[0].payload, locator.lsn);
            if (decoded.record.action != .mutation or (!std.meta.eql(decoded.record.root.interpretation.object, basis.interpretation.object) or !std.mem.eql(u8, &decoded.record.root.schema_fingerprint, &basis.schema_fingerprint)) or
                locator.offset > decoded.rows.len or locator.length > decoded.rows.len - locator.offset) return error.InvalidTableRowReference;
            const bytes = decoded.rows[locator.offset..][0..locator.length];
            if (!std.mem.eql(u8, &r.hash(bytes), &locator.digest)) return error.InvalidTableRowReference;
            var full = try f.TableRow.decode(allocator, schema, bytes);
            if (selected.len == schema.columns.len) break :blk .{ .wal = full };
            defer full.deinit();
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            const cells = try arena.allocator().alloc(f.Types.Values.Cell, selected.len);
            for (selected.columns(), cells) |index, *cell| cell.* = try f.Types.Values.cloneValidated(arena.allocator(), full.row().cells[index]);
            break :blk .{ .segment = .{ .arena = arena, .identity = full.identity, .cells = cells } };
        },
        .segment => blk: {
            var temporary: ?CachedSegment = null;
            defer if (temporary) |*segment| segment.deinit(self.allocator);
            const segment = try self.loadSegment(locator, &temporary);
            const footer = &segment.reader.footer;
            if (footer.object_id != schema.object or footer.schema_revision != schema.revision or
                !std.mem.eql(u8, &footer.layout_fingerprint, &try schema.layoutFingerprint())) return error.TableSchemaChanged;
            if (footer.segment_id != locator.lsn or locator.offset >= footer.pk_index.len or footer.pk_index[locator.offset].global_row_offset != locator.offset) return error.InvalidTableRowReference;
            const entry = footer.pk_index[locator.offset];
            if (!std.mem.eql(u8, segment.projection.columns(), selected.columns())) {
                if (segment.decoded) |*group| group.deinit();
                if (segment.encoded) |*encoded| encoded.deinit();
                segment.decoded = null;
                segment.encoded = null;
                segment.projection = selected;
            }
            if (segment.decoded) |*group| if (group.view().index != entry.row_group or group.view().rowIndex(entry.row_in_group) == null or (mode == .group and group.view().rows != null)) {
                group.deinit();
                segment.decoded = null;
            };
            if (segment.encoded) |*encoded| if (encoded.index != entry.row_group) {
                encoded.deinit();
                segment.encoded = null;
            };
            if (segment.decoded == null) {
                var projection: [128]usize = undefined;
                for (projection[0..selected.len], selected.columns()) |*slot, index| slot.* = index;
                var source: SegmentSource = .{ .owner = self, .locator = locator };
                if (mode == .point) {
                    if (segment.encoded == null) segment.encoded = try segment.reader.encodedGroup(self.allocator, source.source(), schema, entry.row_group, projection[0..selected.len], f.TSeg.max_segment_bytes);
                    const decoded = try segment.encoded.?.select(self.allocator, schema, &.{entry.row_in_group}, self.options.segment_decode_bytes);
                    segment.decoded = .{ .owned = decoded };
                } else {
                    // Scans reuse verified plain payloads and bounded decoded
                    // metadata across adjacent rows; outputs detach below.
                    if (segment.encoded) |*encoded| encoded.deinit();
                    segment.encoded = null;
                    const buffered = try segment.reader.bufferedGroup(self.allocator, source.source(), schema, entry.row_group, projection[0..selected.len], f.TSeg.max_segment_bytes, self.options.segment_decode_bytes);
                    segment.decoded = .{ .buffered = buffered };
                }
                self.row_groups_decoded +|= 1;
            }
            var arena = std.heap.ArenaAllocator.init(allocator);
            errdefer arena.deinit();
            const cells = try arena.allocator().alloc(f.Types.Values.Cell, selected.len);
            const group = segment.decoded.?.view();
            const row_index = group.rowIndex(entry.row_in_group) orelse return error.InvalidTableRowReference;
            for (group.columns, cells) |column, *cell| {
                if (row_index >= column.len) return error.InvalidTableRowReference;
                cell.* = try f.Types.Values.cloneValidated(arena.allocator(), column[row_index]);
            }
            break :blk .{ .segment = .{ .arena = arena, .identity = entry.identity, .cells = cells } };
        },
    };
    errdefer result.deinit();
    var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
    if (!std.meta.eql(key, try r.rowKey(try result.row().storageKey(projected_schema, &actual)))) return error.InvalidTableRowReference;
    return result;
}

fn segmentKey(digest: [32]u8, buffer: *[96]u8) ![]const u8 {
    return std.fmt.bufPrint(buffer, "table-segments/{x}.tseg", .{&digest});
}

const CachedSegment = struct {
    digest: [32]u8,
    length: u32,
    reader: f.TSegReader,
    decoded: ?union(enum) {
        owned: f.TSegReader.Group,
        buffered: f.TSegReader.BufferedGroup,
        pub fn view(group: *@This()) *f.TSegReader.Group {
            return switch (group.*) {
                .owned => |*value| value,
                .buffered => |*value| &value.decoded,
            };
        }
        fn deinit(group: *@This()) void {
            switch (group.*) {
                inline else => |*value| value.deinit(),
            }
            group.* = undefined;
        }
    } = null,
    encoded: ?f.TSegReader.EncodedGroup = null,
    decisions: ?struct { plan: [32]u8, value: f.TSegReader.Decisions } = null,
    projection: f.TableProjection = .{},
    fn deinit(self: *CachedSegment, _: std.mem.Allocator) void {
        if (self.decoded) |*group| group.deinit();
        if (self.encoded) |*group| group.deinit();
        if (self.decisions) |*value| value.value.deinit();
        self.reader.deinit();
    }
};

fn loadSegment(self: *Self, locator: r.Locator, temporary: *?CachedSegment) !*CachedSegment {
    if (self.segment_cache) |*cached| {
        if (std.mem.eql(u8, &cached.digest, &locator.digest) and cached.length == locator.length) return cached;
        cached.deinit(self.allocator);
        self.segment_cache = null;
    }
    if (locator.length == 0 or locator.length > f.TSeg.max_segment_bytes) return error.InvalidTableRowReference;
    var source: SegmentSource = .{ .owner = self, .locator = locator };
    try source.verify();
    var reader = try f.TSegReader.open(self.allocator, source.source(), locator.length, f.TSeg.max_segment_bytes);
    errdefer reader.deinit();
    if (reader.footer.total_rows > max_changes) return error.InvalidTableSegment;
    const segment: CachedSegment = .{ .digest = locator.digest, .length = locator.length, .reader = reader };
    self.segment_reads +|= 1;
    if (locator.length <= self.options.segment_cache_bytes) {
        self.segment_cache = segment;
        return &self.segment_cache.?;
    }
    temporary.* = segment;
    return &temporary.*.?;
}

const SegmentSource = struct {
    owner: *Self,
    locator: r.Locator,
    fn source(self: *SegmentSource) f.TSegReader.Source {
        return .{ .context = self, .read = read };
    }
    fn verify(self: *SegmentSource) !void {
        var name: [96]u8 = undefined;
        const metadata = try self.owner.objects.head(try segmentKey(self.locator.digest, &name)) orelse return error.TableSegmentMissing;
        if (metadata.size != self.locator.length or !std.mem.eql(u8, &metadata.sha256, &self.locator.digest)) return error.InvalidTableRowReference;
    }
    fn read(context: *anyopaque, offset: u64, out: []u8) !void {
        const self: *SegmentSource = @ptrCast(@alignCast(context));
        if (offset > self.locator.length or out.len > self.locator.length - offset) return error.InvalidTableRowReference;
        var name: [96]u8 = undefined;
        const bytes = try self.owner.objects.getRange(try segmentKey(self.locator.digest, &name), offset, @intCast(out.len), out);
        if (bytes.len != out.len) return error.InvalidTableRowReference;
        if (bytes.ptr != out.ptr) @memcpy(out, bytes);
        self.owner.segment_range_reads +|= 1;
        self.owner.segment_bytes_read +|= out.len;
    }
};

fn stageSegment(self: *Self, allocator: std.mem.Allocator, schema: f.TableSchema.Schema, segment_id: u64, rows: []const f.TableRow.Row) !struct { content: d.Content, footer: f.TSeg.Footer } {
    const buffer = try allocator.alloc(u8, f.TSeg.max_segment_bytes);
    defer allocator.free(buffer);
    const bytes = try f.TSeg.writeSegment(allocator, schema, rows, .{ .segment_id = segment_id, .rows_per_group = self.options.segment_rows_per_group }, buffer);
    const digest = r.hash(bytes);
    var name: [96]u8 = undefined;
    const metadata = try self.objects.putImmutable(try segmentKey(digest, &name), bytes, digest);
    if (metadata.size != bytes.len or !std.mem.eql(u8, &metadata.sha256, &digest)) return error.InvalidTableSegment;
    return .{ .content = .{ .bytes = bytes.len, .sha256 = digest }, .footer = try f.TSeg.readFooter(allocator, bytes) };
}

/// Flush at most one bounded group of accepted WAL rows. The accepted row index
/// itself is the paged manifest; replacing locators publishes no logical change.
pub fn flush(self: *Self, guard: Guard) !usize {
    var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.build_resident_bytes };
    defer self.build_resident_peak = memory.peak;
    return self.flushWithinBudget(memory.allocator(), guard) catch |err| return buildFailure(&memory, err);
}

fn flushWithinBudget(self: *Self, allocator: std.mem.Allocator, guard: Guard) !usize {
    try self.ready();
    if (self.root.retired) return error.TableRetired;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var arena = std.heap.ArenaAllocator.init(allocator);
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
    try self.publishSegmentRows(a, rows.items, guard);
    return rows.items.len;
}

fn publishSegmentRows(self: *Self, allocator: std.mem.Allocator, rows: []const f.TableRow.Row, guard: Guard) !void {
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    const segment = try self.stageSegment(allocator, self.declaration.schema.schema, next.next_segment, rows);
    next.next_segment = try std.math.add(u64, next.next_segment, 1);
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    var offset: usize = 0;
    while (offset < segment.footer.pk_index.len) {
        const count = @min(pages.mutation_batch, segment.footer.pk_index.len - offset);
        var changes: [pages.mutation_batch]pages.Mutation = undefined;
        var keys: [pages.mutation_batch]pages.Key = undefined;
        var locators: [pages.mutation_batch]r.Locator = undefined;
        for (segment.footer.pk_index[offset..][0..count], 0..) |entry, i| {
            locators[i] = .{ .kind = .segment, .lsn = segment.footer.segment_id, .offset = entry.global_row_offset, .length = @intCast(segment.content.bytes), .digest = segment.content.sha256 };
            keys[i] = try r.rowKey(entry.pk_sort_key);
            const previous = try r.Locator.decode(try self.tree().get(next.rows, keys[i]) orelse return error.InvalidTableRowReference);
            changes[i] = .{ .key = try previous.scanKey(), .value = null };
        }
        next.scan_rows = try self.tree().mutate(next.scan_rows, changes[0..count]);
        for (0..count) |i| changes[i] = .{ .key = keys[i], .value = try locators[i].encode() };
        next.rows = try self.tree().mutate(next.rows, changes[0..count]);
        for (0..count) |i| changes[i] = .{ .key = try locators[i].scanKey(), .value = try locators[i].scanValue(keys[i]) };
        next.scan_rows = try self.tree().mutate(next.scan_rows, changes[0..count]);
        offset += count;
    }
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .checkpoint }, &.{}, guard);
    try self.reply();
}

pub const CompactionLimits = struct {
    rows: usize = max_changes,
    encoded_bytes: usize = max_row_bytes,
    /// Private row/encoder/build allocations, separate from configured reader
    /// caches, index staging work and provider buffers.
    resident_bytes: usize = 64 * 1024 * 1024,
    fn validate(self: CompactionLimits) !void {
        if (self.rows == 0 or self.rows > max_changes or self.encoded_bytes == 0 or
            self.encoded_bytes > max_row_bytes or self.resident_bytes == 0) return error.InvalidTableCompactionBudget;
    }
};
pub const CompactionProgress = struct {
    before_segment: u64,
    rows: usize,
    input_segments: usize,
    encoded_bytes: usize,
    resident_peak: usize,
    complete: bool,
};

/// Rewrite live rows from segments below a fixed, previously observed
/// next_segment. New output sorts above that boundary, so the accepted row
/// locators themselves are resumable progress after a lost reply/restart.
/// The caller retains the same boundary until complete; no history expires.
pub fn compact(self: *Self, before_segment: u64, limits: CompactionLimits, guard: Guard) !CompactionProgress {
    try self.ready();
    try limits.validate();
    if (before_segment == 0 or before_segment > self.root.next_segment) return error.InvalidTableBasis;
    if (self.root.retired) return error.TableRetired;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = limits.resident_bytes };
    return self.compactBounded(before_segment, limits, &memory, guard) catch |err| {
        return if (err == error.OutOfMemory and memory.exhausted) error.TableCompactionBudget else err;
    };
}

fn compactBounded(self: *Self, before_segment: u64, limits: CompactionLimits, memory: *f.MemoryBudget, guard: Guard) !CompactionProgress {
    const ordinary_log = self.log;
    const ordinary_objects = self.objects;
    const ordinary_store = self.index.store;
    defer {
        self.log = ordinary_log;
        self.objects = ordinary_objects;
        self.index.store = ordinary_store;
    }
    if (self.options.control) |control| {
        self.log = control.log;
        self.objects = control.objects;
        self.index.store = control.objects;
    }
    // A strict prefix of every segment locator skips all WAL locators with one
    // paged seek, independently of unflushed backlog size.
    const first = try pages.Key.init(&.{2});
    const initial = try self.scan(self.root, first);
    if (initial.entries[0] == null or (try r.Locator.decode(initial.entries[0].?.value)).lsn >= before_segment) {
        return .{ .before_segment = before_segment, .rows = 0, .input_segments = 0, .encoded_bytes = 0, .resident_peak = 0, .complete = true };
    }
    const bounded = memory.allocator();
    var arena = std.heap.ArenaAllocator.init(bounded);
    defer arena.deinit();
    const a = arena.allocator();
    const encoded = try bounded.alloc(u8, max_row_bytes);
    defer bounded.free(encoded);
    var rows: std.ArrayList(f.TableRow.Row) = .empty;
    var bytes: usize = 0;
    var segments: usize = 0;
    var last_segment: ?u64 = null;
    var after: ?pages.Key = first;
    find: while (rows.items.len < limits.rows) {
        const batch = try self.scan(self.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            if (rows.items.len == limits.rows) break :find;
            const locator = try r.Locator.decode(entry.value);
            if (locator.kind != .segment) return error.InvalidTableRowReference;
            if (locator.lsn >= before_segment) break :find;
            var owned = try self.readRow(bounded, self.root, entry.key, entry.value);
            defer owned.deinit();
            const row = owned.row();
            const length = (try row.encode(self.declaration.schema.schema, encoded)).len;
            if (length > limits.encoded_bytes - bytes) break :find;
            const cells = try a.alloc(f.Types.Values.Cell, row.cells.len);
            for (row.cells, cells) |cell, *copy| copy.* = try f.Types.Values.cloneValidated(a, cell);
            try rows.append(a, .{ .identity = row.identity, .cells = cells });
            bytes += length;
            if (last_segment == null or last_segment.? != locator.lsn) segments += 1;
            last_segment = locator.lsn;
            after = try locator.scanKey();
        };
        if (batch.next == null) break;
    }
    // One bounded metadata lookahead, before acceptance, identifies whether
    // this batch exhausts the fixed segment boundary without decoding a row.
    const remaining = try self.scan(self.root, after);
    const complete = if (remaining.entries[0]) |entry| (try r.Locator.decode(entry.value)).lsn >= before_segment else true;
    if (rows.items.len == 0) {
        if (!complete) return error.TableCompactionBudget;
        return .{ .before_segment = before_segment, .rows = 0, .input_segments = 0, .encoded_bytes = 0, .resident_peak = memory.peak, .complete = true };
    }
    try self.publishSegmentRows(a, rows.items, guard);
    return .{ .before_segment = before_segment, .rows = rows.items.len, .input_segments = segments, .encoded_bytes = bytes, .resident_peak = memory.peak, .complete = complete };
}

pub const ArchiveProgress = struct {
    through: d.Position,
    frames: u8,
    encoded_bytes: usize,
    complete: bool,
};

/// Copy a bounded prefix towards a fixed accepted frontier. Publication changes
/// physical placement only; receipts, history and row identities remain exact.
pub fn archive(self: *Self, through: d.Position, limits: Archive.Limits, guard: Guard) !ArchiveProgress {
    try self.ready();
    try limits.validate();
    if (through.partition != self.root.partition or through.next_lsn > self.root.next_lsn) return error.InvalidTableBasis;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    var result: ArchiveProgress = .{ .through = .{ .partition = self.root.partition, .next_lsn = self.root.archive.through }, .frames = 0, .encoded_bytes = 0, .complete = self.root.archive.through >= through.next_lsn };
    if (result.complete) return result;
    const ordinary_log = self.log;
    const ordinary_store = self.index.store;
    defer {
        self.log = ordinary_log;
        self.index.store = ordinary_store;
    }
    if (self.options.control) |control| {
        self.log = control.log;
        self.index.store = control.objects;
    }
    try self.index.begin(self.options.index_work_bytes);
    defer self.index.end();
    var next = self.root;
    while (next.archive.through < through.next_lsn and result.frames < limits.frames) {
        var batch = try self.log.read(self.allocator, self.root.partition, next.archive.through, 1);
        defer batch.deinit();
        if (batch.frames.len != 1 or batch.frames[0].header.partition_id != self.root.partition or
            batch.frames[0].header.lsn != next.archive.through) return error.TableHistoryMissing;
        const frame = batch.frames[0];
        if (frame.payload.len > Log.max_payload_bytes) return error.InvalidTableHistory;
        const size = Log.alignedFrameSize(frame.payload.len);
        if (size > limits.encoded_bytes - result.encoded_bytes) break;
        const value = try Archive.stage(self.allocator, self.index.store, frame);
        next.archive.directory = try self.tree().put(next.archive.directory, try Archive.key(next.archive.through), value);
        next.archive.through += 1;
        result.frames += 1;
        result.encoded_bytes += size;
    }
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .archive }, &.{}, guard);
    try self.reply();
    result.through.next_lsn = next.archive.through;
    result.complete = next.archive.through >= through.next_lsn;
    return result;
}

/// Publish a verified recovery baseline covering at least the requested cut.
/// Retry the same cut after an uncertain reply; accepted coverage avoids another
/// append. This changes neither logical retention nor physical trim authority.
pub fn checkpoint(self: *Self, through: d.Position, guard: Guard) !Recovery.Reference {
    try self.ready();
    if (through.partition != self.root.partition or through.next_lsn == 0 or
        through.next_lsn > self.root.next_lsn) return error.InvalidTableBasis;
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
    }
    if (self.root.recovery) |reference| if (reference.next_lsn >= through.next_lsn) return reference;
    const ordinary_log = self.log;
    defer self.log = ordinary_log;
    const objects = if (self.options.control) |control| control.objects else self.objects;
    if (self.options.control) |control| self.log = control.log;
    const reference = try Recovery.stage(objects, .{ .root = self.root, .chain = self.chain });
    var next = self.root;
    next.recovery = reference;
    next.next_lsn = try std.math.add(u64, next.next_lsn, 1);
    try self.publish(.{ .definition = p.Growth.current_definition, .previous = self.chain, .root = next, .action = .recovery }, &.{}, guard);
    try self.reply();
    return reference;
}

/// Resume removal of WAL files covered by the accepted immutable archive. The
/// last acceptance record always remains in WAL, including after interruption.
pub fn trimArchived(self: *Self, guard: Guard) !u64 {
    try self.ready();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const through = self.root.archive.through;
    if (through == 0) return 0;
    self.log.trim(self.root.partition, through) catch |err| {
        self.recovery_required = true;
        return err;
    };
    return through;
}

/// Capture exactly the requested accepted frontier, including unflushed rows.
/// Complete logical history remains retained in WAL or accepted archives. Pin
/// ownership and release are durable; releasing a pin does not delete objects.
pub fn pin(self: *Self, owner: d.Operation, expected: d.Position, guard: Guard) !SnapshotHandle {
    return self.retain(owner, expected, .snapshot, guard);
}

/// Explicit retention of the original root and its logical successors. This
/// does not advance a computation or grant rights to read future history.
pub fn retainHistory(self: *Self, owner: d.Operation, expected: d.Position, guard: Guard) !SnapshotHandle {
    return self.retain(owner, expected, .history, guard);
}

fn retain(self: *Self, owner: d.Operation, expected: d.Position, retention: Retention, guard: Guard) !SnapshotHandle {
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
            if (retention != frozen.retention or expected.partition != frozen.root.partition or expected.next_lsn != frozen.root.next_lsn) return error.DataIdentityConflict;
            return handle;
        }
        if (self.root.retired) return error.TableRetired;
        if (self.root.next_lsn == 0) return error.TableNotCreated;
        if (expected.partition != self.root.partition or expected.next_lsn != self.root.next_lsn) return error.TableDataChanged;
    }
    const handle = try Snapshot.stage(self.allocator, self.objects, owner, retention, self.root, self.declaration.schema.schema);
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
        .interpretation = self.root.interpretation,
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
    var row = try self.readRowWithSchema(allocator, frozen.root, frozen.schema.schema, index_key, value, .point);
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
    return self.scanRetainedRoot(allocator, frozen.root, frozen.schema.schema, handle, handle.content, after, limits, guard);
}

/// Read a canonical physical column subset while preserving identity traversal,
/// full-key verification and the original retained interpretation. WAL rows use
/// bounded full decoding; segment reads fetch only the selected column pages.
pub fn scanSnapshotColumns(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, columns: []const u8, after: ?SnapshotCursor, limits: ReadLimits, guard: Guard) !SnapshotPage {
    try limits.validate();
    var frozen = try self.inspectSnapshot(allocator, handle, guard);
    defer frozen.deinit();
    const selected = try f.TableProjection.init(frozen.schema.schema, columns);
    const source = try selected.cursorSource(handle.content);
    const cursor: ?pages.Key = if (after) |value| blk: {
        if (!std.meta.eql(value.source, source)) return error.InvalidTableSnapshotCursor;
        const key = try pages.Key.init(&value.after);
        if (try self.tree().get(frozen.root.identities, key) == null) return error.InvalidTableSnapshotCursor;
        break :blk key;
    } else null;
    const page = try self.scanRootColumns(allocator, frozen.root, frozen.schema.schema, selected, cursor, limits, guard);
    return .{
        .source = handle,
        .interpretation = frozen.root.declared(),
        .accepted = .{ .partition = frozen.root.partition, .next_lsn = frozen.root.next_lsn },
        .changed_lsn = frozen.root.changed_lsn,
        .total_rows = frozen.root.live_rows,
        .rows = page.rows,
        .count = page.count,
        .encoded_bytes = page.encoded_bytes,
        .next = if (page.next) |next| .{ .source = source, .after = next } else null,
    };
}

/// Continuations bind the exact retained source and complete original plan.
/// The adapter must separately validate the plan's source-basis authority.
pub fn filteredCursorSource(handle: SnapshotHandle, plan: f.LogicalQuery.Plan) !d.Content {
    return filteredCursorFingerprint(handle, try plan.fingerprint());
}

pub fn filteredCursorFingerprint(handle: SnapshotHandle, fingerprint: [32]u8) !d.Content {
    try handle.content.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    const domain = "transit.table.filtered-cursor.v1\x00";
    hash.update(domain);
    hash.update(&p.Growth.definition_bytes);
    var size: [8]u8 = undefined;
    std.mem.writeInt(u64, &size, handle.content.bytes, .little);
    hash.update(&size);
    hash.update(&handle.content.sha256);
    hash.update(&fingerprint);
    return .{ .bytes = domain.len + 32 + 8 + 32 + 32, .sha256 = hash.finalResult() };
}

/// Examine at most one identity-index page. Segment decisions are evaluated in
/// encoded form and cached, but only live locators participate in source order.
/// Empty pages may have continuations. `failure` must be settled after consuming
/// the preceding returned rows; it never establishes source completion.
pub fn scanSnapshotFiltered(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, plan: f.LogicalQuery.Plan, after: ?SnapshotCursor, limits: ReadLimits, guard: Guard) !FilteredPage {
    try limits.validate();
    var frozen = try self.inspectSnapshot(allocator, handle, guard);
    defer frozen.deinit();
    const schema = frozen.schema.schema;
    const selected = try f.TableProjection.fromPlan(schema, plan);
    var instructions: [f.ColumnPredicate.Program.max_instructions]f.ColumnPredicate.Program.Instruction = undefined;
    const program = try f.ColumnPredicate.Program.fromPlan(plan, &instructions);
    try program.validate(schema);
    const source = try filteredCursorSource(handle, plan);
    const fingerprint = try plan.fingerprint();
    const cursor: ?pages.Key = if (after) |value| blk: {
        if (!std.meta.eql(value.source, source)) return error.InvalidTableSnapshotCursor;
        const key = try pages.Key.init(&value.after);
        if (try self.tree().get(frozen.root.identities, key) == null) return error.InvalidTableSnapshotCursor;
        break :blk key;
    } else null;
    var result: FilteredPage = .{ .page = .{
        .source = handle,
        .interpretation = frozen.root.declared(),
        .accepted = .{ .partition = frozen.root.partition, .next_lsn = frozen.root.next_lsn },
        .changed_lsn = frozen.root.changed_lsn,
        .total_rows = frozen.root.live_rows,
    } };
    errdefer result.deinit();
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const projected = try selected.projectedSchema(schema, &columns);
    const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
    defer allocator.free(scratch);
    const batch = try self.tree().scan(frozen.root.identities, cursor);
    var previous = cursor;
    for (batch.entries) |slot| {
        const entry = slot orelse break;
        if (result.page.count == limits.rows) {
            result.page.next = .{ .source = source, .after = previous.?.data[0..f.TableRow.Identity.encoded_bytes].* };
            break;
        }
        if (entry.key.len != f.TableRow.Identity.encoded_bytes or entry.value.len != 32) return error.InvalidTableRowReference;
        const identity = try f.TableRow.Identity.decode(entry.key.data[0..f.TableRow.Identity.encoded_bytes]);
        const key = try pages.Key.init(entry.value.data[0..32]);
        const value = try self.tree().get(frozen.root.rows, key) orelse return error.InvalidTableRowReference;
        const locator = try r.Locator.decode(value);
        var row: ?OwnedRow = null;
        defer if (row) |*owned| owned.deinit();
        const decision = switch (locator.kind) {
            .segment => try self.segmentDecision(schema, locator, key, identity, program, fingerprint),
            .wal => blk: {
                row = try self.readRowWithSchema(allocator, frozen.root, schema, key, value, .point);
                if (!std.meta.eql(identity, row.?.row().identity)) return error.InvalidTableRowReference;
                var instruction: ?u8 = null;
                const truth = program.truth(schema, row.?.row().cells, &instruction) catch |err| switch (err) {
                    error.QueryTypeError, error.QueryConflict => {
                        const at = instruction orelse return err;
                        break :blk f.TSegReader.Decision{ .failure = .{ .column = program.instructions[at].atom.column, .instruction = at, .outcome = if (err == error.QueryTypeError) .type_error else .conflict } };
                    },
                    else => return err,
                };
                break :blk f.TSegReader.Decision{ .selected = truth.selects() };
            },
        };
        if (decision.failure) |failure| {
            result.failure = .{ .identity = identity, .column = failure.column, .instruction = failure.instruction, .outcome = failure.outcome };
            break;
        }
        if (decision.selected) {
            if (row) |*full| {
                if (selected.len != schema.columns.len) {
                    var arena = std.heap.ArenaAllocator.init(allocator);
                    errdefer arena.deinit();
                    const cells = try arena.allocator().alloc(f.Types.Values.Cell, selected.len);
                    for (selected.columns(), cells) |index, *cell| cell.* = try f.Types.Values.cloneValidated(arena.allocator(), full.row().cells[index]);
                    full.deinit();
                    row = .{ .segment = .{ .arena = arena, .identity = identity, .cells = cells } };
                }
            } else {
                row = try self.readRowWithColumns(allocator, frozen.root, schema, key, value, .point, selected);
                if (!std.meta.eql(identity, row.?.row().identity)) return error.InvalidTableRowReference;
            }
            const encoded = try row.?.row().encode(projected, scratch);
            if (encoded.len > limits.encoded_bytes - result.page.encoded_bytes) {
                if (result.page.count == 0) return error.TableReadBudgetTooSmall;
                result.page.next = .{ .source = source, .after = previous.?.data[0..f.TableRow.Identity.encoded_bytes].* };
                break;
            }
            result.offsets[result.page.count] = result.examined + 1;
            result.page.rows[result.page.count] = row;
            row = null;
            result.page.count += 1;
            result.page.encoded_bytes += @intCast(encoded.len);
        }
        result.examined += 1;
        previous = entry.key;
    }
    if (result.failure == null and result.page.next == null) if (batch.next) |key| {
        if (key.len != f.TableRow.Identity.encoded_bytes) return error.InvalidTableRowReference;
        result.page.next = .{ .source = source, .after = key.data[0..f.TableRow.Identity.encoded_bytes].* };
    };
    // No buffered row, empty page, semantic failure or terminal count bypasses
    // the current disclosure gate.
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}

fn segmentDecision(self: *Self, schema: f.TableSchema.Schema, locator: r.Locator, key: pages.Key, identity: f.TableRow.Identity, program: f.ColumnPredicate.Program, fingerprint: [32]u8) !f.TSegReader.Decision {
    var temporary: ?CachedSegment = null;
    defer if (temporary) |*segment| segment.deinit(self.allocator);
    const segment = try self.loadSegment(locator, &temporary);
    const footer = &segment.reader.footer;
    if (footer.object_id != schema.object or footer.schema_revision != schema.revision or
        !std.mem.eql(u8, &footer.layout_fingerprint, &try schema.layoutFingerprint())) return error.TableSchemaChanged;
    if (footer.segment_id != locator.lsn or locator.offset >= footer.pk_index.len or footer.pk_index[locator.offset].global_row_offset != locator.offset) return error.InvalidTableRowReference;
    const entry = footer.pk_index[locator.offset];
    if (!std.meta.eql(entry.identity, identity) or !std.meta.eql(key, try r.rowKey(entry.pk_sort_key))) return error.InvalidTableRowReference;
    if (segment.decisions) |*cached| if (cached.value.index != entry.row_group or !std.mem.eql(u8, &cached.plan, &fingerprint)) {
        cached.value.deinit();
        segment.decisions = null;
    };
    if (segment.decisions == null) {
        var source: SegmentSource = .{ .owner = self, .locator = locator };
        const decisions = try segment.reader.decisions(self.allocator, source.source(), schema, entry.row_group, program, .{ .decoded_bytes = self.options.segment_predicate_bytes });
        segment.decisions = .{ .plan = fingerprint, .value = decisions };
        self.row_groups_filtered +|= 1;
    }
    if (entry.row_in_group >= segment.decisions.?.value.rows.len) return error.InvalidTableRowReference;
    return segment.decisions.?.value.rows[entry.row_in_group];
}

/// Traverse complete collation-aware keys on an exact retained root. A cursor
/// cannot change either its source or interval, including after rename/rewrite.
pub fn rangeSnapshot(self: *Self, allocator: std.mem.Allocator, handle: SnapshotHandle, range: KeyRange, after: ?KeyRange.Cursor, limits: ReadLimits, guard: Guard) !KeyRangePage {
    try limits.validate();
    const interval = try range.fingerprint();
    var frozen = try self.inspectSnapshot(allocator, handle, guard);
    defer frozen.deinit();
    var previous: ?KeyRange.Key = null;
    if (after) |cursor| {
        try cursor.after.validate();
        if (!std.meta.eql(cursor.source, handle.content) or !std.mem.eql(u8, &cursor.interval, &interval) or
            !range.contains(cursor.after.slice()) or try self.orderedKeys().get(frozen.root.ordered_rows, cursor.after.slice()) == null) return error.InvalidTableSnapshotCursor;
        previous = cursor.after;
    }
    var result: KeyRangePage = .{
        .source = handle,
        .interpretation = frozen.root.declared(),
        .accepted = .{ .partition = frozen.root.partition, .next_lsn = frozen.root.next_lsn },
        .changed_lsn = frozen.root.changed_lsn,
        .total_rows = frozen.root.live_rows,
    };
    errdefer result.deinit();
    const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
    defer allocator.free(scratch);
    while (try self.orderedKeys().seek(frozen.root.ordered_rows, if (previous) |*key| .{ .key = key.slice(), .inclusive = false } else range.lower, range.upper)) |entry| {
        if (result.count == limits.rows) {
            result.next = .{ .source = handle.content, .interval = interval, .after = previous.? };
            break;
        }
        const row_key = try pages.Key.init(&entry.value);
        const locator = try self.tree().get(frozen.root.rows, row_key) orelse return error.InvalidTableRowReference;
        var row = try self.readRowWithSchema(allocator, frozen.root, frozen.schema.schema, row_key, locator, .group);
        var moved = false;
        defer if (!moved) row.deinit();
        var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
        if (!std.mem.eql(u8, entry.key.slice(), try row.row().storageKey(frozen.schema.schema, &key_bytes))) return error.InvalidTableRowReference;
        const encoded = try row.row().encode(frozen.schema.schema, scratch);
        if (encoded.len > limits.encoded_bytes - result.encoded_bytes) {
            if (result.count == 0) return error.TableReadBudgetTooSmall;
            result.next = .{ .source = handle.content, .interval = interval, .after = previous.? };
            break;
        }
        result.rows[result.count] = row;
        moved = true;
        result.count += 1;
        result.encoded_bytes += @intCast(encoded.len);
        previous = entry.key;
    }
    // Empty ranges, completion metadata and buffered values all require current
    // permission at disclosure, just like identity-ordered retained scans.
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}

/// Cursor attribution includes the historical WAL commitment, so a cursor from
/// one revision cannot skip rows in another revision under the same lease.
pub fn scanHistory(self: *Self, allocator: std.mem.Allocator, point: HistoryPoint, after: ?SnapshotCursor, limits: ReadLimits, guard: Guard) !HistoryRows {
    try limits.validate();
    var historical = try self.historyAt(allocator, point, guard);
    defer historical.deinit();
    return .{ .point = point, .page = try self.scanRetainedRoot(allocator, historical.root, historical.declaration.schema.schema, point.lease, try point.cursorSource(), after, limits, guard) };
}

fn scanRetainedRoot(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, handle: SnapshotHandle, cursor_source: d.Content, after: ?SnapshotCursor, limits: ReadLimits, guard: Guard) !SnapshotPage {
    const cursor: ?pages.Key = if (after) |value| blk: {
        if (!std.meta.eql(value.source, cursor_source)) return error.InvalidTableSnapshotCursor;
        const key = try pages.Key.init(&value.after);
        if (try self.tree().get(basis.identities, key) == null) return error.InvalidTableSnapshotCursor;
        break :blk key;
    } else null;
    const page = try self.scanRootRows(allocator, basis, schema, cursor, limits, guard);
    return .{
        .source = handle,
        .interpretation = basis.declared(),
        .accepted = .{ .partition = basis.partition, .next_lsn = basis.next_lsn },
        .changed_lsn = basis.changed_lsn,
        .total_rows = basis.live_rows,
        .rows = page.rows,
        .count = page.count,
        .encoded_bytes = page.encoded_bytes,
        .next = if (page.next) |next| .{ .source = cursor_source, .after = next } else null,
    };
}

/// The owner must serialize calls, as for all partition methods. This copies
/// one current root under current read authority without appending a record,
/// acquiring a pin or promising that a later request observes the same root.
pub fn observeRows(self: *Self, allocator: std.mem.Allocator, limits: ReadLimits, guard: Guard) !CurrentPage {
    try self.ready();
    try limits.validate();
    {
        _ = try guard.acquire(guard.context);
        defer guard.release(guard.context);
        if (self.root.retired) return error.TableRetired;
        if (self.root.next_lsn == 0) return error.TableNotFound;
    }
    const basis = self.root;
    const page = try self.scanRootRows(allocator, basis, self.declaration.schema.schema, null, limits, guard);
    return .{
        .interpretation = basis.declared(),
        .accepted = .{ .partition = basis.partition, .next_lsn = basis.next_lsn },
        .changed_lsn = basis.changed_lsn,
        .total_rows = basis.live_rows,
        .rows = page.rows,
        .count = page.count,
        .encoded_bytes = page.encoded_bytes,
        .more = page.next != null,
    };
}

/// An optimistic read of current data. The position is a logical-change fence,
/// not a retention pin: any intervening logical change rejects the read.
/// Physical/control publications and accepted no-ops may advance the root.
fn currentBasis(self: *Self, expected: d.Position, guard: Guard) !Root {
    try self.ready();
    try expected.validate();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (self.root.retired) return error.TableRetired;
    if (self.root.next_lsn == 0) return error.TableNotFound;
    if (expected.next_lsn == 0 or !expected.unchangedAt(.{ .partition = self.root.partition, .next_lsn = self.root.next_lsn }, self.root.changed_lsn)) return error.TableDataChanged;
    return self.root;
}

pub fn readCurrent(self: *Self, allocator: std.mem.Allocator, expected: d.Position, key: []const u8, guard: Guard) !?OwnedRow {
    const basis = try self.currentBasis(expected, guard);
    const index_key = try r.rowKey(key);
    var row: ?OwnedRow = if (try self.tree().get(basis.rows, index_key)) |value|
        try self.readRowWithSchema(allocator, basis, self.declaration.schema.schema, index_key, value, .point)
    else
        null;
    errdefer if (row) |*value| value.deinit();
    if (row) |value| {
        var actual: [f.Collation.max_sort_key_bytes]u8 = undefined;
        if (!std.mem.eql(u8, key, try value.row().storageKey(self.declaration.schema.schema, &actual))) return error.TableKeyHashCollision;
    }
    // Absence and buffered rows both need current disclosure authority.
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return row;
}

/// Ordered suffix under the original logical-change fence. Calls must remain
/// serialized by the owner. A cursor is only a seek key; complete coverage
/// requires an unbroken traversal from null and the original total row count.
pub fn scanCurrent(self: *Self, allocator: std.mem.Allocator, expected: d.Position, after: ?f.TableRow.Identity, limits: ReadLimits, guard: Guard) !RowPage {
    try limits.validate();
    const basis = try self.currentBasis(expected, guard);
    const cursor: ?pages.Key = if (after) |identity| blk: {
        const key = try pages.Key.init(&try identity.encode());
        if (try self.tree().get(basis.identities, key) == null) return error.InvalidTableSnapshotCursor;
        break :blk key;
    } else null;
    return self.scanRootRows(allocator, basis, self.declaration.schema.schema, cursor, limits, guard);
}

fn scanRootRows(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, cursor: ?pages.Key, limits: ReadLimits, guard: Guard) !RowPage {
    var selected: f.TableProjection = .{ .len = @intCast(schema.columns.len) };
    for (selected.indices[0..selected.len], 0..) |*column, i| column.* = @intCast(i);
    return self.scanRootColumns(allocator, basis, schema, selected, cursor, limits, guard);
}

fn scanRootColumns(self: *Self, allocator: std.mem.Allocator, basis: Root, schema: f.TableSchema.Schema, selected: f.TableProjection, cursor: ?pages.Key, limits: ReadLimits, guard: Guard) !RowPage {
    var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
    const projected_schema = if (selected.len == schema.columns.len) schema else try selected.projectedSchema(schema, &columns);
    const batch = try self.tree().scan(basis.identities, cursor);
    var result: RowPage = .{};
    errdefer result.deinit();
    const scratch = try allocator.alloc(u8, f.TableRow.max_bytes);
    defer allocator.free(scratch);
    var previous: ?pages.Key = cursor;
    for (batch.entries) |slot| {
        const entry = slot orelse break;
        if (result.count == limits.rows) {
            result.next = previous.?.data[0..f.TableRow.Identity.encoded_bytes].*;
            break;
        }
        if (entry.key.len != f.TableRow.Identity.encoded_bytes or entry.value.len != 32) return error.InvalidTableRowReference;
        const row_key = try pages.Key.init(entry.value.data[0..32]);
        const locator = try self.tree().get(basis.rows, row_key) orelse return error.InvalidTableRowReference;
        var row = try self.readRowWithColumns(allocator, basis, schema, row_key, locator, .group, selected);
        var moved = false;
        defer if (!moved) row.deinit();
        if (!std.mem.eql(u8, entry.key.data[0..entry.key.len], &try row.row().identity.encode())) return error.InvalidTableRowReference;
        const encoded = try row.row().encode(projected_schema, scratch);
        if (encoded.len > limits.encoded_bytes - result.encoded_bytes) {
            if (result.count == 0) return error.TableReadBudgetTooSmall;
            result.next = previous.?.data[0..f.TableRow.Identity.encoded_bytes].*;
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
        result.next = key.data[0..f.TableRow.Identity.encoded_bytes].*;
    };
    // Authorization may change while rows are decoded or copied. Recheck after
    // buffering, including empty output and end-of-source metadata.
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    return result;
}
