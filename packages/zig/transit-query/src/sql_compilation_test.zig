const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const m = q.fuze.Unified;
const v = q.Values;
const Fixture = struct {
    version: u8,
    cases: []const struct { name: []const u8, request: q.SqlCompilation.Request, plan: v.Plan, literal_sql: []const u8 },
};
const fixture_bytes = @embedFile("fixtures/sql-compilation-v1.json");

// This boundary cannot dispatch, create a snapshot or allocate a sequence.
const ReadOnlyClient = struct {
    reads: usize = 0,
    deny_at: ?usize = null,
    shrink_at: ?usize = null,
    changed_at: ?usize = null,
    pub fn describe(self: *@This(), source: q.SourceDefinition) !q.UnifiedClient.Description {
        self.reads += 1;
        if (self.deny_at == self.reads) return error.QueryDenied;
        if (self.changed_at == self.reads) return error.QuerySourceChanged;
        return .{ .definition = source, .resource_revision = 42, .policy_revision = self.reads, .limits = .{ .pages = if (self.shrink_at == self.reads) 1 else 30, .segments = 40, .result_bytes = 8192 }, .active = null };
    }
};

test "neutral compilation fixtures retain exact scalar bytes and ordinary bundle identity" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const fixtures = (try std.json.parseFromSlice(Fixture, alloc, fixture_bytes, .{})).value;
    try t.expectEqual(1, fixtures.version);
    for (fixtures.cases) |case| {
        var client: ReadOnlyClient = .{};
        const result = try q.SqlCompilation.apply(alloc, &client, case.request);
        try t.expectEqual(2, client.reads);
        const definition = try case.request.scope.source.native(alloc);
        const limits = try case.request.scope.limits.native();
        const explicit: q.Bundle = .{ .source = definition, .plan = try case.plan.native(alloc), .limits = limits };
        const literal = try q.Bundle.fromSql(alloc, definition, try .init(case.request.scope.name), case.literal_sql, limits);
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const actual = try v.unhex(alloc, result.bundle, q.Bundle.max_bytes);
        try t.expectEqualSlices(u8, try explicit.encode(&bytes), actual);
        try t.expectEqualSlices(u8, try literal.encode(&bytes), actual);
        const returned: q.Bundle = .{ .source = try result.source.native(alloc), .plan = try result.plan.native(alloc), .limits = try result.limits.native() };
        try t.expectEqualSlices(u8, try returned.encode(&bytes), actual);
        try t.expectEqualSlices(u8, &try definition.fingerprint(), &result.contract);
        var columns: [m.max_columns]m.Column = undefined;
        try t.expectEqualSlices(u8, &try (try definition.schema(&columns)).fingerprint(), &result.schema);

        // The generated neutral envelopes and workspace share the same values.
        const wire = try std.json.Stringify.valueAlloc(alloc, q.Bridge.Action{ .compile = case.request }, .{});
        const action = (try std.json.parseFromSlice(q.Bridge.Action, alloc, wire, .{})).value;
        try t.expectEqualStrings(case.request.sql, action.compile.sql);
        const workspace_wire = try std.json.Stringify.valueAlloc(alloc, q.Workspace.Request{ .compile = .{ .sql = case.request.sql, .parameters = case.request.parameters } }, .{});
        const workspace = (try std.json.parseFromSlice(q.Workspace.Request, alloc, workspace_wire, .{})).value;
        try t.expectEqualStrings(case.request.sql, workspace.compile.sql);
    }
}

fn owned(allocator: std.mem.Allocator) !void {
    var result_arena = std.heap.ArenaAllocator.init(allocator);
    defer result_arena.deinit();
    const alloc = result_arena.allocator();
    var request_arena = std.heap.ArenaAllocator.init(allocator);
    var request_alive = true;
    defer if (request_alive) request_arena.deinit();
    const fixtures = (try std.json.parseFromSlice(Fixture, request_arena.allocator(), fixture_bytes, .{ .allocate = .alloc_always })).value;
    var client: ReadOnlyClient = .{};
    const result = try q.SqlCompilation.apply(alloc, &client, fixtures.cases[fixtures.cases.len - 1].request);
    request_arena.deinit();
    request_alive = false;
    try t.expectEqualStrings("body", result.source.source.document.projections[0].path[0]);
    try t.expectEqualStrings("owned", result.plan.predicate.compare.value.utf8);
    const restored = try q.Bundle.decode(alloc, try v.unhex(alloc, result.bundle, q.Bundle.max_bytes));
    try t.expectEqualStrings("body", restored.source.source.document.projections[0].path[0].slice());
    try t.expectEqualStrings("owned", restored.plan.predicate.compare.value.utf8);
    const foreign = try std.json.Stringify.valueAlloc(alloc, q.Bridge.Result{ .compiled = result }, .{});
    _ = try std.json.parseFromSlice(q.Bridge.Result, alloc, foreign, .{});
}
test "compiled neutral results outlive all request owners and release on allocation failure" {
    try owned(t.allocator);
    try t.checkAllAllocationFailures(t.allocator, owned, .{});
}

test "neutral compilation rejects at either current check and never returns a candidate" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const fixtures = (try std.json.parseFromSlice(Fixture, alloc, fixture_bytes, .{})).value;
    for (fixtures.cases) |case| {
        for (1..3) |at| {
            var denied: ReadOnlyClient = .{ .deny_at = at };
            try t.expectError(error.QueryDenied, q.SqlCompilation.apply(alloc, &denied, case.request));
            try t.expectEqual(at, denied.reads);
            var limited: ReadOnlyClient = .{ .shrink_at = at };
            try t.expectError(error.QueryBudgetExceeded, q.SqlCompilation.apply(alloc, &limited, case.request));
            try t.expectEqual(at, limited.reads);
            var replaced: ReadOnlyClient = .{ .changed_at = at };
            try t.expectError(error.QuerySourceChanged, q.SqlCompilation.apply(alloc, &replaced, case.request));
            try t.expectEqual(at, replaced.reads);
        }
    }
    var request = fixtures.cases[0].request;
    request.sql = "invalid syntax";
    request.parameters = &.{};
    var denied: ReadOnlyClient = .{ .deny_at = 1 };
    try t.expectError(error.QueryDenied, q.SqlCompilation.apply(alloc, &denied, request));
}

test "neutral compilation validates binding shape and does not reinterpret ordinary SQL" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const fixtures = (try std.json.parseFromSlice(Fixture, alloc, fixture_bytes, .{})).value;
    var request = fixtures.cases[0].request;
    var client: ReadOnlyClient = .{};
    request.parameters = &.{};
    try t.expectError(error.ParameterCountMismatch, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = &.{ .{ .int64 = "0" }, .{ .int64 = "2" } };
    try t.expectError(error.TypeMismatch, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = &.{ .{ .int64 = "0" }, .{ .uint64 = "02" } };
    try t.expectError(error.InvalidDocumentInteger, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = &.{ .{ .int64 = "0" }, .{ .uint64 = "2" }, .{ .uint64 = "3" }, .{ .uint64 = "4" } };
    try t.expectError(error.ParameterCountMismatch, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = null;
    try t.expectError(error.UnsupportedConstruct, q.SqlCompilation.apply(alloc, &client, request));
    const old_request = (try std.json.parseFromSlice(q.Workspace.Request, alloc, "{\"compile\":{\"sql\":\"SELECT value FROM items\"}}", .{})).value;
    try t.expectEqual(null, old_request.compile.parameters);
}
