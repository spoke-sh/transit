//! Replay ResidentOwnerCache.tla counterexample traces against production
//! DirectCatalog resident CachedTable owner, recoverSince prefix verification,
//! transaction temporary owner isolation, and TablePartition snapshot pins.
const std = @import("std");
const c = @import("transit_catalog");
const s = c.storage;
const p = c.protocol;
const f = c.fuze;
const a = c.TableAuthority;
const d = p.DataLifecycle;
const D = c.DirectCatalog;
const P = s.TablePartition;

const Event = enum {
    Init,
    AdvanceWalAndRecoverSince,
    RecoverSinceStaleHint,
    UncertainAppend,
    ExecuteTxStatement,
    BorrowWarmCache,
    CloseWarmBorrow,
    EvictLoseReleaseReply,
    ReconcileCacheTick,
    PinConflictAmbiguous,
};

const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};

const Access = struct {
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
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table => 100 + id,
        };
        return .{
            .reference = a.reference(native),
            .owner = 0,
            .registrar = 1,
            .actions = a.actions(kind),
            .domain = profile.domain(kind),
            .binding = try a.binding(scope, kind, id),
            .parent = switch (kind) {
                .database => null,
                .schema => a.reference(profile.database),
                .table => a.reference(profile.initial_schema_authority),
            },
            .revision = 1,
        };
    }
    fn policy(self: *Access) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } }, .make_guard = make, .registered = registered };
    }
};

fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.InvalidDirectCatalogHistory,
        error.TableRecoveryRequired,
        error.DataIdentityConflict,
        error.Conflict,
        => @errorName(err),
        else => return err,
    };
}

fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    const cfg: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 3, .authority = profile, .database_name = try a.Name.init("main"), .initial_schema_name = try a.Name.init("public") };
    var catalog = try D.init(allocator, cfg, wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    defer catalog.deinit();
    try catalog.recover();
    var access: Access = .{};
    try catalog.initialize(access.policy());

    const create_intent: D.Intent = .{ .namespace = 1, .name = try a.Name.init("selected_0"), .action = .{ .create = .{ .schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} }, .owner = 0 } } };
    const create_req: D.Request = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 10 }, .target = .{ .scope = scope, .branch = 1, .object = 10 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try create_intent.digest(allocator) },
        .intent = create_intent,
    };
    _ = try catalog.admit(create_req, access.policy());
    _ = try catalog.perform(create_req.binding, access.policy());
    _ = try catalog.settle(create_req.binding, access.policy());

    var retained: ?D.CachedTable = null;
    defer if (retained) |*cached| cached.table.deinit();
    catalog.options.table_owner = &retained;
    {
        var warm_view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
        warm_view.deinit();
    }
    const initial_retained_root = retained.?.table.root;

    var resident_slot_unchanged = true;
    var tx_private_rows: u64 = 0;
    var public_rows: u64 = 0;
    var pin_released = false;
    var cache_advertised = true;
    var pin_accepted = false;
    var last_error: []const u8 = "none";

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init, .BorrowWarmCache, .CloseWarmBorrow => {},
            .AdvanceWalAndRecoverSince => {
                const prior = try catalog.recoveryState();
                try catalog.recoverSince(prior);
            },
            .RecoverSinceStaleHint => {
                var corrupted = try catalog.recoveryState();
                corrupted.chain[0] ^= 0xff;
                if (catalog.recoverSince(corrupted)) |_| {} else |err| {
                    last_error = try expectedError(err);
                }
            },
            .UncertainAppend => {
                var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
                defer view.deinit();
                try wal.fenceEpochs(view.table.root.partition, 2, 1);
                const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
                const row_change: P.Change = .{ .put = .{ .row = .{ .identity = .{ .origin = 10, .operation = 99, .ordinal = 0 }, .cells = &.{one} }, .expect = .absent } };
                const b: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 99 }, .target = view.table.root.interpretation.object, .action = .insert, .expected_definition = view.table.root.interpretation, .expected_data = null, .intent = @splat(7) };
                _ = view.table.apply(b, &.{row_change}, .point, .{ .context = &access, .acquire = Access.acquire, .release = Access.release }) catch {};
                // Attempting to use the poisoned owner without recovery must fail closed.
                if (view.table.pin(.{ .scope = scope, .principal = 1, .operation = 100 }, .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, .{ .context = &access, .acquire = Access.acquire, .release = Access.release })) |_| {} else |err| {
                    last_error = try expectedError(err);
                }
            },
            .ExecuteTxStatement => {
                const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                const tx_id: p.Transaction.Identity = .{ .begin = .{ .scope = scope, .principal = 1, .operation = 50 }, .branch = 1 };
                var selected = try s.TransactionDirectory.init(allocator, catalog.data_objects, tx_id, .participants, 100, 1, 1024 * 1024);
                defer selected.deinit();
                try selected.put(.{ .participant = .{ .state = .{ .kind = .table, .access = .read, .guard = .{ .source = .{ .interpretation = initial_retained_root.interpretation, .accepted = .{ .partition = initial_retained_root.partition, .next_lsn = initial_retained_root.next_lsn } }, .changed_lsn = initial_retained_root.changed_lsn } } } });
                const tx_binding: c.DirectClientToken.Binding = .{
                    .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(1) },
                    .fingerprint = @splat(11),
                    .intent = .{ .transaction = .{
                        .connection = connection,
                        .namespace = 1,
                        .begin = .{ .definition = p.Growth.current_definition, .identity = tx_id, .mode = .serializable, .selection = .explicit_tables, .tables = try selected.seal(), .catalog = .{ .partition = 1, .next_lsn = catalog.store.root.next_lsn }, .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 256 * 1024, .participants = 100, .statements = 100, .savepoints = 16 } },
                    } },
                };
                _ = try catalog.clientToken(.{ .bind = tx_binding }, access.policy());
                _ = try catalog.acquireTransaction(tx_binding.key, access.policy());
                const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
                const stmt_binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 500 }, .target = initial_retained_root.interpretation.object, .action = .insert, .expected_definition = initial_retained_root.interpretation, .expected_data = null, .intent = @splat(3) };
                const dml_req: s.TableDmlIntent.Request = .{ .binding = stmt_binding, .interpretation = initial_retained_root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(stmt_binding.identity, 0), .cells = &.{one} }, .expect = .absent } }}, .ingestion = .bulk };
                const ws_req: c.DirectTransactionWorkspace.Request = .{ .statement = .{ .transaction = tx_id, .sequence = 1, .intent = stmt_binding.intent }, .binding = stmt_binding, .intent = try s.TableDmlIntent.stage(allocator, catalog.data_objects, dml_req) };
                _ = try catalog.admitTransactionStatement(tx_binding.key, ws_req, access.policy());
                _ = try catalog.executeTransactionStatement(tx_binding.key, ws_req, access.policy());
                const tx_state = try catalog.transactionTableState(tx_binding.key, stmt_binding.target, access.policy());
                tx_private_rows = tx_state.root.live_rows;
                resident_slot_unchanged = (catalog.options.table_owner.? == &retained) and (retained != null) and std.meta.eql(initial_retained_root, retained.?.table.root);
                var pub_view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
                defer pub_view.deinit();
                public_rows = pub_view.table.root.live_rows;
            },
            .EvictLoseReleaseReply, .ReconcileCacheTick => {
                var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
                defer view.deinit();
                const guard: P.Guard = .{ .context = &access, .acquire = Access.acquire, .release = Access.release };
                const owner_op: d.Operation = .{ .scope = scope, .principal = 1, .operation = 201 };
                const handle = try view.table.pin(owner_op, .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn }, guard);
                cache_advertised = false;
                view.table.lose_reply = true;
                view.table.releaseSnapshot(handle, guard) catch |err| switch (err) {
                    error.LostAcknowledgement => {},
                    else => return err,
                };
                view.table.lose_reply = false;
                try view.table.recover();
                try view.table.releaseSnapshot(handle, guard);
                const state = try view.table.pinState(owner_op, guard);
                pin_released = state.released;
            },
            .PinConflictAmbiguous => {
                var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
                defer view.deinit();
                const guard: P.Guard = .{ .context = &access, .acquire = Access.acquire, .release = Access.release };
                const owner_op: d.Operation = .{ .scope = scope, .principal = 1, .operation = 202 };
                const cut: d.Position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn };
                _ = try view.table.pin(owner_op, cut, guard);
                // Calling pin with the same owner at a mismatched expected cut returns Conflict
                // while pinState proves the original pin was accepted and remains active.
                if (view.table.pin(owner_op, .{ .partition = view.table.root.partition, .next_lsn = cut.next_lsn + 1 }, guard)) |_| {} else |err| {
                    last_error = try expectedError(err);
                }
                const state = try view.table.pinState(owner_op, guard);
                pin_accepted = (state.handle != null) and !state.released;
            },
        }
    }

    try std.json.Stringify.value(.{
        .resident_slot_unchanged = resident_slot_unchanged,
        .tx_private_rows = tx_private_rows,
        .public_rows = public_rows,
        .pin_released = pin_released,
        .cache_advertised = cache_advertised,
        .pin_accepted = pin_accepted,
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
        try replay(init.gpa, events, &output.interface);
    }
    try output.interface.flush();
}
