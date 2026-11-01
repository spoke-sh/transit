//! One metered, temporary log participant owned by the catalog transaction host.
//! The caller supplies current policy guards, owns the common publication fence
//! and meters this owner's lifetime. No cache, descriptor or helper grants rights.
const std = @import("std");
const c = @import("root.zig");
const s = c.storage;
const p = c.protocol;
const x = p.Transaction;
const Self = @This();

pub const Options = struct {
    stream: s.StreamPartition.Options = .{},
    queue: s.QueuePartition.Options = .{},
};

pub const Owners = union(enum) { stream: s.StreamPartition, queue: s.QueuePartition };
definition: c.DirectLog.Definition,
owner: Owners,

/// The caller has already checked the catalog identity and its current rights.
/// Recovery does not consult a current clock, authenticate old cursor keys or
/// remove an unresolved preparation barrier.
pub fn open(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, definition: c.DirectLog.Definition, ordinal: u32, guard_value: s.PublicationGuard, options: Options) !Self {
    const initial = try definition.genesis(ordinal);
    var result: Self = .{ .definition = definition, .owner = undefined };
    switch (definition.kind()) {
        .stream => {
            var configured = options.stream;
            configured.clock = null;
            configured.transaction_control = true;
            configured.control = .{ .log = catalog.store.log, .objects = catalog.store.objects };
            result.owner = .{ .stream = try s.StreamPartition.open(allocator, catalog.data_log, catalog.data_objects, initial, guard_value, configured) };
        },
        .queue => {
            var configured = options.queue;
            configured.clock = null;
            configured.transaction_control = true;
            configured.control = .{ .log = catalog.store.log, .objects = catalog.store.objects };
            result.owner = .{ .queue = try s.QueuePartition.open(allocator, catalog.data_log, catalog.data_objects, initial, guard_value, configured) };
        },
    }
    errdefer result.deinit();
    switch (result.owner) {
        inline else => |*owner| while (!(try owner.recoverStep(guard_value, 256)).complete) {},
    }
    return result;
}
pub fn deinit(self: *Self) void {
    switch (self.owner) {
        inline else => |*owner| owner.deinit() catch unreachable,
    }
    self.* = undefined;
}
pub fn root(self: *const Self) s.StreamPartition.Root {
    return switch (self.owner) {
        .stream => |owner| owner.root,
        .queue => |owner| owner.owner.root,
    };
}
pub fn basis(self: *const Self) !x.LogGuard {
    var current = self.root();
    try current.requireDeclaration(self.definition.stored);
    if (current.transaction != null) return error.TransactionPrepared;
    current.declared = self.definition.stored;
    return s.LogTransaction.logGuard(current);
}
pub fn pinState(self: *Self, identity: p.DataLifecycle.Operation, guard_value: s.PublicationGuard) !s.LogTransaction.PinState {
    if (self.root().transaction != null) return error.TransactionPrepared;
    return switch (self.owner) {
        inline else => |*owner| owner.transactionPinState(identity, guard_value),
    };
}
pub fn pin(self: *Self, identity: x.Identity, position: p.DataLifecycle.Position, guard_value: s.PublicationGuard) !x.Pin {
    return switch (self.owner) {
        inline else => |*owner| owner.pinTransactionSource(self.definition.stored, identity, position, guard_value),
    };
}
pub fn inspect(self: *Self, handle: x.Pin, guard_value: s.PublicationGuard) !s.LogTransaction.Source {
    return switch (self.owner) {
        inline else => |*owner| owner.inspectTransactionSource(handle, guard_value),
    };
}
pub fn release(self: *Self, handle: x.Pin, guard_value: s.PublicationGuard) !void {
    return switch (self.owner) {
        inline else => |*owner| owner.releaseTransactionSource(handle, guard_value),
    };
}
