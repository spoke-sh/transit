//! Finite view demand and scheduler records. Native commands remain bounded SV1;
//! full-width query namespaces use lossless decimal JSON at host boundaries.
const std = @import("std");
const root = @import("root.zig");
const r = root.ReactiveModel;
const p = root.protocol;
pub const max_starts: u8 = 8;
pub const start_interval_ms: u64 = 1000;
pub const Namespace = root.query.TablePosition.Counter;
/// Native admission freezes the original principal, selected role and credential
/// epoch. The stored reference is rechecked before every scheduler continuation.
pub const Proof = @FieldType(p.Authorization.Subject, "accepted");
pub const Selection = struct { session: r.SessionIdentity, generation: u64 };
pub const Captures = [max_starts]Namespace;
pub const Follow = struct { session: r.SessionIdentity, expected: u64, template: Namespace, captures: Captures, limit: u8 };
pub fn validateCaptures(captures: Captures, limit: u8, template: Namespace) !void {
    if (limit == 0 or limit > max_starts or template.value == 0) return error.InvalidRefreshBudget;
    for (captures, 0..) |capture, i| {
        if (i >= limit) {
            if (capture.value != 0) return error.InvalidRefreshBudget;
        } else {
            if (capture.value == 0 or capture.value == template.value) return error.InvalidRefreshTemplate;
            for (captures[0..i]) |previous| if (capture.value == previous.value) return error.InvalidRefreshTemplate;
        }
    }
}
pub const Acknowledged = struct { selection: Selection, namespace: Namespace };
pub const Input = union(enum(u8)) {
    follow: Follow = 0,
    invalidate: Selection = 1,
    acknowledged: Acknowledged = 2,
    pause: Selection = 3,
};
pub const Command = union(enum(u8)) {
    follow: struct { view: Follow } = 0,
    invalidate: Selection = 1,
    acknowledged: Acknowledged = 2,
    pause: Selection = 3,
};
pub const Phase = enum(u8) { idle = 1, preparing = 2, admitted = 3, ready = 4, paused = 5, denied = 6, exhausted = 7, failed = 8 };
pub const View = struct {
    principal: u64,
    session: r.SessionIdentity,
    generation: u64,
    source: r.Source,
    template: Namespace,
    namespace: Namespace,
    dirty: Namespace,
    covered: Namespace,
    starts: u8 = 0,
    limit: u8,
    next_start_ms: u64 = 0,
    enabled: bool = true,
    phase: Phase = .idle,
    failure: root.RefreshFailure.Record = .none,
};
pub const Scheduler = struct {
    next: u8 = 0,
    principal: u64 = 0,
    generation: u64 = 0,
};
pub fn headKey(principal: u64, session: u64) p.Value {
    return root.Model.key('F', principal, session);
}
pub fn viewKey(principal: u64, generation: u64) p.Value {
    return root.Model.key('G', principal, generation);
}
pub fn proofKey(principal: u64, generation: u64) p.Value {
    return root.Model.key('I', principal, generation);
}
pub fn capturesKey(principal: u64, generation: u64) p.Value {
    return root.Model.key('K', principal, generation);
}
pub const scheduler_key = root.Model.key('J', 0, 0);
pub const wake = p.Value.init("SV1w") catch unreachable;

test "refresh records and full-width namespaces preserve existing frame bounds" {
    const t = std.testing;
    const scope: r.SessionIdentity = .{ .session = 3, .generation = 4 };
    const command: Command = .{ .follow = .{ .view = .{ .session = scope, .expected = 0, .template = .{ .value = std.math.maxInt(u64) }, .captures = .{ .{ .value = 1 }, .{ .value = 2 }, .{ .value = 3 }, .{ .value = 4 }, .{ .value = 5 }, .{ .value = 6 }, .{ .value = 7 }, .{ .value = 8 } }, .limit = max_starts } } };
    const bytes = try (root.Model.Command{ .refresh = command }).encode();
    try t.expect(bytes.len <= root.station.Frame.max_payload);
    try t.expectEqual(@as(u16, 103), bytes.len);
    try t.expectEqualDeep(command, (try root.Model.Command.decode(bytes)).refresh);
    const view: View = .{ .principal = 65536, .session = scope, .generation = 9, .source = .{ .revision = 1, .audience = 8, .resource = 9, .realm = 1, .catalog = .{ .value = 9 }, .object = .{ .value = 100 }, .interpretation_revision = .{ .value = 1 }, .branch = 1, .namespace = 1, .interpretation_digest = @splat(5) }, .template = command.follow.view.template, .namespace = .{ .value = 1 << 63 }, .dirty = .{ .value = 11 }, .covered = .{ .value = 10 }, .limit = max_starts };
    const stored = try root.Codec.encode('G', view);
    try t.expect(stored.len <= p.Value.max_bytes);
    try t.expectEqualDeep(view, try root.Codec.decode(View, 'G', stored));
    const json = try p.Json.valueAlloc(t.allocator, command.follow.view.template);
    defer t.allocator.free(json);
    try t.expectEqualStrings("\"18446744073709551615\"", json);
    var decoded = try p.Json.parseFromSlice(Namespace, t.allocator, json);
    defer decoded.deinit();
    try t.expectEqual(std.math.maxInt(u64), decoded.value.value);
    for ([_][]const u8{ "18446744073709551615", "\"18446744073709551616\"", "\"01\"", "\"-1\"", "\"1.0\"" }) |invalid| {
        if (p.Json.parseFromSlice(Namespace, t.allocator, invalid)) |parsed| {
            parsed.deinit();
            return error.AcceptedInvalidNamespace;
        } else |_| {}
    }
}
