//! Private bounded host composition over signed database calls. Native process
//! ownership remains the authority. Recovery never invokes a behavior body.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Actor = @import("Actor.zig");
const Turn = @import("Turn.zig");
const Envelope = @import("Envelope.zig");
const Wait = @import("Wait.zig");
const Timer = @import("Timer.zig");
const KV = c.DirectKVClient;
const Transaction = @import("transit_data_client").Transaction;
const Binary = c.DirectTableProtocol.Binary;
const Self = @This();

pub const resident_bytes = 64 * 1024 * 1024;
pub const Handler = struct {
    context: *anyopaque,
    run: *const fn (*anyopaque, *Turn) anyerror!void,
    failure: enum { block_input, stop } = .block_input,
};
pub const Result = enum { idle, committed, recovering, blocked };
pub const Point = enum { original, head, begin, claim, input, acquire, dispatch, draft, staged, executed, decision, cleared };
pub const Hook = struct { context: *anyopaque, hit: *const fn (*anyopaque, Point) anyerror!void };

parent: std.mem.Allocator,
memory: *c.fuze.MemoryBudget,
output: std.heap.ArenaAllocator,
scratch: std.heap.ArenaAllocator,
client: c.DirectTableClient,
observed_epoch: ?u64 = null,
actor: Actor.Declaration,
activation: p.Transaction.Execution,
digest: [32]u8,
hook: ?Hook = null,

pub fn init(parent: std.mem.Allocator, client: c.DirectTableClient, actor: Actor.Declaration, activation: p.Transaction.Execution) !Self {
    try actor.validate();
    try activation.validate();
    var connection = actor.connection;
    connection.principal = client.connection.principal;
    connection.role = client.connection.role;
    if (!std.meta.eql(connection, client.connection) or activation.realm != connection.scope.realm or activation.principal != connection.principal or
        activation.pid != actor.pid or activation.code != actor.code or !std.meta.eql(activation.workload, actor.workload) or activation.input != null or
        client.delegation != null or client.borrow != null or client.closure != null or client.transaction != null) return error.ActorIdentityConflict;
    const memory = try parent.create(c.fuze.MemoryBudget);
    errdefer parent.destroy(memory);
    memory.* = .{ .parent = parent, .limit = resident_bytes };
    var guarded = client;
    guarded.allocator = memory.allocator();
    guarded.execution = try c.DirectTableClient.Execution.init(activation);
    return .{ .parent = parent, .memory = memory, .output = .init(memory.allocator()), .scratch = .init(memory.allocator()), .client = guarded, .observed_epoch = client.credential_epoch, .actor = actor, .activation = activation, .digest = try actor.digest(parent) };
}
pub fn deinit(self: *Self) void {
    self.output.deinit();
    self.scratch.deinit();
    self.parent.destroy(self.memory);
    self.* = undefined;
}
fn tableClient(self: *Self) c.DirectTableClient {
    var caller = self.client;
    if (caller.credential_epoch == null) caller.observed_epoch = &self.observed_epoch;
    return caller;
}
fn point(self: *Self, value: Point) !void {
    if (self.hook) |hook| try hook.hit(hook.context, value);
}
fn reset(self: *Self) void {
    _ = self.output.reset(.retain_capacity);
    _ = self.scratch.reset(.retain_capacity);
}
fn op(self: *Self, turn: u64, label: []const u8, ordinal: u64) d.Operation {
    return Actor.operation(self.client.connection, self.digest, turn, label, ordinal);
}
fn applyKV(self: *Self, output: *std.heap.ArenaAllocator, action: KV.Action) !KV.Result {
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return KV.apply(output, self.tableClient(), action) catch |err| {
            if (err != error.AuthorityUnavailable) return err;
            last_err = err;
            continue;
        };
    }
    return last_err;
}
fn applyQueue(self: *Self, output: *std.heap.ArenaAllocator, action: c.DirectQueueClient.Action) !c.DirectQueueClient.Result {
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return c.DirectQueueClient.apply(output, self.tableClient(), action) catch |err| {
            if (err != error.AuthorityUnavailable) return err;
            last_err = err;
            continue;
        };
    }
    return last_err;
}
fn applyTx(self: *Self, tx: *Transaction, action: Transaction.Action) !Transaction.Result {
    var current = action;
    var last_err: anyerror = error.AuthorityUnavailable;
    for (0..4) |_| {
        return tx.apply(self.tableClient(), current) catch |err| {
            if (err != error.AuthorityUnavailable) return err;
            last_err = err;
            if (current == .begin) return err;
            if (tx.state.hasPendingWork() or tx.state.command != null) {
                current = .{ .advance = 64 };
            }
            continue;
        };
    }
    return last_err;
}
const Loaded = struct { head: Actor.Head, revision: ?c.fuze.TableRow.Identity };
fn load(self: *Self) !Loaded {
    const read = (try self.applyKV(&self.output, .{ .get = .{ .object = self.actor.control.object, .key = &Actor.key(self.actor.pid) } })).value;
    if (!std.meta.eql(read.interpretation.interpretation, self.actor.control) or !std.meta.eql(read.spec, Actor.spec)) return error.ActorIdentityConflict;
    const value = read.value orelse return .{ .head = Actor.Head.initial(self.digest), .revision = null };
    const bytes = try cellBytes(value);
    if (bytes.len > Actor.max_bytes) return error.TurnCapacity;
    const parsed = try p.Json.parseFromSliceOwned(Actor.Head, self.output.allocator(), bytes);
    try parsed.value.validate(self.actor, self.scratch.allocator());
    return .{ .head = parsed.value, .revision = read.revision orelse return error.ActorIdentityConflict };
}
fn save(self: *Self, loaded: *Loaded) !void {
    try loaded.head.validate(self.actor, self.scratch.allocator());
    const bytes = try p.Json.valueAllocBounded(self.scratch.allocator(), loaded.head, Actor.max_bytes);
    const commitment = try p.Json.hashBounded("transit.station.private.head.v1\x00", .{ .head = loaded.head, .revision = loaded.revision }, Actor.max_bytes + 4096);
    const identity = Actor.operation(self.client.connection, commitment, loaded.head.next_turn, "head", 0);
    const mutation = try KV.prepareMutation(&self.scratch, .{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .target = self.actor.control.object,
        .action = .insert,
        .expected_definition = self.actor.control,
        .expected_data = null,
        .intent = undefined,
    }, Actor.spec, &.{.{ .put = .{ .key = &Actor.key(self.actor.pid), .value = .{ .value = .{ .atom = .{ .bytes = bytes } } }, .expect = if (loaded.revision == null) .absent else .present, .expected_revision = loaded.revision } }});
    const receipt = (try self.applyKV(&self.output, .{ .mutate = mutation })).operation orelse return error.ActorProgressUnresolved;
    loaded.revision = try KV.singlePutRevision(mutation, receipt);
    _ = self.scratch.reset(.retain_capacity);
}

/// Explicit bootstrap retains the immutable declaration before publishing its
/// discoverable row. It registers dependencies without activating a worker.
pub fn bootstrap(self: *Self) !void {
    self.reset();
    const bytes = try p.Json.valueAllocBounded(self.scratch.allocator(), self.actor, 32 * 1024);
    const key = Actor.token(self.client.connection, self.digest, 0);
    var original = try c.DirectOwnedRecord.stage(self.tableClient(), key, self.actor.namespace, self.op(0, "actor", 0).operation, self.digest, .{ .bytes = 64 * 1024 }, Actor.original_format, bytes);
    if (original.original.?.phase != .retained)
        original = try c.DirectOwnedRecord.call(self.tableClient(), .{ .retain_original = .{ .key = key, .expected = original.revision } });
    if (original.original.?.phase != .retained) return error.ActorProgressUnresolved;
    try self.point(.original);
    var loaded = try self.load();
    if (loaded.revision == null) try self.save(&loaded);
    if (loaded.head.initialized) return;

    const Edge = struct { definition: d.Definition, privileges: u64 };
    var edges: [Actor.max_targets]Edge = undefined;
    var edge_count: usize = 5;
    edges[0] = .{ .definition = self.actor.state, .privileges = c.KVAuthority.read | c.KVAuthority.write };
    edges[1] = .{ .definition = self.actor.table, .privileges = c.TableAuthority.select | c.TableAuthority.insert | c.TableAuthority.update };
    edges[2] = .{ .definition = self.actor.inbox.interpretation, .privileges = c.LogAuthority.read | c.LogAuthority.acquire | c.LogAuthority.settle | (if (self.actor.protocol == .envelope) c.LogAuthority.append else 0) };
    edges[3] = .{ .definition = self.actor.journal.interpretation, .privileges = c.LogAuthority.append };
    edges[4] = .{ .definition = self.actor.outbox.interpretation, .privileges = c.LogAuthority.append };
    const mergeEdge = struct {
        fn add(list: *[Actor.max_targets]Edge, len: *usize, def: d.Definition, privs: u64) void {
            for (list[0..len.*]) |*existing| if (std.meta.eql(existing.definition.object, def.object)) {
                existing.privileges |= privs;
                return;
            };
            list[len.*] = .{ .definition = def, .privileges = privs };
            len.* += 1;
        }
    }.add;
    if (self.actor.timers) |tmr| mergeEdge(&edges, &edge_count, tmr.interpretation, c.LogAuthority.append);
    for (self.actor.mailboxes) |mailbox| mergeEdge(&edges, &edge_count, mailbox.interpretation, c.LogAuthority.append);

    for (edges[0..edge_count], 0..) |edge, i| {
        const response = try self.tableClient().call(.{ .dependency_operation = .{ .binding = .{
            .definition = p.Growth.current_definition,
            .connection = self.client.connection,
            .operation = self.op(0, "dependency", i).operation,
            .edge = .{ .source = edge.definition, .dependent = .{ .kind = .application, .interpretation = self.actor.control }, .privileges = edge.privileges },
            .action = .register,
            .authority = .dependent,
        }, .command = .accept } });
        defer response.deinit();
        const observed = response.value.result.dependency_operation;
        if (observed != .outcome or observed.outcome.phase != .applied) return error.ActorDependencyUnresolved;
    }
    loaded.head.initialized = true;
    try self.save(&loaded);
}

fn failHandler(self: *Self, loaded: *Loaded, handler: Handler) !Result {
    loaded.head.pending.?.failed = true;
    try self.save(loaded);
    if (handler.failure == .stop) return error.HandlerStopped;
    return self.recover(loaded);
}

/// One bounded turn or one bounded recovery page. Host cancellation is simply
/// stopping calls: it makes no assertion that accepted work has been rolled back.
pub fn advance(self: *Self, handler: Handler) !Result {
    self.reset();
    var loaded = try self.load();
    if (!loaded.head.initialized or loaded.revision == null) return error.ActorNotInitialized;
    if (loaded.head.pending != null) return self.recover(&loaded);
    if (loaded.head.claim_release != null) _ = try self.finishClaimRelease(&loaded);
    if (loaded.head.blocked or loaded.head.retired) return .blocked;
    const turn = loaded.head.next_turn;
    var target_buf: [Actor.max_targets]p.Transaction.Target = undefined;
    const targets = try self.output.allocator().dupe(p.Transaction.Target, self.actor.targetsInto(&target_buf));
    var execution = self.activation;
    execution.input = if (loaded.head.held_input) |held| held.claim.claim else .{
        .target = self.actor.inbox,
        .operation = self.op(turn, "claim", 0),
        .maximum = 1,
        .lease_ms = self.actor.lease_ms,
        .predicate = self.actor.predicate,
    };
    loaded.head.next_turn = try std.math.add(u64, turn, 1);
    loaded.head.pending = .{
        .begin = .{ .key = Actor.token(self.client.connection, self.digest, turn), .fingerprint = try p.Json.hashBounded("transit.station.private.turn.v1\x00", .{ .actor = self.digest, .turn = turn, .execution = execution }, 32 * 1024), .operation = self.op(turn, "begin", 0), .namespace = self.actor.namespace, .mode = .serializable, .selection = .{ .explicit_objects = targets }, .limits = self.actor.transaction, .deadline = null, .execution = execution, .budget = .{ .bytes = 1024 * 1024 } },
        .commit = self.op(turn, "commit", 0),
        .phase = .beginning,
        .claim = null,
        .source = null,
        .execution_origin = null,
        .lease = null,
        .input = null,
        .draft = null,
        .next_statement = 0,
        .statement = null,
        .batch = null,
        .failed = false,
    };
    var journal: Journal = .{ .runner = self, .loaded = &loaded };
    var tx = try journal.transaction();
    defer tx.deinit();
    _ = tx.apply(self.tableClient(), .begin) catch |err| retry_begin: {
        if (err != error.AuthorityUnavailable) return err;
        var last_err: anyerror = err;
        for (0..4) |_| {
            _ = (c.DirectTransactionClient{ .catalog = self.tableClient() }).begin(tx.state.begin) catch |retry_err| {
                if (retry_err != error.AuthorityUnavailable) return retry_err;
                last_err = retry_err;
                continue;
            };
            break :retry_begin;
        }
        return last_err;
    };
    try self.point(.begin);

    if (loaded.head.held_input) |held| {
        try self.point(.claim);
        loaded.head.pending.?.claim = held.claim;
        const page = (try self.applyQueue(&self.output, .{ .page = .{ .cursor = .{ .receipt = held.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = @intCast(self.actor.limits.bytes) } } })).page;
        if (page.rows.len != 1 or !page.cursor.complete() or page.rows[0].lease.liveness != .live) {
            // Held lease expired before conflict retry began; release retry state and re-claim cleanly.
            loaded.head.held_input = null;
            loaded.head.conflict_retries = 0;
            loaded.head.pending.?.phase = .reading;
            try self.save(&loaded);
            return self.recover(&loaded);
        }
        loaded.head.pending.?.source = held.source;
        loaded.head.pending.?.execution_origin = held.execution_origin;
        loaded.head.pending.?.lease = held.lease;
        loaded.head.pending.?.input = held.input;
    } else {
        const claim = (try self.applyQueue(&self.output, .{ .mutate = .{ .work = .{ .claim = execution.input.? } } })).operation orelse return error.ActorProgressUnresolved;
        if (claim != .claim) return error.ActorIdentityConflict;
        try self.point(.claim);
        loaded.head.pending.?.claim = claim.claim;
        if (claim.claim.rows == 0) {
            loaded.head.pending.?.phase = .reading;
            try self.save(&loaded);
            return self.recover(&loaded);
        }
        const input = (try self.applyQueue(&self.output, .{ .page = .{ .cursor = .{ .receipt = claim.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = @intCast(self.actor.limits.bytes) } } })).page;
        if (input.rows.len != 1 or !input.cursor.complete() or input.rows[0].lease.liveness != .live) return error.ActorInputUnavailable;
        const row = input.rows[0];
        if (row.value.cells.len != 2 or try cellActor(row.value.cells[0]) != self.actor.pid) return error.ActorIdentityConflict;
        loaded.head.pending.?.source = .{ .target = self.actor.inbox, .operation = row.operation, .ordinal = row.ordinal };
        loaded.head.pending.?.execution_origin = row.execution;
        loaded.head.pending.?.lease = row.lease.original;
        loaded.head.pending.?.input = try Binary.encode(self.output.allocator(), try cellBytes(row.value.cells[1]));
    }
    loaded.head.pending.?.phase = .acquiring;
    try self.save(&loaded);
    try self.point(.input);
    _ = try self.applyTx(&tx, .acquire);
    try self.point(.acquire);
    loaded.head.pending.?.phase = .dispatched;
    try self.point(.dispatch);

    var reader: Reader = .{ .runner = self, .transaction = &tx, .loaded = &loaded };
    defer reader.deinit();
    const raw_input = try loaded.head.pending.?.input.?.decode(self.output.allocator(), self.actor.limits.bytes);
    var body = blk: {
        if (self.actor.protocol == .raw_cast) {
            break :blk try Turn.init(self.output.allocator(), self.actor.limits, .{ .context = &reader, .get = Reader.get, .row = Reader.row, .table = Reader.table }, loaded.head.pending.?.source.?, raw_input);
        }
        const env = Envelope.decode(raw_input) catch return self.failHandler(&loaded, handler);
        const orig = env.verifyOrigin(loaded.head.pending.?.source.?.operation, loaded.head.pending.?.execution_origin) catch return self.failHandler(&loaded, handler);
        break :blk try Turn.initWithContext(
            self.output.allocator(),
            self.actor.limits,
            .{ .context = &reader, .get = Reader.get, .row = Reader.row, .table = Reader.table },
            loaded.head.pending.?.source.?,
            env.payload,
            .{
                .turn_id = turn,
                .actor_pid = self.actor.pid,
                .inbox = self.actor.inbox,
                .mailboxes = self.actor.mailboxes,
                .timers = self.actor.timers,
                .envelope = env,
                .origin = orig,
            },
        );
    };

    const run_handler = self.preprocessTurn(turn, &body) catch |err| {
        if (err == error.TransactionConflict and reader.conflict_detected) {
            reader.deinit();
            return self.abortConflict(&loaded, &tx);
        }
        return self.failHandler(&loaded, handler);
    };
    if (run_handler) {
        handler.run(handler.context, &body) catch |err| {
            if (err == error.TransactionConflict and reader.conflict_detected) {
                reader.deinit();
                return self.abortConflict(&loaded, &tx);
            }
            return self.failHandler(&loaded, handler);
        };
    }
    const draft = body.finish() catch return self.failHandler(&loaded, handler);
    reader.deinit();
    loaded.head.pending.?.draft = draft;
    loaded.head.pending.?.phase = .staging;
    try self.save(&loaded);
    try self.point(.draft);
    switch (try self.publish(&loaded, &tx)) {
        .provisional => {},
        .conflict => return self.abortConflict(&loaded, &tx),
    }
    const status = (try self.applyTx(&tx, .{ .settle = .{ .command = .commit, .steps = 64 } })).status;
    try self.point(.decision);
    if (!status.cleanup_complete) return .recovering;
    return self.finish(&loaded, status, true);
}

fn abortConflict(self: *Self, loaded: *Loaded, tx: *Transaction) !Result {
    const status = (try self.applyTx(tx, .{ .settle = .{ .command = .abort, .steps = 64 } })).status;
    try self.point(.decision);
    if (!status.cleanup_complete) return .recovering;
    return self.finish(loaded, status, true);
}

fn preprocessTurn(self: *Self, turn: u64, body: *Turn) !bool {
    if (self.actor.protocol == .raw_cast) return true;
    const env = body.context.envelope.?;
    const orig = body.context.origin.?;
    switch (env.kind) {
        .cast, .call, .cancel => return true,
        .reply => {
            var wait = (try body.waiting(env.correlation)) orelse return error.UnknownCorrelation;
            if (orig != .actor or orig.actor.pid != wait.target_pid) return error.UnexpectedReplySource;
            if (wait.phase != .waiting) {
                try body.putFramework(Wait.disposition_key, Wait.closed_reply_disposition);
                try body.journal("closed-reply");
                return false;
            }
            wait.phase = .replied;
            wait.resolution_turn = turn;
            const wait_key = Wait.key(env.correlation);
            try body.putFramework(&wait_key, try wait.encodeAlloc(body.allocator));
            return true;
        },
        .timeout => {
            const obs = try Timer.Observation.decode(env.payload);
            var wait = (try body.waiting(env.correlation)) orelse return error.UnknownCorrelation;
            if (wait.observer == null or wait.deadline_ms == null or orig != .observer or
                orig.observer != wait.observer.? or obs.observed_ms < wait.deadline_ms.?)
                return error.UnexpectedTimeoutSource;
            if (wait.phase != .waiting) {
                try body.putFramework(Wait.disposition_key, Wait.closed_timeout_disposition);
                try body.journal("closed-timeout");
                return false;
            }
            wait.phase = .timed_out;
            wait.resolution_turn = turn;
            const wait_key = Wait.key(env.correlation);
            try body.putFramework(&wait_key, try wait.encodeAlloc(body.allocator));
            return true;
        },
    }
}

const Reader = struct {
    runner: *Self,
    transaction: *Transaction,
    loaded: *Loaded,
    cached_table: ?struct { reader: Transaction.Read.TableReader, statement_basis: u64 } = null,
    conflict_detected: bool = false,
    fn deinit(self: *@This()) void {
        if (self.cached_table) |*cached| {
            cached.reader.deinit();
            self.cached_table = null;
        }
    }
    fn get(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        const read = (self.transaction.read(runner.tableClient(), &runner.output, .{ .kv = .{ .object = runner.actor.state.object, .key = key, .expected = runner.actor.state } }) catch |err| {
            if (err == error.TransactionConflict) self.conflict_detected = true;
            return err;
        }).kv;
        if (read.workspace == null or !std.meta.eql(read.interpretation.interpretation, runner.actor.state)) return error.ActorIdentityConflict;
        return if (read.value) |value| try allocator.dupe(u8, try cellBytes(value)) else null;
    }
    fn table(raw: *anyopaque, statement: Turn.Table) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.deinit();
        const runner = self.runner;
        const client = try self.transaction.privateClient(runner.tableClient());
        var prepared = try c.DirectTablePreparedDml.prepare(runner.memory.allocator(), client, runner.actor.namespace, statement.sql, .transit, null);
        defer prepared.deinit();
        var work = try prepared.bind(runner.memory.allocator(), client, runner.op(self.loaded.head.next_turn - 1, "statement", self.loaded.head.pending.?.next_statement).operation, statement.parameters, .bulk, null);
        defer work.deinit();
        if (!std.meta.eql(work.parsed.value.work.binding().target, runner.actor.table.object) or !std.meta.eql(work.parsed.value.work.binding().expected_definition, @as(?d.Definition, runner.actor.table))) return error.ActorIdentityConflict;
        const result = try self.transaction.apply(runner.tableClient(), .{ .write = .{ .table = work.parsed.value.work } });
        if (result == .checkpoint_failed) return result.checkpoint_failed.cause;
        switch (result.statement) {
            .state => |value| switch (value.outcome) {
                .provisional => {},
                .rejected => |rejected| {
                    if (rejected.reason == .data_changed) {
                        self.conflict_detected = true;
                        return error.TransactionConflict;
                    }
                    return error.ActorStatementRefused;
                },
            },
            .log => |value| switch (value.outcome) {
                .provisional => {},
                .rejected => |rejected| {
                    if (rejected.reason == .conflict) {
                        self.conflict_detected = true;
                        return error.TransactionConflict;
                    }
                    return error.ActorStatementRefused;
                },
            },
        }
    }
    fn row(raw: *anyopaque, keys: []const c.fuze.Types.Values.Cell) !?Turn.Row {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        const current_basis = self.transaction.state.last_statement;
        if (self.cached_table == null or self.cached_table.?.statement_basis != current_basis) {
            self.deinit();
            const opened = (self.transaction.read(runner.tableClient(), &runner.output, .{ .open_table = .{
                .allocator = runner.memory.allocator(),
                .table = .{ .namespace = runner.actor.namespace, .name = runner.actor.table_name, .expected = runner.actor.table },
            } }) catch |err| {
                if (err == error.TransactionConflict) self.conflict_detected = true;
                return err;
            }).opened;
            self.cached_table = .{ .reader = opened, .statement_basis = current_basis };
        }
        const table_reader = &self.cached_table.?.reader;
        const schema = table_reader.native.reader.schema.schema;
        const result = (self.transaction.read(runner.tableClient(), &runner.output, .{ .table = .{ .reader = table_reader, .command = .{ .key = keys } } }) catch |err| {
            if (err == error.TransactionConflict) self.conflict_detected = true;
            return err;
        }).row orelse return null;
        const scratch_buf = try runner.scratch.allocator().alloc(u8, runner.actor.limits.bytes);
        defer _ = runner.scratch.reset(.retain_capacity);
        const bytes = try result.row().encode(schema, scratch_buf);
        return .{ .cells = result.row().cells, .encoded_bytes = bytes.len };
    }
};
// Station owns only the actor checkpoint representation and fault hooks. The
// shared database API owns sequencing, saved requests and transaction control.
const Journal = struct {
    runner: *Self,
    loaded: *Loaded,
    fn transaction(self: *@This()) !Transaction {
        const pending = self.loaded.head.pending.?;
        return Transaction.borrowed(.{
            .begin = pending.begin,
            .settlement = pending.commit,
            .last_statement = pending.next_statement,
            .statement = pending.statement,
            .batch = pending.batch,
            .command = switch (pending.phase) {
                .committing => .commit,
                .aborting => .abort,
                else => null,
            },
        }, .{ .context = self, .save = Journal.save });
    }
    fn save(raw: *anyopaque, previous: Transaction.State, state: Transaction.State, event: Transaction.Event) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const pending = self.loaded.head.pending.?;
        if (pending.next_statement != previous.last_statement or !std.meta.eql(pending.statement, previous.statement) or !std.meta.eql(pending.batch, previous.batch))
            return error.ActorProgressConflict;
        switch (event) {
            .original => {},
            .statement, .batch => self.loaded.head.pending.?.phase = .executing,
            .statement_complete, .batch_complete => {
                try self.runner.point(.executed);
                self.loaded.head.pending.?.phase = .staging;
            },
            .settlement => self.loaded.head.pending.?.phase = if (state.command == .abort) .aborting else .committing,
            .control, .control_complete => return error.ActorSavepointUnsupported,
        }
        self.loaded.head.pending.?.next_statement = std.math.cast(u16, state.last_statement) orelse return error.TurnCapacity;
        self.loaded.head.pending.?.statement = state.statement;
        self.loaded.head.pending.?.batch = state.batch;
        try self.runner.save(self.loaded);
        if (event == .original) try self.runner.point(.head);
        if (event == .statement or event == .batch) try self.runner.point(.staged);
    }
};
fn isOptimisticConflict(rejected: c.DirectTransactionRequest.BatchRejection) bool {
    return switch (rejected.reason) {
        .log => |reason| reason == .conflict,
        .state => |reason| reason == .data_changed,
    };
}
const PublishOutcome = enum { provisional, conflict };
fn publish(self: *Self, loaded: *Loaded, tx: *Transaction) !PublishOutcome {
    const pending = loaded.head.pending.?;
    const draft = pending.draft.?;
    const turn = loaded.head.next_turn - 1;
    const total = draft.puts.len + 1 + draft.outputs.len + draft.messages.len + 1;
    const writes = try self.output.allocator().alloc(Transaction.Write, total);
    var ordinal: u64 = pending.next_statement;
    var count: usize = 0;
    for (draft.puts) |put| {
        const identity = self.op(turn, "statement", ordinal);
        ordinal += 1;
        const decoded_key = try put.key.decode(self.output.allocator(), c.storage.KVPartition.max_key_bytes);
        const change: c.storage.KVPartition.Change = if (put.value) |val|
            .{ .put = .{ .key = decoded_key, .value = .{ .value = .{ .atom = .{ .bytes = try val.decode(self.output.allocator(), self.actor.limits.bytes) } } }, .expect = .any } }
        else
            .{ .remove = decoded_key };
        const changes = [_]c.storage.KVPartition.Change{change};
        const mutation = try KV.prepareMutation(&self.output, .{ .definition = p.Growth.current_definition, .identity = identity, .target = self.actor.state.object, .action = .insert, .expected_definition = self.actor.state, .expected_data = null, .intent = undefined }, Actor.spec, &changes);
        writes[count] = .{ .kv = mutation };
        count += 1;
    }
    const journal = try p.Json.valueAllocBounded(self.output.allocator(), .{ .definition = self.digest, .transaction = pending.begin.operation, .input = pending.source.?, .body = draft.journal }, 96 * 1024);
    writes[count] = try self.prepareAppend(turn, ordinal, self.actor.journal, .stream, self.actor.pid, 0, journal);
    ordinal += 1;
    count += 1;
    for (draft.outputs) |output| {
        writes[count] = try self.prepareAppend(turn, ordinal, self.actor.outbox, .queue, self.actor.pid, 0, try output.decode(self.output.allocator(), self.actor.limits.bytes));
        ordinal += 1;
        count += 1;
    }
    for (draft.messages) |message| {
        writes[count] = try self.prepareAppend(turn, ordinal, message.target, .queue, message.pid, message.visible_ms, try message.body.decode(self.output.allocator(), self.actor.limits.bytes));
        ordinal += 1;
        count += 1;
    }
    writes[count] = .{ .log = .{ .work = .{ .queue_ack = .{ .operation = self.op(turn, "statement", ordinal), .lease = pending.lease.?, .action = .ack } } } };
    count += 1;
    std.debug.assert(count == total);
    var offset: usize = 0;
    while (offset < writes.len) {
        const end = @min(offset + c.DirectTransactionRequest.max_batch, writes.len);
        const result = try self.applyTx(tx, .{ .write_batch = writes[offset..end] });
        if (result == .checkpoint_failed) return result.checkpoint_failed.cause;
        if (result.batch.rejection) |rejected| {
            if (isOptimisticConflict(rejected)) return .conflict;
            return error.ActorStatementRefused;
        }
        if (result.batch.provisional_count != end - offset) return error.ActorStatementRefused;
        offset = end;
    }
    return .provisional;
}
fn prepareAppend(self: *Self, turn: u64, ordinal: u64, target: p.StreamQueue.Partition, kind: p.StreamQueueDeclaration.Kind, pid: u64, visible_ms: u64, bytes: []const u8) !Transaction.Write {
    const identity = self.op(turn, "statement", ordinal);
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(pid) } } }, .{ .value = .{ .atom = .{ .bytes = bytes } } } };
    const buffer = try self.scratch.allocator().alloc(u8, 256 * 1024);
    defer _ = self.scratch.reset(.retain_capacity);
    const payload = try c.storage.LogBatch.encode(logSchema(target.interpretation.object.object), identity, kind, &.{.{ .cells = &cells, .visible_ms = visible_ms }}, buffer);
    return .{ .log = .{
        .work = .{ .append = .{ .target = target, .operation = identity, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } },
        .payload = try Binary.encode(self.output.allocator(), payload),
    } };
}
fn recover(self: *Self, loaded: *Loaded) !Result {
    const pending = loaded.head.pending.?;
    var journal: Journal = .{ .runner = self, .loaded = loaded };
    var tx = try journal.transaction();
    defer tx.deinit();
    const observed = (try self.applyTx(&tx, .{ .recover = .{ .steps = 64, .close_input = true } })).recovered;
    if (observed) |recovery| {
        if (!recovery.status.cleanup_complete) return .recovering;
        return self.finish(loaded, recovery.status, false);
    }
    // Absence is not cancellation while this activation could still publish a
    // delayed BEGIN. A new native generation fences every old request first.
    const original = pending.begin.execution.?;
    if (original.principal == self.activation.principal and original.generation == self.activation.generation) return .recovering;
    const should_block = pending.failed or pending.source != null;
    loaded.head.blocked = should_block;
    if (should_block) {
        loaded.head.failure = loaded.head.next_turn - 1;
        loaded.head.blocked_generation = original.generation;
    }
    loaded.head.held_input = null;
    loaded.head.pending = null;
    try self.save(loaded);
    return if (loaded.head.blocked) .blocked else .idle;
}
fn finish(self: *Self, loaded: *Loaded, status: c.DirectTransactionControl.Status, allow_conflict_retry: bool) !Result {
    if (!status.cleanup_complete or status.observation != .decided) return error.ActorProgressUnresolved;
    const committed = status.observation.decided.outcome == .committed;
    const pending = loaded.head.pending.?;
    if (committed and (pending.source == null or pending.draft == null)) return error.ActorIdentityConflict;
    if (committed) {
        loaded.head.completed += 1;
        loaded.head.conflict_retries = 0;
        loaded.head.held_input = null;
        loaded.head.pending = null;
        try self.save(loaded);
        try self.point(.cleared);
        return .committed;
    }
    if (allow_conflict_retry and !pending.failed and pending.claim != null and
        loaded.head.conflict_retries < self.actor.max_conflict_retries)
    {
        const claim_turn = if (loaded.head.held_input) |held| held.claim_turn else (loaded.head.next_turn - 1);
        loaded.head.held_input = .{
            .claim_turn = claim_turn,
            .claim = pending.claim.?,
            .source = pending.source.?,
            .execution_origin = pending.execution_origin,
            .lease = pending.lease.?,
            .input = pending.input.?,
        };
        loaded.head.conflict_retries += 1;
        loaded.head.pending = null;
        try self.save(loaded);
        try self.point(.cleared);
        return .recovering;
    }
    const should_block = pending.failed or pending.source != null;
    loaded.head.blocked = should_block;
    if (should_block) {
        loaded.head.failure = loaded.head.next_turn - 1;
        loaded.head.blocked_generation = self.activation.generation;
    }
    loaded.head.held_input = null;
    loaded.head.pending = null;
    try self.save(loaded);
    try self.point(.cleared);
    return if (loaded.head.blocked) .blocked else .idle;
}
/// Explicitly close a settled turn's inbox claim payload-read dependency after
/// any post-turn payload inspection has finished. Persists the release identity
/// before Queue dispatch so uncertain replies resume without inventing an ID.
pub fn releaseClaimRead(self: *Self, turn: u64, claim: p.StreamQueue.ClaimReceipt) !p.QueueRead.ReleaseReceipt {
    self.reset();
    if (turn == 0) return error.InvalidQueueReadRelease;
    var loaded = try self.load();
    if (loaded.head.pending != null or loaded.head.retired or turn >= loaded.head.next_turn) return error.ActorProgressUnresolved;
    const release: p.QueueRead.Release = .{
        .operation = self.op(turn, "claim-release", 0),
        .claim = claim,
    };
    try release.validate();
    if (!std.meta.eql(claim.claim.target, self.actor.inbox)) return error.ActorIdentityConflict;
    if (loaded.head.claim_release) |saved| {
        if (!std.meta.eql(saved, release)) return error.ActorProgressConflict;
    } else {
        loaded.head.claim_release = release;
        try self.save(&loaded);
    }
    return self.finishClaimRelease(&loaded);
}
fn finishClaimRelease(self: *Self, loaded: *Loaded) !p.QueueRead.ReleaseReceipt {
    const release = loaded.head.claim_release orelse return error.ActorProgressUnresolved;
    const caller = self.tableClient();
    const observed = (try c.DirectQueueClient.apply(&self.output, caller, .{ .operation = .{ .release = release } })).operation;
    const receipt = if (observed) |known| known else ((try c.DirectQueueClient.apply(&self.output, caller, .{ .mutate = .{ .work = .{ .release = release } } })).operation orelse return error.ActorProgressUnresolved);
    if (receipt != .release) return error.ActorProgressConflict;
    try receipt.release.requireRelease(release);
    loaded.head.claim_release = null;
    try self.save(loaded);
    return receipt.release;
}
/// Attach a pre-claimed shared-inbox message from a multiplexed Pool slot.
/// Refuses without mutating actor state if the actor is pending, blocked, retired
/// or already holding a retry input.
pub fn acceptPoolInput(self: *Self, claim: p.StreamQueue.ClaimReceipt, row: c.DirectQueueClient.Row) !bool {
    self.reset();
    var loaded = try self.load();
    if (!loaded.head.initialized or loaded.revision == null) return error.ActorNotInitialized;
    while (loaded.head.pending != null) {
        const rec = try self.recover(&loaded);
        if (rec == .recovering) return false;
    }
    if (loaded.head.claim_release != null) _ = try self.finishClaimRelease(&loaded);
    if (loaded.head.blocked or loaded.head.retired or loaded.head.held_input != null) return false;
    if (!std.meta.eql(claim.claim.target, self.actor.inbox) or claim.claim.maximum != 1 or
        claim.claim.operation.principal != self.activation.principal) return error.ActorIdentityConflict;
    if (row.value.cells.len != 2 or try cellActor(row.value.cells[0]) != self.actor.pid) return error.ActorIdentityConflict;
    loaded.head.held_input = .{
        .claim_turn = loaded.head.next_turn,
        .claim = claim,
        .source = .{ .target = self.actor.inbox, .operation = row.operation, .ordinal = row.ordinal },
        .execution_origin = row.execution,
        .lease = row.lease.original,
        .input = try Binary.encode(self.output.allocator(), try cellBytes(row.value.cells[1])),
    };
    loaded.head.conflict_retries = 0;
    try self.save(&loaded);
    return true;
}
/// Explicit retry is a separate authorized decision after original settlement.
pub fn retryBlocked(self: *Self) !void {
    self.reset();
    var loaded = try self.load();
    if (loaded.head.pending != null or loaded.head.retired) return error.ActorProgressUnresolved;
    loaded.head.blocked = false;
    loaded.head.failure = 0;
    loaded.head.blocked_generation = 0;
    loaded.head.conflict_retries = 0;
    try self.save(&loaded);
}
pub fn inspect(self: *Self) !Actor.Head {
    self.reset();
    return (try self.load()).head;
}
const log_columns = [_]c.fuze.TableSchema.Column{
    .{ .id = 1, .name = "actor", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "body", .type = .binary, .nullable = false },
};
pub fn logSchema(object: u64) c.fuze.TableSchema.Schema {
    return .{ .object = object, .revision = 1, .next_column = 3, .columns = &log_columns, .primary_key = &.{} };
}
fn cellBytes(value: c.fuze.Types.Values.Cell) ![]const u8 {
    if (value != .value or value.value != .atom or value.value.atom != .bytes) return error.ActorIdentityConflict;
    return value.value.atom.bytes;
}
fn cellActor(value: c.fuze.Types.Values.Cell) !u64 {
    if (value != .value or value.value != .atom or value.value.atom != .signed or value.value.atom.signed <= 0) return error.ActorIdentityConflict;
    return @intCast(value.value.atom.signed);
}

test "private transactional runner declarations compile" {
    std.testing.refAllDecls(Self);
}
