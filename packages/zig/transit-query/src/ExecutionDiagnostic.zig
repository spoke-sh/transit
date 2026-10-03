//! Owned evidence from the failing computation. Callers authorize disclosure;
//! this projection performs no reads and never turns a local failure into a
//! durable receipt. Stored row values are deliberately excluded.
const std = @import("std");
const q = @import("root.zig");
const m = q.fuze.Unified;
const d = q.protocol.Diagnostic;

pub fn local(cause: anyerror, bound: m.Plan.Bound, page: *const q.UnifiedSource.Batch, failed: m.Stream.Failure) !d {
    if (failed.page_row >= page.count or failed.column >= page.column_count or failed.row == 0 or !std.meta.eql(page.basis, bound.basis)) return error.InvalidExecutionDiagnostic;
    if (page.keys[failed.page_row]) |key| switch (key) {
        .kv => if (bound.basis.kind != .kv) return error.InvalidExecutionDiagnostic,
        .table => if (bound.basis.kind != .table) return error.InvalidExecutionDiagnostic,
        .element => if (bound.basis.kind != .document) return error.InvalidExecutionDiagnostic,
    };
    const failure = q.QueryFailure.fromError(cause, .execution) orelse return error.UnmappedQueryDiagnostic;
    const code = switch (failure.code) {
        inline else => |code| "query." ++ @tagName(code),
    };
    var result = try d.init(code, failure.category(), .execute, .not_applicable, .none, failure.message());
    try result.text(.operation, .execution, @tagName(failed.operation));
    try result.fact(.source_row, .execution, .{ .unsigned = .init(failed.row) });
    try result.text(.column, .schema, (try bound.schema.column(failed.column)).name.slice());
    try result.text(.expected_type, .schema, @tagName((try bound.schema.column(failed.column)).type));
    try result.text(.source_kind, .execution, @tagName(bound.basis.kind));
    try result.fact(.object, .execution, .{ .unsigned = .init(bound.basis.resource) });
    try result.fact(.expected_revision, .execution, .{ .unsigned = .init(bound.basis.revision) });
    try result.fact(.source_basis, .execution, .{ .digest = bound.fingerprint });
    if (failed.instruction) |instruction| try result.fact(.expression, .execution, .{ .unsigned = .init(instruction) });
    if (page.keys[failed.page_row]) |key| switch (key) {
        .table => |value| try result.fact(.source_key, .execution, .{ .signed = .init(value) }),
        .kv => |value| {
            var buffer: [256]u8 = undefined;
            const prefix = value.slice()[0..@min(value.len, buffer.len / 2)];
            const text = try std.fmt.bufPrint(&buffer, "{x}", .{prefix});
            try result.add(.{ .field = .source_key, .origin = .execution, .availability = if (prefix.len < value.len) .truncated else .provided, .value = .{ .text = try d.Text.init(text) } });
        },
        .element => |id| {
            var buffer: [64]u8 = undefined;
            try result.text(.source_key, .execution, try std.fmt.bufPrint(&buffer, "{d}:{d}", .{ id.counter, id.replica }));
        },
    } else try result.absent(.source_key, .execution, .inapplicable);
    if (page.decoding[failed.page_row][failed.column]) |decoder| {
        try result.text(.native_cause, .execution, @tagName(decoder.reason));
        // Lengths accompany the decoding rule, not a dump of stored bytes.
        if (decoder.expected_bytes) |expected| try result.fact(.expected_count, .execution, .{ .unsigned = .init(expected) });
        try result.fact(.actual_count, .execution, .{ .unsigned = .init(decoder.actual_bytes) });
    }
    try result.fact(.completion, .execution, .{ .boolean = false });
    try result.action(.correct_input);
    try result.validate();
    return result;
}

pub fn budget(dimension: q.QueryFailure.Dimension, limit: u64, required: u64) !d {
    const cause: q.QueryFailure = .{ .code = .budget_exceeded, .stage = .execution, .dimension = dimension, .limit = limit, .observed = required };
    try cause.validate();
    var value = try d.init("query.budget_exceeded", .limit, .execute, .not_applicable, .none, cause.message());
    try value.text(.budget, .owner, @tagName(dimension));
    try value.fact(.limit, .execution, .{ .unsigned = .init(limit) });
    try value.fact(.required, .execution, .{ .unsigned = .init(required) });
    try value.fact(.completion, .execution, .{ .boolean = false });
    try value.action(.correct_input);
    return value;
}

test "runtime envelope owns exact keys and decoder evidence without stored values" {
    const t = std.testing;
    const columns = [_]m.Column{.{ .name = try m.Name.init("amount"), .type = .int64 }};
    const schema: m.Schema = .{ .columns = &columns };
    const basis: m.Basis = .{ .kind = .kv, .resource = 9, .revision = 17, .contract = @splat(2), .schema = try schema.fingerprint() };
    const bound = try (m.Plan{ .projection = &.{0}, .aggregate = .sum }).bind(basis, schema);
    var page: q.UnifiedSource.Batch = .{ .basis = basis, .column_count = 1, .count = 1 };
    page.columns[0] = columns[0];
    page.keys[0] = .{ .kv = try q.protocol.Value.init("\x1b\x00key") };
    page.cells[0][0] = try q.Decoder.decodeDiagnostic(.{ .type = .int64 }, t.allocator, "private-value", &page.decoding[0][0]);
    const value = try local(error.QueryTypeError, bound, &page, .{ .operation = .sum, .row = 12, .page_row = 0, .column = 0 });
    page.keys[0] = null;
    try t.expectEqualStrings("1b006b6579", value.facts[8].?.value.?.text.slice());
    try t.expectEqualStrings("invalid_length", value.facts[9].?.value.?.text.slice());
    try t.expectEqual(@as(u64, 8), try value.facts[10].?.value.?.unsigned.value());
    try t.expectEqual(@as(u64, 13), try value.facts[11].?.value.?.unsigned.value());
    var bytes: [d.max_json_bytes]u8 = undefined;
    const encoded = try value.encode(&bytes);
    try t.expect(std.mem.indexOf(u8, encoded, "private-value") == null);
    try t.expectEqualDeep(value, try d.decode(t.allocator, encoded));
    page.keys[0] = .{ .table = std.math.minInt(i64) };
    page.decoding[0][0] = null;
    var table_basis = basis;
    table_basis.kind = .table;
    page.basis = table_basis;
    const table_bound = try bound.plan.bind(table_basis, schema);
    const table_key = try local(error.Overflow, table_bound, &page, .{ .operation = .sum, .row = 12, .page_row = 0, .column = 0 });
    try t.expectEqual(std.math.minInt(i64), try table_key.facts[8].?.value.?.signed.value());
}
