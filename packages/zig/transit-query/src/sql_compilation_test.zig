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

test "structured workspace rejects a malformed saved token before dispatch" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const fixtures = (try std.json.parseFromSlice(Fixture, alloc, fixture_bytes, .{})).value;
    const scope = fixtures.cases[0].request.scope;
    var wire = q.station.client.Client.init(alloc, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var client: q.UnifiedClient = .{ .wire = &wire, .connection = .{ .realm = 1, .principal = 17, .source = 2, .resource = scope.source.resource, .requester = 3, .requests = 7 }, .key = try q.protocol.Ed25519.KeyPair.generateDeterministic(@splat(9)) };
    var detail: ?q.protocol.Diagnostic = null;
    try t.expectError(error.InvalidQueryRequest, q.Workspace.applyStructured(alloc, &client, .{ .name = scope.name, .source = scope.source, .limits = scope.limits }, .{ .submit = .{ .token = "{}" } }, &detail));
    try t.expectEqual(.not_submitted, detail.?.outcome);
    try t.expectEqual(.local_before_dispatch, detail.?.evidence);
    try t.expectEqual(@as(?q.protocol.Diagnostic.Identity, null), detail.?.identity);
}

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
        var columns: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
        const schema = try definition.schema(&columns);
        const explicit: q.Bundle = .{ .source = definition, .plan = try case.plan.native(alloc, schema, try definition.fingerprint()), .limits = limits };
        const literal = try q.Bundle.fromSql(alloc, definition, case.request.scope.name, case.literal_sql, limits);
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const actual = try v.unhex(alloc, result.bundle, q.Bundle.max_bytes);
        try t.expectEqualSlices(u8, try explicit.encode(&bytes), actual);
        try t.expectEqualSlices(u8, try literal.encode(&bytes), actual);
        const returned: q.Bundle = .{ .source = try result.source.native(alloc), .plan = try result.plan.native(alloc, schema, try definition.fingerprint()), .limits = try result.limits.native() };
        try t.expectEqualSlices(u8, try returned.encode(&bytes), actual);
        try t.expectEqualSlices(u8, &try definition.fingerprint(), &result.contract);
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
    try t.expectEqualStrings("owned", restored.plan.predicate.compare.value.bytes);
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
    request.parameters = &.{ .{ .signed = "0" }, .{ .signed = "2" } };
    try t.expectError(error.TypeMismatch, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = &.{ .{ .signed = "0" }, .{ .unsigned = "02" } };
    try t.expectError(error.InvalidIntegerEncoding, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = &.{ .{ .signed = "0" }, .{ .unsigned = "2" }, .{ .unsigned = "3" }, .{ .unsigned = "4" } };
    try t.expectError(error.ParameterCountMismatch, q.SqlCompilation.apply(alloc, &client, request));
    request.parameters = null;
    try t.expectError(error.UnboundParameters, q.SqlCompilation.apply(alloc, &client, request));
    const old_request = (try std.json.parseFromSlice(q.Workspace.Request, alloc, "{\"compile\":{\"sql\":\"SELECT value FROM items\"}}", .{})).value;
    try t.expectEqual(null, old_request.compile.parameters);
}

test "neutral compilation retains original parameter context without admitting work" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const fixtures = (try std.json.parseFromSlice(Fixture, alloc, fixture_bytes, .{})).value;
    var request = fixtures.cases[0].request;
    request.sql = "SELECT value FROM items WHERE value = $1 LIMIT $2";
    request.parameters = &.{ .{ .signed = "1" }, .{ .unsigned = "02" } };
    var client: ReadOnlyClient = .{};
    var detail: q.fuze.Sql.Binding = .{};
    try t.expectError(error.InvalidIntegerEncoding, q.SqlCompilation.applyDiagnostic(alloc, &client, request, &detail));
    try t.expectEqual(@as(usize, 1), client.reads);
    try t.expectEqual(@as(?u32, 2), detail.parameter);
    try t.expectEqualStrings("uint64", detail.expected.?);
    const diagnostic = q.fuze.SqlDiagnostic.bound(request.sql, error.InvalidIntegerEncoding, true, detail).?;
    try t.expect(std.mem.indexOf(u8, diagnostic.detail[0..diagnostic.detail_len], "02") != null);
    for ([_]struct { value: v.Scalar, preview: []const u8 }{
        .{ .value = .{ .signed = "2" }, .preview = "2" },
        .{ .value = .{ .signed = "-170141183460469231731687303715884105728" }, .preview = "-170141183460469231731687303715884105728" },
        .{ .value = .{ .timestamp_micros = "-1" }, .preview = "-1 microseconds since epoch" },
        .{ .value = .{ .interval = .{ .months = "1", .days = "2", .nanos = "3" } }, .preview = "1 months, 2 days, 3 ns" },
        .{ .value = .{ .interval = .{ .months = "1", .days = "bad\x1b\n", .nanos = "3" } }, .preview = "days: \"bad\\x1b\\x0a\"" },
    }) |case| {
        request.parameters = &.{ .{ .signed = "1" }, case.value };
        const before = client.reads;
        if (q.SqlCompilation.applyDiagnostic(alloc, &client, request, &detail)) |_| return error.AcceptedWrongParameter else |_| {}
        try t.expectEqual(before + 1, client.reads);
        try t.expectEqual(@as(?u32, 2), detail.parameter);
        try t.expectEqualStrings(case.preview, detail.literal[0..detail.literal_len]);
        try t.expectEqualStrings(@tagName(case.value), detail.actual.?);
    }
    request.parameters = &.{};
    try t.expectError(error.ParameterCountMismatch, q.SqlCompilation.applyDiagnostic(alloc, &client, request, &detail));
    try t.expectEqual(@as(?usize, 2), detail.expected_count);
    try t.expectEqual(@as(?usize, 0), detail.actual_count);
    request.sql = "SELECT unknown_column FROM items";
    request.parameters = null;
    try t.expectError(error.UnknownColumn, q.SqlCompilation.applyDiagnostic(alloc, &client, request, &detail));
    try t.expectEqualStrings("unknown_column", detail.subject.?.slice());
    try t.expectEqual(null, detail.parameter);
}
