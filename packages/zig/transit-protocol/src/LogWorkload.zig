//! Canonical original Stream/Queue operation identities shared by catalog and
//! storage owners. A binding is neither acceptance nor current authorization.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const q = p.StreamQueue;

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
