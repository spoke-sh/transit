//! Shared runtime storage budgets. These bound private work and physical
//! allocation admission; they never authorize retention or logical expiry.
const std = @import("std");
const p = @import("root.zig");
pub const max_candidate_bytes = 8 * 1024 * 1024;
pub const Limits = struct {
    bytes: u64 = 8 * 1024 * 1024 * 1024,
    control_bytes: u64 = 64 * 1024 * 1024,
    candidate_bytes: u32 = max_candidate_bytes,
    pub fn validate(self: Limits) !void {
        if (self.bytes == 0 or self.bytes > p.max_counter or self.control_bytes < 1024 * 1024 or self.control_bytes > p.max_counter or self.candidate_bytes == 0 or self.candidate_bytes > max_candidate_bytes) return error.InvalidStorageBudget;
    }
};
pub const Flush = struct {
    enabled: bool = false,
    rows: u16 = 256,
    work_rows: u16 = 32,
    bytes: u64 = 256 * 1024,
    age_ms: u32 = 5000,
    pub fn validate(self: Flush) !void {
        if (self.rows == 0 or self.rows > 1024 or self.work_rows == 0 or self.work_rows > 1024 or self.bytes == 0 or self.bytes > p.max_counter or
            self.age_ms == 0 or self.age_ms > 60000) return error.InvalidStorageBudget;
    }
};
pub const Archive = struct {
    enabled: bool = false,
    work_frames: u8 = 4,
    pub fn validate(self: Archive) !void {
        if (self.work_frames == 0 or self.work_frames > 8) return error.InvalidStorageBudget;
    }
};
pub const Maintenance = struct {
    collection_every_records: u64 = 1024,
    compact: bool = false,
    compaction_rows: u16 = 32,
    resident_bytes: u32 = 128 * 1024 * 1024,
    archive: Archive = .{},
    flush: Flush = .{},
    pub fn validate(self: Maintenance) !void {
        try self.flush.validate();
        try self.archive.validate();
        if (self.collection_every_records == 0 or self.collection_every_records > p.max_counter or
            self.compaction_rows == 0 or self.compaction_rows > 1024 or
            self.resident_bytes < 32 * 1024 * 1024 or self.resident_bytes > 512 * 1024 * 1024) return error.InvalidStorageBudget;
    }
};
pub const Requests = struct {
    request_bytes: u32 = 128 * 1024 * 1024,
    data_bytes: u32 = 256 * 1024 * 1024,
    control_bytes: u32 = 64 * 1024 * 1024,
    pub fn validate(self: Requests) !void {
        if (self.request_bytes < 1024 * 1024 or self.request_bytes > 128 * 1024 * 1024 or
            self.data_bytes < self.request_bytes or self.data_bytes > 256 * 1024 * 1024 or
            self.control_bytes < 1024 * 1024 or self.control_bytes > 64 * 1024 * 1024) return error.InvalidStorageBudget;
    }
};
pub const Settings = struct { limits: Limits = .{}, maintenance: Maintenance = .{}, requests: Requests = .{} };

/// Owned native response text. No borrowed filesystem buffer crosses a read.
pub const Path = struct {
    len: u16,
    bytes: [4096]u8 = @splat(0),
    pub fn init(value: []const u8) !Path {
        if (value.len == 0 or value.len > 4096 or value[0] != '/' or
            std.mem.indexOfScalar(u8, value, 0) != null or !std.unicode.utf8ValidateSlice(value)) return error.InvalidStorageObservation;
        var result: Path = .{ .len = @intCast(value.len) };
        @memcpy(result.bytes[0..value.len], value);
        return result;
    }
    pub fn slice(self: *const Path) []const u8 {
        return self.bytes[0..self.len];
    }
    pub fn validate(self: Path) !void {
        if (self.len == 0 or self.len > self.bytes.len) return error.InvalidStorageObservation;
        _ = try Path.init(self.bytes[0..self.len]);
        if (!std.mem.allEqual(u8, self.bytes[self.len..], 0)) return error.InvalidStorageObservation;
    }
    pub fn jsonStringify(self: Path, out: anytype) !void {
        self.validate() catch return error.WriteFailed;
        try out.write(self.slice());
    }
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Path {
        return Path.init(try std.json.innerParse([]const u8, allocator, source, options)) catch error.UnexpectedToken;
    }
    pub fn jsonParseFromValue(_: std.mem.Allocator, value: std.json.Value, _: std.json.ParseOptions) !Path {
        return switch (value) {
            .string => |text| Path.init(text) catch error.UnexpectedToken,
            else => error.UnexpectedToken,
        };
    }
    pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.write(.{ .type = "string", .minLength = 1, .maxLength = 4096, .pattern = "^/[^\\u0000]*$" });
    }
};
pub const Memory = struct {
    limit: u64,
    used: u64,
    peak: u64,
    pub fn validate(self: Memory) !void {
        if (self.limit == 0 or self.limit > p.max_counter or self.used > self.limit or self.peak > self.limit or self.used > self.peak) return error.InvalidStorageObservation;
    }
};
pub const Failure = enum { capacity, denied, clock, timeout, recovery, storage, other };
pub const Activity = struct {
    enabled: bool,
    state: enum { disabled, waiting, running, failed },
    completed_steps: u64,
    failed_steps: u64,
    last_failure: ?Failure,
    interval_ms: u32,
    operation_timeout_ms: u32,
};
/// Live, independently sampled owner counters. They are neither a durable
/// snapshot nor per-Table attribution; null means unavailable, never zero.
pub const Observation = struct {
    backend: enum { unavailable, local, ursula },
    root: ?Path,
    allocated_bytes: ?u64,
    limits: ?Limits,
    data_requests: ?Memory,
    control_requests: ?Memory,
    request_limit_bytes: ?u64,
    maintenance: ?Activity,
    settings: ?Maintenance,

    pub const unavailable: Observation = .{ .backend = .unavailable, .root = null, .allocated_bytes = null, .limits = null, .data_requests = null, .control_requests = null, .request_limit_bytes = null, .maintenance = null, .settings = null };
    pub fn validate(self: Observation) !void {
        if (self.backend == .unavailable and !std.meta.eql(self, unavailable)) return error.InvalidStorageObservation;
        if (self.allocated_bytes) |value| if (value > p.max_counter) return error.InvalidStorageObservation;
        if (self.root) |path| try path.validate();
        if (self.limits) |limits| try limits.validate();
        if (self.data_requests) |value| try value.validate();
        if (self.control_requests) |value| try value.validate();
        if ((self.data_requests == null) != (self.control_requests == null) or
            (self.data_requests == null) != (self.request_limit_bytes == null)) return error.InvalidStorageObservation;
        if (self.request_limit_bytes) |limit| if (limit == 0 or limit > self.data_requests.?.limit) return error.InvalidStorageObservation;
        if (self.settings) |settings| try settings.validate();
        if (self.maintenance) |activity| {
            if (activity.completed_steps > p.max_counter or activity.failed_steps > p.max_counter or
                activity.enabled != (activity.state != .disabled) or
                (activity.state == .failed and activity.last_failure == null) or
                (activity.failed_steps == 0) != (activity.last_failure == null) or
                (activity.enabled and (activity.interval_ms == 0 or activity.operation_timeout_ms == 0)) or
                activity.interval_ms > 60000 or activity.operation_timeout_ms > 60000) return error.InvalidStorageObservation;
        }
    }
};

test "storage observations distinguish unavailable data and reject impossible counters" {
    const t = std.testing;
    try Observation.unavailable.validate();
    var value = Observation.unavailable;
    value.allocated_bytes = 0;
    try t.expectError(error.InvalidStorageObservation, value.validate());
    try t.expectError(error.InvalidStorageObservation, (Memory{ .limit = 16, .used = 9, .peak = 8 }).validate());
    var path = try Path.init("/var/lib/transit");
    try path.validate();
    const bytes = try p.Json.valueAlloc(t.allocator, path);
    defer t.allocator.free(bytes);
    const parsed = try std.json.parseFromSlice(Path, t.allocator, bytes, .{});
    const owned = parsed.value;
    parsed.deinit();
    try t.expectEqualStrings(path.slice(), owned.slice());
    path.bytes[path.len] = 1;
    try t.expectError(error.InvalidStorageObservation, path.validate());
}

test "request capacity validates the total ordinary and independent control bounds" {
    const t = std.testing;
    try (Requests{}).validate();
    try (Requests{ .request_bytes = 1048576, .data_bytes = 1048576, .control_bytes = 1048576 }).validate();
    try t.expectError(error.InvalidStorageBudget, (Requests{ .data_bytes = 1048576 }).validate());
    try t.expectError(error.InvalidStorageBudget, (Requests{ .control_bytes = 0 }).validate());
    try t.expectError(error.InvalidStorageBudget, (Requests{ .data_bytes = 268435457 }).validate());
}
