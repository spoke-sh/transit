//! Durable request-reply wait records stored in the caller's state KV.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;

pub const max_bytes = 2048;
pub const disposition_key = "\x00disposition";
pub const closed_reply_disposition = "station.closed-reply.v1";
pub const closed_timeout_disposition = "station.closed-timeout.v1";

pub const Phase = enum(u8) {
    waiting = 1,
    replied = 2,
    timed_out = 3,
    cancelled = 4,
};

pub const Record = struct {
    version: u8 = 1,
    definition: p.Growth.Definition,
    phase: Phase = .waiting,
    target_pid: u64,
    target_inbox: p.StreamQueue.Partition,
    deadline_ms: ?u64 = null,
    observer: ?u64 = null,
    created_turn: u64,
    resolution_turn: u64 = 0,

    pub fn validate(self: Record) !void {
        if (self.version != 1) return error.InvalidWaitRecord;
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.target_pid == 0 or self.target_pid > p.max_counter or self.created_turn == 0)
            return error.InvalidWaitRecord;
        try self.target_inbox.validate();
        if (self.deadline_ms) |deadline| if (deadline == 0) return error.InvalidDeadline;
        if ((self.deadline_ms == null) != (self.observer == null)) return error.InvalidTimerObserver;
        if (self.observer) |principal| if (principal == 0 or principal > p.max_counter) return error.InvalidTimerObserver;
        if ((self.phase == .waiting) != (self.resolution_turn == 0)) return error.InvalidWaitRecord;
        if (self.phase != .waiting and self.resolution_turn <= self.created_turn) return error.InvalidWaitRecord;
    }

    pub fn encodeAlloc(self: Record, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, max_bytes);
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Record {
        if (bytes.len == 0 or bytes.len > max_bytes) return error.InvalidWaitRecord;
        const parsed = try p.Json.parseFromSlice(Record, allocator, bytes);
        defer parsed.deinit();
        try parsed.value.validate();
        return parsed.value;
    }
};

pub fn key(correlation: u64) [10]u8 {
    var out: [10]u8 = undefined;
    out[0..2].* = "\x00w".*;
    std.mem.writeInt(u64, out[2..10], correlation, .big);
    return out;
}

pub fn correlationFor(turn: u64, ordinal: u16) !u64 {
    if (turn == 0 or turn > (std.math.maxInt(u64) >> 16)) return error.TurnCapacity;
    const step = try std.math.add(u16, ordinal, 1);
    return (turn << 16) | @as(u64, step);
}

test "private transactional wait record validates timer observer pairing and resolution order" {
    const t = std.testing;
    const partition: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(2) },
        .partition = 0,
    };
    var wait: Record = .{
        .definition = p.Growth.current_definition,
        .target_pid = 12,
        .target_inbox = partition,
        .deadline_ms = 5000,
        .observer = 77,
        .created_turn = 1,
    };
    const encoded = try wait.encodeAlloc(t.allocator);
    defer t.allocator.free(encoded);
    try t.expectEqualDeep(wait, try Record.decode(t.allocator, encoded));

    wait.observer = null;
    try t.expectError(error.InvalidTimerObserver, wait.validate());
    wait.observer = 77;
    wait.phase = .replied;
    try t.expectError(error.InvalidWaitRecord, wait.validate());
    wait.resolution_turn = 1;
    try t.expectError(error.InvalidWaitRecord, wait.validate());
    wait.resolution_turn = 2;
    try wait.validate();
}
