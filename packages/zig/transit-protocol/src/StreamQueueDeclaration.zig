//! Immutable Stream/Queue configuration. The catalog owns names, grants and
//! publication; a validated descriptor alone grants no access or execution.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const Kind = enum { stream, queue };
pub const Partitioning = struct {
    count: u32,
    /// Stable schema column identity, not its current display position.
    key_column: ?u64,
    hash: enum { sha256_64 },

    pub fn validate(self: Partitioning) !void {
        if (self.count == 0) return error.InvalidLogPartitioning;
        if (self.key_column) |column| if (column == 0) return error.InvalidLogPartitioning;
    }

    /// Explicit partition selection is allowed without an automatic key.
    /// Hash input is the schema owner's canonical, collation-aware key bytes.
    pub fn select(self: Partitioning, canonical_key: []const u8) !u32 {
        try self.validate();
        if (self.key_column == null) return error.LogPartitionKeyRequired;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(canonical_key, &digest, .{});
        return @intCast(std.mem.readInt(u64, digest[0..8], .big) % self.count);
    }
};

pub const Retention = struct {
    /// Null means unlimited. A duration permits eligibility, never deletion
    /// past a retained read, transaction, consumer or unresolved operation.
    max_age_ms: ?u64,
    pub fn validate(self: Retention) !void {
        if (self.max_age_ms) |age| if (age == 0) return error.InvalidLogRetention;
    }
};

pub const Backoff = struct {
    initial_ms: u64,
    maximum_ms: u64,
    multiplier: u16,
    pub fn validate(self: Backoff) !void {
        if (self.maximum_ms < self.initial_ms or self.multiplier == 0) return error.InvalidQueueBackoff;
    }
    /// Attempt one uses the initial delay. Work is bounded by integer width,
    /// independently of an accepted message's attempt count.
    pub fn delay(self: Backoff, attempt: u32) !u64 {
        try self.validate();
        if (attempt == 0) return error.InvalidQueueAttempt;
        if (self.multiplier == 1 or self.initial_ms == 0) return self.initial_ms;
        var result = self.initial_ms;
        var remaining = attempt - 1;
        while (remaining != 0 and result < self.maximum_ms) : (remaining -= 1)
            result = @min(result *| self.multiplier, self.maximum_ms);
        return result;
    }
};

pub const Queue = struct {
    ordering: enum { unordered, key_fifo },
    key_column: ?u64,
    lease_ms: u64,
    maximum_lease_ms: u64,
    maximum_attempts: u32,
    backoff: Backoff,
    dead_letter: ?d.Definition,

    pub fn validate(self: Queue) !void {
        if (self.lease_ms == 0 or self.maximum_lease_ms < self.lease_ms or
            self.maximum_attempts == 0 or (self.ordering == .key_fifo) != (self.key_column != null))
            return error.InvalidQueuePolicy;
        if (self.key_column) |column| if (column == 0) return error.InvalidQueuePolicy;
        try self.backoff.validate();
        if (self.dead_letter) |destination| try destination.validate();
    }
    pub fn deadline(self: Queue, now_ms: u64, duration_ms: u64) !u64 {
        try self.validate();
        if (duration_ms == 0 or duration_ms > self.maximum_lease_ms) return error.InvalidQueueLeaseDuration;
        return std.math.add(u64, now_ms, duration_ms) catch error.QueueLeaseDeadlineOverflow;
    }
};

pub const Stream = struct {
    /// A stable key is required for opted-in key compaction. Tombstones are
    /// retained until the owning history/dependency contract permits removal.
    compact_key_column: ?u64,
    /// Optional non-null UTC timestamp column; bounds use exact microseconds.
    timestamp_column: ?u64,
    pub fn validate(self: Stream) !void {
        if (self.compact_key_column) |column| if (column == 0) return error.InvalidStreamPolicy;
        if (self.timestamp_column) |column| if (column == 0) return error.InvalidStreamPolicy;
    }
};

pub const Configuration = struct {
    partitioning: Partitioning,
    retention: Retention,
    policy: union(Kind) { stream: Stream, queue: Queue },

    pub fn validate(self: Configuration) !void {
        try self.partitioning.validate();
        try self.retention.validate();
        switch (self.policy) {
            .stream => |value| try value.validate(),
            .queue => |value| {
                try value.validate();
                // All equal FIFO keys route to the same logical partition.
                if (value.ordering == .key_fifo and self.partitioning.count > 1 and
                    self.partitioning.key_column != value.key_column) return error.InvalidQueuePartitionKey;
            },
        }
    }
    pub fn requireEvolution(self: Configuration, next: Configuration) !void {
        try self.validate();
        try next.validate();
        if (std.meta.activeTag(self.policy) != std.meta.activeTag(next.policy) or
            !std.meta.eql(self.partitioning, next.partitioning)) return error.UnsupportedLogRepartition;
        switch (self.policy) {
            .stream => |value| {
                if (value.compact_key_column != next.policy.stream.compact_key_column) return error.UnsupportedLogKeyChange;
                if (value.timestamp_column != next.policy.stream.timestamp_column) return error.UnsupportedLogTimestampChange;
            },
            .queue => |value| if (value.ordering != next.policy.queue.ordering or value.key_column != next.policy.queue.key_column)
                return error.UnsupportedLogKeyChange,
        }
    }
};

/// Operation and active-work budgets, not total durable collection capacities.
/// The host separately meters aggregate resident memory and physical storage,
/// including a control reserve for settlements, revocation and recovery.
pub const Limits = struct {
    append_rows: u32,
    append_bytes: u32,
    claim_rows: u32,
    read_rows: u32,
    read_bytes: u32,
    active_leases: u32,
    waiters: u32,
    timer_steps: u32,
    pub fn validate(self: Limits) !void {
        inline for (@typeInfo(Limits).@"struct".field_names) |name|
            if (@field(self, name) == 0) return error.InvalidLogLimits;
        if (self.claim_rows > self.active_leases) return error.InvalidLogLimits;
    }
};

pub const Declaration = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    /// The immutable schema owner verifies types, codecs, collations and key
    /// column identities; content attribution does not perform schema binding.
    schema: d.Content,
    configuration: Configuration,
    limits: Limits,
    pub fn validate(self: Declaration) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        try self.schema.validate();
        try self.configuration.validate();
        try self.limits.validate();
        if (self.interpretation.object.branch != 1) return error.UnsupportedTransactionDomain;
        if (self.configuration.policy == .queue) {
            if (self.configuration.policy.queue.dead_letter) |destination| {
                if (!std.meta.eql(destination.object.scope, self.interpretation.object.scope) or
                    destination.object.branch != self.interpretation.object.branch or
                    std.meta.eql(destination.object, self.interpretation.object)) return error.InvalidQueueDestination;
            }
        }
    }
    pub fn requireSuccessor(self: Declaration, next: Declaration) !void {
        try self.validate();
        try next.validate();
        if (!std.meta.eql(self.interpretation.object, next.interpretation.object) or
            self.interpretation.revision == std.math.maxInt(u64) or
            next.interpretation.revision != self.interpretation.revision + 1)
            return error.LogDeclarationConflict;
        try self.configuration.requireEvolution(next.configuration);
    }
};

test "log declarations freeze routing and FIFO keys while allowing explicit policy evolution" {
    const t = std.testing;
    const configuration: Configuration = .{
        .partitioning = .{ .count = 4, .key_column = 9, .hash = .sha256_64 },
        .retention = .{ .max_age_ms = null },
        .policy = .{ .queue = .{ .ordering = .key_fifo, .key_column = 9, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } },
    };
    try configuration.validate();
    // Independent SHA-256("abc") prefix is ba7816bf8f01cfea.
    try t.expectEqual(@as(u32, 2), try configuration.partitioning.select("abc"));
    var next = configuration;
    next.retention.max_age_ms = 5000;
    try configuration.requireEvolution(next);
    next.partitioning.count = 8;
    try t.expectError(error.UnsupportedLogRepartition, configuration.requireEvolution(next));
    next = configuration;
    next.policy.queue.key_column = 10;
    try t.expectError(error.InvalidQueuePartitionKey, next.validate());
    next = configuration;
    next.retention.max_age_ms = 0;
    try t.expectError(error.InvalidLogRetention, next.validate());
}

test "queue deadlines and backoff have checked overflow and bounded attempt work" {
    const t = std.testing;
    const backoff: Backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 };
    try t.expectEqual(@as(u64, 10), try backoff.delay(1));
    try t.expectEqual(@as(u64, 80), try backoff.delay(4));
    try t.expectEqual(@as(u64, 1000), try backoff.delay(std.math.maxInt(u32)));
    try t.expectError(error.InvalidQueueAttempt, backoff.delay(0));
    const policy: Queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 100, .maximum_lease_ms = 1000, .maximum_attempts = 5, .backoff = backoff, .dead_letter = null };
    try t.expectEqual(@as(u64, 1100), try policy.deadline(1000, 100));
    try t.expectError(error.InvalidQueueLeaseDuration, policy.deadline(0, 1001));
    try t.expectError(error.QueueLeaseDeadlineOverflow, policy.deadline(std.math.maxInt(u64), 1));
}
