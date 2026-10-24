//! Direct Table dispatch inside the local storage owner. The host coordinates
//! catalog DDL/admission and each Table's mutations before entering this helper.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Policy = @import("LocalCatalogPolicy.zig");
const Runner = @import("LocalCatalogRunner.zig");
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const D = c.DirectCatalog;
const Self = @This();

engine: *backend.DataAuthority.Engine,
configuration: D.Configuration,
registrar: struct { principal: u64, key: c.protocol.Ed25519.KeyPair, role: ?u64 = null },
options: D.Options = .{},
/// Inject a real authority change after response serialization in fault proofs.
before_reply: ?struct { context: *anyopaque, run: *const fn (*anyopaque, *backend.DataAuthority.Engine) anyerror!void } = null,

/// All borrowed result fields live in the request arena until the buffered
/// response is sent. The final fence can discard it after a revocation race.
pub fn execute(self: *Self, arena: *std.heap.ArenaAllocator, request: w.Request, output: []u8) ![]const u8 {
    const allocator = arena.allocator();
    try request.validate(allocator);
    if (!request.connection.matches(self.configuration)) return error.CatalogDenied;
    const context = try w.Request.context(request.input(), allocator);
    const original = if (request.closure) |closure|
        try closure.proof(request.delegation.?, allocator)
    else if (request.borrow) |borrow| try borrow.proof(request.delegation.?, allocator) else if (request.delegation) |delegation| delegation.proof else request.proof;
    const original_context = if (request.closure != null or request.borrow != null) original.claim.context else if (request.delegation) |delegation| try delegation.binding.context(allocator) else context;
    var policy = try Policy.init(self.engine, self.configuration, original, original_context, if (request.delegation != null) request.proof else null);
    const owner = self.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = owner, .control = true };
    var data: backend.DataStore = .{ .backend = owner };
    var catalog = try D.init(allocator, self.configuration, control.log(), control.objects(), data.log(), data.objects(), self.options);
    defer catalog.deinit();
    try catalog.recover();
    const result = try self.apply(allocator, &catalog, policy.policy(), request.action, request.delegation);
    const observed = try policy.observation();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, w.max_response_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try c.protocol.Json.write(w.Response{ .definition = c.protocol.Growth.current_definition, .context = context, .policy_revision = observed.revision, .subject = observed.subject, .result = result }, &encoder);
    if (self.before_reply) |inject| try inject.run(inject.context, self.engine);
    if (!std.meta.eql(try policy.observation(), observed)) return error.AuthorizationChanged;
    return writer.buffered();
}

fn schema(allocator: std.mem.Allocator, value: c.fuze.TableSchema.Schema) !w.Binary {
    const buffer = try allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
    defer allocator.free(buffer);
    return w.Binary.encode(allocator, try value.encode(buffer));
}
fn encodeDefinition(allocator: std.mem.Allocator, view: *const D.View) !w.Definition {
    return .{
        .interpretation = view.table.root.declared(),
        .namespace = view.properties.namespace,
        .authorization = view.properties.authorization,
        .name = view.properties.name,
        .position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn },
        .changed_lsn = view.table.root.changed_lsn,
        .row_count = view.table.root.live_rows,
        .schema = try schema(allocator, view.table.declaration.schema.schema),
    };
}
fn requireSource(delegation: ?c.DirectReadDelegation, source: c.storage.TablePartition.SnapshotDefinition) !void {
    if (delegation) |value| {
        if (value.binding.retention != source.retention) return error.TableDelegationDenied;
        try value.requireSource(source.root.interpretation, .{ .partition = source.root.partition, .next_lsn = source.root.next_lsn });
    }
}
fn historySource(allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, delegation: ?c.DirectReadDelegation, object: d.Object, lease: c.storage.TablePartition.SnapshotHandle, point: ?c.storage.TablePartition.HistoryPoint) !w.HistorySource {
    // Verify the original lease as well as the selected successor. Possession
    // of a later root cannot replace the grant's exact original acquisition.
    if (delegation != null) {
        var original = try catalog.snapshotDefinition(allocator, object, lease, policy);
        defer original.deinit();
        try requireSource(delegation, original);
    }
    var found = try catalog.historyDefinition(allocator, object, lease, point, policy);
    defer found.deinit();
    if (delegation) |grant| try grant.requireHistory(found.root.interpretation, found.point.position);
    return .{ .point = found.point, .source = .{
        .snapshot = .{ .object = object, .handle = lease },
        .interpretation = found.root.declared(),
        .accepted = found.point.position,
        .changed_lsn = found.root.changed_lsn,
        .row_count = found.root.live_rows,
        .schema = try schema(allocator, found.declaration.schema.schema),
        .authority = try catalog.readAuthority(object, lease.owner, policy, false),
    } };
}
fn apply(self: *Self, allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, action: w.Action, delegation: ?c.DirectReadDelegation) anyerror!w.Result {
    switch (action) {
        .initialize => {
            try catalog.initialize(policy);
            return .initialized;
        },
        .describe => return .{ .description = self.configuration },
        .read_authority => |object| return .{ .read_authority = try catalog.currentReadAuthority(object, policy) },
        .name_assertion => |value| return .{ .name_assertion = try catalog.assertName(value.binding, value.command, policy) },
        .namespace => |id| return .{ .namespace = try catalog.inspectNamespace(id, policy) },
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
                    var source = try catalog.snapshotDefinition(allocator, snapshot.object, snapshot.handle, policy);
                    defer source.deinit();
                    try requireSource(delegation, source);
                },
            };
            // LocalCatalogPolicy accumulates successful requirements and
            // rechecks their union after buffering this response.
            return .checked;
        },
        .lookup => |value| {
            var view = (try catalog.resolve(allocator, value.namespace, try .init(value.name), policy)) orelse return .{ .lookup = null };
            defer view.deinit();
            return .{ .lookup = try encodeDefinition(allocator, &view) };
        },
        .observe => |value| {
            var current = try catalog.observe(allocator, value.namespace, value.interpretation, value.rows, policy);
            defer current.deinit();
            const page: ?w.CurrentPage = if (current.page) |*found| blk: {
                const rows = try allocator.alloc(w.Binary, found.count);
                const scratch = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
                defer allocator.free(scratch);
                for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try found.rows[i].?.row().encode(current.view.table.declaration.schema.schema, scratch));
                break :blk .{ .rows = rows, .encoded_bytes = found.encoded_bytes, .more = found.more };
            } else null;
            return .{ .observation = .{ .definition = try encodeDefinition(allocator, &current.view), .authority = current.authority, .page = page } };
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
        .preview => |value| return .{ .preview = try catalog.preview(try value.native(allocator, self.configuration), policy) },
        .stage => |value| {
            try catalog.checkOperation(value.intent.work.binding(), value.namespace, policy);
            // CREATE additionally checks selection of its frozen owner role;
            // preview also validates the exact DDL shape without admission.
            if (value.intent.work == .ddl) _ = try catalog.preview(try value.intent.work.ddl.native(allocator, self.configuration), policy);
            var intent = try c.DirectTableIntent.create(allocator, value.intent.connection, value.intent.work);
            defer intent.deinit();
            return .{ .staged = try c.DirectTableIntentStore.stage(catalog.data_objects, &intent, value.namespace) };
        },
        .admit_saved => |reference| {
            try catalog.checkOperation(reference.binding, reference.namespace, policy);
            var intent = try c.DirectTableIntentStore.load(allocator, catalog.data_objects, reference);
            defer intent.deinit();
            return self.apply(allocator, catalog, policy, intent.parsed.value.work.action(), delegation);
        },
        .admit_ddl => |value| {
            _ = try catalog.admit(try value.native(allocator, self.configuration), policy);
            return .{ .ddl = try catalog.status(value.binding, policy) };
        },
        inline .admit_rows, .admit_statement => |value| return .{ .rows = try catalog.admitRows(try value.native(allocator), policy) },
        .operation => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => return .{ .ddl = switch (value.command) {
                .inspect => try catalog.status(value.binding, policy),
                .cancel => try catalog.cancel(value.binding, policy),
                .execute => blk: {
                    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
                    break :blk (try runner.run(catalog, value.binding, policy, value.steps)).observation;
                },
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
                var original = try catalog.snapshotDefinition(allocator, value.snapshot.object, value.snapshot.handle, policy);
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
            var declaration = try catalog.historyDefinition(allocator, value.source.object, value.source.point.lease, value.source.point, policy);
            defer declaration.deinit();
            var found = try catalog.scanHistory(allocator, value.source.object, value.source.point, value.after, value.limits, policy);
            defer found.deinit();
            const page = found.page;
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(declaration.declaration.schema.schema, scratch));
            return .{ .history_page = .{ .point = found.point, .page = .{ .snapshot = source.source.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } } };
        },
        .pin_status => |value| {
            const state = try catalog.pinState(value.object, value.owner, policy);
            if (delegation != null and !state.released) if (state.handle) |handle| {
                var source = try catalog.snapshotDefinition(allocator, value.object, handle, policy);
                defer source.deinit();
                try requireSource(delegation, source);
            };
            return .{ .pin_state = .{ .interpretation = state.interpretation, .position = state.position, .retired = state.retired, .handle = state.handle, .released = state.released, .authority = try catalog.readAuthority(value.object, value.owner, policy, true) } };
        },
        .snapshot => |value| {
            var found = try catalog.snapshotDefinition(allocator, value.object, value.handle, policy);
            defer found.deinit();
            try requireSource(delegation, found);
            return .{ .snapshot = .{
                .snapshot = value,
                .interpretation = found.root.declared(),
                .accepted = .{ .partition = found.root.partition, .next_lsn = found.root.next_lsn },
                .changed_lsn = found.root.changed_lsn,
                .row_count = found.root.live_rows,
                .schema = try schema(allocator, found.schema.schema),
                .authority = try catalog.readAuthority(value.object, value.handle.owner, policy, false),
            } };
        },
        .read_key => |value| {
            var definition = try catalog.snapshotDefinition(allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            try requireSource(delegation, definition);
            const key = try value.key.decode(allocator, c.fuze.Collation.max_sort_key_bytes);
            defer allocator.free(key);
            var found = try catalog.readRow(allocator, value.snapshot.object, value.snapshot.handle, key, policy);
            defer if (found) |*row| row.deinit();
            const encoded: ?w.Binary = if (found) |row| encoded: {
                const scratch = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
                defer allocator.free(scratch);
                break :encoded try w.Binary.encode(allocator, try row.row().encode(definition.schema.schema, scratch));
            } else null;
            return .{ .point = .{ .snapshot = value.snapshot, .interpretation = definition.root.declared(), .accepted = .{ .partition = definition.root.partition, .next_lsn = definition.root.next_lsn }, .changed_lsn = definition.root.changed_lsn, .total_rows = definition.root.live_rows, .row = encoded } };
        },
        .scan => |value| {
            var definition = try catalog.snapshotDefinition(allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            try requireSource(delegation, definition);
            var page = try catalog.scanRows(allocator, value.snapshot.object, value.snapshot.handle, value.after, value.limits, policy);
            defer page.deinit();
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(definition.schema.schema, scratch));
            return .{ .page = .{ .snapshot = value.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } };
        },
        .release => |value| {
            if (delegation != null) {
                const state = try catalog.pinState(value.object, value.handle.owner, policy);
                if (!state.released) {
                    var source = try catalog.snapshotDefinition(allocator, value.object, value.handle, policy);
                    defer source.deinit();
                    try requireSource(delegation, source);
                }
            }
            try catalog.releaseRows(value.object, value.handle, policy);
            return .released;
        },
    }
}
