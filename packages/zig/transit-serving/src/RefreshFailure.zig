//! Original scheduler stop evidence, independent of the selected query outcome.
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
const f = root.ServingFailure;
pub const Reason = enum(u8) {
    paused,
    budget_exhausted,
    session_closed,
    session_expired,
    source_changed,
    binding_unpublished,
    service_denied,
    native_denied,
    query_denied,
    resource_unavailable,
    query_source_unavailable,
    result_unavailable,
    result_unpublished,
    template_invalid,
    upload_closed,
    namespace_occupied,
    query_rejected,
    query_cancelled,
    query_retired,
};
pub const Status = struct { resource: u64, revision: u64, policy_revision: u64, view: root.RefreshModel.View, diagnostic: ?d = null, query_diagnostic: ?d = null };
pub const Stop = struct { reason: Reason, input: u64, witness: f.Witness = .none };
pub const Record = union(enum(u8)) { none = 0, stopped: Stop = 1 };
pub fn reason(cause: anyerror) ?Reason {
    return switch (cause) {
        error.ReactiveSessionClosed => .session_closed,
        error.ReactiveSessionExpired => .session_expired,
        error.ReactiveResetRequired => .source_changed,
        error.ServiceUnpublished => .binding_unpublished,
        error.ServingDenied => .service_denied,
        error.AccessDenied => .native_denied,
        error.QueryDenied => .query_denied,
        error.ResourceUnavailable => .resource_unavailable,
        error.QuerySourceUnavailable => .query_source_unavailable,
        error.ResultUnavailable => .result_unavailable,
        error.PublicationNotPublished => .result_unpublished,
        error.InvalidRefreshTemplate => .template_invalid,
        error.QueryUploadClosed => .upload_closed,
        else => null,
    };
}
pub fn denied(value: Reason) bool {
    return switch (value) {
        .service_denied, .native_denied, .query_denied => true,
        else => false,
    };
}
pub fn record(input: u64, value: Reason, context: f.Context) Record {
    return .{ .stopped = .{ .reason = value, .input = input, .witness = context.witness } };
}
pub fn project(realm: u64, resource: u64, view: root.RefreshModel.View) !?d {
    const stop = switch (view.failure) {
        .none => return null,
        .stopped => |value| value,
    };
    try root.Model.identity(stop.input);
    const message: []const u8 = switch (stop.reason) {
        .paused => "Follow scheduling was explicitly paused. Already selected query work remains independent and may complete. Inspect its exact namespace; pausing does not cancel it or discard a displayed result.",
        .budget_exhausted => "This Follow generation has used its finite query-start budget. The final selected query can still have a ready result to verify. Inspect its exact outcome before explicitly reviewing another Follow generation.",
        .session_closed => "The session was explicitly closed, so this Follow generation stopped selecting new queries. Previously selected queries retain their own outcomes and are not cancelled by session closure.",
        .session_expired => "The session lease was reached or expiry was recorded, so this Follow generation stopped selecting new queries. The retained phase and clock distinguish observed deadline from committed expiry. Selected queries remain independent.",
        .source_changed => "The watch declaration or source basis changed from this Follow generation's retained source. New refresh selection stopped. Inspect the original source witness before explicitly acquiring an authorized snapshot.",
        .binding_unpublished => "A required service binding was absent or unpublished at the scheduling check. Follow stopped selecting new queries. Existing selected queries retain their recorded source and outcome.",
        .service_denied => "Current service read permission denied Follow progress. No new result coverage was established. Previously selected query work retains its own outcome; inspect current service rights before continuing.",
        .native_denied => "Current native authority denied Follow progress. No new result coverage was established. Inspect the exact selected query and current native scope; restoring authority does not implicitly restart this generation.",
        .query_denied => "Current query authority denied Follow progress. No new result coverage was established. Inspect the exact selected query and source policy before explicitly reviewing further work.",
        .resource_unavailable => "A required process or resource was unavailable, so Follow stopped progressing. This is not evidence that permission was revoked or that a previously selected query failed. Inspect the exact resource and query outcome.",
        .query_source_unavailable => "The required query source was unavailable, so Follow stopped progressing. Retain the last exact result basis and inspect the selected query; source unavailability does not cancel it.",
        .result_unavailable => "A retained result needed by Follow was unavailable. No replacement coverage was established. Inspect the exact template or selected query and its retained result before continuing.",
        .result_unpublished => "The required result publication was incomplete at the check. No replacement coverage was established. Inspect its exact query and publication; a partially published result is not a completed snapshot.",
        .template_invalid => "The Follow template is not a complete result for the required source basis. Refresh progress stopped without establishing replacement coverage. Compare the original template and source commitments.",
        .upload_closed => "The selected query upload is closed. Follow cannot continue copying or admitting that identity. Inspect its original query outcome; do not replace its saved bytes or repeat the SQL automatically.",
        .namespace_occupied => "The scheduler's proposed query namespace was already occupied. It preserved the existing work and did not select a replacement query. Inspect the retained conflicting namespace and this Follow generation.",
        .query_cancelled => "The selected query wait was cancelled, so this Follow generation stopped progressing. Previously disclosed results remain disclosed. Cancellation does not prove that source computation or external effects were undone; inspect the exact query outcome.",
        .query_retired => "The selected query was retired and its result is no longer available through that request. Follow established no replacement coverage. Inspect the retained query identity and choose further work explicitly.",
        .query_rejected => "The selected query has a recorded rejection. Follow established no replacement result coverage. Its separate query diagnostic carries the original query cause and witness when still available; inspect that exact namespace.",
    };
    const category: d.Category = if (denied(stop.reason)) .access else switch (stop.reason) {
        .budget_exhausted => .limit,
        .source_changed, .namespace_occupied => .conflict,
        .template_invalid => .binding,
        .query_rejected => .lifecycle,
        .resource_unavailable, .query_source_unavailable, .result_unavailable => .unavailable,
        else => .lifecycle,
    };
    const code = switch (stop.reason) {
        inline else => |value| "refresh." ++ @tagName(value),
    };
    var result = try d.init(code, category, .control, .not_applicable, .domain_status, message);
    result.identity = .{ .domain = .reactive, .id = .init(view.session.session), .realm = .init(realm), .resource = .init(resource) };
    try result.fact(.native_input, .owner, .{ .unsigned = .init(stop.input) });
    try result.fact(.generation, .owner, .{ .unsigned = .init(view.generation) });
    try result.fact(.proposal, .owner, .{ .unsigned = .init(view.namespace.value) });
    try result.text(.source_kind, .owner, "Follow scheduler; query outcome is independent");
    try f.facts(&result, stop.witness);
    if (stop.reason == .budget_exhausted) {
        try result.fact(.actual_count, .owner, .{ .unsigned = .init(view.starts) });
        try result.fact(.limit, .owner, .{ .unsigned = .init(view.limit) });
        try result.text(.unit, .owner, "selected query intents");
    }
    try result.action(.inspect_status);
    if (denied(stop.reason)) try result.action(.inspect_scope);
    try result.validate();
    return result;
}

test "every scheduler stop preserves bounded original evidence independently of query outcome" {
    const std = @import("std");
    const t = std.testing;
    var view: root.RefreshModel.View = .{ .principal = p.max_counter, .session = .{ .session = p.max_counter, .generation = p.max_counter }, .generation = p.max_counter, .source = .{ .revision = p.max_counter, .target = p.max_counter, .resource = p.max_counter, .table = 1, .progress_key = try p.Value.init(&@as([32]u8, @splat(255))), .schema = @splat(255) }, .template = .{ .value = std.math.maxInt(u64) }, .namespace = .{ .value = std.math.maxInt(u64) }, .dirty = p.max_counter, .covered = p.max_counter, .limit = 8, .starts = 8 };
    const original: f.Witness = f.sourceWitness(view.source, p.max_counter);
    var max_bytes: usize = 0;
    for (std.enums.values(Reason)) |why| {
        view.failure = record(p.max_counter, why, .{ .witness = original });
        const encoded = try root.Codec.encode('G', view);
        max_bytes = @max(max_bytes, encoded.len);
        const restored = try root.Codec.decode(root.RefreshModel.View, 'G', encoded);
        try t.expectEqualDeep(view, restored);
        const diagnostic = (try project(p.max_counter, p.max_counter, restored)).?;
        try t.expectEqual(.not_applicable, diagnostic.outcome);
        try t.expectEqual(denied(why), diagnostic.category == .access);
        const query_failure: root.query.QueryFailure = .{ .code = .arithmetic_overflow, .stage = .execution, .runtime = .{
            .resource = p.max_counter,
            .revision = p.max_counter,
            .binding = @splat(255),
            .row = std.math.maxInt(u64),
            .kind = .kv,
            .operation = .predicate,
            .column = 1,
            .instruction = 0,
            .expected = .int64,
            .key_kind = .kv,
            .key_length = 256,
            .decoding = .invalid_length,
            .actual_bytes = 256,
            .column_length = 23,
            .column_truncated = true,
            .detail = @splat('X'),
        } };
        const status: Status = .{ .resource = p.max_counter, .revision = p.max_counter, .policy_revision = p.max_counter, .view = restored, .diagnostic = diagnostic, .query_diagnostic = try query_failure.diagnostic(view.namespace.value, .rejected) };
        const json = try p.Json.valueAlloc(t.allocator, status);
        defer t.allocator.free(json);
        try t.expect(json.len < 16384);
        try t.expect(std.mem.indexOf(u8, json, "18446744073709551615") != null);
        for (diagnostic.actions) |action| if (action) |value| try t.expect(value.kind == .inspect_status or value.kind == .inspect_scope);
    }
    try t.expectEqual(@as(usize, 251), max_bytes);
}
