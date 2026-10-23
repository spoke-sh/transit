//! Bounded, request-lane-owned observations of local provider attempts. These
//! counters do not establish acceptance and contain no keys or payloads.
const std = @import("std");
const observations = @import("transit_observability");
const Self = @This();
pub const Metrics = struct {
    requests: u64 = 0,
    failures: u64 = 0,
    elapsed_ns: u64 = 0,
    request_payload_bytes: u64 = 0,
    response_bytes: u64 = 0,
};
runtime: ?*observations.telemetry.Runtime = null,
parent: ?observations.telemetry.Context = null,
enabled: bool = false,
metrics: Metrics = .{},

pub fn run(self: *Self, io: std.Io, operation: []const u8, comptime function: anytype, args: anytype) @TypeOf(@call(.auto, function, args)) {
    var observation = self.begin(io, operation);
    defer observation.finish();
    const result = @call(.auto, function, args) catch |err| {
        observation.fail(err);
        return err;
    };
    if (@TypeOf(result) == bool) {
        if (!result) observation.fail(error.Conflict);
    }
    return result;
}

pub fn begin(self: *Self, io: std.Io, operation: []const u8) Operation {
    self.metrics.requests +|= 1;
    return .{ .owner = self, .io = io, .started = .now(io, .awake), .observation = observations.begin(self.runtime, .storage_operation, operation, self.parent) };
}

pub const Operation = struct {
    owner: *Self,
    io: std.Io,
    started: std.Io.Clock.Timestamp,
    observation: observations.Observation,

    pub fn fail(self: *Operation, err: anyerror) void {
        self.owner.metrics.failures +|= 1;
        self.observation.fail(err);
    }
    pub fn finish(self: *Operation) void {
        self.owner.metrics.elapsed_ns +|= @intCast(@max(0, self.started.durationTo(.now(self.io, .awake)).raw.toNanoseconds()));
        self.observation.finish();
    }
};
