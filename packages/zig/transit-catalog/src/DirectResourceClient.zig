//! Typed named-resource calls over the common catalog connection. Every method
//! bounds its exchanges and preserves the original binding. The application
//! persists the binding before admission and initializes through its framework
//! owner after allocation; inspection never enters either execution path.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const r = c.DirectResource;
const Self = @This();

catalog: c.DirectTableClient,

pub fn save(allocator: std.mem.Allocator, binding: r.Binding) ![]u8 {
    try binding.validate();
    const bytes = try p.Json.valueAlloc(allocator, binding);
    errdefer allocator.free(bytes);
    if (bytes.len > c.OperationBinding.max_bytes) return error.InvalidNamedResourceOperation;
    return bytes;
}

pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !r.Binding {
    if (bytes.len == 0 or bytes.len > c.OperationBinding.max_bytes) return error.InvalidNamedResourceOperation;
    const parsed = try p.Json.parseFromSlice(r.Binding, allocator, bytes);
    defer parsed.deinit();
    try parsed.value.validate();
    return parsed.value;
}

pub fn operation(self: Self, binding: r.Binding, command: r.Command, steps: u16) !r.Observation {
    try binding.validate();
    if (!std.meta.eql(binding.connection, self.catalog.connection)) return error.CatalogIdentityConflict;
    if (steps == 0 or steps > 256) return error.InvalidCatalogStepBudget;
    var signed_allocation: ?r.SignedAllocation = null;
    if (command == .execute and binding.action == .create) {
        // Read the already-persisted sequence. Never choose a new one because a
        // response was lost or another native command consumed this sequence.
        const current = try self.request(binding, .inspect, 1, null);
        if (current == .operation and current.operation.phase == .prepared) {
            const allocation = current.operation.allocation.?;
            const signed = try p.Growth.sign(try binding.allocation(allocation), self.catalog.key);
            signed_allocation = .{ .allocation = allocation, .signature = signed.signature };
        }
    }
    return self.request(binding, command, steps, signed_allocation);
}

pub fn preview(self: Self, binding: r.Binding) !r.Preview {
    const response = try self.catalog.call(.{ .resource_preview = binding });
    defer response.deinit();
    return response.value.result.resource_preview;
}

fn request(self: Self, binding: r.Binding, command: r.Command, steps: u16, signed_allocation: ?r.SignedAllocation) !r.Observation {
    const response = try self.catalog.call(.{ .resource_operation = .{ .binding = binding, .command = command, .steps = steps, .signed_allocation = signed_allocation } });
    defer response.deinit();
    return response.value.result.resource_operation;
}

pub fn lookup(self: Self, namespace: u64, name: []const u8) !?c.DirectCatalog.ResourceView {
    const response = try self.catalog.call(.{ .resource_lookup = .{ .namespace = namespace, .name = name } });
    defer response.deinit();
    return response.value.result.resource_lookup;
}

pub fn list(self: Self, namespace: u64, after: ?u64) !@FieldType(c.DirectTableProtocol.Result, "resource_list") {
    const response = try self.catalog.call(.{ .resource_list = .{ .namespace = namespace, .after = after } });
    defer response.deinit();
    return response.value.result.resource_list;
}
