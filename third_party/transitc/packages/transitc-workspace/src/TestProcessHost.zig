//! One joined runtime process per compiled case, with bounded requests and replies.
const std = @import("std");
const p = @import("transit_protocol");
const c = @import("transit_compiler");
const Wire = @import("TestHostProtocol.zig");
const Sources = @import("BuildSources.zig");
const Self = @This();
pub const embedded = false;
pub const cleanup_ms = Wire.cleanup_ms;
executable: []const u8,
identity: ?Wire.Runtime = null,
revision_storage: [128]u8 = undefined,
error_storage: [128]u8 = undefined,
error_len: usize = 0,
pub const Deadline = struct {
    until: std.Io.Clock.Timestamp,
    pub fn init(io: std.Io, milliseconds: u32, parent: ?Deadline) Deadline {
        const result: Deadline = .{ .until = .fromNow(io, .{ .clock = .awake, .raw = .fromMilliseconds(milliseconds) }) };
        return if (parent) |cap| if (cap.until.compare(.lt, result.until)) cap else result else result;
    }
    pub fn check(self: Deadline, io: std.Io) !void {
        if (self.until.durationFromNow(io).raw.nanoseconds <= 0) return error.AuthorityTimeout;
    }
};
pub fn errorName(self: *const Self, err: anyerror) []const u8 {
    return if (err == error.TestHostExecutionFailed) self.error_storage[0..self.error_len] else @errorName(err);
}
pub fn runDetailed(self: *Self, init: std.process.Init, directory: std.Io.Dir, path: []const u8, case: c.Test.Case, deadline: Deadline, observed: *Wire.Observation, detail: *c.Test.Detail) !bool {
    try deadline.check(init.io);
    var budget: @import("transit_memory").Budget = .{ .parent = init.gpa, .limit = 256 * 1024 * 1024 };
    var arena: std.heap.ArenaAllocator = .init(budget.allocator());
    defer arena.deinit();
    const a = arena.allocator();
    const remaining = deadline.until.durationFromNow(init.io).raw.nanoseconds;
    if (remaining <= 0) return error.AuthorityTimeout;
    const milliseconds: u32 = @intCast(@min(Wire.case_ms, @max(1, @divFloor(remaining, std.time.ns_per_ms))));
    const request = try Wire.capture(a, case, milliseconds);
    const bytes = try p.Json.valueAllocBounded(a, request, Wire.max_request_bytes);
    try Sources.writeFile(init.io, directory, "case.json", bytes);
    try deadline.check(init.io);
    const result = std.process.run(a, init.io, .{
        .argv = &.{ self.executable, Wire.argument, path },
        .environ_map = init.environ_map,
        .stdout_limit = .limited(Wire.max_response_bytes),
        .stderr_limit = .limited(Wire.max_response_bytes),
        .timeout = .{ .deadline = deadline.until.addDuration(.{ .raw = .fromMilliseconds(cleanup_ms), .clock = .awake }) },
    }) catch |err| return if (err == error.FileNotFound) error.TestRuntimeUnavailable else err;
    // process.run joins or kills and joins its owned child, including timeout
    // and oversized-output paths, before case storage can be removed.
    switch (result.term) {
        .exited => |status| if (status != 0) return error.TestHostFailed,
        else => return error.TestHostTerminated,
    }
    if (result.stderr.len != 0) return error.TestHostUnexpectedStderr;
    const response = try p.Json.parseFromSlice(Wire.Response, a, result.stdout);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    try Wire.validateResponse(response.value, request, digest);
    const runtime = response.value.runtime;
    if (self.identity) |prior| {
        if (!std.mem.eql(u8, prior.revision, runtime.revision) or !std.mem.eql(u8, &prior.executable_digest, &runtime.executable_digest)) return error.TestRuntimeChanged;
    } else {
        @memcpy(self.revision_storage[0..runtime.revision.len], runtime.revision);
        self.identity = .{ .revision = self.revision_storage[0..runtime.revision.len], .executable_digest = runtime.executable_digest };
    }
    observed.* = response.value.observation;
    detail.* = response.value.detail;
    if (response.value.error_code) |cause| {
        if (cause.len == 0 or cause.len > self.error_storage.len) return error.InvalidTestHostResponse;
        for (cause) |byte| if (!std.ascii.isAlphanumeric(byte)) return error.InvalidTestHostResponse;
        @memcpy(self.error_storage[0..cause.len], cause);
        self.error_len = cause.len;
        return error.TestHostExecutionFailed;
    }
    return response.value.passed;
}
pub fn delete(_: *Self, io: std.Io, parent: std.Io.Dir, name: []const u8) !void {
    const Result = union(enum) { deleted: anyerror!void, expired: anyerror!void };
    const Timer = struct {
        fn wait(clock: std.Io) !void {
            try clock.sleep(.fromMilliseconds(cleanup_ms), .awake);
            return error.TestDeadline;
        }
    };
    var results: [2]Result = undefined;
    var selection: std.Io.Select(Result) = .init(io, &results);
    defer selection.cancelDiscard();
    try selection.concurrent(.expired, Timer.wait, .{io});
    try selection.concurrent(.deleted, std.Io.Dir.deleteTree, .{ parent, io, name });
    switch (try selection.await()) {
        .deleted => |result| try result,
        .expired => |result| try result,
    }
}
