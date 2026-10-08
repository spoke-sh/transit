//! Caller-owned SQL template bound to the complete source definition. No
//! retained snapshot, signed upload, durable prepared state or admission.
const std = @import("std");
const q = @import("root.zig");
const t = q.fuze.Types;
const Self = @This();

template: q.fuze.LogicalPrepared,
definition: [32]u8,

pub const Bound = struct {
    storage: q.fuze.LogicalPlanCodec.Owned,
    bundle: q.Bundle,
    pub fn deinit(self: *Bound) void {
        self.storage.deinit();
        self.* = undefined;
    }
};

/// Pure compilation for an explicitly supplied definition. This records its
/// exact fingerprint, including resource, decoder/path and Document revision.
pub fn init(allocator: std.mem.Allocator, definition: q.SourceDefinition, name: []const u8, text: []const u8) !Self {
    return initDiagnostic(allocator, definition, name, text, null);
}
pub fn initDiagnostic(allocator: std.mem.Allocator, definition: q.SourceDefinition, name: []const u8, text: []const u8, detail: ?*q.fuze.Sql.Binding) !Self {
    if (detail) |value| value.* = .{};
    const fingerprint = try definition.fingerprint();
    var columns: [q.SourceDefinition.max_columns]t.Field = undefined;
    return .{
        .template = try q.fuze.LogicalPrepared.init(allocator, text, name, try definition.schema(&columns), fingerprint, detail),
        .definition = fingerprint,
    };
}

pub fn deinit(self: *Self) void {
    self.template.deinit();
    self.* = undefined;
}

pub fn parameterTypes(self: *const Self) []const t.Type {
    return self.template.parameterTypes();
}

/// Every returned source/plan byte belongs to Bound, independently of both the
/// template and supplied values/definition. Callers still own current admission.
pub fn bind(self: *const Self, allocator: std.mem.Allocator, definition: q.SourceDefinition, values: []const t.Values.Atom, limits: q.Bundle.Limits) !Bound {
    return self.bindDiagnostic(allocator, definition, values, limits, null);
}
pub fn bindDiagnostic(self: *const Self, allocator: std.mem.Allocator, definition: q.SourceDefinition, values: []const t.Values.Atom, limits: q.Bundle.Limits, detail: ?*q.fuze.Sql.Binding) !Bound {
    if (detail) |value| value.* = .{};
    try limits.validate();
    if (!std.mem.eql(u8, &self.definition, &try definition.fingerprint())) return error.QuerySourceChanged;
    var columns: [q.SourceDefinition.max_columns]t.Field = undefined;
    var storage = try self.template.bind(allocator, self.template.name, try definition.schema(&columns), self.definition, values, detail);
    errdefer storage.deinit();
    var bytes: [q.SourceDefinition.max_bytes]u8 = undefined;
    const source = try q.SourceDefinition.decode(storage.descriptor.arena.allocator(), try definition.encode(&bytes));
    const bundle: q.Bundle = .{ .source = source, .plan = storage.plan, .limits = limits };
    try bundle.validate();
    return .{ .storage = storage, .bundle = bundle };
}

/// The generic read-only boundary is also used by UnifiedClient. Tests can
/// revoke permission between checks without providing any submission method.
pub fn prepareCurrent(allocator: std.mem.Allocator, client: anytype, definition: q.SourceDefinition, name: []const u8, text: []const u8) !Self {
    _ = try client.describe(definition);
    var result = try init(allocator, definition, name, text);
    errdefer result.deinit();
    _ = try client.describe(definition);
    return result;
}

pub fn bindCurrent(self: *const Self, allocator: std.mem.Allocator, client: anytype, definition: q.SourceDefinition, values: []const t.Values.Atom, limits: q.Bundle.Limits) !Bound {
    const before = try client.describe(definition);
    if (!before.limits.permits(limits)) return error.QueryBudgetExceeded;
    var result = try self.bind(allocator, definition, values, limits);
    errdefer result.deinit();
    const after = try client.describe(definition);
    if (!after.limits.permits(limits)) return error.QueryBudgetExceeded;
    return result;
}
