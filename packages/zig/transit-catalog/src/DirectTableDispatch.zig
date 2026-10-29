//! Typed direct Table dispatch shared by owning service compositions. This
//! layer is not an authentication boundary: the host validates the signed
//! request/delegation, coordinates catalog/Table access, supplies current native
//! policy and rechecks all observed requirements after buffering disclosure.
//! Every borrowed output belongs to the supplied output allocator. Temporary
//! read owners and encoding buffers use the catalog allocator and are released
//! before returning, even when the output allocator is an arena.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const D = c.DirectCatalog;

/// The host supplies native registration execution. The implementation must
/// recheck the original policy before every registrar publication; its own
/// credential supplies no permission to the caller. Other actions use the
/// catalog/storage owners directly and cannot enter this execution callback.
pub const Execution = struct {
    context: *anyopaque,
    ddl: *const fn (*anyopaque, *D, d.Binding, D.Policy, u16) anyerror!D.Observation,
    namespace: *const fn (*anyopaque, *D, c.DirectNamespace.Binding, D.Policy, u16) anyerror!c.DirectNamespace.Observation,
    resource: ?*const fn (*anyopaque, *D, c.DirectResource.Binding, D.Policy, c.DirectResource.Command, u16, ?c.DirectResource.SignedAllocation) anyerror!c.DirectResource.Observation = null,
};

fn schema(allocator: std.mem.Allocator, scratch_allocator: std.mem.Allocator, value: c.fuze.TableSchema.Schema) !w.Binary {
    const buffer = try scratch_allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
    defer scratch_allocator.free(buffer);
    return w.Binary.encode(allocator, try value.encode(buffer));
}
fn encodeDefinition(allocator: std.mem.Allocator, scratch_allocator: std.mem.Allocator, view: *const D.View) !w.Definition {
    return .{
        .interpretation = view.table.root.declared(),
        .namespace = view.properties.namespace,
        .authorization = view.properties.authorization,
        .name = view.properties.name,
        .position = if (view.table.workspace_read) |read| read.source.source.accepted else .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn },
        .changed_lsn = if (view.table.workspace_read) |read| read.source.changed_lsn else view.table.root.changed_lsn,
        .workspace = view.table.workspace_read,
        .row_count = view.table.root.live_rows,
        .schema = try schema(allocator, scratch_allocator, view.table.declaration.schema.schema),
    };
}
fn requireSource(delegation: ?c.DirectReadDelegation, source: c.storage.TablePartition.SnapshotDefinition) !void {
    if (delegation) |value| {
        if (value.binding.retention != source.retention) return error.TableDelegationDenied;
        try value.requireSource(source.root.interpretation, .{ .partition = source.root.partition, .next_lsn = source.root.next_lsn });
    }
}
fn historySource(allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, delegation: ?c.DirectReadDelegation, object: d.Object, lease: c.storage.TablePartition.SnapshotHandle, point: ?c.storage.TablePartition.HistoryPoint) !w.HistorySource {
    // Reject a foreign original grant before opening the selected successor.
    // Its valid commitment cannot replace the original acquisition's authority.
    if (delegation != null) {
        var original = try catalog.snapshotDefinition(catalog.allocator, object, lease, policy);
        defer original.deinit();
        try requireSource(delegation, original);
    }
    // Selected history and current authority share one request-local owner.
    var read = try catalog.historyRead(catalog.allocator, object, lease, point, policy);
    defer read.deinit();
    const found = &read.definition;
    if (delegation) |grant| try grant.requireHistory(found.root.interpretation, found.point.position);
    return .{ .point = found.point, .source = .{
        .snapshot = .{ .object = object, .handle = lease },
        .interpretation = found.root.declared(),
        .accepted = found.point.position,
        .changed_lsn = found.root.changed_lsn,
        .row_count = found.root.live_rows,
        .schema = try schema(allocator, catalog.allocator, found.declaration.schema.schema),
        .authority = read.authority,
    } };
}
pub fn apply(allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, action: w.Action, delegation: ?c.DirectReadDelegation, execution: Execution) anyerror!w.Result {
    switch (action) {
        .transaction => |request| return .{ .transaction = switch (request) {
            .begin => |value| .{ .begun = try catalog.beginTransaction(value, policy) },
            .acquire => |key| .{ .acquired = try catalog.acquireTransaction(key, policy) },
            .inspect => |key| .{ .status = try catalog.inspectTransaction(key, policy) },
            .stage => |value| .{ .staged = try catalog.stageTransactionStatement(value.key, value.basis, value.sequence, value.work, policy) },
            .statement => |value| .{ .statement = if (value.execute) try catalog.executeTransactionStatement(value.key, value.request, policy) else try catalog.admitTransactionStatement(value.key, value.request, policy) },
            .advance => |value| .{ .status = try catalog.resumeTransaction(value.key, value.steps, policy) },
            .settle => |value| .{ .status = try catalog.settleTransaction(value.key, value.operation, value.command, value.steps, policy) },
        } },
        .record => |value| return .{ .record = try catalog.directRecord(allocator, value, policy) },
        .client_progress => |value| return .{ .client_progress = try catalog.clientProgress(value, policy) },
        .client_token => |value| return .{ .client_token = try catalog.clientToken(value, policy) },
        .initialize => {
            try catalog.initialize(policy);
            return .initialized;
        },
        .describe => return .{ .description = catalog.store.root.configuration },
        .storage => |value| return .{ .storage = try catalog.inspectStorage(value.object, value.pending_limit, policy) },
        .flush => |value| return .{ .flush = try catalog.flushStorage(value, policy) },
        .read_authority => |object| return .{ .read_authority = try catalog.currentReadAuthority(object, policy) },
        .name_assertion => |value| return .{ .name_assertion = try catalog.assertName(value.binding, value.command, policy) },
        .namespace => |id| return .{ .namespace = try catalog.inspectNamespace(id, policy) },
        .dependency_operation => |value| return .{ .dependency_operation = try catalog.dependencyOperation(value.binding, value.command, policy) },
        .dependency_state => |edge| return .{ .dependency_state = try catalog.dependencyState(edge, policy) },
        .dependencies => |value| return .{ .dependencies = try catalog.dependencyPage(value.selection, value.cursor, value.authority, policy) },
        .resource_preview => |binding| return .{ .resource_preview = try catalog.previewResource(binding, policy) },
        .resource_operation => |value| {
            if (value.command == .inspect or value.command == .admit) return .{ .resource_operation = try catalog.resourceOperation(value.binding, value.command, policy) };
            const run = execution.resource orelse return error.NamedResourceNativeUnavailable;
            return .{ .resource_operation = try run(execution.context, catalog, value.binding, policy, value.command, value.steps, value.signed_allocation) };
        },
        .resource_lookup => |value| return .{ .resource_lookup = try catalog.resolveResource(value.namespace, try .init(value.name), policy) },
        .resource_list => |value| {
            var bytes: [8]u8 = undefined;
            const after = if (value.after) |id| blk: {
                std.mem.writeInt(u64, &bytes, id, .big);
                break :blk try c.storage.TreeStore.pages.Key.init(&bytes);
            } else null;
            const page = try catalog.listResources(value.namespace, after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .resource_list = .{ .entries = page.entries, .next = next, .position = page.position } };
        },
        .namespace_preview => |binding| return .{ .namespace_preview = try catalog.previewNamespace(binding, policy) },
        .namespace_operation => |value| {
            if (value.command != .execute) return .{ .namespace_operation = try catalog.namespaceOperation(value.binding, value.command, policy) };
            return .{ .namespace_operation = try execution.namespace(execution.context, catalog, value.binding, policy, value.steps) };
        },
        .namespaces => |value| {
            var bytes: [8]u8 = undefined;
            const after = if (value.after) |id| blk: {
                std.mem.writeInt(u64, &bytes, id, .big);
                break :blk try c.storage.TreeStore.pages.Key.init(&bytes);
            } else null;
            const page = try catalog.listNamespaces(after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .namespaces = .{ .entries = page.entries, .next = next, .directory_position = page.directory_position } };
        },
        .check => |value| {
            try catalog.checkAccess(value, policy);
            return .checked;
        },
        .check_set => |values| {
            for (values) |value| switch (value) {
                .access => |access| try catalog.checkAccess(access, policy),
                .snapshot => |snapshot| {
                    var source = try catalog.snapshotDefinition(catalog.allocator, snapshot.object, snapshot.handle, policy);
                    defer source.deinit();
                    try requireSource(delegation, source);
                },
            };
            // The enclosing authenticated owner accumulates successful
            // requirements and rechecks their union after buffering.
            return .checked;
        },
        .lookup => |value| {
            var view = (try catalog.resolve(catalog.allocator, value.namespace, try .init(value.name), policy)) orelse return .{ .lookup = null };
            defer view.deinit();
            return .{ .lookup = try encodeDefinition(allocator, catalog.allocator, &view) };
        },
        .observe => |value| {
            var current = try catalog.observe(catalog.allocator, value.namespace, value.interpretation, value.rows, policy);
            defer current.deinit();
            const page: ?w.CurrentPage = if (current.page) |*found| blk: {
                const rows = try allocator.alloc(w.Binary, found.count);
                const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
                defer catalog.allocator.free(scratch);
                for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try found.rows[i].?.row().encode(current.view.table.declaration.schema.schema, scratch));
                break :blk .{ .rows = rows, .encoded_bytes = found.encoded_bytes, .more = found.more };
            } else null;
            return .{ .observation = .{ .definition = try encodeDefinition(allocator, catalog.allocator, &current.view), .authority = current.authority, .page = page } };
        },
        .read_current => |value| {
            var found = try catalog.readCurrent(catalog.allocator, value, policy);
            defer found.deinit();
            const declared = found.current.view.table.declaration.schema.schema;
            const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(scratch);
            const selection: @FieldType(w.CurrentReadResult, "selection") = switch (found.selection) {
                .key => |maybe| .{ .key = if (maybe) |row| try w.Binary.encode(allocator, try row.row().encode(declared, scratch)) else null },
                .rows => |page| blk: {
                    const rows = try allocator.alloc(w.Binary, page.count);
                    for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(declared, scratch));
                    break :blk .{ .rows = .{ .rows = rows, .encoded_bytes = page.encoded_bytes, .next = if (page.next) |next| try c.fuze.TableRow.Identity.decode(&next) else null } };
                },
            };
            return .{ .current_read = .{ .definition = try encodeDefinition(allocator, catalog.allocator, &found.current.view), .authority = found.current.authority, .selection = selection } };
        },
        .list => |value| {
            var bytes: [8]u8 = undefined;
            const after = if (value.after) |id| blk: {
                std.mem.writeInt(u64, &bytes, id, .big);
                break :blk try c.storage.TreeStore.pages.Key.init(&bytes);
            } else null;
            const page = try catalog.list(value.namespace, after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .list = .{ .entries = page.entries, .next = next, .directory_position = page.directory_position, .consistency = .independent } };
        },
        .preview => |value| return .{ .preview = try catalog.preview(try value.native(allocator, catalog.store.root.configuration), policy) },
        .name_preview => |value| return .{ .name_preview = try catalog.previewName(value, policy) },
        inline .preview_rows, .preview_statement => |value| return .{ .row_preview = try catalog.previewRows(try value.native(allocator), policy) },
        .stage => |value| {
            try catalog.checkOperation(value.intent.work.binding(), value.namespace, policy);
            // CREATE additionally checks selection of its frozen owner role;
            // preview also validates the exact DDL shape without admission.
            if (value.intent.work == .ddl) _ = try catalog.preview(try value.intent.work.ddl.native(allocator, catalog.store.root.configuration), policy);
            var intent = try c.DirectTableIntent.create(catalog.allocator, value.intent.connection, value.intent.work);
            defer intent.deinit();
            return .{ .staged = try c.DirectTableIntentStore.stage(catalog.data_objects, &intent, value.namespace) };
        },
        .commit_saved => |reference| {
            if (reference.binding.action != .insert and reference.binding.action != .update and reference.binding.action != .delete) return error.UnsupportedTableAction;
            try catalog.checkOperation(reference.binding, reference.namespace, policy);
            var intent = try c.DirectTableIntentStore.load(catalog.allocator, catalog.data_objects, reference);
            defer intent.deinit();
            return .{ .rows = try catalog.applyRows(switch (intent.parsed.value.work) {
                inline .rows, .statement => |value| try value.native(allocator),
                .ddl => return error.UnsupportedTableAction,
            }, policy) };
        },
        .admit_saved => |reference| {
            try catalog.checkOperation(reference.binding, reference.namespace, policy);
            var intent = try c.DirectTableIntentStore.load(catalog.allocator, catalog.data_objects, reference);
            defer intent.deinit();
            return apply(allocator, catalog, policy, intent.parsed.value.work.action(), delegation, execution);
        },
        .admit_ddl => |value| {
            _ = try catalog.admit(try value.native(allocator, catalog.store.root.configuration), policy);
            return .{ .ddl = try catalog.status(value.binding, policy) };
        },
        inline .admit_rows, .admit_statement => |value| return .{ .rows = try catalog.admitRows(try value.native(allocator), policy) },
        .operation => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => return .{ .ddl = switch (value.command) {
                .inspect => try catalog.status(value.binding, policy),
                .cancel => try catalog.cancel(value.binding, policy),
                .execute => try execution.ddl(execution.context, catalog, value.binding, policy, value.steps),
            } },
            .insert, .update, .delete => return .{ .rows = switch (value.command) {
                .inspect => try catalog.rowStatus(value.binding, policy),
                .cancel => try catalog.cancelRows(value.binding, policy),
                .execute => try catalog.performRows(value.binding, policy),
            } },
        },
        .pin => |value| return .{ .pin = if (delegation) |grant| (if (value.selection == .current) try catalog.captureRowsDefined(grant.binding.interpretation, value.owner, value.expected, policy) else try catalog.pinRowsDefined(grant.binding.interpretation, value.owner, value.expected, policy)) else try catalog.pinRows(value.object, value.owner, value.expected, policy) },
        .retain_history => |value| return .{ .pin = try catalog.retainHistory(value.object, value.owner, value.expected, if (delegation) |grant| grant.binding.interpretation else null, policy) },
        .history_start => |value| return .{ .history_source = try historySource(allocator, catalog, policy, delegation, value.object, value.handle, null) },
        .history_source => |value| return .{ .history_source = try historySource(allocator, catalog, policy, delegation, value.object, value.point.lease, value.point) },
        .history => |value| {
            if (delegation != null) {
                var original = try catalog.snapshotDefinition(catalog.allocator, value.snapshot.object, value.snapshot.handle, policy);
                defer original.deinit();
                try requireSource(delegation, original);
            }
            const found = try catalog.history(value.snapshot.object, value.snapshot.handle, value.from, value.through, value.frames, policy);
            const entries = try allocator.alloc(w.HistoryEntry, found.count);
            for (entries, 0..) |*entry, i| {
                const accepted = found.entries[i].?;
                const position: d.Position = .{ .partition = accepted.root.partition, .next_lsn = accepted.root.next_lsn };
                if (delegation) |grant| try grant.requireHistory(accepted.root.interpretation, position);
                entry.* = .{ .point = .{ .lease = value.snapshot.handle, .position = position, .commitment = accepted.commitment }, .interpretation = accepted.root.declared(), .changed_lsn = accepted.root.changed_lsn, .row_count = accepted.root.live_rows, .receipt = accepted.receipt };
            }
            return .{ .history = .{ .snapshot = value.snapshot, .through = found.through, .next = found.next, .scanned = found.scanned, .entries = entries } };
        },
        .history_scan => |value| {
            const source = try historySource(allocator, catalog, policy, delegation, value.source.object, value.source.point.lease, value.source.point);
            var declaration = try catalog.historyDefinition(catalog.allocator, value.source.object, value.source.point.lease, value.source.point, policy);
            defer declaration.deinit();
            var found = try catalog.scanHistory(catalog.allocator, value.source.object, value.source.point, value.after, value.limits, policy);
            defer found.deinit();
            const page = found.page;
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(declaration.declaration.schema.schema, scratch));
            return .{ .history_page = .{ .point = found.point, .page = .{ .snapshot = source.source.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } } };
        },
        .pin_status => |value| {
            const state = try catalog.pinState(value.object, value.owner, policy);
            if (delegation != null and !state.released) if (state.handle) |handle| {
                var source = try catalog.snapshotDefinition(catalog.allocator, value.object, handle, policy);
                defer source.deinit();
                try requireSource(delegation, source);
            };
            return .{ .pin_state = .{ .interpretation = state.interpretation, .position = state.position, .retired = state.retired, .handle = state.handle, .released = state.released, .authority = try catalog.readAuthority(value.object, value.owner, policy, true) } };
        },
        .snapshot => |value| {
            var read = try catalog.snapshotRead(catalog.allocator, value.object, value.handle, policy);
            defer read.deinit();
            const found = &read.definition;
            try requireSource(delegation, found.*);
            return .{ .snapshot = .{
                .snapshot = value,
                .interpretation = found.root.declared(),
                .accepted = found.position(),
                .changed_lsn = found.changedLsn(),
                .workspace = found.transaction,
                .row_count = found.root.live_rows,
                .schema = try schema(allocator, catalog.allocator, found.schema.schema),
                .authority = read.authority,
            } };
        },
        .read_key => |value| {
            var definition = try catalog.snapshotDefinition(catalog.allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            try requireSource(delegation, definition);
            const key = try value.key.decode(allocator, c.fuze.Collation.max_sort_key_bytes);
            defer allocator.free(key);
            var found = try catalog.readRow(catalog.allocator, value.snapshot.object, value.snapshot.handle, key, policy);
            defer if (found) |*row| row.deinit();
            const encoded: ?w.Binary = if (found) |row| encoded: {
                const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
                defer catalog.allocator.free(scratch);
                break :encoded try w.Binary.encode(allocator, try row.row().encode(definition.schema.schema, scratch));
            } else null;
            return .{ .point = .{ .snapshot = value.snapshot, .interpretation = definition.root.declared(), .accepted = definition.position(), .changed_lsn = definition.changedLsn(), .total_rows = definition.root.live_rows, .row = encoded } };
        },
        inline .scan, .column_scan => |value, tag| {
            var definition = try catalog.snapshotDefinition(catalog.allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            try requireSource(delegation, definition);
            var projected_columns: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
            const selected: ?c.fuze.TableProjection = if (tag == .column_scan) try value.projection() else null;
            const row_schema = if (selected) |*projection| try projection.projectedSchema(definition.schema.schema, &projected_columns) else definition.schema.schema;
            var page = if (selected) |*projection| try catalog.scanColumns(catalog.allocator, value.snapshot.object, value.snapshot.handle, projection.columns(), value.after, value.limits, policy) else try catalog.scanRows(catalog.allocator, value.snapshot.object, value.snapshot.handle, value.after, value.limits, policy);
            defer page.deinit();
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(row_schema, scratch));
            return .{ .page = .{ .snapshot = value.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } };
        },
        .filter_scan => |value| {
            var read = try catalog.snapshotRead(catalog.allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer read.deinit();
            const definition = &read.definition;
            try requireSource(delegation, definition.*);
            const basis: c.DirectTableReader.Basis = .{
                .snapshot = value.snapshot,
                .interpretation = definition.root.declared(),
                .accepted = definition.position(),
                .changed_lsn = definition.changedLsn(),
                .row_count = definition.root.live_rows,
                .authority = read.authority,
                .workspace = definition.transaction,
            };
            const plan = try value.decodePlan(allocator, definition.schema.schema, try basis.fingerprint());
            const selected = try c.fuze.TableProjection.fromPlan(definition.schema.schema, plan);
            var columns: [c.fuze.TableSchema.max_columns]c.fuze.TableSchema.Column = undefined;
            const row_schema = try selected.projectedSchema(definition.schema.schema, &columns);
            var result = try catalog.scanFiltered(catalog.allocator, value.snapshot.object, value.snapshot.handle, plan, value.after, value.limits, policy);
            defer result.deinit();
            const page = &result.page;
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(row_schema, scratch));
            return .{ .filtered_page = .{
                .page = .{ .snapshot = value.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next },
                .examined = result.examined,
                .offsets = result.offsets,
                .failure = if (result.failure) |failure| .{
                    .identity = failure.identity,
                    .column = failure.column,
                    .instruction = failure.instruction,
                    .outcome = switch (failure.outcome) {
                        .type_error => .type_error,
                        .conflict => .conflict,
                        else => unreachable,
                    },
                } else null,
            } };
        },
        .key_range => |value| {
            var definition = try catalog.snapshotDefinition(catalog.allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            try requireSource(delegation, definition);
            var bounds = std.heap.ArenaAllocator.init(catalog.allocator);
            defer bounds.deinit();
            const interval = try value.interval.native(bounds.allocator());
            const after = if (value.after) |cursor| try cursor.native(bounds.allocator()) else null;
            var page = try catalog.rangeRows(catalog.allocator, value.snapshot.object, value.snapshot.handle, interval, after, value.limits, policy);
            defer page.deinit();
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(definition.schema.schema, scratch));
            return .{ .key_range = .{ .snapshot = value.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = if (page.next) |cursor| try w.KeyCursor.encode(allocator, cursor) else null } };
        },
        .release => |value| {
            if (delegation != null) {
                const state = try catalog.pinState(value.object, value.handle.owner, policy);
                if (!state.released) {
                    var source = try catalog.snapshotDefinition(catalog.allocator, value.object, value.handle, policy);
                    defer source.deinit();
                    try requireSource(delegation, source);
                }
            }
            try catalog.releaseRows(value.object, value.handle, policy);
            return .released;
        },
    }
}
