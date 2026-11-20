//! Scheduled Timer Queue tickets and observer-authenticated timeout frames.
//! Tickets sit in QueueTimingWheel via `visible_ms = deadline_ms`, eliminating
//! 100 ms O(keys) KV page scans across idle actors and supervisors.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;

pub const max_ticket_bytes = 2048;
pub const observation_magic = "TMO1";
pub const observation_bytes = 12;

pub const Kind = enum {
    wait_timeout,
    supervisor_backoff,
};

pub const Ticket = struct {
    version: u8 = 1,
    definition: p.Growth.Definition,
    kind: Kind,
    target_pid: u64,
    target_inbox: p.StreamQueue.Partition,
    correlation: u64,
    child_pid: ?u64 = null,
    generation: u64 = 0,
    failure: u64 = 0,
    deadline_ms: u64,
    observer: u64,

    pub fn validate(self: Ticket) !void {
        if (self.version != 1) return error.InvalidTimerTicket;
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.target_pid == 0 or self.target_pid > p.max_counter or self.deadline_ms == 0 or
            self.observer == 0 or self.observer > p.max_counter) return error.InvalidTimerTicket;
        try self.target_inbox.validate();
        switch (self.kind) {
            .wait_timeout => if (self.correlation == 0 or self.child_pid != null) return error.InvalidTimerTicket,
            .supervisor_backoff => {
                const child = self.child_pid orelse return error.InvalidTimerTicket;
                if (child == 0 or child > p.max_counter or self.correlation != 0 or self.generation == 0 or self.failure == 0)
                    return error.InvalidTimerTicket;
            },
        }
    }

    pub fn encodeAlloc(self: Ticket, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, max_ticket_bytes);
    }

    pub fn decode(allocator: std.mem.Allocator, bytes: []const u8) !Ticket {
        if (bytes.len == 0 or bytes.len > max_ticket_bytes) return error.InvalidTimerTicket;
        const parsed = try p.Json.parseFromSlice(Ticket, allocator, bytes);
        defer parsed.deinit();
        try parsed.value.validate();
        return parsed.value;
    }
};

pub const Observation = struct {
    observed_ms: u64,

    pub fn encode(self: Observation) ![observation_bytes]u8 {
        if (self.observed_ms == 0) return error.InvalidDeadline;
        var out: [observation_bytes]u8 = undefined;
        out[0..4].* = observation_magic.*;
        std.mem.writeInt(u64, out[4..12], self.observed_ms, .little);
        return out;
    }

    pub fn decode(bytes: []const u8) !Observation {
        if (bytes.len != observation_bytes or !std.mem.eql(u8, bytes[0..4], observation_magic))
            return error.InvalidTimeoutObservation;
        const observed_ms = std.mem.readInt(u64, bytes[4..12], .little);
        if (observed_ms == 0) return error.InvalidTimeoutObservation;
        return .{ .observed_ms = observed_ms };
    }
};

test "private transactional timer tickets and TMO1 observations round-trip with strict kind checks" {
    const t = std.testing;
    const partition: p.StreamQueue.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(2) },
        .partition = 0,
    };
    const ticket: Ticket = .{
        .definition = p.Growth.current_definition,
        .kind = .wait_timeout,
        .target_pid = 15,
        .target_inbox = partition,
        .correlation = 0x10001,
        .deadline_ms = 2500,
        .observer = 109,
    };
    const encoded = try ticket.encodeAlloc(t.allocator);
    defer t.allocator.free(encoded);
    try t.expectEqualDeep(ticket, try Ticket.decode(t.allocator, encoded));

    const obs = try (Observation{ .observed_ms = 2505 }).encode();
    try t.expectEqual(@as(u64, 2505), (try Observation.decode(&obs)).observed_ms);
    try t.expectError(error.InvalidTimeoutObservation, Observation.decode("TMO1\x00\x00\x00\x00\x00\x00\x00\x00"));
}
