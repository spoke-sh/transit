//! Direct, serialized KV data owner over the common paged row engine. No PID,
//! Station turn, native-state value encoding or actor mailbox is involved.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const f = @import("transit_fuze");
const P = @import("TablePartition.zig");
const Declaration = @import("KVDeclaration.zig");
const Self = @This();

pub const max_key_bytes = 1024;
/// Reserve the largest key within the shared logical value budget. The row's
/// descriptor/identity bytes have the codec's separate encoded-byte allowance.
pub const max_value_bytes = (f.Types.Limits{}).value_bytes - max_key_bytes;
pub const max_changes = P.max_changes;
pub const Guard = P.Guard;
pub const Options = P.Options;
pub const Root = P.Root;
pub const Outcome = P.Outcome;
pub const SnapshotHandle = P.SnapshotHandle;
pub const Change = union(enum) {
    put: struct { key: []const u8, value: f.Types.Values.Cell, expect: @import("TableChanges.zig").Expect = .any },
    remove: []const u8,
};

/// Owns the decoded value; it remains valid across the next read/mutation.
pub const Value = struct {
    storage: P.OwnedRow,
    pub fn cell(self: *const Value) f.Types.Values.Cell {
        return self.storage.row().cells[1];
    }
    pub fn deinit(self: *Value) void {
        self.storage.deinit();
        self.* = undefined;
    }
};

/// Exposed to database composition, including the shared transaction owner.
/// Public adapters use this type's key/value operations and authorization.
storage: P,

pub fn init(allocator: std.mem.Allocator, partition: u64, definition: Declaration.Definition, log: @import("TransitLog.zig").Log, objects: @import("TransitObjectStore.zig").ObjectStore, options: Options) !Self {
    var selected = options;
    selected.kind = .kv;
    var columns: [2]f.TableSchema.Column = undefined;
    return .{ .storage = try P.init(allocator, partition, definition.physical(&columns), log, objects, selected) };
}

pub fn deinit(self: *Self) void {
    self.storage.deinit();
    self.* = undefined;
}

pub fn recover(self: *Self) !void {
    try self.storage.recover();
    _ = Declaration.fromPhysical(self.storage.declaration.definition) catch |err| {
        self.storage.recovery_required = true;
        return err;
    };
}

pub fn create(self: *Self, binding: d.Binding, guard: Guard) !Outcome {
    if (binding.action != .create) return error.InvalidKVOperation;
    return self.storage.apply(binding, &.{}, .point, guard);
}

pub fn encodeKey(key: []const u8, output: []u8) ![]const u8 {
    if (key.len == 0 or key.len > max_key_bytes) return error.InvalidKVKey;
    return f.Collation.encodeSortKey(.{ .value = .{ .atom = .{ .bytes = key } } }, .binary, .none, output);
}

/// One bounded batch has one accepted receipt and publication. Lowering uses
/// one batch arena, never one arena per key. Parent memory is bounded jointly
/// with the shared engine's candidate builder.
pub fn apply(self: *Self, binding: d.Binding, changes: []const Change, guard: Guard) !Outcome {
    try binding.validate();
    if (binding.action != .insert or changes.len == 0 or changes.len > max_changes) return error.InvalidKVOperation;
    var memory: f.MemoryBudget = .{ .parent = self.storage.allocator, .limit = self.storage.options.build_resident_bytes };
    return self.applyBounded(binding, changes, guard, &memory) catch |err| return if (err == error.OutOfMemory and memory.exhausted) error.KVBuildBudget else err;
}

fn applyBounded(self: *Self, binding: d.Binding, changes: []const Change, guard: Guard, memory: *f.MemoryBudget) !Outcome {
    var scratch: std.heap.ArenaAllocator = .init(memory.allocator());
    defer scratch.deinit();
    const a = scratch.allocator();
    const lowered = try a.alloc(P.Change, changes.len);
    const schema = self.storage.declaration.schema.schema;
    const field = schema.columns[1].field();
    for (changes, lowered, 0..) |change, *out, ordinal| switch (change) {
        .put => |value| {
            if (value.key.len == 0 or value.key.len > max_key_bytes) return error.InvalidKVKey;
            if (value.value == .value and value.value.value == .atom and value.value.value.atom == .bytes and value.value.value.atom.bytes.len > max_value_bytes) return error.KVValueTooLarge;
            try value.value.validate(field, .{});
            const cells = try a.alloc(f.Types.Values.Cell, 2);
            cells[0] = .{ .value = .{ .atom = .{ .bytes = value.key } } };
            cells[1] = value.value;
            out.* = .{ .put = .{ .row = .{ .identity = .{ .origin = binding.identity.principal + 1, .operation = binding.identity.operation, .ordinal = @intCast(ordinal) }, .cells = cells }, .expect = value.expect } };
        },
        .remove => |key| {
            var encoded: [f.Collation.max_sort_key_bytes]u8 = undefined;
            out.* = .{ .remove = try a.dupe(u8, try encodeKey(key, &encoded)) };
        },
    };
    const budget = self.storage.options.build_resident_bytes;
    if (memory.used >= budget) return error.KVBuildBudget;
    self.storage.options.build_resident_bytes = budget - memory.used;
    defer self.storage.options.build_resident_bytes = budget;
    return self.storage.apply(binding, lowered, .point, guard);
}

pub fn observe(self: *Self, binding: d.Binding, guard: Guard) !?P.Evidence {
    return self.storage.observeEvidence(binding, guard);
}

pub fn get(self: *Self, allocator: std.mem.Allocator, key: []const u8, guard: Guard) !?Value {
    var encoded: [f.Collation.max_sort_key_bytes]u8 = undefined;
    return .{ .storage = try self.storage.get(allocator, try encodeKey(key, &encoded), guard) orelse return null };
}

pub fn pin(self: *Self, owner: d.Operation, expected: d.Position, guard: Guard) !SnapshotHandle {
    return self.storage.pin(owner, expected, guard);
}

pub fn readSnapshot(self: *Self, allocator: std.mem.Allocator, source: SnapshotHandle, key: []const u8, guard: Guard) !?Value {
    var encoded: [f.Collation.max_sort_key_bytes]u8 = undefined;
    return .{ .storage = try self.storage.readSnapshot(allocator, source, try encodeKey(key, &encoded), guard) orelse return null };
}

pub fn releaseSnapshot(self: *Self, source: SnapshotHandle, guard: Guard) !void {
    return self.storage.releaseSnapshot(source, guard);
}
