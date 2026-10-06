//! Flight's bounded projection of a currently authorized saved query outcome.
const std = @import("std");
const q = @import("root.zig").query;
const Self = @This();
namespace: u64,
phase: q.UnifiedRequest.Phase,
failure: ?q.QueryFailure,

pub fn status(self: Self) u8 {
    if (self.phase == .cancelled) return 1;
    if (self.phase == .retired) return 9;
    const failure = self.failure orelse return 13;
    return switch (failure.code) {
        .policy_denied, .access_denied, .publisher_mismatch, .peer_mismatch, .catalog_read_denied => 7,
        .catalog_owner_changed,
        .catalog_configuration_changed,
        .catalog_uninitialized,
        .table_absent,
        .table_retired,
        .table_definition_changed,
        .catalog_scope_changed,
        .definition_mismatch,
        .resource_unavailable,
        .request_unpublished,
        .document_history_gap,
        .document_retired,
        .document_resync_required,
        .source_changed,
        .table_schema_changed,
        .query_after_mutation,
        .writer_not_ready,
        .request_resource_expired,
        .request_resource_missing,
        => 9,
        .value_budget,
        .source_definition_too_large,
        .budget_exceeded,
        .projection_budget,
        .segment_byte_limit,
        .plan_too_large,
        .bundle_too_large,
        .cell_too_large,
        => 8,
        .arithmetic_overflow => 11,
        .expansion_missing,
        .expansion_null,
        .expansion_conflict,
        .expansion_type_error,
        .cell_type_error,
        .cell_conflict,
        => 9,
        .unsupported_comparison,
        .unsupported_aggregate,
        .unsupported_source,
        .unsupported_decoder,
        .unsupported_document_source,
        .unsupported_plan,
        .unsupported_schema,
        => 12,
        .namespace_in_use => 10,
        .type_mismatch,
        .unknown_column,
        .invalid_projection,
        .duplicate_projection,
        .invalid_bundle,
        .invalid_source,
        .invalid_prefix,
        .invalid_path,
        .invalid_projection_budget,
        .invalid_text_projection,
        .invalid_element_projection,
        .invalid_source_encoding,
        .invalid_plan_encoding,
        .plan_definition_mismatch,
        .invalid_output_names,
        .truncated_input,
        .invalid_budget,
        .nonfinite_value,
        .invalid_utf8,
        .invalid_column_name,
        .invalid_column_count,
        .duplicate_column,
        .invalid_request_reference,
        => 3,
    };
}

pub fn render(self: Self, out: *std.Io.Writer) !void {
    if (self.failure) |failure| {
        if (self.phase == .retired) try out.writeAll("retired ");
        try out.print("query.{s} {s} #{d}", .{ @tagName(failure.code), @tagName(failure.stage), self.namespace });
        if (failure.dimension != .none) {
            try out.print(" {s} limit={d} required={d}", .{ @tagName(failure.dimension), failure.limit, failure.observed });
        }
    } else switch (self.phase) {
        .cancelled => try out.print("query.cancelled #{d}; the saved wait was cancelled; previously disclosed results are not retracted", .{self.namespace}),
        .retired => try out.print("query.retired #{d}; the saved result is no longer available through this request", .{self.namespace}),
        else => return error.InvalidQueryDiagnostic,
    }
}

test "every retained failure fits Flight's existing bound and has an explicit status" {
    inline for (comptime std.meta.tags(q.QueryFailure.Code)) |code| {
        const failure: q.QueryFailure = .{ .code = code, .stage = .execution };
        const diagnostic: Self = .{ .namespace = q.protocol.max_counter, .phase = if (failure.denied()) .denied else .rejected, .failure = failure };
        var bytes: [128]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try diagnostic.render(&out);
        try std.testing.expect(diagnostic.status() != 0 and diagnostic.status() != 13);
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), @tagName(code)) != null);
    }
    inline for (.{ .pages, .segments, .result_bytes }) |dimension| {
        var diagnostic: Self = .{ .namespace = q.protocol.max_counter, .phase = .rejected, .failure = .{ .code = .budget_exceeded, .stage = .execution, .dimension = dimension, .limit = std.math.maxInt(u64) - 1, .observed = std.math.maxInt(u64) } };
        var bytes: [128]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try diagnostic.render(&out);
        try std.testing.expectEqual(@as(u8, 8), diagnostic.status());
        try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "required=18446744073709551615") != null);
        diagnostic.phase = .retired;
        out = .fixed(&bytes);
        try diagnostic.render(&out);
        try std.testing.expect(std.mem.startsWith(u8, out.buffered(), "retired query.budget_exceeded"));
        try std.testing.expectEqual(@as(u8, 9), diagnostic.status());
    }
}

pub fn structured(self: Self) !q.protocol.Diagnostic {
    if (self.failure) |failure| return failure.diagnostic(self.namespace, self.phase);
    const d = q.protocol.Diagnostic;
    var value = switch (self.phase) {
        .cancelled => try d.init("query.cancelled", .lifecycle, .control, .cancelled, .domain_status, "The saved query wait was cancelled. Cancellation does not retract previously disclosed results."),
        .retired => try d.init("query.retired", .lifecycle, .read, .retired, .domain_status, "The saved query was retired; its result is no longer available through this request."),
        else => return error.InvalidQueryDiagnostic,
    };
    value.identity = .{ .domain = .query, .id = .init(self.namespace) };
    try value.fact(.completion, .owner, .{ .boolean = false });
    try value.action(.inspect_status);
    return value;
}
