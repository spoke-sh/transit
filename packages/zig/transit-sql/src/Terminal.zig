//! Compact projection of the direct owner's terminal evidence. A SQL progress
//! record grants no disclosure rights: callers reobserve the original binding.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Self = @This();
pub const magic = "GST1";
kind: enum(u8) { ddl = 1, dml = 2, catalog_assertion = 3, namespace_change = 4, log_declaration = 5 },
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
    if (self.kind == .namespace_change or self.kind == .log_declaration) {
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
    if (reference == .branch) return error.BranchOperationRequired;
    if (reference == .workload) return error.WorkloadOperationRequired;
    if (reference == .external) return error.ExternalOperationOwnerRequired;
    if (reference == .transaction or reference == .transaction_call) return error.TransactionOperationRequired;
    if (reference == .table) return fromResult(reference.table.binding, result);
    if (reference == .log) {
        const evidence = switch (result) {
            .log_admitted => |value| value,
            .log_operation => |observed| switch (observed) {
                .not_observed => return null,
                .operation => |value| value,
            },
            else => return error.InvalidGatewayTerminal,
        };
        try evidence.validate();
        const binding = reference.log.binding;
        try binding.requireSame(evidence.binding);
        if (evidence.kind != reference.log.kind or evidence.namespace != reference.log.namespace) return error.InvalidGatewayTerminal;
        if (evidence.pending()) return null;
        const value: Self = .{
            .kind = .log_declaration,
            .identity = try reference.digest(),
            .resource = binding.identity.scope.resource,
            .principal = binding.identity.principal,
            .operation = binding.identity.operation,
            .object = binding.target.object,
            .state = switch (evidence.phase) {
                .complete => .applied,
                .rejected => .rejected,
                .cancelled => .cancelled,
                .admitted, .initializing => unreachable,
            },
            .reason = @backingInt(evidence.reason),
            .partition = evidence.position.partition,
            .next_lsn = evidence.position.next_lsn,
            .resulting_revision = if (evidence.phase == .complete) evidence.resulting.?.stored.declaration.interpretation.revision else 0,
        };
        try value.validate();
        return value;
    }
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
pub fn summary(self: Self) g.OperationRecords.Summary {
    return switch (self.state) {
        .applied => .applied,
        .rejected => .rejected,
        .cancelled => .cancelled,
        .unchanged => .unchanged,
    };
}

/// Project already verified owner evidence for native and database adapters.
/// The SQL operation identity is distinct from the direct owner's operation.
pub fn completion(self: Self, command: g.results.Command, operation: g.results.Operation) !g.results.CommandCompletion {
    try self.validate();
    const expected: @FieldType(Self, "kind") = switch (command) {
        .insert, .update, .delete => .dml,
        .create_table, .drop_table => if (self.kind == .catalog_assertion) .catalog_assertion else .ddl,
        .alter_table => .ddl,
        .create_schema, .alter_schema, .drop_schema => .namespace_change,
        .create_stream, .alter_stream, .drop_stream, .create_queue, .alter_queue, .drop_queue => .log_declaration,
        else => return error.InvalidGatewayTerminal,
    };
    if (self.kind != expected) return error.InvalidGatewayTerminal;
    const result: g.results.CommandCompletion = .{
        .kind = command,
        .outcome = switch (self.state) {
            .applied => .applied,
            .unchanged => .unchanged,
            .rejected => .rejected,
            .cancelled => .cancelled,
        },
        .counts = .{ .matched = self.matched, .changed = self.changed },
        .operation = operation,
        .pending_restart = false,
        .diagnostic = null,
    };
    try result.validate();
    return result;
}

test "log declaration projection preserves pending and rejected original evidence" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
    const connection: w.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
    const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 55 }, .target = .{ .scope = scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = @splat(9) };
    const reference: g.IntentReference.Reference = .{ .log = .{ .connection = connection, .namespace = 1, .kind = .queue, .binding = binding, .record = .{ .scope = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(8) }, .format = c.DirectLogIntent.format, .content = .{ .bytes = 100, .sha256 = @splat(4) } } } };
    var evidence: c.DirectLog.Operation = .{ .binding = binding, .intent = .{ .bytes = 100, .sha256 = @splat(5) }, .kind = .queue, .namespace = 1, .name = try .init("work"), .owner = 0, .position = .{ .partition = 1, .next_lsn = 8 }, .phase = .admitted, .reason = .none, .first_partition = 11, .partition_count = 2, .initialized = 0, .resulting = null };
    try t.expect(try fromReference(reference, .{ .log_operation = .not_observed }) == null);
    try t.expect(try fromReference(reference, .{ .log_operation = .{ .operation = evidence } }) == null);
    try t.expect(try fromReference(reference, .{ .log_admitted = evidence }) == null);
    evidence.phase = .rejected;
    evidence.reason = .name_conflict;
    const terminal = (try fromReference(reference, .{ .log_operation = .{ .operation = evidence } })).?;
    try t.expectEqualDeep(terminal, (try fromReference(reference, .{ .log_admitted = evidence })).?);
    try t.expectEqual(.rejected, terminal.state);
    const completion_value = try terminal.completion(try g.IntentReference.commandKind(reference), .{ .account = @splat(8), .id = 99 });
    try t.expectEqual(.create_queue, completion_value.kind);
    try t.expectEqual(.rejected, completion_value.outcome);
    try t.expectEqual(@as(u64, 0), terminal.resulting_revision);
    try t.expectError(error.InvalidGatewayTerminal, terminal.completion(.create_table, completion_value.operation.?));
    evidence.kind = .stream;
    try t.expectError(error.InvalidGatewayTerminal, fromReference(reference, .{ .log_operation = .{ .operation = evidence } }));
    evidence.kind = .queue;
    evidence.binding.identity.operation += 1;
    try t.expectError(error.DataIdentityConflict, fromReference(reference, .{ .log_operation = .{ .operation = evidence } }));
}

test "command projection preserves matched and changed counts and the SQL identity" {
    const t = std.testing;
    var terminal: Self = .{ .kind = .dml, .identity = @splat(3), .resource = 1, .principal = 2, .operation = 55, .object = 4, .state = .applied, .matched = 7, .changed = 0, .partition = 1, .next_lsn = 9, .resulting_revision = 2 };
    const operation: g.results.Operation = .{ .account = @splat(8), .id = 99 };
    const completion_value = try terminal.completion(.update, operation);
    try t.expectEqualDeep(operation, completion_value.operation.?);
    try t.expectEqual(.update, completion_value.kind);
    try t.expectEqualDeep(g.results.Counts{ .matched = 7, .changed = 0 }, completion_value.counts.?);
    try t.expectError(error.InvalidGatewayTerminal, terminal.completion(.create_table, operation));
    terminal.changed = 8;
    try t.expectError(error.InvalidGatewayTerminal, terminal.completion(.update, operation));
    terminal = .{ .kind = .catalog_assertion, .identity = @splat(3), .resource = 1, .principal = 2, .operation = 55, .object = 0, .state = .unchanged, .partition = 1, .next_lsn = 9 };
    const absent = try terminal.completion(.drop_table, operation);
    try t.expectEqual(.unchanged, absent.outcome);
    try t.expectEqualDeep(g.results.Counts{ .matched = 0, .changed = 0 }, absent.counts.?);
    try t.expectError(error.InvalidGatewayTerminal, terminal.completion(.alter_table, operation));
}
