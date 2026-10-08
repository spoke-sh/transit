const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const m = q.fuze.Unified;
const limits: q.Bundle.Limits = .{ .pages = 30, .segments = 40, .result_bytes = 8192 };
const text = "SELECT value AS chosen FROM items WHERE value = $1 LIMIT $2";
const document_path = [_]q.document.Model.Name{q.document.Model.Name.init("body") catch unreachable};
const document_projections = [_]q.SourceDefinition.Projection{.{
    .column = .{ .name = m.Name.init("value") catch unreachable, .type = .utf8 },
    .path = &document_path,
}};

fn sources() ![3]q.SourceDefinition {
    return .{
        .{ .resource = 7, .source = .{ .kv = .{ .prefix = try q.protocol.Value.init("data/"), .key = .{ .type = .int64 }, .value = .{ .type = .utf8 } } } },
        .{ .resource = 7, .source = .{ .table = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .owner = 3, .object = 9, .metadata = .{ .id = 1, .spec = .{ .format = q.catalog.TableMetadata.format, .length = 200, .digest = @splat(1) } }, .row_type = .{ .structure = &.{ .{ .name = "id", .type = .int64 }, .{ .name = "value", .type = .utf8, .nullable = true } } } } } },
        .{ .resource = 7, .source = .{ .document = .{
            .reference = .{ .resource = 7, .document = 13, .epoch = 3, .type_revision = 1, .revision = 42 },
            .projections = &document_projections,
        } } },
    };
}

test "templates bind complete source identity even when schemas are unchanged" {
    for (try sources()) |source| {
        var prepared = try q.SqlTemplate.init(t.allocator, source, "items", text);
        defer prepared.deinit();
        try t.expectEqualDeep(@as([]const q.fuze.Types.Type, &.{ .utf8, .uint64 }), prepared.parameterTypes());
        var bound = try prepared.bind(t.allocator, source, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits);
        defer bound.deinit();
        var bytes: [q.Bundle.max_bytes]u8 = undefined;
        const saved = try bound.bundle.encode(&bytes);
        var expected_arena = std.heap.ArenaAllocator.init(t.allocator);
        defer expected_arena.deinit();
        const literal = try q.Bundle.fromSql(expected_arena.allocator(), source, "items", "SELECT value AS chosen FROM items WHERE value = 'owned' LIMIT 3", limits);
        var expected: [q.Bundle.max_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, try literal.encode(&expected), saved);
        const restored = try q.Bundle.decode(expected_arena.allocator(), saved);
        try t.expectEqualSlices(u8, saved, try restored.encode(&expected));
        var replacement = source;
        replacement.resource += 1;
        if (replacement.source == .document) replacement.source.document.reference.resource = replacement.resource;
        if (replacement.source == .table) replacement.source.table.scope.resource = replacement.resource;
        try t.expectError(error.QuerySourceChanged, prepared.bind(t.allocator, replacement, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits));
        replacement = source;
        switch (replacement.source) {
            .kv => |*kv| kv.prefix = try q.protocol.Value.init("other/"),
            .table => |*table| table.object += 1,
            .document => |*document| document.reference.revision += 1,
        }
        if (source.source == .document) try t.expectEqualSlices(u8, &try q.Bundle.declaration(source), &try q.Bundle.declaration(replacement));
        try t.expectError(error.QuerySourceChanged, prepared.bind(t.allocator, replacement, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits));
        if (source.source == .document) {
            var alternate_path = [_]q.document.Model.Name{try .init("elsewhere")};
            var alternate_projection = document_projections;
            alternate_projection[0].path = &alternate_path;
            replacement = source;
            replacement.source.document.projections = &alternate_projection;
            try t.expectError(error.QuerySourceChanged, prepared.bind(t.allocator, replacement, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits));
        }
    }
}

fn owned(allocator: std.mem.Allocator) !void {
    var path = [_]q.document.Model.Name{try .init("body")};
    var projection = [_]q.SourceDefinition.Projection{.{ .column = .{ .name = try .init("value"), .type = .utf8 }, .path = &path }};
    var source = (try sources())[2];
    source.source.document.projections = &projection;
    var prepared = try q.SqlTemplate.init(allocator, source, "items", text);
    var alive = true;
    defer if (alive) prepared.deinit();
    var value = "it's owned".*;
    var bound = try prepared.bind(allocator, source, &.{ .{ .bytes = &value }, .{ .unsigned = 1 } }, limits);
    defer bound.deinit();
    prepared.deinit();
    alive = false;
    @memset(&value, 0);
    path[0] = try .init("replaced");
    projection[0].column.name = try .init("changed");
    try t.expectEqualStrings("body", bound.bundle.source.source.document.projections[0].path[0].slice());
    try t.expectEqualStrings("value", bound.bundle.source.source.document.projections[0].column.name.slice());
    try t.expectEqualStrings("it's owned", bound.bundle.plan.predicate.compare.value.bytes);
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    _ = try bound.bundle.encode(&bytes);
}
test "bound bundles own source paths and values through released inputs and allocation failures" {
    try owned(t.allocator);
    try t.checkAllAllocationFailures(t.allocator, owned, .{});
}

const ReadOnlyClient = struct {
    reads: usize = 0,
    deny_at: ?usize = null,
    shrink_at: ?usize = null,
    pub fn describe(self: *@This(), source: q.SourceDefinition) !q.UnifiedClient.Description {
        self.reads += 1;
        if (self.deny_at == self.reads) return error.QueryDenied;
        var permitted = limits;
        if (self.shrink_at == self.reads) permitted.pages = 1;
        return .{ .definition = source, .resource_revision = 42, .policy_revision = self.reads, .limits = permitted, .active = null };
    }
};
test "current preparation and binding require current rights and final budgets without dispatch" {
    const source = (try sources())[1];
    var client: ReadOnlyClient = .{};
    var prepared = try q.SqlTemplate.prepareCurrent(t.allocator, &client, source, "items", text);
    defer prepared.deinit();
    try t.expectEqual(2, client.reads);
    var bound = try prepared.bindCurrent(t.allocator, &client, source, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits);
    defer bound.deinit();
    try t.expectEqual(4, client.reads);
    for (1..3) |deny_at| {
        client = .{ .deny_at = deny_at };
        try t.expectError(error.QueryDenied, q.SqlTemplate.prepareCurrent(t.allocator, &client, source, "items", text));
        try t.expectEqual(deny_at, client.reads);
        client = .{ .deny_at = deny_at };
        try t.expectError(error.QueryDenied, prepared.bindCurrent(t.allocator, &client, source, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits));
        try t.expectEqual(deny_at, client.reads);
        client = .{ .shrink_at = deny_at };
        try t.expectError(error.QueryBudgetExceeded, prepared.bindCurrent(t.allocator, &client, source, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, limits));
        try t.expectEqual(deny_at, client.reads);
    }
    client = .{ .deny_at = 1 };
    try t.expectError(error.QueryDenied, q.SqlTemplate.prepareCurrent(t.allocator, &client, source, "items", "invalid syntax"));
    client = .{ .deny_at = 1 };
    try t.expectError(error.QueryDenied, prepared.bindCurrent(t.allocator, &client, source, &.{}, limits));
    var invalid = limits;
    invalid.pages = 0;
    try t.expectError(error.InvalidQueryBudget, prepared.bind(t.allocator, source, &.{ .{ .bytes = "owned" }, .{ .unsigned = 3 } }, invalid));
}
