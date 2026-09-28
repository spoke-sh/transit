//! Explicit empty-Table composition for a local query installation. The owning
//! Station activation initializes metadata and policy; this is not kernel DDL.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const Self = @This();
pub const Configuration = struct {
    peer: u64,
    initializer: u64,
    requests: u64,
    table: u32 = 1,
    key_name: []const u8 = "id",
    value_name: []const u8 = "value",
    limits: q.Bundle.Limits,
    pub fn definition(self: Configuration, resource: u64) !q.SourceDefinition {
        const result: q.SourceDefinition = .{ .resource = resource, .source = .{ .table = .{ .id = self.table, .schema = .{ .names = .{ try .init(self.key_name), try .init(self.value_name) }, .value_type = .int64 } } } };
        _ = try result.fingerprint();
        try self.limits.validate();
        try q.UnifiedRecords.identity(self.peer);
        try q.UnifiedRecords.identity(self.initializer);
        try q.UnifiedRecords.identity(self.requests);
        return result;
    }
};
configuration: Configuration,
source: *q.UnifiedBehavior.Source,
pub fn interface(self: *Self) s.GrowingGenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
fn initialize(raw: ?*anyopaque, turn: *s.GrowingTurn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (self.source.peer != self.configuration.peer or self.source.initializer != self.configuration.initializer) return error.QueryConfigurationChanged;
    const before = turn.decision;
    errdefer turn.decision = before;
    const definition = try self.configuration.definition(turn.view.resource);
    _ = try s.Table.create(turn, definition.source.table.id, definition.source.table.schema);
    try q.UnifiedCapture.setPolicy(turn, .{ .peer = self.configuration.peer, .requests = self.configuration.requests, .revision = 1, .allow = true, .limits = self.configuration.limits, .declaration = try q.Bundle.declaration(definition) });
    const source = self.source.interface();
    try source.initialize.?(source.context, turn);
    try turn.validate();
}
fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    try q.UnifiedSource.checkCurrent(try self.configuration.definition(turn.view.resource), turn);
    const source = self.source.interface();
    return source.handle(source.context, turn, frame);
}
test "empty local Table initialization is atomic, bounded and refuses existing metadata" {
    const t = std.testing;
    var store: q.testing.Store = .{};
    defer store.deinit();
    var source: q.UnifiedBehavior.Source = .{ .peer = 9, .initializer = 10, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = undefined };
    var table: Self = .{ .source = &source, .configuration = .{ .peer = 9, .initializer = 10, .requests = 8, .limits = .{ .pages = 100, .segments = 10, .result_bytes = 65536 } } };
    var turn = try store.capture();
    try initialize(&table, &turn);
    var count: usize = 0;
    for (turn.decision.mutations) |mutation| if (mutation != null) {
        count += 1;
    };
    try t.expectEqual(3, count);
    try store.commit(turn);
    turn = try store.capture();
    const opened = try s.Table.open(&turn, 1);
    try t.expectEqual(.int64, opened.schema.value_type);
    try t.expectEqual(null, try opened.get(&turn, 0));
    const policy = (try q.UnifiedCapture.policy(&turn, 9)).?;
    try t.expect(policy.allow);
    try t.expectEqual(8, policy.requests);
    try t.expectEqualSlices(u8, &try q.Bundle.declaration(try table.configuration.definition(turn.view.resource)), &policy.declaration);
    try t.expectError(error.TableExists, initialize(&table, &turn));
    for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
}
