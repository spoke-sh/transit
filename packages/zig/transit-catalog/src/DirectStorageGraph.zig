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

pub const Work = union(enum) {
    catalog_history: c.DirectCatalogRoots,
    transaction: struct { root: r.Root, progress: c.DirectClientToken.Progress, slot: u8 = 0 },
    transaction_walk: struct { walk: c.DirectCatalogWalk, head: W.Head, scope: c.DirectRecord.Scope, tables: bool },
    transaction_intent: W.Request,
    table_preparation: struct { reference: s.TableTransaction.Reference, archive: ?s.TableArchive.Coverage = null },
    transaction_journal: u64,
    transaction_directory: struct { catalog: r.Root, identity: c.protocol.Transaction.Identity, directory: c.protocol.Transaction.Directory, kind: s.TransactionDirectory.Kind, after: ?u64 = null, started: bool = false },
    catalog_root: struct { root: r.Root, slot: u8 = 0 },
    catalog_walk: c.DirectCatalogWalk,
    catalog_intent: struct { configuration: r.Configuration, operation: r.Operation },
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
    for ([_][]const u8{ "data-index/", "data-maintenance/", "catalog-intents/", "table-definitions/", "table-evidence/", "table-intents/", "table-snapshots/", "table-checkpoints/", "table-history/", "table-segments/", "table-preparations/" }) |prefix| {
        if (std.mem.startsWith(u8, key, prefix)) return true;
    }
    return false;
}

pub fn fromFrame(allocator: std.mem.Allocator, frame: s.TransitLog.Frame) !Work {
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

/// Advance one cursor, directory slot, or bounded object. At most three child
/// jobs are added. Caller publishes work, marks and this active cursor together;
/// any error discards all private cursor/root changes from this step.
pub fn step(allocator: std.mem.Allocator, index: *s.TreeStore, log: s.TransitLog.Log, work: *Work, workspace: anytype) !bool {
    switch (work.*) {
        .declaration, .evidence, .intent, .snapshot, .wal, .segment, .catalog_intent => if (try workspace.visited(try scope(work.*))) return true,
        else => {},
    }
    var key_buffer: [96]u8 = undefined;
    switch (work.*) {
        .catalog_history => |*walk| {
            const record = try walk.next(allocator, log) orelse return true;
            try workspace.enqueue(.{ .catalog_root = .{ .root = record.root } });
            if (record.action == .operation) try workspace.enqueue(.{ .catalog_intent = .{ .configuration = record.root.configuration, .operation = record.action.operation } });
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
        .transaction => |*value| {
            const progress = value.progress;
            const begin = progress.receipt.binding.intent.transaction.begin;
            if (value.slot == 0) {
                var selected = try s.TransactionDirectory.init(allocator, index.store, begin.identity, .participants, begin.limits.participants, 0, 1);
                defer selected.deinit();
                try selected.restore(begin.tables);
                try markContent(workspace, try s.TransactionDirectory.objectKey(begin.tables.content, &key_buffer), begin.tables.content);
                if (selected.root.entries) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(value.root, .{ .reference = reference, .kind = .pages_only }) });
            } else {
                if (progress.record == null) return true;
                const control = if (progress.record.?.format == c.DirectTransactionControl.format) try c.DirectTransactionControl.load(allocator, index.store, progress) else null;
                if (value.slot == 5) {
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
                        try workspace.enqueue(.{ .transaction_intent = request });
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
                        const completed = try W.load(W.Completed, allocator, index.store, reference, value.scope, format);
                        try completed.validate();
                        if (!std.meta.eql(completed.request.statement.transaction, value.head.acquired.cut.begin.identity) or
                            completed.request.statement.sequence > value.head.last_statement or !std.meta.eql(entry.key, try W.idKey(completed.request.statement.sequence))) return error.InvalidTableStorageGraph;
                        try workspace.enqueue(.{ .transaction_intent = completed.request });
                    }
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
            if (value.kind != .preparations) return true;
            const page = try directory.page(value.after);
            const entry = page.entries[0] orelse return true;
            try workspace.enqueue(.{ .table_preparation = .{ .reference = .{ .content = entry.prepared.successor } } });
            value.after = entry.object().object;
            return false;
        },
        .table_preparation => |value| {
            const preparation = try s.TableTransaction.load(allocator, index.store, value.reference);
            try markContent(workspace, try s.TableTransaction.key(value.reference, &key_buffer), value.reference.content);
            if (value.archive) |archive| try workspace.enqueue(.{ .table_root = .{ .root = preparation.workspace.root, .archive = archive, .role = .workspace } });
        },
        .catalog_root => |*value| {
            const root = value.root;
            const directories = [_]?s.TreeStore.pages.Reference{ root.schemas, root.schema_names, root.namespace_claims, root.namespace_pending, root.objects, root.names, root.operations, root.pending, root.native_allocations, root.dependents, root.dependencies, root.client_tokens, root.client_operations, root.client_pending, root.client_accounts };
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
