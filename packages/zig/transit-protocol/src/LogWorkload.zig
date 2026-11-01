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
        cursor: read.Cursor,
        pub fn validate(self: @This()) !void {
            try self.commit.validate();
            try self.cursor.validate();
            if (!std.meta.eql(self.commit.coverage, self.cursor.coverage) or
                self.commit.operation.principal != self.cursor.read.owner.principal)
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
