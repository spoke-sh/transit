//! Retained direct-data dependencies. A storage adapter supplies durable work
//! and marks; this owner supplies catalog/Table interpretation and reachability.
const std = @import("std");
const c = @import("root.zig");
const s = c.storage;
const d = c.protocol.DataLifecycle;
const r = @import("DirectCatalogRecords.zig");
const CatalogStore = @import("DirectCatalogStore.zig");
const Intent = @import("DirectCatalogIntent.zig");
const Role = enum { current, recovery, history, snapshot, workspace };
const Walk = s.TableStorageWalk;
const Context = Walk.Context;
const W = c.DirectTransactionWorkspace;
const LogContext = struct {
    interpretation: d.Definition,
    partition: u64,
    ordinal: u32,
    next_lsn: u64,
    next_offset: u64,
    segments: ?s.TreeStore.pages.Reference,
    hidden: s.BitmapDirectory.Root,
    queue_read_releases: ?s.TreeStore.pages.Reference,
    archive: s.LogHistory.Coverage,
    fn fromRoot(root: s.StreamPartition.Root, archive: s.LogHistory.Coverage) !LogContext {
        try root.validate();
        return .{ .interpretation = root.declared.declaration.interpretation, .partition = root.initialization.partition, .ordinal = root.initialization.ordinal, .next_lsn = root.next_lsn, .next_offset = root.next_offset, .segments = root.segments, .hidden = root.hidden, .queue_read_releases = if (root.queue) |queue| queue.read_releases else null, .archive = archive };
    }
    fn requireTarget(self: LogContext, target: c.protocol.StreamQueue.Partition) !void {
        try target.validate();
        if (!std.meta.eql(target.interpretation.object, self.interpretation.object) or target.partition != self.ordinal or target.interpretation.revision > self.interpretation.revision or
            (target.interpretation.revision == self.interpretation.revision and !std.meta.eql(target.interpretation, self.interpretation))) return error.InvalidLogStorageGraph;
    }
    fn owner(self: LogContext, key: s.TreeStore.pages.Key) !d.Operation {
        if (key.len != 16) return error.InvalidLogStorageGraph;
        const identity: d.Operation = .{ .scope = self.interpretation.object.scope, .principal = std.mem.readInt(u64, key.data[0..8], .big), .operation = std.mem.readInt(u64, key.data[8..16], .big) };
        try identity.validate();
        return identity;
    }
};
const LogIndexKind = enum { pages_only, batches, receipts, producer_receipts, producers, groups, group_offsets, pins, transaction_pins, bitmap, ordered_keys, queue_items, queue_sidecars, queue_keys, queue_read_releases };
const TimerContext = struct {
    log: LogContext,
    seed: c.protocol.StreamQueue.Partition,
    kind: s.QueueTimeRun.Kind,
    serial: u64,
    fn validate(self: TimerContext) !void {
        try self.log.requireTarget(self.seed);
        if (self.seed.interpretation.revision != 1 or self.serial == 0) return error.InvalidLogStorageGraph;
    }
};
const DocumentContext = struct {
    interpretation: d.Definition,
    partition: u64,
    ordinal: u32,
    next_lsn: u64,
    archive: s.LogHistory.Coverage,
    fn fromRoot(root: s.DocumentPartitionRecord.Root, archive: s.LogHistory.Coverage) !DocumentContext {
        try root.validate();
        return .{
            .interpretation = root.declared.declaration.interpretation,
            .partition = root.initialization.partition,
            .ordinal = root.initialization.ordinal,
            .next_lsn = root.next_lsn,
            .archive = archive,
        };
    }
    fn requireTarget(self: DocumentContext, target: c.protocol.DocumentOperation.Partition) !void {
        try target.validate();
        if (!std.meta.eql(target.interpretation.object, self.interpretation.object) or
            target.partition != self.ordinal or
            target.interpretation.revision > self.interpretation.revision or
            (target.interpretation.revision == self.interpretation.revision and !std.meta.eql(target.interpretation, self.interpretation)))
        {
            return error.InvalidDocumentStorageGraph;
        }
    }
    fn owner(self: DocumentContext, key: s.TreeStore.pages.Key) !d.Operation {
        if (key.len != 16) return error.InvalidDocumentStorageGraph;
        const identity: d.Operation = .{
            .scope = self.interpretation.object.scope,
            .principal = std.mem.readInt(u64, key.data[0..8], .big),
            .operation = std.mem.readInt(u64, key.data[8..16], .big),
        };
        try identity.validate();
        return identity;
    }
};
const DocumentIndexKind = enum { pages_only, documents, revisions, replicas, operations, reads, logical_records, logical_ordered };

pub const Work = union(enum) {
    catalog_history: c.DirectCatalogRoots,
    branch: struct { root: r.Root, progress: c.DirectClientToken.Progress },
    transaction: struct { root: r.Root, progress: c.DirectClientToken.Progress, slot: u8 = 0 },
    transaction_walk: struct { walk: c.DirectCatalogWalk, head: W.Head, scope: c.DirectRecord.Scope, tables: bool },
    transaction_intent: W.Request,
    transaction_log_intent: c.DirectTransactionLogWork.Request,
    private_index: struct { reference: s.TreeStore.pages.Reference, height: ?u8 = null, slot: u8 = 0, marked: bool = false },
    transaction_controls: struct { walk: c.DirectCatalogWalk, head: W.Head, scope: c.DirectRecord.Scope },
    transaction_savepoints: struct { root: r.Root, head: W.Head, scope: c.DirectRecord.Scope, next: ?c.DirectRecord.Reference, depth: u64 },
    table_preparation: struct { reference: s.TableTransaction.Reference, archive: ?s.TableArchive.Coverage = null },
    transaction_journal: u64,
    transaction_directory: struct { catalog: r.Root, identity: c.protocol.Transaction.Identity, directory: c.protocol.Transaction.Directory, kind: s.TransactionDirectory.Kind, after: ?s.TransactionDirectory.Cursor = null, started: bool = false },
    catalog_root: struct { root: r.Root, slot: u8 = 0 },
    catalog_walk: c.DirectCatalogWalk,
    catalog_intent: struct { configuration: r.Configuration, operation: r.Operation },
    log_operation: struct { configuration: r.Configuration, operation: c.DirectLog.Operation },
    log_declaration: s.LogDeclaration.Stored,
    queue_destination: d.Definition,
    log_partitions: struct { definition: c.DirectLog.Definition, initialized: u32, next: u32 = 0 },
    log_initialization: s.LogInitialization.Request,
    log_history: s.LogStorageRoots,
    log_root: struct { root: s.StreamPartition.Root, archive: s.LogHistory.Coverage, slot: u8 = 0 },
    log_index: struct { context: LogContext, reference: s.TreeStore.pages.Reference, kind: LogIndexKind, prefix_bytes: u16 = 0, height: ?u8 = null, slot: u8 = 0, marked: bool = false },
    log_compaction: struct { context: LogContext, state: s.StreamCompaction.State, slot: u8 = 0 },
    queue_sidecar: struct { context: LogContext, manifest: s.Tack, slot: u8 = 0 },
    queue_schedule: struct { context: TimerContext, root: s.QueueSchedule.Root, slot: u8 = 0, started: bool = false },
    queue_timer_index: struct { context: TimerContext, reference: s.TreeStore.pages.Reference, kind: enum { pending, levels }, height: ?u8 = null, slot: u8 = 0, marked: bool = false },
    queue_timer_run: struct { context: TimerContext, audit: s.QueueTimeDirectory.Audit, started: bool = false },
    queue_selection: struct { context: LogContext, receipt: c.protocol.StreamQueue.ClaimReceipt, slot: u8 = 0 },
    log_preparation: struct { reference: s.LogTransaction.Reference, archive: ?s.LogHistory.Coverage = null, slot: u8 = 0 },
    log_actions: struct { identity: c.protocol.Transaction.Identity, guard: c.protocol.Transaction.LogGuard, directory: c.protocol.Transaction.Directory, after: ?s.LogTransactionActions.Cursor = null, started: bool = false, count: u64 = 0, payload_bytes: u64 = 0 },
    log_transaction_source: struct { context: LogContext, handle: c.protocol.Transaction.Pin },
    log_read: struct { context: LogContext, handle: c.protocol.StreamRead.Handle, slot: u8 = 0 },
    log_segment: struct { context: LogContext, descriptor: s.LogSegment.Descriptor, evidence: s.LogEvidence.Record },
    log_wal: struct { context: LogContext, lsn: u64, receipt: ?c.protocol.StreamQueue.AppendReceipt = null },
    log_archive_range: struct { context: LogContext, from: u64, until: u64 },
    document_declaration: s.DocumentDeclaration.Stored,
    document_initialization: s.DocumentInitialization.Request,
    document_history: s.DocumentStorageRoots.Cursor,
    document_root: struct { root: s.DocumentPartitionRecord.Root, archive: s.LogHistory.Coverage, slot: u8 = 0 },
    document_index: struct { context: DocumentContext, reference: s.TreeStore.pages.Reference, kind: DocumentIndexKind, prefix_bytes: u16 = 0, height: ?u8 = null, slot: u8 = 0, marked: bool = false },
    document_read: struct { context: DocumentContext, handle: c.protocol.DocumentOperation.Read.Handle },
    document_wal: struct { context: DocumentContext, lsn: u64 },
    table_history: s.TableStorageRoots,
    table_root: struct { root: s.TablePartition.Root, archive: s.TableArchive.Coverage, role: Role, slot: u8 = 0 },
    table_walk: struct { walk: Walk, archive: s.TableArchive.Coverage, live_pins: bool },
    declaration: s.TableDeclaration.Stored,
    evidence: struct { context: Context, edge: @FieldType(Walk.Edge, "evidence") },
    intent: s.TablePartition.Operation,
    snapshot: struct { context: Context, archive: s.TableArchive.Coverage, handle: s.TableSnapshot.Handle, live: bool },
    wal: struct { context: Context, archive: s.TableArchive.Coverage, lsn: u64 },
    segment: d.Content,
};

pub fn collectible(key: []const u8) bool {
    // Saved staging references and permanent operation-to-target reservations
    // have independent lifetimes. Unknown generic object namespaces also remain
    // outside this collector's authority.
    for ([_][]const u8{ "data-index/", "bitmap-containers/", "data-maintenance/", "catalog-intents/", "catalog-log-intents/", "log-definitions/", "log-evidence/", "log-reads/", "log-tx-sources/", "log-preparations/", "transaction-log-actions/", "transaction-log-payload/", "log-checkpoints/", "log-segments/", "log-segment-metadata/", "queue-selections/", "queue-time-buffers/", "queue-time-runs/", "document-definitions/", "document-evidence/", "document-reads/", "document-checkpoints/", "document-payloads/", "document-states/", "document-segment/", "table-definitions/", "table-evidence/", "table-intents/", "table-snapshots/", "table-checkpoints/", "table-history/", "table-segments/", "table-preparations/" }) |prefix| {
        if (std.mem.startsWith(u8, key, prefix)) return true;
    }
    return false;
}

pub fn fromFrame(allocator: std.mem.Allocator, frame: s.TransitLog.Frame) !Work {
    if (std.mem.startsWith(u8, frame.payload, "LINIT001")) return .{ .log_initialization = (try s.LogInitialization.decode(allocator, frame)).request };
    if (std.mem.startsWith(u8, frame.payload, "LOGPART1")) {
        const record = (try s.LogPartitionRecord.decode(allocator, frame, frame.header.partition_id, frame.header.lsn)).record;
        return .{ .log_history = try .init(.{ .root = record.root, .commitment = s.LogEvidence.hash(frame.payload) }) };
    }
    if (std.mem.startsWith(u8, frame.payload, "DINIT001")) return .{ .document_initialization = (try s.DocumentInitialization.decode(allocator, frame)).request };
    if (std.mem.startsWith(u8, frame.payload, "DOCPART1")) {
        const record = (try s.DocumentPartitionRecord.decode(allocator, frame, frame.header.partition_id, frame.header.lsn)).record;
        return .{ .document_history = try .init(record.root.initialization, record.root.next_lsn) };
    }
    if (std.mem.startsWith(u8, frame.payload, "TCATLOG1")) {
        const record = try CatalogStore.decodeFrame(allocator, frame, frame.header.partition_id, frame.header.lsn);
        return .{ .catalog_history = try .init(.{ .root = record.root, .chain = r.hash(frame.payload) }) };
    }
    if (std.mem.startsWith(u8, frame.payload, "TXDEC1\x00\x00")) return .{ .transaction_journal = frame.header.partition_id };
    const decoded = try s.TablePartitionRecord.decodeFrame(allocator, frame, frame.header.partition_id, frame.header.lsn);
    return .{ .table_history = try .init(.{ .root = decoded.record.root, .chain = r.hash(frame.payload) }) };
}

fn scope(value: anytype) ![32]u8 {
    var bytes: [128 * 1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(value, .{}, &writer) catch return error.StorageMaintenanceBudget;
    return r.hash(writer.buffered());
}
fn markContent(workspace: anytype, key: []const u8, content: d.Content) !void {
    try workspace.mark(key, .{ .size = content.bytes, .sha256 = content.sha256 });
}
fn markPage(index: *s.TreeStore, workspace: anytype, reference: s.TreeStore.pages.Reference) !void {
    var buffer: [96]u8 = undefined;
    const key = try s.TreeStore.key(reference.location, &buffer);
    const meta = try index.store.head(key) orelse return error.MissingDataIndexObject;
    if (!std.mem.eql(u8, &meta.sha256, &reference.location)) return error.InvalidDataIndexObject;
    try workspace.mark(key, meta);
}
fn requireOwner(context: Context, root: s.TablePartition.Root) !void {
    if (root.partition != context.partition or !std.meta.eql(root.interpretation.object, context.object) or
        root.next_lsn > context.next_lsn or root.next_segment > context.next_segment) return error.InvalidTableStorageGraph;
}

fn timerChunk(allocator: std.mem.Allocator, index: *s.TreeStore, workspace: anytype, context: TimerContext, chunk: s.QueueTimeRun.Descriptor) !void {
    try context.validate();
    if (!std.meta.eql(chunk.seed, context.seed) or chunk.kind != context.kind or chunk.serial >= context.serial) return error.InvalidLogStorageGraph;
    var output: [s.QueueTimeRun.max_rows]s.QueueTimeRun.Event = undefined;
    const events = try s.QueueTimeRun.load(allocator, index.store, chunk, &output);
    for (events) |event| if (event.offset >= context.log.next_offset) return error.InvalidLogStorageGraph;
    var name: [96]u8 = undefined;
    try markContent(workspace, try s.QueueTimeRun.key(chunk.content, &name), chunk.content);
}

fn logEntry(allocator: std.mem.Allocator, index: *s.TreeStore, workspace: anytype, context: LogContext, kind: LogIndexKind, prefix_bytes: u16, entry: s.TreeStore.pages.Entry) !void {
    switch (kind) {
        .pages_only => {},
        .queue_read_releases => {
            const receipt = try s.QueueReadRelease.entry(allocator, index, entry.key, entry.value, .{ .partition = context.partition, .next_lsn = context.next_lsn });
            try context.requireTarget(receipt.release.claim.claim.target);
            const content = try s.LogEvidence.decodeReference(entry.value);
            var name: [96]u8 = undefined;
            try markContent(workspace, try s.LogEvidence.key(content, &name), content);
        },
        .bitmap => {
            const prefix = try s.BitmapDirectory.prefixOf(entry.key);
            const reference = try s.BitmapDirectory.Reference.decode(entry.value);
            var directory: s.BitmapDirectory = .{ .store = index, .objects = index.store };
            var offsets = (try directory.read(prefix, reference)).iterator();
            while (offsets.next()) |low| if (((prefix << 16) | low) >= context.next_offset) return error.InvalidLogStorageGraph;
            var name: [96]u8 = undefined;
            try markContent(workspace, try s.BitmapDirectory.objectKey(reference, &name), .{ .bytes = reference.bytes, .sha256 = reference.digest });
        },
        .ordered_keys => {
            if (try s.OrderedKeyIndex.terminalValue(entry, prefix_bytes)) |value| _ = try s.StreamCompaction.decodeOffset(value, 0, context.next_offset);
            if (try s.OrderedKeyIndex.childIndex(entry, prefix_bytes)) |child| try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = child, .kind = .ordered_keys, .prefix_bytes = prefix_bytes + entry.key.len } });
        },
        .queue_keys => {
            if (try s.OrderedKeyIndex.terminalValue(entry, prefix_bytes)) |value| {
                const head = try s.QueueIndex.Head.decode(value);
                if (head.last >= context.next_offset) return error.InvalidLogStorageGraph;
            }
            if (try s.OrderedKeyIndex.childIndex(entry, prefix_bytes)) |child| try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = child, .kind = .queue_keys, .prefix_bytes = prefix_bytes + entry.key.len } });
        },
        .queue_items => {
            const item = try s.LogPartitionRecord.valueDecode(s.QueueItem, allocator, entry.value);
            try item.validate();
            if (!std.meta.eql(entry.key, try s.LogPartitionRecord.integerKey(item.offset)) or item.batch_next > context.next_offset or
                (item.next_key != null and item.next_key.? >= context.next_offset)) return error.InvalidLogStorageGraph;
            if (item.lease) |lease| try context.requireTarget(lease.target);
            if (item.blocked == .dead_letter) {
                const destination = item.blocked.dead_letter;
                if (!std.meta.eql(destination.object.scope, context.interpretation.object.scope) or
                    destination.object.branch != context.interpretation.object.branch or
                    std.meta.eql(destination.object, context.interpretation.object)) return error.InvalidQueueDestination;
                try workspace.enqueue(.{ .queue_destination = destination });
            }
        },
        .queue_sidecars => {
            const manifest = try s.Tack.decode(entry.value.data[0..entry.value.len]);
            try context.requireTarget(manifest.target);
            if (!std.meta.eql(entry.key, try s.LogPartitionRecord.integerKey(manifest.next)) or manifest.next > context.next_offset or
                manifest.accepted.partition != context.partition or manifest.accepted.next_lsn > context.next_lsn) return error.InvalidLogStorageGraph;
            try workspace.enqueue(.{ .queue_sidecar = .{ .context = context, .manifest = manifest } });
        },
        .batches, .receipts, .producer_receipts => {
            const evidence = try s.LogEvidence.load(allocator, index.store, entry.value);
            try context.requireTarget(evidence.target());
            if (evidence.accepted().partition != context.partition or evidence.accepted().next_lsn > context.next_lsn) return error.InvalidLogStorageGraph;
            switch (kind) {
                .receipts => if (!std.meta.eql(try context.owner(entry.key), evidence.operation())) return error.InvalidLogStorageGraph,
                .batches => {
                    if (evidence.outcome != .append) return error.InvalidLogStorageGraph;
                    const receipt = evidence.outcome.append;
                    if (receipt.next > context.next_offset or !std.meta.eql(entry.key, try s.LogPartitionRecord.integerKey(receipt.next))) return error.InvalidLogStorageGraph;
                    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = index };
                    if (try tree.get(context.segments, entry.key)) |value| {
                        try workspace.enqueue(.{ .log_segment = .{ .context = context, .descriptor = try s.LogSegment.Descriptor.decode(value), .evidence = evidence } });
                    } else try workspace.enqueue(.{ .log_wal = .{ .context = context, .lsn = receipt.accepted.next_lsn - 1, .receipt = receipt } });
                },
                .producer_receipts => {
                    if (evidence.outcome != .append or evidence.outcome.append.append.producer == null or !std.meta.eql(entry.key, try s.LogPartitionRecord.producerKey(evidence.outcome.append.append, true))) return error.InvalidLogStorageGraph;
                },
                else => unreachable,
            }
            const content = try s.LogEvidence.decodeReference(entry.value);
            var name: [96]u8 = undefined;
            try markContent(workspace, try s.LogEvidence.key(content, &name), content);
            try workspace.enqueue(.{ .log_declaration = evidence.declared });
            if (evidence.outcome == .claim and evidence.outcome.claim.receipt.leases != null) try workspace.enqueue(.{ .queue_selection = .{ .context = context, .receipt = evidence.outcome.claim.receipt } });
        },
        .producers => {
            const producer = try s.LogPartitionRecord.valueDecode(c.protocol.StreamQueue.ProducerState, allocator, entry.value);
            try context.requireTarget(producer.target);
            if (entry.key.len != 24 or std.mem.readInt(u64, entry.key.data[0..8], .big) != producer.principal or !std.mem.eql(u8, entry.key.data[8..24], &producer.producer.id)) return error.InvalidLogStorageGraph;
        },
        .groups, .group_offsets => {
            const progress = try s.LogPartitionRecord.valueDecode(c.protocol.StreamQueue.GroupProgress, allocator, entry.value);
            try context.requireTarget(progress.target);
            const key = if (kind == .groups) try s.LogPartitionRecord.integerKey(progress.group.id) else try s.LogPartitionRecord.groupOffsetKey(progress);
            if (progress.next > context.next_offset or !std.meta.eql(entry.key, key)) return error.InvalidLogStorageGraph;
        },
        .transaction_pins => {
            const owner = try context.owner(entry.key);
            const pin = try s.LogTransaction.Pin.decode(entry.value);
            if (!pin.released) try workspace.enqueue(.{ .log_transaction_source = .{ .context = context, .handle = .{ .owner = owner, .content = pin.source } } });
        },
        .pins => {
            const owner = try context.owner(entry.key);
            const pin = try s.LogRead.Pin.decode(entry.value);
            if (!pin.released) try workspace.enqueue(.{ .log_read = .{ .context = context, .handle = .{ .owner = owner, .source = pin.source } } });
        },
    }
}

fn markDocumentBlob(allocator: std.mem.Allocator, context: DocumentContext, store: s.TransitObjectStore.ObjectStore, workspace: anytype, prefix: []const u8, content: d.Content) !void {
    try content.validate();
    var name: [96]u8 = undefined;
    const key = try std.fmt.bufPrint(&name, "{s}/{x}.data", .{ prefix, &content.sha256 });
    const meta = (try store.head(key)) orelse return error.DocumentStateObjectMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidDocumentStorageGraph;
    try markContent(workspace, key, content);
    if (std.mem.eql(u8, prefix, "document-states") and try s.DocumentLogicalState.isLogical(store, content)) {
        const state = try s.DocumentLogicalState.load(allocator, store, content);
        try context.requireTarget(state.target.partition);
        try workspace.enqueue(.{ .document_index = .{ .context = context, .reference = state.index.records, .kind = .logical_records } });
        try workspace.enqueue(.{ .document_index = .{ .context = context, .reference = state.index.ordered, .kind = .logical_ordered } });
    }
}

fn documentEntry(allocator: std.mem.Allocator, index: *s.TreeStore, workspace: anytype, context: DocumentContext, kind: DocumentIndexKind, prefix_bytes: u16, entry: s.TreeStore.pages.Entry) !void {
    switch (kind) {
        .pages_only => {},
        .logical_records => {
            if (entry.key.len != 32) return error.InvalidDocumentStorageGraph;
            const locator = try s.DocumentIndex.Locator.decode(entry.value);
            var name: [96]u8 = undefined;
            const key = try s.DocumentIndex.segmentKey(locator.segment, &name);
            const meta = try index.store.head(key) orelse return error.MissingDocumentSegment;
            if (meta.size != locator.length or !std.mem.eql(u8, &meta.sha256, &locator.segment)) return error.InvalidDocumentStorageGraph;
            try markContent(workspace, key, .{ .bytes = locator.length, .sha256 = locator.segment });
        },
        .logical_ordered => {
            if (try s.OrderedKeyIndex.childIndex(entry, prefix_bytes)) |child| {
                try workspace.enqueue(.{ .document_index = .{ .context = context, .reference = child, .kind = .logical_ordered, .prefix_bytes = prefix_bytes + 64 } });
            }
        },
        .documents => {
            const parsed = try c.protocol.Json.parseFromSlice(s.DocumentPartition.DocumentHead, allocator, entry.value.slice());
            defer parsed.deinit();
            try parsed.value.cut.validate();
            try context.requireTarget(parsed.value.cut.target.partition);
            if (entry.key.len != 16 or !std.mem.eql(u8, entry.key.data[0..16], &parsed.value.cut.target.document)) return error.InvalidDocumentStorageGraph;
            try markDocumentBlob(allocator, context, index.store, workspace, "document-states", parsed.value.cut.state);
        },
        .revisions => {
            const parsed = try c.protocol.Json.parseFromSlice(s.DocumentPartition.RevisionEntry, allocator, entry.value.slice());
            defer parsed.deinit();
            if (entry.key.len != 24 or parsed.value.lsn >= context.next_lsn) return error.InvalidDocumentStorageGraph;
            try markDocumentBlob(allocator, context, index.store, workspace, "document-states", parsed.value.state);
            try markDocumentBlob(allocator, context, index.store, workspace, "document-payloads", parsed.value.payload);
        },
        .replicas => {
            const parsed = try c.protocol.Json.parseFromSlice(c.protocol.DocumentOperation.ReplicaState, allocator, entry.value.slice());
            defer parsed.deinit();
            try parsed.value.validate();
            try context.requireTarget(parsed.value.target.partition);
            if (entry.key.len != 32 or
                !std.mem.eql(u8, entry.key.data[0..16], &parsed.value.target.document) or
                !std.mem.eql(u8, entry.key.data[16..32], &parsed.value.replica.id))
            {
                return error.InvalidDocumentStorageGraph;
            }
        },
        .operations => {
            const parsed = try c.protocol.Json.parseFromSlice(d.Content, allocator, entry.value.slice());
            defer parsed.deinit();
            const outcome = try s.DocumentEvidence.load(allocator, index.store, parsed.value);
            const expected_op: d.Operation = switch (outcome) {
                .mutation => |v| v.mutation.operation,
                .checkpoint => |v| v.checkpoint.operation,
                .read => |v| v.request.operation,
                .read_release => |v| v.release.operation,
            };
            if (!std.meta.eql(try context.owner(entry.key), expected_op)) return error.InvalidDocumentStorageGraph;
            var name: [96]u8 = undefined;
            try markContent(workspace, try s.DocumentEvidence.key(parsed.value, &name), parsed.value);
        },
        .reads => {
            const owner = try context.owner(entry.key);
            const parsed = try c.protocol.Json.parseFromSlice(s.DocumentPartition.PinEntry, allocator, entry.value.slice());
            defer parsed.deinit();
            try parsed.value.source.validate();
            if (!parsed.value.released) {
                try workspace.enqueue(.{ .document_read = .{ .context = context, .handle = .{ .owner = owner, .source = parsed.value.source } } });
            }
        },
    }
}

/// Advance one cursor, directory slot, or bounded object. At most three child
/// jobs are added. Caller publishes work, marks and this active cursor together;
/// any error discards all private cursor/root changes from this step.
pub fn step(allocator: std.mem.Allocator, index: *s.TreeStore, log: s.TransitLog.Log, work: *Work, workspace: anytype) !bool {
    switch (work.*) {
        .declaration, .evidence, .intent, .snapshot, .wal, .segment, .catalog_intent, .log_operation, .log_declaration, .queue_destination, .log_initialization, .log_segment, .log_wal, .document_declaration, .document_initialization, .document_read, .document_wal => if (try workspace.visited(try scope(work.*))) return true,
        else => {},
    }
    var key_buffer: [96]u8 = undefined;
    switch (work.*) {
        .catalog_history => |*walk| {
            const record = try walk.next(allocator, log) orelse return true;
            try workspace.enqueue(.{ .catalog_root = .{ .root = record.root } });
            if (record.action == .operation) try workspace.enqueue(.{ .catalog_intent = .{ .configuration = record.root.configuration, .operation = record.action.operation } });
            if (record.action == .log) try workspace.enqueue(.{ .log_operation = .{ .configuration = record.root.configuration, .operation = record.action.log } });
            if (record.action == .client_token and record.action.client_token.receipt.binding.intent == .branch and !record.action.client_token.pending and !record.action.client_token.cancel)
                try workspace.enqueue(.{ .branch = .{ .root = record.root, .progress = record.action.client_token } });
            if (record.action == .client_token and record.action.client_token.receipt.binding.intent == .transaction_call) {
                const call = record.action.client_token.receipt.binding.intent.transaction_call;
                if (call.work == .statement) try workspace.enqueue(.{ .transaction_intent = call.work.statement.request });
            }
            if (record.action == .client_token and record.action.client_token.receipt.binding.intent == .transaction) {
                // Replay retains historical catalog directories. Private workspace
                // data belongs only to the latest accepted token at this cut.
                const key = try s.TreeStore.pages.Key.init(&try record.action.client_token.receipt.binding.key.digest());
                var tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = index };
                const latest = try tree.get(walk.cut.root.client_tokens, key) orelse return error.InvalidClientToken;
                if (latest.len != 8) return error.InvalidClientToken;
                if (std.mem.readInt(u64, latest.data[0..8], .little) + 1 == record.action.client_token.revision.next_lsn)
                    try workspace.enqueue(.{ .transaction = .{ .root = walk.cut.root, .progress = record.action.client_token } });
            }
            return false;
        },
        .branch => |value| {
            const state = try c.DirectBranch.State.load(allocator, index.store, value.progress);
            const head = state.head orelse return error.InvalidBranchState;
            const intent = value.progress.receipt.binding.intent.branch;
            const manifest = try s.BranchSnapshot.loadManifest(index.store, head.reference);
            if (manifest.kind != .genesis or manifest.mode != intent.mode or !std.meta.eql(manifest.catalog, value.progress.receipt.position) or !std.meta.eql(manifest.retention_owner, intent.identity())) return error.InvalidBranchState;
            var directory = try s.BranchSnapshot.init(allocator, index.store, state.branch, intent.identity(), 1, 0, 1);
            defer directory.deinit();
            try directory.restore(manifest.objects);
            const entry = try directory.get(intent.source.interpretation.object.object) orelse return error.IncompleteBranchDirectory;
            if (directory.root.count != 1 or !std.meta.eql(entry.source, intent.source)) return error.InvalidBranchState;
            try directory.verifyEntry(allocator, entry);
            try markContent(workspace, try s.BranchSnapshot.objectKey(head.reference.content, &key_buffer), head.reference.content);
            try markContent(workspace, try s.BranchSnapshot.objectKey(manifest.objects.content, &key_buffer), manifest.objects.content);
            // Table live-pin traversal retains the data/archive closure. This
            // additional root protects the branch's own paged source directory.
            try workspace.enqueue(.{ .catalog_walk = try .init(value.root, .{ .reference = directory.root.entries.?, .kind = .pages_only }) });
        },
        .transaction => |*value| {
            const progress = value.progress;
            const begin = progress.receipt.binding.intent.transaction.begin;
            if (value.slot == 0) {
                var selected = try s.TransactionDirectory.init(allocator, index.store, begin.identity, .participants, begin.limits.participants, 0, 1);
                defer selected.deinit();
                try selected.restore(begin.objects);
                try markContent(workspace, try s.TransactionDirectory.objectKey(begin.objects.content, &key_buffer), begin.objects.content);
                if (selected.root.entries) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(value.root, .{ .reference = reference, .kind = .pages_only }) });
            } else {
                if (progress.record == null) return true;
                const control = if (progress.record.?.format == c.DirectTransactionControl.format) try c.DirectTransactionControl.load(allocator, index.store, progress) else null;
                if (value.slot == 9) {
                    if (control) |state| {
                        try workspace.enqueue(.{ .transaction_directory = .{ .catalog = value.root, .identity = begin.identity, .directory = state.binding.attempt.participants, .kind = .participants } });
                        if (state.preparations) |directory| try workspace.enqueue(.{ .transaction_directory = .{ .catalog = value.root, .identity = begin.identity, .directory = directory, .kind = .preparations } });
                        // A decision may have reached WAL before catalog progress.
                        if (try log.tail(progress.receipt.coordination.?) != 0) try workspace.enqueue(.{ .transaction_journal = progress.receipt.coordination.? });
                    }
                    return true;
                }
                const head = if (control) |state| state.workspace else try W.recover(allocator, index.store, progress);
                if (head == null) {
                    value.slot += 1;
                    return false;
                }
                const retained = head.?;
                switch (value.slot) {
                    1 => {
                        var sources = try s.TransactionDirectory.init(allocator, index.store, begin.identity, .sources, begin.limits.participants, 0, 1);
                        defer sources.deinit();
                        try sources.restore(retained.acquired.cut.sources);
                        try markContent(workspace, try s.TransactionDirectory.objectKey(retained.acquired.cut.sources.content, &key_buffer), retained.acquired.cut.sources.content);
                        if (sources.root.entries) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(value.root, .{ .reference = reference, .kind = .pages_only }) });
                    },
                    2, 3 => if (if (value.slot == 2 and (control == null or !control.?.cleanup_complete)) retained.tables else if (value.slot == 3) retained.statements else null) |reference| {
                        try workspace.enqueue(.{ .transaction_walk = .{ .walk = try .init(value.root, .{ .reference = reference, .kind = .values }), .head = retained, .scope = progress.receipt.binding.key.scope(), .tables = value.slot == 2 } });
                    },
                    4 => if (retained.pending) |request| {
                        switch (request) {
                            .state => |state| try workspace.enqueue(.{ .transaction_intent = state }),
                            .log => |pending_log| try workspace.enqueue(.{ .transaction_log_intent = pending_log }),
                        }
                    },
                    5 => if (retained.controls) |reference| {
                        try workspace.enqueue(.{ .transaction_controls = .{ .walk = try .init(value.root, .{ .reference = reference, .kind = .values }), .head = retained, .scope = progress.receipt.binding.key.scope() } });
                    },
                    6 => if (control == null or !control.?.cleanup_complete) {
                        if (retained.savepoints) |reference| try workspace.enqueue(.{ .transaction_savepoints = .{ .root = value.root, .head = retained, .scope = progress.receipt.binding.key.scope(), .next = reference, .depth = retained.savepoint_count } });
                    },
                    7 => if (control == null or !control.?.cleanup_complete) {
                        if (retained.pending_control) |pending| if (pending.tables) |reference| {
                            try workspace.enqueue(.{ .transaction_walk = .{ .walk = try .init(value.root, .{ .reference = reference, .kind = .values }), .head = retained, .scope = progress.receipt.binding.key.scope(), .tables = true } });
                        };
                    },
                    8 => if (control == null or !control.?.cleanup_complete) {
                        if (retained.logs) |directory| try workspace.enqueue(.{ .transaction_directory = .{ .catalog = value.root, .identity = begin.identity, .directory = directory, .kind = .participants } });
                    },
                    else => return error.InvalidTableStorageGraph,
                }
            }
            value.slot += 1;
            return false;
        },
        .transaction_walk => |*value| {
            const edge = try value.walk.next(allocator, index) orelse return true;
            switch (edge) {
                .page => |page| try markPage(index, workspace, page.reference),
                .declaration => return error.InvalidTableStorageGraph,
                .value => |entry| {
                    const format = if (value.tables) W.table_format else W.statement_format;
                    const reference = try W.referenceOf(entry.value, value.scope, format);
                    if (value.tables) {
                        const state = try W.load(s.TableWorkspace.State, allocator, index.store, reference, value.scope, format);
                        try state.validate();
                        if (!std.meta.eql(state.begin, value.head.acquired.cut.begin) or state.last_statement > value.head.last_statement or
                            !std.meta.eql(entry.key, try W.idKey(state.root.interpretation.object.object))) return error.InvalidTableStorageGraph;
                        // Private positions are not public WAL positions. Use the
                        // real latest accepted owner's archive for old WAL locators.
                        const tail = try log.tail(state.root.partition);
                        if (tail == 0) return error.InvalidTableStorageGraph;
                        var batch = try log.read(allocator, state.root.partition, tail - 1, 1);
                        defer batch.deinit();
                        if (batch.frames.len != 1) return error.TableHistoryMissing;
                        const accepted = (try s.TablePartitionRecord.decodeFrame(allocator, batch.frames[0], state.root.partition, tail - 1)).record.root;
                        if (!std.meta.eql(accepted.interpretation.object, state.root.interpretation.object)) return error.InvalidTableStorageGraph;
                        try workspace.enqueue(.{ .table_root = .{ .root = state.root, .archive = accepted.archive, .role = .workspace } });
                    } else {
                        const stored = try W.load(W.StatementCompletion, allocator, index.store, reference, value.scope, format);
                        try stored.validate();
                        const request = stored.request();
                        if (!std.meta.eql(request.statement().transaction, value.head.acquired.cut.begin.identity) or
                            request.statement().sequence > value.head.last_statement or !std.meta.eql(entry.key, try W.idKey(request.statement().sequence))) return error.InvalidTableStorageGraph;
                        switch (request) {
                            .state => |pending_state| try workspace.enqueue(.{ .transaction_intent = pending_state }),
                            .log => |pending_log| try workspace.enqueue(.{ .transaction_log_intent = pending_log }),
                        }
                    }
                },
            }
            return false;
        },
        .transaction_savepoints => |*value| {
            const reference = value.next orelse return true;
            const saved = try c.DirectTransactionSavepoint.load(allocator, index.store, value.scope, reference, value.head);
            if (saved.depth != value.depth) return error.InvalidTableStorageGraph;
            if (saved.tables) |tables| try workspace.enqueue(.{ .transaction_walk = .{ .walk = try .init(value.root, .{ .reference = tables, .kind = .values }), .head = value.head, .scope = value.scope, .tables = true } });
            if (saved.logs) |directory| try workspace.enqueue(.{ .transaction_directory = .{ .catalog = value.root, .identity = saved.transaction, .directory = directory, .kind = .participants } });
            value.next = saved.previous;
            value.depth -= 1;
            return value.next == null;
        },
        .transaction_controls => |*value| {
            const edge = try value.walk.next(allocator, index) orelse return true;
            switch (edge) {
                .page => |page| try markPage(index, workspace, page.reference),
                .declaration => return error.InvalidTableStorageGraph,
                .value => |entry| {
                    const format = c.DirectTransactionSavepoint.result_format;
                    const result = try W.load(c.DirectTransactionSavepoint.Result, allocator, index.store, try W.referenceOf(entry.value, value.scope, format), value.scope, format);
                    try result.validate();
                    if (!std.meta.eql(result.request.transaction, value.head.acquired.cut.begin.identity) or result.request.sequence > value.head.last_control or
                        !std.meta.eql(entry.key, try W.idKey(result.request.sequence)) or result.completed == null) return error.InvalidTableStorageGraph;
                },
            }
            return false;
        },
        .transaction_intent => |request| {
            try request.validate();
            var intent = try s.TableDmlIntent.load(allocator, index.store, request.intent);
            defer intent.deinit();
            try request.binding.requireSame(intent.request.binding);
            try markContent(workspace, try s.TableDmlIntent.key(request.intent, &key_buffer), request.intent);
            try workspace.enqueue(.{ .declaration = intent.request.interpretation });
        },
        .transaction_log_intent => |request| {
            try request.validate();
            if (try c.DirectTransactionLogWork.loadPayload(allocator, index.store, request.work)) |bytes| {
                defer allocator.free(bytes);
                const content = request.work.appendPayload().?.payload;
                try markContent(workspace, try s.LogTransactionActions.payloadKey(content, &key_buffer), content);
            }
        },
        .private_index => |*value| {
            const page = try index.load(value.reference);
            if (value.height) |height| if (page.height != height) return error.InvalidTableStorageGraph;
            if (value.slot > page.count) return error.InvalidTableStorageGraph;
            if (!value.marked) {
                if (value.slot != 0) return error.InvalidTableStorageGraph;
                try markPage(index, workspace, value.reference);
                if (try workspace.visited(try scope(.{ .private_index = value.reference }))) return true;
                value.marked = true;
                return false;
            }
            if (value.slot == page.count) return true;
            if (page.body == .branch) try workspace.enqueue(.{ .private_index = .{ .reference = page.body.branch[value.slot].?.reference, .height = page.height - 1 } });
            value.slot += 1;
            return false;
        },
        .transaction_journal => |partition| {
            const binding = try s.TransactionDecisionLog.frozenBinding(allocator, log, partition);
            var journal = try s.TransactionDecisionLog.init(allocator, log, index.store, partition, binding);
            try journal.recover();
            var batch = try log.read(allocator, binding.begin.catalog.partition, binding.begin.catalog.next_lsn - 1, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.CatalogHistoryMissing;
            const catalog = (try CatalogStore.decodeFrame(allocator, batch.frames[0], binding.begin.catalog.partition, binding.begin.catalog.next_lsn - 1)).root;
            try workspace.enqueue(.{ .transaction_directory = .{ .catalog = catalog, .identity = binding.begin.identity, .directory = binding.attempt.participants, .kind = .participants } });
            if (journal.decision) |decision| try workspace.enqueue(.{ .transaction_directory = .{ .catalog = catalog, .identity = binding.begin.identity, .directory = decision.prepared, .kind = .preparations } });
        },
        .transaction_directory => |*value| {
            var directory = try s.TransactionDirectory.init(allocator, index.store, value.identity, value.kind, @max(1, value.directory.count), 0, 1);
            defer directory.deinit();
            try directory.restore(value.directory);
            if (!value.started) {
                try markContent(workspace, try s.TransactionDirectory.objectKey(value.directory.content, &key_buffer), value.directory.content);
                if (directory.root.entries) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(value.catalog, .{ .reference = reference, .kind = .pages_only }) });
                value.started = true;
                return false;
            }
            const page = try directory.page(value.after);
            const entry = page.entries[0] orelse return true;
            switch (entry) {
                .prepared => |prepared| switch (prepared.predecessor) {
                    .state => {
                        _ = try prepared.predecessor.requirePagedState();
                        try workspace.enqueue(.{ .table_preparation = .{ .reference = .{ .content = prepared.successor } } });
                    },
                    .log => try workspace.enqueue(.{ .log_preparation = .{ .reference = .{ .content = prepared.successor } } }),
                },
                .participant => |participant| if (participant == .log) {
                    if (participant.log.actions) |actions| try workspace.enqueue(.{ .log_actions = .{ .identity = value.identity, .guard = participant.log.guard, .directory = actions } });
                },
                .source => {},
            }
            value.after = entry.cursor();
            return false;
        },
        .table_preparation => |value| {
            const preparation = try s.TableTransaction.load(allocator, index.store, value.reference);
            try markContent(workspace, try s.TableTransaction.key(value.reference, &key_buffer), value.reference.content);
            if (value.archive) |archive| try workspace.enqueue(.{ .table_root = .{ .root = preparation.workspace.root, .archive = archive, .role = .workspace } });
        },
        .catalog_root => |*value| {
            const root = value.root;
            const directories = [_]?s.TreeStore.pages.Reference{ root.schemas, root.schema_names, root.namespace_claims, root.namespace_pending, root.objects, root.names, root.operations, root.pending, root.native_allocations, root.dependents, root.dependencies, root.client_tokens, root.client_operations, root.client_pending, root.client_accounts, root.branches, root.branch_names, root.branch_owners };
            if (value.slot > directories.len) return error.InvalidDirectCatalogHistory;
            if (value.slot == directories.len) return true;
            const slot = value.slot;
            value.slot += 1;
            if (directories[slot]) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(root, .{ .reference = reference, .kind = if (slot == 4) .objects else .pages_only }) });
            return false;
        },
        .catalog_walk => |*walk| {
            const edge = try walk.next(allocator, index) orelse return true;
            switch (edge) {
                .value => return error.InvalidTableStorageGraph,
                .page => |root| {
                    try markPage(index, workspace, root.reference);
                    if (try workspace.visited(try scope(.{ .catalog = walk.configuration, .next_lsn = walk.next_lsn, .next_partition = walk.next_partition, .root = root }))) try walk.skip();
                },
                .declaration => |stored| try workspace.enqueue(.{ .declaration = stored }),
            }
            return false;
        },
        .catalog_intent => |value| {
            var intent = try Intent.load(allocator, index.store, value.configuration, value.operation.intent);
            defer intent.deinit();
            try value.operation.binding.requireSame(intent.value.binding);
            try markContent(workspace, try Intent.key(value.operation.intent, &key_buffer), value.operation.intent);
        },
        .log_operation => |value| {
            const LogIntent = c.DirectLog.IntentStore;
            var intent = try LogIntent.load(allocator, index.store, value.configuration, value.operation.intent);
            defer intent.deinit();
            try value.operation.binding.requireSame(intent.value.binding);
            try markContent(workspace, try LogIntent.key(value.operation.intent, &key_buffer), value.operation.intent);
            if (value.operation.resulting) |definition| {
                try workspace.enqueue(.{ .log_declaration = definition.stored });
                try workspace.enqueue(.{ .log_declaration = definition.seed });
                // Later declarations preserve the original fully initialized
                // range; a private creation retains only its verified prefix.
                try workspace.enqueue(.{ .log_partitions = .{ .definition = definition, .initialized = if (value.operation.binding.action == .create) value.operation.initialized else definition.count() } });
            }
        },
        .log_declaration => |stored| {
            var declaration = try s.LogDeclaration.load(allocator, index.store, stored);
            defer declaration.deinit();
            try markContent(workspace, try s.LogDeclaration.key(stored.content, &key_buffer), stored.content);
            if (stored.declaration.configuration.policy == .queue) {
                if (stored.declaration.configuration.policy.queue.dead_letter) |destination| try workspace.enqueue(.{ .queue_destination = destination });
            }
        },
        .queue_destination => |interpretation| {
            var declaration = try s.LogDeclaration.resolve(allocator, index.store, interpretation);
            defer declaration.deinit();
            if (declaration.definition.configuration.policy != .queue or declaration.definition.retired) return error.InvalidQueueDestination;
            try workspace.enqueue(.{ .log_declaration = try declaration.stored() });
        },
        .log_partitions => |*value| {
            try value.definition.validate();
            if (value.next > value.initialized or value.initialized > value.definition.count()) return error.InvalidLogCatalogOperation;
            if (value.next == value.initialized) return true;
            try workspace.enqueue(.{ .log_initialization = try value.definition.genesis(value.next) });
            value.next += 1;
            return false;
        },
        .log_initialization => |request| {
            try request.validate();
            _ = try s.LogInitialization.readStored(allocator, log, index.store, request);
            try workspace.enqueue(.{ .log_declaration = request.declared });
            const end = try log.tail(request.partition);
            if (end > 1) {
                var latest = try log.read(allocator, request.partition, end - 1, 1);
                defer latest.deinit();
                if (latest.frames.len != 1) return error.LogHistoryUnavailable;
                const decoded = (try s.LogPartitionRecord.decode(allocator, latest.frames[0], request.partition, end - 1)).record;
                try request.requireSame(decoded.root.initialization);
                try workspace.enqueue(.{ .log_history = try .init(.{ .root = decoded.root, .commitment = s.LogEvidence.hash(latest.frames[0].payload) }) });
            }
        },
        .log_history => |*walk| {
            const context = try LogContext.fromRoot(walk.cut.root, walk.cut.root.archive);
            switch (try walk.next(allocator, index, log)) {
                .complete => return true,
                .current => |root| try workspace.enqueue(.{ .log_root = .{ .root = root, .archive = context.archive } }),
                .checkpoint => |checkpoint| {
                    try markContent(workspace, try s.LogRecovery.key(checkpoint.reference.content, &key_buffer), checkpoint.reference.content);
                    try workspace.enqueue(.{ .log_root = .{ .root = checkpoint.basis.root, .archive = context.archive } });
                },
                .initialization => |initialized| try workspace.enqueue(.{ .log_declaration = initialized.request.declared }),
                .frame => |record| {
                    try workspace.enqueue(.{ .log_root = .{ .root = record.root, .archive = context.archive } });
                    try workspace.enqueue(.{ .log_wal = .{ .context = context, .lsn = record.root.next_lsn - 1 } });
                    if (record.action == .archive) try workspace.enqueue(.{ .log_archive_range = .{ .context = context, .from = record.action.archive.from_lsn, .until = record.root.archive.through } });
                },
            }
            return false;
        },
        .log_root => |*value| {
            const root = value.root;
            const queue = root.queue orelse s.QueueIndex.Root.empty;
            const directories = [_]?s.TreeStore.pages.Reference{ root.batches, root.receipts, root.producers, root.producer_receipts, root.groups, root.group_offsets, root.pins, root.transaction_pins, root.archive.directory, root.segments, root.hidden.containers, queue.items, queue.sidecars, queue.keys, queue.read_releases };
            const kinds = [_]LogIndexKind{ .batches, .receipts, .producers, .producer_receipts, .groups, .group_offsets, .pins, .transaction_pins, .pages_only, .pages_only, .bitmap, .queue_items, .queue_sidecars, .queue_keys, .queue_read_releases };
            if (value.slot > directories.len + 4) return error.InvalidLogStorageGraph;
            if (value.slot == directories.len + 4) return true;
            const context = try LogContext.fromRoot(root, value.archive);
            if (value.slot == 0) {
                try workspace.enqueue(.{ .log_declaration = root.declared });
                try workspace.enqueue(.{ .log_declaration = root.initialization.declared });
                if (root.compaction) |state| try workspace.enqueue(.{ .log_compaction = .{ .context = context, .state = state } });
            } else if (value.slot <= directories.len) {
                if (directories[value.slot - 1]) |reference| try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = reference, .kind = kinds[value.slot - 1] } });
            } else if (value.slot == directories.len + 3) {
                if (root.transaction) |reference| try workspace.enqueue(.{ .log_preparation = .{ .reference = reference, .archive = value.archive } });
            } else if (root.queue != null) {
                const visible = value.slot == directories.len + 1;
                const scheduled = if (visible) queue.eligible else queue.deadlines;
                try workspace.enqueue(.{ .queue_schedule = .{ .context = .{ .log = context, .seed = root.initialization.target(), .kind = if (visible) .visible else .lease, .serial = scheduled.serial }, .root = scheduled } });
            }
            value.slot += 1;
            return false;
        },
        .queue_schedule => |*value| {
            try value.context.validate();
            try value.root.validate();
            if (value.context.serial != value.root.serial or value.slot > 8) return error.InvalidLogStorageGraph;
            if (value.slot == 8) return true;
            if (!value.started) {
                if (value.slot != 0) return error.InvalidLogStorageGraph;
                if (try workspace.visited(try scope(.{ .queue_schedule = .{ .context = value.context, .root = value.root } }))) return true;
                value.started = true;
                return false;
            }
            switch (value.slot) {
                0 => if (value.root.active) |content| {
                    var bytes: [s.QueueTimeBuffer.max_bytes]u8 = undefined;
                    var events: [s.QueueTimeBuffer.max_rows]s.QueueTimeRun.Event = undefined;
                    const buffer = try s.QueueTimeBuffer.load(value.context.seed, value.context.kind, index.store, content, &bytes, &events);
                    if (buffer.len != value.root.active_rows) return error.InvalidLogStorageGraph;
                    for (buffer.rows()) |event| if (event.offset >= value.context.log.next_offset) return error.InvalidLogStorageGraph;
                    var name: [96]u8 = undefined;
                    try markContent(workspace, try s.QueueTimeBuffer.key(content, &name), content);
                },
                1, 2 => {
                    const reference = if (value.slot == 1) value.root.pending else value.root.levels;
                    if (reference) |root| try workspace.enqueue(.{ .queue_timer_index = .{ .context = value.context, .reference = root, .kind = if (value.slot == 1) .pending else .levels } });
                },
                3, 4 => if (value.root.work) |merge_work| {
                    if (!std.meta.eql(merge_work.merge.seed, value.context.seed) or merge_work.merge.kind != value.context.kind or merge_work.merge.basis.next_offset > value.context.log.next_offset) return error.InvalidLogStorageGraph;
                    const reference = if (value.slot == 3) merge_work.merge.basis.items else merge_work.merge.basis.sidecars;
                    if (reference) |root| {
                        var context = value.context.log;
                        context.next_offset = merge_work.merge.basis.next_offset;
                        try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = root, .kind = if (value.slot == 3) .queue_items else .queue_sidecars } });
                    }
                },
                5, 6, 7 => if (value.root.work) |merge_work| {
                    const run = switch (value.slot) {
                        5 => merge_work.merge.sources[0],
                        6 => merge_work.merge.sources[1],
                        else => merge_work.merge.output,
                    };
                    try workspace.enqueue(.{ .queue_timer_run = .{ .context = value.context, .audit = .{ .basis = run } } });
                },
                else => unreachable,
            }
            value.slot += 1;
            return false;
        },
        .queue_timer_index => |*value| {
            try value.context.validate();
            const page = try index.load(value.reference);
            if (value.height) |height| if (page.height != height) return error.InvalidLogStorageGraph;
            if (value.slot > page.count) return error.InvalidLogStorageGraph;
            if (!value.marked) {
                if (value.slot != 0) return error.InvalidLogStorageGraph;
                try markPage(index, workspace, value.reference);
                if (try workspace.visited(try scope(.{ .queue_timer_index = .{ .context = value.context, .reference = value.reference, .kind = value.kind } }))) return true;
                value.marked = true;
                return false;
            }
            if (value.slot == page.count) return true;
            switch (page.body) {
                .branch => |children| try workspace.enqueue(.{ .queue_timer_index = .{ .context = value.context, .reference = children[value.slot].?.reference, .kind = value.kind, .height = page.height - 1 } }),
                .leaf => |entries| {
                    const entry = entries[value.slot].?;
                    switch (value.kind) {
                        .pending => {
                            const chunk = try s.QueueTimeRun.Descriptor.decode(entry.value);
                            if (!std.meta.eql(entry.key, try s.QueueSchedule.pendingKey(chunk))) return error.InvalidLogStorageGraph;
                            try timerChunk(allocator, index, workspace, value.context, chunk);
                        },
                        .levels => {
                            const slot = try s.QueueSchedule.Slot.decode(entry.key);
                            const run = try s.LogPartitionRecord.valueDecode(s.QueueTimeDirectory.Root, allocator, entry.value);
                            if (run.rows == 0 or run.first.?.bucket() != slot.bucket or run.last.?.bucket() != slot.bucket) return error.InvalidLogStorageGraph;
                            try workspace.enqueue(.{ .queue_timer_run = .{ .context = value.context, .audit = .{ .basis = run } } });
                        },
                    }
                },
            }
            value.slot += 1;
            return false;
        },
        .queue_timer_run => |*value| {
            try value.context.validate();
            try value.audit.basis.validate();
            if (!value.started) {
                if (value.audit.rows != 0 or value.audit.chunks != 0 or value.audit.after != null or value.audit.complete) return error.InvalidLogStorageGraph;
                if (try workspace.visited(try scope(.{ .queue_timer_run = .{ .context = value.context, .root = value.audit.basis } }))) return true;
                if (value.audit.basis.directory) |reference| try workspace.enqueue(.{ .log_index = .{ .context = value.context.log, .reference = reference, .kind = .pages_only } });
                value.started = true;
                return false;
            }
            const directory: s.QueueTimeDirectory = .{ .store = index, .seed = value.context.seed, .kind = value.context.kind, .bucket = if (value.audit.basis.first) |event| event.bucket() else 0 };
            var audit = value.audit;
            if (try directory.audit(&audit)) |entry| try timerChunk(allocator, index, workspace, value.context, entry.chunk);
            value.audit = audit;
            return audit.complete;
        },
        .queue_selection => |*value| {
            try value.receipt.validate();
            const content = value.receipt.leases orelse return error.InvalidLogStorageGraph;
            if (value.slot > 3 or content.bytes > s.QueueSelection.max_bytes) return error.InvalidLogStorageGraph;
            if (value.slot == 3) return true;
            const buffer = try allocator.alloc(u8, @intCast(content.bytes));
            defer allocator.free(buffer);
            const selection = try s.QueueSelection.load(allocator, index.store, content, buffer);
            try selection.requireReceipt(value.receipt);
            const source = selection.metadata.source;
            try value.context.requireTarget(value.receipt.claim.target);
            if (value.receipt.accepted.partition != value.context.partition or value.receipt.accepted.next_lsn > value.context.next_lsn or source.next_offset > value.context.next_offset) return error.InvalidLogStorageGraph;
            if (value.slot == 0) {
                var name: [96]u8 = undefined;
                try markContent(workspace, try s.QueueSelection.objectKey(content, &name), content);
                try workspace.enqueue(.{ .log_declaration = selection.metadata.declared });
                // Only closure accepted in this exact retained cut can remove
                // the selection's payload dependency. Old replay roots retain
                // their own closure directory and therefore their old payloads.
                if (try s.QueueReadRelease.find(allocator, index, value.context.queue_read_releases, value.receipt, .{ .partition = value.context.partition, .next_lsn = value.context.next_lsn }) != null) return true;
            } else {
                const roots = [_]?s.TreeStore.pages.Reference{ source.batches, source.segments };
                if (roots[value.slot - 1]) |reference| {
                    var context = value.context;
                    context.interpretation = value.receipt.claim.target.interpretation;
                    context.next_lsn = source.accepted.next_lsn;
                    context.next_offset = source.next_offset;
                    context.segments = source.segments;
                    context.hidden = .empty;
                    context.queue_read_releases = null;
                    try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = reference, .kind = if (value.slot == 1) .batches else .pages_only } });
                }
            }
            value.slot += 1;
            return false;
        },
        .queue_sidecar => |*value| {
            try value.manifest.validate();
            if (value.slot > value.manifest.states.len) return error.InvalidLogStorageGraph;
            if (value.slot == value.manifest.states.len) return true;
            if (value.manifest.states[value.slot].containers) |reference| try workspace.enqueue(.{ .log_index = .{ .context = value.context, .reference = reference, .kind = .bitmap } });
            value.slot += 1;
            return false;
        },
        .log_index => |*value| {
            const page = try index.load(value.reference);
            if (value.height) |height| if (page.height != height) return error.InvalidLogStorageGraph;
            if (value.slot > page.count) return error.InvalidLogStorageGraph;
            if (!value.marked) {
                if (value.slot != 0) return error.InvalidLogStorageGraph;
                try markPage(index, workspace, value.reference);
                if (try workspace.visited(try scope(.{ .log_index = .{ .context = value.context, .reference = value.reference, .kind = value.kind, .prefix_bytes = value.prefix_bytes } }))) return true;
                value.marked = true;
                return false;
            }
            if (value.slot == page.count) return true;
            switch (page.body) {
                .branch => |children| try workspace.enqueue(.{ .log_index = .{ .context = value.context, .reference = children[value.slot].?.reference, .kind = value.kind, .prefix_bytes = value.prefix_bytes, .height = page.height - 1 } }),
                .leaf => |entries| try logEntry(allocator, index, workspace, value.context, value.kind, value.prefix_bytes, entries[value.slot].?),
            }
            value.slot += 1;
            return false;
        },
        .log_compaction => |*value| {
            const state = value.state;
            try state.validate();
            try value.context.requireTarget(state.source.cut.target);
            if (state.source.cut.accepted.partition != value.context.partition or state.source.cut.accepted.next_lsn >= value.context.next_lsn or state.source.cut.next > value.context.next_offset) return error.InvalidLogStorageGraph;
            const roots = [_]?s.TreeStore.pages.Reference{ state.source.batches, state.source.segments, state.source.hidden.containers, state.latest, state.candidate.containers };
            const kinds = [_]LogIndexKind{ .batches, .pages_only, .bitmap, .ordered_keys, .bitmap };
            if (value.slot > roots.len + 1) return error.InvalidLogStorageGraph;
            if (value.slot == roots.len + 1) return true;
            if (value.slot == 0) {
                try workspace.enqueue(.{ .log_declaration = state.source.declared });
            } else if (roots[value.slot - 1]) |reference| {
                var context = value.context;
                context.interpretation = state.source.cut.target.interpretation;
                context.next_lsn = state.source.cut.accepted.next_lsn;
                context.next_offset = state.source.cut.next;
                context.segments = state.source.segments;
                context.hidden = state.source.hidden;
                try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = reference, .kind = kinds[value.slot - 1] } });
            }
            value.slot += 1;
            return false;
        },
        .log_preparation => |*value| {
            const preparation = try s.LogTransaction.loadPreparation(index.store, value.reference);
            const context = try LogContext.fromRoot(preparation.successor, value.archive orelse preparation.predecessor.archive);
            switch (value.slot) {
                0 => try markContent(workspace, try s.LogTransaction.preparationKey(value.reference, &key_buffer), value.reference.content),
                1, 2 => if (value.archive) |archive| {
                    const root = if (value.slot == 1) preparation.predecessor else preparation.successor;
                    try workspace.enqueue(.{ .log_root = .{ .root = root, .archive = archive } });
                },
                3 => try workspace.enqueue(.{ .log_actions = .{ .identity = preparation.binding.begin.identity, .guard = preparation.guard, .directory = preparation.actions } }),
                4, 5 => {
                    var journal = try s.TransactionDecisionLog.init(allocator, log, index.store, preparation.coordination, preparation.binding);
                    try journal.recover();
                    if (journal.next_lsn == 0) return error.TransactionNotFrozen;
                    const directory = if (value.slot == 4) preparation.binding.attempt.participants else if (journal.decision) |decision| decision.prepared else {
                        value.slot += 1;
                        return false;
                    };
                    var selected = try s.TransactionDirectory.init(allocator, index.store, preparation.binding.begin.identity, if (value.slot == 4) .participants else .preparations, @max(1, directory.count), 0, 1);
                    defer selected.deinit();
                    try selected.restore(directory);
                    try markContent(workspace, try s.TransactionDirectory.objectKey(directory.content, &key_buffer), directory.content);
                    if (selected.root.entries) |reference| try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = reference, .kind = .pages_only } });
                },
                6 => return true,
                else => return error.InvalidLogStorageGraph,
            }
            value.slot += 1;
            return false;
        },
        .log_actions => |*value| {
            var actions = try s.LogTransactionActions.init(allocator, index.store, value.identity, value.guard, @max(1, value.directory.count), std.math.maxInt(u64), 0, 1);
            defer actions.deinit();
            try actions.restore(value.directory);
            if (!value.started) {
                try markContent(workspace, try s.LogTransactionActions.objectKey(value.directory.content, &key_buffer), value.directory.content);
                for ([_]?s.TreeStore.pages.Reference{ actions.root.entries, actions.root.operations }) |root| if (root) |reference| {
                    try workspace.enqueue(.{ .private_index = .{ .reference = reference } });
                };
                value.started = true;
                return false;
            }
            const page = try actions.page(value.after);
            const entry = page.entries[0] orelse {
                if (value.count != actions.root.count or value.payload_bytes != actions.root.payload_bytes) return error.InvalidTransactionActions;
                return true;
            };
            value.count = try std.math.add(u64, value.count, 1);
            if (value.count > actions.root.count) return error.InvalidTransactionActions;
            const at = s.LogTransactionActions.cursor(entry.work);
            const content = try actions.entryContent(at);
            try markContent(workspace, try s.LogTransactionActions.objectKey(content, &key_buffer), content);
            if (s.LogTransactionActions.append(entry.work)) |appended| {
                const payload = appended.payload;
                const bytes = try allocator.alloc(u8, @intCast(payload.bytes));
                defer allocator.free(bytes);
                _ = try actions.readPayload(entry.work, bytes);
                try markContent(workspace, try s.LogTransactionActions.payloadKey(payload, &key_buffer), payload);
                value.payload_bytes = try std.math.add(u64, value.payload_bytes, payload.bytes);
            }
            value.after = at;
            return false;
        },
        .log_transaction_source => |value| {
            const source = try s.LogTransaction.loadSource(index.store, value.handle);
            try value.context.requireTarget((try source.guard()).source.target);
            if (source.root.initialization.partition != value.context.partition or source.root.next_lsn >= value.context.next_lsn or source.root.next_offset > value.context.next_offset) return error.InvalidLogStorageGraph;
            try markContent(workspace, try s.LogTransaction.sourceKey(value.handle.content, &key_buffer), value.handle.content);
            try workspace.enqueue(.{ .log_root = .{ .root = source.root, .archive = value.context.archive } });
        },
        .log_read => |*value| {
            const basis = try s.LogRead.load(allocator, index.store, value.handle);
            try value.context.requireTarget(basis.cut.target);
            if (basis.cut.accepted.partition != value.context.partition or basis.cut.accepted.next_lsn >= value.context.next_lsn or basis.cut.next > value.context.next_offset) return error.InvalidLogStorageGraph;
            const directories = [_]?s.TreeStore.pages.Reference{ basis.batches, basis.segments, basis.hidden.containers };
            const kinds = [_]LogIndexKind{ .batches, .pages_only, .bitmap };
            if (value.slot > directories.len + 1) return error.InvalidLogStorageGraph;
            if (value.slot == directories.len + 1) return true;
            if (value.slot == 0) {
                if (try workspace.visited(try scope(work.*))) return true;
                try markContent(workspace, try s.LogRead.key(value.handle.source, &key_buffer), value.handle.source);
                try workspace.enqueue(.{ .log_declaration = basis.declared });
                value.slot += 1;
                return false;
            }
            var context = value.context;
            context.interpretation = basis.cut.target.interpretation;
            context.next_lsn = basis.cut.accepted.next_lsn;
            context.next_offset = basis.cut.next;
            context.segments = basis.segments;
            context.hidden = basis.hidden;
            // Looking up a descriptor through this directory does not mark its
            // pages. Pins must retain both locator pages and pointed-to objects.
            if (directories[value.slot - 1]) |reference| {
                try workspace.enqueue(.{ .log_index = .{ .context = context, .reference = reference, .kind = kinds[value.slot - 1] } });
            }
            value.slot += 1;
            return false;
        },
        .log_archive_range => |*value| {
            if (value.from > value.until or value.until >= value.context.next_lsn) return error.InvalidLogStorageGraph;
            if (value.from == value.until) return true;
            try workspace.enqueue(.{ .log_wal = .{ .context = value.context, .lsn = value.from } });
            value.from += 1;
            return false;
        },
        .log_segment => |value| {
            const evidence = value.evidence;
            try evidence.validate();
            try value.context.requireTarget(evidence.target());
            if (evidence.outcome != .append or evidence.accepted().partition != value.context.partition or evidence.accepted().next_lsn > value.context.next_lsn or evidence.outcome.append.next > value.context.next_offset or evidence.outcome.append.append.payload.bytes > s.LogPartitionRecord.max_batch_bytes) return error.InvalidLogStorageGraph;
            var declaration = try s.LogDeclaration.load(allocator, index.store, evidence.declared);
            defer declaration.deinit();
            const output = try allocator.alloc(u8, @intCast(evidence.outcome.append.append.payload.bytes));
            defer allocator.free(output);
            const payload = try s.LogSegment.materialize(allocator, index.store, value.descriptor, &declaration, evidence, output);
            try s.LogSegment.requireVisibility(value.descriptor, payload, declaration.definition.schema, evidence.outcome.append, index, value.context.hidden);
            if (value.descriptor.segment) |segment| try markContent(workspace, try s.LogSegment.segmentKey(segment, &key_buffer), segment);
            try markContent(workspace, try s.LogSegment.metadataKey(value.descriptor.metadata, &key_buffer), value.descriptor.metadata);
        },
        .log_wal => |value| {
            if (value.lsn >= value.context.next_lsn) return error.InvalidLogStorageGraph;
            var batch = if (value.lsn < value.context.archive.through)
                try s.LogHistory.read(allocator, index, value.context.archive, value.context.partition, value.lsn)
            else
                try log.read(allocator, value.context.partition, value.lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.LogHistoryUnavailable;
            if (value.lsn == 0) {
                const initialized = try s.LogInitialization.decode(allocator, batch.frames[0]);
                try value.context.requireTarget(initialized.request.target());
                if (value.receipt != null) return error.InvalidLogStorageGraph;
            } else {
                const record = (try s.LogPartitionRecord.decode(allocator, batch.frames[0], value.context.partition, value.lsn)).record;
                if (record.root.next_offset > value.context.next_offset) return error.InvalidLogStorageGraph;
                try value.context.requireTarget((try record.root.cut(record.root.declared)).target);
                if (value.receipt) |receipt| if (record.action != .operation or record.action.operation.outcome != .append or !std.meta.eql(record.action.operation.outcome.append, receipt)) return error.InvalidLogStorageGraph;
            }
            if (value.lsn < value.context.archive.through) {
                const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = index };
                const reference = try tree.get(value.context.archive.directory, try s.TableArchive.key(value.lsn)) orelse return error.LogHistoryUnavailable;
                const content = try s.TableArchive.decodeReference(reference);
                try markContent(workspace, try s.TableArchive.objectKey(content.sha256, &key_buffer), content);
            }
        },
        .document_declaration => |stored| {
            var declaration = try s.DocumentDeclaration.load(allocator, index.store, stored);
            defer declaration.deinit();
            try markContent(workspace, try s.DocumentDeclaration.key(stored.content, &key_buffer), stored.content);
        },
        .document_initialization => |request| {
            try request.validate();
            _ = try s.DocumentInitialization.readStored(allocator, log, index.store, request);
            try workspace.enqueue(.{ .document_declaration = request.declared });
            const end = try log.tail(request.partition);
            if (end > 1) {
                var latest = try log.read(allocator, request.partition, end - 1, 1);
                defer latest.deinit();
                if (latest.frames.len != 1) return error.DocumentHistoryUnavailable;
                const decoded = (try s.DocumentPartitionRecord.decode(allocator, latest.frames[0], request.partition, end - 1)).record;
                try request.requireSame(decoded.root.initialization);
                try workspace.enqueue(.{ .document_history = try .init(decoded.root.initialization, decoded.root.next_lsn) });
            }
        },
        .document_history => |*walk| {
            switch (try walk.step(allocator, log, index.store)) {
                .complete => return true,
                .empty => |initialized| try workspace.enqueue(.{ .document_declaration = initialized.declared }),
                .root => |root| {
                    const archive = if (walk.latest) |latest| (latest.record.root.archive orelse s.LogHistory.Coverage.empty) else (root.archive orelse s.LogHistory.Coverage.empty);
                    const context = try DocumentContext.fromRoot(root, archive);
                    if (root.recovery) |rec| {
                        try markContent(workspace, try s.DocumentRecovery.key(rec.content, &key_buffer), rec.content);
                    }
                    try workspace.enqueue(.{ .document_root = .{ .root = root, .archive = archive } });
                    try workspace.enqueue(.{ .document_wal = .{ .context = context, .lsn = root.next_lsn - 1 } });
                },
            }
            return false;
        },
        .document_root => |*value| {
            const root = value.root;
            const archive_dir = if (root.archive) |a| a.directory else null;
            const directories = [_]?s.TreeStore.pages.Reference{ root.documents_root, root.revisions_root, root.replicas_root, root.operations_root, root.reads_root, archive_dir };
            const kinds = [_]DocumentIndexKind{ .documents, .revisions, .replicas, .operations, .reads, .pages_only };
            if (value.slot > directories.len + 1) return error.InvalidDocumentStorageGraph;
            if (value.slot == directories.len + 1) return true;
            const context = try DocumentContext.fromRoot(root, value.archive);
            if (value.slot == 0) {
                try workspace.enqueue(.{ .document_declaration = root.declared });
                try workspace.enqueue(.{ .document_declaration = root.initialization.declared });
            } else if (directories[value.slot - 1]) |reference| {
                try workspace.enqueue(.{ .document_index = .{ .context = context, .reference = reference, .kind = kinds[value.slot - 1] } });
            }
            value.slot += 1;
            return false;
        },
        .document_index => |*value| {
            const page = try index.load(value.reference);
            if (value.height) |height| if (page.height != height) return error.InvalidDocumentStorageGraph;
            if (value.slot > page.count) return error.InvalidDocumentStorageGraph;
            if (!value.marked) {
                if (value.slot != 0) return error.InvalidDocumentStorageGraph;
                try markPage(index, workspace, value.reference);
                if (try workspace.visited(try scope(.{ .document_index = .{ .context = value.context, .reference = value.reference, .kind = value.kind, .prefix_bytes = value.prefix_bytes } }))) return true;
                value.marked = true;
                return false;
            }
            if (value.slot == page.count) return true;
            switch (page.body) {
                .branch => |children| try workspace.enqueue(.{ .document_index = .{ .context = value.context, .reference = children[value.slot].?.reference, .kind = value.kind, .prefix_bytes = value.prefix_bytes, .height = page.height - 1 } }),
                .leaf => |entries| try documentEntry(allocator, index, workspace, value.context, value.kind, value.prefix_bytes, entries[value.slot].?),
            }
            value.slot += 1;
            return false;
        },
        .document_read => |value| {
            const source = try s.DocumentRead.load(allocator, index.store, value.handle.source);
            try value.context.requireTarget(source.cut.target.partition);
            if (!std.meta.eql(source.request.operation, value.handle.owner) or
                source.cut.accepted.partition != value.context.partition or
                source.cut.accepted.next_lsn >= value.context.next_lsn)
            {
                return error.InvalidDocumentStorageGraph;
            }
            try markContent(workspace, try s.DocumentRead.key(value.handle.source, &key_buffer), value.handle.source);
        },
        .document_wal => |value| {
            if (value.lsn >= value.context.next_lsn) return error.InvalidDocumentStorageGraph;
            var batch = if (value.lsn < value.context.archive.through)
                try s.LogHistory.read(allocator, index, value.context.archive, value.context.partition, value.lsn)
            else
                try log.read(allocator, value.context.partition, value.lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.DocumentHistoryUnavailable;
            if (value.lsn == 0) {
                const initialized = try s.DocumentInitialization.decode(allocator, batch.frames[0]);
                try value.context.requireTarget(initialized.request.target());
            } else {
                const record = (try s.DocumentPartitionRecord.decode(allocator, batch.frames[0], value.context.partition, value.lsn)).record;
                try value.context.requireTarget(record.root.initialization.target());
            }
            if (value.lsn < value.context.archive.through) {
                const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = index };
                const reference = try tree.get(value.context.archive.directory, try s.TableArchive.key(value.lsn)) orelse return error.DocumentHistoryUnavailable;
                const content = try s.TableArchive.decodeReference(reference);
                try markContent(workspace, try s.TableArchive.objectKey(content.sha256, &key_buffer), content);
            }
        },
        .table_history => |*walk| {
            const context = try Context.fromRoot(walk.cut.root);
            const archive = walk.cut.root.archive;
            switch (try walk.next(allocator, index, log)) {
                .complete => return true,
                .progress => {},
                .current => |root| try workspace.enqueue(.{ .table_root = .{ .root = root, .archive = archive, .role = .current } }),
                .checkpoint => |checkpoint| {
                    try markContent(workspace, try s.TableRecovery.key(checkpoint.reference.content, &key_buffer), checkpoint.reference.content);
                    try workspace.enqueue(.{ .table_root = .{ .root = checkpoint.basis.root, .archive = archive, .role = .recovery } });
                },
                .frame => |frame| {
                    const record = frame.record;
                    try workspace.enqueue(.{ .table_root = .{ .root = record.root, .archive = archive, .role = if (frame.role == .recovery) .recovery else .history } });
                    try workspace.enqueue(.{ .wal = .{ .context = context, .archive = archive, .lsn = record.root.next_lsn - 1 } });
                    if (frame.role == .recovery) switch (record.action) {
                        inline .pin, .release => |pin| try workspace.enqueue(.{ .snapshot = .{ .context = context, .archive = archive, .handle = .{ .owner = pin.owner, .content = pin.basis }, .live = false } }),
                        else => {},
                    };
                },
            }
            return false;
        },
        .table_root => |*value| {
            const root = value.root;
            const controls = value.role == .current or value.role == .recovery or value.role == .workspace;
            const directories = [_]?s.TreeStore.pages.Reference{ root.rows, root.scan_rows, root.identities, root.ordered_rows, root.physical_schemas, root.column_origins, if (controls) root.receipts else null, if (controls) root.operations else null, if (controls) root.pending else null, if (controls) root.pins else null, if (controls) root.history_pins else null, if (value.role == .current) root.archive.directory else null };
            const kinds = [_]Walk.Kind{ .rows, .scan_rows, .pages_only, .ordered_rows, .physical_schemas, .column_origins, .receipts, .operations, .pages_only, .pins, .pages_only, .pages_only };
            if (value.slot > directories.len + 1) return error.InvalidTableStorageGraph;
            if (value.slot == directories.len + 1) return true;
            const slot = value.slot;
            value.slot += 1;
            if (slot == 0) {
                try workspace.enqueue(.{ .declaration = root.declared() });
                if (root.transaction) |reference| try workspace.enqueue(.{ .table_preparation = .{ .reference = reference, .archive = if (value.role == .current) value.archive else null } });
            } else if (directories[slot - 1]) |reference| {
                try workspace.enqueue(.{ .table_walk = .{ .walk = try Walk.init(try Context.fromRoot(root), .{ .reference = reference, .kind = kinds[slot - 1] }), .archive = value.archive, .live_pins = value.role == .current } });
            }
            return false;
        },
        .table_walk => |*value| {
            const edge = try value.walk.next(index) orelse return true;
            const context = value.walk.context;
            switch (edge) {
                .page => |root| {
                    try markPage(index, workspace, root.reference);
                    if (try workspace.visited(try scope(.{ .table = context, .root = root, .live_pins = value.live_pins }))) try value.walk.skip();
                },
                .index => |root| try workspace.enqueue(.{ .table_walk = .{ .walk = try Walk.init(context, root), .archive = value.archive, .live_pins = value.live_pins } }),
                .segment => |content| try workspace.enqueue(.{ .segment = content }),
                .declaration => |stored| try workspace.enqueue(.{ .declaration = stored }),
                .wal => |position| try workspace.enqueue(.{ .wal = .{ .context = context, .archive = value.archive, .lsn = position.next_lsn - 1 } }),
                .snapshot => |handle| try workspace.enqueue(.{ .snapshot = .{ .context = context, .archive = value.archive, .handle = handle, .live = value.live_pins } }),
                .evidence => |evidence| try workspace.enqueue(.{ .evidence = .{ .context = context, .edge = evidence } }),
                .archive => return error.InvalidTableStorageGraph, // Archive values are weak; required frames have explicit jobs.
            }
            return false;
        },
        .declaration => |stored| {
            var declaration = try s.TableDeclaration.load(allocator, index.store, stored);
            defer declaration.deinit();
            try markContent(workspace, try s.TableDeclaration.key(stored.content, &key_buffer), stored.content);
        },
        .evidence => |value| {
            const evidence = try s.TableEvidence.load(allocator, index.store, try s.TableEvidence.reference(value.edge.content));
            if (!std.meta.eql(evidence.binding().identity, value.edge.owner) or !std.meta.eql(evidence.binding().target, value.context.object) or
                evidence.position.partition != value.context.partition or evidence.position.next_lsn > value.context.next_lsn or
                (evidence.evidence == .receipt) != (value.edge.kind == .receipt)) return error.InvalidTableStorageGraph;
            try markContent(workspace, try s.TableEvidence.key(value.edge.content, &key_buffer), value.edge.content);
            switch (evidence.evidence) {
                .receipt => |accepted| try workspace.enqueue(.{ .declaration = accepted.resulting }),
                .operation => |operation| try workspace.enqueue(.{ .intent = operation }),
            }
        },
        .intent => |operation| {
            var intent = try s.TableDmlIntent.load(allocator, index.store, operation.intent);
            defer intent.deinit();
            try operation.binding.requireSame(intent.request.binding);
            try markContent(workspace, try s.TableDmlIntent.key(operation.intent, &key_buffer), operation.intent);
            try workspace.enqueue(.{ .declaration = intent.request.interpretation });
        },
        .snapshot => |value| {
            var frozen = try s.TableSnapshot.load(allocator, index.store, value.handle);
            defer frozen.deinit();
            try requireOwner(value.context, frozen.root);
            try markContent(workspace, try s.TableSnapshot.key(value.handle.content, &key_buffer), value.handle.content);
            if (value.live) {
                try workspace.enqueue(.{ .table_root = .{ .root = frozen.root, .archive = value.archive, .role = .snapshot } });
                if (frozen.retention == .history) {
                    if (frozen.root.next_lsn == 0) return error.InvalidTableStorageGraph;
                    try workspace.enqueue(.{ .wal = .{ .context = value.context, .archive = value.archive, .lsn = frozen.root.next_lsn - 1 } });
                }
            } else try workspace.enqueue(.{ .declaration = frozen.root.declared() });
        },
        .wal => |value| {
            if (value.lsn >= value.context.next_lsn) return error.InvalidTableStorageGraph;
            var batch = if (value.lsn < value.archive.through)
                try s.TableArchive.read(allocator, index, value.archive, value.context.partition, value.lsn)
            else
                try log.read(allocator, value.context.partition, value.lsn, 1);
            defer batch.deinit();
            if (batch.frames.len != 1) return error.TableHistoryMissing;
            const record = (try s.TablePartitionRecord.decodeFrame(allocator, batch.frames[0], value.context.partition, value.lsn)).record;
            try requireOwner(value.context, record.root);
            if (value.lsn < value.archive.through) {
                const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = index };
                const entry = try tree.get(value.archive.directory, try s.TableArchive.key(value.lsn)) orelse return error.TableHistoryMissing;
                const content = try s.TableArchive.decodeReference(entry);
                try markContent(workspace, try s.TableArchive.objectKey(content.sha256, &key_buffer), content);
            }
            // A row locator owns this frame's bytes, not its obsolete root graph.
        },
        .segment => |content| {
            try content.validate();
            if (content.bytes > s.TransitObjectStore.max_object_bytes) return error.InvalidTableStorageGraph;
            const key = try std.fmt.bufPrint(&key_buffer, "table-segments/{x}.tseg", .{&content.sha256});
            const meta = try index.store.head(key) orelse return error.TableSegmentMissing;
            if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) return error.InvalidTableStorageGraph;
            var buffer: [64 * 1024]u8 = undefined;
            var digest = std.crypto.hash.sha2.Sha256.init(.{});
            var offset: u64 = 0;
            while (offset < content.bytes) {
                const length: u32 = @intCast(@min(buffer.len, content.bytes - offset));
                const bytes = try index.store.getRange(key, offset, length, &buffer);
                if (bytes.len != length) return error.InvalidTableStorageGraph;
                digest.update(bytes);
                offset += length;
            }
            if (!std.mem.eql(u8, &digest.finalResult(), &content.sha256)) return error.InvalidTableStorageGraph;
            try markContent(workspace, key, content);
        },
    }
    return true;
}
