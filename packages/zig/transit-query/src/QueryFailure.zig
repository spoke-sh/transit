//! Source-owned stable finite-query failure codes. No payload or credentials.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Self = @This();
pub const Stage = enum(u8) { admission = 1, execution = 2 };
pub const Dimension = enum(u8) { none = 0, pages = 1, segments = 2, result_bytes = 3 };
pub const Code = enum(u16) {
    policy_denied = 1,
    access_denied = 2,
    resource_unavailable = 3,
    request_unpublished = 4,
    publisher_mismatch = 5,
    document_history_gap = 6,
    document_retired = 7,
    document_resync_required = 8,
    budget_exceeded = 9,
    projection_budget = 10,
    expansion_missing = 11,
    expansion_null = 12,
    expansion_conflict = 13,
    expansion_type_error = 14,
    cell_type_error = 15,
    cell_conflict = 16,
    arithmetic_overflow = 17,
    segment_byte_limit = 18,
    type_mismatch = 19,
    unsupported_aggregate = 20,
    unknown_column = 21,
    invalid_projection = 22,
    duplicate_projection = 23,
    invalid_bundle = 24,
    invalid_source = 25,
    invalid_prefix = 26,
    invalid_path = 27,
    invalid_projection_budget = 28,
    invalid_text_projection = 29,
    invalid_element_projection = 30,
    unsupported_source = 31,
    unsupported_decoder = 32,
    unsupported_document_source = 33,
    invalid_source_encoding = 34,
    invalid_plan_encoding = 35,
    plan_definition_mismatch = 36,
    invalid_output_names = 37,
    unsupported_plan = 38,
    plan_too_large = 39,
    bundle_too_large = 40,
    truncated_input = 41,
    source_changed = 42,
    table_schema_changed = 43,
    invalid_budget = 44,
    namespace_in_use = 45,
    query_after_mutation = 46,
    nonfinite_value = 47,
    invalid_utf8 = 48,
    cell_too_large = 49,
    invalid_column_name = 50,
    invalid_column_count = 51,
    duplicate_column = 52,
    unsupported_schema = 53,
    peer_mismatch = 54,
    invalid_request_reference = 55,
    writer_not_ready = 56,
    request_resource_expired = 57,
    request_resource_missing = 58,
};
code: Code,
stage: Stage,
dimension: Dimension = .none,
limit: u64 = 0,
observed: u64 = 0,
runtime: ?q.RuntimeWitness = null,
source: ?q.SourceWitness = null,
pub const encoded_bytes = 112;
pub fn category(self: Self) p.Diagnostic.Category {
    if (self.source) |witness| switch (witness.reason) {
        .policy_budget => return .limit,
        .policy_revision, .declaration, .table_schema, .contract => return .conflict,
        else => {},
    };
    return switch (self.code) {
        .policy_denied, .access_denied, .publisher_mismatch, .peer_mismatch => .access,
        .resource_unavailable, .writer_not_ready => .unavailable,
        .request_unpublished, .document_history_gap, .document_retired, .document_resync_required, .request_resource_expired, .request_resource_missing => .lifecycle,
        .budget_exceeded, .projection_budget, .segment_byte_limit, .plan_too_large, .bundle_too_large, .cell_too_large, .arithmetic_overflow => .limit,
        .source_changed, .table_schema_changed, .namespace_in_use, .expansion_conflict, .cell_conflict => .conflict,
        .unsupported_aggregate, .unsupported_source, .unsupported_decoder, .unsupported_document_source, .unsupported_plan, .unsupported_schema => .unsupported,
        .invalid_source_encoding, .invalid_plan_encoding, .plan_definition_mismatch, .truncated_input => .integrity,
        .expansion_missing, .expansion_null, .expansion_type_error, .cell_type_error, .type_mismatch, .unknown_column, .invalid_projection, .duplicate_projection, .invalid_bundle, .invalid_source, .invalid_prefix, .invalid_path, .invalid_projection_budget, .invalid_text_projection, .invalid_element_projection, .invalid_output_names, .invalid_budget, .query_after_mutation, .nonfinite_value, .invalid_utf8, .invalid_column_name, .invalid_column_count, .duplicate_column, .invalid_request_reference => .binding,
    };
}

/// Invoke only after current access has authorized disclosure of this status.
/// Retirement preserves the original cause, while actions follow current phase.
pub fn diagnostic(self: Self, namespace: u64, phase: q.UnifiedRequest.Phase) !p.Diagnostic {
    try self.validate();
    const outcome: p.Diagnostic.Outcome = switch (phase) {
        .denied, .rejected => .rejected,
        .retired => .retired,
        else => return error.InvalidQueryDiagnostic,
    };
    const code = switch (self.code) {
        inline else => |code| "query." ++ @tagName(code),
    };
    var result = try p.Diagnostic.init(code, self.category(), if (self.stage == .admission) .admission else .execute, outcome, .domain_status, self.message());
    result.identity = .{ .domain = .query, .id = .init(namespace) };
    if (self.dimension != .none) {
        try result.text(.budget, .owner, @tagName(self.dimension));
        try result.fact(.limit, .execution, .{ .unsigned = .init(self.limit) });
        try result.fact(.required, .execution, .{ .unsigned = .init(self.observed) });
    }
    if (self.runtime) |witness| try witness.enrich(&result);
    if (self.source) |witness| try witness.enrich(&result);
    try result.fact(.completion, .execution, .{ .boolean = false });
    try result.action(.inspect_status);
    if (self.code == .source_changed or self.code == .table_schema_changed or (self.source != null and (self.source.?.reason == .policy_revision or self.source.?.reason == .declaration))) {
        try result.action(.recompile);
    } else switch (self.category()) {
        .access, .lifecycle, .unavailable => try result.action(.inspect_scope),
        .integrity => try result.action(.contact_operator),
        else => try result.action(.correct_input),
    }
    try result.validate();
    return result;
}
pub fn fromError(cause: anyerror, stage: Stage) ?Self {
    return .{ .stage = stage, .code = switch (cause) {
        error.QueryDenied => .policy_denied,
        error.AccessDenied => .access_denied,
        error.ResourceUnavailable => .resource_unavailable,
        error.PublicationNotPublished => .request_unpublished,
        error.UnexpectedQueryPublisher => .publisher_mismatch,
        error.DocumentHistoryGap => .document_history_gap,
        error.DocumentRetired => .document_retired,
        error.DocumentResyncRequired => .document_resync_required,
        error.QueryBudgetExceeded => .budget_exceeded,
        error.QueryProjectionBudget => .projection_budget,
        error.QueryExpansionMissing => .expansion_missing,
        error.QueryExpansionNull => .expansion_null,
        error.QueryExpansionConflict => .expansion_conflict,
        error.QueryExpansionTypeError => .expansion_type_error,
        error.QueryTypeError => .cell_type_error,
        error.QueryConflict => .cell_conflict,
        error.Overflow => .arithmetic_overflow,
        error.QuerySegmentBudgetExceeded => .segment_byte_limit,
        error.TypeMismatch => .type_mismatch,
        error.UnsupportedAggregate => .unsupported_aggregate,
        error.UnknownColumn => .unknown_column,
        error.InvalidProjection => .invalid_projection,
        error.DuplicateProjection => .duplicate_projection,
        error.InvalidQueryBundle => .invalid_bundle,
        error.InvalidQuerySource => .invalid_source,
        error.InvalidQueryPrefix => .invalid_prefix,
        error.InvalidQueryPath => .invalid_path,
        error.InvalidProjectionBudget => .invalid_projection_budget,
        error.InvalidTextProjection => .invalid_text_projection,
        error.InvalidElementProjection => .invalid_element_projection,
        error.UnsupportedSource => .unsupported_source,
        error.UnsupportedDecoder => .unsupported_decoder,
        error.UnsupportedDocumentSource => .unsupported_document_source,
        error.InvalidSourceEncoding => .invalid_source_encoding,
        error.InvalidPlanEncoding => .invalid_plan_encoding,
        error.UnsupportedPlanDefinition => .plan_definition_mismatch,
        error.InvalidOutputNames => .invalid_output_names,
        error.UnsupportedPlan => .unsupported_plan,
        error.PlanTooLarge => .plan_too_large,
        error.QueryBundleTooLarge => .bundle_too_large,
        error.EndOfStream => .truncated_input,
        error.SourceChanged => .source_changed,
        error.TableSchemaChanged => .table_schema_changed,
        error.InvalidQueryBudget => .invalid_budget,
        error.QueryNamespaceInUse => .namespace_in_use,
        error.QueryAfterMutation => .query_after_mutation,
        error.NonFiniteValue => .nonfinite_value,
        error.InvalidUtf8 => .invalid_utf8,
        error.CellTooLarge => .cell_too_large,
        error.InvalidColumnName => .invalid_column_name,
        error.InvalidColumnCount => .invalid_column_count,
        error.DuplicateColumn => .duplicate_column,
        error.UnsupportedSchema => .unsupported_schema,
        error.UnexpectedQueryPeer => .peer_mismatch,
        error.InvalidPublicationReference => .invalid_request_reference,
        error.TableQueryWriterNotReady => .writer_not_ready,
        error.RequestResourceExpired => .request_resource_expired,
        error.RequestResourceMissing => .request_resource_missing,
        else => return null,
    } };
}
pub fn denied(self: Self) bool {
    return switch (self.code) {
        .policy_denied => true,
        .access_denied => true,
        .resource_unavailable => true,
        .request_unpublished => true,
        .publisher_mismatch => true,
        .document_history_gap => true,
        .document_retired => true,
        .document_resync_required => true,
        .peer_mismatch => true,
        .request_resource_expired, .request_resource_missing => true,
        else => false,
    };
}
pub fn message(self: Self) []const u8 {
    if (self.source) |witness| return witness.message();
    return switch (self.code) {
        .policy_denied => "The current query policy does not permit this request.",
        .access_denied => "Current access to a required resource was denied.",
        .resource_unavailable => "A required resource is unavailable.",
        .request_unpublished => "The request publication is no longer published.",
        .publisher_mismatch => "The request publication has an unexpected publisher.",
        .document_history_gap => "Required Document history is no longer available.",
        .document_retired => "The Document revision is retired.",
        .document_resync_required => "The Document source requires resynchronization.",
        .budget_exceeded => "The query exceeded an admitted execution budget.",
        .projection_budget => "The source projection exceeds its bounded work budget.",
        .expansion_missing => "A collection required for expansion is missing.",
        .expansion_null => "A collection required for expansion is NULL.",
        .expansion_conflict => "A collection required for expansion has an unresolved conflict.",
        .expansion_type_error => "A collection required for expansion has the wrong type.",
        .cell_type_error => "The query encountered a type-error cell.",
        .cell_conflict => "The query encountered an unresolved conflict cell.",
        .arithmetic_overflow => "Checked arithmetic exceeded its representable range.",
        .segment_byte_limit => "One Arrow result segment exceeds the segment-byte limit.",
        .type_mismatch => "A value does not match its required type.",
        .unsupported_aggregate => "The aggregate or its input type is unsupported.",
        .unknown_column => "A referenced column is absent from the source schema.",
        .invalid_projection => "The query projection is invalid for this source.",
        .duplicate_projection => "The query repeats an output position without distinct names.",
        .invalid_bundle => "The submitted query bundle is invalid.",
        .invalid_source => "The query source declaration is invalid.",
        .invalid_prefix => "The KV source prefix is invalid.",
        .invalid_path => "The source projection path is invalid.",
        .invalid_projection_budget => "The source projection budget is invalid.",
        .invalid_text_projection => "The text source projection is invalid.",
        .invalid_element_projection => "The element source projection is invalid.",
        .unsupported_source => "This query source kind is unsupported.",
        .unsupported_decoder => "This source decoder is unsupported.",
        .unsupported_document_source => "This Document source projection is unsupported.",
        .invalid_source_encoding => "The source declaration encoding is invalid.",
        .invalid_plan_encoding => "The query plan encoding is invalid.",
        .plan_definition_mismatch => "The query plan belongs to a different contract definition.",
        .invalid_output_names => "Query output names are invalid or duplicated.",
        .unsupported_plan => "This query plan uses an unsupported operation.",
        .plan_too_large => "The query plan exceeds its byte limit.",
        .bundle_too_large => "The query bundle exceeds its byte limit.",
        .truncated_input => "A required encoded query value is truncated.",
        .source_changed => "The source identity changed from the submitted query basis.",
        .table_schema_changed => "The Table schema changed from the submitted query basis.",
        .invalid_budget => "The submitted execution budget is invalid.",
        .namespace_in_use => "The query namespace is already in use.",
        .query_after_mutation => "Query admission cannot follow a mutation in the same turn.",
        .nonfinite_value => "A query value is not a finite number.",
        .invalid_utf8 => "A query value is not valid UTF-8.",
        .cell_too_large => "A query cell exceeds its byte limit.",
        .invalid_column_name => "A source column name is invalid.",
        .invalid_column_count => "The source column count exceeds the supported shape.",
        .duplicate_column => "The source schema repeats a column name.",
        .unsupported_schema => "The source schema uses an unsupported type or shape.",
        .peer_mismatch => "The caller is not the configured query peer.",
        .invalid_request_reference => "The query request publication reference is invalid.",
        .writer_not_ready => "The combined Table query and writer owner has not completed initialization.",
        .request_resource_expired => "The query request resource expired.",
        .request_resource_missing => "The query request resource no longer exists.",
    };
}
pub fn validate(self: Self) !void {
    if (self.source) |witness| {
        if (self.runtime != null or self.dimension != .none) return error.InvalidQueryFailure;
        const expected: Code = switch (witness.reason) {
            .table_schema => .table_schema_changed,
            .contract => .source_changed,
            .resource => if (self.code == .policy_denied) .policy_denied else .source_changed,
            else => .policy_denied,
        };
        if (self.code != expected) return error.InvalidQueryFailure;
        try witness.validate();
    }
    if (self.runtime) |witness| {
        if (self.stage != .execution or self.dimension != .none) return error.InvalidQueryFailure;
        switch (self.code) {
            .cell_type_error, .cell_conflict, .arithmetic_overflow, .type_mismatch, .unknown_column, .nonfinite_value, .invalid_utf8, .cell_too_large => {},
            else => return error.InvalidQueryFailure,
        }
        try witness.validate();
    }
    if (self.dimension == .none) {
        if (self.limit != 0 or self.observed != 0) return error.InvalidQueryFailure;
    } else if (self.code != .budget_exceeded or self.stage != .execution or self.limit == 0 or self.observed <= self.limit) return error.InvalidQueryFailure;
}
pub fn encode(self: Self) !p.Value {
    try self.validate();
    var bytes: [encoded_bytes]u8 = @splat(0);
    bytes[0..4].* = "UQF1".*;
    std.mem.writeInt(u16, bytes[4..6], @backingInt(self.code), .little);
    bytes[6] = @backingInt(self.stage);
    if (self.runtime) |witness| {
        bytes[7] = 4;
        bytes[8..].* = try witness.encode();
    } else if (self.source) |witness| {
        bytes[7] = 5;
        bytes[8..].* = try witness.encode();
    } else {
        bytes[7] = @backingInt(self.dimension);
        std.mem.writeInt(u64, bytes[8..16], self.limit, .little);
        std.mem.writeInt(u64, bytes[16..24], self.observed, .little);
    }
    return p.Value.init(&bytes);
}
pub fn decode(value: p.Value) !Self {
    try value.validate();
    if (value.len != encoded_bytes or !std.mem.eql(u8, value.data[0..4], "UQF1")) return error.InvalidQueryFailure;
    const result: Self = .{
        .code = std.enums.fromInt(Code, std.mem.readInt(u16, value.data[4..6], .little)) orelse return error.InvalidQueryFailure,
        .stage = std.enums.fromInt(Stage, value.data[6]) orelse return error.InvalidQueryFailure,
        .dimension = if (value.data[7] == 4 or value.data[7] == 5) .none else std.enums.fromInt(Dimension, value.data[7]) orelse return error.InvalidQueryFailure,
        .limit = if (value.data[7] == 4 or value.data[7] == 5) 0 else std.mem.readInt(u64, value.data[8..16], .little),
        .observed = if (value.data[7] == 4 or value.data[7] == 5) 0 else std.mem.readInt(u64, value.data[16..24], .little),
        .runtime = if (value.data[7] == 4) try q.RuntimeWitness.decode(value.data[8..encoded_bytes]) else null,
        .source = if (value.data[7] == 5) try q.SourceWitness.decode(value.data[8..encoded_bytes]) else null,
    };
    try result.validate();
    if (!(try result.encode()).eql(value)) return error.InvalidQueryFailure;
    return result;
}

test "every saved query failure projects stable evidence and safe actions" {
    const t = std.testing;
    inline for (comptime std.meta.tags(Code)) |code| {
        const failure: Self = .{ .code = code, .stage = .execution };
        for ([_]q.UnifiedRequest.Phase{ .denied, .rejected, .retired }) |phase| {
            const value = try failure.diagnostic(p.max_counter, phase);
            try t.expectEqualStrings("query." ++ @tagName(code), value.code.slice());
            try t.expectEqual(p.Diagnostic.Evidence.domain_status, value.evidence);
            try t.expectEqual(p.Diagnostic.ActionKind.inspect_status, value.actions[0].?.kind);
            for (value.actions) |slot| if (slot) |action| {
                try t.expect(action.kind != .resume_exact and action.kind != .cancel_wait);
            };
        }
        try t.expectError(error.InvalidQueryDiagnostic, failure.diagnostic(1, .complete));
    }
    const measured: Self = .{ .code = .budget_exceeded, .stage = .execution, .dimension = .result_bytes, .limit = std.math.maxInt(u64) - 1, .observed = std.math.maxInt(u64) };
    const value = try measured.diagnostic(1, .rejected);
    try t.expectEqual(std.math.maxInt(u64), try value.facts[2].?.value.?.unsigned.value());
}
