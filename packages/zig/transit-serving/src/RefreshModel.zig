//! M21 view demand and scheduler records. Native commands remain bounded SV1;
//! full-width query namespaces use lossless decimal JSON at host boundaries.
const std = @import("std");
const root = @import("root.zig");
const r = root.ReactiveModel;
const p = root.protocol;
pub const max_starts: u8 = 8;
pub const start_interval_ms: u64 = 1000;
pub const Namespace = struct {
    value: u64 = 0,
    pub fn jsonStringify(self: Namespace, out: *std.json.Stringify) !void {
        var bytes: [20]u8 = undefined;
        try out.write(std.fmt.bufPrint(&bytes, "{d}", .{self.value}) catch unreachable);
    }
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Namespace {
        const text = try std.json.innerParse([]const u8, allocator, source, options);
        return .{ .value = root.query.Values.unsigned(text) catch return error.InvalidNumber };
    }
    pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.write(.{ .type = "string", .pattern = "^(0|[1-9][0-9]*)$", .maxLength = 20, .@"x-transit-encoding" = "unsigned-decimal-u64" });
    }
};
/// Scoped read proofs are rechecked with the native authority before each new
/// evaluation. They are not credentials granting general delegation. The source
/// and requester resource identities come from the frozen accepted declaration.
pub const Proof = struct { identity: [64]u8, source: [64]u8, requester: [64]u8 };
pub const Selection = struct { session: r.SessionIdentity, generation: u64 };
pub const Follow = struct { session: r.SessionIdentity, expected: u64, template: Namespace, limit: u8 };
pub const Acknowledged = struct { selection: Selection, namespace: Namespace };
pub const Input = union(enum(u8)) {
    follow: Follow = 0,
    invalidate: Selection = 1,
    acknowledged: Acknowledged = 2,
    pause: Selection = 3,
};
pub const Command = union(enum(u8)) {
    follow: struct { view: Follow, proof: Proof } = 0,
    invalidate: Selection = 1,
    acknowledged: Acknowledged = 2,
    pause: Selection = 3,
};
pub const Phase = enum(u8) { idle = 1, copying = 2, admitted = 3, ready = 4, paused = 5, denied = 6, exhausted = 7, failed = 8 };
pub const View = struct {
    principal: u64,
    session: r.SessionIdentity,
    generation: u64,
    source: r.Source,
    template: Namespace,
    namespace: Namespace,
    dirty: u64,
    covered: u64,
    starts: u8 = 0,
    limit: u8,
    next_start_ms: u64 = 0,
    enabled: bool = true,
    phase: Phase = .idle,
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
pub const scheduler_key = root.Model.key('J', 0, 0);
pub const wake = p.Value.init("SV1w") catch unreachable;

test "refresh records and full-width namespaces preserve existing frame bounds" {
    const t = std.testing;
    const scope: r.SessionIdentity = .{ .session = 3, .generation = 4 };
    const command: Command = .{ .follow = .{ .view = .{ .session = scope, .expected = 0, .template = .{ .value = std.math.maxInt(u64) }, .limit = max_starts }, .proof = .{ .identity = @splat(1), .source = @splat(2), .requester = @splat(3) } } };
    const bytes = try (root.Model.Command{ .refresh = command }).encode();
    try t.expect(bytes.len <= root.station.Frame.max_payload);
    try t.expectEqual(@as(u16, 231), bytes.len);
    try t.expectEqualDeep(command, (try root.Model.Command.decode(bytes)).refresh);
    const view: View = .{ .principal = 65536, .session = scope, .generation = 9, .source = .{ .revision = 1, .target = 8, .resource = 9, .table = 1, .progress_key = try p.Value.init(&@as([32]u8, @splat(1))), .schema = @splat(5) }, .template = command.follow.view.template, .namespace = .{ .value = 1 << 63 }, .dirty = 11, .covered = 10, .limit = max_starts };
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
