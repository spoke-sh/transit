//! Private bounded host composition over signed database calls. Native process
//! ownership remains the authority. Recovery never invokes a behavior body.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const d = p.DataLifecycle;
const Actor = @import("Actor.zig");
const Turn = @import("Turn.zig");
const KV = c.DirectKVClient;
const Tx = c.DirectTransactionClient;
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
    return .{ .parent = parent, .memory = memory, .output = .init(memory.allocator()), .scratch = .init(memory.allocator()), .client = guarded, .actor = actor, .activation = activation, .digest = try actor.digest(parent) };
}
pub fn deinit(self: *Self) void {
    self.output.deinit();
    self.scratch.deinit();
    self.parent.destroy(self.memory);
    self.* = undefined;
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
    const read = (try KV.apply(&self.output, self.client, .{ .get = .{ .object = self.actor.control.object, .key = &Actor.key(self.actor.pid) } })).value;
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
    _ = (try KV.apply(&self.output, self.client, .{ .mutate = mutation })).operation orelse return error.ActorProgressUnresolved;
    const observed = try self.load();
    const expected = try p.Json.hashBounded("transit.station.private.head.value.v1\x00", loaded.head, Actor.max_bytes);
    const actual = try p.Json.hashBounded("transit.station.private.head.value.v1\x00", observed.head, Actor.max_bytes);
    if (!std.mem.eql(u8, &expected, &actual)) return error.ActorProgressConflict;
    loaded.* = observed;
    _ = self.scratch.reset(.retain_capacity);
}

/// Explicit bootstrap retains the immutable declaration before publishing its
/// discoverable row. It registers dependencies without activating a worker.
pub fn bootstrap(self: *Self) !void {
    self.reset();
    const bytes = try p.Json.valueAllocBounded(self.scratch.allocator(), self.actor, 32 * 1024);
    const key = Actor.token(self.client.connection, self.digest, 0);
    var original = try c.DirectOwnedRecord.stage(self.client, key, self.actor.namespace, self.op(0, "actor", 0).operation, self.digest, .{ .bytes = 64 * 1024 }, Actor.original_format, bytes);
    if (original.original.?.phase != .retained)
        original = try c.DirectOwnedRecord.call(self.client, .{ .retain_original = .{ .key = key, .expected = original.revision } });
    if (original.original.?.phase != .retained) return error.ActorProgressUnresolved;
    try self.point(.original);
    var loaded = try self.load();
    if (loaded.revision == null) try self.save(&loaded);
    if (loaded.head.initialized) return;
    const definitions = [_]d.Definition{ self.actor.state, self.actor.table, self.actor.inbox.interpretation, self.actor.journal.interpretation, self.actor.outbox.interpretation };
    const rights = [_]u64{ c.KVAuthority.read | c.KVAuthority.write, c.TableAuthority.select | c.TableAuthority.insert | c.TableAuthority.update, c.LogAuthority.read | c.LogAuthority.acquire | c.LogAuthority.settle, c.LogAuthority.append, c.LogAuthority.append };
    for (definitions, rights, 0..) |definition, privileges, i| {
        const response = try self.client.call(.{ .dependency_operation = .{ .binding = .{
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
        .failed = false,
    };
    try self.save(&loaded);
    try self.point(.head);
    const tx: Tx = .{ .catalog = self.client };
    _ = try tx.begin(loaded.head.pending.?.begin);
    try self.point(.begin);
    const claim = (try c.DirectQueueClient.apply(&self.output, self.client, .{ .mutate = .{ .work = .{ .claim = execution.input.? } } })).operation orelse return error.ActorProgressUnresolved;
    if (claim != .claim) return error.ActorIdentityConflict;
    try self.point(.claim);
    loaded.head.pending.?.claim = claim.claim;
    loaded.head.pending.?.phase = .reading;
    try self.save(&loaded);
    if (claim.claim.rows == 0) return self.recover(&loaded);
    const input = (try c.DirectQueueClient.apply(&self.output, self.client, .{ .page = .{ .cursor = .{ .receipt = claim.claim, .next = 0 }, .limits = .{ .rows = 1, .encoded_bytes = @intCast(self.actor.limits.bytes) } } })).page;
    if (input.rows.len != 1 or !input.cursor.complete() or input.rows[0].lease.liveness != .live) return error.ActorInputUnavailable;
    const row = input.rows[0];
    if (row.value.cells.len != 2 or try cellActor(row.value.cells[0]) != self.actor.pid) return error.ActorIdentityConflict;
    loaded.head.pending.?.source = .{ .target = self.actor.inbox, .operation = row.operation, .ordinal = row.ordinal };
    loaded.head.pending.?.lease = row.lease.original;
    loaded.head.pending.?.input = try Binary.encode(self.output.allocator(), try cellBytes(row.value.cells[1]));
    loaded.head.pending.?.phase = .acquiring;
    try self.save(&loaded);
    try self.point(.input);
    const key = loaded.head.pending.?.begin.key;
    _ = try tx.acquire(key);
    try self.point(.acquire);
    loaded.head.pending.?.phase = .dispatched;
    try self.save(&loaded);
    try self.point(.dispatch);
    var reader: Reader = .{ .runner = self, .key = key, .loaded = &loaded };
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
    loaded.head.pending.?.draft = draft;
    loaded.head.pending.?.phase = .staging;
    try self.save(&loaded);
    try self.point(.draft);
    try self.publish(&loaded);
    const status = try tx.settle(key, loaded.head.pending.?.commit, .commit, 8);
    try self.point(.decision);
    if (!status.cleanup_complete) return .recovering;
    return self.finish(&loaded, status);
}

const Reader = struct {
    runner: *Self,
    key: c.DirectClientToken.Key,
    loaded: *Loaded,
    fn get(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        var client = runner.client;
        client.transaction = .{ .key = self.key, .revision = (try (Tx{ .catalog = client }).inspect(self.key)).revision };
        const read = (try KV.apply(&runner.output, client, .{ .get = .{ .object = runner.actor.state.object, .key = key } })).value;
        if (read.workspace == null or !std.meta.eql(read.interpretation.interpretation, runner.actor.state)) return error.ActorIdentityConflict;
        return if (read.value) |value| try allocator.dupe(u8, try cellBytes(value)) else null;
    }
    fn table(raw: *anyopaque, statement: Turn.Table) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        const tx: Tx = .{ .catalog = runner.client };
        var client = runner.client;
        client.transaction = .{ .key = self.key, .revision = (try tx.inspect(self.key)).revision };
        var prepared = try c.DirectTablePreparedDml.prepare(runner.memory.allocator(), client, runner.actor.namespace, statement.sql, .transit, null);
        defer prepared.deinit();
        var work = try prepared.bind(runner.memory.allocator(), client, runner.op(self.loaded.head.next_turn - 1, "statement", self.loaded.head.pending.?.next_statement).operation, statement.parameters, .bulk, null);
        defer work.deinit();
        if (!std.meta.eql(work.parsed.value.work.binding().target, runner.actor.table.object) or !std.meta.eql(work.parsed.value.work.binding().expected_definition, @as(?d.Definition, runner.actor.table))) return error.ActorIdentityConflict;
        try runner.execute(self.loaded, .{ .state = try tx.stage(self.key, (try tx.inspect(self.key)).revision, self.loaded.head.pending.?.next_statement + 1, work.parsed.value.work) });
    }
    fn row(raw: *anyopaque, keys: []const c.fuze.Types.Values.Cell) !?Turn.Row {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const runner = self.runner;
        var client = runner.client;
        client.transaction = .{ .key = self.key, .revision = (try (Tx{ .catalog = client }).inspect(self.key)).revision };
        const lookup = try client.call(.{ .lookup = .{ .namespace = runner.actor.namespace, .name = runner.actor.table_name.slice() } });
        defer lookup.deinit();
        const metadata = lookup.value.result.lookup orelse return error.ActorIdentityConflict;
        if (!std.meta.eql(metadata.interpretation.interpretation, runner.actor.table)) return error.ActorIdentityConflict;
        const pinned = try client.call(.{ .pin = .{ .object = runner.actor.table.object, .owner = self.loaded.head.pending.?.begin.operation, .expected = metadata.position, .interpretation = runner.actor.table } });
        defer pinned.deinit();
        var reader = try c.DirectTableReader.open(runner.memory.allocator(), client, .{ .object = runner.actor.table.object, .handle = pinned.value.result.pin });
        defer reader.deinit();
        if (reader.basis.workspace == null) return error.ActorIdentityConflict;
        const schema = reader.schema.schema;
        if (keys.len != schema.primary_key.len or keys.len == 0) return error.InvalidTableKey;
        var cells: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = @splat(.null);
        for (schema.primary_key, keys) |column, cell| cells[try schema.index(column)] = cell;
        var key_buffer: [c.fuze.Collation.max_sort_key_bytes]u8 = undefined;
        const key = try c.fuze.Collation.encodePrimaryKeySortKey(schema, cells[0..schema.columns.len], true, &key_buffer);
        var result = try reader.readKey(client, key) orelse return null;
        defer result.deinit();
        const buffer = try runner.output.allocator().alloc(u8, runner.actor.limits.bytes);
        const bytes = try result.row().encode(schema, buffer);
        const owned = try c.fuze.TableRow.decodeInto(runner.output.allocator(), schema, bytes);
        return .{ .cells = owned.row().cells, .encoded_bytes = bytes.len };
    }
};
fn execute(self: *Self, loaded: *Loaded, work: c.DirectTransactionWorkspace.StatementWork) !void {
    loaded.head.pending.?.statement = work;
    loaded.head.pending.?.phase = .executing;
    try self.save(loaded);
    try self.point(.staged);
    const tx: Tx = .{ .catalog = self.client };
    const key = loaded.head.pending.?.begin.key;
    switch (work) {
        .state => |request| if ((try tx.execute(key, request)) != .provisional) return error.ActorStatementRefused,
        .log => |request| if ((try tx.executeLog(key, request)) != .provisional) return error.ActorStatementRefused,
    }
    try self.point(.executed);
    loaded.head.pending.?.next_statement += 1;
    loaded.head.pending.?.statement = null;
    loaded.head.pending.?.phase = .staging;
    try self.save(loaded);
}
fn publish(self: *Self, loaded: *Loaded) !void {
    const pending = loaded.head.pending.?;
    const draft = pending.draft.?;
    const key = pending.begin.key;
    const turn = loaded.head.next_turn - 1;
    const tx: Tx = .{ .catalog = self.client };
    for (draft.puts) |put| {
        const identity = self.op(turn, "statement", loaded.head.pending.?.next_statement);
        const changes = [_]c.storage.KVPartition.Change{.{ .put = .{ .key = try put.key.decode(self.output.allocator(), c.storage.KVPartition.max_key_bytes), .value = .{ .value = .{ .atom = .{ .bytes = try put.value.decode(self.output.allocator(), self.actor.limits.bytes) } } }, .expect = .any } }};
        const mutation = try KV.prepareMutation(&self.output, .{ .definition = p.Growth.current_definition, .identity = identity, .target = self.actor.state.object, .action = .insert, .expected_definition = self.actor.state, .expected_data = null, .intent = undefined }, Actor.spec, &changes);
        const work = try tx.stageKV(key, (try tx.inspect(key)).revision, loaded.head.pending.?.next_statement + 1, mutation);
        try self.execute(loaded, .{ .state = work });
    }
    const journal = try p.Json.valueAllocBounded(self.output.allocator(), .{ .definition = self.digest, .transaction = pending.begin.operation, .input = pending.source.?, .body = draft.journal }, 96 * 1024);
    try self.append(loaded, self.actor.journal, .stream, journal);
    for (draft.outputs) |output| try self.append(loaded, self.actor.outbox, .queue, try output.decode(self.output.allocator(), self.actor.limits.bytes));
    const work = try tx.stageLog(key, (try tx.inspect(key)).revision, loaded.head.pending.?.next_statement + 1, .{ .queue_ack = .{ .operation = self.op(turn, "statement", loaded.head.pending.?.next_statement), .lease = pending.lease.?, .action = .ack } }, null);
    try self.execute(loaded, .{ .log = work });
    loaded.head.pending.?.phase = .committing;
    try self.save(loaded);
}
fn append(self: *Self, loaded: *Loaded, target: p.StreamQueue.Partition, kind: p.StreamQueueDeclaration.Kind, bytes: []const u8) !void {
    const key = loaded.head.pending.?.begin.key;
    const identity = self.op(loaded.head.next_turn - 1, "statement", loaded.head.pending.?.next_statement);
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = @intCast(self.actor.pid) } } }, .{ .value = .{ .atom = .{ .bytes = bytes } } } };
    const buffer = try self.output.allocator().alloc(u8, 256 * 1024);
    const payload = try c.storage.LogBatch.encode(logSchema(target.interpretation.object.object), identity, kind, &.{.{ .cells = &cells }}, buffer);
    const tx: Tx = .{ .catalog = self.client };
    const work = try tx.stageLog(key, (try tx.inspect(key)).revision, loaded.head.pending.?.next_statement + 1, .{ .append = .{ .target = target, .operation = identity, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload) } }, try Binary.encode(self.output.allocator(), payload));
    try self.execute(loaded, .{ .log = work });
}
fn recover(self: *Self, loaded: *Loaded) !Result {
    const pending = loaded.head.pending.?;
    const observed = try (Tx{ .catalog = self.client }).recover(.{ .key = pending.begin.key, .execution = pending.begin.execution.?, .work = .{ .settle = .{ .operation = pending.commit, .steps = 8 } }, .close_input = true });
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
