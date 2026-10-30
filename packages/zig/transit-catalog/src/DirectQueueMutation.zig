//! Frozen Queue work in the catalog's common operation namespace. An identity
//! reservation grants no rights and establishes no Queue acceptance.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueue;

pub const Request = union(enum) {
    enqueue: q.Append,
    claim: q.Claim,
    settle: q.Settlement,

    pub fn validate(self: Request) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
        if (self == .enqueue and self.enqueue.kind != .queue) return error.CatalogKindMismatch;
    }
    pub fn identity(self: Request) d.Operation {
        return switch (self) {
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: Request) q.Partition {
        return switch (self) {
            .settle => |value| value.lease.target,
            inline else => |value| value.target,
        };
    }
    pub fn access(self: Request) c.LogAuthority.Access {
        return switch (self) {
            .enqueue => .append,
            .claim => .acquire,
            .settle => .settle,
        };
    }
    pub fn control(self: Request) bool {
        return self == .settle;
    }
    pub fn binding(self: Request, scratch: std.mem.Allocator) !Binding {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(scratch, self, 16 * 1024);
        defer scratch.free(bytes);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        digest.update("transit.catalog.queue.operation.v1\x00");
        digest.update(&p.Growth.definition_bytes);
        digest.update(bytes);
        const result: Binding = .{
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

pub const Binding = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    target: q.Partition,
    kind: std.meta.Tag(Request),
    intent: [32]u8,
    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target.requireOperation(self.operation);
        if (std.mem.allEqual(u8, &self.intent, 0)) return error.InvalidQueueOperationBinding;
    }
    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};
