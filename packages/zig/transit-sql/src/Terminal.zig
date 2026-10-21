//! Attributed terminal facts copied from public Table outcomes. Detailed native
//! witnesses remain with the Table owner and require a fresh authorized read.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const Self = @This();
pub const magic = "GST1";
kind: enum(u8) { ddl = 1, dml = 2, upload = 3 },
identity: [32]u8,
resource: u64,
principal: u64,
operation: u64,
object: u64,
admitted_input: u64,
completed_input: u64,
state: enum(u8) { applied = 1, unchanged = 2, rejected = 3, cancelled = 4, upload_cancelled = 5 },
reason: u8 = 0,
matched: u64 = 0,
changed: u64 = 0,
actual_object: u64 = 0,
route: u8 = 0,
pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > p.max_counter or self.principal > p.max_counter or self.operation == 0 or self.admitted_input == 0 or self.admitted_input > p.max_counter or self.completed_input > p.max_counter or self.changed > self.matched) return error.InvalidGatewayTerminal;
    if (self.kind == .upload) {
        if (self.state != .upload_cancelled or self.completed_input != 0 or self.reason != 0 or self.matched != 0 or self.changed != 0 or self.actual_object != 0 or self.route != 0) return error.InvalidGatewayTerminal;
        return;
    }
    if (self.completed_input < self.admitted_input or (self.state == .rejected) != (self.reason != 0) or (self.state != .applied and (self.matched != 0 or self.changed != 0))) return error.InvalidGatewayTerminal;
    switch (self.kind) {
        .ddl => {
            if (self.state == .upload_cancelled or (self.route != 0 and self.route != 3) or self.matched != 0 or self.changed != 0 or self.reason > @as(u8, if (self.route == 3) 7 else 5) or (self.state == .applied and (self.object == 0 or self.actual_object != self.object)) or (self.route == 3 and (self.object == 0 or self.state == .unchanged))) return error.InvalidGatewayTerminal;
        },
        .dml => {
            if (self.object == 0 or self.state == .unchanged or self.state == .upload_cancelled or self.route < 1 or self.route > 2 or self.reason > 7 or self.actual_object != 0 or (self.route == 1 and self.matched > 1)) return error.InvalidGatewayTerminal;
        },
        .upload => unreachable,
    }
}
pub fn fromOutcome(outcome: c.TableClient.Outcome) !Self {
    if (!outcome.terminal()) return error.GatewayOperationNotTerminal;
    const result: Self = switch (outcome) {
        .ddl => |v| blk: {
            const value = v.operation;
            try value.validate();
            if (v.table) |table| {
                try table.validate();
                if (value.state != .delegated or table.route != .alter or !std.meta.eql(table.reference, try value.tableReference()) or table.admitted_input < value.admitted_input) return error.InvalidGatewayTerminal;
                break :blk .{ .kind = .ddl, .identity = value.digest, .resource = value.scope.resource, .principal = value.principal, .operation = value.operation, .object = value.object, .admitted_input = value.admitted_input, .completed_input = table.completed_input, .state = switch (table.state) {
                    .applied => .applied,
                    .rejected => .rejected,
                    .cancelled => .cancelled,
                    .building => return error.GatewayOperationNotTerminal,
                }, .reason = @backingInt(table.rejection), .actual_object = value.actual_object, .route = 3 };
            }
            break :blk .{ .kind = .ddl, .identity = value.digest, .resource = value.scope.resource, .principal = value.principal, .operation = value.operation, .object = value.object, .admitted_input = value.admitted_input, .completed_input = value.completed_input, .state = switch (value.state) {
                .applied => .applied,
                .unchanged => .unchanged,
                .rejected => .rejected,
                .cancelled => .cancelled,
                else => return error.GatewayOperationNotTerminal,
            }, .reason = @backingInt(value.reason), .actual_object = value.actual_object };
        },
        .dml => |value| blk: {
            try value.validate();
            break :blk .{ .kind = .dml, .identity = value.reference.digest, .resource = value.reference.resource, .principal = value.reference.principal, .operation = value.reference.operation, .object = value.reference.object, .admitted_input = value.admitted_input, .completed_input = value.completed_input, .state = switch (value.state) {
                .applied => .applied,
                .rejected => .rejected,
                .cancelled => .cancelled,
                else => return error.GatewayOperationNotTerminal,
            }, .reason = @backingInt(value.rejection), .matched = value.matched, .changed = value.changed, .route = @backingInt(value.route) };
        },
    };
    try result.validate();
    return result;
}
pub fn fromUpload(value: c.TableUpload.Status) !Self {
    try value.validate();
    if (value.namespace != value.header.operation) return error.GatewayIdentityConflict;
    if (value.phase != .cancelled) return error.GatewayOperationNotTerminal;
    const result: Self = .{ .kind = .upload, .identity = value.spec.digest, .resource = value.header.scope.resource, .principal = value.header.principal, .operation = value.header.operation, .object = value.header.object, .admitted_input = value.admitted_input, .completed_input = 0, .state = .upload_cancelled };
    try result.validate();
    return result;
}
pub fn matches(self: Self, binding: c.TableIntent.Binding) !void {
    try self.validate();
    const h = binding.header;
    if ((self.object == 0 and h.kind != .drop) or (self.kind == .ddl and self.route == 3 and h.kind != .alter)) return error.GatewayIdentityConflict;
    if (self.operation != h.operation or self.principal != h.principal or self.resource != h.scope.resource or self.object != h.object or self.admitted_input <= self.operation) return error.GatewayIdentityConflict;
    const digest = switch (self.kind) {
        .ddl => if (binding.identity == .ddl) binding.identity.ddl.digest else return error.GatewayIdentityConflict,
        .dml => if (binding.identity == .dml and self.route == @backingInt(binding.identity.dml.route)) binding.identity.dml.reference.digest else return error.GatewayIdentityConflict,
        .upload => binding.spec.digest,
    };
    if (!std.mem.eql(u8, &self.identity, &digest)) return error.GatewayIdentityConflict;
}
pub fn summary(self: Self) g.LedgerRecords.Summary {
    return switch (self.state) {
        .applied, .unchanged => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .upload_cancelled => .upload_cancelled,
    };
}
