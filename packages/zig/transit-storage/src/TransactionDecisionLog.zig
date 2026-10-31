//! One frozen transaction attempt and one terminal decision in a dedicated,
//! catalog-reserved coordination partition. Participant preparation remains in
//! its data owner. This component does not acquire Table guards or publish rows.
const std = @import("std");
const p = @import("transit_protocol");
const x = p.Transaction;
const d = p.DataLifecycle;
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Directory = @import("TransactionDirectory.zig");
const MemoryBudget = @import("transit_fuze").MemoryBudget;
const Self = @This();
pub const Guard = @import("TablePartition.zig").Guard;
pub const max_record_bytes = 16 * 1024;

pub const Binding = struct {
    begin: x.Begin,
    attempt: x.Attempt,

    pub fn validate(self: Binding) !void {
        try self.begin.validate();
        try self.attempt.validate();
        if (!std.meta.eql(self.begin.identity, self.attempt.transaction) or
            self.attempt.participants.count > self.begin.objects.count or
            self.attempt.last_statement > self.begin.limits.statements or
            (self.begin.mode == .read_only and self.attempt.writes != 0)) return error.InvalidTransactionAttempt;
    }

    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.begin.requireSame(other.begin);
        try self.attempt.requireSame(other.attempt);
    }
};

/// The host holds all selected participant/name/current-policy guards while
/// these callbacks run and through the conditional decision append. Each check
/// verifies the actual owner, not only a caller-supplied descriptor. Recovery
/// never calls these callbacks or dispatches an application effect.
pub const Verification = struct {
    context: *anyopaque,
    participant: *const fn (*anyopaque, x.Participant) anyerror!void,
    prepared: *const fn (*anyopaque, x.Prepared) anyerror!void,
};

pub const Record = struct {
    definition: p.Growth.Definition,
    previous: [32]u8,
    event: union(enum) { freeze: Binding, decision: x.Decision },
};

allocator: std.mem.Allocator,
log: Log.Log,
objects: Objects.ObjectStore,
partition: u64,
binding: Binding,
next_lsn: u64 = 0,
chain: [32]u8 = @splat(0),
decision: ?x.Decision = null,
recovery_required: bool = true,
lose_reply: bool = false,
resident_peak: usize = 0,

pub fn init(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, partition: u64, binding: Binding) !Self {
    try binding.validate();
    if (binding.begin.limits.resident_bytes > std.math.maxInt(usize)) return error.InvalidTransactionLimits;
    if (partition == 0 or partition == binding.begin.catalog.partition) return error.InvalidTransactionPartition;
    return .{ .allocator = allocator, .log = log, .objects = objects, .partition = partition, .binding = binding };
}

fn directory(self: *Self, kind: Directory.Kind) !Directory {
    return Directory.init(self.allocator, self.objects, self.binding.begin.identity, kind, self.binding.begin.limits.participants, 1, 1024 * 1024);
}

fn participants(self: *Self) !Directory {
    var result = try self.directory(.participants);
    errdefer result.deinit();
    try result.restore(self.binding.attempt.participants);
    var after: ?Directory.Cursor = null;
    var count: u64 = 0;
    var writes: u64 = 0;
    while (true) {
        const page = try result.page(after);
        for (page.entries) |entry| if (entry) |value| {
            count = try std.math.add(u64, count, 1);
            if (count > result.root.count) return error.InvalidTransactionDirectory;
            try value.participant.requireLocalTable(self.binding.begin);
            if (value.participant.state.guard.source.accepted.partition == self.partition)
                return error.InvalidTransactionPartition;
            writes += @intFromBool(value.participant.state.access == .write);
        };
        after = page.next orelse break;
    }
    if (count != result.root.count or writes != result.root.writes or writes != self.binding.attempt.writes)
        return error.InvalidTransactionDirectory;
    return result;
}

fn preparations(self: *Self, decision: x.Decision) !Directory {
    try decision.requireAttempt(self.binding.attempt);
    var selected = try self.participants();
    defer selected.deinit();
    var prepared = try self.directory(.preparations);
    errdefer prepared.deinit();
    try prepared.restore(decision.prepared);
    if (decision.outcome == .committed) {
        try selected.requireComplete(&prepared, self.binding.begin, self.binding.attempt);
    } else {
        // Abort is independent of how many participants prepared. The complete
        // frozen participant directory remains the cleanup/recovery work list.
        if (prepared.root.count != 0) return error.InvalidTransactionDecision;
    }
    return prepared;
}

fn encode(record: Record, output: []u8) ![]const u8 {
    if (output.len < 40) return error.InvalidTransactionHistory;
    output[0..8].* = "TXDEC1\x00\x00".*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[40..@min(output.len, max_record_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    return output[0 .. 40 + writer.end];
}

fn decode(bytes: []const u8) !Record {
    if (bytes.len <= 40 or bytes.len > max_record_bytes or !std.mem.eql(u8, bytes[0..8], "TXDEC1\x00\x00")) return error.InvalidTransactionHistory;
    if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    var scratch: [max_record_bytes]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    const parsed = std.json.parseFromSliceLeaky(Record, fixed.allocator(), bytes[40..], .{}) catch |err|
        return if (err == error.OutOfMemory) error.TransactionDecodeLimit else err;
    var canonical: [max_record_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try encode(parsed, &canonical))) return error.InvalidTransactionHistory;
    return parsed;
}

/// Read the original frozen binding from its actual acceptance log. Callers
/// subsequently recover the journal to validate its complete retained chain.
pub fn frozenBinding(allocator: std.mem.Allocator, log: Log.Log, partition: u64) !Binding {
    var batch = try log.read(allocator, partition, 0, 1);
    defer batch.deinit();
    if (batch.frames.len != 1) return error.TransactionHistoryMissing;
    const frame = batch.frames[0];
    if (frame.header.partition_id != partition or frame.header.lsn != 0 or frame.header.kind != .policy_control) return error.InvalidTransactionHistory;
    const value = try decode(frame.payload);
    if (value.event != .freeze or !std.mem.allEqual(u8, &value.previous, 0)) return error.InvalidTransactionHistory;
    try value.event.freeze.validate();
    return value.event.freeze;
}

/// A new physical owner checks every retained frame and immutable directory.
/// No participant is replayed and recovery stages no objects or log records.
pub fn recover(self: *Self) !void {
    return self.bounded(recoverBounded, .{});
}

fn recoverBounded(self: *Self) !void {
    self.recovery_required = true;
    const end = try self.log.tail(self.partition);
    if (end > 2 or end < self.next_lsn) return error.InvalidTransactionHistory;
    var next: u64 = 0;
    var chain: [32]u8 = @splat(0);
    var decision: ?x.Decision = null;
    while (next < end) : (next += 1) {
        var batch = try self.log.read(self.allocator, self.partition, next, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.TransactionHistoryMissing;
        const frame = batch.frames[0];
        if (frame.header.partition_id != self.partition or frame.header.lsn != next or frame.header.kind != .policy_control)
            return error.InvalidTransactionHistory;
        const record = try decode(frame.payload);
        if (!std.mem.eql(u8, &record.previous, &chain)) return error.InvalidTransactionHistory;
        switch (record.event) {
            .freeze => |binding| {
                if (next != 0) return error.InvalidTransactionHistory;
                try self.binding.requireSame(binding);
                var selected = try self.participants();
                selected.deinit();
            },
            .decision => |value| {
                if (next != 1 or value.position.partition != self.partition or value.position.next_lsn != 2 or
                    value.coordinator_epoch != frame.header.writer_epoch or value.policy_epoch != frame.header.policy_epoch)
                    return error.InvalidTransactionHistory;
                var prepared = try self.preparations(value);
                prepared.deinit();
                decision = value;
            },
        }
        chain = hash(frame.payload);
    }
    self.next_lsn = next;
    self.chain = chain;
    self.decision = decision;
    self.recovery_required = false;
}

fn ready(self: *Self) !void {
    if (self.recovery_required) return error.TransactionRecoveryRequired;
    if (try self.log.tail(self.partition) != self.next_lsn) {
        self.recovery_required = true;
        return error.TransactionRecoveryRequired;
    }
}

pub fn observe(self: *Self, guard: Guard) !x.Observation {
    return self.bounded(observeBounded, .{guard});
}

fn observeBounded(self: *Self, guard: Guard) !x.Observation {
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    try self.ready();
    if (self.decision) |decision| return .{ .decided = decision };
    return if (self.next_lsn == 0) .not_observed else .{ .preparing = self.binding.attempt };
}

/// Called before any participant preparation. The caller has already admitted
/// the original token, acquired its cut and reserved this dedicated partition.
pub fn freeze(self: *Self, guard: Guard) !void {
    return self.bounded(freezeBounded, .{guard});
}

fn freezeBounded(self: *Self, guard: Guard) !void {
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    try self.ready();
    if (self.next_lsn != 0) return;
    var selected = try self.participants();
    defer selected.deinit();
    try self.append(.{ .freeze = self.binding }, fence);
    if (self.lose_reply) return error.LostAcknowledgement;
}

pub fn commit(self: *Self, prepared_directory: x.Directory, verification: Verification, guard: Guard) !x.Decision {
    return self.bounded(commitBounded, .{ prepared_directory, verification, guard });
}

fn commitBounded(self: *Self, prepared_directory: x.Directory, verification: Verification, guard: Guard) !x.Decision {
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    try self.ready();
    if (self.decision) |decision| return decision;
    if (self.next_lsn != 1) return error.TransactionNotFrozen;
    const decision = self.proposal(.committed, prepared_directory, fence);
    var prepared = try self.preparations(decision);
    defer prepared.deinit();
    var selected = try self.participants();
    defer selected.deinit();
    var after: ?Directory.Cursor = null;
    while (true) {
        const page = try selected.page(after);
        for (page.entries) |entry| if (entry) |value| {
            try verification.participant(verification.context, value.participant);
            if (value.participant.state.access == .write) {
                const original = (try prepared.get(value.target())).?.prepared;
                try verification.prepared(verification.context, original);
            }
        };
        after = page.next orelse break;
    }
    try self.append(.{ .decision = decision }, fence);
    if (self.lose_reply) return error.LostAcknowledgement;
    return decision;
}

/// This races commit through the same expected log position. Once either
/// decision exists, both methods return it. Session loss never invokes abort.
pub fn abort(self: *Self, guard: Guard) !x.Decision {
    return self.bounded(abortBounded, .{guard});
}

fn abortBounded(self: *Self, guard: Guard) !x.Decision {
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    try self.ready();
    if (self.decision) |decision| return decision;
    if (self.next_lsn != 1) return error.TransactionNotFrozen;
    var empty = try self.directory(.preparations);
    defer empty.deinit();
    const decision = self.proposal(.aborted, try empty.seal(), fence);
    try self.append(.{ .decision = decision }, fence);
    if (self.lose_reply) return error.LostAcknowledgement;
    return decision;
}

fn proposal(self: *Self, outcome: @FieldType(x.Decision, "outcome"), prepared: x.Directory, fence: Guard.Fence) x.Decision {
    return .{
        .attempt = self.binding.attempt,
        .outcome = outcome,
        .prepared = prepared,
        .position = .{ .partition = self.partition, .next_lsn = self.next_lsn + 1 },
        .coordinator_epoch = fence.writer_epoch,
        .policy_epoch = fence.policy_epoch,
    };
}

fn append(self: *Self, event: @FieldType(Record, "event"), fence: Guard.Fence) !void {
    if (event == .decision) try event.decision.validate();
    const record: Record = .{ .definition = p.Growth.current_definition, .previous = self.chain, .event = event };
    var bytes: [max_record_bytes]u8 = undefined;
    const payload = try encode(record, &bytes);
    _ = self.log.append(self.partition, self.next_lsn, fence.writer_epoch, fence.policy_epoch, .policy_control, payload) catch |err| {
        self.recovery_required = true;
        return err;
    };
    self.next_lsn += 1;
    self.chain = hash(payload);
    if (event == .decision) self.decision = event.decision;
}

fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

fn bounded(self: *Self, comptime action: anytype, args: anytype) @typeInfo(@TypeOf(action)).@"fn".return_type.? {
    var memory: MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(self.binding.begin.limits.resident_bytes) };
    var scoped = self.*;
    scoped.allocator = memory.allocator();
    defer {
        scoped.allocator = self.allocator;
        scoped.resident_peak = memory.peak;
        self.* = scoped;
        std.debug.assert(memory.used == 0);
    }
    return @call(.auto, action, .{&scoped} ++ args) catch |err| {
        if (err == error.OutOfMemory and memory.exhausted) return error.TransactionMemoryLimit;
        return err;
    };
}
