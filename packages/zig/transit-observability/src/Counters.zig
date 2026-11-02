//! Opt-in, process-lifetime observations with fixed cardinality. No allocation,
//! locks, sinks or authority. Configure before starting workers; never reset a
//! live instance. Snapshots are independent atomic loads, not an atomic cut.
const std = @import("std");

pub fn Counters(comptime Values: type) type {
    const fields = @typeInfo(Values).@"struct".field_names;
    return struct {
        const Self = @This();
        enabled: bool = false,
        values: [fields.len]std.atomic.Value(u64) = @splat(.init(0)),
        overflowed: std.atomic.Value(bool) = .init(false),
        pub const Snapshot = struct { values: Values, overflowed: bool };

        pub fn add(self: *Self, comptime field: []const u8, amount: u64) void {
            if (!self.enabled) return;
            const index = std.meta.fieldIndex(Values, field) orelse @compileError("unknown counter");
            const previous = self.values[index].fetchAdd(amount, .monotonic);
            if (amount > std.math.maxInt(u64) - previous) self.overflowed.store(true, .monotonic);
        }

        pub fn snapshot(self: *const Self) ?Snapshot {
            if (!self.enabled) return null;
            var result: Values = undefined;
            inline for (fields, 0..) |field, index| @field(result, field) = self.values[index].load(.monotonic);
            return .{ .values = result, .overflowed = self.overflowed.load(.monotonic) };
        }

        pub fn timer(self: *Self, io: std.Io) Timer {
            return .{ .owner = self, .io = io, .started = if (self.enabled) .now(io, .awake) else null };
        }
        pub const Timer = struct {
            owner: *Self,
            io: std.Io,
            started: ?std.Io.Clock.Timestamp,
            pub fn finish(self: Timer, comptime field: []const u8) void {
                if (self.started) |started| self.owner.add(field, @intCast(@max(0, started.durationTo(.now(self.io, .awake)).raw.toNanoseconds())));
            }
        };
    };
}

test "disabled counters are absent and overflow invalidates observations" {
    const t = std.testing;
    var counters: Counters(struct { calls: u64 }) = .{};
    counters.add("calls", 9);
    try t.expect(counters.snapshot() == null);
    counters.enabled = true;
    try t.expectEqual(0, counters.snapshot().?.values.calls);
    counters.add("calls", std.math.maxInt(u64));
    try t.expect(!counters.snapshot().?.overflowed);
    counters.add("calls", 1);
    try t.expect(counters.snapshot().?.overflowed);
}
