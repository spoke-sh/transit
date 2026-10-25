//! Compact projection of the direct owner's terminal evidence. A SQL ledger
//! record grants no disclosure rights: callers reobserve the original binding.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Self = @This();
pub const magic = "GST1";
kind: enum(u8) { ddl = 1, dml = 2, catalog_assertion = 3, namespace_change = 4 },
identity: [32]u8,
resource: u64,
principal: u64,
operation: u64,
object: u64,
state: enum(u8) { applied = 1, rejected = 2, cancelled = 3, unchanged = 4 },
reason: u8 = 0,
matched: u64 = 0,
changed: u64 = 0,
partition: u64 = 0,
next_lsn: u64 = 0,
resulting_revision: u64 = 0,

pub fn validate(self: Self) !void {
    if (self.resource == 0 or self.resource > p.max_counter or self.principal > p.max_counter or self.operation == 0 or (self.object == 0 and self.kind != .catalog_assertion) or self.changed > self.matched or std.mem.allEqual(u8, &self.identity, 0)) return error.InvalidGatewayTerminal;
    if ((self.state == .rejected) != (self.reason != 0) or self.reason > 6) return error.InvalidGatewayTerminal;
    if (self.kind == .namespace_change) {
        if (self.state == .unchanged or self.reason > 4 or self.partition == 0 or self.next_lsn == 0 or (self.state == .applied) != (self.resulting_revision != 0) or self.matched != 0 or self.changed != 0) return error.InvalidGatewayTerminal;
        return;
    }
    if (self.kind == .catalog_assertion) {
        if (self.state == .applied or self.reason > 1 or self.partition == 0 or self.next_lsn == 0 or self.resulting_revision != 0 or self.matched != 0 or self.changed != 0) return error.InvalidGatewayTerminal;
        return;
    }
    if (self.state == .unchanged) return error.InvalidGatewayTerminal;
    if (self.state == .applied) {
        if (self.partition == 0 or self.next_lsn == 0 or self.resulting_revision == 0) return error.InvalidGatewayTerminal;
    } else if (self.matched != 0 or self.changed != 0 or self.partition != 0 or self.next_lsn != 0 or self.resulting_revision != 0) return error.InvalidGatewayTerminal;
    if (self.kind == .ddl and (self.matched != 0 or self.changed != 0)) return error.InvalidGatewayTerminal;
}
pub fn fromReference(reference: g.IntentReference.Reference, result: w.Result) !?Self {
    try reference.validate();
    if (reference == .table) return fromResult(reference.table.binding, result);
    if (reference == .namespace_change) {
        if (result != .namespace_operation) return error.InvalidGatewayTerminal;
        const evidence = switch (result.namespace_operation) {
            .not_observed => return null,
            .operation => |value| value,
        };
        try evidence.validate();
        const binding = reference.namespace_change.binding;
        try binding.requireSame(evidence.binding);
        if (evidence.phase == .admitted) return null;
        const value: Self = .{
            .kind = .namespace_change,
            .identity = try reference.digest(),
            .resource = binding.connection.scope.resource,
            .principal = binding.connection.principal,
            .operation = binding.operation,
            .object = binding.namespace,
            .state = switch (evidence.phase) {
                .applied => .applied,
                .rejected => .rejected,
                .cancelled => .cancelled,
                .admitted => unreachable,
            },
            .reason = @backingInt(evidence.reason),
            .partition = evidence.position.partition,
            .next_lsn = evidence.position.next_lsn,
            .resulting_revision = if (evidence.resulting) |schema| schema.revision else 0,
        };
        try value.validate();
        return value;
    }
    if (result != .name_assertion) return error.InvalidGatewayTerminal;
    const evidence = switch (result.name_assertion) {
        .not_observed => return null,
        .outcome => |value| value,
    };
    const binding = reference.name_assertion;
    try evidence.validate();
    try binding.requireSame(evidence.binding);
    const value: Self = .{
        .kind = .catalog_assertion,
        .identity = try reference.digest(),
        .resource = binding.connection.scope.resource,
        .principal = binding.connection.principal,
        .operation = binding.operation,
        .object = if (binding.expected) |expected| expected.object.object else 0,
        .state = switch (evidence.state) {
            .unchanged => .unchanged,
            .rejected => .rejected,
            .cancelled => .cancelled,
        },
        .reason = @backingInt(evidence.reason),
        .partition = evidence.position.partition,
        .next_lsn = evidence.position.next_lsn,
    };
    try value.validate();
    return value;
}
fn base(binding: d.Binding) !Self {
    try binding.validate();
    return .{ .kind = switch (binding.action) {
        .create, .alter, .rename, .drop => .ddl,
        .insert, .update, .delete => .dml,
    }, .identity = try g.IntentReference.bindingDigest(binding), .resource = binding.identity.scope.resource, .principal = binding.identity.principal, .operation = binding.identity.operation, .object = binding.target.object, .state = .applied };
}
pub fn fromResult(binding: d.Binding, result: w.Result) !?Self {
    var value = try base(binding);
    if ((value.kind == .ddl and result != .ddl) or (value.kind == .dml and result != .rows)) return error.InvalidGatewayTerminal;
    switch (result) {
        inline .ddl, .rows => |observation| switch (observation) {
            .not_observed, .admitted => return null,
            .committed => |evidence| {
                try binding.requireSame(evidence.binding);
                try evidence.resulting.validate();
                try evidence.outcome.position.validate();
                const expected_revision = switch (binding.action) {
                    .create => @as(u64, 1),
                    .alter, .rename, .drop => try std.math.add(u64, binding.expected_definition.?.revision, 1),
                    else => binding.expected_definition.?.revision,
                };
                if (!std.meta.eql(binding.target, evidence.resulting.interpretation.object) or evidence.resulting.interpretation.revision != expected_revision or evidence.resulting.retired != (binding.action == .drop)) return error.InvalidGatewayTerminal;
                if (value.kind == .dml and !std.meta.eql(binding.expected_definition.?, evidence.resulting.interpretation)) return error.InvalidGatewayTerminal;
                if (binding.expected_data) |expected| if (evidence.outcome.position.partition != expected.partition or evidence.outcome.position.next_lsn <= expected.next_lsn) return error.InvalidGatewayTerminal;
                value.partition = evidence.outcome.position.partition;
                value.next_lsn = evidence.outcome.position.next_lsn;
                value.resulting_revision = evidence.resulting.interpretation.revision;
                value.matched = evidence.outcome.matched;
                value.changed = evidence.outcome.affected;
            },
            inline .rejected, .cancelled => |operation, tag| {
                try binding.requireSame(operation.binding);
                if (!std.mem.eql(u8, @tagName(operation.phase), @tagName(tag))) return error.InvalidGatewayTerminal;
                value.state = if (tag == .rejected) .rejected else .cancelled;
                value.reason = @backingInt(operation.reason);
            },
        },
        else => return error.InvalidGatewayTerminal,
    }
    try value.validate();
    return value;
}
pub fn matches(self: Self, binding: d.Binding) !void {
    try self.validate();
    const expected = try base(binding);
    if (self.kind != expected.kind or !std.mem.eql(u8, &self.identity, &expected.identity) or self.resource != expected.resource or self.principal != expected.principal or self.operation != expected.operation or self.object != expected.object) return error.GatewayIdentityConflict;
}
pub fn summary(self: Self) g.LedgerRecords.Summary {
    return switch (self.state) {
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .unchanged => .unchanged,
    };
}
