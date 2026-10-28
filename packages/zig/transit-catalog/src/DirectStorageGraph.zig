//! Retained direct-data dependencies. A storage adapter supplies durable work
//! and marks; this owner supplies catalog/Table interpretation and reachability.
const std = @import("std");
const c = @import("root.zig");
const s = c.storage;
const d = c.protocol.DataLifecycle;
const r = @import("DirectCatalogRecords.zig");
const CatalogStore = @import("DirectCatalogStore.zig");
const Intent = @import("DirectCatalogIntent.zig");
const Role = enum { current, recovery, history, snapshot };
const Walk = s.TableStorageWalk;
const Context = Walk.Context;

pub const Work = union(enum) {
    catalog_history: c.DirectCatalogRoots,
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
    for ([_][]const u8{ "data-index/", "data-maintenance/", "catalog-intents/", "table-definitions/", "table-evidence/", "table-intents/", "table-snapshots/", "table-checkpoints/", "table-history/", "table-segments/" }) |prefix| {
        if (std.mem.startsWith(u8, key, prefix)) return true;
    }
    return false;
}

pub fn fromFrame(allocator: std.mem.Allocator, frame: s.TransitLog.Frame) !Work {
    if (std.mem.startsWith(u8, frame.payload, "TCATLOG1")) {
        const record = try CatalogStore.decodeFrame(allocator, frame, frame.header.partition_id, frame.header.lsn);
        return .{ .catalog_history = try .init(.{ .root = record.root, .chain = r.hash(frame.payload) }) };
    }
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
                const begin = record.action.client_token.receipt.binding.intent.transaction.begin;
                var selected = try s.TransactionDirectory.init(allocator, index.store, begin.identity, .participants, begin.limits.participants, 0, 1);
                defer selected.deinit();
                try selected.restore(begin.tables);
                try markContent(workspace, try s.TransactionDirectory.objectKey(begin.tables.content, &key_buffer), begin.tables.content);
                if (selected.root.entries) |reference| try workspace.enqueue(.{ .catalog_walk = try .init(record.root, .{ .reference = reference, .kind = .pages_only }) });
            }
            return false;
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
            const controls = value.role == .current or value.role == .recovery;
            const directories = [_]?s.TreeStore.pages.Reference{ root.rows, root.scan_rows, root.identities, root.ordered_rows, root.physical_schemas, root.column_origins, if (controls) root.receipts else null, if (controls) root.operations else null, if (controls) root.pending else null, if (controls) root.pins else null, if (controls) root.history_pins else null, if (value.role == .current) root.archive.directory else null };
            const kinds = [_]Walk.Kind{ .rows, .scan_rows, .pages_only, .ordered_rows, .physical_schemas, .column_origins, .receipts, .operations, .pages_only, .pins, .pages_only, .pages_only };
            if (value.slot > directories.len + 1) return error.InvalidTableStorageGraph;
            if (value.slot == directories.len + 1) return true;
            const slot = value.slot;
            value.slot += 1;
            if (slot == 0) {
                try workspace.enqueue(.{ .declaration = root.declared() });
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
