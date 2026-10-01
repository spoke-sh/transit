//! One-shot SQL/template compilation shared by foreign callers and workspaces.
//! Current reads bracket compilation; the result is never query admission.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const v = q.Values;
const a = q.document.JsonValues;

pub const Capabilities = struct {
    version: u8 = 1,
    parameters: bool = true,
    max_parameters: u8 = q.fuze.Prepared.max_parameters,
    statement_bytes: u32 = q.fuze.Sql.max_statement_bytes,
};
pub const Request = struct {
    scope: q.SqlInspection.Scope,
    sql: []const u8,
    parameters: ?[]const v.Scalar = null,
};
pub const Result = struct { bundle: []const u8, source: v.Source, plan: v.Plan, limits: v.Limits, contract: [32]u8, schema: [32]u8 };

/// All returned slices belong to the result allocator. Temporary source paths,
/// values, templates and native plans are released before returning, including
/// on denial, changed source, invalid binding and allocation failure.
pub fn apply(allocator: std.mem.Allocator, client: anytype, request: Request) !Result {
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const temporary = scratch.allocator();
    const definition = try request.scope.source.native(temporary);
    const name = try m.Name.init(request.scope.name);
    const limits = try request.scope.limits.native();
    const before = try client.describe(definition);
    if (!before.limits.permits(limits)) return error.QueryBudgetExceeded;

    var bound: ?q.SqlTemplate.Bound = null;
    defer if (bound) |*owner| owner.deinit();
    const bundle = if (request.parameters) |parameters| blk: {
        if (parameters.len > q.fuze.Prepared.max_parameters) return error.ParameterCountMismatch;
        var values: [q.fuze.Prepared.max_parameters]m.Scalar = undefined;
        for (parameters, 0..) |value, i| values[i] = try value.native(temporary);
        var template = try q.SqlTemplate.init(temporary, definition, name, request.sql);
        defer template.deinit();
        bound = try template.bind(temporary, definition, values[0..parameters.len], limits);
        break :blk bound.?.bundle;
    } else try q.Bundle.fromSql(temporary, definition, name, request.sql, limits);

    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const encoded = try bundle.encode(&bytes);
    const after = try client.describe(definition);
    if (!after.limits.permits(limits)) return error.QueryBudgetExceeded;
    var columns: [m.max_columns]m.Column = undefined;
    return .{
        .bundle = try a.hex(allocator, encoded),
        .source = try v.Source.fromNative(allocator, bundle.source),
        .plan = try v.Plan.fromNative(allocator, bundle.plan),
        .limits = try v.Limits.fromNative(allocator, bundle.limits),
        .contract = try definition.fingerprint(),
        .schema = try (try definition.schema(&columns)).fingerprint(),
    };
}
