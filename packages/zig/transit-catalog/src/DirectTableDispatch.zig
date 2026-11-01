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
/// catalog/storage owners directly. Stream composition uses a separate callback
/// for its bounded resident owner, private cursor key and trusted clock.
pub const Execution = struct {
    context: *anyopaque,
    ddl: *const fn (*anyopaque, *D, d.Binding, D.Policy, u16) anyerror!D.Observation,
    namespace: *const fn (*anyopaque, *D, c.DirectNamespace.Binding, D.Policy, u16) anyerror!c.DirectNamespace.Observation,
    resource: ?*const fn (*anyopaque, *D, c.DirectResource.Binding, D.Policy, c.DirectResource.Command, u16, ?c.DirectResource.SignedAllocation) anyerror!c.DirectResource.Observation = null,
    log: ?*const fn (*anyopaque, *D, d.Binding, D.Policy, u16) anyerror!c.DirectLog.Observation = null,
    stream: ?*const fn (*anyopaque, std.mem.Allocator, *D, D.Policy, c.DirectStream.Request) anyerror!c.DirectStream.Result = null,
    queue: ?*const fn (*anyopaque, std.mem.Allocator, *D, D.Policy, c.DirectQueue.Request) anyerror!c.DirectQueue.Result = null,
};

fn inspectWorkload(context: *anyopaque, output: std.mem.Allocator, catalog: *D, policy: D.Policy, work: c.DirectWorkloadIntent.Work) !c.DirectWorkloadIntent.Reader.Result {
    return switch (work) {
        .stream => |value| .{ .stream = try workloadStream(context, output, catalog, policy, .{ .operation = value.work }) },
        .queue => |value| .{ .queue = try workloadQueue(context, output, catalog, policy, .{ .operation = value.work }) },
    };
}
fn workloadStream(context: *anyopaque, output: std.mem.Allocator, catalog: *D, policy: D.Policy, request: c.DirectStream.Request) !c.DirectStream.Result {
    const execution: *const Execution = @ptrCast(@alignCast(context));
    return (execution.stream orelse return error.StreamServiceUnavailable)(execution.context, output, catalog, policy, request);
}
fn workloadQueue(context: *anyopaque, output: std.mem.Allocator, catalog: *D, policy: D.Policy, request: c.DirectQueue.Request) !c.DirectQueue.Result {
    const execution: *const Execution = @ptrCast(@alignCast(context));
    return (execution.queue orelse return error.QueueServiceUnavailable)(execution.context, output, catalog, policy, request);
}

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
    // Isolate each action's frame. A runtime switch reserves debug-build
    // temporaries for every unrelated arm, including large page results.
    switch (std.meta.activeTag(action)) {
        inline else => |tag| return applySelected(tag, allocator, catalog, policy, &action, delegation, execution),
    }
}

fn applySelected(comptime action_tag: std.meta.Tag(w.Action), allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, action: *const w.Action, delegation: ?c.DirectReadDelegation, execution: Execution) anyerror!w.Result {
    switch (action_tag) {
        .branch => return .{ .branch = try branch(allocator, catalog, policy, action.branch) },
        .kv => {
            var scratch: std.heap.ArenaAllocator = .init(catalog.allocator);
            defer scratch.deinit();
            return .{ .kv = try c.DirectKV.apply(scratch.allocator(), allocator, catalog, action.kv, policy) };
        },
        .kv_declaration => {
            var scratch: std.heap.ArenaAllocator = .init(catalog.allocator);
            defer scratch.deinit();
            const value = action.kv_declaration;
            const request = try value.declaration.request(scratch.allocator());
            return .{ .kv_declaration = switch (value.command) {
                .preview => .{ .preview = try catalog.preview(request, policy) },
                .admit => blk: {
                    _ = try catalog.admit(request, policy);
                    break :blk .{ .operation = try catalog.status(request.binding, policy) };
                },
                .inspect => .{ .operation = try catalog.status(request.binding, policy) },
                .execute => .{ .operation = try execution.ddl(execution.context, catalog, request.binding, policy, value.steps) },
                .cancel => .{ .operation = try catalog.cancel(request.binding, policy) },
            } };
        },
        .kv_lookup => {
            const value = action.kv_lookup;
            var view = try catalog.resolveKV(catalog.allocator, value.namespace, try c.TableAuthority.Name.init(value.name), policy) orelse return .{ .kv_lookup = null };
            defer view.deinit();
            return .{ .kv_lookup = try c.DirectKV.definition(&view.table, view.properties) };
        },
        .kv_list => {
            const value = action.kv_list;
            const after = if (value.after) |id| try @import("DirectCatalogRecords.zig").idKey(id) else null;
            const page = try catalog.listKV(value.namespace, after, policy);
            return .{ .kv_list = .{ .entries = page.entries, .next = if (page.next) |cursor| next: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :next std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null, .directory_position = page.directory_position, .consistency = .independent } };
        },
        .queue => {
            const run = execution.queue orelse return error.QueueServiceUnavailable;
            return .{ .queue = try run(execution.context, allocator, catalog, policy, action.queue) };
        },
        .stream => {
            const run = execution.stream orelse return error.StreamServiceUnavailable;
            return .{ .stream = try run(execution.context, allocator, catalog, policy, action.stream) };
        },
        .transaction => {
            const request = @field(action.*, @tagName(action_tag));
            return .{ .transaction = switch (request) {
                .call => |value| .{ .call = try catalog.transactionCall(value.key, value.steps, value.control, value.cancel, policy) },
                .call_outcome => |value| .{ .call = try catalog.transactionCallOutcome(value, policy) },
                .begin => |value| .{ .begun = try catalog.beginTransaction(value, policy) },
                .acquire => |key| .{ .acquired = try catalog.acquireTransaction(key, policy) },
                .inspect => |key| .{ .status = try catalog.inspectTransaction(key, policy) },
                .stage => |value| .{ .staged = try catalog.stageTransactionStatement(value.key, value.basis, value.sequence, value.work, policy) },
                .stage_kv => |value| .{ .staged = try catalog.stageTransactionKV(value.key, value.basis, value.sequence, value.work, policy) },
                .stage_log => |value| staged: {
                    const payload = if (value.payload) |encoded| try encoded.decode(catalog.allocator, c.storage.LogTransactionActions.max_payload_bytes) else null;
                    defer if (payload) |bytes| catalog.allocator.free(bytes);
                    break :staged .{ .staged_log = try catalog.stageTransactionLog(value.key, value.basis, value.sequence, value.work, payload, policy) };
                },
                .log_statement => |value| .{ .log_statement = if (value.execute) try catalog.executeTransactionLog(value.key, value.request, policy) else try catalog.admitTransactionLog(value.key, value.request, policy) },
                .log_outcome => |value| .{ .log_statement = try catalog.transactionLogOutcome(value.key, value.request, policy) },
                .statement => |value| .{ .statement = if (value.execute) try catalog.executeTransactionStatement(value.key, value.request, policy) else try catalog.admitTransactionStatement(value.key, value.request, policy) },
                .statement_outcome => |value| .{ .statement = try catalog.transactionStatementOutcome(value.key, value.request, policy) },
                .savepoint_outcome => |value| .{ .savepoint_outcome = try catalog.transactionSavepointOutcome(value.key, value.request, policy) },
                .savepoint => |value| .{ .savepoint = try catalog.transactionSavepoint(value.key, value.request, value.steps, policy) },
                .advance => |value| .{ .status = try catalog.resumeTransaction(value.key, value.steps, policy) },
                .settle => |value| .{ .status = try catalog.settleTransaction(value.key, value.operation, value.command, value.steps, policy) },
            } };
        },
        .record => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .record = try catalog.directRecord(allocator, value, policy) };
        },
        .workload_result => {
            var owners = execution;
            return .{ .workload_result = try c.DirectWorkloadResultProtocol.apply(allocator, catalog, policy, action.workload_result, .{ .context = &owners, .stream = workloadStream, .queue = workloadQueue }) };
        },
        .client_progress => {
            const value = @field(action.*, @tagName(action_tag));
            var owners = execution;
            return .{ .client_progress = try catalog.clientProgressWithWorkloads(value, policy, .{ .context = &owners, .inspect = inspectWorkload }) };
        },
        .client_token => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .client_token = try catalog.clientToken(value, policy) };
        },
        .initialize => {
            try catalog.initialize(policy);
            return .initialized;
        },
        .describe => return .{ .description = catalog.store.root.configuration },
        .storage => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .storage = try catalog.inspectStorage(value.object, value.pending_limit, policy) };
        },
        .flush => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .flush = try catalog.flushStorage(value, policy) };
        },
        .read_authority => {
            const object = @field(action.*, @tagName(action_tag));
            return .{ .read_authority = try catalog.currentReadAuthority(object, policy) };
        },
        .name_assertion => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .name_assertion = try catalog.assertName(value.binding, value.command, policy) };
        },
        .namespace => {
            const id = @field(action.*, @tagName(action_tag));
            return .{ .namespace = try catalog.inspectNamespace(id, policy) };
        },
        .dependency_operation => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .dependency_operation = try catalog.dependencyOperation(value.binding, value.command, policy) };
        },
        .dependency_state => {
            const edge = @field(action.*, @tagName(action_tag));
            return .{ .dependency_state = try catalog.dependencyState(edge, policy) };
        },
        .dependencies => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .dependencies = try catalog.dependencyPage(value.selection, value.cursor, value.authority, policy) };
        },
        .resource_preview => {
            const binding = @field(action.*, @tagName(action_tag));
            return .{ .resource_preview = try catalog.previewResource(binding, policy) };
        },
        .log_preview => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .log_preview = try catalog.previewLog(try value.request(allocator), policy) };
        },
        .log_admit => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .log_admitted = try catalog.admitLog(try value.request(allocator), policy) };
        },
        .log_operation => {
            const value = @field(action.*, @tagName(action_tag));

            if (value.command == .execute) {
                const run = execution.log orelse return error.LogCatalogExecutionUnavailable;
                return .{ .log_operation = try run(execution.context, catalog, value.binding, policy, value.steps) };
            }
            return .{ .log_operation = try catalog.logOperation(value.binding, if (value.command == .inspect) .inspect else .cancel, policy) };
        },
        .log_lookup => {
            const value = @field(action.*, @tagName(action_tag));

            const found = try catalog.resolveLog(value.namespace, try .init(value.name), policy) orelse return .{ .log_lookup = null };
            var declaration = try catalog.logDefinition(catalog.allocator, found, policy);
            defer declaration.deinit();
            return .{ .log_lookup = .{ .declaration = found, .schema = try schema(allocator, catalog.allocator, declaration.definition.schema) } };
        },
        .log_list => {
            const value = @field(action.*, @tagName(action_tag));

            const after = if (value.after) |id| try @import("DirectCatalogRecords.zig").idKey(id) else null;
            const page = try catalog.listLogs(value.namespace, after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .log_list = .{ .entries = page.entries, .next = next, .position = page.position } };
        },
        .log_pending => {
            const value = @field(action.*, @tagName(action_tag));

            const after = if (value.after) |id| try @import("DirectCatalogRecords.zig").idKey(id) else null;
            const page = try catalog.pendingLogs(value.namespace, after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .log_pending = .{ .entries = page.entries, .next = next, .position = page.position } };
        },
        .resource_operation => {
            const value = @field(action.*, @tagName(action_tag));

            if (value.command == .inspect or value.command == .admit) return .{ .resource_operation = try catalog.resourceOperation(value.binding, value.command, policy) };
            const run = execution.resource orelse return error.NamedResourceNativeUnavailable;
            return .{ .resource_operation = try run(execution.context, catalog, value.binding, policy, value.command, value.steps, value.signed_allocation) };
        },
        .resource_lookup => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .resource_lookup = try catalog.resolveResource(value.namespace, try .init(value.name), policy) };
        },
        .resource_list => {
            const value = @field(action.*, @tagName(action_tag));

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
        .namespace_preview => {
            const binding = @field(action.*, @tagName(action_tag));
            return .{ .namespace_preview = try catalog.previewNamespace(binding, policy) };
        },
        .namespace_operation => {
            const value = @field(action.*, @tagName(action_tag));

            if (value.command != .execute) return .{ .namespace_operation = try catalog.namespaceOperation(value.binding, value.command, policy) };
            return .{ .namespace_operation = try execution.namespace(execution.context, catalog, value.binding, policy, value.steps) };
        },
        .namespaces => {
            const value = @field(action.*, @tagName(action_tag));

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
        .check => {
            const value = @field(action.*, @tagName(action_tag));

            try catalog.checkAccess(value, policy);
            return .checked;
        },
        .check_set => {
            const values = @field(action.*, @tagName(action_tag));

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
        .lookup => {
            const value = @field(action.*, @tagName(action_tag));

            var view = (try catalog.resolve(catalog.allocator, value.namespace, try .init(value.name), policy)) orelse return .{ .lookup = null };
            defer view.deinit();
            return .{ .lookup = try encodeDefinition(allocator, catalog.allocator, &view) };
        },
        .observe => {
            const value = @field(action.*, @tagName(action_tag));

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
        .read_current => {
            const value = @field(action.*, @tagName(action_tag));

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
        .list => {
            const value = @field(action.*, @tagName(action_tag));

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
        .preview => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .preview = try catalog.preview(try value.native(allocator, catalog.store.root.configuration), policy) };
        },
        .name_preview => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .name_preview = try catalog.previewName(value, policy) };
        },
        .preview_rows, .preview_statement => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .row_preview = try catalog.previewRows(try value.native(allocator), policy) };
        },
        .stage => {
            const value = @field(action.*, @tagName(action_tag));

            try catalog.checkOperation(value.intent.work.binding(), value.namespace, policy);
            // CREATE additionally checks selection of its frozen owner role;
            // preview also validates the exact DDL shape without admission.
            if (value.intent.work == .ddl) _ = try catalog.preview(try value.intent.work.ddl.native(allocator, catalog.store.root.configuration), policy);
            var intent = try c.DirectTableIntent.create(catalog.allocator, value.intent.connection, value.intent.work);
            defer intent.deinit();
            return .{ .staged = try c.DirectTableIntentStore.stageWithBinding(catalog.data_objects, &intent, value.namespace, value.intent.work != .ddl) };
        },
        .commit_saved => {
            const reference = @field(action.*, @tagName(action_tag));

            if (reference.binding.action != .insert and reference.binding.action != .update and reference.binding.action != .delete) return error.UnsupportedTableAction;
            try catalog.checkOperation(reference.binding, reference.namespace, policy);
            var intent = try c.DirectTableIntentStore.load(catalog.allocator, catalog.data_objects, reference);
            defer intent.deinit();
            return .{ .rows = try catalog.applyRows(switch (intent.parsed.value.work) {
                inline .rows, .statement => |value| try value.native(allocator),
                .ddl => return error.UnsupportedTableAction,
            }, policy) };
        },
        .admit_saved => {
            const reference = @field(action.*, @tagName(action_tag));

            try catalog.checkOperation(reference.binding, reference.namespace, policy);
            var intent = try c.DirectTableIntentStore.load(catalog.allocator, catalog.data_objects, reference);
            defer intent.deinit();
            return apply(allocator, catalog, policy, intent.parsed.value.work.action(), delegation, execution);
        },
        .admit_ddl => {
            const value = @field(action.*, @tagName(action_tag));

            _ = try catalog.admit(try value.native(allocator, catalog.store.root.configuration), policy);
            return .{ .ddl = try catalog.status(value.binding, policy) };
        },
        .admit_rows, .admit_statement => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .rows = try catalog.admitRows(try value.native(allocator), policy) };
        },
        .operation => {
            const value = @field(action.*, @tagName(action_tag));
            switch (value.binding.action) {
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
            }
        },
        .pin => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .pin = if (delegation) |grant| (if (value.selection == .current) try catalog.captureRowsDefined(grant.binding.interpretation, value.owner, value.expected, policy) else try catalog.pinRowsDefined(grant.binding.interpretation, value.owner, value.expected, policy)) else try catalog.pinRows(value.object, value.owner, value.expected, policy) };
        },
        .retain_history => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .pin = try catalog.retainHistory(value.object, value.owner, value.expected, if (delegation) |grant| grant.binding.interpretation else null, policy) };
        },
        .history_start => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .history_source = try historySource(allocator, catalog, policy, delegation, value.object, value.handle, null) };
        },
        .history_source => {
            const value = @field(action.*, @tagName(action_tag));
            return .{ .history_source = try historySource(allocator, catalog, policy, delegation, value.object, value.point.lease, value.point) };
        },
        .history => {
            const value = @field(action.*, @tagName(action_tag));

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
        .history_scan => {
            const value = @field(action.*, @tagName(action_tag));

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
        .pin_status => {
            const value = @field(action.*, @tagName(action_tag));

            const state = try catalog.pinState(value.object, value.owner, policy);
            if (delegation != null and !state.released) if (state.handle) |handle| {
                var source = try catalog.snapshotDefinition(catalog.allocator, value.object, handle, policy);
                defer source.deinit();
                try requireSource(delegation, source);
            };
            return .{ .pin_state = .{ .interpretation = state.interpretation, .position = state.position, .retired = state.retired, .handle = state.handle, .released = state.released, .authority = try catalog.readAuthority(value.object, value.owner, policy, true) } };
        },
        .snapshot => {
            const value = @field(action.*, @tagName(action_tag));

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
        .read_key => {
            const value = @field(action.*, @tagName(action_tag));

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
        .scan, .column_scan => {
            const value = @field(action.*, @tagName(action_tag));
            const tag = action_tag;

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
        .filter_scan => {
            const value = @field(action.*, @tagName(action_tag));

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
        .key_range => {
            const value = @field(action.*, @tagName(action_tag));

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
        .release => {
            const value = @field(action.*, @tagName(action_tag));

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

fn branch(output: std.mem.Allocator, catalog: *D, policy: D.Policy, request: c.DirectBranch.Request) !c.DirectBranch.Result {
    switch (request) {
        .create => |value| return .{ .status = try catalog.createBranch(value, policy) },
        .inspect => |key| return .{ .status = try catalog.inspectBranch(key, policy) },
        .advance => |key| return .{ .status = try catalog.advanceBranch(key, false, policy) },
        .cancel => |key| return .{ .status = try catalog.advanceBranch(key, true, policy) },
        .lookup => |value| return .{ .status = try catalog.lookupBranch(value.namespace, value.name, policy) },
        .source, .scan => {},
    }
    const head = if (request == .source) request.source else request.scan.head;
    var scratch = std.heap.ArenaAllocator.init(catalog.allocator);
    defer scratch.deinit();
    var selected = try catalog.openBranch(scratch.allocator(), head, policy);
    defer selected.deinit();
    var definition = try selected.access.view.table.inspectSnapshot(catalog.allocator, selected.entry.pin, selected.access.current);
    defer definition.deinit();
    const current = selected.access.current;
    const result: c.DirectBranch.Result = if (request == .source) .{ .source = .{
        .head = head,
        .source = selected.entry.source,
        .mode = selected.mode,
        .interpretation = definition.root.declared(),
        .rows = if (selected.mode == .schema_only) 0 else definition.root.live_rows,
        .schema = try schema(output, catalog.allocator, definition.schema.schema),
    } } else result: {
        const read = request.scan;
        if (selected.mode == .schema_only) {
            if (read.after != null) return error.InvalidBranchCursor;
            break :result .{ .page = .{ .head = head, .source = selected.entry.source, .total_rows = 0, .rows = &.{}, .encoded_bytes = 0, .next = null } };
        }
        var page = try selected.access.view.table.scanSnapshot(catalog.allocator, selected.entry.pin, read.after, read.limits, current);
        defer page.deinit();
        const rows = try output.alloc(w.Binary, page.count);
        const buffer = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
        defer catalog.allocator.free(buffer);
        for (rows, 0..) |*row, i| row.* = try w.Binary.encode(output, try page.rows[i].?.row().encode(definition.schema.schema, buffer));
        break :result .{ .page = .{ .head = head, .source = selected.entry.source, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } };
    };
    // Includes buffered rows, schema, and genuinely empty terminal results.
    _ = try current.acquire(current.context);
    current.release(current.context);
    return result;
}
