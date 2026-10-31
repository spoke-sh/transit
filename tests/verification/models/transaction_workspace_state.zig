//! Replay TransactionWorkspace.tla counterexample traces against the production
//! DirectCatalog, DirectTransaction, DirectTransactionWorkspace, and TableWorkspace.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const s = c.storage;
const a = c.TableAuthority;
const D = c.DirectCatalog;
const P = s.TablePartition;

const Event = enum {
    Init,
    Begin1,
    Begin2,
    PinSelected,
    AdvanceEpoch,
    AcquireCut,
    AdmitStmt1,
    AdmitStmt2,
    ExecuteStmt,
    Autocommit1,
    InspectWorkspace,
    TogglePolicy,
    CrashRecover,
};

const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .kv_domain = 33, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};

const Access = struct {
    calls: usize = 0,
    allowed: bool = true,
    epoch_change_at: usize = std.math.maxInt(usize),
    const Context = struct { access: *Access, requested: p.Authorization.Guard };

    fn erased(context: *anyopaque) *Access {
        return @ptrCast(@alignCast(context));
    }
    fn make(context: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .access = erased(context), .requested = requested };
        return .{ .context = result, .acquire = acquire, .release = release };
    }
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const value: *Context = @ptrCast(@alignCast(context));
        value.access.calls += 1;
        if (!value.access.allowed) return error.CatalogDenied;
        return .{ .writer_epoch = 1, .policy_epoch = if (value.access.calls >= value.access.epoch_change_at) 2 else 1 };
    }
    fn release(_: *anyopaque) void {}
    fn registered(_: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table => 100 + id,
            .stream, .queue, .kv => return null,
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
                .stream, .queue, .kv => return null,
            },
            .revision = 1,
        };
    }
    fn policy(self: *Access) D.Policy {
        return .{
            .context = self,
            .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } },
            .make_guard = make,
            .registered = registered,
        };
    }
};

fn configuration() !D.Configuration {
    return .{
        .scope = scope,
        .branch = 1,
        .partition = 1,
        .audience = 3,
        .authority = profile,
        .database_name = try a.Name.init("main"),
        .initial_schema_name = try a.Name.init("public"),
    };
}

fn initOwner(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !D {
    var options: D.Options = .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } };
    options.transaction_account_limits.count = 1;
    var catalog = try D.init(allocator, try configuration(), wal.log(), objects.objectStore(), wal.log(), objects.objectStore(), options);
    errdefer catalog.deinit();
    try catalog.recover();
    return catalog;
}

fn createTable(allocator: std.mem.Allocator, catalog: *D, access: *Access, object_id: u64, operation: u64, name: []const u8) !void {
    const schema: c.fuze.TableSchema.Schema = .{ .object = object_id, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
    const intent: D.Intent = .{ .namespace = 1, .name = try a.Name.init(name), .action = .{ .create = .{ .schema = schema, .owner = 0 } } };
    const req: D.Request = .{
        .binding = .{
            .definition = p.Growth.current_definition,
            .identity = .{ .scope = scope, .principal = 1, .operation = operation },
            .target = .{ .scope = scope, .branch = 1, .object = object_id },
            .action = .create,
            .expected_definition = null,
            .expected_data = null,
            .intent = try intent.digest(allocator),
        },
        .intent = intent,
    };
    _ = try catalog.admit(req, access.policy());
    _ = try catalog.perform(req.binding, access.policy());
    _ = try catalog.settle(req.binding, access.policy());
}

fn makeTxBinding(allocator: std.mem.Allocator, catalog: *D, access: *Access, operation: u64, token: u8) !c.DirectClientToken.Binding {
    const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const identity: p.Transaction.Identity = .{ .begin = .{ .scope = scope, .principal = 1, .operation = operation }, .branch = 1 };
    var selected = try s.TransactionDirectory.init(allocator, catalog.data_objects, identity, .participants, 100, 1, 1024 * 1024);
    defer selected.deinit();
    for ([_][]const u8{ "selected_0", "selected_1" }) |name| {
        var view = (try catalog.resolve(allocator, 1, try a.Name.init(name), access.policy())).?;
        defer view.deinit();
        const root = view.table.root;
        try selected.put(.{ .participant = .{ .state = .{
            .kind = .table,
            .access = .read,
            .guard = .{ .source = .{ .interpretation = root.interpretation, .accepted = .{ .partition = root.partition, .next_lsn = root.next_lsn } }, .changed_lsn = root.changed_lsn },
        } } });
    }
    const reference: c.DirectTransaction.Reference = .{
        .connection = connection,
        .namespace = 1,
        .begin = .{
            .definition = p.Growth.current_definition,
            .identity = identity,
            .mode = .serializable,
            .selection = .explicit_objects,
            .objects = try selected.seal(),
            .catalog = .{ .partition = 1, .next_lsn = catalog.store.root.next_lsn },
            .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 128 * 1024, .participants = 100, .statements = 100, .savepoints = 16 },
        },
    };
    return .{
        .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(token) },
        .fingerprint = @splat(token + 10),
        .intent = .{ .transaction = reference },
    };
}

fn makeStmtRequest(allocator: std.mem.Allocator, catalog: *D, access: *Access, key: c.DirectClientToken.Key, sequence: u64, operation: u64) !c.DirectTransactionWorkspace.Request {
    var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
    defer view.deinit();
    const object = view.table.root.interpretation.object;
    const binding: p.DataLifecycle.Binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = scope, .principal = 1, .operation = operation },
        .target = object,
        .action = .insert,
        .expected_definition = view.table.root.interpretation,
        .expected_data = null,
        .intent = @splat(@intCast(sequence + 2)),
    };
    const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = @intCast(operation) } } }};
    const request: s.TableDmlIntent.Request = .{
        .binding = binding,
        .interpretation = view.table.root.declared(),
        .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }},
        .ingestion = .bulk,
    };
    const state = try catalog.inspectTransaction(key, access.policy());
    return .{
        .basis = state.revision,
        .statement = .{ .transaction = state.begin.identity, .sequence = sequence, .intent = binding.intent },
        .binding = binding,
        .intent = try s.TableDmlIntent.stage(allocator, catalog.data_objects, request),
    };
}

fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.InvalidClientToken,
        error.TransactionAccountCapacity,
        error.TransactionAuthorityChanged,
        error.TransactionCutNotAcquired,
        error.TransactionStatementConflict,
        error.TransactionStatementPending,
        error.DataIdentityConflict,
        error.TransactionWorkspaceLimit,
        error.CatalogDenied,
        => @errorName(err),
        else => return err,
    };
}

fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var catalog = try initOwner(allocator, &wal, &objects);
    defer catalog.deinit();
    var access: Access = .{};
    try catalog.initialize(access.policy());
    try createTable(allocator, &catalog, &access, 10, 100, "selected_0");
    try createTable(allocator, &catalog, &access, 11, 101, "selected_1");

    var binding1: ?c.DirectClientToken.Binding = null;
    var receipt1: ?c.DirectClientToken.Receipt = null;
    var active_tx: usize = 0;
    var cut_acquired = false;
    var advance_epoch_on_cut = false;
    var last_error: []const u8 = "none";
    var disclosed: []const u8 = "none";
    var current_pending: ?c.DirectTransactionWorkspace.Request = null;

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init, .PinSelected => {},
            .Begin1 => {
                const b1 = try makeTxBinding(allocator, &catalog, &access, 900, 1);
                if (catalog.clientToken(.{ .bind = b1 }, access.policy())) |rec| {
                    binding1 = b1;
                    receipt1 = rec.?;
                    active_tx += 1;
                    var bad = rec.?;
                    bad.coordination = 1;
                    bad.validate() catch |err| {
                        last_error = try expectedError(err);
                    };
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .Begin2 => {
                const b2 = try makeTxBinding(allocator, &catalog, &access, 901, 2);
                if (catalog.clientToken(.{ .bind = b2 }, access.policy())) |_| {
                    active_tx += 1;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .AdvanceEpoch => {
                advance_epoch_on_cut = true;
            },
            .AcquireCut => {
                if (advance_epoch_on_cut) access.epoch_change_at = access.calls + 5;
                if (catalog.acquireTransaction(binding1.?.key, access.policy())) |_| {
                    cut_acquired = true;
                } else |err| {
                    last_error = try expectedError(err);
                }
                access.epoch_change_at = std.math.maxInt(usize);
            },
            .AdmitStmt1 => {
                const saved = access.allowed;
                access.allowed = true;
                const req = try makeStmtRequest(allocator, &catalog, &access, binding1.?.key, 1, 500);
                access.allowed = saved;
                if (catalog.admitTransactionStatement(binding1.?.key, req, access.policy())) |_| {
                    current_pending = req;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .AdmitStmt2 => {
                const saved = access.allowed;
                access.allowed = true;
                const req = try makeStmtRequest(allocator, &catalog, &access, binding1.?.key, 2, 501);
                access.allowed = saved;
                if (catalog.admitTransactionStatement(binding1.?.key, req, access.policy())) |_| {
                    current_pending = req;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .ExecuteStmt => {
                if (current_pending) |req| {
                    if (catalog.executeTransactionStatement(binding1.?.key, req, access.policy())) |_| {
                        current_pending = null;
                    } else |err| {
                        last_error = try expectedError(err);
                    }
                }
            },
            .Autocommit1 => {
                const saved = access.allowed;
                access.allowed = true;
                var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), access.policy())).?;
                defer view.deinit();
                access.allowed = saved;
                const binding: p.DataLifecycle.Binding = .{
                    .definition = p.Growth.current_definition,
                    .identity = .{ .scope = scope, .principal = 1, .operation = 500 },
                    .target = view.table.root.interpretation.object,
                    .action = .insert,
                    .expected_definition = view.table.root.interpretation,
                    .expected_data = null,
                    .intent = @splat(3),
                };
                const cells = [_]c.fuze.Types.Values.Cell{.{ .value = .{ .atom = .{ .signed = 500 } } }};
                const request: s.TableDmlIntent.Request = .{
                    .binding = binding,
                    .interpretation = view.table.root.declared(),
                    .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(binding.identity, 0), .cells = &cells }, .expect = .absent } }},
                    .ingestion = .point,
                };
                if (catalog.applyRows(request, access.policy())) |_| {} else |err| {
                    last_error = try expectedError(err);
                }
            },
            .InspectWorkspace => {
                const object: p.DataLifecycle.Object = .{ .scope = scope, .branch = 1, .object = 10 };
                if (catalog.transactionTableState(binding1.?.key, object, access.policy())) |_| {
                    disclosed = "ok";
                } else |err| {
                    last_error = try expectedError(err);
                    if (err == error.CatalogDenied) disclosed = "denied";
                }
            },
            .TogglePolicy => {
                access.allowed = !access.allowed;
            },
            .CrashRecover => {
                catalog.deinit();
                catalog = try initOwner(allocator, &wal, &objects);
                disclosed = "none";
            },
        }
    }

    var auditor: Access = .{};
    var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), auditor.policy())).?;
    defer view.deinit();
    const public_rows = view.table.root.live_rows;
    var private_rows: u64 = 0;
    var last_seq: u64 = 0;
    var pending_seq: u64 = 0;
    if (binding1) |b1| {
        if (cut_acquired) {
            const progress = (try catalog.clientProgress(.{ .inspect = b1.key }, auditor.policy())).state.?;
            const head = try c.DirectTransactionWorkspace.recover(allocator, catalog.data_objects, progress);
            last_seq = head.last_statement;
            pending_seq = if (head.pending) |req| req.statement.sequence else 0;
            const state = try catalog.transactionTableState(b1.key, view.table.root.interpretation.object, auditor.policy());
            private_rows = state.root.live_rows;
        }
    }

    try std.json.Stringify.value(.{
        .coordination = if (receipt1) |r| (r.coordination orelse 0) else 0,
        .active_tx = active_tx,
        .cut_acquired = cut_acquired,
        .last_seq = last_seq,
        .pending_seq = pending_seq,
        .private_rows = private_rows,
        .public_rows = public_rows,
        .disclosed = disclosed,
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
