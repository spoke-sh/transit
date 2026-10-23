//! One-shot SQL/template compilation shared by foreign callers and workspaces.
//! Current reads bracket compilation; the result is never query admission.
const std = @import("std");
const q = @import("root.zig");
const v = q.Values;
const a = q.document.JsonValues;

pub const Capabilities = struct {
    version: u8 = 1,
    parameters: bool = true,
    max_parameters: u8 = q.fuze.LogicalPrepared.max_parameters,
    statement_bytes: u32 = q.fuze.Sql.max_statement_bytes,
};
pub const Request = struct {
    pub const json_schema_sequence_bounds = .{ .parameters = q.fuze.LogicalPrepared.max_parameters };
    scope: q.SqlInspection.Scope,
    sql: []const u8,
    parameters: ?[]const v.Scalar = null,
};
pub const Result = struct { bundle: []const u8, source: v.Source, plan: v.Plan, limits: v.Limits, contract: [32]u8, schema: [32]u8 };

/// All returned slices belong to the result allocator. Temporary source paths,
/// values, templates and native plans are released before returning, including
/// on denial, changed source, invalid binding and allocation failure.
pub fn apply(allocator: std.mem.Allocator, client: anytype, request: Request) !Result {
    return applyDiagnostic(allocator, client, request, null);
}
pub fn applyDiagnostic(allocator: std.mem.Allocator, client: anytype, request: Request, detail: ?*q.fuze.Sql.Binding) !Result {
    if (detail) |value| value.* = .{};
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const temporary = scratch.allocator();
    const definition = try request.scope.source.native(temporary);
    const name = request.scope.name;
    const limits = try request.scope.limits.native();
    const before = try client.describe(definition);
    if (!before.limits.permits(limits)) return error.QueryBudgetExceeded;

    var bound: ?q.SqlTemplate.Bound = null;
    defer if (bound) |*owner| owner.deinit();
    const description = if (request.parameters) |parameters| blk: {
        var template = try q.SqlTemplate.initDiagnostic(temporary, definition, name, request.sql, detail);
        defer template.deinit();
        if (parameters.len != template.parameterTypes().len) {
            if (detail) |value| {
                value.expected_count = template.parameterTypes().len;
                value.actual_count = parameters.len;
            }
            return error.ParameterCountMismatch;
        }
        var values: [q.fuze.LogicalPrepared.max_parameters]q.fuze.Types.Values.Atom = undefined;
        for (parameters, 0..) |value, i| values[i] = v.scalar(temporary, value, template.parameterTypes()[i]) catch |err| {
            if (detail) |context| {
                context.parameter = @intCast(i + 1);
                if (template.template.sites[i]) |site| {
                    context.parameter_sites[0] = site.offset;
                    context.location = .{ .offset = site.offset };
                }
                context.expected = @tagName(template.parameterTypes()[i]);
                context.actual = @tagName(value);
                supplied(context, value);
            }
            return err;
        };
        bound = try template.bindDiagnostic(temporary, definition, values[0..parameters.len], limits, detail);
        break :blk bound.?.bundle;
    } else try q.Bundle.fromSqlDiagnostic(temporary, definition, name, request.sql, limits, detail);

    const after = try client.describe(definition);
    if (!after.limits.permits(limits)) return error.QueryBudgetExceeded;
    const bundle = description;
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    const encoded = try bundle.encode(&bytes);
    var columns: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
    return .{
        .bundle = try a.hex(allocator, encoded),
        .source = try v.Source.fromNative(allocator, bundle.source),
        .plan = try v.Plan.fromNative(allocator, bundle.plan),
        .limits = try v.Limits.fromNative(allocator, bundle.limits),
        .contract = try definition.fingerprint(),
        .schema = try (try definition.schema(&columns)).fingerprint(),
    };
}

/// A wrong expected descriptor must not turn a valid number into quoted text.
/// Decode only the caller's atom family into bounded scratch; malformed or
/// oversized encodings retain escaped original bytes instead of a guessed value.
fn supplied(context: *q.fuze.Sql.Binding, value: v.Scalar) void {
    const kind: q.fuze.Types.Type = switch (value) {
        .signed => .int128,
        .unsigned => .uint128,
        .decimal => .{ .decimal = .{ .precision = 38, .scale = 0 } },
        .float_bits => |bytes| if (bytes.len == 8) .float32 else .float64,
        .boolean => .boolean,
        .utf8 => .utf8,
        .binary => .binary,
        .date_days => .date,
        .time_nanos => .time,
        .timestamp_micros => .{ .timestamp = .civil },
        .interval => .interval,
        .uuid => .uuid,
    };
    var bytes: [64]u8 = undefined;
    var scratch: std.heap.FixedBufferAllocator = .init(&bytes);
    const atom = v.scalar(scratch.allocator(), value, kind) catch {
        switch (value) {
            .boolean => unreachable,
            .interval => |parts| {
                // Name the original malformed component without interpolating
                // arbitrary input into the terminal or omitting its context.
                inline for (.{ "months", "days", "nanos" }, .{ q.fuze.Types.Type.int32, .int32, .int64 }) |field, field_type| {
                    _ = v.scalar(scratch.allocator(), .{ .signed = @field(parts, field) }, field_type) catch {
                        q.fuze.Sql.Binding.supplied(context, q.fuze.Unified.Scalar{ .utf8 = @field(parts, field) });
                        const length = context.literal_len;
                        std.mem.copyBackwards(u8, context.literal[field.len + 2 ..][0..length], context.literal[0..length]);
                        @memcpy(context.literal[0..field.len], field);
                        @memcpy(context.literal[field.len..][0..2], ": ");
                        context.literal_len += field.len + 2;
                        return;
                    };
                }
                unreachable;
            },
            inline else => |raw| q.fuze.Sql.Binding.supplied(context, q.fuze.Unified.Scalar{ .utf8 = raw }),
        }
        return;
    };
    q.fuze.Sql.Binding.suppliedLogical(context, atom);
}
