//! Private bounded host composition over signed database calls. Native process
//! ownership remains the authority. Recovery never invokes a behavior body.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Actor = @import("Actor.zig");
const Turn = @import("Turn.zig");
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
const Loaded = struct { head: Actor.Head, revision: ?c.fuze.TableRow.Identity };
fn load(self: *Self) !Loaded {
    const read = (try KV.apply(&self.output, self.tableClient(), .{ .get = .{ .object = self.actor.control.object, .key = &Actor.key(self.actor.pid) } })).value;
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
    const receipt = (try KV.apply(&self.output, self.tableClient(), .{ .mutate = mutation })).operation orelse return error.ActorProgressUnresolved;
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
    const definitions = [_]d.Definition{ self.actor.state, self.actor.table, self.actor.inbox.interpretation, self.actor.journal.interpretation, self.actor.outbox.interpretation };
    const rights = [_]u64{ c.KVAuthority.read | c.KVAuthority.write, c.TableAuthority.select | c.TableAuthority.insert | c.TableAuthority.update, c.LogAuthority.read | c.LogAuthority.acquire | c.LogAuthority.settle, c.LogAuthority.append, c.LogAuthority.append };
    for (definitions, rights, 0..) |definition, privileges, i| {
        const response = try self.tableClient().call(.{ .dependency_operation = .{ .binding = .{
            .definition = p.Growth.current_definition,
            .connection = self.client.connection,
            .operation = self.op(0, "dependency", i).operation,
            .edge = .{ .source = definition, .dependent = .{ .kind = .application, .interpretation = self.actor.control }, .privileges = privileges },
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
    const targets = try self.output.allocator().dupe(p.Transaction.Target, &self.actor.targets());
    var execution = self.activation;
    execution.input = .{ .target = self.actor.inbox, .operation = self.op(turn, "claim", 0), .maximum = 1, .lease_ms = self.actor.lease_ms, .predicate = self.actor.predicate };
    loaded.head.next_turn = try std.math.add(u64, turn, 1);
    loaded.head.pending = .{
        .begin = .{ .key = Actor.token(self.client.connection, self.digest, turn), .fingerprint = try p.Json.hashBounded("transit.station.private.turn.v1\x00", .{ .actor = self.digest, .turn = turn, .execution = execution }, 32 * 1024), .operation = self.op(turn, "begin", 0), .namespace = self.actor.namespace, .mode = .serializable, .selection = .{ .explicit_objects = targets }, .limits = self.actor.transaction, .deadline = null, .execution = execution, .budget = .{ .bytes = 1024 * 1024 } },
        .commit = self.op(turn, "commit", 0),
        .phase = .beginning,
        .claim = null,
        .source = null,
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
    _ = try tx.apply(self.tableClient(), .begin);
    try self.point(.begin);
    const claim = (try c.DirectQueueClient.apply(&self.output, self.tableClient(), .{ .mutate = .{ .work = .{ .claim = execution.input.? } } })).operation orelse return error.ActorProgressUnresolved;
    if (claim != .claim) return error.ActorIdentityConflict;
    try self.point(.claim);
    loaded.head.pending.?.claim = claim.claim;
    if (claim.claim.rows == 0) {
        loaded.head.pending.?.phase = .reading;
        try self.save(&loaded);
        return self.recover(&loaded);
    }
    const input = (try c.DirectQueueClient.apply(&self.output, self.tableClient(), .{ .page = .{ .cursor = .{ .receipt = claim.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = @intCast(self.actor.limits.bytes) } } })).page;
    if (input.rows.len != 1 or !input.cursor.complete() or input.rows[0].lease.liveness != .live) return error.ActorInputUnavailable;
    const row = input.rows[0];
    if (row.value.cells.len != 2 or try cellActor(row.value.cells[0]) != self.actor.pid) return error.ActorIdentityConflict;
    loaded.head.pending.?.source = .{ .target = self.actor.inbox, .operation = row.operation, .ordinal = row.ordinal };
    loaded.head.pending.?.lease = row.lease.original;
    loaded.head.pending.?.input = try Binary.encode(self.output.allocator(), try cellBytes(row.value.cells[1]));
    loaded.head.pending.?.phase = .acquiring;
    try self.save(&loaded);
    try self.point(.input);
    _ = try tx.apply(self.tableClient(), .acquire);
    try self.point(.acquire);
    loaded.head.pending.?.phase = .dispatched;
    try self.point(.dispatch);
    var reader: Reader = .{ .runner = self, .transaction = &tx, .loaded = &loaded };
    defer reader.deinit();
    var body = try Turn.init(self.output.allocator(), self.actor.limits, .{ .context = &reader, .get = Reader.get, .row = Reader.row, .table = Reader.table }, loaded.head.pending.?.source.?, try loaded.head.pending.?.input.?.decode(self.output.allocator(), self.actor.limits.bytes));
    handler.run(handler.context, &body) catch {
        loaded.head.pending.?.failed = true;
        try self.save(&loaded);
        if (handler.failure == .stop) return error.HandlerStopped;
        return self.recover(&loaded);
    };
    const draft = body.finish() catch {
        loaded.head.pending.?.failed = true;
        try self.save(&loaded);
        if (handler.failure == .stop) return error.HandlerStopped;
        return self.recover(&loaded);
    };
    reader.deinit();
    loaded.head.pending.?.draft = draft;
    loaded.head.pending.?.phase = .staging;
    try self.save(&loaded);
    try self.point(.draft);
    try self.publish(&loaded, &tx);
    const status = (try tx.apply(self.tableClient(), .{ .settle = .{ .command = .commit } })).status;
    try self.point(.decision);
    if (!status.cleanup_complete) return .recovering;
    return self.finish(&loaded, status);
}

const Reader = struct {
    runner: *Self,
    transaction: *Transaction,
    loaded: *Loaded,
    cached_table: ?struct { reader: Transaction.Read.TableReader, statement_basis: u64 } = null,
    fn deinit(self: *@This()) void {
        if (self.cached_table) |*cached| {
            cached.reader.deinit();
            self.cached_table = null;
        }
    }
    fn get(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        const read = (try self.transaction.read(runner.tableClient(), &runner.output, .{ .kv = .{ .object = runner.actor.state.object, .key = key, .expected = runner.actor.state } })).kv;
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
        try requireStatement(try self.transaction.apply(runner.tableClient(), .{ .write = .{ .table = work.parsed.value.work } }));
    }
    fn row(raw: *anyopaque, keys: []const c.fuze.Types.Values.Cell) !?Turn.Row {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        const current_basis = self.transaction.state.last_statement;
        if (self.cached_table == null or self.cached_table.?.statement_basis != current_basis) {
            self.deinit();
            const opened = (try self.transaction.read(runner.tableClient(), &runner.output, .{ .open_table = .{
                .allocator = runner.memory.allocator(),
                .table = .{ .namespace = runner.actor.namespace, .name = runner.actor.table_name, .expected = runner.actor.table },
            } })).opened;
            self.cached_table = .{ .reader = opened, .statement_basis = current_basis };
        }
        const table_reader = &self.cached_table.?.reader;
        const schema = table_reader.native.reader.schema.schema;
        const result = (try self.transaction.read(runner.tableClient(), &runner.output, .{ .table = .{ .reader = table_reader, .command = .{ .key = keys } } })).row orelse return null;
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
            .command = if (pending.phase == .committing) .commit else null,
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
            .settlement => self.loaded.head.pending.?.phase = .committing,
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
fn requireStatement(result: Transaction.Result) !void {
    if (result == .checkpoint_failed) return result.checkpoint_failed.cause;
    switch (result.statement) {
        inline else => |value| if (value.outcome != .provisional) return error.ActorStatementRefused,
    }
}
fn requireBatch(result: Transaction.Result, expected: usize) !void {
    if (result == .checkpoint_failed) return result.checkpoint_failed.cause;
    if (result.batch.rejection != null or result.batch.provisional_count != expected) return error.ActorStatementRefused;
}
fn publish(self: *Self, loaded: *Loaded, tx: *Transaction) !void {
    const pending = loaded.head.pending.?;
    const draft = pending.draft.?;
    const turn = loaded.head.next_turn - 1;
    const total = draft.puts.len + 1 + draft.outputs.len + 1;
    const writes = try self.output.allocator().alloc(Transaction.Write, total);
    var ordinal: u64 = pending.next_statement;
    var count: usize = 0;
    for (draft.puts) |put| {
        const identity = self.op(turn, "statement", ordinal);
        ordinal += 1;
        const changes = [_]c.storage.KVPartition.Change{.{ .put = .{ .key = try put.key.decode(self.output.allocator(), c.storage.KVPartition.max_key_bytes), .value = .{ .value = .{ .atom = .{ .bytes = try put.value.decode(self.output.allocator(), self.actor.limits.bytes) } } }, .expect = .any } }};
        const mutation = try KV.prepareMutation(&self.output, .{ .definition = p.Growth.current_definition, .identity = identity, .target = self.actor.state.object, .action = .insert, .expected_definition = self.actor.state, .expected_data = null, .intent = undefined }, Actor.spec, &changes);
        writes[count] = .{ .kv = mutation };
        count += 1;
    }
    const journal = try p.Json.valueAllocBounded(self.output.allocator(), .{ .definition = self.digest, .transaction = pending.begin.operation, .input = pending.source.?, .body = draft.journal }, 96 * 1024);
    writes[count] = try self.prepareAppend(turn, ordinal, self.actor.journal, .stream, journal);
    ordinal += 1;
    count += 1;
    for (draft.outputs) |output| {
        writes[count] = try self.prepareAppend(turn, ordinal, self.actor.outbox, .queue, try output.decode(self.output.allocator(), self.actor.limits.bytes));
        ordinal += 1;
        count += 1;
    }
    writes[count] = .{ .log = .{ .work = .{ .queue_ack = .{ .operation = self.op(turn, "statement", ordinal), .lease = pending.lease.?, .action = .ack } } } };
    count += 1;
    std.debug.assert(count == total);
    var offset: usize = 0;
    while (offset < writes.len) {
        const end = @min(offset + c.DirectTransactionRequest.max_batch, writes.len);
        try requireBatch(try tx.apply(self.tableClient(), .{ .write_batch = writes[offset..end] }), end - offset);
        offset = end;
    }
}
fn prepareAppend(self: *Self, turn: u64, ordinal: u64, target: p.StreamQueue.Partition, kind: p.StreamQueueDeclaration.Kind, bytes: []const u8) !Transaction.Write {
    const identity = self.op(turn, "statement", ordinal);
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(self.actor.pid) } } }, .{ .value = .{ .atom = .{ .bytes = bytes } } } };
    const buffer = try self.scratch.allocator().alloc(u8, 256 * 1024);
    defer _ = self.scratch.reset(.retain_capacity);
    const payload = try c.storage.LogBatch.encode(logSchema(target.interpretation.object.object), identity, kind, &.{.{ .cells = &cells }}, buffer);
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
    const observed = (try tx.apply(self.tableClient(), .{ .recover = .{ .close_input = true } })).recovered;
    if (observed) |recovery| {
        if (!recovery.status.cleanup_complete) return .recovering;
        return self.finish(loaded, recovery.status);
    }
    // Absence is not cancellation while this activation could still publish a
    // delayed BEGIN. A new native generation fences every old request first.
    const original = pending.begin.execution.?;
    if (original.principal == self.activation.principal and original.generation == self.activation.generation) return .recovering;
    loaded.head.blocked = pending.failed or pending.source != null;
    loaded.head.pending = null;
    try self.save(loaded);
    return if (loaded.head.blocked) .blocked else .idle;
}
fn finish(self: *Self, loaded: *Loaded, status: c.DirectTransactionControl.Status) !Result {
    if (!status.cleanup_complete or status.observation != .decided) return error.ActorProgressUnresolved;
    const committed = status.observation.decided.outcome == .committed;
    const pending = loaded.head.pending.?;
    if (committed and (pending.source == null or pending.draft == null)) return error.ActorIdentityConflict;
    loaded.head.blocked = !committed and (pending.failed or pending.source != null);
    if (committed) loaded.head.completed += 1;
    loaded.head.pending = null;
    try self.save(loaded);
    try self.point(.cleared);
    return if (committed) .committed else if (loaded.head.blocked) .blocked else .idle;
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
/// Explicit retry is a separate authorized decision after original settlement.
pub fn retryBlocked(self: *Self) !void {
    self.reset();
    var loaded = try self.load();
    if (loaded.head.pending != null or loaded.head.retired) return error.ActorProgressUnresolved;
    loaded.head.blocked = false;
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
