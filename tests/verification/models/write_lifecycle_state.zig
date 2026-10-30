//! Selected lifecycle counterexamples against the real TablePartition owner
//! and WriteTokens counterexamples against DirectCatalog.clientToken.
//! Proposed TRUNCATE/combined SQL acceptance and physical power loss have
//! separate owners; this adapter does not simulate them.
const std = @import("std");
const c = @import("transit_catalog");
const s = @import("transit_storage");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const a = c.TableAuthority;
const d = p.DataLifecycle;
const D = c.DirectCatalog;
const P = s.TablePartition;
const Event = enum { Init, Freeze, Accept, Commit, Retry, Cancel, Observe, LaterInsert, Crash, Recover, Fence, Execution, Inspection, LoseReply, Cleanup, TokenConflict, TokenIsolation, Submit1, Submit2, LoseReply1, LoseReply2, Rebind };
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .int64, .nullable = false },
};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const Access = struct {
    allowed: bool = true,
    epoch: u64 = 1,
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(context));
        if (!self.allowed) return error.PermissionDenied;
        return .{ .writer_epoch = self.epoch, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};
fn owner(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !P {
    var table = try P.init(allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer table.deinit();
    try table.recover();
    return table;
}
fn binding(table: *P, id: u64, action: d.Action) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = if (action == .create) null else .{ .partition = 17, .next_lsn = table.root.next_lsn }, .intent = @splat(7) };
}
fn insert(table: *P, access: *Access, id: i64, operation: u64) !void {
    const exact = binding(table, operation, .insert);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .signed = 1 } } } };
    const changes = [_]P.Change{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(exact.identity, 0), .cells = &cells }, .expect = .absent } }};
    const state = try table.commit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &changes, .ingestion = .point }, access.guard());
    if (state != .committed) return error.InsertNotCommitted;
}
fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.LostAcknowledgement, error.PermissionDenied, error.StaleWriterEpoch => @errorName(err),
        else => return err,
    };
}
fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var table = try owner(allocator, &wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    try insert(&table, &access, 1, 2);
    try insert(&table, &access, 2, 3);
    const snapshot = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 4 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    var compiled = try f.TableDml.compile(allocator, "UPDATE events SET value = 2", "events", schema, null);
    defer compiled.deinit();
    var exact = binding(&table, 10, .update);
    exact.intent = try compiled.plan.fingerprint(allocator);
    var execution = true;
    var inspection = true;
    var online = true;
    var epoch: u64 = 1;
    var first: ?P.Evidence = null;
    var last_error: []const u8 = "none";
    for (events) |event| {
        last_error = "none";
        access.allowed = execution;
        switch (event) {
            .Init, .LoseReply => {},
            .Freeze => {
                exact = binding(&table, 10, .update);
                exact.intent = try compiled.plan.fingerprint(allocator);
            },
            .Accept => {
                _ = table.admit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &.{}, .ingestion = .bulk, .statement = compiled.plan }, access.guard()) catch |err| blk: {
                    last_error = try expectedError(err);
                    break :blk P.OperationState.not_observed;
                };
            },
            .Commit, .Retry, .Cancel, .Observe => {
                if (!online) return error.UnmappedOfflineAction;
                access.allowed = if (event == .Observe or event == .Retry) inspection else execution;
                // The first completion reply is deliberately lost. Observation
                // below must recover the exact receipt, including after retry.
                table.lose_reply = event == .Commit and first == null;
                const result = (switch (event) {
                    .Commit => table.commit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &.{}, .ingestion = .bulk, .statement = compiled.plan }, access.guard()),
                    .Cancel => table.cancel(exact, access.guard()),
                    else => table.operationState(exact, access.guard()),
                }) catch |err| blk: {
                    last_error = try expectedError(err);
                    break :blk P.OperationState.not_observed;
                };
                table.lose_reply = false;
                if (result == .committed) {
                    if (first) |original| if (!std.meta.eql(original, result.committed)) return error.ChangedOriginalOutcome;
                }
            },
            .LaterInsert => {
                var current: Access = .{ .epoch = epoch };
                try insert(&table, &current, 3, 20);
            },
            .Execution => execution = !execution,
            .Inspection => inspection = !inspection,
            .Fence => {
                epoch = 2;
                try wal.fenceEpochs(17, epoch, 1);
            },
            .Crash => {
                online = false;
            },
            .Recover => {
                table.deinit();
                table = try owner(allocator, &wal, &objects);
                access.epoch = epoch;
                online = true;
            },
            .Cleanup => {
                var current: Access = .{ .epoch = epoch };
                _ = try table.checkpoint(.{ .partition = 17, .next_lsn = table.root.next_lsn }, current.guard());
            },
            .TokenConflict, .TokenIsolation, .Submit1, .Submit2, .LoseReply1, .LoseReply2, .Rebind => return error.UnmappedWriteLifecycleAction,
        }
        // An uncertain append poisons the owner. Reconstruct it before the
        // oracle reads; this extra recovery is recorded in the model guide.
        if (table.recovery_required) try table.recover();
        // Independent inspection for the oracle, never caller disclosure.
        var auditor: Access = .{ .epoch = epoch };
        const state = try table.operationState(exact, auditor.guard());
        if (state == .committed) {
            if (first) |original| {
                if (!std.meta.eql(original, state.committed)) return error.ChangedOriginalOutcome;
            } else first = state.committed;
        }
    }
    var auditor: Access = .{ .epoch = epoch };
    const state = try table.operationState(exact, auditor.guard());
    var rows: [3]i128 = @splat(0);
    var after: ?s.TreeStore.pages.Key = null;
    while (true) {
        const batch = try table.scan(table.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            const index = row.row().cells[0].value.atom.signed - 1;
            if (index < 0 or index >= rows.len or rows[@intCast(index)] != 0) return error.UnexpectedRow;
            rows[@intCast(index)] = row.row().cells[1].value.atom.signed;
        };
        after = batch.next orelse break;
    }
    var retained = try table.scanSnapshot(allocator, snapshot, null, .{}, auditor.guard());
    defer retained.deinit();
    if (retained.total_rows != 2) return error.RetainedSnapshotChanged;
    for (retained.rows) |slot| if (slot) |row| {
        if (row.row().cells[1].value.atom.signed != 1) return error.RetainedSnapshotChanged;
    };
    try std.json.Stringify.value(.{ .rows = rows, .decision = @tagName(state), .matched = if (state == .committed) state.committed.outcome.matched else 0, .changed = if (state == .committed) state.committed.outcome.affected else 0, .last_error = last_error, .retained_rows = retained.total_rows }, .{}, out);
    try out.writeByte('\n');
}

const cat_scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const cat_profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
const CatAccess = struct {
    const Context = struct { requested: p.Authorization.Guard };
    fn make(_: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .requested = requested };
        return .{ .context = result, .acquire = acquire, .release = release };
    }
    fn acquire(_: *anyopaque) !P.Guard.Fence {
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(_: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        const native: u64 = switch (kind) {
            .database => cat_profile.database,
            .schema => if (id == 1) cat_profile.initial_schema_authority else 20000 + id,
            .table => 100 + id,
        };
        return .{
            .reference = a.reference(native),
            .owner = 0,
            .registrar = 1,
            .actions = a.actions(kind),
            .domain = cat_profile.domain(kind),
            .binding = try a.binding(cat_scope, kind, id),
            .parent = switch (kind) {
                .database => null,
                .schema => a.reference(cat_profile.database),
                .table => a.reference(cat_profile.initial_schema_authority),
            },
            .revision = 1,
        };
    }
    fn policy(self: *CatAccess) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } }, .make_guard = make, .registered = registered };
    }
};

fn initCatalog(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !D {
    const cfg: D.Configuration = .{ .scope = cat_scope, .branch = 1, .partition = 1, .audience = 3, .authority = cat_profile, .database_name = try a.Name.init("main"), .initial_schema_name = try a.Name.init("public") };
    var catalog = try D.init(allocator, cfg, wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    errdefer catalog.deinit();
    try catalog.recover();
    return catalog;
}

fn createCatTable(allocator: std.mem.Allocator, catalog: *D, access: *CatAccess, object_id: u64, operation: u64, name: []const u8) !void {
    const tbl_schema: f.TableSchema.Schema = .{ .object = object_id, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .namespace = 1, .name = try a.Name.init(name), .action = .{ .create = .{ .schema = tbl_schema, .owner = 0 } } };
    const req: D.Request = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = cat_scope, .principal = 1, .operation = operation }, .target = .{ .scope = cat_scope, .branch = 1, .object = object_id }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(allocator) },
        .intent = intent,
    };
    _ = try catalog.admit(req, access.policy());
    _ = try catalog.perform(req.binding, access.policy());
    _ = try catalog.settle(req.binding, access.policy());
}

fn renameCatTable(allocator: std.mem.Allocator, catalog: *D, access: *CatAccess, from: []const u8, to: []const u8, operation: u64) !void {
    var view = (try catalog.resolve(allocator, 1, try a.Name.init(from), access.policy())).?;
    defer view.deinit();
    const intent: D.Intent = .{ .namespace = 1, .name = view.properties.name, .action = .{ .rename = try a.Name.init(to) } };
    const req: D.Request = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = cat_scope, .principal = 1, .operation = operation }, .target = view.table.root.interpretation.object, .action = .rename, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = try intent.digest(allocator) },
        .intent = intent,
    };
    _ = try catalog.admit(req, access.policy());
    _ = try catalog.perform(req.binding, access.policy());
    _ = try catalog.settle(req.binding, access.policy());
}

fn makeRowTokenBinding(allocator: std.mem.Allocator, catalog: *D, access: *CatAccess, name: []const u8, operation: u64, account: u8, token: u8, fingerprint: u8) !c.DirectClientToken.Binding {
    var view = (try catalog.resolve(allocator, 1, try a.Name.init(name), access.policy())).?;
    defer view.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = cat_scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const scratch = try alloc.alloc(u8, 4096);
    const tbl_schema = view.table.declaration.schema.schema;
    const wire_schema = try c.DirectTableProtocol.Binary.encode(alloc, try tbl_schema.encode(scratch));
    const orig_binding: d.Binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = cat_scope, .principal = 1, .operation = operation },
        .target = view.table.root.interpretation.object,
        .action = .insert,
        .expected_definition = view.table.root.interpretation,
        .expected_data = null,
        .intent = @splat(0),
    };
    const cells = [_]f.Types.Values.Cell{
        .{ .value = .{ .atom = .{ .signed = @intCast(operation) } } },
        .{ .value = .{ .atom = .{ .signed = 1 } } },
    };
    const row: f.TableRow.Row = .{ .identity = try c.DirectTableProtocol.Rows.insertIdentity(orig_binding.identity, 0), .cells = &cells };
    const encoded_row = try row.encode(tbl_schema, scratch);
    const changes = [_]c.DirectTableProtocol.RowChange{.{ .insert = try c.DirectTableProtocol.Binary.encode(alloc, encoded_row) }};
    var work: c.DirectTableProtocol.Rows = .{
        .binding = orig_binding,
        .interpretation = view.table.root.declared(),
        .schema = wire_schema,
        .changes = &changes,
        .ingestion = .point,
    };
    work.binding.intent = try work.digest(alloc);
    var intent = try c.DirectTableIntent.create(allocator, connection, .{ .rows = work });
    defer intent.deinit();
    return .{
        .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(account), .token = @splat(token) },
        .fingerprint = @splat(fingerprint),
        .intent = .{ .table = try c.DirectTableIntentStore.stage(catalog.data_objects, &intent, 1) },
    };
}

fn replayTokens(allocator: std.mem.Allocator, isolation: bool, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var catalog = try initCatalog(allocator, &wal, &objects);
    defer catalog.deinit();
    var access: CatAccess = .{};
    try catalog.initialize(access.policy());
    try createCatTable(allocator, &catalog, &access, 1, 10, "table_1");
    try createCatTable(allocator, &catalog, &access, 2, 11, "table_2");

    const b1 = try makeRowTokenBinding(allocator, &catalog, &access, "table_1", 101, 1, 1, 1);
    const b2 = if (isolation)
        try makeRowTokenBinding(allocator, &catalog, &access, "table_1", 102, 2, 1, 1)
    else
        try makeRowTokenBinding(allocator, &catalog, &access, "table_2", 102, 1, 1, 2);

    var replies: [2]u64 = .{ 0, 0 };
    var target1: u64 = 0;
    var retained = true;
    var last_error: []const u8 = "none";

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init => {},
            .Submit1, .Submit2 => {
                const idx: usize = if (event == .Submit1) 0 else 1;
                const req = if (idx == 0) b1 else b2;
                if (catalog.clientToken(.{ .bind = req }, access.policy())) |rec| {
                    const op = rec.?.binding.intent.table.binding.identity.operation;
                    replies[idx] = if (op == 101) 1 else 2;
                    if (idx == 0) target1 = rec.?.binding.intent.table.binding.target.object;
                } else |err| switch (err) {
                    error.ClientTokenConflict => {
                        replies[idx] = 3;
                        last_error = "ClientTokenConflict";
                    },
                    else => return err,
                }
            },
            .LoseReply1 => replies[0] = 0,
            .LoseReply2 => replies[1] = 0,
            .Rebind => {
                try renameCatTable(allocator, &catalog, &access, "table_1", "table_tmp", 20);
                try renameCatTable(allocator, &catalog, &access, "table_2", "table_1", 21);
                try renameCatTable(allocator, &catalog, &access, "table_tmp", "table_2", 22);
            },
            .Recover => {
                const count_before = catalog.store.root.client_token_count;
                catalog.deinit();
                catalog = try initCatalog(allocator, &wal, &objects);
                retained = retained and (catalog.store.root.client_token_count == count_before);
                if (count_before > 0) {
                    retained = retained and ((try catalog.clientToken(.{ .lookup = b1.key }, access.policy())) != null);
                }
            },
            else => return error.UnmappedTokenAction,
        }
    }
    try std.json.Stringify.value(.{
        .replies = replies,
        .retained = retained,
        .target1 = target1,
        .unique_tokens = catalog.store.root.client_token_count,
        .last_error = last_error,
    }, .{}, out);
    try out.writeByte('\n');
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTracePath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(bytes);
    var traces = try std.json.parseFromSlice([]const []const Event, init.gpa, bytes, .{});
    defer traces.deinit();
    if (traces.value.len > 128) return error.TooManyTraces;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (traces.value) |events| {
        if (events.len > 128) return error.TraceTooLong;
        if (events.len > 0 and (events[0] == .TokenConflict or events[0] == .TokenIsolation)) {
            try replayTokens(init.gpa, events[0] == .TokenIsolation, events[1..], &output.interface);
        } else {
            try replay(init.gpa, events, &output.interface);
        }
    }
    try output.interface.flush();
}
