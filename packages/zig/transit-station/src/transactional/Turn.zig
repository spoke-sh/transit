//! Private detached behavior interface. The host supplies one bounded private
//! read capability; the body cannot submit, settle or sign database work.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Envelope = @import("Envelope.zig");
const Wait = @import("Wait.zig");
const Timer = @import("Timer.zig");
const Self = @This();

pub const Limits = struct {
    bytes: usize = 64 * 1024,
    reads: u16 = 16,
    writes: u16 = 16,
    outputs: u16 = 4,

    pub fn validate(self: Limits) !void {
        if (self.bytes == 0 or self.bytes > 64 * 1024 or self.reads == 0 or self.reads > 16 or
            self.writes == 0 or self.writes > 16 or self.outputs > 4) return error.InvalidTurnLimits;
    }
};
pub const Binary = c.DirectTableProtocol.Binary;
pub const Put = struct { key: Binary, value: ?Binary };
pub const Table = struct { sql: []const u8, parameters: []const ?c.fuze.Types.Values.Atom };
pub const TargetedOutput = struct {
    target: p.StreamQueue.Partition,
    pid: u64,
    body: Binary,
    visible_ms: u64 = 0,
};
pub const Draft = struct {
    pub const json_schema_sequence_bounds = .{ .puts = 16, .tables = 16, .outputs = 4, .messages = 8 };
    puts: []const Put,
    tables: []const []const u8,
    outputs: []const Binary,
    messages: []const TargetedOutput = &.{},
    journal: Binary,
};
pub const Row = struct { cells: []const c.fuze.Types.Values.Cell, encoded_bytes: usize };
pub const Read = struct {
    context: *anyopaque,
    get: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!?[]const u8,
    row: ?*const fn (*anyopaque, []const c.fuze.Types.Values.Cell) anyerror!?Row = null,
    table: ?*const fn (*anyopaque, Table) anyerror!void = null,
};
pub const Context = struct {
    turn_id: u64 = 1,
    actor_pid: u64 = 0,
    inbox: ?p.StreamQueue.Partition = null,
    mailboxes: []const p.StreamQueue.Partition = &.{},
    timers: ?p.StreamQueue.Partition = null,
    envelope: ?Envelope = null,
    origin: ?Envelope.Origin = null,
};

allocator: std.mem.Allocator,
limits: Limits,
reader: Read,
source: p.StreamQueue.RecordIdentity,
input: []const u8,
context: Context = .{},
puts: std.ArrayList(Put) = .empty,
tables: std.ArrayList([]const u8) = .empty,
outputs: std.ArrayList(Binary) = .empty,
messages: std.ArrayList(TargetedOutput) = .empty,
journal_bytes: Binary = .{ .base64 = "" },
bytes: usize = 0,
reads: u16 = 0,
calls_issued: u16 = 0,
poisoned: bool = false,

pub fn init(allocator: std.mem.Allocator, limits: Limits, reader: Read, source: p.StreamQueue.RecordIdentity, input: []const u8) !Self {
    return initWithContext(allocator, limits, reader, source, input, .{});
}

pub fn initWithContext(allocator: std.mem.Allocator, limits: Limits, reader: Read, source: p.StreamQueue.RecordIdentity, input: []const u8, context: Context) !Self {
    try limits.validate();
    try source.validate();
    if (context.turn_id == 0) return error.InvalidTurnContext;
    if (context.envelope) |env| try env.validate();
    if (context.origin) |orig| try orig.validate();
    if (input.len > limits.bytes) return error.TurnCapacity;
    return .{
        .allocator = allocator,
        .limits = limits,
        .reader = reader,
        .source = source,
        .input = input,
        .context = context,
        .bytes = input.len,
    };
}

fn own(self: *Self, bytes: []const u8) ![]const u8 {
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    const copy = try self.allocator.dupe(u8, bytes);
    self.bytes += bytes.len;
    return copy;
}

fn binary(self: *Self, bytes: []const u8) !Binary {
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    const result = try Binary.encode(self.allocator, bytes);
    self.bytes += bytes.len;
    return result;
}

fn checkUserKey(key: []const u8) !void {
    if (key.len == 0 or key.len > c.storage.KVPartition.max_key_bytes) return error.TurnCapacity;
    if (key[0] == 0) return error.ReservedFrameworkKey;
}

pub fn get(self: *Self, key: []const u8) !?[]const u8 {
    errdefer self.poisoned = true;
    try checkUserKey(key);
    return self.getInternal(key);
}

pub fn getFramework(self: *Self, key: []const u8) !?[]const u8 {
    errdefer self.poisoned = true;
    if (key.len == 0 or key.len > c.storage.KVPartition.max_key_bytes) return error.TurnCapacity;
    return self.getInternal(key);
}

fn getInternal(self: *Self, key: []const u8) !?[]const u8 {
    if (self.poisoned) return error.PoisonedTurn;
    if (self.reads == self.limits.reads) return error.TurnCapacity;
    self.reads += 1;
    var at = self.puts.items.len;
    while (at != 0) {
        at -= 1;
        var key_buffer: [c.storage.KVPartition.max_key_bytes]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&key_buffer);
        if (std.mem.eql(u8, try self.puts.items[at].key.decode(scratch.allocator(), key_buffer.len), key)) {
            const val = self.puts.items[at].value orelse return null;
            const bytes = try val.decode(self.allocator, self.limits.bytes - self.bytes);
            self.bytes += bytes.len;
            return bytes;
        }
    }
    const bytes = try self.reader.get(self.reader.context, self.allocator, key) orelse return null;
    if (bytes.len > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += bytes.len;
    return bytes;
}

/// Typed primary-key values address the one immutable declared Table.
pub fn readTable(self: *Self, key: []const c.fuze.Types.Values.Cell) !?[]const c.fuze.Types.Values.Cell {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.reads == self.limits.reads) return error.TurnCapacity;
    self.reads += 1;
    const read = self.reader.row orelse return error.UnsupportedTableRead;
    const row = try read(self.reader.context, key) orelse return null;
    if (row.encoded_bytes > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += row.encoded_bytes;
    return row.cells;
}

pub fn put(self: *Self, key: []const u8, value: []const u8) !void {
    errdefer self.poisoned = true;
    try checkUserKey(key);
    try self.writeInternal(key, value);
}

pub fn delete(self: *Self, key: []const u8) !void {
    errdefer self.poisoned = true;
    try checkUserKey(key);
    try self.writeInternal(key, null);
}

pub fn putFramework(self: *Self, key: []const u8, value: []const u8) !void {
    errdefer self.poisoned = true;
    if (key.len == 0 or key.len > c.storage.KVPartition.max_key_bytes or key[0] != 0) return error.InvalidFrameworkKey;
    try self.writeInternal(key, value);
}

fn writeInternal(self: *Self, key: []const u8, value: ?[]const u8) !void {
    if (self.poisoned) return error.PoisonedTurn;
    if (self.puts.items.len + self.tables.items.len >= self.limits.writes) return error.TurnCapacity;
    const encoded_val = if (value) |bytes| try self.binary(bytes) else null;
    try self.puts.append(self.allocator, .{ .key = try self.binary(key), .value = encoded_val });
}

pub fn table(self: *Self, sql: []const u8, parameters: []const ?c.fuze.Types.Values.Atom) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.puts.items.len + self.tables.items.len >= self.limits.writes) return error.TurnCapacity;
    const Atom = c.fuze.Types.Values.Atom;
    const fixed = try std.math.mul(usize, parameters.len, @sizeOf(?Atom));
    if (fixed > self.limits.bytes - self.bytes) return error.TurnCapacity;
    self.bytes += fixed;
    const owned = try self.allocator.alloc(?Atom, parameters.len);
    for (parameters, owned) |parameter, *copy| {
        copy.* = if (parameter) |atom| blk: {
            const extra: usize = if (atom == .bytes) atom.bytes.len else if (atom == .capability) 32 else 0;
            if (extra > self.limits.bytes - self.bytes) return error.TurnCapacity;
            self.bytes += extra;
            break :blk try c.fuze.Types.Values.cloneAtom(self.allocator, atom);
        } else null;
    }
    const text = try self.own(sql);
    try self.tables.append(self.allocator, text);
    const stage = self.reader.table orelse return error.UnsupportedTableWrite;
    try stage(self.reader.context, .{ .sql = text, .parameters = owned });
}

pub fn emit(self: *Self, bytes: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (self.outputs.items.len >= self.limits.outputs) return error.TurnCapacity;
    try self.outputs.append(self.allocator, try self.binary(bytes));
}

fn canDeliver(self: *const Self, target: p.StreamQueue.Partition) bool {
    if (self.context.inbox) |inbox| if (std.meta.eql(target, inbox)) return true;
    for (self.context.mailboxes) |mailbox| if (std.meta.eql(target, mailbox)) return true;
    return false;
}

pub fn sendEnvelope(self: *Self, target: p.StreamQueue.Partition, destination_pid: u64, env: Envelope) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (destination_pid == 0 or destination_pid > p.max_counter) return error.InvalidDestination;
    if (!self.canDeliver(target)) return error.UndeclaredMailboxTarget;
    if (self.outputs.items.len + self.messages.items.len >= @as(usize, self.limits.outputs) * 2) return error.TurnCapacity;
    const raw = try env.encodeAlloc(self.allocator);
    try self.messages.append(self.allocator, .{ .target = target, .pid = destination_pid, .body = try self.binary(raw), .visible_ms = 0 });
}

pub fn cast(self: *Self, target: p.StreamQueue.Partition, destination_pid: u64, payload: []const u8) !void {
    try self.sendEnvelope(target, destination_pid, .{ .kind = .cast, .correlation = 0, .payload = payload });
}

pub fn call(self: *Self, target: p.StreamQueue.Partition, destination_pid: u64, payload: []const u8) !u64 {
    return self.callWithTimer(target, destination_pid, payload, null, null);
}

pub fn callWithTimer(self: *Self, target: p.StreamQueue.Partition, destination_pid: u64, payload: []const u8, deadline_ms: ?u64, observer: ?u64) !u64 {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    if (destination_pid == 0 or destination_pid > p.max_counter) return error.InvalidDestination;
    if (!self.canDeliver(target)) return error.UndeclaredMailboxTarget;
    if ((deadline_ms == null) != (observer == null)) return error.InvalidTimerObserver;
    if (deadline_ms) |d_ms| if (d_ms == 0) return error.InvalidDeadline;
    if (observer) |obs| if (obs == 0 or obs > p.max_counter) return error.InvalidTimerObserver;
    if (deadline_ms != null and (self.context.timers == null or self.context.inbox == null or self.context.actor_pid == 0))
        return error.TimerQueueRequired;

    const correlation = try Wait.correlationFor(self.context.turn_id, self.calls_issued);
    const wait_key = Wait.key(correlation);
    if (try self.getFramework(&wait_key) != null) return error.CorrelationAlreadyUsed;

    const wait_record: Wait.Record = .{
        .definition = p.Growth.current_definition,
        .phase = .waiting,
        .target_pid = destination_pid,
        .target_inbox = target,
        .deadline_ms = deadline_ms,
        .observer = observer,
        .created_turn = self.context.turn_id,
    };
    const encoded_wait = try wait_record.encodeAlloc(self.allocator);
    try self.putFramework(&wait_key, encoded_wait);
    try self.sendEnvelope(target, destination_pid, .{ .kind = .call, .correlation = correlation, .payload = payload });

    if (deadline_ms) |d_ms| {
        const ticket: Timer.Ticket = .{
            .definition = p.Growth.current_definition,
            .kind = .wait_timeout,
            .target_pid = self.context.actor_pid,
            .target_inbox = self.context.inbox.?,
            .correlation = correlation,
            .deadline_ms = d_ms,
            .observer = observer.?,
        };
        const raw_ticket = try ticket.encodeAlloc(self.allocator);
        try self.messages.append(self.allocator, .{
            .target = self.context.timers.?,
            .pid = observer.?,
            .body = try self.binary(raw_ticket),
            .visible_ms = d_ms,
        });
    }
    self.calls_issued += 1;
    return correlation;
}

pub fn reply(self: *Self, return_inbox: p.StreamQueue.Partition, payload: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    const req = self.context.envelope orelse return error.ExpectedCall;
    if (req.kind != .call) return error.ExpectedCall;
    const orig = self.context.origin orelse return error.UnauthenticatedActorOrigin;
    if (orig != .actor) return error.UnauthenticatedActorOrigin;
    try self.sendEnvelope(return_inbox, orig.actor.pid, .{ .kind = .reply, .correlation = req.correlation, .payload = payload });
}

pub fn waiting(self: *Self, correlation: u64) !?Wait.Record {
    errdefer self.poisoned = true;
    const wait_key = Wait.key(correlation);
    const bytes = (try self.getFramework(&wait_key)) orelse return null;
    return try Wait.Record.decode(self.allocator, bytes);
}

pub fn cancelWait(self: *Self, correlation: u64) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    var wait = (try self.waiting(correlation)) orelse return error.UnknownCorrelation;
    if (wait.phase != .waiting) return error.WaitAlreadyClosed;
    wait.phase = .cancelled;
    wait.resolution_turn = self.context.turn_id;
    const wait_key = Wait.key(correlation);
    const encoded_wait = try wait.encodeAlloc(self.allocator);
    try self.putFramework(&wait_key, encoded_wait);
    try self.sendEnvelope(wait.target_inbox, wait.target_pid, .{ .kind = .cancel, .correlation = correlation, .payload = &.{} });
}

pub fn scheduleSupervisorBackoff(self: *Self, child_pid: u64, generation: u64, failure: u64, retry_at_ms: u64, observer: u64) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    const timers = self.context.timers orelse return error.TimerQueueRequired;
    const inbox = self.context.inbox orelse return error.TimerQueueRequired;
    if (self.context.actor_pid == 0) return error.TimerQueueRequired;
    const ticket: Timer.Ticket = .{
        .definition = p.Growth.current_definition,
        .kind = .supervisor_backoff,
        .target_pid = self.context.actor_pid,
        .target_inbox = inbox,
        .correlation = 0,
        .child_pid = child_pid,
        .generation = generation,
        .failure = failure,
        .deadline_ms = retry_at_ms,
        .observer = observer,
    };
    const raw_ticket = try ticket.encodeAlloc(self.allocator);
    try self.messages.append(self.allocator, .{
        .target = timers,
        .pid = observer,
        .body = try self.binary(raw_ticket),
        .visible_ms = retry_at_ms,
    });
}

pub fn journal(self: *Self, bytes: []const u8) !void {
    errdefer self.poisoned = true;
    if (self.poisoned) return error.PoisonedTurn;
    self.journal_bytes = try self.binary(bytes);
}

pub fn finish(self: *Self) !Draft {
    if (self.poisoned) return error.PoisonedTurn;
    return .{
        .puts = self.puts.items,
        .tables = self.tables.items,
        .outputs = self.outputs.items,
        .messages = self.messages.items,
        .journal = self.journal_bytes,
    };
}

test "private transactional turn poisons caught reads and owns handler scratch" {
    const t = std.testing;
    const Reader = struct {
        fail: bool = false,
        fn get(raw: *anyopaque, allocator: std.mem.Allocator, _: []const u8) !?[]const u8 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            if (self.fail) return error.AccessDenied;
            return try allocator.dupe(u8, "retained");
        }
    };
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var reader: Reader = .{};
    const source: p.StreamQueue.RecordIdentity = .{
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(1) }, .partition = 0 },
        .operation = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 4, .operation = 5 },
        .ordinal = 0,
    };
    var turn = try init(arena.allocator(), .{}, .{ .context = &reader, .get = Reader.get }, source, "input");
    var scratch: [512]u8 = @splat(42);
    try turn.put("first", &scratch);
    try turn.emit(&scratch);
    @memset(&scratch, 0);
    try t.expectEqual(@as(u8, 42), (try turn.get("first")).?[0]);
    try turn.delete("first");
    try t.expect((try turn.get("first")) == null);
    try t.expectEqual(@as(u8, 42), (try (try turn.finish()).outputs[0].decode(arena.allocator(), 512))[0]);
    try t.expectError(error.ReservedFrameworkKey, turn.put("\x00w1", "forged"));
    try t.expectError(error.PoisonedTurn, turn.finish());
    turn = try init(arena.allocator(), .{}, .{ .context = &reader, .get = Reader.get }, source, "input");
    reader.fail = true;
    _ = turn.get("unread") catch null;
    try t.expectError(error.PoisonedTurn, turn.finish());
    try t.expectError(error.PoisonedTurn, turn.put("second", "hidden"));
    reader.fail = false;
    for (0..4) |ceiling| {
        _ = arena.reset(.retain_capacity);
        var bounded = try init(arena.allocator(), .{ .reads = 1, .writes = 1, .outputs = 1, .bytes = 8 }, .{ .context = &reader, .get = Reader.get }, source, "");
        switch (ceiling) {
            0 => {
                _ = try bounded.get("one");
                try t.expectError(error.TurnCapacity, bounded.get("two"));
            },
            1 => {
                try bounded.put("a", "b");
                try t.expectError(error.TurnCapacity, bounded.put("c", "d"));
            },
            2 => {
                try bounded.emit("first");
                try t.expectError(error.TurnCapacity, bounded.emit("second"));
            },
            3 => try t.expectError(error.TurnCapacity, bounded.put("k", "12345678")),
            else => unreachable,
        }
        try t.expectError(error.PoisonedTurn, bounded.finish());
    }
    var failing = std.testing.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    var exhausted = try init(failing.allocator(), .{}, .{ .context = &reader, .get = Reader.get }, source, "input");
    try t.expectError(error.OutOfMemory, exhausted.put("a", "b"));
    try t.expectError(error.PoisonedTurn, exhausted.finish());
}
