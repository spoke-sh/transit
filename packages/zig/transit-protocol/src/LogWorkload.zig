//! Canonical original Stream/Queue operation identities shared by catalog and
//! storage owners. A binding is neither acceptance nor current authorization.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const read = p.StreamRead;

/// Operation categories only. Current grants remain the native policy owner's
/// responsibility; this enum neither grants nor evaluates permission.
pub const Access = enum { create, inspect, read, append, acquire, settle, administer };

pub const StreamKind = enum { append, assign, consume, release, offset };
pub const QueueKind = enum { enqueue, claim, settle, release };

/// These owner decisions are terminal for the exact frozen request. Capacity,
/// storage, authorization and clock availability failures are deliberately absent.
pub const Refusal = enum {
    producer_fenced,
    producer_receipt_expired,
    lease_fenced,
    lease_expired,

    pub fn fromError(cause: anyerror) ?Refusal {
        return switch (cause) {
            error.LogProducerFenced => .producer_fenced,
            error.LogProducerReceiptExpired => .producer_receipt_expired,
            error.QueueLeaseFenced => .lease_fenced,
            error.QueueLeaseExpired => .lease_expired,
            else => null,
        };
    }
};

/// The immutable request identity, independent of any transport or SQL token.
pub const Binding = union(enum) {
    stream: StreamBinding,
    queue: QueueBinding,

    pub fn validate(self: Binding) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
    pub fn operation(self: Binding) d.Operation {
        return switch (self) {
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: Binding) q.Partition {
        return switch (self) {
            inline else => |value| value.target,
        };
    }
    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

/// A partition-owned terminal decision that prevents admission of the bound
/// request. `recorded` is the closure's WAL position, not mutation acceptance.
/// A missing success receipt never supplies this evidence.
pub const Closure = struct {
    binding: Binding,
    recorded: d.Position,
    reason: union(enum) { cancelled, refused: Refusal },

    pub fn validate(self: Closure) !void {
        try self.binding.validate();
        try self.recorded.validate();
        if (self.recorded.next_lsn < 2) return error.InvalidLogClosure;
        if (self.reason == .refused) switch (self.reason.refused) {
            .producer_fenced, .producer_receipt_expired => switch (self.binding) {
                .stream => |value| if (value.kind != .append) return error.InvalidLogClosure,
                .queue => |value| if (value.kind != .enqueue) return error.InvalidLogClosure,
            },
            .lease_fenced, .lease_expired => if (self.binding != .queue or self.binding.queue.kind != .settle) return error.InvalidLogClosure,
        };
    }
    pub fn requireStream(self: Closure, request: StreamRequest) !void {
        try self.validate();
        var bytes: [16 * 1024]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&bytes);
        try self.binding.requireSame(.{ .stream = try request.binding(scratch.allocator()) });
    }
    pub fn requireQueue(self: Closure, request: QueueRequest) !void {
        try self.validate();
        var bytes: [16 * 1024]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&bytes);
        try self.binding.requireSame(.{ .queue = try request.binding(scratch.allocator()) });
    }
};

pub const StreamBinding = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    target: q.Partition,
    kind: StreamKind,
    intent: [32]u8,
    pub fn validate(self: StreamBinding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target.requireOperation(self.operation);
        if (std.mem.allEqual(u8, &self.intent, 0)) return error.InvalidStreamOperationBinding;
    }
    pub fn requireSame(self: StreamBinding, other: StreamBinding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

pub const QueueBinding = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    target: q.Partition,
    kind: QueueKind,
    intent: [32]u8,
    pub fn validate(self: QueueBinding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target.requireOperation(self.operation);
        if (std.mem.allEqual(u8, &self.intent, 0)) return error.InvalidQueueOperationBinding;
    }
    pub fn requireSame(self: QueueBinding, other: QueueBinding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

pub const StreamRequest = union(StreamKind) {
    append: q.Append,
    assign: q.GroupAssignment,
    consume: read.Request,
    release: read.Release,
    offset: struct {
        commit: q.OffsetCommit,
        progress: read.Progress,
        pub fn validate(self: @This()) !void {
            try self.commit.validate();
            try self.progress.validate();
            if (!std.meta.eql(self.commit.coverage, try self.progress.coverage()) or
                self.commit.operation.principal != self.progress.end().read.owner.principal)
                return error.StreamReadConflict;
        }
    },

    pub fn validate(self: StreamRequest) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
        if (self == .append and self.append.kind != .stream) return error.CatalogKindMismatch;
    }
    pub fn identity(self: StreamRequest) d.Operation {
        return switch (self) {
            .offset => |value| value.commit.operation,
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: StreamRequest) q.Partition {
        return switch (self) {
            .assign => |value| value.cut.target,
            .offset => |value| value.commit.coverage.cut.target,
            inline else => |value| value.target,
        };
    }
    pub fn access(self: StreamRequest) Access {
        return switch (self) {
            .append => .append,
            .assign => .administer,
            .consume => |value| if (value.group != null) .acquire else .read,
            .release => .read,
            .offset => .settle,
        };
    }
    pub fn control(self: StreamRequest) bool {
        return switch (self) {
            .assign => |value| value.expected != null,
            .release, .offset => true,
            .append, .consume => false,
        };
    }
    /// Payload bytes are already bound by Append.payload. Hash every remaining
    /// frozen field, including cursor authentication and exact consumer basis.
    pub fn binding(self: StreamRequest, scratch: std.mem.Allocator) !StreamBinding {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(scratch, self, 16 * 1024);
        defer scratch.free(bytes);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        digest.update("transit.catalog.stream.operation.v1\x00");
        digest.update(&p.Growth.definition_bytes);
        digest.update(bytes);
        const result: StreamBinding = .{
            .definition = p.Growth.current_definition,
            .operation = self.identity(),
            .target = self.target(),
            .kind = std.meta.activeTag(self),
            .intent = digest.finalResult(),
        };
        try result.validate();
        return result;
    }
};

pub const QueueRequest = union(QueueKind) {
    enqueue: q.Append,
    claim: q.Claim,
    settle: q.Settlement,
    release: p.QueueRead.Release,

    pub fn validate(self: QueueRequest) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
        if (self == .enqueue and self.enqueue.kind != .queue) return error.CatalogKindMismatch;
    }
    pub fn identity(self: QueueRequest) d.Operation {
        return switch (self) {
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: QueueRequest) q.Partition {
        return switch (self) {
            .settle => |value| value.lease.target,
            .release => |value| value.claim.claim.target,
            inline else => |value| value.target,
        };
    }
    pub fn access(self: QueueRequest) Access {
        return switch (self) {
            .enqueue => .append,
            .claim, .release => .acquire,
            .settle => .settle,
        };
    }
    pub fn control(self: QueueRequest) bool {
        return self == .settle or self == .release;
    }
    pub fn binding(self: QueueRequest, scratch: std.mem.Allocator) !QueueBinding {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(scratch, self, 16 * 1024);
        defer scratch.free(bytes);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        digest.update("transit.catalog.queue.operation.v1\x00");
        digest.update(&p.Growth.definition_bytes);
        digest.update(bytes);
        const result: QueueBinding = .{
            .definition = p.Growth.current_definition,
            .operation = self.identity(),
            .target = self.target(),
            .kind = std.meta.activeTag(self),
            .intent = digest.finalResult(),
        };
        try result.validate();
        return result;
    }
};

test "workload terminal refusal classification excludes uncertain and retryable failures" {
    const t = std.testing;
    try t.expectEqual(Refusal.lease_expired, Refusal.fromError(error.QueueLeaseExpired).?);
    try t.expectEqual(Refusal.lease_fenced, Refusal.fromError(error.QueueLeaseFenced).?);
    try t.expectEqual(Refusal.producer_fenced, Refusal.fromError(error.LogProducerFenced).?);
    try t.expectEqual(Refusal.producer_receipt_expired, Refusal.fromError(error.LogProducerReceiptExpired).?);
    for ([_]anyerror{ error.LogAppendUncertain, error.LogRecoveryRequired, error.OutOfMemory, error.CatalogDenied, error.PermissionDenied, error.QueueTimeUnavailable, error.LogTimeRegression, error.QueueWaitPending, error.QueueLeaseCapacity, error.LogProducerSequenceGap, error.StorageUnavailable, error.Timeout }) |cause|
        try t.expectEqual(@as(?Refusal, null), Refusal.fromError(cause));
}
