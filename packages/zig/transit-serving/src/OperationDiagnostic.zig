//! Pure projection of retained serving outcomes. A reply is opaque application
//! data; closing the serving wait never proves remote cancellation or rollback.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const d = p.Diagnostic;
const m = root.Model;
pub fn project(realm: u64, service: u64, resource: u64, record: m.Operation) !d {
    try record.validate();
    var result = switch (record.phase) {
        .admitted => try d.init("serving.operation_admitted", .lifecycle, .admission, .pending, .domain_status, "The serving owner recorded this operation, its wait and outgoing call atomically. A destination result is not yet recorded. Inspect this exact operation or cancel its local wait; do not submit a replacement command to recover it."),
        .completed => try d.init("serving.reply_recorded", .lifecycle, .execute, .completed, .domain_status, "The serving owner recorded an authenticated reply from the original target. Interpret that reply with the recorded application codec to determine its business outcome. Receiving a reply does not by itself establish business success."),
        .cancelled => try d.init("serving.wait_cancelled", .lifecycle, .control, .cancelled, .domain_status, "The serving wait was cancelled and its active slot released. The outgoing application call and any remote effect were not cancelled or rolled back. A late reply cannot replace this outcome. Inspect the application before considering new work."),
        .timed_out => try d.init("serving.wait_timed_out", .lifecycle, .execute, .closed_unknown, .domain_status, "The serving wait reached its recorded deadline and closed without a reply. The application's outcome remains unknown here. A late reply cannot replace this outcome. Inspect the original application operation; a timeout does not make a new submission safe."),
        .failed => try d.init("serving.reply_too_large", .limit, .output, .failed, .domain_status, "An authenticated reply exceeded the serving inline result limit. Its exact byte count is retained, but its payload was not retained. The application may already have acted. Inspect its original operation; do not repeat the command to obtain a smaller reply."),
    };
    result.identity = .{ .domain = .serving, .id = .init(record.operation), .realm = .init(realm), .resource = .init(resource) };
    try result.fact(.object, .owner, .{ .unsigned = .init(service) });
    try result.fact(.scope, .authority, .{ .unsigned = .init(record.principal) });
    try result.fact(.actual_source, .owner, .{ .unsigned = .init(record.target) });
    try result.fact(.actual_revision, .owner, .{ .unsigned = .init(record.binding) });
    try result.fact(.actual_policy, .owner, .{ .unsigned = .init(record.policy_revision) });
    try result.fact(.actual_codec, .owner, .{ .unsigned = .init(record.codec) });
    try result.fact(.lease, .owner, .{ .unsigned = .init(record.deadline_ms) });
    try result.fact(.proposal, .caller, .{ .digest = record.digest });
    try result.fact(.native_input, .authority, .{ .unsigned = .init(if (record.resolution_input == 0) record.correlation else record.resolution_input) });
    if (record.phase == .failed) {
        result.cause = try d.Code.init("ServingResultTooLarge");
        try result.fact(.required, .execution, .{ .unsigned = .init(record.reply_bytes) });
        try result.fact(.limit, .owner, .{ .unsigned = .init(m.inline_bytes) });
        try result.text(.unit, .owner, "bytes");
    }
    try result.action(.inspect_status);
    if (record.phase == .admitted) try result.action(.cancel_wait);
    try result.validate();
    return result;
}

test "all serving phases preserve their exact outcome without authorizing a fresh command" {
    const t = std.testing;
    var record: m.Operation = .{ .principal = p.max_counter, .operation = p.max_counter, .binding = p.max_counter, .codec = 65535, .deadline_ms = p.max_counter, .digest = @splat(255), .target = p.max_counter, .correlation = p.max_counter, .policy_revision = p.max_counter };
    const outcomes = [_]d.Outcome{ .pending, .completed, .cancelled, .closed_unknown, .failed };
    inline for (std.meta.tags(m.Phase), 0..) |phase, index| {
        record.phase = phase;
        record.resolution_input = if (phase == .admitted) 0 else p.max_counter;
        record.result = if (phase == .completed) try p.Value.init(&@as([64]u8, @splat(255))) else .{};
        record.reply_bytes = if (phase == .completed) 64 else if (phase == .failed) root.station.Frame.max_payload else 0;
        const detail = try project(p.max_counter, p.max_counter, p.max_counter, record);
        try t.expectEqual(outcomes[index], detail.outcome);
        try t.expectEqual(.domain_status, detail.evidence);
        for (detail.actions) |slot| if (slot) |action| try t.expect(action.kind == .inspect_status or (phase == .admitted and action.kind == .cancel_wait));
        const stored = try root.Codec.encode('o', record);
        try t.expect(stored.len <= 170);
        try t.expectEqualDeep(record, try root.Codec.decode(m.Operation, 'o', stored));
        var buffer: [8192]u8 = undefined;
        _ = try detail.encode(&buffer);
        const maximum = p.max_counter;
        const event: root.ReactiveWire.ServerMessage = .{ .event = .{
            .cursor = .{ .position = .{ .scope = .{ .realm = maximum, .principal = maximum, .service = maximum, .ingress = maximum, .session = maximum, .generation = maximum, .subscription = maximum, .subscription_generation = maximum }, .watch_revision = maximum, .resource = maximum, .schema = @splat(255), .data_revision = .{ .value = std.math.maxInt(u64) }, .outcome_position = record.resolution_input }, .signature = @splat(255) },
            .event = .{ .source_changed = true, .resource = maximum, .data_revision = .{ .value = std.math.maxInt(u64) }, .outcome = .{ .resource = maximum, .operation = maximum, .phase = phase, .resolution_input = record.resolution_input, .diagnostic = detail } },
        } };
        var writer: std.Io.Writer = .fixed(&buffer);
        try std.json.Stringify.value(event, .{}, &writer);
    }
    record.reply_bytes = 64;
    try t.expectError(error.InvalidServingRecord, record.validate());
}
