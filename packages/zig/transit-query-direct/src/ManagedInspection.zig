//! Read-only computation inspection shared by application adapters. All exact
//! quantities cross foreign boundaries as decimal strings; no row reader opens.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const h = c.DirectTableValues;
const v = c.TableValues;
const p = q.protocol;
pub const Request = struct {
    definition: p.Growth.Definition,
    namespace: u64,
    name: []const u8,
    expected: ?h.Interpretation,
    revision: ?[]const u8,
    pub fn native(self: Request) !c.ManagedInspection.Request {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        return .{ .namespace = self.namespace, .name = try .init(self.name), .expected = if (self.expected) |value| try value.native() else null, .revision = if (self.revision) |value| try v.unsigned(value) else null };
    }
};
pub const Binding = struct { namespace: u64, name: []const u8, interpretation: h.Interpretation };
pub const Current = struct {
    state: p.Dataflow.State,
    epoch: []const u8,
    refresh: []const u8,
    attempt: []const u8,
    pending: ?struct { account: []const u8, token: []const u8 },
    blocked: p.Dataflow.Blocked,
    retirement_complete: bool,
    storage: h.Interpretation,
    position: h.Position,
};
pub const Completed = struct {
    revision: []const u8,
    rows: []const u8,
    source: h.Interpretation,
    output: h.Interpretation,
    source_position: h.Position,
    schema: h.Content,
    manifest: h.Content,
    decision: h.TransactionDecision,
};
pub const Response = struct {
    definition: p.Growth.Definition,
    binding: Binding,
    source: Binding,
    output: Binding,
    sql: []const u8,
    current: ?Current,
    completed: ?Completed,
};
pub fn apply(allocator: std.mem.Allocator, client: c.DirectTableClient, request: Request) !Response {
    const response = try client.call(.{ .managed_inspection = try request.native() });
    defer response.deinit();
    const found = response.value.result.managed_inspection;
    const declaration = found.declaration;
    return .{
        .definition = p.Growth.current_definition,
        .binding = .{ .namespace = declaration.namespace, .name = try allocator.dupe(u8, declaration.name.slice()), .interpretation = try h.Interpretation.foreign(allocator, found.interpretation) },
        .source = try binding(allocator, declaration.source),
        .output = try binding(allocator, declaration.output),
        .sql = try allocator.dupe(u8, declaration.sql),
        .current = if (found.observation) |observation| .{
            .state = observation.head.control.state,
            .epoch = try v.decimal(allocator, observation.head.control.epoch),
            .refresh = try v.decimal(allocator, observation.head.control.refresh),
            .attempt = try v.decimal(allocator, observation.head.attempt),
            .pending = if (observation.head.pending) |key| .{ .account = try v.hex(allocator, &key.account), .token = try v.hex(allocator, &key.token) } else null,
            .blocked = observation.head.blocked,
            .retirement_complete = observation.head.retirement_complete,
            .storage = try h.Interpretation.foreign(allocator, observation.storage),
            .position = try h.Position.foreign(allocator, observation.position),
        } else null,
        .completed = if (found.completed) |completed| .{
            .revision = try v.decimal(allocator, completed.revision.metadata.revision),
            .rows = try v.decimal(allocator, completed.revision.metadata.rows),
            .source = try h.Interpretation.foreign(allocator, completed.revision.metadata.source),
            .output = try h.Interpretation.foreign(allocator, completed.revision.metadata.output),
            .source_position = try h.Position.foreign(allocator, completed.revision.metadata.source_position),
            .schema = try h.Content.foreign(allocator, completed.revision.metadata.schema),
            .manifest = try h.Content.foreign(allocator, completed.manifest.content),
            .decision = try h.TransactionDecision.foreign(allocator, completed.decision),
        } else null,
    };
}
fn binding(allocator: std.mem.Allocator, value: c.DirectTableBinding) !Binding {
    return .{ .namespace = value.namespace, .name = try allocator.dupe(u8, value.name.slice()), .interpretation = try h.Interpretation.foreign(allocator, value.interpretation.interpretation) };
}
